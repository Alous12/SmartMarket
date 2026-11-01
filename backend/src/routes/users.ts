import { Router } from 'express';

import {
  createUser,
  deactivateUser,
  getUser,
  listUsers,
  updateUser,
} from '../controllers/user-controller.js';
import { requireAdmin } from '../middlewares/auth.js';

export const usersRouter = Router();

// El registro de clientes es público; el resto de la gestión es solo para trabajadores.
usersRouter.post('/', createUser);
usersRouter.get('/', ...requireAdmin, listUsers);
usersRouter.get('/:userId', ...requireAdmin, getUser);
usersRouter.patch('/:userId', ...requireAdmin, updateUser);
usersRouter.delete('/:userId', ...requireAdmin, deactivateUser);
