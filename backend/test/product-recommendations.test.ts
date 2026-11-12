import assert from 'node:assert/strict';
import test from 'node:test';
import { AiServiceError } from '../src/services/ai/ai-error.js';
import { parseRecommendations, recommendProducts } from '../src/services/ai/product-recommendations.js';
import { parseCompactRecipeAnalysis } from '../src/services/ai/recipe-analysis.js';
import type { IngredientAvailabilityItem } from '../src/models/shopping-list.js';
import type { SelectionHistoryEntry } from '../src/repositories/assistant-choice-repository.js';

const candidates = [
  { item_id: 1, branch_id: 2, product_id: 3 },
  { item_id: 1, branch_id: 2, product_id: 4 },
];

test('preserves general intentions from the model', () => {
  const analysis = parseCompactRecipeAnalysis({
    r: true, n: 'plato', i: [{ n: 'Arroz', q: 1, u: 'kg' }],
    m: null, p: ['productos económicos', 'sin carne'],
  });
  assert.ok(analysis.isRecipe);
  assert.deepEqual(analysis.intents, ['productos económicos', 'sin carne']);
});

test('only accepts real candidates and one selection per ingredient and branch', () => {
  assert.deepEqual(parseRecommendations({ choices: [candidates[1]] }, candidates), [candidates[1]]);
  assert.throws(() => parseRecommendations({ choices: [{ item_id: 1, branch_id: 2, product_id: 999 }] }, candidates), AiServiceError);
  assert.throws(() => parseRecommendations({ choices: candidates }, candidates), AiServiceError);
  assert.throws(() => parseRecommendations({ choices: [{ item_id: '1' }] }, candidates), AiServiceError);
});

test('sends grouped candidates and only relevant compact context to Ollama', async () => {
  const item: IngredientAvailabilityItem = {
    item_id: 1,
    ingredient_id: 10,
    name: 'tomate',
    raw_name: 'tomate',
    normalized_name: 'tomate',
    quantity: 1,
    unit: 'u',
    availability: 'AVAILABLE',
    available_products: [],
    other_branches: [],
    substitutes: [],
    product_options: [{
      product_id: 3,
      sku: 'tomate-3',
      name: 'Tomate',
      stock_quantity: 10,
      section_name: 'Verduras',
      shelf: null,
      ingredient_id: 10,
      ingredient_name: 'tomate',
      branch_id: 2,
      branch_name: 'Sucursal',
      price: 2,
      unit_of_measure: 'u',
      brand: 'Marca',
      description: `  ${'descripción '.repeat(30)}  `,
      is_substitute: false,
      selected: false,
    }],
    invalid_selected_branches: [],
  };
  const history: SelectionHistoryEntry[] = [
    { ingredient_id: 99, product_id: 8, product_name: 'Otro', price: 1, unit_of_measure: 'u', chose_cheapest: true },
    { ingredient_id: 10, product_id: 3, product_name: 'Tomate', price: 2, unit_of_measure: 'u', chose_cheapest: false },
  ];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body));
    const userData = JSON.parse(body.messages[1].content);
    assert.equal(userData.c.length, 1);
    assert.deepEqual(userData.c[0], [
      1, 'tomate',
      [[2, 3, 10, 'Tomate', 2, 'u', 'Marca', 'descripción '.repeat(13) + 'desc', false]],
    ]);
    assert.deepEqual(userData.h, [[10, 'Tomate', 2, 'u', false]]);
    assert.equal(userData.ip.length, 1);
    assert.equal(userData.p.length, 8);
    return Response.json({ message: { content: '{"choices":[{"item_id":1,"branch_id":2,"product_id":3}]}' } });
  };
  try {
    const result = await recommendProducts(
      { id: 'ollama:local:test', label: 'Ollama' },
      'elige tomate',
      ['barato', ...Array.from({ length: 8 }, (_, index) => `preferencia ${index}`)],
      [item],
      history,
      [
        { ingredient_id: 99, preference_type: 'AVOID' },
        { ingredient_id: 10, preference_type: 'PREFER' },
      ],
    );
    assert.deepEqual(result, [{ item_id: 1, branch_id: 2, product_id: 3 }]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
