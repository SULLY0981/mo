extends Node3D
class_name World
## The 3D game world: environment, player, enemies, weapons and the spawn director.
## Gameplay runs on the XZ plane using Vector2 positions (x, z).

signal level_up_ready
signal run_finished(reason: String)
signal banner(title: String, sub: String, color: Color)
signal toast(text: String, color: Color)
signal victory_ready
signal boss_changed(active: bool)

const CELL := 2.0
const SPAWN_R := 23.0
const RECYCLE_R := 34.0
const CHUNK := 14.0
const CHUNK_RANGE := 2
const MAX_ENEMIES := 420
const MAX_GEMS := 600

# ---------------------------------------------------------------- types
class Enemy:
	var id := 0
	var type := ""
	var pos := Vector2.ZERO
	var r := 0.4
	var hp := 1.0
	var max_hp := 1.0
	var speed := 1.0
	var dmg := 1.0
	var xp := 1.0
	var kb := Vector2.ZERO
	var flash := 0.0
	var flash_cd := 0.0
	var slow := 0.0
	var hit_cd := {}
	var elite := false
	var boss := false
	var t := 0.0
	var shoot_t := 2.0
	var dir := 1
	var heavy := 0.0
	var dead := false
	var node: Node3D
	var meshes: Array = []
	var parts := {}
	var overlay := 0
	var facing := 0.0
	var spawn_t := 0.0
	# boss
	var bname := ""
	var is_king := false
	var state := ""
	var st_t := 0.0
	var dash := Vector2.ZERO
	var atk := 2.5
	var spiral := 0.0
	var sp_t := 0.0
	var sp_a := 0.0
	var mv := Vector2.ZERO
	var cur_speed := 0.0

class Proj:
	var kind := ""
	var w: Weapon
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var speed := 0.0
	var r := 0.3
	var dmg := 1.0
	var pierce := 1
	var life := 1.0
	var home: Enemy
	var hit := {}
	var t := 0.0
	var rot := 0.0
	var arm := 0.0
	var blast := 0.0
	var node: Node3D
	var dead := false

class Weapon:
	var id := ""
	var lvl := 1
	var cd := 0.4
	var dmg_total := 0.0
	var ang := 0.0
	var orbs: Array = []
	var orb_nodes: Array = []
	var second := 0.0
	var rot := 0.0

class Pickup:
	var kind := ""
	var pos := Vector2.ZERO
	var mag := false
	var sp := 0.0
	var t := 0.0
	var v := 0
	var node: Node3D
	var dead := false

class Bullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 1.0
	var life := 6.0
	var node: MeshInstance3D

# ---------------------------------------------------------------- run state
var mode := "menu"
var char_id := "keeper"
var time := 0.0
var kills := 0
var coins := 0
var weapons: Array[Weapon] = []
var passives := {}
var passive_order: Array[String] = []
var enemies: Array[Enemy] = []
var bosses: Array[Enemy] = []
var projs: Array[Proj] = []
var bullets: Array[Bullet] = []
var gems: Array = []  # [Vector2 pos, float value, bool mag, float speed]
var pickups: Array[Pickup] = []
var spawn_acc := 0.0
var boss_done := {}
var ev_done := {}
var elite_t := 70.0
var pending_levels := 0
var over := false
var won := false
var endless := false
var dying := 0.0
var victory_t := 0.0
var ach_t := 1.0
var took_damage := false
var choices: Array = []
var shake := 0.0
var hurt := 0.0
var eid := 0
var grid := {}

# player
var P := {}
var ppos := Vector2.ZERO
var pface := Vector2(0, 1)
var pmoving := false
var iframe := 0.0

# ---------------------------------------------------------------- nodes
var cam: Camera3D
var cam_target := Vector3.ZERO
var env: Environment
var moon: DirectionalLight3D
var player_node: Node3D
var lantern_node: Node3D
var lantern_light: OmniLight3D
var ground: MeshInstance3D
var gem_mm: MultiMeshInstance3D
var scenes := {}
var pools := {}
var chunks := {}
var colliders := {}
var flash_mat: StandardMaterial3D
var elite_mat: StandardMaterial3D
var slow_mat: StandardMaterial3D
var bolt_mesh: SphereMesh
var bolt_mat: StandardMaterial3D
var frost_mesh: PrismMesh
var frost_mat: StandardMaterial3D
var bullet_mesh: SphereMesh
var bullet_mat: StandardMaterial3D
var orb_mat: StandardMaterial3D
var bolt_seg_mesh: BoxMesh
var bolt_seg_mat: StandardMaterial3D
var ring_mesh: PlaneMesh
var ring_mat: ShaderMaterial
var tele_mat: StandardMaterial3D
var particle_pool: Array = []
var particle_next := 0
var labels: Array[Label3D] = []
var label_next := 0
var fx_rings: Array = []    # [node, life, max, radius]
var fx_lights: Array = []   # [OmniLight3D, life, max, energy]
var fx_segs: Array = []     # [node, life]
var font: Font
var rng := RandomNumberGenerator.new()
var menu_t := 0.0
var quality := 2


# ================================================================= setup
func _ready() -> void:
	quality = int(Save.setting("quality"))
	font = load("res://assets/fonts/AlegreyaSans-ExtraBold.woff2")
	_build_materials()
	_build_environment()
	_build_ground()
	_load_scenes()
	_build_pools()
	player_node = _spawn_model("player")
	add_child(player_node)
	lantern_node = player_node.find_child("Lantern", true, false)
	lantern_light = OmniLight3D.new()
	lantern_light.light_color = Color(1.0, 0.68, 0.38)
	lantern_light.omni_range = 12.0
	lantern_light.light_energy = 6.0
	lantern_light.omni_attenuation = 0.85
	lantern_light.shadow_enabled = quality >= 1
	lantern_light.light_volumetric_fog_energy = 1.6
	if lantern_node:
		for mi in lantern_node.find_children("*", "MeshInstance3D", true, false) + ([lantern_node] if lantern_node is MeshInstance3D else []):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lantern_node.add_child(lantern_light)
		lantern_light.position = Vector3(0, -0.32, 0)
	else:
		player_node.add_child(lantern_light)
		lantern_light.position = Vector3(0.4, 1.4, -0.4)


func _build_materials() -> void:
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.3, 1.3, 1.3)
	elite_mat = StandardMaterial3D.new()
	elite_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elite_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elite_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	elite_mat.albedo_color = Color(1.0, 0.75, 0.2, 0.5)
	elite_mat.rim_enabled = true
	slow_mat = StandardMaterial3D.new()
	slow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	slow_mat.albedo_color = Color(0.4, 0.8, 1.0, 0.45)
	bolt_mesh = SphereMesh.new(); bolt_mesh.radius = 0.15; bolt_mesh.height = 0.3; bolt_mesh.radial_segments = 12; bolt_mesh.rings = 6
	bolt_mat = _glow_mat(Color(1.0, 0.55, 0.15), 4.0)
	frost_mesh = PrismMesh.new(); frost_mesh.size = Vector3(0.16, 0.6, 0.08)
	frost_mat = _glow_mat(Color(0.6, 0.9, 1.0), 2.4)
	bullet_mesh = SphereMesh.new(); bullet_mesh.radius = 0.22; bullet_mesh.height = 0.44; bullet_mesh.radial_segments = 10; bullet_mesh.rings = 5
	bullet_mat = _glow_mat(Color(1.0, 0.3, 0.85), 3.0)
	orb_mat = _glow_mat(Color(1.0, 0.8, 0.3), 3.0)
	bolt_seg_mesh = BoxMesh.new(); bolt_seg_mesh.size = Vector3(0.07, 0.07, 1.0)
	bolt_seg_mat = _glow_mat(Color(0.55, 0.85, 1.0), 4.5)
	ring_mesh = PlaneMesh.new(); ring_mesh.size = Vector2(2, 2)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float r = mix(0.15, 1.0, sqrt(progress));
	float ring = smoothstep(0.16, 0.0, abs(d - r)) * (1.0 - progress);
	float fill = smoothstep(r, 0.0, d) * 0.06 * (1.0 - progress);
	vec3 c = tint.rgb * 1.4;
	ALBEDO = c;
	ALPHA = clamp(ring + fill, 0.0, 1.0);
}
"""
	ring_mat = ShaderMaterial.new(); ring_mat.shader = sh
	tele_mat = StandardMaterial3D.new()
	tele_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tele_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tele_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tele_mat.albedo_color = Color(1.0, 0.15, 0.3, 0.35)
	tele_mat.no_depth_test = true


func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r * energy * 0.5, c.g * energy * 0.5, c.b * energy * 0.5)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.01, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.5)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0); env.set_glow_level(1, 1.0); env.set_glow_level(2, 1.0); env.set_glow_level(3, 0.6); env.set_glow_level(4, 0.4)
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.04, 0.1)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = quality >= 2
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.55, 0.5, 0.8)
	env.volumetric_fog_emission = Color(0.012, 0.01, 0.03)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.15
	env.ssao_enabled = quality >= 2
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52, -35, 0)
	moon.light_color = Color(0.55, 0.6, 1.0)
	moon.light_energy = 0.5
	moon.shadow_enabled = quality >= 1
	moon.directional_shadow_max_distance = 45.0
	moon.light_volumetric_fog_energy = 0.4
	add_child(moon)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.5
	cam.far = 120.0
	add_child(cam)
	cam.position = Vector3(0, 13, 9.5)
	cam.look_at(Vector3.ZERO)


func _build_ground() -> void:
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(150, 150); pm.subdivide_width = 0; pm.subdivide_depth = 0
	ground.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float big = fbm(p * 0.045);
	float mid = fbm(p * 0.22 + 7.3);
	float fine = fbm(p * 1.7 + 3.1);
	vec3 grass = vec3(0.045, 0.06, 0.045);
	vec3 moss = vec3(0.035, 0.05, 0.05);
	vec3 dirt = vec3(0.07, 0.055, 0.05);
	vec3 stone = vec3(0.075, 0.07, 0.085);
	vec3 c = mix(grass, moss, smoothstep(0.35, 0.65, mid));
	c = mix(c, dirt, smoothstep(0.52, 0.68, big + mid * 0.25));
	float path = smoothstep(0.03, 0.0, abs(fbm(p * 0.03 + 11.0) - 0.5) - 0.02);
	c = mix(c, stone * (0.8 + fine * 0.5), path * 0.85);
	c *= 0.75 + fine * 0.5;
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""
	var m := ShaderMaterial.new(); m.shader = sh
	ground.material_override = m
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# Gems use a single MultiMesh for performance.
	gem_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var gm: Mesh = _first_mesh(load("res://assets/models/gem.glb"))
	mm.mesh = gm
	mm.instance_count = MAX_GEMS
	mm.visible_instance_count = 0
	gem_mm.multimesh = mm
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.vertex_color_use_as_albedo = true
	gem_mm.material_override = gmat
	gem_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gem_mm)


func _first_mesh(ps: PackedScene) -> Mesh:
	var n := ps.instantiate()
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var m := mi.mesh
	n.free()
	return m


const MODELS := ["player", "wisp", "bat", "brute", "spitter", "splitter", "mite", "ghoul", "warden", "choir", "king",
	"tree_dead_a", "tree_dead_b", "tree_pine_a", "tree_pine_b", "grave_a", "grave_b", "grave_c", "rock_a", "rock_b",
	"mushrooms", "ruins", "fence", "candles", "grass", "coin", "chest", "heart", "magnet", "scythe_blade", "seed"]

func _load_scenes() -> void:
	for n in MODELS:
		var path := "res://assets/models/%s.glb" % n
		if ResourceLoader.exists(path):
			scenes[n] = load(path)


func _spawn_model(n: String) -> Node3D:
	var node: Node3D = scenes[n].instantiate()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s)
			if mat is StandardMaterial3D and "Glow" in mat.resource_name and not mat.has_meta("tuned"):
				mat.set_meta("tuned", true)
				mat.emission_enabled = true
				mat.emission_energy_multiplier = clampf(mat.emission_energy_multiplier, 0.5, 6.0)
	return node


func _build_pools() -> void:
	for i in 40:
		var gp := GPUParticles3D.new()
		gp.one_shot = true
		gp.emitting = false
		gp.amount = 24
		gp.lifetime = 0.5
		gp.explosiveness = 1.0
		gp.local_coords = false
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 1.5
		pm.initial_velocity_max = 4.0
		pm.gravity = Vector3(0, -6, 0)
		pm.damping_min = 2.0; pm.damping_max = 4.0
		pm.scale_min = 0.5; pm.scale_max = 1.2
		var curve := CurveTexture.new(); var c := Curve.new(); c.add_point(Vector2(0, 1)); c.add_point(Vector2(1, 0)); curve.curve = c
		pm.scale_curve = curve
		gp.process_material = pm
		var q := QuadMesh.new(); q.size = Vector2(0.14, 0.14)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.vertex_color_use_as_albedo = true
		var gt := GradientTexture2D.new()
		var gr := Gradient.new(); gr.set_color(0, Color(1, 1, 1, 1)); gr.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = gr; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 32; gt.height = 32
		qm.albedo_texture = gt
		q.material = qm
		gp.draw_pass_1 = q
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(gp)
		particle_pool.append(gp)
	for i in 60:
		var l := Label3D.new()
		l.font = font
		l.font_size = 64
		l.pixel_size = 0.006
		l.outline_size = 14
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.visible = false
		l.set_meta("life", 0.0)
		add_child(l)
		labels.append(l)
	for i in 14:
		var r := MeshInstance3D.new()
		r.mesh = ring_mesh
		r.material_override = ring_mat
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		fx_rings.append([r, 0.0, 1.0, 1.0])
	for i in 8:
		var l := OmniLight3D.new()
		l.visible = false
		l.shadow_enabled = false
		l.omni_range = 6.0
		add_child(l)
		fx_lights.append([l, 0.0, 1.0, 1.0])
	for i in 80:
		var s := MeshInstance3D.new()
		s.mesh = bolt_seg_mesh
		s.material_override = bolt_seg_mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		fx_segs.append([s, 0.0])


func _pool_get(kind: String) -> Node3D:
	var arr: Array = pools.get(kind, [])
	if arr.size() > 0:
		var n: Node3D = arr.pop_back()
		n.visible = true
		return n
	var node: Node3D
	match kind:
		"bolt":
			var mi := MeshInstance3D.new(); mi.mesh = bolt_mesh; mi.material_override = bolt_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node = mi
		"frost":
			var mi := MeshInstance3D.new(); mi.mesh = frost_mesh; mi.material_override = frost_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node = mi
		"bullet":
			var mi := MeshInstance3D.new(); mi.mesh = bullet_mesh; mi.material_override = bullet_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node = mi
		"orb":
			var mi := MeshInstance3D.new(); mi.mesh = bolt_mesh; mi.material_override = orb_mat; mi.scale = Vector3.ONE * 1.6
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.75, 0.3); l.light_energy = 0.8; l.omni_range = 3.0
			mi.add_child(l)
			node = mi
		"scythe":
			node = _spawn_model("scythe_blade") if scenes.has("scythe_blade") else MeshInstance3D.new()
		"mine":
			node = _spawn_model("seed") if scenes.has("seed") else MeshInstance3D.new()
		"tele":
			var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(1, 1); mi.mesh = pm; mi.material_override = tele_mat
			node = mi
		_:
			node = _spawn_model(kind)
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("kind", kind)
	add_child(node)
	return node


func _pool_put(n: Node3D) -> void:
	if n == null:
		return
	n.visible = false
	var kind: String = n.get_meta("kind", "")
	if not pools.has(kind):
		pools[kind] = []
	pools[kind].append(n)


# ================================================================= runs
func setup_menu(c: String) -> void:
	mode = "menu"
	char_id = c
	_tint_player(c)
	ppos = Vector2.ZERO
	pface = Vector2(0, 1)
	_update_chunks(true)


func start_run(c: String) -> void:
	mode = "run"
	char_id = c
	_tint_player(c)
	P = {"level": 1, "xp": 0.0, "xp_next": xp_for(1), "revives": Save.shop_level("revive"), "rerolls": Save.shop_level("reroll"), "max_hp": 0.0, "hp": 0.0}
	recalc_stats()
	P.hp = P.max_hp
	add_weapon(Data.CHARS[c].weapon)
	_update_chunks(true)
	toast.emit("Survive until dawn", Color("ffd166"))


func _tint_player(c: String) -> void:
	var col := Color(Data.CHARS[c].color)
	for mi in player_node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s)
			if mat and mat.resource_name == "Cloak":
				var d: StandardMaterial3D = mat.duplicate()
				d.albedo_color = col
				m.set_surface_override_material(s, d)


static func xp_for(l: int) -> float:
	return floor(4 + l * 3 + l * l * 0.32)


func recalc_stats() -> void:
	var mods: Dictionary = Data.CHARS[char_id].mods
	var sh := func(id): return Save.shop_level(id)
	var pl := func(id): return int(passives.get(id, 0))
	var old_max: float = P.max_hp
	P.max_hp = (120.0 + sh.call("hp") * 10) * mods.get("hp", 1.0) * (1 + 0.2 * pl.call("vigor"))
	P.speed = 5.0 * (1 + sh.call("speed") * 0.04) * mods.get("speed", 1.0) * (1 + 0.08 * pl.call("swift"))
	P.might = (1 + sh.call("might") * 0.05) * mods.get("might", 1.0) * (1 + 0.1 * pl.call("might"))
	P.cd = (1 - sh.call("cd") * 0.03) * mods.get("cd", 1.0) * pow(0.93, pl.call("haste"))
	P.area = (1 + sh.call("area") * 0.04) * mods.get("area", 1.0) * (1 + 0.1 * pl.call("reach"))
	P.amount = pl.call("multi") + mods.get("amount", 0)
	P.magnet = 2.4 * (1 + sh.call("magnet") * 0.15) * (1 + 0.3 * pl.call("magnet"))
	P.growth = (1 + sh.call("growth") * 0.04 + mods.get("growth", 0.0)) * (1 + 0.08 * pl.call("wisdom"))
	P.armor = sh.call("armor") + mods.get("armor", 0) + pl.call("plating")
	P.regen = sh.call("regen") * 0.1 + 0.3 * pl.call("renewal")
	P.luck = 1 + sh.call("luck") * 0.05 + mods.get("luck", 0.0) + 0.1 * pl.call("luck")
	P.greed = 1 + sh.call("greed") * 0.1
	P.light = 9.0 * mods.get("light", 1.0) * (1 + 0.15 * pl.call("light"))
	P.light_bonus = 1.15 if pl.call("light") > 0 else 1.0
	if old_max > 0:
		P.hp = minf(P.max_hp, P.hp + maxf(0, P.max_hp - old_max))
	lantern_light.omni_range = P.light * 1.35


func add_weapon(id: String) -> void:
	var w := Weapon.new()
	w.id = id
	weapons.append(w)


# ================================================================= main loop
func _process(delta: float) -> void:
	if mode == "menu":
		_menu_anim(delta)
		return
	if get_tree().paused:
		return
	step(delta)
	sync_visuals(delta)


func step(dt: float) -> void:
	if over:
		return
	if dying > 0:
		dying -= dt
		dt *= 0.3
		if dying <= 0:
			end_run("death")
			return
	if victory_t > 0:
		victory_t -= dt
		if victory_t <= 0:
			victory_ready.emit()
	time += dt
	if dying <= 0:
		var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if has_meta("bot"):
			mv = _bot_move()
		ppos += mv * P.speed * dt
		_resolve_props()
		pmoving = mv.length() > 0.1
		if pmoving:
			pface = mv.normalized()
	iframe -= dt
	if P.hp > 0 and P.hp < P.max_hp:
		P.hp = minf(P.max_hp, P.hp + P.regen * dt)
	if not won or endless:
		_director(dt)
	_build_grid()
	if dying <= 0:
		for w in weapons:
			_weapon_update(w, dt)
	_update_enemies(dt)
	_update_projs(dt)
	_update_bullets(dt)
	_update_gems(dt)
	_update_pickups(dt)
	_cleanup()
	ach_t -= dt
	if ach_t <= 0:
		ach_t = 1.0
		check_achievements()
	if pending_levels > 0 and dying <= 0 and not over:
		_offer_level()


func _cleanup() -> void:
	var alive: Array[Enemy] = []
	for e in enemies:
		if e.dead:
			_pool_put(e.node)
			e.node = null
		else:
			alive.append(e)
	if alive.size() != enemies.size():
		enemies = alive
		var b: Array[Enemy] = []
		for e in bosses:
			if not e.dead:
				b.append(e)
		if b.size() != bosses.size():
			bosses = b
			boss_changed.emit(bosses.size() > 0)
	var ap: Array[Proj] = []
	for p in projs:
		if p.dead:
			_pool_put(p.node)
		else:
			ap.append(p)
	projs = ap


# ================================================================= grid
func _key(x: float, y: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(y / CELL))


func _build_grid() -> void:
	grid.clear()
	for e in enemies:
		if e.dead or e.boss:
			continue
		var k := _key(e.pos.x, e.pos.y)
		if grid.has(k):
			grid[k].append(e)
		else:
			grid[k] = [e]


func query(p: Vector2, r: float) -> Array:
	var out := []
	var pad := r + 0.7
	var a := _key(p.x - pad, p.y - pad)
	var b := _key(p.x + pad, p.y + pad)
	for cx in range(a.x, b.x + 1):
		for cy in range(a.y, b.y + 1):
			var arr = grid.get(Vector2i(cx, cy))
			if arr == null:
				continue
			for e in arr:
				if not e.dead:
					var rr: float = r + e.r
					if p.distance_squared_to(e.pos) < rr * rr:
						out.append(e)
	for e in bosses:
		if not e.dead:
			var rr: float = r + e.r
			if p.distance_squared_to(e.pos) < rr * rr:
				out.append(e)
	return out


func nearest(p: Vector2, n: int, rng_max: float) -> Array:
	var r2 := rng_max * rng_max
	var list := []
	for e in enemies:
		if e.dead:
			continue
		var d := p.distance_squared_to(e.pos)
		if d < r2:
			list.append([d, e])
	if list.size() > n:
		list.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(n, list.size()):
		out.append(list[i][1])
	return out


# ================================================================= spawning
func _hp_scale() -> float:
	var m := time / 60.0
	return 1.0 + m * 0.22 + m * m * 0.011


func _spawn_point(scale: float = 1.0) -> Vector2:
	var a := randf() * TAU
	return ppos + Vector2(cos(a), sin(a)) * SPAWN_R * scale


func spawn_enemy(type: String, at = null, elite := false) -> Enemy:
	var T: Dictionary = Data.ENEMIES[type]
	var m := time / 60.0
	var e := Enemy.new()
	eid += 1
	e.id = eid
	e.type = type
	e.pos = at if at != null else _spawn_point()
	e.r = T.r * (1.45 if elite else 1.0)
	e.hp = T.hp * _hp_scale() * (8.0 if elite else 1.0)
	e.max_hp = e.hp
	e.speed = T.speed * randf_range(0.9, 1.1) * (0.92 if elite else 1.0)
	e.dmg = T.dmg * (1 + m * 0.05) * (1.4 if elite else 1.0)
	e.xp = T.xp * (1 + m * 0.08) * (12.0 if elite else 1.0)
	e.elite = elite
	e.t = randf() * 10
	e.shoot_t = randf_range(1.5, 3.0)
	e.dir = 1 if randf() < 0.5 else -1
	e.heavy = T.get("heavy", 0.0)
	e.node = _pool_get(type)
	e.meshes = e.node.find_children("*", "MeshInstance3D", true, false)
	e.parts = {"WingL": e.node.find_child("WingL", true, false), "WingR": e.node.find_child("WingR", true, false)}
	e.overlay = -1
	e.spawn_t = 0.0
	e.node.scale = Vector3.ONE * (1.45 if elite else 1.0)
	enemies.append(e)
	return e


func spawn_boss(type: String, mult: float) -> void:
	var B: Dictionary = Data.BOSSES[type]
	var e := Enemy.new()
	eid += 1
	e.id = eid
	e.type = type
	e.boss = true
	e.pos = _spawn_point(0.7)
	e.r = B.r
	var hs := _hp_scale() / 4.0 if endless else 1.0
	e.hp = B.hp * mult * hs
	e.max_hp = e.hp
	e.speed = B.speed
	e.dmg = B.dmg * (1.3 if mult > 1 else 1.0) * (1.5 if endless else 1.0)
	e.xp = B.xp
	e.heavy = 1.0
	e.bname = B.name
	e.is_king = type == "king"
	e.atk = 2.5
	e.node = _pool_get(type)
	e.meshes = e.node.find_children("*", "MeshInstance3D", true, false)
	e.overlay = -1
	enemies.append(e)
	bosses.append(e)
	boss_changed.emit(true)
	banner.emit(B.name.to_upper(), "has awakened", Color(B.color))
	Sfx.play("boss_roar")
	add_shake(0.6)


func _pick_type(m: float) -> String:
	var opts := [["wisp", maxf(2, 10 - m * 0.8)], ["bat", 5.0 if m >= 0.75 else 0.0], ["spitter", 2.5 if m >= 2 else 0.0],
		["brute", 2 + m * 0.25 if m >= 3 else 0.0], ["splitter", 3.0 if m >= 4 else 0.0], ["ghoul", 2 + (m - 7) * 0.6 if m >= 7 else 0.0]]
	var total := 0.0
	for o in opts:
		total += o[1]
	var r := randf() * total
	for o in opts:
		r -= o[1]
		if r <= 0:
			return o[0]
	return "wisp"


func _ring_spawn(type: String, n: int, msg: String) -> void:
	for i in n:
		var a := float(i) / n * TAU
		spawn_enemy(type, ppos + Vector2(cos(a), sin(a)) * SPAWN_R * 0.8)
	toast.emit(msg, Color("ff7b9a"))


func _director(dt: float) -> void:
	var m := time / 60.0
	for b in Data.BOSS_SCHEDULE:
		if time >= b[0] and not boss_done.has(b[0]):
			boss_done[b[0]] = true
			spawn_boss(b[1], b[2])
	for ev in Data.EVENTS:
		if time >= ev[0] and not ev_done.has(ev[0]):
			ev_done[ev[0]] = true
			_ring_spawn(ev[1], ev[2], ev[3])
	if endless:
		var k := int((time - Data.DAWN_TIME) / 120.0)
		if k >= 1 and not boss_done.has("e%d" % k) and bosses.size() < 3:
			boss_done["e%d" % k] = true
			spawn_boss(["warden", "choir", "king"].pick_random(), 1.0 + k * 0.5)
	elite_t -= dt
	if elite_t <= 0:
		elite_t = maxf(35.0, 70.0 - m * 3)
		spawn_enemy(_pick_type(m), null, true)
	var target := minf(MAX_ENEMIES, 22 + time * 0.75)
	var rate := minf(45.0, 1.6 + time / 12.0) * (0.6 if bosses.size() > 0 else 1.0)
	spawn_acc += rate * dt
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if enemies.size() < target:
			spawn_enemy(_pick_type(m), null, randf() < 0.004)


# ================================================================= combat
func hurt_enemy(e: Enemy, base: float, kdir: Vector2, kb: float, w: Weapon) -> void:
	if e.dead:
		return
	var dmg: float = base * P.might
	if P.light_bonus > 1.0 and e.pos.distance_squared_to(ppos) < pow(P.light * 0.6, 2):
		dmg *= P.light_bonus
	var crit: bool = randf() < 0.05 * P.luck
	if crit:
		dmg *= 2.0
	dmg *= randf_range(0.92, 1.08)
	e.hp -= dmg
	if e.flash_cd <= 0.0:
		e.flash = 0.07
		e.flash_cd = 0.3 if e.boss else 0.15
	if w:
		w.dmg_total += minf(dmg, dmg + e.hp)
	if kb > 0 and not e.boss:
		e.kb += kdir * kb * (1.0 - e.heavy)
	if Save.setting("dmg_nums"):
		_damage_number(e, dmg, crit)
	Sfx.play("hit")
	if e.hp <= 0:
		kill_enemy(e)


func aoe(p: Vector2, r: float, dmg: float, kb: float, color: Color, w: Weapon) -> void:
	for e in query(p, r):
		var d: Vector2 = e.pos - p
		hurt_enemy(e, dmg, d.normalized() if d.length() > 0.01 else Vector2.RIGHT, kb, w)
	fx_ring(p, r, color)


func kill_enemy(e: Enemy) -> void:
	e.dead = true
	kills += 1
	var col := Color(Data.BOSSES[e.type].color) if e.boss else Color(Data.ENEMIES[e.type].color)
	burst(e.pos, 1.0, col, 3.0 if e.boss else (1.0 if e.elite else 0.3))
	if e.boss:
		Sfx.play("explode")
		add_shake(1.0)
		fx_light(e.pos, col, 8.0, 0.8)
		drop_gem(e.pos, e.xp)
		spawn_pickup("chest", e.pos)
		for i in 12:
			spawn_pickup("coin", e.pos + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
		Save.data.totals.bosses += 1
		Save.unlock("ACH_BOSS")
		if e.is_king and not won:
			won = true
			victory_t = 2.8
			Save.data.totals.wins += 1
			Save.unlock("ACH_DAWN")
			banner.emit("DAWN BREAKS", "The Hollow King has fallen", Color("ffd166"))
			Sfx.play("victory")
			for o in enemies:
				if not o.boss and not o.dead:
					o.dead = true
		else:
			banner.emit("BOSS DEFEATED", e.bname, Color("ffd166"))
		return
	Sfx.play("kill")
	drop_gem(e.pos, e.xp)
	if e.elite:
		spawn_pickup("chest", e.pos)
	if Data.ENEMIES[e.type].get("splits", false):
		for i in 2:
			spawn_enemy("mite", e.pos + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)))
	var L: float = P.luck
	var r := randf()
	if r < 0.022 * L:
		spawn_pickup("coin", e.pos)
	elif r < 0.022 * L + 0.0035:
		spawn_pickup("heart", e.pos)
	elif r < 0.022 * L + 0.0048:
		spawn_pickup("magnet", e.pos)
	elif r < 0.022 * L + 0.0058:
		spawn_pickup("bomb", e.pos)


func damage_player(raw: float, src := "?") -> void:
	if iframe > 0 or over or dying > 0 or (won and victory_t > 0):
		return
	var d := maxf(1.0, raw - P.armor)
	if has_meta("bot"):
		var lg: Dictionary = get_meta("dmglog", {})
		lg[src] = lg.get(src, 0.0) + d
		set_meta("dmglog", lg)
	P.hp -= d
	iframe = 0.6
	hurt = 1.0
	took_damage = true
	add_shake(0.35)
	Sfx.play("hurt")
	if P.hp <= 0:
		if P.revives > 0:
			P.revives -= 1
			P.hp = P.max_hp * 0.6
			iframe = 2.5
			nuke(true)
			banner.emit("SECOND FLAME", "You rise again", Color("ffb347"))
			Sfx.play("revive")
		else:
			P.hp = 0
			dying = 1.6
			Sfx.play("death")
			burst(ppos, 1.2, Color("ffb347"), 3.0)
			add_shake(0.8)


func nuke(include_elites: bool) -> void:
	for e in enemies:
		if e.dead or e.boss:
			continue
		if e.pos.distance_to(ppos) < 20.0 and (include_elites or not e.elite):
			kill_enemy(e)
	for b in bullets:
		b.life = 0
	fx_ring(ppos, 18.0, Color("fff3b0"))
	fx_light(ppos, Color("fff3b0"), 16.0, 0.8)
	Sfx.play("explode")
	add_shake(0.8)


func add_shake(v: float) -> void:
	if Save.setting("shake"):
		shake = maxf(shake, v)


# ================================================================= weapons
func _weapon_update(w: Weapon, dt: float) -> void:
	var L := w.lvl
	match w.id:
		"bolt":
			w.cd -= dt
			if w.cd > 0:
				return
			var n := 1 + int(L >= 3) + int(L >= 5) + int(P.amount)
			var tg := nearest(ppos, n, 15.0)
			if tg.is_empty():
				w.cd = 0.1
				return
			w.cd = (0.62 if L >= 6 else 0.95) * P.cd
			var dmg := 10.0 + (5.0 if L >= 2 else 0.0) + (10.0 if L >= 6 else 0.0)
			for i in n:
				var e: Enemy = tg[i % tg.size()]
				var a := (e.pos - ppos).angle()
				if i >= tg.size():
					a += (i - tg.size() + 1) * 0.2 * (1 if i % 2 else -1)
				_proj("bolt", w, ppos, a, 17.0, 0.32 * sqrt(P.area), dmg, 1 + int(L >= 4), 1.3, e)
			Sfx.play("shoot")
		"halo":
			var n: int = [2, 3, 3, 4, 4, 6][L - 1] + int(P.amount)
			var dmg: float = [8, 8, 11, 11, 15, 15][L - 1]
			var rad: float = [2.2, 2.2, 2.2, 2.5, 2.5, 2.5][L - 1] * P.area
			var spin: float = [2.6, 2.6, 2.6, 2.6, 3.6, 3.6][L - 1]
			var orb_r := 0.4 * sqrt(P.area)
			w.ang += spin * dt
			w.orbs.resize(n)
			for i in n:
				var a := w.ang + float(i) / n * TAU
				var op := ppos + Vector2(cos(a), sin(a)) * rad
				w.orbs[i] = op
				for e in query(op, orb_r):
					if float(e.hit_cd.get("halo", -1.0)) > time:
						continue
					e.hit_cd["halo"] = time + 0.45
					hurt_enemy(e, dmg, (e.pos - ppos).normalized(), 4.2, w)
		"pulse":
			var rad: float = [3.0, 3.45, 3.45, 3.45, 3.95, 3.95][L - 1] * P.area
			var dmg: float = [15, 15, 23, 23, 31, 31][L - 1]
			if w.second > 0:
				w.second -= dt
				if w.second <= 0:
					aoe(ppos, rad, dmg, 9.0, Color("ff6bd6"), w)
					Sfx.play("pulse")
			w.cd -= dt
			if w.cd > 0:
				return
			if nearest(ppos, 1, rad).is_empty():
				w.cd = 0.2
				return
			w.cd = (2.55 if L >= 4 else 3.0) * P.cd
			aoe(ppos, rad, dmg, 9.0, Color("ff6bd6"), w)
			fx_light(ppos, Color("ff6bd6"), 5.0, 0.35)
			Sfx.play("pulse")
			if L >= 6:
				w.second = 0.3
		"arc":
			w.cd -= dt
			if w.cd > 0:
				return
			var chains: int = [3, 4, 4, 6, 6, 8][L - 1] + int(P.amount) * 2
			var dmg: float = [14, 14, 20, 20, 20, 28][L - 1]
			var first := nearest(ppos, 1, 13.0)
			if first.is_empty():
				w.cd = 0.15
				return
			w.cd = (1.2 if L >= 5 else 1.5) * P.cd
			var hit := {}
			var pts: Array = [Vector3(ppos.x, 1.4, ppos.y)]
			var cur: Enemy = first[0]
			for i in chains:
				if cur == null:
					break
				hit[cur.id] = true
				pts.append(Vector3(cur.pos.x, 0.8, cur.pos.y))
				var cp := cur.pos
				hurt_enemy(cur, dmg, Vector2.ZERO, 0.0, w)
				var best: Enemy = null
				var bd := 1e12
				for e in query(cp, 5.0 * P.area):
					if hit.has(e.id) or e.dead:
						continue
					var dd := cp.distance_squared_to(e.pos)
					if dd < bd:
						bd = dd
						best = e
				cur = best
			fx_lightning(pts)
			Sfx.play("zap")
		"scythe":
			w.cd -= dt
			if w.cd > 0:
				return
			var n: int = [1, 1, 2, 2, 3, 3][L - 1] + int(P.amount)
			var dmg: float = [18, 26, 26, 26, 34, 46][L - 1]
			var size := (1.25 if L >= 4 else 1.0) * sqrt(P.area)
			w.cd = (1.3 if L >= 6 else 1.7) * P.cd
			var tg := nearest(ppos, 1, 13.0)
			var base: float = (tg[0].pos - ppos).angle() + randf_range(-0.25, 0.25) if not tg.is_empty() else pface.angle()
			for i in n:
				var p := _proj("scythe", w, ppos, base + (i - (n - 1) / 2.0) * 0.55, 17.0, 0.65 * size, dmg, 9999, 3.0, null)
				p.node.scale = Vector3.ONE * size
			Sfx.play("whoosh")
		"mines":
			w.cd -= dt
			if w.cd > 0:
				return
			var n: int = [1, 1, 2, 2, 2, 3][L - 1] + int(P.amount)
			w.cd = (1.76 if L >= 5 else 2.2) * P.cd
			var active := 0
			for p in projs:
				if p.kind == "mine":
					active += 1
			if active >= 8 + L * 2:
				return
			for i in n:
				var a := randf() * TAU
				var at := ppos + Vector2(cos(a), sin(a)) * randf_range(0.6, 3.3)
				var p := _proj("mine", w, at, 0, 0, 0.3, [22, 30, 30, 30, 30, 45][L - 1], 1, 6.0, null)
				p.arm = 0.45
				p.blast = (2.4 if L >= 3 else 2.0) * P.area
		"frost":
			w.cd -= dt
			if w.cd > 0:
				return
			if nearest(ppos, 1, 14.0).is_empty():
				w.cd = 0.15
				return
			var n: int = [6, 8, 8, 8, 12, 12][L - 1] + int(P.amount) * 2
			var dmg: float = [12, 12, 18, 18, 18, 28][L - 1]
			w.cd = (1.6 if L >= 6 else 2.0) * P.cd
			w.rot += 0.35
			for i in n:
				_proj("frost", w, ppos, w.rot + float(i) / n * TAU, 12.5, 0.24 * sqrt(P.area), dmg, 4 if L >= 4 else 3, 1.0, null)
			Sfx.play("freeze")


func _proj(kind: String, w: Weapon, at: Vector2, a: float, speed: float, r: float, dmg: float, pierce: int, life: float, home: Enemy) -> Proj:
	var p := Proj.new()
	p.kind = kind
	p.w = w
	p.pos = at
	p.speed = speed
	p.vel = Vector2(cos(a), sin(a)) * speed
	p.r = r
	p.dmg = dmg
	p.pierce = pierce
	p.life = life
	p.home = home
	p.node = _pool_get(kind)
	p.node.scale = Vector3.ONE
	projs.append(p)
	return p


func _update_projs(dt: float) -> void:
	for p in projs:
		if p.dead:
			continue
		p.t += dt
		p.life -= dt
		if p.life <= 0:
			if p.kind == "mine":
				_explode_mine(p)
			p.dead = true
			continue
		match p.kind:
			"bolt":
				if p.home and not p.home.dead:
					var want := (p.home.pos - p.pos).angle()
					var cur := p.vel.angle()
					var da := wrapf(want - cur, -PI, PI)
					var na := cur + clampf(da, -6 * dt, 6 * dt)
					p.vel = Vector2(cos(na), sin(na)) * p.speed
			"scythe":
				p.rot += dt * 16
				p.speed -= 27.0 * dt
				if p.speed >= 0:
					p.vel = p.vel.normalized() * p.speed
				else:
					var d := ppos - p.pos
					p.vel = d.normalized() * minf(22.0, -p.speed + 4.5)
					if d.length() < 0.7:
						p.dead = true
						continue
			"mine":
				p.arm -= dt
				if p.arm <= 0 and not query(p.pos, 0.9).is_empty():
					_explode_mine(p)
					p.dead = true
				continue
		p.pos += p.vel * dt
		for e in query(p.pos, p.r):
			if p.kind == "scythe":
				var last = p.hit.get(e.id)
				if last != null and time - float(last) < 0.4:
					continue
				p.hit[e.id] = time
				hurt_enemy(e, p.dmg, p.vel.normalized(), 2.7, p.w)
				continue
			if p.hit.has(e.id):
				continue
			p.hit[e.id] = true
			hurt_enemy(e, p.dmg, p.vel.normalized(), 3.6 if p.kind == "bolt" else 1.8, p.w)
			if p.kind == "frost":
				e.slow = 1.6
			p.pierce -= 1
			if p.pierce <= 0:
				p.dead = true
				break


func _explode_mine(p: Proj) -> void:
	aoe(p.pos, p.blast, p.dmg, 8.0, Color("9dff5c"), p.w)
	burst(p.pos, 0.6, Color("c6ff7a"), 1.0)
	fx_light(p.pos, Color("9dff5c"), 6.0, 0.3)
	Sfx.play("explode", 1.0, -6.0)
	add_shake(0.12)


# ================================================================= enemies
func _update_enemies(dt: float) -> void:
	for e in enemies:
		if e.dead:
			continue
		e.t += dt
		e.spawn_t = minf(1.0, e.spawn_t + dt * 2.5)
		if e.flash > 0:
			e.flash -= dt
		if e.flash_cd > 0:
			e.flash_cd -= dt
		if e.slow > 0:
			e.slow -= dt
		var to := ppos - e.pos
		var dist := maxf(0.001, to.length())
		var d := to / dist
		var sp := e.speed * (0.5 if e.slow > 0 and not e.boss else 1.0)
		var mv := d
		if e.boss:
			_boss_ai(e, dt, d, dist)
			mv = e.mv
			sp = e.cur_speed
		else:
			var T: Dictionary = Data.ENEMIES[e.type]
			if T.get("erratic", false):
				var wv := sin(e.t * 5 + e.id) * 0.8
				mv = d + Vector2(-d.y, d.x) * wv
			if T.get("ranged", false):
				if dist < 6.5:
					mv = -d
					sp *= 0.6
				elif dist < 9.5:
					mv = Vector2(-d.y, d.x) * e.dir
					sp *= 0.55
				e.shoot_t = maxf(0.0, e.shoot_t - dt)
				if e.shoot_t <= 0 and dist < 13.0:
					e.shoot_t = randf_range(2.4, 3.4)
					fire_bullet(e.pos, d.angle(), 5.5, e.dmg)
		if mv.length_squared() > 0.0001:
			mv = mv.normalized()
			e.facing = lerp_angle(e.facing, atan2(-mv.x, -mv.y), minf(1.0, dt * 10))
		e.pos += (mv * sp + e.kb) * dt
		e.kb *= exp(-dt * 9.0)
		if not e.boss:
			_separate(e)
			if dist > RECYCLE_R:
				e.pos = _spawn_point()
		elif dist > RECYCLE_R * 0.85 and e.state != "dash":
			e.pos = _spawn_point(0.7)
			burst(e.pos, 1.0, Color(Data.BOSSES[e.type].color), 2.0)
		if dist < e.r + 0.4:
			damage_player(e.dmg, e.type + ("_dash" if e.state == "dash" else ""))


func _separate(e: Enemy) -> void:
	var arr = grid.get(_key(e.pos.x, e.pos.y))
	if arr == null:
		return
	var n := 0
	for o in arr:
		if o == e or o.dead:
			continue
		var dv: Vector2 = e.pos - o.pos
		var r: float = e.r + o.r
		var dd := dv.length_squared()
		if dd < r * r and dd > 0.0001:
			var dl := sqrt(dd)
			e.pos += dv / dl * (r - dl) * 0.25
			n += 1
			if n > 5:
				break


func _boss_ai(e: Enemy, dt: float, d: Vector2, dist: float) -> void:
	var B: Dictionary = Data.BOSSES[e.type]
	e.mv = d
	e.cur_speed = e.speed
	var enraged := e.hp < e.max_hp * 0.5
	if e.state == "prep":
		e.cur_speed = 0
		e.st_t -= dt
		e.dash = d
		if e.st_t <= 0:
			e.state = "dash"
			e.st_t = 0.55
			Sfx.play("dash")
		return
	if e.state == "dash":
		e.mv = e.dash
		e.cur_speed = 19.0 if enraged else 16.0
		e.st_t -= dt
		if e.st_t <= 0:
			e.state = ""
		return
	if e.spiral > 0:
		e.spiral -= dt
		e.cur_speed = e.speed * 0.3
		e.sp_t -= dt
		if e.sp_t <= 0:
			e.sp_t = 0.09
			e.sp_a += 0.45
			var k := 3 if enraged else 2
			for i in k:
				fire_bullet(e.pos, e.sp_a + i * TAU / k, 5.0, e.dmg * 0.35)
	e.atk -= dt
	if e.atk <= 0:
		var mvname: String = B.moves.pick_random()
		match mvname:
			"dash":
				e.state = "prep"
				e.st_t = 0.75
				e.atk = 3.2
			"ring":
				var n := 26 if e.is_king else 18
				var off := randf() * TAU
				for i in n:
					fire_bullet(e.pos, off + float(i) / n * TAU, 4.6, e.dmg * 0.4)
				if enraged:
					for i in n:
						fire_bullet(e.pos, off + (i + 0.5) / n * TAU, 3.4, e.dmg * 0.4)
				e.atk = 2.6
				Sfx.play("boss_shot")
			"summon":
				for i in mini(10, MAX_ENEMIES - enemies.size()):
					var a := float(i) / 10 * TAU
					spawn_enemy("ghoul" if e.is_king else "bat", e.pos + Vector2(cos(a), sin(a)) * 2.6)
				e.atk = 3.0
				burst(e.pos, 1.0, Color(B.color), 2.0)
			"spiral":
				e.spiral = 2.2
				e.atk = 3.6
		if enraged:
			e.atk *= 0.7


func fire_bullet(at: Vector2, a: float, speed: float, dmg: float) -> void:
	var b := Bullet.new()
	b.pos = at
	b.vel = Vector2(cos(a), sin(a)) * speed
	b.dmg = dmg
	b.node = _pool_get("bullet")
	bullets.append(b)


func _update_bullets(dt: float) -> void:
	var keep: Array[Bullet] = []
	for b in bullets:
		b.life -= dt
		b.pos += b.vel * dt
		if b.life > 0 and b.pos.distance_squared_to(ppos) < 0.36:
			damage_player(b.dmg, "bullet")
			b.life = 0
			burst(b.pos, 0.4, Color("ff4dd2"), 0.4)
		if b.life > 0:
			keep.append(b)
		else:
			_pool_put(b.node)
	bullets = keep


# ================================================================= pickups
func drop_gem(at: Vector2, v: float) -> void:
	if gems.size() >= MAX_GEMS - 10:
		gems[randi() % gems.size()][1] += v
		return
	gems.append([at, v, false, 0.0])


func spawn_pickup(kind: String, at: Vector2) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.pos = at
	p.t = randf() * 6
	p.v = randi_range(1, 3) if kind == "coin" else 0
	var model: String = {"coin": "coin", "chest": "chest", "heart": "heart", "magnet": "magnet", "bomb": "orb"}[kind]
	p.node = _pool_get(model)
	pickups.append(p)


func add_xp(v: float) -> void:
	P.xp += v
	while P.xp >= P.xp_next:
		P.xp -= P.xp_next
		P.level += 1
		P.xp_next = xp_for(P.level)
		pending_levels += 1


func _update_gems(dt: float) -> void:
	var m2: float = P.magnet * P.magnet
	var keep := []
	for g in gems:
		var d2: float = g[0].distance_squared_to(ppos)
		if not g[2] and d2 < m2:
			g[2] = true
		if g[2]:
			g[3] = minf(26.0, g[3] + 40.0 * dt)
			var dd := sqrt(d2)
			if dd < 0.6:
				add_xp(g[1] * P.growth)
				Sfx.play("gem")
				continue
			g[0] += (ppos - g[0]) / maxf(dd, 0.001) * minf(g[3] * dt, dd)
		keep.append(g)
	gems = keep


func _update_pickups(dt: float) -> void:
	var m2: float = pow(P.magnet * 0.8, 2)
	var far2 := pow(RECYCLE_R * 1.5, 2)
	for p in pickups:
		p.t += dt
		var d2 := p.pos.distance_squared_to(ppos)
		if d2 > far2 and p.kind != "chest":
			# Left far behind: bank coins, drop the rest, so long Endless runs don't pile up nodes.
			p.dead = true
			if p.kind == "coin":
				coins += maxi(1, int(round(p.v * P.greed)))
			continue
		if not p.mag and d2 < m2:
			p.mag = true
		if p.mag:
			p.sp = minf(24.0, p.sp + 36.0 * dt)
			var dd := sqrt(d2)
			p.pos += (ppos - p.pos) / maxf(dd, 0.001) * minf(p.sp * dt, dd)
			if dd < 0.7:
				p.dead = true
				_collect(p)
	var keep: Array[Pickup] = []
	for p in pickups:
		if p.dead:
			_pool_put(p.node)
		else:
			keep.append(p)
	pickups = keep


func _collect(p: Pickup) -> void:
	match p.kind:
		"coin":
			coins += maxi(1, int(round(p.v * P.greed)))
			Sfx.play("coin")
		"heart":
			P.hp = minf(P.max_hp, P.hp + maxf(30.0, P.max_hp * 0.3))
			Sfx.play("pickup")
			toast.emit("+HP", Color("ff5d73"))
		"magnet":
			for g in gems:
				g[2] = true
			Sfx.play("pickup")
			toast.emit("Lodestar!", Color("6ec6ff"))
		"bomb":
			nuke(false)
			toast.emit("Flashbang!", Color("fff3b0"))
		"chest":
			_open_chest()
	burst(p.pos, 0.5, Color("ffd166"), 0.5)


func upgradables() -> Array:
	var out := []
	for w in weapons:
		if w.lvl < Data.WEAPONS[w.id].max:
			out.append({"type": "w", "id": w.id})
	for id in passives:
		if passives[id] < Data.PASSIVES[id].max:
			out.append({"type": "p", "id": id})
	return out


func _open_chest() -> void:
	var n := 3 if randf() < 0.1 * P.luck else 1
	var got := []
	for i in n:
		var opts := upgradables()
		if opts.is_empty():
			break
		var o: Dictionary = opts.pick_random()
		apply_choice(o)
		var lvl: int = _weapon(o.id).lvl if o.type == "w" else passives[o.id]
		got.append("%s Lv%d" % [Data.item_def(o.id).name, lvl])
	var c := int(round(randi_range(10, 25) * P.greed))
	coins += c
	got.append("+%d Embers" % c)
	banner.emit("BLESSED TREASURE!" if n == 3 else "TREASURE!", "  ·  ".join(got), Color("ffd166"))
	Sfx.play("chest")
	burst(ppos, 1.0, Color("ffd166"), 2.0)
	fx_light(ppos, Color("ffd166"), 8.0, 0.6)


func _weapon(id: String) -> Weapon:
	for w in weapons:
		if w.id == id:
			return w
	return null


# ================================================================= level up
func build_choices() -> Array:
	var pool := []
	for w in weapons:
		if w.lvl < Data.WEAPONS[w.id].max:
			pool.append({"type": "w", "id": w.id, "weight": 3.0})
	if weapons.size() < 6:
		for id in Data.WEAPONS:
			if _weapon(id) == null:
				pool.append({"type": "w", "id": id, "weight": 1.8})
	for id in passives:
		if passives[id] < Data.PASSIVES[id].max:
			pool.append({"type": "p", "id": id, "weight": 2.4})
	if passives.size() < 6:
		for id in Data.PASSIVES:
			if not passives.has(id):
				pool.append({"type": "p", "id": id, "weight": 1.3})
	var n := 4 if randf() < 0.08 * P.luck + (P.luck - 1.0) * 0.3 else 3
	var out := []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += c.weight
		var r := randf() * total
		for c in pool:
			r -= c.weight
			if r <= 0:
				out.append(c)
				pool.erase(c)
				break
	return out


func apply_choice(c: Dictionary) -> void:
	if c.type == "w":
		var w := _weapon(c.id)
		if w:
			w.lvl += 1
		else:
			add_weapon(c.id)
		for x in weapons:
			if x.lvl >= Data.WEAPONS[x.id].max:
				Save.unlock("ACH_MAX_WEAPON")
		if weapons.size() >= 6:
			Save.unlock("ACH_ARSENAL")
	elif c.type == "p":
		passives[c.id] = int(passives.get(c.id, 0)) + 1
		if not passive_order.has(c.id):
			passive_order.append(c.id)
		recalc_stats()


func _offer_level() -> void:
	choices = build_choices()
	if choices.is_empty():
		# Build is complete: pay out instead of interrupting play.
		var n := pending_levels
		pending_levels = 0
		var c := int(round(5 * n * P.greed))
		coins += c
		P.hp = minf(P.max_hp, P.hp + P.max_hp * 0.1 * n)
		toast.emit("MAX POWER  +%d Embers" % c, Color("ffd166"))
		return
	level_up_ready.emit()


func choose(i: int) -> bool:
	## Returns true when more level-ups are pending.
	if i >= 0 and i < choices.size():
		apply_choice(choices[i])
	pending_levels -= 1
	if pending_levels > 0:
		choices = build_choices()
		return not choices.is_empty()
	return false


func reroll() -> void:
	if P.rerolls > 0:
		P.rerolls -= 1
		choices = build_choices()


# ================================================================= end
func end_run(reason: String) -> void:
	if over:
		return
	over = true
	var bonus := int(floor((floor(time / 10.0) + floor(kills / 25.0) + (400 if won else 0)) * P.greed))
	var total := coins + bonus
	set_meta("earned", total)
	Save.add_coins(total)
	check_achievements()  # before totals absorb this run's kills, or ACH_KILLS_TOTAL counts them twice
	var t: Dictionary = Save.data.totals
	t.kills += kills
	t.runs += 1
	t.time += time
	var b: Dictionary = Save.data.best
	b.time = maxf(b.time, time)
	b.kills = maxi(int(b.kills), kills)
	b.level = maxi(int(b.level), int(P.level))
	Save.unlock("ACH_FIRST_NIGHT")
	if Save.data.coins >= 2000:
		Save.unlock("ACH_RICH")
	Save.persist()
	run_finished.emit(reason)


func check_achievements() -> void:
	if time >= 300: Save.unlock("ACH_SURVIVE_5")
	if time >= 600: Save.unlock("ACH_SURVIVE_10")
	if time >= 1200: Save.unlock("ACH_ENDLESS_20")
	if time >= 180 and not took_damage: Save.unlock("ACH_NO_HIT_3")
	if kills >= 1000: Save.unlock("ACH_KILLS_1000")
	if P.level >= 30: Save.unlock("ACH_LEVEL_30")
	if int(Save.data.totals.kills) + kills >= 10000: Save.unlock("ACH_KILLS_TOTAL")


# ================================================================= world props
func _update_chunks(force := false) -> void:
	var c := Vector2i(floori(ppos.x / CHUNK), floori(ppos.y / CHUNK))
	if not force and has_meta("chunk") and get_meta("chunk") == c:
		return
	set_meta("chunk", c)
	var want := {}
	for x in range(c.x - CHUNK_RANGE, c.x + CHUNK_RANGE + 1):
		for y in range(c.y - CHUNK_RANGE, c.y + CHUNK_RANGE + 1):
			want[Vector2i(x, y)] = true
	for k in chunks.keys():
		if not want.has(k):
			chunks[k].queue_free()
			chunks.erase(k)
			colliders.erase(k)
	for k in want:
		if not chunks.has(k):
			_make_chunk(k)


func _make_chunk(k: Vector2i) -> void:
	var root := Node3D.new()
	add_child(root)
	chunks[k] = root
	var cols := []
	var r := RandomNumberGenerator.new()
	r.seed = hash(k) + 1337
	var origin := Vector2(k.x * CHUNK, k.y * CHUNK)
	var safe := k == Vector2i(0, 0) or k == Vector2i(-1, 0) or k == Vector2i(0, -1) or k == Vector2i(-1, -1)
	var n := r.randi_range(2, 6)
	var table := [["tree_dead_a", 14, 0.5], ["tree_dead_b", 12, 0.5], ["tree_pine_a", 6, 0.9], ["tree_pine_b", 5, 0.9],
		["grave_a", 10, 0.45], ["grave_b", 8, 0.35], ["grave_c", 8, 0.4], ["rock_a", 8, 0.8], ["rock_b", 6, 0.6],
		["mushrooms", 8, 0.0], ["ruins", 3, 0.9], ["fence", 4, 0.0], ["candles", 4, 0.0]]
	var total := 0
	for t in table:
		total += t[1]
	for i in n:
		var pick := r.randi_range(0, total - 1)
		var choice: Array = table[0]
		for t in table:
			pick -= t[1]
			if pick < 0:
				choice = t
				break
		var at := origin + Vector2(r.randf_range(1, CHUNK - 1), r.randf_range(1, CHUNK - 1))
		if safe and at.length() < 5.0:
			continue
		if not scenes.has(choice[0]):
			continue
		var node: Node3D = scenes[choice[0]].instantiate()
		node.position = Vector3(at.x, 0, at.y)
		node.rotation.y = r.randf() * TAU
		var s := r.randf_range(0.85, 1.25)
		node.scale = Vector3(s, s, s)
		root.add_child(node)
		if choice[2] > 0:
			cols.append([at, choice[2] * s])
		if choice[0] == "candles":
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.65, 0.3)
			l.light_energy = 1.6
			l.omni_range = 4.5
			l.position = Vector3(0, 0.6, 0)
			node.add_child(l)
		if choice[0].begins_with("grave") and r.randf() < 0.5:
			# graves come in small clusters
			for j in r.randi_range(1, 2):
				var g: Node3D = scenes[["grave_a", "grave_b", "grave_c"].pick_random()].instantiate()
				var off := Vector2(r.randf_range(1.2, 2.2) * (1 if r.randf() < 0.5 else -1), r.randf_range(-0.5, 0.5))
				g.position = node.position + Vector3(off.x, 0, off.y)
				g.rotation.y = node.rotation.y + r.randf_range(-0.3, 0.3)
				root.add_child(g)
				cols.append([at + off, 0.4])
	# grass
	if scenes.has("grass"):
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _first_mesh(scenes["grass"])
		var count := 70 if quality >= 1 else 25
		mm.instance_count = count
		for i in count:
			var p := origin + Vector2(r.randf() * CHUNK, r.randf() * CHUNK)
			var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.7, 1.4))
			mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, 0, p.y)))
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	colliders[k] = cols


func _resolve_props() -> void:
	var c := Vector2i(floori(ppos.x / CHUNK), floori(ppos.y / CHUNK))
	for x in range(c.x - 1, c.x + 2):
		for y in range(c.y - 1, c.y + 2):
			for col in colliders.get(Vector2i(x, y), []):
				var d: Vector2 = ppos - col[0]
				var r: float = col[1] + 0.35
				var l := d.length()
				if l < r and l > 0.0001:
					ppos = col[0] + d / l * r


# ================================================================= effects
func burst(at: Vector2, height: float, color: Color, amount: float) -> void:
	var gp: GPUParticles3D = particle_pool[particle_next]
	particle_next = (particle_next + 1) % particle_pool.size()
	gp.position = Vector3(at.x, height, at.y)
	var pm: ParticleProcessMaterial = gp.process_material
	pm.color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5)
	gp.amount_ratio = clampf(amount, 0.1, 1.0)
	var s := clampf(amount, 1.0, 3.0)
	pm.initial_velocity_max = 4.0 * s
	gp.restart()
	gp.emitting = true


func fx_ring(at: Vector2, radius: float, color: Color) -> void:
	for f in fx_rings:
		if f[1] <= 0:
			var n: MeshInstance3D = f[0]
			n.visible = true
			n.position = Vector3(at.x, 0.15, at.y)
			n.scale = Vector3(radius, 1, radius)
			n.set_instance_shader_parameter("tint", color)
			n.set_instance_shader_parameter("progress", 0.0)
			f[1] = 0.4
			f[2] = 0.4
			return


func fx_light(at: Vector2, color: Color, energy: float, life: float) -> void:
	for f in fx_lights:
		if f[1] <= 0:
			var l: OmniLight3D = f[0]
			l.visible = true
			l.light_color = color
			l.position = Vector3(at.x, 1.5, at.y)
			l.omni_range = 4.0 + energy * 0.6
			f[1] = life
			f[2] = life
			f[3] = energy * 0.5
			return


func fx_lightning(pts: Array) -> void:
	var jag := [pts[0]]
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		for s in range(1, 4):
			var t := s / 4.0
			jag.append(a.lerp(b, t) + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3)))
		jag.append(b)
	var j := 0
	for i in range(1, jag.size()):
		while j < fx_segs.size() and fx_segs[j][1] > 0:
			j += 1
		if j >= fx_segs.size():
			return
		var a: Vector3 = jag[i - 1]
		var b: Vector3 = jag[i]
		var s: MeshInstance3D = fx_segs[j][0]
		s.visible = true
		var mid := (a + b) / 2
		s.position = mid
		if a.distance_to(b) > 0.01:
			s.look_at_from_position(mid, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
		s.scale = Vector3(1, 1, a.distance_to(b))
		fx_segs[j][1] = 0.16
	var p1: Vector3 = pts[1]
	fx_light(Vector2(p1.x, p1.z), Color("7fd8ff"), 3.0, 0.15)


func _damage_number(e: Enemy, dmg: float, crit: bool) -> void:
	var l := labels[label_next]
	label_next = (label_next + 1) % labels.size()
	l.visible = true
	l.text = str(maxi(1, int(round(dmg))))
	l.modulate = Color(1.0, 0.82, 0.3) if crit else Color(1, 1, 1)
	l.font_size = 84 if crit else 60
	var h := 2.2 if e.boss else 1.3
	l.position = Vector3(e.pos.x + randf_range(-0.3, 0.3), h, e.pos.y)
	l.set_meta("life", 0.65)


# ================================================================= visuals
func sync_visuals(dt: float) -> void:
	_update_chunks()
	# player
	var t := time
	var target_rot := atan2(-pface.x, -pface.y)
	player_node.rotation.y = lerp_angle(player_node.rotation.y, target_rot, minf(1.0, dt * 12))
	var bob := absf(sin(t * 9.0)) * 0.06 if pmoving else sin(t * 2.0) * 0.015
	player_node.position = Vector3(ppos.x, bob, ppos.y)
	player_node.rotation.x = lerpf(player_node.rotation.x, -0.08 if pmoving else 0.0, dt * 8)
	player_node.visible = dying <= 0 and not (iframe > 0 and int(t * 20) % 2 == 0)
	if lantern_node:
		lantern_node.rotation.x = sin(t * (7.0 if pmoving else 2.0)) * (0.25 if pmoving else 0.06)
		lantern_node.rotation.z = sin(t * 3.1) * 0.05
	var flick := 1.0 + sin(t * 9.0) * 0.04 + sin(t * 23.0) * 0.03
	lantern_light.light_energy = (6.0 if not won or endless else 3.0) * flick
	# camera
	cam_target = cam_target.lerp(Vector3(ppos.x, 0, ppos.y), minf(1.0, dt * 6))
	var shk := Vector3.ZERO
	if shake > 0:
		shk = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.4
		shake = maxf(0, shake - dt * 2.5)
	cam.position = cam_target + Vector3(0, 13, 9.5) + shk
	cam.look_at(cam_target + Vector3(0, 0.5, 0) + shk * 0.5)
	ground.position = Vector3(snappedf(ppos.x, 10), 0, snappedf(ppos.y, 10))
	hurt = maxf(0, hurt - dt * 2.2)
	if won and not endless:
		moon.light_energy = lerpf(moon.light_energy, 1.2, dt * 0.5)
		moon.light_color = moon.light_color.lerp(Color(1.0, 0.75, 0.55), dt * 0.5)
		env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.9, dt * 0.5)
	# enemies
	for e in enemies:
		if e.dead or e.node == null:
			continue
		var n := e.node
		var h := 0.0
		var T: Dictionary = Data.ENEMIES.get(e.type, {})
		match e.type:
			"wisp", "choir":
				h = 0.15 + sin(e.t * 3.0) * 0.12
			"bat":
				h = 0.9 + sin(e.t * 6.0) * 0.12
				if e.parts.WingL:
					e.parts.WingL.rotation.z = sin(e.t * 20.0) * 0.8
					e.parts.WingR.rotation.z = -sin(e.t * 20.0) * 0.8
			"brute", "warden":
				h = absf(sin(e.t * 5.0)) * 0.08
				n.rotation.z = sin(e.t * 5.0) * 0.07
			"splitter", "mite":
				h = absf(sin(e.t * 7.0)) * 0.12
			"ghoul":
				h = absf(sin(e.t * 6.0)) * 0.06
			"king":
				h = 0.1 + sin(e.t * 1.5) * 0.1
		n.position = Vector3(e.pos.x, h, e.pos.y)
		n.rotation.y = e.facing
		var base := 1.45 if e.elite else 1.0
		var sc := base * (ease(e.spawn_t, 0.4) if e.spawn_t < 1.0 else 1.0)
		if e.type == "spitter":
			sc *= 1.0 + clampf(0.4 - e.shoot_t, 0.0, 0.4) * 0.6
		n.scale = Vector3.ONE * maxf(0.01, sc)
		var want := 1 if e.flash > 0 else (3 if e.slow > 0 and not e.boss else (2 if e.elite else 0))
		if want != e.overlay:
			e.overlay = want
			var mat: Material = [null, flash_mat, elite_mat, slow_mat][want]
			for mi in e.meshes:
				(mi as MeshInstance3D).material_overlay = mat
		if e.boss and e.state == "prep":
			if not e.has_meta("tele"):
				pass
	_sync_telegraphs()
	# projectiles
	for p in projs:
		if p.node == null:
			continue
		match p.kind:
			"bolt":
				p.node.position = Vector3(p.pos.x, 1.0, p.pos.y)
			"frost":
				p.node.position = Vector3(p.pos.x, 0.9, p.pos.y)
				p.node.rotation = Vector3(-PI / 2, atan2(-p.vel.x, -p.vel.y), 0)
			"scythe":
				p.node.position = Vector3(p.pos.x, 0.9, p.pos.y)
				p.node.rotation = Vector3(0, -p.rot, 0)
			"mine":
				p.node.position = Vector3(p.pos.x, 0.15, p.pos.y)
				var blink := 1.0 + (0.15 * sin(p.t * 14.0) if p.arm <= 0 else 0.0)
				p.node.scale = Vector3.ONE * blink * (minf(1.0, p.t * 4.0))
	for b in bullets:
		b.node.position = Vector3(b.pos.x, 0.8, b.pos.y)
	# halo orbs
	for w in weapons:
		if w.id != "halo":
			continue
		while w.orb_nodes.size() < w.orbs.size():
			w.orb_nodes.append(_pool_get("orb"))
		for i in w.orb_nodes.size():
			var on: Node3D = w.orb_nodes[i]
			if i < w.orbs.size():
				on.visible = true
				on.position = Vector3(w.orbs[i].x, 1.0, w.orbs[i].y)
			else:
				on.visible = false
	# gems
	var mm := gem_mm.multimesh
	var cnt := mini(gems.size(), MAX_GEMS)
	mm.visible_instance_count = cnt
	for i in cnt:
		var g: Array = gems[i]
		var v: float = g[1]
		var col := Color(0.35, 1.5, 1.7) if v < 5 else (Color(0.4, 1.8, 0.6) if v < 25 else Color(2.0, 0.35, 0.5))
		var s := 1.3 if v < 5 else (1.7 if v < 25 else 2.2)
		var bas := Basis(Vector3.UP, t * 2.0 + i).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(bas, Vector3(g[0].x, 0.35 + sin(t * 4.0 + i) * 0.08, g[0].y)))
		mm.set_instance_color(i, col)
	# pickups
	for p in pickups:
		if p.node == null:
			continue
		p.node.position = Vector3(p.pos.x, 0.3 + sin(p.t * 3.0) * 0.1 if p.kind != "chest" else 0.0, p.pos.y)
		if p.kind != "chest":
			p.node.rotation.y = p.t * 2.0
	# fx
	for f in fx_rings:
		if f[1] > 0:
			f[1] -= dt
			var n: MeshInstance3D = f[0]
			n.set_instance_shader_parameter("progress", clampf(1.0 - f[1] / f[2], 0, 1))
			if f[1] <= 0:
				n.visible = false
	for f in fx_lights:
		if f[1] > 0:
			f[1] -= dt
			var l: OmniLight3D = f[0]
			l.light_energy = f[3] * maxf(0, f[1] / f[2])
			if f[1] <= 0:
				l.visible = false
	for f in fx_segs:
		if f[1] > 0:
			f[1] -= dt
			if f[1] <= 0:
				f[0].visible = false
	for l in labels:
		var life: float = l.get_meta("life")
		if life > 0:
			life -= dt
			l.set_meta("life", life)
			l.position.y += dt * 1.4
			l.modulate.a = clampf(life / 0.3, 0, 1)
			if life <= 0:
				l.visible = false


var tele_nodes := {}
func _sync_telegraphs() -> void:
	for e in bosses:
		var tn: Node3D = tele_nodes.get(e.id)
		if e.state == "prep" and not e.dead:
			if tn == null:
				tn = _pool_get("tele")
				tele_nodes[e.id] = tn
			var len := 9.5
			var dir := e.dash
			var mid := e.pos + dir * len / 2
			tn.position = Vector3(mid.x, 0.08, mid.y)
			tn.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
			tn.scale = Vector3(e.r * 1.8, 1, len)
			tele_mat.albedo_color.a = 0.25 + sin(time * 30.0) * 0.12
		elif tn != null:
			_pool_put(tn)
			tele_nodes.erase(e.id)
	# A boss killed mid wind-up has already left `bosses`; release its strip too.
	if not tele_nodes.is_empty():
		var live := {}
		for e in bosses:
			live[e.id] = true
		for id in tele_nodes.keys():
			if not live.has(id):
				_pool_put(tele_nodes[id])
				tele_nodes.erase(id)


func _menu_anim(delta: float) -> void:
	menu_t += delta
	var t := menu_t
	player_node.position = Vector3(0, sin(t * 2.0) * 0.015, 0)
	player_node.rotation.y = lerp_angle(player_node.rotation.y, 2.45, delta * 3)
	if lantern_node:
		lantern_node.rotation.x = sin(t * 1.6) * 0.08
	lantern_light.light_energy = 5.0 * (1.0 + sin(t * 9.0) * 0.04 + sin(t * 23.0) * 0.03)
	var a := t * 0.05
	cam.position = Vector3(sin(a) * 2.0 - 2.4, 2.6, 6.2 + cos(a) * 0.4)
	cam.look_at(Vector3(-1.9, 1.15, 0))
	# drifting wisps at the edge of the light
	if not has_meta("menu_wisps"):
		var arr := []
		for i in 6:
			var w := _pool_get("wisp" if i % 3 else "bat")
			arr.append(w)
		set_meta("menu_wisps", arr)
	var ws: Array = get_meta("menu_wisps")
	for i in ws.size():
		var w: Node3D = ws[i]
		var ang := t * 0.12 + i * 1.05
		var rr := 9.0 + sin(t * 0.3 + i) * 1.5
		w.position = Vector3(cos(ang) * rr, 0.3 + sin(t * 2.0 + i) * 0.2 + (0.8 if i % 3 == 0 else 0.0), sin(ang) * rr - 3.0)
		w.rotation.y = atan2(-(-w.position.x), -(-w.position.z))


# ================================================================= test bot
func _bot_move() -> Vector2:
	var mv := Vector2(cos(time * 0.25), sin(time * 0.25)) * 0.3
	for e in enemies:
		var dv := ppos - e.pos
		var R := 3.2 + e.r * 2.0
		var d2 := dv.length_squared()
		if d2 < R * R:
			var d := sqrt(d2)
			mv += dv / maxf(d, 0.01) * (R - d) / R * 2.5
	for b in bullets:
		var dv := ppos - b.pos
		if dv.length_squared() < 5.0:
			mv += dv.normalized() * 1.5
	var best = null
	var bd := 144.0
	for g in gems:
		var d: float = g[0].distance_squared_to(ppos)
		if d < bd:
			bd = d
			best = g[0]
	for p in pickups:
		var d := p.pos.distance_squared_to(ppos)
		if d < bd:
			bd = d
			best = p.pos
	if best != null:
		mv += (best - ppos).normalized() * 0.8
	return mv.normalized() if mv.length() > 0.05 else Vector2.ZERO
