extends Node
## 3D MODEL STÜDYOSU: uçakları ve Vahar gemilerini 3D olarak kurar, ışıklandırır ve
## 7 yatış açısında yukarıdan çekip art/3d/<ad>.png sprite şeridine kaydeder.
## Çalıştır: godot --path . -- --scene=studio      (pencere açılır, iş bitince kapanır)
## Ölçek: 1 model birimi = SVG'deki 1 piksel; çıktı 2 kat çözünürlükte (oyunda scale 0.5).

var main
const ROLLS := 7
const MAX_ROLL := 55.0

# Oyuncu uçakları (make_art.js ile aynı plan ölçüleri)
const P := {
	"serce": {"main": "8fa3b5", "camo": "6c7f92", "acc": "4fd8ff", "k": 1.75, "fins": 1,
		"body": [[0, -26], [4, -16], [5.5, 4], [4.5, 15], [0, 19]], "wing": [[4.5, -5], [24, 8], [24, 13], [4.5, 11]],
		"extra": [[[3.5, 11], [11, 18], [11, 21], [3.5, 18]]], "cockpit": [0, -12, 2.8, 6.5], "eng": [[0, 20, 3.4]]},
	"dogan": {"main": "7d8f6a", "camo": "56653f", "acc": "57ff9a", "k": 1.65, "fins": 1,
		"body": [[0, -30], [4.5, -19], [6.5, 2], [5.5, 17], [0, 21]], "wing": [[5.5, 2], [27, -9], [29, -4], [6.5, 14]],
		"extra": [[[3.5, -16], [11, -13], [11, -10], [3.5, -10]], [[4.5, 13], [13, 21], [13, 24], [4.5, 21]]], "cockpit": [0, -15, 3, 6.5], "eng": [[0, 22, 4]]},
	"simsek": {"main": "c8c2a8", "camo": "9e9474", "acc": "ffe14f", "k": 1.55, "fins": 2,
		"body": [[0, -38], [3.4, -23], [4.5, 8], [3.4, 23], [0, 26]], "wing": [[3.4, -3], [22, 14], [22, 18], [4.5, 13]],
		"extra": [[[2.4, -20], [9, -12], [2.4, -12]], [[3.4, 15], [11, 26], [9, 28], [3.4, 24]]], "cockpit": [0, -19, 2.4, 7.5], "eng": [[-2.6, 27, 2.6], [2.6, 27, 2.6]]},
	"kartal": {"main": "7a6e62", "camo": "544a42", "acc": "ff9a3c", "k": 1.6, "fins": 2,
		"body": [[0, -29], [6.5, -19], [8.5, 8], [7.5, 21], [0, 24]], "wing": [[7.5, -8], [34, 9], [34, 15], [19, 15], [8.5, 13]],
		"extra": [[[6.5, 14], [18, 22], [18, 27], [6.5, 23]], [[22, -3], [26, -3], [26, 15], [22, 15]]], "cockpit": [0, -16, 3.6, 7.5], "eng": [[-4.8, 25, 3.6], [4.8, 25, 3.6]]},
	"anka": {"main": "3e2a4a", "camo": "2a1d33", "acc": "ff4fd8", "k": 1.55, "fins": 2, "gold": true,
		"body": [[0, -33], [5.5, -21], [6.5, 6], [4.5, 19], [0, 25]], "wing": [[5.5, -10], [21, -6], [38, 6], [32, 9], [39, 14], [28, 14], [32, 20], [19, 16], [6.5, 12]],
		"extra": [[[4.5, 15], [14, 28], [7.5, 26], [3.4, 23]]], "cockpit": [0, -18, 3.2, 7.5], "eng": [[-3.2, 26, 3.4], [3.2, 26, 3.4]]},
}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/3d"))
	var only: String = main.dev.get("only", "") if main else ""
	var jobs := []
	for id in P: jobs.append(["plane_" + id, _plane.bind(P[id]), 256, 256])
	jobs.append(["e_drone", _drone, 128, 128])
	jobs.append(["e_avci", _avci, 160, 160])
	jobs.append(["e_kamikaze", _kamikaze, 144, 144])
	jobs.append(["e_topcu", _topcu, 192, 192])
	jobs.append(["e_girdap", _girdap, 192, 192])
	jobs.append(["e_bombardiman", _bomber, 320, 256])
	for b in ["oncu", "indirme", "matkap", "goz", "hasat", "buz", "kizil_kanat", "firtina_kalesi", "ikiz", "kum", "ates", "emici", "enkaz", "varek"]: jobs.append(_boss_job(b, 512))
	jobs.append(_boss_job("sefine", 640))
	for j in jobs:
		if only != "" and not j[0].contains(only): continue
		await _render(j[0], j[1].call(), j[2], j[3])
		print("STUDIO ", j[0])
	get_tree().quit()

# ---------------- çekim ----------------
func _render(name: String, model: Node3D, w: int, h: int) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h); vp.transparent_bg = true; vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.55, 0.62, 0.75); env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 0.95
	env.ssao_enabled = true; env.ssao_radius = 2.0; env.ssao_intensity = 1.5
	we.environment = env; vp.add_child(we)
	var key := DirectionalLight3D.new(); key.light_energy = 1.7; key.shadow_enabled = true; key.light_color = Color(1.0, 0.96, 0.9)
	key.rotation_degrees = Vector3(-62, -35, 0); vp.add_child(key)
	var fill := DirectionalLight3D.new(); fill.light_energy = 0.6; fill.light_color = Color(0.6, 0.75, 1.0)
	fill.rotation_degrees = Vector3(-40, 150, 0); vp.add_child(fill)
	var rim := DirectionalLight3D.new(); rim.light_energy = 0.9; rim.light_color = Color(1.0, 0.9, 0.8)
	rim.rotation_degrees = Vector3(-15, 180, 0); vp.add_child(rim)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = h / 2.0
	cam.position = Vector3(0, 200, 0); cam.rotation_degrees = Vector3(-90, 0, 0); cam.far = 400.0
	vp.add_child(cam); cam.current = true
	vp.add_child(model)
	for i in 12: await RenderingServer.frame_post_draw # CSG ve gürültü dokuları hazırlansın
	var sheet := Image.create(w * ROLLS, h, false, Image.FORMAT_RGBA8)
	for i in ROLLS:
		model.rotation.z = deg_to_rad(-(i - 3) / 3.0 * MAX_ROLL)
		for f in 3: await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image(); img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	sheet.save_png("res://art/3d/%s.png" % name)
	vp.queue_free()

# ---------------- malzemeler ----------------
func _metal(c: Color, rough := 0.4, metal := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m
func _camo(a: Color, b: Color) -> StandardMaterial3D:
	var n := FastNoiseLite.new(); n.frequency = 0.035; n.fractal_octaves = 2; n.seed = randi()
	var g := Gradient.new(); g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.set_color(0, a); g.set_color(1, b); g.set_offset(1, 0.55)
	var t := NoiseTexture2D.new(); t.width = 256; t.height = 256; t.seamless = true; t.noise = n; t.color_ramp = g
	var m := _metal(Color.WHITE, 0.45, 0.45); m.albedo_texture = t
	m.uv1_triplanar = true; m.uv1_scale = Vector3(0.012, 0.012, 0.012)
	return m
func _glow(c: Color, e := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = e
	return m
func _glass() -> StandardMaterial3D:
	var m := _metal(Color(0.05, 0.14, 0.24), 0.05, 0.9); m.emission_enabled = true; m.emission = Color(0.1, 0.35, 0.5); m.emission_energy_multiplier = 0.4
	return m
func _pearl(c := Color(0.07, 0.085, 0.075)) -> StandardMaterial3D: # Vahar gövdesi: koyu çelik
	var m := _metal(c, 0.28, 0.6); m.clearcoat_enabled = true; m.clearcoat = 1.0; m.clearcoat_roughness = 0.1
	return m

# ---------------- yapı taşları ----------------
func _v2(a: Array, k: float, flip := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in a: out.append(Vector2((-p[0] if flip else p[0]) * k, p[1] * k))
	return out
## Dönel gövde (torna). profile: [[yarıçap, boy]] burun -y. flat: dikey basıklık
func _lathe(parent: Node, profile: Array, k: float, mat: Material, flat := 0.7, y := 0.0) -> CSGPolygon3D:
	var p := CSGPolygon3D.new(); p.mode = CSGPolygon3D.MODE_SPIN; p.spin_degrees = 360; p.spin_sides = 28; p.smooth_faces = true
	p.polygon = _v2(profile, k); p.material = mat
	p.rotation.x = PI / 2; p.scale = Vector3(1, 1, flat); p.position.y = y
	parent.add_child(p); return p
## Yatay plaka (kanat, kuyruk). Kalınlık aşağı doğru.
func _plate(parent: Node, poly: Array, k: float, mat: Material, thick := 1.2, y := 0.0, flip := false) -> CSGPolygon3D:
	var p := CSGPolygon3D.new(); p.mode = CSGPolygon3D.MODE_DEPTH; p.depth = thick; p.polygon = _v2(poly, k, flip); p.material = mat
	p.rotation.x = PI / 2; p.position.y = y
	parent.add_child(p); return p
## Dikey kuyruk dikmesi
func _fin(parent: Node, x: float, z0: float, z1: float, hgt: float, mat: Material, thick := 0.8) -> void:
	var p := CSGPolygon3D.new(); p.mode = CSGPolygon3D.MODE_DEPTH; p.depth = thick; p.material = mat
	p.polygon = PackedVector2Array([Vector2(z1, 0), Vector2(z0, 0), Vector2(z1 - 1.0, hgt), Vector2(z1, hgt)])
	p.rotation.y = -PI / 2; p.position = Vector3(x + thick / 2.0, 0, 0)
	parent.add_child(p)
func _box(parent: Node, a: Vector3, b: Vector3, w: float, h: float, mat: Material) -> void:
	var bx := CSGBox3D.new(); bx.size = Vector3(w, h, a.distance_to(b)); bx.material = mat
	bx.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) / 2.0)
	parent.add_child(bx)
func _sphere(parent: Node, pos: Vector3, r: float, mat: Material, sc := Vector3.ONE) -> void:
	var s := CSGSphere3D.new(); s.radius = r; s.radial_segments = 20; s.rings = 12; s.material = mat
	s.position = pos; s.scale = sc; parent.add_child(s)
func _cyl(parent: Node, pos: Vector3, r: float, length: float, mat: Material, along_z := true, sides := 16) -> void:
	var c := CSGCylinder3D.new(); c.radius = r; c.height = length; c.sides = sides; c.material = mat
	c.position = pos
	if along_z: c.rotation.x = PI / 2
	parent.add_child(c)
func _decal(parent: Node, pos: Vector3, size: float, tex: Texture2D) -> void:
	var d := Decal.new(); d.texture_albedo = tex; d.size = Vector3(size, 12, size); d.position = pos + Vector3(0, 4, 0)
	d.cull_mask = 1; parent.add_child(d)

# ---------------- oyuncu uçağı ----------------
func _plane(d: Dictionary) -> Node3D:
	var root := Node3D.new()
	var k: float = d.k
	var main := Color(d.main); var camo := Color(d.camo); var acc := Color(d.acc)
	var body := CSGCombiner3D.new(); root.add_child(body)
	var mb := _metal(main.darkened(0.08), 0.5, 0.45)
	var mc := _camo(main, camo)
	var dark := _metal(Color(0.13, 0.14, 0.16), 0.5, 0.7)
	_lathe(body, d.body, k, mb, 0.48, 0.0)
	for flip in [false, true]:
		_plate(body, d.wing, k, mc, 1.6, 0.6, flip)
		for e in d.extra: _plate(body, e, k, mc, 1.1, 0.4, flip)
		# kanat ön kenarı: parlayan şerit
		var w: Array = d.wing
		var sx := -1.0 if flip else 1.0
		_box(root, Vector3(w[0][0] * k * sx, 0.9, w[0][1] * k), Vector3(w[1][0] * k * sx, 0.9, w[1][1] * k), 0.9, 0.5, _glow(acc, 2.0))
		# kanat altı füze
		var cx: float = (w[0][0] + w[1][0] + w[2][0]) / 3.0 * k * sx
		var cz: float = (w[0][1] + w[1][1] + w[2][1]) / 3.0 * k
		_cyl(root, Vector3(cx, -1.2, cz), 1.3, 15.0, _metal(Color(0.88, 0.9, 0.93), 0.3, 0.3))
		_sphere(root, Vector3(cx, -1.2, cz - 7.5), 1.3, _glow(Color(1.0, 0.25, 0.3), 1.5))
		# nişan (lacivert disk + beyaz yıldız)
		_decal(root, Vector3(cx + sx * 4.0, 0, cz + 1.0), 9.0, load("res://art/roundel.svg"))
		# kanat ucu seyir ışığı
		var tip: Array = w.reduce(func(a, b): return b if b[0] > a[0] else a)
		_sphere(root, Vector3(tip[0] * k * sx, 0.6, tip[1] * k), 0.9, _glow(Color(1, 0.2, 0.2) if flip else Color(0.2, 1, 0.3), 4.0))
	# kuyruk dikmeleri
	var tail: float = d.body[3][1] * k
	if d.fins == 1: _fin(root, 0.0, tail - 14.0, tail + 2.0, 9.0, mb)
	else:
		for sx in [-1.0, 1.0]: _fin(root, sx * 4.5 * k / 1.6, tail - 12.0, tail + 3.0, 8.0, mb)
	# kokpit camı
	var c: Array = d.cockpit
	_sphere(root, Vector3(0, 1.8, c[1] * k), c[2] * k * 0.85, _glass(), Vector3(1.0, 0.7, c[3] / c[2]))
	_sphere(root, Vector3(-c[2] * k * 0.3, 2.9, (c[1] - c[3] * 0.35) * k), c[2] * k * 0.22, _glow(Color(0.85, 0.95, 1.0), 1.2), Vector3(1, 0.4, 1.8)) # cam parlaması
	# motor nozulları
	for e in d.eng:
		_cyl(root, Vector3(e[0] * k, 0, e[1] * k + 1.5), e[2] * k, 5.0, dark)
		_cyl(root, Vector3(e[0] * k, 0, e[1] * k + 4.2), e[2] * k * 0.62, 0.6, _glow(Color(1.0, 0.55, 0.2), 4.0))
	if d.get("gold", false): # Anka: altın çizgiler
		_box(root, Vector3(0, 2.6, d.body[0][1] * k + 4), Vector3(0, 2.6, tail), 1.2, 0.6, _glow(Color(1.0, 0.8, 0.3), 1.5))
	return root

# ---------------- Vahar gemileri (inci gövde, parlayan derzler) ----------------
func _drone() -> Node3D:
	var r := Node3D.new(); var pearl := _pearl(); var vio := _glow(Color(1.0, 0.25, 0.1), 4.5)
	var hull := CSGPolygon3D.new(); hull.mode = CSGPolygon3D.MODE_SPIN; hull.spin_sides = 24; hull.smooth_faces = true
	hull.polygon = PackedVector2Array([Vector2(0, -6), Vector2(10, -4), Vector2(13, 0), Vector2(10, 4), Vector2(0, 6)]); hull.material = pearl
	r.add_child(hull)
	for i in 3:
		var a := -PI / 2 + i * TAU / 3.0
		var tip := Vector3(cos(a) * 21.0, 0, sin(a) * 21.0)
		_box(r, Vector3.ZERO, tip, 3.0, 2.0, _metal(Color(0.08, 0.06, 0.08), 0.4, 0.7))
		_sphere(r, tip, 5.0, pearl, Vector3(1, 0.5, 1))
		_sphere(r, tip + Vector3(0, 1.5, 0), 2.2, vio)
	_sphere(r, Vector3(0, 4, 0), 5.0, vio, Vector3(1, 0.6, 0.8))
	return r
func _avci() -> Node3D:
	var r := Node3D.new(); var pearl := _pearl(); var pink := _glow(Color(1.0, 0.15, 0.55), 4.0)
	_lathe(r, [[0, -36], [4, -20], [6.5, 10], [0, 24]], 1.0, pearl, 0.6)
	for flip in [false, true]:
		_plate(r, [[6, -8], [26, -4], [36, 10], [30, 26], [22, 16], [14, 14], [7, 16]], 1.0, pearl, 1.4, 0.4, flip)
		var sx := -1.0 if flip else 1.0
		_box(r, Vector3(10 * sx, 0.9, -4), Vector3(30 * sx, 0.9, 18), 1.0, 0.5, pink)
	_sphere(r, Vector3(0, 2.5, -12), 3.2, pink, Vector3(1, 0.6, 2.4))
	for sx in [-4.0, 4.0]: _sphere(r, Vector3(sx, 0, 22), 2.6, _glow(Color(1.0, 0.25, 0.1), 4.5))
	return r
func _kamikaze() -> Node3D:
	var r := Node3D.new(); var pearl := _pearl(); var yel := _glow(Color(1.0, 0.85, 0.2), 3.0)
	_lathe(r, [[0, -36], [7, -8], [5.5, 22], [0, 17]], 1.0, pearl, 0.8)
	for flip in [false, true]: _plate(r, [[5, 2], [17, 28], [5, 19]], 1.0, pearl, 1.0, 0.0, flip)
	for z in [-14.0, -4.0, 6.0]: _cyl(r, Vector3(0, 0, z), 6.2, 1.6, yel)
	_sphere(r, Vector3(0, 0, -30), 3.0, yel)
	_sphere(r, Vector3(0, 0, 18), 3.2, _glow(Color(1.0, 0.6, 0.2), 4.0))
	return r
func _topcu() -> Node3D:
	var r := Node3D.new(); var pearl := _pearl(); var teal := _glow(Color(0.65, 1.0, 0.15), 4.0)
	_cyl(r, Vector3.ZERO, 30.0, 9.0, pearl, false, 6)
	_cyl(r, Vector3(0, 3.0, 0), 21.0, 5.0, _metal(Color(0.07, 0.05, 0.07), 0.4, 0.7), false, 6)
	for sx in [-11.0, 11.0]:
		_cyl(r, Vector3(sx, 3.0, -30), 3.0, 28.0, _metal(Color(0.2, 0.18, 0.2), 0.3, 0.7))
		_sphere(r, Vector3(sx, 3.0, -44), 2.6, teal)
	for i in 6:
		var a := PI / 6 + i * PI / 3
		_sphere(r, Vector3(cos(a) * 25.0, 4.0, sin(a) * 25.0), 2.0, teal)
	_sphere(r, Vector3(0, 6, 0), 7.0, teal, Vector3(1, 0.6, 1))
	return r
func _girdap() -> Node3D:
	var r := Node3D.new(); var pearl := _pearl(); var vio := _glow(Color(1.0, 0.2, 0.5), 4.0)
	for i in 3:
		var holder := Node3D.new(); holder.rotation.y = i * TAU / 3.0; r.add_child(holder)
		_plate(holder, [[6, -8], [20, -24], [36, -22], [44, -10], [40, 12], [30, 0], [18, -4], [8, 6]], 1.0, pearl, 2.0, 1.0)
		_box(holder, Vector3(14, 1.5, -14), Vector3(38, 1.5, -8), 1.4, 0.6, vio)
	_sphere(r, Vector3.ZERO, 14.0, pearl, Vector3(1, 0.6, 1))
	_sphere(r, Vector3(0, 6, 0), 8.0, vio, Vector3(1, 0.5, 1))
	return r
func _bomber() -> Node3D:
	var r := Node3D.new(); var pearl := _pearl(); var blue := _glow(Color(1.0, 0.5, 0.1), 4.0)
	for flip in [false, true]:
		_plate(r, [[0, -52], [30, -44], [60, -10], [74, 14], [60, 20], [44, 14], [30, 24], [18, 30], [0, 26]], 1.0, pearl, 2.0, 0.0, flip)
		_plate(r, [[10, -36], [30, -30], [48, -8], [40, 8], [24, 10], [10, 14]], 1.0, _metal(Color(0.06, 0.05, 0.07), 0.4, 0.6), 0.6, 0.5, flip)
		var sx := -1.0 if flip else 1.0
		_box(r, Vector3(16 * sx, 1.0, -40), Vector3(70 * sx, 1.0, 12), 1.4, 0.8, blue)
		for x in [28.0, 48.0]:
			_sphere(r, Vector3(x * sx, 1.0, 14), 6.5, _metal(Color(0.08, 0.06, 0.08), 0.4, 0.7), Vector3(1, 0.6, 1.3))
			_sphere(r, Vector3(x * sx, 3.0, 16), 3.5, blue)
	_lathe(r, [[0, -42], [10, -26], [13, 14], [0, 20]], 1.0, pearl, 0.6, 2.0)
	_sphere(r, Vector3(0, 7, -16), 5.0, _glow(Color(1.0, 0.25, 0.1), 4.5), Vector3(1, 0.5, 1.8))
	return r

# ================= 3D BOSSLAR (Starblast esinli: köşeli gövdeler, neon paneller) =================
func _hullf(parent: Node, profile: Array, mat: Material, sides := 6, flat := 0.55, y := 0.0) -> CSGPolygon3D:
	var p := _lathe(parent, profile, 1.0, mat, flat, y); p.spin_sides = sides; p.smooth_faces = false # köşeli (fasetli)
	return p
func _turret(parent: Node, pos: Vector3, r: float, glow: Material) -> void:
	_cyl(parent, pos, r, r * 0.8, _metal(Color(0.12, 0.1, 0.12), 0.35, 0.8), false, 8)
	_box(parent, pos + Vector3(0, r * 0.4, 0), pos + Vector3(0, r * 0.4, -r * 2.2), r * 0.45, r * 0.45, _metal(Color(0.25, 0.22, 0.25), 0.3, 0.8))
	_sphere(parent, pos + Vector3(0, r * 0.4, -r * 2.2), r * 0.3, glow)
func _engine(parent: Node, pos: Vector3, r: float, glow: Material, len := 18.0) -> void:
	_cyl(parent, pos, r, len, _metal(Color(0.1, 0.09, 0.1), 0.4, 0.8), true, 10)
	_cyl(parent, pos + Vector3(0, 0, len / 2.0 + 0.4), r * 0.75, 0.8, glow)
func _strip(parent: Node, a: Vector3, b: Vector3, glow: Material, w := 2.0) -> void:
	_box(parent, a, b, w, 1.0, glow)
func _boss_job(name: String, size: int) -> Array:
	return ["b_" + name, Callable(self, "_b_" + name), size, size]

func _b_oncu() -> Node3D: # Öncü Avcı: hilal kanatlı av gemisi
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(0.9, 0.3, 1.0), 4.0)
	_hullf(r, [[0, -86], [14, -52], [18, 30], [10, 58], [0, 52]], h, 6)
	for f in [false, true]:
		var sx := -1.0 if f else 1.0
		_plate(r, [[10, -30], [60, -50], [112, -22], [116, 32], [92, 12], [60, 8], [16, 32]], 1.0, h, 4.0, 2.0, f)
		_plate(r, [[20, -24], [58, -38], [96, -16], [86, 4], [56, 2], [22, 16]], 1.0, _metal(Color(0.06, 0.04, 0.06), 0.4, 0.6), 1.0, 2.5, f)
		_strip(r, Vector3(20 * sx, 3, -28), Vector3(108 * sx, 3, -18), g)
		_turret(r, Vector3(70 * sx, 3, -6), 6.0, g)
	for x in [-9.0, 0.0, 9.0]: _engine(r, Vector3(x, 0, 52), 5.0, g, 12.0)
	_sphere(r, Vector3(0, 7, -36), 6.0, g, Vector3(1, 0.6, 2.4))
	return r
func _b_indirme() -> Node3D: # Kuşatma Gemisi: kutu gövde, bölmeler, dört motor
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(1.0, 0.35, 0.15), 4.0); var dk := _metal(Color(0.05, 0.04, 0.05), 0.5, 0.6)
	var b := CSGBox3D.new(); b.size = Vector3(190, 16, 210); b.material = h; r.add_child(b)
	var t := CSGBox3D.new(); t.size = Vector3(120, 10, 150); t.position = Vector3(0, 12, -6); t.material = h; r.add_child(t)
	for i in 3:
		for j in 2:
			var p := Vector3(-60 + i * 60, 18, -40 + j * 70)
			var bay := CSGBox3D.new(); bay.size = Vector3(40, 4, 50); bay.position = p; bay.material = dk; r.add_child(bay)
			_sphere(r, p + Vector3(0, 2, 0), 6.0, g)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]: _engine(r, Vector3(sx * 104, 0, sz * 70 + 20), 13.0, g, 50.0)
	_sphere(r, Vector3(0, 20, -84), 12.0, _glow(Color(1.0, 0.6, 0.2), 3.0), Vector3(2.2, 0.6, 1))
	return r
func _b_matkap() -> Node3D: # Matkap: dönen sivri uç + paletler
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(1.0, 0.55, 0.1), 4.0)
	var c := CSGCylinder3D.new(); c.cone = true; c.radius = 34; c.height = 80; c.sides = 10; c.material = _metal(Color(0.55, 0.5, 0.48), 0.25, 0.9)
	c.rotation.x = -PI / 2; c.position = Vector3(0, 6, -92); r.add_child(c)
	for i in 4: _cyl(r, Vector3(0, 6, -60 - i * 16), 30 - i * 6, 2.0, g)
	_hullf(r, [[0, -56], [42, -50], [48, 60], [30, 80], [0, 76]], h, 8, 0.6)
	for sx in [-1.0, 1.0]:
		var tr := CSGBox3D.new(); tr.size = Vector3(22, 18, 150); tr.position = Vector3(sx * 58, 0, 10); tr.material = _metal(Color(0.08, 0.07, 0.08), 0.6, 0.6); r.add_child(tr)
		for i in 7: _strip(r, Vector3(sx * 58 - 10, 10, -54 + i * 21), Vector3(sx * 58 + 10, 10, -54 + i * 21), g, 2.5)
	_sphere(r, Vector3(0, 22, 20), 14.0, g)
	return r
func _b_goz() -> Node3D: # Gözcü Kule: istasyon halkası + dev göz
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(0.2, 1.0, 0.8), 4.0)
	var ring := CSGTorus3D.new(); ring.inner_radius = 92; ring.outer_radius = 112; ring.sides = 8; ring.ring_sides = 6; ring.material = h; r.add_child(ring)
	for i in 6:
		var a := i * TAU / 6.0
		var p := Vector3(cos(a), 0, sin(a))
		_box(r, p * 40.0, p * 100.0, 12.0, 8.0, h)
		_turret(r, p * 102.0 + Vector3(0, 8, 0), 9.0, g)
	_hullf(r, [[0, -60], [60, -30], [60, 30], [0, 60]], h, 8, 0.5)
	_sphere(r, Vector3(0, 18, 0), 34.0, _glow(Color(0.9, 1.0, 0.95), 1.2), Vector3(1.3, 0.5, 0.8))
	_sphere(r, Vector3(0, 26, 0), 16.0, g, Vector3(1, 0.4, 1))
	_sphere(r, Vector3(0, 32, 0), 6.0, _metal(Color(0.02, 0.02, 0.02), 0.2, 0.2), Vector3(0.5, 0.4, 1.6))
	return r
func _b_hasat() -> Node3D: # Su Hasatçısı: daire gövde, toplayıcı kollar, girdap
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(0.4, 1.0, 0.4), 4.0)
	var s := CSGPolygon3D.new(); s.mode = CSGPolygon3D.MODE_SPIN; s.spin_sides = 12; s.smooth_faces = false
	s.polygon = PackedVector2Array([Vector2(0, -12), Vector2(96, -6), Vector2(108, 0), Vector2(96, 6), Vector2(0, 14)]); s.material = h; r.add_child(s)
	for i in 6:
		var a := i * TAU / 6.0
		var p := Vector3(cos(a), 0, sin(a))
		_box(r, p * 90.0, p * 140.0, 12.0, 10.0, h)
		_sphere(r, p * 146.0, 16.0, h, Vector3(1, 0.6, 1))
		_sphere(r, p * 146.0 + Vector3(0, 6, 0), 7.0, g)
	for k in 4: _cyl(r, Vector3(0, 14 + k * 0.5, 0), 70 - k * 16, 1.2, g if k % 2 == 0 else _metal(Color(0.03, 0.03, 0.03), 0.3, 0.3), false, 24)
	_sphere(r, Vector3(0, 16, 0), 12.0, _glow(Color(0.9, 1.0, 0.9), 3.0))
	return r
func _b_buz() -> Node3D: # Buz Kırıcı: kristal kanatlar
	var r := Node3D.new(); var h := _pearl()
	var ice := _metal(Color(0.65, 0.85, 1.0), 0.05, 0.3); ice.emission_enabled = true; ice.emission = Color(0.2, 0.5, 0.9); ice.emission_energy_multiplier = 0.8
	var g := _glow(Color(0.5, 0.85, 1.0), 4.0)
	_hullf(r, [[0, -110], [26, -40], [30, 60], [0, 92]], h, 5, 0.7)
	for f in [false, true]:
		for i in 3: _plate(r, [[18, -26 + i * 34], [104 - i * 18, -48 + i * 40], [62 - i * 6, 10 + i * 34]], 1.0, ice, 5.0, 4.0 + i, f)
	for z in [-70.0, -30.0, 10.0, 50.0]: _strip(r, Vector3(0, 12, z), Vector3(0, 12, z + 22), g, 4.0)
	_sphere(r, Vector3(0, 14, 0), 14.0, g)
	return r
func _b_kizil_kanat() -> Node3D: # Kızıl Kanat: ağır bombardıman
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(1.0, 0.25, 0.1), 4.5)
	for f in [false, true]:
		var sx := -1.0 if f else 1.0
		_plate(r, [[0, -70], [30, -56], [130, -8], [150, 24], [110, 18], [86, 34], [56, 26], [40, 48], [0, 40]], 1.0, h, 7.0, 3.0, f)
		_strip(r, Vector3(30 * sx, 5, -54), Vector3(128 * sx, 5, -6), g, 3.0)
		for x in [70.0, 100.0]: _turret(r, Vector3(x * sx, 5, 6), 9.0, g)
		for x in [16.0, 40.0]: _engine(r, Vector3(x * sx, 0, 44), 7.0, g, 16.0)
	_hullf(r, [[0, -60], [24, -40], [28, 26], [0, 36]], h, 6, 0.6, 3.0)
	_sphere(r, Vector3(0, 16, -14), 12.0, g, Vector3(1, 0.5, 1.5))
	return r
func _b_firtina_kalesi() -> Node3D: # Fırtına Kalesi: dönen kale
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(0.2, 1.0, 0.85), 4.0)
	for i in 8:
		var a := i * TAU / 8.0
		var p := Vector3(cos(a), 0, sin(a))
		var bx := CSGBox3D.new(); bx.size = Vector3(60, 18, 24); bx.material = h; bx.position = p * 125.0; bx.rotation.y = -a + PI / 2; r.add_child(bx)
		_sphere(r, p * 125.0 + Vector3(0, 10, 0), 5.0, g)
	_cyl(r, Vector3.ZERO, 92, 22, h, false, 8)
	_cyl(r, Vector3(0, 12, 0), 70, 6, _metal(Color(0.04, 0.04, 0.05), 0.4, 0.6), false, 8)
	for i in 4:
		var a := i * TAU / 4.0
		_turret(r, Vector3(cos(a), 0, sin(a)) * 74.0 + Vector3(0, 14, 0), 10.0, g)
	_sphere(r, Vector3(0, 18, 0), 30.0, g, Vector3(1, 0.4, 1))
	return r
func _b_ikiz() -> Node3D: # İkiz Avcılar: kirişle bağlı iki av gemisi
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(1.0, 0.15, 0.55), 4.5)
	_box(r, Vector3(-70, 2, 0), Vector3(70, 2, 0), 10.0, 6.0, _metal(Color(0.08, 0.06, 0.08), 0.4, 0.7))
	_sphere(r, Vector3(0, 6, 0), 14.0, g)
	for sx in [-70.0, 70.0]:
		var s := Node3D.new(); s.position.x = sx; r.add_child(s)
		_hullf(s, [[0, -76], [12, -40], [14, 30], [0, 44]], h, 6)
		for f in [false, true]: _plate(s, [[8, -20], [52, 6], [48, 34], [10, 26]], 1.0, h, 3.0, 1.0, f)
		_sphere(s, Vector3(0, 6, -30), 5.0, g, Vector3(1, 0.6, 2.2))
		_engine(s, Vector3(0, 0, 44), 6.0, g, 12.0)
		_strip(s, Vector3(-46, 3, 18), Vector3(46, 3, 18), g, 2.0)
	return r
func _b_kum() -> Node3D: # Kum Yılanı: halkalı gövde + çeneler
	var r := Node3D.new(); var h := _metal(Color(0.5, 0.36, 0.14), 0.35, 0.7); var g := _glow(Color(1.0, 0.75, 0.2), 4.0)
	for i in range(7, 0, -1):
		var z := i * 30.0
		var rr := 40.0 - i * 3.5
		_sphere(r, Vector3(0, 0, z), rr, h, Vector3(1, 0.6, 0.9))
		_cyl(r, Vector3(0, rr * 0.55, z), rr * 0.5, 1.5, g, false, 6)
	_hullf(r, [[0, -70], [44, -50], [48, 10], [0, 26]], _pearl(), 6, 0.7)
	for f in [false, true]: _plate(r, [[18, -60], [40, -106], [34, -56]], 1.0, _metal(Color(0.2, 0.15, 0.08), 0.3, 0.8), 4.0, 2.0, f)
	for sx in [-18.0, 18.0]: _sphere(r, Vector3(sx, 14, -30), 7.0, _glow(Color(1.0, 0.2, 0.05), 5.0))
	return r
func _b_ates() -> Node3D: # Dökümhane: lav potası, dört baca
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(1.0, 0.45, 0.05), 5.0)
	_cyl(r, Vector3.ZERO, 112, 20, h, false, 4)
	_cyl(r, Vector3(0, 12, 0), 78, 6, _metal(Color(0.05, 0.03, 0.03), 0.6, 0.4), false, 16)
	_cyl(r, Vector3(0, 15, 0), 66, 2, g, false, 24)
	for i in 4:
		var a := PI / 4 + i * TAU / 4.0
		var p := Vector3(cos(a), 0, sin(a)) * 104.0
		_cyl(r, p + Vector3(0, 14, 0), 18, 36, _metal(Color(0.12, 0.1, 0.1), 0.5, 0.8), false, 8)
		_cyl(r, p + Vector3(0, 33, 0), 13, 1, g, false, 12)
	return r
func _b_emici() -> Node3D: # Atmosfer Emici: türbin
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(0.4, 0.75, 1.0), 4.0)
	for i in 8:
		var hold := Node3D.new(); hold.rotation.y = i * TAU / 8.0; r.add_child(hold)
		_plate(hold, [[0, -60], [40, -90], [90, -110], [130, -80], [100, -70], [60, -60], [30, -40]], 1.0, h, 4.0, 2.0)
		_strip(hold, Vector3(40, 4, -80), Vector3(110, 4, -90), g, 2.5)
	_cyl(r, Vector3.ZERO, 80, 20, h, false, 12)
	for k in 5: _cyl(r, Vector3(0, 11 + k * 0.4, 0), 64 - k * 12, 1.0, _metal(Color(0.02, 0.03, 0.06), 0.3, 0.3) if k % 2 else g, false, 24)
	return r
func _b_enkaz() -> Node3D: # Çöpçü: hurdadan gemi, güneş panelleri, kıskaçlar
	var r := Node3D.new(); var h := _pearl(); var g := _glow(Color(1.0, 0.25, 0.2), 4.0); var pan := _metal(Color(0.05, 0.1, 0.3), 0.15, 0.8)
	_plate(r, [[-70, -50], [20, -70], [80, -20], [60, 60], [-20, 74], [-80, 20]], 1.0, h, 18.0, 9.0)
	for c in [[-130, -30, -15], [60, -40, 12], [-100, 40, 20], [50, 50, -18]]:
		var p := CSGBox3D.new(); p.size = Vector3(70, 2, 28); p.material = pan; p.position = Vector3(c[0] + 35, 4, c[1] + 14); p.rotation.y = deg_to_rad(c[2]); r.add_child(p)
	for sx in [-1.0, 1.0]: _box(r, Vector3(50 * sx, 4, 40), Vector3(110 * sx, 4, 110), 7.0, 7.0, _metal(Color(0.3, 0.28, 0.3), 0.3, 0.9))
	for p in [Vector3(-30, 12, -30), Vector3(30, 12, 10), Vector3(-10, 12, 40)]: _turret(r, p, 9.0, g)
	_sphere(r, Vector3(0, 14, 0), 12.0, g)
	return r
func _b_sefine() -> Node3D: # SEFİNE: yaşam gemisi (ana gemi)
	var r := Node3D.new(); var h := _metal(Color(0.62, 0.55, 0.42), 0.4, 0.75); var g := _glow(Color(1.0, 0.8, 0.3), 4.0)
	_hullf(r, [[0, -190], [60, -150], [96, -40], [104, 60], [70, 160], [0, 180]], h, 10, 0.5)
	for z in [-90.0, 0.0, 90.0]:
		var ring := CSGTorus3D.new(); ring.inner_radius = 108 - absf(z) * 0.2; ring.outer_radius = ring.inner_radius + 12; ring.sides = 10; ring.ring_sides = 4
		ring.material = _pearl(); ring.position = Vector3(0, 0, z); ring.rotation.x = PI / 2; ring.scale = Vector3(1, 1, 0.3); r.add_child(ring)
	for i in 40:
		var a := randf() * TAU
		var rr := randf() * 80.0
		_sphere(r, Vector3(cos(a) * rr, 26, sin(a) * rr * 1.6), 2.2, g if randf() < 0.7 else _glow(Color(1.0, 0.3, 0.2), 4.0))
	for sx in [-1.0, 1.0]:
		for z in [40.0, 120.0]: _engine(r, Vector3(sx * 86, 0, z), 16.0, g, 40.0)
	_sphere(r, Vector3(0, 30, 0), 26.0, _glow(Color(1.0, 0.9, 0.5), 3.0), Vector3(1, 0.4, 1))
	return r
func _b_varek() -> Node3D: # Varek'in Tahtı: taç biçimli amiral gemisi
	var r := Node3D.new(); var h := _metal(Color(0.08, 0.05, 0.1), 0.25, 0.85); var gold := _metal(Color(0.95, 0.7, 0.25), 0.2, 1.0); var g := _glow(Color(1.0, 0.15, 0.2), 5.0)
	_hullf(r, [[0, -112], [30, -80], [36, -20], [32, 62], [0, 90]], h, 8, 0.65)
	for f in [false, true]:
		var sx := -1.0 if f else 1.0
		_plate(r, [[20, -40], [80, -90], [140, -60], [150, 10], [120, -10], [90, 0], [60, 40], [24, 60]], 1.0, h, 5.0, 2.0, f)
		for i in 4: _plate(r, [[40 + i * 26, -50 - i * 6], [50 + i * 26, -100 - i * 4], [58 + i * 26, -46 - i * 6]], 1.0, gold, 3.0, 5.0, f)
		_strip(r, Vector3(24 * sx, 5, 50), Vector3(146 * sx, 5, 6), g, 2.5)
		_turret(r, Vector3(96 * sx, 6, -20), 10.0, g)
	for i in 5: _plate(r, [[-24 + i * 12, -78], [-18 + i * 12, -118 - (14 if i == 2 else 0)], [-12 + i * 12, -78]], 1.0, gold, 3.0, 12.0)
	_sphere(r, Vector3(0, 20, -20), 16.0, g)
	_engine(r, Vector3(0, 0, 88), 12.0, g, 16.0)
	return r
