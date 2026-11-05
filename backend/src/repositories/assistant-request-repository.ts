import type { ResultSetHeader, RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type {
  AssistantRequest,
  AssistantRequestStatus,
  RecipeHistoryEntry,
} from '../models/assistant-request.js';

interface AssistantRequestRow extends RowDataPacket, AssistantRequest {}

interface RecipeHistoryRow extends RowDataPacket, RecipeHistoryEntry {}

const columns = `
  request_id,
  user_id,
  branch_id,
  prompt,
  status,
  recipe_name,
  response_message,
  created_at,
  updated_at
`;

export async function findById(
  requestId: number,
): Promise<AssistantRequest | null> {
  const [rows] = await pool.execute<AssistantRequestRow[]>(
    `SELECT ${columns} FROM assistant_requests WHERE request_id = ? LIMIT 1`,
    [requestId],
  );
  if (rows.length === 0) return null;
  const row = rows[0];
  return {
    request_id: row.request_id,
    user_id: row.user_id,
    branch_id: row.branch_id,
    prompt: row.prompt,
    status: row.status,
    recipe_name: row.recipe_name,
    response_message: row.response_message,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

/** Recetas completadas del usuario que tienen lista, de la más nueva a la más antigua. */
export async function findCompletedRecipes(
  userId: number,
): Promise<RecipeHistoryEntry[]> {
  const [rows] = await pool.execute<RecipeHistoryRow[]>(
    `SELECT request.request_id, request.recipe_name, list.branch_id,
            COUNT(item.item_id) AS ingredient_count, request.created_at
     FROM assistant_requests request
     JOIN shopping_lists list ON list.request_id = request.request_id
     JOIN shopping_list_items item ON item.list_id = list.list_id
     WHERE request.user_id = ?
       AND request.status = 'COMPLETED'
       AND request.recipe_name IS NOT NULL
     GROUP BY request.request_id, request.recipe_name, list.branch_id,
              request.created_at
     ORDER BY request.request_id DESC`,
    [userId],
  );
  return rows.map((row) => ({
    request_id: row.request_id,
    recipe_name: row.recipe_name,
    branch_id: row.branch_id,
    ingredient_count: Number(row.ingredient_count),
    created_at: row.created_at,
  }));
}

export async function create(input: {
  userId: number;
  branchId: number | null;
  prompt: string;
}): Promise<AssistantRequest> {
  const [result] = await pool.execute<ResultSetHeader>(
    `INSERT INTO assistant_requests (user_id, branch_id, prompt, status)
     VALUES (?, ?, ?, 'RECEIVED')`,
    [input.userId, input.branchId, input.prompt],
  );

  const request = await findById(result.insertId);
  if (!request) {
    throw new Error('No se pudo recuperar la petición recién guardada.');
  }
  return request;
}

export async function updateStatus(
  requestId: number,
  status: AssistantRequestStatus,
): Promise<AssistantRequest | null> {
  await pool.execute(
    `UPDATE assistant_requests
     SET status = ?, updated_at = CURRENT_TIMESTAMP
     WHERE request_id = ?`,
    [status, requestId],
  );
  return findById(requestId);
}

/**
 * Guarda el resultado del análisis de la IA: estado final o intermedio, receta
 * identificada y mensaje para el usuario.
 */
export async function saveAnalysis(
  requestId: number,
  analysis: {
    status: AssistantRequestStatus;
    recipeName: string | null;
    message: string | null;
  },
): Promise<void> {
  await pool.execute(
    `UPDATE assistant_requests
     SET status = ?, recipe_name = ?, response_message = ?,
         updated_at = CURRENT_TIMESTAMP
     WHERE request_id = ?`,
    [analysis.status, analysis.recipeName, analysis.message, requestId],
  );
}
