import * as THREE from 'three';
import {S, bounds, center, requestRender} from './state.js';
import {setPose, startFollowing, stopFollowing} from './avatar.js';
import {createPath, remainingPoints, walkedPoints} from './route_path.js';

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

/** Puntos cardinales en el piso, dentro de los muros para que entren en pantalla. */
export function buildCompass() {
  const group = new THREE.Group();
  group.name = 'Puntos cardinales';
  group.position.set(center.x, bounds.min.y + 0.2, center.z);
  const reach = {x: (bounds.max.x - bounds.min.x) / 2 - 2, z: (bounds.max.z - bounds.min.z) / 2 - 2};
  const letters = [['N', 0, -reach.z, '#e0583a'], ['S', 0, reach.z, '#1c1f1a'], ['E', reach.x, 0, '#1c1f1a'], ['O', -reach.x, 0, '#1c1f1a']];
  for (const [letter, x, z, color] of letters) {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 128;
    const context = canvas.getContext('2d');
    context.fillStyle = '#ffffff';
    context.beginPath();
    context.arc(64, 64, 60, 0, Math.PI * 2);
    context.fill();
    context.fillStyle = color;
    context.font = 'bold 84px sans-serif';
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillText(letter, 64, 70);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    const mark = new THREE.Mesh(
      new THREE.PlaneGeometry(2.4, 2.4),
      new THREE.MeshBasicMaterial({map: texture, transparent: true, depthTest: false, toneMapped: false}));
    mark.rotation.x = -Math.PI / 2;
    mark.position.set(x, 0, z);
    mark.renderOrder = 3;
    group.add(mark);
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
  const ribbons = new THREE.Group();
  const markers = new THREE.Group();
  group.add(ribbons, markers);
  S.scene.add(group);
  return {group, ribbons, markers, positions, path: null, key: ''};
}

const ROUTE_COLORS = {
  pending: 0xf06435, done: 0x2fae6b, outline: 0xffffff, start: 0x1f4fa8,
  base: 0x9aa0a6, walked: 0x2fae6b,
};
const LINE_HEIGHT = 0.16;

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

function clearGroup(group) {
  const geometries = new Set();
  const materials = new Set();
  for (const object of [...group.children]) {
    group.remove(object);
    if (object.geometry) geometries.add(object.geometry);
    if (object.material) materials.add(object.material);
  }
  geometries.forEach(geometry => geometry.dispose());
  materials.forEach(material => material.dispose());
}

const lifted = points => points.map(point => ({...point, y: point.y + LINE_HEIGHT}));

/**
 * Como en un navegador: la ruta en gris y lo recorrido en verde, sin borrar
 * nada. Si el camino vuelve por un pasillo ya recorrido, lo que falta se dibuja
 * encima: siempre se ve por dónde seguir.
 */
export function paintRoute(distance) {
  const {ribbons, path} = S.routeOverlay;
  clearGroup(ribbons);
  const full = lifted(path.points);
  if (full.length > 1) ribbons.add(buildRibbon(full, 0.62, ROUTE_COLORS.outline, 4));
  const walked = lifted(walkedPoints(path, distance));
  if (walked.length > 1) ribbons.add(buildRibbon(walked, 0.4, ROUTE_COLORS.walked, 5));
  const ahead = lifted(remainingPoints(path, distance));
  if (ahead.length > 1) {
    ribbons.add(buildRibbon(ahead, 0.4, ROUTE_COLORS.base, 6));
    // Las flechas solo en lo que falta: indican hacia dónde seguir.
    ribbons.add(buildRibbon(ahead, 0.3, ROUTE_COLORS.outline, 7, {arrows: true, arrowsOnly: true}));
  }
  requestRender();
}

/** Borra la ruta del mapa y deja de seguir al muñeco. */
export function clearRoute() {
  const overlay = S.routeOverlay;
  if (!overlay) return;
  overlay.group.visible = false;
  clearGroup(overlay.ribbons);
  clearGroup(overlay.markers);
  overlay.path = null;
  overlay.key = '';
  stopFollowing();
  requestRender();
}

export function showRoute(route) {
  if (!S.routeOverlay) return false;
  const overlay = S.routeOverlay;
  const {group, markers, positions} = overlay;
  const nodeIds = Array.isArray(route?.nodeIds) ? route.nodeIds.map(String) : [];
  const points = nodeIds.map(id => positions.get(id));
  if (!nodeIds.length || points.some(point => !point)) {
    clearRoute();
    return nodeIds.length === 0;
  }

  const key = nodeIds.join('|');
  if (route.finished) {
    // Último producto recogido: el muñeco termina de caminar hasta él y recién
    // entonces la ruta desaparece. Sin un recorrido en curso se borra ya.
    if (key === overlay.key && S.follow) {
      S.follow.finishing = true;
      setPose(route.pose);
    } else {
      clearRoute();
    }
    return true;
  }
  if (key === overlay.key && S.follow) {
    S.follow.finishing = false;
    setPose(route.pose);
  } else {
    overlay.key = key;
    overlay.path = createPath(points);
    startFollowing(overlay.path, route.pose);
    paintRoute(S.follow.distance);
  }

  clearGroup(markers);
  const doneStops = Number(route.completedStops) || 0;
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
    markers.add(marker);
  };
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
