import { HttpError } from '../middlewares/http-error.js';

// Límite de la columna TEXT de MySQL.
export const maxPromptBytes = 65535;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isPositiveId(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0;
}

/**
 * Valida el cuerpo de la petición y devuelve el texto exactamente como lo
 * escribió el usuario, sin recortar ni normalizar, junto con la sucursal
 * seleccionada (opcional).
 */
export function parseAssistantRequest(body: unknown): {
  prompt: string;
  branchId: number | null;
  modelId?: string;
} {
  if (!isRecord(body)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }
  const unexpectedField = Object.keys(body).find(
    (field) => field !== 'prompt' && field !== 'branch_id' && field !== 'model_id',
  );
  if (unexpectedField) {
    throw new HttpError(400, `El campo ${unexpectedField} no está permitido.`);
  }
  if (typeof body.prompt !== 'string' || !body.prompt.trim()) {
    throw new HttpError(400, 'prompt es obligatorio y no puede estar vacío.');
  }
  if (Buffer.byteLength(body.prompt, 'utf8') > maxPromptBytes) {
    throw new HttpError(400, `prompt no puede superar ${maxPromptBytes} bytes.`);
  }
  if (body.model_id !== undefined &&
      (typeof body.model_id !== 'string' || !body.model_id.trim())) {
    throw new HttpError(400, 'model_id debe ser un identificador de modelo.');
  }
  const modelId = typeof body.model_id === 'string' ? body.model_id : undefined;
  if (body.branch_id === undefined) {
    return { prompt: body.prompt, branchId: null, ...(modelId === undefined ? {} : { modelId }) };
  }
  if (!isPositiveId(body.branch_id)) {
    throw new HttpError(400, 'branch_id debe ser un entero positivo.');
  }
  return { prompt: body.prompt, branchId: body.branch_id, ...(modelId === undefined ? {} : { modelId }) };
}

export function parseRequestId(value: string | string[]): number {
  const requestId = typeof value === 'string' ? Number(value) : Number.NaN;
  if (!isPositiveId(requestId)) {
    throw new HttpError(400, 'El id de la petición debe ser un entero positivo.');
  }
  return requestId;
}
