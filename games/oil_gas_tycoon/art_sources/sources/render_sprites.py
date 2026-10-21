"""Render the selected Kenney CC0 models as transparent tycoon sprites.

Reproduce with the verified portable Blender 4.5.0 archive:
  blender --background --factory-startup --python render_sprites.py -- --only refinery
  blender --background --factory-startup --python render_sprites.py

All paths are relative to this script. Source assets stay unchanged. The script
uses Cycles on the CPU, a fixed seed, an orthographic camera, and soft self-shadow
lighting. The game draws contact shadows independently, keeping sprite borders
fully transparent and preventing rectangular shadow seams.
It is an ordinary Blender asset preparation script, not a game-dev CLI run.
"""

import argparse
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "derived" / "sprites"
SELECTION = [
    ("refinery", "city-kit-industrial", "building-g", "Industrial processing building with pipework and stack"),
    ("processing_plant", "city-kit-industrial", "building-o", "Two-storey industrial processing building"),
    ("warehouse", "city-kit-industrial", "building-k", "Sawtooth-roof industrial warehouse"),
    ("workshop", "city-kit-industrial", "building-m", "Industrial workshop with three exhaust stacks"),
    ("headquarters", "city-kit-industrial", "building-a", "Three-storey industrial headquarters"),
    ("office", "city-kit-industrial", "building-p", "Low industrial office with rooftop skylights"),
    ("storage_tank", "city-kit-industrial", "detail-tank-large", "Large cylindrical storage tank"),
    ("compressor", "city-kit-industrial", "detail-tank", "Horizontal pressure vessel"),
    ("water_tower", "city-kit-industrial", "water-tower", "Elevated water tank"),
    ("shipping_container", "city-kit-industrial", "shipping-container-a", "Corrugated shipping container"),
    ("cooling_tower", "city-kit-industrial", "chimney-large", "Cooling tower"),
    ("crew_pickup", "car-kit", "truck", "Utility crew pickup truck"),
    ("flatbed_truck", "car-kit", "truck-flat", "Flatbed truck"),
    ("delivery_truck", "car-kit", "delivery", "Delivery truck"),
    ("site_loader", "car-kit", "tractor-shovel", "Wheeled front loader"),
    ("crew_van", "car-kit", "van", "Crew van"),
    ("pumpjack", "project-original", "pumpjack", "Original walking-beam oil pumpjack"),
    ("heavy_pumpjack", "project-original", "heavy_pumpjack", "Original heavy-duty oil pumpjack"),
    ("drilling_rig", "project-original", "drilling_rig", "Original drilling derrick and service deck"),
    ("gas_skid", "project-original", "gas_skid", "Original gas separator and compressor skid"),
    ("field_tanker", "project-original", "field_tanker", "Original field oil tanker truck"),
    ("heavy_tanker", "project-original", "heavy_tanker", "Original heavy oil tanker truck"),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def aim(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def area_light(name, location, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = location
    aim(light, (0, 0, 0.7))


def corners(objects):
    return [obj.matrix_world @ Vector(p) for obj in objects for p in obj.bound_box]


def render(selection, resolution, samples):
    name, pack, model, description = selection
    original = pack == "project-original"
    source = ROOT / "original_equipment.py" if original else ROOT / "extracted" / pack / "Models" / "GLB format" / (model + ".glb")
    texture = None if original else source.parent / "Textures" / "colormap.png"
    if pack == "city-kit-industrial":
        texture = ROOT / "extracted" / pack / "Models" / "Textures" / "variation-a.png"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.seed = 1729
    scene.cycles.use_denoising = True
    scene.cycles.adaptive_threshold = 0.018
    scene.cycles.max_bounces = 6
    scene.cycles.diffuse_bounces = 4
    scene.cycles.glossy_bounces = 4
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 8
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 70
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = -0.25
    scene.view_settings.gamma = 1.0

    world = bpy.data.worlds.new("Soft studio environment")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.76, 0.82, 1.0, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    scene.world = world

    if original:
        spec = importlib.util.spec_from_file_location("original_equipment", source)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.build(model)
    else:
        bpy.ops.import_scene.gltf(filepath=str(source))
    if pack == "city-kit-industrial":
        palette = bpy.data.images.load(str(texture), check_existing=True)
        for material in bpy.data.materials:
            if material.use_nodes:
                for node in material.node_tree.nodes:
                    if node.type == "TEX_IMAGE":
                        node.image = palette
    imported = list(scene.objects)
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("No geometry in " + str(source))
    root = bpy.data.objects.new("Asset origin", None)
    bpy.context.collection.objects.link(root)
    for obj in imported:
        if obj.parent is None:
            obj.parent = root
    if pack == "city-kit-industrial":
        root.rotation_euler.z = math.pi
    bpy.context.view_layer.update()
    points = corners(meshes)
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    scale = 2.0 / max(high.x - low.x, high.y - low.y)
    root.scale = (scale,) * 3
    root.location = (-0.5 * (low.x + high.x) * scale, -0.5 * (low.y + high.y) * scale, -low.z * scale)
    bpy.context.view_layer.update()

    for material in bpy.data.materials:
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type == "BSDF_PRINCIPLED":
                    node.inputs["Roughness"].default_value = 0.62
                    node.inputs["Metallic"].default_value = 0.03
                    node.inputs["Specular IOR Level"].default_value = 0.25
                if node.type == "TEX_IMAGE":
                    node.interpolation = "Closest"

    camera_data = bpy.data.cameras.new("Matched isometric camera")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new("Matched isometric camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (8, -8, 8)
    aim(camera, (0, 0, 0))
    scene.camera = camera
    bpy.context.view_layer.update()
    rotation = camera.rotation_euler.to_matrix()
    right, up, toward = rotation @ Vector((1, 0, 0)), rotation @ Vector((0, 1, 0)), rotation @ Vector((0, 0, 1))
    projected = [(p.dot(right), p.dot(up)) for p in corners(meshes)]
    left, rightmost = min(p[0] for p in projected), max(p[0] for p in projected)
    bottom, top = min(p[1] for p in projected), max(p[1] for p in projected)
    target = right * ((left + rightmost) * 0.5) + up * ((bottom + top) * 0.5)
    camera.location = target + toward * 12
    camera_data.ortho_scale = max(rightmost - left, top - bottom) / 0.76

    area_light("Warm key", (-3.5, -4.5, 7), 420, 5, (1.0, 0.89, 0.76))
    area_light("Cool fill", (4, -1, 4.5), 180, 4, (0.69, 0.84, 1.0))
    area_light("Soft rim", (1, 5, 6), 260, 4, (0.83, 0.93, 1.0))

    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / (name + ".png")
    scene.render.filepath = str(path)
    bpy.context.view_layer.update()
    anchor = world_to_camera_view(scene, camera, Vector((0, 0, 0)))
    bpy.ops.render.render(write_still=True)
    return {
        "id": name,
        "description": description,
        "source_pack": pack,
        "source_model": str(source.relative_to(ROOT)),
        "source_model_sha256": digest(source),
        "source_texture": str(texture.relative_to(ROOT)) if texture else None,
        "source_texture_sha256": digest(texture) if texture else None,
        "output": str(path.relative_to(ROOT)),
        "bytes": path.stat().st_size,
        "sha256": digest(path),
        "width": resolution,
        "height": resolution,
        "ground_anchor_normalized": [round(anchor.x, 6), round(1.0 - anchor.y, 6)],
        "camera_azimuth_degrees": -45,
        "camera_elevation_degrees": round(math.degrees(math.atan(1 / math.sqrt(2))), 6),
        "ortho_scale": camera_data.ortho_scale,
        "geometry_uniform_scale": scale,
        "samples": samples,
        "lighting": "Three soft area lights and cool ambient world; self-shadows only",
        "ground_shadow": "Drawn by the game rather than baked into the transparent sprite",
        "renderer": "Blender 4.5.0 / Cycles CPU",
        "license": "project-authored" if original else "CC0-1.0",
        "model_rotation_z_degrees": 180 if pack == "city-kit-industrial" else 0,
    }


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="*")
    parser.add_argument("--resolution", type=int, default=512)
    parser.add_argument("--samples", type=int, default=64)
    options = parser.parse_args(args)
    rows = []
    for selection in SELECTION:
        if options.only and selection[0] not in options.only:
            continue
        print("Rendering", selection[0], flush=True)
        row = render(selection, options.resolution, options.samples)
        rows.append(row)
        metadata = ROOT / "derived" / "metadata"
        metadata.mkdir(parents=True, exist_ok=True)
        (metadata / (row["id"] + ".json")).write_text(json.dumps(row, indent=2) + "\n")
        print("Rendered", row["id"], row["sha256"], flush=True)
    print("Completed", len(rows), "sprites", flush=True)


if __name__ == "__main__":
    main()
