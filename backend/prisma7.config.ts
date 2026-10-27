import "dotenv/config";
import { defineConfig } from "prisma/config";

// Usa DATABASE_URL si existe; si no, la arma con las variables DB_* del backend.
function databaseUrl(): string | undefined {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const { DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME } = process.env;
  if (!DB_HOST || !DB_USER || !DB_NAME) return undefined;
  const user = encodeURIComponent(DB_USER);
  const password = encodeURIComponent(DB_PASSWORD ?? "");
  return `mysql://${user}:${password}@${DB_HOST}:${DB_PORT ?? "3306"}/${DB_NAME}`;
}

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: databaseUrl(),
  },
});
