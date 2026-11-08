import * as THREE from 'three';
import {GLTFLoader} from './vendor/GLTFLoader.js';
import {S, send, boxMeshes, ghosts, requestRender} from './state.js';
import {clearRoute, paintRoute} from './route_overlay.js';
import {pointAt} from './route_path.js';

const AVATAR_SPEED = 4;                  // metros por segundo
const FOLLOW_SPEED = 1.3;                // paso de una persona en el supermercado
const MAX_FOLLOW_SPEED = 3.5;            // al confirmar una parada lejana se ve caminar el tramo
const PAINT_STEP = 0.1;                  // cada cuánto se pinta lo recorrido (metros)

export function buildAvatar() {
  const group = new THREE.Group();
  const body = new THREE.MeshBasicMaterial({color: 0x1f4fa8, toneMapped: false});
  const skin = new THREE.MeshBasicMaterial({color: 0xf2c9a0, toneMapped: false});
  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.2, 0.7, 4, 12), body);
  torso.position.y = 0.75;
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.17, 16, 12), skin);
  head.position.y = 1.52;
  const crate = new THREE.Mesh(
    new THREE.BoxGeometry(0.3, 0.3, 0.3),
    new THREE.MeshBasicMaterial({color: 0xf06435, toneMapped: false}));
  crate.position.set(0, 0.85, 0.34);
  crate.visible = false;
  // Círculo que señala la posición desde la vista superior, entre los estantes.
  const ring = new THREE.Mesh(
    new THREE.CircleGeometry(0.6, 24),
    new THREE.MeshBasicMaterial({
      color: 0x1f4fa8, transparent: true, opacity: 0.35,
      depthWrite: false, toneMapped: false,
    }));
  ring.rotation.x = -Math.PI / 2;
  ring.position.y = 0.2;                 // sobre la línea y por debajo de los pies
  // Flecha en el piso: desde arriba el muñeco no deja ver hacia dónde mira.
  const arrow = new THREE.Mesh(
    new THREE.BufferGeometry().setAttribute('position', new THREE.Float32BufferAttribute(
      [-0.34, 0, 0.62, 0.34, 0, 0.62, 0, 0, 1.25], 3)),
    new THREE.MeshBasicMaterial({color: 0x1f4fa8, side: THREE.DoubleSide, depthTest: false, toneMapped: false}));
  arrow.position.y = 0.2;
  arrow.renderOrder = 11;
  group.add(torso, head, crate, ring, arrow);
  group.userData.placeholder = [torso, head];
  group.visible = false;
  group.name = 'Avatar';
  S.carried = crate;
  S.scene.add(group);
  return group;
}

/** Cambia el muñeco provisional por el del GLB. Si falla, el provisional se queda. */
export async function loadPerson() {
  const gltf = await new GLTFLoader().loadAsync('./personaje.glb');
  if (S.disposed) return;
  gltf.scene.traverse(object => {
    if (!object.isMesh) return;
    object.frustumCulled = false;
    object.renderOrder = 12;             // la línea ignora la profundidad: va antes
    const {color} = object.material;
    object.material.dispose();
    object.material = new THREE.MeshLambertMaterial({color});
  });
  // La tienda no usa luces (sus materiales no se iluminan): esto solo afecta al muñeco.
  S.scene.add(new THREE.HemisphereLight(0xffffff, 0x9aa095, 3));
  S.avatar ??= buildAvatar();
  S.avatar.userData.placeholder.forEach(part => { part.visible = false; });
  S.avatar.add(gltf.scene);
  const mixer = new THREE.AnimationMixer(gltf.scene);
  const [clip] = gltf.animations;
  S.person = {mixer, action: clip ? mixer.clipAction(clip) : null};
  setWalking(Boolean(S.walk || S.follow?.walking));
  requestRender();
}

/** Arranca o detiene la animación de caminar; quieto vuelve a la pose de pie. */
export function setWalking(walking) {
  const action = S.person?.action;
  if (!action) return;
  if (walking) action.play(); else action.stop();
}

const shortestTurn = (from, to) => Math.atan2(Math.sin(to - from), Math.cos(to - from));

/** Coloca al muñeco en una ruta nueva, en la pose indicada. */
export function startFollowing(path, pose) {
  S.avatar ??= buildAvatar();
  S.avatar.visible = true;
  setWalking(false);
  const walked = Math.min(Math.max(Number(pose?.walked) || 0, 0), path.total);
  const floor = path.points[0]?.y ?? 0;
  // El muñeco siempre está sobre la ruta: nunca atraviesa un estante.
  const {x, z} = path.points.length ? pointAt(path, walked) : {x: 0, z: 0};
  S.follow = {
    path, floor, rotation: pose?.rotation ?? 0,
    distance: walked, target: walked, painted: walked,
    active: false, walking: false, last: 0,
  };
  S.avatar.position.set(x, floor, z);
  S.avatar.rotation.y = S.follow.rotation;
}

export function stopFollowing() {
  S.follow = null;
  setWalking(false);
  if (S.avatar && !S.editMode) S.avatar.visible = false;
}

/** Nueva pose de la persona: el muñeco gira y camina hasta allí a su ritmo. */
export function setPose(pose) {
  const follow = S.follow;
  if (!follow || !pose) return;
  follow.rotation = Number(pose.rotation) || 0;
  const walked = Math.min(Math.max(Number(pose.walked) || 0, 0), follow.path.total);
  follow.target = walked;
  if (walked < follow.distance - 1e-3) {
    // Reinicio de la ruta: no tiene sentido caminar hacia atrás.
    follow.distance = follow.painted = walked;
    const {x, z} = pointAt(follow.path, walked);
    S.avatar.position.set(x, follow.floor, z);
    paintRoute(walked);
  }
  if (!follow.active) {
    follow.active = true;
    follow.last = performance.now();
  }
  requestRender();
}

export function stepFollow(now) {
  const follow = S.follow;
  // El cuadro puede llevar una marca anterior a la de la última pose recibida.
  const dt = Math.min(0.1, Math.max(0, now - follow.last) / 1000);
  follow.last = now;

  // Camina por la línea, nunca en recta hacia el destino: así dobla las
  // esquinas igual que la ruta y no atraviesa estantes.
  const left = follow.target - follow.distance;
  // Si los pasos llegan más rápido que el muñeco, acelera para no quedarse atrás.
  const speed = Math.min(MAX_FOLLOW_SPEED, Math.max(FOLLOW_SPEED, left * 1.5));
  const move = Math.min(Math.max(left, 0), speed * dt);
  follow.distance += move;
  const {x, z} = pointAt(follow.path, follow.distance);
  // La cámara acompaña al muñeco, como un navegador en modo navegación.
  if (!S.animation && S.controls) {
    const dx = x - S.avatar.position.x, dz = z - S.avatar.position.z;
    S.camera.position.x += dx;
    S.camera.position.z += dz;
    S.controls.target.x += dx;
    S.controls.target.z += dz;
  }
  S.avatar.position.set(x, follow.floor, z);

  const turn = shortestTurn(S.avatar.rotation.y, follow.rotation);
  S.avatar.rotation.y += turn * Math.min(1, dt * 12);

  const moving = follow.target - follow.distance > 1e-3;
  if (moving !== follow.walking) {
    follow.walking = moving;
    setWalking(moving);
  }
  if (moving) S.person?.mixer.update(dt * Math.min(speed / FOLLOW_SPEED, 2.5));

  if ((!moving && follow.painted !== follow.distance) ||
      follow.distance - follow.painted >= PAINT_STEP) {
    follow.painted = follow.distance;
    paintRoute(follow.distance);
  }
  if (!moving && follow.finishing) {
    clearRoute();
    return;
  }
  follow.active = moving || Math.abs(turn) > 0.01;
}

export function stepWalk(now) {
  const {avatar, walk} = S;
  const dt = Math.min(0.1, (now - walk.last) / 1000);
  walk.last = now;
  S.person?.mixer.update(dt);
  const before = avatar.position.clone();
  let move = AVATAR_SPEED * dt;
  while (move > 0 && walk.index < walk.points.length) {
    const target = walk.points[walk.index];
    const direction = target.clone().sub(avatar.position);
    const distance = direction.length();
    if (distance > 1e-4) avatar.rotation.y = Math.atan2(direction.x, direction.z);
    if (distance <= move) {
      avatar.position.copy(target);
      move -= distance;
      walk.index++;
    } else {
      avatar.position.addScaledVector(direction.normalize(), move);
      move = 0;
    }
  }
  const delta = avatar.position.clone().sub(before);
  if (!S.animation) { S.camera.position.add(delta); S.controls.target.add(delta); }
  if (walk.index >= walk.points.length) {
    const token = walk.token;
    S.walk = null;
    setWalking(false);
    send({type: 'avatarArrived', token});
  }
}

export function setGhosts(hiddenIds) {
  for (const {mesh, productId} of boxMeshes) {
    let ghost = ghosts.get(productId);
    if (!ghost) {
      ghost = new THREE.Mesh(mesh.geometry, new THREE.MeshBasicMaterial({
        color: 0x2fae6b, transparent: true, opacity: 0.35, depthWrite: false, toneMapped: false,
      }));
      mesh.matrixWorld.decompose(ghost.position, ghost.quaternion, ghost.scale);
      ghost.userData = mesh.userData;
      S.scene.add(ghost);
      ghosts.set(productId, ghost);
    }
    ghost.visible = S.editMode && hiddenIds.has(productId);
  }
}
