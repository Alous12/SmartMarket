import { Router } from 'express';

import {
  createRequest,
  getIngredientAvailability,
  getIngredients,
  getRequest,
  listRecipeHistory,
  listModels,
  saveIngredients,
  selectProduct,
  setIngredientExcluded,
} from '../controllers/assistant-controller.js';

export const assistantRouter = Router();

assistantRouter.get('/models', listModels);
assistantRouter.post('/requests', createRequest);
assistantRouter.get('/requests', listRecipeHistory);
assistantRouter.get('/requests/:requestId', getRequest);
assistantRouter.put('/requests/:requestId/ingredients', saveIngredients);
assistantRouter.get('/requests/:requestId/ingredients', getIngredients);
assistantRouter.get(
  '/requests/:requestId/ingredients/availability',
  getIngredientAvailability,
);
assistantRouter.put('/requests/:requestId/ingredients/:itemId/product', selectProduct);
assistantRouter.put('/requests/:requestId/ingredients/:itemId/exclusion', setIngredientExcluded);
