import * as THREE from 'three';
import {OrbitControls} from './vendor/OrbitControls.js';
import {S, bounds, center, home, requestRender} from './state.js';

// Distancia para que una esfera de radio r quepa en el campo de visión más estrecho.
export function fitDistance(r) {
  const camera = S.camera;
  const vertical = THREE.MathUtils.degToRad(camera.fov) / 2;
  const horizontal = Math.atan(Math.tan(vertical) * camera.aspect);
  return r / Math.sin(Math.min(vertical, horizontal));
}

export function animateTo(position, target, duration = 450) {
  S.animation = {
    start: performance.now(), duration,
    fromPosition: S.camera.position.clone(), fromTarget: S.controls.target.clone(),
    toPosition: position.clone(), toTarget: target.clone(),
  };
  requestRender();
}

export function stepAnimation(now) {
  const animation = S.animation;
  const t = Math.min(1, (now - animation.start) / animation.duration);
  const k = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  S.camera.position.lerpVectors(animation.fromPosition, animation.toPosition, k);
  S.controls.target.lerpVectors(animation.fromTarget, animation.toTarget, k);
  if (t >= 1) S.animation = null;
}

export function offsetFromTarget() {
  return S.camera.position.clone().sub(S.controls.target);
}

export function clampTarget() {
  const {camera, controls} = S;
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

export const views = {
  inicio: () => ({position: home.position, target: home.target}),
  superior: () => ({
    position: center.clone().add(new THREE.Vector3(0, fitDistance(S.radius) * 0.85, 0.01)),
    target: center.clone(),
  }),
  frente: () => ({
    position: center.clone().add(new THREE.Vector3(0, 0.35, 0.94).multiplyScalar(fitDistance(S.radius) * 0.85)),
    target: center.clone(),
  }),
  pasillo: () => {
    const target = S.controls.target.clone();
    target.y = 1.2;
    const dir = offsetFromTarget().setY(0);
    if (dir.lengthSq() < 0.01) dir.set(0, 0, 1);
    dir.setLength(5);
    return {position: target.clone().add(dir).setY(1.65), target};
  },
};

// Vista inicial: desde la entrada (frente, +Z en glTF), en perspectiva como Blender.
export function placeHomeCamera() {
  const {camera} = S;
  const distance = fitDistance(S.radius) * 0.8;
  home.target.copy(center).setY(bounds.min.y);
  home.position.copy(home.target).add(new THREE.Vector3(-0.18, 0.78, 0.6).normalize().multiplyScalar(distance));
  camera.position.copy(home.position);
  camera.far = Math.max(2000, S.radius * 12);
  camera.updateProjectionMatrix();
}

export function createControls() {
  const controls = new OrbitControls(S.camera, S.renderer.domElement);
  S.controls = controls;
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
  controls.maxDistance = S.radius * 4;
  controls.maxPolarAngle = Math.PI * 0.497;
  controls.touches.ONE = THREE.TOUCH.ROTATE;
  controls.touches.TWO = THREE.TOUCH.DOLLY_PAN;
  controls.mouseButtons.LEFT = THREE.MOUSE.ROTATE;
  controls.mouseButtons.MIDDLE = THREE.MOUSE.DOLLY;
  controls.mouseButtons.RIGHT = THREE.MOUSE.PAN;
  controls.addEventListener('change', () => { clampTarget(); requestRender(); });
  return controls;
}
