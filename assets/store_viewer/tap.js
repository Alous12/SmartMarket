import * as THREE from 'three';
import {S, send, productBoxes, ghosts} from './state.js';
import {selectProduct} from './products.js';

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();

export function installTapDetection(element) {
  const downs = new Map();
  let multi = false;
  element.addEventListener('pointerdown', event => {
    downs.set(event.pointerId, {x: event.clientX, y: event.clientY, t: performance.now()});
    if (downs.size > 1) multi = true;
    S.animation = null;
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
    raycaster.setFromCamera(pointer, S.camera);
    const targets = productBoxes.concat([...ghosts.values()].filter(g => g.visible));
    const hit = raycaster.intersectObjects(targets, false)[0];
    const id = hit?.object.userData.product_id;
    if (id !== undefined) {
      selectProduct(String(id), false);
      send({type: 'productTapped', id: String(id)});
    }
  };
  element.addEventListener('pointerup', finish);
  element.addEventListener('pointercancel', finish);
}
