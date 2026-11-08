import { HttpError } from '../middlewares/http-error.js';

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export interface ProfileUpdate {
  name?: string;
  last_name?: string;
  email?: string;
}

export interface PasswordChange {
  current_password: string;
  new_password: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function rejectUnexpected(body: Record<string, unknown>, allowed: string[]): void {
  const unexpected = Object.keys(body).find((field) => !allowed.includes(field));
  if (unexpected) {
    throw new HttpError(400, `El campo ${unexpected} no se puede cambiar desde el perfil.`);
  }
}

function readText(
  body: Record<string, unknown>,
  field: string,
  label: string,
  maxLength: number,
): string | undefined {
  const value = body[field];
  if (value === undefined) return undefined;
  if (typeof value !== 'string') throw new HttpError(400, `${label} debe ser texto.`);
  const text = value.trim();
  if (!text) throw new HttpError(400, `${label} no puede estar vacío.`);
  if (text.length > maxLength) {
    throw new HttpError(400, `${label} no puede superar ${maxLength} caracteres.`);
  }
  return text;
}

/** Datos que el usuario puede cambiar de sí mismo: nombre, apellido y correo. */
export function parseProfileUpdate(body: unknown): ProfileUpdate {
  if (!isRecord(body)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }
  rejectUnexpected(body, ['name', 'last_name', 'email']);
  const update: ProfileUpdate = {};
  const name = readText(body, 'name', 'El nombre', 100);
  const lastName = readText(body, 'last_name', 'El apellido', 100);
  const email = readText(body, 'email', 'El correo', 255);
  if (name !== undefined) update.name = name;
  if (lastName !== undefined) update.last_name = lastName;
  if (email !== undefined) {
    if (!emailPattern.test(email)) {
      throw new HttpError(400, 'El correo debe tener un formato válido.');
    }
    update.email = email.toLowerCase();
  }
  if (Object.keys(update).length === 0) {
    throw new HttpError(400, 'Indica al menos un dato para actualizar.');
  }
  return update;
}

/** Cambio de contraseña: siempre pide la actual. */
export function parsePasswordChange(body: unknown): PasswordChange {
  if (!isRecord(body)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }
  rejectUnexpected(body, ['current_password', 'new_password']);
  const current = body.current_password;
  const next = body.new_password;
  if (typeof current !== 'string' || !current) {
    throw new HttpError(400, 'Ingresa tu contraseña actual.');
  }
  if (typeof next !== 'string' || next.length < 8) {
    throw new HttpError(400, 'La nueva contraseña debe tener al menos 8 caracteres.');
  }
  if (
    Buffer.byteLength(current, 'utf8') > 1024 ||
    Buffer.byteLength(next, 'utf8') > 1024
  ) {
    throw new HttpError(400, 'La contraseña no puede superar 1024 bytes.');
  }
  if (current === next) {
    throw new HttpError(400, 'La nueva contraseña debe ser distinta de la actual.');
  }
  return { current_password: current, new_password: next };
}
