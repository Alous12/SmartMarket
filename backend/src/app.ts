import express from 'express';

import { errorHandler } from './middlewares/error-handler.js';
import { HttpError } from './middlewares/http-error.js';
import { apiRouter } from './routes/index.js';

export const app = express();

app.use(express.json());
app.use('/api', apiRouter);
app.use((_request, _response, next) => {
  next(new HttpError(404, 'Ruta no encontrada.'));
});
app.use(errorHandler);
