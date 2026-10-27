import { Router } from 'express';

import { createRequest } from '../controllers/assistant-controller.js';

export const assistantRouter = Router();

assistantRouter.post('/requests', createRequest);
