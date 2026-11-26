import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';

import { adminFallbackModels } from '../src/services/assistant-service.js';

const original = { ...process.env };

beforeEach(() => {
  process.env.GEMINI_API_KEY = 'test-key';
  process.env.OLLAMA_MODEL = 'local:test';
});

afterEach(() => {
  for (const key of ['GEMINI_API_KEY', 'OLLAMA_MODEL']) {
    if (original[key] === undefined) delete process.env[key];
    else process.env[key] = original[key];
  }
});

test('el administrador prueba los demás modelos después del seleccionado', () => {
  assert.deepEqual(adminFallbackModels({ id: 'ollama:local:test', label: 'Ollama' }), [
    { id: 'ollama:local:test', label: 'Ollama' },
    {
      id: 'gemini',
      label: `Gemini (${process.env.GEMINI_MODEL?.trim() || 'gemini-3.5-flash-lite'})`,
    },
  ]);
});
