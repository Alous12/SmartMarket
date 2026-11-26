import type { RequestHandler } from 'express';

import { identityOf } from '../middlewares/auth.js';
import * as settingsService from '../services/assistant-settings-service.js';

export const getOwnAssistantSettings: RequestHandler = async (_request, response) => {
  response.json({ data: await settingsService.getSettings(identityOf(response).userId) });
};

export const updateOwnAssistantSettings: RequestHandler = async (request, response) => {
  const userId = identityOf(response).userId;
  response.json({ data: await settingsService.updateSettings(userId, request.body) });
};
