import { HttpError } from '../middlewares/http-error.js';
import type { User } from '../models/user.js';
import * as userRepository from '../repositories/user-repository.js';
import { hashPassword, verifyPassword } from './password-hasher.js';
import { parsePasswordChange, parseProfileUpdate } from './profile-input.js';

async function activeUser(userId: number): Promise<User> {
  const user = await userRepository.findById(userId);
  // Un token sigue siendo válido tras desactivar al usuario.
  if (!user?.status) throw new HttpError(401, 'Token inválido o expirado.');
  return user;
}

export async function getProfile(userId: number): Promise<User> {
  return activeUser(userId);
}

export async function updateProfile(userId: number, body: unknown): Promise<User> {
  const update = parseProfileUpdate(body);
  await activeUser(userId);
  const user = await userRepository.updateOwn(userId, update);
  if (!user) throw new HttpError(404, 'Usuario no encontrado.');
  return user;
}

export async function changePassword(userId: number, body: unknown): Promise<void> {
  const change = parsePasswordChange(body);
  await activeUser(userId);
  const hash = await userRepository.findPasswordHash(userId);
  if (!hash || !(await verifyPassword(change.current_password, hash))) {
    throw new HttpError(400, 'La contraseña actual no es correcta.');
  }
  await userRepository.updateOwn(userId, {
    passwordHash: await hashPassword(change.new_password),
  });
}
