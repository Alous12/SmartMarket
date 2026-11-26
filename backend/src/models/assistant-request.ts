import type { ShoppingListItem } from './shopping-list.js';

/** Producto mostrado como barra de stock en la respuesta del admin. */
export interface AdminAnswerRow {
  product_id: number;
  name: string;
  stock: number;
  status: 'out' | 'low' | 'ok';
}

export type AssistantRequestStatus =
  | 'RECEIVED'
  | 'PROCESSING'
  | 'COMPLETED'
  | 'REJECTED'
  | 'FAILED';

export interface AssistantRequest {
  request_id: number;
  user_id: number;
  branch_id: number | null;
  prompt: string;
  status: AssistantRequestStatus;
  /** Receta identificada por la IA; null mientras no exista. */
  recipe_name: string | null;
  /** Respuesta de la IA o mensaje para el usuario cuando la petición se rechaza o falla. */
  response_message: string | null;
  /**
   * Productos con su stock que acompañan la respuesta del asistente del admin.
   * Salen de la consulta real al inventario; ausente si la respuesta no los trae.
   */
  rows?: AdminAnswerRow[];
  recommendations_ready?: boolean;
  created_at: Date;
  updated_at: Date;
}

/** Receta ya resuelta por la IA, que se puede repetir sin volver a consultarla. */
export interface RecipeHistoryEntry {
  request_id: number;
  recipe_name: string;
  branch_id: number;
  ingredient_count: number;
  created_at: Date;
}

/** Petición con los ingredientes de su lista, si ya se generó. */
export interface AssistantRequestDetail extends AssistantRequest {
  ingredients: ShoppingListItem[];
}
