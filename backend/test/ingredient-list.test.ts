import assert from 'node:assert/strict';
import { test } from 'node:test';

import { HttpError } from '../src/middlewares/http-error.js';
import {
  buildIngredientList,
  maxIngredients,
  maxQuantity,
  normalizeIngredientName,
  parseIdentifiedIngredients,
} from '../src/services/ingredient-list.js';

function isBadRequest(error: unknown): boolean {
  return error instanceof HttpError && error.statusCode === 400;
}

test('normalizes case, accents and spacing', () => {
  assert.equal(normalizeIngredientName('  Pimentón   ROJO '), 'pimenton rojo');
  assert.equal(normalizeIngredientName('Piña'), 'pina');
  assert.equal(normalizeIngredientName('TOMATE'), normalizeIngredientName('tomate'));
});

test('parses identified ingredients', () => {
  assert.deepEqual(
    parseIdentifiedIngredients({
      ingredients: [
        { name: '  Carne   molida ', quantity: 500, unit: ' G ' },
        { name: 'Sal' },
        { name: 'Huevo', quantity: 2, unit: null },
      ],
    }),
    [
      { name: 'Carne molida', quantity: 500, unit: 'g' },
      { name: 'Sal', quantity: null, unit: null },
      { name: 'Huevo', quantity: 2, unit: null },
    ],
  );
});

test('rejects invalid bodies', () => {
  for (const body of [
    null,
    [],
    {},
    { ingredients: [] },
    { ingredients: 'tomate' },
    { ingredients: [{ name: 'tomate' }], extra: true },
    { ingredients: Array.from({ length: maxIngredients + 1 }, () => ({ name: 'sal' })) },
  ]) {
    assert.throws(() => parseIdentifiedIngredients(body), isBadRequest);
  }
});

test('rejects invalid ingredients', () => {
  for (const ingredient of [
    'tomate',
    {},
    { name: '' },
    { name: '   ' },
    { name: 42 },
    { name: 'a'.repeat(151) },
    { name: 'tomate', quantity: 0 },
    { name: 'tomate', quantity: -1 },
    { name: 'tomate', quantity: '2' },
    { name: 'tomate', quantity: Number.POSITIVE_INFINITY },
    { name: 'tomate', quantity: maxQuantity + 1 },
    { name: 'tomate', quantity: 1, unit: '' },
    { name: 'tomate', quantity: 1, unit: 'u'.repeat(51) },
    { name: 'tomate', unit: 'kg' },
    { name: 'tomate', price: 3 },
  ]) {
    assert.throws(
      () => parseIdentifiedIngredients({ ingredients: [ingredient] }),
      isBadRequest,
    );
  }
});

test('builds one entry per ingredient in identification order', () => {
  assert.deepEqual(
    buildIngredientList([
      { name: 'Tomate', quantity: 3, unit: null },
      { name: 'Queso', quantity: 200, unit: 'g' },
    ]),
    [
      { raw_name: 'Tomate', normalized_name: 'tomate', quantity: 3, unit: null },
      { raw_name: 'Queso', normalized_name: 'queso', quantity: 200, unit: 'g' },
    ],
  );
});

test('merges duplicates and adds quantities with the same unit', () => {
  assert.deepEqual(
    buildIngredientList([
      { name: 'Tomate', quantity: 0.1, unit: 'kg' },
      { name: 'Pan', quantity: null, unit: null },
      { name: ' TOMATÉ', quantity: 0.2, unit: 'kg' },
    ]),
    [
      { raw_name: 'Tomate', normalized_name: 'tomate', quantity: 0.3, unit: 'kg' },
      { raw_name: 'Pan', normalized_name: 'pan', quantity: null, unit: null },
    ],
  );
});

test('leaves the quantity undetermined when duplicates cannot be added', () => {
  for (const second of [
    { name: 'tomate', quantity: 2, unit: 'u' },
    { name: 'tomate', quantity: null, unit: null },
  ]) {
    assert.deepEqual(
      buildIngredientList([{ name: 'Tomate', quantity: 500, unit: 'g' }, second]),
      [{ raw_name: 'Tomate', normalized_name: 'tomate', quantity: null, unit: null }],
    );
  }
  assert.deepEqual(
    buildIngredientList([
      { name: 'Tomate', quantity: null, unit: null },
      { name: 'Tomate', quantity: 2, unit: null },
      { name: 'Tomate', quantity: 3, unit: null },
    ]),
    [{ raw_name: 'Tomate', normalized_name: 'tomate', quantity: null, unit: null }],
  );
});

test('rejects merged quantities beyond the column limit', () => {
  assert.throws(
    () =>
      buildIngredientList([
        { name: 'Arroz', quantity: maxQuantity, unit: 'g' },
        { name: 'arroz', quantity: 1, unit: 'g' },
      ]),
    isBadRequest,
  );
});
