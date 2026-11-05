import type {
  AvailableIngredientProduct,
  BranchSummary,
  IngredientAvailabilityItem,
  IngredientProductMatch,
  IngredientSubstitution,
  ShoppingListItem,
  ShoppingRoute,
  ShoppingRouteStop,
  SubstituteInBranch,
} from '../models/shopping-list.js';

export interface AvailabilityInput {
  items: ShoppingListItem[];
  /** Sucursal seleccionada en la petición. */
  branchId: number;
  branches: BranchSummary[];
  products: IngredientProductMatch[];
  /** Alternativas ordenadas de mejor a peor. */
  substitutions: IngredientSubstitution[];
}

export interface AvailabilityResult {
  items: IngredientAvailabilityItem[];
  routes: ShoppingRoute[];
}

function toProduct({
  product_id,
  sku,
  name,
  stock_quantity,
  section_name,
  shelf,
}: IngredientProductMatch): AvailableIngredientProduct {
  return { product_id, sku, name, stock_quantity, section_name, shelf };
}

/**
 * Cruza la lista con el inventario de todas las sucursales. Cada ingrediente se
 * clasifica según la sucursal seleccionada, e informa además en qué otras
 * sucursales está y qué alternativa hay donde falta.
 */
export function buildIngredientAvailability({
  items,
  branchId,
  branches,
  products,
  substitutions,
}: AvailabilityInput): AvailabilityResult {
  const inventory = new Map<string, IngredientProductMatch[]>();
  for (const product of products) {
    const key = `${product.branch_id}:${product.ingredient_id}`;
    inventory.set(key, [...(inventory.get(key) ?? []), product]);
  }
  const stocked = (targetBranch: number, ingredientId: number | null) =>
    ingredientId === null
      ? []
      : (inventory.get(`${targetBranch}:${ingredientId}`) ?? []);

  /** Primera alternativa con producto en la sucursal, si al ingrediente le falta. */
  const substituteIn = (
    item: ShoppingListItem,
    branch: BranchSummary,
  ): SubstituteInBranch | null => {
    if (stocked(branch.branch_id, item.ingredient_id).length > 0) return null;
    for (const substitution of substitutions) {
      if (substitution.ingredient_id !== item.ingredient_id) continue;
      const found = stocked(branch.branch_id, substitution.substitute_ingredient_id);
      if (found.length > 0) {
        return {
          branch_id: branch.branch_id,
          branch_name: branch.name,
          ingredient_name: substitution.substitute_name,
          products: found.map(toProduct),
        };
      }
    }
    return null;
  };

  const availabilityItems = items.map((item): IngredientAvailabilityItem => {
    const availableProducts = stocked(branchId, item.ingredient_id);
    return {
      ...item,
      availability:
        item.ingredient_id === null
          ? 'NOT_IN_CATALOG'
          : availableProducts.length > 0
            ? 'AVAILABLE'
            : 'UNAVAILABLE',
      available_products: availableProducts.map(toProduct),
      other_branches: branches.flatMap((branch) => {
        if (branch.branch_id === branchId) return [];
        const found = stocked(branch.branch_id, item.ingredient_id);
        return found.length > 0
          ? [
              {
                branch_id: branch.branch_id,
                branch_name: branch.name,
                products: found.map(toProduct),
              },
            ]
          : [];
      }),
      substitutes: branches.flatMap((branch) => substituteIn(item, branch) ?? []),
    };
  });

  const planRoute = (branch: BranchSummary) => {
    const stops: ShoppingRouteStop[] = [];
    const missing: string[] = [];
    let exact = 0;
    for (const item of items) {
      const product = stocked(branch.branch_id, item.ingredient_id)[0];
      const chosen = product ?? substituteIn(item, branch)?.products[0];
      if (!chosen) {
        missing.push(item.name);
        continue;
      }
      if (product) exact++;
      stops.push({
        item_id: item.item_id,
        ingredient_name: item.name,
        product_id: chosen.product_id,
        product_name: chosen.name,
        section_name: chosen.section_name,
        shelf: chosen.shelf,
        is_substitute: !product,
      });
    }
    return { branch, stops, missing, exact };
  };

  // Primero la sucursal con más ingredientes exactos, luego la que más cubre con
  // alternativas; si empatan va primero la que eligió el usuario.
  const routes = branches
    .map(planRoute)
    .filter((plan) => plan.stops.length > 0)
    .sort(
      (a, b) =>
        b.exact - a.exact ||
        b.stops.length - a.stops.length ||
        Number(b.branch.branch_id === branchId) -
          Number(a.branch.branch_id === branchId),
    );

  return {
    items: availabilityItems,
    routes: routes.map(({ branch, stops, missing }) => ({
      branch_id: branch.branch_id,
      branch_name: branch.name,
      model_3d_url: branch.model_3d_url,
      stops,
      missing,
    })),
  };
}
