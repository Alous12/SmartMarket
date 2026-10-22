import { Router } from 'express';

import { authRouter } from './auth.js';
import { usersRouter } from './users.js';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
apiRouter.use('/users', usersRouter);
