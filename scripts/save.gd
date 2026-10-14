extends Node
## Persistent progress, settings, achievements and the optional Steam bridge.

signal achievement_unlocked(id: String)
signal coins_changed

const PATH := "user://save.json"

var data := {}
var steam: Object = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep Steam callbacks pumping on paused screens
	data = _defaults()
	_load()
	_init_steam()
	apply_settings()


func _defaults() -> Dictionary:
	return {
		"coins": 0, "shop": {}, "ach": {},
		"best": {"time": 0.0, "kills": 0, "level": 0},
		"totals": {"kills": 0, "runs": 0, "bosses": 0, "wins": 0, "time": 0.0},
		"settings": {"sfx": 0.8, "music": 0.6, "shake": true, "dmg_nums": true, "fullscreen": true, "quality": 2, "vsync": true},
		"last_char": "keeper",
	}


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else null


func _load() -> void:
	var parsed = _read(PATH)
	if parsed == null:
		parsed = _read(PATH + ".bak")  # main file missing or torn by a crash mid-write
	if parsed == null:
		return
	for k in data.keys():
		if not parsed.has(k):
			continue
		if typeof(data[k]) == TYPE_DICTIONARY and typeof(parsed[k]) == TYPE_DICTIONARY:
			data[k].merge(parsed[k], true)
		else:
			data[k] = parsed[k]
	if not Data.CHARS.has(str(data.last_char)):
		data.last_char = "keeper"  # unknown id would crash the menu on every boot


func persist() -> void:
	if has_meta("no_persist"):
		return  # test/recording modes must never touch the player's save
	# Write to a temp file, then swap it in, keeping the previous save as .bak.
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(PATH):
		DirAccess.rename_absolute(PATH, PATH + ".bak")
	DirAccess.rename_absolute(tmp, PATH)


func setting(key: String):
	return data.settings[key]


func set_setting(key: String, value) -> void:
	data.settings[key] = value
	persist()
	apply_settings()


func apply_settings() -> void:
	var s: Dictionary = data.settings
	if OS.has_feature("editor") == false and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if s.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if s.vsync else DisplayServer.VSYNC_DISABLED)
	_set_bus("Music", s.music)
	_set_bus("SFX", s.sfx)


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


func shop_level(id: String) -> int:
	return int(data.shop.get(id, 0))


func add_coins(n: int) -> void:
	data.coins = int(data.coins) + n
	coins_changed.emit()


# ---------------------------------------------------------------- achievements
func has_ach(id: String) -> bool:
	return data.ach.has(id)


func unlock(id: String) -> void:
	if has_ach(id):
		return
	data.ach[id] = Time.get_unix_time_from_system()
	persist()
	if steam:
		steam.call("setAchievement", id)
		steam.call("storeStats")
	achievement_unlocked.emit(id)
	if id != "ACH_ALL_CHARS":
		var all := true
		for c in Data.CHAR_ORDER:
			if not is_char_unlocked(c):
				all = false
		if all:
			unlock("ACH_ALL_CHARS")


func is_char_unlocked(c: String) -> bool:
	var req: String = Data.CHARS[c].get("unlock", "")
	return req == "" or has_ach(req)


# ---------------------------------------------------------------- steam
func _init_steam() -> void:
	# Works when the GodotSteam GDExtension is installed (see README). Silently skipped otherwise.
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	var res = steam.call("steamInitEx", false)
	if typeof(res) == TYPE_DICTIONARY and int(res.get("status", 1)) != 0:
		push_warning("Steam init failed: %s" % res)
		steam = null
		return
	# Re-sync achievements earned while offline.
	for id in data.ach.keys():
		steam.call("setAchievement", id)
	steam.call("storeStats")


func _process(_d: float) -> void:
	if steam:
		steam.call("run_callbacks")
