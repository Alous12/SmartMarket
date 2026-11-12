import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';

import { AiServiceError } from '../src/services/ai/ai-error.js';
import { generateOllamaJson } from '../src/services/ai/ollama-provider.js';
import { availableModels, resolveModel } from '../src/services/ai/ai-provider.js';

const original = { ...process.env };
beforeEach(() => {
  process.env.OLLAMA_MODEL = 'local:test';
  process.env.OLLAMA_BASE_URL = 'http://127.0.0.1:11434';
  delete process.env.GEMINI_API_KEY;
  delete process.env.AI_PROVIDER;
  delete process.env.OLLAMA_MODELS;
});
afterEach(() => {
  for (const key of ['OLLAMA_MODEL', 'OLLAMA_MODELS', 'OLLAMA_BASE_URL', 'GEMINI_API_KEY', 'AI_PROVIDER']) {
    if (original[key] === undefined) delete process.env[key];
    else process.env[key] = original[key];
  }
});

const input = {
  systemInstruction: 'Solo recetas',
  userText: 'Lasaña',
  responseSchema: {
    type: 'OBJECT',
    properties: { unit: { type: 'STRING', nullable: true, enum: ['g', 'u'] } },
  },
};

test('Ollama receives the model, messages and a JSON Schema with null support', async () => {
  let init: RequestInit | undefined;
  const result = await generateOllamaJson(input, async (url, options) => {
    assert.equal(String(url), 'http://127.0.0.1:11434/api/chat');
    init = options;
    return Response.json({ message: { content: '{"is_recipe":true}' } });
  });
  assert.deepEqual(result, { is_recipe: true });
  const body = JSON.parse(String(init?.body));
  assert.equal(body.model, 'local:test');
  assert.equal(body.stream, false);
  assert.equal(body.think, false);
  assert.deepEqual(body.format.properties.unit, {
    type: ['string', 'null'], enum: ['g', 'u', null],
  });
  assert.deepEqual(body.messages, [
    { role: 'system', content: 'Solo recetas' },
    { role: 'user', content: 'Lasaña' },
  ]);
});

test('rejects missing model, HTTP errors, malformed replies and connection failures', async () => {
  delete process.env.OLLAMA_MODEL;
  await assert.rejects(generateOllamaJson(input), AiServiceError);
  process.env.OLLAMA_MODEL = 'local:test';
  for (const fake of [
    async () => new Response('missing', { status: 404 }),
    async () => Response.json({ message: { content: 'not json' } }),
    async () => Response.json({}),
    async () => { throw new Error('offline'); },
  ]) {
    await assert.rejects(generateOllamaJson(input, fake), AiServiceError);
  }
});

test('uses the specifically selected local model', async () => {
  await generateOllamaJson(input, async (_target, options) => {
    assert.equal(JSON.parse(String(options?.body)).model, 'other:4b');
    return Response.json({ message: { content: '{}' } });
  }, 'other:4b');
});

test('only configured models can be selected', () => {
  process.env.OLLAMA_MODELS = 'other:4b, local:test';
  assert.deepEqual(availableModels(), [
    { id: 'ollama:local:test', label: 'Ollama (local:test)' },
    { id: 'ollama:other:4b', label: 'Ollama (other:4b)' },
  ]);
  assert.equal(resolveModel('ollama').id, 'ollama:local:test');
  assert.equal(resolveModel('ollama:other:4b').id, 'ollama:other:4b');
  assert.throws(() => resolveModel('ollama:unlisted'), AiServiceError);
  assert.throws(() => resolveModel('http://other-server'), AiServiceError);
  process.env.AI_PROVIDER = 'ollama';
  assert.equal(resolveModel().id, 'ollama:local:test');
});

test('limits local generation to one request and releases the slot', async () => {
  let release: ((response: Response) => void) | undefined;
  const pending = generateOllamaJson(input, () => new Promise<Response>((resolve) => {
    release = resolve;
  }));
  await assert.rejects(generateOllamaJson(input), (error: unknown) =>
    error instanceof AiServiceError && /ocupado/.test(error.userMessage));
  assert.ok(release);
  release(Response.json({ message: { content: '{}' } }));
  await pending;
  await generateOllamaJson(input, async () => Response.json({ message: { content: '{}' } }));
});

test('rejects truncated output even if its JSON happens to parse', async () => {
  await assert.rejects(
    generateOllamaJson(input, async () =>
      Response.json({ done_reason: 'length', message: { content: '{}' } })),
    AiServiceError,
  );
});
