import assert from 'node:assert/strict';
import test from 'node:test';

import {createPath, pointAt, remainingPoints, walkedPoints} from '../../assets/store_viewer/route_path.js';

const point = (x, z) => ({x, y: 0, z});
const path = createPath([point(0, 0), point(10, 0), point(10, 5)]);

test('mide el largo total del recorrido', () => {
  assert.equal(path.total, 15);
});

test('ubica una distancia dentro de cualquier tramo', () => {
  assert.deepEqual(pointAt(path, 4), point(4, 0));
  assert.deepEqual(pointAt(path, 12), point(10, 2));
});

test('una distancia fuera del recorrido queda en sus extremos', () => {
  assert.deepEqual(pointAt(path, -3), point(0, 0));
  assert.deepEqual(pointAt(path, 99), point(10, 5));
});

test('lo recorrido desaparece de la línea', () => {
  assert.deepEqual(remainingPoints(path, 0), [point(0, 0), point(10, 0), point(10, 5)]);
  assert.deepEqual(remainingPoints(path, 4), [point(4, 0), point(10, 0), point(10, 5)]);
  assert.deepEqual(remainingPoints(path, 12), [point(10, 2), point(10, 5)]);
});

test('en una esquina la línea sigue desde esa esquina', () => {
  assert.deepEqual(remainingPoints(path, 10), [point(10, 0), point(10, 5)]);
});

test('al llegar al final no queda línea', () => {
  assert.deepEqual(remainingPoints(path, 15), []);
  assert.deepEqual(remainingPoints(path, 20), []);
});

test('ignora los tramos de largo cero', () => {
  const repeated = createPath([point(0, 0), point(0, 0), point(0, 4)]);

  assert.equal(repeated.total, 4);
  assert.deepEqual(pointAt(repeated, 2), point(0, 2));
});

test('un recorrido de un solo punto no falla', () => {
  const single = createPath([point(3, 3)]);

  assert.deepEqual(pointAt(single, 2), point(3, 3));
  assert.deepEqual(remainingPoints(single, 0), []);
});

test('lo recorrido va del inicio a la posición actual', () => {
  const walked = walkedPoints(path, 12);
  assert.deepEqual(walked, [point(0, 0), point(10, 0), point(10, 2)]);
  assert.deepEqual(walkedPoints(path, 0), []);
  assert.deepEqual(walkedPoints(path, 99).at(-1), point(10, 5));
});

test('lo recorrido y lo que falta se juntan en la posición actual', () => {
  const walked = walkedPoints(path, 4);
  const ahead = remainingPoints(path, 4);
  assert.deepEqual(walked.at(-1), ahead[0]);
});
