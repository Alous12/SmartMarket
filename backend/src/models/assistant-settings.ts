/** Interruptores de Perfil que ajustan cómo elige el asistente. */
export interface AssistantSettings {
  /** El precio manda siempre, sin esperar a aprenderlo del historial. */
  prioritize_cheapest: boolean;
  /** Repite los productos que el usuario suele elegir. */
  remember_brands: boolean;
}

/** Valores para quien nunca tocó los interruptores: el comportamiento de siempre. */
export const defaultAssistantSettings: AssistantSettings = {
  prioritize_cheapest: false,
  remember_brands: true,
};
