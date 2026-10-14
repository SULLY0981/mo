"""
Builds every 3D model for The Last Lantern in Blender and exports them as .glb.

Run with Blender's Python module (pip install bpy==4.2.0, Python 3.11):
    python tools/blender/build_assets.py assets/models
or with a full Blender install:
    blender -b -P tools/blender/build_assets.py -- assets/models

Conventions: meters, Z up, models face +Y (becomes -Z "forward" in Godot), feet at origin.
Materials whose name ends in "Glow" are emissive; the game boosts them for bloom.
Material "Cloak" is recolored per character in-game.
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, noise

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
OUT = os.path.abspath(args[0] if args else 'assets/models')
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- helpers
def lin(hexs):
    hexs = hexs.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(hexs[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return out


MATS = {}


def mat(name, color, rough=0.75, metal=0.0, emit=None, strength=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*lin(color), 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = (*lin(emit), 1)
        b.inputs['Emission Strength'].default_value = strength
    MATS[name] = m
    return m


def finish(o, m, smooth=True):
    o.data.materials.clear()
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def active():
    return bpy.context.active_object


def sphere(loc, scale, m, seg=24, rings=14, smooth=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc)
    o = active(); o.scale = scale
    return finish(o, m, smooth)


def ico(loc, r, m, sub=1, scale=(1, 1, 1), smooth=False):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = active(); o.scale = scale
    return finish(o, m, smooth)


def cone(loc, r1, r2, depth, m, verts=24, rot=(0, 0, 0), smooth=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(active(), m, smooth)


def cyl(loc, r, depth, m, verts=16, rot=(0, 0, 0), smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    return finish(active(), m, smooth)


def box(loc, size, m, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = active(); o.scale = size
    finish(o, m, False)
    if bevel:
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        mod = o.modifiers.new('bev', 'BEVEL'); mod.width = bevel; mod.segments = 2
        bpy.ops.object.modifier_apply(modifier='bev')
    return o


def torus(loc, R, r, m, rot=(0, 0, 0), maj=32, mino=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=maj, minor_segments=mino, location=loc, rotation=rot)
    return finish(active(), m, True)


def limb(p1, p2, r1, r2, m, verts=12):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    return cone(tuple((p1 + p2) / 2), r1, r2, d.length, m, verts=verts, rot=rot)


def jitter(o, amt, freq=2.0, seed=0.0, zmin=-99):
    """Organic deformation. Uses continuous noise so seams stay closed."""
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    mw = o.matrix_world
    for v in o.data.vertices:
        w = mw @ v.co
        if w.z < zmin:
            continue
        n = noise.noise_vector(w * freq + Vector((seed, seed * 2, seed * 3)))
        v.co += n * amt
    return o


def flat_poly(points, m, thick=0.02, loc=(0, 0, 0)):
    me = bpy.data.meshes.new('poly')
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0)) for x, y in points]
    bm.faces.new(vs)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('poly', me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    mod = o.modifiers.new('sol', 'SOLIDIFY'); mod.thickness = thick; mod.offset = 0
    bpy.ops.object.modifier_apply(modifier='sol')
    return finish(o, m, False)


def join(objs, name, origin=(0, 0, 0)):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = active(); o.name = name; o.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.scene.cursor.location = origin
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = (0, 0, 0)
    return o


def export(name):
    bpy.ops.object.select_all(action='SELECT')
    path = os.path.join(OUT, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT')
    bpy.ops.object.delete()
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    print('exported', path)


# ---------------------------------------------------------------- palette
M = dict(
    cloak=mat('Cloak', '#3b2a5c', 0.85),
    cloak2=mat('CloakDark', '#22183a', 0.9),
    trim=mat('Trim', '#c9a24a', 0.35, 0.8),
    void=mat('Void', '#050307', 1.0),
    eyeAmber=mat('EyeAmberGlow', '#ffb347', 0.4, 0, '#ffb347', 10),
    wood=mat('Wood', '#4a3324', 0.85),
    brass=mat('Brass', '#b8862f', 0.3, 0.9),
    flame=mat('FlameGlow', '#ffd27a', 0.2, 0, '#ffb54a', 14),
    glove=mat('Glove', '#2a1d1a', 0.8),
    bone=mat('Bone', '#d8cfb8', 0.6),
    eyeWhite=mat('EyeWhiteGlow', '#fff1c1', 0.3, 0, '#fff1c1', 8),
)


# ================================================================ PLAYER
def build_player():
    p = []
    robe = cone((0, 0, 0.575), 0.42, 0.15, 1.15, M['cloak'], verts=32)
    jitter(robe, 0.035, 5, 1.0)
    p.append(robe)
    p.append(torus((0, 0, 0.035), 0.405, 0.028, M['trim']))
    p.append(torus((0, 0, 0.76), 0.255, 0.03, M['trim']))
    p.append(sphere((0, 0.02, 1.1), (0.36, 0.3, 0.17), M['cloak2']))
    p.append(sphere((0, -0.02, 1.38), (0.24, 0.26, 0.27), M['cloak']))
    p.append(cone((0, -0.17, 1.56), 0.12, 0.0, 0.28, M['cloak'], rot=(math.radians(-50), 0, 0)))
    p.append(sphere((0, 0.17, 1.36), (0.16, 0.1, 0.17), M['void']))
    for s in (-1, 1):
        p.append(sphere((s * 0.06, 0.255, 1.38), (0.03, 0.02, 0.03), M['eyeAmber']))
    # sleeves + hands
    p.append(limb((0.27, 0.03, 1.12), (0.36, 0.2, 0.9), 0.1, 0.075, M['cloak']))
    p.append(sphere((0.37, 0.24, 0.88), (0.065, 0.065, 0.065), M['glove']))
    p.append(limb((-0.27, 0.03, 1.12), (-0.25, 0.18, 0.82), 0.1, 0.075, M['cloak']))
    p.append(sphere((-0.24, 0.21, 0.8), (0.06, 0.06, 0.06), M['glove']))
    # front tabard with emblem
    p.append(box((0, 0.27, 0.45), (0.2, 0.02, 0.55), M['cloak2'], rot=(math.radians(-14), 0, 0)))
    p.append(ico((0, 0.31, 0.58), 0.05, M['trim'], sub=0))
    # staff
    p.append(limb((0.38, 0.25, 0.0), (0.38, 0.25, 1.78), 0.028, 0.022, M['wood'], verts=8))
    p.append(limb((0.38, 0.25, 1.76), (0.38, 0.46, 1.74), 0.02, 0.018, M['wood'], verts=8))
    p.append(sphere((0.38, 0.25, 1.8), (0.04, 0.04, 0.04), M['brass']))
    join(p, 'Body')
    # lantern (separate so it can swing); origin at the hook
    hook = (0.38, 0.46, 1.72)
    q = []
    q.append(limb(hook, (0.38, 0.46, 1.62), 0.006, 0.006, M['brass'], verts=6))
    q.append(torus((0.38, 0.46, 1.6), 0.03, 0.007, M['brass'], rot=(math.radians(90), 0, 0)))
    q.append(cone((0.38, 0.46, 1.555), 0.1, 0.025, 0.07, M['brass'], verts=8))
    q.append(cyl((0.38, 0.46, 1.42), 0.07, 0.2, M['flame'], verts=8))
    q.append(cyl((0.38, 0.46, 1.31), 0.095, 0.035, M['brass'], verts=8))
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        q.append(cyl((0.38 + math.cos(a) * 0.082, 0.46 + math.sin(a) * 0.082, 1.43), 0.01, 0.22, M['brass'], verts=6))
    join(q, 'Lantern', origin=hook)
    export('player')


# ================================================================ ENEMIES
def build_wisp():
    m = mat('WispGlow', '#7d5cff', 0.4, 0, '#5a3dd6', 0.9)
    p = [sphere((0, 0, 0.78), (0.38, 0.36, 0.4), m)]
    t = cone((0, 0, 0.36), 0.37, 0.04, 0.75, m, verts=24, rot=(math.pi, 0, 0))
    jitter(t, 0.07, 4, 3.0)
    p.append(t)
    for s in (-1, 1):
        p.append(sphere((s * 0.13, 0.3, 0.84), (0.1, 0.06, 0.13), M['void']))
        p.append(sphere((s * 0.13, 0.35, 0.84), (0.035, 0.02, 0.04), M['eyeWhite']))
        p.append(limb((s * 0.3, 0.05, 0.75), (s * 0.5, 0.15, 0.45), 0.08, 0.02, m))
    p.append(sphere((0, 0.33, 0.66), (0.08, 0.04, 0.04), M['void']))
    join(p, 'Body')
    export('wisp')


def build_bat():
    body = mat('BatFur', '#5a1830', 0.9)
    wing = mat('BatWing', '#2e0a1a', 0.7)
    eye = mat('EyeRedGlow', '#ff4d6d', 0.3, 0, '#ff3355', 10)
    p = [sphere((0, 0, 0), (0.17, 0.19, 0.2), body)]
    for s in (-1, 1):
        p.append(cone((s * 0.09, 0.02, 0.2), 0.05, 0.0, 0.16, body, verts=6, rot=(0, s * 0.3, 0)))
        p.append(sphere((s * 0.06, 0.16, 0.05), (0.03, 0.02, 0.03), eye))
        p.append(cone((s * 0.03, 0.17, -0.06), 0.012, 0.0, 0.05, M['bone'], verts=5, rot=(math.pi, 0, 0)))
    join(p, 'Body')
    pts = [(0.0, 0.08), (0.18, 0.13), (0.38, 0.14), (0.62, 0.04), (0.56, -0.08), (0.46, -0.02), (0.38, -0.14), (0.27, -0.05), (0.15, -0.13), (0.0, -0.06)]
    wl = flat_poly([(-x, y) for x, y in pts][::-1], wing, 0.015)
    join([wl], 'WingL', origin=(0, 0, 0))
    wr = flat_poly(pts, wing, 0.015)
    join([wr], 'WingR', origin=(0, 0, 0))
    bpy.data.objects['WingL'].location = (-0.12, 0, 0.03)
    bpy.data.objects['WingR'].location = (0.12, 0, 0.03)
    export('bat')


def build_brute():
    skin = mat('BruteSkin', '#3d5f8c', 0.85)
    dark = mat('BruteDark', '#1f2f48', 0.9)
    eye = mat('EyeCyanGlow', '#6ff0ff', 0.3, 0, '#6ff0ff', 10)
    p = []
    torso = sphere((0, 0, 0.85), (0.55, 0.45, 0.52), skin)
    jitter(torso, 0.05, 3, 2.0)
    p.append(torso)
    p.append(sphere((0, 0.05, 0.6), (0.45, 0.38, 0.3), dark))
    p.append(sphere((0, 0.42, 1.05), (0.27, 0.27, 0.24), skin))
    p.append(box((0, 0.56, 0.93), (0.3, 0.14, 0.1), dark, bevel=0.03))
    for s in (-1, 1):
        p.append(sphere((s * 0.11, 0.62, 1.1), (0.045, 0.03, 0.04), eye))
        h = limb((s * 0.18, 0.4, 1.22), (s * 0.42, 0.35, 1.55), 0.07, 0.01, M['bone'])
        p.append(h)
        p.append(limb((s * 0.5, 0.1, 1.05), (s * 0.66, 0.32, 0.45), 0.17, 0.13, skin))
        p.append(sphere((s * 0.67, 0.36, 0.36), (0.18, 0.18, 0.16), dark))
        p.append(limb((s * 0.24, 0, 0.45), (s * 0.27, 0.02, 0.05), 0.17, 0.15, skin))
        p.append(sphere((s * 0.27, 0.08, 0.05), (0.17, 0.2, 0.08), dark))
        p.append(cone((s * 0.66, 0.5, 0.3), 0.03, 0.0, 0.12, M['bone'], verts=5, rot=(-1.2, 0, 0)))
    for i in range(3):
        p.append(cone((0, -0.32 + i * 0.05, 1.28 - i * 0.18), 0.06, 0.0, 0.2, M['bone'], verts=6, rot=(-0.6, 0, 0)))
    join(p, 'Body')
    export('brute')


def build_spitter():
    green = mat('PlantGreen', '#3f7a2a', 0.7)
    leaf = mat('PlantLeaf', '#24461c', 0.8)
    iris = mat('ToxicGlow', '#c6ff4a', 0.3, 0, '#a8ff2a', 10)
    p = [cone((0, 0, 0.25), 0.18, 0.12, 0.5, leaf, verts=10)]
    bulb = sphere((0, 0, 0.78), (0.42, 0.42, 0.4), green)
    jitter(bulb, 0.04, 4, 5.0)
    p.append(bulb)
    for i in range(6):
        a = i / 6 * math.tau
        p.append(sphere((math.cos(a) * 0.38, math.sin(a) * 0.38, 0.08), (0.3, 0.12, 0.04), leaf))
        bpy.context.active_object.rotation_euler = (0, 0, a)
    for i in range(5):
        a = i / 5 * math.tau + 0.3
        p.append(cone((math.cos(a) * 0.3, math.sin(a) * 0.3, 1.1), 0.05, 0.0, 0.22, iris, verts=6,
                      rot=(math.cos(a + math.pi / 2) * 0.6, math.sin(a + math.pi / 2) * -0.6, 0)))
    p.append(sphere((0, 0.3, 0.85), (0.21, 0.14, 0.21), M['eyeWhite']))
    p.append(sphere((0, 0.42, 0.85), (0.11, 0.04, 0.11), iris))
    p.append(sphere((0, 0.45, 0.85), (0.05, 0.02, 0.07), M['void']))
    p.append(torus((0, 0.36, 0.56), 0.11, 0.03, M['void'], rot=(math.radians(80), 0, 0)))
    join(p, 'Body')
    export('spitter')


def build_crystal(name, scale):
    amber = mat('AmberGlow', '#ffb52e', 0.15, 0.1, '#ff8a1a', 2.2)
    rock = mat('CrystalRock', '#3a2a22', 0.9)
    p = []
    base = ico((0, 0, 0.18 * scale), 0.3 * scale, rock, sub=1, scale=(1.2, 1.2, 0.6))
    jitter(base, 0.05 * scale, 3, 9)
    p.append(base)
    p.append(cone((0, 0, 0.7 * scale), 0.24 * scale, 0.0, 1.0 * scale, amber, verts=6, smooth=False))
    for i in range(4):
        a = i / 4 * math.tau + 0.5
        p.append(cone((math.cos(a) * 0.22 * scale, math.sin(a) * 0.22 * scale, 0.45 * scale), 0.11 * scale, 0, 0.55 * scale, amber,
                      verts=6, rot=(math.sin(a) * -0.6, math.cos(a) * 0.6, 0), smooth=False))
    for s in (-1, 1):
        p.append(sphere((s * 0.08 * scale, 0.2 * scale, 0.62 * scale), (0.035 * scale, 0.03 * scale, 0.05 * scale), M['void']))
    join(p, 'Body')
    export(name)


def build_ghoul():
    char = mat('GhoulChar', '#3a2018', 0.9)
    ember = mat('EmberGlow', '#ff6a1a', 0.4, 0, '#ff5a10', 6)
    p = []
    torso = sphere((0, -0.05, 0.95), (0.32, 0.28, 0.42), char)
    jitter(torso, 0.06, 3, 7)
    p.append(torso)
    p.append(sphere((0, 0.25, 1.28), (0.19, 0.22, 0.2), M['bone']))
    p.append(box((0, 0.36, 1.15), (0.2, 0.12, 0.08), M['bone'], bevel=0.02))
    for s in (-1, 1):
        p.append(sphere((s * 0.08, 0.4, 1.32), (0.05, 0.03, 0.05), M['void']))
        p.append(sphere((s * 0.08, 0.42, 1.32), (0.025, 0.015, 0.025), ember))
        p.append(limb((s * 0.3, 0.05, 1.15), (s * 0.4, 0.45, 0.85), 0.07, 0.05, char))
        p.append(limb((s * 0.4, 0.45, 0.85), (s * 0.35, 0.75, 0.6), 0.05, 0.04, char))
        for k in range(3):
            p.append(limb((s * 0.35, 0.75, 0.6), (s * (0.3 + k * 0.05), 0.92, 0.45 - k * 0.05), 0.015, 0.002, M['bone'], verts=5))
        p.append(limb((s * 0.15, 0, 0.6), (s * 0.2, 0.05, 0.02), 0.09, 0.06, char))
    for i in range(6):
        z = 0.7 + i * 0.13
        p.append(cone((0, -0.3 - math.sin(i * 0.5) * 0.05, z), 0.06, 0.0, 0.3, ember, verts=5, rot=(-1.1 - i * 0.05, 0, 0)))
    for s in (-1, 1):
        for i in range(3):
            p.append(cone((s * 0.25, -0.12, 0.9 + i * 0.15), 0.045, 0, 0.22, ember, verts=5, rot=(-0.7, s * 0.8, 0)))
    join(p, 'Body')
    export('ghoul')


# ================================================================ BOSSES
def build_warden():
    iron = mat('Iron', '#3a3a46', 0.4, 0.85)
    ironD = mat('IronDark', '#1e1e26', 0.5, 0.8)
    red = mat('RedGlow', '#ff3d6e', 0.3, 0, '#ff2050', 12)
    cape = mat('WardenCape', '#4a0f1e', 0.9)
    p = []
    for s in (-1, 1):
        p.append(limb((s * 0.35, 0, 1.3), (s * 0.4, 0.05, 0.2), 0.24, 0.2, ironD))
        p.append(box((s * 0.4, 0.12, 0.12), (0.36, 0.55, 0.24), iron, bevel=0.05))
        p.append(sphere((s * 0.38, 0.12, 0.8), (0.2, 0.2, 0.2), iron))
    p.append(box((0, 0, 1.75), (1.15, 0.7, 1.0), iron, bevel=0.12))
    p.append(box((0, 0.1, 1.2), (0.95, 0.6, 0.4), ironD, bevel=0.08))
    p.append(sphere((0, 0.36, 1.85), (0.14, 0.06, 0.14), red))
    for s in (-1, 1):
        p.append(sphere((s * 0.75, 0, 2.2), (0.42, 0.42, 0.3), iron))
        for k in range(3):
            p.append(cone((s * (0.7 + k * 0.12), 0, 2.45), 0.07, 0, 0.35, ironD, verts=6, rot=(0, s * 0.4, 0)))
        p.append(limb((s * 0.8, 0, 2.0), (s * 0.95, 0.25, 1.2), 0.2, 0.17, ironD))
        p.append(sphere((s * 0.96, 0.32, 1.1), (0.22, 0.22, 0.2), iron))
    p.append(cyl((0, 0.05, 2.55), 0.32, 0.55, iron, verts=20))
    p.append(cone((0, 0.05, 2.95), 0.33, 0.05, 0.35, ironD, verts=20))
    p.append(box((0, 0.36, 2.58), (0.42, 0.05, 0.06), red))
    for s in (-1, 1):
        p.append(limb((s * 0.3, 0.05, 2.75), (s * 0.7, 0.0, 3.35), 0.09, 0.0, M['bone']))
    c = cone((0, -0.45, 1.3), 0.85, 0.5, 2.0, cape, verts=24)
    jitter(c, 0.05, 3, 4)
    p.append(c)
    # greatsword in right hand, point down
    p.append(box((0.98, 0.55, 0.65), (0.1, 0.24, 1.6), iron, bevel=0.02))
    p.append(box((0.98, 0.55, 1.5), (0.12, 0.6, 0.1), ironD))
    p.append(box((0.98, 0.55, 0.65), (0.03, 0.08, 1.4), red))
    join(p, 'Body')
    export('warden')


def build_choir():
    m = mat('ChoirGlow', '#6b4bd6', 0.45, 0, '#4a2fb0', 1.2)
    m2 = mat('ChoirDark', '#2a1a5a', 0.8)
    gold = mat('HaloGlow', '#ffd166', 0.3, 0.5, '#ffc24a', 8)
    p = []
    robe = cone((0, 0, 1.25), 1.05, 0.38, 1.9, m, verts=32)
    jitter(robe, 0.14, 2.2, 6)
    p.append(robe)
    p.append(cone((0, 0, 0.45), 0.9, 0.6, 0.5, m2, verts=32))
    for x, z, s in ((0, 2.45, 1.0), (-0.72, 2.05, 0.72), (0.72, 2.05, 0.72)):
        p.append(sphere((x, 0, z), (0.36 * s, 0.38 * s, 0.4 * s), m))
        p.append(cone((x, -0.16 * s, z + 0.38 * s), 0.2 * s, 0, 0.45 * s, m, rot=(-0.7, 0, 0)))
        p.append(sphere((x, 0.2 * s, z - 0.02), (0.22 * s, 0.14 * s, 0.25 * s), M['void']))
        for e in (-1, 1):
            p.append(sphere((x + e * 0.08 * s, 0.32 * s, z + 0.05 * s), (0.035 * s, 0.02 * s, 0.045 * s), M['eyeWhite']))
        p.append(sphere((x, 0.32 * s, z - 0.12 * s), (0.06 * s, 0.02 * s, 0.09 * s), gold))
        p.append(torus((x, -0.05 * s, z + 0.55 * s), 0.22 * s, 0.025, gold, rot=(0.3, 0, 0)))
    for s in (-1, 1):
        p.append(limb((s * 0.45, 0.1, 1.9), (s * 1.25, 0.45, 1.4), 0.16, 0.05, m))
        p.append(limb((s * 1.25, 0.45, 1.4), (s * 1.45, 0.7, 1.75), 0.05, 0.015, m2))
    join(p, 'Body')
    export('choir')


def build_king():
    robe = mat('KingRobe', '#1c1030', 0.85)
    robe2 = mat('KingRobe2', '#3a1f5a', 0.8)
    gold = mat('Gold', '#ffcf5a', 0.25, 1.0)
    gglow = mat('GoldGlow', '#ffd166', 0.3, 0, '#ffc24a', 12)
    p = []
    r = cone((0, 0, 1.4), 1.15, 0.45, 2.8, robe, verts=32)
    jitter(r, 0.08, 2, 8)
    p.append(r)
    p.append(torus((0, 0, 0.06), 1.12, 0.06, gold, maj=48))
    p.append(box((0, 0.55, 1.3), (0.5, 0.05, 2.2), robe2, rot=(math.radians(-14), 0, 0)))
    p.append(sphere((0, 0, 2.85), (0.85, 0.7, 0.35), robe2))
    for i in range(10):
        a = i / 10 * math.pi + math.pi
        p.append(cone((math.cos(a) * 0.75, -math.sin(a) * 0.6 * -1 - 0.1, 3.1), 0.08, 0, 0.6, robe, verts=6,
                      rot=(-0.4, math.cos(a) * 0.5, 0)))
    p.append(sphere((0, 0.1, 3.4), (0.36, 0.38, 0.42), M['bone']))
    p.append(box((0, 0.36, 3.2), (0.32, 0.18, 0.16), M['bone'], bevel=0.04))
    for s in (-1, 1):
        p.append(sphere((s * 0.13, 0.4, 3.45), (0.1, 0.06, 0.1), M['void']))
        p.append(sphere((s * 0.13, 0.44, 3.45), (0.045, 0.03, 0.045), gglow))
    p.append(cyl((0, 0.1, 3.82), 0.4, 0.2, gold, verts=24))
    for i in range(8):
        a = i / 8 * math.tau
        p.append(cone((math.cos(a) * 0.38, 0.1 + math.sin(a) * 0.38, 4.1), 0.07, 0, 0.45, gold, verts=4))
        if i % 2 == 0:
            p.append(ico((math.cos(a) * 0.41, 0.1 + math.sin(a) * 0.41, 3.82), 0.06, gglow, sub=0))
    for s in (-1, 1):
        p.append(limb((s * 0.75, 0, 2.8), (s * 1.05, 0.45, 1.9), 0.22, 0.14, robe))
        p.append(sphere((s * 1.07, 0.52, 1.82), (0.13, 0.13, 0.15), M['bone']))
    p.append(limb((1.07, 0.55, 0.0), (1.07, 0.55, 3.6), 0.05, 0.04, gold, verts=10))
    p.append(ico((1.07, 0.55, 3.8), 0.24, gglow, sub=2, smooth=True))
    p.append(torus((1.07, 0.55, 3.8), 0.3, 0.03, gold, rot=(1.2, 0, 0)))
    join(p, 'Body')
    export('king')


# ================================================================ ENVIRONMENT
def build_tree_dead(name, seed):
    random.seed(seed)
    bark = mat('Bark', '#2c2433', 0.95)
    p = []
    t = cone((0, 0, 1.6), 0.32, 0.1, 3.2, bark, verts=12)
    jitter(t, 0.12, 1.2, seed)
    p.append(t)

    def branch(pt, d, length, r, depth):
        if depth == 0 or length < 0.25:
            return
        end = pt + d * length
        p.append(limb(tuple(pt), tuple(end), r, r * 0.6, bark, verts=7))
        for _ in range(2):
            nd = (d + Vector((random.uniform(-0.8, 0.8), random.uniform(-0.8, 0.8), random.uniform(-0.1, 0.5)))).normalized()
            branch(end, nd, length * random.uniform(0.55, 0.75), r * 0.6, depth - 1)

    for i in range(4):
        a = random.uniform(0, math.tau)
        z = random.uniform(1.6, 3.0)
        d = Vector((math.cos(a), math.sin(a), random.uniform(0.3, 0.9))).normalized()
        branch(Vector((0, 0, z)), d, random.uniform(0.9, 1.4), 0.1, 3)
    for i in range(4):
        a = i / 4 * math.tau + random.random()
        p.append(limb((0, 0, 0.3), (math.cos(a) * 0.65, math.sin(a) * 0.65, -0.05), 0.12, 0.03, bark, verts=6))
    join(p, 'Body')
    export(name)


def build_tree_pine(name, seed):
    random.seed(seed)
    needles = mat('Pine', '#1b2f2a', 0.9)
    bark = mat('Bark', '#2c2433', 0.95)
    p = [cyl((0, 0, 0.6), 0.14, 1.2, bark, verts=8)]
    h = random.uniform(3.6, 4.6)
    for i in range(4):
        z = 0.9 + i * h * 0.2
        rr = 1.3 - i * 0.27
        c = cone((0, 0, z + 0.5), rr, 0.05, 1.3, needles, verts=10)
        jitter(c, 0.1, 2.2, seed + i)
        p.append(c)
    join(p, 'Body')
    export(name)


def build_graves():
    stone = mat('Stone', '#4a4658', 0.95)
    moss = mat('Moss', '#2c3a2a', 1.0)
    dirt = mat('Dirt', '#1c1612', 1.0)
    # rounded headstone
    p = [box((0, 0, 0.45), (0.6, 0.16, 0.9), stone, bevel=0.03), cyl((0, 0, 0.9), 0.3, 0.16, stone, verts=24, rot=(math.pi / 2, 0, 0))]
    p.append(box((0, 0.1, 0.55), (0.3, 0.03, 0.06), moss))
    p.append(box((0, 0.6, 0.04), (0.7, 1.1, 0.1), dirt, bevel=0.04))
    g = join(p, 'Body'); g.rotation_euler = (0.08, 0.05, 0)
    export('grave_a')
    # cross
    p = [box((0, 0, 0.7), (0.16, 0.14, 1.4), stone, bevel=0.02), box((0, 0, 1.05), (0.7, 0.14, 0.16), stone, bevel=0.02),
         torus((0, 0, 1.05), 0.22, 0.04, stone, rot=(math.pi / 2, 0, 0)), box((0, 0, 0.08), (0.4, 0.3, 0.16), stone, bevel=0.03)]
    g = join(p, 'Body'); g.rotation_euler = (0, 0.12, 0)
    export('grave_b')
    # broken slab
    p = [box((0, 0, 0.3), (0.55, 0.14, 0.6), stone, bevel=0.03), box((0.35, 0.3, 0.06), (0.4, 0.3, 0.12), stone, rot=(0, 0, 0.7), bevel=0.02)]
    s = p[0]; jitter(s, 0.03, 4, 3)
    g = join(p, 'Body'); g.rotation_euler = (-0.25, 0, 0.1)
    export('grave_c')


def build_rocks():
    stone = mat('RockStone', '#3a3746', 0.95)
    for i, (sc, n) in enumerate((((1.0, 0.8, 0.55), 2), ((0.6, 0.7, 0.9), 1))):
        p = []
        for k in range(n + 1):
            r = ico((k * 0.5 - 0.3, k * 0.2, 0.15), 0.4 - k * 0.1, stone, sub=2, scale=sc)
            jitter(r, 0.09, 2.5, i * 10 + k)
            p.append(r)
        join(p, 'Body')
        export('rock_' + 'ab'[i])


def build_mushrooms():
    stem = mat('Stem', '#cfc6b0', 0.8)
    cap = mat('MushGlow', '#3fc6d4', 0.5, 0, '#2ad0e0', 3.5)
    p = []
    for x, y, h, r in ((0, 0, 0.35, 0.16), (0.22, 0.1, 0.22, 0.11), (-0.15, 0.18, 0.18, 0.08), (0.08, -0.2, 0.14, 0.07)):
        p.append(cyl((x, y, h / 2), r * 0.25, h, stem, verts=8))
        c = sphere((x, y, h), (r, r, r * 0.55), cap, seg=16, rings=8)
        p.append(c)
    join(p, 'Body')
    export('mushrooms')


def build_ruins():
    stone = mat('RuinStone', '#57536a', 0.9)
    p = [box((0, 0, 0.12), (1.0, 1.0, 0.24), stone, bevel=0.03)]
    for i in range(4):
        c = cyl((0, 0, 0.24 + 0.35 * i + 0.17), 0.33, 0.33, stone, verts=16)
        c.rotation_euler = (0, 0, i * 0.3)
        p.append(c)
    top = cyl((0, 0, 1.68), 0.33, 0.3, stone, verts=16)
    jitter(top, 0.08, 3, 2, zmin=1.6)
    p.append(top)
    fallen = cyl((1.1, 0.3, 0.3), 0.3, 1.2, stone, verts=16, rot=(0, math.pi / 2, 0.4))
    p.append(fallen)
    p.append(box((-0.8, 0.6, 0.15), (0.5, 0.4, 0.3), stone, rot=(0.2, 0.1, 0.5), bevel=0.04))
    join(p, 'Body')
    export('ruins')


def build_fence():
    wood = mat('OldWood', '#3a2e26', 0.95)
    p = []
    for i in range(3):
        post = box((i * 0.9 - 0.9, 0, 0.5), (0.1, 0.1, 1.0), wood, rot=(0, (i - 1) * 0.08, 0), bevel=0.01)
        p.append(post)
        p.append(cone((i * 0.9 - 0.9, 0, 1.05), 0.08, 0, 0.14, wood, verts=4))
    p.append(box((-0.45, 0, 0.75), (0.95, 0.05, 0.1), wood, rot=(0, 0.04, 0)))
    p.append(box((-0.45, 0, 0.4), (0.95, 0.05, 0.1), wood))
    p.append(box((0.45, 0, 0.6), (0.95, 0.05, 0.1), wood, rot=(0, -0.35, 0)))
    join(p, 'Body')
    export('fence')


def build_candles():
    wax = mat('Wax', '#d8cbb0', 0.6)
    fl = mat('CandleGlow', '#ffcf70', 0.2, 0, '#ffb040', 20)
    stone = mat('Stone', '#4a4658', 0.95)
    p = [cyl((0, 0, 0.08), 0.35, 0.16, stone, verts=10)]
    for x, y, h in ((0, 0, 0.35), (0.15, 0.1, 0.25), (-0.12, 0.12, 0.2), (0.05, -0.17, 0.3), (-0.17, -0.08, 0.15)):
        p.append(cyl((x, y, 0.16 + h / 2), 0.04, h, wax, verts=8))
        p.append(sphere((x, y, 0.16 + h + 0.04), (0.022, 0.022, 0.045), fl, seg=8, rings=6))
    join(p, 'Body')
    export('candles')


def build_grass():
    g = mat('Grass', '#22362a', 0.95)
    p = []
    random.seed(4)
    for i in range(9):
        a = random.uniform(0, math.tau); r = random.uniform(0, 0.15)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = random.uniform(0.18, 0.38)
        p.append(cone((x, y, h / 2), 0.025, 0.0, h, g, verts=3, rot=(random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), 0), smooth=False))
    join(p, 'Body')
    export('grass')


# ================================================================ PICKUPS
def build_pickups():
    white = mat('GemGlow', '#ffffff', 0.15, 0, '#ffffff', 1.0)
    p = [cone((0, 0, 0.12), 0.1, 0, 0.16, white, verts=4, smooth=False), cone((0, 0, -0.04), 0.1, 0, 0.16, white, verts=4, rot=(math.pi, 0, 0), smooth=False)]
    join(p, 'Body')
    export('gem')
    gold = mat('Gold', '#ffcf5a', 0.25, 1.0)
    p = [cyl((0, 0, 0), 0.13, 0.035, gold, verts=20, rot=(math.pi / 2, 0, 0)), box((0, 0, 0), (0.05, 0.05, 0.05), gold, rot=(math.pi / 2, math.pi / 4, 0))]
    join(p, 'Body')
    export('coin')
    wood = mat('ChestWood', '#6a3c1e', 0.8)
    p = [box((0, 0, 0.2), (0.7, 0.45, 0.4), wood, bevel=0.03)]
    for x in (-0.25, 0.25):
        p.append(box((x, 0, 0.2), (0.06, 0.47, 0.42), gold))
    p.append(box((0, 0.23, 0.32), (0.1, 0.03, 0.12), gold))
    join(p, 'Body')
    lid = [cyl((0, 0, 0.4), 0.225, 0.7, wood, verts=16, rot=(0, math.pi / 2, 0))]
    lid.append(box((0, -0.0, 0.4), (0.7, 0.45, 0.01), wood))
    for x in (-0.25, 0.25):
        lid.append(cyl((x, 0, 0.4), 0.235, 0.06, gold, verts=16, rot=(0, math.pi / 2, 0)))
    lo = join(lid, 'Lid', origin=(0, -0.225, 0.4))
    export('chest')
    red = mat('HeartGlow', '#ff3d5a', 0.2, 0, '#ff2040', 3)
    p = [sphere((-0.08, 0, 0.08), (0.11, 0.08, 0.11), red), sphere((0.08, 0, 0.08), (0.11, 0.08, 0.11), red),
         cone((0, 0, -0.06), 0.16, 0, 0.22, red, verts=16, rot=(math.pi, 0, 0))]
    p[2].scale = (1, 0.55, 1)
    join(p, 'Body')
    export('heart')
    blue = mat('MagnetGlow', '#6ec6ff', 0.3, 0.5, '#4aa8ff', 2)
    silver = mat('Silver', '#d0d8e0', 0.2, 1.0)
    p = [torus((0, 0, 0), 0.13, 0.045, blue, rot=(math.pi / 2, 0, 0))]
    bm = p[0]
    me = bm.data
    bmo = bmesh.new(); bmo.from_mesh(me)
    bmesh.ops.bisect_plane(bmo, geom=bmo.verts[:] + bmo.edges[:] + bmo.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_outer=True)
    bmo.to_mesh(me); bmo.free()
    for s in (-1, 1):
        p.append(cyl((s * 0.13, 0, 0.06), 0.045, 0.12, blue, verts=12))
        p.append(cyl((s * 0.13, 0, 0.14), 0.046, 0.05, silver, verts=12))
    join(p, 'Body')
    export('magnet')


# ================================================================ PROJECTILES
def build_projectiles():
    blade = mat('ScytheGlow', '#c9a0ff', 0.3, 0.2, '#9a6bff', 4)
    me = bpy.data.meshes.new('blade')
    bm = bmesh.new()
    outer, inner = [], []
    for i in range(17):
        a = -2.4 + (1.1 + 2.4) * i / 16
        outer.append((math.cos(a) * 0.62, math.sin(a) * 0.62))
    for i in range(17):
        a = 1.0 + (-2.2 - 1.0) * i / 16
        inner.append((0.2 + math.cos(a) * 0.45, -0.13 + math.sin(a) * 0.45))
    vs = [bm.verts.new((x, y, 0)) for x, y in outer + inner]
    bm.faces.new(vs)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('Body', me)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    mod = o.modifiers.new('sol', 'SOLIDIFY'); mod.thickness = 0.05; mod.offset = 0
    bpy.ops.object.modifier_apply(modifier='sol')
    finish(o, blade, False)
    p = [o, sphere((0, 0, 0), (0.08, 0.08, 0.08), M['eyeWhite'])]
    join(p, 'Body')
    export('scythe_blade')
    seedm = mat('SeedGlow', '#9dff5c', 0.4, 0, '#7dff3a', 4)
    husk = mat('SeedHusk', '#2a3a1a', 0.8)
    p = [sphere((0, 0, 0.12), (0.16, 0.16, 0.14), husk)]
    for i in range(6):
        a = i / 6 * math.tau
        p.append(cone((math.cos(a) * 0.14, math.sin(a) * 0.14, 0.14), 0.05, 0, 0.16, seedm, verts=5, rot=(math.sin(a) * -1.2, math.cos(a) * 1.2, 0)))
    p.append(sphere((0, 0, 0.24), (0.08, 0.08, 0.08), seedm))
    join(p, 'Body')
    export('seed')


build_player()
build_wisp(); build_bat(); build_brute(); build_spitter()
build_crystal('splitter', 1.0); build_crystal('mite', 0.55)
build_ghoul()
build_warden(); build_choir(); build_king()
build_tree_dead('tree_dead_a', 1); build_tree_dead('tree_dead_b', 7)
build_tree_pine('tree_pine_a', 2); build_tree_pine('tree_pine_b', 9)
build_graves(); build_rocks(); build_mushrooms(); build_ruins(); build_fence(); build_candles(); build_grass()
build_pickups()
build_projectiles()
print('ALL ASSETS BUILT')
