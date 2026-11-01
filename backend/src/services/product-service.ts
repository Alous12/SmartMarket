import { HttpError } from '../middlewares/http-error.js';
import * as productRepository from '../repositories/product-repository.js';
import type {
  LocationInput,
  NewProduct,
} from '../repositories/product-repository.js';

type Body = Record<string, unknown>;

function asRecord(value: unknown): Body {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }
  return value as Body;
}

function rejectUnexpected(body: Body, allowed: string[]): void {
  const extra = Object.keys(body).find((field) => !allowed.includes(field));
  if (extra) throw new HttpError(400, `El campo ${extra} no está permitido.`);
}

function readText(
  body: Body,
  field: string,
  maxLength: number,
  required: boolean,
): string | null {
  const value = body[field];
  if (value === undefined || value === null) {
    if (required) throw new HttpError(400, `${field} es obligatorio.`);
    return null;
  }
  if (typeof value !== 'string' || !value.trim()) {
    throw new HttpError(400, `${field} debe ser texto no vacío.`);
  }
  const text = value.trim();
  if (text.length > maxLength) {
    throw new HttpError(400, `${field} no puede superar ${maxLength} caracteres.`);
  }
  return text;
}

function readNumber(
  body: Body,
  field: string,
  { min, max, integer = false }: { min: number; max: number; integer?: boolean },
): number {
  const value = body[field];
  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    (integer && !Number.isInteger(value)) ||
    value < min ||
    value > max
  ) {
    throw new HttpError(
      400,
      `${field} debe ser un número${integer ? ' entero' : ''} entre ${min} y ${max}.`,
    );
  }
  return value;
}

const coordinate = { min: -100000, max: 100000 };

function parseLocation(body: Body): LocationInput {
  return {
    sectionId: readNumber(body, 'section_id', {
      min: 1,
      max: 2147483647,
      integer: true,
    }),
    x: readNumber(body, 'coordinate_x', coordinate),
    y: readNumber(body, 'coordinate_y', coordinate),
    z: readNumber(body, 'coordinate_z', coordinate),
    shelf: readText(body, 'shelf', 100, false),
  };
}

export function parseNewProduct(rawBody: unknown): NewProduct {
  const body = asRecord(rawBody);
  rejectUnexpected(body, [
    'sku',
    'name',
    'description',
    'brand',
    'price',
    'unit_of_measure',
    'category_id',
    'stock_quantity',
    'section_id',
    'coordinate_x',
    'coordinate_y',
    'coordinate_z',
    'shelf',
  ]);
  return {
    sku: readText(body, 'sku', 100, true)!,
    name: readText(body, 'name', 150, true)!,
    description: readText(body, 'description', 5000, false),
    brand: readText(body, 'brand', 100, false),
    price: readNumber(body, 'price', { min: 0, max: 99999999 }),
    unitOfMeasure: readText(body, 'unit_of_measure', 50, true)!,
    categoryId: readNumber(body, 'category_id', {
      min: 1,
      max: 2147483647,
      integer: true,
    }),
    stock: readNumber(body, 'stock_quantity', { min: 0, max: 99999999 }),
    location: parseLocation(body),
  };
}

export function parseProductId(value: string | string[] | undefined): number {
  const id = typeof value === 'string' ? Number(value) : NaN;
  if (!Number.isSafeInteger(id) || id < 1) {
    throw new HttpError(400, 'El id de producto debe ser un entero positivo.');
  }
  return id;
}

export function parseBranchFilter(value: unknown): number | null {
  if (value === undefined) return null;
  const id = typeof value === 'string' ? Number(value) : NaN;
  if (!Number.isSafeInteger(id) || id < 1) {
    throw new HttpError(400, 'branch_id debe ser un entero positivo.');
  }
  return id;
}

export const listProducts = productRepository.list;
export const listOptions = productRepository.listOptions;

export async function createProduct(rawBody: unknown) {
  const product = parseNewProduct(rawBody);
  if (!(await productRepository.categoryExists(product.categoryId))) {
    throw new HttpError(400, 'category_id no existe.');
  }
  const branchId = await productRepository.findActiveSectionBranch(
    product.location.sectionId,
  );
  if (branchId === null) {
    throw new HttpError(400, 'section_id no pertenece a una sucursal activa.');
  }
  if (await productRepository.skuExists(product.sku)) {
    throw new HttpError(409, 'Ya existe un producto con ese sku.');
  }
  const productId = await productRepository.create(product, branchId);
  return productRepository.findLocations(productId);
}

export async function moveProduct(productId: number, rawBody: unknown) {
  const body = asRecord(rawBody);
  rejectUnexpected(body, [
    'section_id',
    'coordinate_x',
    'coordinate_y',
    'coordinate_z',
    'shelf',
  ]);
  const location = parseLocation(body);
  if (!(await productRepository.productExists(productId))) {
    throw new HttpError(404, 'Producto no encontrado.');
  }
  const branchId = await productRepository.findActiveSectionBranch(
    location.sectionId,
  );
  if (branchId === null) {
    throw new HttpError(400, 'section_id no pertenece a una sucursal activa.');
  }
  await productRepository.move(productId, branchId, location);
  return productRepository.findLocations(productId);
}
