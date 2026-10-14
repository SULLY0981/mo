extends Node
## Game flow: menu <-> run, pausing, and the automated test mode.

var world: World
var ui: UI
var autotest := false
var shots_dir := ""
var shot_times: Array = []
var test_log_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps Esc/Start/F11 working while paused; World stays PAUSABLE
	_setup_input()
	ui = UI.new()
	ui.main = self
	add_child(ui)
	Save.achievement_unlocked.connect(ui.on_achievement)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--autotest" or a.begins_with("--trailer=") or a.begins_with("--menushots="):
			Save.set_meta("no_persist", true)
	for a in args:
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
	for a in args:
		if a.begins_with("--trailer="):
			_trailer(float(a.substr(10)), "--char=" in " ".join(args))
			return
		if a.begins_with("--menushots="):
			_menu_shots(a.substr(12))
			return
	if autotest:
		Save.data = Save._defaults()
		var c := "keeper"
		for a in args:
			if a.begins_with("--char="):
				c = a.substr(7)
		start_run(c)
		world.set_meta("bot", true)
		if "--god" in args:
			world.set_meta("god", true)
	else:
		go_menu()


func _setup_input() -> void:
	var defs := {
		"move_left": [KEY_A, KEY_LEFT, [JOY_AXIS_LEFT_X, -1.0], JOY_BUTTON_DPAD_LEFT],
		"move_right": [KEY_D, KEY_RIGHT, [JOY_AXIS_LEFT_X, 1.0], JOY_BUTTON_DPAD_RIGHT],
		"move_up": [KEY_W, KEY_UP, [JOY_AXIS_LEFT_Y, -1.0], JOY_BUTTON_DPAD_UP],
		"move_down": [KEY_S, KEY_DOWN, [JOY_AXIS_LEFT_Y, 1.0], JOY_BUTTON_DPAD_DOWN],
		"pause": [KEY_ESCAPE, KEY_P, JOY_BUTTON_START],
		"reroll": [KEY_R, JOY_BUTTON_X],
	}
	for action in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for d in defs[action]:
			var ev: InputEvent
			if d is Array:
				ev = InputEventJoypadMotion.new()
				ev.axis = d[0]
				ev.axis_value = d[1]
			elif d is int and d < 32:
				ev = InputEventJoypadButton.new()
				ev.button_index = d
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = d
			InputMap.action_add_event(action, ev)


func _new_world() -> void:
	if world:
		remove_child(world)
		world.queue_free()
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	move_child(world, 0)


func go_menu() -> void:
	get_tree().paused = false
	_new_world()
	world.setup_menu(str(Save.data.last_char))
	ui.show_menu()
	Sfx.music("menu")


func preview_char(c: String) -> void:
	if world and world.mode == "menu":
		world._tint_player(c)


func start_run(c: String) -> void:
	Save.data.last_char = c
	Save.persist()
	get_tree().paused = false
	_new_world()
	world.level_up_ready.connect(_on_level_up)
	world.run_finished.connect(_on_run_finished)
	world.victory_ready.connect(_on_victory)
	world.banner.connect(ui.banner)
	world.toast.connect(ui.toast)
	world.boss_changed.connect(func(active): Sfx.music("boss" if active else "battle"))
	ui.show_hud(world)  # before start_run, which emits the opening toast
	world.start_run(c)
	Sfx.music("battle")


func _on_level_up() -> void:
	if autotest:
		while world.pending_levels > 0:
			if not world.choose(_bot_pick()):
				break
		return
	get_tree().paused = true
	Sfx.play("levelup")
	ui.show_level()


func level_choice_done(more: bool) -> void:
	if more:
		ui.show_level()
	elif world.won and world.victory_t <= 0 and not world.endless and not world.over:
		ui.show_victory()  # a level-up landed on the same frame as the victory screen
	else:
		ui.hide_overlays()
		get_tree().paused = false


func _on_victory() -> void:
	if autotest:
		print("AUTOTEST VICTORY at %.0f" % world.time)
		world.end_run("victory")
		return
	get_tree().paused = true
	ui.show_victory()


func continue_endless() -> void:
	world.endless = true
	ui.hide_overlays()
	get_tree().paused = false
	ui.banner("THE ENDLESS NIGHT", "How long can your light last?", Color("b38cff"))


func _on_run_finished(reason: String) -> void:
	if autotest:
		_print_summary(reason)
		get_tree().quit()
		return
	get_tree().paused = true
	ui.show_over(reason)


func toggle_pause() -> void:
	if world == null or world.mode != "run" or world.over:
		return
	if ui.current == "pause":
		ui.hide_overlays()
		get_tree().paused = false
	elif ui.current == "":
		get_tree().paused = true
		ui.show_pause()


func abandon() -> void:
	get_tree().paused = false
	world.end_run("abandon")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not autotest:
		if world and world.mode == "run" and ui.current == "" and not world.over:
			toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if world and world.mode == "run" and ui.current in ["", "pause"]:
			toggle_pause()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F11:
		Save.set_setting("fullscreen", not Save.setting("fullscreen"))


# ---------------------------------------------------------------- autotest
func _process(_delta: float) -> void:
	if not autotest or world == null or world.over or get_tree().paused:
		return
	var steps := 12 if shots_dir != "" else 30
	if shots_dir == "trailer":
		var dt := minf(_delta, 1.0 / 30.0)
		world.step(dt)
		if world.P.hp < world.P.max_hp * 0.5:
			world.P.hp = world.P.max_hp
		world.sync_visuals(dt)
		test_log_t += 1
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--snap=") and int(test_log_t) == 150:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(a.substr(7))
				print("SNAP ", a.substr(7))
				get_tree().quit()
		return
	if shots_dir != "":
		for st in [6.0, 75.0, 186.0, 380.0, 545.0]:
			if world.time >= st and not world.has_meta("shot%d" % st):
				world.set_meta("shot%d" % st, true)
				world.sync_visuals(1.0 / 60.0)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/play_%03d.png" % [shots_dir, int(st)])
				print("SHOT ", st)
				if st >= 545.0:
					get_tree().quit()
				return
	for i in steps:
		world.step(1.0 / 60.0)
		if world.has_meta("god") and world.P.hp < 30:
			world.P.hp = world.P.max_hp
		if world.over:
			return
	world.sync_visuals(1.0 / 60.0)
	if world.time - test_log_t >= 60.0:
		test_log_t = world.time
		var bs := []
		for b in world.bosses:
			bs.append("%s:%d" % [b.type, int(b.hp)])
		print("t=%d lvl=%d kills=%d enemies=%d hp=%d/%d bosses=%s fps=%d" % [world.time, world.P.level, world.kills, world.enemies.size(), world.P.hp, world.P.max_hp, ",".join(bs), Engine.get_frames_per_second()])
	if world.time > 16 * 60:
		world.end_run("timeout")


func _print_summary(reason: String) -> void:
	var ws := []
	for w in world.weapons:
		ws.append("%s%d:%d" % [w.id, w.lvl, int(w.dmg_total)])
	print("AUTOTEST END reason=%s t=%d lvl=%d kills=%d won=%s coins=%d weapons=%s passives=%s dmg=%s" % [reason, world.time, world.P.level, world.kills, world.won, world.coins, " ".join(ws), world.passives, world.get_meta("dmglog", {})])


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("SHOT ", name)


func _menu_shots(dir: String) -> void:
	Save.data = Save._defaults()
	Save.data.coins = 1250
	Save.data.ach = {"ACH_SURVIVE_5": 1, "ACH_BOSS": 1, "ACH_FIRST_NIGHT": 1}
	go_menu()
	await get_tree().create_timer(4.0).timeout
	await _shot(dir, "menu")
	ui.show_chars()
	await get_tree().create_timer(2.0).timeout
	await _shot(dir, "chars")
	ui.show_shop()
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "shop")
	ui.show_ach()
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "ach")
	start_run("warden")
	world.set_meta("bot", true)
	while ui.current != "level":
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "levelup")
	level_choice_done(world.choose(0))
	ui.show_pause()
	get_tree().paused = true
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "pause")
	get_tree().quit()


func _trailer(at: float, has_char: bool) -> void:
	## Fast-forwards a bot run to `at` seconds, then plays in real time for recording (use with --write-movie).
	Save.data = Save._defaults()
	for ach in Data.ACHIEVEMENTS:
		Save.data.ach[ach.id] = 1  # no popups in recorded footage
	var c := "keeper"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--char="):
			c = a.substr(7)
	start_run(c)
	world.set_meta("bot", true)
	world.set_meta("god", true)
	autotest = true
	shots_dir = "trailer"
	while world.time < at:
		world.step(1.0 / 60.0)
		while world.pending_levels > 0:
			world.choices = world.build_choices()
			if world.choices.is_empty() or not world.choose(_bot_pick()):
				break
		if world.P.hp < 30:
			world.P.hp = world.P.max_hp
	world.cam_target = Vector3(world.ppos.x, 0, world.ppos.y)
	world.hurt = 0.0
	world.P.hp = world.P.max_hp
	ui.clear_messages()
	for e in world.enemies:
		e.spawn_t = 1.0


func _bot_pick() -> int:
	## Test bot: favour upgrading owned weapons, then new weapons, then relics.
	var best := 0
	var best_score := -1.0
	for i in world.choices.size():
		var c: Dictionary = world.choices[i]
		var score := randf()
		if c.type == "w":
			score += 2.0 if world._weapon(c.id) else 1.0
		if score > best_score:
			best_score = score
			best = i
	return best
