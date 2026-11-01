import type { RequestHandler, Response } from 'express';

import type { UserRole } from '../models/user.js';
import { getIdentity } from '../services/auth-service.js';
import { HttpError } from './http-error.js';

export interface Identity {
  userId: number;
  username: string;
  role: UserRole;
}

export const authenticate: RequestHandler = (request, response, next) => {
  try {
    response.locals.identity = getIdentity(request.get('authorization'));
    next();
  } catch (error) {
    next(error);
  }
};

export function requireRole(...roles: UserRole[]): RequestHandler {
  return (_request, response, next) => {
    const identity = response.locals.identity as Identity | undefined;
    if (!identity) {
      next(new HttpError(401, 'Se requiere un token de acceso.'));
    } else if (!roles.includes(identity.role)) {
      next(new HttpError(403, 'No tienes permisos para realizar esta acción.'));
    } else {
      next();
    }
  };
}

export function identityOf(response: Response): Identity {
  return response.locals.identity as Identity;
}

export const requireAdmin: RequestHandler[] = [
  authenticate,
  requireRole('admin'),
];
