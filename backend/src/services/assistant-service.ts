import type { AssistantRequest } from '../models/assistant-request.js';
import * as assistantRequestRepository from '../repositories/assistant-request-repository.js';
import { parseAssistantPrompt } from './assistant-prompt.js';
import { getIdentity } from './auth-service.js';

/** Recibe la petición del usuario, la guarda tal cual e inicia su procesamiento. */
export async function submitRequest(
  authorization: string | undefined,
  body: unknown,
): Promise<AssistantRequest> {
  const identity = getIdentity(authorization);
  const prompt = parseAssistantPrompt(body);
  const received = await assistantRequestRepository.create({
    userId: identity.userId,
    prompt,
  });
  return startProcessing(received);
}

/**
 * Marca la petición como en procesamiento para que el sistema de IA la tome.
 * La identificación del contenido (plato, productos, cantidades) se conecta
 * aquí cuando exista el modelo de IA.
 */
async function startProcessing(
  request: AssistantRequest,
): Promise<AssistantRequest> {
  const processing = await assistantRequestRepository.updateStatus(
    request.request_id,
    'PROCESSING',
  );
  if (!processing) {
    throw new Error('No se pudo iniciar el procesamiento de la petición.');
  }
  return processing;
}
