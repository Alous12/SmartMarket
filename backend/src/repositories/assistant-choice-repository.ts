import type { RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import { HttpError } from '../middlewares/http-error.js';
import type { ProductChoice } from '../models/shopping-list.js';

interface ChoiceRow extends RowDataPacket, ProductChoice {}
interface CandidateRow extends RowDataPacket {
  product_id: number;
  ingredient_id: number;
  price: string;
  unit_of_measure: string;
}

export async function findChoices(listId: number): Promise<ProductChoice[]> {
  const [rows] = await pool.execute<ChoiceRow[]>(
    `SELECT choice.item_id, choice.branch_id, choice.product_id
     FROM assistant_product_choices choice
     JOIN shopping_list_items item ON item.item_id = choice.item_id
     WHERE item.list_id = ?`,
    [listId],
  );
  return rows.map(({ item_id, branch_id, product_id }) => ({ item_id, branch_id, product_id }));
}

export async function findProfile(userId: number): Promise<{
  preferLowerPrice: boolean;
  preferences: Array<{ ingredient_id: number; preference_type: 'PREFER' | 'AVOID' }>;
  preferredProducts: number[];
  learnedIngredients: Array<{ ingredient_id: number; preferred_ingredient_id: number }>;
}> {
  const [preferences] = await pool.execute<RowDataPacket[]>(
    'SELECT ingredient_id, preference_type FROM user_preferences WHERE user_id = ?',
    [userId],
  );
  const [signals] = await pool.execute<RowDataPacket[]>(
    `SELECT COUNT(*) AS total, SUM(chose_cheapest = TRUE) AS cheapest
     FROM assistant_choice_events event
     JOIN (
       SELECT MAX(event_id) AS event_id FROM assistant_choice_events
       WHERE user_id = ? AND item_id IS NOT NULL GROUP BY item_id
     ) latest ON latest.event_id = event.event_id
     WHERE event.chose_cheapest IS NOT NULL`,
    [userId],
  );
  const total = Number(signals[0].total);
  const [products] = await pool.execute<RowDataPacket[]>(
    `SELECT event.product_id, COUNT(DISTINCT event.item_id) AS selections
     FROM assistant_choice_events event
     JOIN (
       SELECT MAX(event_id) AS event_id FROM assistant_choice_events
       WHERE user_id = ? AND item_id IS NOT NULL GROUP BY item_id
     ) latest ON latest.event_id = event.event_id
     GROUP BY event.product_id
     HAVING COUNT(DISTINCT event.item_id) >= 3
     ORDER BY selections DESC, event.product_id`,
    [userId],
  );
  const [ingredients] = await pool.execute<RowDataPacket[]>(
    `SELECT item.ingredient_id AS base_id, event.ingredient_id AS selected_id,
            COUNT(*) AS selections
     FROM assistant_choice_events event
     JOIN (
       SELECT MAX(event_id) AS event_id FROM assistant_choice_events
       WHERE user_id = ? AND item_id IS NOT NULL GROUP BY item_id
     ) latest ON latest.event_id = event.event_id
     JOIN shopping_list_items item ON item.item_id = event.item_id
     WHERE item.ingredient_id IS NOT NULL
     GROUP BY item.ingredient_id, event.ingredient_id`,
    [userId],
  );
  const totals = new Map<number, number>();
  for (const entry of ingredients) {
    const baseId = Number(entry.base_id);
    totals.set(baseId, (totals.get(baseId) ?? 0) + Number(entry.selections));
  }
  return {
    preferLowerPrice: total >= 3 && Number(signals[0].cheapest) / total >= 0.7,
    preferences: preferences.map((entry) => ({
      ingredient_id: Number(entry.ingredient_id),
      preference_type: entry.preference_type as 'PREFER' | 'AVOID',
    })),
    preferredProducts: products.map((entry) => Number(entry.product_id)),
    learnedIngredients: ingredients
      .filter((entry) => {
        const total = totals.get(Number(entry.base_id)) ?? 0;
        return total >= 3 && Number(entry.selections) / total >= 0.7;
      })
      .map((entry) => ({
        ingredient_id: Number(entry.base_id),
        preferred_ingredient_id: Number(entry.selected_id),
      })),
  };
}

export async function saveChoice(input: {
  userId: number;
  requestId: number;
  itemId: number;
  branchId: number;
  productId: number;
}): Promise<void> {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [items] = await connection.execute<RowDataPacket[]>(
      `SELECT item.ingredient_id FROM shopping_list_items item
       JOIN shopping_lists list ON list.list_id = item.list_id
       WHERE item.item_id = ? AND list.request_id = ? AND list.user_id = ?
       FOR UPDATE`,
      [input.itemId, input.requestId, input.userId],
    );
    if (!items.length) throw new HttpError(404, 'Ingrediente no encontrado.');
    const ingredientId = items[0].ingredient_id as number | null;
    if (ingredientId === null) throw new HttpError(409, 'El ingrediente no está en el catálogo.');

    const [candidates] = await connection.execute<CandidateRow[]>(
      `SELECT DISTINCT p.product_id, pi.ingredient_id, p.price, p.unit_of_measure
       FROM product_ingredients pi
       JOIN products p ON p.product_id = pi.product_id AND p.status = TRUE
       JOIN inventory i ON i.product_id = p.product_id AND i.branch_id = ? AND i.stock_quantity > 0
       JOIN branches b ON b.branch_id = i.branch_id AND b.status = TRUE
       JOIN product_locations pl ON pl.product_id = p.product_id
       JOIN sections s ON s.section_id = pl.section_id AND s.branch_id = i.branch_id
       WHERE pi.ingredient_id = ? OR pi.ingredient_id IN (
         SELECT substitute_ingredient_id FROM ingredient_substitutes WHERE ingredient_id = ?
       ) FOR UPDATE`,
      [input.branchId, ingredientId, ingredientId],
    );
    const chosen = candidates.find((candidate) =>
      candidate.product_id === input.productId && candidate.ingredient_id === ingredientId,
    ) ?? candidates.find((candidate) => candidate.product_id === input.productId);
    if (!chosen) throw new HttpError(409, 'El producto ya no está disponible para este ingrediente.');

    const [existing] = await connection.execute<RowDataPacket[]>(
      'SELECT product_id FROM assistant_product_choices WHERE item_id = ? AND branch_id = ? FOR UPDATE',
      [input.itemId, input.branchId],
    );
    if (existing.length && existing[0].product_id === input.productId) {
      await connection.commit();
      return;
    }

    await connection.execute(
      `INSERT INTO assistant_product_choices (item_id, branch_id, product_id)
       VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE product_id = VALUES(product_id), selected_at = CURRENT_TIMESTAMP`,
      [input.itemId, input.branchId, input.productId],
    );
    const comparable = candidates.filter((candidate) =>
      candidate.ingredient_id === chosen.ingredient_id && candidate.unit_of_measure === chosen.unit_of_measure,
    );
    const prices = [...new Set(comparable.map((candidate) => Number(candidate.price)))];
    const choseCheapest = prices.length > 1 ? Number(chosen.price) === Math.min(...prices) : null;
    await connection.execute(
      `INSERT INTO assistant_choice_events
       (user_id, item_id, branch_id, product_id, ingredient_id, price, chose_cheapest, candidates_at_selection)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [input.userId, input.itemId, input.branchId, input.productId, chosen.ingredient_id,
        chosen.price, choseCheapest, JSON.stringify(candidates)],
    );
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
