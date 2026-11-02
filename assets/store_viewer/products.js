import * as THREE from 'three';
import {ProductLabels, boxFrontFace as boxFaceOf} from './labels.js';
import {S, products, productBoxes, boxMeshes, requestRender} from './state.js';
import {fitDistance, animateTo} from './camera.js';

export function collectProducts(root) {
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
      boxMeshes.push({mesh: object, productId: id});
      boxes.push({mesh: object, productId: id, name: String(data.display_name ?? id)});
    }
  });
  const labels = new ProductLabels({
    canvas: document.createElement('canvas'),
    maxAnisotropy: Math.min(4, S.renderer.capabilities.getMaxAnisotropy()),
  });
  S.labels = labels;
  if (boxes.length) {
    for (const box of boxes) {
      if (products.has(box.productId)) box.name = products.get(box.productId).name;
    }
    S.scene.add(labels.build(boxes));
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

export function buildMarker() {
  const group = new THREE.Group();
  const material = new THREE.MeshBasicMaterial({color: 0xe0583a, toneMapped: false});
  const cone = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.42, 16), material);
  cone.rotation.x = Math.PI;
  const ball = new THREE.Mesh(new THREE.SphereGeometry(0.16, 16, 10), material);
  ball.position.y = 0.3;
  group.add(cone, ball);
  group.visible = false;
  group.name = 'Marcador de producto';
  S.scene.add(group);
  return group;
}

export function selectProduct(id, focus) {
  const entry = products.get(id);
  S.labels.setSelected(entry ? id : null);
  if (!entry || !entry.faces) {
    S.marker.visible = false;
    requestRender();
    return false;
  }
  const marker = S.marker;
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
