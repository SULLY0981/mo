"""Renders a contact sheet of models (for checking art). Usage: python render_lineup.py out.png model1 model2 ..."""
import bpy, sys, os, math
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
out, names = args[0], args[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
here = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'models')
x = 0.0
for n in names:
    bpy.ops.import_scene.gltf(filepath=os.path.join(here, n + '.glb'))
    objs = bpy.context.selected_objects
    w = max(max((o.dimensions.x for o in objs), default=1), 0.6)
    for o in objs:
        if o.parent is None:
            o.location.x += x + w / 2
            o.rotation_euler.z += math.radians(-20)
    x += w + 0.5
sc = bpy.context.scene
bpy.ops.mesh.primitive_plane_add(size=200)
pl = bpy.context.active_object
m = bpy.data.materials.new('floor'); m.use_nodes = True
m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.02, 0.018, 0.03, 1)
pl.data.materials.append(m)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
cx = x / 2
dist = max(4.0, x * 1.15)
cam.location = (cx, -dist, dist * 0.45)
cam.rotation_euler = (math.radians(70), 0, 0)
for loc, e, c in (((cx - 3, -4, 6), 2500, (1, 0.8, 0.6)), ((cx + 4, -2, 3), 900, (0.6, 0.7, 1)), ((cx, 4, 5), 1500, (0.7, 0.5, 1))):
    L = bpy.data.objects.new('L', bpy.data.lights.new('L', 'AREA')); L.data.energy = e * max(1, x / 6); L.data.size = 4; L.data.color = c
    L.location = loc; L.rotation_euler = (math.radians(45) if loc[1] < 0 else math.radians(-45), 0, 0); sc.collection.objects.link(L)
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.01, 0.008, 0.02, 1)
sc.render.engine = 'CYCLES'; sc.cycles.samples = 32; sc.cycles.use_denoising = True; sc.cycles.device = 'CPU'
sc.render.resolution_x = 1600; sc.render.resolution_y = 700; sc.render.filepath = os.path.abspath(out)
sc.view_settings.view_transform = 'AgX'
bpy.ops.render.render(write_still=True)
print('rendered', out)
