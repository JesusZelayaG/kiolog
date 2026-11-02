"""Give the `muslo` morph a natural thigh shape, in place.

    python reshape_thigh.py IN.glb OUT.glb

The swell from fit_measures.py is a mid-thigh spindle that grows inwards as much
as outwards, and it also inflates the hands. This one runs from the hip towards
the knee, grows mostly outwards and leaves the arms alone. It is scaled to keep
the perimeter at the tape height, so the calibration JSON stays valid.
"""
import json
import struct
import sys

import numpy as np

SHAPE = "muslo"
# Mesh-space heights: the tape sits at 0.66, the hip tape at 0.90 stays untouched.
GAIN = [(0.46, 0.0), (0.60, 0.8), (0.72, 1.0), (0.80, 0.9), (0.875, 0.0)]
TAPE_Y = 0.66
TAPE_BAND = 0.012
TAPE_X = (0.0, 0.24)
AXIS_Y = (0.42, 0.95)
ARM_FADE = (0.215, 0.235)
# Share of the sideways growth kept on the inner side of the thigh.
INNER_SHARE = 0.35


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    length = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + length]), bytearray(data[28 + length:])


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


def span(gltf, index):
    accessor = gltf["accessors"][index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    return view.get("byteOffset", 0) + accessor.get("byteOffset", 0), accessor["count"]


def load(gltf, blob, index):
    start, count = span(gltf, index)
    return np.frombuffer(blob, "<f4", count * 3, start).reshape(-1, 3).astype(float)


def thigh_axis(cloud):
    """Centre of one thigh at each height, as (x from midline, z)."""
    side = np.abs(cloud[:, 0])
    keep = (side > 0) & (side < ARM_FADE[0]) & (cloud[:, 1] > AXIS_Y[0]) & (cloud[:, 1] < AXIS_Y[1])
    legs = cloud[keep]
    bins = np.arange(AXIS_Y[0], AXIS_Y[1] + 0.02, 0.02)
    centre = np.full((len(bins), 2), np.nan)
    for i, y in enumerate(bins):
        ring = legs[np.abs(legs[:, 1] - y) < 0.03]
        if len(ring) >= 10:
            centre[i, 0] = np.percentile(np.abs(ring[:, 0]), [2, 98]).mean()
            centre[i, 1] = np.percentile(ring[:, 2], [2, 98]).mean()
    known = ~np.isnan(centre[:, 0])
    for i in range(2):
        centre[:, i] = np.interp(bins, bins[known], centre[known, i])
    kernel = np.ones(5) / 5
    pad = np.pad(centre, ((2, 2), (0, 0)), mode="edge")
    return bins, np.stack([np.convolve(pad[:, i], kernel, "valid") for i in range(2)], axis=1)


def swell(points, bins, centre):
    side = np.abs(points[:, 0])
    y = points[:, 1]
    gain = np.interp(y, *zip(*GAIN))
    gain *= np.clip((ARM_FADE[1] - side) / (ARM_FADE[1] - ARM_FADE[0]), 0, 1)
    across = side - np.interp(y, bins, centre[:, 0])
    out = np.zeros_like(points)
    out[:, 0] = across * gain * np.where(across < 0, INNER_SHARE, 1.0) * np.sign(points[:, 0])
    out[:, 2] = (points[:, 2] - np.interp(y, bins, centre[:, 1])) * gain
    return out


def hull_perimeter(flat):
    """Perimeter of the convex hull of 2D points."""
    pts = sorted(set(map(tuple, np.round(flat, 6))))

    def half(sequence):
        hull = []
        for p in sequence:
            while len(hull) >= 2 and ((hull[-1][0] - hull[-2][0]) * (p[1] - hull[-2][1])
                                      - (hull[-1][1] - hull[-2][1]) * (p[0] - hull[-2][0])) <= 0:
                hull.pop()
            hull.append(p)
        return hull[:-1]

    ring = np.array(half(pts) + half(pts[::-1]))
    return np.linalg.norm(ring - np.roll(ring, 1, axis=0), axis=1).sum()


def tape(cloud):
    near = (np.abs(cloud[:, 1] - TAPE_Y) < TAPE_BAND) & (cloud[:, 0] > TAPE_X[0]) & (cloud[:, 0] < TAPE_X[1])
    return hull_perimeter(cloud[near][:, [0, 2]])


def main(source, target):
    gltf, blob = read_glb(source)
    parts = []
    for node in gltf["nodes"]:
        mesh = gltf["meshes"][node["mesh"]]
        primitive = mesh["primitives"][0]
        names = mesh["extras"]["targetNames"]
        base = load(gltf, blob, primitive["attributes"]["POSITION"])
        index = primitive["targets"][names.index(SHAPE)]["POSITION"]
        parts.append((node["name"], base, index, load(gltf, blob, index)))
    solid = [p for p in parts if p[0] != "fat"]
    cloud = np.vstack([p[1] for p in solid])
    bins, centre = thigh_axis(cloud)
    new = [swell(p[1], bins, centre) for p in parts]
    start = tape(cloud)
    wanted = tape(np.vstack([p[1] + p[3] for p in solid])) - start
    got = tape(np.vstack([p[1] + d for p, d in zip(parts, new) if p[0] != "fat"])) - start
    scale = wanted / got
    print(f"tape base {start * 100:.1f} cm, old gain {wanted * 100:.1f}, new {got * 100:.1f}, scale {scale:.3f}")
    for (name, base, index, _), delta in zip(parts, new):
        delta = delta * scale
        offset, _count = span(gltf, index)
        blob[offset:offset + delta.size * 4] = delta.astype("<f4").tobytes()
        accessor = gltf["accessors"][index]
        accessor["min"] = delta.min(axis=0).tolist()
        accessor["max"] = delta.max(axis=0).tolist()
    final = tape(np.vstack([p[1] + d * scale for p, d in zip(parts, new) if p[0] != "fat"])) - start
    print(f"final gain {final * 100:.1f} cm")
    write_glb(target, gltf, blob)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
