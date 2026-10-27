import type { RequestHandler } from 'express';

import * as assistantService from '../services/assistant-service.js';

export const createRequest: RequestHandler = async (request, response) => {
  const assistantRequest = await assistantService.submitRequest(
    request.get('authorization'),
    request.body,
  );
  response.status(201).json({ data: assistantRequest });
};
