import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import type { ResultSetHeader, RowDataPacket } from 'mysql2';

test('real MySQL validates ownership, stock and idempotent selections', {
  skip: process.env.RUN_DB_INTEGRATION !== '1',
}, async () => {
  const { pool } = await import('../src/database/pool.js');
  const { saveChoice, findChoices, findProfile } = await import('../src/repositories/assistant-choice-repository.js');
  const { app } = await import('../src/app.js');
  const { createAuthToken } = await import('../src/services/auth-token.js');
  const server = app.listen(0, '127.0.0.1');
  let userId: number | undefined;
  try {
    await new Promise<void>((resolve, reject) => {
      server.once('listening', resolve);
      server.once('error', reject);
    });
    const address = server.address();
    assert.ok(address && typeof address !== 'string');
    const base = `http://127.0.0.1:${address.port}/api/assistant`;
    const [available] = await pool.query<RowDataPacket[]>(
      `SELECT DISTINCT pi.ingredient_id, p.product_id, i.branch_id
       FROM product_ingredients pi
       JOIN products p ON p.product_id = pi.product_id AND p.status = TRUE
       JOIN inventory i ON i.product_id = p.product_id AND i.stock_quantity > 0
       JOIN branches b ON b.branch_id = i.branch_id AND b.status = TRUE
       JOIN product_locations pl ON pl.product_id = p.product_id
       JOIN sections s ON s.section_id = pl.section_id AND s.branch_id = i.branch_id
       LIMIT 1`,
    );
    assert.ok(available.length, 'La base de pruebas necesita un producto disponible.');
    const { ingredient_id: ingredientId, product_id: productId, branch_id: branchId } = available[0];
    const [user] = await pool.execute<ResultSetHeader>(
      `INSERT INTO users (name, last_name, email, password_hash, role)
       VALUES ('Prueba', 'Temporal', ?, 'not-a-password', 'user')`,
      [`test-${randomUUID()}@invalid.example`],
    );
    userId = user.insertId;
    const [request] = await pool.execute<ResultSetHeader>(
      `INSERT INTO assistant_requests (user_id, branch_id, prompt, status)
       VALUES (?, ?, 'prueba temporal', 'COMPLETED')`,
      [userId, branchId],
    );
    const [list] = await pool.execute<ResultSetHeader>(
      `INSERT INTO shopping_lists (user_id, branch_id, request_id, source)
       VALUES (?, ?, ?, 'AI')`,
      [userId, branchId, request.insertId],
    );
    const [item] = await pool.execute<ResultSetHeader>(
      `INSERT INTO shopping_list_items (list_id, ingredient_id, raw_name, normalized_name)
       VALUES (?, ?, 'temporal', 'temporal')`,
      [list.insertId, ingredientId],
    );
    const input = {
      userId, requestId: request.insertId, itemId: item.insertId,
      branchId: Number(branchId), productId: Number(productId),
    };
    const token = createAuthToken({ userId, username: 'Prueba', role: 'user' });
    const otherToken = createAuthToken({ userId: 2147483647, username: 'Otro', role: 'user' });
    const target = `${base}/requests/${request.insertId}/ingredients/${item.insertId}/product`;
    const select = (auth: string) => fetch(target, {
      method: 'PUT',
      headers: { authorization: `Bearer ${auth}`, 'content-type': 'application/json' },
      body: JSON.stringify({ branch_id: Number(branchId), product_id: Number(productId) }),
    });
    assert.equal((await fetch(`${base}/models`)).status, 401);
    assert.equal((await fetch(`${base}/models`, { headers: { authorization: `Bearer ${token}` } })).status, 200);
    assert.equal((await select(otherToken)).status, 404);
    const response = await select(token);
    assert.equal(response.status, 200);
    const result = await response.json() as { data: { items: Array<{ product_options: Array<{ product_id: number; selected: boolean }> }> } };
    assert.ok(result.data.items[0].product_options.some((option) => option.product_id === Number(productId) && option.selected));
    await assert.rejects(saveChoice({ ...input, userId: 2147483647 }), /no encontrado/);
    await assert.rejects(saveChoice({ ...input, productId: 2147483647 }), /no está disponible/);
    await saveChoice(input);
    await saveChoice(input);
    assert.deepEqual(await findChoices(list.insertId), [{
      item_id: item.insertId, branch_id: Number(branchId), product_id: Number(productId),
    }]);
    const [events] = await pool.execute<RowDataPacket[]>(
      'SELECT COUNT(*) AS count FROM assistant_choice_events WHERE user_id = ?',
      [userId],
    );
    assert.equal(Number(events[0].count), 1);
    assert.equal((await findProfile(userId)).preferLowerPrice, false);
  } finally {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    if (userId !== undefined) {
      await pool.execute('DELETE FROM users WHERE user_id = ?', [userId]);
    }
    await pool.end();
  }
});
