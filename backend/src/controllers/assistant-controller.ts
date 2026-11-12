import type { RequestHandler } from 'express';

import { parseRequestId } from '../services/assistant-prompt.js';
import * as assistantService from '../services/assistant-service.js';
import * as ingredientListService from '../services/ingredient-list-service.js';

export const createRequest: RequestHandler = async (request, response) => {
  const assistantRequest = await assistantService.submitRequest(
    request.get('authorization'),
    request.body,
  );
  response.status(201).json({ data: assistantRequest });
};

export const listModels: RequestHandler = (request, response) => {
  response.json({ data: assistantService.listModels(request.get('authorization')) });
};

export const listRecipeHistory: RequestHandler = async (request, response) => {
  const history = await assistantService.listRecipeHistory(
    request.get('authorization'),
  );
  response.json({ data: history });
};

export const getRequest: RequestHandler = async (request, response) => {
  const assistantRequest = await assistantService.getRequest(
    request.get('authorization'),
    parseRequestId(request.params.requestId),
  );
  response.json({ data: assistantRequest });
};

export const saveIngredients: RequestHandler = async (request, response) => {
  const list = await ingredientListService.saveIdentifiedIngredients(
    request.get('authorization'),
    parseRequestId(request.params.requestId),
    request.body,
  );
  response.json({ data: list });
};

export const getIngredients: RequestHandler = async (request, response) => {
  const list = await ingredientListService.getIngredientList(
    request.get('authorization'),
    parseRequestId(request.params.requestId),
  );
  response.json({ data: list });
};

export const getIngredientAvailability: RequestHandler = async (
  request,
  response,
) => {
  const availability = await ingredientListService.getIngredientAvailability(
    request.get('authorization'),
    parseRequestId(request.params.requestId),
  );
  response.json({ data: availability });
};

export const selectProduct: RequestHandler = async (request, response) => {
  const availability = await ingredientListService.selectProduct(
    request.get('authorization'),
    parseRequestId(request.params.requestId),
    parseRequestId(request.params.itemId),
    request.body,
  );
  response.json({ data: availability });
};
