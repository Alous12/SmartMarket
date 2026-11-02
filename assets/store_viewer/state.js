import * as THREE from 'three';

export const send = data => window.StoreViewer?.postMessage(JSON.stringify(data));

// Estado mutable compartido entre módulos (se accede siempre como S.campo).
export const S = {
  renderer: null, scene: null, camera: null, controls: null, labels: null,
  marker: null, nodesOverlay: null, routeOverlay: null,
  active: true, continuous: false, disposed: false, scheduled: 0,
  animation: null,
  frames: 0, frameStart: performance.now(), lastPublished: 0,
  radius: 30,
  meshBindings: new Map(),               // uuid de malla original -> {mesh, index} visible
  editMode: false, avatar: null, walk: null, carried: null,
  hiddenBoxes: new Set(),
  onFrame: null,                         // callback del bucle de render (lo fija viewer.js)
};

export const bounds = new THREE.Box3();
export const center = new THREE.Vector3();
export const home = {position: new THREE.Vector3(), target: new THREE.Vector3()};
export const productBoxes = [];          // mallas originales (invisibles) para el toque
export const products = new Map();       // product_id -> {name, category, center, normal}
export const boxMeshes = [];             // {mesh, productId} de todas las cajas del modelo
export const ghosts = new Map();         // id de caja -> malla fantasma (espacio libre)
export const UP = new THREE.Vector3(0, 1, 0);

export function requestRender() {
  if (!S.active || S.disposed || S.scheduled) return;
  S.scheduled = requestAnimationFrame(S.onFrame);
}
