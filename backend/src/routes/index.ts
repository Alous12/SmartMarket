import { Router } from 'express';

import { authRouter } from './auth.js';
import { catalogRouter } from './catalog.js';
import { usersRouter } from './users.js';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
apiRouter.use('/', catalogRouter);
apiRouter.use('/users', usersRouter);
