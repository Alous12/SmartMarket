import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';

import { ensureOllamaRunning } from '../src/services/ai/ollama-lifecycle.js';

const original = { ...process.env };
const keys = ['OLLAMA_MODEL', 'OLLAMA_MODELS', 'OLLAMA_BASE_URL', 'OLLAMA_AUTO_START', 'OLLAMA_COMMAND'];

beforeEach(() => {
  process.env.OLLAMA_MODEL = 'local:test';
  process.env.OLLAMA_BASE_URL = 'http://127.0.0.1:11434';
  delete process.env.OLLAMA_AUTO_START;
  delete process.env.OLLAMA_COMMAND;
});

afterEach(() => {
  for (const key of keys) {
    if (original[key] === undefined) delete process.env[key];
    else process.env[key] = original[key];
  }
});

function childProcessStub() {
  return {
    once: () => undefined,
    unref: () => undefined,
  } as never;
}

test('starts Ollama when a configured local server is unavailable', async () => {
  let command = '';
  let args: readonly string[] = [];
  let attempts = 0;
  await ensureOllamaRunning({
    fetchImpl: async () => new Response('', { status: ++attempts >= 2 ? 200 : 503 }),
    spawnImpl: ((file: string, suppliedArgs: readonly string[]) => {
      command = file;
      args = suppliedArgs;
      return childProcessStub();
    }) as never,
    wait: async () => undefined,
    log: { info: () => undefined, warn: () => undefined },
  });
  assert.equal(command, 'ollama');
  assert.deepEqual(args, ['serve']);
});

test('does not spawn Ollama when it is already running or configured remotely', async () => {
  let calls = 0;
  const spawnImpl = (() => { calls += 1; return childProcessStub(); }) as never;
  await ensureOllamaRunning({
    fetchImpl: async () => new Response('', { status: 200 }),
    spawnImpl,
    log: { info: () => undefined, warn: () => undefined },
  });
  process.env.OLLAMA_BASE_URL = 'http://ollama.internal:11434';
  await ensureOllamaRunning({
    spawnImpl,
    log: { info: () => undefined, warn: () => undefined },
  });
  assert.equal(calls, 0);
});

test('respects OLLAMA_AUTO_START=false', async () => {
  process.env.OLLAMA_AUTO_START = 'false';
  let calls = 0;
  await ensureOllamaRunning({
    spawnImpl: (() => { calls += 1; return childProcessStub(); }) as never,
    log: { info: () => undefined, warn: () => undefined },
  });
  assert.equal(calls, 0);
});
