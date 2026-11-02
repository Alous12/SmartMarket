import { Router } from 'express';

import {
  createRequest,
  getIngredientAvailability,
  getIngredients,
  saveIngredients,
} from '../controllers/assistant-controller.js';

export const assistantRouter = Router();

assistantRouter.post('/requests', createRequest);
assistantRouter.put('/requests/:requestId/ingredients', saveIngredients);
assistantRouter.get('/requests/:requestId/ingredients', getIngredients);
assistantRouter.get(
  '/requests/:requestId/ingredients/availability',
  getIngredientAvailability,
);
