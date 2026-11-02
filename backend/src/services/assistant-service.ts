import { HttpError } from '../middlewares/http-error.js';
import type {
  AssistantRequest,
  AssistantRequestDetail,
  AssistantRequestStatus,
} from '../models/assistant-request.js';
import * as assistantRequestRepository from '../repositories/assistant-request-repository.js';
import * as branchRepository from '../repositories/branch-repository.js';
import * as ingredientRepository from '../repositories/ingredient-repository.js';
import * as shoppingListRepository from '../repositories/shopping-list-repository.js';
import { AiServiceError } from './ai/ai-error.js';
import { generateJson } from './ai/gemini-provider.js';
import {
  buildRecipeInstruction,
  maxAnalyzedPromptLength,
  parseRecipeAnalysis,
  recipeResponseSchema,
  type RecipeAnalysis,
} from './ai/recipe-analysis.js';
import { parseAssistantRequest } from './assistant-prompt.js';
import { getIdentity } from './auth-service.js';
import { generateIngredientList } from './ingredient-list-service.js';

/**
 * Recibe la petición del usuario, la guarda tal cual junto con la sucursal
 * seleccionada e inicia su procesamiento.
 */
export async function submitRequest(
  authorization: string | undefined,
  body: unknown,
): Promise<AssistantRequest> {
  const identity = getIdentity(authorization);
  const { prompt, branchId } = parseAssistantRequest(body);
  if (branchId !== null && !(await branchRepository.isActive(branchId))) {
    throw new HttpError(400, 'branch_id no corresponde a una sucursal activa.');
  }
  const received = await assistantRequestRepository.create({
    userId: identity.userId,
    branchId,
    prompt,
  });
  const processing = await startProcessing(received);
  // La IA tarda unos segundos: se responde de inmediato y la app consulta el
  // resultado con getRequest. processRequest nunca lanza errores.
  void processRequest(processing);
  return processing;
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
async function analyzePrompt(prompt: string): Promise<RecipeAnalysis> {
  if (prompt.length > maxAnalyzedPromptLength) {
    return {
      isRecipe: false,
      message: 'Tu petición es muy larga. Escribe solo el plato que quieres preparar.',
    };
  }
  const catalogNames = await ingredientRepository.findAllNames();
  const output = await generateJson({
    systemInstruction: buildRecipeInstruction(catalogNames),
    userText: prompt,
    responseSchema: recipeResponseSchema,
  });
  return parseRecipeAnalysis(output);
}

/**
 * Procesa la petición en segundo plano y deja el resultado en la base de datos:
 * REJECTED si no es una receta, COMPLETED con la receta y su lista de
 * ingredientes (HU-16), o FAILED con un mensaje para el usuario.
 */
export async function processRequest(request: AssistantRequest): Promise<void> {
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

    const analysis = await analyzePrompt(request.prompt);
    if (!analysis.isRecipe) {
      await save('REJECTED', null, analysis.message);
      return;
    }

    // La receta identificada queda disponible para extraer sus ingredientes.
    recipeName = analysis.recipeName;
    await save('PROCESSING', recipeName, null);
    await generateIngredientList(request, analysis.ingredients);
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
