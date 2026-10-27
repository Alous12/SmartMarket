import type { ResultSetHeader, RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type {
  AssistantRequest,
  AssistantRequestStatus,
} from '../models/assistant-request.js';

interface AssistantRequestRow extends RowDataPacket, AssistantRequest {}

const columns = `
  request_id,
  user_id,
  branch_id,
  prompt,
  status,
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
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
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
