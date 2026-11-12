import { AiServiceError } from './ai-error.js';
import type { GenerateJsonInput } from './ai-provider.js';

const timeoutMs = 600_000;
let processing = false;

function jsonSchema(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(jsonSchema);
  if (typeof value !== 'object' || value === null) return value;
  const schema = value as Record<string, unknown>;
  const result: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(schema)) {
    if (key === 'nullable') continue;
    if (key === 'type' && typeof entry === 'string') {
      const type = entry.toLowerCase();
      result.type = schema.nullable === true ? [type, 'null'] : type;
    } else {
      result[key] = jsonSchema(entry);
    }
  }
  if (schema.nullable === true && Array.isArray(result.enum)) {
    result.enum = [...result.enum, null];
  }
  return result;
}

export async function generateOllamaJson(
  input: GenerateJsonInput,
  fetchImpl: typeof fetch = fetch,
  selectedModel?: string,
): Promise<unknown> {
  if (processing) {
    throw new AiServiceError(
      'Ollama ya está procesando otra petición.',
      'El modelo local está ocupado. Espera a que termine e inténtalo de nuevo.',
    );
  }
  processing = true;
  try {
    return await requestOllamaJson(input, fetchImpl, selectedModel);
  } finally {
    processing = false;
  }
}

async function requestOllamaJson(
  input: GenerateJsonInput,
  fetchImpl: typeof fetch,
  selectedModel?: string,
): Promise<unknown> {
  const model = selectedModel ?? process.env.OLLAMA_MODEL?.trim();
  if (!model) {
    throw new AiServiceError('OLLAMA_MODEL no está configurado.');
  }
  const baseUrl = process.env.OLLAMA_BASE_URL?.trim() || 'http://127.0.0.1:11434';
  let response: Response;
  try {
    response = await fetchImpl(`${baseUrl.replace(/\/+$/, '')}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        stream: false,
        think: false,
        format: jsonSchema(input.responseSchema),
        messages: [
          { role: 'system', content: input.systemInstruction },
          { role: 'user', content: input.userText },
        ],
        options: { temperature: 0.2, num_predict: 4096 },
      }),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    if (error instanceof Error && (error.name === 'TimeoutError' || error.name === 'AbortError')) {
      throw new AiServiceError(
        'Ollama superó el tiempo máximo de generación.',
        'El modelo local tardó demasiado. Intenta nuevamente o elige otro modelo.',
      );
    }
    throw new AiServiceError(
      `No se pudo conectar con Ollama: ${error instanceof Error ? error.message : String(error)}`,
      'No se pudo conectar con el modelo local. Verifica que Ollama esté activo.',
    );
  }
  if (!response.ok) {
    const body = await response.text();
    throw new AiServiceError(
      `Ollama respondió ${response.status}: ${body.slice(0, 300)}`,
      'El modelo local no está disponible. Verifica la configuración de Ollama.',
    );
  }
  let data: unknown;
  try {
    data = await response.json();
  } catch {
    throw new AiServiceError('Ollama devolvió una respuesta HTTP que no es JSON.');
  }
  if (typeof data !== 'object' || data === null || !('message' in data)) {
    throw new AiServiceError('Ollama no devolvió un mensaje.');
  }
  if ('done_reason' in data && data.done_reason === 'length') {
    throw new AiServiceError('Ollama agotó el límite de salida antes de completar la respuesta.');
  }
  const message: unknown = data.message;
  if (typeof message !== 'object' || message === null || !('content' in message) ||
      typeof message.content !== 'string') {
    throw new AiServiceError('Ollama no devolvió contenido de texto.');
  }
  try {
    return JSON.parse(message.content);
  } catch {
    throw new AiServiceError('Ollama devolvió contenido JSON inválido.');
  }
}
