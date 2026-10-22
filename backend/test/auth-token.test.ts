import assert from 'node:assert/strict';
import { after, test } from 'node:test';

import { createAuthToken, verifyAuthToken } from '../src/services/auth-token.js';

const previousSecret = process.env.AUTH_TOKEN_SECRET;
process.env.AUTH_TOKEN_SECRET = 'unit-test-auth-secret-at-least-32-bytes';

after(() => {
  if (previousSecret === undefined) {
    delete process.env.AUTH_TOKEN_SECRET;
  } else {
    process.env.AUTH_TOKEN_SECRET = previousSecret;
  }
});

test('the token contains only username and role as identity claims', () => {
  const token = createAuthToken({ username: 'Ana', role: 'user' });
  const identity = verifyAuthToken(token);

  assert.deepEqual(identity, { username: 'Ana', role: 'user' });
});

test('rejects tokens with an invalid signature', () => {
  const token = createAuthToken({ username: 'Ana', role: 'user' });

  assert.throws(
    () => verifyAuthToken(`${token.slice(0, -1)}x`),
    /Token inválido o expirado/,
  );
});
