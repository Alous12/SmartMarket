import type { RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type { BranchSummary } from '../models/shopping-list.js';

interface BranchSummaryRow extends RowDataPacket, BranchSummary {}

export async function isActive(branchId: number): Promise<boolean> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    'SELECT 1 FROM branches WHERE branch_id = ? AND status = TRUE LIMIT 1',
    [branchId],
  );
  return rows.length > 0;
}

export async function findActive(): Promise<BranchSummary[]> {
  const [rows] = await pool.query<BranchSummaryRow[]>(
    'SELECT branch_id, name, model_3d_url FROM branches WHERE status = TRUE ORDER BY branch_id',
  );
  return rows;
}
