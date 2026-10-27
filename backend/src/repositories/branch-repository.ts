import type { RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';

export async function isActive(branchId: number): Promise<boolean> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    'SELECT 1 FROM branches WHERE branch_id = ? AND status = TRUE LIMIT 1',
    [branchId],
  );
  return rows.length > 0;
}
