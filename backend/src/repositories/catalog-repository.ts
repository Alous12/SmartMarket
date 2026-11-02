import type { RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type {
  Branch,
  BranchPoint,
  BranchProduct,
  Category,
  ProductFilters,
  ProductLocation,
  Section,
} from '../models/catalog.js';

const maxProducts = 500;

// mysql2 devuelve los DECIMAL como texto; la API los expone como números.
const toNumber = (value: unknown): number => Number(value);

function mapBranch(row: RowDataPacket): Branch {
  return {
    branch_id: row.branch_id,
    name: row.name,
    address: row.address,
    latitude: toNumber(row.latitude),
    longitude: toNumber(row.longitude),
    status: Boolean(row.status),
    model_3d_url: row.model_3d_url,
  };
}

export async function findBranches(): Promise<Branch[]> {
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT branch_id, name, address, latitude, longitude, status, model_3d_url
     FROM branches WHERE status = TRUE ORDER BY branch_id`,
  );
  return rows.map(mapBranch);
}

export async function findBranchById(branchId: number): Promise<Branch | null> {
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT branch_id, name, address, latitude, longitude, status, model_3d_url
     FROM branches WHERE branch_id = ? AND status = TRUE LIMIT 1`,
    [branchId],
  );
  return rows[0] ? mapBranch(rows[0]) : null;
}

export async function findPointsByBranch(
  branchId: number,
): Promise<BranchPoint[]> {
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT point_id, branch_id, name, point_type,
            coordinate_x, coordinate_y, coordinate_z
     FROM branch_points WHERE branch_id = ? ORDER BY point_id`,
    [branchId],
  );
  return rows.map((row) => ({
    point_id: row.point_id,
    branch_id: row.branch_id,
    name: row.name,
    point_type: row.point_type,
    coordinate_x: toNumber(row.coordinate_x),
    coordinate_y: toNumber(row.coordinate_y),
    coordinate_z: toNumber(row.coordinate_z),
  }));
}

export async function findSectionsByBranch(
  branchId: number,
): Promise<Section[]> {
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT section_id, branch_id, name, description
     FROM sections WHERE branch_id = ? ORDER BY section_id`,
    [branchId],
  );
  return rows as Section[];
}

export async function findCategories(): Promise<Category[]> {
  const [rows] = await pool.query<RowDataPacket[]>(
    'SELECT category_id, name, description FROM categories ORDER BY name',
  );
  return rows as Category[];
}

async function findLocations(
  branchId: number,
  productIds: number[],
): Promise<Map<number, ProductLocation[]>> {
  const byProduct = new Map<number, ProductLocation[]>();
  if (!productIds.length) return byProduct;
  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT pl.product_id, pl.product_location_id, pl.section_id,
            s.name AS section_name, pl.coordinate_x, pl.coordinate_y,
            pl.coordinate_z, pl.shelf
     FROM product_locations pl
     JOIN sections s ON s.section_id = pl.section_id
     WHERE s.branch_id = ? AND pl.product_id IN (?)
     ORDER BY pl.product_location_id`,
    [branchId, productIds],
  );
  for (const row of rows) {
    const list = byProduct.get(row.product_id) ?? [];
    list.push({
      product_location_id: row.product_location_id,
      section_id: row.section_id,
      section_name: row.section_name,
      coordinate_x: toNumber(row.coordinate_x),
      coordinate_y: toNumber(row.coordinate_y),
      coordinate_z: toNumber(row.coordinate_z),
      shelf: row.shelf,
    });
    byProduct.set(row.product_id, list);
  }
  return byProduct;
}

export async function findProductsByBranch(
  branchId: number,
  filters: ProductFilters,
): Promise<BranchProduct[]> {
  const conditions = ['p.status = TRUE'];
  const params: unknown[] = [branchId];
  if (filters.categoryId !== undefined) {
    conditions.push('p.category_id = ?');
    params.push(filters.categoryId);
  }
  if (filters.search) {
    conditions.push('(p.name LIKE ? OR p.sku LIKE ? OR p.brand LIKE ?)');
    const pattern = `%${filters.search.replace(/[\\%_]/g, '\\$&')}%`;
    params.push(pattern, pattern, pattern);
  }
  if (filters.productIds?.length) {
    conditions.push('p.product_id IN (?)');
    params.push(filters.productIds);
  }

  const [rows] = await pool.query<RowDataPacket[]>(
    `SELECT p.product_id, p.sku, p.name, p.brand, p.price, p.unit_of_measure,
            p.image_url, p.category_id, c.name AS category_name,
            COALESCE(i.stock_quantity, 0) AS stock_quantity
     FROM products p
     JOIN categories c ON c.category_id = p.category_id
     LEFT JOIN inventory i
       ON i.product_id = p.product_id AND i.branch_id = ?
     WHERE ${conditions.join(' AND ')}
     ORDER BY p.name
     LIMIT ${maxProducts}`,
    params,
  );
  const locations = await findLocations(
    branchId,
    rows.map((row) => row.product_id),
  );
  return rows.map((row) => ({
    product_id: row.product_id,
    sku: row.sku,
    name: row.name,
    brand: row.brand,
    price: toNumber(row.price),
    unit_of_measure: row.unit_of_measure,
    image_url: row.image_url,
    category_id: row.category_id,
    category_name: row.category_name,
    stock_quantity: toNumber(row.stock_quantity),
    locations: locations.get(row.product_id) ?? [],
  }));
}
