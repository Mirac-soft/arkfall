extends Node3D
## 3D ARA SAHNE ÇEKİMLERİ: gerçek zamanlı sahneler (gökyüzü, arazi, deniz, bulut, Dünya), stüdyonun 3D modelleri
## (uçaklar, Vahar gemileri, 15 boss, Sefine), efektler (duman, ateş, patlama, iz) ve sinematik kamera yolları.
## Kullanım: var s = Shots.new(); viewport.add_child(s); s.build("cine_boss_down", {"boss": "oncu", "biome": 0})
## Birim: 1 = oyundaki 1 piksel (uçak ~60, boss 200-300).

const StudioS = preload("res://scripts/studio.gd")
const GameS = preload("res://scripts/game.gd")
var studio: Node
var cam: Camera3D
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var keys: Array = []        # kamera: [zaman, konum, bakış, fov]; konum/bakış Vector3 ya da Callable
var t := 0.0
var upd := Callable()       # çekime özel her kare güncellemesi: func(t, dt)
var shake := 0.0
var flash: OmniLight3D
var hmap: NoiseTexture2D
var detail: NoiseTexture2D
var trails: Array = []
var soft: Texture2D           # yumuşak parçacık dokusu (kenarı tamamen erir)
var top_down := Vector3.ZERO # oyunla eşleşen tepeden bakış noktası (geçişler için)

const MOODS := {
	"day": {"top": Color(0.16, 0.32, 0.62), "hor": Color(0.68, 0.78, 0.9), "bot": Color(0.3, 0.33, 0.36), "sun": Color(1.0, 0.94, 0.84), "dir": Vector3(0.4, 0.55, -0.7), "e": 1.5, "fog": 0.00022, "amb": 0.55},
	"dusk": {"top": Color(0.12, 0.14, 0.3), "hor": Color(0.78, 0.5, 0.36), "bot": Color(0.1, 0.08, 0.09), "sun": Color(1.0, 0.7, 0.45), "dir": Vector3(0.25, 0.12, -1.0), "e": 1.2, "fog": 0.00022, "amb": 0.45},
	"night": {"top": Color(0.02, 0.03, 0.07), "hor": Color(0.1, 0.13, 0.22), "bot": Color(0.02, 0.02, 0.03), "sun": Color(0.6, 0.7, 0.95), "dir": Vector3(-0.3, 0.6, -0.5), "e": 1.3, "fog": 0.0002, "amb": 0.5, "stars": 1.0},
	"space": {"top": Color(0, 0, 0), "hor": Color(0.005, 0.008, 0.02), "bot": Color(0, 0, 0), "sun": Color(1.0, 0.97, 0.92), "dir": Vector3(0.8, 0.25, 0.4), "e": 2.2, "fog": 0.0, "amb": 0.12, "stars": 1.6},
	"storm": {"top": Color(0.08, 0.09, 0.12), "hor": Color(0.25, 0.28, 0.33), "bot": Color(0.06, 0.07, 0.09), "sun": Color(0.6, 0.65, 0.75), "dir": Vector3(0.1, 0.8, -0.3), "e": 0.5, "fog": 0.0009, "amb": 0.35},
	"polar": {"top": Color(0.22, 0.36, 0.62), "hor": Color(0.7, 0.8, 0.9), "bot": Color(0.5, 0.55, 0.6), "sun": Color(1.0, 0.95, 0.9), "dir": Vector3(0.6, 0.18, -0.7), "e": 1.05, "fog": 0.00025, "amb": 0.42},
	"desert": {"top": Color(0.24, 0.42, 0.72), "hor": Color(0.85, 0.76, 0.62), "bot": Color(0.45, 0.38, 0.3), "sun": Color(1.0, 0.92, 0.78), "dir": Vector3(0.3, 0.7, -0.5), "e": 1.5, "fog": 0.0002, "amb": 0.5},
	"lava": {"top": Color(0.03, 0.015, 0.02), "hor": Color(0.3, 0.1, 0.06), "bot": Color(0.04, 0.02, 0.02), "sun": Color(0.9, 0.5, 0.35), "dir": Vector3(-0.4, 0.5, -0.8), "e": 0.6, "fog": 0.00035, "amb": 0.3, "stars": 0.3},
	"strato": {"top": Color(0.01, 0.03, 0.12), "hor": Color(0.45, 0.65, 0.95), "bot": Color(0.7, 0.75, 0.82), "sun": Color(1.0, 0.97, 0.92), "dir": Vector3(0.5, 0.35, -0.6), "e": 1.7, "fog": 0.0, "amb": 0.5, "stars": 0.5},
}
## 15 bölgenin 3D karşılığı (Data.STAGES biome sırası)
const BIOMES := [
	{"mood": "day", "g": {"amp": 160, "water": 0.6, "low": Color(0.2, 0.32, 0.14), "mid": Color(0.5, 0.42, 0.3), "high": Color(0.6, 0.55, 0.45), "snow": 2.0, "wcol": Color(0.04, 0.24, 0.34)}}, # Ege
	{"mood": "dusk", "g": {"amp": 220, "water": 0.42, "low": Color(0.16, 0.26, 0.12), "mid": Color(0.32, 0.3, 0.22), "high": Color(0.5, 0.48, 0.4), "snow": 2.0}},       # Sinop
	{"mood": "day", "g": {"amp": 240, "ridge": 0.25, "low": Color(0.62, 0.48, 0.34), "mid": Color(0.78, 0.62, 0.45), "high": Color(0.9, 0.82, 0.7), "snow": 2.0}, "chimneys": true}, # Kapadokya
	{"mood": "day", "g": {"amp": 650, "ridge": 1.0, "low": Color(0.2, 0.28, 0.14), "mid": Color(0.42, 0.4, 0.38), "high": Color(0.94, 0.95, 0.98), "snow": 0.8}},       # Toros
	{"mood": "day", "g": {"amp": 420, "ridge": 0.6, "water": 0.52, "low": Color(0.3, 0.33, 0.2), "mid": Color(0.45, 0.4, 0.34), "high": Color(0.92, 0.94, 0.98), "snow": 0.85}}, # Van
	{"mood": "polar", "g": {"amp": 950, "ridge": 1.0, "low": Color(0.55, 0.58, 0.62), "mid": Color(0.45, 0.46, 0.5), "high": Color(0.97, 0.98, 1.0), "snow": 0.45}},   # Ağrı
	{"mood": "day", "clouds_only": true},                                                                                                                              # bulut duvarı
	{"mood": "storm", "g": {"amp": 10, "water": 2.0, "wcol": Color(0.07, 0.12, 0.15)}, "lightning": true},                                                            # Karadeniz fırtınası
	{"mood": "polar", "g": {"amp": 90, "water": 0.3, "low": Color(0.85, 0.9, 0.96), "mid": Color(0.78, 0.86, 0.95), "high": Color(1, 1, 1), "snow": 0.4, "wcol": Color(0.02, 0.06, 0.1)}}, # kutup
	{"mood": "desert", "g": {"amp": 150, "dunes": 1.0, "low": Color(0.62, 0.48, 0.32), "mid": Color(0.72, 0.58, 0.4), "high": Color(0.8, 0.68, 0.5), "snow": 2.0}}, # Sahra
	{"mood": "lava", "g": {"amp": 420, "ridge": 0.6, "lava": 1.0, "low": Color(0.08, 0.06, 0.06), "mid": Color(0.16, 0.12, 0.1), "high": Color(0.25, 0.2, 0.18), "snow": 2.0}}, # volkan
	{"mood": "strato", "clouds_only": true, "low": true},                                                                                                             # stratosfer
	{"mood": "space", "earth": true},                                                                                                                                  # alçak yörünge
	{"mood": "space", "debris": true},                                                                                                                                 # enkaz kuşağı
	{"mood": "dusk", "g": {"amp": 60, "low": Color(0.3, 0.29, 0.27), "mid": Color(0.4, 0.38, 0.35), "high": Color(0.5, 0.48, 0.45), "snow": 2.0}, "ruins": true},     # İstanbul
]

func _init() -> void:
	studio = StudioS.new()
	hmap = _noise(0.006, 5, 512); detail = _noise(0.03, 3, 256)
	var g := Gradient.new(); g.offsets = PackedFloat32Array([0.0, 0.35, 1.0]); g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5); gt.width = 128; gt.height = 128; soft = gt

func _exit_tree() -> void:
	if is_instance_valid(studio): studio.free()

func _noise(freq: float, oct: int, size: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new(); n.frequency = freq; n.fractal_octaves = oct; n.seed = 7
	var t2 := NoiseTexture2D.new(); t2.width = size; t2.height = size; t2.seamless = true; t2.noise = n; t2.generate_mipmaps = true
	return t2

# ================= ortam =================
func _env(mood_name: String) -> Dictionary:
	var m: Dictionary = MOODS[mood_name]
	var we := WorldEnvironment.new(); env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sk := Sky.new(); sky_mat = ShaderMaterial.new(); sky_mat.shader = load("res://scripts/c3d_sky.gdshader"); sk.sky_material = sky_mat; env.sky = sk
	sky_mat.set_shader_parameter("top_col", m.top); sky_mat.set_shader_parameter("hor_col", m.hor); sky_mat.set_shader_parameter("bot_col", m.bot)
	sky_mat.set_shader_parameter("sun_dir", m.dir); sky_mat.set_shader_parameter("sun_col", m.sun); sky_mat.set_shader_parameter("stars", m.get("stars", 0.0))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = m.amb
	if mood_name == "night": env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.32, 0.4, 0.6); env.ambient_light_energy = 1.6; env.tonemap_exposure = 1.7 # ay ışığı: gece okunaklı kalsın
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.0
	env.glow_enabled = true; env.glow_intensity = 0.55; env.glow_bloom = 0.04; env.glow_hdr_threshold = 1.1
	if m.fog > 0.0:
		env.fog_enabled = true; env.fog_light_color = m.hor; env.fog_density = m.fog; env.fog_aerial_perspective = 0.6; env.fog_sky_affect = 0.0
	env.adjustment_enabled = true; env.adjustment_contrast = 1.08; env.adjustment_saturation = 0.95
	we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.light_color = m.sun; sun.light_energy = m.e; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 4000.0
	sun.transform = Transform3D(Basis.looking_at(-(m.dir as Vector3).normalized(), Vector3.UP if absf((m.dir as Vector3).normalized().y) < 0.95 else Vector3.FORWARD), Vector3.ZERO)
	add_child(sun)
	cam = Camera3D.new(); cam.far = 60000.0; cam.near = 1.0; cam.fov = 55.0; add_child(cam); cam.current = true
	flash = OmniLight3D.new(); flash.omni_range = 4000.0; flash.light_energy = 0.0; flash.light_color = Color(1.0, 0.7, 0.4); add_child(flash)
	return m

## Bölgenin zemini: arazi / deniz / bulut denizi / uzay
func _world(biome: int) -> Dictionary:
	var b: Dictionary = BIOMES[clampi(biome, 0, BIOMES.size() - 1)]
	_env(b.mood)
	if b.has("g"): _ground(b.g)
	if b.get("chimneys", false): _chimneys()
	if b.get("clouds_only", false):
		_clouds(90, 9000.0, -260.0, -60.0, 420.0, 900.0)
		if b.get("low", false): _earth_curve()
	elif b.has("g") and b.mood != "space": _clouds(26, 9000.0, 700.0, 1100.0, 300.0, 700.0)
	if b.get("earth", false): _earth(Vector3(0, -9200, -3000), 8600.0)
	if b.get("debris", false): _debris(160, 5000.0)
	if b.get("ruins", false): _ruins(true)
	if b.get("lightning", false): upd_lightning = true
	return b

var upd_lightning := false
var light_t := 2.0
var quiet := false # oyun içi arka planda şimşek sesi çalmasın

# ================= OYUN İÇİ 3D ARKA PLAN (v0.13) =================
# Bölgenin 3D dünyası tepeden, yüksekten görünür; kamera oyunun kamerasını izler (1 piksel = 1 birim). Zemin kameradan
# BD_H uzakta olduğu için ekranda ~%26 hızla, bulutlar ~%45-60 hızla akar: Sky Force'taki gibi katmanlı derinlik.
# Dünya sonsuz değil: zemin ızgarası kamerayla birlikte (ızgara adımına oturtularak) kayar, diğer nesneler BD_AREA'da sarılır.
const BD_H := 2600.0
const BD_AREA := 9000.0
var bd_wrap: Array = []
var bd_ground: Node3D
var bd_earth: Array = []
var bd_base := {}
func backdrop(biome: int) -> void:
	quiet = true
	var b := _world(biome)
	sun.shadow_enabled = b.get("chimneys", false) or b.get("ruins", false)
	if env.fog_enabled: env.fog_density *= 0.55
	env.glow_intensity = 0.35
	env.tonemap_exposure = {"storm": 2.6, "lava": 1.15, "polar": 1.15, "space": 1.3, "dusk": 1.9}.get(b.mood, 1.35) # oyunun karanlık son işlemesinin altında okunsun
	if b.has("g") and b.g.get("lava", 0.0) > 0.0: # lav sakin parlasın: turuncu düşman mermileriyle karışmasın
		for c in get_children():
			if c is MeshInstance3D and c.mesh is PlaneMesh: c.material_override.set_shader_parameter("lava", 0.35)
	if b.mood == "space": sky_mat.set_shader_parameter("star_floor", 1.0) # aşağı bakınca da yıldız
	if b.get("clouds_only", false) or b.mood == "space": _clouds(40 if b.mood != "space" else 0, BD_AREA, -900.0, -300.0, 500.0, 1100.0)
	for c in get_children():
		if c == cam or c == sun or c == flash or c is WorldEnvironment: continue
		if c is MeshInstance3D and c.mesh is PlaneMesh: bd_ground = c
		elif c is MeshInstance3D and c.mesh is SphereMesh and (c.mesh as SphereMesh).radius > 3000.0:
			bd_earth.append(c); bd_base[c] = c.position
			if b.get("earth", false): bd_base[c] = Vector3(0, -12400, 0) # yörüngeden: gezegen ekranı doldurur, kenarlarda uzay
			if c.material_override is ShaderMaterial: c.material_override.set_shader_parameter("rough", 0.85)
		elif c is Node3D: bd_wrap.append(c)
	cam.fov = 50.0; cam.far = 80000.0
	follow(Vector2.ZERO)

## Oyun kamerasının dünya merkezi (piksel) -> 3D kamera
func follow(c2: Vector2, zoom := 1.0) -> void:
	var p := Vector3(c2.x, BD_H / zoom - 420.0, c2.y)
	cam.position = p
	cam.basis = Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
	if bd_ground: # ızgara adımına oturt: köşeler yerinde kalsın, arazi kaymasın (gölgelendirici dünya koordinatı kullanır)
		var g := 18000.0 / 220.0
		bd_ground.position.x = snappedf(p.x, g); bd_ground.position.z = snappedf(p.z, g)
	for e in bd_earth: # gezegen altta kalır, uçtukça döner
		e.position = bd_base[e] + Vector3(p.x, 0, p.z)
		e.rotation = Vector3(-p.z, 0, p.x) / absf(bd_base[e].y) * 0.5
	for n in bd_wrap:
		if not is_instance_valid(n): continue
		var d: Vector3 = n.position - p
		if absf(d.x) > BD_AREA * 0.5: n.position.x -= signf(d.x) * BD_AREA
		if absf(d.z) > BD_AREA * 0.5: n.position.z -= signf(d.z) * BD_AREA

func _ground(g: Dictionary) -> void:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(18000, 18000); pm.subdivide_width = 220; pm.subdivide_depth = 220
	mi.mesh = pm; mi.position.y = -420.0
	var mat := ShaderMaterial.new(); mat.shader = load("res://scripts/c3d_ground.gdshader")
	mat.set_shader_parameter("hmap", hmap); mat.set_shader_parameter("detail", detail)
	mat.set_shader_parameter("amp", float(g.get("amp", 150))); mat.set_shader_parameter("ridge", float(g.get("ridge", 0.0)))
	mat.set_shader_parameter("water", float(g.get("water", -1.0))); mat.set_shader_parameter("lava", float(g.get("lava", 0.0))); mat.set_shader_parameter("dunes", float(g.get("dunes", 0.0)))
	mat.set_shader_parameter("snow_line", float(g.get("snow", 2.0)))
	for k in [["low", "low_col"], ["mid", "mid_col"], ["high", "high_col"], ["wcol", "water_col"]]:
		if g.has(k[0]): mat.set_shader_parameter(k[1], g[k[0]])
	mi.material_override = mat; mi.extra_cull_margin = 2000.0; add_child(mi)

func _clouds(n: int, area: float, y0: float, y1: float, s0: float, s1: float, lit := Color(1.0, 0.97, 0.92), shade := Color(0.6, 0.65, 0.74)) -> void:
	var sh := load("res://scripts/c3d_cloud.gdshader")
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	for i in n:
		var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2.ONE; q.mesh = qm
		var m := ShaderMaterial.new(); m.shader = sh; m.set_shader_parameter("noise", detail); m.set_shader_parameter("seed", rng.randf() * 10.0)
		m.set_shader_parameter("lit", lit); m.set_shader_parameter("shade", shade)
		q.material_override = m
		var s := rng.randf_range(s0, s1); q.scale = Vector3(s * 1.6, s, 1.0)
		q.position = Vector3(rng.randf_range(-area, area) * 0.5, rng.randf_range(y0, y1), rng.randf_range(-area, area) * 0.5)
		add_child(q)

func _chimneys() -> void: # Kapadokya peribacaları
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.82, 0.68, 0.52); m.roughness = 1.0
	var cap := StandardMaterial3D.new(); cap.albedo_color = Color(0.35, 0.28, 0.24); cap.roughness = 1.0
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for i in 70:
		var p := Vector3(rng.randf_range(-3500, 3500), -300, rng.randf_range(-3500, 1500))
		var h := rng.randf_range(120, 300)
		var c := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 10; cm.bottom_radius = rng.randf_range(35, 60); cm.height = h; c.mesh = cm; c.material_override = m
		c.position = p + Vector3(0, h / 2.0, 0); add_child(c)
		var k := MeshInstance3D.new(); var km := CylinderMesh.new(); km.top_radius = 0; km.bottom_radius = 26; km.height = 40; k.mesh = km; k.material_override = cap
		k.position = p + Vector3(0, h + 15, 0); add_child(k)

func _ruins(broken: bool) -> void: # şehir: sağlam ya da harabe (kırık bloklar, kubbeler, ince kuleler, duman)
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color(0.45, 0.42, 0.38); stone.roughness = 1.0
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.16, 0.15, 0.14); dark.roughness = 1.0
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	for i in 140:
		var b := MeshInstance3D.new(); var bm := BoxMesh.new(); var h := rng.randf_range(40, 260)
		bm.size = Vector3(rng.randf_range(60, 160), h, rng.randf_range(60, 160)); b.mesh = bm; b.material_override = stone if rng.randf() < 0.7 else dark
		b.position = Vector3(rng.randf_range(-3000, 3000), -380 + h / 2.0, rng.randf_range(-3600, 1200)); b.rotation.y = rng.randf() * 0.3
		if broken and rng.randf() < 0.3: b.rotation.z = rng.randf_range(-0.25, 0.25) # yıkık, eğik
		add_child(b)
	for i in 5: # kubbeler ve ince kuleler
		var c := Vector3(rng.randf_range(-1800, 1800), -380, rng.randf_range(-3000, -600))
		var d := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 150; sm.height = 150; sm.is_hemisphere = true; d.mesh = sm; d.material_override = stone
		d.position = c + Vector3(0, 160, 0); add_child(d)
		var base := MeshInstance3D.new(); var bm2 := BoxMesh.new(); bm2.size = Vector3(320, 160, 320); base.mesh = bm2; base.material_override = stone; base.position = c + Vector3(0, 80, 0); add_child(base)
		for sx in [-1, 1]:
			var mn := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 9; cm.bottom_radius = 12; cm.height = rng.randf_range(250, 420)
			mn.mesh = cm; mn.material_override = stone; mn.position = c + Vector3(sx * 230, cm.height / 2.0, 120); add_child(mn)
	if broken:
		for i in 8: _smoke_col(Vector3(rng.randf_range(-2500, 2500), -360, rng.randf_range(-3200, 0)), 0.8)
	else: # sağlam şehirde pencere ışıkları
		for i in 60:
			var w := OmniLight3D.new(); w.light_color = Color(1.0, 0.8, 0.5); w.light_energy = 1.5; w.omni_range = 160; w.position = Vector3(rng.randf_range(-3000, 3000), -300, rng.randf_range(-3600, 1200)); add_child(w)

func _earth(pos: Vector3, r: float) -> MeshInstance3D:
	var e := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 96; sm.rings = 48; e.mesh = sm
	var m := ShaderMaterial.new(); m.shader = load("res://scripts/c3d_earth.gdshader")
	m.set_shader_parameter("land", _noise(0.004, 5, 1024)); m.set_shader_parameter("clouds", _noise(0.01, 4, 512)); m.set_shader_parameter("sun_dir", MOODS.space.dir)
	e.material_override = m; e.position = pos; add_child(e)
	var a := MeshInstance3D.new(); var am := SphereMesh.new(); am.radius = r * 1.03; am.height = r * 2.06; am.radial_segments = 96; am.rings = 48; a.mesh = am
	var mm := ShaderMaterial.new(); mm.shader = load("res://scripts/c3d_atmo.gdshader"); a.material_override = mm; a.position = pos; add_child(a)
	return e

func _earth_curve() -> void: # stratosfer: aşağıda Dünya'nın kavisli ufku
	var e := _earth(Vector3(0, -60000, -8000), 58000.0); e.rotation.z = 0.05

func _debris(n: int, area: float) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	var mats := [studio._metal(Color(0.35, 0.36, 0.4), 0.5, 0.8), studio._metal(Color(0.6, 0.55, 0.4), 0.6, 0.6), studio._glow(Color(0.3, 0.6, 1.0), 2.0)]
	for i in n:
		var d := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(rng.randf_range(4, 40), rng.randf_range(2, 14), rng.randf_range(6, 60)); d.mesh = bm
		d.material_override = mats[0 if rng.randf() < 0.6 else (1 if rng.randf() < 0.85 else 2)]
		d.position = Vector3(rng.randf_range(-area, area), rng.randf_range(-600, 600), rng.randf_range(-area, area * 0.3))
		d.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0); d.set_meta("spin", Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4), 0)); d.add_to_group("spin")
		add_child(d)

# ================= aktörler =================
func plane(id: String) -> Node3D:
	var p: Node3D = studio._plane(StudioS.P.get(id, StudioS.P.serce))
	var root := Node3D.new(); root.add_child(p)
	var d: Dictionary = StudioS.P.get(id, StudioS.P.serce)
	for e in d.eng: # art yakıcı: ışıyan koni + ışık
		var k: float = d.k
		var c := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = e[2] * k * 0.6; cm.bottom_radius = 0.5; cm.height = 34
		c.mesh = cm; var gm := StandardMaterial3D.new(); gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; gm.albedo_color = Color(2.4, 1.2, 0.5); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.albedo_color.a = 0.75
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; c.material_override = gm
		c.rotation.x = PI / 2; c.position = Vector3(e[0] * k, 0, (e[1] * k + 4) + 17); c.name = "burner"; root.add_child(c)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.55, 0.25); l.light_energy = 2.0; l.omni_range = 120; l.position = Vector3(0, 0, 60); root.add_child(l)
	add_child(root)
	return root

func boss(key: String) -> Node3D:
	var tex: String = Data.BOSSES[key].tex
	var b: Node3D = studio.call("_" + tex) if studio.has_method("_" + tex) else studio._b_oncu()
	var root := Node3D.new(); root.add_child(b); add_child(root)
	return root

## Dev gemiyi gece de seçilir yapar: gövdesine dağılmış ışıklar + alt yüzeyi aydınlatan ışık
func glow_lights(n: Node3D, col: Color, count: int, spread: float) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 13
	var m: Material = studio._glow(col, 6.0)
	for i in count:
		var l := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 4; sm.height = 8; l.mesh = sm; l.material_override = m
		var a := rng.randf() * TAU; var r := spread * sqrt(rng.randf())
		l.position = Vector3(cos(a) * r, rng.randf_range(-8, 4), sin(a) * r * 0.6); n.add_child(l)
	var o := OmniLight3D.new(); o.light_color = col; o.light_energy = 4.0; o.omni_range = spread * 2.5; o.position = Vector3(0, -spread * 0.4, 0); n.add_child(o)

func vahar(kind := "avci") -> Node3D:
	var root := Node3D.new(); root.add_child(studio.call("_" + kind)); add_child(root)
	return root

# ================= efektler =================
func _mat_particle(col_add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; m.albedo_texture = soft
	if col_add: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

## Sürekli yayıcı (duman / ateş / kıvılcım) — hedefe bağlanır, izi dünyada kalır
func emitter(parent: Node3D, col: Color, size: float, life: float, amount: int, vel := Vector3.ZERO, add := false, grow := 2.0) -> CPUParticles3D:
	var p := CPUParticles3D.new(); var q := QuadMesh.new(); q.size = Vector2.ONE * size; q.material = _mat_particle(add); p.mesh = q
	p.amount = amount; p.lifetime = life; p.local_coords = false; p.direction = vel.normalized() if vel != Vector3.ZERO else Vector3.UP
	p.initial_velocity_min = vel.length() * 0.5; p.initial_velocity_max = vel.length() * 1.2; p.spread = 25.0; p.gravity = Vector3.ZERO
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.4)); sc.add_point(Vector2(1, grow)); p.scale_amount_curve = sc
	var g := Gradient.new(); g.colors = PackedColorArray([col, Color(col, 0.0)]); p.color_ramp = g
	parent.add_child(p); return p

## Tek seferlik patlama: ışık parlaması + ateş topu + dağılan kıvılcım ve duman
func boom(at: Vector3, k := 1.0) -> void:
	for spec in [[Color(3.0, 1.6, 0.6, 1.0), 60.0 * k, 0.6, 40, 220.0 * k, true], [Color(2.6, 1.1, 0.3, 1.0), 12.0 * k, 1.2, 60, 520.0 * k, true], [Color(0.12, 0.1, 0.1, 0.35), 110.0 * k, 3.0, 30, 160.0 * k, false]]:
		var n := Node3D.new(); add_child(n); n.position = at
		var p := emitter(n, spec[0], spec[1], spec[2], spec[3], Vector3.UP * spec[4], spec[5])
		p.one_shot = true; p.explosiveness = 0.95; p.spread = 180.0; p.emitting = true
		get_tree().create_timer(spec[2] + 0.5).timeout.connect(n.queue_free)
	flash.position = at; flash.light_energy = 12.0 * k; shake = maxf(shake, 14.0 * k)
	Sfx.play("bigboom" if k > 1.5 else "boom", 0.0)

func _smoke_col(at: Vector3, k: float) -> void:
	var n := Node3D.new(); n.position = at; add_child(n)
	var p := emitter(n, Color(0.07, 0.065, 0.06, 0.55), 160.0 * k, 9.0, 30, Vector3(12, 70, 0) * k, false, 3.0); p.preprocess = 9.0
	var f := emitter(n, Color(2.4, 0.9, 0.25, 0.9), 50.0 * k, 0.8, 24, Vector3(0, 60, 0), true, 0.5); f.preprocess = 1.0

## Kontrail: hedefin arkasında solan şerit
class Trail extends MeshInstance3D:
	var target: Node3D
	var offset := Vector3.ZERO
	var pts: Array = []
	var width := 3.0
	var col := Color(1, 1, 1, 0.5)
	var im := ImmediateMesh.new()
	func _ready() -> void:
		mesh = im
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true; m.cull_mode = BaseMaterial3D.CULL_DISABLED; material_override = m
		extra_cull_margin = 100000.0
	func _process(_dt: float) -> void:
		if not is_instance_valid(target) or not target.is_inside_tree(): return
		pts.push_front(target.global_transform * offset)
		if pts.size() > 90: pts.pop_back()
		im.clear_surfaces()
		var c := get_viewport().get_camera_3d()
		if c == null or pts.size() < 2: return
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var p: Vector3 = pts[i]; var nx: Vector3 = pts[mini(i + 1, pts.size() - 1)]
			var side := (nx - p).cross(c.global_position - p).normalized() * width * (1.0 + i * 0.012)
			var a := col.a * (1.0 - float(i) / pts.size())
			im.surface_set_color(Color(col, a)); im.surface_add_vertex(p - side)
			im.surface_set_color(Color(col, a)); im.surface_add_vertex(p + side)
		im.surface_end()

func trail(target: Node3D, offset: Vector3, col := Color(1, 1, 1, 0.45), w := 2.5) -> void:
	var tr := Trail.new(); tr.target = target; tr.offset = offset; tr.col = col; tr.width = w; add_child(tr)

# ================= kamera =================
func _v(x) -> Vector3: return x.call() if x is Callable else x

func _process(dt: float) -> void:
	t += dt
	if upd.is_valid(): upd.call(t, dt)
	for d in get_tree().get_nodes_in_group("spin"):
		if is_ancestor_of(d): d.rotation += d.get_meta("spin") * dt
	if upd_lightning:
		light_t -= dt
		if light_t <= 0.0:
			light_t = randf_range(2.0, 4.5); flash.position = cam.global_position + Vector3(randf_range(-2000, 2000), 1500, -2500); flash.light_color = Color(0.7, 0.8, 1.0); flash.light_energy = 18.0
			if not quiet: Sfx.play("boom", 0.0)
	flash.light_energy = maxf(0.0, flash.light_energy - dt * 30.0)
	if keys.size() > 0: _camera()
	shake = maxf(0.0, shake - dt * 20.0)
	if shake > 0.0: cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.4

## Anahtar noktalar arasında yumuşak (Catmull-Rom) kamera
func _camera() -> void:
	var i := 0
	while i < keys.size() - 1 and t > keys[i + 1][0]: i += 1
	var k0: Array = keys[maxi(i - 1, 0)]; var k1: Array = keys[i]; var k2: Array = keys[mini(i + 1, keys.size() - 1)]; var k3: Array = keys[mini(i + 2, keys.size() - 1)]
	var u := 0.0 if k2[0] == k1[0] else clampf((t - k1[0]) / (k2[0] - k1[0]), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var pos := _cr(_v(k0[1]), _v(k1[1]), _v(k2[1]), _v(k3[1]), u)
	var look := _cr(_v(k0[2]), _v(k1[2]), _v(k2[2]), _v(k3[2]), u)
	cam.position = pos
	var dir := look - pos
	if dir.length() > 0.01: cam.basis = Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.FORWARD)
	cam.fov = lerpf(k1[3] if k1.size() > 3 else 55.0, k2[3] if k2.size() > 3 else 55.0, u)

func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: float) -> Vector3:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)

# ================= çekimler =================
func build(kind: String, ctx := {}) -> void:
	match kind:
		"cine_boss_down": _boss_down(ctx)
		"cine_victory": _victory(ctx)
		"cine_earth": _shot_earth(ctx)
		"cine_ark": _shot_ark(ctx)
		"cine_envoy": _shot_envoy(ctx)
		"cine_betrayal": _shot_betrayal(ctx)
		"cine_squadron": _shot_squadron(ctx)
		"cine_pilot": _shot_pilot(ctx)
		"cine_base": _shot_base(ctx)
		"cine_harvest": _shot_harvest(ctx)
		"cine_forge": _shot_forge(ctx)
		"cine_ruins": _shot_ruins(ctx)
		_: _flyover(ctx) # dağ / buz / çöl / uzay: bir sonraki bölgenin üstünden uçuş

## Oyuncunun uçağı + kanat ucu izleri; yön -Z, hız v
func _hero(at: Vector3, trails_on := true) -> Node3D:
	var p := plane(Save.plane)
	p.position = at
	if trails_on:
		var d: Dictionary = StudioS.P.get(Save.plane, StudioS.P.serce)
		var tip := 0.0
		for w in d.wing: tip = maxf(tip, w[0])
		for sx in [-1.0, 1.0]: trail(p, Vector3(sx * tip * d.k, 0, 10), Color(1, 1, 1, 0.3), 0.7)
	return p

## Bölüm sonu: oyunla aynı tepeden bakışla başlar (eşleşen kesme), boss yanarak düşer, bölgeye göre çarpar, uçak geçer
func _boss_down(ctx: Dictionary) -> void:
	var bi: int = ctx.get("biome", 0)
	var b := _world(bi)
	var bs := boss(ctx.get("boss", "oncu"))
	var hero := _hero(Vector3(0, 200, 300))
	var fire := emitter(bs, Color(2.6, 1.0, 0.3, 0.95), 70.0, 0.9, 50, Vector3(0, 40, 0), true, 0.6)
	var smoke := emitter(bs, Color(0.08, 0.07, 0.07, 0.7), 140.0, 4.0, 60, Vector3(0, 50, 0), false, 3.0)
	var start := Vector3(250, 520, -500); var ground_y := -420.0 + (180.0 if b.has("g") and b.g.get("water", -1.0) < 0.0 else 0.0)
	if b.get("clouds_only", false) or b.mood == "space": ground_y = -900.0
	var end := Vector3(-150, ground_y, -1900)
	var crashed := [false]
	top_down = hero.position
	upd = func(tt: float, dt: float):
		hero.position += Vector3(0, 0, -260) * dt # uçak ileri uçar
		hero.rotation.z = sin(tt * 0.8) * 0.25
		if not crashed[0]:
			var u := clampf(tt / 4.2, 0.0, 1.0)
			bs.position = start.lerp(end, u * u); bs.rotation += Vector3(0.6, 0.3, 1.1) * dt * (0.4 + u)
			if fmod(tt, 0.45) < dt: boom(bs.position + Vector3(randf_range(-60, 60), randf_range(-30, 30), randf_range(-60, 60)), 0.6)
			if u >= 1.0:
				crashed[0] = true; boom(bs.position, 3.0); bs.visible = false; fire.emitting = false; smoke.emitting = false
				_impact(bs.position, GameS.IMPACT[clampi(bi, 0, 14)])
	# kamera: oyunun tepeden görüntüsü -> aşağı süzülüp düşen bossa döner -> çarpmayı geniş açıdan izler -> uçağın arkasına geçer
	var hp := func(): return hero.position
	keys = [[0.0, hero.position + Vector3(0, 900, 1), hero.position, 50.0],
		[1.2, hero.position + Vector3(260, 420, 380), func(): return bs.position, 55.0],
		[3.0, Vector3(500, 120, -700), func(): return bs.position, 50.0],
		[4.6, Vector3(700, 60, -1100), end + Vector3(0, 120, 0), 45.0],
		[6.6, func(): return hero.position + Vector3(-90, 40, 220), func(): return hero.position + Vector3(0, 0, -600), 60.0],
		[9.0, func(): return hero.position + Vector3(0, 700, 60), hp, 55.0]]

func _impact(at: Vector3, kind: String) -> void:
	var n := Node3D.new(); n.position = at; add_child(n)
	match kind:
		"water":
			var s := emitter(n, Color(0.92, 0.97, 1.0, 0.7), 46.0, 2.4, 260, Vector3(0, 900, 0), false, 2.2); s.gravity = Vector3(0, -700, 0); s.spread = 22.0; s.one_shot = true; s.explosiveness = 0.9; s.emitting = true
			var r := emitter(n, Color(0.8, 0.9, 1.0, 0.6), 160.0, 3.0, 40, Vector3(0, 60, 0), false, 3.0); r.one_shot = true; r.explosiveness = 0.9; r.spread = 90.0; r.emitting = true
		"snow":
			var s := emitter(n, Color(1, 1, 1, 0.9), 160.0, 3.5, 90, Vector3(0, 380, 0), false, 3.0); s.gravity = Vector3(0, -120, 0); s.spread = 70.0; s.one_shot = true; s.explosiveness = 0.9; s.emitting = true
		"lava":
			var s := emitter(n, Color(3.0, 1.0, 0.2, 1.0), 26.0, 2.2, 140, Vector3(0, 760, 0), true, 0.6); s.gravity = Vector3(0, -600, 0); s.spread = 50.0; s.one_shot = true; s.explosiveness = 0.9; s.emitting = true
			_smoke_col(at, 1.6)
		"cloud", "space", "metal":
			var s := emitter(n, Color(0.6, 0.62, 0.68, 1.0), 14.0, 4.0, 90, Vector3(0, 300, 0), false, 1.0); s.spread = 180.0; s.one_shot = true; s.explosiveness = 0.95; s.emitting = true
		_:
			var c: Color = {"sand": Color(0.85, 0.7, 0.45), "rock": Color(0.5, 0.48, 0.46), "rubble": Color(0.55, 0.52, 0.5), "dirt": Color(0.45, 0.34, 0.22)}.get(kind, Color(0.45, 0.34, 0.22))
			var s := emitter(n, Color(c, 0.95), 26.0, 2.2, 120, Vector3(0, 650, 0), false, 1.0); s.gravity = Vector3(0, -700, 0); s.spread = 45.0; s.one_shot = true; s.explosiveness = 0.9; s.emitting = true
			var d := emitter(n, Color(c.darkened(0.2), 0.6), 240.0, 5.0, 30, Vector3(0, 80, 0), false, 3.0); d.one_shot = true; d.explosiveness = 0.9; d.spread = 90.0; d.emitting = true
			_smoke_col(at, 1.2)

## Bir sonraki bölgenin üstünden uçuş: uçak bulutları yararak ilerler, kamera geniş açıdan uçağın arkasına ve en son
## oyunun tepeden bakışına yükselir (oyuna eşleşen kesme)
func _flyover(ctx: Dictionary) -> void:
	var bi: int = ctx.get("biome", 3)
	_world(bi)
	var hero := _hero(Vector3(0, 120, 600))
	var sp := 340.0
	upd = func(tt: float, dt: float):
		hero.position += Vector3(0, 0, -sp) * dt; hero.rotation.z = sin(tt * 0.7) * 0.3; hero.position.x = sin(tt * 0.35) * 160.0
	keys = [[0.0, Vector3(-900, 260, -400), func(): return hero.position, 42.0],
		[3.5, func(): return hero.position + Vector3(-260, 70, 300), func(): return hero.position + Vector3(0, 0, -500), 55.0],
		[6.5, func(): return hero.position + Vector3(120, 40, 160), func(): return hero.position + Vector3(0, 0, -900), 62.0],
		[9.0, func(): return hero.position + Vector3(0, 900, 1), func(): return hero.position, 50.0]]

func _victory(ctx: Dictionary) -> void:
	var key: String = ctx.get("boss", "sefine")
	if key == "varek": # ilk temas meydanı: taht düşer, sonra şafakta uçuş
		_world(14)
		var bs := boss("varek"); bs.position = Vector3(0, 900, -1600)
		emitter(bs, Color(0.08, 0.07, 0.07, 0.7), 160.0, 4.0, 60, Vector3(0, 50, 0), false, 3.0)
		var crashed := [false]
		upd = func(tt: float, dt: float):
			if not crashed[0]:
				bs.position.y -= (200.0 + tt * 260.0) * dt; bs.rotation.z += dt * 0.3
				if bs.position.y < -300.0: crashed[0] = true; boom(bs.position, 3.5); bs.visible = false; _impact(bs.position, "rubble")
		keys = [[0.0, Vector3(900, 300, 600), func(): return bs.position, 50.0], [4.0, Vector3(600, 80, 200), Vector3(0, -250, -1600), 45.0], [9.0, Vector3(-400, 200, 400), Vector3(0, 0, -1600), 50.0]]
		return
	_env("space") # Sefine çöker: parçalanıp Ay'ın arkasına sürüklenir
	_earth(Vector3(3000, -2600, -9000), 3200.0)
	var moon := MeshInstance3D.new(); var mm := SphereMesh.new(); mm.radius = 900; mm.height = 1800; moon.mesh = mm
	var ms := StandardMaterial3D.new(); ms.albedo_color = Color(0.6, 0.6, 0.62); ms.roughness = 1.0; ms.albedo_texture = detail; moon.material_override = ms; moon.position = Vector3(-2500, 400, -7000); add_child(moon)
	var bs := boss("sefine"); bs.scale = Vector3.ONE * 2.0; bs.position = Vector3(0, 0, -2600)
	upd = func(tt: float, dt: float):
		bs.position += Vector3(-80, 10, -60) * dt; bs.rotation += Vector3(0.02, 0.05, 0.03) * dt
		if fmod(tt, 0.5) < dt: boom(bs.position + Vector3(randf_range(-400, 400), randf_range(-150, 150), randf_range(-200, 200)), 1.6)
	keys = [[0.0, Vector3(0, 300, 1400), Vector3(0, 0, -2600), 45.0], [9.0, Vector3(-600, 150, 600), func(): return bs.position, 50.0]]

func _shot_earth(_ctx: Dictionary) -> void:
	_env("space")
	var e := _earth(Vector3(0, 0, 0), 3000.0)
	upd = func(_tt: float, dt: float): e.rotation.y += dt * 0.03
	keys = [[0.0, Vector3(5200, 1400, 6400), Vector3(0, 0, 0), 38.0], [10.0, Vector3(3800, 900, 5200), Vector3(-600, 200, 0), 42.0]]

func _shot_ark(_ctx: Dictionary) -> void:
	_env("space")
	_earth(Vector3(0, -4200, -2000), 3600.0)
	var bs := boss("sefine"); bs.scale = Vector3.ONE * 9.0; bs.position = Vector3(1400, 700, -3200)
	upd = func(_tt: float, dt: float): bs.position += Vector3(-110, -15, 120) * dt; bs.rotation.y += dt * 0.02
	keys = [[0.0, Vector3(0, -300, 1500), Vector3(1400, 700, -3200), 55.0], [10.0, Vector3(-200, -260, 1100), func(): return bs.position, 48.0]]

func _shot_envoy(_ctx: Dictionary) -> void:
	_env("dusk"); _ground(BIOMES[14].g); _ruins(false); _clouds(18, 9000.0, 900.0, 1300.0, 300.0, 700.0)
	var bs := boss("sefine"); bs.scale = Vector3.ONE * 6.0; bs.position = Vector3(0, 2800, -5600)
	var shuttle := vahar("girdap"); shuttle.position = Vector3(0, 900, -1600); shuttle.scale = Vector3.ONE * 1.6
	var beam := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 40; cm.bottom_radius = 160; cm.height = 1300; beam.mesh = cm
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; bm.albedo_color = Color(1.0, 0.95, 0.75, 0.12)
	beam.material_override = bm; add_child(beam)
	upd = func(tt: float, dt: float):
		shuttle.position.y = maxf(-120.0, 900.0 - tt * 140.0); shuttle.rotation.y += dt * 0.4
		beam.position = shuttle.position + Vector3(0, -650, 0)
	keys = [[0.0, Vector3(500, -300, 600), func(): return shuttle.position, 45.0], [10.0, Vector3(300, -330, 200), func(): return shuttle.position + Vector3(0, 200, 0), 40.0]]

func _shot_betrayal(_ctx: Dictionary) -> void:
	_env("night"); _ground(BIOMES[14].g); _ruins(true); env.fog_light_color = Color(0.35, 0.12, 0.08)
	sky_mat.set_shader_parameter("hor_col", Color(0.4, 0.1, 0.06)) # yanan şehrin kızıllığı
	var bs := boss("sefine"); bs.scale = Vector3.ONE * 6.0; bs.position = Vector3(0, 2600, -5600)
	glow_lights(bs, Color(1.0, 0.35, 0.25), 140, 220.0)
	var rim := DirectionalLight3D.new(); rim.light_color = Color(1.0, 0.5, 0.35); rim.light_energy = 1.2; rim.rotation_degrees = Vector3(-10, 160, 0); add_child(rim)
	var beams := []
	for i in 4:
		var b := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 18; cm.bottom_radius = 30; cm.height = 4200; b.mesh = cm
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; m.albedo_color = Color(3.0, 0.3, 0.4)
		b.material_override = m; b.visible = false; add_child(b); beams.append(b)
	upd = func(tt: float, _dt: float):
		for i in beams.size():
			var on := fmod(tt + i * 0.7, 2.8) < 0.9
			var b: MeshInstance3D = beams[i]
			if on and not b.visible:
				var hit := Vector3(randf_range(-2000, 2000), -300, randf_range(-3000, -800))
				var top := bs.position + Vector3(randf_range(-600, 600), -200, 0)
				b.position = (hit + top) / 2.0; b.basis = Basis.looking_at((hit - top).normalized(), Vector3.FORWARD) * Basis(Vector3.RIGHT, PI / 2)
				b.scale = Vector3(1, hit.distance_to(top) / 4200.0, 1); boom(hit, 1.8)
			b.visible = on
	keys = [[0.0, Vector3(-600, -250, 900), Vector3(0, 900, -3000), 55.0], [10.0, Vector3(400, -200, 600), Vector3(0, 400, -3000), 50.0]]

func _env_tint(c: Color) -> void:
	env.adjustment_enabled = true; sun.light_color = sun.light_color.lerp(c, 0.5)

func _shot_squadron(ctx: Dictionary) -> void:
	_world(ctx.get("biome", 6))
	var lead := _hero(Vector3(0, 200, 0))
	var wing := []
	for o in [Vector3(-110, -10, 90), Vector3(110, -10, 90), Vector3(-220, -20, 180)]:
		var p := plane(["dogan", "kartal", "simsek"][wing.size()]); p.position = lead.position + o; wing.append([p, o])
		trail(p, Vector3(0, 0, 40), Color(1, 1, 1, 0.2), 0.9)
	upd = func(tt: float, dt: float):
		lead.position += Vector3(0, 0, -380) * dt; lead.rotation.z = sin(tt * 0.6) * 0.15
		for w in wing: w[0].position = lead.position + w[1] + Vector3(sin(tt * 1.3 + w[1].x) * 6, sin(tt + w[1].x) * 4, 0); w[0].rotation.z = lead.rotation.z
	keys = [[0.0, func(): return lead.position + Vector3(500, 120, -700), func(): return lead.position, 45.0],
		[5.0, func(): return lead.position + Vector3(-300, 60, 400), func(): return lead.position + Vector3(0, 0, -300), 55.0],
		[10.0, func(): return lead.position + Vector3(0, 900, 1), func(): return lead.position, 50.0]]

func _shot_pilot(_ctx: Dictionary) -> void:
	_world(6)
	var hero := _hero(Vector3(0, 0, 0))
	upd = func(tt: float, dt: float): hero.position += Vector3(0, 0, -300) * dt; hero.rotation.z = sin(tt * 0.9) * 0.35
	keys = [[0.0, func(): return hero.position + Vector3(40, 20, -110), func(): return hero.position + Vector3(0, 6, 0), 50.0],
		[5.0, func(): return hero.position + Vector3(-140, 40, 60), func(): return hero.position, 55.0],
		[10.0, func(): return hero.position + Vector3(0, 30, 260), func(): return hero.position + Vector3(0, 0, -800), 60.0]]

func _shot_base(_ctx: Dictionary) -> void:
	_env("dusk"); env.tonemap_exposure = 0.85 # şafak öncesi üs: pist ışıkları, sığınaklar, arama ışıkları
	sky_mat.set_shader_parameter("hor_col", Color(0.45, 0.32, 0.36)); sky_mat.set_shader_parameter("top_col", Color(0.05, 0.07, 0.16)); sky_mat.set_shader_parameter("stars", 0.6)
	_ground({"amp": 30, "low": Color(0.1, 0.14, 0.08), "mid": Color(0.14, 0.16, 0.12), "high": Color(0.2, 0.2, 0.18), "snow": 2.0})
	var asphalt := StandardMaterial3D.new(); asphalt.albedo_color = Color(0.08, 0.08, 0.09)
	var rw := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(160, 4, 5000); rw.mesh = bm; rw.material_override = asphalt; rw.position = Vector3(0, -390, -1500); add_child(rw)
	for i in 50:
		for sx in [-1, 1]:
			var l := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 3; sm.height = 6; l.mesh = sm; l.material_override = studio._glow(Color(1.0, 0.85, 0.5), 5.0)
			l.position = Vector3(sx * 86, -385, 900 - i * 100); add_child(l)
	for i in 3:
		var h := MeshInstance3D.new(); var hm := SphereMesh.new(); hm.radius = 140; hm.height = 140; hm.is_hemisphere = true; h.mesh = hm
		h.material_override = studio._metal(Color(0.25, 0.27, 0.25), 0.8, 0.3); h.position = Vector3(-520 + i * 340, -392, -300); h.scale = Vector3(1, 0.8, 1.6); add_child(h)
	for i in 8: # pist kenarı ışık havuzları
		var o := OmniLight3D.new(); o.light_color = Color(1.0, 0.8, 0.55); o.light_energy = 3.0; o.omni_range = 260; o.position = Vector3(0, -330, 700 - i * 300); add_child(o)
	for i in 3:
		var f := SpotLight3D.new(); f.light_color = Color(1.0, 0.85, 0.6); f.light_energy = 14.0; f.spot_range = 900; f.spot_angle = 40.0; f.position = Vector3(-520 + i * 340, -200, -150); f.basis = Basis.looking_at(Vector3(0, -1, -0.4).normalized(), Vector3.FORWARD); add_child(f)
	var lights := []
	for x in [-700, 700]:
		var s := SpotLight3D.new(); s.light_color = Color(0.9, 0.95, 1.0); s.light_energy = 8.0; s.spot_range = 5000; s.spot_angle = 6.0; s.position = Vector3(x, -380, -200); add_child(s); lights.append(s)
	var jets := []
	for i in 2: var p := plane(["serce", "dogan"][i]); p.position = Vector3(-60 + i * 120, -380, 400 - i * 150); jets.append(p)
	upd = func(tt: float, _dt: float):
		for i in lights.size(): lights[i].basis = Basis.looking_at(Vector3(sin(tt * 0.5 + i * 2.0) * 0.6, 1.0, -0.4).normalized(), Vector3.FORWARD)
	keys = [[0.0, Vector3(600, -300, 900), Vector3(0, -380, 0), 50.0], [10.0, Vector3(200, -340, 700), Vector3(0, -370, -400), 45.0]]

func _shot_harvest(ctx: Dictionary) -> void:
	var bi: int = ctx.get("biome", 4)
	_world(bi)
	var bs := boss("su_hasat" if bi == 4 else "emici"); bs.position = Vector3(0, 900, -2400); bs.scale = Vector3.ONE * 2.0
	var col := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 60; cm.bottom_radius = 260; cm.height = 1500; col.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = Color(0.6, 0.85, 1.0, 0.35); m.albedo_texture = detail; m.uv1_scale = Vector3(2, 4, 1)
	col.material_override = m; col.position = Vector3(0, 100, -2400); add_child(col)
	var spray := Node3D.new(); spray.position = Vector3(0, -300, -2400); add_child(spray)
	var p := emitter(spray, Color(0.8, 0.92, 1.0, 0.6), 80.0, 3.0, 80, Vector3(0, 500, 0), false, 2.0); p.spread = 15.0
	upd = func(tt: float, dt: float): bs.rotation.y += dt * 0.5; m.uv1_offset = Vector3(tt * 0.3, -tt * 0.8, 0)
	keys = [[0.0, Vector3(1400, 0, 400), Vector3(0, 400, -2400), 48.0], [10.0, Vector3(800, -200, -600), Vector3(0, 700, -2400), 52.0]]

func _shot_forge(_ctx: Dictionary) -> void:
	_world(10)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var ships := []
	for i in 6: var s := vahar(["avci", "topcu", "bomber"][i % 3]); s.position = Vector3(rng.randf_range(-400, 400), -200 - i * 160, -2200 + rng.randf_range(-200, 200)); ships.append(s); emitter(s, Color(2.0, 0.8, 0.3, 0.8), 40.0, 0.6, 20, Vector3(0, -80, 0), true, 0.4)
	_smoke_col(Vector3(0, -300, -2300), 2.5)
	upd = func(_tt: float, dt: float):
		for s in ships: s.position.y += 160.0 * dt; s.rotation.y += dt * 0.3
	keys = [[0.0, Vector3(700, 0, -1200), Vector3(0, -100, -2200), 50.0], [10.0, Vector3(500, 300, -1500), Vector3(0, 500, -2200), 55.0]]

func _shot_ruins(_ctx: Dictionary) -> void:
	_world(14)
	var bs := boss("varek"); bs.position = Vector3(0, 1600, -2400); bs.scale = Vector3.ONE * 1.6
	emitter(bs, Color(2.2, 0.4, 0.4, 0.8), 60.0, 0.8, 30, Vector3(0, -120, 0), true, 0.5)
	upd = func(tt: float, dt: float): bs.position.y = maxf(200.0, 1600.0 - tt * 160.0); bs.rotation.y += dt * 0.15
	keys = [[0.0, Vector3(-1200, 250, 900), func(): return bs.position, 50.0], [10.0, Vector3(-600, 120, 300), func(): return bs.position + Vector3(0, -100, 0), 45.0]]
