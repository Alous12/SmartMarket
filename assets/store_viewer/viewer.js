import * as THREE from 'three';
import {GLTFLoader} from './vendor/GLTFLoader.js';
import {OrbitControls} from './vendor/OrbitControls.js';
import {instanceStoreMeshes} from './instancing.js';

const send = data => window.StoreViewer?.postMessage(JSON.stringify(data));
let renderer, scene, camera, controls;
let active = true, continuous = false, disposed = false, scheduled = 0;
let frames = 0, frameStart = performance.now(), lastPublished = 0;
let span = 80;

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
  renderer.render(scene, camera);
  frames++;
  if (continuous && now - frameStart >= 1000) {
    publish(frames * 1000 / (now - frameStart));
    frames = 0;
    frameStart = now;
  } else if (!continuous && now - lastPublished >= 1000) {
    publish(0);
  }
  if (continuous) requestRender();
}

function resize() {
  const width = window.innerWidth, height = window.innerHeight;
  const aspect = width / height;
  const worldHeight = Math.max(span * 0.7, span / aspect);
  camera.left = -worldHeight * aspect / 2;
  camera.right = worldHeight * aspect / 2;
  camera.top = worldHeight / 2;
  camera.bottom = -worldHeight / 2;
  camera.updateProjectionMatrix();
  renderer.setSize(width, height);
  requestRender();
}

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
  camera = new THREE.OrthographicCamera(-40, 40, 40, -40, 0.1, 1000);
  const loader = new GLTFLoader();
  const response = await fetch('./model.glb');
  if (!response.ok) throw new Error(`No se pudo cargar el modelo (${response.status}).`);
  const gltf = await loader.parseAsync(await response.arrayBuffer(), '');
  if (gltf.animations.length) throw new Error('Esta vista requiere un modelo estático.');
  const bounds = new THREE.Box3().setFromObject(gltf.scene);
  if (bounds.isEmpty()) throw new Error('El modelo no contiene geometría visible.');
  const size = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  span = Math.max(size.x + size.z, size.y * 2) * 0.82;
  const optimized = instanceStoreMeshes(gltf.scene);
  scene.add(gltf.scene, optimized.visuals);
  // Kept within this engine adapter; future inventory updates must also update
  // optimized.bindings and label geometry. No inventory behavior is implemented.
  camera.position.copy(center).add(new THREE.Vector3(70, 85, 70));
  camera.lookAt(center);
  controls = new OrbitControls(camera, renderer.domElement);
  controls.target.copy(center);
  controls.enableRotate = false;
  controls.enableDamping = false;
  controls.screenSpacePanning = false;
  controls.minZoom = 0.7;
  controls.maxZoom = 7;
  controls.touches.ONE = THREE.TOUCH.PAN;
  controls.touches.TWO = THREE.TOUCH.DOLLY_PAN;
  controls.mouseButtons.LEFT = THREE.MOUSE.PAN;
  controls.addEventListener('change', requestRender);
  controls.update();
  controls.saveState();
  resize();
  window.addEventListener('resize', resize);
  document.addEventListener('visibilitychange', () => window.smartMarket.setActive(!document.hidden));

  window.smartMarket = {
    reset() { controls.reset(); requestRender(); },
    zoomBy(factor) {
      camera.zoom = THREE.MathUtils.clamp(camera.zoom * factor, 0.7, 7);
      camera.updateProjectionMatrix();
      requestRender();
    },
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
      materials.forEach(material => material.dispose());
      renderer.dispose();
      renderer.forceContextLoss();
    },
  };
  renderer.render(scene, camera);
  send({type: 'ready', originalMeshes: optimized.originalMeshes, drawObjects: optimized.visuals.children.length});
  publish(0);
}

setup().catch(error => send({type: 'error', message: String(error)}));
