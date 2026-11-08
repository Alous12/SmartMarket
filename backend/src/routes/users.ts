import { Router } from 'express';

import {
  changeOwnPassword,
  createUser,
  deactivateUser,
  getOwnProfile,
  getUser,
  listUsers,
  updateOwnProfile,
  updateUser,
} from '../controllers/user-controller.js';
import { authenticate, requireAdmin } from '../middlewares/auth.js';

export const usersRouter = Router();

// El registro de clientes es público; el resto de la gestión es solo para trabajadores.
usersRouter.post('/', createUser);
// Perfil: cada usuario (cliente o trabajador) ve y edita sus propios datos.
// Va antes de /:userId para que "me" no se lea como un id.
usersRouter.get('/me', authenticate, getOwnProfile);
usersRouter.patch('/me', authenticate, updateOwnProfile);
usersRouter.put('/me/password', authenticate, changeOwnPassword);
usersRouter.get('/', ...requireAdmin, listUsers);
usersRouter.get('/:userId', ...requireAdmin, getUser);
usersRouter.patch('/:userId', ...requireAdmin, updateUser);
usersRouter.delete('/:userId', ...requireAdmin, deactivateUser);
