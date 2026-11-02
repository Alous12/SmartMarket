import * as THREE from 'three';
import {GLTFLoader} from './vendor/GLTFLoader.js';
import {instanceStoreMeshes} from './instancing.js';
import {S, send, bounds, center, productBoxes, boxMeshes, products, requestRender} from './state.js';
import {stepAnimation, placeHomeCamera, createControls} from './camera.js';
import {collectProducts, buildMarker} from './products.js';
import {stepWalk} from './avatar.js';
import {buildNodesOverlay, buildRouteOverlay} from './route_overlay.js';
import {installTapDetection} from './tap.js';
import {createCommands} from './commands.js';

const loading = new AbortController();

function releaseObjects(root) {
  const geometries = new Set(), materials = new Set(), textures = new Set();
  root?.traverse(object => {
    if (object.isInstancedMesh) object.dispose();
    if (object.geometry) geometries.add(object.geometry);
    const list = Array.isArray(object.material) ? object.material : [object.material];
    list.filter(Boolean).forEach(material => materials.add(material));
  });
  materials.forEach(material => {
    Object.values(material).filter(value => value?.isTexture).forEach(texture => textures.add(texture));
    material.dispose();
  });
  textures.forEach(texture => { texture.dispose(); texture.source.data?.close?.(); });
  geometries.forEach(geometry => geometry.dispose());
}

function visibilityChanged() {
  window.smartMarket?.setActive?.(!document.hidden);
}

function disposeViewer() {
  if (S.disposed) return;
  S.disposed = true;
  S.active = false;
  S.animation = null;
  loading.abort();
  cancelAnimationFrame(S.scheduled);
  S.scheduled = 0;
  S.controls?.dispose();
  window.removeEventListener('resize', resize);
  document.removeEventListener('visibilitychange', visibilityChanged);
  window.removeEventListener('pagehide', disposeViewer);
  // Las etiquetas son dueñas de su atlas; se liberan una sola vez.
  S.labels?.mesh?.removeFromParent();
  S.labels?.dispose();
  releaseObjects(S.scene);
  S.scene?.clear();
  productBoxes.length = 0;
  boxMeshes.length = 0;
  S.meshBindings = new Map();
  products.clear();
  S.renderer?.dispose();
  S.renderer?.forceContextLoss();
  S.renderer?.domElement.remove();
  window.smartMarket = {dispose: disposeViewer};
  S.renderer = S.scene = S.controls = S.labels = S.marker = S.nodesOverlay = S.routeOverlay = null;
}

// Disponible incluso si se cambia de mapa durante fetch/parseAsync.
window.smartMarket = {dispose: disposeViewer};
window.addEventListener('pagehide', disposeViewer);

function publish(fps) {
  const info = S.renderer.info.render;
  const finite = value => (Number.isFinite(value) ? value : 0);
  send({
    type: 'metrics',
    fps: finite(fps),
    drawCalls: finite(info.calls),
    triangles: finite(info.triangles),
  });
  S.lastPublished = performance.now();
}

function renderFrame(now) {
  S.scheduled = 0;
  if (!S.active || S.disposed) return;
  if (S.walk) stepWalk(now);
  if (S.animation) stepAnimation(now);
  S.controls.update();                   // amortiguación: pide otro cuadro mientras se mueve
  S.renderer.render(S.scene, S.camera);
  S.frames++;
  if (S.continuous && now - S.frameStart >= 1000) {
    publish(S.frames * 1000 / (now - S.frameStart));
    S.frames = 0;
    S.frameStart = now;
  } else if (!S.continuous && now - S.lastPublished >= 1000) {
    publish(0);
  }
  if (S.continuous || S.animation || S.walk) requestRender();
}
S.onFrame = renderFrame;

function resize() {
  const width = window.innerWidth, height = window.innerHeight;
  S.camera.aspect = width / Math.max(height, 1);
  S.camera.updateProjectionMatrix();
  S.renderer.setSize(width, height);
  requestRender();
}

async function setup() {
  const renderer = new THREE.WebGLRenderer({antialias: false, alpha: false, stencil: false});
  S.renderer = renderer;
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.setClearColor(0xf4f6f0);
  renderer.shadowMap.enabled = false;
  renderer.toneMapping = THREE.NoToneMapping;
  document.body.appendChild(renderer.domElement);
  renderer.domElement.addEventListener('webglcontextlost', event => {
    if (S.disposed) return;
    event.preventDefault();
    send({type: 'error', message: 'Se perdió el contexto WebGL.'});
  });
  S.scene = new THREE.Scene();
  S.camera = new THREE.PerspectiveCamera(50, window.innerWidth / Math.max(window.innerHeight, 1), 0.05, 2000);
  const loader = new GLTFLoader();
  const response = await fetch('./model.glb', {signal: loading.signal});
  if (!response.ok) throw new Error(`No se pudo cargar el modelo (${response.status}).`);
  const gltf = await loader.parseAsync(await response.arrayBuffer(), '');
  if (S.disposed) { releaseObjects(gltf.scene); return; }
  if (gltf.animations.length) throw new Error('Esta vista requiere un modelo estático.');
  const optimized = instanceStoreMeshes(gltf.scene);
  S.meshBindings = optimized.bindings;
  S.scene.add(gltf.scene, optimized.visuals);
  bounds.setFromObject(optimized.visuals);
  if (bounds.isEmpty()) throw new Error('El modelo no contiene geometría visible.');
  bounds.getCenter(center);
  S.radius = bounds.getSize(new THREE.Vector3()).length() / 2;
  collectProducts(gltf.scene);
  S.marker = buildMarker();
  S.nodesOverlay = buildNodesOverlay(gltf.scene);
  S.routeOverlay = buildRouteOverlay(gltf.scene);

  placeHomeCamera();
  const controls = createControls();
  controls.update();
  installTapDetection(renderer.domElement);
  resize();
  window.addEventListener('resize', resize);
  document.addEventListener('visibilitychange', visibilityChanged);

  window.smartMarket = createCommands(disposeViewer);
  renderer.render(S.scene, S.camera);
  send({
    type: 'ready',
    originalMeshes: optimized.originalMeshes,
    drawObjects: optimized.visuals.children.length,
    products: products.size,
    labels: S.labels.cells.size,
  });
  publish(0);
}

setup().catch(error => {
  if (!S.disposed) send({type: 'error', message: String(error?.stack ?? error)});
});
