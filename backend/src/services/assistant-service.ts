import { HttpError } from '../middlewares/http-error.js';
import type {
  AdminAnswerRow,
  AssistantRequest,
  AssistantRequestDetail,
  AssistantRequestStatus,
  RecipeHistoryEntry,
} from '../models/assistant-request.js';
import type { AdminInventoryProduct } from '../models/catalog.js';
import * as assistantRequestRepository from '../repositories/assistant-request-repository.js';
import * as catalogRepository from '../repositories/catalog-repository.js';
import * as choiceRepository from '../repositories/assistant-choice-repository.js';
import * as branchRepository from '../repositories/branch-repository.js';
import * as ingredientRepository from '../repositories/ingredient-repository.js';
import * as productRepository from '../repositories/product-repository.js';
import * as shoppingListRepository from '../repositories/shopping-list-repository.js';
import { AiServiceError } from './ai/ai-error.js';
import { recommendProducts } from './ai/product-recommendations.js';
import { availableModels, generateJson, resolveModel, type AiModel } from './ai/ai-provider.js';
import {
  buildRecipeInstruction,
  buildCompactRecipeInstruction,
  compactRecipeResponseSchema,
  maxAnalyzedPromptLength,
  parseRecipeAnalysis,
  parseCompactRecipeAnalysis,
  recipeResponseSchema,
  type RecipeAnalysis,
} from './ai/recipe-analysis.js';
import { parseAssistantRequest } from './assistant-prompt.js';
import { getIdentity } from './auth-service.js';
import { generateIngredientList } from './ingredient-list-service.js';
import { buildIngredientAvailability } from './ingredient-availability.js';
import { latestPerRecipe } from './recipe-history.js';
import {
  adminAssistantQuerySchema,
  buildAdminAssistantInstruction,
  buildAdminAssistantQueryInstruction,
  parseAdminAssistantResponse,
  parseAdminAssistantQuery,
  adminAssistantResponseSchema,
} from './ai/admin-assistant.js';

/**
 * Recibe la petición del usuario, la guarda tal cual junto con la sucursal
 * seleccionada e inicia su procesamiento.
 */
export async function submitRequest(
  authorization: string | undefined,
  body: unknown,
): Promise<AssistantRequest> {
  const identity = getIdentity(authorization);
  const { prompt, branchId, modelId } = parseAssistantRequest(body);
  let model: AiModel;
  try {
    model = resolveModel(modelId);
  } catch (error) {
    if (error instanceof AiServiceError) throw new HttpError(400, error.userMessage);
    throw error;
  }
  const assignedBranchId = identity.role === 'admin'
    ? await productRepository.findAdminBranch(identity.userId)
    : null;
  if (identity.role === 'admin' && prompt.length > maxAnalyzedPromptLength) {
    throw new HttpError(400, 'La consulta es muy larga. Resume lo que necesitas saber.');
  }
  if (identity.role === 'admin' && assignedBranchId === null) {
    throw new HttpError(403, 'Tu usuario no tiene una sucursal asignada.');
  }
  if (identity.role === 'admin' && branchId !== null && branchId !== assignedBranchId) {
    throw new HttpError(403, 'Solo puedes consultar tu sucursal asignada.');
  }
  if (
    identity.role !== 'admin' &&
    branchId !== null &&
    !(await branchRepository.isActive(branchId))
  ) {
    throw new HttpError(400, 'branch_id no corresponde a una sucursal activa.');
  }
  const effectiveBranchId = assignedBranchId ?? branchId;
  const received = await assistantRequestRepository.create({
    userId: identity.userId,
    branchId: effectiveBranchId,
    prompt,
  });
  const processing = await startProcessing(received);
  // La IA tarda unos segundos: se responde de inmediato y la app consulta el
  // resultado con getRequest. processRequest nunca lanza errores.
  void processRequest(processing, model, identity.role === 'admin');
  return processing;
}

export function listModels(authorization: string | undefined): AiModel[] {
  getIdentity(authorization);
  return availableModels();
}

/** Petición del usuario con su estado actual y los ingredientes generados. */
export async function getRequest(
  authorization: string | undefined,
  requestId: number,
): Promise<AssistantRequestDetail> {
  const identity = getIdentity(authorization);
  const request = await assistantRequestRepository.findById(requestId);
  if (!request || request.user_id !== identity.userId) {
    throw new HttpError(404, 'Petición no encontrada.');
  }
  const list = await shoppingListRepository.findByRequest(requestId);
  return { ...request, ingredients: list?.items ?? [] };
}

/** Recetas que el usuario ya pidió; repetirlas no vuelve a consultar a la IA. */
export async function listRecipeHistory(
  authorization: string | undefined,
): Promise<RecipeHistoryEntry[]> {
  const identity = getIdentity(authorization);
  return latestPerRecipe(
    await assistantRequestRepository.findCompletedRecipes(identity.userId),
  );
}

/** Marca la petición como en procesamiento para que el sistema de IA la tome. */
async function startProcessing(
  request: AssistantRequest,
): Promise<AssistantRequest> {
  const processing = await assistantRequestRepository.updateStatus(
    request.request_id,
    'PROCESSING',
  );
  if (!processing) {
    throw new Error('No se pudo iniciar el procesamiento de la petición.');
  }
  return processing;
}

/** HU-14 y HU-15: la IA decide si la petición es una receta y extrae sus ingredientes. */
async function analyzePrompt(prompt: string, model: AiModel): Promise<RecipeAnalysis> {
  if (prompt.length > maxAnalyzedPromptLength) {
    return {
      isRecipe: false,
      message: 'Tu petición es muy larga. Escribe solo el plato que quieres preparar.',
    };
  }
  const catalogNames = await ingredientRepository.findAllNames();
  const compact = model.id.startsWith('ollama:');
  const output = await generateJson({
    systemInstruction: compact
      ? buildCompactRecipeInstruction(catalogNames)
      : buildRecipeInstruction(catalogNames),
    userText: prompt,
    responseSchema: compact ? compactRecipeResponseSchema : recipeResponseSchema,
    maxOutputTokens: 3072,
  }, model);
  return compact ? parseCompactRecipeAnalysis(output) : parseRecipeAnalysis(output);
}

async function answerAdminQuestion(
  request: AssistantRequest,
  model: AiModel,
): Promise<{ answer: string; rows?: AdminAnswerRow[] }> {
  if (request.branch_id === null) {
    throw new HttpError(403, 'Tu usuario no tiene una sucursal asignada.');
  }
  const branch = await catalogRepository.findBranchById(request.branch_id);
  if (!branch) throw new HttpError(404, 'Sucursal no encontrada.');
  const categories = await catalogRepository.findCategories();
  const queryOutput = await generateJson({
    systemInstruction: buildAdminAssistantQueryInstruction(categories),
    userText: request.prompt,
    responseSchema: adminAssistantQuerySchema,
    maxOutputTokens: 512,
  }, model);
  const query = parseAdminAssistantQuery(queryOutput);
  if (query.category) {
    const category = categories.find(
      (entry) => entry.name.localeCompare(
        query.category!, undefined, { sensitivity: 'base' },
      ) === 0,
    );
    if (category) query.category = category.name;
  }
  const inventory = await catalogRepository.findAdminInventory(
    request.branch_id,
    query,
  );
  const output = await generateJson({
    systemInstruction: buildAdminAssistantInstruction(branch, query, inventory),
    userText: request.prompt,
    responseSchema: adminAssistantResponseSchema,
    maxOutputTokens: 1200,
  }, model);
  return {
    answer: parseAdminAssistantResponse(output),
    ...adminAnswerRows(inventory.products),
  };
}

/**
 * Barras de stock de la respuesta: los mismos productos de la consulta real
 * que recibió la IA. Sin productos (conteos o resúmenes por categoría), no hay filas.
 */
export function adminAnswerRows(
  products: AdminInventoryProduct[],
): { rows?: AdminAnswerRow[] } {
  const rows = products.flatMap((product) =>
    product.product_id === undefined
      ? []
      : [{
          product_id: product.product_id,
          name: product.name,
          stock: product.stock,
          status: product.stock <= 0 ? 'out' as const
            : product.stock <= lowStockThreshold ? 'low' as const
            : 'ok' as const,
        }],
  );
  return rows.length === 0 ? {} : { rows };
}

/** Mismo umbral que el inventario usa para «por agotarse». */
const lowStockThreshold = 5;

/**
 * Procesa la petición en segundo plano y deja el resultado en la base de datos:
 * REJECTED si no es una receta, COMPLETED con la receta y su lista de
 * ingredientes (HU-16), o FAILED con un mensaje para el usuario.
 */
export async function processRequest(
  request: AssistantRequest,
  model: AiModel,
  adminMode = false,
): Promise<void> {
  const save = (
    status: AssistantRequestStatus,
    recipeName: string | null,
    message: string | null,
  ) =>
    assistantRequestRepository.saveAnalysis(request.request_id, {
      status,
      recipeName,
      message,
    });

  let recipeName: string | null = null;
  try {
    if (request.branch_id === null) {
      // Sin sucursal no se puede guardar la lista ni consultar el inventario.
      await save('FAILED', null, 'Elige un supermercado antes de pedir una receta.');
      return;
    }

    if (adminMode) {
      const { answer, rows } = await answerAdminQuestion(request, model);
      await assistantRequestRepository.saveAnalysis(request.request_id, {
        status: 'COMPLETED',
        recipeName: null,
        message: answer,
        rows,
      });
      return;
    }

    const analysis = await analyzePrompt(request.prompt, model);
    if (!analysis.isRecipe) {
      await save('REJECTED', null, analysis.message);
      return;
    }

    // La receta identificada queda disponible para extraer sus ingredientes.
    recipeName = analysis.recipeName;
    await save('PROCESSING', recipeName, null);
    const list = await generateIngredientList(request, analysis.ingredients);
    await choiceRepository.saveIntents(request.user_id, analysis.intents ?? []);
    const ingredientIds = list.items.flatMap((item) => item.ingredient_id === null ? [] : [item.ingredient_id]);
    const substitutions = await ingredientRepository.findSubstitutions(ingredientIds);
    const [products, branches, intents, history, profile] = await Promise.all([
      ingredientRepository.findAvailableProducts([...ingredientIds, ...substitutions.map((item) => item.substitute_ingredient_id)]),
      branchRepository.findActive(),
      choiceRepository.findIntents(request.user_id),
      choiceRepository.findSelectionHistory(request.user_id),
      choiceRepository.findProfile(request.user_id),
    ]);
    const candidates = buildIngredientAvailability({
      items: list.items, branchId: request.branch_id, branches, products, substitutions,
    });
    const recommendations = await recommendProducts(
      model, request.prompt, intents, candidates.items, history, profile.preferences,
    );
    await choiceRepository.saveRecommendations(recommendations);
    await assistantRequestRepository.markRecommendationsReady(request.request_id);
    await save('COMPLETED', recipeName, null);
  } catch (error) {
    console.error(`No se pudo procesar la petición ${request.request_id}:`, error);
    const aiError = error instanceof AiServiceError ? error : null;
    await save(
      aiError?.rejected ? 'REJECTED' : 'FAILED',
      recipeName,
      aiError?.userMessage ??
        'El asistente no pudo procesar tu petición. Inténtalo de nuevo.',
    ).catch((saveError: unknown) => {
      console.error(
        `No se pudo guardar el error de la petición ${request.request_id}:`,
        saveError,
      );
    });
  }
}
