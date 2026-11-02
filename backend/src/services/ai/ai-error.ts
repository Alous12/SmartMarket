/**
 * Error del servicio de IA. `message` describe la causa técnica (para el log);
 * `userMessage` es el texto que se muestra en la app. `rejected` indica que la
 * petición se descartó por su contenido y no por una falla técnica.
 */
export class AiServiceError extends Error {
  constructor(
    message: string,
    readonly userMessage = 'El asistente no pudo procesar tu petición. Inténtalo de nuevo.',
    readonly rejected = false,
  ) {
    super(message);
    this.name = 'AiServiceError';
  }
}
