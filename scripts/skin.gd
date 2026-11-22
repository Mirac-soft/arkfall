extends RefCounted
## KOZMETİK ÇİZİMİ (v0.14): boya deseni ve arma bir SubViewport'ta uçak görselinin koordinatlarında (256 px, burun yukarıda)
## çizilir; skin.gdshader bunları uçağın kendi gölge/parlamasıyla birleştirir (boyanmış gibi durur). İz ve alev stilleri de burada.
## Kullanım: var mat = Skin.material(host, plane_id)  -> host'a görünmez çizim alanları eklenir, oyuncu sprite'ına verilir.

const F := 256
const NUMS := {"serce": "07", "dogan": "21", "simsek": "09", "kartal": "33", "anka": "01"}
static var _geo := {}

## Uçağın 3. (düz) karesinden ölçüler: kanat satırı, uçlar, burun, kuyruk, kanopi, gövde genişliği
static func geo(pid: String) -> Dictionary:
	if _geo.has(pid): return _geo[pid]
	var g := {"wy": 128.0, "wl": 60.0, "wr": 196.0, "cx": 128.0, "ty": 30.0, "by": 220.0, "cty": 70.0, "half": {}}
	var tex := Data.sheet("plane_" + pid)
	var im: Image = tex.get_image() if tex else null
	if im == null or im.is_empty(): _geo[pid] = g; return g
	if im.is_compressed(): im.decompress()
	im = im.get_region(Rect2i(im.get_width() / 7 * 3, 0, im.get_width() / 7, im.get_height()))
	if im.get_width() != F: im.resize(F, F)
	var A := func(x: int, y: int) -> float: return im.get_pixel(x, y).a
	var best := 0
	for y in range(40, 220):
		var l := -1; var r := -1
		for x in F:
			if A.call(x, y) > 0.4:
				if l < 0: l = x
				r = x
		if r - l > best: best = r - l; g.wy = float(y); g.wl = float(l); g.wr = float(r)
	g.cx = (g.wl + g.wr) / 2.0
	for y in range(F - 1, 0, -1):
		var hit := false
		for x in range(90, 166):
			if A.call(x, y) > 0.47: hit = true; break
		if hit: g.by = float(y); break
	for y in F:
		var hit := false
		for x in F:
			if A.call(x, y) > 0.4: hit = true; break
		if hit: g.ty = float(y); break
	var cty := F
	for y in range(int(g.ty), int(g.by)):
		var w := 0
		var x0 := int(g.cx)
		while x0 - w > 0 and A.call(x0 - w, y) > 0.4: w += 1
		var w2 := 0
		while x0 + w2 < F - 1 and A.call(x0 + w2, y) > 0.4: w2 += 1
		g.half[y] = (w + w2) / 2.0
		var c := im.get_pixel(x0, y)
		var mx := maxf(c.r, maxf(c.g, c.b)); var sat := (mx - minf(c.r, minf(c.g, c.b))) / maxf(mx, 0.001)
		if c.b >= mx - 0.001 and sat > 0.45 and c.get_luminance() < 0.6 and y < cty: cty = y
	g.cty = float(cty) if cty < F else g.ty + (g.by - g.ty) * 0.2
	_geo[pid] = g
	return g

static func half(g: Dictionary, y: float) -> float: return float(g.half.get(clampi(int(y), int(g.ty), int(g.by) - 1), 8.0))

## Ressam: bir deseni ya da armayı 256 px tuvale çizer
class Painter extends Node2D:
	var it: Dictionary
	var pid := ""
	var decal := false
	var g: Dictionary
	var rng := RandomNumberGenerator.new()
	func rnd() -> float: return rng.randf()
	func hy(y: float) -> float: return float(g.half.get(clampi(int(y), int(g.ty), int(g.by) - 1), 8.0))
	func quad(a: Vector2, c: Vector2, b: Vector2, n := 10) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in n + 1:
			var t := i / float(n)
			out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
		return out
	func blobs(col: Color, n: int, r: float) -> void:
		for i in n:
			var c := Vector2(rnd() * F, rnd() * F)
			var pts := PackedVector2Array()
			var a := 0.0
			while a < TAU:
				var rr := r * (0.6 + rnd() * 0.8); pts.append(c + Vector2(cos(a) * rr * 1.5, sin(a) * rr)); a += 0.45
			draw_colored_polygon(pts, col)
	func star8(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 16:
			var a := k * PI / 8.0; var rr := r * 0.55 if k % 2 else r
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		return pts
	func _draw() -> void:
		rng.seed = hash(it.n)
		if decal: _decal(); return
		var a: Color = it.c[0]; var b: Color = it.c[1]; var d: Color = it.c[2] if it.c.size() > 2 else b
		draw_rect(Rect2(0, 0, F, F), a)
		match it.k:
			"blob": draw_rect(Rect2(0, 0, F, F), b); blobs(a, 20, 24); blobs(d, 14, 16); blobs(a, 10, 10)
			"splinter":
				for pair in [[b, 14], [d, 10]]:
					for i in pair[1]:
						var c := Vector2(rnd() * F, rnd() * F); var an := rnd() * PI; var L := 30.0 + rnd() * 50.0; var W := 10.0 + rnd() * 16.0
						var u := Vector2(cos(an), sin(an)); var n := Vector2(-u.y, u.x)
						draw_colored_polygon(PackedVector2Array([c - u * L, c - n * W, c + u * L * 0.8, c + n * W * 0.6]), pair[0])
			"pixel":
				for y in range(0, F, 6):
					for x in range(0, F, 6):
						var v := sin(x * 0.05 + sin(y * 0.07) * 2.0) + sin(y * 0.045 + x * 0.02) + (rnd() - 0.5) * 0.8
						draw_rect(Rect2(x, y, 6, 6), d if v > 0.7 else (b if v > -0.2 else a))
			"waves":
				for k in 9:
					var y0 := k * 30.0 + 6.0
					var top := PackedVector2Array(); var bot := PackedVector2Array()
					for x in range(0, F + 4, 4):
						top.append(Vector2(x, y0 + sin(x * 0.05 + k) * 8.0)); bot.append(Vector2(x, y0 + 9.0 + sin(x * 0.05 + k + 0.6) * 8.0))
					bot.reverse(); draw_colored_polygon(top + bot, b); draw_polyline(top, d, 2.0)
			"ghost":
				blobs(b, 18, 20)
				var y := 20.0
				while y < F:
					var x := fmod(y / 44.0, 2.0) * 22.0 + 10.0
					while x < F:
						draw_set_transform(Vector2(x, y), -0.25)
						var body := PackedVector2Array()
						for k in 9: body.append(Vector2(cos(PI + k * PI / 8.0), sin(PI + k * PI / 8.0)) * 9.0)
						body.append(Vector2(9, 10))
						for k in 4: body.append(Vector2(9.0 - (k + 0.5) * 4.5, 10.0 if k % 2 else 6.0))
						body.append(Vector2(-9, 10))
						draw_colored_polygon(body, Color(d, 0.55))
						draw_circle(Vector2(-3.5, 0), 2.0, a); draw_circle(Vector2(3.5, 0), 2.0, a)
						draw_set_transform(Vector2.ZERO)
						x += 44.0
					y += 44.0
			"tiger":
				for i in 16:
					var y := 10.0 + i * 16.0 + rnd() * 6.0; var side := 1.0 if i % 2 else -1.0; var x0 := 0.0 if side < 0 else float(F); var L := 50.0 + rnd() * 50.0
					var pts := quad(Vector2(x0, y - 5), Vector2(x0 - side * L * 0.6, y - 8 + rnd() * 10), Vector2(x0 - side * L, y + 4))
					pts.append_array(quad(Vector2(x0 - side * L, y + 4), Vector2(x0 - side * L * 0.5, y + 4), Vector2(x0, y + 6)))
					draw_colored_polygon(pts, b)
				blobs(Color(d, 0.4), 6, 6)
			"claw":
				blobs(Color("1e2618"), 10, 22)
				for i in 6:
					var p := Vector2(30 + rnd() * 196, 30 + rnd() * 196); var an := -0.9 + rnd() * 0.5
					for k in 3:
						draw_set_transform(p + Vector2(cos(an + 1.57), sin(an + 1.57)) * k * 9.0, an)
						var pts := quad(Vector2(-26, 0), Vector2(0, -4), Vector2(26, 0)); pts.append_array(quad(Vector2(26, 0), Vector2(0, 1.5), Vector2(-26, 0)))
						draw_colored_polygon(pts, b)
					draw_set_transform(Vector2.ZERO)
			"bolts":
				blobs(Color("262a34"), 10, 22)
				for i in 9:
					var p := Vector2(rnd() * F, rnd() * F); var pts := PackedVector2Array([p])
					for k in 6: p += Vector2((rnd() - 0.5) * 28.0, 8.0 + rnd() * 10.0); pts.append(p)
					draw_polyline(pts, b, 6.0); draw_polyline(pts, d, 2.0)
			"circuit":
				for i in 34:
					var p := Vector2(round(rnd() * 32) * 8, round(rnd() * 32) * 8); var pts := PackedVector2Array([p])
					for k in 3:
						if rnd() < 0.5: p.x += (-1.0 if rnd() < 0.5 else 1.0) * 24.0
						else: p.y += (-1.0 if rnd() < 0.5 else 1.0) * 24.0
						pts.append(p)
					draw_polyline(pts, b, 2.0); draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), d)
			"flames":
				var top: float = g.ty
				for i in range(-4, 5):
					var x0: float = g.cx + i * 7.0; var L := 60.0 + (4 - absi(i)) * 22.0 + rnd() * 20.0
					var pts := quad(Vector2(x0 - 6, top), Vector2(x0 - 10 + i * 3, top + L * 0.6), Vector2(x0 + i * 6, top + L))
					pts.append_array(quad(Vector2(x0 + i * 6, top + L), Vector2(x0 + 6 + i * 2, top + L * 0.5), Vector2(x0 + 6, top)))
					var cols := PackedColorArray()
					for q in pts: cols.append(d.lerp(b, clampf((q.y - top) / L * 1.6, 0, 1)) * Color(1, 1, 1, clampf(1.6 - (q.y - top) / L * 1.6, 0, 1)))
					draw_polygon(pts, cols)
				for sx in [-1.0, 1.0]:
					for k in 4:
						var x0: float = g.cx + sx * (18.0 + k * 16.0); var y0: float = g.wy - 14.0 + k * 6.0; var L := 40.0 - k * 6.0
						var pts := quad(Vector2(x0, y0), Vector2(x0 + sx * L * 0.7, y0 + 4), Vector2(x0 + sx * L, y0 + 16))
						pts.append_array(quad(Vector2(x0 + sx * L, y0 + 16), Vector2(x0 + sx * L * 0.4, y0 + 12), Vector2(x0, y0 + 10)))
						draw_colored_polygon(pts, d if k % 2 else b)
			"hex":
				var r := 13.0; var h := r * sqrt(3.0)
				for row in range(-1, int(F / h) + 2):
					for col in range(-1, int(F / (r * 1.5)) + 2):
						var c := Vector2(col * r * 1.5, row * h + (h / 2.0 if col % 2 else 0.0))
						var pts := PackedVector2Array()
						for k in 7: pts.append(c + Vector2(cos(k * 1.047), sin(k * 1.047)) * r)
						if rnd() < 0.25: draw_colored_polygon(pts.slice(0, 6), d)
						draw_polyline(pts, b, 1.6)
			"feather":
				var y := -10.0
				while y < F + 20:
					var x := fmod(y / 13.0, 2.0) * 9.0 - 10.0
					while x < F + 20:
						var pts := quad(Vector2(x - 9, y - 8), Vector2(x, y + 14), Vector2(x + 9, y - 8))
						var cols := PackedColorArray()
						for q in pts: cols.append(d.lerp(b, clampf((q.y - y + 12) / 18.0, 0, 1)))
						draw_polygon(pts, cols); draw_polyline(pts, a, 1.2)
						x += 18.0
					y += 13.0
			"candy":
				var pts := PackedVector2Array([Vector2(0, 0), Vector2(F, 0), Vector2(F, F), Vector2(0, F)])
				var t0 := clampf(g.ty / F, 0, 1); var b0 := clampf(g.by / F, 0, 1)
				draw_polygon(pts, PackedColorArray([b.lerp(a, t0 * 0.3), b.lerp(a, t0 * 0.3), a, a]))
				var mid := (t0 + b0) / 2.0
				draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(F, 0), Vector2(F, mid * F), Vector2(0, mid * F)]), PackedColorArray([b, b, a, a]))
			"legend":
				var y := 0.0
				while y < F + 40:
					var x := fmod(y / 34.0, 2.0) * 17.0
					while x < F + 40:
						var s := star8(Vector2(x, y), 13.0); s.append(s[0]); draw_polyline(s, b, 1.6)
						x += 34.0
					y += 34.0
	func _decal() -> void:
		var a: Color = it.c[0]; var b: Color = it.c[1]
		var span: float = (g.wr - g.wl) / 2.0; var L: float = g.by - g.ty; var cx: float = g.cx; var wy: float = g.wy
		match it.k:
			"number":
				var fs := int(span * 0.32)
				var txt: String = NUMS.get(pid, "07")
				var w := Data.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(Data.font_bold, Vector2(cx + span * 0.55 - w / 2.0, wy + 4 + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, a)
				var yb: float = g.by - L * 0.2; var hw := hy(g.by - L * 0.18)
				draw_rect(Rect2(cx - hw - 2, yb, hw * 2 + 4, L * 0.035), a)
			"chevron":
				for sx in [-1.0, 1.0]:
					for pair in [[0, a], [1, b], [2, a]]:
						var x0: float = cx + sx * span * 0.3; var x1: float = cx + sx * span * 0.85; var y: float = wy - 4 + pair[0] * span * 0.09
						draw_polyline(PackedVector2Array([Vector2(x0, y + span * 0.14), Vector2((x0 + x1) / 2.0, y), Vector2(x1, y + span * 0.14)]), pair[1], span * 0.07)
			"bands":
				for sx in [-1.0, 1.0]:
					for k in 5:
						draw_set_transform(Vector2(cx + sx * (span * 0.25 + k * span * 0.07), wy), sx * 0.5)
						draw_rect(Rect2(-span * 0.035, -span * 0.5, span * 0.07, span), b if k % 2 else a)
					draw_set_transform(Vector2.ZERO)
			"rings":
				for sx in [-1.0, 1.0]:
					for pair in [[1.0, a], [0.72, b], [0.45, a], [0.18, b]]: draw_circle(Vector2(cx + sx * span * 0.6, wy + 3), span * 0.2 * pair[0], pair[1])
			"shark":
				var y0: float = g.ty + L * 0.07; var w := hy(g.ty + L * 0.12) * 1.05 + 2.0; var hg := maxf(6.0, (g.cty - y0) * 0.75)
				var m := quad(Vector2(cx - w, y0 + hg * 0.2), Vector2(cx, y0 + hg * 1.5), Vector2(cx + w, y0 + hg * 0.2))
				m.append_array(quad(Vector2(cx + w, y0 + hg * 0.2), Vector2(cx, y0 + hg * 0.6), Vector2(cx - w, y0 + hg * 0.2)))
				draw_colored_polygon(m, a)
				for k in range(-3, 4):
					var x := cx + k * w / 3.6; var yy := y0 + hg * (0.45 + 0.45 * (1.0 - absi(k) / 3.5))
					draw_colored_polygon(PackedVector2Array([Vector2(x - w / 9, yy - hg * 0.25), Vector2(x + w / 9, yy - hg * 0.25), Vector2(x, yy + hg * 0.05)]), b)
				for sx in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([Vector2(cx + sx * span * 0.45, wy - 8), Vector2(cx + sx * span * 0.7, wy + 4), Vector2(cx + sx * span * 0.42, wy + 6)]), Color("1a1d22"))
			"eyes":
				var y: float = (g.ty + g.cty) / 2.0 + 2.0; var w := hy(y)
				for sx in [-1.0, 1.0]:
					var p := Vector2(cx + sx * w * 0.55, y); var r := maxf(3.0, w * 0.5)
					draw_set_transform(p, sx * 0.5, Vector2(1.2, 0.85)); draw_circle(Vector2.ZERO, r, b)
					draw_set_transform(p, sx * 0.5, Vector2(0.95, 0.65)); draw_circle(Vector2.ZERO, r, a)
					draw_set_transform(p + Vector2(sx * r * 0.15, 0), 0.0, Vector2(0.28, 0.55)); draw_circle(Vector2.ZERO, r, b)
					draw_set_transform(Vector2.ZERO)
			"boltnose":
				var p := Vector2(cx, g.ty + 4); var pts := PackedVector2Array([p]); var y: float = p.y
				while y < g.by - 8:
					y += L * 0.12
					pts.append(Vector2(cx + (1.0 if pts.size() % 2 else -1.0) * hy(minf(y, g.by - 1)) * 0.55, y))
				draw_polyline(pts, b, 7.0); draw_polyline(pts, a, 4.0)
				for sx in [-1.0, 1.0]:
					draw_polyline(PackedVector2Array([Vector2(cx + sx * span * 0.25, wy - 6), Vector2(cx + sx * span * 0.5, wy + 2), Vector2(cx + sx * span * 0.45, wy + 4), Vector2(cx + sx * span * 0.8, wy + 12)]), a, 3.0)
			"shield":
				for sx in [-1.0, 1.0]:
					var p := Vector2(cx + sx * span * 0.58, wy + 2); var r := span * 0.2
					var sh := func(k: float) -> PackedVector2Array: return PackedVector2Array([p + Vector2(-r, -r * 0.9) * k, p + Vector2(r, -r * 0.9) * k, p + Vector2(r, r * 0.1) * k, p + Vector2(0, r * 1.1) * k, p + Vector2(-r, r * 0.1) * k])
					draw_colored_polygon(sh.call(1.0), b); draw_colored_polygon(sh.call(0.78), a); draw_colored_polygon(star8(p - Vector2(0, r * 0.05), r * 0.42), b)
			"phoenix":
				for sx in [-1.0, 1.0]:
					for k in 6:
						var x0: float = cx + sx * span * 0.18; var y0: float = wy - 6 + k * 2.5; var L2: float = span * (0.85 - k * 0.1)
						var pts := quad(Vector2(x0, y0), Vector2(x0 + sx * L2 * 0.6, y0 - 8 + k * 2), Vector2(x0 + sx * L2, y0 + 6 + k * 3))
						pts.append_array(quad(Vector2(x0 + sx * L2, y0 + 6 + k * 3), Vector2(x0 + sx * L2 * 0.5, y0 + 6), Vector2(x0, y0 + 5)))
						var cols := PackedColorArray()
						for q in pts: cols.append(b.lerp(a, clampf(absf(q.x - x0) / L2, 0, 1)))
						draw_polygon(pts, cols)
			"legend":
				for sx in [-1.0, 1.0]:
					var p := Vector2(cx + sx * span * 0.58, wy + 3); var r := span * 0.17
					draw_colored_polygon(star8(p, r), it.c[2]); draw_colored_polygon(star8(p, r * 0.55), it.c[0])

## Görünmez çizim alanı: tek seferlik çizer, dokusu gölgelendiriciye gider
static func _canvas(host: Node, pid: String, it: Dictionary, decal: bool) -> Texture2D:
	var vp := SubViewport.new(); vp.size = Vector2i(F, F); vp.transparent_bg = true; vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var p := Painter.new(); p.it = it; p.pid = pid; p.decal = decal; p.g = geo(pid)
	vp.add_child(p); host.add_child(vp)
	return vp.get_texture()

## Oyuncu / önizleme malzemesi: dış çizgi + boya + arma (skin.gdshader)
static func material(host: Node, pid: String, frames := 7, line_col := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = load("res://scripts/skin.gdshader")
	m.set_shader_parameter("frames", float(frames)); m.set_shader_parameter("line_col", line_col)
	var g := geo(pid); m.set_shader_parameter("cx", g.cx / F)
	var paint := Save.equipped(pid, "boya"); var arma := Save.equipped(pid, "arma")
	if not paint.is_empty():
		m.set_shader_parameter("pat", _canvas(host, pid, paint, false)); m.set_shader_parameter("has_pat", 1.0)
		m.set_shader_parameter("base_col", paint.c[0])
		var shiny: bool = paint.k == "candy" or paint.k == "legend"
		m.set_shader_parameter("shine", 1.0 if shiny else 0.0); m.set_shader_parameter("gloss", 1.0 if paint.k == "candy" else 0.55)
		m.set_shader_parameter("star_glow", 1.0 if paint.k == "legend" else 0.0)
		if shiny: m.set_shader_parameter("glow_col", Color(paint.c[1], 1.0)); m.set_shader_parameter("width", 3.0)
	if not arma.is_empty(): m.set_shader_parameter("dec", _canvas(host, pid, arma, true)); m.set_shader_parameter("has_dec", 1.0)
	return m

## İz ve alevin renkleri: kendi renkleri, ya da ayar açıksa boyanın renkleri
static func colors(pid: String, slot: String) -> Array:
	var it := Save.equipped(pid, slot); var paint := Save.equipped(pid, "boya")
	if Save.skin_match and not paint.is_empty() and paint.has("m"): return paint.m
	return it.c if not it.is_empty() else []
static func style(pid: String, slot: String) -> String:
	var it := Save.equipped(pid, slot)
	if it.is_empty(): return ""
	return "stars" if it.k == "legend" and slot == "iz" else it.k

## Kuyruk izi: kanat uçlarının geçtiği noktalar (dünya koordinatı), stile göre çizilir
class TrailFx extends Node2D:
	var kind := "contrail"
	var c0 := Color.WHITE
	var c1 := Color.WHITE
	var pts := [[], []]
	var sp := []
	var t := 0.0
	const LIFE := 0.9
	func push(tips: Array, dt: float, on: bool, scroll := Vector2.ZERO) -> void:
		t += dt
		for i in 2:
			var P: Array = pts[i]
			for p in P: p.a += dt; p.p += scroll * dt
			if on:
				var off := Vector2.ZERO
				var side: Vector2 = tips[2] if tips.size() > 2 else Vector2.RIGHT
				match kind:
					"wave": off = side * sin(t * 9.0) * 7.0
					"zigzag": off = side * randf_range(-5.0, 5.0)
				P.push_front({"p": tips[i] + off, "a": 0.0, "h": sin(t * 14.0) * 6.0})
			while not P.is_empty() and P[-1].a > (1.4 if kind == "smoke" else LIFE): P.pop_back()
			if on and kind in ["comet", "stars", "embers"] and randf() < (0.8 if kind == "embers" else 0.45):
				sp.append({"p": tips[i] + Vector2(randf_range(-3, 3), randf_range(-3, 3)), "v": Vector2(randf_range(-35, 35), randf_range(-35, 35)), "a": 0.0, "life": 1.2 if kind == "embers" else 0.7})
		for s in sp: s.a += dt; s.p += (s.v + scroll) * dt
		sp = sp.filter(func(s): return s.a < s.life)
		queue_redraw()
	func _line(P: Array, w: float, col: Color, alpha: float, helix := 0.0) -> void:
		for i in range(1, P.size()):
			var p: Dictionary = P[i]; var q: Dictionary = P[i - 1]
			var f := maxf(0.0, 1.0 - p.a / LIFE)
			if kind == "dash" and int(p.a * 9.0) % 2 == 1: continue
			var c := col
			if kind == "ribbon": c = c0 if i % 6 < 3 else c1
			if kind == "stars": c = Color.from_hsv(fmod(p.a * 0.35 + t * 0.15, 1.0), 0.6, 1.4)
			var side: Vector2 = (p.p - q.p).orthogonal().normalized()
			draw_line(q.p + side * q.h * helix, p.p + side * p.h * helix, Color(c, f * alpha), w * (0.4 + f * 0.6))
	func _draw() -> void:
		for P in pts:
			if P.size() < 2: continue
			match kind:
				"smoke":
					for i in range(0, P.size(), 2):
						var p: Dictionary = P[i]; draw_circle(p.p, 3.0 + p.a * 14.0, Color(c0, 0.3 * (1.0 - p.a / 1.4)))
				"helix": _line(P, 2.6, c0, 0.85, 1.0); _line(P, 2.6, c1, 0.85, -1.0)
				"wave": _line(P, 4.0, c0, 0.85)
				"ribbon": _line(P, 7.0, c0, 0.8)
				"zigzag":
					var fl := 0.6 + 0.4 * sin(t * 30.0); _line(P, 5.0, c0, 0.35 * fl); _line(P, 2.0, c1, 0.95 * fl)
				"comet": _line(P.slice(0, 20), 12.0, c0, 0.25); _line(P.slice(0, 30), 4.0, c1, 0.9); _line(P, 2.0, c0, 0.5)
				"embers": _line(P, 1.6, c0, 0.4)
				"stars": _line(P, 4.0, c0, 0.8)
				"dash": _line(P, 2.6, c0, 0.8)
				_: _line(P, 2.2, c0, 0.45)
		for s in sp:
			var a: float = 1.0 - s.a / s.life
			if kind == "stars":
				var pts8 := PackedVector2Array()
				for k in 16: pts8.append(s.p + Vector2(cos(k * PI / 8.0 + s.a * 4.0), sin(k * PI / 8.0 + s.a * 4.0)) * (2.0 if k % 2 else 5.0))
				draw_colored_polygon(pts8, Color(2.0, 1.8, 1.0, a))
			elif kind == "embers": draw_circle(s.p, 2.5, Color(c1, a))
			else: draw_rect(Rect2(s.p, Vector2(2.2, 2.2)), Color(c1, a))
