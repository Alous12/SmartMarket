import { spawn as nodeSpawn } from 'node:child_process';

const defaultBaseUrl = 'http://127.0.0.1:11434';
const startupTimeoutMs = 10_000;
const retryDelayMs = 250;

export interface OllamaLifecycleDependencies {
  fetchImpl?: typeof fetch;
  spawnImpl?: typeof nodeSpawn;
  wait?: (ms: number) => Promise<void>;
  log?: Pick<Console, 'info' | 'warn'>;
}

function isEnabled(): boolean {
  return Boolean(process.env.OLLAMA_MODEL?.trim() || process.env.OLLAMA_MODELS?.trim());
}

function autoStartEnabled(): boolean {
  return process.env.OLLAMA_AUTO_START?.trim().toLowerCase() !== 'false';
}

function baseUrl(): string {
  return (process.env.OLLAMA_BASE_URL?.trim() || defaultBaseUrl).replace(/\/+$/, '');
}

function isLocalUrl(url: string): boolean {
  try {
    const { hostname } = new URL(url);
    return hostname === '127.0.0.1' || hostname === 'localhost' || hostname === '::1';
  } catch {
    return false;
  }
}

async function isRunning(fetchImpl: typeof fetch, url: string): Promise<boolean> {
  try {
    const response = await fetchImpl(`${url}/api/tags`, {
      signal: AbortSignal.timeout(1_000),
    });
    return response.ok;
  } catch {
    return false;
  }
}

/**
 * Inicia el daemon local cuando hay un modelo local configurado. No intenta
 * ejecutar comandos para una URL remota, y nunca impide que la API arranque.
 */
export async function ensureOllamaRunning(
  dependencies: OllamaLifecycleDependencies = {},
): Promise<void> {
  const fetchImpl = dependencies.fetchImpl ?? fetch;
  const spawnImpl = dependencies.spawnImpl ?? nodeSpawn;
  const wait = dependencies.wait ?? ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));
  const log = dependencies.log ?? console;
  const url = baseUrl();

  if (!isEnabled() || !autoStartEnabled()) return;
  if (!isLocalUrl(url)) {
    log.info(`Ollama usa un servidor remoto (${url}); no se iniciará localmente.`);
    return;
  }
  if (await isRunning(fetchImpl, url)) {
    log.info('Ollama local ya está disponible.');
    return;
  }

  const command = process.env.OLLAMA_COMMAND?.trim() || 'ollama';
  log.info('Iniciando Ollama local…');
  try {
    const child = spawnImpl(command, ['serve'], {
      stdio: 'ignore',
      windowsHide: true,
    });
    child.once('error', (error) => {
      log.warn(`No se pudo iniciar Ollama automáticamente: ${error.message}`);
    });
    // No se usa `detached`: en Windows eso puede crear una consola separada.
    // La salida está ignorada y windowsHide evita que el proceso hijo muestre ventana.
    child.unref();
  } catch (error) {
    log.warn(`No se pudo iniciar Ollama automáticamente: ${error instanceof Error ? error.message : String(error)}`);
    return;
  }

  const deadline = Date.now() + startupTimeoutMs;
  while (Date.now() < deadline) {
    await wait(retryDelayMs);
    if (await isRunning(fetchImpl, url)) {
      log.info('Ollama local está listo.');
      return;
    }
  }
  log.warn('Ollama se inició, pero no respondió a tiempo. La API seguirá disponible sin el modelo local.');
}
