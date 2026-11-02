"""Render a GLB headlessly to check it without a phone.

blender -b -P preview.py -- input.glb output.png [morph=weight ...]
"""
import math
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
source, target, overrides = args[0], args[1], args[2:]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
body = next(o for o in bpy.context.scene.objects if o.type == "MESH")
for override in overrides:
    name, weight = override.split("=")
    body.data.shape_keys.key_blocks[name].value = float(weight)

corners = [body.matrix_world @ Vector(c) for c in body.bound_box]
center = sum(corners, Vector()) / 8
height = max(c.z for c in corners) - min(c.z for c in corners)

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.render.resolution_x, scene.render.resolution_y = 900, 1200
scene.render.film_transparent = True
scene.render.filepath = target
camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
scene.collection.objects.link(camera)
camera.data.type = "ORTHO"
camera.data.ortho_scale = height * 1.1
camera.location = center + Vector((0, -5, 0))
camera.rotation_euler = (math.pi / 2, 0, 0)
scene.camera = camera
bpy.ops.render.render(write_still=True)
