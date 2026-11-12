import { AiServiceError } from './ai-error.js';
import type { GenerateJsonInput } from './ai-provider.js';

const apiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
export const defaultGeminiModel = 'gemini-3.5-flash-lite';
const timeoutMs = 30_000;
/** Espera antes de cada reintento cuando el modelo está saturado (503). */
const retryDelaysMs = [1_000, 2_000];

const notConfiguredMessage =
  'El asistente no está disponible en este momento. Avísale al administrador.';

interface GeminiResponse {
  promptFeedback?: { blockReason?: string };
  candidates?: Array<{
    finishReason?: string;
    content?: { parts?: Array<{ text?: string }> };
  }>;
}

function errorForStatus(status: number, body: string): AiServiceError {
  const detail = `Gemini respondió ${status}: ${body.slice(0, 300)}`;
  if (status === 429) {
    return new AiServiceError(
      detail,
      'El asistente alcanzó su límite de consultas. Inténtalo en unos minutos.',
    );
  }
  if (status === 503) {
    return new AiServiceError(
      detail,
      'Gemini está saturado en este momento. Inténtalo más tarde o elige otro modelo.',
    );
  }
  if (status === 400 || status === 401 || status === 403 || status === 404) {
    // Clave inválida, modelo inexistente o petición mal formada: es configuración.
    return new AiServiceError(detail, notConfiguredMessage);
  }
  return new AiServiceError(detail);
}

/**
 * Llama a Gemini (generateContent) y devuelve su respuesta JSON ya parseada.
 * La clave vive solo en el backend (GEMINI_API_KEY); la app nunca la recibe.
 */
export async function generateJson(
  input: GenerateJsonInput,
  fetchImpl: typeof fetch = fetch,
  retryDelays: number[] = retryDelaysMs,
): Promise<unknown> {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) {
    throw new AiServiceError(
      'GEMINI_API_KEY no está configurada en backend/.env.',
      notConfiguredMessage,
    );
  }
  const model = process.env.GEMINI_MODEL?.trim() || defaultGeminiModel;

  const request = async (): Promise<Response> => {
    try {
      return await fetchImpl(
        `${apiBaseUrl}/models/${encodeURIComponent(model)}:generateContent`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: input.systemInstruction }] },
            contents: [{ role: 'user', parts: [{ text: input.userText }] }],
            generationConfig: {
              temperature: 0.2,
              maxOutputTokens: 4096,
              responseMimeType: 'application/json',
              responseSchema: input.responseSchema,
            },
          }),
          signal: AbortSignal.timeout(timeoutMs),
        },
      );
    } catch (error) {
      if (error instanceof Error && (error.name === 'TimeoutError' || error.name === 'AbortError')) {
        throw new AiServiceError(
          `Gemini superó el tiempo máximo de respuesta: ${error.message}`,
          'Gemini tardó demasiado en responder. Inténtalo de nuevo o elige otro modelo.',
        );
      }
      throw new AiServiceError(
        `No se pudo conectar con Gemini: ${error instanceof Error ? error.message : String(error)}`,
        'No se pudo conectar con Gemini. Verifica tu conexión e inténtalo de nuevo.',
      );
    }
  };

  // Un 503 es saturación pasajera del modelo: suele resolverse al reintentar.
  let response = await request();
  for (const delay of retryDelays) {
    if (response.status !== 503) break;
    await response.body?.cancel();
    await new Promise((resolve) => setTimeout(resolve, delay));
    response = await request();
  }

  if (!response.ok) {
    throw errorForStatus(response.status, await response.text());
  }

  const data = (await response.json()) as GeminiResponse;
  const blockReason = data.promptFeedback?.blockReason;
  const candidate = data.candidates?.[0];
  if (blockReason || candidate?.finishReason === 'SAFETY') {
    // Los filtros de seguridad de Gemini descartaron el contenido.
    throw new AiServiceError(
      `Gemini bloqueó la petición (${blockReason ?? 'SAFETY'}).`,
      'No puedo ayudarte con esa petición. Escribe el plato que quieres preparar.',
      true,
    );
  }

  const text = candidate?.content?.parts?.map((part) => part.text ?? '').join('');
  if (!text) {
    throw new AiServiceError(
      `Gemini no devolvió texto (finishReason: ${candidate?.finishReason ?? 'ninguno'}).`,
    );
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new AiServiceError(`Gemini devolvió JSON inválido: ${text.slice(0, 300)}`);
  }
}
