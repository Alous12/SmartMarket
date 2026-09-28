import * as THREE from 'three';
import {GLTFLoader} from './vendor/GLTFLoader.js';
import {OrbitControls} from './vendor/OrbitControls.js';
import {instanceStoreMeshes} from './instancing.js';
import {ProductLabels, boxFrontFace as boxFaceOf} from './labels.js';

const send = data => window.StoreViewer?.postMessage(JSON.stringify(data));
let renderer, scene, camera, controls, labels, marker, nodesOverlay;
let active = true, continuous = false, disposed = false, scheduled = 0;
let frames = 0, frameStart = performance.now(), lastPublished = 0;
let animation = null;
const bounds = new THREE.Box3();
const center = new THREE.Vector3();
let radius = 30;
const home = {position: new THREE.Vector3(), target: new THREE.Vector3()};
const productBoxes = [];                 // mallas originales (invisibles) para el toque
const products = new Map();              // product_id -> {name, category, center, normal}
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const UP = new THREE.Vector3(0, 1, 0);

function publish(fps) {
  const info = renderer.info.render;
  send({type: 'metrics', fps, drawCalls: info.calls, triangles: info.triangles});
  lastPublished = performance.now();
}

function requestRender() {
  if (!active || disposed || scheduled) return;
  scheduled = requestAnimationFrame(renderFrame);
}

function renderFrame(now) {
  scheduled = 0;
  if (!active || disposed) return;
  if (animation) stepAnimation(now);
  controls.update();                     // amortiguación: pide otro cuadro mientras se mueve
  renderer.render(scene, camera);
  frames++;
  if (continuous && now - frameStart >= 1000) {
    publish(frames * 1000 / (now - frameStart));
    frames = 0;
    frameStart = now;
  } else if (!continuous && now - lastPublished >= 1000) {
    publish(0);
  }
  if (continuous || animation) requestRender();
}

function resize() {
  const width = window.innerWidth, height = window.innerHeight;
  camera.aspect = width / Math.max(height, 1);
  camera.updateProjectionMatrix();
  renderer.setSize(width, height);
  requestRender();
}

// ---------------------------------------------------------------- cámara
// Distancia para que una esfera de radio r quepa en el campo de visión más estrecho.
function fitDistance(r) {
  const vertical = THREE.MathUtils.degToRad(camera.fov) / 2;
  const horizontal = Math.atan(Math.tan(vertical) * camera.aspect);
  return r / Math.sin(Math.min(vertical, horizontal));
}

function animateTo(position, target, duration = 450) {
  animation = {
    start: performance.now(), duration,
    fromPosition: camera.position.clone(), fromTarget: controls.target.clone(),
    toPosition: position.clone(), toTarget: target.clone(),
  };
  requestRender();
}

function stepAnimation(now) {
  const t = Math.min(1, (now - animation.start) / animation.duration);
  const k = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  camera.position.lerpVectors(animation.fromPosition, animation.toPosition, k);
  controls.target.lerpVectors(animation.fromTarget, animation.toTarget, k);
  if (t >= 1) animation = null;
}

function offsetFromTarget() {
  return camera.position.clone().sub(controls.target);
}

function clampTarget() {
  const margin = 6;
  const min = bounds.min.clone().subScalar(margin), max = bounds.max.clone().addScalar(margin);
  min.y = bounds.min.y - 1;
  max.y = bounds.max.y + 4;
  const clamped = controls.target.clone().clamp(min, max);
  if (!clamped.equals(controls.target)) {
    camera.position.add(clamped.clone().sub(controls.target));
    controls.target.copy(clamped);
  }
}

const views = {
  inicio: () => ({position: home.position, target: home.target}),
  superior: () => ({
    position: center.clone().add(new THREE.Vector3(0, fitDistance(radius) * 0.85, 0.01)),
    target: center.clone(),
  }),
  frente: () => ({
    position: center.clone().add(new THREE.Vector3(0, 0.35, 0.94).multiplyScalar(fitDistance(radius) * 0.85)),
    target: center.clone(),
  }),
  pasillo: () => {
    const target = controls.target.clone();
    target.y = 1.2;
    const dir = offsetFromTarget().setY(0);
    if (dir.lengthSq() < 0.01) dir.set(0, 0, 1);
    dir.setLength(5);
    return {position: target.clone().add(dir).setY(1.65), target};
  },
};

// ---------------------------------------------------------------- productos
function collectProducts(root) {
  const boxes = [];
  root.updateMatrixWorld(true);
  root.traverse(object => {
    const data = object.userData;
    if (data.kind === 'product_group' && data.product_id) {
      const id = String(data.product_id);
      const entry = products.get(id) ?? {center: new THREE.Vector3(), normal: new THREE.Vector3(), faces: 0};
      entry.name = String(data.display_name ?? id);
      entry.category = data.category ?? '';
      entry.routeNode = data.route_node ?? '';
      products.set(id, entry);
    }
    if (data.kind === 'product_box' && object.isMesh && data.product_id) {
      const id = String(data.product_id);
      productBoxes.push(object);
      boxes.push({mesh: object, productId: id, name: String(data.display_name ?? id)});
    }
  });
  labels = new ProductLabels({
    canvas: document.createElement('canvas'),
    maxAnisotropy: Math.min(4, renderer.capabilities.getMaxAnisotropy()),
  });
  if (boxes.length) {
    for (const box of boxes) {
      if (products.has(box.productId)) box.name = products.get(box.productId).name;
    }
    scene.add(labels.build(boxes));
    // centro y normal de cada producto para enfocarlo desde la app
    for (const box of boxes) {
      const face = boxFaceOf(box.mesh);
      const entry = products.get(box.productId) ??
        {name: box.name, category: '', center: new THREE.Vector3(), normal: new THREE.Vector3(), faces: 0};
      entry.center.add(face.center);
      entry.normal.add(face.normal);
      entry.faces++;
      products.set(box.productId, entry);
    }
    for (const entry of products.values()) {
      if (entry.faces) {
        entry.center.divideScalar(entry.faces);
        entry.normal.setY(0).normalize();
      }
    }
  }
}

function buildMarker() {
  const group = new THREE.Group();
  const material = new THREE.MeshBasicMaterial({color: 0xe0583a, toneMapped: false});
  const cone = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.42, 16), material);
  cone.rotation.x = Math.PI;
  const ball = new THREE.Mesh(new THREE.SphereGeometry(0.16, 16, 10), material);
  ball.position.y = 0.3;
  group.add(cone, ball);
  group.visible = false;
  group.name = 'Marcador de producto';
  scene.add(group);
  return group;
}

function selectProduct(id, focus) {
  const entry = products.get(id);
  labels.setSelected(entry ? id : null);
  if (!entry || !entry.faces) {
    marker.visible = false;
    requestRender();
    return false;
  }
  marker.visible = true;
  marker.position.copy(entry.center).addScaledVector(entry.normal, 0.25).setY(entry.center.y + 0.75);
  if (focus) {
    const target = entry.center.clone();
    const away = THREE.MathUtils.clamp(fitDistance(2.2), 3, 9);
    const position = target.clone().addScaledVector(entry.normal, away).add(new THREE.Vector3(0, away * 0.38, 0));
    animateTo(position, target, 600);
  }
  requestRender();
  return true;
}

// ---------------------------------------------------------------- nodos de ruta
function buildNodesOverlay(root) {
  const positions = new Map();
  root.traverse(object => {
    if (object.userData.kind !== 'route_node') return;
    const id = String(object.userData.node_id ?? object.name);
    positions.set(id, {point: object.getWorldPosition(new THREE.Vector3()), neighbours: object.userData.vecinos});
  });
  const group = new THREE.Group();
  group.name = 'Nodos de ruta';
  group.visible = false;
  if (!positions.size) return group;
  const material = new THREE.MeshBasicMaterial({color: 0x2f6fd1, toneMapped: false, depthTest: false});
  const spheres = new THREE.InstancedMesh(new THREE.SphereGeometry(0.16, 10, 6), material, positions.size);
  const matrix = new THREE.Matrix4();
  let i = 0;
  const segments = [];
  const seen = new Set();
  for (const [id, {point, neighbours}] of positions) {
    matrix.makeTranslation(point.x, point.y + 0.08, point.z);
    spheres.setMatrixAt(i++, matrix);
    const list = Array.isArray(neighbours) ? neighbours : String(neighbours ?? '').split(',');
    for (const other of list.map(value => value.trim()).filter(Boolean)) {
      const key = [id, other].sort().join('|');
      if (seen.has(key) || !positions.has(other)) continue;
      seen.add(key);
      const b = positions.get(other).point;
      segments.push(point.x, point.y + 0.08, point.z, b.x, b.y + 0.08, b.z);
    }
  }
  spheres.renderOrder = 3;
  group.add(spheres);
  if (segments.length) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(segments, 3));
    const lines = new THREE.LineSegments(geometry,
      new THREE.LineBasicMaterial({color: 0x2f6fd1, transparent: true, opacity: 0.75, depthTest: false}));
    lines.renderOrder = 2;
    group.add(lines);
  }
  scene.add(group);
  return group;
}

// ---------------------------------------------------------------- toque
function installTapDetection(element) {
  const downs = new Map();
  let multi = false;
  element.addEventListener('pointerdown', event => {
    downs.set(event.pointerId, {x: event.clientX, y: event.clientY, t: performance.now()});
    if (downs.size > 1) multi = true;
    animation = null;
  });
  const finish = event => {
    const down = downs.get(event.pointerId);
    downs.delete(event.pointerId);
    if (!down) return;
    const wasMulti = multi;
    if (!downs.size) multi = false;
    if (event.type !== 'pointerup' || wasMulti) return;
    const moved = Math.hypot(event.clientX - down.x, event.clientY - down.y);
    if (moved > 10 || performance.now() - down.t > 450) return;
    const rect = element.getBoundingClientRect();
    pointer.set(((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1);
    raycaster.setFromCamera(pointer, camera);
    const hit = raycaster.intersectObjects(productBoxes, false)[0];
    const id = hit?.object.userData.product_id;
    if (id !== undefined) {
      selectProduct(String(id), false);
      send({type: 'productTapped', id: String(id)});
    }
  };
  element.addEventListener('pointerup', finish);
  element.addEventListener('pointercancel', finish);
}

// ---------------------------------------------------------------- arranque
async function setup() {
  renderer = new THREE.WebGLRenderer({antialias: false, alpha: false, stencil: false});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.setClearColor(0xf4f6f0);
  renderer.shadowMap.enabled = false;
  renderer.toneMapping = THREE.NoToneMapping;
  document.body.appendChild(renderer.domElement);
  renderer.domElement.addEventListener('webglcontextlost', event => {
    if (disposed) return;
    event.preventDefault();
    send({type: 'error', message: 'Se perdió el contexto WebGL.'});
  });
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(50, window.innerWidth / Math.max(window.innerHeight, 1), 0.05, 2000);
  const loader = new GLTFLoader();
  const response = await fetch('./model.glb');
  if (!response.ok) throw new Error(`No se pudo cargar el modelo (${response.status}).`);
  const gltf = await loader.parseAsync(await response.arrayBuffer(), '');
  if (gltf.animations.length) throw new Error('Esta vista requiere un modelo estático.');
  const optimized = instanceStoreMeshes(gltf.scene);
  scene.add(gltf.scene, optimized.visuals);
  bounds.setFromObject(optimized.visuals);
  if (bounds.isEmpty()) throw new Error('El modelo no contiene geometría visible.');
  bounds.getCenter(center);
  radius = bounds.getSize(new THREE.Vector3()).length() / 2;
  collectProducts(gltf.scene);
  marker = buildMarker();
  nodesOverlay = buildNodesOverlay(gltf.scene);

  // Vista inicial: desde la entrada (frente, +Z en glTF), en perspectiva como Blender.
  const distance = fitDistance(radius) * 0.8;
  home.target.copy(center).setY(bounds.min.y);
  home.position.copy(home.target).add(new THREE.Vector3(-0.18, 0.78, 0.6).normalize().multiplyScalar(distance));
  camera.position.copy(home.position);
  camera.far = Math.max(2000, radius * 12);
  camera.updateProjectionMatrix();

  controls = new OrbitControls(camera, renderer.domElement);
  controls.target.copy(home.target);
  controls.enableDamping = true;
  controls.dampingFactor = 0.14;
  controls.enableRotate = true;
  controls.enablePan = true;
  controls.enableZoom = true;
  controls.zoomToCursor = true;          // acerca hacia el punto señalado, como Blender
  controls.screenSpacePanning = true;    // desplazamiento en el plano de la pantalla
  controls.rotateSpeed = 0.75;
  controls.panSpeed = 1.0;
  controls.zoomSpeed = 1.2;
  controls.minDistance = 0.35;
  controls.maxDistance = radius * 4;
  controls.maxPolarAngle = Math.PI * 0.497;
  controls.touches.ONE = THREE.TOUCH.ROTATE;
  controls.touches.TWO = THREE.TOUCH.DOLLY_PAN;
  controls.mouseButtons.LEFT = THREE.MOUSE.ROTATE;
  controls.mouseButtons.MIDDLE = THREE.MOUSE.DOLLY;
  controls.mouseButtons.RIGHT = THREE.MOUSE.PAN;
  controls.addEventListener('change', () => { clampTarget(); requestRender(); });
  controls.update();
  installTapDetection(renderer.domElement);
  resize();
  window.addEventListener('resize', resize);
  document.addEventListener('visibilitychange', () => window.smartMarket.setActive(!document.hidden));

  window.smartMarket = {
    reset() { selectProduct(null, false); animateTo(home.position, home.target); },
    setView(name) {
      const view = views[name]?.();
      if (view) animateTo(view.position, view.target);
    },
    zoomBy(factor) {
      const offset = offsetFromTarget();
      const length = THREE.MathUtils.clamp(offset.length() / factor, controls.minDistance, controls.maxDistance);
      animateTo(controls.target.clone().add(offset.setLength(length)), controls.target, 220);
    },
    rotateBy(degrees) {
      const offset = offsetFromTarget().applyAxisAngle(UP, THREE.MathUtils.degToRad(degrees));
      animateTo(controls.target.clone().add(offset), controls.target, 300);
    },
    panBy(dx, dz) {
      // dx, dz en fracciones del tamaño visible; se mueve en el plano del suelo
      const offset = offsetFromTarget();
      const forward = offset.clone().setY(0).normalize().negate();
      const right = new THREE.Vector3().crossVectors(forward, UP);
      const step = Math.max(1, offset.length() * 0.6);
      const delta = right.multiplyScalar(dx * step).add(forward.multiplyScalar(dz * step));
      animateTo(camera.position.clone().add(delta), controls.target.clone().add(delta), 260);
    },
    setOneFingerMode(mode) {
      controls.touches.ONE = mode === 'pan' ? THREE.TOUCH.PAN : THREE.TOUCH.ROTATE;
      controls.mouseButtons.LEFT = mode === 'pan' ? THREE.MOUSE.PAN : THREE.MOUSE.ROTATE;
    },
    setProductNames(names) {
      let changed = 0;
      for (const [id, name] of Object.entries(names ?? {})) {
        if (labels.setName(id, name)) changed++;
        const entry = products.get(id);
        if (entry) entry.name = String(name);
      }
      requestRender();
      return changed;
    },
    setProductName(id, name) { return this.setProductNames({[id]: name}); },
    selectProduct(id, focus = true) { return selectProduct(id == null ? null : String(id), focus); },
    showNodes(value) { nodesOverlay.visible = Boolean(value); requestRender(); },
    setContinuous(value) {
      continuous = Boolean(value);
      frames = 0;
      frameStart = performance.now();
      lastPublished = 0;
      requestRender();
    },
    setActive(value) {
      active = Boolean(value);
      frames = 0;
      frameStart = performance.now();
      if (!active && scheduled) { cancelAnimationFrame(scheduled); scheduled = 0; }
      if (active) requestRender();
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      cancelAnimationFrame(scheduled);
      controls.dispose();
      window.removeEventListener('resize', resize);
      const geometries = new Set(), materials = new Set();
      scene.traverse(object => {
        if (object.isInstancedMesh) object.dispose();
        if (object.geometry) geometries.add(object.geometry);
        const list = Array.isArray(object.material) ? object.material : [object.material];
        list.filter(Boolean).forEach(material => materials.add(material));
      });
      geometries.forEach(geometry => geometry.dispose());
      materials.forEach(material => { material.map?.dispose(); material.dispose(); });
      labels.dispose();
      renderer.dispose();
      renderer.forceContextLoss();
    },
  };
  renderer.render(scene, camera);
  send({
    type: 'ready',
    originalMeshes: optimized.originalMeshes,
    drawObjects: optimized.visuals.children.length,
    products: products.size,
    labels: labels.cells.size,
  });
  publish(0);
}

setup().catch(error => send({type: 'error', message: String(error?.stack ?? error)}));
