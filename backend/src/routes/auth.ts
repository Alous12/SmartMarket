import { Router } from 'express';

import { currentUser, login } from '../controllers/auth-controller.js';

export const authRouter = Router();

authRouter.post('/login', login);
authRouter.get('/me', currentUser);
