import type { ResultSetHeader, RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type { UpdateUserInput, User } from '../models/user.js';

interface UserRow extends RowDataPacket, User {}

const publicUserColumns = `
  user_id,
  name,
  last_name,
  email,
  role,
  status,
  created_at,
  created_by_user_id,
  updated_at,
  updated_by_user_id
`;

function toUser(row: UserRow): User {
  if (row.role !== 'user' && row.role !== 'admin') {
    throw new Error(`La base de datos contiene un rol no soportado: ${row.role}`);
  }
  return {
    user_id: row.user_id,
    name: row.name,
    last_name: row.last_name,
    email: row.email,
    role: row.role,
    status: Boolean(row.status),
    created_at: row.created_at,
    created_by_user_id: row.created_by_user_id,
    updated_at: row.updated_at,
    updated_by_user_id: row.updated_by_user_id,
  };
}

export async function findAll(): Promise<User[]> {
  const [rows] = await pool.execute<UserRow[]>(
    `SELECT ${publicUserColumns} FROM users ORDER BY user_id`,
  );
  return rows.map(toUser);
}

export async function findById(userId: number): Promise<User | null> {
  const [rows] = await pool.execute<UserRow[]>(
    `SELECT ${publicUserColumns} FROM users WHERE user_id = ? LIMIT 1`,
    [userId],
  );
  return rows.length > 0 ? toUser(rows[0]) : null;
}

export async function create(
  input: {
    name: string;
    lastName: string;
    email: string;
    passwordHash: string;
  },
): Promise<User> {
  const [result] = await pool.execute<ResultSetHeader>(
    `INSERT INTO users (name, last_name, email, password_hash, role)
     VALUES (?, ?, ?, ?, 'user')`,
    [input.name, input.lastName, input.email, input.passwordHash],
  );

  const user = await findById(result.insertId);
  if (!user) {
    throw new Error('No se pudo recuperar el usuario recién creado.');
  }
  return user;
}

export async function update(
  userId: number,
  input: UpdateUserInput & { passwordHash?: string },
): Promise<User | null> {
  const columns: Array<[keyof typeof input, string]> = [
    ['name', 'name'],
    ['last_name', 'last_name'],
    ['email', 'email'],
    ['status', 'status'],
    ['passwordHash', 'password_hash'],
  ];
  const updates: string[] = [];
  const values: Array<string | number> = [];

  for (const [key, column] of columns) {
    const value = input[key];
    if (value !== undefined) {
      updates.push(`${column} = ?`);
      values.push(typeof value === 'boolean' ? Number(value) : value);
    }
  }

  if (updates.length === 0) {
    return findById(userId);
  }

  values.push(userId);
  await pool.execute(
    `UPDATE users SET ${updates.join(', ')} WHERE user_id = ?`,
    values,
  );
  return findById(userId);
}

export async function deactivate(userId: number): Promise<boolean> {
  const [result] = await pool.execute<ResultSetHeader>(
    'UPDATE users SET status = FALSE WHERE user_id = ? AND status = TRUE',
    [userId],
  );
  return result.affectedRows > 0;
}
