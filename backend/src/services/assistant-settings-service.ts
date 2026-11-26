import { HttpError } from '../middlewares/http-error.js';
import type { AssistantSettings } from '../models/assistant-settings.js';
import * as settingsRepository from '../repositories/assistant-settings-repository.js';

const fields = ['prioritize_cheapest', 'remember_brands'] as const;

/** Valida el cuerpo del PATCH: solo los dos interruptores, como booleanos. */
export function parseSettingsUpdate(body: unknown): Partial<AssistantSettings> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw new HttpError(400, 'El cuerpo debe ser un objeto JSON.');
  }
  const record = body as Record<string, unknown>;
  const unexpected = Object.keys(record).find(
    (field) => !(fields as readonly string[]).includes(field),
  );
  if (unexpected) {
    throw new HttpError(400, `El campo ${unexpected} no es un ajuste del asistente.`);
  }
  const update: Partial<AssistantSettings> = {};
  for (const field of fields) {
    const value = record[field];
    if (value === undefined) continue;
    if (typeof value !== 'boolean') {
      throw new HttpError(400, `${field} debe ser verdadero o falso.`);
    }
    update[field] = value;
  }
  if (Object.keys(update).length === 0) {
    throw new HttpError(400, 'Indica al menos un ajuste para cambiar.');
  }
  return update;
}

/**
 * Aplica los ajustes al perfil aprendido. Con los valores por defecto el perfil
 * queda igual: solo cambia algo si el usuario tocó un interruptor.
 */
export function applyAssistantSettings<
  T extends { preferLowerPrice: boolean; preferredProducts: number[] },
>(profile: T, settings: AssistantSettings): T {
  return {
    ...profile,
    preferLowerPrice: profile.preferLowerPrice || settings.prioritize_cheapest,
    preferredProducts: settings.remember_brands ? profile.preferredProducts : [],
  };
}

export async function getSettings(userId: number): Promise<AssistantSettings> {
  return settingsRepository.find(userId);
}

export async function updateSettings(
  userId: number,
  body: unknown,
): Promise<AssistantSettings> {
  const update = parseSettingsUpdate(body);
  const next = { ...(await settingsRepository.find(userId)), ...update };
  await settingsRepository.save(userId, next);
  return next;
}
