import * as THREE from 'three';

// Etiquetas dinámicas de producto. Todas las etiquetas comparten una textura
// (atlas de 2048 px) y una sola geometría: 1 llamada de dibujo en total.
// Cambiar un nombre solo redibuja su celda del atlas.
export const ATLAS_SIZE = 2048;
export const CELL_W = 256;
export const CELL_H = 64;
const COLS = ATLAS_SIZE / CELL_W;
const ROWS = ATLAS_SIZE / CELL_H;
export const MAX_LABELS = COLS * ROWS;

const _center = new THREE.Vector3();
const _right = new THREE.Vector3();
const _up = new THREE.Vector3();
const _normal = new THREE.Vector3();

/**
 * Cara frontal de una caja de producto, en coordenadas del mundo.
 * Convención de ambos .blend: el frente es el eje local -Y de Blender, que en
 * glTF es el eje local +Z. X local es la derecha del cliente e Y local es arriba.
 */
export function boxFrontFace(mesh) {
  const geometry = mesh.geometry;
  if (!geometry.boundingBox) geometry.computeBoundingBox();
  const box = geometry.boundingBox;
  const e = mesh.matrixWorld.elements;
  const axis = (i, target) => target.set(e[i * 4], e[i * 4 + 1], e[i * 4 + 2]);
  const sx = box.max.x - box.min.x, sy = box.max.y - box.min.y;
  _center.set((box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2, box.max.z)
    .applyMatrix4(mesh.matrixWorld);
  const right = axis(0, _right).multiplyScalar(sx);
  const up = axis(1, _up).multiplyScalar(sy);
  const normal = axis(2, _normal).normalize();
  return {
    center: _center.clone(),
    right: right.clone(),
    up: up.clone(),
    normal: normal.clone(),
    width: right.length(),
    height: up.length(),
  };
}

export class ProductLabels {
  constructor({canvas, maxAnisotropy = 1}) {
    this.canvas = canvas;
    this.context = canvas.getContext('2d');
    canvas.width = ATLAS_SIZE;
    canvas.height = ATLAS_SIZE;
    this.cells = new Map();       // product_id -> índice de celda
    this.names = new Map();       // product_id -> nombre visible
    this.selected = null;
    this.texture = new THREE.CanvasTexture(canvas);
    this.texture.colorSpace = THREE.SRGBColorSpace;
    this.texture.anisotropy = maxAnisotropy;
    this.texture.generateMipmaps = true;
    this.texture.minFilter = THREE.LinearMipmapLinearFilter;
    this.material = new THREE.MeshBasicMaterial({
      map: this.texture,
      polygonOffset: true,
      polygonOffsetFactor: -2,
      polygonOffsetUnits: -2,
      toneMapped: false,
    });
    this.mesh = null;
  }

  /** Crea una etiqueta por caja. boxes: [{mesh, productId, name}] */
  build(boxes) {
    const quads = [];
    for (const {mesh, productId, name} of boxes) {
      if (!this.cells.has(productId)) {
        if (this.cells.size >= MAX_LABELS) continue;
        this.cells.set(productId, this.cells.size);
        this.names.set(productId, name);
      }
      quads.push({face: boxFrontFace(mesh), cell: this.cells.get(productId)});
    }
    const positions = new Float32Array(quads.length * 12);
    const uvs = new Float32Array(quads.length * 8);
    const indices = new Uint32Array(quads.length * 6);
    const corner = new THREE.Vector3();
    quads.forEach(({face, cell}, q) => {
      // La placa ocupa el 92 % del ancho y hasta el 70 % del alto de la cara,
      // conservando la proporción de la celda para que el texto no se deforme.
      const aspect = CELL_W / CELL_H;
      let w = face.width * 0.92;
      let h = Math.min(face.height * 0.7, w / aspect);
      w = Math.min(w, h * aspect * 1.6);
      const r = face.right.clone().setLength(w / 2);
      const u = face.up.clone().setLength(h / 2);
      const base = face.center.clone().addScaledVector(face.normal, 0.006);
      [[-1, -1], [1, -1], [1, 1], [-1, 1]].forEach(([a, b], i) => {
        corner.copy(base).addScaledVector(r, a).addScaledVector(u, b);
        positions.set([corner.x, corner.y, corner.z], q * 12 + i * 3);
      });
      const col = cell % COLS, row = Math.floor(cell / COLS);
      const u0 = (col * CELL_W + 2) / ATLAS_SIZE, u1 = ((col + 1) * CELL_W - 2) / ATLAS_SIZE;
      const v1 = 1 - (row * CELL_H + 2) / ATLAS_SIZE, v0 = 1 - ((row + 1) * CELL_H - 2) / ATLAS_SIZE;
      uvs.set([u0, v0, u1, v0, u1, v1, u0, v1], q * 8);
      const k = q * 4;
      indices.set([k, k + 1, k + 2, k, k + 2, k + 3], q * 6);
    });
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
    geometry.setIndex(new THREE.BufferAttribute(indices, 1));
    geometry.computeBoundingSphere();
    this.mesh = new THREE.Mesh(geometry, this.material);
    this.mesh.name = 'Etiquetas de productos';
    this.mesh.matrixAutoUpdate = false;
    for (const id of this.cells.keys()) this.draw(id);
    this.texture.needsUpdate = true;
    return this.mesh;
  }

  setName(productId, name) {
    if (!this.cells.has(productId)) return false;
    this.names.set(productId, String(name));
    this.draw(productId);
    this.texture.needsUpdate = true;
    return true;
  }

  setSelected(productId) {
    const previous = this.selected;
    this.selected = this.cells.has(productId) ? productId : null;
    if (previous) this.draw(previous);
    if (this.selected) this.draw(this.selected);
    this.texture.needsUpdate = true;
  }

  draw(productId) {
    const cell = this.cells.get(productId);
    const ctx = this.context;
    const x = (cell % COLS) * CELL_W, y = Math.floor(cell / COLS) * CELL_H;
    const selected = productId === this.selected;
    ctx.save();
    ctx.clearRect(x, y, CELL_W, CELL_H);
    ctx.fillStyle = selected ? '#345f2c' : '#fbfbf6';
    ctx.fillRect(x, y, CELL_W, CELL_H);
    ctx.fillStyle = selected ? '#a8d983' : '#345f2c';
    ctx.fillRect(x, y + CELL_H - 7, CELL_W, 7);
    ctx.strokeStyle = selected ? '#a8d983' : '#c9d2c2';
    ctx.lineWidth = 3;
    ctx.strokeRect(x + 1.5, y + 1.5, CELL_W - 3, CELL_H - 3);
    const text = String(this.names.get(productId) ?? productId);
    const maxWidth = CELL_W - 20;
    const font = size => `700 ${size}px system-ui, -apple-system, Roboto, sans-serif`;
    const fits = (line, size) => { ctx.font = font(size); return ctx.measureText(line).width <= maxWidth; };
    let lines = [text], size = 34;
    while (size > 22 && !fits(text, size)) size -= 2;
    if (!fits(text, size)) {
      // Nombre largo: dos líneas, partiendo por el espacio más centrado.
      const words = text.split(/\s+/);
      let best = [text, ''], bestWidth = Infinity;
      for (let i = 1; i < words.length; i++) {
        const a = words.slice(0, i).join(' '), b = words.slice(i).join(' ');
        ctx.font = font(22);
        const width = Math.max(ctx.measureText(a).width, ctx.measureText(b).width);
        if (width < bestWidth) { bestWidth = width; best = [a, b]; }
      }
      lines = best[1] ? best : [text];
      size = 24;
      while (size > 12 && !lines.every(line => fits(line, size))) size -= 1;
    }
    ctx.font = font(size);
    ctx.fillStyle = selected ? '#ffffff' : '#1f2a1c';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.beginPath();
    ctx.rect(x + 6, y, CELL_W - 12, CELL_H);
    ctx.clip();
    const middle = y + (CELL_H - 7) / 2 + 1;
    const gap = size * 1.05;
    lines.forEach((line, i) => ctx.fillText(line, x + CELL_W / 2, middle + (i - (lines.length - 1) / 2) * gap));
    ctx.restore();
  }

  dispose() {
    this.mesh?.geometry.dispose();
    this.material.dispose();
    this.texture.dispose();
  }
}
