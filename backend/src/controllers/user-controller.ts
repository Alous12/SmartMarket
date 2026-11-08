import type { RequestHandler } from 'express';

import { identityOf } from '../middlewares/auth.js';
import * as profileService from '../services/profile-service.js';
import * as userService from '../services/user-service.js';

export const listUsers: RequestHandler = async (_request, response) => {
  response.json({ data: await userService.listUsers() });
};

export const getUser: RequestHandler = async (request, response) => {
  const userId = userService.parseUserId(request.params.userId);
  response.json({ data: await userService.getUser(userId) });
};

export const createUser: RequestHandler = async (request, response) => {
  const user = await userService.createUser(request.body);
  response.status(201).json({ data: user });
};

export const updateUser: RequestHandler = async (request, response) => {
  const userId = userService.parseUserId(request.params.userId);
  response.json({ data: await userService.updateUser(userId, request.body) });
};

export const deactivateUser: RequestHandler = async (request, response) => {
  const userId = userService.parseUserId(request.params.userId);
  await userService.deactivateUser(userId);
  response.status(204).end();
};

export const getOwnProfile: RequestHandler = async (_request, response) => {
  response.json({ data: await profileService.getProfile(identityOf(response).userId) });
};

export const updateOwnProfile: RequestHandler = async (request, response) => {
  const userId = identityOf(response).userId;
  response.json({ data: await profileService.updateProfile(userId, request.body) });
};

export const changeOwnPassword: RequestHandler = async (request, response) => {
  await profileService.changePassword(identityOf(response).userId, request.body);
  response.status(204).end();
};
