import { createHmac, timingSafeEqual } from 'node:crypto';

import { HttpError } from '../middlewares/http-error.js';
import type { UserRole } from '../models/user.js';

const tokenLifetimeSeconds = 60 * 60 * 8;

interface TokenPayload {
  username: string;
  role: UserRole;
  iat: number;
  exp: number;
}

function getSecret(): string {
  const secret = process.env.AUTH_TOKEN_SECRET;
  if (!secret || Buffer.byteLength(secret, 'utf8') < 32) {
    throw new Error(
      'AUTH_TOKEN_SECRET debe configurarse en backend/.env con al menos 32 bytes.',
    );
  }
  return secret;
}

function encode(value: object): string {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function sign(data: string): Buffer {
  return createHmac('sha256', getSecret()).update(data).digest();
}

export function createAuthToken(identity: {
  username: string;
  role: UserRole;
}): string {
  const now = Math.floor(Date.now() / 1000);
  const header = encode({ alg: 'HS256', typ: 'JWT' });
  const payload = encode({
    username: identity.username,
    role: identity.role,
    iat: now,
    exp: now + tokenLifetimeSeconds,
  });
  const content = `${header}.${payload}`;
  return `${content}.${sign(content).toString('base64url')}`;
}

export function verifyAuthToken(token: string): {
  username: string;
  role: UserRole;
} {
  const secret = getSecret();
  try {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error('Invalid token');

    const [headerPart, payloadPart, signaturePart] = parts;
    const content = `${headerPart}.${payloadPart}`;
    const receivedSignature = Buffer.from(signaturePart, 'base64url');
    const expectedSignature = createHmac('sha256', secret)
      .update(content)
      .digest();
    if (
      receivedSignature.length !== expectedSignature.length ||
      !timingSafeEqual(receivedSignature, expectedSignature)
    ) {
      throw new Error('Invalid token');
    }

    const header = JSON.parse(
      Buffer.from(headerPart, 'base64url').toString('utf8'),
    ) as Record<string, unknown>;
    const payload = JSON.parse(
      Buffer.from(payloadPart, 'base64url').toString('utf8'),
    ) as Partial<TokenPayload>;
    const now = Math.floor(Date.now() / 1000);
    if (
      header.alg !== 'HS256' ||
      typeof payload.username !== 'string' ||
      (payload.role !== 'user' && payload.role !== 'admin') ||
      typeof payload.iat !== 'number' ||
      typeof payload.exp !== 'number' ||
      payload.exp <= now
    ) {
      throw new Error('Invalid token');
    }

    return { username: payload.username, role: payload.role };
  } catch {
    throw new HttpError(401, 'Token inválido o expirado.');
  }
}
