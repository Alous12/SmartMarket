import type { ErrorRequestHandler } from 'express';

import { HttpError } from './http-error.js';

export const errorHandler: ErrorRequestHandler = (
  error: unknown,
  _request,
  response,
  _next,
) => {
  if (error instanceof HttpError) {
    response.status(error.statusCode).json({ error: error.message });
    return;
  }

  if (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    error.code === 'ER_DUP_ENTRY'
  ) {
    response.status(409).json({ error: 'El correo electrónico ya está registrado.' });
    return;
  }

  if (
    typeof error === 'object' &&
    error !== null &&
    'status' in error &&
    error.status === 400
  ) {
    response.status(400).json({ error: 'La solicitud contiene JSON inválido.' });
    return;
  }

  console.error('Error inesperado en la API:', error);
  response.status(500).json({ error: 'Ocurrió un error interno.' });
};
