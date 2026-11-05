import assert from 'node:assert/strict';
import test from 'node:test';

import {
  applyProductOverrides,
  ingredientsForProduct,
} from '../src/database/demo-catalog.js';
import type { SeedProduct } from '../src/database/glb-seed-data.js';

const ingredients = [
  { name: 'Papa' },
  { name: 'Pollo' },
  { name: 'Carne de res' },
  { name: 'Mantequilla' },
];

test('links products whose name does not mention the ingredient', () => {
  assert.deepEqual(ingredientsForProduct('Res', ingredients), [
    { name: 'Carne de res' },
  ]);
});

test('processed products do not count as the raw ingredient', () => {
  assert.deepEqual(ingredientsForProduct('Papas chips', ingredients), []);
  assert.deepEqual(ingredientsForProduct('Pollo al horno', ingredients), []);
  assert.deepEqual(ingredientsForProduct('Mantequilla de mani', ingredients), []);
});

test('the remaining products are linked by name', () => {
  assert.deepEqual(ingredientsForProduct('Pollo entero', ingredients), [
    { name: 'Pollo' },
  ]);
  assert.deepEqual(ingredientsForProduct('Papa', ingredients), [{ name: 'Papa' }]);
});

test('an override keeps the slot and position of the replaced box', () => {
  const box: SeedProduct = {
    sku: 'PIL_0016',
    slot: 'SLOT_1',
    name: 'Oferta semanal',
    category: 'Promociones',
    section: 'Zona caliente',
    shelf: 'E1',
    x: 1,
    y: 2,
    z: 3,
    boxCount: 4,
  };

  const data = applyProductOverrides({ sections: [], points: [], products: [box] }, [
    { sku: 'PIL_0016', from: 'Oferta semanal', name: 'Ajo', category: 'Verduras' },
  ]);

  assert.deepEqual(data.products, [{ ...box, name: 'Ajo', category: 'Verduras' }]);
});
