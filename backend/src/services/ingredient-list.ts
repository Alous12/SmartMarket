import { HttpError } from '../middlewares/http-error.js';
import type {
  IdentifiedIngredient,
  IngredientListEntry,
} from '../models/shopping-list.js';

// Límites de las columnas de shopping_list_items.
export const maxIngredients = 100;
export const maxNameLength = 150;
export const maxUnitLength = 50;
// DECIMAL(10, 3)
export const maxQuantity = 9_999_999.999;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Clave con la que se compara un ingrediente: sin mayúsculas, tildes ni
 * espacios repetidos. Coincide con la colación utf8mb4_unicode_ci de MySQL.
 */
export function normalizeIngredientName(name: string): string {
  return name
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function readIngredient(value: unknown, index: number): IdentifiedIngredient {
  const label = `ingredients[${index}]`;
  if (!isRecord(value)) {
    throw new HttpError(400, `${label} debe ser un objeto.`);
  }
  const unexpectedField = Object.keys(value).find(
    (field) => !['name', 'quantity', 'unit'].includes(field),
  );
  if (unexpectedField) {
    throw new HttpError(400, `El campo ${label}.${unexpectedField} no está permitido.`);
  }

  if (typeof value.name !== 'string' || !normalizeIngredientName(value.name)) {
    throw new HttpError(400, `${label}.name es obligatorio y no puede estar vacío.`);
  }
  const name = value.name.replace(/\s+/g, ' ').trim();
  if (name.length > maxNameLength) {
    throw new HttpError(400, `${label}.name no puede superar ${maxNameLength} caracteres.`);
  }

  let quantity: number | null = null;
  if (value.quantity !== undefined && value.quantity !== null) {
    if (
      typeof value.quantity !== 'number' ||
      !Number.isFinite(value.quantity) ||
      value.quantity <= 0 ||
      value.quantity > maxQuantity
    ) {
      throw new HttpError(
        400,
        `${label}.quantity debe ser un número mayor que 0 y menor o igual a ${maxQuantity}.`,
      );
    }
    quantity = value.quantity;
  }

  let unit: string | null = null;
  if (value.unit !== undefined && value.unit !== null) {
    if (typeof value.unit !== 'string' || !value.unit.trim()) {
      throw new HttpError(400, `${label}.unit debe ser texto no vacío.`);
    }
    unit = value.unit.trim().toLowerCase();
    if (unit.length > maxUnitLength) {
      throw new HttpError(400, `${label}.unit no puede superar ${maxUnitLength} caracteres.`);
    }
    if (quantity === null) {
      throw new HttpError(400, `${label}.unit requiere una cantidad.`);
    }
  }

  return { name, quantity, unit };
}

/** Valida la salida del paso de identificación: `{ ingredients: [...] }`. */
export function parseIdentifiedIngredients(body: unknown): IdentifiedIngredient[] {
  if (!isRecord(body)) {
    throw new HttpError(400, 'El cuerpo de la solicitud debe ser un objeto JSON.');
  }
  const unexpectedField = Object.keys(body).find((field) => field !== 'ingredients');
  if (unexpectedField) {
    throw new HttpError(400, `El campo ${unexpectedField} no está permitido.`);
  }
  if (!Array.isArray(body.ingredients) || body.ingredients.length === 0) {
    throw new HttpError(400, 'ingredients debe ser una lista con al menos un ingrediente.');
  }
  if (body.ingredients.length > maxIngredients) {
    throw new HttpError(400, `ingredients no puede tener más de ${maxIngredients} elementos.`);
  }
  return body.ingredients.map(readIngredient);
}

/**
 * Genera la lista estructurada: un elemento por ingrediente, en el orden en
 * que se identificaron. Los repetidos se fusionan; sus cantidades se suman
 * solo si todas existen y usan la misma unidad, y si no, la cantidad queda
 * indeterminada (null).
 */
export function buildIngredientList(
  ingredients: IdentifiedIngredient[],
): IngredientListEntry[] {
  const entries = new Map<string, IngredientListEntry & { mergeable: boolean }>();

  for (const ingredient of ingredients) {
    const normalizedName = normalizeIngredientName(ingredient.name);
    const existing = entries.get(normalizedName);
    if (!existing) {
      entries.set(normalizedName, {
        raw_name: ingredient.name,
        normalized_name: normalizedName,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        mergeable: ingredient.quantity !== null,
      });
      continue;
    }

    if (
      existing.mergeable &&
      ingredient.quantity !== null &&
      existing.unit === ingredient.unit
    ) {
      const total = Math.round((existing.quantity! + ingredient.quantity) * 1000) / 1000;
      if (total > maxQuantity) {
        throw new HttpError(
          400,
          `La cantidad total de ${ingredient.name} no puede superar ${maxQuantity}.`,
        );
      }
      existing.quantity = total;
    } else {
      existing.mergeable = false;
      existing.quantity = null;
      existing.unit = null;
    }
  }

  return [...entries.values()].map(({ mergeable: _mergeable, ...entry }) => entry);
}
