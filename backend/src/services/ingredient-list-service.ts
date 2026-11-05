import { HttpError } from '../middlewares/http-error.js';
import type { AssistantRequest } from '../models/assistant-request.js';
import type {
  IngredientAvailabilityList,
  IdentifiedIngredient,
  ShoppingList,
} from '../models/shopping-list.js';
import * as assistantRequestRepository from '../repositories/assistant-request-repository.js';
import * as branchRepository from '../repositories/branch-repository.js';
import * as ingredientRepository from '../repositories/ingredient-repository.js';
import * as shoppingListRepository from '../repositories/shopping-list-repository.js';
import { getIdentity } from './auth-service.js';
import { buildIngredientAvailability } from './ingredient-availability.js';
import {
  buildIngredientList,
  normalizeIngredientName,
  parseIdentifiedIngredients,
} from './ingredient-list.js';

async function findOwnRequest(
  userId: number,
  requestId: number,
): Promise<AssistantRequest> {
  const request = await assistantRequestRepository.findById(requestId);
  if (!request || request.user_id !== userId) {
    throw new HttpError(404, 'Petición no encontrada.');
  }
  return request;
}

/**
 * Genera la lista estructurada a partir de los ingredientes identificados,
 * relaciona cada uno con el catálogo y la deja guardada para la sucursal de la
 * petición, lista para consultar el inventario. El paso de identificación con
 * IA debe llamar a esta función cuando exista.
 */
export async function generateIngredientList(
  request: AssistantRequest,
  identified: IdentifiedIngredient[],
): Promise<ShoppingList> {
  if (request.branch_id === null) {
    throw new HttpError(409, 'La petición no tiene una sucursal seleccionada.');
  }

  const entries = buildIngredientList(identified);
  const catalog = await ingredientRepository.findByNames(
    entries.map((entry) => entry.normalized_name),
  );
  const ingredientIds = new Map(
    catalog.map((ingredient) => [
      normalizeIngredientName(ingredient.name),
      ingredient.ingredient_id,
    ]),
  );

  return shoppingListRepository.saveForRequest({
    userId: request.user_id,
    branchId: request.branch_id,
    requestId: request.request_id,
    items: entries.map((entry) => ({
      ...entry,
      ingredient_id: ingredientIds.get(entry.normalized_name) ?? null,
    })),
  });
}

/** Recibe la salida del paso de identificación para una petición del usuario. */
export async function saveIdentifiedIngredients(
  authorization: string | undefined,
  requestId: number,
  body: unknown,
): Promise<ShoppingList> {
  const identity = getIdentity(authorization);
  const identified = parseIdentifiedIngredients(body);
  const request = await findOwnRequest(identity.userId, requestId);
  return generateIngredientList(request, identified);
}

export async function getIngredientList(
  authorization: string | undefined,
  requestId: number,
): Promise<ShoppingList> {
  const identity = getIdentity(authorization);
  await findOwnRequest(identity.userId, requestId);
  const list = await shoppingListRepository.findByRequest(requestId);
  if (!list) {
    throw new HttpError(404, 'La petición todavía no tiene lista de ingredientes.');
  }
  return list;
}

/**
 * Compara la lista con el inventario de la sucursal de la petición (HU-18),
 * arma el recorrido con lo disponible (HU-20) y deja registrado lo que falta
 * para informar al usuario (HU-21).
 */
export async function getIngredientAvailability(
  authorization: string | undefined,
  requestId: number,
): Promise<IngredientAvailabilityList> {
  const identity = getIdentity(authorization);
  const request = await findOwnRequest(identity.userId, requestId);
  if (request.branch_id === null) {
    throw new HttpError(409, 'La petición no tiene una sucursal seleccionada.');
  }

  const list = await shoppingListRepository.findByRequest(requestId);
  if (!list) {
    throw new HttpError(404, 'La petición todavía no tiene lista de ingredientes.');
  }

  const ingredientIds = [
    ...new Set(
      list.items.flatMap((item) =>
        item.ingredient_id === null ? [] : [item.ingredient_id],
      ),
    ),
  ];
  const substitutions = await ingredientRepository.findSubstitutions(ingredientIds);
  const [products, branches] = await Promise.all([
    ingredientRepository.findAvailableProducts([
      ...ingredientIds,
      ...substitutions.map((substitution) => substitution.substitute_ingredient_id),
    ]),
    branchRepository.findActive(),
  ]);

  const { items, routes } = buildIngredientAvailability({
    items: list.items,
    branchId: list.branch_id,
    branches,
    products,
    substitutions,
  });
  await shoppingListRepository.saveAvailability(items);

  return {
    ...list,
    branch_name:
      branches.find((branch) => branch.branch_id === list.branch_id)?.name ?? null,
    items,
    routes,
  };
}
