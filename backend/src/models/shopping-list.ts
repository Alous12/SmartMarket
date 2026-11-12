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
  /** Última disponibilidad registrada; null si aún no se consultó el inventario. */
  availability: IngredientAvailabilityStatus | null;
  excluded?: boolean;
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

export type IngredientAvailabilityStatus =
  | 'AVAILABLE'
  | 'UNAVAILABLE'
  | 'NOT_IN_CATALOG';

export interface AvailableIngredientProduct {
  product_id: number;
  sku: string;
  name: string;
  stock_quantity: number;
  section_name: string;
  shelf: string | null;
}

export interface IngredientProductMatch extends AvailableIngredientProduct {
  ingredient_id: number;
  branch_id: number;
  price: number;
  unit_of_measure: string;
  brand?: string | null;
  description?: string | null;
}

export interface ProductChoice {
  item_id: number;
  branch_id: number;
  product_id: number;
}

export interface ProductOption extends AvailableIngredientProduct {
  ingredient_id: number;
  ingredient_name: string;
  branch_id: number;
  branch_name: string;
  price: number;
  unit_of_measure: string;
  brand?: string | null;
  description?: string | null;
  is_substitute: boolean;
  selected: boolean;
}

/** Ingrediente que puede reemplazar a otro; a menor priority, mejor alternativa. */
export interface IngredientSubstitution {
  ingredient_id: number;
  substitute_ingredient_id: number;
  substitute_name: string;
  priority: number;
}

export interface BranchSummary {
  branch_id: number;
  name: string;
  model_3d_url: string | null;
}

export interface BranchProducts {
  branch_id: number;
  branch_name: string;
  products: AvailableIngredientProduct[];
}

/** Alternativa para un ingrediente sin producto en esa sucursal. */
export interface SubstituteInBranch extends BranchProducts {
  ingredient_name: string;
}

export interface IngredientAvailabilityItem extends ShoppingListItem {
  /** Estado en la sucursal de la petición. */
  availability: IngredientAvailabilityStatus;
  available_products: AvailableIngredientProduct[];
  /** Otras sucursales que sí tienen el ingrediente. */
  other_branches: BranchProducts[];
  substitutes: SubstituteInBranch[];
  product_options: ProductOption[];
  invalid_selected_branches: number[];
}

export interface ShoppingRouteStop {
  item_id: number;
  ingredient_name: string;
  product_id: number;
  product_name: string;
  section_name: string;
  shelf: string | null;
  is_substitute: boolean;
}

/** Recorrido de compra por una sucursal. */
export interface ShoppingRoute {
  branch_id: number;
  branch_name: string;
  model_3d_url: string | null;
  stops: ShoppingRouteStop[];
  /** Ingredientes de la lista que no entran en el recorrido. */
  missing: string[];
}

export type IngredientAvailabilityList = Omit<ShoppingList, 'items'> & {
  branch_name: string | null;
  items: IngredientAvailabilityItem[];
  /** Un recorrido por sucursal con algo de la lista, de mejor a peor. */
  routes: ShoppingRoute[];
};
