// Geometría de un recorrido: una polilínea medida por la distancia desde su inicio.

const span = (a, b) => Math.hypot(b.x - a.x, b.y - a.y, b.z - a.z);

export function createPath(points) {
  const lengths = [0];
  for (let i = 1; i < points.length; i++) {
    lengths.push(lengths[i - 1] + span(points[i - 1], points[i]));
  }
  return {points, lengths, total: lengths[lengths.length - 1] ?? 0};
}

function segmentAt(path, distance) {
  const {lengths} = path;
  let index = 1;
  while (index < lengths.length - 1 && distance >= lengths[index]) index++;
  return index;
}

export function pointAt(path, distance) {
  const {points, lengths, total} = path;
  if (points.length < 2) return {...points[0]};
  const clamped = Math.min(Math.max(distance, 0), total);
  const index = segmentAt(path, clamped);
  const from = points[index - 1], to = points[index];
  const length = lengths[index] - lengths[index - 1];
  const t = length > 0 ? (clamped - lengths[index - 1]) / length : 0;
  return {
    x: from.x + (to.x - from.x) * t,
    y: from.y + (to.y - from.y) * t,
    z: from.z + (to.z - from.z) * t,
  };
}

/** Lo ya recorrido: desde el inicio hasta la posición actual. */
export function walkedPoints(path, distance) {
  const {points, lengths, total} = path;
  if (points.length < 2 || distance <= 1e-6) return [];
  const clamped = Math.min(distance, total);
  return [
    ...points.filter((_, index) => lengths[index] < clamped - 1e-6),
    pointAt(path, clamped),
  ];
}

/** Lo que falta por recorrer: desde la posición actual hasta el final. */
export function remainingPoints(path, distance) {
  const {points, lengths, total} = path;
  if (points.length < 2 || distance >= total - 1e-6) return [];
  const clamped = Math.max(distance, 0);
  return [
    pointAt(path, clamped),
    ...points.filter((_, index) => lengths[index] > clamped + 1e-6),
  ];
}
