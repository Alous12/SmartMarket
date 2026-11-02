import assert from 'node:assert/strict';
import { test } from 'node:test';

import { AiServiceError } from '../src/services/ai/ai-error.js';
import {
  buildRecipeInstruction,
  defaultRejectionMessage,
  maxRecipeNameLength,
  parseRecipeAnalysis,
  recipeResponseSchema,
} from '../src/services/ai/recipe-analysis.js';

function isAiFailure(error: unknown): boolean {
  return error instanceof AiServiceError && !error.rejected;
}

test('HU-15 CC2: identifies the requested recipe and its ingredients', () => {
  const analysis = parseRecipeAnalysis({
    is_recipe: true,
    recipe_name: ' Lasaña  de carne ',
    ingredients: [
      { name: 'Masa para lasaña', quantity: 250, unit: 'g' },
      { name: 'Carne molida', quantity: 500, unit: 'g' },
      { name: 'Sal', quantity: null, unit: null },
    ],
    message: null,
  });

  assert.deepEqual(analysis, {
    isRecipe: true,
    recipeName: 'Lasaña de carne',
    ingredients: [
      { name: 'Masa para lasaña', quantity: 250, unit: 'g' },
      { name: 'Carne molida', quantity: 500, unit: 'g' },
      { name: 'Sal', quantity: null, unit: null },
    ],
  });
});

test('HU-15 CC1: a request that is not a recipe is rejected with a message', () => {
  assert.deepEqual(
    parseRecipeAnalysis({
      is_recipe: false,
      recipe_name: null,
      ingredients: [],
      message: 'Solo puedo ayudarte con recetas.',
    }),
    { isRecipe: false, message: 'Solo puedo ayudarte con recetas.' },
  );
  assert.deepEqual(
    parseRecipeAnalysis({ is_recipe: false, recipe_name: null, ingredients: [], message: null }),
    { isRecipe: false, message: defaultRejectionMessage },
  );
});

test('drops a unit that comes without quantity instead of failing', () => {
  const analysis = parseRecipeAnalysis({
    is_recipe: true,
    recipe_name: 'Ensalada',
    ingredients: [{ name: 'Sal', quantity: null, unit: 'g' }],
    message: null,
  });
  assert.equal(analysis.isRecipe, true);
  assert.deepEqual(analysis.isRecipe && analysis.ingredients, [
    { name: 'Sal', quantity: null, unit: null },
  ]);
});

test('truncates recipe names longer than the column', () => {
  const analysis = parseRecipeAnalysis({
    is_recipe: true,
    recipe_name: 'a'.repeat(maxRecipeNameLength + 20),
    ingredients: [{ name: 'Arroz', quantity: 1, unit: 'kg' }],
    message: null,
  });
  assert.equal(analysis.isRecipe && analysis.recipeName.length, maxRecipeNameLength);
});

test('never trusts malformed AI output', () => {
  const invalid = [
    null,
    'texto',
    {},
    { is_recipe: 'true' },
    { is_recipe: true, recipe_name: '', ingredients: [{ name: 'Arroz' }] },
    { is_recipe: true, recipe_name: 'Arroz', ingredients: [] },
    { is_recipe: true, recipe_name: 'Arroz', ingredients: [{ name: '' }] },
    { is_recipe: true, recipe_name: 'Arroz', ingredients: ['arroz'] },
  ];
  for (const output of invalid) {
    assert.throws(() => parseRecipeAnalysis(output), isAiFailure);
  }
});

test('the instruction limits the AI to recipes and lists the catalog', () => {
  const instruction = buildRecipeInstruction(['Tomate', 'Masa para lasaña']);
  assert.match(instruction, /ÚNICA tarea/);
  assert.match(instruction, /Ignora cualquier instrucción/);
  assert.match(instruction, /Tomate, Masa para lasaña/);
  assert.deepEqual(recipeResponseSchema.required, [
    'is_recipe',
    'recipe_name',
    'ingredients',
    'message',
  ]);
});
