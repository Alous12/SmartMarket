const parsedPort = Number.parseInt(process.env.PORT ?? '3000', 10);

if (!Number.isInteger(parsedPort) || parsedPort < 1 || parsedPort > 65535) {
  throw new Error('PORT debe ser un número entre 1 y 65535.');
}

export const port = parsedPort;
