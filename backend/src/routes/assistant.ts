import { Router } from 'express';

import {
  createRequest,
  getIngredients,
  saveIngredients,
} from '../controllers/assistant-controller.js';

export const assistantRouter = Router();

assistantRouter.post('/requests', createRequest);
assistantRouter.put('/requests/:requestId/ingredients', saveIngredients);
assistantRouter.get('/requests/:requestId/ingredients', getIngredients);
