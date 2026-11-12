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
  ProductChoice,
} from '../models/shopping-list.js';

export interface AvailabilityInput {
  items: ShoppingListItem[];
  /** Sucursal seleccionada en la petición. */
  branchId: number;
  branches: BranchSummary[];
  products: IngredientProductMatch[];
  /** Alternativas ordenadas de mejor a peor. */
  substitutions: IngredientSubstitution[];
  choices?: ProductChoice[];
  preferLowerPrice?: boolean;
  preferences?: Array<{ ingredient_id: number; preference_type: 'PREFER' | 'AVOID' }>;
  preferredProducts?: number[];
  learnedIngredients?: Array<{ ingredient_id: number; preferred_ingredient_id: number }>;
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
  choices = [],
  preferLowerPrice = false,
  preferences = [],
  preferredProducts = [],
  learnedIngredients = [],
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
    const preference = new Map(preferences.map((entry) => [entry.ingredient_id, entry.preference_type]));
    const relevant = [
      ...(item.ingredient_id === null ? [] : [{ id: item.ingredient_id, name: item.name, substitute: false }]),
      ...substitutions.filter((entry) => entry.ingredient_id === item.ingredient_id)
        .map((entry) => ({ id: entry.substitute_ingredient_id, name: entry.substitute_name, substitute: true })),
    ];
    const rawOptions = branches.flatMap((branch) => relevant.flatMap((ingredient) =>
      stocked(branch.branch_id, ingredient.id).map((product) => ({
        ...toProduct(product),
        ingredient_id: ingredient.id,
        ingredient_name: ingredient.name,
        branch_id: branch.branch_id,
        branch_name: branch.name,
        price: product.price,
        unit_of_measure: product.unit_of_measure,
        is_substitute: ingredient.substitute,
        selected: choices.some((choice) => choice.item_id === item.item_id &&
          choice.branch_id === branch.branch_id && choice.product_id === product.product_id),
      })),
    ));
    const uniqueOptions = new Map<string, typeof rawOptions[number]>();
    for (const option of rawOptions) {
      const key = `${option.branch_id}:${option.product_id}`;
      const existing = uniqueOptions.get(key);
      if (!existing || (existing.is_substitute && !option.is_substitute)) {
        uniqueOptions.set(key, option);
      }
    }
    const productOptions = [...uniqueOptions.values()].sort((a, b) => {
      const score = (id: number) => preference.get(id) === 'PREFER' ? 1 : preference.get(id) === 'AVOID' ? -1 : 0;
      const learned = learnedIngredients.find((entry) => entry.ingredient_id === item.ingredient_id);
      return score(b.ingredient_id) - score(a.ingredient_id) ||
        Number(b.ingredient_id === learned?.preferred_ingredient_id) -
          Number(a.ingredient_id === learned?.preferred_ingredient_id) ||
        Number(a.is_substitute) - Number(b.is_substitute) ||
        Number(preferredProducts.includes(b.product_id)) - Number(preferredProducts.includes(a.product_id)) ||
        a.ingredient_id - b.ingredient_id ||
        a.unit_of_measure.localeCompare(b.unit_of_measure) ||
        (preferLowerPrice ? a.price - b.price : 0) ||
        a.product_id - b.product_id;
    });
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
      product_options: productOptions,
      invalid_selected_branches: choices
        .filter((choice) => choice.item_id === item.item_id &&
          !productOptions.some((option) => option.branch_id === choice.branch_id && option.product_id === choice.product_id))
        .map((choice) => choice.branch_id),
    };
  });

  const planRoute = (branch: BranchSummary) => {
    const stops: ShoppingRouteStop[] = [];
    const missing: string[] = [];
    let exact = 0;
    for (const item of items) {
      const product = stocked(branch.branch_id, item.ingredient_id)[0];
      const choice = choices.find((entry) => entry.item_id === item.item_id && entry.branch_id === branch.branch_id);
      const selected = choice && availabilityItems.find((entry) => entry.item_id === item.item_id)
        ?.product_options.find((option) => option.branch_id === branch.branch_id && option.product_id === choice.product_id);
      if (choice && !selected) {
        missing.push(item.name);
        continue;
      }
      const chosen = selected ?? product ?? substituteIn(item, branch)?.products[0];
      if (!chosen) {
        missing.push(item.name);
        continue;
      }
      const isSubstitute = selected ? selected.is_substitute : !product;
      if (!isSubstitute) exact++;
      stops.push({
        item_id: item.item_id,
        ingredient_name: item.name,
        product_id: chosen.product_id,
        product_name: chosen.name,
        section_name: chosen.section_name,
        shelf: chosen.shelf,
        is_substitute: isSubstitute,
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
