"""Genera el muñeco de la app: low-poly, con esqueleto y animación de caminar.

Uso (desde la raíz del proyecto):
    blender --background --factory-startup --python Modelos_3D/scripts/crear_personaje.py

Crea Modelos_3D/personaje.blend y Modelos_3D/personaje.glb. Cada parte del cuerpo
sigue a un solo hueso (sin pesos mezclados), lo que mantiene el archivo pequeño.
Mira hacia -Y en Blender, que al exportar queda hacia +Z en glTF.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.dirname(HERE)
BLEND_OUT = os.path.join(OUT_DIR, "personaje.blend")
GLB_OUT = os.path.join(OUT_DIR, "personaje.glb")

CYCLE_FRAMES = 24  # dos pasos por segundo a 24 fps
FPS = 24

COLORS = {
    "Piel": (0.93, 0.72, 0.55),
    "Polera": (0.12, 0.31, 0.66),
    "Pantalon": (0.16, 0.18, 0.24),
    "Zapatos": (0.95, 0.42, 0.21),
    "Pelo": (0.17, 0.11, 0.08),
}

# nombre: (cabeza, cola, padre)
BONES = {
    "cadera": ((0, 0, 0.90), (0, 0, 1.02), None),
    "torso": ((0, 0, 1.02), (0, 0, 1.42), "cadera"),
    "cabeza": ((0, 0, 1.42), (0, 0, 1.70), "torso"),
    "brazo.L": ((0.25, 0, 1.38), (0.27, 0, 1.13), "torso"),
    "antebrazo.L": ((0.27, 0, 1.13), (0.28, 0, 0.88), "brazo.L"),
    "brazo.R": ((-0.25, 0, 1.38), (-0.27, 0, 1.13), "torso"),
    "antebrazo.R": ((-0.27, 0, 1.13), (-0.28, 0, 0.88), "brazo.R"),
    "muslo.L": ((0.10, 0, 0.90), (0.10, 0, 0.50), "cadera"),
    "pierna.L": ((0.10, 0, 0.50), (0.10, 0, 0.07), "muslo.L"),
    "muslo.R": ((-0.10, 0, 0.90), (-0.10, 0, 0.50), "cadera"),
    "pierna.R": ((-0.10, 0, 0.50), (-0.10, 0, 0.07), "muslo.R"),
}


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_materials():
    materials = {}
    for name, color in COLORS.items():
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        material.diffuse_color = (*color, 1)
        principled = material.node_tree.nodes.get("Principled BSDF")
        principled.inputs["Base Color"].default_value = (*color, 1)
        principled.inputs["Roughness"].default_value = 1
        materials[name] = material
    return materials


class Body:
    """Acumula las partes en una sola malla, cada una ligada a un hueso."""

    def __init__(self):
        self.mesh = bmesh.new()
        self.layer = self.mesh.verts.layers.deform.verify()
        self.bone_index = {name: index for index, name in enumerate(BONES)}
        self.material_index = {name: index for index, name in enumerate(COLORS)}

    def _assign(self, verts, faces, bone, material):
        for vert in verts:
            vert[self.layer][self.bone_index[bone]] = 1.0
        for face in faces:
            face.material_index = self.material_index[material]
            face.smooth = False

    def limb(self, start, end, radius_start, radius_end, bone, material, sides=6):
        """Tronco de cono entre dos puntos."""
        start, end = Vector(start), Vector(end)
        axis = end - start
        result = bmesh.ops.create_cone(
            self.mesh,
            cap_ends=True,
            segments=sides,
            radius1=radius_start,
            radius2=radius_end,
            depth=axis.length,
            matrix=(
                Matrix.Translation((start + end) / 2)
                @ axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
            ),
        )
        verts = result["verts"]
        self._assign(verts, {f for v in verts for f in v.link_faces}, bone, material)

    def box(self, center, size, bone, material):
        matrix = Matrix.Translation(center) @ Matrix.Diagonal((*size, 1))
        verts = bmesh.ops.create_cube(self.mesh, size=1, matrix=matrix)["verts"]
        self._assign(verts, {f for v in verts for f in v.link_faces}, bone, material)

    def ball(self, center, radius, bone, material, squash=1.0):
        matrix = Matrix.Translation(center) @ Matrix.Diagonal(
            (radius, radius, radius * squash, 1)
        )
        verts = bmesh.ops.create_icosphere(
            self.mesh, subdivisions=2, radius=1, matrix=matrix
        )["verts"]
        self._assign(verts, {f for v in verts for f in v.link_faces}, bone, material)


def build_body():
    body = Body()
    body.limb((0, 0, 0.90), (0, 0, 1.40), 0.17, 0.21, "torso", "Polera", sides=8)
    body.limb((0, 0, 0.84), (0, 0, 0.98), 0.16, 0.17, "cadera", "Pantalon", sides=8)
    body.limb((0, 0, 1.40), (0, 0, 1.47), 0.05, 0.05, "cabeza", "Piel")
    body.ball((0, 0, 1.56), 0.125, "cabeza", "Piel")
    body.ball((0, 0.015, 1.60), 0.13, "cabeza", "Pelo", squash=0.82)
    for side, sign in (("L", 1), ("R", -1)):
        body.limb((0.25 * sign, 0, 1.39), (0.27 * sign, 0, 1.13), 0.06, 0.05,
                  f"brazo.{side}", "Polera")
        body.limb((0.27 * sign, 0, 1.13), (0.28 * sign, 0, 0.92), 0.045, 0.04,
                  f"antebrazo.{side}", "Piel")
        body.ball((0.28 * sign, 0, 0.88), 0.05, f"antebrazo.{side}", "Piel")
        body.limb((0.10 * sign, 0, 0.90), (0.10 * sign, 0, 0.50), 0.085, 0.07,
                  f"muslo.{side}", "Pantalon")
        body.limb((0.10 * sign, 0, 0.50), (0.10 * sign, 0, 0.09), 0.065, 0.05,
                  f"pierna.{side}", "Pantalon")
        body.box((0.10 * sign, -0.05, 0.05), (0.10, 0.25, 0.10),
                 f"pierna.{side}", "Zapatos")
    return body


def build_armature():
    data = bpy.data.armatures.new("Esqueleto")
    armature = bpy.data.objects.new("Personaje", data)
    bpy.context.scene.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, _) in BONES.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        # Rodilla y codo se doblan alrededor del eje X local de cada hueso.
        bone.align_roll(Vector((0, -1, 0)))
    for name, (_, _, parent) in BONES.items():
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
            data.edit_bones[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def build_mesh(armature, materials):
    body = build_body()
    mesh = bpy.data.meshes.new("Cuerpo")
    body.mesh.to_mesh(mesh)
    body.mesh.free()
    for name in COLORS:
        mesh.materials.append(materials[name])
    obj = bpy.data.objects.new("Cuerpo", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for name in BONES:
        obj.vertex_groups.new(name=name)
    obj.parent = armature
    modifier = obj.modifiers.new("Esqueleto", "ARMATURE")
    modifier.object = armature
    return obj


def key(bone, frame, angle=None, location=None):
    if angle is not None:
        bone.rotation_euler = (math.radians(angle), 0, 0)
        bone.keyframe_insert("rotation_euler", frame=frame)
    if location is not None:
        bone.location = location
        bone.keyframe_insert("location", frame=frame)


def animate(armature):
    pose = armature.pose.bones
    for bone in pose:
        bone.rotation_mode = "XYZ"
    armature.animation_data_create()
    action = bpy.data.actions.new("Caminar")
    armature.animation_data.action = action

    # Una zancada completa; cada lado usa el mismo ciclo con media vuelta de desfase.
    for step in range(0, CYCLE_FRAMES + 1, 3):
        frame = step
        phase = 2 * math.pi * step / CYCLE_FRAMES
        for side, offset in (("L", 0.0), ("R", math.pi)):
            swing = math.sin(phase + offset)
            # La rodilla se dobla al pasar la pierna hacia adelante.
            knee = max(0.0, math.sin(phase + offset + math.pi / 2))
            key(pose[f"muslo.{side}"], frame, angle=THIGH_SIGN * 26 * swing)
            key(pose[f"pierna.{side}"], frame, angle=KNEE_SIGN * 42 * knee)
            key(pose[f"brazo.{side}"], frame, angle=-THIGH_SIGN * 20 * swing)
            key(pose[f"antebrazo.{side}"], frame, angle=KNEE_SIGN * -12)
        # El cuerpo sube dos veces por zancada y baja al apoyar cada pie.
        key(pose["cadera"], frame, location=(0, 0.018 * math.cos(2 * phase), 0))
    return action


# Signos del giro de los huesos: X local apunta hacia afuera del personaje.
THIGH_SIGN = 1
KNEE_SIGN = -1


def export():
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=False,
        export_optimize_animation_size=True,
        export_materials="EXPORT",
        export_image_format="NONE",
        export_texcoords=False,
        export_normals=True,
        export_tangents=False,
        export_cameras=False,
        export_lights=False,
    )


def render_preview(path, frame):
    """Vista de control: python crear_personaje.py -- <png> <frame>."""
    scene = bpy.context.scene
    scene.frame_set(frame)
    camera_data = bpy.data.cameras.new("Vista")
    camera = bpy.data.objects.new("Vista", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (2.6, -3.2, 1.3)
    target = Vector((0, 0, 0.85)) - camera.location
    camera.rotation_euler = target.to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    world = bpy.data.worlds.new("Fondo")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.9, 0.9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.4
    scene.world = world
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 360
    scene.render.resolution_y = 480
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    clear_scene()
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 0
    scene.frame_end = CYCLE_FRAMES
    materials = make_materials()
    armature = build_armature()
    build_mesh(armature, materials)
    animate(armature)
    export()
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    for index in range(0, len(args), 2):
        render_preview(args[index], int(args[index + 1]))


main()
