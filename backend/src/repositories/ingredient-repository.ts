import type { RowDataPacket } from 'mysql2';

import { pool } from '../database/pool.js';
import type {
  IngredientProductMatch,
  IngredientSubstitution,
} from '../models/shopping-list.js';

interface IngredientRow extends RowDataPacket {
  ingredient_id: number;
  name: string;
}

interface AvailableIngredientProductRow extends RowDataPacket {
  ingredient_id: number;
  branch_id: number;
  product_id: number;
  sku: string;
  name: string;
  stock_quantity: string;
  section_name: string;
  shelf: string | null;
  price: string;
  unit_of_measure: string;
  brand: string | null;
  description: string | null;
}

interface IngredientSubstitutionRow extends RowDataPacket, IngredientSubstitution {}

/**
 * Busca ingredientes del catálogo por nombre. La colación de la tabla
 * (utf8mb4_unicode_ci) ignora mayúsculas y tildes.
 */
export async function findByNames(
  names: string[],
): Promise<Array<{ ingredient_id: number; name: string }>> {
  if (names.length === 0) return [];
  const [rows] = await pool.query<IngredientRow[]>(
    'SELECT ingredient_id, name FROM ingredients WHERE name IN (?)',
    [names],
  );
  return rows.map((row) => ({ ingredient_id: row.ingredient_id, name: row.name }));
}

/** Nombres de todo el catálogo de ingredientes, en orden alfabético. */
export async function findAllNames(): Promise<string[]> {
  const [rows] = await pool.query<IngredientRow[]>(
    'SELECT ingredient_id, name FROM ingredients ORDER BY name',
  );
  return rows.map((row) => row.name);
}

/**
 * Productos activos con stock de esos ingredientes en todas las sucursales
 * activas, junto con su ubicación en cada una. Los nombres más cortos van primero:
 * son los más genéricos ("Leche entera" antes que "Leche deslactosada").
 */
export async function findAvailableProducts(
  ingredientIds: number[],
): Promise<IngredientProductMatch[]> {
  if (ingredientIds.length === 0) return [];

  const [rows] = await pool.query<AvailableIngredientProductRow[]>(
    `SELECT pi.ingredient_id, i.branch_id, p.product_id, p.sku, p.name,
            i.stock_quantity, s.name AS section_name, pl.shelf,
            p.price, p.unit_of_measure, p.brand, p.description
     FROM product_ingredients pi
     JOIN products p ON p.product_id = pi.product_id AND p.status = TRUE
     JOIN inventory i ON i.product_id = p.product_id AND i.stock_quantity > 0
     JOIN branches b ON b.branch_id = i.branch_id AND b.status = TRUE
     JOIN product_locations pl ON pl.product_id = p.product_id
     JOIN sections s ON s.section_id = pl.section_id AND s.branch_id = i.branch_id
     WHERE pi.ingredient_id IN (?)
     ORDER BY pi.ingredient_id, CHAR_LENGTH(p.name), p.name, p.product_id`,
    [ingredientIds],
  );

  return rows.map((row) => ({
    ingredient_id: row.ingredient_id,
    branch_id: row.branch_id,
    product_id: row.product_id,
    sku: row.sku,
    name: row.name,
    stock_quantity: Number(row.stock_quantity),
    section_name: row.section_name,
    shelf: row.shelf,
    price: Number(row.price),
    unit_of_measure: row.unit_of_measure,
    brand: row.brand,
    description: row.description,
  }));
}

/** Alternativas de esos ingredientes, de la mejor a la peor. */
export async function findSubstitutions(
  ingredientIds: number[],
): Promise<IngredientSubstitution[]> {
  if (ingredientIds.length === 0) return [];

  const [rows] = await pool.query<IngredientSubstitutionRow[]>(
    `SELECT sub.ingredient_id, sub.substitute_ingredient_id,
            ingredient.name AS substitute_name, sub.priority
     FROM ingredient_substitutes sub
     JOIN ingredients ingredient
       ON ingredient.ingredient_id = sub.substitute_ingredient_id
     WHERE sub.ingredient_id IN (?)
     ORDER BY sub.ingredient_id, sub.priority`,
    [ingredientIds],
  );
  return rows;
}
