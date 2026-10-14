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
		if a.begins_with("--lang="):
			Loc.apply(a.substr(7))
			ui.apply_fonts()
			ui._build_ach_toast()
	for a in args:
		if a.begins_with("--trailer="):
			go_menu()
			_trailer(float(a.substr(10)), "--char=" in " ".join(args))
			return
		if a.begins_with("--menushots="):
			_menu_shots(a.substr(12))
			return
		if a.begins_with("--mapshots="):
			_map_shots(a.substr(11))
			return
		if a.begins_with("--cards="):
			_cards(a.substr(8))
			return
		if a.begins_with("--bestiary="):
			_bestiary_shot(a.substr(11))
			return
		if a.begins_with("--dlgshots="):
			_dialogue_shots(a.substr(11))
			return
	if autotest:
		Save.data = Save._defaults()
		var c := "keeper"
		for a in args:
			if a.begins_with("--char="):
				c = a.substr(7)
			elif a.begins_with("--night="):
				Save.data.night = int(a.substr(8))
				Save.data.nights_won = 5
		if "--daily" in args:
			start_daily()
		else:
			start_run(c)
		world.set_meta("bot", true)
		if "--god" in args:
			world.set_meta("god", true)
	else:
		go_menu()


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


func start_daily() -> void:
	var d := Data.daily_info()
	start_run(d.char, d)


func start_run(c: String, daily := {}) -> void:
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
	world.story.connect(_on_story)
	world.tip.connect(ui.on_tip)
	ui.show_hud(world)  # before start_run, which emits the opening toast
	var n := 1 if not daily.is_empty() else mini(int(Save.data.get("night", 1)), int(Save.data.get("nights_won", 0)) + 1)
	world.start_run(c, n, daily)
	if Controls.p2_device >= 0 and not autotest:
		world.add_coop_player(ui.p2_char, Controls.p2_device)
	elif autotest and "--coop" in OS.get_cmdline_user_args():
		world.add_coop_player("warden", -1)
	Sfx.music("battle")


func _on_story(id: String) -> void:
	## Picks a full conversation (first time, pauses) or a one-line remark (never pauses).
	if autotest or shots_dir != "":
		return
	if id == "start":
		var lines: Array = Data.KEEPER_LINES.get(world.char_id, [])
		if not lines.is_empty():
			ui.bark("self", lines.pick_random())
		return
	var seen: Array = Save.data.seen_dialogue
	if Data.DIALOGUE.has(id) and not seen.has(id) and Save.setting("dialogue"):
		seen.append(id)
		Save.persist()
		get_tree().paused = true
		ui.dialogue(Data.DIALOGUE[id], func():
			if ui.current == "":
				get_tree().paused = false)
		return
	if Data.BARKS.has(id):
		var b: Array = Data.BARKS[id].pick_random()
		ui.bark(b[0], b[1])


func _on_level_up() -> void:
	if autotest:
		while world.pending_levels > 0:
			if not world.choose(_bot_pick()):
				break
		return
	if ui.dialogue_active:
		ui.after_dialogue.append(_on_level_up)  # don't stack a level-up on top of a conversation
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
	if world.has_meta("demo_end"):
		ui.show_demo_end()
		return
	if world.night >= Data.NIGHTS.size() and not Save.data.get("seen_true_ending", false):
		Save.data.seen_true_ending = true
		Save.data.seen_ending = true
		Save.persist()
		ui.show_story(Data.ENDING_TRUE, "The Longest Night", func(): ui.show_victory())
	elif not Save.data.get("seen_ending", false):
		Save.data.seen_ending = true
		Save.persist()
		ui.show_story(Data.ENDING, "Dawn Breaks", func(): ui.show_victory())
	else:
		ui.show_victory()


func continue_endless() -> void:
	world.endless = true
	ui.hide_overlays()
	get_tree().paused = false
	ui.banner(tr("The Endless Night").to_upper(), tr("How long can your light last?"), Color("b38cff"))


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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not autotest and Save.setting("autopause"):
		if world and world.mode == "run" and ui.current == "" and not world.over:
			toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	# Player 2's Start pauses too (their pad isn't in the shared input map).
	if event is InputEventJoypadButton and event.pressed and event.device == Controls.p2_device and event.button_index == JOY_BUTTON_START:
		if world and world.mode == "run" and ui.current in ["", "pause"]:
			toggle_pause()
			get_viewport().set_input_as_handled()
			return
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
		if "--perf" in OS.get_cmdline_user_args() and int(test_log_t) % 60 == 0:
			print("PERF t=%.0f fps=%d enemies=%d projs=%d bullets=%d gems=%d pickups=%d draw_calls=%d" % [world.time, Engine.get_frames_per_second(),
				world.enemies.size(), world.projs.size(), world.bullets.size(), world.gems.size(), world.pickups.size(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
			if int(test_log_t) >= 60 * 20:
				get_tree().quit()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--snap=") and int(test_log_t) == 150:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(a.substr(7))
				print("SNAP ", a.substr(7))
				get_tree().quit()
		return
	if shots_dir != "":
		if world.shrine_prog > 0.6 and not world.has_meta("shot_shrine"):
			world.set_meta("shot_shrine", true)
			world.sync_visuals(1.0 / 60.0)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/shrine.png" % shots_dir)
			return
		for st in [6.0, 75.0, 186.0, 380.0, 545.0, 640.0]:
			if world.time >= st and not world.has_meta("shot%d" % st):
				world.set_meta("shot%d" % st, true)
				world.sync_visuals(1.0 / 60.0)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/play_%03d.png" % [shots_dir, int(st)])
				print("SHOT ", st)
				if st >= 640.0:
					get_tree().quit()
				return
	for i in steps:
		world.step(1.0 / 60.0)
		if "--coopdown" in OS.get_cmdline_user_args():
			for pair in [[20.0, 0], [90.0, 1]]:
				if world.time > pair[0] and not world.has_meta("downed%d" % pair[1]):
					world.set_meta("downed%d" % pair[1], true)
					world.iframe = 0
					world.players[pair[1]].iframe = 0
					world._hurt_player(pair[1], 99999.0, "test")
					print("FORCED DOWN p%d at %.0f all_down=%s dying=%.2f" % [pair[1] + 1, world.time, world._all_down(), world.dying])
		if world.has_meta("god"):
			for ps in world.players:
				var PP: Dictionary = world.P if ps == world.players[world.ci] else ps.P
				if PP.hp < 30:
					PP.hp = PP.max_hp
		if world.over:
			return
	world.sync_visuals(1.0 / 60.0)
	if world.time - test_log_t >= 60.0:
		test_log_t = world.time
		var bs := []
		for b in world.bosses:
			bs.append("%s:%d" % [b.type, int(b.hp)])
		print("t=%d lvl=%d kills=%d enemies=%d hp=%d/%d bosses=%s fps=%d" % [world.time, world.P.level, world.kills, world.enemies.size(), world.P.hp, world.P.max_hp, ",".join(bs), Engine.get_frames_per_second()] + ("  players=" + str(range(world.players.size()).map(func(i): return "%s:%d%s" % [world.player_info(i).char, int(world.player_info(i).P.hp), "D" if world.player_down(i) else ""])) if world.coop() else ""))
	if world.time > 16 * 60:
		world.end_run("timeout")


func _print_summary(reason: String) -> void:
	var ws := []
	for w in world.weapons:
		ws.append("%s%d%s:%d" % [w.id, w.lvl, "*" if w.awake else "", int(w.dmg_total)])
	print("AUTOTEST END reason=%s t=%d lvl=%d kills=%d won=%s coins=%d weapons=%s passives=%s dmg=%s" % [reason, world.time, world.P.level, world.kills, world.won, world.coins, " ".join(ws), world.passives, world.get_meta("dmglog", {})])
	print("AUTOTEST MAP shrines_lit=%d pumpkins=%d memories=%d" % [Save.data.totals.shrines, Save.data.totals.pumpkins, Save.data.memories.size()])


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("SHOT ", name)


func _menu_shots(dir: String) -> void:
	Save.data = Save._defaults()
	Save.data.coins = 1250
	Save.data.ach = {"ACH_SURVIVE_5": 1, "ACH_BOSS": 1, "ACH_FIRST_NIGHT": 1}
	Save.data.settings.autopause = false
	Save.data.memories = [0, 1, 2, 3]
	go_menu()
	await get_tree().create_timer(4.0).timeout
	await _shot(dir, "menu")
	ui.show_story(Data.INTRO, "", func(): pass)
	await get_tree().create_timer(9.0).timeout
	await _shot(dir, "intro")
	ui.show_journal()
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "journal")
	ui.show_daily()
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "daily")
	for tab in ["General", "Controls"]:
		ui.show_settings("menu", tab)
		await get_tree().create_timer(1.0).timeout
		await _shot(dir, "settings_" + tab.to_lower())
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


func _map_shots(dir: String) -> void:
	## Visits each region (and a shrine) with enemies cleared, for checking the map and for store shots.
	Save.data = Save._defaults()
	Save.data.settings.autopause = false
	for ach in Data.ACHIEVEMENTS:
		Save.data.ach[ach.id] = 1
	start_run("keeper")
	world.set_meta("god", true)
	await get_tree().create_timer(1.0).timeout
	for reg in [1, 2, 3, 0]:
		var spot := Vector2.ZERO
		for i in 4000:
			var p := Vector2(randf_range(-600, 600), randf_range(-600, 600))
			if p.length() > 60 and world.region_at(p) == reg and world.region_at(p + Vector2(10, 0)) == reg and world.region_at(p + Vector2(0, 10)) == reg:
				spot = p
				break
		world.ppos = spot
		world.cam_target = Vector3(spot.x, 0, spot.y)
		for e in world.enemies:
			e.dead = true
		world._cleanup()
		world.sync_visuals(0.016)
		if reg == 0:
			var sh: Dictionary = world._make_shrine()
			sh.node.position = Vector3(spot.x + 2.5, 0, spot.y - 1.5)
			world.add_child(sh.node)
			sh.flame.scale = Vector3.ONE
			sh.light.light_color = Color(1.0, 0.7, 0.35); sh.light.light_energy = 3.0; sh.light.omni_range = 9.0
			world.spawn_pickup("pumpkin", spot + Vector2(-2.2, 1.0))
		await get_tree().create_timer(2.5).timeout
		await _shot(dir, "region_%d" % reg)
	get_tree().quit()


func _cards(dir: String) -> void:
	## Renders the trailer's title cards with the game's own fonts.
	var bg := TextureRect.new()
	bg.texture = load("res://assets/icon.png")  # replaced below if the store art is available
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://store/page_background_1438x810.png"))
	if img:
		bg.texture = ImageTexture.create_from_image(img)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.modulate = Color(0.5, 0.5, 0.55)
	ui.root.add_child(bg)
	var logo := TextureRect.new()
	var limg := Image.load_from_file(ProjectSettings.globalize_path("res://store/logo.png"))
	if limg:
		logo.texture = ImageTexture.create_from_image(limg)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ui._place(logo, 0.5, 0.5, -560, -330, 1120, 460)
	ui.root.add_child(logo)
	var line := ui._label("", 50, ui.f_body, Color("e9dcff"), HORIZONTAL_ALIGNMENT_CENTER)
	ui._place(line, 0.5, 0.5, -900, 170, 1800, 80)
	line.label_settings.outline_size = 8
	ui.root.add_child(line)
	var sub := ui._label("", 34, ui.f_bold, Color("ffd166"), HORIZONTAL_ALIGNMENT_CENTER)
	ui._place(sub, 0.5, 0.5, -900, 250, 1800, 60)
	sub.label_settings.outline_size = 6
	ui.root.add_child(sub)
	var cards := [["t0", "The night is endless. Your light is not.", ""],
		["t1", "Rekindle the shrines. Remember the fallen.", ""],
		["t2", "Bring a friend.", "2-player co-op  ·  Remote Play Together"],
		["t9", "Wishlist now on Steam", "Coming Halloween season"]]
	for c in cards:
		line.text = tr(c[1])
		sub.text = c[2]
		await get_tree().create_timer(0.4).timeout
		await _shot(dir, c[0])
	get_tree().quit()


func _bestiary_shot(dir: String) -> void:
	Save.data = Save._defaults()
	Save.data.settings.autopause = false
	Save.data.settings.dialogue = false
	start_run("keeper")
	world.set_meta("god", true)
	await get_tree().create_timer(0.5).timeout
	world.spawn_boss("witch", 1.0)
	world.bosses[0].pos = world.ppos + Vector2(-3.5, -2.5)
	for i in 3:
		var sc: World.Enemy = world.spawn_enemy("scarecrow", world.ppos + Vector2(3.0 + i * 1.6, -1.5 + i * 0.8))
		sc.spawn_t = 1.0
	world.spawn_enemy("gourd", world.ppos + Vector2(1.5, 3.0)).spawn_t = 1.0
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = true
	await get_tree().create_timer(0.3).timeout
	await _shot(dir, "bestiary")
	get_tree().quit()


func _dialogue_shots(dir: String) -> void:
	Save.data = Save._defaults()
	Save.data.settings.autopause = false
	for ach in Data.ACHIEVEMENTS:
		Save.data.ach[ach.id] = 1
	start_run("reaper")
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = true
	ui.dialogue(Data.DIALOGUE.boss_king)
	await get_tree().create_timer(1.5).timeout
	await _shot(dir, "dlg_king")
	ui._dialogue_advance()
	await get_tree().create_timer(1.5).timeout
	await _shot(dir, "dlg_self")
	while ui.dialogue_active:
		ui.dlg_text.visible_ratio = 1.0
		ui._dialogue_advance()
	get_tree().paused = false
	ui.bark("spirit", Data.BARKS.shrine[0][1])
	await get_tree().create_timer(1.5).timeout
	await _shot(dir, "dlg_spirit")
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
	autotest = true  # set before start_run so --coop adds the bot partner
	start_run(c)
	world.set_meta("bot", true)
	world.set_meta("god", true)
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
