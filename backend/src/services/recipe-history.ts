import type { RecipeHistoryEntry } from '../models/assistant-request.js';
import { normalizeIngredientName } from './ingredient-list.js';

export const maxHistoryEntries = 30;

/**
 * Deja una sola entrada por receta: la más reciente. Espera las entradas
 * ordenadas de la más nueva a la más antigua.
 */
export function latestPerRecipe(entries: RecipeHistoryEntry[]): RecipeHistoryEntry[] {
  const latest = new Map<string, RecipeHistoryEntry>();
  for (const entry of entries) {
    const key = normalizeIngredientName(entry.recipe_name);
    if (!latest.has(key)) latest.set(key, entry);
  }
  return [...latest.values()].slice(0, maxHistoryEntries);
}
