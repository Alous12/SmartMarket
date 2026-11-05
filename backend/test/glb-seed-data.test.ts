import assert from 'node:assert/strict';
import test from 'node:test';

import { demoPrice, matchIngredients } from '../src/database/glb-seed-data.js';

const ingredients = [
  { name: 'Arroz' },
  { name: 'Lenteja' },
  { name: 'Crema de leche' },
  { name: 'Leche' },
  { name: 'Limón' },
];

test('matches ingredients by whole word, ignoring accents and plurals', () => {
  assert.deepEqual(
    matchIngredients('Arroz-Perlita', ingredients).map((i) => i.name),
    ['Arroz'],
  );
  assert.deepEqual(
    matchIngredients('Lentejas', ingredients).map((i) => i.name),
    ['Lenteja'],
  );
  assert.deepEqual(
    matchIngredients('Limon en polvo', ingredients).map((i) => i.name),
    ['Limón'],
  );
  assert.deepEqual(matchIngredients('Arrozal', ingredients), []);
});

test('does not take a flavor or a description for the ingredient', () => {
  assert.deepEqual(matchIngredients('Soda limon', ingredients), []);
  assert.deepEqual(matchIngredients('Dulce de leche', ingredients), []);
  assert.deepEqual(
    matchIngredients('Leche entera', ingredients).map((i) => i.name),
    ['Leche'],
  );
});

test('demo price is stable and within range', () => {
  assert.equal(demoPrice('ARROZ_001'), demoPrice('ARROZ_001'));
  const price = demoPrice('PIL_0091');
  assert.ok(price >= 5 && price < 35);
});
