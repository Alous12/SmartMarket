import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  IngredientProductMatch,
  ShoppingListItem,
} from '../src/models/shopping-list.js';
import { buildIngredientAvailabilityItems } from '../src/services/ingredient-availability.js';

const items: ShoppingListItem[] = [
  {
    item_id: 1,
    ingredient_id: 10,
    name: 'Tomate',
    raw_name: 'tomate',
    normalized_name: 'tomate',
    quantity: 2,
    unit: 'u',
  },
  {
    item_id: 2,
    ingredient_id: 20,
    name: 'Sal',
    raw_name: 'sal',
    normalized_name: 'sal',
    quantity: null,
    unit: null,
  },
  {
    item_id: 3,
    ingredient_id: null,
    name: 'Ingrediente nuevo',
    raw_name: 'ingrediente nuevo',
    normalized_name: 'ingrediente nuevo',
    quantity: null,
    unit: null,
  },
];

test('classifies ingredients and includes available products', () => {
  const products: IngredientProductMatch[] = [
    {
      ingredient_id: 10,
      product_id: 100,
      name: 'Tomate pera',
      stock_quantity: 4,
    },
  ];

  const result = buildIngredientAvailabilityItems(items, products);

  assert.deepEqual(
    result.map(({ availability, available_products }) => ({
      availability,
      available_products,
    })),
    [
      {
        availability: 'AVAILABLE',
        available_products: [
          { product_id: 100, name: 'Tomate pera', stock_quantity: 4 },
        ],
      },
      { availability: 'UNAVAILABLE', available_products: [] },
      { availability: 'NOT_IN_CATALOG', available_products: [] },
    ],
  );
});
