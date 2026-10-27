import { Router } from 'express';

import { assistantRouter } from './assistant.js';
import { authRouter } from './auth.js';
import { usersRouter } from './users.js';

export const apiRouter = Router();

apiRouter.use('/assistant', assistantRouter);
apiRouter.use('/auth', authRouter);
apiRouter.use('/users', usersRouter);
