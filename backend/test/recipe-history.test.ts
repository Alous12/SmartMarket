import assert from 'node:assert/strict';
import test from 'node:test';

import type { RecipeHistoryEntry } from '../src/models/assistant-request.js';
import { latestPerRecipe, maxHistoryEntries } from '../src/services/recipe-history.js';

function entry(requestId: number, recipeName: string): RecipeHistoryEntry {
  return {
    request_id: requestId,
    recipe_name: recipeName,
    branch_id: 1,
    ingredient_count: 5,
    created_at: new Date('2026-11-05T12:00:00Z'),
  };
}

test('a repeated recipe appears once, with its latest request', () => {
  const history = latestPerRecipe([
    entry(9, 'Silpancho'),
    entry(7, 'Lasaña'),
    entry(4, 'silpancho '),
    entry(2, 'LASANA'),
  ]);

  assert.deepEqual(
    history.map((item) => item.request_id),
    [9, 7],
  );
});

test('the history keeps a limited number of recipes', () => {
  const entries = Array.from({ length: maxHistoryEntries + 5 }, (_, index) =>
    entry(index + 1, `Receta ${index}`),
  );

  assert.equal(latestPerRecipe(entries).length, maxHistoryEntries);
});
