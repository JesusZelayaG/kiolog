#!/usr/bin/env python3
"""Bake Anny body models into GLB files with one morph target per measurement.

Anny needs PyTorch, so it cannot run on a phone. This script runs on a
computer and writes the assets the app loads. Requires `pip install anny torch`.

    python export_body.py assets/models

Every morph target spans a body zone from its smallest to its largest value:
weight 0 is the thin end of the range and weight 1 the thick end.
"""
import json
import math
import struct
import sys
import warnings
from pathlib import Path

import anny
import numpy as np
import torch

warnings.filterwarnings("ignore")

SEXES = {"male": 0.0, "female": 1.0}
PHENOTYPE = {"age": 0.5, "muscle": 0.5, "weight": 0.5, "height": 0.5, "proportions": 0.5}

# App-facing name -> Anny local changes that move together.
MORPHS = {
    "pecho": ["measure-bust-circ-incr"],
    "cintura": ["measure-waist-circ-incr"],
    "abdomen": ["stomach-pregnant-incr"],
    "cadera": ["measure-hips-circ-incr"],
    "brazo": ["measure-upperarm-circ-incr"],
    "muslo": ["measure-thigh-circ-incr"],
    "pantorrilla": ["measure-calf-circ-incr"],
}
MORPH_RANGE = 0.6
# Relaxed standing pose, in degrees around the front-back axis.
POSE = {
    "upperarm01": 74,
    "lowerarm01": -8,
    "upperleg01": -6,
}
SKIN = [0.80, 0.66, 0.58, 1.0]


def rotation_y(degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return torch.tensor(
        [[[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]],
        dtype=torch.float64,
    )


def to_y_up(vertices):
    """Anny is Z-up facing -Y; glTF is Y-up facing +Z."""
    return np.stack([vertices[:, 0], vertices[:, 2], -vertices[:, 1]], axis=1)


def vertex_normals(vertices, faces):
    a, b, c = (vertices[faces[:, i]] for i in range(3))
    face_normals = np.cross(b - a, c - a)
    normals = np.zeros_like(vertices)
    for i in range(3):
        np.add.at(normals, faces[:, i], face_normals)
    lengths = np.linalg.norm(normals, axis=1, keepdims=True)
    return normals / np.maximum(lengths, 1e-12)


def build_glb(path, vertices, normals, faces, targets):
    """Write a single skin-free mesh. `targets` maps name -> (dpos, dnormal)."""
    blob = bytearray()
    views, accessors = [], []

    def add(array, component, kind, target=None, bounds=False):
        data = array.tobytes()
        while len(blob) % 4:
            blob.append(0)
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
        if target:
            view["target"] = target
        blob.extend(data)
        views.append(view)
        accessor = {
            "bufferView": len(views) - 1,
            "componentType": component,
            "count": len(array),
            "type": kind,
        }
        if bounds:
            accessor["min"] = array.min(axis=0).tolist()
            accessor["max"] = array.max(axis=0).tolist()
        accessors.append(accessor)
        return len(accessors) - 1

    FLOAT, UINT32, VEC3, SCALAR = 5126, 5125, "VEC3", "SCALAR"
    ARRAY, ELEMENT = 34962, 34963
    attributes = {
        "POSITION": add(vertices.astype("<f4"), FLOAT, VEC3, ARRAY, bounds=True),
        "NORMAL": add(normals.astype("<f4"), FLOAT, VEC3, ARRAY),
    }
    indices = add(faces.astype("<u4").reshape(-1), UINT32, SCALAR, ELEMENT)
    morphs = [
        {
            "POSITION": add(dpos.astype("<f4"), FLOAT, VEC3, ARRAY, bounds=True),
            "NORMAL": add(dnormal.astype("<f4"), FLOAT, VEC3, ARRAY),
        }
        for dpos, dnormal in targets.values()
    ]
    names = list(targets)
    gltf = {
        "asset": {"version": "2.0", "generator": "kiolog/tools/body_model"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "body", "mesh": 0}],
        "meshes": [
            {
                "name": "body",
                "primitives": [
                    {
                        "attributes": attributes,
                        "indices": indices,
                        "material": 0,
                        "targets": morphs,
                    }
                ],
                "weights": [0.5] * len(names),
                "extras": {"targetNames": names},
            }
        ],
        "materials": [
            {
                "name": "skin",
                "pbrMetallicRoughness": {
                    "baseColorFactor": SKIN,
                    "metallicFactor": 0.0,
                    "roughnessFactor": 0.75,
                },
            }
        ],
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": views,
        "accessors": accessors,
    }
    payload = json.dumps(gltf, separators=(",", ":")).encode()
    payload += b" " * (-len(payload) % 4)
    blob.extend(b"\0" * (-len(blob) % 4))
    total = 12 + 8 + len(payload) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(payload), 0x4E4F534A))
        f.write(payload)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(blob)


def main(output_dir):
    labels = sorted({label for group in MORPHS.values() for label in group})
    model = anny.Anny(local_changes=labels, pose_parameterization="local-bone-world")
    faces = model.get_triangular_faces().cpu().numpy()
    pose = {}
    for bone, degrees in POSE.items():
        pose[f"{bone}.L"] = rotation_y(degrees)
        pose[f"{bone}.R"] = rotation_y(-degrees)

    def evaluate(gender, changes):
        with torch.no_grad():
            output = model(
                pose_parameters=pose,
                phenotype_kwargs={"gender": gender, **PHENOTYPE},
                local_changes_kwargs={label: float(v) for label, v in changes.items()},
            )
        return to_y_up(output["vertices"][0].cpu().numpy().astype(np.float64))

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    for sex, gender in SEXES.items():
        low = {label: -MORPH_RANGE for label in labels}
        base = evaluate(gender, low)
        base_normals = vertex_normals(base, faces)
        targets = {}
        for name, group in MORPHS.items():
            varied = evaluate(gender, {**low, **{g: MORPH_RANGE for g in group}})
            normals = vertex_normals(varied, faces)
            targets[name] = (varied - base, normals - base_normals)
        path = output_dir / f"body_{sex}.glb"
        build_glb(path, base, base_normals, faces, targets)
        extent = base.max(axis=0) - base.min(axis=0)
        largest = {n: round(float(np.abs(d).max()) * 100, 1) for n, (d, _) in targets.items()}
        print(f"{path}: {path.stat().st_size / 1e6:.1f} MB, "
              f"{len(base)} verts, {len(faces)} tris, extent {extent.round(3)}, "
              f"max shift cm {largest}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/models")
