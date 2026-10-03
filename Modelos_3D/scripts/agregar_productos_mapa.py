# -*- coding: utf-8 -*-
"""
SmartMarket 3D - Añade productos editables a SmartMarket_mapa3D_2.blend (Blender 5.x)

Toma como referencia supermercado_natural.blend y replica su estructura de datos:

    slot_<SLOT>            EMPTY  kind=product_location  (slot_id, shelf_id, route_node)
      producto_<ID> | ...  EMPTY  kind=product_group     (product_id, display_name, category, ...)
        caja_<ID>_<fila><col>      MESH kind=product_box      (4 cajas: 2 columnas x 2 niveles)
          etiqueta_<ID>_<fila><col> FONT kind=editable_label  (texto editable)

Además normaliza los nodos de ruta (kind=route_node, node_id) y marca las zonas SKU
(kind=sku_zone) para que la app Flutter lea ambos supermercados con el mismo esquema.

Uso en Blender:   abrir SmartMarket_mapa3D_2.blend > Scripting > abrir este archivo > Run Script
Uso en consola:   blender -b SmartMarket_mapa3D_2.blend -P scripts/agregar_productos_mapa.py

El script es idempotente: borra los productos que haya creado antes y los vuelve a generar.
Para cambiar un nombre en Blender, edita el texto de la etiqueta y la propiedad display_name
del grupo; en la app los nombres se editan sin tocar el .blend.
"""
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
if not os.path.exists(os.path.join(HERE, "catalogo_nombres.py")):   # Run Script desde Blender
    HERE = bpy.path.abspath("//scripts")
if HERE not in sys.path:
    sys.path.insert(0, HERE)
from catalogo_nombres import nombre_para  # noqa: E402

BLEND_DIR = bpy.path.abspath("//") or os.path.dirname(HERE)
NATURAL_BLEND = os.path.join(BLEND_DIR, "supermercado_natural.blend")
ATLAS_REL = "//texturas/smartmarket_atlas_horneado.png"
GLB_OUT = os.path.join(BLEND_DIR, "supermercado_2.glb")

ROOT_NAME = "SmartMarket_Sucursal_Piloto"
COL_EXPORT = "EXPORT_glb"
COL_PRODUCTS = "PRODUCTOS / grupos de cuatro"
GROUP_ROOT = "PRODUCTOS_grupos"
BOX_MESH = "CAJA COMPARTIDA / 12 tris"
BOX_MAT = "Cajas / marfil por cara"
TEXT_MAT = "Grupos / texto"
ID_PREFIX = "PIL"

# Ancho util de la cara de cada modulo que corresponde a una zona SKU (m)
MODULE_WIDTH = {"E01": 3.4, "E02": 3.4, "E03": 3.4, "E04": 2.35, "E05": 2.4, "E06": 3.44,
                "F01": 1.3, "F02": 0.7, "F03": 2.0, "S03i": 2.4, "S01i": 2.4,
                "S07": 1.8}
DEFAULT_WIDTH = 2.9      # sectores S01-S08: dos zonas por modulo de 6.1 m


# ------------------------------------------------------------------------------------
def _scene():
    return bpy.data.scenes.get("SmartMarket_Mapa") or bpy.context.scene


def _append_from_natural():
    need_mesh = BOX_MESH not in bpy.data.meshes
    need_mats = [m for m in (BOX_MAT, TEXT_MAT) if m not in bpy.data.materials]
    if not (need_mesh or need_mats):
        return
    with bpy.data.libraries.load(NATURAL_BLEND, link=False) as (src, dst):
        dst.meshes = [BOX_MESH] if need_mesh else []
        dst.materials = need_mats


def _fix_atlas():
    img = bpy.data.images.get("SM_Atlas_Horneado")
    if img and not img.packed_file:
        img.filepath = ATLAS_REL
        try:
            img.reload()
        except RuntimeError:
            pass


def _clear_previous():
    for o in list(bpy.data.objects):
        if o.get("kind") in ("product_location", "product_group", "product_box", "editable_label") \
                or o.name == GROUP_ROOT:
            data = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if data is not None and data.users == 0 and isinstance(data, bpy.types.Curve):
                bpy.data.curves.remove(data)
    col = bpy.data.collections.get(COL_PRODUCTS)
    if col:
        bpy.data.collections.remove(col)


def _bvh():
    ob = bpy.data.objects["MAP_estatico"]
    dg = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(ob, dg, epsilon=0.0)


def _support_heights(bvh, x, y):
    """Alturas de superficies horizontales (repisas, tapas) en (x, y), de arriba abajo."""
    out, z = [], 3.2
    while z > 0.02:
        hit, normal, _i, _d = bvh.ray_cast(Vector((x, y, z)), Vector((0, 0, -1)), z)
        if hit is None:
            break
        if normal.z > 0.7 and hit.z > 0.05:
            out.append(round(hit.z, 3))
        z = hit.z - 0.01
    return out


def _levels(code, supports):
    """Devuelve (lista de (z_base, alto), columnas, modo, profundidad)."""
    # Cada bloque conserva cuatro cajas: dos columnas sobre dos niveles reales.
    if code == "E01":
        boards = sorted(s for s in supports if 0.8 <= s <= 1.7)
        assert len(boards) >= 2, f"Repisas E01 no encontradas: {supports}"
        return [(s + 0.006, 0.43) for s in boards[:2]], 2, "repisa", 0.42
    if code == "E06":
        boards = sorted(s for s in supports if 1.0 <= s <= 2.2)
        assert len(boards) >= 2, f"Repisas E06 no encontradas: {supports}"
        return [(s + 0.006, 0.53) for s in boards[:2]], 2, "repisa", 0.42
    if code == "E04":
        return [(0.506, 0.38), (1.066, 0.38)], 2, "escalonado", 0.42
    if code == "E03":
        return [(0.364, 0.30), (0.764, 0.30)], 2, "repisa", 0.38
    if code == "S07":
        return [(0.364, 0.33), (0.804, 0.33)], 2, "repisa", 0.38
    if code == "S08":
        return [(1.196, 0.32), (1.831, 0.32)], 2, "repisa", 0.38
    if code == "S02":
        return [(1.026, 0.25), (1.281, 0.25)], 2, "mostrador", 0.36
    if code == "S04":
        return [(0.78, 0.38), (1.30, 0.38)], 2, "puerta", 0.10
    if code in ("F01", "F02"):          # refrigeradores: frentes sobre la puerta de vidrio
        return [(0.60, 0.38), (1.15, 0.38)], 2, "puerta", 0.06
    top = supports[0] if supports else 0.9
    if code == "F03":                   # vitrina curva: exhibición sobre el respaldo
        return [(1.31, 0.24), (1.56, 0.24)], 2, "respaldo", 0.24
    if code == "E03":                   # isla baja: usar sus repisas, no la cubierta
        supports = [s for s in supports if s < top - 0.1] + [top]
    if top >= 1.6 or code == "E03":     # estanterías: dos repisas a la altura de la vista
        boards = sorted(s for s in supports if 0.45 <= s <= 1.55)
        pick = []
        for s in boards:
            above = [b for b in supports if b > s + 0.2]
            gap = (min(above) - s) if above else 0.45
            if gap >= 0.28 and (not pick or s - pick[-1][0] >= 0.28):
                pick.append((s + 0.005, min(0.36, gap - 0.05)))
        if len(pick) >= 2:
            pick = sorted(pick, key=lambda p: abs(p[0] - 1.0))[:2]
            return sorted(pick), 2, "repisa", 0.30
        return [(0.85, 0.34), (1.24, 0.34)], 2, "repisa", 0.30
    base = top + 0.005                  # muebles bajos: cajas apiladas encima
    return [(base, 0.25), (base + 0.255, 0.25)], 2, "encima", 0.32


def _label(name, text, box, frame, center, width, height, pid):
    # Editar el texto de una caja actualiza las cuatro etiquetas en Blender.
    cu = bpy.data.curves.get(f"NOMBRE_{pid}")
    if cu is not None:
        ob = bpy.data.objects.new(name, cu)
        ob["kind"], ob["product_id"], ob["text"] = "editable_label", pid, text
        return ob
    cu = bpy.data.curves.new(f"NOMBRE_{pid}", "FONT")
    cu.body = text
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    cu.resolution_u = 2
    cu.fill_mode = "BOTH"
    cu.size = min(height * 0.62, 0.24)
    est = 0.56 * cu.size * max(len(text), 1)    # ancho aproximado de Bfont
    if est > width * 0.9:
        cu.size *= width * 0.9 / est
    ob = bpy.data.objects.new(name, cu)
    ob.data.materials.append(bpy.data.materials[TEXT_MAT])
    ob["kind"], ob["product_id"], ob["text"] = "editable_label", pid, text
    return ob


def build(report=True):
    sc = _scene()
    previous_names = {o.get("product_id"): o.get("display_name") for o in sc.objects
                      if o.get("kind") == "product_group"}
    _append_from_natural()
    _fix_atlas()
    _clear_previous()

    root = bpy.data.objects[ROOT_NAME]
    exp = bpy.data.collections[COL_EXPORT]
    col = bpy.data.collections.new(COL_PRODUCTS)
    exp.children.link(col)
    groot = bpy.data.objects.new(GROUP_ROOT, None)
    col.objects.link(groot)
    groot.parent = root

    # Nodos de ruta con el mismo esquema que supermercado_natural
    nav = [o for o in bpy.data.objects if o.parent and o.parent.name == "NAV_nodos"]
    for o in nav:
        o["kind"], o["node_id"] = "route_node", o.name
    zones = sorted((o for o in bpy.data.objects if o.parent and o.parent.name == "SKU_zonas"),
                   key=lambda o: o.name)
    root["version_grafo"] = max(int(root.get("version_grafo", 1)), 4)
    root["productos"] = "PRODUCTOS_grupos: grupos de cuatro cajas con etiqueta editable"

    bvh = _bvh()
    box_mesh = bpy.data.meshes[BOX_MESH]
    per_cat, created, modes = {}, 0, {}
    up = Vector((0, 0, 1))
    for zid, z in enumerate(zones, start=1):
        z["kind"] = "sku_zone"
        code, cat = z["modulo"], z["categoria"]
        ang = z.rotation_euler.z - math.pi / 2
        n = Vector((math.cos(ang), math.sin(ang), 0.0))           # normal hacia el pasillo
        t = up.cross(n)                                            # derecha del cliente
        face = Vector((z.location.x, z.location.y, 0.0)) - n * 0.12
        if code == "S07":
            # La vitrina delantera es más corta que el panel trasero de este sector.
            # Sus dos bloques deben quedar dentro de la vitrina, no de la pared.
            siblings = [a for a in zones if a["instancia"] == z["instancia"]]
            midpoint = sum((a.location for a in siblings), Vector()) / len(siblings)
            along = (z.location - midpoint).dot(t)
            face += t * (-along + math.copysign(0.95, along))
        probe = face - n * 0.18
        levels, cols, mode, depth = _levels(code, _support_heights(bvh, probe.x, probe.y))
        modes[mode] = modes.get(mode, 0) + 1
        width = MODULE_WIDTH.get(code, DEFAULT_WIDTH)
        col_w = min(1.34, (width * 0.88 - 0.08 * (cols - 1)) / cols)
        if mode == "puerta":
            front = face - n * 0.02
        elif mode == "respaldo":
            front = face - n * 0.83
        elif mode == "encima":
            front = face - n * 0.03
        elif mode == "mostrador":
            front = face - n * 0.36
        elif mode == "escalonado":
            front = face - n * 0.04
        else:
            front = face - n * 0.04
        idx = per_cat.get(cat, 0)
        per_cat[cat] = idx + 1
        name = nombre_para(cat, idx)
        pid = f"{ID_PREFIX}_{zid:04d}"
        name = previous_names.get(pid) or name
        slot_id = f"SLOT_{z['instancia']}_{zid:03d}"
        z_mid = (levels[0][0] + levels[-1][0] + levels[-1][1]) / 2
        origin = front - n * (depth / 2) + up * z_mid
        frame = Matrix((t, -n, up)).transposed()                   # X=t, Y=-n (hacia el mueble), Z=arriba
        world = Matrix.Translation(origin) @ frame.to_4x4()

        slot = bpy.data.objects.new(f"slot_{slot_id}", None)
        slot.empty_display_type, slot.empty_display_size = "PLAIN_AXES", 0.25
        col.objects.link(slot)
        slot.parent = groot
        slot.matrix_basis = world                                  # PRODUCTOS_grupos está en el origen
        slot["kind"], slot["slot_id"], slot["shelf_id"] = "product_location", slot_id, z["instancia"]
        slot["route_node"], slot["sku_zone"] = z["nav_node"], z.name

        grp = bpy.data.objects.new(f"producto_{pid} | {name}", None)
        grp.empty_display_type, grp.empty_display_size = "CUBE", 0.1
        col.objects.link(grp)
        grp.parent = slot
        grp["kind"], grp["product_id"], grp["display_name"] = "product_group", pid, name
        grp["slot_id"], grp["route_node"], grp["category"] = slot_id, z["nav_node"], cat
        grp["zona"], grp["sku_zone"], grp["box_count"] = z["zona"], z.name, 4
        grp["layout"] = f"{cols} columns x {len(levels)} shelf levels"
        grp["inventory_demo"], grp["stock_source"] = True, "inventory_backend"
        grp["label_data"] = f"NOMBRE_{pid}"
        z["product_id"] = pid

        first_label = None
        for li, (zb, h) in enumerate(levels, start=1):
            for ci in range(cols):
                cx = (ci - (cols - 1) / 2) * (col_w + 0.08)
                center = origin + t * cx + up * (zb + h / 2 - z_mid)
                if mode == "escalonado":
                    center -= n * (li - 1) * 0.76
                bname = f"caja_{pid}_{li}{ci + 1}"
                box = bpy.data.objects.new(bname, box_mesh)
                col.objects.link(box)
                box.parent = grp
                box_world = Matrix.Translation(center) @ frame.to_4x4() @ \
                    Matrix.Diagonal((col_w, depth, h, 1.0))
                box.matrix_basis = world.inverted() @ box_world            # padre: grupo = slot
                box["kind"], box["product_id"], box["display_name"] = "product_box", pid, name
                box["row"], box["column"] = li, ci + 1
                box["label_face"] = "-Y"
                lab = _label(f"etiqueta_{pid}_{li}{ci + 1}", name, box, frame,
                             center, col_w, h, pid)
                col.objects.link(lab)
                lab.parent = box
                lab_frame = Matrix((t, up, n)).transposed()           # texto: X=t, Y=arriba, Z=normal
                lab_world = Matrix.Translation(center + n * (depth / 2 + 0.004)) @ lab_frame.to_4x4()
                lab.matrix_basis = box_world.inverted() @ lab_world
                first_label = first_label or lab.name
                created += 1
        grp["label_object"] = first_label
    sc.frame_set(sc.frame_current)
    info = {"zonas": len(zones), "productos": len(zones), "cajas": created, "nodos_ruta": len(nav),
            "modos": modes}
    if report:
        print(json.dumps(info, ensure_ascii=False))
    return info


def export_glb(path=GLB_OUT):
    sc = _scene()
    exp = bpy.data.collections[COL_EXPORT]
    # Las etiquetas de texto quedan en el .blend para editarlas en Blender; la app dibuja
    # sus propias etiquetas sobre la cara frontal de cada caja (eje local -Y de Blender),
    # así que no se exportan sus mallas (ahorra ~4 MB y ~100 000 triángulos).
    names = {o.name for o in exp.all_objects if o.get("kind") != "editable_label"}
    for o in sc.objects:
        o.select_set(o.name in names)
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_extras=True,
              export_cameras=False, export_lights=False, export_apply=True, export_yup=True,
              export_texcoords=True, export_normals=False, export_tangents=False,
              export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=88,
              export_vertex_color="MATERIAL",
              export_attributes=False, export_animations=False,
              export_skins=False, export_morph=False, export_draco_mesh_compression_enable=False,
              will_save_settings=False)
    valid = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in valid})
    return os.path.getsize(path)


if __name__ == "__main__":
    build()
    if "--export" in sys.argv:
        print("GLB bytes", export_glb())
