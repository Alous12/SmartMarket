import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { Branch, BranchProduct } from '../src/models/catalog.js';
import {
  buildAdminAssistantInstruction,
  parseAdminAssistantResponse,
} from '../src/services/ai/admin-assistant.js';

const branch: Branch = {
  branch_id: 7,
  name: 'Sucursal Centro',
  address: 'Centro',
  latitude: 0,
  longitude: 0,
  status: true,
  model_3d_url: 'centro.glb',
};

const product: BranchProduct = {
  product_id: 9,
  sku: 'LE-9',
  name: 'Leche',
  brand: null,
  price: 2.5,
  unit_of_measure: 'unidad',
  image_url: null,
  category_id: 3,
  category_name: 'Lácteos',
  stock_quantity: 2,
  locations: [{
    product_location_id: 1,
    section_id: 4,
    section_name: 'Fríos',
    coordinate_x: 1,
    coordinate_y: 0,
    coordinate_z: 2,
    shelf: 'B2',
  }],
};

test('el prompt administrativo incluye solo la sucursal y su inventario', () => {
  const prompt = buildAdminAssistantInstruction(branch, [product]);

  assert.match(prompt, /Sucursal Centro \(ID 7\)/);
  assert.match(prompt, /Solo puedes usar el inventario JSON/);
  assert.match(prompt, /resume listas largas/);
  assert.match(prompt, /"stock":2/);
  assert.match(prompt, /"estante":"B2"/);
  assert.doesNotMatch(prompt, /Sucursal Norte/);
});

test('parsea respuestas naturales dinámicas', () => {
  assert.equal(
    parseAdminAssistantResponse({ answer: '  Leche: 2 unidades.  ' }),
    'Leche: 2 unidades.',
  );
  assert.throws(() => parseAdminAssistantResponse({ answer: '' }));
});
