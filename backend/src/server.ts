import { app } from './app.js';
import { port } from './config/environment.js';
import { pool } from './database/pool.js';

async function startServer(): Promise<void> {
  try {
    await pool.query('SELECT 1');
    app.listen(port, () => {
      console.info(`SmartMarket API escuchando en el puerto ${port}`);
    });
  } catch (error) {
    console.error('No se pudo conectar a MySQL; la API no se inició:', error);
    await pool.end();
    process.exitCode = 1;
  }
}

void startServer();
