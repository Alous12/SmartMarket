import { HttpError } from '../middlewares/http-error.js';
import type { AssistantRequest } from '../models/assistant-request.js';
import * as assistantRequestRepository from '../repositories/assistant-request-repository.js';
import * as branchRepository from '../repositories/branch-repository.js';
import { parseAssistantRequest } from './assistant-prompt.js';
import { getIdentity } from './auth-service.js';

/**
 * Recibe la petición del usuario, la guarda tal cual junto con la sucursal
 * seleccionada e inicia su procesamiento.
 */
export async function submitRequest(
  authorization: string | undefined,
  body: unknown,
): Promise<AssistantRequest> {
  const identity = getIdentity(authorization);
  const { prompt, branchId } = parseAssistantRequest(body);
  if (branchId !== null && !(await branchRepository.isActive(branchId))) {
    throw new HttpError(400, 'branch_id no corresponde a una sucursal activa.');
  }
  const received = await assistantRequestRepository.create({
    userId: identity.userId,
    branchId,
    prompt,
  });
  return startProcessing(received);
}

/**
 * Marca la petición como en procesamiento para que el sistema de IA la tome.
 * La identificación del contenido (plato, productos, cantidades) se conecta
 * aquí cuando exista el modelo de IA; sus ingredientes se entregan a
 * ingredient-list-service.generateIngredientList.
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
