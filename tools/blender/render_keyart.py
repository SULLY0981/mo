"""
Renders Steam key art (Cycles) from the game's own models.
Usage: python tools/blender/render_keyart.py <out.png> <width> <height> [samples] [layout]
layout: "wide" (character left, room for logo right), "tall" (character centered low), "hero" (ultra-wide, no text)
"""
import bpy, sys, os, math, random
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
OUT, W, H = os.path.abspath(args[0]), int(args[1]), int(args[2])
SAMPLES = int(args[3]) if len(args) > 3 else 64
LAYOUT = args[4] if len(args) > 4 else 'wide'
MODELS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'models')
random.seed(3)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def place(name, loc, rot_z=0.0, scale=1.0):
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + '.glb'))
    objs = bpy.context.selected_objects
    root = bpy.data.objects.new(name + '_root', None)
    sc.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    root.location = loc
    root.rotation_euler = (0, 0, rot_z)
    root.scale = (scale, scale, scale)
    return root


def face(target_from, target_to):
    d = Vector(target_to) - Vector(target_from)
    # models face +Y
    return math.atan2(-d.x, d.y)


# ---------------- ground
bpy.ops.mesh.primitive_plane_add(size=300)
g = bpy.context.active_object
m = bpy.data.materials.new('ground'); m.use_nodes = True
nt = m.node_tree
bsdf = nt.nodes['Principled BSDF']
noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 0.6; noise.inputs['Detail'].default_value = 8
ramp = nt.nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].color = (0.012, 0.016, 0.012, 1)
ramp.color_ramp.elements[1].color = (0.03, 0.026, 0.024, 1)
nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
nt.links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
bsdf.inputs['Roughness'].default_value = 0.95
g.data.materials.append(m)

# ---------------- cast
cam_loc = {'wide': (1.5, 4.8, 1.3), 'tall': (0.0, 5.6, 1.5), 'hero': (0.0, 7.5, 1.6)}[LAYOUT]
hero = (0, 0, 0)
if LAYOUT == 'wide':
    hero = (1.15, 0, 0)
p = place('player', hero, face(hero, cam_loc) + 0.35)

ring = []
spots = [(-2.6, -3.5, 'wisp'), (-1.2, -5.5, 'brute'), (1.9, -4.8, 'ghoul'), (3.6, -3.0, 'wisp'), (-4.2, -1.6, 'spitter'),
         (4.6, -6.5, 'wisp'), (-3.6, -7.5, 'wisp'), (0.6, -8.5, 'brute'), (5.8, -2.0, 'splitter'), (-6.0, -4.5, 'ghoul'),
         (2.8, -10.0, 'wisp'), (-1.0, -11.0, 'wisp'), (7.5, -7.0, 'brute'), (-8.0, -8.0, 'wisp')]
if LAYOUT == 'hero':
    spots += [(-11, -5, 'wisp'), (11, -5, 'ghoul'), (-14, -9, 'brute'), (13, -10, 'wisp'), (-9, -2, 'bat'), (9, -3, 'spitter')]
for x, y, n in spots:
    loc = (x + hero[0], y, 0)
    place(n, loc, face(loc, hero) + random.uniform(-0.2, 0.2), random.uniform(0.95, 1.15))
for x, y, z in ((-1.8, -2.2, 1.9), (2.3, -2.6, 2.4), (-3.5, -5.0, 2.8)):
    loc = (x + hero[0], y, z)
    place('bat', loc, face(loc, hero), 1.1)
place('warden', (hero[0] - 0.5, -15.0, 0), face((0, -15, 0), hero), 1.15)

props = [('tree_dead_a', -5.5, -9.5), ('tree_dead_b', 6.0, -12.0), ('tree_pine_a', -9.0, -15.0), ('tree_pine_b', 10.0, -16.0),
         ('tree_dead_a', 9.5, -5.0), ('grave_a', -2.2, -1.2), ('grave_b', 3.4, -1.5), ('grave_c', -4.0, -3.0), ('grave_b', 1.5, -6.5),
         ('rock_a', 4.6, 0.8), ('mushrooms', -1.5, 1.0), ('candles', 3.0, 0.3), ('ruins', -7.5, -6.0), ('tree_pine_a', 2.0, -20.0),
         ('tree_dead_b', -12.0, -11.0), ('fence', 6.5, -8.5)]
for n, x, y in props:
    place(n, (x + hero[0], y, 0), random.uniform(0, math.tau), random.uniform(0.9, 1.2))

# ---------------- lights
lantern_pos = Vector(hero) + Vector((0.38, 0.46, 1.42))
lantern_pos = p.matrix_world @ Vector((0.38, 0.46, 1.42)) if False else None
bpy.context.view_layer.update()
lan = [o for o in bpy.data.objects if o.name.startswith('Lantern')]
lp = lan[0].matrix_world @ Vector((0, 0, -0.3)) if lan else Vector(hero) + Vector((0.4, 0.4, 1.4))
for o in lan:
    o.visible_shadow = False
L = bpy.data.objects.new('lantern', bpy.data.lights.new('lantern', 'POINT'))
L.data.energy = 380; L.data.color = (1.0, 0.62, 0.3); L.data.shadow_soft_size = 0.05
L.location = lp; sc.collection.objects.link(L)
L2 = bpy.data.objects.new('candle', bpy.data.lights.new('candle', 'POINT'))
L2.data.energy = 120; L2.data.color = (1.0, 0.55, 0.25); L2.location = (3.0 + hero[0], 0.3, 0.6); sc.collection.objects.link(L2)
moon = bpy.data.objects.new('moon', bpy.data.lights.new('moon', 'SUN'))
moon.data.energy = 0.35; moon.data.color = (0.45, 0.55, 1.0); moon.data.angle = 0.05
moon.rotation_euler = (math.radians(60), 0, math.radians(180)); sc.collection.objects.link(moon)
rim = bpy.data.objects.new('rim', bpy.data.lights.new('rim', 'AREA'))
rim.data.energy = 260; rim.data.color = (0.5, 0.45, 1.0); rim.data.size = 6
rim.location = (hero[0], -9, 6); rim.rotation_euler = (math.radians(-55), 0, 0); sc.collection.objects.link(rim)

# ---------------- world + fog
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes['Background']; bg.inputs['Color'].default_value = (0.004, 0.003, 0.012, 1); bg.inputs['Strength'].default_value = 1
vol = w.node_tree.nodes.new('ShaderNodeVolumePrincipled')
vol.inputs['Density'].default_value = 0.012
vol.inputs['Color'].default_value = (0.6, 0.55, 0.85, 1)
vol.inputs['Anisotropy'].default_value = 0.4
w.node_tree.links.new(vol.outputs['Volume'], w.node_tree.nodes['World Output'].inputs['Volume'])

# ---------------- camera
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.location = cam_loc
look = {'wide': (-1.3, -3.0, 1.45), 'tall': (0.0, -2.0, 1.2), 'hero': (0.0, -4.0, 1.2)}[LAYOUT]
d = Vector(look) - Vector(cam_loc)
cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = {'wide': 32, 'tall': 32, 'hero': 26}[LAYOUT]
cam.data.dof.use_dof = True
cam.data.dof.focus_object = p
cam.data.dof.aperture_fstop = 2.8

sc.render.engine = 'CYCLES'
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.cycles.device = 'CPU'
sc.cycles.volume_step_rate = 4.0
sc.cycles.max_bounces = 4
sc.render.resolution_x = W; sc.render.resolution_y = H
sc.render.filepath = OUT
sc.view_settings.view_transform = 'AgX'
sc.view_settings.look = 'AgX - Punchy'
sc.view_settings.exposure = -0.3
bpy.ops.render.render(write_still=True)
print('rendered', OUT)
