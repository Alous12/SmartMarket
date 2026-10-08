import { Router } from 'express';

import { usersRouter } from './users.js';

export const apiRouter = Router();

apiRouter.use('/users', usersRouter);
