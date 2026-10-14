extends Node
## Sound effect pool and music player with crossfades.

const SFX_NAMES := ["shoot", "hit", "kill", "gem", "coin", "pickup", "levelup", "chest", "hurt", "pulse", "explode", "zap",
	"freeze", "whoosh", "boss_roar", "boss_shot", "dash", "achievement", "click", "hover", "buy", "deny", "death", "victory", "revive"]
const GAPS := {"hit": 0.045, "kill": 0.035, "shoot": 0.06, "gem": 0.03, "zap": 0.07, "explode": 0.06, "pulse": 0.08, "coin": 0.04,
	"hurt": 0.12, "hover": 0.03, "freeze": 0.08, "boss_shot": 0.1, "whoosh": 0.08}
const VOL := {"hit": -9.0, "kill": -8.0, "shoot": -10.0, "gem": -11.0, "zap": -7.0, "hover": -12.0, "coin": -6.0, "whoosh": -8.0, "freeze": -6.0}

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var last := {}
var gem_combo := 0
var gem_t := 0.0
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var current_music := ""
var music_in: AudioStreamPlayer
var music_tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for n in SFX_NAMES:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	music_a = AudioStreamPlayer.new(); music_a.bus = "Music"; add_child(music_a)
	music_b = AudioStreamPlayer.new(); music_b.bus = "Music"; add_child(music_b)
	Save.apply_settings()


func play(n: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not streams.has(n):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = GAPS.get(n, 0.0)
	if gap > 0.0 and now - float(last.get(n, -10.0)) < gap:
		return
	last[n] = now
	if n == "gem":
		if now - gem_t > 0.45:
			gem_combo = 0
		gem_t = now
		gem_combo = mini(gem_combo + 1, 24)
		pitch = pow(2.0, gem_combo / 24.0)
	var p := players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = streams[n]
	p.pitch_scale = pitch * randf_range(0.96, 1.04) if n in ["hit", "kill", "shoot", "zap", "whoosh"] else pitch
	p.volume_db = VOL.get(n, 0.0) + vol_db
	p.play()


func music(n: String) -> void:
	if n == current_music:
		return
	current_music = n
	var stream: AudioStream = load("res://assets/audio/music_%s.ogg" % n)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	# Fade out whichever player was last faded in; the old tween would otherwise stop the new track.
	if music_tw:
		music_tw.kill()
	var out := music_in if music_in else music_a
	var inn := music_b if out == music_a else music_a
	music_in = inn
	inn.stream = stream
	inn.volume_db = -40.0
	inn.play()
	var tw := create_tween().set_parallel(true)
	music_tw = tw
	tw.tween_property(inn, "volume_db", 0.0, 1.5)
	if out.playing:
		tw.tween_property(out, "volume_db", -40.0, 1.5)
		tw.chain().tween_callback(out.stop)
