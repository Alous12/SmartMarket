import { HttpError } from '../middlewares/http-error.js';
import type {
  Branch,
  BranchPoint,
  BranchProduct,
  Category,
  ProductFilters,
  Section,
} from '../models/catalog.js';
import * as catalogRepository from '../repositories/catalog-repository.js';

const maxIds = 100;

export function parseId(value: unknown, label: string): number {
  const id = typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : NaN;
  if (!Number.isSafeInteger(id) || id < 1) {
    throw new HttpError(400, `${label} debe ser un entero positivo.`);
  }
  return id;
}

export function parseProductFilters(query: Record<string, unknown>): ProductFilters {
  const filters: ProductFilters = {};
  if (query.search !== undefined) {
    if (typeof query.search !== 'string' || query.search.length > 100) {
      throw new HttpError(400, 'search debe ser un texto de hasta 100 caracteres.');
    }
    const search = query.search.trim();
    if (search) filters.search = search;
  }
  if (query.categoryId !== undefined) {
    filters.categoryId = parseId(query.categoryId, 'categoryId');
  }
  if (query.productIds !== undefined) {
    if (typeof query.productIds !== 'string') {
      throw new HttpError(400, 'productIds debe ser una lista separada por comas.');
    }
    const ids = query.productIds.split(',').map((id) => parseId(id.trim(), 'productIds'));
    if (ids.length > maxIds) {
      throw new HttpError(400, `productIds admite hasta ${maxIds} valores.`);
    }
    filters.productIds = [...new Set(ids)];
  }
  return filters;
}

export function listBranches(): Promise<Branch[]> {
  return catalogRepository.findBranches();
}

export async function getBranch(branchId: number): Promise<Branch> {
  const branch = await catalogRepository.findBranchById(branchId);
  if (!branch) throw new HttpError(404, 'Sucursal no encontrada.');
  return branch;
}

export async function listPoints(branchId: number): Promise<BranchPoint[]> {
  await getBranch(branchId);
  return catalogRepository.findPointsByBranch(branchId);
}

export async function listSections(branchId: number): Promise<Section[]> {
  await getBranch(branchId);
  return catalogRepository.findSectionsByBranch(branchId);
}

export function listCategories(): Promise<Category[]> {
  return catalogRepository.findCategories();
}

export async function listProducts(
  branchId: number,
  filters: ProductFilters,
): Promise<BranchProduct[]> {
  await getBranch(branchId);
  return catalogRepository.findProductsByBranch(branchId, filters);
}

export async function getProduct(
  branchId: number,
  productId: number,
): Promise<BranchProduct> {
  await getBranch(branchId);
  const [product] = await catalogRepository.findProductsByBranch(branchId, {
    productIds: [productId],
  });
  if (!product) throw new HttpError(404, 'Producto no encontrado.');
  return product;
}
