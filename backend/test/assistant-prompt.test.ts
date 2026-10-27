import assert from 'node:assert/strict';
import { test } from 'node:test';

import { HttpError } from '../src/middlewares/http-error.js';
import {
  maxPromptBytes,
  parseAssistantPrompt,
} from '../src/services/assistant-prompt.js';

test('keeps the prompt exactly as the user wrote it', () => {
  const prompt = '  Quiero preparar lasaña para 4 personas 🍝\n y pan  ';

  assert.equal(parseAssistantPrompt({ prompt }), prompt);
});

test('rejects empty or whitespace-only prompts', () => {
  for (const prompt of ['', '   ', '\n\t']) {
    assert.throws(
      () => parseAssistantPrompt({ prompt }),
      (error: unknown) =>
        error instanceof HttpError && error.statusCode === 400,
    );
  }
});

test('rejects bodies without a text prompt', () => {
  for (const body of [null, [], 'texto', {}, { prompt: 42 }]) {
    assert.throws(
      () => parseAssistantPrompt(body),
      (error: unknown) =>
        error instanceof HttpError && error.statusCode === 400,
    );
  }
});

test('rejects unexpected fields', () => {
  assert.throws(
    () => parseAssistantPrompt({ prompt: 'pan', user_id: 1 }),
    /El campo user_id no está permitido/,
  );
});

test('rejects prompts larger than the TEXT column', () => {
  assert.throws(
    () => parseAssistantPrompt({ prompt: 'a'.repeat(maxPromptBytes + 1) }),
    /no puede superar/,
  );
  assert.doesNotThrow(() =>
    parseAssistantPrompt({ prompt: 'a'.repeat(maxPromptBytes) }),
  );
});
