import type { RequestHandler } from 'express';

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
