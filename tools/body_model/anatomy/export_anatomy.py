"""Build phone-sized anatomy GLBs from Z-Anatomy muscles.

    blender -b --disable-autoexec muscles.blend --python export_anatomy.py -- OUT_DIR 60000 120000

`muscles.blend` comes from extract_muscles.py and holds `muscle` and `fascia`.
Muscle data derives from Z-Anatomy (CC BY-SA 4.0) and BodyParts3D (CC BY-SA 2.1 JP),
so the exported files keep those terms. Fat pads are generated here and carry
one morph target per zone: weight 0 hides the pad, weight 1 is its thickest.
"""
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, budgets = args[0], [int(a) for a in args[1:]]

SINK = 0.012
BODY_CENTER_Z = 0.86
VISIBLE_DISTANCE = 0.009
PAD_MAX_X = 0.20
# name: (thickness m, [(cx, cz, rx, rz, front limit y)])
ZONES = {
    "abdomen": (0.040, [(0, 1.00, 0.20, 0.17, 0.03)]),
    "pecho": (0.020, [(-0.105, 1.31, 0.10, 0.066, -0.02), (0.105, 1.31, 0.10, 0.066, -0.02)]),
    "muslo": (0.026, [(-0.165, 0.70, 0.085, 0.24, 0.06), (0.165, 0.70, 0.085, 0.24, 0.06)]),
}
RED, YELLOW, DARK = (0.62, 0.075, 0.055, 1), (0.95, 0.66, 0.12, 1), (0.22, 0.03, 0.03, 1)
WHITE = (0.86, 0.80, 0.72, 1)
HIDDEN_DEPTH = 0.05
HIDDEN_REACH = 0.8
SLICE_HEIGHT = 0.04
LIMB_ZONES = {"muslo"}
HOLE_RINGS = 4
MIN_ISLAND = 300
# Below this height a slice of the torso is centred between the legs, outside the body.
TORSO_BOTTOM_Z = 0.98
# Voxel remesh turns open sheets into hollow double walls. A vertex that sees less
# than this share of its hemisphere belongs to the wall facing the body cavity.
MIN_SKY = 0.25
SKY_RAYS = 48
SKY_START = 0.02

scene = bpy.context.scene
muscle, fascia = bpy.data.objects["muscle"], bpy.data.objects["fascia"]
white = bpy.data.objects["white"]


def coords(mesh):
    a = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def normals(mesh):
    a = np.empty(len(mesh.vertices) * 3)
    mesh.vertex_normals.foreach_get("vector", a)
    return a.reshape(-1, 3)


def material(name, color, roughness):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    node = m.node_tree.nodes["Principled BSDF"]
    node.inputs["Base Color"].default_value = color
    node.inputs["Roughness"].default_value = roughness
    return m


def apply_modifiers(obj):
    graph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(graph))
    obj.modifiers.clear()
    obj.data = mesh


def build_shell():
    verts = np.vstack([coords(fascia.data), coords(muscle.data)])
    offset = len(fascia.data.vertices)
    faces = [tuple(p.vertices) for p in fascia.data.polygons]
    faces += [tuple(i + offset for i in p.vertices) for p in muscle.data.polygons]
    mesh = bpy.data.meshes.new("shell")
    mesh.from_pydata(verts.tolist(), [], faces)
    mesh.update()
    obj = bpy.data.objects.new("shell", mesh)
    scene.collection.objects.link(obj)
    remesh = obj.modifiers.new("remesh", "REMESH")
    remesh.mode, remesh.voxel_size = "VOXEL", 0.008
    smooth = obj.modifiers.new("smooth", "SMOOTH")
    smooth.iterations, smooth.factor = 30, 0.8
    apply_modifiers(obj)
    return obj


def keep_visible(obj, shell_points):
    """Drop whole muscles that sit deeper than the visible surface."""
    tree = KDTree(len(shell_points))
    for i, p in enumerate(shell_points):
        tree.insert(p, i)
    tree.balance()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seen, drop, total, kept = set(), [], 0, 0
    for start in bm.verts:
        if start in seen:
            continue
        stack, island = [start], []
        seen.add(start)
        while stack:
            v = stack.pop()
            island.append(v)
            for e in v.link_edges:
                w = e.other_vert(v)
                if w not in seen:
                    seen.add(w)
                    stack.append(w)
        total += 1
        sample = island[:: max(1, len(island) // 200)]
        if any(tree.find(v.co)[2] < VISIBLE_DISTANCE for v in sample):
            kept += 1
        else:
            drop.extend(island)
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    print(f"muscles kept {kept}/{total}, verts {len(obj.data.vertices)}")


def sky_directions():
    """Evenly spread unit vectors over the sphere."""
    index = np.arange(SKY_RAYS) + 0.5
    z = 1 - 2 * index / SKY_RAYS
    angle = np.pi * (3 - 5 ** 0.5) * index
    radius = np.sqrt(1 - z * z)
    return np.stack([radius * np.cos(angle), radius * np.sin(angle), z], axis=1)


def sees_outside(shell, points, outward):
    """True where a vertex looks out of the body, not into its hollow inside."""
    faces = [tuple(p.vertices) for p in shell.data.polygons]
    tree = BVHTree.FromPolygons(coords(shell.data).tolist(), faces)
    directions = sky_directions()
    result = np.zeros(len(points), bool)
    for i, (point, normal) in enumerate(zip(points, outward)):
        start = Vector(point + normal * SKY_START)
        rays = directions[directions @ normal > 0]
        free = sum(tree.ray_cast(start, Vector(r))[0] is None for r in rays)
        result[i] = free >= MIN_SKY * len(rays)
    return result


def edge_pairs(mesh):
    """Every edge in both directions, as a two-column array."""
    edges = np.empty(len(mesh.edges) * 2, int)
    mesh.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    return np.vstack([edges, edges[:, ::-1]])


def drop_islands(edges, kept):
    """Remove small disconnected scraps, such as bits of arm inside a zone."""
    neighbours = {}
    for a, b in edges[kept[edges[:, 0]] & kept[edges[:, 1]]]:
        neighbours.setdefault(int(a), []).append(int(b))
    result, seen = kept.copy(), set()
    for start in np.flatnonzero(kept).tolist():
        if start in seen:
            continue
        stack, island = [start], [start]
        seen.add(start)
        while stack:
            for other in neighbours.get(stack.pop(), []):
                if other not in seen:
                    seen.add(other)
                    stack.append(other)
                    island.append(other)
        if len(island) < MIN_ISLAND:
            result[island] = False
    return result


def close_holes(edges, kept, allowed):
    """Fill small gaps in a vertex mask: grow it, then shrink it back."""

    def grow(mask):
        grown = mask.copy()
        grown[edges[mask[edges[:, 0]], 1]] = True
        return grown

    closed = kept.copy()
    for _ in range(HOLE_RINGS):
        closed = grow(closed) & allowed
    for _ in range(HOLE_RINGS):
        closed = ~grow(allowed & ~closed) & allowed
    return closed


def cross_section_centers(points, zones, cloud):
    """Middle of the body slice around each point: always well inside the body."""
    centers = np.empty_like(points)
    for index, name in enumerate(ZONES):
        for side in (-1, 1) if name in LIMB_ZONES else (0,):
            chosen = np.flatnonzero((zones == index) & ((side == 0) | (np.sign(points[:, 0]) == side)))
            pool = cloud[(np.abs(cloud[:, 0]) < PAD_MAX_X) & ((side == 0) | (np.sign(cloud[:, 0]) == side))]
            pool_slice = np.floor(pool[:, 2] / SLICE_HEIGHT)
            lowest = 0 if name in LIMB_ZONES else TORSO_BOTTOM_Z
            slices = np.floor(np.maximum(points[chosen, 2], lowest) / SLICE_HEIGHT)
            for value in np.unique(slices):
                centers[chosen[slices == value]] = pool[pool_slice == value].mean(axis=0)
    return centers


def build_pads(shell):
    p, n = coords(shell.data), normals(shell.data)
    distance = np.full(len(p), 9.0)
    thickness, zone = np.zeros(len(p)), np.full(len(p), -1)
    for index, (name, (t, ellipses)) in enumerate(ZONES.items()):
        for cx, cz, rx, rz, front in ellipses:
            q = ((p[:, 0] - cx) / rx) ** 2 + ((p[:, 2] - cz) / rz) ** 2
            q = np.where((p[:, 1] < front) & (np.abs(p[:, 0]) < PAD_MAX_X), q, 9.0)
            closer = q < distance
            distance = np.where(closer, q, distance)
            thickness = np.where(closer, t, thickness)
            zone = np.where(closer, index, zone)
    in_zone = distance < 1
    zoned = np.flatnonzero(in_zone)
    keep = np.zeros(len(p), bool)
    keep[zoned] = sees_outside(shell, p[zoned], n[zoned])
    edges = edge_pairs(shell.data)
    keep = drop_islands(edges, close_holes(edges, keep, in_zone))
    remap = -np.ones(len(p), int)
    remap[keep] = np.arange(keep.sum())
    faces = []
    for poly in shell.data.polygons:
        ids = [int(remap[i]) for i in poly.vertices]
        if min(ids) >= 0:
            faces.append(ids)
    fade = np.clip((1 - distance[keep]) / 0.30, 0, 1)
    fade = fade * fade * (3 - 2 * fade)
    surface, outward = p[keep], n[keep]
    inward = cross_section_centers(surface, zone[keep], p) - surface
    reach = np.linalg.norm(inward, axis=1, keepdims=True)
    base = surface + inward / reach * np.minimum(HIDDEN_DEPTH, reach * HIDDEN_REACH)
    mesh = bpy.data.meshes.new("fat")
    mesh.from_pydata(base.tolist(), [], faces)
    mesh.update()
    obj = bpy.data.objects.new("fat", mesh)
    scene.collection.objects.link(obj)
    obj.shape_key_add(name="Basis")
    for index, name in enumerate(ZONES):
        key = obj.shape_key_add(name=name)
        target = base.copy()
        chosen = zone[keep] == index
        lift = thickness[keep] * fade - SINK * (1 - fade)
        target[chosen] = surface[chosen] + outward[chosen] * lift[chosen, None]
        key.data.foreach_set("co", target.reshape(-1))
    return obj


def decimate(obj, budget):
    triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    modifier = obj.modifiers.new("decimate", "DECIMATE")
    modifier.ratio = min(1.0, budget / triangles)
    apply_modifiers(obj)


shell = build_shell()
shell_points = coords(shell.data)
keep_visible(muscle, shell_points)
muscle.data.materials.clear()
muscle.data.materials.append(material("muscle", RED, 0.55))
white.data.materials.append(material("white", WHITE, 0.6))
pads = build_pads(shell)
fat = material("fat", YELLOW, 0.5)
fat.use_backface_culling = True  # a hidden pad must not show through gaps in the muscles
pads.data.materials.append(fat)
shell.data.materials.append(material("inner", DARK, 0.7))
source = muscle.data.copy()
shell_source = shell.data.copy()
white_source = white.data.copy()
for budget in budgets:
    muscle.data = source.copy()
    decimate(muscle, budget)
    shell.data = shell_source.copy()
    decimate(shell, 12000)
    white.data = white_source.copy()
    decimate(white, 8000)
    co, no = coords(shell.data), normals(shell.data)
    shell.data.vertices.foreach_set("co", (co - no * SINK).reshape(-1))
    for obj in (muscle, pads, shell, white):
        for poly in obj.data.polygons:
            poly.use_smooth = True
        obj.location = (0, 0, -BODY_CENTER_Z)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (muscle, pads, shell, white):
        obj.select_set(True)
    path = f"{out_dir}/anatomy_{budget // 1000}k.glb"
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_morph=True,
        export_morph_normal=True, export_animations=False, export_yup=True,
        export_try_sparse_sk=False,  # Filament reads sparse morph accessors as zeros
    )
    tris = sum(len(p.vertices) - 2 for o in (muscle, pads, shell, white) for p in o.data.polygons)
    print(f"EXPORTED {path}: {tris} tris")
