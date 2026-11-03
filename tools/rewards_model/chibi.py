"""Builds the chibi avatar and its room for Recompensas, and renders previews.

blender -b -P chibi.py -- OUT_DIR

Writes OUT_DIR/rewards.blend, OUT_DIR/rewards.glb and preview PNGs.
Every unlockable piece is its own object (avatar_*, top_*, bottom_*,
shoes_*, acc_*, house_*); the app shows or hides them by name.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ── Materials ────────────────────────────────────────────────────────────────

_materials = {}


def mat(name, hex_color, roughness=0.55):
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    h = hex_color.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    bsdf.inputs["Base Color"].default_value = (*linear, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    _materials[name] = m
    return m


SKIN = "#EDB48C"
HAIR = "#4A3326"

# ── Primitive helpers ────────────────────────────────────────────────────────


def finish(obj, name, material, smooth=True, bevel=0.0, subdiv=0):
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    if subdiv:
        mod = obj.modifiers.new("subdiv", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def sphere(name, material, loc, scale, segments=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2,
                                         location=loc)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, material)


def box(name, material, loc, size, bevel=0.05, rot=(0, 0, 0), subdiv=0):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, name, material, bevel=bevel, subdiv=subdiv)


def capsule(name, material, a, b, radius, verts=24):
    """A rounded tube from point a to point b."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=axis.length,
                                        location=(a + b) / 2)
    obj = bpy.context.object
    obj.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
    finish(obj, name, material, bevel=radius * 0.9)
    return obj


def cylinder(name, material, loc, radius, depth, verts=32, bevel=0.02, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    return finish(bpy.context.object, name, material, bevel=bevel)


def join(name, objects):
    for o in objects:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    return obj


# ── Avatar ───────────────────────────────────────────────────────────────────
# One continuous body (a skeleton wrapped by the Skin modifier) and an
# egg-shaped head. Clothes, hair and hats are copies of the body or head
# surface pushed out a little, so they always fit. Front faces -Y.

import bmesh

HEAD_C = Vector((0, 0, 1.06))
HEAD_R = 0.32

BODY_POINTS = {
    "pelvis": ((0, 0.0, 0.42), 0.160, 0.122),
    "belly": ((0, -0.015, 0.52), 0.168, 0.133),
    "chest": ((0, 0.0, 0.625), 0.150, 0.110),
    "neck": ((0, 0.0, 0.725), 0.058, 0.055),
}
for _side, _s in (("l", -1), ("r", 1)):
    BODY_POINTS.update({
        f"shoulder_{_side}": ((_s * 0.145, 0, 0.665), 0.066, 0.062),
        f"elbow_{_side}": ((_s * 0.245, 0, 0.555), 0.054, 0.051),
        f"wrist_{_side}": ((_s * 0.315, -0.005, 0.46), 0.043, 0.040),
        f"hand_{_side}": ((_s * 0.345, -0.012, 0.405), 0.050, 0.034),
        f"hip_{_side}": ((_s * 0.098, 0, 0.37), 0.090, 0.088),
        f"thigh_{_side}": ((_s * 0.11, -0.005, 0.29), 0.078, 0.078),
        f"knee_{_side}": ((_s * 0.117, -0.01, 0.2), 0.060, 0.060),
        f"calf_{_side}": ((_s * 0.12, 0.0, 0.13), 0.060, 0.060),
        f"ankle_{_side}": ((_s * 0.122, 0, 0.055), 0.047, 0.047),
        f"toe_{_side}": ((_s * 0.126, -0.095, 0.03), 0.054, 0.035),
    })
BODY_EDGES = [("pelvis", "belly"), ("belly", "chest"), ("chest", "neck")]
for _side in ("l", "r"):
    BODY_EDGES += [("chest", f"shoulder_{_side}"), (f"shoulder_{_side}", f"elbow_{_side}"),
                   (f"elbow_{_side}", f"wrist_{_side}"), (f"wrist_{_side}", f"hand_{_side}"),
                   ("pelvis", f"hip_{_side}"), (f"hip_{_side}", f"thigh_{_side}"),
                   (f"thigh_{_side}", f"knee_{_side}"), (f"knee_{_side}", f"calf_{_side}"),
                   (f"calf_{_side}", f"ankle_{_side}"), (f"ankle_{_side}", f"toe_{_side}")]

# Hidden source surfaces; removed before export.
SOURCES = {}


def evaluated_copy(source, name):
    """A plain mesh object with the source's modifiers applied."""
    deps = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(source.evaluated_get(deps))
    obj = bpy.data.objects.new(name, mesh)
    obj.matrix_world = source.matrix_world.copy()
    scene.collection.objects.link(obj)
    return obj


def shell(name, material, source, planes, offset, thickness=0.006):
    """The part of [source] inside every half-space in [planes], pushed out by
    offset. Each plane is (point, normal) in world space and keeps the side the
    normal points to. Cutting along planes leaves clean straight hems."""
    obj = evaluated_copy(source, name)
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    inv = obj.matrix_world.inverted()
    for point, normal in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5,
                               plane_co=inv @ Vector(point),
                               plane_no=(inv.to_3x3() @ Vector(normal)).normalized(),
                               clear_inner=True)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.clear()
    mesh.materials.append(material)
    for p in mesh.polygons:
        p.use_smooth = True
    if thickness:
        solid = obj.modifiers.new("solid", "SOLIDIFY")
        solid.thickness = thickness
        solid.offset = 1
    obj.data.name = name
    return obj


def above(z):
    return ((0, 0, z), (0, 0, 1))


def below(z):
    return ((0, 0, z), (0, 0, -1))


def within_x(reach):
    return [((reach, 0, 0), (-1, 0, 0)), ((-reach, 0, 0), (1, 0, 0))]


def beyond_x(x, side):
    """Keeps |x| beyond x on one side (side=1 right, -1 left)."""
    return ((side * x, 0, 0), (side, 0, 0))


def front_of(y):
    return ((0, y, 0), (0, -1, 0))


def behind(y):
    return ((0, y, 0), (0, 1, 0))


def surface(obj, x, z, side=-1):
    """Where a ray along Y meets obj at (x, z), and the surface normal there.
    side=-1 hits the front, 1 the back."""
    deps = bpy.context.evaluated_depsgraph_get()
    inv = obj.matrix_world.inverted()
    origin = inv @ Vector((x, side * 3.0, z))
    direction = (inv.to_3x3() @ Vector((0, -side, 0))).normalized()
    hit, loc, normal, _ = obj.ray_cast(origin, direction, depsgraph=deps)
    if not hit:
        raise RuntimeError(f"{obj.name}: no surface at x={x} z={z}")
    return obj.matrix_world @ loc, (obj.matrix_world.to_3x3() @ normal).normalized()


def body_source():
    mesh = bpy.data.meshes.new("body_src")
    obj = bpy.data.objects.new("body_src", mesh)
    scene.collection.objects.link(obj)
    names = list(BODY_POINTS)
    bm = bmesh.new()
    verts = {n: bm.verts.new(BODY_POINTS[n][0]) for n in names}
    for a, b in BODY_EDGES:
        bm.edges.new((verts[a], verts[b]))
    bm.to_mesh(mesh)
    bm.free()
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    for i, n in enumerate(names):
        _, rx, ry = BODY_POINTS[n]
        mesh.skin_vertices[0].data[i].radius = (rx, ry)
    mesh.skin_vertices[0].data[names.index("pelvis")].use_root = True
    sub = obj.modifiers.new("subdiv", "SUBSURF")
    sub.levels = sub.render_levels = 2
    return obj


def head_source():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=HEAD_R, location=HEAD_C)
    head = bpy.context.object
    head.name = head.data.name = "head_src"
    for v in head.data.vertices:
        # Wide cranium, narrower soft jaw, slightly flat face.
        t = max(0.0, -v.co.z / HEAD_R)
        v.co.x *= 1.0 - 0.22 * t ** 1.5
        v.co.y *= (1.0 - 0.28 * t ** 1.5) * 0.94
        v.co.z *= 0.97
    for p in head.data.polygons:
        p.use_smooth = True
    return head


def build_avatar():
    skin, hair = mat("skin", SKIN), mat("hair", HAIR)
    SOURCES["body"] = body_source()
    SOURCES["head"] = head_source()

    parts = [evaluated_copy(SOURCES["body"], "body_part"), evaluated_copy(SOURCES["head"], "head_part")]
    for side in (-1, 1):
        ear = sphere(f"ear_{side}", skin, (side * HEAD_R, 0.03, HEAD_C.z - 0.04), (0.041, 0.052, 0.075), segments=24)
        parts.append(ear)
    for p in parts[:2]:
        p.data.materials.clear()
        p.data.materials.append(skin)
        for poly in p.data.polygons:
            poly.use_smooth = True
    body = join("avatar_body", parts)

    head = SOURCES["head"]
    eye, white = mat("eye", "#2B1B14", 0.2), mat("eye_shine", "#FFFFFF", 0.1)
    blush, mouth = mat("blush", "#F29C9C", 0.7), mat("mouth", "#7A3B32", 0.5)
    face = []
    for side in (-1, 1):
        at, _ = surface(head, side * 0.12, HEAD_C.z - 0.03)
        face.append(sphere(f"eye_{side}", eye, at + Vector((0, 0.008, 0)), (0.058, 0.025, 0.078)))
        shine, _ = surface(head, side * 0.12 + 0.02, HEAD_C.z + 0.005)
        face.append(sphere(f"shine_{side}", white, shine + Vector((0, -0.016, 0)), (0.018, 0.008, 0.018), segments=12))
        cheek, _ = surface(head, side * 0.2, HEAD_C.z - 0.11)
        face.append(sphere(f"blush_{side}", blush, cheek + Vector((0, 0.004, 0)), (0.05, 0.012, 0.03), segments=16))
    at, _ = surface(head, 0, HEAD_C.z - 0.135)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.04, minor_radius=0.01,
                                     location=at + Vector((0, -0.004, 0)), rotation=(math.pi / 2, 0, 0))
    smile = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(smile.data)
    # The ring is rotated onto the face: local +Y points up. Keep the lower half.
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.004], context="VERTS")
    bm.to_mesh(smile.data)
    bm.free()
    face.append(finish(smile, "smile", mouth))
    join("avatar_face", face)

    cz = HEAD_C.z
    crown = shell("hair_crown", hair, head, [above(cz + 0.05)], 0.022, thickness=0.02)
    back = shell("hair_back", hair, head, [below(cz + 0.06), above(cz - 0.17), behind(-0.06)], 0.022, thickness=0.02)
    locks = [crown, back]
    for i, x in enumerate((-0.17, 0.0, 0.17)):
        at, normal = surface(head, x, cz + 0.15 - abs(x) * 0.25)
        locks.append(sphere(f"lock_{i}", hair, at + normal * 0.006, (0.12, 0.04, 0.085)))
    for side in (-1, 1):
        at, normal = surface(head, side * 0.27, cz + 0.01)
        locks.append(sphere(f"side_{side}", hair, at + normal * 0.015, (0.055, 0.07, 0.12)))
    join("avatar_hair", locks)
    return body


def torso(top=0.70, bottom=0.44, reach=0.215):
    return [above(bottom), below(top), *within_x(reach)]


def long_sleeves():
    return [above(0.445), below(0.70), *within_x(0.33)]


def legs(bottom, top=0.475):
    # Hands hang at hip height: keep only the body's width.
    return [above(bottom), below(top), *within_x(0.205)]


def wrist_band(name, material, face=None):
    elbow, wrist = Vector(BODY_POINTS["elbow_l"][0]), Vector(BODY_POINTS["wrist_l"][0])
    axis = (wrist - elbow).normalized()
    center = wrist - axis * 0.025
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.05, depth=0.03, location=center)
    band = bpy.context.object
    band.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
    parts = [finish(band, f"{name}_band", material, bevel=0.008)]
    if face is not None:
        parts.append(box(f"{name}_face", face, center + Vector((0, -0.05, 0)), (0.05, 0.016, 0.045), bevel=0.008))
    return join(name, parts) if len(parts) > 1 else rename(parts[0], name)


def rename(obj, name):
    obj.name = obj.data.name = name
    return obj


def clothing():
    body, head = SOURCES["body"], SOURCES["head"]
    cz = HEAD_C.z

    # Tops.
    shell("top_tshirt", mat("tee", "#2E8B74"), body, torso(), 0.016)

    white, navy = mat("tee_white", "#F4F1EA"), mat("stripe_navy", "#2F3E5C")
    tee = shell("stripes_tee", white, body, torso(), 0.016)
    bands = [shell(f"stripe_{i}", navy, body, [above(lo), below(lo + 0.03), *within_x(0.19)], 0.026)
             for i, lo in enumerate((0.475, 0.55, 0.625))]
    join("top_tshirt_stripes", [tee] + bands)

    coral, cream = mat("tee_coral", "#E86A6A"), mat("heart_cream", "#FFF4E6")
    tee = shell("heart_tee", coral, body, torso(), 0.016)
    at, _ = surface(tee, 0, 0.6)
    join("top_tshirt_heart", [tee, heart("chest_heart", cream, (at.x, at.y - 0.006, at.z), 0.06)])

    tank = mat("tank", "#3A6EA5")
    parts = [shell("tank_body", tank, body, torso(top=0.69, reach=0.155), 0.016)]
    for side in (-1, 1):
        front, _ = surface(body, side * 0.09, 0.67)
        back, _ = surface(body, side * 0.09, 0.67, side=1)
        top = Vector((side * 0.09, 0.0, 0.735))
        parts.append(capsule(f"tank_strap_f_{side}", tank, front + Vector((0, -0.012, 0)), top, 0.022))
        parts.append(capsule(f"tank_strap_b_{side}", tank, back + Vector((0, 0.012, 0)), top, 0.022))
    join("top_tank", parts)

    hoodie, string = mat("hoodie", "#E0803A"), mat("hoodie_string", "#FFF4E6")
    sweat = shell("hoodie_body", hoodie, body, long_sleeves(), 0.028, thickness=0.01)
    pocket = shell("pocket", hoodie, body, [above(0.47), below(0.53), *within_x(0.09), front_of(-0.05)], 0.04)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.11, minor_radius=0.045, location=(0, 0.04, 0.715))
    hood = finish(bpy.context.object, "hood", hoodie)
    parts = [sweat, pocket, hood]
    for side in (-1, 1):
        top, _ = surface(sweat, side * 0.04, 0.68)
        parts.append(capsule(f"hoodie_string_{side}", string, top + Vector((0, -0.006, 0)),
                             top + Vector((0, -0.01, -0.1)), 0.01))
    join("top_hoodie", parts)

    jacket, zip_, trim = mat("jacket", "#5E4B8B"), mat("zip", "#EDEDED"), mat("jacket_trim", "#F2C94C")
    parts = [shell("jacket_body", jacket, body, long_sleeves(), 0.026, thickness=0.01),
             shell("jacket_zip", zip_, body, [above(0.445), below(0.69), *within_x(0.012), front_of(0)], 0.037)]
    for side in (-1, 1):
        parts.append(shell(f"jacket_stripe_{side}", trim, body,
                           [above(0.445), beyond_x(0.17, side), front_of(-0.048), behind(-0.062)], 0.036))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.022, location=(0, 0, 0.705))
    parts.append(finish(bpy.context.object, "jacket_collar", trim))
    join("top_jacket", parts)

    # Bottoms.
    shell("bottom_shorts", mat("shorts", "#2F3E5C"), body, legs(0.25), 0.013)
    sport = mat("shorts_sport", "#C2413A")
    parts = [shell("sport_body", sport, body, legs(0.28), 0.013)]
    for side in (-1, 1):
        parts.append(shell(f"sport_line_{side}", mat("sport_line", "#FFFFFF"), body,
                           [above(0.28), below(0.45), beyond_x(0.17, side), *within_x(0.205)], 0.02))
    join("bottom_shorts_sport", parts)
    join("bottom_joggers", [
        shell("joggers_body", mat("joggers", "#5B6270"), body, legs(0.1), 0.014),
        shell("joggers_cuffs", mat("joggers_cuff", "#3F4550"), body, legs(0.075, top=0.105), 0.021),
    ])

    # Shoes: the foot surface plus a sole.
    for name, upper, sole, top in (("shoes_basic", "#F5F5F0", "#C9C9C2", 0.095),
                                   ("shoes_running", "#3BB4E0", "#FFFFFF", 0.095),
                                   ("shoes_hightop", "#D9483B", "#F5F5F0", 0.15),
                                   ("shoes_gold", "#E8B931", "#FFF4D6", 0.095)):
        parts = [shell(f"{name}_upper", mat(name, upper, 0.25 if "gold" in name else 0.55), body,
                       [below(top)], 0.018, thickness=0.01)]
        for side in (-1, 1):
            parts.append(box(f"{name}_sole_{side}", mat(f"{name}_sole", sole),
                             (side * 0.124, -0.045, 0.01), (0.13, 0.23, 0.022), bevel=0.01))
        join(name, parts)

    # Head and face. Hats sit outside the hair, which is 0.042 thick.
    cap, visor = mat("cap", "#C2413A"), mat("cap_visor", "#9E322D")
    dome = shell("cap_dome", cap, head, [above(cz + 0.06)], 0.06, thickness=0.015)
    front, _ = surface(head, 0, cz + 0.08)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.15, depth=0.02,
                                        location=(0, front.y - 0.08, cz + 0.085), rotation=(0.18, 0, 0))
    brim = bpy.context.object
    brim.scale = (1.0, 0.75, 1.0)
    join("acc_cap", [dome, finish(brim, "cap_visor", visor, bevel=0.006)])

    knit, pom = mat("beanie", "#6C8A73", 0.9), mat("beanie_pom", "#F4F1EA", 0.9)
    join("acc_beanie", [
        shell("beanie_dome", knit, head, [above(cz + 0.02)], 0.075, thickness=0.02),
        shell("beanie_rim", knit, head, [above(cz + 0.02), below(cz + 0.08)], 0.095, thickness=0.02),
        sphere("beanie_pom", pom, (0, 0.01, cz + HEAD_R + 0.1), (0.065, 0.065, 0.065)),
    ])

    shell("acc_headband", mat("headband", "#F2C94C"), head, [above(cz + 0.09), below(cz + 0.14)], 0.055, thickness=0.012)

    frame, lens = mat("glasses_frame", "#1F1F1F", 0.3), mat("glasses_lens", "#26323F", 0.1)
    parts = []
    for side in (-1, 1):
        at, _ = surface(head, side * 0.12, cz - 0.03)
        parts.append(cylinder(f"lens_{side}", lens, at + Vector((0, -0.035, 0)), 0.07, 0.016, rot=(math.pi / 2, 0, 0)))
    mid, _ = surface(head, 0, cz - 0.01)
    parts.append(box("glasses_bridge", frame, mid + Vector((0, -0.04, 0)), (0.08, 0.016, 0.016), bevel=0.004))
    join("acc_sunglasses", parts)

    wrist_band("acc_watch", mat("watch", "#1F1F1F"), face=mat("watch_face", "#4FD1A5", 0.2))
    wrist_band("acc_smartband", mat("smartband", "#4FD1A5", 0.4))

    for source in SOURCES.values():
        bpy.data.objects.remove(source, do_unlink=True)


# ── Room ─────────────────────────────────────────────────────────────────────
# A corner diorama behind the avatar: floor and two walls, then furniture.


def build_room():
    floor, trim = mat("floor", "#C99A6B", 0.7), mat("trim", "#D8C7AE")
    back, side = mat("wall_back", "#E8DCCB", 0.9), mat("wall_left", "#D7E6DE", 0.9)
    box("house_floor", floor, (0, 0.6, -0.05), (3.2, 3.0, 0.1), bevel=0.04)
    box("house_wall_back", back, (0, 2.05, 1.2), (3.2, 0.1, 2.5), bevel=0.02)
    box("house_wall_left", side, (-1.55, 0.6, 1.2), (0.1, 3.0, 2.5), bevel=0.02)
    box("house_baseboard", trim, (0, 1.99, 0.06), (3.1, 0.04, 0.12), bevel=0.01)

    # Window on the back wall.
    frame, glass = mat("window_frame", "#FFFFFF"), mat("window_glass", "#A8DDF0", 0.1)
    join("house_window", [
        box("window_frame", frame, (0.6, 1.99, 1.45), (0.9, 0.06, 0.8), bevel=0.02),
        box("window_glass", glass, (0.6, 1.97, 1.45), (0.78, 0.04, 0.68), bevel=0.0),
    ])

    # Level 1: a mattress on the floor and a yoga mat.
    mattress, pillow = mat("mattress", "#E8E4DC"), mat("pillow", "#FFFFFF")
    join("house_bed_basic", [
        box("mattress", mattress, (-0.95, 1.2, 0.08), (0.9, 1.4, 0.16), bevel=0.06),
        box("pillow", pillow, (-0.95, 1.75, 0.2), (0.6, 0.25, 0.1), bevel=0.05),
    ])
    box("house_yoga_mat", mat("yoga_mat", "#7CC6A8"), (0.55, 0.2, 0.01), (0.6, 1.2, 0.02), bevel=0.005)

    # Upgrades.
    wood, blanket = mat("wood", "#9C6B43", 0.6), mat("blanket", "#2E8B74", 0.8)
    join("house_bed_nice", [
        box("bed_frame", wood, (-0.95, 1.15, 0.15), (1.0, 1.55, 0.3), bevel=0.04),
        box("bed_head", wood, (-0.95, 1.92, 0.5), (1.0, 0.08, 0.8), bevel=0.04),
        box("bed_mattress", mattress, (-0.95, 1.15, 0.36), (0.92, 1.45, 0.14), bevel=0.06),
        box("bed_blanket", blanket, (-0.95, 0.95, 0.44), (0.96, 1.0, 0.05), bevel=0.03),
        box("bed_pillow", pillow, (-0.95, 1.7, 0.47), (0.6, 0.22, 0.1), bevel=0.05),
    ])
    pot, leaf = mat("pot", "#C9734A"), mat("leaf", "#4E9F5C", 0.7)
    join("house_plant", [cylinder("pot", pot, (1.25, 1.7, 0.18), 0.17, 0.36)] +
         [sphere(f"leaf_{i}", leaf, (1.25 + dx, 1.7 + dy, 0.5 + dz), (0.16, 0.16, 0.2))
          for i, (dx, dy, dz) in enumerate(((0, 0, 0.1), (0.12, 0.05, 0), (-0.1, -0.05, 0.02), (0, 0.1, 0.22)))])
    metal, weight = mat("metal", "#8A8F98", 0.3), mat("dumbbell", "#2B2D33", 0.4)
    parts = []
    for i, y in enumerate((0.1, 0.4)):
        parts.append(cylinder(f"bar_{i}", metal, (1.15, y, 0.08), 0.02, 0.35, rot=(0, math.pi / 2, 0)))
        for side in (-1, 1):
            parts.append(cylinder(f"plate_{i}_{side}", weight, (1.15 + side * 0.15, y, 0.08), 0.08, 0.07, rot=(0, math.pi / 2, 0)))
    join("house_dumbbells", parts)
    rug = mat("rug", "#E9A6A0", 0.9)
    cylinder("house_rug", rug, (0, 0.5, 0.005), 0.75, 0.01, verts=64, bevel=0.004)
    shelf, trophy = mat("shelf", "#B88452"), mat("trophy", "#E8B931", 0.25)
    join("house_shelf", [
        box("shelf_board", shelf, (-1.45, 0.3, 1.35), (0.14, 0.9, 0.04), bevel=0.01),
        box("book_1", mat("book_a", "#C2413A"), (-1.42, 0.0, 1.47), (0.12, 0.06, 0.2), bevel=0.01),
        box("book_2", mat("book_b", "#2F3E5C"), (-1.42, 0.08, 1.46), (0.12, 0.06, 0.18), bevel=0.01),
        box("book_3", mat("book_c", "#7CC6A8"), (-1.42, 0.16, 1.47), (0.12, 0.06, 0.2), bevel=0.01),
    ])
    lamp_metal, shade = mat("lamp_metal", "#3A3A3A", 0.3), mat("lamp_shade", "#FFE9B8", 0.6)
    join("house_lamp", [
        cylinder("lamp_base", lamp_metal, (-0.25, 1.8, 0.02), 0.12, 0.04),
        cylinder("lamp_pole", lamp_metal, (-0.25, 1.8, 0.6), 0.015, 1.16),
        cylinder("lamp_shade", shade, (-0.25, 1.8, 1.2), 0.17, 0.22, bevel=0.01),
    ])
    poster = mat("poster", "#F2C94C")
    join("house_poster_simple", [
        box("poster_bg", poster, (-0.1, 1.99, 1.55), (0.55, 0.02, 0.7), bevel=0.0),
        box("poster_mark", mat("poster_mark", "#2E8B74"), (-0.1, 1.975, 1.6), (0.3, 0.02, 0.3), bevel=0.02),
    ])



# ── Catalog: more things to earn ─────────────────────────────────────────────


def ring(name, material, z, radius=0.2, thickness=0.022, squash=(1.06, 0.78)):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness, location=(0, 0, z))
    obj = bpy.context.object
    obj.scale = (squash[0], squash[1], 1)
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, name, material)


def heart(name, material, loc, size):
    x, y, z = loc
    return join(name, [
        sphere(f"{name}_l", material, (x - size * 0.45, y, z + size * 0.25), (size * 0.55, size * 0.25, size * 0.55)),
        sphere(f"{name}_r", material, (x + size * 0.45, y, z + size * 0.25), (size * 0.55, size * 0.25, size * 0.55)),
        box(f"{name}_tip", material, (x, y, z - size * 0.2), (size * 0.95, size * 0.4, size * 0.95),
            bevel=size * 0.15, rot=(0, math.pi / 4, 0)),
    ])


def text_mesh(name, material, body, loc, size, rot=(math.pi / 2, 0, 0)):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.data.body = body
    obj.data.size = size
    obj.data.extrude = 0.01
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    return finish(obj, name, material, smooth=False)


def more_room():
    # Posters share the spot on the back wall, left of the window.
    spot = (-0.1, 1.99, 1.55)
    sky, snow, rock, sun = mat("poster_sky", "#9FD3EA"), mat("poster_snow", "#FFFFFF"), mat("poster_rock", "#6E7B8B"), mat("poster_sun", "#F2C94C")
    join("house_poster_mountain", [
        box("mountain_bg", sky, spot, (0.55, 0.02, 0.7), bevel=0.0),
        box("mountain_a", rock, (spot[0] - 0.08, 1.975, 1.38), (0.28, 0.02, 0.28), bevel=0.0, rot=(0, math.pi / 4, 0)),
        box("mountain_b", rock, (spot[0] + 0.12, 1.972, 1.36), (0.22, 0.02, 0.22), bevel=0.0, rot=(0, math.pi / 4, 0)),
        box("mountain_snow", snow, (spot[0] - 0.08, 1.968, 1.53), (0.08, 0.02, 0.08), bevel=0.0, rot=(0, math.pi / 4, 0)),
        cylinder("mountain_sun", sun, (spot[0] + 0.15, 1.972, 1.75), 0.06, 0.02, rot=(math.pi / 2, 0, 0)),
    ])
    paper = mat("poster_paper", "#FFF4E6")
    join("house_poster_fruit", [
        box("fruit_bg", paper, spot, (0.55, 0.02, 0.7), bevel=0.0),
        sphere("apple", mat("apple", "#D9483B"), (spot[0] - 0.12, 1.97, 1.62), (0.08, 0.02, 0.08)),
        sphere("orange", mat("orange", "#F0913A"), (spot[0] + 0.1, 1.97, 1.66), (0.08, 0.02, 0.08)),
        sphere("pear", mat("pear", "#A8C256"), (spot[0], 1.97, 1.42), (0.07, 0.02, 0.09)),
        sphere("fruit_leaf", mat("leaf", "#4E9F5C", 0.7), (spot[0] - 0.08, 1.965, 1.72), (0.04, 0.015, 0.02)),
    ])
    green, light = mat("poster_green", "#2E8B74"), mat("poster_text", "#FFFFFF")
    join("house_poster_kiolog", [
        box("kiolog_bg", green, spot, (0.55, 0.02, 0.7), bevel=0.0),
        heart("kiolog_heart", light, (spot[0], 1.972, 1.66), 0.07),
        text_mesh("kiolog_text", light, "KIOLOG", (spot[0], 1.972, 1.42), 0.11),
    ])

    blue = mat("rug_blue", "#5B8DB8", 0.9)
    box("house_rug_blue", blue, (0, 0.5, 0.008), (1.4, 1.1, 0.016), bevel=0.004)

    pot, cactus = mat("cactus_pot", "#E9A6A0"), mat("cactus", "#5E9E6E", 0.7)
    join("house_cactus", [
        cylinder("cactus_pot", pot, (1.3, 1.05, 0.1), 0.1, 0.2),
        capsule("cactus_body", cactus, (1.3, 1.05, 0.2), (1.3, 1.05, 0.42), 0.06),
        capsule("cactus_arm", cactus, (1.36, 1.05, 0.3), (1.38, 1.05, 0.38), 0.03),
    ])

    iron = mat("kettlebell", "#2B2D33", 0.4)
    kb_body = sphere("kb_body", iron, (0.95, 0.7, 0.1), (0.1, 0.1, 0.1))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.02, location=(0.95, 0.7, 0.2),
                                     rotation=(math.pi / 2, 0, 0))
    join("house_kettlebell", [kb_body, finish(bpy.context.object, "kb_handle", iron)])

    bottle, cap = mat("bottle", "#7FC8E8", 0.15), mat("bottle_cap", "#2E8B74")
    join("house_water_bottle", [
        cylinder("bottle_body", bottle, (0.95, -0.3, 0.16), 0.07, 0.32),
        cylinder("bottle_cap", cap, (0.95, -0.3, 0.35), 0.05, 0.06),
    ])

    frame, seat, wheel = mat("bike_frame", "#3A6EA5", 0.4), mat("bike_seat", "#1F1F1F"), mat("bike_wheel", "#2B2D33")
    x, y = 0.7, 1.45
    join("house_bike", [
        box("bike_base", frame, (x, y, 0.03), (0.2, 0.7, 0.05), bevel=0.02),
        capsule("bike_post", frame, (x, y + 0.15, 0.05), (x, y + 0.05, 0.5), 0.03),
        capsule("bike_front", frame, (x, y - 0.2, 0.05), (x, y - 0.25, 0.65), 0.03),
        box("bike_seat", seat, (x, y + 0.05, 0.53), (0.12, 0.18, 0.04), bevel=0.02),
        box("bike_bar", seat, (x, y - 0.25, 0.67), (0.3, 0.04, 0.04), bevel=0.015),
        cylinder("bike_wheel", wheel, (x, y - 0.15, 0.22), 0.16, 0.05, rot=(0, math.pi / 2, 0)),
    ])

    # Trophy shelf on the left wall, below the book shelf.
    wood = mat("trophy_shelf", "#8A5A36")
    box("house_trophy_shelf", wood, (-1.43, 0.45, 0.92), (0.18, 1.4, 0.05), bevel=0.01)
    base = mat("trophy_base", "#5B4636")
    shelf_z = 0.945
    for i, (name, color, scale) in enumerate((("trophy_month_1", "#C98552", 0.8),
                                              ("trophy_month_3", "#C0C4CC", 0.9),
                                              ("trophy_month_6", "#E8B931", 1.0),
                                              ("trophy_year_1", "#E8B931", 1.3))):
        join(name, trophy_cup(name, mat(name, color, 0.25), base, (-1.42, -0.1 + i * 0.22, shelf_z), scale))
    medal, ribbon = mat("medal", "#E8B931", 0.25), mat("medal_ribbon", "#C2413A")
    for n in range(2, 6):
        y = 0.82 + (n - 2) * 0.13
        parts = [cylinder(f"medal_{n}", medal, (-1.42, y, shelf_z + 0.07), 0.05, 0.015, rot=(0, math.pi / 2, 0)),
                 box(f"medal_ribbon_{n}", ribbon, (-1.43, y, shelf_z + 0.14), (0.01, 0.04, 0.08), bevel=0.003),
                 box(f"medal_stand_{n}", base, (-1.42, y, shelf_z + 0.01), (0.06, 0.08, 0.02), bevel=0.005),
                 text_mesh(f"medal_text_{n}", base, str(n), (-1.408, y, shelf_z + 0.065), 0.06,
                           rot=(math.pi / 2, 0, math.pi / 2))]
        join(f"trophy_year_{n}", parts)


def trophy_cup(name, metal, base, loc, scale):
    """A cup with handles on a base, sitting at loc."""
    x, y, z = loc
    s = scale
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.022 * s, radius2=0.062 * s, depth=0.09 * s,
                                    location=(x, y, z + 0.115 * s))
    cup = finish(bpy.context.object, f"{name}_cup", metal, bevel=0.004)
    parts = [
        box(f"{name}_base", base, (x, y, z + 0.02 * s), (0.09 * s, 0.09 * s, 0.04 * s), bevel=0.008),
        cylinder(f"{name}_stem", metal, (x, y, z + 0.055 * s), 0.012 * s, 0.04 * s),
        cylinder(f"{name}_foot", metal, (x, y, z + 0.045 * s), 0.03 * s, 0.012 * s),
        cup,
        cylinder(f"{name}_rim", metal, (x, y, z + 0.16 * s), 0.064 * s, 0.008 * s),
    ]
    for side in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.025 * s, minor_radius=0.007 * s,
                                         location=(x, y + side * 0.06 * s, z + 0.12 * s),
                                         rotation=(0, math.pi / 2, 0))
        parts.append(finish(bpy.context.object, f"{name}_handle_{side}", metal))
    return parts

# ── Render ───────────────────────────────────────────────────────────────────


def set_visible(names):
    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        hidden = obj.name not in names
        obj.hide_render = hidden
        obj.hide_viewport = hidden


def setup_render():
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 900, 1000
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("world")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.95, 0.93, 0.9, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
    scene.world = world
    scene.view_settings.view_transform = "Standard"

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.2
    sun.data.angle = 0.6
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "AREA"))
    fill.data.energy = 120
    fill.data.size = 4
    fill.location = (2.5, -3, 2.5)
    fill.rotation_euler = (math.radians(60), 0, math.radians(40))
    scene.collection.objects.link(fill)

    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    camera.data.lens = 45
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def aim(camera, location, target):
    camera.location = location
    direction = Vector(target) - Vector(location)
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render(path):
    scene.render.filepath = os.path.join(OUT, path)
    bpy.ops.render.render(write_still=True)


AVATAR = ["avatar_body", "avatar_face", "avatar_hair"]
ROOM = ["house_floor", "house_wall_back", "house_wall_left", "house_baseboard", "house_window"]
LOOKS = {
    "nivel_1": AVATAR + ["top_tshirt", "bottom_shorts", "shoes_basic"]
    + ROOM + ["house_bed_basic", "house_yoga_mat"],
    "nivel_5": AVATAR + ["top_tshirt", "bottom_joggers", "shoes_running", "acc_headband", "acc_watch"]
    + ROOM + ["house_bed_basic", "house_yoga_mat", "house_rug", "house_plant", "house_dumbbells", "house_lamp"],
    "nivel_10": AVATAR + ["top_hoodie", "bottom_joggers", "shoes_running", "acc_cap", "acc_watch"]
    + ROOM + ["house_bed_nice", "house_yoga_mat", "house_rug", "house_plant", "house_dumbbells",
              "house_lamp", "house_shelf", "house_poster_simple"],
}
TROPHIES = ["house_trophy_shelf", "trophy_month_1", "trophy_month_3", "trophy_month_6",
            "trophy_year_1", "trophy_year_2", "trophy_year_3"]
LOOKS["completo"] = AVATAR + ["top_jacket", "bottom_joggers", "shoes_gold", "acc_beanie", "acc_smartband"] \
    + ROOM + ["house_bed_nice", "house_rug_blue", "house_plant", "house_cactus", "house_kettlebell",
              "house_water_bottle", "house_bike", "house_lamp", "house_shelf", "house_poster_kiolog"] + TROPHIES
OUTFITS = {
    "ropa_rayas": ["top_tshirt_stripes", "bottom_joggers", "shoes_hightop", "acc_beanie"],
    "ropa_corazon": ["top_tshirt_heart", "bottom_shorts", "shoes_running", "acc_sunglasses", "acc_smartband"],
    "ropa_sinmangas": ["top_tank", "bottom_shorts_sport", "shoes_gold", "acc_headband", "acc_watch"],
    "ropa_chaqueta": ["top_jacket", "bottom_joggers", "shoes_running", "acc_cap"],
}
POSTERS = ["house_poster_simple", "house_poster_mountain", "house_poster_fruit", "house_poster_kiolog"]

build_avatar()
clothing()
# Bigger in the room; the feet stay on the floor at z=0.
AVATAR_SCALE = 1.2
# Scale the whole transform: some pieces keep their own scale.
from mathutils import Matrix
for obj in scene.objects:
    if obj.type == "MESH" and not obj.name.startswith(("house_", "trophy_")):
        obj.matrix_world = Matrix.Scale(AVATAR_SCALE, 4) @ obj.matrix_world
build_room()
more_room()
camera = setup_render()

for name, outfit in OUTFITS.items():
    set_visible(set(AVATAR + outfit))
    camera.data.lens = 45
    aim(camera, (1.0, -3.4, 1.4), (0, 0, 0.82))
    render(f"{name}.png")
set_visible(set(AVATAR + ["top_tshirt", "bottom_shorts", "shoes_basic"]))
camera.data.lens = 70
aim(camera, (0.5, -2.6, 1.05), (0, 0, 0.7))
render("retrato.png")
for poster in POSTERS:
    set_visible({"house_wall_back", "house_floor", poster})
    camera.data.lens = 60
    aim(camera, (-0.1, 0.2, 1.55), (-0.1, 2.0, 1.55))
    render(f"{poster}.png")
set_visible(set(ROOM) | set(TROPHIES))
camera.data.lens = 50
aim(camera, (0.4, 0.45, 1.05), (-1.45, 0.45, 0.98))
render("trofeos.png")

for name, visible in LOOKS.items():
    set_visible(set(visible))
    camera.data.lens = 34
    aim(camera, (3.0, -3.3, 2.7), (-0.15, 0.75, 0.85))
    render(f"{name}_cuarto.png")
    set_visible(set(visible) - set(ROOM) - {n for n in visible if n.startswith("house_")})
    camera.data.lens = 45
    aim(camera, (0.9, -3.0, 1.25), (0, 0, 0.78))
    render(f"{name}_avatar.png")

set_visible({o.name for o in scene.objects if o.type == "MESH"})
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "rewards.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "rewards.glb"), export_format="GLB",
                          use_selection=False, export_apply=True,
                          export_cameras=False, export_lights=False)
print("done", sorted(o.name for o in scene.objects if o.type == "MESH"))
