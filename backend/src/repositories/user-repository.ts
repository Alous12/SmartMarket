import type { ResultSetHeader, RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type {
  UpdateUserInput,
  User,
  UserCredentials,
} from '../models/user.js';

interface UserRow extends RowDataPacket, User {}
interface UserCredentialsRow extends RowDataPacket, UserCredentials {}

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

export async function findBranchOf(
  userId: number,
): Promise<{ branch_id: number; model_3d_url: string | null } | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT b.branch_id, b.model_3d_url
     FROM users u JOIN branches b ON b.branch_id = u.branch_id
     WHERE u.user_id = ? LIMIT 1`,
    [userId],
  );
  return rows.length > 0
    ? {
        branch_id: rows[0].branch_id as number,
        model_3d_url: (rows[0].model_3d_url as string | null) ?? null,
      }
    : null;
}

export async function findAllManaged(): Promise<User[]> {
  const [rows] = await pool.execute<UserRow[]>(
    `SELECT ${publicUserColumns}
     FROM users
     WHERE role = 'user'
     ORDER BY user_id`,
  );
  return rows.map(toUser);
}

export async function findManagedById(userId: number): Promise<User | null> {
  const [rows] = await pool.execute<UserRow[]>(
    `SELECT ${publicUserColumns}
     FROM users
     WHERE user_id = ? AND role = 'user'
     LIMIT 1`,
    [userId],
  );
  return rows.length > 0 ? toUser(rows[0]) : null;
}

export async function findById(userId: number): Promise<User | null> {
  const [rows] = await pool.execute<UserRow[]>(
    `SELECT ${publicUserColumns} FROM users WHERE user_id = ? LIMIT 1`,
    [userId],
  );
  return rows.length > 0 ? toUser(rows[0]) : null;
}

export async function findCredentialsByEmail(
  email: string,
): Promise<UserCredentials | null> {
  const [rows] = await pool.execute<UserCredentialsRow[]>(
    `SELECT ${publicUserColumns}, password_hash
     FROM users WHERE email = ? LIMIT 1`,
    [email],
  );
  if (rows.length === 0) return null;
  return {
    ...toUser(rows[0]),
    password_hash: rows[0].password_hash,
  };
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
    return findManagedById(userId);
  }

  values.push(userId);
  await pool.execute(
    `UPDATE users SET ${updates.join(', ')}
     WHERE user_id = ? AND role = 'user'`,
    values,
  );
  return findManagedById(userId);
}

export async function deactivate(userId: number): Promise<boolean> {
  const [result] = await pool.execute<ResultSetHeader>(
    `UPDATE users
     SET status = FALSE
     WHERE user_id = ? AND status = TRUE AND role = 'user'`,
    [userId],
  );
  return result.affectedRows > 0;
}

/** Contraseña guardada del usuario, para comprobar la actual antes de cambiarla. */
export async function findPasswordHash(userId: number): Promise<string | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    'SELECT password_hash FROM users WHERE user_id = ? LIMIT 1',
    [userId],
  );
  return rows.length > 0 ? (rows[0].password_hash as string) : null;
}

/**
 * El propio usuario edita sus datos (cliente o trabajador). Solo toca nombre,
 * apellido, correo y contraseña; el rol, el estado y la sucursal no cambian.
 */
export async function updateOwn(
  userId: number,
  input: {
    name?: string;
    last_name?: string;
    email?: string;
    passwordHash?: string;
  },
): Promise<User | null> {
  const columns: Array<[keyof typeof input, string]> = [
    ['name', 'name'],
    ['last_name', 'last_name'],
    ['email', 'email'],
    ['passwordHash', 'password_hash'],
  ];
  const updates: string[] = [];
  const values: Array<string | number> = [];
  for (const [key, column] of columns) {
    const value = input[key];
    if (value !== undefined) {
      updates.push(`${column} = ?`);
      values.push(value);
    }
  }
  if (updates.length > 0) {
    updates.push('updated_at = CURRENT_TIMESTAMP', 'updated_by_user_id = ?');
    values.push(userId, userId);
    await pool.execute(
      `UPDATE users SET ${updates.join(', ')} WHERE user_id = ?`,
      values,
    );
  }
  return findById(userId);
}
