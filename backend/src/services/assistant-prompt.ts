import { HttpError } from '../middlewares/http-error.js';

// Límite de la columna TEXT de MySQL.
export const maxPromptBytes = 65535;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Valida el cuerpo de la petición y devuelve el texto exactamente como lo
 * escribió el usuario, sin recortar ni normalizar.
 */
export function parseAssistantPrompt(body: unknown): string {
  if (!isRecord(body)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }
  const unexpectedField = Object.keys(body).find((field) => field !== 'prompt');
  if (unexpectedField) {
    throw new HttpError(400, `El campo ${unexpectedField} no está permitido.`);
  }
  if (typeof body.prompt !== 'string' || !body.prompt.trim()) {
    throw new HttpError(400, 'prompt es obligatorio y no puede estar vacío.');
  }
  if (Buffer.byteLength(body.prompt, 'utf8') > maxPromptBytes) {
    throw new HttpError(400, `prompt no puede superar ${maxPromptBytes} bytes.`);
  }
  return body.prompt;
}
