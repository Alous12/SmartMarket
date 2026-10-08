import { HttpError } from '../middlewares/http-error.js';
import type { CreateUserInput, UpdateUserInput, User } from '../models/user.js';
import * as userRepository from '../repositories/user-repository.js';
import { hashPassword } from './password-hasher.js';

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function readText(
  body: Record<string, unknown>,
  field: string,
  maxLength: number,
  required: boolean,
): string | undefined {
  const value = body[field];
  if (value === undefined && !required) {
    return undefined;
  }
  if (typeof value !== 'string') {
    throw new HttpError(400, `${field} debe ser texto.`);
  }

  const text = value.trim();
  if (!text) {
    throw new HttpError(
      400,
      required ? `${field} es obligatorio.` : `${field} no puede estar vacío.`,
    );
  }
  if (text.length > maxLength) {
    throw new HttpError(400, `${field} no puede superar ${maxLength} caracteres.`);
  }
  return text;
}

function readEmail(
  body: Record<string, unknown>,
  required: boolean,
): string | undefined {
  const email = readText(body, 'email', 255, required);
  if (email !== undefined && !emailPattern.test(email)) {
    throw new HttpError(400, 'email debe tener un formato válido.');
  }
  return email?.toLowerCase();
}

function readPassword(
  body: Record<string, unknown>,
  required: boolean,
): string | undefined {
  const password = body.password;
  if (password === undefined && !required) {
    return undefined;
  }
  if (typeof password !== 'string' || password.length < 8) {
    throw new HttpError(400, 'password debe tener al menos 8 caracteres.');
  }
  if (Buffer.byteLength(password, 'utf8') > 1024) {
    throw new HttpError(400, 'password no puede superar 1024 bytes.');
  }
  return password;
}

function parseCreateInput(body: unknown): CreateUserInput {
  if (!isRecord(body)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }

  rejectUnexpectedFields(body, ['name', 'last_name', 'email', 'password']);
  return {
    name: readText(body, 'name', 100, true)!,
    last_name: readText(body, 'last_name', 100, true)!,
    email: readEmail(body, true)!,
    password: readPassword(body, true)!,
  };
}

function parseUpdateInput(body: unknown): UpdateUserInput {
  if (!isRecord(body)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }

  rejectUnexpectedFields(body, [
    'name',
    'last_name',
    'email',
    'password',
    'status',
  ]);
  const input: UpdateUserInput = {};
  const name = readText(body, 'name', 100, false);
  const lastName = readText(body, 'last_name', 100, false);
  const email = readEmail(body, false);
  const password = readPassword(body, false);

  if (name !== undefined) input.name = name;
  if (lastName !== undefined) input.last_name = lastName;
  if (email !== undefined) input.email = email;
  if (password !== undefined) input.password = password;

  if (body.status !== undefined) {
    if (typeof body.status !== 'boolean') {
      throw new HttpError(400, 'status debe ser true o false.');
    }
    input.status = body.status;
  }

  if (Object.keys(input).length === 0) {
    throw new HttpError(400, 'Indica al menos un campo válido para actualizar.');
  }
  return input;
}

function rejectUnexpectedFields(
  body: Record<string, unknown>,
  allowedFields: string[],
): void {
  const unexpectedField = Object.keys(body).find(
    (field) => !allowedFields.includes(field),
  );
  if (unexpectedField) {
    throw new HttpError(
      400,
      `El campo ${unexpectedField} no se puede asignar mediante esta API.`,
    );
  }
}

function parseNumericUserId(value: string): number {
  const userId = Number(value);
  if (!Number.isSafeInteger(userId) || userId < 1) {
    throw new HttpError(400, 'El id de usuario debe ser un entero positivo.');
  }
  return userId;
}

export function parseUserId(value: string | string[]): number {
  if (typeof value !== 'string') {
    throw new HttpError(400, 'El id de usuario debe ser un entero positivo.');
  }
  return parseNumericUserId(value);
}

export async function listUsers(): Promise<User[]> {
  return userRepository.findAll();
}

export async function getUser(userId: number): Promise<User> {
  const user = await userRepository.findById(userId);
  if (!user) {
    throw new HttpError(404, 'Usuario no encontrado.');
  }
  return user;
}

export async function createUser(body: unknown): Promise<User> {
  const input = parseCreateInput(body);
  return userRepository.create({
    name: input.name,
    lastName: input.last_name,
    email: input.email,
    passwordHash: await hashPassword(input.password),
  });
}

export async function updateUser(userId: number, body: unknown): Promise<User> {
  const input = parseUpdateInput(body);
  const { password, ...fields } = input;
  const updated = await userRepository.update(userId, {
    ...fields,
    ...(password === undefined
      ? {}
      : { passwordHash: await hashPassword(password) }),
  });
  if (!updated) {
    throw new HttpError(404, 'Usuario no encontrado.');
  }
  return updated;
}

export async function deactivateUser(userId: number): Promise<void> {
  const deactivated = await userRepository.deactivate(userId);
  if (!deactivated) {
    const user = await userRepository.findById(userId);
    if (!user) {
      throw new HttpError(404, 'Usuario no encontrado.');
    }
  }
}
