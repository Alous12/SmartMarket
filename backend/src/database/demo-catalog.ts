import { matchIngredients, normalizeName, type SeedBranchData } from './glb-seed-data.js';

export interface ProductOverride {
  sku: string;
  /** Nombre que trae el modelo: solo se reemplaza si nadie lo editó. */
  from: string;
  name: string;
  category: string;
}

/**
 * Productos que los .glb no traen. Todos los espacios del modelo están ocupados,
 * así que toman el lugar de cajas de relleno (promociones o repetidos) para
 * conservar su posición en el mapa y su nodo de ruta.
 */
export const productOverrides: Record<string, ProductOverride[]> = {
  supermercado_1: [
    { sku: 'GRP_0014', from: 'Azucar', name: 'Canela', category: 'Despensa' },
  ],
  supermercado_2: [
    { sku: 'PIL_0016', from: 'Oferta semanal', name: 'Ajo', category: 'Verduras' },
    { sku: 'PIL_0017', from: 'Pack ahorro', name: 'Papa', category: 'Verduras' },
    { sku: 'PIL_0134', from: 'Ofertas', name: 'Pimentón', category: 'Verduras' },
    { sku: 'PIL_0100', from: 'Snacks', name: 'Orégano', category: 'Aceites y condimentos' },
    { sku: 'PIL_0120', from: 'Bebidas', name: 'Canela', category: 'Aceites y condimentos' },
  ],
};

/**
 * Vínculos que el nombre del producto no permite deducir. Una lista vacía indica
 * que el producto no sirve como ese ingrediente (unas papas chips no son papa).
 */
const ingredientLinks: Record<string, string[]> = {
  res: ['Carne de res'],
  'filete de pescado': ['Pescado'],
  trucha: ['Pescado'],
  banana: ['Plátano'],
  lasagna: ['Masa para lasaña'],
  salsa: ['Salsa de tomate'],
  spaghetti: ['Fideo'],
  tallarines: ['Fideo'],
  macarron: ['Fideo'],
  verduras: ['Verduras mixtas'],
  'mix de verduras': ['Verduras mixtas'],
  papas: [],
  'papas chips': [],
  'papas fritas': [],
  'pollo listo': [],
  'pollo al horno': [],
  'mantequilla de mani': [],
  'leche infantil': [],
};

export function applyProductOverrides(
  data: SeedBranchData,
  overrides: ProductOverride[],
): SeedBranchData {
  const bySku = new Map(overrides.map((override) => [override.sku, override]));
  return {
    ...data,
    products: data.products.map((product) => {
      const override = bySku.get(product.sku);
      return override
        ? { ...product, name: override.name, category: override.category }
        : product;
    }),
  };
}

/** Ingredientes del catálogo que el producto permite comprar. */
export function ingredientsForProduct<T extends { name: string }>(
  productName: string,
  ingredients: T[],
): T[] {
  const linked = ingredientLinks[normalizeName(productName)];
  return linked === undefined
    ? matchIngredients(productName, ingredients)
    : ingredients.filter((ingredient) => linked.includes(ingredient.name));
}
