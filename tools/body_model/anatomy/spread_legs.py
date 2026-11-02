"""Open the legs of a body GLB by a few degrees, in place.

    python spread_legs.py IN.glb OUT.glb [degrees]

Each leg slides sideways in proportion to its distance below the hip. A sideways
shear keeps every horizontal slice the same size, so tape measures and the
calibration JSON stay valid. Morph targets are deltas and carry over unchanged.
"""
import json
import math
import struct
import sys

import numpy as np

# Heights in world metres, with the body centred on the origin.
HIP_HEIGHT = 0.02
BLEND_HEIGHT = 0.12
MIDLINE_WIDTH = 0.04
DEFAULT_DEGREES = 5.0


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + length])
    return gltf, bytearray(data[28 + length:])


def write_glb(path, gltf, blob):
    payload = json.dumps(gltf, separators=(",", ":")).encode()
    payload += b" " * (-len(payload) % 4)
    total = 12 + 8 + len(payload) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(payload), 0x4E4F534A))
        f.write(payload)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(blob)


def sideways_shift(points, slope):
    """How far each point moves along x."""
    below = HIP_HEIGHT - points[:, 1]
    ramp = np.clip(below / BLEND_HEIGHT, 0, 1)
    distance = np.where(below > BLEND_HEIGHT, below - BLEND_HEIGHT / 2,
                        BLEND_HEIGHT / 2 * ramp * ramp)
    side = np.clip(points[:, 0] / MIDLINE_WIDTH, -1, 1)
    return slope * distance * side


def main(source, target, degrees):
    gltf, blob = read_glb(source)
    slope = math.tan(math.radians(degrees))
    done = set()
    for node in gltf["nodes"]:
        if "mesh" not in node:
            continue
        offset = np.array(node.get("translation", [0, 0, 0]), dtype=float)
        for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
            index = primitive["attributes"]["POSITION"]
            if index in done:
                continue
            done.add(index)
            accessor = gltf["accessors"][index]
            view = gltf["bufferViews"][accessor["bufferView"]]
            if view.get("byteStride", 12) != 12:
                raise ValueError("interleaved positions are not supported")
            start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            local = np.frombuffer(blob, "<f4", accessor["count"] * 3, start).reshape(-1, 3).copy()
            local[:, 0] += sideways_shift(local + offset, slope)
            blob[start:start + local.size * 4] = local.astype("<f4").tobytes()
            accessor["min"] = local.min(axis=0).tolist()
            accessor["max"] = local.max(axis=0).tolist()
            print(node.get("name"), "y", local[:, 1].min() + offset[1], local[:, 1].max() + offset[1])
    write_glb(target, gltf, blob)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_DEGREES)
