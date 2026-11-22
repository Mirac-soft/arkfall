extends RefCounted
## Arayüz yardımcıları (tüm ekranlar aynı stili kullanır)

const CYAN := Color("38d9c8") # kimlik: turkuaz
const GOLD := Color("ffb547") # kimlik: kehribar
const DIM := Color(0.62, 0.7, 0.82)

static func lbl(text: String, size := 18, col := Color.WHITE, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = Data.L(text)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_font_override("font", Data.font_bold if bold else Data.font) # tema zinciri CanvasLayer altında güvenilir değil
	return l

static func box(bg := Color(0.02, 0.04, 0.08, 0.88), border := CYAN, radius := 10, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(radius); s.set_content_margin_all(14)
	s.shadow_color = Color(border, 0.25); s.shadow_size = 6
	return s

static func panel(border := CYAN) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Selçuklu yıldızlı köşeli çerçeve (9 parçalı doku)
static func frame() -> StyleBoxTexture:
	var s := StyleBoxTexture.new(); s.texture = Data.tex("ui_frame")
	s.texture_margin_left = 30; s.texture_margin_right = 30; s.texture_margin_top = 30; s.texture_margin_bottom = 30
	s.set_content_margin_all(18)
	return s
static func btn_style(name: String) -> StyleBoxTexture:
	var s := StyleBoxTexture.new(); s.texture = Data.tex(name)
	s.texture_margin_left = 16; s.texture_margin_right = 16; s.texture_margin_top = 14; s.texture_margin_bottom = 14
	s.content_margin_left = 22; s.content_margin_right = 14; s.content_margin_top = 6; s.content_margin_bottom = 6
	return s
## Menü arka planına hafif girih (geometrik yıldız) deseni
static func girih(alpha := 0.05) -> TextureRect:
	var r := TextureRect.new(); r.texture = Data.tex("girih"); r.stretch_mode = TextureRect.STRETCH_TILE
	r.set_anchors_preset(Control.PRESET_FULL_RECT); r.modulate = Color(0.6, 1.0, 0.95, alpha); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
## Uçağın 3D çekilmiş düz (yatışsız) karesi; yoksa SVG
static func plane_tex(id: String) -> Texture2D:
	var sh := Data.sheet("plane_" + id)
	if sh == null: return Data.tex("plane_" + id)
	var a := AtlasTexture.new(); a.atlas = sh; a.region = Rect2(sh.get_width() / 7 * 3, 0, sh.get_width() / 7, sh.get_height())
	return a

const ORANGE := Color("ff6a1a") # arayüz vurgu rengi (endüstriyel, agresif)

## DOOM tarzı düğme: kutusuz, sola dayalı sert yazı; üstüne gelince soldan turuncu bar süpürülür
static func button(text: String, cb: Callable, size := 24, w := 320.0) -> Button:
	var b := Button.new()
	b.text = "    " + Data.L(text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(w, 48)
	b.add_theme_font_override("font", Data.font_bold)
	b.add_theme_font_size_override("font_size", size + 8)
	for st in ["normal", "hover", "focus", "pressed", "disabled"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.36, 0.4))
	var grad := Gradient.new(); grad.set_color(0, Color(ORANGE, 0.95)); grad.set_color(1, Color(ORANGE, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = grad; gt.width = 256; gt.height = 8
	var bar := TextureRect.new(); bar.texture = gt; bar.stretch_mode = TextureRect.STRETCH_SCALE; bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_behind_parent = true; bar.scale = Vector2(0, 1); b.add_child(bar)
	var tick := ColorRect.new(); tick.color = Color(ORANGE, 0.35); tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); tick.offset_right = 5; tick.offset_top = 6; tick.offset_bottom = -6; b.add_child(tick)
	var on := func():
		if b.disabled: return
		bar.pivot_offset = Vector2(0, b.size.y / 2.0)
		b.create_tween().tween_property(bar, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tick.color = Color(1.0, 0.75, 0.4); Sfx.play("click", 0.0)
	var off := func():
		if b.has_focus(): return
		b.create_tween().tween_property(bar, "scale:x", 0.0, 0.12)
		tick.color = Color(ORANGE, 0.35)
	b.focus_entered.connect(on); b.focus_exited.connect(off)
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	b.pressed.connect(func(): Sfx.play("select", 0.0); cb.call())
	return b

## Tüm menülerde endüstriyel ekran dokusu (tarama çizgileri + köşe karartma)
static func scanlines() -> ColorRect:
	var c := ColorRect.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new(); m.shader = load("res://scripts/scan.gdshader"); c.material = m
	return c

static func bar(w: float, h: float, col: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, h); p.show_percentage = false; p.max_value = 1.0; p.step = 0.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(1, 1, 1, 0.08); bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new(); fg.bg_color = col; fg.set_corner_radius_all(3)
	p.add_theme_stylebox_override("background", bg); p.add_theme_stylebox_override("fill", fg)
	return p

static func pic(t: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t; r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Konuşan portre (sınırlı animasyon): konuşurken ağız kareleri değişir, arada göz kırpar, hafifçe nefes alır.
## Kareler art/<ad>_talk.svg ve <ad>_blink.svg; yoksa sabit resim gibi davranır.
class Talker extends TextureRect:
	var base: Texture2D
	var talk_t: Texture2D
	var blink_t: Texture2D
	var talking := false
	var t := 0.0
	var next_blink := 2.0
	var blink_left := 0.0
	func set_face(name: String) -> void:
		base = Data.tex(name)
		var tp := "res://art/%s_talk.svg" % name
		talk_t = load(tp) if ResourceLoader.exists(tp) else null
		var bp := "res://art/%s_blink.svg" % name
		blink_t = load(bp) if ResourceLoader.exists(bp) else null
		texture = base
	func _process(dt: float) -> void:
		t += dt
		pivot_offset = Vector2(size.x / 2.0, size.y) # nefes: alttan hafif genişleme
		scale = Vector2(1.0 + 0.006 * sin(t * 2.1), 1.0 + 0.014 * sin(t * 2.1))
		blink_left -= dt; next_blink -= dt
		if next_blink <= 0.0: blink_left = 0.12; next_blink = randf_range(2.2, 4.8)
		var open: bool = talking and talk_t != null and fmod(t * 7.0 + sin(t * 3.0), 2.0) < 1.0 # düzensiz ağız hareketi
		texture = blink_t if blink_left > 0.0 and blink_t else (talk_t if open else base)

static func talker(size: Vector2) -> Talker:
	var r := Talker.new()
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Ayarlar paneli (ana menü ve oyun içi duraklat menüsü ortak): ses yüzdesi, tuş ipuçları, eğitim, tam ekran (+ menüde dil)
static func settings(parent: Control, close: Callable, extra: Callable = Callable(), focus_extra := false) -> Control:
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); parent.add_child(root)
	var dim := ColorRect.new(); dim.color = Color(0, 0.02, 0.06, 0.75); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	var p := panel(); p.custom_minimum_size = Vector2(560, 0); at(p, Control.PRESET_CENTER, Vector2.ZERO); root.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); p.add_child(v)
	v.add_child(lbl(Data.L("AYARLAR"), 40, Color(2.4, 2.0, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER))
	var vh := HBoxContainer.new(); vh.add_theme_constant_override("separation", 16); v.add_child(vh)
	var vl := lbl("    " + Data.L("SES: ") + "%d%%" % Save.volume, 32, Color(0.72, 0.74, 0.78), true); vl.custom_minimum_size = Vector2(230, 48); vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; vh.add_child(vl)
	var first := HSlider.new(); first.min_value = 0; first.max_value = 100; first.step = 5; first.value = Save.volume
	first.custom_minimum_size = Vector2(280, 24); first.size_flags_vertical = Control.SIZE_SHRINK_CENTER; vh.add_child(first)
	var track := StyleBoxFlat.new(); track.bg_color = Color(0.08, 0.09, 0.11); track.border_color = Color(0.35, 0.36, 0.4); track.set_border_width_all(1); track.content_margin_top = 5; track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new(); fill.bg_color = ORANGE; fill.content_margin_top = 5; fill.content_margin_bottom = 5
	first.add_theme_stylebox_override("slider", track); first.add_theme_stylebox_override("grabber_area", fill); first.add_theme_stylebox_override("grabber_area_highlight", fill)
	first.value_changed.connect(func(x: float): Save.volume = int(x); Sfx.set_volume(Save.volume); vl.text = "    " + Data.L("SES: ") + "%d%%" % Save.volume)
	first.drag_ended.connect(func(_c): Save.write(); Sfx.play("click", 0.0))
	_opt(v, func(): return Data.L("EFEKT OPAKLIĞI: ") + "%d%%" % Save.fx_alpha, func(): Save.fx_alpha = {100: 75, 75: 50, 50: 30}.get(Save.fx_alpha, 100))
	_opt(v, func(): return Data.L("HASAR SAYILARI: ") + [Data.L("KAPALI"), Data.L("SADECE KRİTİK"), Data.L("HEPSİ")][Save.dmg_nums], func(): Save.dmg_nums = (Save.dmg_nums + 1) % 3)
	_opt(v, func(): return Data.L("3D ARKA PLAN: ") + (Data.L("AÇIK") if Save.bg3d else Data.L("KAPALI")), func(): Save.bg3d = not Save.bg3d)
	_opt(v, func(): return Data.L("TUŞ İPUÇLARI: ") + (Data.L("AÇIK") if Save.hints else Data.L("KAPALI")), func(): Save.hints = not Save.hints)
	_opt(v, func(): return Data.L("EĞİTİM: ") + (Data.L("SONRAKİ UÇUŞTA") if not Save.tutorial_done else Data.L("TEKRAR GÖSTER")), func(): Save.tutorial_done = false)
	_opt(v, func(): return Data.L("TAM EKRAN: ") + (Data.L("AÇIK") if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else Data.L("KAPALI")),
		func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	var ex: Button = extra.call() if extra.is_valid() else null
	if ex: v.add_child(ex)
	v.add_child(button(Data.L("GERİ"), func(): Save.write(); root.queue_free(); close.call(), 24, 520))
	var cr := lbl("Jet audio: Work With Sounds / Torsten Nilsson (CC BY 4.0)  •  Sonic boom: AirMan / SoundBible (CC BY 3.0)", 11, Color(0.5, 0.52, 0.58)) # lisans gereği isim gösterimi
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cr.custom_minimum_size = Vector2(520, 0); v.add_child(cr)
	(ex if focus_extra and ex else first).grab_focus.call_deferred()
	return root

## Tıklanınca ayarı değiştirip kendi yazısını yenileyen düğme
static func _opt(v: VBoxContainer, txt: Callable, act: Callable) -> Button:
	var b := button(txt.call(), func(): pass, 24, 520)
	b.pressed.connect(func(): act.call(); Save.write(); b.text = "    " + txt.call())
	v.add_child(b)
	return b

static func sky(biome := 12) -> ColorRect:
	var c := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/sky.gdshader")
	m.set_shader_parameter("biome", biome)
	m.set_shader_parameter("ntex", noise_tex())
	m.set_shader_parameter("stex", star_tex())
	c.material = m
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Kontrolü ekranın bir noktasına sabitler; boyutu belli olunca kenardan içeri doğru büyür
static func at(c: Control, preset: int, pos := Vector2.ZERO) -> Control:
	const GROW := [Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN]
	c.set_anchors_preset(preset)
	c.offset_left = pos.x; c.offset_right = pos.x; c.offset_top = pos.y; c.offset_bottom = pos.y
	c.grow_horizontal = GROW[int(c.anchor_left * 2)]
	c.grow_vertical = GROW[int(c.anchor_top * 2)]
	return c

## Gökyüzü shader'ının kullandığı, kendini tekrar eden gürültü dokusu (bir kez üretilir)
static var _ntex: NoiseTexture2D
static func noise_tex() -> NoiseTexture2D:
	if _ntex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; n.frequency = 0.008; n.fractal_octaves = 5
		_ntex = NoiseTexture2D.new()
		_ntex.width = 512; _ntex.height = 512; _ntex.seamless = true; _ntex.generate_mipmaps = true; _ntex.noise = n
	return _ntex

## Yıldız dokusu: hücresel gürültü = rastgele dağılmış noktalar
static var _stex: NoiseTexture2D
static func star_tex() -> NoiseTexture2D:
	if _stex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR; n.frequency = 0.035; n.fractal_type = FastNoiseLite.FRACTAL_NONE
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		_stex = NoiseTexture2D.new()
		_stex.width = 512; _stex.height = 512; _stex.seamless = true; _stex.noise = n
	return _stex

static func mmss(sec: float) -> String:
	return Data.L("%02d:%02d") % [int(sec) / 60, int(sec) % 60]

## Pilot kartı (menü ve hangarda): rütbe, pilot puanı ve sıradaki uçak
static func pilot_card() -> PanelContainer:
	var info: Dictionary = Data.rank_info(Save.xp)
	var p := panel()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	v.add_child(lbl(Data.L("PİLOT ŞAHİN-1"), 13, DIM, true))
	var h := HBoxContainer.new(); v.add_child(h)
	var rn := lbl(Data.rank_name(info.level), 26, Color.WHITE, true); rn.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(rn)
	h.add_child(lbl(Data.L("SV %d") % info.level, 26, GOLD, true))
	var b := bar(300, 10, GOLD); b.value = float(info.into) / info.need; v.add_child(b)
	v.add_child(lbl(Data.L("Pilot gücü: %d puan yatırılmış  •  %d harcanabilir") % [Save.power(), Save.tree_points()], 14, Color(2.0, 1.8, 0.8), true))
	var next = null
	for pl in Data.PLANES:
		if not Save.unlocked(pl):
			next = pl; break
	if next: v.add_child(lbl(Data.L("Sonraki uçak: %s (Bölüm %d'i geç)") % [Data.L(next.name), next.unlock], 15, next.color, true))
	else: v.add_child(lbl(Data.L("Tüm uçaklar açık!"), 15, Color("57ff9a"), true))
	return p
