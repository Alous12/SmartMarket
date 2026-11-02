import { fileURLToPath } from 'node:url';

import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import type { PoolConnection } from 'mysql2/promise';

import { pool } from './pool.js';
import {
  demoPrice,
  matchIngredients,
  readBranchModel,
  type SeedBranchData,
} from './glb-seed-data.js';

const stockPerBox = 10;

const modelsDir = fileURLToPath(new URL('../../../Modelos_3D/', import.meta.url));

async function idMap(
  connection: PoolConnection,
  sql: string,
  params: unknown[],
  key: string,
  id: string,
): Promise<Map<string, number>> {
  const [rows] = await connection.query<RowDataPacket[]>(sql, params);
  return new Map(rows.map((row) => [String(row[key]), row[id] as number]));
}

/** Carga (sin duplicar ni pisar ediciones) los datos de un modelo en su sucursal. */
async function seedBranch(
  connection: PoolConnection,
  modelUrl: string,
  data: SeedBranchData,
) {
  const [branches] = await connection.query<RowDataPacket[]>(
    'SELECT branch_id, name FROM branches WHERE model_3d_url = ? LIMIT 1',
    [modelUrl],
  );
  if (branches.length === 0) throw new Error(`No hay sucursal para ${modelUrl}.`);
  const branchId = branches[0].branch_id as number;

  const categories = [...new Set(data.products.map((p) => p.category))];
  await connection.query('INSERT IGNORE INTO categories (name) VALUES ?', [
    categories.map((name) => [name]),
  ]);
  const categoryIds = await idMap(
    connection,
    'SELECT category_id, name FROM categories WHERE name IN (?)',
    [categories],
    'name',
    'category_id',
  );

  const existingSections = await idMap(
    connection,
    'SELECT section_id, name FROM sections WHERE branch_id = ?',
    [branchId],
    'name',
    'section_id',
  );
  const missingSections = data.sections.filter((name) => !existingSections.has(name));
  if (missingSections.length > 0) {
    await connection.query('INSERT INTO sections (branch_id, name) VALUES ?', [
      missingSections.map((name) => [branchId, name]),
    ]);
  }
  const sectionIds = await idMap(
    connection,
    'SELECT section_id, name FROM sections WHERE branch_id = ?',
    [branchId],
    'name',
    'section_id',
  );

  await connection.query('DELETE FROM branch_points WHERE branch_id = ?', [branchId]);
  if (data.points.length > 0) {
    await connection.query(
      `INSERT INTO branch_points
         (branch_id, name, point_type, coordinate_x, coordinate_y, coordinate_z)
       VALUES ?`,
      [data.points.map((p) => [branchId, p.name, p.type, p.x, p.y, p.z])],
    );
  }

  const skus = data.products.map((p) => p.sku);
  const knownProducts = await idMap(
    connection,
    'SELECT product_id, sku FROM products WHERE sku IN (?)',
    [skus],
    'sku',
    'product_id',
  );
  const newProducts = data.products.filter((p) => !knownProducts.has(p.sku));
  if (newProducts.length > 0) {
    await connection.query(
      `INSERT INTO products (sku, name, price, unit_of_measure, category_id)
       VALUES ?`,
      [
        newProducts.map((p) => [
          p.sku,
          p.name,
          demoPrice(p.sku),
          'unidad',
          categoryIds.get(p.category),
        ]),
      ],
    );
  }
  const productIds = await idMap(
    connection,
    'SELECT product_id, sku FROM products WHERE sku IN (?)',
    [skus],
    'sku',
    'product_id',
  );

  const [located] = await connection.query<RowDataPacket[]>(
    `SELECT pl.product_id FROM product_locations pl
     JOIN sections s ON s.section_id = pl.section_id
     WHERE s.branch_id = ?`,
    [branchId],
  );
  const alreadyLocated = new Set(located.map((row) => row.product_id as number));
  const newLocations = data.products.filter(
    (p) => !alreadyLocated.has(productIds.get(p.sku)!),
  );
  if (newLocations.length > 0) {
    await connection.query(
      `INSERT INTO product_locations
         (product_id, section_id, coordinate_x, coordinate_y, coordinate_z, shelf)
       VALUES ?`,
      [
        newLocations.map((p) => [
          productIds.get(p.sku),
          sectionIds.get(p.section),
          p.x,
          p.y,
          p.z,
          p.shelf,
        ]),
      ],
    );
  }

  const [inventory] = await connection.query<ResultSetHeader>(
    'INSERT IGNORE INTO inventory (branch_id, product_id, stock_quantity) VALUES ?',
    [data.products.map((p) => [branchId, productIds.get(p.sku), p.boxCount * stockPerBox])],
  );

  const [ingredients] = await connection.query<RowDataPacket[]>(
    'SELECT ingredient_id, name FROM ingredients',
  );
  const links = data.products.flatMap((p) =>
    matchIngredients(p.name, ingredients as Array<{ name: string; ingredient_id: number }>).map(
      (ingredient) => [productIds.get(p.sku), ingredient.ingredient_id],
    ),
  );
  if (links.length > 0) {
    await connection.query(
      'INSERT IGNORE INTO product_ingredients (product_id, ingredient_id) VALUES ?',
      [links],
    );
  }

  console.log(
    `${branches[0].name}: ${data.sections.length} secciones, ${data.points.length} puntos, ` +
      `${data.products.length} productos (${newProducts.length} nuevos), ` +
      `${newLocations.length} ubicaciones nuevas, ${inventory.affectedRows} registros de stock, ` +
      `${links.length} vínculos con ingredientes.`,
  );
}

const models = ['supermercado_1', 'supermercado_2'];

const connection = await pool.getConnection();
try {
  await connection.beginTransaction();
  for (const model of models) {
    await seedBranch(
      connection,
      `Modelos_3D/${model}.glb`,
      readBranchModel(`${modelsDir}${model}.glb`),
    );
  }
  await connection.commit();
} catch (error) {
  await connection.rollback();
  throw error;
} finally {
  connection.release();
  await pool.end();
}
