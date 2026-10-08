import type { RequestHandler } from 'express';

import * as authService from '../services/auth-service.js';

export const login: RequestHandler = async (request, response) => {
  response.json({ data: await authService.login(request.body) });
};

export const currentUser: RequestHandler = (request, response) => {
  response.json({
    data: authService.getIdentity(request.get('authorization')),
  });
};
