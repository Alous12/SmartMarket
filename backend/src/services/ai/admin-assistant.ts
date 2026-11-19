import type { Branch, BranchProduct } from '../../models/catalog.js';

export const adminAssistantResponseSchema = {
  type: 'object',
  properties: {
    answer: { type: 'string' },
  },
  required: ['answer'],
  additionalProperties: false,
} as const;

export function buildAdminAssistantInstruction(
  branch: Branch,
  products: BranchProduct[],
): string {
  const inventory = products.map((product) => ({
    id: product.product_id,
    sku: product.sku,
    nombre: product.name,
    marca: product.brand,
    categoria: product.category_name,
    precio: product.price,
    unidad: product.unit_of_measure,
    stock: product.stock_quantity,
    ubicaciones: product.locations.map((location) => ({
      seccion: location.section_name,
      estante: location.shelf,
      x: location.coordinate_x,
      y: location.coordinate_y,
      z: location.coordinate_z,
    })),
  }));
  return [
    'Eres el asistente operativo de SmartMarket para un dependiente de supermercado.',
    'Responde en español, de forma breve, clara y útil; resume listas largas y omite repeticiones.',
    'Solo puedes usar el inventario JSON de la sucursal asignada incluido abajo.',
    'Nunca menciones, supongas, compares ni inventes productos de otra sucursal.',
    'Si preguntan por otra sucursal, indica que solo tienes acceso a la sucursal asignada.',
    'Puedes calcular totales, filtrar por categoría, ubicar productos, resumir valor de inventario,',
    'y crear rankings. Considera "a punto de agotarse" un stock mayor que 0 y menor o igual que 5;',
    'ordena esos productos de menor a mayor stock.',
    'No inventes ventas, demanda, fechas ni cantidades que no estén en los datos.',
    'Si el dato no existe o la respuesta depende de información externa, dilo explícitamente.',
    'Devuelve únicamente texto natural en la propiedad answer, sin reproducir todo el inventario.',
    `Sucursal asignada: ${branch.name} (ID ${branch.branch_id}).`,
    `Inventario actual: ${JSON.stringify(inventory)}`,
  ].join('\n');
}

export function parseAdminAssistantResponse(output: unknown): string {
  if (typeof output !== 'object' || output === null || Array.isArray(output)) {
    throw new Error('Respuesta inválida del asistente administrativo.');
  }
  const answer = (output as Record<string, unknown>).answer;
  if (typeof answer !== 'string' || !answer.trim()) {
    throw new Error('Respuesta inválida del asistente administrativo.');
  }
  return answer.trim();
}
