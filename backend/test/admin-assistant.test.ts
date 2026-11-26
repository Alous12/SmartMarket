import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { AdminInventoryResult, Branch, Category } from '../src/models/catalog.js';
import {
  buildAdminAssistantInstruction,
  buildAdminAssistantQueryInstruction,
  enforceAdminIntent,
  parseAdminAssistantQuery,
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

const categories: Category[] = [
  { category_id: 3, name: 'Lácteos', description: null },
];

const query = {
  operation: 'list' as const,
  searchTerms: ['leche'],
  category: 'Lácteos',
  stock: 'low' as const,
  sort: 'stock_asc' as const,
  limit: 20,
  groupByCategory: false,
  includeLocations: true,
};

const inventory: AdminInventoryResult = {
  summary: {
    products: 1,
    stock: 2,
    value: 5,
    lowStockProducts: 1,
    outOfStockProducts: 0,
  },
  products: [{
    name: 'Leche',
    sku: 'LE-9',
    brand: null,
    category: 'Lácteos',
    price: 2.5,
    unit: 'unidad',
    stock: 2,
    locations: [{ section: 'Fríos', shelf: 'B2' }],
  }],
  categories: [],
};

test('la extracción administrativa envía categorías, no productos', () => {
  const prompt = buildAdminAssistantQueryInstruction(categories);

  assert.match(prompt, /Lácteos/);
  assert.match(prompt, /stock=low/);
  assert.doesNotMatch(prompt, /Leche|LE-9/);
});

test('valida y normaliza el filtro estructurado', () => {
  assert.deepEqual(parseAdminAssistantQuery({
    operation: 'list',
    search_terms: [' leche ', 'leche'],
    category: 'Lácteos',
    stock: 'low',
    sort: 'stock_asc',
    limit: 20,
    group_by_category: false,
    include_locations: true,
  }), query);
  assert.throws(() => parseAdminAssistantQuery({
    operation: 'delete',
    search_terms: [],
    category: null,
    stock: 'all',
    sort: 'name',
    limit: 10,
    group_by_category: false,
    include_locations: false,
  }));
});

test('el prompt de respuesta solo incluye el inventario filtrado', () => {
  const prompt = buildAdminAssistantInstruction(branch, query, inventory);

  assert.match(prompt, /Sucursal Centro \(ID 7\)/);
  assert.match(prompt, /"unidades":2/);
  assert.match(prompt, /"nombre":"Leche"/);
  assert.match(prompt, /"shelf":"B2"/);
  assert.match(prompt, /viñetas que comiencen con «•»/);
  assert.match(prompt, /Máximo 90 palabras/);
  assert.doesNotMatch(prompt, /Inventario actual|Sucursal Norte/);
});

test('parsea respuestas naturales dinámicas', () => {
  assert.equal(
    parseAdminAssistantResponse({ answer: '  Leche: 2 unidades.  ' }),
    'Leche: 2 unidades.',
  );
  assert.throws(() => parseAdminAssistantResponse({ answer: '' }));
});

test('protege la intención explícita de resumen para consultar todo el inventario', () => {
  assert.deepEqual(enforceAdminIntent('Hazme un resumen del inventario', query), {
    ...query, operation: 'count', stock: 'all', sort: 'value_desc', groupByCategory: true,
  });
});
