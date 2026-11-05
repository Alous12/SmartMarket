import { readFileSync } from 'node:fs';

type Mat4 = number[];

interface GltfNode {
  name?: string;
  children?: number[];
  matrix?: Mat4;
  translation?: number[];
  rotation?: number[];
  scale?: number[];
  extras?: Record<string, unknown>;
}

interface Gltf {
  nodes?: GltfNode[];
  scene?: number;
  scenes?: Array<{ nodes?: number[] }>;
}

export type PointType = 'ENTRANCE' | 'CHECKOUT' | 'OTHER';

export interface SeedPoint {
  name: string;
  type: PointType;
  x: number;
  y: number;
  z: number;
}

export interface SeedProduct {
  sku: string;
  slot: string;
  name: string;
  category: string;
  section: string;
  shelf: string | null;
  x: number;
  y: number;
  z: number;
  boxCount: number;
}

export interface SeedBranchData {
  sections: string[];
  points: SeedPoint[];
  products: SeedProduct[];
}

function multiply(a: Mat4, b: Mat4): Mat4 {
  const out = new Array<number>(16).fill(0);
  for (let c = 0; c < 4; c++) {
    for (let r = 0; r < 4; r++) {
      for (let k = 0; k < 4; k++) out[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k];
    }
  }
  return out;
}

function localMatrix(node: GltfNode): Mat4 {
  if (node.matrix) return node.matrix;
  const [x, y, z, w] = node.rotation ?? [0, 0, 0, 1];
  const [sx, sy, sz] = node.scale ?? [1, 1, 1];
  const [tx, ty, tz] = node.translation ?? [0, 0, 0];
  return [
    (1 - 2 * (y * y + z * z)) * sx, 2 * (x * y + z * w) * sx, 2 * (x * z - y * w) * sx, 0,
    2 * (x * y - z * w) * sy, (1 - 2 * (x * x + z * z)) * sy, 2 * (y * z + x * w) * sy, 0,
    2 * (x * z + y * w) * sz, 2 * (y * z - x * w) * sz, (1 - 2 * (x * x + y * y)) * sz, 0,
    tx, ty, tz, 1,
  ];
}

function readGltf(path: string): Gltf {
  const bytes = readFileSync(path);
  const jsonLength = bytes.readUInt32LE(12);
  return JSON.parse(bytes.subarray(20, 20 + jsonLength).toString('utf8')) as Gltf;
}

const round = (value: number) => Math.round(value * 1000) / 1000;

function pointType(name: string): PointType | null {
  if (/acceso|entrada/i.test(name)) return 'ENTRANCE';
  if (/caja|checkout/i.test(name)) return 'CHECKOUT';
  return null;
}

/** Extrae sucursal, puntos y productos de los metadatos de un modelo GLB. */
export function readBranchModel(path: string): SeedBranchData {
  const gltf = readGltf(path);
  const nodes = gltf.nodes ?? [];
  const world = new Map<number, Mat4>();
  const visit = (index: number, parent: Mat4 | null) => {
    const local = localMatrix(nodes[index]);
    const matrix = parent ? multiply(parent, local) : local;
    world.set(index, matrix);
    for (const child of nodes[index].children ?? []) visit(child, matrix);
  };
  for (const root of gltf.scenes?.[gltf.scene ?? 0]?.nodes ?? []) visit(root, null);

  const position = (index: number) => {
    const m = world.get(index) ?? [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
    return { x: round(m[12]), y: round(m[13]), z: round(m[14]) };
  };

  const sectionNodes: Array<{ name: string; x: number; z: number }> = [];
  const points: SeedPoint[] = [];
  const groups: Array<Record<string, unknown>> = [];
  const slots = new Map<string, { x: number; y: number; z: number; shelf: string | null }>();

  nodes.forEach((node, index) => {
    const extras = node.extras;
    if (!extras || !world.has(index)) return;
    switch (extras.kind) {
      case 'section':
        sectionNodes.push({
          name: String(extras.display_name ?? extras.section_id),
          ...position(index),
        });
        break;
      case 'route_node': {
        const name = String(extras.node_id ?? node.name);
        const type = pointType(name);
        if (type) points.push({ name: name.slice(0, 100), type, ...position(index) });
        break;
      }
      case 'product_group':
        if (typeof extras.product_id === 'string') groups.push(extras);
        break;
      case 'product_location':
        slots.set(String(extras.slot_id), {
          ...position(index),
          shelf: extras.shelf_id ? String(extras.shelf_id) : null,
        });
        break;
    }
  });

  const sectionFor = (group: Record<string, unknown>, x: number, z: number) => {
    if (sectionNodes.length === 0) {
      return `Zona ${String(group.zona ?? group.category ?? 'general')}`;
    }
    return sectionNodes.reduce((best, section) =>
      Math.hypot(section.x - x, section.z - z) < Math.hypot(best.x - x, best.z - z)
        ? section
        : best,
    ).name;
  };

  const products: SeedProduct[] = [];
  for (const group of groups) {
    const slot = slots.get(String(group.slot_id));
    if (!slot) continue;
    products.push({
      sku: String(group.product_id).slice(0, 100),
      slot: String(group.slot_id).slice(0, 100),
      name: String(group.display_name ?? group.product_id).slice(0, 150),
      category: String(group.category ?? 'General').slice(0, 100),
      section: sectionFor(group, slot.x, slot.z).slice(0, 100),
      shelf: slot.shelf,
      x: slot.x,
      y: slot.y,
      z: slot.z,
      boxCount: Number(group.box_count ?? 1),
    });
  }

  const sections =
    sectionNodes.length > 0
      ? [...new Set(sectionNodes.map((section) => section.name.slice(0, 100)))]
      : [...new Set(products.map((product) => product.section))];
  return { sections, points, products };
}

export function normalizeName(name: string): string {
  return name
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/**
 * Ingredientes con los que empieza el nombre del producto (admite plural). Solo
 * se mira el inicio porque el resto describe otra cosa: "Soda limon" no es limón.
 */
export function matchIngredients<T extends { name: string }>(
  productName: string,
  ingredients: T[],
): T[] {
  const haystack = `${normalizeName(productName)} `;
  return ingredients.filter((ingredient) => {
    const phrase = normalizeName(ingredient.name);
    return [`${phrase} `, `${phrase}s `, `${phrase}es `].some((prefix) =>
      haystack.startsWith(prefix),
    );
  });
}

/** Precio de prueba estable por SKU, entre 5.00 y 34.90. */
export function demoPrice(sku: string): number {
  let hash = 0;
  for (const char of sku) hash = (hash * 31 + char.charCodeAt(0)) % 100000;
  return 5 + (hash % 300) / 10;
}
