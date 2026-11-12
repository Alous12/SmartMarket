import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  BranchSummary,
  IngredientProductMatch,
  IngredientSubstitution,
  ShoppingListItem,
} from '../src/models/shopping-list.js';
import { buildIngredientAvailability } from '../src/services/ingredient-availability.js';

const selected = 1;
const other = 2;

const branches: BranchSummary[] = [
  { branch_id: selected, name: 'Natural', model_3d_url: 'uno.glb' },
  { branch_id: other, name: 'Piloto', model_3d_url: 'dos.glb' },
];

function item(id: number, name: string, ingredientId: number | null): ShoppingListItem {
  return {
    item_id: id,
    ingredient_id: ingredientId,
    name,
    raw_name: name,
    normalized_name: name.toLowerCase(),
    quantity: null,
    unit: null,
    availability: null,
  };
}

function product(
  branchId: number,
  ingredientId: number,
  productId: number,
  name: string,
): IngredientProductMatch {
  return {
    ingredient_id: ingredientId,
    branch_id: branchId,
    product_id: productId,
    sku: `SKU_${productId}`,
    name,
    stock_quantity: 4,
    section_name: 'Pasillo 1',
    shelf: 'E01',
    price: 10,
    unit_of_measure: 'u',
  };
}

test('offers stocked alternatives even when the original exists and uses a confirmed selection', () => {
  const original = product(selected, 20, 100, 'Crema');
  const alternative = { ...product(selected, 21, 101, 'Leche'), price: 5 };
  const result = buildIngredientAvailability({
    items: [crema],
    branchId: selected,
    branches,
    products: [original, alternative],
    substitutions: [cremaByLeche],
    choices: [{ item_id: crema.item_id, branch_id: selected, product_id: 101 }],
  });
  assert.deepEqual(result.items[0].product_options.map((option) => option.product_id), [100, 101]);
  assert.equal(result.items[0].product_options[1].selected, true);
  assert.equal(result.routes[0].stops[0].product_id, 101);
  assert.equal(result.routes[0].stops[0].is_substitute, true);
});

test('does not silently replace a selection that lost stock', () => {
  const result = buildIngredientAvailability({
    items: [crema],
    branchId: selected,
    branches,
    products: [product(selected, 20, 100, 'Crema')],
    substitutions: [cremaByLeche],
    choices: [{ item_id: crema.item_id, branch_id: selected, product_id: 101 }],
  });
  assert.deepEqual(result.items[0].invalid_selected_branches, [selected]);
  assert.equal(result.routes.length, 0);
});

test('uses explicit ingredient preferences and price signals to order options', () => {
  const result = buildIngredientAvailability({
    items: [crema],
    branchId: selected,
    branches,
    products: [
      { ...product(selected, 20, 100, 'Crema cara'), price: 20 },
      { ...product(selected, 20, 101, 'Crema económica'), price: 10 },
      product(selected, 21, 102, 'Leche'),
    ],
    substitutions: [cremaByLeche],
    preferLowerPrice: true,
    preferences: [{ ingredient_id: 21, preference_type: 'PREFER' }],
  });

  assert.deepEqual(result.items[0].product_options.map((option) => option.product_id), [102, 101, 100]);
});

test('learned ingredient preferences rank alternatives below explicit preferences', () => {
  const input = {
    items: [crema],
    branchId: selected,
    branches,
    products: [product(selected, 20, 100, 'Crema'), product(selected, 21, 101, 'Leche')],
    substitutions: [cremaByLeche],
    learnedIngredients: [{ ingredient_id: 20, preferred_ingredient_id: 21 }],
  };
  assert.deepEqual(buildIngredientAvailability(input).items[0].product_options.map((option) => option.product_id), [101, 100]);
  assert.deepEqual(buildIngredientAvailability({
    ...input, preferences: [{ ingredient_id: 21, preference_type: 'AVOID' }],
  }).items[0].product_options.map((option) => option.product_id), [100, 101]);
});

const tomate = item(1, 'Tomate', 10);
const crema = item(2, 'Crema de leche', 20);
const chorizo = item(3, 'Chorizo', 30);
const nuevo = item(4, 'Ingrediente nuevo', null);

const cremaByLeche: IngredientSubstitution = {
  ingredient_id: 20,
  substitute_ingredient_id: 21,
  substitute_name: 'Leche',
  priority: 1,
};

function build(
  items: ShoppingListItem[],
  products: IngredientProductMatch[],
  substitutions: IngredientSubstitution[] = [],
) {
  return buildIngredientAvailability({
    items,
    branchId: selected,
    branches,
    products,
    substitutions,
  });
}

test('HU-18: classifies each ingredient against the selected branch', () => {
  const { items } = build(
    [tomate, chorizo, nuevo],
    [product(selected, 10, 100, 'Tomate pera')],
  );

  assert.deepEqual(
    items.map((entry) => entry.availability),
    ['AVAILABLE', 'UNAVAILABLE', 'NOT_IN_CATALOG'],
  );
});

test('HU-20: available products carry their location', () => {
  const { items } = build([tomate], [product(selected, 10, 100, 'Tomate pera')]);

  assert.deepEqual(items[0].available_products, [
    {
      product_id: 100,
      sku: 'SKU_100',
      name: 'Tomate pera',
      stock_quantity: 4,
      section_name: 'Pasillo 1',
      shelf: 'E01',
    },
  ]);
});

test('HU-20: available products are included in the route', () => {
  const { routes: [route] } = build([tomate], [product(selected, 10, 100, 'Tomate pera')]);

  assert.equal(route?.branch_id, selected);
  assert.deepEqual(
    route?.stops.map((stop) => [stop.item_id, stop.product_id, stop.is_substitute]),
    [[1, 100, false]],
  );
  assert.deepEqual(route?.missing, []);
});

test('HU-21: a missing ingredient reports the branch that does have it', () => {
  const { items } = build([tomate], [product(other, 10, 200, 'Tomate')]);

  assert.equal(items[0].availability, 'UNAVAILABLE');
  assert.deepEqual(
    items[0].other_branches.map((entry) => [entry.branch_name, entry.products[0].name]),
    [['Piloto', 'Tomate']],
  );
});

test('HU-21: a missing ingredient suggests the similar one of each branch', () => {
  const { items } = build(
    [crema],
    [product(selected, 21, 110, 'Leche entera')],
    [cremaByLeche],
  );

  assert.deepEqual(
    items[0].substitutes.map((entry) => [
      entry.branch_name,
      entry.ingredient_name,
      entry.products[0].name,
    ]),
    [['Natural', 'Leche', 'Leche entera']],
  );
});

test('suggests the first alternative that has stock in the branch', () => {
  const { items } = build(
    [crema],
    [product(selected, 22, 120, 'Mantequilla')],
    [
      cremaByLeche,
      {
        ingredient_id: 20,
        substitute_ingredient_id: 22,
        substitute_name: 'Mantequilla',
        priority: 2,
      },
    ],
  );

  assert.equal(items[0].substitutes[0].ingredient_name, 'Mantequilla');
});

test('does not suggest an alternative in a branch that has the ingredient', () => {
  const { items } = build(
    [crema],
    [product(selected, 20, 130, 'Crema'), product(selected, 21, 110, 'Leche')],
    [cremaByLeche],
  );

  assert.deepEqual(items[0].substitutes, []);
});

test('HU-21: an ingredient without product nor alternative stays missing', () => {
  const { items, routes: [route] } = build(
    [tomate, chorizo],
    [product(selected, 10, 100, 'Tomate')],
    [cremaByLeche],
  );

  assert.deepEqual(items[1].other_branches, []);
  assert.deepEqual(items[1].substitutes, []);
  assert.deepEqual(route?.missing, ['Chorizo']);
});

test('the route goes to the branch that has more ingredients', () => {
  const { routes: [route] } = build(
    [tomate, crema],
    [
      product(selected, 10, 100, 'Tomate'),
      product(other, 10, 200, 'Tomate'),
      product(other, 20, 210, 'Crema'),
    ],
  );

  assert.equal(route?.branch_id, other);
  assert.equal(route?.model_3d_url, 'dos.glb');
  assert.equal(route?.stops.length, 2);
});

test('the route prefers exact products over alternatives', () => {
  const { routes: [route] } = build(
    [tomate, crema],
    [
      product(selected, 10, 100, 'Tomate'),
      product(selected, 21, 110, 'Leche'),
      product(other, 10, 200, 'Tomate'),
      product(other, 20, 210, 'Crema'),
    ],
    [cremaByLeche],
  );

  assert.equal(route?.branch_id, other);
});

test('alternatives go in the route when they cover more of the list', () => {
  const { routes: [route] } = build(
    [tomate, crema],
    [
      product(other, 10, 200, 'Tomate'),
      product(selected, 10, 100, 'Tomate'),
      product(selected, 21, 110, 'Leche'),
    ],
    [cremaByLeche],
  );

  assert.equal(route?.branch_id, selected);
  assert.deepEqual(
    route?.stops.map((stop) => [stop.product_name, stop.is_substitute]),
    [
      ['Tomate', false],
      ['Leche', true],
    ],
  );
});

test('a tie keeps the branch chosen by the user', () => {
  const { routes: [route] } = build(
    [tomate, crema],
    [product(other, 20, 210, 'Crema'), product(selected, 10, 100, 'Tomate')],
  );

  assert.equal(route?.branch_id, selected);
});

test('a tie also keeps the chosen branch when it comes last', () => {
  const {
    routes: [route],
  } = buildIngredientAvailability({
    items: [tomate],
    branchId: other,
    branches,
    products: [product(selected, 10, 100, 'Tomate'), product(other, 10, 200, 'Tomate')],
    substitutions: [],
  });

  assert.equal(route?.branch_id, other);
});

test('there is no route when no branch has anything', () => {
  const { routes } = build([chorizo, nuevo], []);

  assert.deepEqual(routes, []);
});

test('offers one route per branch that has something, best first', () => {
  const { routes } = build(
    [tomate, crema],
    [
      product(selected, 10, 100, 'Tomate'),
      product(other, 10, 200, 'Tomate'),
      product(other, 20, 210, 'Crema'),
    ],
  );

  assert.deepEqual(
    routes.map((route) => [route.branch_id, route.stops.length, route.missing]),
    [
      [other, 2, []],
      [selected, 1, ['Crema de leche']],
    ],
  );
});

test('a branch without anything from the list offers no route', () => {
  const { routes } = build([tomate], [product(other, 10, 200, 'Tomate')]);

  assert.deepEqual(
    routes.map((route) => route.branch_id),
    [other],
  );
});
