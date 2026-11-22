extends Control
## Ana menü — ARKFALL. Endüstriyel/agresif arayüz: glitch başlık, kayarak gelen menü, 3D yatan uçak.

const UI = preload("res://scripts/ui.gd")
var main
var plane_spr: Sprite2D
var flame: Node2D # oyundaki egzozla aynı: lülelerden çıkan, gazla değişen alev
var sky_mat: ShaderMaterial
var t := 0.0
var title: Label
var ghosts: Array = []
var glitch_t := 2.0
var status: Label
var settings: Control = null
var open_settings_lang := false # dil değişince menü yeniden kurulur, ayarlar açık kalır

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sky := UI.sky(12); add_child(sky); sky_mat = sky.material
	var shade := TextureRect.new() # soldan kararan perde: yazılar okunaklı kalsın
	var g := Gradient.new(); g.set_color(0, Color(0, 0, 0, 0.82)); g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.width = 256; gt.height = 4
	shade.texture = gt; shade.stretch_mode = TextureRect.STRETCH_SCALE; shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE); shade.offset_right = 760; shade.mouse_filter = MOUSE_FILTER_IGNORE; add_child(shade)
	add_child(UI.girih(0.035))
	Sfx.play_music("music_menu")

	var holder := Node2D.new(); add_child(holder)
	var pd: Dictionary = Data.plane(Save.plane)
	flame = preload("res://scripts/game.gd").Exhaust.new(); flame.noz = pd.noz; flame.electric = pd.id == "simsek"; holder.add_child(flame)
	var add := CanvasItemMaterial.new(); add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; flame.material = add
	if not Data.sheet("plane_" + pd.id): flame.visible = false # eski SVG çiziminde lüle konumları farklı
	plane_spr = Sprite2D.new(); plane_spr.texture = Data.tex("plane_" + pd.id); plane_spr.scale = Vector2.ONE * 2.6; holder.add_child(plane_spr)
	var sh3 := Data.sheet("plane_" + pd.id)
	if sh3: plane_spr.texture = sh3; plane_spr.hframes = 7; plane_spr.frame = 3; plane_spr.scale = Vector2.ONE * 1.5

	# başlık + glitch kopyaları (kırmızı/turkuaz kayma)
	for c in [Color(1.0, 0.1, 0.15, 0.8), Color(0.1, 0.9, 1.0, 0.8)]:
		var gl := UI.lbl(Data.L("ARKFALL"), 170, c, true); gl.position = Vector2(80, 10); gl.visible = false; add_child(gl); ghosts.append(gl)
	title = UI.lbl(Data.L("ARKFALL"), 170, Color(1.0, 0.93, 0.85), true); title.position = Vector2(80, 10); add_child(title)
	var line := ColorRect.new(); line.color = UI.ORANGE; line.position = Vector2(90, 186); line.size = Vector2(0, 4); add_child(line)
	line.create_tween().tween_property(line, "size:x", 460.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var sub := UI.lbl(Data.L("THE LAST SKY   //   OPERASYON SEFİNE"), 22, UI.ORANGE, true); sub.position = Vector2(92, 194); add_child(sub)

	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); v.position = Vector2(70, 250)
	var pts := Save.tree_points()
	v.add_child(UI.button(Data.L("SEFER  —  BÖLÜM %d") % (Save.next_stage() + 1), func(): main.show_stages(), 30, 460))
	var best := "" if Save.endless.is_empty() else Data.L("   [%s]") % UI.mmss(Save.endless[0].time)
	v.add_child(UI.button(Data.L("SONSUZ MOD") + best, func(): main.start_endless(), 24, 460))
	v.add_child(UI.button(Data.L("PİLOT AĞACI") + (Data.L("   [+%d]") % pts if pts > 0 else ""), func(): main.show_tree(), 24, 460))
	v.add_child(UI.button(Data.L("HANGAR"), func(): main.show_hangar(), 24, 460))
	v.add_child(UI.button(Data.L("REKORLAR"), func(): main.show_records(), 24, 460))
	v.add_child(UI.button(Data.L("DEFTER"), func(): main.show_codex(), 24, 460))
	v.add_child(UI.button(Data.L("HİKAYE"), func(): main.play_cine("intro", main.show_menu), 24, 460))
	v.add_child(UI.button(Data.L("AYARLAR"), _open_settings, 24, 460))
	v.add_child(UI.button(Data.L("ÇIKIŞ"), func(): get_tree().quit(), 24, 460))
	add_child(v)
	for i in v.get_child_count(): # menü soldan sırayla kayarak gelir
		var b: Control = v.get_child(i)
		b.modulate.a = 0.0
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "modulate:a", 1.0, 0.25).set_delay(0.08 + i * 0.05)
		tw.tween_property(b, "position:x", 0.0, 0.3).from(-60.0).set_delay(0.08 + i * 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	v.get_child(0).grab_focus.call_deferred()

	var card := UI.pilot_card(); card.custom_minimum_size = Vector2(360, 0)
	UI.at(card, PRESET_BOTTOM_RIGHT, Vector2(-40, -54)); add_child(card)
	status = UI.lbl("", 15, UI.ORANGE, true); status.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT); status.offset_left = -420; status.offset_right = -30; status.offset_top = 24
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; add_child(status)
	var foot := UI.lbl("v0.14", 14, Color(0.5, 0.52, 0.58), true, HORIZONTAL_ALIGNMENT_RIGHT) # tuşlar oyun içinde ve eğitimde gösteriliyor
	foot.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT); foot.offset_left = -120; foot.offset_right = -14; foot.offset_top = -30; foot.offset_bottom = -8
	add_child(foot)
	add_child(UI.scanlines())
	if open_settings_lang or main.dev.has("settings"): reopen_lang = open_settings_lang; _open_settings() # test: --settings

## Ayarlar: ses, tuş ipuçları, eğitimi yeniden göster, tam ekran
func _open_settings() -> void:
	var lb_cb := func() -> Button:
		var lb := UI.button("DİL / LANGUAGE:  " + _lang_name(), func(): pass, 24, 520); lb.pressed.connect(_next_lang); return lb
	settings = UI.settings(self, _close_settings, lb_cb, reopen_lang); reopen_lang = false

var reopen_lang := false
func _lang_name() -> String:
	for l in Data.LANGS:
		if l[0] == Data.lang: return l[1]
	return Data.lang

## Sıradaki dile geç: kaydet, metinleri yeniden yükle, menüyü o dilde yeniden kur
func _next_lang() -> void:
	var i := 0
	for k in Data.LANGS.size():
		if Data.LANGS[k][0] == Data.lang: i = k
	var code: String = Data.LANGS[(i + 1) % Data.LANGS.size()][0]
	Save.lang = code; Save.write(); Data.set_lang(code)
	var m = main.MenuS.new(); m.set("open_settings_lang", true)
	main._do_swap(m)

func _close_settings() -> void:
	Save.write()
	if settings: settings.queue_free(); settings = null

func _unhandled_input(e: InputEvent) -> void:
	if settings and e.is_action_pressed("pause"): _close_settings(); get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	t += dt
	var vs := get_viewport_rect().size
	sky_mat.set_shader_parameter("cam", Vector2(t * 30.0, -t * 140.0))
	sky_mat.set_shader_parameter("view_size", vs)
	# uçak süzülür ve gerçek 3D yatış kareleriyle sağa sola yatar
	var sway := sin(t * 0.6)
	plane_spr.position = Vector2(vs.x * 0.66, vs.y * 0.5 + sin(t * 1.3) * 12.0)
	plane_spr.rotation = sway * 0.12
	if plane_spr.hframes == 7: plane_spr.frame = clampi(int(round(3.0 + sway * 2.6)), 0, 6)
	flame.position = plane_spr.position; flame.rotation = plane_spr.rotation
	flame.sc = plane_spr.scale.y / 0.5; flame.roll = sway * 0.85; flame.thr = 0.42 + 0.08 * sin(t * 2.0); flame.queue_redraw()
	# glitch: birkaç saniyede bir başlık kayar, renk kanalları ayrılır
	glitch_t -= dt
	var on := glitch_t < 0.0
	if glitch_t < -0.16: glitch_t = randf_range(2.0, 4.5)
	title.position.x = 80.0 + (randf_range(-6, 6) if on else 0.0)
	for i in ghosts.size():
		ghosts[i].visible = on
		ghosts[i].position = Vector2(80.0 + (8.0 if i == 0 else -8.0) + randf_range(-3, 3), 10.0 + randf_range(-2, 2))
	status.text = ("● " if fmod(t, 1.2) < 0.6 else "   ") + Data.L("SİSTEM ÇEVRİMİÇİ  //  PİLOT GÜCÜ %d") % Save.power()
