import { createHmac } from 'node:crypto';

import bcrypt from 'bcrypt';

const bcryptCost = 12;
const minimumKeyBytes = 32;

export async function hashPassword(password: string): Promise<string> {
  const key = process.env.PASSWORD_HASH_KEY;
  if (!key || Buffer.byteLength(key, 'utf8') < minimumKeyBytes) {
    throw new Error(
      'PASSWORD_HASH_KEY debe configurarse en backend/.env con al menos 32 bytes.',
    );
  }

  const passwordDigest = createHmac('sha256', key)
    .update(password, 'utf8')
    .digest('hex');
  return bcrypt.hash(passwordDigest, bcryptCost);
}
