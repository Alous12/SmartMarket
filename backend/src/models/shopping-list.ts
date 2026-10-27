export type ShoppingListSource = 'MANUAL' | 'RECIPE' | 'AI';

export type ShoppingListStatus = 'ACTIVE' | 'COMPLETED' | 'CANCELLED';

/** Ingrediente tal como lo entrega el paso de identificación. */
export interface IdentifiedIngredient {
  name: string;
  quantity: number | null;
  unit: string | null;
}

/** Ingrediente ya normalizado y sin duplicados, listo para guardarse. */
export interface IngredientListEntry {
  raw_name: string;
  normalized_name: string;
  quantity: number | null;
  unit: string | null;
}

export interface ShoppingListItem {
  item_id: number;
  ingredient_id: number | null;
  name: string;
  raw_name: string;
  normalized_name: string;
  quantity: number | null;
  unit: string | null;
}

export interface ShoppingList {
  list_id: number;
  user_id: number;
  branch_id: number;
  request_id: number | null;
  source: ShoppingListSource;
  status: ShoppingListStatus;
  created_at: Date;
  updated_at: Date;
  items: ShoppingListItem[];
}
