import { Router } from 'express';

import { assistantRouter } from './assistant.js';
import { authRouter } from './auth.js';
import { catalogRouter } from './catalog.js';
import { productsRouter } from './products.js';
import { usersRouter } from './users.js';

export const apiRouter = Router();

apiRouter.use('/assistant', assistantRouter);
apiRouter.use('/auth', authRouter);
apiRouter.use('/', catalogRouter);
apiRouter.use('/products', productsRouter);
apiRouter.use('/users', usersRouter);
