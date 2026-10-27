import assert from 'node:assert/strict';
import { test } from 'node:test';

import { HttpError } from '../src/middlewares/http-error.js';
import {
  maxPromptBytes,
  parseAssistantRequest,
  parseRequestId,
} from '../src/services/assistant-prompt.js';

test('keeps the prompt exactly as the user wrote it', () => {
  const prompt = '  Quiero preparar lasaña para 4 personas 🍝\n y pan  ';

  assert.deepEqual(parseAssistantRequest({ prompt }), { prompt, branchId: null });
});

test('rejects empty or whitespace-only prompts', () => {
  for (const prompt of ['', '   ', '\n\t']) {
    assert.throws(
      () => parseAssistantRequest({ prompt }),
      (error: unknown) =>
        error instanceof HttpError && error.statusCode === 400,
    );
  }
});

test('rejects bodies without a text prompt', () => {
  for (const body of [null, [], 'texto', {}, { prompt: 42 }]) {
    assert.throws(
      () => parseAssistantRequest(body),
      (error: unknown) =>
        error instanceof HttpError && error.statusCode === 400,
    );
  }
});

test('rejects unexpected fields', () => {
  assert.throws(
    () => parseAssistantRequest({ prompt: 'pan', user_id: 1 }),
    /El campo user_id no está permitido/,
  );
});

test('rejects prompts larger than the TEXT column', () => {
  assert.throws(
    () => parseAssistantRequest({ prompt: 'a'.repeat(maxPromptBytes + 1) }),
    /no puede superar/,
  );
  assert.doesNotThrow(() =>
    parseAssistantRequest({ prompt: 'a'.repeat(maxPromptBytes) }),
  );
});

test('accepts the selected branch', () => {
  assert.deepEqual(parseAssistantRequest({ prompt: 'lasaña', branch_id: 2 }), {
    prompt: 'lasaña',
    branchId: 2,
  });
});

test('rejects invalid branch ids', () => {
  for (const branch_id of [0, -1, 1.5, '1', null]) {
    assert.throws(
      () => parseAssistantRequest({ prompt: 'pan', branch_id }),
      /branch_id debe ser un entero positivo/,
    );
  }
});

test('parses request ids from the route', () => {
  assert.equal(parseRequestId('15'), 15);
  for (const value of ['0', '-3', 'abc', '1.5', '', ['1']]) {
    assert.throws(
      () => parseRequestId(value),
      (error: unknown) =>
        error instanceof HttpError && error.statusCode === 400,
    );
  }
});
