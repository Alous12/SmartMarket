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
