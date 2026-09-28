// Node 22+: node --experimental-default-type=module --test test/store_viewer/instancing_test.mjs
import {register} from 'node:module';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {test} from 'node:test';

const root = new URL('../../', import.meta.url);
const threeUrl = new URL('assets/store_viewer/vendor/three.module.min.js', root).href;
const utilsUrl = new URL('assets/store_viewer/vendor/BufferGeometryUtils.js', root).href;
register('data:text/javascript,' + encodeURIComponent(`
  export function resolve(specifier, context, next) {
    if (specifier === 'three') return {url: ${JSON.stringify(threeUrl)}, shortCircuit: true};
    if (specifier === '../utils/BufferGeometryUtils.js') return {url: ${JSON.stringify(utilsUrl)}, shortCircuit: true};
    return next(specifier, context);
  }
`));
const THREE = await import(threeUrl);
const {GLTFLoader} = await import(new URL('assets/store_viewer/vendor/GLTFLoader.js', root));
const {instanceStoreMeshes, countTriangles} = await import(new URL('assets/store_viewer/instancing.js', root));

test('Las instancias preservan transformaciones, colores y metadatos', () => {
  const source = new THREE.Group();
  source.position.set(20, 3, -4);
  const geometry = new THREE.BoxGeometry();
  const material = new THREE.MeshBasicMaterial({color: 0x345f2c});
  for (let i = 0; i < 4; i++) {
    const box = new THREE.Mesh(geometry, material);
    box.position.set(i, i % 2, 2);
    box.scale.set(1.3, 0.4, 0.5);
    box.userData.product_id = 'ARROZ_001';
    source.add(box);
  }
  source.updateMatrixWorld(true);
  const matrices = source.children.map(mesh => mesh.matrixWorld.clone());
  const result = instanceStoreMeshes(source);
  assert.equal(result.visuals.children.length, 1);
  const batch = result.visuals.children[0];
  assert.equal(batch.count, 4);
  assert.equal(batch.material, material);
  matrices.forEach((matrix, i) => {
    const instanced = new THREE.Matrix4();
    batch.getMatrixAt(i, instanced);
    matrix.elements.forEach((value, index) => assert.ok(Math.abs(value - instanced.elements[index]) < 0.00001));
    assert.equal(source.children[i].userData.product_id, 'ARROZ_001');
    assert.equal(result.bindings.get(source.children[i].uuid).index, i);
  });
});

test('Materiales distintos y reflejos se conservan por separado', () => {
  const source = new THREE.Group();
  const geometry = new THREE.BoxGeometry();
  const red = new THREE.MeshBasicMaterial({color: 0xff0000});
  const blue = new THREE.MeshBasicMaterial({color: 0x0000ff});
  source.add(new THREE.Mesh(geometry, red), new THREE.Mesh(geometry, blue));
  const mirrored = new THREE.Mesh(geometry, red);
  mirrored.scale.x = -1;
  source.add(mirrored);
  assert.equal(instanceStoreMeshes(source).visuals.children.length, 3);
});

test('El GLB conserva sus triángulos e IDs y reduce objetos dibujables', async () => {
  const bytes = await readFile(new URL('Modelos_3D/supermercado_1.glb', root));
  const gltf = await new GLTFLoader().parseAsync(
    bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '',
  );
  const result = instanceStoreMeshes(gltf.scene);
  const triangles = result.visuals.children.reduce((total, mesh) =>
    total + countTriangles(mesh) * (mesh.isInstancedMesh ? mesh.count : 1), 0);
  assert.equal(triangles, result.originalTriangles);
  assert.equal(triangles, 55112);
  assert.ok(result.visuals.children.length < 300);
  let productFound = false, entranceFound = false;
  gltf.scene.traverse(object => {
    if (object.userData.kind === 'product_group' && object.userData.product_id === 'ARROZ_001') productFound = true;
    if (object.userData.node_id === 'node_acceso') entranceFound = true;
  });
  assert.ok(productFound && entranceFound);
  console.log(`Supermercado: ${result.originalMeshes} objetos → ${result.visuals.children.length} grupos de dibujo; ${triangles} triángulos.`);
});
