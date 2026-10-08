import 'dotenv/config';

import mysql from 'mysql2/promise';

const { DB_HOST, DB_USER, DB_NAME } = process.env;
const parsedDatabasePort = Number.parseInt(process.env.DB_PORT ?? '3306', 10);

if (!DB_HOST || !DB_USER || !DB_NAME) {
  throw new Error(
    'Faltan DB_HOST, DB_USER o DB_NAME. Copia backend/.env.example a backend/.env y configura los datos de MySQL.',
  );
}

if (
  !Number.isInteger(parsedDatabasePort) ||
  parsedDatabasePort < 1 ||
  parsedDatabasePort > 65535
) {
  throw new Error('DB_PORT debe ser un número entre 1 y 65535.');
}

export const pool = mysql.createPool({
  host: DB_HOST,
  port: parsedDatabasePort,
  user: DB_USER,
  password: process.env.DB_PASSWORD ?? '',
  database: DB_NAME,
  connectionLimit: 10,
  waitForConnections: true,
});
