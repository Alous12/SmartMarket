import * as THREE from 'three';
import {S, requestRender} from './state.js';

export function buildNodesOverlay(root) {
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
  S.scene.add(group);
  return group;
}

export function buildRouteOverlay(root) {
  const positions = new Map();
  root.traverse(object => {
    if (object.userData.kind !== 'route_node') return;
    const id = String(object.userData.node_id ?? object.name);
    positions.set(id, object.getWorldPosition(new THREE.Vector3()));
  });
  const group = new THREE.Group();
  group.name = 'Ruta calculada';
  group.visible = false;
  S.scene.add(group);
  return {group, positions};
}

const ROUTE_COLORS = {pending: 0xf06435, done: 0x2fae6b, outline: 0xffffff, start: 0x1f4fa8};

// Cinta plana con ancho real (las líneas WebGL siempre miden 1 px) más
// uniones redondeadas y, opcionalmente, flechas que indican el sentido.
function buildRibbon(points, width, color, order, {arrows = false, arrowsOnly = false} = {}) {
  const positions = [];
  const half = width / 2;
  const quad = (a, b, c, d) => positions.push(...a, ...b, ...c, ...b, ...d, ...c);
  const arrowSpacing = 2.4;
  let sinceArrow = arrowSpacing / 2;
  const disc = (p, radius) => {
    const steps = 12;
    for (let i = 0; i < steps; i++) {
      const a0 = (i / steps) * Math.PI * 2;
      const a1 = ((i + 1) / steps) * Math.PI * 2;
      positions.push(p.x, p.y, p.z,
        p.x + Math.cos(a0) * radius, p.y, p.z + Math.sin(a0) * radius,
        p.x + Math.cos(a1) * radius, p.y, p.z + Math.sin(a1) * radius);
    }
  };
  points.forEach((p, i) => {
    if (!arrowsOnly) disc(p, half);
    if (i === 0) return;
    const prev = points[i - 1];
    const dx = p.x - prev.x;
    const dz = p.z - prev.z;
    const length = Math.hypot(dx, dz);
    if (length < 1e-4) return;
    const ux = dx / length;
    const uz = dz / length;
    const nx = -uz * half;
    const nz = ux * half;
    if (!arrowsOnly) quad([prev.x + nx, prev.y, prev.z + nz], [p.x + nx, p.y, p.z + nz],
      [prev.x - nx, prev.y, prev.z - nz], [p.x - nx, p.y, p.z - nz]);
    if (!arrows) return;
    let travelled = arrowSpacing - sinceArrow;
    for (; travelled < length; travelled += arrowSpacing) {
      const cx = prev.x + ux * travelled;
      const cz = prev.z + uz * travelled;
      const size = half * 1.1;
      positions.push(
        cx + ux * size, prev.y, cz + uz * size,
        cx - ux * size * 0.7 + (-uz) * size, prev.y, cz - uz * size * 0.7 + ux * size,
        cx - ux * size * 0.7 - (-uz) * size, prev.y, cz - uz * size * 0.7 - ux * size);
    }
    sinceArrow = length - (travelled - arrowSpacing);
  });
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({
    color, toneMapped: false, side: THREE.DoubleSide, depthTest: false,
  }));
  mesh.renderOrder = order;
  mesh.frustumCulled = false;
  return mesh;
}

export function showRoute(route) {
  if (!S.routeOverlay) return false;
  const {group, positions} = S.routeOverlay;
  group.visible = false;
  const geometries = new Set();
  const materials = new Set();
  for (const object of [...group.children]) {
    group.remove(object);
    if (object.geometry) geometries.add(object.geometry);
    const objectMaterials = Array.isArray(object.material) ? object.material : [object.material];
    objectMaterials.filter(Boolean).forEach(material => materials.add(material));
  }
  geometries.forEach(geometry => geometry.dispose());
  materials.forEach(material => material.dispose());
  const nodeIds = Array.isArray(route?.nodeIds) ? route.nodeIds.map(String) : [];
  if (!nodeIds.length) {
    group.visible = false;
    requestRender();
    return true;
  }
  const points = nodeIds.map(id => positions.get(id));
  if (points.some(point => !point)) return false;
  const lifted = points.map(point => point.clone().setY(point.y + 0.16));
  const progress = THREE.MathUtils.clamp(Number(route.progressIndex) || 0, 0, lifted.length - 1);
  const doneStops = Number(route.completedStops) || 0;
  const doneLine = lifted.slice(0, progress + 1);
  const pendingLine = lifted.slice(progress);

  if (pendingLine.length > 1) {
    group.add(buildRibbon(pendingLine, 0.62, ROUTE_COLORS.outline, 4));
    group.add(buildRibbon(pendingLine, 0.4, ROUTE_COLORS.pending, 5));
    group.add(buildRibbon(pendingLine, 0.3, ROUTE_COLORS.outline, 6, {arrows: true, arrowsOnly: true}));
  }
  if (doneLine.length > 1) {
    group.add(buildRibbon(doneLine, 0.62, ROUTE_COLORS.outline, 7));
    group.add(buildRibbon(doneLine, 0.4, ROUTE_COLORS.done, 8));
  }

  const stopNodes = Array.isArray(route.stopNodes)
    ? route.stopNodes.map(String)
    : (route.stopNodeIds ?? []).map(String);
  const sphereGeometry = new THREE.SphereGeometry(0.28, 14, 10);
  const addSphere = (point, color, scale, order) => {
    const marker = new THREE.Mesh(sphereGeometry, new THREE.MeshBasicMaterial({
      color, toneMapped: false, depthTest: false,
    }));
    marker.position.copy(point).setY(point.y + 0.3);
    marker.scale.setScalar(scale);
    marker.renderOrder = order;
    group.add(marker);
  };
  addSphere(points[0], ROUTE_COLORS.start, 1, 9);
  stopNodes.forEach((id, index) => {
    const point = positions.get(id);
    if (!point) return;
    if (index < doneStops) addSphere(point, ROUTE_COLORS.done, 0.9, 10);
    else if (index === doneStops) addSphere(point, ROUTE_COLORS.pending, 1.5, 10);
    else addSphere(point, ROUTE_COLORS.pending, 1, 10);
  });
  group.visible = true;
  requestRender();
  return true;
}
