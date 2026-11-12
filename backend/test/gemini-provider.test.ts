import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';

import { AiServiceError } from '../src/services/ai/ai-error.js';
import { defaultGeminiModel, generateJson } from '../src/services/ai/gemini-provider.js';

const input = {
  systemInstruction: 'Solo recetas.',
  userText: 'Quiero preparar lasaña',
  responseSchema: { type: 'OBJECT' },
};

function geminiReply(body: unknown, status = 200): typeof fetch {
  return async () =>
    new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    });
}

function textReply(text: string, finishReason = 'STOP'): typeof fetch {
  return geminiReply({
    candidates: [{ finishReason, content: { parts: [{ text }] } }],
  });
}

let savedKey: string | undefined;
let savedModel: string | undefined;

beforeEach(() => {
  savedKey = process.env.GEMINI_API_KEY;
  savedModel = process.env.GEMINI_MODEL;
  process.env.GEMINI_API_KEY = 'test-key';
  delete process.env.GEMINI_MODEL;
});

afterEach(() => {
  if (savedKey === undefined) delete process.env.GEMINI_API_KEY;
  else process.env.GEMINI_API_KEY = savedKey;
  if (savedModel === undefined) delete process.env.GEMINI_MODEL;
  else process.env.GEMINI_MODEL = savedModel;
});

test('HU-14 CC1 y CC2: sends the user text unchanged with the instruction and schema', async () => {
  let url = '';
  let init: RequestInit | undefined;
  const fakeFetch: typeof fetch = async (target, options) => {
    url = String(target);
    init = options;
    return textReply('{"is_recipe":false}')(target, options);
  };

  const result = await generateJson(input, fakeFetch);

  assert.deepEqual(result, { is_recipe: false });
  assert.equal(
    url,
    `https://generativelanguage.googleapis.com/v1beta/models/${defaultGeminiModel}:generateContent`,
  );
  assert.equal((init?.headers as Record<string, string>)['x-goog-api-key'], 'test-key');
  const body = JSON.parse(String(init?.body));
  assert.deepEqual(body.contents, [
    { role: 'user', parts: [{ text: 'Quiero preparar lasaña' }] },
  ]);
  assert.deepEqual(body.systemInstruction, { parts: [{ text: 'Solo recetas.' }] });
  assert.equal(body.generationConfig.responseMimeType, 'application/json');
  assert.deepEqual(body.generationConfig.responseSchema, { type: 'OBJECT' });
});

test('uses GEMINI_MODEL when it is configured', async () => {
  process.env.GEMINI_MODEL = 'gemini-otro';
  let url = '';
  await generateJson(input, async (target, options) => {
    url = String(target);
    return textReply('{}')(target, options);
  });
  assert.match(url, /models\/gemini-otro:generateContent$/);
});

test('fails without calling Gemini when the key is missing', async () => {
  delete process.env.GEMINI_API_KEY;
  await assert.rejects(
    generateJson(input, async () => assert.fail('No debería llamar a Gemini')),
    (error: unknown) => error instanceof AiServiceError && /GEMINI_API_KEY/.test(error.message),
  );
});

test('explains the free quota limit to the user', async () => {
  await assert.rejects(
    generateJson(input, geminiReply({ error: { message: 'quota' } }, 429)),
    (error: unknown) =>
      error instanceof AiServiceError && /límite de consultas/.test(error.userMessage),
  );
});

test('retries while the model is saturated and returns the answer', async () => {
  let calls = 0;
  const fakeFetch: typeof fetch = async (target, options) => {
    calls++;
    return calls < 3
      ? geminiReply({ error: { code: 503 } }, 503)(target, options)
      : textReply('{"is_recipe":false}')(target, options);
  };

  const result = await generateJson(input, fakeFetch, [0, 0]);

  assert.deepEqual(result, { is_recipe: false });
  assert.equal(calls, 3);
});

test('gives up after the last retry if the model stays saturated', async () => {
  let calls = 0;
  const fakeFetch: typeof fetch = async (target, options) => {
    calls++;
    return geminiReply({ error: { code: 503 } }, 503)(target, options);
  };

  await assert.rejects(
    generateJson(input, fakeFetch, [0, 0]),
    (error: unknown) => error instanceof AiServiceError && /503/.test(error.message) &&
      /saturado/.test(error.userMessage),
  );
  assert.equal(calls, 3);
});

test('does not retry errors that will not change, like the quota limit', async () => {
  let calls = 0;
  const fakeFetch: typeof fetch = async (target, options) => {
    calls++;
    return geminiReply({ error: { code: 429 } }, 429)(target, options);
  };

  await assert.rejects(generateJson(input, fakeFetch, [0, 0]), AiServiceError);
  assert.equal(calls, 1);
});

test('treats content blocked by Gemini as a rejected request', async () => {
  await assert.rejects(
    generateJson(input, geminiReply({ promptFeedback: { blockReason: 'SAFETY' } })),
    (error: unknown) => error instanceof AiServiceError && error.rejected,
  );
});

test('fails on empty or invalid JSON answers', async () => {
  for (const reply of [textReply(''), textReply('no es json'), geminiReply({})]) {
    await assert.rejects(
      generateJson(input, reply),
      (error: unknown) => error instanceof AiServiceError && !error.rejected,
    );
  }
});

test('fails when Gemini cannot be reached', async () => {
  await assert.rejects(
    generateJson(input, async () => {
      throw new TypeError('fetch failed');
    }),
    (error: unknown) => error instanceof AiServiceError && /conectar/.test(error.message),
  );
});

test('reports Gemini timeouts separately from connection failures', async () => {
  await assert.rejects(
    generateJson(input, async () => {
      throw new DOMException('timeout', 'TimeoutError');
    }),
    (error: unknown) => error instanceof AiServiceError && /tardó demasiado/.test(error.userMessage),
  );
});
