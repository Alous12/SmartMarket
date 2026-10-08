import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { afterEach, test } from 'node:test';

import bcrypt from 'bcrypt';

import { hashPassword } from '../src/services/password-hasher.js';

const originalKey = process.env.PASSWORD_HASH_KEY;

afterEach(() => {
  if (originalKey === undefined) {
    delete process.env.PASSWORD_HASH_KEY;
  } else {
    process.env.PASSWORD_HASH_KEY = originalKey;
  }
});

test('hashes password with HMAC-SHA-256 pepper and bcrypt', async () => {
  const key = 'test-only-key-with-at-least-32-characters';
  const password = 'correct horse battery staple';
  process.env.PASSWORD_HASH_KEY = key;

  const hash = await hashPassword(password);
  const digest = createHmac('sha256', key).update(password, 'utf8').digest('hex');

  assert.match(hash, /^\$2[aby]\$12\$/);
  assert.equal(await bcrypt.compare(digest, hash), true);
  assert.equal(await bcrypt.compare(password, hash), false);
});

test('uses an independent bcrypt salt for each password hash', async () => {
  process.env.PASSWORD_HASH_KEY = 'test-only-key-with-at-least-32-characters';

  const firstHash = await hashPassword('same password');
  const secondHash = await hashPassword('same password');

  assert.notEqual(firstHash, secondHash);
});

test('rejects an absent or too-short pepper key', async () => {
  process.env.PASSWORD_HASH_KEY = 'too-short';
  await assert.rejects(hashPassword('correct horse battery staple'), {
    message: /PASSWORD_HASH_KEY/,
  });
});
