import * as THREE from 'three';

export function countTriangles(mesh) {
  return (mesh.geometry.index?.count ?? mesh.geometry.attributes.position.count) / 3;
}

// Keep the original hierarchy and extras for future inventory/route lookup.
// Render shared geometry/material with a separate static visual hierarchy.
export function instanceStoreMeshes(source) {
  source.updateMatrixWorld(true);
  const groups = new Map();
  let originalTriangles = 0;
  let originalMeshes = 0;
  source.traverseVisible(object => {
    if (!object.isMesh) return;
    if (object.isSkinnedMesh || object.morphTargetInfluences?.length) {
      throw new Error('La vista espera mallas estáticas, sin deformaciones.');
    }
    originalTriangles += countTriangles(object);
    originalMeshes++;
    const materials = Array.isArray(object.material) ? object.material : [object.material];
    const key = object.matrixWorld.determinant() < 0 ? object.uuid :
      `${object.geometry.uuid}/${materials.map(material => material.uuid).join(',')}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(object);
  });

  const visuals = new THREE.Group();
  visuals.name = 'Supermercado / vista optimizada';
  const bindings = new Map();
  for (const meshes of groups.values()) {
    const first = meshes[0];
    let visual;
    if (meshes.length === 1) {
      visual = new THREE.Mesh(first.geometry, first.material);
      visual.matrixAutoUpdate = false;
      visual.matrix.copy(first.matrixWorld);
      bindings.set(first.uuid, {mesh: visual, index: null});
    } else {
      visual = new THREE.InstancedMesh(first.geometry, first.material, meshes.length);
      meshes.forEach((mesh, index) => {
        visual.setMatrixAt(index, mesh.matrixWorld);
        bindings.set(mesh.uuid, {mesh: visual, index});
      });
      visual.instanceMatrix.needsUpdate = true;
      visual.computeBoundingSphere();
    }
    visual.name = first.name;
    visuals.add(visual);
  }
  source.visible = false;
  source.traverse(object => { object.matrixAutoUpdate = false; });
  return {visuals, bindings, originalTriangles, originalMeshes};
}
