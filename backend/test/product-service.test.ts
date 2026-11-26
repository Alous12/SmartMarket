import assert from 'node:assert/strict';
import test from 'node:test';

// El servicio importa el pool de MySQL; crearlo no abre conexiones, pero exige
// estas variables aunque la prueba no toque la base de datos.
process.env.DB_HOST ??= 'localhost';
process.env.DB_USER ??= 'test';
process.env.DB_NAME ??= 'test';

const { parseCollect, parseNewProductRequest } = await import(
  '../src/services/product-service.js'
);

const base = {
  name: 'Fideo canelón 400 g',
  price: 12.5,
  unit_of_measure: 'unidad',
  category_id: 3,
  stock_quantity: 10,
};

test('un producto nuevo sin ubicación queda solo en el inventario', () => {
  const { product, slotCode } = parseNewProductRequest(base);
  assert.equal(product.location, null);
  assert.equal(slotCode, null);
  assert.equal(product.name, 'Fideo canelón 400 g');
  assert.match(product.sku, /^ADM_/);
});

test('se respeta el sku, la marca y la descripción enviados', () => {
  const { product } = parseNewProductRequest({
    ...base,
    sku: 'PASTA-01',
    brand: 'Don Vittorio',
    description: 'Pasta seca',
  });
  assert.equal(product.sku, 'PASTA-01');
  assert.equal(product.brand, 'Don Vittorio');
  assert.equal(product.description, 'Pasta seca');
});

test('slot_code pide un espacio del plano', () => {
  const { product, slotCode } = parseNewProductRequest({
    ...base,
    slot_code: 'SLOT_E01_09_0001',
  });
  assert.equal(slotCode, 'SLOT_E01_09_0001');
  assert.equal(product.location, null);
});

test('la ubicación con coordenadas del panel sigue funcionando', () => {
  const { product, slotCode } = parseNewProductRequest({
    ...base,
    sku: 'X1',
    section_id: 4,
    coordinate_x: 1,
    coordinate_y: 0,
    coordinate_z: -2.5,
    shelf: 'E01_09',
  });
  assert.equal(slotCode, null);
  assert.deepEqual(product.location, {
    sectionId: 4,
    x: 1,
    y: 0,
    z: -2.5,
    shelf: 'E01_09',
  });
});

test('no se mezclan slot_code y coordenadas', () => {
  assert.throws(
    () => parseNewProductRequest({ ...base, slot_code: 'S', section_id: 4 }),
    /slot_code o section_id/,
  );
});

test('faltan datos obligatorios o sobran campos', () => {
  assert.throws(() => parseNewProductRequest({ ...base, name: undefined }), /name/);
  assert.throws(() => parseNewProductRequest({ ...base, price: -1 }), /price/);
  assert.throws(() => parseNewProductRequest({ ...base, color: 'rojo' }), /color/);
});

test('«Ya lo tengo» descuenta una unidad por defecto', () => {
  assert.deepEqual(parseCollect({ branch_id: 2 }), { branchId: 2, quantity: 1 });
  assert.deepEqual(parseCollect({ branch_id: 2, quantity: 3 }), {
    branchId: 2,
    quantity: 3,
  });
});

test('«Ya lo tengo» exige una sucursal y una cantidad válida', () => {
  assert.throws(() => parseCollect({}), /branch_id/);
  assert.throws(() => parseCollect(undefined), /branch_id/);
  assert.throws(() => parseCollect({ branch_id: 2, quantity: 0 }), /quantity/);
  assert.throws(() => parseCollect({ branch_id: 2, quantity: 1.5 }), /quantity/);
});
