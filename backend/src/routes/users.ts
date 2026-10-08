import { Router } from 'express';

import {
  createUser,
  deactivateUser,
  getUser,
  listUsers,
  updateUser,
} from '../controllers/user-controller.js';

export const usersRouter = Router();

usersRouter.get('/', listUsers);
usersRouter.get('/:userId', getUser);
usersRouter.post('/', createUser);
usersRouter.patch('/:userId', updateUser);
usersRouter.delete('/:userId', deactivateUser);
