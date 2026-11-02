import { AiServiceError } from './ai-error.js';

const apiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
export const defaultGeminiModel = 'gemini-3.5-flash-lite';
const timeoutMs = 30_000;

const notConfiguredMessage =
  'El asistente no está disponible en este momento. Avísale al administrador.';

export interface GenerateJsonInput {
  systemInstruction: string;
  userText: string;
  responseSchema: object;
}

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
): Promise<unknown> {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) {
    throw new AiServiceError(
      'GEMINI_API_KEY no está configurada en backend/.env.',
      notConfiguredMessage,
    );
  }
  const model = process.env.GEMINI_MODEL?.trim() || defaultGeminiModel;

  let response: Response;
  try {
    response = await fetchImpl(
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
    throw new AiServiceError(
      `No se pudo conectar con Gemini: ${(error as Error).message}`,
    );
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
