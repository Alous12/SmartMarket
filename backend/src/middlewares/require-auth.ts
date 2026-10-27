import type { RequestHandler } from 'express';

import { getIdentity } from '../services/auth-service.js';

/** Exige un token Bearer válido; lanza 401 si falta o es inválido. */
export const requireAuth: RequestHandler = (request, _response, next) => {
  getIdentity(request.get('authorization'));
  next();
};
