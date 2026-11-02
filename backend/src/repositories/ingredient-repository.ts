import type { RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type { IngredientProductMatch } from '../models/shopping-list.js';

interface IngredientRow extends RowDataPacket {
  ingredient_id: number;
  name: string;
}

interface AvailableIngredientProductRow extends RowDataPacket {
  ingredient_id: number;
  product_id: number;
  name: string;
  stock_quantity: string;
}

/**
 * Busca ingredientes del catálogo por nombre. La colación de la tabla
 * (utf8mb4_unicode_ci) ignora mayúsculas y tildes.
 */
export async function findByNames(
  names: string[],
): Promise<Array<{ ingredient_id: number; name: string }>> {
  if (names.length === 0) return [];
  const [rows] = await pool.query<IngredientRow[]>(
    'SELECT ingredient_id, name FROM ingredients WHERE name IN (?)',
    [names],
  );
  return rows.map((row) => ({ ingredient_id: row.ingredient_id, name: row.name }));
}

export async function findAvailableProducts(
  branchId: number,
  ingredientIds: number[],
): Promise<IngredientProductMatch[]> {
  if (ingredientIds.length === 0) return [];

  const [rows] = await pool.query<AvailableIngredientProductRow[]>(
    `SELECT pi.ingredient_id, p.product_id, p.name, i.stock_quantity
     FROM product_ingredients pi
     JOIN products p ON p.product_id = pi.product_id AND p.status = TRUE
     JOIN inventory i
       ON i.product_id = p.product_id
      AND i.branch_id = ?
      AND i.stock_quantity > 0
     WHERE pi.ingredient_id IN (?)
     ORDER BY pi.ingredient_id, p.name`,
    [branchId, ingredientIds],
  );

  return rows.map((row) => ({
    ingredient_id: row.ingredient_id,
    product_id: row.product_id,
    name: row.name,
    stock_quantity: Number(row.stock_quantity),
  }));
}
