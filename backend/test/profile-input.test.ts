import assert from 'node:assert/strict';
import test from 'node:test';

import { HttpError } from '../src/middlewares/http-error.js';
import {
  parsePasswordChange,
  parseProfileUpdate,
} from '../src/services/profile-input.js';

function rejects(run: () => unknown, message: RegExp) {
  assert.throws(run, (error: unknown) => {
    assert.ok(error instanceof HttpError);
    assert.equal(error.statusCode, 400);
    assert.match(error.message, message);
    return true;
  });
}

test('perfil: acepta nombre, apellido y correo, limpios', () => {
  assert.deepEqual(
    parseProfileUpdate({ name: '  Ana ', last_name: 'Pérez', email: 'ANA@Mail.com ' }),
    { name: 'Ana', last_name: 'Pérez', email: 'ana@mail.com' },
  );
  assert.deepEqual(parseProfileUpdate({ name: 'Ana' }), { name: 'Ana' });
});

test('perfil: no deja cambiar rol, estado ni contraseña', () => {
  rejects(() => parseProfileUpdate({ role: 'admin' }), /role/);
  rejects(() => parseProfileUpdate({ status: false }), /status/);
  rejects(() => parseProfileUpdate({ password: '12345678' }), /password/);
});

test('perfil: rechaza datos vacíos o inválidos', () => {
  rejects(() => parseProfileUpdate({}), /al menos un dato/);
  rejects(() => parseProfileUpdate({ name: '   ' }), /nombre/);
  rejects(() => parseProfileUpdate({ email: 'sin-arroba' }), /formato/);
  rejects(() => parseProfileUpdate({ last_name: 'x'.repeat(101) }), /100/);
  rejects(() => parseProfileUpdate([]), /objeto JSON/);
});

test('contraseña: pide la actual y una nueva válida y distinta', () => {
  assert.deepEqual(
    parsePasswordChange({ current_password: 'vieja123', new_password: 'nueva1234' }),
    { current_password: 'vieja123', new_password: 'nueva1234' },
  );
  rejects(() => parsePasswordChange({ new_password: 'nueva1234' }), /actual/);
  rejects(
    () => parsePasswordChange({ current_password: 'vieja123', new_password: 'corta' }),
    /8 caracteres/,
  );
  rejects(
    () => parsePasswordChange({ current_password: 'misma1234', new_password: 'misma1234' }),
    /distinta/,
  );
  rejects(
    () => parsePasswordChange({ current_password: 'a', new_password: 'b'.repeat(8), role: 'x' }),
    /role/,
  );
});
