import assert from 'node:assert/strict';
import test from 'node:test';

import { HttpError } from '../src/middlewares/http-error.js';
import { defaultAssistantSettings } from '../src/models/assistant-settings.js';
import {
  applyAssistantSettings,
  parseSettingsUpdate,
} from '../src/services/assistant-settings-service.js';

const learned = {
  preferLowerPrice: false,
  preferredProducts: [10, 20],
  preferences: [],
  learnedIngredients: [],
};

function rejects(run: () => unknown, message: RegExp) {
  assert.throws(run, (error: unknown) => {
    assert.ok(error instanceof HttpError);
    assert.equal(error.statusCode, 400);
    assert.match(error.message, message);
    return true;
  });
}

test('los valores por defecto dejan el perfil aprendido exactamente igual', () => {
  assert.deepEqual(applyAssistantSettings(learned, defaultAssistantSettings), learned);
  const cheapLearned = { ...learned, preferLowerPrice: true };
  assert.deepEqual(
    applyAssistantSettings(cheapLearned, defaultAssistantSettings),
    cheapLearned,
  );
});

test('priorizar lo más barato hace mandar al precio sin esperar el umbral', () => {
  const profile = applyAssistantSettings(learned, {
    prioritize_cheapest: true,
    remember_brands: true,
  });
  assert.equal(profile.preferLowerPrice, true);
  assert.deepEqual(profile.preferredProducts, [10, 20]);
});

test('sin recordar marcas no se usan los productos repetidos', () => {
  const profile = applyAssistantSettings(learned, {
    prioritize_cheapest: false,
    remember_brands: false,
  });
  assert.deepEqual(profile.preferredProducts, []);
  assert.equal(profile.preferLowerPrice, false);
});

test('el PATCH acepta solo los interruptores como booleanos', () => {
  assert.deepEqual(parseSettingsUpdate({ prioritize_cheapest: true }), {
    prioritize_cheapest: true,
  });
  assert.deepEqual(
    parseSettingsUpdate({ prioritize_cheapest: false, remember_brands: false }),
    { prioritize_cheapest: false, remember_brands: false },
  );
  rejects(() => parseSettingsUpdate({}), /al menos un ajuste/);
  rejects(() => parseSettingsUpdate({ remember_brands: 'sí' }), /verdadero o falso/);
  rejects(() => parseSettingsUpdate({ user_id: 3 }), /no es un ajuste/);
  rejects(() => parseSettingsUpdate([]), /objeto JSON/);
});
