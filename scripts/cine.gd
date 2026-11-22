extends Control
## Fragman tarzı ara sahne: resim + yavaş yakınlaşma (Ken Burns) + sahneye göre parçacık katmanı (kar, kıvılcım, duman...)
## + şimşek/ateş ışığı + konuşan anlatıcı portresi (sınırlı animasyon: ağız, göz kırpma, nefes) + daktilo alt yazı

const UI = preload("res://scripts/ui.gd")
var main
var slides: Array = []
var done: Callable
var i := -1
var img: TextureRect
var cap: Label
var title: Label
var fade: ColorRect
var ch := 0.0
var hold := 0.0
var busy := true
var ended := false
var kb: Tween
var key := ""            # boss anahtarıysa ilk sahne canlı "boss düşüşü" sahnesi olur
const Shots = preload("res://scripts/shots.gd")
var vp: SubViewport      # 3D çekim dünyası
var shot: Node3D
var bars: Array = []
var fx: Control          # parçacık katmanı (resmin üstünde, bantların altında)
var glow: ColorRect      # ışık titremesi / şimşek
var glow_kind := ""
var speaker: UI.Talker
var gt := 0.0
## Sahne -> efektler ve konuşan (slaytta "fx" / "who" varsa onlar geçerli)
const FX := {"cine_earth": ["stars"], "cine_ark": ["stars"], "cine_space": ["stars"], "cine_envoy": ["motes"], "cine_betrayal": ["embers", "lightning"],
	"cine_base": ["smoke"], "cine_mountain": ["snow"], "cine_ice": ["snow"], "cine_desert": ["dust"], "cine_forge": ["embers", "fire"],
	"cine_harvest": ["mist"], "cine_squadron": ["streaks"], "cine_pilot": ["streaks"], "cine_ruins": ["smoke", "embers", "fire"],
	"cine_boss_down": ["embers"], "cine_victory": ["motes"]}
const WHO_BY_IMG := {"cine_boss_down": "cmd", "cine_victory": "cmd", "cine_pilot": "pilot", "cine_envoy": "lyra", "cine_betrayal": "varek"}

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color.BLACK; bg.set_anchors_preset(PRESET_FULL_RECT); add_child(bg)
	img = TextureRect.new(); img.set_anchors_preset(PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(img)
	var vpc := SubViewportContainer.new(); vpc.set_anchors_preset(PRESET_FULL_RECT); vpc.stretch = true; vpc.mouse_filter = MOUSE_FILTER_IGNORE; add_child(vpc)
	vp = SubViewport.new(); vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X; vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA; vpc.add_child(vp)
	fx = Control.new(); fx.set_anchors_preset(PRESET_FULL_RECT); fx.mouse_filter = MOUSE_FILTER_IGNORE; add_child(fx)
	glow = ColorRect.new(); glow.set_anchors_preset(PRESET_FULL_RECT); glow.mouse_filter = MOUSE_FILTER_IGNORE; glow.color = Color(0, 0, 0, 0)
	var am := CanvasItemMaterial.new(); am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; glow.material = am; add_child(glow)
	for top in [true, false]: # sinema bantları
		var bar := ColorRect.new(); bar.color = Color.BLACK
		bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE if top else PRESET_BOTTOM_WIDE)
		add_child(bar); bars.append(bar) # bantlar sahneye kayarak girer (oyundan sinemaya geçiş işareti)
		var tw := bar.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if top: tw.tween_property(bar, "offset_bottom", 64.0, 0.6).from(0.0)
		else: tw.tween_property(bar, "offset_top", -150.0, 0.6).from(0.0)
	cap = UI.lbl("", 22, Color(0.92, 0.95, 1.0), false, HORIZONTAL_ALIGNMENT_CENTER)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE); cap.offset_top = -138; cap.offset_bottom = -20; cap.offset_left = 140; cap.offset_right = -140
	add_child(cap)
	speaker = UI.talker(Vector2(130, 130)); speaker.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT); speaker.offset_left = 8; speaker.offset_top = -144; speaker.offset_right = 138; speaker.offset_bottom = -14
	speaker.visible = false; add_child(speaker)
	title = UI.lbl("", 120, Color(0.9, 1.7, 2.1), true, HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_and_offsets_preset(PRESET_CENTER); title.offset_left = -640; title.offset_right = 640; title.offset_top = -120; title.offset_bottom = 40
	add_child(title)
	var hint := UI.lbl(Data.L("Tıkla / SPACE: devam      ESC: atla"), 13, Color(0.5, 0.58, 0.7), false, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT); hint.offset_left = -400; hint.offset_right = -20; hint.offset_top = 22
	add_child(hint)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 0); fade.set_anchors_preset(PRESET_FULL_RECT); fade.mouse_filter = MOUSE_FILTER_IGNORE; add_child(fade)
	Sfx.play_music("music_menu")
	_next.call_deferred()

func _next() -> void:
	i += 1
	if i >= slides.size(): _finish(); return
	busy = true
	var tw := create_tween()
	if i > 0: tw.tween_property(fade, "color:a", 1.0, 0.3) # slaytlar arası kısa karartma; ilk slayt oyundan çapraz geçişle gelir
	tw.tween_callback(_show.bind(slides[i]))
	tw.tween_property(fade, "color:a", 0.0, 0.5 if i > 0 else 0.01)
	tw.tween_callback(func(): busy = false)

func _show(s: Dictionary) -> void:
	if shot: shot.queue_free()
	shot = Shots.new(); vp.add_child(shot); img.visible = false
	shot.build(s.img, _ctx())
	cap.text = Data.L(s.text); cap.visible_characters = 0; ch = 0.0; hold = 0.0
	title.text = Data.L(s.get("title", "")); title.modulate.a = 0.0
	if title.text != "": create_tween().tween_property(title, "modulate:a", 1.0, 1.8)
	Sfx.play("whoosh", 0.0)
	var who: String = s.get("who", WHO_BY_IMG.get(s.img, ""))
	speaker.visible = who != "" and Data.WHO.has(who)
	if speaker.visible: speaker.set_face(Data.WHO[who].tex)
	_set_fx(s.get("fx", [])) # 3D çekimler kendi efektlerini taşır; 2D katman yalnızca istenirse

## Çekim bağlamı: bölüm sonu (ilk slayt) o bölümün haritası; sonraki slaytlar bir sonraki bölgenin haritası
func _ctx() -> Dictionary:
	var si := -1
	for k in Data.STAGES.size():
		if Data.STAGES[k].boss == key: si = k
	if si < 0: return {"boss": key}
	return {"boss": key, "biome": Data.STAGES[mini(si + (1 if i > 0 else 0), Data.STAGES.size() - 1)].biome}

## Sahne parçacıkları: hepsi kodla, glow dokusundan
func _set_fx(kinds: Array) -> void:
	for c in fx.get_children(): c.queue_free()
	glow_kind = ""
	var vs := get_viewport_rect().size
	for k in kinds:
		if k in ["lightning", "fire"]: glow_kind = k; continue
		var p := CPUParticles2D.new(); p.texture = Data.tex("glow"); fx.add_child(p)
		var add := CanvasItemMaterial.new(); add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE; p.position = vs / 2.0; p.emission_rect_extents = vs / 2.0
		p.direction = Vector2.UP; p.spread = 20.0; p.gravity = Vector2.ZERO; p.preprocess = 4.0
		var g := Gradient.new()
		match k:
			"stars": # yıldız parıltısı: yerinde söner yanar
				p.amount = 70; p.lifetime = 3.0; p.initial_velocity_min = 0; p.initial_velocity_max = 2; p.scale_amount_min = 0.04; p.scale_amount_max = 0.12; p.material = add
				g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1.4, 1.4, 1.6, 0.9), Color(1, 1, 1, 0)]); g.offsets = PackedFloat32Array([0, 0.5, 1])
			"motes": # süzülen ışık zerreleri
				p.amount = 50; p.lifetime = 6.0; p.initial_velocity_min = 6; p.initial_velocity_max = 18; p.spread = 60; p.scale_amount_min = 0.05; p.scale_amount_max = 0.14; p.material = add
				g.colors = PackedColorArray([Color(1.6, 1.3, 0.7, 0), Color(1.6, 1.3, 0.7, 0.7), Color(1.6, 1.3, 0.7, 0)]); g.offsets = PackedFloat32Array([0, 0.5, 1])
			"embers": # yükselen kıvılcımlar
				p.amount = 90; p.lifetime = 4.0; p.initial_velocity_min = 30; p.initial_velocity_max = 90; p.spread = 35; p.gravity = Vector2(12, -8); p.scale_amount_min = 0.04; p.scale_amount_max = 0.1; p.material = add
				p.position = Vector2(vs.x / 2.0, vs.y); p.emission_rect_extents = Vector2(vs.x / 2.0, 20)
				g.colors = PackedColorArray([Color(2.4, 1.0, 0.3, 0), Color(2.4, 0.9, 0.2, 0.9), Color(1.2, 0.3, 0.1, 0)]); g.offsets = PackedFloat32Array([0, 0.2, 1])
			"snow":
				p.amount = 160; p.lifetime = 7.0; p.direction = Vector2.DOWN; p.initial_velocity_min = 30; p.initial_velocity_max = 70; p.spread = 25; p.gravity = Vector2(14, 6); p.scale_amount_min = 0.04; p.scale_amount_max = 0.11
				p.position = Vector2(vs.x / 2.0, -20); p.emission_rect_extents = Vector2(vs.x * 0.6, 10)
				g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)]); g.offsets = PackedFloat32Array([0, 0.15, 1])
			"dust": # yatay kum
				p.amount = 140; p.lifetime = 5.0; p.direction = Vector2.RIGHT; p.initial_velocity_min = 80; p.initial_velocity_max = 160; p.spread = 8; p.scale_amount_min = 0.05; p.scale_amount_max = 0.16
				p.position = Vector2(-20, vs.y / 2.0); p.emission_rect_extents = Vector2(10, vs.y / 2.0)
				g.colors = PackedColorArray([Color(0.9, 0.7, 0.45, 0), Color(0.9, 0.7, 0.45, 0.5), Color(0.9, 0.7, 0.45, 0)]); g.offsets = PackedFloat32Array([0, 0.3, 1])
			"smoke", "mist": # ağır, yavaş duman / buhar
				p.amount = 22; p.lifetime = 9.0; p.initial_velocity_min = 8; p.initial_velocity_max = 22; p.spread = 40; p.scale_amount_min = 3.0; p.scale_amount_max = 6.0
				var sc := Color(0.08, 0.07, 0.07) if k == "smoke" else Color(0.7, 0.85, 1.0)
				g.colors = PackedColorArray([Color(sc, 0), Color(sc, 0.28 if k == "smoke" else 0.12), Color(sc, 0)]); g.offsets = PackedFloat32Array([0, 0.4, 1])
			"streaks": # hız çizgileri: yukarıdan aşağı akan bulut parçaları
				p.amount = 40; p.lifetime = 1.2; p.direction = Vector2.DOWN; p.initial_velocity_min = 700; p.initial_velocity_max = 1100; p.spread = 2; p.scale_amount_min = 0.3; p.scale_amount_max = 0.8
				p.position = Vector2(vs.x / 2.0, -40); p.emission_rect_extents = Vector2(vs.x / 2.0, 10); p.material = add
				g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(0.9, 0.95, 1.0, 0.25), Color(1, 1, 1, 0)]); g.offsets = PackedFloat32Array([0, 0.5, 1])
		p.color_ramp = g

func _process(dt: float) -> void:
	gt += dt
	match glow_kind: # ışık katmanı
		"fire": glow.color = Color(1.0, 0.35, 0.1, 0.06 + 0.04 * sin(gt * 9.0) * sin(gt * 3.7))
		"lightning":
			var fl := 0.0
			if fmod(gt, 4.3) < 0.08 or (fmod(gt, 4.3) > 0.16 and fmod(gt, 4.3) < 0.22): fl = 0.35 # çift çakan şimşek
			glow.color = Color(0.7, 0.75, 1.0, fl)
		_: glow.color.a = 0.0
	if speaker: speaker.talking = cap.visible_characters != -1 and not busy
	if busy or ended: return
	if cap.visible_characters != -1:
		ch += dt * 38.0
		cap.visible_characters = -1 if int(ch) >= cap.text.length() else int(ch)
	else:
		hold += dt
		if hold > 3.2 and (shot == null or shot.t > 8.5): _next() # kamera hareketi yarıda kesilmesin

func _input(e: InputEvent) -> void:
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	if e.is_action_pressed("pause"): _finish()
	elif click or e.is_action_pressed("ok"):
		if busy: return
		if cap.visible_characters != -1: cap.visible_characters = -1
		else: _next()
	else: return
	get_viewport().set_input_as_handled()

func _finish() -> void:
	if ended: return
	ended = true
	done.call()
