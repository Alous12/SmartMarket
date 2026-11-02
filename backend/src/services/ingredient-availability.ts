import type {
  IngredientAvailabilityItem,
  IngredientProductMatch,
  ShoppingListItem,
} from '../models/shopping-list.js';

export function buildIngredientAvailabilityItems(
  items: ShoppingListItem[],
  products: IngredientProductMatch[],
): IngredientAvailabilityItem[] {
  const productsByIngredient = new Map<number, IngredientProductMatch[]>();
  for (const product of products) {
    const matches = productsByIngredient.get(product.ingredient_id) ?? [];
    matches.push(product);
    productsByIngredient.set(product.ingredient_id, matches);
  }

  return items.map((item) => {
    const availableProducts =
      item.ingredient_id === null
        ? []
        : productsByIngredient.get(item.ingredient_id) ?? [];

    return {
      ...item,
      availability:
        item.ingredient_id === null
          ? 'NOT_IN_CATALOG'
          : availableProducts.length > 0
            ? 'AVAILABLE'
            : 'UNAVAILABLE',
      available_products: availableProducts.map(
        ({ product_id, name, stock_quantity }) => ({
          product_id,
          name,
          stock_quantity,
        }),
      ),
    };
  });
}
