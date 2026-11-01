import type { RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';

interface IngredientRow extends RowDataPacket {
  ingredient_id: number;
  name: string;
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
