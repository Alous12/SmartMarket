import { HttpError } from '../middlewares/http-error.js';
import * as userRepository from '../repositories/user-repository.js';
import type { UserRole } from '../models/user.js';
import { createAuthToken, verifyAuthToken } from './auth-token.js';
import { verifyPassword } from './password-hasher.js';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function login(body: unknown): Promise<{
  token: string;
  username: string;
  role: UserRole;
}> {
  if (!isRecord(body)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }
  const unexpectedField = Object.keys(body).find(
    (field) => field !== 'email' && field !== 'password',
  );
  if (unexpectedField) {
    throw new HttpError(400, `El campo ${unexpectedField} no está permitido.`);
  }
  if (typeof body.email !== 'string' || !body.email.trim()) {
    throw new HttpError(400, 'email y password son obligatorios.');
  }

  const email = body.email.trim().toLowerCase();
  if (email.length > 255 || !emailPattern.test(email)) {
    throw new HttpError(400, 'email debe tener un formato válido.');
  }
  if (typeof body.password !== 'string' || !body.password) {
    throw new HttpError(400, 'email y password son obligatorios.');
  }
  if (Buffer.byteLength(body.password, 'utf8') > 1024) {
    throw new HttpError(400, 'password no puede superar 1024 bytes.');
  }

  const user = await userRepository.findCredentialsByEmail(email);
  if (
    !user ||
    !user.status ||
    !(await verifyPassword(body.password, user.password_hash))
  ) {
    throw new HttpError(401, 'Correo o contraseña incorrectos.');
  }

  return {
    token: createAuthToken({ username: user.name, role: user.role }),
    username: user.name,
    role: user.role,
  };
}

export function getIdentity(authorization: string | undefined): {
  username: string;
  role: UserRole;
} {
  if (!authorization?.startsWith('Bearer ')) {
    throw new HttpError(401, 'Se requiere un token de acceso.');
  }
  return verifyAuthToken(authorization.slice('Bearer '.length));
}
