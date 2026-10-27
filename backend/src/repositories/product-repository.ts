import type { ResultSetHeader, RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';

export interface ProductLocationRow extends RowDataPacket {
  product_id: number;
  sku: string;
  name: string;
  price: string;
  unit_of_measure: string;
  category_id: number;
  branch_id: number | null;
  branch_name: string | null;
  section_id: number | null;
  section_name: string | null;
  coordinate_x: string | null;
  coordinate_y: string | null;
  coordinate_z: string | null;
  shelf: string | null;
  stock_quantity: string | null;
}

export interface NewProduct {
  sku: string;
  name: string;
  description: string | null;
  brand: string | null;
  price: number;
  unitOfMeasure: string;
  categoryId: number;
  stock: number;
  location: LocationInput;
}

export interface LocationInput {
  sectionId: number;
  x: number;
  y: number;
  z: number;
  shelf: string | null;
}

const listQuery = `
  SELECT p.product_id, p.sku, p.name, p.price, p.unit_of_measure,
         p.category_id, s.branch_id, b.name AS branch_name,
         s.section_id, s.name AS section_name,
         pl.coordinate_x, pl.coordinate_y, pl.coordinate_z, pl.shelf,
         i.stock_quantity
  FROM products p
  LEFT JOIN product_locations pl ON pl.product_id = p.product_id
  LEFT JOIN sections s ON s.section_id = pl.section_id
  LEFT JOIN branches b ON b.branch_id = s.branch_id
  LEFT JOIN inventory i
    ON i.product_id = p.product_id AND i.branch_id = s.branch_id
`;

export async function list(branchId: number | null): Promise<ProductLocationRow[]> {
  const [rows] = await pool.execute<ProductLocationRow[]>(
    `${listQuery} WHERE p.status = TRUE
       ${branchId === null ? '' : 'AND s.branch_id = ?'}
     ORDER BY p.name`,
    branchId === null ? [] : [branchId],
  );
  return rows;
}

export async function findLocations(
  productId: number,
): Promise<ProductLocationRow[]> {
  const [rows] = await pool.execute<ProductLocationRow[]>(
    `${listQuery} WHERE p.product_id = ?`,
    [productId],
  );
  return rows;
}

export async function categoryExists(categoryId: number): Promise<boolean> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    'SELECT 1 FROM categories WHERE category_id = ? LIMIT 1',
    [categoryId],
  );
  return rows.length > 0;
}

export async function findActiveSectionBranch(
  sectionId: number,
): Promise<number | null> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT s.branch_id FROM sections s
     JOIN branches b ON b.branch_id = s.branch_id
     WHERE s.section_id = ? AND b.status = TRUE LIMIT 1`,
    [sectionId],
  );
  return rows.length > 0 ? (rows[0].branch_id as number) : null;
}

export async function productExists(productId: number): Promise<boolean> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    'SELECT 1 FROM products WHERE product_id = ? AND status = TRUE LIMIT 1',
    [productId],
  );
  return rows.length > 0;
}

export async function skuExists(sku: string): Promise<boolean> {
  const [rows] = await pool.execute<RowDataPacket[]>(
    'SELECT 1 FROM products WHERE sku = ? LIMIT 1',
    [sku],
  );
  return rows.length > 0;
}

export async function create(
  product: NewProduct,
  branchId: number,
): Promise<number> {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [result] = await connection.execute<ResultSetHeader>(
      `INSERT INTO products
         (sku, name, description, brand, price, unit_of_measure, category_id)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        product.sku,
        product.name,
        product.description,
        product.brand,
        product.price,
        product.unitOfMeasure,
        product.categoryId,
      ],
    );
    const productId = result.insertId;
    await connection.execute(
      `INSERT INTO inventory (branch_id, product_id, stock_quantity)
       VALUES (?, ?, ?)`,
      [branchId, productId, product.stock],
    );
    await connection.execute(
      `INSERT INTO product_locations
         (product_id, section_id, coordinate_x, coordinate_y, coordinate_z, shelf)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        productId,
        product.location.sectionId,
        product.location.x,
        product.location.y,
        product.location.z,
        product.location.shelf,
      ],
    );
    await connection.commit();
    return productId;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

/** Mueve el producto dentro de la sucursal de la sección destino. */
export async function move(
  productId: number,
  branchId: number,
  location: LocationInput,
): Promise<void> {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [existing] = await connection.execute<RowDataPacket[]>(
      `SELECT pl.product_location_id FROM product_locations pl
       JOIN sections s ON s.section_id = pl.section_id
       WHERE pl.product_id = ? AND s.branch_id = ?
       ORDER BY pl.product_location_id LIMIT 1 FOR UPDATE`,
      [productId, branchId],
    );
    const values = [
      location.sectionId,
      location.x,
      location.y,
      location.z,
      location.shelf,
    ];
    if (existing.length > 0) {
      await connection.execute(
        `UPDATE product_locations
         SET section_id = ?, coordinate_x = ?, coordinate_y = ?,
             coordinate_z = ?, shelf = ?
         WHERE product_location_id = ?`,
        [...values, existing[0].product_location_id],
      );
    } else {
      await connection.execute(
        `INSERT INTO product_locations
           (section_id, coordinate_x, coordinate_y, coordinate_z, shelf, product_id)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [...values, productId],
      );
      await connection.execute(
        `INSERT IGNORE INTO inventory (branch_id, product_id, stock_quantity)
         VALUES (?, ?, 0)`,
        [branchId, productId],
      );
    }
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

export async function listOptions(): Promise<{
  categories: RowDataPacket[];
  sections: RowDataPacket[];
}> {
  const [categories] = await pool.execute<RowDataPacket[]>(
    'SELECT category_id, name FROM categories ORDER BY name',
  );
  const [sections] = await pool.execute<RowDataPacket[]>(
    `SELECT s.section_id, s.name, s.branch_id, b.name AS branch_name
     FROM sections s JOIN branches b ON b.branch_id = s.branch_id
     WHERE b.status = TRUE ORDER BY b.name, s.name`,
  );
  return { categories, sections };
}
