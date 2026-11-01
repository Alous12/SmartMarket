import type { ResultSetHeader, RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type {
  IngredientListEntry,
  ShoppingList,
  ShoppingListItem,
  ShoppingListSource,
  ShoppingListStatus,
} from '../models/shopping-list.js';

interface ShoppingListRow extends RowDataPacket {
  list_id: number;
  user_id: number;
  branch_id: number;
  request_id: number | null;
  source: ShoppingListSource;
  status: ShoppingListStatus;
  created_at: Date;
  updated_at: Date;
}

interface ShoppingListItemRow extends RowDataPacket {
  item_id: number;
  ingredient_id: number | null;
  name: string;
  raw_name: string;
  normalized_name: string;
  // mysql2 devuelve DECIMAL como texto.
  quantity: string | null;
  unit: string | null;
}

function toItem(row: ShoppingListItemRow): ShoppingListItem {
  return {
    item_id: row.item_id,
    ingredient_id: row.ingredient_id,
    name: row.name,
    raw_name: row.raw_name,
    normalized_name: row.normalized_name,
    quantity: row.quantity === null ? null : Number(row.quantity),
    unit: row.unit,
  };
}

export async function findByRequest(
  requestId: number,
): Promise<ShoppingList | null> {
  const [lists] = await pool.execute<ShoppingListRow[]>(
    `SELECT list_id, user_id, branch_id, request_id, source, status,
            created_at, updated_at
     FROM shopping_lists WHERE request_id = ? LIMIT 1`,
    [requestId],
  );
  if (lists.length === 0) return null;
  const list = lists[0];

  const [items] = await pool.execute<ShoppingListItemRow[]>(
    `SELECT item.item_id,
            item.ingredient_id,
            COALESCE(ingredient.name, item.raw_name) AS name,
            item.raw_name,
            item.normalized_name,
            item.quantity,
            item.unit
     FROM shopping_list_items item
     LEFT JOIN ingredients ingredient
       ON ingredient.ingredient_id = item.ingredient_id
     WHERE item.list_id = ?
     ORDER BY item.item_id`,
    [list.list_id],
  );

  return {
    list_id: list.list_id,
    user_id: list.user_id,
    branch_id: list.branch_id,
    request_id: list.request_id,
    source: list.source,
    status: list.status,
    created_at: list.created_at,
    updated_at: list.updated_at,
    items: items.map(toItem),
  };
}

/**
 * Guarda la lista generada para una petición del asistente. Si la petición ya
 * tenía lista, sus elementos se reemplazan y conserva el mismo list_id.
 */
export async function saveForRequest(input: {
  userId: number;
  branchId: number;
  requestId: number;
  items: Array<IngredientListEntry & { ingredient_id: number | null }>;
}): Promise<ShoppingList> {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    // Bloquea la petición para que dos generaciones simultáneas no creen dos listas.
    await connection.execute(
      'SELECT request_id FROM assistant_requests WHERE request_id = ? FOR UPDATE',
      [input.requestId],
    );

    const [existing] = await connection.execute<RowDataPacket[]>(
      'SELECT list_id FROM shopping_lists WHERE request_id = ? LIMIT 1',
      [input.requestId],
    );
    let listId: number;
    if (existing.length > 0) {
      listId = existing[0].list_id as number;
      await connection.execute('DELETE FROM shopping_list_items WHERE list_id = ?', [
        listId,
      ]);
      await connection.execute(
        `UPDATE shopping_lists
         SET branch_id = ?, status = 'ACTIVE', updated_at = CURRENT_TIMESTAMP
         WHERE list_id = ?`,
        [input.branchId, listId],
      );
    } else {
      const [result] = await connection.execute<ResultSetHeader>(
        `INSERT INTO shopping_lists (user_id, branch_id, request_id, source, status)
         VALUES (?, ?, ?, 'AI', 'ACTIVE')`,
        [input.userId, input.branchId, input.requestId],
      );
      listId = result.insertId;
    }

    if (input.items.length > 0) {
      await connection.query(
        `INSERT INTO shopping_list_items
           (list_id, ingredient_id, raw_name, normalized_name, quantity, unit)
         VALUES ?`,
        [
          input.items.map((item) => [
            listId,
            item.ingredient_id,
            item.raw_name,
            item.normalized_name,
            item.quantity,
            item.unit,
          ]),
        ],
      );
    }
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }

  const list = await findByRequest(input.requestId);
  if (!list) {
    throw new Error('No se pudo recuperar la lista recién guardada.');
  }
  return list;
}
