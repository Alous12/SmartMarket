import { AiServiceError } from './ai-error.js';
import { defaultGeminiModel, generateJson as generateGeminiJson } from './gemini-provider.js';
import { generateOllamaJson } from './ollama-provider.js';

export interface GenerateJsonInput {
  systemInstruction: string;
  userText: string;
  responseSchema: object;
}

export interface AiModel {
  id: string;
  label: string;
}

function configuredOllamaModels(): string[] {
  const defaultModel = process.env.OLLAMA_MODEL?.trim();
  const additional = (process.env.OLLAMA_MODELS ?? '')
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean);
  return [...new Set([...(defaultModel ? [defaultModel] : []), ...additional])];
}

export function availableModels(): AiModel[] {
  const models: AiModel[] = [];
  if (process.env.GEMINI_API_KEY?.trim()) {
    models.push({ id: 'gemini', label: `Gemini (${process.env.GEMINI_MODEL?.trim() || defaultGeminiModel})` });
  }
  for (const ollamaModel of configuredOllamaModels()) {
    models.push({ id: `ollama:${ollamaModel}`, label: `Ollama (${ollamaModel})` });
  }
  return models;
}

export function resolveModel(id?: string): AiModel {
  let selected = id ?? (process.env.AI_PROVIDER?.trim() || 'gemini');
  if (selected === 'ollama' && process.env.OLLAMA_MODEL?.trim()) {
    selected = `ollama:${process.env.OLLAMA_MODEL.trim()}`;
  }
  const model = availableModels().find((entry) => entry.id === selected);
  if (!model) {
    throw new AiServiceError(
      `El proveedor de IA "${selected}" no está habilitado.`,
      'El modelo seleccionado no está disponible. Elige otro modelo o consulta al administrador.',
    );
  }
  return model;
}

export function generateJson(input: GenerateJsonInput, model: AiModel): Promise<unknown> {
  if (model.id === 'gemini') return generateGeminiJson(input);
  if (model.id.startsWith('ollama:')) {
    return generateOllamaJson(input, fetch, model.id.slice('ollama:'.length));
  }
  throw new AiServiceError(`Proveedor de IA desconocido: ${model.id}`);
}
