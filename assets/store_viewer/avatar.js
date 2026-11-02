import * as THREE from 'three';
import {S, send, boxMeshes, ghosts} from './state.js';

const AVATAR_SPEED = 4;                  // metros por segundo

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
  group.add(torso, head, crate);
  group.visible = false;
  group.name = 'Avatar';
  S.carried = crate;
  S.scene.add(group);
  return group;
}

export function stepWalk(now) {
  const {avatar, walk} = S;
  const dt = Math.min(0.1, (now - walk.last) / 1000);
  walk.last = now;
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
