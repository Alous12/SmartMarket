import * as THREE from 'three';
import {S, UP, home, send, products, productBoxes, boxMeshes, requestRender} from './state.js';
import {animateTo, offsetFromTarget, views} from './camera.js';
import {selectProduct} from './products.js';
import {buildAvatar, setGhosts} from './avatar.js';
import {showRoute} from './route_overlay.js';

// Comandos que Flutter invoca vía window.smartMarket (nombres y argumentos estables).
export function createCommands(dispose) {
  return {
    reset() { selectProduct(null, false); animateTo(home.position, home.target); },
    setView(name) {
      const view = views[name]?.();
      if (view) animateTo(view.position, view.target);
    },
    zoomBy(factor) {
      const {controls} = S;
      const offset = offsetFromTarget();
      const length = THREE.MathUtils.clamp(offset.length() / factor, controls.minDistance, controls.maxDistance);
      animateTo(controls.target.clone().add(offset.setLength(length)), controls.target, 220);
    },
    rotateBy(degrees) {
      const offset = offsetFromTarget().applyAxisAngle(UP, THREE.MathUtils.degToRad(degrees));
      animateTo(S.controls.target.clone().add(offset), S.controls.target, 300);
    },
    panBy(dx, dz) {
      // dx, dz en fracciones del tamaño visible; se mueve en el plano del suelo
      const offset = offsetFromTarget();
      const forward = offset.clone().setY(0).normalize().negate();
      const right = new THREE.Vector3().crossVectors(forward, UP);
      const step = Math.max(1, offset.length() * 0.6);
      const delta = right.multiplyScalar(dx * step).add(forward.multiplyScalar(dz * step));
      animateTo(S.camera.position.clone().add(delta), S.controls.target.clone().add(delta), 260);
    },
    setOneFingerMode(mode) {
      S.controls.touches.ONE = mode === 'pan' ? THREE.TOUCH.PAN : THREE.TOUCH.ROTATE;
      S.controls.mouseButtons.LEFT = mode === 'pan' ? THREE.MOUSE.PAN : THREE.MOUSE.ROTATE;
    },
    setProductNames(names) {
      let changed = 0;
      for (const [id, name] of Object.entries(names ?? {})) {
        if (S.labels.setName(id, name)) changed++;
        const entry = products.get(id);
        if (entry) entry.name = String(name);
      }
      requestRender();
      return changed;
    },
    /** Muestra solo las cajas de estos productos; el resto se oculta (borrados en la BD). */
    setAvailableProducts(ids) {
      const available = new Set((ids ?? []).map(String));
      const hidden = new Set();
      productBoxes.length = 0;
      const touched = new Set();
      const zero = new THREE.Matrix4().makeScale(0, 0, 0);
      for (const {mesh, productId} of boxMeshes) {
        const show = available.has(productId);
        if (show) productBoxes.push(mesh); else hidden.add(productId);
        const binding = S.meshBindings.get(mesh.uuid);
        if (!binding) continue;
        if (binding.index === null) {
          binding.mesh.visible = show;
        } else {
          binding.mesh.setMatrixAt(binding.index, show ? mesh.matrixWorld : zero);
          touched.add(binding.mesh);
        }
      }
      touched.forEach(visual => { visual.instanceMatrix.needsUpdate = true; });
      S.labels.setHidden(hidden);
      S.hiddenBoxes = hidden;
      setGhosts(hidden);
      requestRender();
      return hidden.size;
    },
    /** Activa la edición: muestra el avatar (en el nodo indicado) y los espacios libres. */
    setEditMode(args) {
      const {on, start} = args ?? {};
      S.editMode = Boolean(on);
      S.avatar ??= buildAvatar();
      S.avatar.visible = S.editMode;
      S.walk = null;
      S.carried.visible = false;
      const startPosition = S.routeOverlay.positions.get(String(start));
      if (S.editMode && startPosition) S.avatar.position.copy(startPosition);
      setGhosts(S.hiddenBoxes);
      requestRender();
    },
    /** Camina el avatar por los nodos indicados; avisa con avatarArrived {token}. */
    walkAvatar(args) {
      const {nodes = [], token} = args ?? {};
      const points = nodes.map(n => S.routeOverlay.positions.get(String(n))).filter(Boolean);
      if (!S.avatar || !points.length) { send({type: 'avatarArrived', token}); return false; }
      S.walk = {points, index: 0, last: performance.now(), token};
      requestRender();
      return true;
    },
    carry(value) { if (S.carried) S.carried.visible = Boolean(value); requestRender(); },
    setProductName(id, name) { return this.setProductNames({[id]: name}); },
    selectProduct(id, focus = true) { return selectProduct(id == null ? null : String(id), focus); },
    showNodes(value) { S.nodesOverlay.visible = Boolean(value); requestRender(); },
    showRoute(route) { return showRoute(route); },
    setContinuous(value) {
      S.continuous = Boolean(value);
      S.frames = 0;
      S.frameStart = performance.now();
      S.lastPublished = 0;
      requestRender();
    },
    setActive(value) {
      S.active = Boolean(value);
      S.frames = 0;
      S.frameStart = performance.now();
      if (!S.active && S.scheduled) { cancelAnimationFrame(S.scheduled); S.scheduled = 0; }
      if (S.active) requestRender();
    },
    dispose,
  };
}
