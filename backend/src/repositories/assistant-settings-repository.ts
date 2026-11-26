import type { RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import {
  defaultAssistantSettings,
  type AssistantSettings,
} from '../models/assistant-settings.js';

/** Ajustes del usuario; sin fila devuelve los valores por defecto sin guardarlos. */
export async function find(userId: number): Promise<AssistantSettings> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT prioritize_cheapest, remember_brands
     FROM user_assistant_settings WHERE user_id = ? LIMIT 1`,
    [userId],
  );
  if (rows.length === 0) return { ...defaultAssistantSettings };
  return {
    prioritize_cheapest: Boolean(rows[0].prioritize_cheapest),
    remember_brands: Boolean(rows[0].remember_brands),
  };
}

/** Guarda los ajustes completos (crea la fila la primera vez). */
export async function save(
  userId: number,
  settings: AssistantSettings,
): Promise<void> {
  await pool.execute(
    `INSERT INTO user_assistant_settings (user_id, prioritize_cheapest, remember_brands)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE
       prioritize_cheapest = VALUES(prioritize_cheapest),
       remember_brands = VALUES(remember_brands),
       updated_at = CURRENT_TIMESTAMP`,
    [userId, settings.prioritize_cheapest, settings.remember_brands],
  );
}

/** Veces que el usuario eligió cada producto (en ítems distintos), los repetidos primero. */
export async function findFrequentProducts(
  userId: number,
): Promise<Array<{ product_id: number; times: number }>> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT event.product_id, COUNT(DISTINCT event.item_id) AS times
     FROM assistant_choice_events event
     JOIN (
       SELECT MAX(event_id) AS event_id FROM assistant_choice_events
       WHERE user_id = ? AND item_id IS NOT NULL GROUP BY item_id
     ) latest ON latest.event_id = event.event_id
     GROUP BY event.product_id
     HAVING COUNT(DISTINCT event.item_id) >= 2
     ORDER BY times DESC, event.product_id`,
    [userId],
  );
  return rows.map((row) => ({
    product_id: Number(row.product_id),
    times: Number(row.times),
  }));
}
