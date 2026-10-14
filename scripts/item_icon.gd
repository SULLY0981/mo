extends Control
class_name ItemIcon
## Vector-drawn icon for a weapon or relic, with optional level pips.

var id := ""
var level := 0
var max_level := 0
var show_pips := false
var glow := true


func setup(item_id: String, lvl := 0, show_level := false) -> ItemIcon:
	id = item_id
	level = lvl
	var def := Data.item_def(id)
	max_level = int(def.get("max", 0))
	show_pips = show_level
	queue_redraw()
	return self


func _draw() -> void:
	if id == "":
		return
	var def := Data.item_def(id)
	var col := Color(def.color)
	var s := minf(size.x, size.y - (8.0 if show_pips else 0.0))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.07, 0.14, 0.95)
	box.border_color = Color(col, 0.85)
	box.set_border_width_all(maxi(2, int(s / 26)))
	box.set_corner_radius_all(int(s * 0.2))
	box.shadow_color = Color(col, 0.25)
	box.shadow_size = int(s * 0.12)
	draw_style_box(box, Rect2(Vector2.ZERO, Vector2(s, s)))
	var k := s / 64.0
	var c := Vector2(s / 2, s / 2)
	if glow:
		_glyph(c, k, Color(col, 0.22), 2.4)
	_glyph(c, k, col, 1.0)
	if show_pips and max_level > 0:
		var pw := (s - 4) / max_level
		for i in max_level:
			var on := i < level
			draw_rect(Rect2(2 + i * pw, s + 2, pw - 2, 4), Color("ffb347") if on else Color(1, 1, 1, 0.15))


func _glyph(c: Vector2, k: float, col: Color, wmul: float) -> void:
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
	var circ := func(x: float, y: float, r: float, a := 1.0): draw_circle(P.call(x, y), r * k + (wmul - 1) * 2 * k, Color(col, col.a * a))
	var ring := func(x: float, y: float, r: float, w: float, a := 1.0): draw_arc(P.call(x, y), r * k, 0, TAU, 40, Color(col, col.a * a), w * k * wmul, true)
	var line := func(pts: Array, w: float, closed := false):
		var arr := PackedVector2Array()
		for p in pts:
			arr.append(P.call(p[0], p[1]))
		if closed:
			arr.append(arr[0])
		draw_polyline(arr, col, w * k * wmul, true)
	var poly := func(pts: Array, a := 1.0):
		var arr := PackedVector2Array()
		for p in pts:
			arr.append(P.call(p[0], p[1]))
		if wmul > 1.0:
			arr.append(arr[0])
			draw_polyline(arr, Color(col, col.a * a), 6 * k * wmul, true)
		elif Geometry2D.triangulate_polygon(arr).is_empty():
			arr.append(arr[0])
			draw_polyline(arr, Color(col, col.a * a), 3 * k, true)
		else:
			draw_colored_polygon(arr, Color(col, col.a * a))
	match id:
		"bolt":
			circ.call(5, -5, 11)
			poly.call([[-3, 3], [-20, 20], [1, -10], [14, 4]], 0.6)
		"halo":
			ring.call(0, 0, 15, 4)
			for i in 3:
				var a := i / 3.0 * TAU
				circ.call(cos(a) * 15, sin(a) * 15, 6)
		"pulse":
			for r in [6, 13, 20]:
				ring.call(0, 0, r, 4, 1.2 - r / 22.0)
		"arc":
			poly.call([[6, -22], [-8, 2], [3, 2], [-6, 22], [10, -4], [-1, -4]])
		"scythe":
			var pts := []
			for i in 17:
				var a := lerpf(-2.4, 1.1, i / 16.0)
				pts.append([cos(a) * 18, sin(a) * 18])
			for i in 17:
				var a := lerpf(1.0, -2.2, i / 16.0)
				pts.append([6 + cos(a) * 13, -4 + sin(a) * 13])
			poly.call(pts)
		"mines":
			circ.call(0, 0, 10)
			for i in 8:
				var a := i / 8.0 * TAU
				line.call([[cos(a) * 12, sin(a) * 12], [cos(a) * 19, sin(a) * 19]], 4)
		"frost":
			for i in 3:
				var r := i / 3.0 * PI
				var rot := func(x: float, y: float) -> Array: return [x * cos(r) - y * sin(r), x * sin(r) + y * cos(r)]
				line.call([rot.call(0, -20), rot.call(0, 20)], 4)
				line.call([rot.call(-6, -14), rot.call(0, -8), rot.call(6, -14)], 4)
				line.call([rot.call(-6, 14), rot.call(0, 8), rot.call(6, 14)], 4)
		"vigor":
			var pts := []
			for i in 32:
				var t := i / 32.0 * TAU
				pts.append([16 * pow(sin(t), 3) * 1.1, -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) * 1.1 - 2])
			poly.call(pts)
		"swift":
			for x in [-10, 4]:
				line.call([[x, -14], [x + 12, 0], [x, 14]], 5)
		"might":
			poly.call([[0, -22], [9, -10], [12, 4], [8, 16], [0, 20], [-8, 16], [-12, 4], [-6, -4], [-3, 2], [-2, -8]])
		"haste":
			line.call([[-12, -18], [12, -18], [-12, 18], [12, 18]], 4, true)
			poly.call([[-6, 13], [6, 13], [0, 4]])
		"reach":
			circ.call(0, 0, 8)
			for i in 4:
				var r := i * PI / 2
				var rot := func(x: float, y: float) -> Array: return [x * cos(r) - y * sin(r), x * sin(r) + y * cos(r)]
				line.call([rot.call(0, -12), rot.call(0, -21)], 4)
				line.call([rot.call(-5, -16), rot.call(0, -21), rot.call(5, -16)], 4)
		"multi":
			for p in [[0, -11], [-11, 8], [11, 8]]:
				circ.call(p[0], p[1], 7)
		"magnet":
			draw_arc(P.call(0, 0), 12 * k, 0, PI, 24, col, 7 * k * wmul, true)
			line.call([[-12, 0], [-12, -14]], 7)
			line.call([[12, 0], [12, -14]], 7)
		"wisdom":
			var pts := []
			for i in 21:
				var x := lerpf(-20, 20, i / 20.0)
				pts.append([x, -sqrt(maxf(0, 1 - pow(x / 20.0, 2))) * 11])
			for i in 21:
				var x := lerpf(20, -20, i / 20.0)
				pts.append([x, sqrt(maxf(0, 1 - pow(x / 20.0, 2))) * 11])
			line.call(pts, 4, true)
			circ.call(0, 0, 6)
		"plating":
			poly.call([[0, -20], [17, -12], [15, 4], [8, 14], [0, 21], [-8, 14], [-15, 4], [-17, -12]])
		"renewal":
			poly.call([[-5, -18], [5, -18], [5, -5], [18, -5], [18, 5], [5, 5], [5, 18], [-5, 18], [-5, 5], [-18, 5], [-18, -5], [-5, -5]])
		"luck":
			for p in [[0, -8], [8, 0], [0, 8], [-8, 0]]:
				circ.call(p[0], p[1], 8)
		"light":
			line.call([[-9, -12], [9, -12], [12, 14], [-12, 14]], 4, true)
			circ.call(0, 2, 5)
			line.call([[-5, -12], [0, -19], [5, -12]], 4)
		"cinder":
			poly.call([[4, -22], [13, -6], [10, 6], [2, 12], [-6, 8], [-8, -2], [-3, 3], [-1, -9]])
			for x in [-20, -12]:
				line.call([[x, 10], [x + 7, 16], [x, 22]], 4)
