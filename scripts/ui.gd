extends CanvasLayer
class_name UI
## All menus, the HUD and overlays. Built in code with a shared theme.

const AMBER := Color("ffb347")
const GOLD := Color("ffd166")
const TEXT := Color("f3e9ff")
const MUTED := Color("a99bc4")
const PANEL := Color(0.075, 0.055, 0.12, 0.9)
const LINE := Color(0.25, 0.18, 0.36)

var main
var current := ""
var root: Control
var th: Theme
var f_title: Font
var f_head: Font
var f_body: Font
var f_bold: Font
var screens := {}
var hud: Control
var world: World

# HUD widgets
var xp_bar: ProgressBar
var lvl_label: Label
var time_label: Label
var sub_label: Label
var kills_label: Label
var coins_label: Label
var weapon_row: HBoxContainer
var passive_row: HBoxContainer
var boss_box: VBoxContainer
var toast_box: VBoxContainer
var banner_box: Control
var banner_title: Label
var banner_sub: Label
var vignette: ColorRect
var hp_bar: ProgressBar
var dash_bar: ProgressBar
var dash_hint: Label
var fps_label: Label
var near_label: Label
var buff_label: Label
var hint_label: Label
var ach_panel: PanelContainer
var ach_queue: Array = []
var ach_busy := false
var build_sig := ""
var card_lock := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	f_title = load("res://assets/fonts/CinzelDecorative-Black.woff2")
	f_head = load("res://assets/fonts/Cinzel-Bold.woff2")
	f_body = load("res://assets/fonts/AlegreyaSans-Medium.woff2")
	f_bold = load("res://assets/fonts/AlegreyaSans-ExtraBold.woff2")
	apply_fonts()
	_build_theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = th
	add_child(root)
	_build_hud()
	_build_ach_toast()


# ================================================================= fonts
const CJK_FONTS := {
	"zh_CN": ["Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "Microsoft YaHei", "PingFang SC", "WenQuanYi Micro Hei", "Droid Sans Fallback"],
	"zh_TW": ["Noto Sans CJK TC", "Noto Sans TC", "Source Han Sans TC", "Microsoft JhengHei", "PingFang TC"],
	"ja": ["Noto Sans CJK JP", "Noto Sans JP", "Source Han Sans JP", "Yu Gothic UI", "Yu Gothic", "Meiryo", "Hiragino Sans"],
	"ko": ["Noto Sans CJK KR", "Noto Sans KR", "Source Han Sans KR", "Malgun Gothic", "Apple SD Gothic Neo"],
}


func apply_fonts() -> void:
	## Cinzel is Latin-only; Alegreya adds Cyrillic/Greek; system CJK fonts cover the rest,
	## ordered so Japanese text gets Japanese glyph shapes, and so on.
	var sys: Array[Font] = []
	for code in Loc.cjk_order():
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(CJK_FONTS[code])
		sf.font_weight = 600
		sys.append(sf)
	var head_fb: Array[Font] = [f_bold]
	head_fb.append_array(sys)
	f_title.fallbacks = head_fb
	f_head.fallbacks = head_fb
	f_body.fallbacks = sys
	f_bold.fallbacks = sys


# ================================================================= theme
func _sb(bg: Color, border: Color, bw := 2, radius := 12, shadow := Color(0, 0, 0, 0), ssize := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = shadow
	s.shadow_size = ssize
	s.content_margin_left = 24; s.content_margin_right = 24
	s.content_margin_top = 12; s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


func _build_theme() -> void:
	th = Theme.new()
	th.default_font = f_body
	th.default_font_size = 26
	th.set_stylebox("normal", "Button", _sb(PANEL, LINE))
	th.set_stylebox("hover", "Button", _sb(Color(0.13, 0.09, 0.17, 0.95), AMBER, 2, 12, Color(1, 0.55, 0.15, 0.35), 14))
	th.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), AMBER, 3, 12, Color(1, 0.55, 0.15, 0.4), 16))
	th.set_stylebox("pressed", "Button", _sb(Color(0.2, 0.12, 0.08, 0.95), GOLD, 2))
	th.set_stylebox("disabled", "Button", _sb(Color(0.06, 0.05, 0.09, 0.7), Color(0.15, 0.12, 0.2)))
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color("ffe2b0"))
	th.set_color("font_focus_color", "Button", Color("ffe2b0"))
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.6))
	th.set_font_size("font_size", "Button", 28)
	th.set_color("font_color", "Label", TEXT)
	th.set_stylebox("panel", "PanelContainer", _sb(PANEL, LINE, 2, 14))
	th.set_stylebox("panel", "Panel", _sb(PANEL, LINE, 2, 14))
	var slider_bg := _sb(Color(0.15, 0.11, 0.22), Color(0, 0, 0, 0), 0, 6)
	slider_bg.content_margin_top = 4; slider_bg.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", slider_bg)
	var fill := _sb(AMBER, Color(0, 0, 0, 0), 0, 6)
	fill.content_margin_top = 4; fill.content_margin_bottom = 4
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	th.set_stylebox("focus", "HSlider", _sb(Color(0, 0, 0, 0), AMBER, 2, 8))


func _label(text: String, size := 26, font: Font = null, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font if font else f_body
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = int(size / 6.0) if size >= 30 else 0
	ls.outline_color = Color(0, 0, 0, 0.6)
	l.label_settings = ls
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _title(text: String, size := 64, color := AMBER) -> Label:
	var l := _label(text, size, f_head, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.label_settings.shadow_color = Color(color, 0.45)
	l.label_settings.shadow_size = 16
	l.label_settings.shadow_offset = Vector2.ZERO
	return l


func _button(text: String, cb: Callable, min_w := 360) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 64)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Sfx.play("click"); cb.call())
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play("hover"))
	return b


func _screen(name: String, dim := false) -> Control:
	var s := Control.new()
	s.name = name
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	if dim:
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.01, 0.05, 0.72)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		s.add_child(bg)
	root.add_child(s)
	screens[name] = s
	return s


func _center_col(parent: Control, sep := 18) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	return v


func _clear(name: String) -> Control:
	if screens.has(name):
		screens[name].queue_free()
		screens.erase(name)
	return null


func _show(name: String) -> void:
	for k in screens:
		screens[k].visible = k == name
	current = name if name in ["pause", "level", "victory", "over"] else ("" if name == "" else name)
	if name != "":
		_focus_first.call_deferred(screens[name])


func _focus_first(n: Node) -> void:
	for c in n.find_children("*", "Button", true, false):
		if c.visible and not c.disabled and c.is_visible_in_tree():
			c.grab_focus()
			return


func hide_overlays() -> void:
	for k in screens:
		screens[k].visible = false
	current = ""


# ================================================================= main menu
func show_menu() -> void:
	hud.visible = false
	_clear("menu")
	var s := _screen("menu")
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.005, 0.03, 0.92)); g.set_color(1, Color(0.01, 0.005, 0.03, 0.0))
	gt.gradient = g; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(1, 0); gt.width = 256; gt.height = 4
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.custom_minimum_size.x = 1100
	grad.size.x = 1100
	s.add_child(grad)
	var v := VBoxContainer.new()
	v.position = Vector2(130, 70)
	v.add_theme_constant_override("separation", 10)
	s.add_child(v)
	var small := _label("T H E", 34, f_head, Color("ffe7b0"))
	v.add_child(small)
	var t := _label("LAST\nLANTERN", 124, f_title, AMBER)
	t.label_settings.line_spacing = -24
	t.label_settings.shadow_color = Color(1, 0.45, 0.1, 0.5)
	t.label_settings.shadow_size = 24
	t.label_settings.shadow_offset = Vector2.ZERO
	t.label_settings.outline_size = 0
	v.add_child(t)
	v.add_child(_label(tr("The night is endless. Your light is not."), 30, f_body, MUTED))
	var sp := Control.new(); sp.custom_minimum_size.y = 12; v.add_child(sp)
	v.add_child(_button(tr("Play"), func(): play_pressed()))
	v.add_child(_button(tr("Sanctum"), func(): show_shop()))
	v.add_child(_button(tr("Journal"), func(): show_journal()))
	v.add_child(_button(tr("Achievements"), func(): show_ach()))
	v.add_child(_button(tr("Settings"), func(): show_settings("menu")))
	v.add_child(_button(tr("Quit"), func(): get_tree().quit()))
	var sp2 := Control.new(); sp2.custom_minimum_size.y = 10; v.add_child(sp2)
	v.add_child(_label("◆ " + tr("%d Embers") % int(Save.data.coins), 30, f_bold, GOLD))
	var hint := _label(_menu_hint(), 20, f_body, Color(0.45, 0.4, 0.58), HORIZONTAL_ALIGNMENT_CENTER)
	_place(hint, 0.5, 1, -700, -50, 1400, 30)
	s.add_child(hint)
	hint_label = hint
	var ver := _label("v" + str(ProjectSettings.get_setting("application/config/version")), 18, f_body, Color(0.35, 0.3, 0.45))
	_place(ver, 0, 1, 24, -40, 200, 30)
	s.add_child(ver)
	_show("menu")


# ================================================================= characters
func show_chars() -> void:
	_clear("chars")
	var s := _screen("chars")
	var grad := ColorRect.new(); grad.color = Color(0.01, 0.005, 0.03, 0.55); grad.set_anchors_preset(Control.PRESET_FULL_RECT); s.add_child(grad)
	var t := _title(tr("Choose your Keeper"), 60)
	t.anchor_right = 1; t.offset_top = 50; t.offset_bottom = 130
	s.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.position = Vector2(110, 180)
	s.add_child(grid)
	var detail := PanelContainer.new()
	_place(detail, 1, 1, -680, -440, 580, 300)
	detail.custom_minimum_size = Vector2(580, 300)
	s.add_child(detail)
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 10); detail.add_child(dv)
	var dname := _label("", 40, f_head, AMBER); dv.add_child(dname)
	var ddesc := _label("", 26, f_body, TEXT); ddesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ddesc.custom_minimum_size.x = 530; dv.add_child(ddesc)
	var wrow := HBoxContainer.new(); wrow.add_theme_constant_override("separation", 14); dv.add_child(wrow)
	var wicon := ItemIcon.new(); wicon.custom_minimum_size = Vector2(64, 64); wrow.add_child(wicon)
	var wtext := _label("", 22, f_body, MUTED); wtext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; wtext.custom_minimum_size.x = 440; wrow.add_child(wtext)
	var first: Button = null
	for c in Data.CHAR_ORDER:
		var def: Dictionary = Data.CHARS[c]
		var un: bool = Save.is_char_unlocked(c)
		var b := _button(tr(def.name) if un else "? ? ?", func():
			if un:
				main.start_run(c)
			else:
				Sfx.play("deny"), 470)
		b.custom_minimum_size.y = 84
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not un:
			b.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
		b.focus_entered.connect(func():
			if un:
				main.preview_char(c)
				dname.text = tr(def.name)
				ddesc.text = tr(def.desc)
				wicon.setup(def.weapon)
				wicon.visible = true
				wtext.text = tr("Starts with %s — %s") % [tr(Data.WEAPONS[def.weapon].name), tr(Data.WEAPONS[def.weapon].desc)]
			else:
				dname.text = tr("Locked")
				var a := Data.ach_by_id(def.unlock)
				ddesc.text = tr("Unlock: %s") % tr(a.desc)
				wicon.visible = false
				wtext.text = "")
		grid.add_child(b)
		if c == str(Save.data.last_char) and un:
			first = b
	var back := _button(tr("Back"), func(): show_menu(), 220)
	back.position = Vector2(110, 960)
	s.add_child(back)
	_show("chars")
	if first:
		first.grab_focus.call_deferred()


# ================================================================= shop
func show_shop(focus_idx := -1) -> void:
	_clear("shop")
	var s := _screen("shop")
	var grad := ColorRect.new(); grad.color = Color(0.01, 0.005, 0.03, 0.78); grad.set_anchors_preset(Control.PRESET_FULL_RECT); s.add_child(grad)
	var v := _center_col(s, 16)
	v.add_child(_title(tr("The Sanctum"), 60))
	v.add_child(_label(tr("Spend Embers on permanent blessings.") + "      ◆ %d" % int(Save.data.coins), 28, f_body, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	var buttons := []
	for i in Data.SHOP.size():
		var it: Dictionary = Data.SHOP[i]
		var l := Save.shop_level(it.id)
		var maxed: bool = l >= it.max
		var cost := Data.shop_cost(it, l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(360, 128)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_entered.connect(func(): b.grab_focus())
		b.focus_entered.connect(func(): Sfx.play("hover"))
		var bv := VBoxContainer.new(); bv.set_anchors_preset(Control.PRESET_FULL_RECT); bv.offset_left = 18; bv.offset_top = 12; bv.offset_right = -18
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_theme_constant_override("separation", 4)
		b.add_child(bv)
		bv.add_child(_label(tr(it.name), 28, f_head, AMBER))
		bv.add_child(_label(tr(it.desc), 22, f_body, MUTED))
		var pips := ""
		for k in it.max:
			pips += "■ " if k < l else "□ "
		bv.add_child(_label(pips + "     " + (tr("MAXED") if maxed else "◆ %d" % cost), 22, f_bold, Color("7dff9a") if maxed else GOLD))
		b.pressed.connect(func():
			if maxed or int(Save.data.coins) < cost:
				Sfx.play("deny")
				return
			Save.add_coins(-cost)
			Save.data.shop[it.id] = l + 1
			Save.persist()
			Sfx.play("buy")
			show_shop(i))
		grid.add_child(b)
		buttons.append(b)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	row.add_child(_button(tr("Refund All"), func():
		var back := 0
		for it in Data.SHOP:
			for k in Save.shop_level(it.id):
				back += Data.shop_cost(it, k)
		if back == 0:
			Sfx.play("deny")
			return
		Save.add_coins(back)
		Save.data.shop = {}
		Save.persist()
		Sfx.play("coin")
		if int(Save.data.coins) >= 2000:
			Save.unlock("ACH_RICH")
		show_shop(), 260))
	row.add_child(_button(tr("Back"), func(): show_menu(), 220))
	_show("shop")
	if focus_idx >= 0:
		buttons[focus_idx].grab_focus.call_deferred()


# ================================================================= achievements
func show_ach() -> void:
	_clear("ach")
	var s := _screen("ach")
	var grad := ColorRect.new(); grad.color = Color(0.01, 0.005, 0.03, 0.8); grad.set_anchors_preset(Control.PRESET_FULL_RECT); s.add_child(grad)
	var v := _center_col(s, 14)
	v.add_child(_title(tr("Achievements"), 60))
	var got := 0
	for a in Data.ACHIEVEMENTS:
		if Save.has_ach(a.id):
			got += 1
	v.add_child(_label(tr("%d / %d unlocked") % [got, Data.ACHIEVEMENTS.size()], 26, f_body, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for a in Data.ACHIEVEMENTS:
		var has: bool = Save.has_ach(a.id)
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(500, 96)
		if has:
			p.add_theme_stylebox_override("panel", _sb(Color(0.12, 0.09, 0.06, 0.92), Color("8a6a2a"), 2, 14))
		else:
			p.modulate = Color(1, 1, 1, 0.5)
		var pv := VBoxContainer.new(); p.add_child(pv)
		pv.add_child(_label(("★ " if has else "") + tr(a.name), 26, f_head, GOLD if has else AMBER))
		var c := Data.char_unlocked_by(a.id)
		pv.add_child(_label(tr(a.desc) + (("   — " + tr("Unlocks a Keeper")) if c != "" else ""), 20, f_body, MUTED))
		grid.add_child(p)
	var T: Dictionary = Save.data.totals
	var B: Dictionary = Save.data.best
	v.add_child(_label(tr("Runs %d   ·   Total kills %d   ·   Bosses slain %d   ·   Dawns %d   ·   Longest night %s   ·   Best level %d") % [
		T.runs, T.kills, T.bosses, T.wins, _fmt_time(B.time), B.level], 22, f_body, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var back := _button(tr("Back"), func(): show_menu(), 220)
	var bc := CenterContainer.new(); bc.add_child(back); v.add_child(bc)
	_show("ach")


# ================================================================= story
func show_story(lines: Array, title: String, then: Callable) -> void:
	## Full-screen text that fades in line by line. Confirm skips ahead, then continues.
	_clear("story")
	var s := _screen("story")
	var bg := ColorRect.new(); bg.color = Color(0.01, 0.005, 0.03, 0.97); bg.set_anchors_preset(Control.PRESET_FULL_RECT); s.add_child(bg)
	var v := _center_col(s, 30)
	if title != "":
		v.add_child(_title(tr(title), 64, GOLD))
	var labels := []
	for line in lines:
		var l := _label(tr(line), 34, f_body, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1100
		l.modulate.a = 0.0
		v.add_child(l)
		labels.append(l)
	var btn := _button(tr("Continue"), func(): pass, 300)
	var bc := CenterContainer.new(); bc.add_child(btn); v.add_child(bc)
	var tw := s.create_tween()
	for l in labels:
		tw.tween_property(l, "modulate:a", 1.0, 1.2)
		tw.tween_interval(0.9)
	btn.pressed.connect(func():
		if tw.is_running():
			tw.kill()
			for l in labels:
				l.modulate.a = 1.0
			return
		_clear("story")
		then.call())
	_show("story")


func play_pressed() -> void:
	if not Save.data.get("seen_intro", false):
		Save.data.seen_intro = true
		Save.persist()
		show_story(Data.INTRO, "", func(): show_chars())
	else:
		show_chars()


func show_journal() -> void:
	_clear("journal")
	var s := _screen("journal")
	var grad := ColorRect.new(); grad.color = Color(0.01, 0.005, 0.03, 0.85); grad.set_anchors_preset(Control.PRESET_FULL_RECT); s.add_child(grad)
	var t := _title(tr("Journal"), 60)
	t.anchor_right = 1; t.offset_top = 40; t.offset_bottom = 120
	s.add_child(t)
	var mem: Array = Save.data.get("memories", [])
	var sub := _label(tr("Memories recovered: %d / %d") % [mem.size(), Data.MEMORIES.size()] + "   ·   " + tr("Light lantern shrines during a run to recover more."),
		22, f_body, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.anchor_right = 1; sub.offset_top = 118; sub.offset_bottom = 150
	s.add_child(sub)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 6)
	list.position = Vector2(110, 180)
	s.add_child(list)
	var panel := PanelContainer.new()
	_place(panel, 1, 0, -1080, 180, 960, 720)
	s.add_child(panel)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 18); panel.add_child(pv)
	var ptitle := _label("", 40, f_head, AMBER); pv.add_child(ptitle)
	var ptext := _label("", 30, f_body, TEXT); ptext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ptext.custom_minimum_size.x = 900
	pv.add_child(ptext)
	var entries := [["The Long Night", "\n\n".join(Data.INTRO.map(func(x): return tr(x))), true]]
	for i in Data.MEMORIES.size():
		var m: Dictionary = Data.MEMORIES[i]
		entries.append([m.title, tr(m.text), mem.has(i) or mem.has(float(i))])
	entries.append(["Dawn", "\n\n".join(Data.ENDING.map(func(x): return tr(x))), bool(Save.data.get("seen_ending", false))])
	var first: Button = null
	for e in entries:
		var b := _button(tr(e[0]) if e[2] else "? ? ?", func(): pass, 640)
		b.custom_minimum_size.y = 48
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not e[2]:
			b.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
		b.focus_entered.connect(func():
			ptitle.text = tr(e[0]) if e[2] else tr("Not yet recovered")
			ptext.text = e[1] if e[2] else tr("Light lantern shrines during a run to recover more."))
		list.add_child(b)
		if first == null:
			first = b
	var back := _button(tr("Back"), func(): show_menu(), 220)
	back.position = Vector2(110, 960)
	s.add_child(back)
	_show("journal")
	if first:
		first.grab_focus.call_deferred()


# ================================================================= settings
const SETTINGS_TABS := ["General", "Audio", "Video", "Controls"]
var settings_from := "menu"
var settings_tab := "General"
var capture := {}  # {"action": String, "kind": "key"/"pad", "button": Button} while waiting for a new binding


func _set_key(c: Control, key: String) -> Control:
	c.set_meta("fkey", key)
	return c


func _focus_key(root_node: Node, key: String) -> void:
	for c in root_node.find_children("*", "Control", true, false):
		if c.get_meta("fkey", "") == key and c.focus_mode != Control.FOCUS_NONE:
			c.grab_focus()
			return


func _row(label: String, right: Control) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size.x = 860
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 24); row.add_child(h)
	var l := _label(label, 26); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.add_child(right)
	return row


func _toggle(label: String, key: String, after := Callable()) -> PanelContainer:
	var b := _button("", func(): pass, 220)
	b.custom_minimum_size.y = 48
	var refresh := func(): b.text = tr("On") if Save.setting(key) else tr("Off")
	refresh.call()
	b.pressed.connect(func():
		Save.set_setting(key, not Save.setting(key))
		refresh.call()
		if after.is_valid():
			after.call())
	_set_key(b, key)
	return _row(label, b)


func _cycle(label: String, key: String, opts: Array, after := Callable()) -> PanelContainer:
	## opts: [[value, display name], ...]. Pressing cycles forward; Left/Right on the focused button cycles too.
	var b := _button("", func(): pass, 300)
	b.custom_minimum_size.y = 48
	var idx := func() -> int:
		for i in opts.size():
			if str(opts[i][0]) == str(Save.setting(key)):
				return i
		return 0
	var refresh := func(): b.text = "◂  %s  ▸" % tr(opts[idx.call()][1])
	refresh.call()
	var step := func(d: int):
		Save.set_setting(key, opts[(idx.call() + d + opts.size()) % opts.size()][0])
		refresh.call()
		if after.is_valid():
			after.call()
	b.pressed.connect(func(): step.call(1))
	b.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left"):
			Sfx.play("click"); step.call(-1); b.accept_event()
		elif ev.is_action_pressed("ui_right"):
			Sfx.play("click"); step.call(1); b.accept_event())
	_set_key(b, key)
	return _row(label, b)


func _slider(label: String, key: String, lo: float, hi: float, stp: float, after := Callable()) -> PanelContainer:
	var sl := HSlider.new()
	sl.min_value = lo; sl.max_value = hi; sl.step = stp
	sl.value = float(Save.setting(key))
	sl.custom_minimum_size = Vector2(300, 32)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(func(val):
		Save.set_setting(key, val)
		Sfx.play("click")
		if after.is_valid():
			after.call())
	sl.mouse_entered.connect(func(): sl.grab_focus())
	_set_key(sl, key)
	return _row(label, sl)


func show_settings(from: String, tab := "", focus := "") -> void:
	settings_from = from
	if tab != "":
		settings_tab = tab
	capture = {}
	_clear("settings")
	var s := _screen("settings", true)
	var v := _center_col(s, 12)
	v.add_child(_title(tr("Settings"), 60))
	var tabs := HBoxContainer.new(); tabs.alignment = BoxContainer.ALIGNMENT_CENTER; tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	for t in SETTINGS_TABS:
		var tb := _button(tr(t), func(): show_settings(from, t, "tab_" + t), 200)
		tb.custom_minimum_size.y = 52
		if t == settings_tab:
			tb.add_theme_stylebox_override("normal", _sb(Color(0.2, 0.12, 0.08, 0.95), GOLD, 2))
			tb.add_theme_color_override("font_color", GOLD)
		_set_key(tb, "tab_" + t)
		tabs.add_child(tb)
	v.add_child(_label(tr("LB / RB or Q / E to switch tabs"), 18, f_body, Color(0.45, 0.4, 0.58), HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 690)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	v.add_child(scroll)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	match settings_tab:
		"General":
			var langs := []
			for l in Loc.LANGS:
				langs.append([l[0], l[1]])
			body.add_child(_cycle(tr("Language"), "language", langs, func():
				Loc.apply(str(Save.setting("language")))
				apply_fonts()
				_build_ach_toast()
				show_settings.call_deferred(from, "General", "language")))
			body.add_child(_toggle(tr("Screen Shake"), "shake"))
			body.add_child(_toggle(tr("Damage Numbers"), "dmg_nums"))
			body.add_child(_toggle(tr("Reduce Flashing"), "reduce_flash"))
			body.add_child(_toggle(tr("Pause When Unfocused"), "autopause"))
			body.add_child(_toggle(tr("Show FPS"), "show_fps"))
			if from == "menu":
				var rb := _button(tr("Reset Save Data"), func(): pass, 640)
				rb.pressed.connect(func():
					if rb.get_meta("armed", false):
						var st: Dictionary = Save.data.settings
						Save.data = Save._defaults()
						Save.data.settings = st
						Save.persist()
						rb.text = tr("Save data erased")
						rb.set_meta("armed", false)
					else:
						rb.set_meta("armed", true)
						rb.text = tr("Press again to erase ALL progress")
						Sfx.play("deny"))
				var rc := CenterContainer.new(); rc.add_child(rb); body.add_child(rc)
		"Audio":
			body.add_child(_slider(tr("Sound Effects"), "sfx", 0, 1, 0.05))
			body.add_child(_slider(tr("Music"), "music", 0, 1, 0.05))
		"Video":
			body.add_child(_toggle(tr("Fullscreen"), "fullscreen"))
			body.add_child(_toggle(tr("V-Sync"), "vsync"))
			body.add_child(_cycle(tr("Graphics"), "quality", [[0, "Low"], [1, "Medium"], [2, "High"]], func():
				if main.world and main.world.mode == "menu":
					main.go_menu.call_deferred()
					show_settings.call_deferred("menu", "Video", "quality")))
		"Controls":
			body.add_child(_toggle(tr("Vibration"), "vibration", func(): Controls.rumble(0.4, 0.4, 0.25)))
			body.add_child(_slider(tr("Vibration Strength"), "vibration_strength", 0.1, 1, 0.1, func(): Controls.rumble(0.4, 0.4, 0.2)))
			body.add_child(_slider(tr("Stick Deadzone"), "deadzone", 0.05, 0.6, 0.05, func(): Controls.apply()))
			body.add_child(_cycle(tr("Button Prompts"), "prompts", [["auto", "Auto"], ["xbox", "Xbox"], ["ps", "PlayStation"], ["nintendo", "Nintendo"]],
				func(): show_settings.call_deferred(from, "Controls", "prompts")))
			var grid := GridContainer.new(); grid.columns = 3
			grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 6)
			grid.add_child(_label("", 20))
			grid.add_child(_label(tr("Keyboard"), 20, f_bold, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
			grid.add_child(_label(tr("Controller"), 20, f_bold, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
			for action in Controls.ACTIONS:
				var nl := _label(tr(Controls.NAMES[action]), 24); nl.custom_minimum_size.x = 300; nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				grid.add_child(nl)
				for kind in ["key", "pad"]:
					var txt := Controls.key_name(Controls.key_for(action)) if kind == "key" else Controls.pad_name(Controls.pad_for(action))
					var bb := _button(txt, func(): pass, 260)
					bb.custom_minimum_size.y = 44
					bb.pressed.connect(func():
						capture = {"action": action, "kind": kind, "button": bb, "t": 6.0}
						bb.text = tr("Press a key...") if kind == "key" else tr("Press a button..."))
					_set_key(bb, "bind_%s_%s" % [action, kind])
					grid.add_child(bb)
			var gc := CenterContainer.new(); gc.add_child(grid); body.add_child(gc)
			var rs := _button(tr("Reset Controls"), func():
				Controls.reset_binds()
				show_settings.call_deferred(from, "Controls", "reset_binds"), 360)
			_set_key(rs, "reset_binds")
			var rsc := CenterContainer.new(); rsc.add_child(rs); body.add_child(rsc)
	var back := _button(tr("Back"), func(): _settings_back(), 220)
	var bc := CenterContainer.new(); bc.add_child(back); v.add_child(bc)
	_show("settings")
	_focus_key.call_deferred(s, focus if focus != "" else "tab_" + settings_tab)  # runs after _show's _focus_first
	if from == "pause":
		current = "pause"


func _settings_back() -> void:
	if settings_from == "pause":
		show_pause()
	else:
		show_menu()


func _settings_tab_step(d: int) -> void:
	var i := SETTINGS_TABS.find(settings_tab)
	var t: String = SETTINGS_TABS[(i + d + SETTINGS_TABS.size()) % SETTINGS_TABS.size()]
	Sfx.play("click")
	show_settings(settings_from, t, "tab_" + t)


func _input(event: InputEvent) -> void:
	## Captures the next key / button for rebinding before anything else sees it.
	if capture.is_empty():
		return
	var action: String = capture.action
	if capture.kind == "key" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE and action != "pause":
			show_settings(settings_from, "Controls", "bind_%s_key" % action)
			return
		Controls.rebind(action, "key", event.physical_keycode)
		Sfx.play("buy")
		show_settings(settings_from, "Controls", "bind_%s_key" % action)
	elif capture.kind == "pad" and event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		Controls.rebind(action, "pad", event.button_index)
		Sfx.play("buy")
		show_settings.call_deferred(settings_from, "Controls", "bind_%s_pad" % action)
	elif capture.kind == "pad" and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		show_settings(settings_from, "Controls", "bind_%s_pad" % action)


func _place(c: Control, ax: float, ay: float, left: float, top: float, w: float, h: float) -> void:
	## Anchor a control to a fraction of the screen and offset it in pixels (robust to aspect changes).
	c.anchor_left = ax; c.anchor_right = ax; c.anchor_top = ay; c.anchor_bottom = ay
	c.offset_left = left; c.offset_right = left + w; c.offset_top = top; c.offset_bottom = top + h


# ================================================================= HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	root.add_child(hud)
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p * vec2(1.6, 1.0));
	COLOR = vec4(0.9, 0.0, 0.12, smoothstep(0.35, 0.95, d) * amount);
}
"""
	var m := ShaderMaterial.new(); m.shader = sh
	vignette.material = m
	hud.add_child(vignette)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.anchor_right = 1; xp_bar.offset_bottom = 16
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.04, 0.03, 0.08, 0.85)
	var fg := StyleBoxFlat.new(); fg.bg_color = Color("6fe3f0"); fg.shadow_color = Color(0.4, 0.9, 1, 0.5); fg.shadow_size = 6
	xp_bar.add_theme_stylebox_override("background", bg)
	xp_bar.add_theme_stylebox_override("fill", fg)
	hud.add_child(xp_bar)
	lvl_label = _label("LV 1", 24, f_bold, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(lvl_label, 1, 0, -220, 18, 200, 30)
	lvl_label.label_settings.outline_size = 6
	hud.add_child(lvl_label)
	time_label = _label("0:00", 54, f_head, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_place(time_label, 0.5, 0, -200, 22, 400, 64)
	hud.add_child(time_label)
	sub_label = _label("", 22, f_body, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_place(sub_label, 0.5, 0, -200, 86, 400, 30)
	sub_label.label_settings.outline_size = 5
	hud.add_child(sub_label)
	kills_label = _label("", 30, f_bold, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(kills_label, 1, 0, -330, 52, 300, 36)
	kills_label.label_settings.outline_size = 6
	hud.add_child(kills_label)
	coins_label = _label("", 30, f_bold, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(coins_label, 1, 0, -330, 92, 300, 36)
	coins_label.label_settings.outline_size = 6
	hud.add_child(coins_label)
	weapon_row = HBoxContainer.new(); weapon_row.position = Vector2(20, 30); weapon_row.add_theme_constant_override("separation", 8)
	hud.add_child(weapon_row)
	passive_row = HBoxContainer.new(); passive_row.position = Vector2(20, 104); passive_row.add_theme_constant_override("separation", 6)
	hud.add_child(passive_row)
	boss_box = VBoxContainer.new()
	_place(boss_box, 0.5, 1, -450, -190, 900, 160)
	boss_box.alignment = BoxContainer.ALIGNMENT_END
	hud.add_child(boss_box)
	toast_box = VBoxContainer.new()
	_place(toast_box, 0.5, 0, -400, 130, 800, 200)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast_box)
	banner_box = Control.new()
	banner_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.modulate.a = 0
	hud.add_child(banner_box)
	var strip := ColorRect.new()
	strip.color = Color(0.02, 0.01, 0.05, 0.6)
	strip.anchor_right = 1; strip.offset_top = 270; strip.offset_bottom = 420
	banner_box.add_child(strip)
	banner_title = _title("", 72)
	banner_title.anchor_right = 1; banner_title.offset_top = 280; banner_title.offset_bottom = 370
	banner_box.add_child(banner_title)
	banner_sub = _label("", 28, f_body, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub.anchor_right = 1; banner_sub.offset_top = 372; banner_sub.offset_bottom = 412
	banner_box.add_child(banner_sub)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(70, 9)
	hp_bar.size = Vector2(70, 9)
	var hbg := StyleBoxFlat.new(); hbg.bg_color = Color(0, 0, 0, 0.7); hbg.set_corner_radius_all(3)
	var hfg := StyleBoxFlat.new(); hfg.bg_color = Color("ff5d73"); hfg.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", hbg)
	hp_bar.add_theme_stylebox_override("fill", hfg)
	hud.add_child(hp_bar)
	dash_bar = ProgressBar.new()
	dash_bar.show_percentage = false
	dash_bar.custom_minimum_size = Vector2(70, 5)
	dash_bar.size = Vector2(70, 5)
	dash_bar.max_value = 1.0
	var dbg := StyleBoxFlat.new(); dbg.bg_color = Color(0, 0, 0, 0.6); dbg.set_corner_radius_all(2)
	var dfg := StyleBoxFlat.new(); dfg.bg_color = Color("ffb347"); dfg.set_corner_radius_all(2)
	dash_bar.add_theme_stylebox_override("background", dbg)
	dash_bar.add_theme_stylebox_override("fill", dfg)
	hud.add_child(dash_bar)
	dash_hint = _label("", 22, f_bold, TEXT)
	dash_hint.label_settings.outline_size = 5
	_place(dash_hint, 0, 1, 24, -52, 500, 30)
	hud.add_child(dash_hint)
	near_label = _label("", 22, f_bold, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	near_label.label_settings.outline_size = 6
	near_label.size = Vector2(300, 30)
	hud.add_child(near_label)
	buff_label = _label("", 22, f_bold, Color("ffd166"))
	buff_label.label_settings.outline_size = 5
	_place(buff_label, 0, 1, 24, -88, 600, 30)
	hud.add_child(buff_label)
	fps_label = _label("", 18, f_body, MUTED)
	_place(fps_label, 1, 0, -220, 134, 196, 24)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(fps_label)
	Controls.device_changed.connect(_refresh_prompts)


func show_hud(w: World) -> void:
	world = w
	build_sig = ""
	hide_overlays()
	hud.visible = true
	_refresh_prompts()
	for c in toast_box.get_children():
		c.queue_free()
	banner_box.modulate.a = 0


func _refresh_prompts() -> void:
	if dash_hint:
		dash_hint.text = "[%s]  %s" % [Controls.prompt("dash"), tr("Dash")]
	if hint_label and is_instance_valid(hint_label):
		hint_label.text = _menu_hint()
	if current == "level" and _visible("level"):
		show_level()


func _menu_hint() -> String:
	if Controls.using_pad:
		return tr("Move: Left Stick    ·    Dash: %s    ·    Weapons fire on their own    ·    Pause: %s") % [Controls.prompt("dash"), Controls.prompt("pause")]
	return tr("Move: %s    ·    Dash: %s    ·    Weapons fire on their own    ·    Pause: %s") % [
		"".join([Controls.prompt("move_up"), Controls.prompt("move_left"), Controls.prompt("move_down"), Controls.prompt("move_right")]),
		Controls.prompt("dash"), Controls.prompt("pause")]


func _process(_dt: float) -> void:
	card_lock -= _dt
	fps_label.visible = bool(Save.setting("show_fps"))
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if not capture.is_empty():
		capture.t -= _dt
		if capture.t <= 0:
			show_settings(settings_from, "Controls", "bind_%s_%s" % [capture.action, capture.kind])
	var want_hidden := hud.visible and current == "" and world != null and is_instance_valid(world) and world.mode == "run"
	var mm := Input.MOUSE_MODE_HIDDEN if want_hidden else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mm:
		Input.mouse_mode = mm
	if not hud.visible or world == null or not is_instance_valid(world) or world.mode != "run":
		return
	var P := world.P
	xp_bar.max_value = P.xp_next
	xp_bar.value = P.xp
	lvl_label.text = tr("LV %d") % P.level
	time_label.text = _fmt_time(world.time)
	if world.won:
		sub_label.text = tr("Endless Night") if world.endless else tr("Dawn")
	elif world.time < Data.DAWN_TIME:
		sub_label.text = tr("Dawn in %s") % _fmt_time(Data.DAWN_TIME - world.time)
	else:
		sub_label.text = tr("Slay the Hollow King")
	kills_label.text = "☠ %d" % world.kills
	coins_label.text = "◆ %d" % world.coins
	var sig := ""
	for w in world.weapons:
		sig += "%s%d," % [w.id, w.lvl]
	for id in world.passive_order:
		sig += "%s%d," % [id, world.passives[id]]
	if sig != build_sig:
		build_sig = sig
		for c in weapon_row.get_children(): c.queue_free()
		for c in passive_row.get_children(): c.queue_free()
		for w in world.weapons:
			var ic := ItemIcon.new(); ic.custom_minimum_size = Vector2(58, 66); ic.setup(w.id, w.lvl, true); weapon_row.add_child(ic)
		for id in world.passive_order:
			var ic := ItemIcon.new(); ic.custom_minimum_size = Vector2(44, 52); ic.setup(id, world.passives[id], true); passive_row.add_child(ic)
	# boss bars
	while boss_box.get_child_count() < world.bosses.size() * 2:
		var nl := _label("", 26, f_head, TEXT, HORIZONTAL_ALIGNMENT_CENTER); nl.label_settings.outline_size = 6
		boss_box.add_child(nl)
		var pb := ProgressBar.new(); pb.show_percentage = false; pb.custom_minimum_size = Vector2(900, 18)
		var bbg := StyleBoxFlat.new(); bbg.bg_color = Color(0, 0, 0, 0.7); bbg.set_corner_radius_all(4); bbg.border_color = Color(0.4, 0.1, 0.2); bbg.set_border_width_all(2)
		var bfg := StyleBoxFlat.new(); bfg.bg_color = Color("ff3d6e"); bfg.set_corner_radius_all(4); bfg.shadow_color = Color(1, 0.2, 0.4, 0.5); bfg.shadow_size = 8
		pb.add_theme_stylebox_override("background", bbg); pb.add_theme_stylebox_override("fill", bfg)
		boss_box.add_child(pb)
	while boss_box.get_child_count() > world.bosses.size() * 2:
		var c := boss_box.get_child(boss_box.get_child_count() - 1)
		boss_box.remove_child(c); c.queue_free()
	for i in world.bosses.size():
		var b = world.bosses[i]
		(boss_box.get_child(i * 2) as Label).text = tr(b.bname)
		var pb: ProgressBar = boss_box.get_child(i * 2 + 1)
		pb.max_value = b.max_hp; pb.value = maxf(0, b.hp)
	# player hp bar follows the player on screen
	var cam := world.cam
	var sp := cam.unproject_position(Vector3(world.ppos.x, 0, world.ppos.y))
	var vs := get_viewport().get_visible_rect().size
	var scale := 1080.0 / vs.y if vs.y > 0 else 1.0
	hp_bar.position = sp * scale + Vector2(-35, 22)
	hp_bar.max_value = P.max_hp
	hp_bar.value = P.hp
	hp_bar.visible = world.dying <= 0
	dash_bar.position = hp_bar.position + Vector2(0, 12)
	dash_bar.value = 1.0 - clampf(world.dash_cd / maxf(0.01, P.dash_cd), 0, 1)
	dash_bar.visible = hp_bar.visible
	dash_bar.modulate.a = 1.0 if dash_bar.value >= 1.0 else 0.55
	near_label.visible = world.shrine_prog > 0.0 and hp_bar.visible
	if near_label.visible:
		near_label.text = tr("Kindling the shrine... %d%%") % int(world.shrine_prog * 100)
		near_label.position = hp_bar.position + Vector2(35 - 150, -86)
	var buffs := []
	if world.fury_t > 0:
		buffs.append(tr("Fury %ds") % ceili(world.fury_t))
	if world.haste_t > 0:
		buffs.append(tr("Haste %ds") % ceili(world.haste_t))
	buff_label.text = "   ".join(buffs)
	var low := 0.0
	if P.hp > 0 and P.hp / P.max_hp < 0.3:
		low = 0.3 + sin(Time.get_ticks_msec() / 160.0) * 0.12
	(vignette.material as ShaderMaterial).set_shader_parameter("amount", maxf(world.hurt * 0.7, low))


func _fmt_time(s: float) -> String:
	var i := int(s)
	return "%d:%02d" % [i / 60, i % 60]


func toast(text: String, color: Color) -> void:
	var l := _label(text, 32, f_bold, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.label_settings.outline_size = 8
	toast_box.add_child(l)
	while toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func banner(title: String, sub: String, color: Color) -> void:
	banner_title.text = title
	banner_title.label_settings.font_color = color
	banner_title.label_settings.shadow_color = Color(color, 0.5)
	banner_sub.text = sub
	var tw := banner_box.create_tween()
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(banner_box, "modulate:a", 0.0, 0.6)


# ================================================================= level up
func show_level() -> void:
	_clear("level")
	var s := _screen("level", true)
	var v := _center_col(s, 26)
	v.add_child(_title(tr("Level Up!"), 76))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 22); row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	card_lock = 0.6  # long enough that a dash/confirm press held from gameplay can't pick a card
	for i in world.choices.size():
		var c: Dictionary = world.choices[i]
		var def := Data.item_def(c.id)
		var is_w: bool = c.type == "w"
		var cur: int = (world._weapon(c.id).lvl if world._weapon(c.id) else 0) if is_w else int(world.passives.get(c.id, 0))
		var b := Button.new()
		b.custom_minimum_size = Vector2(330, 420)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_entered.connect(func(): b.grab_focus())
		b.focus_entered.connect(func(): Sfx.play("hover"))
		var bv := VBoxContainer.new(); bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		bv.offset_left = 20; bv.offset_right = -20; bv.offset_top = 28; bv.offset_bottom = -20
		bv.add_theme_constant_override("separation", 14); bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bv)
		var icc := CenterContainer.new(); icc.mouse_filter = Control.MOUSE_FILTER_IGNORE; bv.add_child(icc)
		var ic := ItemIcon.new(); ic.custom_minimum_size = Vector2(110, 110); ic.setup(c.id); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; icc.add_child(ic)
		bv.add_child(_label(tr(def.name), 32, f_head, AMBER, HORIZONTAL_ALIGNMENT_CENTER))
		var tag: String
		if cur == 0:
			tag = tr("NEW WEAPON") if is_w else tr("NEW RELIC")
		else:
			tag = tr("LV %d → %d") % [cur, cur + 1] + (("  (" + tr("MAX") + ")") if cur + 1 == int(def.max) else "")
		bv.add_child(_label(tag, 22, f_bold, GOLD if cur == 0 else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		var desc: String = (def.desc if cur == 0 else def.up[cur - 1]) if is_w else def.desc
		var dl := _label(tr(desc), 25, f_body, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 290
		bv.add_child(dl)
		var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE; bv.add_child(spacer)
		bv.add_child(_label("" if Controls.using_pad else "[%d]" % (i + 1), 18, f_body, Color(0.45, 0.4, 0.58), HORIZONTAL_ALIGNMENT_CENTER))
		b.pressed.connect(func(): _pick_card(i))
		row.add_child(b)
	var r2 := HBoxContainer.new(); r2.alignment = BoxContainer.ALIGNMENT_CENTER; r2.add_theme_constant_override("separation", 16)
	v.add_child(r2)
	var rr := _button(tr("Reroll (%d)") % int(world.P.rerolls) + "  [%s]" % Controls.prompt("reroll"), func():
		if world.P.rerolls > 0:
			world.reroll()
			show_level(), 260)
	rr.disabled = world.P.rerolls <= 0
	r2.add_child(rr)
	r2.add_child(_button(tr("Skip") + " (+10 ◆)", func():
		if card_lock > 0:
			return
		world.coins += 10
		main.level_choice_done(world.choose(-1)), 260))
	_show("level")


func _pick_card(i: int) -> void:
	if card_lock > 0:
		return
	Sfx.play("buy")
	main.level_choice_done(world.choose(i))


# ================================================================= pause / end
func _build_icons(parent: Control) -> void:
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 8)
	for w in world.weapons:
		var ic := ItemIcon.new(); ic.custom_minimum_size = Vector2(64, 72); ic.setup(w.id, w.lvl, true); row.add_child(ic)
	parent.add_child(row)
	var row2 := HBoxContainer.new(); row2.alignment = BoxContainer.ALIGNMENT_CENTER; row2.add_theme_constant_override("separation", 8)
	for id in world.passive_order:
		var ic := ItemIcon.new(); ic.custom_minimum_size = Vector2(52, 60); ic.setup(id, world.passives[id], true); row2.add_child(ic)
	parent.add_child(row2)


func show_pause() -> void:
	_clear("pause")
	var s := _screen("pause", true)
	var v := _center_col(s, 16)
	v.add_child(_title(tr("Paused"), 70))
	_build_icons(v)
	var P := world.P
	v.add_child(_label(tr("Damage ×%.2f   ·   Area ×%.2f   ·   Cooldown ×%.2f   ·   Speed %.1f   ·   Armor %d") % [P.might, P.area, P.cd, P.speed, P.armor],
		22, f_body, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for b in [["Resume", func(): main.toggle_pause()], ["Settings", func(): show_settings("pause")], ["Abandon Run", func(): main.abandon()]]:
		var cc := CenterContainer.new(); cc.add_child(_button(tr(b[0]), b[1])); v.add_child(cc)
	_show("pause")


func show_victory() -> void:
	_clear("victory")
	var s := _screen("victory", true)
	var v := _center_col(s, 20)
	v.add_child(_title(tr("Dawn Breaks"), 84, GOLD))
	v.add_child(_label(tr("The Hollow King has fallen. You may rest... or keep the light burning."), 28, f_body, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var c1 := CenterContainer.new(); c1.add_child(_button(tr("Continue into the Endless Night"), func(): main.continue_endless(), 520)); v.add_child(c1)
	var c2 := CenterContainer.new(); c2.add_child(_button(tr("Rest & Claim Rewards"), func(): get_tree().paused = false; world.end_run("victory"), 520)); v.add_child(c2)
	_show("victory")


func show_over(reason: String) -> void:
	_clear("over")
	var s := _screen("over", true)
	var v := _center_col(s, 16)
	var title := "The Dawn Remembers You" if world.won else ("You Retreat Into the Dark" if reason == "abandon" else "Your Light Fades")
	v.add_child(_title(tr(title), 64, GOLD if world.won else AMBER))
	var stats := HBoxContainer.new(); stats.alignment = BoxContainer.ALIGNMENT_CENTER; stats.add_theme_constant_override("separation", 70)
	for pair in [["Survived", _fmt_time(world.time)], ["Enemies", str(world.kills)], ["Level", str(world.P.level)], ["Embers", "+%d" % int(world.get_meta("earned", 0))]]:
		var col := VBoxContainer.new()
		col.add_child(_label(tr(pair[0]), 24, f_body, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(_label(pair[1], 46, f_head, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		stats.add_child(col)
	v.add_child(stats)
	var newm := int(world.get_meta("new_memories", 0))
	if newm > 0:
		v.add_child(_label(tr("New memories recovered: %d. Read them in the Journal.") % newm, 24, f_bold, Color("b9a7ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var ws := world.weapons.duplicate()
	ws.sort_custom(func(a, b): return a.dmg_total > b.dmg_total)
	var maxd := 1.0
	for w in ws:
		maxd = maxf(maxd, w.dmg_total)
	for w in ws:
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14)
		var ic := ItemIcon.new(); ic.custom_minimum_size = Vector2(44, 44); ic.setup(w.id); h.add_child(ic)
		var cv := VBoxContainer.new(); cv.custom_minimum_size.x = 560
		cv.add_child(_label(tr(Data.WEAPONS[w.id].name) + "  " + tr("LV %d") % w.lvl, 22))
		var bar := ColorRect.new(); bar.color = AMBER; bar.custom_minimum_size = Vector2(560 * w.dmg_total / maxd, 6)
		cv.add_child(bar)
		h.add_child(cv)
		h.add_child(_label(str(int(w.dmg_total)), 22, f_bold, TEXT))
		var cc := CenterContainer.new(); cc.add_child(h); v.add_child(cc)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 16)
	row.add_child(_button(tr("Play Again"), func(): main.start_run(world.char_id), 300))
	row.add_child(_button(tr("Main Menu"), func(): main.go_menu(), 300))
	v.add_child(row)
	_show("over")


# ================================================================= input
func _visible(name: String) -> bool:
	return screens.has(name) and is_instance_valid(screens[name]) and screens[name].visible


func _unhandled_input(event: InputEvent) -> void:
	if not capture.is_empty():
		return
	if _visible("settings"):
		var tab_d := 0
		if event is InputEventJoypadButton and event.pressed:
			tab_d = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
		elif event is InputEventKey and event.pressed and not event.echo:
			tab_d = -1 if event.physical_keycode == KEY_Q else (1 if event.physical_keycode == KEY_E else 0)
		if tab_d != 0:
			_settings_tab_step(tab_d)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		for n in ["chars", "shop", "ach", "journal"]:
			if _visible(n):
				show_menu()
				get_viewport().set_input_as_handled()
				return
		if _visible("settings"):
			_settings_back()
			get_viewport().set_input_as_handled()
	if current == "level":
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.physical_keycode - KEY_1
			if k >= 0 and k < world.choices.size():
				_pick_card(k)
		if event.is_action_pressed("reroll") and world.P.rerolls > 0:
			world.reroll()
			show_level()


# ================================================================= achievements toast
func _build_ach_toast() -> void:
	if ach_panel and is_instance_valid(ach_panel):
		ach_panel.queue_free()
	ach_panel = PanelContainer.new()
	ach_panel.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.1, 0.95), GOLD, 2, 14, Color(1, 0.8, 0.3, 0.35), 14))
	_place(ach_panel, 1, 1, 20, -150, 460, 110)
	ach_panel.custom_minimum_size = Vector2(460, 110)
	var v := VBoxContainer.new(); ach_panel.add_child(v)
	v.add_child(_label(tr("ACHIEVEMENT UNLOCKED"), 18, f_bold, GOLD))
	v.add_child(_label("", 30, f_head, TEXT))
	v.add_child(_label("", 20, f_body, MUTED))
	root.add_child(ach_panel)


func on_achievement(id: String) -> void:
	var a := Data.ach_by_id(id)
	var c := Data.char_unlocked_by(id)
	ach_queue.append([tr(a.name), (tr("New Keeper unlocked: %s") % tr(Data.CHARS[c].name)) if c != "" else tr(a.desc)])
	if not ach_busy:
		_next_ach()


func _next_ach() -> void:
	if ach_queue.is_empty():
		ach_busy = false
		return
	ach_busy = true
	var a: Array = ach_queue.pop_front()
	var v := ach_panel.get_child(0)
	(v.get_child(1) as Label).text = a[0]
	(v.get_child(2) as Label).text = a[1]
	Sfx.play("achievement")
	var tw := create_tween()
	tw.tween_property(ach_panel, "offset_left", -490.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ach_panel, "offset_right", -30.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(ach_panel, "offset_left", 20.0, 0.3)
	tw.parallel().tween_property(ach_panel, "offset_right", 480.0, 0.3)
	tw.tween_callback(_next_ach)


func clear_messages() -> void:
	for c in toast_box.get_children():
		toast_box.remove_child(c)
		c.queue_free()
	ach_queue.clear()
	banner_box.modulate.a = 0
