import assert from 'node:assert/strict';
import test from 'node:test';

import type { AdminInventoryProduct } from '../src/models/catalog.js';
import { adminAnswerRows } from '../src/services/assistant-service.js';

function product(
  product_id: number | undefined,
  name: string,
  stock: number,
): AdminInventoryProduct {
  return {
    product_id,
    name,
    sku: `SKU-${name}`,
    brand: null,
    category: 'Lácteos',
    price: 10,
    unit: 'u',
    stock,
    locations: [],
  };
}

test('las filas salen de la consulta real con su estado de stock', () => {
  assert.deepEqual(
    adminAnswerRows([
      product(1, 'Queso mozzarella', 0),
      product(2, 'Yogur natural', 4),
      product(3, 'Leche', 30),
    ]),
    {
      rows: [
        { product_id: 1, name: 'Queso mozzarella', stock: 0, status: 'out' },
        { product_id: 2, name: 'Yogur natural', stock: 4, status: 'low' },
        { product_id: 3, name: 'Leche', stock: 30, status: 'ok' },
      ],
    },
  );
});

test('sin productos (conteos o resúmenes) no se agrega el campo rows', () => {
  assert.deepEqual(adminAnswerRows([]), {});
  assert.deepEqual(adminAnswerRows([product(undefined, 'Sin id', 2)]), {});
});

test('el umbral de stock bajo es 5 unidades, como en el inventario', () => {
  const [low, ok] = adminAnswerRows([product(1, 'A', 5), product(2, 'B', 6)]).rows!;
  assert.equal(low.status, 'low');
  assert.equal(ok.status, 'ok');
});
