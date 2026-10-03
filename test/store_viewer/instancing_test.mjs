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
const {boxFrontFace} = await import(new URL('assets/store_viewer/labels.js', root));

// Node no decodifica imágenes: se quitan las texturas del JSON del GLB (la geometría
// y los extras no cambian).
function withoutTextures(bytes) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const jsonLength = view.getUint32(12, true);
  const json = JSON.parse(new TextDecoder().decode(bytes.subarray(20, 20 + jsonLength)));
  if (!json.images) return bytes;
  delete json.images; delete json.textures; delete json.samplers;
  const strip = value => {
    if (Array.isArray(value)) return value.forEach(strip);
    if (value && typeof value === 'object') {
      for (const key of Object.keys(value)) {
        if (/Texture$/.test(key)) delete value[key]; else strip(value[key]);
      }
    }
  };
  strip(json.materials);
  const text = new TextEncoder().encode(JSON.stringify(json));
  const padded = (text.length + 3) & ~3;
  const rest = bytes.subarray(20 + jsonLength);
  const out = new Uint8Array(20 + padded + rest.length).fill(0x20, 20, 20 + padded);
  out.set(bytes.subarray(0, 20));
  out.set(text, 20);
  out.set(rest, 20 + padded);
  const outView = new DataView(out.buffer);
  outView.setUint32(8, out.length, true);
  outView.setUint32(12, padded, true);
  return out;
}

async function loadGlb(path) {
  const bytes = withoutTextures(await readFile(new URL(path, root)));
  return new GLTFLoader().parseAsync(
    bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '',
  );
}

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
  // Los textos editables quedan en Blender; la app crea su atlas de etiquetas.
  assert.equal(result.labelTriangles, 0);
  assert.ok(triangles < 80000);
  const fixtures = [];
  gltf.scene.traverse(object => {
    if (object.userData.kind === 'fixture') fixtures.push(object);
  });
  assert.equal(fixtures.length, 12);
  for (const fixture of fixtures) {
    const box = new THREE.Box3().setFromObject(fixture);
    // El corredor transversal Y=2 de Blender es Z=-2 en glTF.
    assert.ok(box.max.z < -2.9 || box.min.z > -1.1, 'corredor central libre');
  }
  assert.ok(result.visuals.children.length < 300);
  let productFound = false, entranceFound = false;
  gltf.scene.traverse(object => {
    if (object.userData.kind === 'product_group' && object.userData.product_id === 'ARROZ_001') productFound = true;
    if (object.userData.node_id === 'node_acceso') entranceFound = true;
  });
  assert.ok(productFound && entranceFound);
  console.log(`Supermercado: ${result.originalMeshes} objetos → ${result.visuals.children.length} grupos de dibujo; ${triangles} triángulos.`);
});

test('El supermercado piloto tiene cajas con frente hacia su nodo de ruta', async () => {
  const gltf = await loadGlb('Modelos_3D/supermercado_2.glb');
  const result = instanceStoreMeshes(gltf.scene);
  assert.ok(result.visuals.children.length <= 4, 'mapa + cajas instanciadas');
  const nodes = new Map(), groups = new Map();
  const boxes = [];
  gltf.scene.traverse(object => {
    const data = object.userData;
    if (data.kind === 'route_node') nodes.set(data.node_id, object.getWorldPosition(new THREE.Vector3()));
    if (data.kind === 'product_group') groups.set(data.product_id, data);
    if (data.kind === 'product_box') boxes.push(object);
  });
  assert.equal(groups.size, 247);
  assert.equal(boxes.length, 988);
  assert.equal(nodes.size, 276);
  let facing = 0;
  for (const box of boxes) {
    const face = boxFrontFace(box);
    assert.ok(Math.abs(face.normal.y) < 0.01, 'la etiqueta es vertical');
    assert.ok(face.width > 0.2 && face.height > 0.2);
    const node = nodes.get(groups.get(box.userData.product_id).route_node);
    assert.ok(node, 'cada producto apunta a un nodo existente');
    if (node.clone().sub(face.center).setY(0).dot(face.normal) > 0) facing++;
  }
  // El frente mira hacia el pasillo donde está su nodo (se toleran esquinas).
  assert.ok(facing / boxes.length > 0.9, `frentes hacia el pasillo: ${facing}/${boxes.length}`);
  for (const [id] of groups) {
    const productBoxes = boxes.filter(box => box.userData.product_id === id);
    assert.equal(productBoxes.length, 4);
    assert.deepEqual(productBoxes.map(box => `${box.userData.row}:${box.userData.column}`).sort(),
      ['1:1', '1:2', '2:1', '2:2'], 'cuatro cajas en un bloque de dos por dos');
  }
});
