"""Tint the iliotibial band so it melts into the thigh muscles, in place.

    python blend_band.py IN.glb OUT.glb

Adds vertex colours to the `white` mesh. They multiply its material colour, so
everything outside the band stays white: vertices near a muscle turn muscle red
and the middle of the band keeps a soft, slightly paler red.
"""
import json
import struct
import sys

import numpy as np

# Mesh-space box around both bands, clear of the linea alba and the Achilles tendon.
BAND_Y = (0.40, 1.02)
BAND_MIN_X = 0.10
FADE_HEIGHT = 0.04
MUSCLE_REACH = 0.018
EDGE = np.array([0.62, 0.075, 0.055])
MIDDLE = np.array([0.70, 0.22, 0.17])
CHUNK = 500


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    length = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + length]), bytearray(data[28 + length:])


def write_glb(path, gltf, blob):
    blob.extend(b"\0" * (-len(blob) % 4))
    gltf["buffers"][0]["byteLength"] = len(blob)
    payload = json.dumps(gltf, separators=(",", ":")).encode()
    payload += b" " * (-len(payload) % 4)
    total = 12 + 8 + len(payload) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(payload), 0x4E4F534A))
        f.write(payload)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(blob)


def positions(gltf, blob, name):
    node = next(n for n in gltf["nodes"] if n["name"] == name)
    primitive = gltf["meshes"][node["mesh"]]["primitives"][0]
    accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
    view = gltf["bufferViews"][accessor["bufferView"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return primitive, np.frombuffer(bytes(blob), "<f4", accessor["count"] * 3, start).reshape(-1, 3)


def nearest_distance(points, cloud):
    result = np.empty(len(points))
    for i in range(0, len(points), CHUNK):
        gaps = points[i:i + CHUNK, None, :] - cloud[None, :, :]
        result[i:i + CHUNK] = np.sqrt((gaps * gaps).sum(axis=2).min(axis=1))
    return result


def main(source, target):
    gltf, blob = read_glb(source)
    primitive, band = positions(gltf, blob, "white")
    _, muscle = positions(gltf, blob, "muscle")
    node = next(n for n in gltf["nodes"] if n["name"] == "white")
    material = gltf["materials"][gltf["meshes"][node["mesh"]]["primitives"][0]["material"]]
    white = np.array(material["pbrMetallicRoughness"]["baseColorFactor"][:3])

    low, high = BAND_Y
    fade = np.minimum(band[:, 1] - low, high - band[:, 1]) / FADE_HEIGHT
    weight = np.clip(fade, 0, 1) * (np.abs(band[:, 0]) > BAND_MIN_X)
    chosen = weight > 0
    near = np.clip(nearest_distance(band[chosen], muscle[muscle[:, 1] > low - 0.05]) / MUSCLE_REACH, 0, 1)
    tint = EDGE + (MIDDLE - EDGE)[None, :] * near[:, None]

    colors = np.ones((len(band), 4), dtype="<f4")
    colors[chosen, :3] = 1 + (tint / white - 1) * weight[chosen, None]
    print(f"tinted {chosen.sum()} of {len(band)} vertices")

    blob.extend(b"\0" * (-len(blob) % 4))
    gltf["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": colors.nbytes,
                                "target": 34962})
    blob.extend(colors.tobytes())
    gltf["accessors"].append({"bufferView": len(gltf["bufferViews"]) - 1, "componentType": 5126,
                              "count": len(colors), "type": "VEC4"})
    primitive["attributes"]["COLOR_0"] = len(gltf["accessors"]) - 1
    write_glb(target, gltf, blob)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
