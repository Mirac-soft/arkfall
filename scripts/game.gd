extends Node2D
## ARKFALL — oyun: açık gökyüzü, otomatik silahlar, sürü, bosslar, hikaye

const UI = preload("res://scripts/ui.gd")
const SkinS = preload("res://scripts/skin.gd")

var main
var dev := {}

# ================= Varlıklar =================
class Enemy extends Sprite2D:
	var kind := ""
	var d: Dictionary
	var hp := 1.0
	var maxhp := 1.0
	var spd := 50.0
	var dmg := 5.0
	var xpv := 1
	var r := 16.0
	var t := 0.0
	var st := 0
	var tm := 0.0
	var tm2 := 0.0
	var ang := 0.0
	var flip := 1.0
	var flash := 0.0
	var vel := Vector2.ZERO
	var kb := Vector2.ZERO
	var lock := Vector2.ZERO
	var boss := false
	var dead := false
	var hitcd := 0.0
	var bank := 0.0
	var prot := 0.0
	var base_sc := 1.0
	var armor := 0.0
	var elite := false
	var tint := Color.WHITE
	var is3d := false
	var eng: Sprite2D = null   # motor ışığı (türün renginde)
	var aim: Line2D = null     # keskin nişancı nişan çizgisi
	var core: Sprite2D = null  # nabız gibi atan çekirdek ışığı

class Shot extends Sprite2D:
	var kind := "bullet"
	var vel := Vector2.ZERO
	var dmg := 10.0
	var pierce := 0
	var life := 2.0
	var rad := 0.0
	var target = null
	var hit := {}
	var tick := 0.0     # napalm / taret zamanlayıcısı
	var period := 0.0
	var ret := false    # bıçak geri dönüyor
	var rng := 0.0
	var dead := false

class EBullet extends Sprite2D:
	var vel := Vector2.ZERO
	var r := 6.0
	var dmg := 8.0
	var life := 9.0
	var a := 0.0
	var sp := 100.0
	var av := 0.0
	var acc := 0.0
	var maxsp := 400.0
	var split := 0.0
	var heavy := false
	var dead := false

class Gem extends Sprite2D:
	var kind := "xp"
	var val := 1
	var mag := false
	var vel := Vector2.ZERO
	var dead := false

## Jet egzozu: her lüleden ayrı, gaz koluyla (thr) uzayan alev. 0 = rölanti (sadece kızgın lüle),
## ~0.45 = askeri güç (kısa turuncu alev), 1 = art yakıcı (uzun alev + şok elmasları).
class Exhaust extends Node2D:
	var noz: Array = []
	var thr := 0.0
	var sc := 1.0
	var roll := 0.0
	var electric := false
	var kind := ""                 # kozmetik alev stili (Data.COSMETICS, boş: varsayılan)
	var c0 := Color(1.2, 0.4, 0.1)
	var c1 := Color(1.5, 1.05, 0.55)
	func _cone(p: Vector2, r0: float, r1: float, ln: float, c: Color) -> void:
		var e := Color(c, 0.0)
		var m := Color(c, c.a * 0.55)
		draw_polygon(PackedVector2Array([p + Vector2(-r0, 0), p + Vector2(r0, 0), p + Vector2(r0 * 0.75, ln * 0.4), p + Vector2(-r0 * 0.75, ln * 0.4)]), PackedColorArray([c, c, m, m]))
		draw_polygon(PackedVector2Array([p + Vector2(-r0 * 0.75, ln * 0.4), p + Vector2(r0 * 0.75, ln * 0.4), p + Vector2(r1, ln), p + Vector2(-r1, ln)]), PackedColorArray([m, m, e, e]))
	func _draw() -> void:
		var cr := cos(roll * deg_to_rad(55.0)) # yatışta lüleler gövde eksenine yaklaşır
		var outer := Color(0.4, 0.6, 1.5) if electric else Color(1.2, 0.4, 0.1)
		var inner := Color(1.0, 1.15, 1.7) if electric else Color(1.5, 1.05, 0.55)
		var now := Time.get_ticks_msec() / 1000.0
		if kind != "":
			outer = Color(c0.r * 1.6, c0.g * 1.6, c0.b * 1.6)
			inner = Color(c1.r * 1.7, c1.g * 1.7, c1.b * 1.7)
			if kind == "legend": var h := Color.from_hsv(fmod(now * 0.08, 1.0), 0.5, 1.8); outer = outer.lerp(h, 0.35)
		var lk: float = {"long": 1.6, "twin": 1.4, "diamond": 1.5, "forked": 1.3, "plasma": 1.4, "nova": 1.9, "legend": 1.9}.get(kind, 1.0)
		for n in noz:
			var p := Vector2(n[0] * cr, n[1]) * sc
			var r: float = n[2] * sc
			var ab := smoothstep(0.55, 1.0, thr) # art yakıcı payı
			var ln := r * (1.2 + thr * 5.0 + ab * 7.0) * randf_range(0.9, 1.1) * lk
			draw_circle(p, r * 0.8, Color(1.3, 0.38, 0.1, 0.55 + 0.3 * thr)) # kızgın lüle ağzı
			if thr > 0.08:
				if kind == "forked":
					for dx in [-1.0, 0.0, 1.0]:
						draw_set_transform(p, dx * 0.28); _cone(Vector2.ZERO, r * 0.7, r * 0.1, ln * (0.8 if dx != 0.0 else 1.0), Color(outer, 0.18 + 0.5 * thr))
					draw_set_transform(Vector2.ZERO)
				else: _cone(p, r * 0.95, r * 0.2, ln, Color(outer, 0.18 + 0.5 * thr))
				_cone(p, r * 0.6, r * 0.08, ln * (0.9 if kind == "twin" else 0.6), Color(inner, 0.25 + 0.6 * thr))
				if kind in ["nova", "legend"]:
					for k in 3: draw_circle(p + Vector2(0, r), r * (1.4 + k * 0.9), Color(inner, (0.22 - k * 0.06) * thr))
				if kind in ["plasma", "legend"]:
					for k in 2:
						var ph := fmod(now * 3.0 + k * 0.5 + n[0] * 0.1, 1.0)
						draw_set_transform(p + Vector2(0, ln * ph * 0.8), 0.0, Vector2(1.0, 0.35))
						draw_arc(Vector2.ZERO, r * (0.8 + ph), 0.0, TAU, 20, Color(inner, (1.0 - ph) * thr), 1.6)
					draw_set_transform(Vector2.ZERO)
			if ab > 0.0 or (kind == "diamond" and thr > 0.3): # şok elmasları
				var k2 := maxf(ab, 0.7 if kind == "diamond" else 0.0)
				for i in 3:
					var y := ln * (0.16 + 0.15 * i)
					draw_circle(p + Vector2(0, y), r * (0.42 - 0.08 * i), Color(inner, k2 * (0.7 - 0.18 * i)))

## Ekran dışındaki elit gemi ve ikmal kapsülünü kenarda yanıp sönen okla gösterir.
class OffPointer extends Control:
	var g
	func _draw() -> void:
		var c: Vector2 = g.cam.get_screen_center_position()
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		for e in g.enemies:
			if e.elite and not e.dead: _arrow(e.position - c, Color(1.0, 0.75, 0.25, pulse), Data.L("ELİT"))
		for o in g.gems:
			if o.kind == "chest" and not o.dead: _arrow(o.position - c, Color(1.0, 0.6, 0.15, pulse), Data.L("KAPSÜL"))
	func _arrow(rel: Vector2, col: Color, txt: String) -> void:
		var half := size * 0.5 - Vector2(44, 44)
		if absf(rel.x) < half.x + 60.0 and absf(rel.y) < half.y + 60.0: return # ekranda görünüyor
		var k := minf(half.x / maxf(absf(rel.x), 0.01), half.y / maxf(absf(rel.y), 0.01))
		var p := size * 0.5 + rel * k
		var d := rel.normalized(); var n := d.orthogonal()
		draw_colored_polygon(PackedVector2Array([p + d * 18, p + n * 11 - d * 8, p - n * 11 - d * 8]), col)
		var tw: float = Data.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 4.0 # yazı genişliği ölçülür, kesilmez
		draw_string(Data.font_bold, p - d * 34 - Vector2(tw / 2.0, -5), txt, HORIZONTAL_ALIGNMENT_CENTER, tw, 13, col)

## Vurulan gemi: döner, küçülür (aşağı düşüyor), kararır, duman ve ateş bırakır; süre dolunca zemine çarpar.
class Wreck extends Sprite2D:
	var g
	var vel := Vector2.ZERO
	var spin := 4.0
	var life := 1.1
	var k := 1.0
	var sc0 := Vector2.ONE
	var t := 0.0
	var smoke_t := 0.0
	var player := false
	func _process(dt: float) -> void:
		t += dt
		var f := minf(t / life, 1.0)
		position += vel * dt; vel *= 1.0 - minf(1.6 * dt, 1.0)
		rotation += spin * dt * (0.4 + f)
		scale = sc0 * lerpf(1.0, 0.3, f * f)
		modulate = Color.WHITE.lerp(Color(0.28, 0.25, 0.23), f)
		smoke_t -= dt
		if smoke_t <= 0.0:
			smoke_t = 0.04 if player else 0.06
			g._puff(position, Color(0.09, 0.08, 0.08, 0.55), (0.22 + 0.25 * f) * k, Vector2(randf_range(-12, 12), randf_range(-26, -6)), 1.1)
			if randf() < 0.7: g._puff(position + Vector2(randf_range(-4, 4), randf_range(-4, 4)) * k, Color(1.6, 0.6, 0.15, 0.85), 0.16 * k, Vector2.ZERO, 0.2)
		if t >= life:
			g.impact(position, g.impact_kind(), k)
			if not player: g.wrecks -= 1
			queue_free()

## Boss uyarısı: kayan sarı-siyah tehlike şeritleri ve kırmızı nabız (yazılar üstteki etiketlerde)
class WarnFX extends Control:
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt; queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.0, 0.0, 0.1 + 0.08 * sin(t * TAU * 1.5)))
		var cy := size.y * 0.5
		for band in [-1.0, 1.0]:
			var y: float = cy + band * 118.0 - 20.0
			draw_rect(Rect2(0, y, size.x, 40), Color(0.04, 0.03, 0.0, 0.9))
			var off: float = fmod(t * 140.0 * band, 56.0)
			for i in range(-2, int(size.x / 56.0) + 3):
				var x := i * 56.0 + off
				draw_colored_polygon(PackedVector2Array([Vector2(x, y + 40), Vector2(x + 26, y), Vector2(x + 50, y), Vector2(x + 24, y + 40)]), Color(1.0, 0.72, 0.05, 0.92))

class Runway extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-1600, -2600, 3200, 3400), Color(0.15, 0.27, 0.14))
		for k in 34: draw_rect(Rect2(-1600, -2600 + k * 100, 3200, 50), Color(0.17, 0.3, 0.16))
		for k in 7:
			var y := 120.0 - k * 400.0
			draw_rect(Rect2(-460, y - 70, 220, 140), Color(0.3, 0.32, 0.36))
			for s in 6: draw_rect(Rect2(-452, y - 62 + s * 22, 204, 8), Color(0.38, 0.4, 0.45))
			draw_rect(Rect2(260, y - 40, 140, 90), Color(0.28, 0.3, 0.33))
			draw_circle(Vector2(480, y + 10), 30, Color(0.22, 0.4, 0.2))
		draw_rect(Rect2(-100, -2400, 200, 2800), Color(0.24, 0.25, 0.28))
		draw_rect(Rect2(-88, -2400, 176, 2800), Color(0.14, 0.15, 0.17))
		draw_rect(Rect2(-80, -2400, 4, 2800), Color(0.85, 0.87, 0.9)); draw_rect(Rect2(76, -2400, 4, 2800), Color(0.85, 0.87, 0.9))
		for y in range(-2360, 200, 80): draw_rect(Rect2(-3, y, 6, 40), Color(0.9, 0.9, 0.9))
		for k in 8: draw_rect(Rect2(-70 + k * 16 + (12 if k >= 4 else 0), 210, 9, 54), Color(0.9, 0.9, 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(-40, 340), "27", HORIZONTAL_ALIGNMENT_CENTER, 80, 60, Color(0.9, 0.9, 0.9))
		for y in range(-2400, 400, 60):
			draw_circle(Vector2(-96, y), 3.5, Color(1.6, 1.4, 0.7)); draw_circle(Vector2(96, y), 3.5, Color(1.6, 1.4, 0.7))
		draw_circle(Vector2(300, 230), 40, Color(0.35, 0.37, 0.4)); draw_circle(Vector2(300, 230), 26, Color(0.25, 0.6, 0.7))

class HPBar extends Node2D:
	## Her uçağın kendi can göstergesi. Yerel (0,-48) = uçağın merkezi.
	var style := "pill"
	var col := Color.WHITE
	var k := 1.0       # can oranı
	var a := 1.0       # yetenek dolumu (0..1)
	var flag := false  # kalkan hazır / diriliş hakkı
	func _draw() -> void:
		var hc: Color = col * 1.6 if k > 0.35 else Color(2.2, 0.4, 0.4)
		var c := Vector2(0, -48)
		match style:
			"pill": # 5 kapsül
				for i in 5:
					var x := -34.0 + i * 14.0
					draw_rect(Rect2(x, 0, 12, 6), Color(0, 0, 0, 0.6))
					var f := clampf(k * 5.0 - i, 0.0, 1.0)
					if f > 0: draw_rect(Rect2(x + 1, 1, 10 * f, 4), hc)
			"arc": # uçağın altında yay
				draw_arc(c, 44, PI * 0.22, PI * 0.78, 24, Color(0, 0, 0, 0.6), 7.0, true)
				draw_arc(c, 44, PI * 0.78 - PI * 0.56 * k, PI * 0.78, 24, hc, 4.0, true)
				draw_arc(c, 51, PI * 0.35, PI * 0.35 + PI * 0.3 * a, 16, Color(0.6, 2.0, 0.9, 0.8), 2.0, true)
			"bolt": # ince şimşek çizgisi + atılım göstergesi
				draw_rect(Rect2(-38, 0, 76, 4), Color(0, 0, 0, 0.6))
				draw_rect(Rect2(-37, 1, 74 * k, 2), hc)
				draw_colored_polygon(PackedVector2Array([Vector2(38, -3), Vector2(46, 2), Vector2(38, 7)]), hc)
				draw_rect(Rect2(-37, 7, 74 * a, 2), Color(2.5, 2.3, 0.6) if a >= 1.0 else Color(0.6, 0.6, 0.4))
			"armor": # kalın plakalı zırh + kalkan halkası
				draw_rect(Rect2(-34, 0, 68, 9), Color(0, 0, 0, 0.7))
				draw_rect(Rect2(-33, 1, 66 * k, 7), hc)
				for i in range(1, 8): draw_line(Vector2(-33 + i * 66.0 / 8.0, 1), Vector2(-33 + i * 66.0 / 8.0, 8), Color(0, 0, 0, 0.7), 1.5)
				if flag: draw_arc(c, 46, 0, TAU, 40, Color(0.5, 1.4, 2.6, 0.8), 2.5, true)
				else: draw_arc(c, 46, -PI / 2, -PI / 2 + TAU * a, 40, Color(0.4, 0.6, 1.0, 0.35), 1.5, true)
			"flame": # tam halka; diriliş hakkı varsa tüy işareti
				draw_arc(c, 42, 0, TAU, 40, Color(0, 0, 0, 0.5), 5.0, true)
				draw_arc(c, 42, -PI / 2, -PI / 2 + TAU * k, 40, hc, 3.0, true)
				if flag: draw_colored_polygon(PackedVector2Array([c + Vector2(44, -6), c + Vector2(56, -16), c + Vector2(50, 2)]), Color(2.6, 1.2, 0.4))

class DialogBox extends Control:
	var lines: Array
	var done: Callable
	var i := 0
	var ch := 0.0
	var pic: UI.Talker
	var name_l: Label
	var role_l: Label
	var text_l: Label
	var frame: PanelContainer
	func _ready() -> void:
		set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.45); dim.set_anchors_preset(PRESET_FULL_RECT); add_child(dim)
		frame = UI.panel(); frame.custom_minimum_size = Vector2(980, 230)
		UI.at(frame, PRESET_CENTER_BOTTOM, Vector2(0, -30)); add_child(frame)
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 24); frame.add_child(h)
		pic = UI.talker(Vector2(190, 190)); h.add_child(pic)
		var v := VBoxContainer.new(); v.size_flags_horizontal = SIZE_EXPAND_FILL; h.add_child(v)
		name_l = UI.lbl("", 26, Color.WHITE, true); v.add_child(name_l)
		role_l = UI.lbl("", 14, UI.DIM); v.add_child(role_l)
		text_l = UI.lbl("", 22); text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; text_l.custom_minimum_size = Vector2(700, 110); v.add_child(text_l)
		v.add_child(UI.lbl(Data.L("Tıkla / SPACE: devam      ESC: atla"), 13, Color(0.45, 0.55, 0.7), false, HORIZONTAL_ALIGNMENT_RIGHT))
		_show()
	func _show() -> void:
		var w: Dictionary = Data.WHO[lines[i][0]]
		pic.set_face(w.tex); name_l.text = Data.L(w.n); role_l.text = Data.L(w.r)
		name_l.add_theme_color_override("font_color", w.c)
		frame.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.04, 0.08, 0.94), w.c))
		text_l.text = Data.L(lines[i][1]); text_l.visible_characters = 0; ch = 0.0
	func _process(dt: float) -> void:
		if text_l.visible_characters == -1: pic.talking = false; return
		ch += dt * 55.0
		text_l.visible_characters = int(ch) if int(ch) < text_l.text.length() else -1
		pic.talking = text_l.visible_characters != -1
	func _input(e: InputEvent) -> void:
		var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
		if e.is_action_pressed("pause"): _finish()
		elif click or e.is_action_pressed("ok"):
			if text_l.visible_characters != -1: text_l.visible_characters = -1
			else:
				i += 1
				Sfx.play("click", 0.0)
				if i >= lines.size(): _finish()
				else: _show()
		else: return
		get_viewport().set_input_as_handled()
	func _finish() -> void:
		get_tree().paused = false
		queue_free()
		done.call()

# ================= Durum =================
var ADD: CanvasItemMaterial
var T_GLOW: Texture2D
var T_ORB: Texture2D
var eb_tex := {}     # düşman mermisi dokuları: renk + sınıf (hafif / orta / ağır) başına bir kez üretilir
var out_mat := {}    # düşman türü başına dış çizgi malzemesi (türün renginde)
const EB_DMG := [6.0, 9.0, 15.0] # hafif / orta / ağır mermi hasarı
var cam: Camera2D
var sky_mat: ShaderMaterial
var sky_rect: ColorRect
var bg3: Node3D = null      # oyun içi 3D arka plan (shots.gd backdrop); kapalıysa 2D gökyüzü gölgelendiricisi
var bg_vp: SubViewport
var L_ground: Node2D; var L_gem: Node2D; var L_en: Node2D; var L_shot: Node2D; var L_top: Node2D; var L_fx: Node2D; var L_eb: Node2D
var player: Sprite2D; var shadow: Sprite2D; var flame: Exhaust; var hpbar: HPBar
var throttle := 0.3
var runway: Node2D       # hava üssü (Blender): zemin + sığınak çatısı + kapılar
var roof: Sprite2D
var doors: Node2D
var spill: Sprite2D
var emp_ring: Sprite2D
var orbs: Array = []

var pd: Dictionary
var phase := "brief"
var tt := 0.0
var t := 0.0
var hp := 100.0
var max_hp := 100.0
var inv := 0.0
var vel := Vector2.ZERO
var lvl := 1
var xp := 0
var kills := 0
var chests := 0
var score := 0
var bosses_killed := 0
var weapons := {}
var passives := {}
var st := {}
var enemies: Array = []
var bosses: Array = []
var shots: Array = []
var ebs: Array = []
var gems: Array = []
var grid := {}
var dir_i := 0
var ev_i := 0
var spawn_acc := 0.0
var pending_lv := 0
var shake := 0.0
var fx_count := 0
var dmg_labels := 0
var autoplay := false
var dead_t := 0.0
var crash: Wreck = null
var hud_root: Control
var warned := false
var warn_fx: WarnFX = null
var warn_num: Label
var warn_last := 0
var flashed := false
var stage := 0
var stg: Dictionary
var tree_s := {}
var radio_sched: Array = []  # [zaman, [kim, metin]] bu uçuşun planlı telsiz konuşmaları
var radio_q: Array = []      # meşgulken bekleyen replikler
var radio_who := ""
var radio_tag: Label
var elite_times: Array = []  # ikmal kapsüllü elit gemilerin geliş zamanları
var pointer: Control
var lowhp_said := false
var kill_times: Array = []
var streak_next := 0.0
var boss_spawned := false
var won := false
var clear_r := -1.0         # boss sonrası temizleme dalgasının yarıçapı (-1: yok)
var clear_c := Vector2.ZERO
var bank := 0.0
var prev_rot := 0.0
var pull := Vector2.ZERO
var beam: Line2D
var stage_lbl: Label
var BANK_MAT: ShaderMaterial
var boss_t := 150.0
var diff := 0               # zorluk kademesi (Data.DIFF)
var boss_hit := false       # boss savaşında hasar alındı mı (3. yıldız)
const PS := 0.77            # oyuncu uçağı ölçeği (v0.9: %10 büyüdü, kalabalıkta kaybolmasın)
var carry := {}             # harekât: önceki bölümden taşınan build (boşsa taze başlangıç)
var op_pos := 0             # bölümün harekâttaki sırası (0/1/2)
var chest_picks := 0        # bekleyen ikmal kapsülü seçimleri (2 seviye verir, evrim buradan çıkar)
var card_chest := false
var bans := 0
var banned := {}            # bu harekâtta yasaklanan kartlar
var ban_mode := false
var curse := {}             # lanetli kartların biriken bedelleri
var offered := {}           # kart -> gösterilip seçilmeme sayısı (çeşitlilik; harekât boyunca taşınır)
var tac := {}               # taktik kartlarının biriken bonusları (harekât boyunca)
var mast := {}              # uçak ustalığı bonusları (Data.mastery_stats)
var haz: Dictionary = {}    # bu bölgenin ortam tehlikesi (Data.HAZARDS), yoksa boş
var haz_t := 25.0           # ilk tehlikeye kadar süre
var hazs: Array = []        # bekleyen işaretler: {k, pos, r, life, ...}
var haz_said := false
var wind := Vector2.ZERO
var wind_t := 0.0
var wind_fx: CPUParticles2D
var defl_t := 0.0
var chain := false          # önceki bölümden gelindi: hangar yerine bulutların içinden dalış
var outro_m := ""           # zafer manevrası: eight / roll / spiral
var outro_c := Vector2.ZERO
var outro_head := 0.0
var endless := false        # sonsuz mod: dalgalar 15 bölgeyi döner, her turda düşmanlar güçlenir
var wave := 0
var wave_t0 := 0.0
const ENDLESS_WAVE := 110.0
var cloud_layer: CanvasLayer
var hmult := 1.0
var dmult := 1.0
var rerolls := 0
var salvo_t := 3.0
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector2.UP
var shield_t := 0.0
var shield_ready := false
var revived := false
var swarms_done := 0
var psc := 1.0          # oyuncu sprite ölçeği (3D şerit 2x çözünürlükte -> 0.5)
var use3d := false
var post_mat: ShaderMaterial
var cloud_mat: ShaderMaterial
var trails: Array = []
var cos_next := 0.0         # sonsuz mod: sonraki kozmetik jetonunun zamanı (Data.COS_EVERY)
var cos_got: Array = []     # bu uçuşta kazanılan jeton renkleri (ölünce de kalır: anında kaydedilir)
var tok_lbl: Label; var tok_bar: ProgressBar
var trail_fx = null         # kozmetik kuyruk izi (SkinS.TrailFx); yoksa düz kontrail çizgileri
var hitstop := 0.0
var ca_pulse := 0.0
var hurt_flash := 0.0
var OUTLINE: ShaderMaterial
var turn_w := 0.0
const CELL := 80.0

# UI
var ui: CanvasLayer
var xp_bar: ProgressBar; var lvl_lbl: Label; var time_lbl: Label; var kill_lbl: Label; var score_lbl: Label
var wbox: HBoxContainer; var pbox: HBoxContainer
var boss_box: VBoxContainer; var boss_bar: ProgressBar; var boss_lbl: Label
var radio_panel: PanelContainer; var radio_lbl: Label; var radio_pic: UI.Talker; var radio_name: Label; var radio_t := 0.0
var banner_box: VBoxContainer; var banner_lbl: Label; var banner_sub: Label
var flash_rect: ColorRect
var overlay: Control = null
var hint_lbl: Label
var tut_box: PanelContainer; var tut_tag: Label; var tut_lbl: Label
var tut_i := -1          # eğitim adımı (-1: kapalı)
var tut_t := 0.0
var tut_p := Vector2.ZERO

# ================= Kurulum =================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # duraklatmayı kendimiz yönetiyoruz
	autoplay = dev.has("auto")
	ADD = CanvasItemMaterial.new(); ADD.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	T_GLOW = Data.tex("glow"); T_ORB = Data.tex("orb")
	OUTLINE = ShaderMaterial.new(); OUTLINE.shader = load("res://scripts/outline.gdshader") # düşmanlar her zeminde seçilsin
	pd = Data.plane(dev.get("plane", Save.plane))
	if not Save.unlocked(pd) and not dev.has("plane"): pd = Data.PLANES[0]
	stage = clampi(stage, 0, Data.STAGES.size() - 1)
	stg = Data.STAGES[stage]
	var bc: Color = Data.BOSSES[stg.boss].col
	for pre in [[Color("ffb03c"), 1], [Color("c88cff"), 0], [Color("ff3a2a"), 2], [Color("ffb0c0"), 0], [bc, 0], [bc, 1], [bc, 2]]: _bullet_tex(pre[0], pre[1])
	tree_s = Data.tree_stats(Save.tree)
	mast = Data.mastery_stats(pd.id, int(Save.mastery.get(pd.id, 0)))
	if dev.has("mast"): mast = Data.mastery_stats(pd.id, Data.MASTERY_XP[clampi(int(dev.mast), 1, 5) - 1]) # test: --mast=N kademe
	if dev.has("pts"): tree_s = Data.tree_stats(_auto_tree(int(dev.pts))) # test: N puanı dengeli dağıt
	boss_t = Data.boss_time(stage + 1)
	hmult = Data.enemy_hp_mult(stage + 1); dmult = Data.enemy_dmg_mult(stage + 1)
	if endless: _wave_data()
	else: hmult *= Data.DIFF[diff].hp; dmult *= Data.DIFF[diff].dmg
	rerolls = Data.REROLLS + (2 if pd.id == "serce" else 0) + int(mast.get("reroll", 0)); bans = Data.BANS + int(mast.get("ban", 0))
	op_pos = 0 if endless else stage % Data.OP_LEN
	if not endless: hmult *= Data.OP_HP[op_pos]; dmult *= Data.OP_DMG[op_pos]
	shield_ready = pd.id == "kartal"
	if not endless and not dev.has("nohaz"): haz = Data.HAZARDS.get(stage, {})
	if dev.has("haz"): haz = Data.HAZARDS[int(dev.haz)]; haz_t = 2.0 # test: --haz=N tehlikesi

	var bgl := CanvasLayer.new(); bgl.layer = -10; add_child(bgl)
	var sky := UI.sky(stg.biome); bgl.add_child(sky); sky_mat = sky.material; sky_rect = sky
	if Save.bg3d and DisplayServer.get_name() != "headless" and not dev.has("no3d"): _build_bg3d()
	sky_mat.set_shader_parameter("tint", Vector3(stg.tint.r, stg.tint.g, stg.tint.b))
	var gr: Array = Data.GRADE[stg.biome]
	var cl := CanvasLayer.new(); cl.layer = 2; add_child(cl) # oyuncunun üstünden geçen bulutlar
	var cr := ColorRect.new(); cr.set_anchors_preset(Control.PRESET_FULL_RECT); cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_mat = ShaderMaterial.new(); cloud_mat.shader = load("res://scripts/overlay.gdshader")
	cloud_mat.set_shader_parameter("ntex", UI.noise_tex()); cloud_mat.set_shader_parameter("amount", gr[4]); cloud_mat.set_shader_parameter("col", gr[5])
	cr.material = cloud_mat; cl.add_child(cr); cl.visible = gr[4] > 0.0 or endless; cloud_layer = cl
	var pl := CanvasLayer.new(); pl.layer = 3; add_child(pl) # sinematik son işleme (HUD bunun üstünde)
	var pr := ColorRect.new(); pr.set_anchors_preset(Control.PRESET_FULL_RECT); pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new(); post_mat.shader = load("res://scripts/post.gdshader")
	post_mat.set_shader_parameter("shadow_col", gr[0]); post_mat.set_shader_parameter("high_col", gr[1])
	post_mat.set_shader_parameter("sat", gr[2]); post_mat.set_shader_parameter("contrast", gr[3])
	pr.material = post_mat; pl.add_child(pr)
	if not dev.has("time") and not chain: post_mat.set_shader_parameter("exposure", 0.95) # üs sahnesi aydınlık; savaş alanında karanlığa iner
	var clouds_on := cloud_layer.visible
	if not dev.has("time") and not chain: cloud_layer.visible = false # yerdeyken üstte bulut olmaz; tırmanırken bulut tabakasına girilir
	cloud_layer.set_meta("on", clouds_on)
	for n in ["L_ground", "L_gem", "L_en", "L_shot", "L_top", "L_fx", "L_eb"]:
		var l := Node2D.new(); add_child(l); set(n, l)
	_build_base()
	# okunurluk (v0.13): oyuncu uçağı patlama/efektlerin ÜSTÜNDE, düşman mermileri en üstte; efektler ayardan saydamlaşır
	L_top.z_index = 2; L_eb.z_index = 3
	L_fx.modulate.a = Save.fx_alpha / 100.0

	shadow = Sprite2D.new(); shadow.texture = Data.tex("plane_" + pd.id); shadow.modulate = Color(0, 0, 0, 0.4); L_ground.add_child(shadow)
	flame = Exhaust.new(); flame.material = ADD; flame.noz = pd.noz; flame.electric = pd.id == "simsek"; L_top.add_child(flame)
	player = Sprite2D.new(); player.texture = Data.tex("plane_" + pd.id); L_top.add_child(player)
	BANK_MAT = ShaderMaterial.new(); BANK_MAT.shader = load("res://scripts/bank.gdshader"); player.material = BANK_MAT
	var sh3 := Data.sheet("plane_" + pd.id)
	if sh3: # gerçek 3D yatış kareleri
		use3d = true; psc = 0.5
		player.material = SkinS.material(self, pd.id, 7, pd.color.lerp(Color.WHITE, 0.35)) # dış çizgi + kozmetik boya / arma
		for sp in [player, shadow]: sp.texture = sh3; sp.hframes = 7; sp.frame = 3
	for i in 2: # kanat ucu kontrail izleri
		var tr := Line2D.new(); tr.width = 3.0; tr.material = ADD
		var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0)); g.set_color(1, Color(0.9, 0.95, 1.0, 0.3)); tr.gradient = g
		var cv := Curve.new(); cv.add_point(Vector2(0, 0.2)); cv.add_point(Vector2(1, 1)); tr.width_curve = cv
		L_shot.add_child(tr); trails.append(tr)
	_apply_trail_flame()
	beam = Line2D.new(); beam.width = 46.0; beam.material = ADD; beam.default_color = Color(0.4, 2.2, 0.9, 0.35); beam.visible = false; L_fx.add_child(beam)
	player.position = Vector2(0, 505); player.scale = Vector2.ONE * 0.55 * psc # sığınağın içinde, çatının altında
	if chain: player.position = Vector2(0, 560); player.scale = Vector2.ONE * 1.1 * psc
	hpbar = HPBar.new(); hpbar.style = pd.bar; hpbar.col = pd.color; L_top.add_child(hpbar)
	emp_ring = Sprite2D.new(); emp_ring.texture = Data.tex("ring"); emp_ring.material = ADD; emp_ring.modulate = Color(1.2, 0.6, 2.4, 0.28); emp_ring.visible = false; L_shot.add_child(emp_ring)

	cam = Camera2D.new(); cam.position_smoothing_enabled = true; cam.position_smoothing_speed = 7.0; add_child(cam); cam.make_current()
	cam.zoom = Vector2.ONE * (1.0 if dev.has("time") or chain else 1.35) # sığınakta yakın plan, kalkışta geri çekilir
	cam.position = player.position
	_build_ui()
	max_hp = pd.hp; hp = max_hp
	weapons["sig"] = {"lvl": 1, "cd": 0.3, "s": {}} # uçağa özel imza silahı
	_recalc()
	if not carry.is_empty(): _apply_carry()
	if dev.has("lvlup"): pending_lv = 1
	if dev.has("evo"): add_weapon("top"); weapons.top.lvl = Data.MAX_LV; _weapon_changed("top"); passives["kalibre"] = 1; pending_lv = 1 # test: evrim kartı
	if dev.has("end"): _results.call_deferred(dev.end == "won")
	if dev.has("weps"): # test: --weps=napalm,ray seviye 5
		for id in str(dev.weps).split(","): add_weapon(id); weapons[id].lvl = int(dev.get("wlv", "5")); _weapon_changed(id)
	if dev.has("lvl"):
		for id in ["fuze", "emp", "kalkan", "simsek", "lazer"]: add_weapon(id)

	_plan_radio()
	if dev.has("outro"): _win_screen.call_deferred() # test: zafer manevrası
	if dev.has("pset"): (func(): _open_pause(); UI.settings(overlay, func(): pass)).call_deferred() # test: oyun içi ayarlar
	if dev.has("pod"): _drop.call_deferred(Vector2(260, -120), "chest") # test: kapsül görünümü
	if dev.has("time"):
		t = float(dev.time); phase = "play"; player.scale = Vector2.ONE * PS * psc; runway.visible = false; roof.visible = false; doors.visible = false; spill.visible = false
		while not radio_sched.is_empty() and radio_sched[0][0] < t: radio_sched.pop_front()
		while not elite_times.is_empty() and elite_times[0] < t: elite_times.pop_front()
		swarms_done = int(t > boss_t * 0.4) + int(t > boss_t * 0.75)
		Sfx.play_music(_battle_music())
	else:
		Sfx.play_music("music_menu")
		if chain:
			for n in [runway, roof, doors, spill]: n.visible = false
		dialog([["cmd", Data.L("Sonsuz devriye, Şahin-1. Vahar dalgaları bitmeyecek. Ne kadar dayanırsan o kadar can kurtarırsın.")]] if endless else stg.brief, _begin_arrive if chain else _begin_takeoff)
	_player_visuals(0.0)

## 3D arka plan: 2D gökyüzünün altında ayrı bir görüntü alanı. Kalkışta 2D zemin (üs) üstte kalır; uçak bulut tabakasını
## delince 2D gökyüzü erir ve altından 3D dünya çıkar (alçak irtifadan yüksek irtifaya geçiş). Dalışta ve testte baştan 3D.
func _build_bg3d() -> void:
	var l := CanvasLayer.new(); l.layer = -11; add_child(l)
	var c := SubViewportContainer.new(); c.stretch = true; c.set_anchors_preset(Control.PRESET_FULL_RECT); c.mouse_filter = Control.MOUSE_FILTER_IGNORE; l.add_child(c)
	bg_vp = SubViewport.new(); bg_vp.own_world_3d = true; bg_vp.scaling_3d_scale = 0.8; bg_vp.msaa_3d = Viewport.MSAA_DISABLED
	c.add_child(bg_vp)
	_bg_world(stg.biome)
	if dev.has("time") or chain: sky_rect.visible = false

func _bg_world(biome: int) -> void:
	if bg3: bg3.queue_free()
	bg3 = load("res://scripts/shots.gd").new(); bg_vp.add_child(bg3); bg3.backdrop(biome) # load: shots.gd da game.gd’yi yükler (döngü)

func _build_ui() -> void:
	ui = CanvasLayer.new(); ui.layer = 5; add_child(ui)
	var hud := Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(hud)
	hud_root = hud
	flash_rect = ColorRect.new(); flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT); flash_rect.color = Color(1, 1, 1, 0); flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(flash_rect)
	xp_bar = UI.bar(100, 14, Color(0.3, 0.7, 2.0)); xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); xp_bar.offset_bottom = 14; hud.add_child(xp_bar)
	lvl_lbl = UI.lbl(Data.L("SV 1"), 22, Color.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT); lvl_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); lvl_lbl.offset_left = -200; lvl_lbl.offset_right = -16; lvl_lbl.offset_top = 16; hud.add_child(lvl_lbl)
	time_lbl = UI.lbl("00:00", 38, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER); time_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); time_lbl.offset_left = -120; time_lbl.offset_right = 120; time_lbl.offset_top = 14; hud.add_child(time_lbl)
	stage_lbl = UI.lbl("", 15, UI.DIM, true, HORIZONTAL_ALIGNMENT_CENTER); stage_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); stage_lbl.offset_left = -300; stage_lbl.offset_right = 300; stage_lbl.offset_top = 56; hud.add_child(stage_lbl)
	kill_lbl = UI.lbl("", 17, UI.DIM, true, HORIZONTAL_ALIGNMENT_RIGHT); kill_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); kill_lbl.offset_left = -300; kill_lbl.offset_right = -16; kill_lbl.offset_top = 46; hud.add_child(kill_lbl)
	score_lbl = UI.lbl("", 17, UI.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT); score_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); score_lbl.offset_left = -300; score_lbl.offset_right = -16; score_lbl.offset_top = 70; hud.add_child(score_lbl)
	if endless: # sonraki kozmetik jetonuna kalan süre
		tok_lbl = UI.lbl("", 15, UI.DIM, true, HORIZONTAL_ALIGNMENT_RIGHT); tok_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); tok_lbl.offset_left = -300; tok_lbl.offset_right = -16; tok_lbl.offset_top = 94; hud.add_child(tok_lbl)
		tok_bar = UI.bar(150, 5, Color(0.6, 1.8, 1.0)); tok_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); tok_bar.offset_left = -166; tok_bar.offset_right = -16; tok_bar.offset_top = 116; tok_bar.offset_bottom = 121; hud.add_child(tok_bar)
	var icons := VBoxContainer.new(); icons.position = Vector2(14, 22); hud.add_child(icons)
	wbox = HBoxContainer.new(); icons.add_child(wbox)
	pbox = HBoxContainer.new(); icons.add_child(pbox)
	boss_box = VBoxContainer.new(); boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); boss_box.offset_left = -300; boss_box.offset_right = 300; boss_box.offset_top = 82; boss_box.visible = false; hud.add_child(boss_box)
	boss_lbl = UI.lbl("", 18, Color("ff5a3c"), true, HORIZONTAL_ALIGNMENT_CENTER); boss_box.add_child(boss_lbl)
	boss_bar = UI.bar(600, 12, Color(2.0, 0.4, 0.3)); boss_box.add_child(boss_bar)
	pointer = OffPointer.new(); pointer.g = self; pointer.set_anchors_preset(Control.PRESET_FULL_RECT); pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(pointer)
	radio_panel = UI.panel(); radio_panel.position = Vector2(14, 246); radio_panel.custom_minimum_size = Vector2(470, 0); radio_panel.visible = false; hud.add_child(radio_panel)
	var rh := HBoxContainer.new(); rh.add_theme_constant_override("separation", 12); radio_panel.add_child(rh)
	radio_pic = UI.talker(Vector2(64, 64)); rh.add_child(radio_pic)
	var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation", 0); rh.add_child(rv)
	radio_tag = UI.lbl("", 11, UI.DIM, true); rv.add_child(radio_tag)
	radio_name = UI.lbl("", 14, UI.CYAN, true); rv.add_child(radio_name)
	radio_lbl = UI.lbl("", 15); radio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; radio_lbl.custom_minimum_size = Vector2(360, 0); rv.add_child(radio_lbl)
	banner_box = VBoxContainer.new(); banner_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); banner_box.offset_left = -450; banner_box.offset_right = 450; banner_box.offset_top = 120; banner_box.offset_bottom = 230; banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; banner_box.modulate.a = 0; hud.add_child(banner_box)
	banner_lbl = UI.lbl("", 56, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER); banner_box.add_child(banner_lbl)
	banner_sub = UI.lbl("", 18, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER); banner_box.add_child(banner_sub)
	# alt kenarda sönük tuş ipuçları (Ayarlar'dan kapatılabilir)
	hint_lbl = UI.lbl(_keys_text(), 13, Color(0.7, 0.75, 0.85, 0.4), true, HORIZONTAL_ALIGNMENT_CENTER)
	hint_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); hint_lbl.offset_top = -26; hint_lbl.offset_bottom = -6; hint_lbl.visible = false; hud.add_child(hint_lbl)
	tut_box = UI.panel(); tut_box.custom_minimum_size = Vector2(620, 0); tut_box.visible = false
	UI.at(tut_box, Control.PRESET_CENTER_BOTTOM, Vector2(0, -60)); hud.add_child(tut_box)
	var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", 4); tut_box.add_child(tv)
	tut_tag = UI.lbl("", 12, UI.ORANGE, true); tv.add_child(tut_tag)
	tut_lbl = UI.lbl("", 20, Color.WHITE, true); tut_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tut_lbl.custom_minimum_size = Vector2(580, 0); tv.add_child(tut_lbl)
	tv.add_child(UI.lbl(Data.L("ENTER / TAB / SELECT: eğitimi geç"), 12, Color(0.45, 0.55, 0.7), false, HORIZONTAL_ALIGNMENT_RIGHT))

# ================= Hikaye / bildirimler =================
func dialog(lines: Array, done: Callable) -> void:
	if autoplay:
		done.call_deferred(); return
	get_tree().paused = true
	var d := DialogBox.new(); d.lines = lines; d.done = done
	ui.add_child(d)

## prio 0: telsiz meşgulse atla, 1: sıraya gir, 2: hemen göster. nm: konuşanın adını değiştir (boss pilotları)
func radio(who: String, text: String, prio := 1, nm := "") -> void:
	if radio_panel.visible and prio < 2:
		if prio == 1 and radio_q.size() < 3: radio_q.append([who, text, nm])
		return
	_show_radio(who, text, nm)

func _show_radio(who: String, text: String, nm := "") -> void:
	var w: Dictionary = Data.WHO[who]
	radio_who = who
	var enemy := who == "varek" or who == "vahar"
	radio_tag.text = Data.L("// YAKALANAN VAHAR YAYINI") if enemy else (Data.L("// ŞİFRELİ KANAL — KAYNAK BİLİNMİYOR") if who == "lyra" else Data.L("// DSHK TAKTİK TELSİZ"))
	radio_tag.add_theme_color_override("font_color", Color(w.c, 0.75))
	radio_pic.set_face(w.tex); radio_name.text = Data.L(nm if nm != "" else w.n); radio_name.add_theme_color_override("font_color", w.c)
	radio_lbl.text = Data.L(text); radio_lbl.visible_ratio = 0.0
	radio_lbl.create_tween().tween_property(radio_lbl, "visible_ratio", 1.0, text.length() * 0.022) # daktilo
	radio_panel.visible = true; radio_t = 3.4 + text.length() * 0.05
	radio_panel.add_theme_stylebox_override("panel", UI.box(Color(0.12, 0.01, 0.02, 0.9) if enemy else Color(0.02, 0.04, 0.08, 0.88), w.c))
	radio_panel.position.x = -500.0
	radio_panel.create_tween().tween_property(radio_panel, "position:x", 14.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("select" if enemy else "click", 0.0)

## Havuzdan replik: [kim, metin]. Düz metin havuzlarında konuşan havuzun adından gelir.
func _line(pool: String) -> Array:
	var arr: Array = Data.LINES[pool]
	var x = arr[Save.pick_line(pool, arr.size())]
	if x is Array: return x
	return ["cmd" if pool in ["takeoff", "swarm", "boss_near"] else pool, x]

## Bu uçuşun telsiz planı: bölüme özel 2 replik + 2 genel (Varek / yakalanan Vahar yayını / komuta) + boss uyarısı
func _plan_radio() -> void:
	var key := Data.L("stage%d") % stage
	var sl: Array = Data.LINES.stage[stage]
	var a: Array = sl[Save.pick_line(key, sl.size())]
	var b: Array = sl[Save.pick_line(key, sl.size())]
	var gen := ["varek", "vahar", "cmd"]; gen.shuffle()
	radio_sched = [[0.1, a], [0.27, _line(gen[0])], [0.5, b], [0.66, _line(gen[1])], [0.88, _line("boss_near")]]
	for s in radio_sched: s[0] = wave_t0 + s[0] * (boss_t - wave_t0)
	if stage == 0 and not endless: radio_sched.push_front([12.0, ["cmd", Data.STORY.radio[0][2]]])
	# ikmal kapsüllü elit gemiler: bölüme göre sabit sayıda, uçuşa yayılmış (Data.chest_count)
	var c := 0 if dev.has("noelite") else Data.chest_count(stage + 1)
	for i in c: elite_times.append(wave_t0 + (boss_t - wave_t0) * (0.15 + 0.7 * i / float(c - 1)) * randf_range(0.95, 1.05))

## Büyük duyurular sıraya girer (üst üste binmesin); sırada bekleyen varsa ekranda daha kısa kalır.
## Konum: ekranın üst kısmı (boss çubuğunun altı), uçağın ve telsiz kutusunun üstüne düşmez.
var banner_q: Array = []
var banner_tw: Tween
func banner(text: String, sub := "", col := Color(1.2, 2.0, 2.6)) -> void:
	if banner_tw and banner_tw.is_running():
		if banner_q.size() < 3: banner_q.append([text, sub, col])
		return
	banner_lbl.text = Data.L(text); banner_sub.text = Data.L(sub)
	banner_lbl.add_theme_color_override("font_color", col)
	banner_tw = banner_box.create_tween()
	banner_box.modulate.a = 0; banner_box.scale = Vector2.ONE
	banner_tw.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	banner_tw.tween_interval(2.2 if banner_q.is_empty() else 1.3)
	banner_tw.tween_property(banner_box, "modulate:a", 0.0, 0.45)
	banner_tw.tween_callback(func():
		if not banner_q.is_empty():
			var nx: Array = banner_q.pop_front(); banner(nx[0], nx[1], nx[2]))

func screen_flash(col: Color, a := 0.7, dur := 0.5) -> void:
	flash_rect.color = Color(col, a)
	flash_rect.create_tween().tween_property(flash_rect, "color:a", 0.0, dur)

# ================= Ana döngü =================
func _process(dt: float) -> void:
	if get_tree().paused: return
	match phase:
		"takeoff": _update_takeoff(dt)
		"play":
			if hitstop > 0.0: hitstop -= dt # vuruşta kısa donma: dünya durur, efektler sürer
			else: _update_play(dt)
		"dead": _update_dead(dt)
		"outro": _update_outro(dt)
		"arrive": _update_arrive(dt)
	# zafer gösterisinde ve bölüme dalışta kamera sabit durur, uçak kadrajın içinde uçar
	cam.position = outro_c if phase == "outro" else (Vector2.ZERO if chain and phase in ["brief", "arrive"] else player.position)
	shake = maxf(0.0, shake - 30.0 * dt)
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	sky_mat.set_shader_parameter("cam", cam.get_screen_center_position())
	sky_mat.set_shader_parameter("view_size", get_viewport_rect().size)
	if bg3: bg3.follow(cam.get_screen_center_position(), cam.zoom.x)
	_player_visuals(dt)
	_update_hud(dt)
	ca_pulse = maxf(0.0, ca_pulse - dt * 3.0); hurt_flash = maxf(0.0, hurt_flash - dt * 2.5)
	post_mat.set_shader_parameter("ca", minf(ca_pulse, 1.0)); post_mat.set_shader_parameter("hurt", hurt_flash)
	cloud_mat.set_shader_parameter("cam", cam.get_screen_center_position()); cloud_mat.set_shader_parameter("view_size", get_viewport_rect().size)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") and phase == "play":
		if overlay and Data.L(overlay.name) == "Pause": _close_pause()
		elif overlay == null and not get_tree().paused: _open_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "play" and overlay == null and not get_tree().paused and not autoplay:
		_open_pause()

# ================= Kalkış =================
# ================= Kalkış: sığınaktan pist başına, art yakıcı, havalanma, bulut tabakası =================
const TK_DOORS := 1.2   # kapılar açılır
const TK_TAXI := 3.1    # taksi biter, pist başında bekleme
const TK_ROLL := 3.9    # frenler bırakılır
const TK_LIFT := 5.5    # tekerlek kesilir
const TK_END := 7.4     # savaş alanı

## Hava üssü: Blender'da çekilmiş zemin + ayrı katmanda sığınak çatısı + kayan zırhlı kapılar
func _build_base() -> void:
	runway = Node2D.new(); L_ground.add_child(runway)
	var tex := Data.sheet("base")
	if tex:
		var b := Sprite2D.new(); b.texture = tex; b.position = Vector2(0, -950); runway.add_child(b)
	else:
		runway.add_child(Runway.new()) # Blender çıktısı yoksa eski çizim
	roof = Sprite2D.new(); roof.texture = Data.sheet("base_roof"); roof.position = Vector2(0, 490); roof.z_index = 4; add_child(roof) # oyuncunun (z 2) üstünde; efekt opaklığından etkilenmez
	spill = Sprite2D.new(); spill.texture = T_GLOW; spill.material = ADD; spill.position = Vector2(0, 360); spill.scale = Vector2(1.6, 1.0)
	spill.modulate = Color(1.2, 1.0, 0.75, 0.0); L_ground.add_child(spill) # açılan kapıdan sızan hangar ışığı
	doors = Node2D.new(); doors.z_index = 4; add_child(doors)
	for sx in [-1.0, 1.0]:
		var d := Polygon2D.new(); d.color = Color(0.2, 0.21, 0.2)
		d.polygon = PackedVector2Array([Vector2(0, -7), Vector2(96 * sx, -7), Vector2(96 * sx, 7), Vector2(0, 7)])
		for i in 5: # sarı-siyah uyarı şeridi
			var st := Polygon2D.new(); st.color = Color(0.85, 0.62, 0.08); var x: float = (12 + i * 17) * sx
			st.polygon = PackedVector2Array([Vector2(x, -5), Vector2(x + 7 * sx, -5), Vector2(x + 3 * sx, 5), Vector2(x - 4 * sx, 5)]); d.add_child(st)
		d.position = Vector2(0, 380); d.name = "L" if sx < 0 else "R"; doors.add_child(d)

func _begin_takeoff() -> void:
	phase = "takeoff"; tt = 0.0
	Sfx.play("whoosh", 0.0); Sfx.play_music(_battle_music())
	for d in doors.get_children(): # kapılar yana kayar
		d.create_tween().tween_property(d, "position:x", 100.0 * (-1.0 if Data.L(d.name) == "L" else 1.0), TK_DOORS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	spill.create_tween().tween_property(spill, "modulate:a", 0.55, TK_DOORS)
	var tk := _line("takeoff"); radio(tk[0], tk[1], 2)

func _update_takeoff(dt: float) -> void:
	tt += dt
	if (Input.is_action_just_pressed("ok") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and tt > 0.5 and tt < TK_LIFT and not autoplay:
		tt = TK_LIFT; player.position.y = minf(player.position.y, -420.0) # sahneyi atla
	player.rotation = 0.0
	if tt < TK_DOORS:
		throttle = 0.04
	elif tt < TK_TAXI: # çatının altından çıkıp bekleme çizgisine taksi
		throttle = 0.22
		player.position.y = lerpf(505.0, 262.0, smoothstep(TK_DOORS, TK_TAXI, tt))
		if tt < TK_DOORS + 0.1: Sfx.play("engine", 0.0)
	elif tt < TK_ROLL: # pist başı: art yakıcı yanar, toz ve sarsıntı
		throttle = lerpf(0.3, 1.0, smoothstep(TK_TAXI, TK_ROLL - 0.2, tt)); shake = maxf(shake, 1.5 * throttle)
		if randf() < 0.6: _puff(player.position + Vector2(randf_range(-20, 20), 48), Color(0.45, 0.42, 0.38, 0.45), randf_range(0.5, 0.9), Vector2(randf_range(-50, 50), 90), 0.9)
	else: # kalkış koşusu
		throttle = 1.0
		if tt - dt < TK_ROLL: Sfx.play("afterburner", 0.0) # frenler bırakıldı: art yakıcı
		var s := tt - TK_ROLL
		player.position.y -= minf(900.0, 30.0 + 300.0 * pow(s, 1.6)) * dt
		if tt < TK_LIFT and randf() < 0.5: _puff(player.position + Vector2(randf_range(-14, 14), 46), Color(0.5, 0.5, 0.5, 0.4), randf_range(0.5, 1.0), Vector2(randf_range(-40, 40), 70), 0.7)
	player.scale = Vector2.ONE * lerpf(0.55, PS, smoothstep(TK_LIFT, TK_LIFT + 1.4, tt)) * psc # tırmanırken kameraya yaklaşır
	cam.zoom = Vector2.ONE * lerpf(1.35, 1.0, smoothstep(TK_TAXI, TK_END, tt))
	if tt > TK_END - 1.2 and tt < TK_END - 0.1: # bulut tabakasının içinden geçiş
		for k in 2: _puff(player.position + Vector2(randf_range(-760, 760), randf_range(-500, -200)), Color(0.9, 0.92, 0.95, 0.45), randf_range(5, 9), Vector2.ZERO, 1.1)
	if tt >= TK_END - 1.2: cloud_layer.visible = cloud_layer.get_meta("on", true)
	if tt >= TK_END - 0.6 and not flashed:
		flashed = true; screen_flash(Color(0.85, 0.88, 0.95), 0.35, 0.9); Sfx.play("whoosh", 0.0)
		for n in [runway, roof, doors, spill]: n.visible = false # bulutların üstüne çıkınca üs bir daha görünmez
		if bg3: sky_rect.create_tween().tween_property(sky_rect, "modulate:a", 0.0, 0.5) # altından 3D dünya çıkar
	if tt >= TK_END:
		_enter_play()
		for n in [runway, roof, doors, spill]: n.create_tween().tween_property(n, "modulate:a", 0.0, 2.5)
		create_tween().tween_method(func(v: float): post_mat.set_shader_parameter("exposure", v), 0.95, 0.7, 2.5)

func _enter_play() -> void:
	phase = "play"; inv = 1.0; cam.zoom = Vector2.ONE
	if endless: banner(Data.L("SONSUZ MOD"), Data.L("Dalga 1  •  ") + Data.L(stg.sub))
	else: banner(Data.L("BÖLÜM %d: %s") % [stage + 1, Data.L(stg.name)], Data.L(stg.sub) + Data.L("  •  Boss ") + UI.mmss(boss_t) + Data.L("'da geliyor"))
	_start_tutorial()

## Önceki bölümden gelince: uçak yukarıdan, bulut tabakasını yararak savaş alanına dalar
const ARRIVE := 1.7
func _begin_arrive() -> void:
	phase = "arrive"; tt = 0.0
	Sfx.play("whoosh", 0.0); Sfx.play_music(_battle_music())
	screen_flash(Color(0.85, 0.9, 1.0), 0.5, 1.0)

func _update_arrive(dt: float) -> void:
	tt += dt
	var u := minf(tt / ARRIVE, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	player.position = Vector2(0, lerpf(560.0, 0.0, e)); player.rotation = 0.0
	player.scale = Vector2.ONE * lerpf(1.1, PS, e) * psc # irtifa kaybederken küçülür
	vel = Vector2(0, -320.0 * (1.0 - e)); throttle = lerpf(1.0, 0.45, u)
	if u < 0.7: # geride kalan bulut parçaları
		for k in 2: _puff(Vector2(randf_range(-700, 700), randf_range(-420, 420)), Color(0.88, 0.9, 0.95, 0.35 * (1.0 - u)), randf_range(4, 7), Vector2(0, 500), 0.8)
	if tt >= ARRIVE: _enter_play()

func _puff(pos: Vector2, col: Color, sc: float, v: Vector2, life: float) -> void:
	var p := Sprite2D.new(); p.texture = T_GLOW; p.position = pos; p.modulate = col; p.scale = Vector2.ONE * sc
	L_fx.add_child(p)
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "position", pos + v * life, life)
	tw.tween_property(p, "scale", Vector2.ONE * sc * 1.6, life)
	tw.tween_property(p, "modulate:a", 0.0, life)
	tw.chain().tween_callback(p.queue_free)

# ================= Düşüş ve çarpma =================
# Vurulan büyük gemiler ve oyuncu dönerek düşer; gölgesiyle buluştuğu yerde haritaya göre zemine çarpar.
const IMPACT := ["water", "dirt", "rock", "rock", "water", "snow", "cloud", "water", "snow", "sand", "lava", "cloud", "space", "metal", "rubble"]
var wrecks := 0

func impact_kind() -> String: return IMPACT[clampi(stg.biome, 0, IMPACT.size() - 1)]

func wreck_from(s: Sprite2D, vel: Vector2, k: float, life := 1.1) -> Wreck:
	var w := Wreck.new(); w.g = self; w.texture = s.texture; w.hframes = s.hframes; w.frame = s.frame
	w.position = s.position; w.rotation = s.rotation; w.scale = s.scale; w.sc0 = s.scale
	w.vel = vel; w.k = k; w.life = life; w.spin = randf_range(2.5, 5.0) * (1.0 if randf() < 0.5 else -1.0)
	L_en.add_child(w)
	return w

func impact(pos: Vector2, kind: String, k := 1.0) -> void:
	shake = maxf(shake, 3.0 + 3.0 * k)
	match kind:
		"water": # su sütunu, halka halka dalga, köpük
			explosion(pos, Color(1.0, 0.6, 0.3), 0.5 * k)
			_spray(pos, k, Color(0.9, 0.96, 1.0, 0.95), Color(0.55, 0.75, 0.95, 0.0), 820.0, 55, false)
			for i in 3: _ripple(pos, k, i * 0.25, Color(0.85, 0.95, 1.0, 0.6))
			_decal(pos, k * 1.2, Color(0.85, 0.95, 1.0, 0.35), 2.5)
		"dirt", "rock", "sand", "rubble": # toprak ve taş parçaları, toz bulutu, yanık krater
			var c: Color = {"dirt": Color(0.36, 0.27, 0.17), "rock": Color(0.42, 0.4, 0.38), "sand": Color(0.78, 0.64, 0.42), "rubble": Color(0.5, 0.47, 0.44)}[kind]
			explosion(pos, Color(1.0, 0.5, 0.15), 0.9 * k)
			_spray(pos, k, c.lightened(0.15), Color(c, 0.0), 700.0, 40, false)
			for i in int(4 + 3 * k): _puff(pos + Vector2(randf_range(-14, 14), randf_range(-14, 14)) * k, Color(c, 0.75), randf_range(0.5, 0.9) * k, Vector2.from_angle(randf() * TAU) * randf_range(25, 60) * k, randf_range(1.3, 2.2))
			_decal(pos, k, Color(0.04, 0.03, 0.02, 0.75), 9.0)
		"snow": # kar tozu ve buz kırıkları
			explosion(pos, Color(1.0, 0.6, 0.3), 0.7 * k)
			_spray(pos, k, Color(0.8, 0.92, 1.0, 0.95), Color(0.6, 0.8, 1.0, 0.0), 650.0, 45, false)
			for i in int(5 + 3 * k): _puff(pos + Vector2(randf_range(-16, 16), randf_range(-16, 16)) * k, Color(0.95, 0.97, 1.0, 0.8), randf_range(0.6, 1.0) * k, Vector2.from_angle(randf() * TAU) * randf_range(30, 70) * k, randf_range(1.4, 2.4))
			_decal(pos, k, Color(0.25, 0.3, 0.38, 0.6), 9.0)
		"lava": # lav fışkırması, ateş, kara duman
			explosion(pos, Color(1.0, 0.45, 0.1), 1.0 * k)
			_spray(pos, k, Color(2.2, 0.9, 0.2), Color(1.2, 0.15, 0.02, 0.0), 750.0, 50, true)
			for i in int(4 + 2 * k): _puff(pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)) * k, Color(0.06, 0.05, 0.05, 0.75), randf_range(0.6, 1.0) * k, Vector2(randf_range(-20, 20), randf_range(-70, -35)), randf_range(1.6, 2.6))
			_decal(pos, k, Color(1.4, 0.35, 0.05, 0.6), 4.0)
		"cloud": # bulutların içine gömülür: bulut patlaması ve içeriden parlama
			explosion(pos, Color(1.0, 0.55, 0.25), 0.6 * k)
			for i in int(6 + 3 * k): _puff(pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)) * k, Color(0.88, 0.9, 0.95, 0.7), randf_range(0.8, 1.3) * k, Vector2.from_angle(randf() * TAU) * randf_range(15, 40) * k, randf_range(1.5, 2.5))
		"space": # yerçekimi yok: kıvılcımlar ve enkaz her yöne savrulur
			explosion(pos, Color(1.0, 0.6, 0.3), 1.2 * k)
			_spray(pos, k, Color(2.0, 1.5, 0.8), Color(0.8, 0.3, 0.1, 0.0), 0.0, 45, true, 180.0)
		"metal": # Sefine gövdesi: kıvılcım yağmuru ve yanık iz
			explosion(pos, Color(1.0, 0.55, 0.2), 1.0 * k)
			_spray(pos, k, Color(2.2, 1.7, 0.6), Color(1.0, 0.4, 0.1, 0.0), 900.0, 50, true)
			_decal(pos, k, Color(0.03, 0.03, 0.04, 0.7), 8.0)

func _spray(pos: Vector2, k: float, c0: Color, c1: Color, grav: float, n: int, add: bool, spread := 70.0) -> void:
	if fx_count >= 40: return
	fx_count += 1
	var p := CPUParticles2D.new(); p.texture = T_GLOW; p.position = pos; p.one_shot = true; p.explosiveness = 0.92
	if add: p.material = ADD
	p.amount = int(n * clampf(k, 0.6, 2.0)); p.lifetime = 1.1; p.direction = Vector2.UP; p.spread = spread
	p.gravity = Vector2(0, grav); p.initial_velocity_min = 120.0 * sqrt(k); p.initial_velocity_max = 400.0 * sqrt(k)
	p.damping_min = 20.0; p.damping_max = 60.0; p.scale_amount_min = 0.04 * k; p.scale_amount_max = 0.13 * k
	var gr := Gradient.new(); gr.set_color(0, c0); gr.set_color(1, c1); p.color_ramp = gr
	p.finished.connect(func(): fx_count -= 1; p.queue_free())
	L_fx.add_child(p); p.emitting = true

func _ripple(pos: Vector2, k: float, delay: float, col: Color) -> void:
	var r := Sprite2D.new(); r.texture = Data.tex("ring"); r.position = pos; r.modulate = Color(col, 0.0); r.scale = Vector2(0.08, 0.068) * k
	L_ground.add_child(r)
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "modulate:a", col.a, 0.1).set_delay(delay)
	tw.tween_property(r, "scale", Vector2(0.62, 0.52) * k, 1.4).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(r, "modulate:a", 0.0, 1.2).set_delay(delay + 0.2)
	tw.chain().tween_callback(r.queue_free)

func _decal(pos: Vector2, k: float, col: Color, life: float) -> void:
	var d := Sprite2D.new(); d.texture = T_GLOW; d.position = pos; d.modulate = col; d.scale = Vector2.ONE * 0.75 * k; d.rotation = randf() * TAU
	L_ground.add_child(d)
	var tw := d.create_tween(); tw.tween_property(d, "modulate:a", 0.0, life).set_delay(life * 0.4); tw.tween_callback(d.queue_free)

# ================= Oyun =================
func _update_play(dt: float) -> void:
	if dev.has("crash") and t > float(dev.get("time", "0")) + 1.0: _die(); return # test: düşüş efekti
	t += dt
	_director(dt)
	_rebuild_grid() # hareket ve atılım güncel düşman listesini kullansın
	_move_player(dt)
	_update_weapons(dt)
	_update_shots(dt)
	_update_enemies(dt)
	_update_ebs(dt)
	_update_gems(dt)
	if clear_r >= 0.0: _update_clear(dt)
	if not haz.is_empty(): _update_hazards(dt)
	if endless and t >= cos_next + Data.COS_EVERY: _cos_token()
	if st.regen > 0: hp = minf(max_hp, hp + st.regen * dt)
	defl_t -= dt
	inv = maxf(0.0, inv - dt)
	enemies = enemies.filter(func(e): return not e.dead)
	shots = shots.filter(func(s): return not s.dead)
	ebs = ebs.filter(func(b): return not b.dead)
	gems = gems.filter(func(g): return not g.dead)
	if pending_lv > 0 and overlay == null and phase == "play": _open_levelup()

func _move_player(dt: float) -> void:
	var spd: float = pd.speed * st.speed
	var desired := Vector2.ZERO
	var kv := Input.get_vector("left", "right", "up", "down")
	if autoplay:
		var to: Vector2 = Vector2(cos(t * 0.35), sin(t * 0.5)) * 550.0 - player.position
		desired = to.normalized() * spd
		if dev.has("mortal"): desired = _bot_dodge(desired, spd) - wind * 0.8 # gerçek oyuncu gibi rüzgâra karşı koyar
	elif kv.length() > 0.1:
		desired = kv * spd
	elif Data.pad:
		desired = Vector2.ZERO
	else:
		var to := get_global_mouse_position() - player.position
		var d := to.length()
		if d > 12.0: desired = to / d * spd * clampf(d / 140.0, 0.0, 1.0)
	# --- UÇUŞ FİZİĞİ: ivme = itki/kütle, dönüş hızı = kaldırma/hız, yatış = atan(v·ω/g) ---
	var acc: float = pd.thrust * st.agi
	var lat: float = pd.lift * st.agi
	var v := vel.length()
	var nv := vel
	if v < 40.0: # neredeyse dururken burnu serbestçe çevirebilir
		nv = vel.move_toward(desired, acc * dt)
		turn_w = 0.0
	else:
		var head := vel.angle()
		var want := desired.angle() if desired.length() > 1.0 else head
		var new_head := rotate_toward(head, want, lat / maxf(v, 60.0) * dt)
		var new_speed := move_toward(v, desired.length(), (acc if desired.length() > v else acc * 1.4) * dt)
		nv = Vector2.from_angle(new_head) * new_speed
		turn_w = angle_difference(head, new_head) / maxf(dt, 0.001)
	# gaz kolu: hızlanırken art yakıcı, seyirde askeri güç, yavaşlarken rölanti; sert dönüşte pilot gazı keser
	var want_v := desired.length()
	var thr_t := 1.0 if want_v > vel.length() + 15.0 else (0.45 if want_v > vel.length() - 25.0 else 0.06)
	var turn_k := clampf(absf(turn_w) / maxf(lat / maxf(vel.length(), 60.0), 0.01), 0.0, 1.0)
	thr_t *= 1.0 - 0.75 * smoothstep(0.35, 0.9, turn_k)
	if dash_t > 0.0: thr_t = 1.0
	throttle = move_toward(throttle, thr_t, dt * (3.0 if thr_t > throttle else 5.0))
	vel = nv
	player.position += (vel + pull + wind) * dt
	if vel.length() > 25.0: player.rotation = vel.angle() + PI / 2.0
	_trait_dash(dt)
	# koordineli dönüş: tan(φ) = v·ω / g ; ±55° = tam yatış karesi
	var phi := atan(vel.length() * turn_w / 900.0)
	bank = lerpf(bank, clampf(phi / deg_to_rad(55.0), -1.0, 1.0), 1.0 - exp(-dt * 10.0 * st.agi))

## Kozmetik iz ve alev (Hangar > BOYAHANE). "Renkler boyaya uysun" açıksa boyanın renklerini alır.
func _apply_trail_flame() -> void:
	var ts: String = SkinS.style(pd.id, "iz"); var tc: Array = SkinS.colors(pd.id, "iz")
	if ts != "":
		trail_fx = SkinS.TrailFx.new(); trail_fx.kind = ts; trail_fx.c0 = tc[0]; trail_fx.c1 = tc[1]
		if ts != "smoke": trail_fx.material = ADD
		L_shot.add_child(trail_fx)
		for tr in trails: tr.visible = false
	elif not tc.is_empty():
		for tr in trails: tr.gradient.set_color(1, Color(tc[0], 0.35))
	var fs: String = SkinS.style(pd.id, "alev"); var fc: Array = SkinS.colors(pd.id, "alev")
	if fs != "" or not fc.is_empty():
		flame.kind = fs if fs != "" else "basic"; flame.c0 = fc[0]; flame.c1 = fc[1]

func _player_visuals(_dt: float) -> void:
	if phase == "dead": # düşüşü _update_dead yönetir
		flame.visible = false
		for tr in trails: if tr.get_point_count() > 0: tr.remove_point(0)
		return
	var k := smoothstep(TK_LIFT, TK_LIFT + 1.4, tt) if phase == "takeoff" else (0.0 if phase == "brief" else 1.0)
	shadow.position = player.position + Vector2(8, 12).lerp(Vector2(60, 90), k)
	if use3d:
		player.frame = clampi(int(round((bank + 1.0) * 3.0)), 0, 6); shadow.frame = player.frame
	else:
		player.scale.x = player.scale.y * (1.0 - 0.38 * absf(bank)); player.skew = bank * 0.22
		BANK_MAT.set_shader_parameter("bank", bank)
	shadow.rotation = player.rotation; shadow.scale = player.scale * 0.9; shadow.skew = player.skew
	var ws := player.scale.y / psc / 0.7 # dünya ölçeği
	for i in 2:
		var tr: Line2D = trails[i]
		if phase == "play" and vel.length() > 120.0 and player.visible:
			tr.add_point(player.position + Vector2((i * 2 - 1) * 26.0 * (1.0 - 0.3 * absf(bank)), 8.0).rotated(player.rotation) * ws)
		elif tr.get_point_count() > 0: tr.remove_point(0)
		while tr.get_point_count() > 14: tr.remove_point(0)
	if trail_fx:
		var tips := []
		for i in 2: tips.append(player.position + Vector2((i * 2 - 1) * 26.0 * (1.0 - 0.3 * absf(bank)), 8.0).rotated(player.rotation) * ws)
		tips.append(Vector2.RIGHT.rotated(player.rotation))
		trail_fx.push(tips, _dt, phase == "play" and vel.length() > 120.0 and player.visible)
	shadow.modulate.a = lerpf(0.45, 0.18, k)
	if phase == "brief": throttle = 0.04 # sığınakta rölanti; kalkış ve çıkış gazı kendi fonksiyonlarında
	flame.position = player.position; flame.rotation = player.rotation
	flame.sc = player.scale.y / psc; flame.roll = bank; flame.thr = throttle
	flame.visible = player.visible; flame.queue_redraw()
	hpbar.position = player.position + Vector2(0, 48)
	hpbar.visible = phase == "play"
	hpbar.k = hp / max_hp
	hpbar.a = (1.0 - dash_cd / _dash_cd()) if pd.id == "simsek" else ((1.0 - salvo_t / _salvo_cd()) if pd.id == "dogan" else clampf(shield_t / _shield_cd(), 0.0, 1.0))
	hpbar.flag = shield_ready if pd.id == "kartal" else (not revived and pd.id == "anka")
	hpbar.queue_redraw()
	if inv > 0.0 and phase == "play" and fmod(t, 0.12) < 0.06: player.modulate = Color(2.5, 0.6, 0.6)
	else: player.modulate = Color.WHITE

# ================= İstatistik, silah ekleme =================
func _recalc() -> void:
	var p := passives
	var T := tree_s
	var old_amount: int = st.get("amount", 0)
	st = {
		"speed": maxf(0.4, 1.0 + 0.10 * p.get("motor", 0) + T.get("speed", 0) / 100.0 + curse.get("pspd", 0.0)),
		"might": pd.might * (1.0 + 0.10 * p.get("kalibre", 0) + T.get("dmg", 0) / 100.0 + tac.get("dmg", 0.0)) * (1.0 + mast.get("dmg", 0.0)),
		"cdr": (1.0 - 0.08 * p.get("sogutucu", 0)) / maxf(0.3, 1.0 + T.get("rate", 0) / 100.0 + tac.get("rate", 0.0)),
		"magnet": pd.magnet * (1.0 + 0.4 * p.get("miknatis", 0) + T.get("magnet", 0) / 100.0 + tac.get("mag", 0.0)),
		"armor": pd.armor + p.get("zirh", 0) + T.get("armor", 0),
		"regen": 0.5 * p.get("onarim", 0) + T.get("regen", 0),
		"area": 1.0 + 0.10 * p.get("alan", 0) + T.get("area", 0) / 100.0,
		"crit": 5.0 + 4.0 * p.get("nisan", 0) + T.get("crit", 0) + tac.get("crit", 0.0),
		"critm": 1.5 + 0.10 * p.get("nisan", 0) + T.get("critm", 0) / 100.0,
		"amount": int(T.get("amount", 0)) + int(p.get("coklayici", 0) / 2),
		"xpm": maxf(0.3, 1.0 + 0.10 * p.get("ogrenme", 0) + T.get("xp", 0) / 100.0 + curse.get("xp", 0.0) + tac.get("xp", 0.0) + mast.get("xp", 0.0)),
		"agi": 1.0 + T.get("agi", 0) / 100.0,
		"pen": T.get("pen", 0.0) + 2.0 * p.get("delici", 0),
		"dodge": minf(40.0, T.get("dodge", 0.0)),
	}
	var nm: float = maxf(20.0, (pd.hp + 20.0 * p.get("zirh", 0) + T.get("hp", 0) + tac.get("hp", 0.0) + mast.get("hp", 0.0)) * (1.0 + T.get("hpp", 0) / 100.0) + curse.get("maxhp", 0.0))
	if nm > max_hp: hp += nm - max_hp
	max_hp = nm; hp = minf(hp, max_hp)
	if weapons.has("kalkan") and old_amount != st.amount: _weapon_changed("kalkan")
	_refresh_icons()

func add_weapon(id: String) -> void:
	weapons[id] = {"lvl": 1, "cd": 0.3, "s": Data.wstats(id, 1), "on": true, "pt": 0.0, "tick": 0.0}
	_weapon_changed(id)

func _weapon_changed(id: String) -> void:
	var w: Dictionary = weapons[id]
	w.s = Data.wstats(id, w.lvl)
	if id == "kalkan":
		for o in orbs: o.queue_free()
		orbs.clear()
		for k in w.s.n + st.get("amount", 0):
			var o := Sprite2D.new(); o.texture = Data.tex("p_orb"); o.scale = Vector2.ONE * 0.9; L_shot.add_child(o); orbs.append(o)
	if id == "emp": emp_ring.visible = true
	_refresh_icons()

func _refresh_icons() -> void:
	if wbox == null: return
	for c in wbox.get_children(): c.queue_free()
	for c in pbox.get_children(): c.queue_free()
	for id in weapons: wbox.add_child(_icon(Data.SIGS[pd.sig].icon if id == "sig" else Data.WEAPONS[id].icon, "★" if id == "sig" else ("E" if weapons[id].lvl > Data.MAX_LV else str(weapons[id].lvl)), 44))
	for id in passives: pbox.add_child(_icon(Data.PASSIVES[id].icon, str(passives[id]), 34))

func _icon(name: String, lv: String, s: float) -> Control:
	var c := Control.new(); c.custom_minimum_size = Vector2(s + 4, s + 4); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := UI.pic(Data.tex(name), Vector2(s, s)); c.add_child(p)
	var l := UI.lbl(lv, 14, UI.GOLD, true); l.position = Vector2(s - 10, s - 20); c.add_child(l)
	return c

# ================= Uzaysal ızgara =================
func _rebuild_grid() -> void:
	grid.clear()
	for e in enemies:
		if e.dead or e.boss: continue
		var k := Vector2i(floori(e.position.x / CELL), floori(e.position.y / CELL))
		if grid.has(k): grid[k].append(e)
		else: grid[k] = [e]

func near(pos: Vector2, rad: float) -> Array:
	var out := []
	var a := Vector2i(floori((pos.x - rad) / CELL), floori((pos.y - rad) / CELL))
	var b := Vector2i(floori((pos.x + rad) / CELL), floori((pos.y + rad) / CELL))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var k := Vector2i(x, y)
			if grid.has(k): out.append_array(grid[k])
	out.append_array(bosses)
	return out

## Otomatik nişan: menzilde boss varsa ona kilitlenir, yoksa en yakın düşman
func target_for(pos: Vector2, rng: float):
	for b in bosses:
		if not b.dead and pos.distance_squared_to(b.position) < rng * rng: return b
	return nearest(pos, rng)

func nearest(pos: Vector2, rng: float):
	var best = null
	var bd := rng * rng
	for e in enemies:
		if e.dead: continue
		var d: float = pos.distance_squared_to(e.position)
		if d < bd: bd = d; best = e
	return best

# ================= Silahlar =================
func _update_weapons(dt: float) -> void:
	for id in weapons:
		if id == "sig":
			_fire_sig(dt); continue
		var w: Dictionary = weapons[id]
		var s: Dictionary = w.s
		match id:
			"kalkan": _update_orbs(dt, w, s); continue
			"emp": _update_emp(dt, w, s); continue
		w.cd -= dt
		if w.cd > 0.0: continue
		w.cd = s.cd * st.cdr
		match id:
			"top": _fire_top(s)
			"fuze": _fire_fuze(s)
			"simsek": _fire_simsek(s)
			"lazer": _fire_lazer(s)
			"mayin": _fire_mayin(s)
			"napalm": _fire_napalm(s)
			"ray": _fire_ray(s)
			"glaive": _fire_glaive(s)
			"hava": _fire_hava(s)
			"taret": _fire_taret(s)

func _fwd() -> Vector2: return Vector2.UP.rotated(player.rotation)

## Uçağa özel imza silahı: kartlarla değil oyuncu seviyesiyle güçlenir
func _fire_sig(dt: float) -> void:
	var w: Dictionary = weapons.sig
	w.cd -= dt
	if w.cd > 0.0: return
	var S: Dictionary = Data.SIGS[pd.sig]
	var m: float = (1.0 + 0.07 * (lvl - 1)) * (1.0 + mast.get("sig_dmg", 0.0))
	w.cd = S.cd / (1.0 + 0.02 * (lvl - 1)) * st.cdr * (1.0 - mast.get("sig_cd", 0.0))
	var tg = target_for(player.position, 760.0)
	var aim: Vector2 = (tg.position - player.position).normalized() if tg else _fwd()
	match pd.sig:
		"vulcan":
			for sx in [-1.0, 1.0]:
				var b := _new_shot("bullet", "p_bullet", player.position + aim.orthogonal() * sx * 11.0 + aim * 20.0, aim * 900.0, S.dmg * m, 1.0)
				b.material = ADD; b.modulate = Color(pd.color.r * 2.2, pd.color.g * 2.2, pd.color.b * 2.2); b.scale = Vector2(0.75, 0.9)
				b.pierce = int(mast.get("sig_pierce", 0))
			_muzzle(aim, 1.0)
			Sfx.play("shoot")
		"rockets":
			for k in 2:
				var r := _new_shot("missile", "p_missile", player.position, Vector2.from_angle(aim.angle() + (k * 2 - 1) * 1.1) * 240.0, S.dmg * m, 2.5)
				r.rad = S.rad * st.area; r.target = tg; r.scale = Vector2.ONE * 0.75
			Sfx.play("missile")
		"arc":
			var cur = nearest(player.position, S.range)
			if cur == null: return
			var pts: Array = [player.position]
			var hit := {}
			for c in 3 + int(mast.get("sig_chain", 0)):
				pts.append(cur.position); hit[cur] = true; hurt(cur, S.dmg * m, Vector2.ZERO, 0.0, false)
				var nx = null
				var bd := 200.0 * 200.0
				for e in near(cur.position, 200.0):
					if e.dead or hit.has(e): continue
					var dd: float = e.position.distance_squared_to(cur.position)
					if dd < bd: bd = dd; nx = e
				if nx == null: break
				cur = nx
			_bolt(pts); Sfx.play("zap")
		"flak":
			var nf := 5 + int(mast.get("sig_n", 0))
			for k in nf:
				var dir := aim.rotated((k - (nf - 1) / 2.0) * 0.2)
				var fl := _new_shot("flak", "p_bullet", player.position + dir * 24.0, dir * 520.0, S.dmg * m, 220.0 / 520.0)
				fl.rad = S.rad * st.area; fl.material = ADD; fl.modulate = Color(2.6, 1.4, 0.5); fl.scale = Vector2(1.3, 0.7)
			Sfx.play("shoot")
		"solar":
			_fire_lazer({"dmg": S.dmg * m, "w": S.w, "len": S.len, "back": false})

func _new_shot(kind: String, tex: String, pos: Vector2, v: Vector2, dmg: float, life: float) -> Shot:
	var s := Shot.new(); s.kind = kind; s.texture = Data.tex(tex); s.position = pos; s.vel = v; s.dmg = dmg; s.life = life
	s.rotation = v.angle() + PI / 2.0
	L_shot.add_child(s); shots.append(s)
	return s

func _fire_top(s: Dictionary) -> void:
	var tg = target_for(player.position, 750.0)
	var base: float = (tg.position - player.position).angle() if tg else _fwd().angle()
	var n: int = s.n + st.amount
	for k in n:
		var a: float = base + (k - (n - 1) / 2.0) * 0.11
		var b := _new_shot("bullet", "p_bullet", player.position + Vector2.from_angle(a) * 24.0, Vector2.from_angle(a) * s.spd, s.dmg, 1.2)
		b.pierce = s.pierce; b.material = ADD; b.modulate = Color(pd.color.r * 2.2, pd.color.g * 2.2, pd.color.b * 2.2); b.scale = Vector2(0.9, 0.9)
	_muzzle(Vector2.from_angle(base), 1.2)
	Sfx.play("shoot")

## Namlu ağzı: kısa parlak çekirdek + öne doğru uzayan ince alev (eskiden tek sönük nokta)
func _muzzle(dir: Vector2, k: float) -> void:
	var p0 := player.position + dir * 30.0 * player.scale.y / psc / PS
	var mz := Sprite2D.new(); mz.texture = T_GLOW; mz.material = ADD; mz.position = p0; mz.z_index = 3
	mz.modulate = Color(pd.color.r * 3.0 + 1.0, pd.color.g * 3.0 + 0.8, pd.color.b * 3.0 + 0.5, 0.9); mz.scale = Vector2(0.32, 0.32) * k
	L_fx.add_child(mz)
	var fl := Sprite2D.new(); fl.texture = T_GLOW; fl.material = ADD; fl.position = p0 + dir * 10.0 * k; fl.rotation = dir.angle(); fl.z_index = 3
	fl.modulate = Color(2.6, 1.8, 0.8, 0.7); fl.scale = Vector2(0.55, 0.13) * k; L_fx.add_child(fl)
	for sp in [mz, fl]:
		var tw: Tween = sp.create_tween().set_parallel()
		tw.tween_property(sp, "modulate:a", 0.0, 0.06); tw.tween_property(sp, "scale", sp.scale * 1.5, 0.06)
		tw.chain().tween_callback(sp.queue_free)

func _fire_fuze(s: Dictionary) -> void:
	for k in s.n + st.amount:
		var side := 1.0 if k % 2 == 0 else -1.0
		var a := _fwd().angle() + side * (1.3 + 0.25 * int(k / 2))
		var m := _new_shot("missile", "p_missile", player.position, Vector2.from_angle(a) * 220.0, s.dmg, 3.0)
		m.rad = s.rad * st.area; m.target = target_for(player.position, 800.0)
	Sfx.play("missile")

func _fire_simsek(s: Dictionary) -> void:
	var pool := enemies.filter(func(e): return not e.dead and e.position.distance_squared_to(player.position) < 650.0 * 650.0)
	if pool.is_empty(): return
	for k in s.n + st.amount:
		var cur = pool.pick_random()
		var pts: Array = [cur.position + Vector2(randf_range(-80, 80), -520)]
		var hitset := {}
		for c in s.chain + 1:
			pts.append(cur.position); hitset[cur] = true
			hurt(cur, s.dmg)
			var nxt = null
			var bd := 240.0 * 240.0
			for e in near(cur.position, 240.0):
				if e.dead or hitset.has(e): continue
				var d: float = e.position.distance_squared_to(cur.position)
				if d < bd: bd = d; nxt = e
			if nxt == null: break
			cur = nxt
		_bolt(pts)
	Sfx.play("zap")

func _bolt(pts: Array) -> void:
	var ln := Line2D.new(); ln.width = 4.0; ln.default_color = Color(2.6, 2.4, 1.0); ln.material = ADD
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]
		for j in 6:
			var p := a.lerp(b, j / 6.0)
			if j > 0: p += (b - a).orthogonal().normalized() * randf_range(-14, 14)
			ln.add_point(p)
	ln.add_point(pts[-1])
	L_fx.add_child(ln)
	var tw := ln.create_tween(); tw.tween_property(ln, "modulate:a", 0.0, 0.3); tw.tween_callback(ln.queue_free)

func _fire_lazer(s: Dictionary) -> void:
	var tg = target_for(player.position, 760.0)
	var aimd: Vector2 = (tg.position - player.position).normalized() if tg else _fwd()
	var dirs := [aimd]
	if s.back: dirs.append(-aimd)
	for d in dirs: _beam(d, s.len, s.w * st.area, s.dmg, Color(pd.color.r * 2.5, pd.color.g * 2.5, pd.color.b * 2.5))
	Sfx.play("laser")

## Düz ışın: oyuncudan d yönünde, yolundaki her düşmana bir kez vurur
func _beam(d: Vector2, ln_len: float, w: float, dmg: float, col: Color) -> void:
	var a: Vector2 = player.position + d * 30.0
	var b: Vector2 = a + d * ln_len
	for e in enemies:
		if e.dead: continue
		var q := Geometry2D.get_closest_point_to_segment(e.position, a, b)
		if q.distance_to(e.position) < w * 0.5 + e.r: hurt(e, dmg, d, 60.0)
	for k in 2:
		var ln := Line2D.new(); ln.points = PackedVector2Array([a, b]); ln.material = ADD
		ln.width = w if k == 0 else w * 0.35
		ln.default_color = col if k == 0 else Color(3, 3, 3)
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND; ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		L_fx.add_child(ln)
		var tw := ln.create_tween().set_parallel()
		tw.tween_property(ln, "width", 0.0, 0.3); tw.tween_property(ln, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(ln.queue_free)

# --- v0.9 silahları ---
func _fire_napalm(s: Dictionary) -> void:
	var f := _new_shot("fire", "glow", player.position - _fwd() * 34.0, Vector2.ZERO, s.dmg, s.dur)
	f.texture = T_GLOW; f.material = ADD; f.rad = s.rad * st.area; f.period = s.tick; f.tick = 0.0
	f.scale = Vector2.ONE * f.rad / 36.0; f.modulate = Color(1.3, 0.45, 0.12, 0.32); f.rotation = randf() * TAU # üst üste binen izler kör etmesin

func _fire_ray(s: Dictionary) -> void:
	var tg = target_for(player.position, 900.0)
	var base: float = (tg.position - player.position).angle() if tg else _fwd().angle()
	var n: int = s.n + st.amount
	for k in n: _beam(Vector2.from_angle(base + (k - (n - 1) / 2.0) * 0.14), 1500.0, s.w * st.area, s.dmg, Color(1.2, 2.2, 2.8))
	shake = maxf(shake, 3.0); Sfx.play("laser")

func _fire_glaive(s: Dictionary) -> void:
	var tg = target_for(player.position, s.range)
	var base: float = (tg.position - player.position).angle() if tg else _fwd().angle()
	var n: int = s.n + st.amount
	for k in n:
		var a: float = base + k * TAU / n if n > 2 else base + (k - (n - 1) / 2.0) * 0.5
		var g := _new_shot("glaive", "p_glaive", player.position, Vector2.from_angle(a) * s.spd, s.dmg, 6.0)
		g.rng = s.range * st.area; g.material = ADD

func _fire_hava(s: Dictionary) -> void:
	var pool := enemies.filter(func(e): return not e.dead and e.position.distance_squared_to(player.position) < 620.0 * 620.0)
	for k in s.n + st.amount:
		var pos: Vector2 = pool.pick_random().position if not pool.is_empty() else player.position + Vector2.from_angle(randf() * TAU) * randf_range(120, 400)
		var m := _new_shot("strike", "ring", pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Vector2.ZERO, s.dmg, 0.8 + 0.08 * k)
		m.rad = s.rad * st.area; m.material = ADD; m.modulate = Color(1.8, 0.35, 0.25, 0.45); m.rotation = 0.0

func _fire_taret(s: Dictionary) -> void:
	for k in s.n + st.amount:
		var tr := _new_shot("turret", "p_turret", player.position + Vector2.from_angle(randf() * TAU) * 40.0, Vector2.ZERO, s.dmg, s.dur)
		tr.period = s.rate; tr.tick = 0.2; tr.scale = Vector2.ONE * 1.2

func _fire_mayin(s: Dictionary) -> void:
	for k in s.n + st.amount:
		var m := _new_shot("mine", "p_mine", player.position - _fwd() * 40.0 + Vector2(randf_range(-30, 30), randf_range(-30, 30)), Vector2.ZERO, s.dmg, 12.0)
		m.rad = s.rad * st.area; m.rotation = randf() * TAU

func _update_orbs(dt: float, w: Dictionary, s: Dictionary) -> void:
	w.pt += dt
	if w.on and w.pt > s.on: w.on = false; w.pt = 0.0
	elif not w.on and w.pt > s.off: w.on = true; w.pt = 0.0
	for k in orbs.size():
		var o: Sprite2D = orbs[k]
		o.visible = w.on
		if not w.on: continue
		var a: float = t * s.spd + k * TAU / orbs.size()
		o.position = player.position + Vector2.from_angle(a) * s.r * st.area
		o.rotation += dt * 8.0
		for e in near(o.position, 60.0):
			if e.dead or e.hitcd > t: continue
			if o.position.distance_squared_to(e.position) < pow(e.r + 15.0, 2):
				e.hitcd = t + 0.35
				hurt(e, s.dmg, (e.position - player.position).normalized(), 140.0)

func _update_emp(dt: float, w: Dictionary, s: Dictionary) -> void:
	emp_ring.position = player.position
	emp_ring.scale = Vector2.ONE * (s.r * st.area * 2.0 / 124.0) * (1.0 + 0.04 * sin(t * 8.0))
	emp_ring.rotation += dt
	w.tick -= dt
	if w.tick > 0: return
	w.tick = s.tick
	var er: float = s.r * st.area
	for e in near(player.position, er + 50.0):
		if not e.dead and e.position.distance_to(player.position) < er + e.r:
			hurt(e, s.dmg, (e.position - player.position).normalized(), 90.0, false)

# ================= Mermiler =================
func _update_shots(dt: float) -> void:
	for s in shots:
		if s.dead: continue
		s.life -= dt
		if s.life <= 0.0:
			if s.kind == "mine" or s.kind == "flak" or s.kind == "strike": _blast(s.position, s.rad, s.dmg, {"flak": 0.45, "strike": 0.5}.get(s.kind, 1.0))
			_kill_shot(s); continue
		match s.kind:
			"flak":
				s.position += s.vel * dt
				for e in near(s.position, 50.0):
					if not e.dead and s.position.distance_squared_to(e.position) < pow(e.r + 6.0, 2):
						_blast(s.position, s.rad, s.dmg, 0.45); _kill_shot(s); break
			"bullet":
				s.position += s.vel * dt
				for e in near(s.position, 50.0):
					if e.dead or s.hit.has(e): continue
					if s.position.distance_squared_to(e.position) < pow(e.r + 6.0, 2):
						s.hit[e] = true
						hurt(e, s.dmg, s.vel.normalized(), 30.0)
						s.pierce -= 1
						if s.pierce < 0: _kill_shot(s); break
			"missile":
				if s.target == null or not is_instance_valid(s.target) or s.target.dead: s.target = nearest(s.position, 700.0)
				var a: float = s.vel.angle()
				if s.target: a = rotate_toward(a, (s.target.position - s.position).angle(), 6.0 * dt)
				s.vel = Vector2.from_angle(a) * minf(s.vel.length() + 900.0 * dt, 720.0)
				s.rotation = a + PI / 2.0
				s.position += s.vel * dt
				if randf() < 0.5: _puff(s.position, Color(1, 0.7, 0.4, 0.5), 0.35, Vector2.ZERO, 0.3)
				for e in near(s.position, 50.0):
					if not e.dead and s.position.distance_squared_to(e.position) < pow(e.r + 8.0, 2):
						_blast(s.position, s.rad, s.dmg); _kill_shot(s); break
			"fire": # napalm: alan hasarı, söner
				s.modulate.a = minf(0.32, s.life * 0.4) * randf_range(0.8, 1.0)
				s.tick -= dt
				if s.tick <= 0.0:
					s.tick = s.period
					for e in near(s.position, s.rad + 40.0):
						if not e.dead and s.position.distance_squared_to(e.position) < pow(s.rad + e.r, 2): hurt(e, s.dmg, Vector2.ZERO, 0.0, false)
			"glaive": # dön, ilerle; menzil sonunda geri dön
				s.rotation += dt * 18.0
				var to_p: Vector2 = player.position - s.position
				if not s.ret and to_p.length() > s.rng: s.ret = true
				if s.ret:
					s.vel = s.vel.lerp(to_p.normalized() * 820.0, 1.0 - exp(-dt * 6.0))
					if to_p.length() < 30.0: _kill_shot(s); continue
				s.position += s.vel * dt
				for e in near(s.position, 50.0):
					if e.dead or s.hit.get(e, 0.0) > t: continue
					if s.position.distance_squared_to(e.position) < pow(e.r + 14.0, 2):
						s.hit[e] = t + 0.35; hurt(e, s.dmg, s.vel.normalized(), 40.0)
			"strike": # hedef işareti daralır, sonunda patlar
				s.scale = Vector2.ONE * s.rad / 62.0 * (0.5 + s.life * 0.5)
			"turret":
				s.tick -= dt
				if s.life < 0.6: s.modulate.a = s.life / 0.6
				if s.tick <= 0.0:
					s.tick = s.period
					var tg = nearest(s.position, 460.0)
					if tg:
						var dir: Vector2 = (tg.position - s.position).normalized()
						s.rotation = dir.angle() + PI / 2.0
						var b := _new_shot("bullet", "p_bullet", s.position + dir * 16.0, dir * 760.0, s.dmg, 0.8)
						b.material = ADD; b.modulate = Color(2.6, 1.6, 0.5); b.scale = Vector2(0.7, 0.7)
			"mine":
				s.modulate = Color(1, 1, 1) if fmod(s.life, 0.6) > 0.3 else Color(2, 0.6, 0.6)
				if s.life < 11.6:
					for e in near(s.position, 60.0):
						if not e.dead and s.position.distance_squared_to(e.position) < pow(e.r + 22.0, 2):
							_blast(s.position, s.rad, s.dmg); _kill_shot(s); break

## Sıçrayan'ın varış işareti: daralan halka
func _telegraph(pos: Vector2, life: float, col: Color) -> void:
	var r := Sprite2D.new(); r.texture = Data.tex("ring"); r.material = ADD; r.position = pos; r.modulate = Color(col, 0.8); L_fx.add_child(r)
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "scale", Vector2.ONE * 0.4, life).from(Vector2.ONE * 1.4)
	tw.chain().tween_callback(r.queue_free)

func _heal_beam(a: Vector2, b: Vector2) -> void:
	var ln := Line2D.new(); ln.points = PackedVector2Array([a, b]); ln.width = 3.0; ln.default_color = Color(0.5, 2.6, 0.8, 0.8); ln.material = ADD; L_fx.add_child(ln)
	var tw := ln.create_tween(); tw.tween_property(ln, "modulate:a", 0.0, 0.4); tw.tween_callback(ln.queue_free)

func _kill_shot(s: Shot) -> void:
	s.dead = true; s.queue_free()

func _blast(pos: Vector2, rad: float, dmg: float, vis := 1.0) -> void:
	for e in near(pos, rad + 50.0):
		if not e.dead and e.position.distance_to(pos) < rad + e.r:
			hurt(e, dmg, (e.position - pos).normalized(), 160.0, false)
	explosion(pos, Color(1.0, 0.55, 0.2), rad / 35.0 * vis)
	Sfx.play("mine")

# ================= Hasar / ölüm =================
func hurt(e: Enemy, dmg: float, dir := Vector2.ZERO, kbf := 0.0, sound := true) -> void:
	if e.dead: return
	dmg *= st.might
	if pd.id == "dogan" and (e.boss or e.elite): dmg *= 1.3 + mast.get("boss_dmg", 0.0)
	if e.boss or e.elite: dmg *= 1.0 + 0.10 * passives.get("avci", 0)
	if hp < max_hp * 0.5: dmg *= 1.0 + 0.08 * passives.get("sonnefes", 0)
	if e.d.get("ai", "") == "shield" and dir != Vector2.ZERO and dir.dot(Vector2.UP.rotated(e.rotation)) < -0.2:
		dmg *= 0.25 # kalkancı: önden gelen vuruşu emer
		if randf() < 0.3: _puff(e.position + Vector2.UP.rotated(e.rotation) * e.r, Color(0.6, 1.4, 2.6, 0.7), 0.25, Vector2.ZERO, 0.2)
	var crit: bool = randf() * 100.0 < st.crit
	if crit: dmg *= st.critm
	dmg = maxf(dmg * 0.25, dmg - maxf(0.0, e.armor - st.pen)) # zırh düz hasar azaltır, en az %25 geçer
	e.hp -= dmg; e.flash = 0.07
	if kbf > 0.0 and not e.boss: e.kb += dir * kbf
	_dmg_text(e.position, dmg, crit)
	if sound: Sfx.play("hit")
	if e.hp <= 0.0: _kill_enemy(e)

## Hasar sayıları (Ayarlar): 0 kapalı, 1 sadece kritik (varsayılan, Brotato gibi), 2 hepsi
func _dmg_text(pos: Vector2, dmg: float, crit := false) -> void:
	if dmg_labels >= 40 or Save.dmg_nums == 0 or (Save.dmg_nums == 1 and not crit): return
	dmg_labels += 1
	var l := UI.lbl(str(int(round(dmg))) + ("!" if crit else ""), 28 if crit else 17, Color(2.4, 2.0, 0.5) if crit else Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 5); l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.size = Vector2(60, 24); l.position = pos + Vector2(-30 + randf_range(-10, 10), -40); l.z_index = 50
	L_fx.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 30.0, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tw.chain().tween_callback(func(): dmg_labels -= 1; l.queue_free())

func _kill_enemy(e: Enemy) -> void:
	e.dead = true; kills += 1; score += e.xpv * 10
	Save.seen[e.kind] = int(Save.seen.get(e.kind, 0)) + 1 # Defter: öldürülen tür açılır
	if e.aim: e.aim.queue_free()
	if e.d.get("ai", "") == "split" and enemies.size() < 160:
		for k in 3: make_enemy("kivilcim", Data.ENEMIES.kivilcim, e.position + Vector2.from_angle(k * TAU / 3.0) * 22.0)
	explosion(e.position, e.d.col, e.r / 18.0)
	if e.boss:
		_boss_killed(e)
	else:
		_drop_gem(e.position, e.xpv)
		if e.elite: _drop(e.position, "chest"); hitstop = maxf(hitstop, 0.04)
		if (e.r >= 24.0 or e.elite) and wrecks < 14: # büyük gemi dönerek düşer
			wrecks += 1; wreck_from(e, e.vel * 0.6, e.r / 26.0 * (1.3 if e.elite else 1.0))
		kill_times.append(t) # seri düşürme repliği: 6 sn'de 30 düşman
		while not kill_times.is_empty() and kill_times[0] < t - 6.0: kill_times.pop_front()
		if kill_times.size() >= 30 and t >= streak_next:
			streak_next = t + 50.0; var sk := _line("streak"); radio(sk[0], sk[1], 0)
		var r := randf()
		if r < 0.006: _drop(e.position, "heal")
		elif r < 0.009: _drop(e.position, "magnet")
	e.queue_free()

func explosion(pos: Vector2, col: Color, k := 1.0) -> void:
	Sfx.play("boom")
	var fl := Sprite2D.new(); fl.texture = T_GLOW; fl.material = ADD; fl.position = pos
	fl.modulate = Color(1.6, 0.75, 0.3).lerp(col, 0.3); fl.scale = Vector2.ONE * 1.1 * k # ateş topu: turuncu, kısa
	L_fx.add_child(fl)
	var tw := fl.create_tween().set_parallel()
	tw.tween_property(fl, "scale", Vector2.ONE * 2.2 * k, 0.22); tw.tween_property(fl, "modulate:a", 0.0, 0.26)
	tw.chain().tween_callback(fl.queue_free)
	if k >= 1.3: # şok dalgası + renk kayması
		var rg := Sprite2D.new(); rg.texture = Data.tex("ring"); rg.material = ADD; rg.position = pos; rg.scale = Vector2.ONE * 0.2 * k
		rg.modulate = Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 0.9); L_fx.add_child(rg)
		var rt := rg.create_tween().set_parallel()
		rt.tween_property(rg, "scale", Vector2.ONE * 1.1 * k, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		rt.tween_property(rg, "modulate:a", 0.0, 0.35); rt.chain().tween_callback(rg.queue_free)
		if k >= 2.5: ca_pulse = minf(ca_pulse + 0.2, 0.6) # sadece büyük patlamalar ekranı sarsar
	if k >= 0.9: # yükselen duman
		for i in int(2 + k):
			_puff(pos + Vector2(randf_range(-12, 12), randf_range(-12, 12)) * k, Color(0.18, 0.17, 0.2, 0.55), randf_range(0.6, 1.0) * k, Vector2(randf_range(-30, 30), randf_range(-50, -20)), randf_range(0.8, 1.3))
	if fx_count >= 40: return
	fx_count += 1
	if true: # dönen enkaz parçaları (v0.13: küçük gemilerde de, gövde renginde kıvılcımlı)
		var db := CPUParticles2D.new(); db.texture = T_GLOW; db.position = pos; db.one_shot = true; db.amount = int(4 + 3 * k)
		db.lifetime = 0.9; db.explosiveness = 1.0; db.spread = 180.0; db.gravity = Vector2.ZERO
		db.initial_velocity_min = 80.0; db.initial_velocity_max = 220.0 * k; db.damping_min = 120.0; db.damping_max = 180.0
		db.scale_amount_min = 0.05; db.scale_amount_max = 0.11; db.color = Color(0.25, 0.22, 0.28).lerp(col, 0.35)
		db.angular_velocity_min = -400.0; db.angular_velocity_max = 400.0
		db.finished.connect(db.queue_free); L_fx.add_child(db); db.emitting = true
	var p := CPUParticles2D.new(); p.texture = T_GLOW; p.material = ADD; p.position = pos
	p.one_shot = true; p.amount = int(10 + 8 * k); p.lifetime = 0.55; p.explosiveness = 1.0
	p.spread = 180.0; p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0 * k + 40.0; p.initial_velocity_max = 260.0 * k + 80.0
	p.damping_min = 150.0; p.damping_max = 250.0
	p.scale_amount_min = 0.1; p.scale_amount_max = 0.3 * clampf(k, 0.8, 2.5)
	var g := Gradient.new()
	g.set_color(0, Color(1.8, 1.3, 0.8, 1)); g.set_color(1, Color(0.25, 0.1, 0.05, 0))
	g.add_point(0.3, Color(1.5, 0.55, 0.15, 0.9).lerp(col, 0.35))
	p.color_ramp = g
	p.finished.connect(func(): fx_count -= 1; p.queue_free())
	L_fx.add_child(p); p.emitting = true

func _drop_gem(pos: Vector2, v: int) -> void:
	if gems.size() > 400:
		var g: Gem = gems.pick_random(); g.val += v; return
	var g := Gem.new(); g.kind = "xp"; g.val = v; g.texture = Data.tex("core"); g.position = pos
	g.modulate = Color(1.6, 0.35, 0.3) if v >= 10 else (Color(1.6, 1.0, 0.3) if v >= 4 else Color(0.4, 1.3, 1.25)) # turkuaz < kehribar < kızıl
	g.scale = Vector2.ONE * (0.55 + minf(v, 20) * 0.02); g.rotation = randf() * TAU
	L_gem.add_child(g); gems.append(g)

func _drop(pos: Vector2, kind: String) -> void:
	var g := Gem.new(); g.kind = kind; g.texture = Data.tex(kind); g.position = pos
	if kind == "chest": # Blender'da çekilmiş küçük Vahar ikmal kapsülü + yumuşak altın parıltı ve ince nabız halkası
		var pod := Data.sheet("pod")
		if pod: g.texture = pod; g.scale = Vector2.ONE * 0.45
		var glow := Sprite2D.new(); glow.texture = T_GLOW; glow.material = ADD; glow.show_behind_parent = true
		glow.modulate = Color(1.2, 0.75, 0.25, 0.35); glow.scale = Vector2.ONE * 0.9; g.add_child(glow)
		var ring := Sprite2D.new(); ring.texture = Data.tex("ring"); ring.material = ADD; ring.show_behind_parent = true; g.add_child(ring)
		var tw := ring.create_tween().set_loops()
		tw.tween_property(ring, "scale", Vector2.ONE * 1.1, 1.3).from(Vector2.ONE * 0.45)
		tw.parallel().tween_property(ring, "modulate", Color(1.3, 0.85, 0.3, 0.0), 1.3).from(Color(1.3, 0.85, 0.3, 0.6))
	L_gem.add_child(g); gems.append(g)

func _update_gems(dt: float) -> void:
	var rad: float = 90.0 * st.magnet
	var pp := player.position
	for g in gems:
		if g.dead: continue
		var to: Vector2 = pp - g.position
		var d := to.length()
		if not g.mag and d < rad: g.mag = true
		g.rotation += dt * (0.7 if g.kind == "chest" else 1.5)
		var step := 0.0
		if g.mag: # doğrudan takip: yörüngeye girmez, hızlanarak uçağa gelir
			var sp: float = minf(maxf(g.vel.length(), vel.length() + 250.0) + 3200.0 * dt, 2400.0)
			g.vel = to / maxf(d, 1.0) * sp; step = sp * dt
			g.position += g.vel * dt
		if d < 24.0 + step:
			g.dead = true; g.queue_free(); _collect(g)

func _collect(g: Gem) -> void:
	match g.kind:
		"xp":
			Sfx.play("gem"); xp += maxi(1, int(round(g.val * st.xpm)))
			while xp >= Data.run_need(lvl):
				xp -= Data.run_need(lvl); lvl += 1; pending_lv += 1
		"heal":
			hp = minf(max_hp, hp + 30.0); Sfx.play("levelup"); _float_text(Data.L("+30 CAN"), Color(0.4, 2.0, 0.7))
		"magnet":
			for o in gems: o.mag = true
			Sfx.play("chest"); _float_text(Data.L("MIKNATIS!"), Color(2.0, 0.5, 0.6))
		"chest":
			chests += 1; pending_lv += 1; chest_picks += 1; hp = minf(max_hp, hp + 30.0); score += 2000
			Sfx.play("chest"); banner(Data.L("İKMAL KAPSÜLÜ"), Data.L("4 seçenek  •  evrimler yalnızca buradan çıkar"), Color(2.0, 1.4, 0.45))
			explosion(g.position, Color(1.0, 0.7, 0.2), 1.6)
			var cl := _line("chest"); radio(cl[0], cl[1], 0)

func _float_text(s: String, col: Color) -> void:
	var l := UI.lbl(s, 24, col, true, HORIZONTAL_ALIGNMENT_CENTER); l.size = Vector2(240, 30)
	l.position = player.position + Vector2(-120, -90); L_fx.add_child(l)
	var tw := l.create_tween(); tw.tween_property(l, "position:y", l.position.y - 50.0, 1.0); tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0); tw.tween_callback(l.queue_free)

# ================= Düşmanlar =================
func _wpick(mix: Dictionary) -> String:
	var tot := 0.0
	for k in mix: tot += mix[k]
	var r := randf() * tot
	for k in mix:
		r -= mix[k]
		if r <= 0.0: return k
	return mix.keys()[0]

func _spawn_pos(extra := 80.0) -> Vector2:
	return player.position + Vector2.from_angle(randf() * TAU) * (get_viewport_rect().size.length() * 0.5 + extra)

func make_enemy(kind: String, d: Dictionary, pos: Vector2, boss := false, elite := false) -> Enemy:
	var e := Enemy.new()
	e.kind = kind; e.d = d; e.texture = Data.sheet(d.tex) if Data.sheet(d.tex) else Data.tex(d.tex); e.position = pos; e.boss = boss
	e.hp = d.hp * hmult * (Data.BOSS_HP * d.get("hpk", 1.0) if boss else 1.0 + (t - wave_t0) / 240.0); e.maxhp = e.hp
	e.spd = d.spd * randf_range(0.9, 1.1) * (1.0 + curse.get("espd", 0.0)); e.dmg = d.dmg * dmult * (1.0 + curse.get("edmg", 0.0)); e.xpv = d.get("xp", 0); e.r = d.r
	e.hp *= 1.0 + curse.get("ehp", 0.0); e.maxhp = e.hp
	e.armor = stg.armor + d.get("armor", 0.0)
	if d.get("ai", "") == "sniper":
		e.aim = Line2D.new(); e.aim.width = 2.0; e.aim.default_color = Color(2.6, 0.2, 0.3, 0.8); e.aim.material = ADD; e.aim.visible = false; L_fx.add_child(e.aim)
	e.base_sc = d.get("scale", 1.0)
	var esh := Data.sheet(d.tex)
	if esh: e.texture = esh; e.hframes = 7; e.frame = 3; e.base_sc *= 0.5; e.is3d = true
	e.material = _outline_for(Color(1.0, 0.8, 0.3) if elite else d.col)
	e.tint = Color(1.3, 1.3, 1.35) # koyu çelik gövde zeminden ayrılsın
	var fh: float = e.texture.get_height()
	var gs: float = fh / T_GLOW.get_height()
	var ac: Color = d.col
	if not boss:
		e.core = Sprite2D.new(); e.core.texture = T_GLOW; e.core.material = ADD; e.core.scale = Vector2.ONE * gs * 0.35
		e.core.modulate = Color(ac * 2.2, 0.8); e.add_child(e.core)
	if not (boss or d.get("ai", "") == "spin"):
		e.eng = Sprite2D.new(); e.eng.texture = T_GLOW; e.eng.material = ADD; e.eng.position = Vector2(0, fh * 0.4)
		e.eng.scale = Vector2(0.28, 0.5) * gs; e.eng.modulate = Color(ac.lerp(Color(1.0, 0.6, 0.3), 0.4) * 2.0, 0.9); e.add_child(e.eng)
	if elite: # elit: 6 kat can, altın renk, ikmal kapsülü düşürür (zamanları _plan_radio'da)
		e.elite = true; e.hp *= 6.0; e.maxhp = e.hp; e.base_sc *= 1.35; e.xpv *= 5; e.armor += 2.0
		e.tint = Color(1.45, 1.25, 0.7)
		var halo := Sprite2D.new(); halo.texture = Data.tex("ring"); halo.material = ADD; halo.show_behind_parent = true; e.add_child(halo)
		var ht := halo.create_tween().set_loops() # altın hale: elit ve kapsülü uzaktan seçilsin
		ht.tween_property(halo, "scale", Vector2.ONE * 1.5 / e.base_sc, 0.8).from(Vector2.ONE * 0.6 / e.base_sc)
		ht.parallel().tween_property(halo, "modulate", Color(1.6, 1.15, 0.3, 0.0), 0.8).from(Color(1.6, 1.15, 0.3, 0.9))
	e.scale = Vector2.ONE * e.base_sc
	e.tm = randf_range(0.5, 2.0); e.rotation = (player.position - pos).angle() + PI / 2.0
	L_en.add_child(e); enemies.append(e)
	if boss: bosses.append(e)
	return e

## Düşman sayısı sınırsız değil: zamanla artan bir HEDEF var (Vampire Survivors'taki dakikalık "minimum").
## Hedefin altındaysa hızlı doldurur, üstündeyse doğurmaz. Boss gelince hedef ~14'e iner (Brotato'daki gibi).
func _director(dt: float) -> void:
	var k := stage + 1
	var prog := clampf((t - wave_t0) / (boss_t - wave_t0), 0.0, 1.0)
	var target: float = (13.0 + (32.0 + 2.0 * k) * smoothstep(0.0, 1.0, prog)) * stg.dens # v0.9: ilk saniyeden baskı
	target *= Data.OP_DENS[op_pos]
	if endless: target *= minf(1.0 + 0.05 * wave, 2.0) # sonsuz modda sürü de kalabalıklaşır
	if not bosses.is_empty(): target = 14.0 * stg.dens
	var alive := enemies.size() - bosses.size()
	spawn_acc += (0.0 if won else (6.0 if alive < target * 0.7 else (1.5 if alive < target else 0.0))) * dt
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if alive < target:
			var kind := _pick_kind(k, prog)
			make_enemy(kind, Data.ENEMIES[kind], _spawn_pos()); alive += 1
	while not radio_sched.is_empty() and t >= radio_sched[0][0]:
		var r: Array = radio_sched.pop_front()[1]
		if not boss_spawned: radio(r[0], r[1])
	if not elite_times.is_empty() and t >= elite_times[0] and not boss_spawned:
		elite_times.pop_front()
		var ek := _pick_kind(k, prog)
		for i in 6: # kamikaze çarpıp ölür, kapsül kaybolmasın
			if ek != "kamikaze": break
			ek = _pick_kind(k, prog)
		make_enemy(ek, Data.ENEMIES[ek], _spawn_pos(), false, true)
		var el := _line("elite"); radio(el[0], el[1], 2)
	if bosses.is_empty() and swarms_done < 2 and prog >= [0.4, 0.75][swarms_done]: # kuşatma halkası
		swarms_done += 1
		var n := int((16 + k) * stg.dens)
		for i in n: make_enemy(stg.swarm, Data.ENEMIES[stg.swarm], player.position + Vector2.from_angle(i * TAU / n) * 700.0)
		var sw := _line("swarm"); radio(sw[0], sw[1], 2)
	if not warned and not boss_spawned and t >= boss_t - 3.0: # 3 sn önceden WARNING geri sayımı
		warned = true; _boss_warning()
	if not boss_spawned and t >= boss_t:
		boss_spawned = true; _spawn_boss(stg.boss)

func _pick_kind(k: int, prog: float) -> String:
	var mix := {}
	for id in Data.ENEMIES:
		var d: Dictionary = Data.ENEMIES[id]
		if d.from > k: continue
		var debut := clampf((k - d.from + 1) / 3.0, 0.0, 1.0) # yeni tür 3 bölümde tam ağırlığa çıkar
		mix[id] = d.w * debut * ((1.2 - prog * 0.6) if id == "drone" else (0.5 + prog))
	return _wpick(mix)

func _update_enemies(dt: float) -> void:
	var pp := player.position
	pull = Vector2.ZERO; beam.visible = false
	for e in enemies:
		if e.dead: continue
		e.t += dt; e.flash -= dt
		e.modulate = Color(4, 4, 4) if e.flash > 0.0 else e.tint
		var to: Vector2 = pp - e.position
		var dist := to.length()
		var dir := to / maxf(dist, 1.0)
		e.tm -= dt; e.tm2 -= dt
		if e.core: e.core.modulate.a = 0.45 + 0.4 * sin(e.t * 5.0 + e.maxhp)
		if e.eng: e.eng.modulate.a = randf_range(0.65, 1.0)
		if e.boss: _boss_ai(e, dir, dist)
		else:
			match e.d.ai:
				"chase": e.vel = dir * e.spd
				"dash":
					if e.st == 0:
						e.vel = dir * e.spd
						if dist < 280.0: e.st = 1; e.tm = 0.7
					elif e.st == 1:
						e.vel = e.vel.lerp(Vector2.ZERO, dt * 8.0)
						if fmod(e.t, 0.14) < 0.07: e.modulate = Color(3, 2.5, 0.5)
						if e.tm <= 0.0: e.st = 2; e.tm = 0.9; e.lock = dir; Sfx.play("dash")
					else:
						e.vel = e.lock * 520.0
						if e.tm <= 0.0: e.st = 0
				"gun":
					if dist > 340.0: e.vel = dir * e.spd
					elif dist < 240.0: e.vel = -dir * e.spd * 0.7
					else: e.vel = dir.orthogonal() * e.spd * 0.6
					if e.tm <= 0.0 and dist < 700.0:
						e.tm = 2.4; _fan(e.position, 3, 0.3, 210.0, dir.angle(), Color("ffb03c"), 7.0, {"tier": 1})
				"spin":
					e.vel = (dir + dir.orthogonal() * 0.8).normalized() * e.spd
					if e.tm <= 0.0 and dist < 650.0:
						e.tm = 0.16; e.ang += 0.5
						for k in 2: _eb(e.position, e.ang + k * PI, 140.0, Color("c88cff"), 7.0, {"tier": 0})
				"bomber":
					e.vel = dir * e.spd
					if e.tm <= 0.0 and dist < 750.0:
						e.tm = 3.2; _ring(e.position, 16, 130.0, randf() * TAU, Color("ff3a2a"), 7.0, {"tier": 2})
				"shield", "split": e.vel = dir * e.spd
				"ghost": # uzakta görünmez (yalnız dış çizgi), yakında belirip dalar
					if e.st == 0:
						e.vel = dir * e.spd
						if dist < 260.0: e.st = 1; e.tm = 0.35
					elif e.st == 1:
						e.vel = e.vel.lerp(Vector2.ZERO, dt * 8.0)
						if e.tm <= 0.0: e.st = 2; e.tm = 0.7; e.lock = dir; Sfx.play("dash")
					else:
						e.vel = e.lock * 480.0
						if e.tm <= 0.0: e.st = 0
					if e.flash <= 0.0: e.modulate.a = 0.1 if e.st == 0 else 1.0
				"blink": # işaretler, ışınlanır, halka atar
					if e.st == 0:
						e.vel = dir * e.spd
						if e.tm <= 0.0 and dist < 800.0:
							e.st = 1; e.tm = 0.7; e.lock = pp + Vector2.from_angle(randf() * TAU) * randf_range(170, 230)
							_telegraph(e.lock, 0.7, Color(0.6, 0.7, 2.4))
					elif e.tm <= 0.0:
						explosion(e.position, e.d.col, 0.4); e.position = e.lock; explosion(e.position, e.d.col, 0.4)
						_ring(e.position, 10, 120.0, randf() * TAU, Color("8f9cff"), 7.0, {"tier": 1})
						e.st = 0; e.tm = 3.2
				"sniper": # mesafe tutar, kırmızı çizgiyle kilitlenir, ağır atış
					if e.st == 0:
						e.vel = (dir if dist > 560.0 else (-dir if dist < 440.0 else dir.orthogonal() * 0.5)) * e.spd
						if e.tm <= 0.0 and dist < 760.0: e.st = 1; e.tm = 1.0
					else:
						e.vel = Vector2.ZERO
						if e.tm <= 0.0:
							_eb(e.position + dir * 30.0, dir.angle(), 520.0, Color("ff3355"), 8.0, {"tier": 2}); Sfx.play("laser")
							e.st = 0; e.tm = 3.0
					e.aim.visible = e.st == 1
					if e.aim.visible: e.aim.points = PackedVector2Array([e.position, e.position + dir * 900.0]); e.aim.width = 1.0 + 3.0 * (1.0 - e.tm)
				"mines": # oyuncunun etrafında geniş tur atar, duran mayın bırakır
					var want: Vector2 = pp + (e.position - pp).normalized().rotated(0.6) * 360.0
					e.vel = (want - e.position).normalized() * e.spd
					if e.tm <= 0.0: e.tm = 1.6; var mb := _eb(e.position, 0.0, 0.0, Color("ff7a3c"), 9.0, {"tier": 2}); if mb: mb.life = 7.0
				"healer": # arkada kalır, yakındakileri onarır
					e.vel = (dir if dist > 460.0 else (-dir if dist < 340.0 else dir.orthogonal() * 0.4)) * e.spd
					if e.tm <= 0.0:
						e.tm = 1.5
						for o in near(e.position, 230.0):
							if o != e and not o.dead and not o.boss and o.hp < o.maxhp and o.position.distance_to(e.position) < 230.0:
								o.hp = minf(o.maxhp, o.hp + o.maxhp * 0.15); _heal_beam(e.position, o.position)
				"hive": # yavaş, mesafeli; dron doğurur
					e.vel = (dir if dist > 420.0 else dir.orthogonal() * 0.3) * e.spd
					if e.tm <= 0.0 and enemies.size() < 140:
						e.tm = 4.5
						for k in 3: make_enemy("kivilcim", Data.ENEMIES.kivilcim, e.position + Vector2.from_angle(randf() * TAU) * 40.0)
				"tank":
					e.vel = dir * e.spd
					if e.tm <= 0.0 and dist < 700.0: e.tm = 3.5; _ring(e.position, 12, 90.0, randf() * TAU, Color("ff5a3c"), 9.0, {"tier": 2})
				"orbit": # etrafında döner, sonra dalar
					if e.st == 2:
						e.vel = e.lock * 560.0
						if e.tm <= 0.0: e.st = 0; e.tm = randf_range(2.5, 3.5)
					else:
						var tang: Vector2 = dir.orthogonal() * e.flip
						e.vel = (tang + dir * clampf((dist - 230.0) / 120.0, -1.0, 1.0)).normalized() * e.spd
						if e.tm <= 0.0 and dist < 400.0: e.st = 2; e.tm = 0.55; e.lock = dir; Sfx.play("dash")
			# sürü ayrışması: aynı hücredekilerden uzaklaş
			var cell := Vector2i(floori(e.position.x / CELL), floori(e.position.y / CELL))
			if grid.has(cell):
				for o in grid[cell]:
					if o == e: continue
					var dd: Vector2 = e.position - o.position
					var l := dd.length()
					var m: float = e.r + o.r
					if l < m and l > 0.01: e.vel += dd / l * (m - l) * 8.0
		e.position += (e.vel + e.kb) * dt
		e.kb *= exp(-dt * 6.0)
		var spins: bool = e.d.get("ai", "") == "spin" or e.d.get("spin", false)
		if spins: e.rotation += dt * (4.0 if not e.boss else 0.35)
		elif e.st == 2 and (e.d.get("ai", "") in ["dash", "ghost", "orbit"] or e.boss): e.rotation = e.lock.angle() + PI / 2.0
		else: e.rotation = lerp_angle(e.rotation, dir.angle() + PI / 2.0, 1.0 - exp(-dt * (6.0 if not e.boss else 2.0)))
		if not spins: # boyuta göre yatış: küçük gemi hızlı ve çok, büyük gemi yavaş ve az yatar
			var av := angle_difference(e.prot, e.rotation) / maxf(dt, 0.001)
			e.prot = e.rotation
			var sk := clampf(20.0 / e.r, 0.3, 1.2)
			e.bank = lerpf(e.bank, clampf(av * 0.3, -1.0, 1.0) * sk, 1.0 - exp(-dt * 6.0 * sk))
			if e.is3d: e.frame = clampi(int(round((e.bank + 1.0) * 3.0)), 0, 6)
			else: e.scale.x = e.base_sc * (1.0 - 0.35 * absf(e.bank)); e.skew = e.bank * 0.2
		if pd.id == "kartal" and e.hitcd < t and dist < e.r * 0.75 + 22.0: # Kartal çarpması
			e.hitcd = t + 0.5; hurt(e, 30.0 * (1.0 + 0.04 * lvl), -dir, 220.0)
		if inv <= 0.0 and dist < e.r * 0.75 + 16.0: hurt_player(e.dmg)
		if not e.boss and dist > 1500.0:
			e.position = pp + (vel.normalized().rotated(randf_range(-0.7, 0.7)) if vel.length() > 50.0 else Vector2.from_angle(randf() * TAU)) * 850.0

func _eb(pos: Vector2, a: float, sp: float, col: Color, r := 7.0, opts := {}) -> EBullet:
	if ebs.size() > 1200: return null # performans sınırı
	sp *= stg.bspd * (1.0 + curse.get("bspd", 0.0))
	# sınıf: hafif (yumuşak ışık), orta (koyu kenarlı), ağır (yıldız dikenli, çift halkalı, dönen ve nabız atan)
	var tier: int = opts.get("tier", 2 if r >= 11.0 or opts.has("split") else (0 if r <= 6.0 else 1))
	var b := EBullet.new(); b.texture = _bullet_tex(col, tier); b.position = pos; b.a = a; b.sp = sp; b.vel = Vector2.from_angle(a) * sp
	b.r = r; b.scale = Vector2.ONE * (r / 7.0); b.heavy = tier == 2; b.rotation = a # doku +x yönüne bakar: mermi gidiş yönünü gösterir
	b.av = opts.get("av", 0.0); b.acc = opts.get("acc", 0.0); b.maxsp = opts.get("max", 400.0); b.split = opts.get("split", 0.0)
	b.dmg = EB_DMG[tier] * dmult * (1.0 + curse.get("edmg", 0.0))
	L_eb.add_child(b); ebs.append(b)
	return b
func _ring(pos: Vector2, n: int, sp: float, off: float, col: Color, r := 7.0, opts := {}) -> void:
	for k in n: _eb(pos, off + k * TAU / n, sp, col, r, opts)
func _fan(pos: Vector2, n: int, spread: float, sp: float, a: float, col: Color, r := 7.0, opts := {}) -> void:
	for k in n: _eb(pos, a + ((k / float(n - 1) - 0.5) * spread if n > 1 else 0.0), sp, col, r, opts)

## Mermi dokusu (HDR renkli), +x gidiş yönü. Ödüller yuvarlak; düşman mermisi asla yuvarlak değil:
## hafif = ince iğne, orta = kapsül, ağır = koyu çekirdekli, çift kenarlı ok ucu (nabız atar).
func _bullet_tex(col: Color, tier: int) -> Texture2D:
	var key := col.to_html() + str(tier)
	if eb_tex.has(key): return eb_tex[key]
	const N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBAH)
	var dark := Color(col.r * 0.08, col.g * 0.08, col.b * 0.08)
	for y in N:
		for x in N:
			var u := (x + 0.5) / (N / 2.0) - 1.0 # -1 (arka) .. 1 (burun)
			var v := (y + 0.5) / (N / 2.0) - 1.0
			var c := Color(0, 0, 0, 0)
			match tier:
				0: # iğne
					var d := sqrt(u * u / 0.9 + v * v / 0.07)
					if d < 0.45: c = Color(1.8, 1.8, 1.8)
					elif d < 0.8: c = col * 1.6
					elif d < 1.0: c = Color(dark, 0.85)
				1: # kapsül: beyaz çekirdek, renkli gövde, koyu kenar
					var d := sqrt(u * u / 0.85 + v * v / 0.2)
					if d < 0.4: c = Color(1.9, 1.9, 1.9)
					elif d < 0.75: c = Color(1.6, 1.6, 1.6).lerp(col * 1.7, smoothstep(0.4, 0.7, d))
					elif d < 1.0: c = Color(dark, 0.95)
				2: # ok ucu (eşkenar dörtgen, burnu sivri): koyu bant + parlak dış kenar
					var d := ((u - 0.1) / 0.9 if u > 0.1 else (0.1 - u) / 1.1) + absf(v) / 0.62
					if d < 0.3: c = Color(2.4, 2.3, 2.2)
					elif d < 0.5: c = col * 2.2
					elif d < 0.62: c = Color(dark, 1.0)
					elif d < 0.8: c = col * 2.8
					elif d < 0.95: c = Color(dark, 0.95)
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	eb_tex[key] = t
	return t

func _outline_for(col: Color) -> ShaderMaterial:
	var key := col.to_html()
	if not out_mat.has(key):
		var m: ShaderMaterial = OUTLINE.duplicate(); m.set_shader_parameter("line_col", col); out_mat[key] = m
	return out_mat[key]

func _update_ebs(dt: float) -> void:
	var pp := player.position
	for b in ebs:
		if b.dead: continue
		b.life -= dt
		if b.acc != 0.0 or b.av != 0.0:
			b.sp = clampf(b.sp + b.acc * dt, 20.0, b.maxsp); b.a += b.av * dt; b.vel = Vector2.from_angle(b.a) * b.sp; b.rotation = b.a
		b.position += b.vel * dt
		if b.heavy: b.self_modulate.v = 1.0 + 0.45 * sin(b.life * 16.0)
		var d2: float = b.position.distance_squared_to(pp)
		if b.split > 0.0 and b.life < 9.0 - b.split:
			_ring(b.position, 10, 120.0, randf() * TAU, Color("ffb0c0"), 6.0)
			b.dead = true; b.queue_free(); continue
		if b.life <= 0.0 or d2 > 1500.0 * 1500.0:
			b.dead = true; b.queue_free(); continue
		if inv <= 0.0 and d2 < pow(b.r + 10.0, 2):
			hurt_player(b.dmg); b.dead = true; b.queue_free()

var boss_t0 := 0.0; var boss_taken := 0.0; var boss_hits := 0 # ölçüm (--log): boss savaşı süresi ve alınan hasar
func hurt_player(d: float) -> void:
	if inv > 0.0 or phase != "play" or (autoplay and not dev.has("mortal")): return
	if dev.has("god"): # test: kaçan ama ölmeyen bot, alınacak hasarı sayar
		if boss_spawned and not won: boss_taken += maxf(1.0, d - st.armor); boss_hits += 1
		inv = 0.6; return
	if randf() * 100.0 < st.dodge:
		inv = 0.25; _float_text(Data.L("ISKA!"), Color(0.6, 2.0, 2.4)); return
	if passives.has("deflektor") and defl_t <= 0.0: # deflektör: darbeyi tamamen engeller
		defl_t = 18.0 - 2.0 * passives.deflektor; inv = 0.5
		Sfx.play("zap", 0.0); _float_text(Data.L("DEFLEKTÖR!"), Color(0.6, 1.6, 2.6)); return
	if shield_ready: # Kartal: enerji kalkanı darbeyi emer
		shield_ready = false; shield_t = 0.0; inv = 0.6
		if mast.has("shield_blast"): _blast(player.position, 170.0 * st.area, 45.0 * st.might * (1.0 + 0.05 * lvl))
		Sfx.play("zap", 0.0); screen_flash(Color(0.3, 0.6, 1.0), 0.25, 0.3); _float_text(Data.L("KALKAN!"), Color(0.6, 1.4, 2.6)); return
	hp -= maxf(1.0, d - st.armor); inv = 0.6; shake = 9.0
	if boss_spawned: boss_hit = true
	Sfx.play("hurt"); hurt_flash = 1.0; hitstop = 0.05; ca_pulse += 0.6
	if hp <= 0.0:
		if pd.id == "anka" and not revived: # Anka: küllerinden doğuş
			revived = true; hp = max_hp * (0.6 + mast.get("revive", 0.0)); inv = 2.5
			_blast(player.position, 420.0 * (1.4 if mast.has("revive_blast") else 1.0), 250.0 * (2.0 if mast.has("revive_blast") else 1.0))
			for b in ebs: b.dead = true; b.queue_free()
			screen_flash(Color(1.0, 0.5, 0.2), 0.9, 1.2); banner(Data.L("KÜLLERİNDEN DOĞDU!"), "", Color(2.6, 1.2, 0.5)); return
		_die()

## Test pilotu: hedef yöne giderken yakındaki mermi ve düşmanlardan uzaklaşır
func _bot_dodge(desired: Vector2, spd: float) -> Vector2:
	var push := Vector2.ZERO
	for b in ebs:
		if not is_instance_valid(b) or b.dead: continue
		var dd: Vector2 = player.position - b.position
		var l := dd.length()
		if l < 150.0 and l > 0.1: push += dd / l * (150.0 - l) / 150.0 * 3.0
	for h in hazs: # işaretli tehlike alanları
		var dd: Vector2 = player.position - (h.pos if h.has("pos") else h.a)
		if h.has("dir"): dd = dd - h.dir * dd.dot(h.dir)
		var l := dd.length(); var rr: float = h.get("r", h.get("w", 40.0)) + 60.0
		if l < rr and l > 0.1: push += dd / l * (rr - l) / rr * 4.0
	for e in near(player.position, 140.0):
		var dd: Vector2 = player.position - e.position
		var l := dd.length()
		if l < 140.0 and l > 0.1: push += dd / l * (140.0 - l) / 140.0 * 2.0
	return (desired.normalized() * 0.6 + push).normalized() * spd

## Test: N pilot puanını dallara sırayla (dengeli) dağıtır
func _auto_tree(n: int) -> Array:
	var order := []
	for i in 12:
		for br in Data.TREE_BRANCHES: order.append(Data.L("%s_m%d") % [br.key, i])
	for i in 10:
		for br in Data.TREE_BRANCHES:
			order.append(Data.L("%s_a%d") % [br.key, i]); order.append(Data.L("%s_b%d") % [br.key, i])
	return order.slice(0, n)

## Uçak yetenekleri (her karede)
func _dash_cd() -> float: return 2.5 - mast.get("dash_cd", 0.0)
func _shield_cd() -> float: return 7.0 - mast.get("shield_cd", 0.0)
func _salvo_cd() -> float: return 5.0 - mast.get("salvo_cd", 0.0)

func _trait_dash(dt: float) -> void:
	dash_cd = maxf(0.0, dash_cd - dt)
	if pd.id == "simsek":
		if dash_t > 0.0:
			dash_t -= dt
			player.position += dash_dir * 1800.0 * dt
			for e in near(player.position, 60.0):
				if not e.dead and e.hitcd < t and e.position.distance_to(player.position) < e.r + 30.0:
					e.hitcd = t + 0.4; hurt(e, 35.0 * (1.0 + 0.04 * lvl) * (1.0 + mast.get("dash_dmg", 0.0)), dash_dir, 250.0)
			if randf() < 0.8: _puff(player.position, Color(2.0, 1.8, 0.5, 0.6), 0.6, Vector2.ZERO, 0.3)
		elif dash_cd <= 0.0 and not autoplay and Input.is_action_just_pressed("dash"):
			var m := (Input.get_vector("left", "right", "up", "down") * 100.0) if Data.pad else get_global_mouse_position() - player.position
			dash_dir = m.normalized() if m.length() > 20.0 else _fwd()
			dash_t = 0.15; dash_cd = _dash_cd(); inv = maxf(inv, 0.4); Sfx.play("dash", 0.0)
	elif pd.id == "kartal" and not shield_ready:
		shield_t += dt
		if shield_t >= _shield_cd(): shield_ready = true
	elif pd.id == "dogan":
		salvo_t -= dt
		if salvo_t <= 0.0:
			salvo_t = _salvo_cd()
			var tg = target_for(player.position, 900.0)
			if tg:
				var ns := 4 + int(mast.get("salvo_n", 0))
				for i in ns:
					var m := _new_shot("missile", "p_missile", player.position, Vector2.from_angle(_fwd().angle() + (i - (ns - 1) / 2.0) * 0.7) * 260.0, 30.0 * (1.0 + 0.05 * lvl), 3.0)
					m.rad = 60.0 * st.area; m.target = tg; m.scale = Vector2.ONE * 1.3
				Sfx.play("missile", 0.0)

## Sonsuz mod kozmetik jetonu: süre arttıkça renk yükselir (Data.cos_color); uçulan uçağa yazılır, hemen kaydedilir
func _cos_token() -> void:
	cos_next += Data.COS_EVERY
	var c: String = Data.cos_color(t)
	cos_got.append(c); Save.add_token(pd.id, c)
	if dev.has("log"): print("JETON t=%.0f renk=%s toplam=%d" % [t, c, Save.tok(pd.id, c)])
	var info: Array = Data.COS_COLORS[c]
	Sfx.play("chest", 0.0)
	_float_text(Data.L("%s JETON!") % Data.L(info[1]), Color(info[2].r * 2.0, info[2].g * 2.0, info[2].b * 2.0))
	radio("cmd", Data.L("Hangar ekibi bir %s kapsül jetonu ayırdı, Şahin-1. Dayanmaya devam.") % Data.L(info[1]).to_lower(), 0)

# ================= Ortam tehlikeleri =================
func _update_hazards(dt: float) -> void:
	if won: return
	haz_t -= dt
	if haz_t <= 0.0:
		haz_t = haz.cd * randf_range(0.85, 1.15) * (0.8 if boss_spawned else 1.0)
		if not haz_said:
			haz_said = true; radio("cmd", haz.say, 1); banner(Data.L("ÇEVRE TEHLİKESİ"), Data.L(haz.name), Color(2.6, 1.2, 0.4))
		_haz_wave()
	if wind_t > 0.0:
		wind_t -= dt
		if wind_t < 0.6: wind *= maxf(0.0, 1.0 - dt / maxf(wind_t, 0.05)) # rüzgâr yavaşça diner
		if wind_fx: wind_fx.position = cam.get_screen_center_position()
		if wind_t <= 0.0:
			wind = Vector2.ZERO
			if wind_fx: wind_fx.emitting = false
	for h in hazs:
		h.life -= dt
		var k: float = clampf(1.0 - h.life / h.tot, 0.0, 1.0)
		if h.node is Sprite2D:
			h.node.scale = Vector2.ONE * h.r / 62.0 * lerpf(1.6, 1.0, k); h.node.modulate.a = 0.35 + 0.55 * k
		elif h.node is Line2D:
			h.node.width = lerpf(2.0, h.w * 2.0, k * k); h.node.default_color.a = 0.25 + 0.5 * k
		if h.life <= 0.0:
			_haz_hit(h); h.node.queue_free()
	hazs = hazs.filter(func(h): return h.life > 0.0)

## Bir tehlike dalgası: oyuncunun çevresine / gittiği yere işaretler koyar
func _haz_wave() -> void:
	var pp := player.position + vel * 0.6 # durana değil, gittiği yere
	match haz.k:
		"ice", "bolt", "lava":
			var r: float = {"ice": 62.0, "bolt": 85.0, "lava": 100.0}[haz.k]
			var life: float = {"ice": 1.0, "bolt": 1.1, "lava": 1.3}[haz.k]
			var col: Color = {"ice": Color(0.6, 1.4, 2.6), "bolt": Color(1.8, 1.8, 2.8), "lava": Color(2.6, 0.9, 0.2)}[haz.k]
			for i in haz.n:
				var off := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(120.0, 320.0)
				_haz_mark({"k": haz.k, "pos": pp + off, "r": r, "life": life + i * 0.25, "col": col})
		"arty": # topçu hattı oyuncuya doğru yürür
			var dir := Vector2.from_angle(randf() * TAU)
			for i in haz.n:
				_haz_mark({"k": "arty", "pos": pp - dir * (360.0 - i * 150.0), "r": 80.0, "life": 1.0 + i * 0.32, "col": Color(2.6, 0.5, 0.3)})
		"debris", "beam":
			for i in haz.n:
				var dir := Vector2.from_angle(randf() * TAU)
				var through := pp + Vector2(randf_range(-80, 80), randf_range(-80, 80))
				var a := through - dir * 900.0
				var w: float = 22.0 if haz.k == "debris" else 30.0
				var ln := Line2D.new(); ln.points = PackedVector2Array([a, a + dir * 1800.0]); ln.width = 2.0; ln.material = ADD
				ln.default_color = Color(2.6, 0.3, 0.3, 0.3) if haz.k == "debris" else Color(1.6, 0.5, 2.6, 0.3)
				L_fx.add_child(ln)
				hazs.append({"k": haz.k, "a": a, "dir": dir, "w": w, "life": 1.1 + i * 0.4, "tot": 1.1 + i * 0.4, "node": ln})
		"wind":
			var dir := Vector2.from_angle(randf() * TAU)
			wind = dir * (105.0 + 4.0 * stage); wind_t = 2.8 # oyuncu hızının ~%50'si: karşı uçunca yenilir
			if wind_fx == null:
				wind_fx = CPUParticles2D.new(); wind_fx.texture = T_GLOW; wind_fx.material = ADD; wind_fx.amount = 90; wind_fx.lifetime = 1.1
				wind_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE; wind_fx.emission_rect_extents = Vector2(900, 900)
				wind_fx.spread = 4.0; wind_fx.gravity = Vector2.ZERO; wind_fx.initial_velocity_min = 900.0; wind_fx.initial_velocity_max = 1300.0
				wind_fx.particle_flag_align_y = true; wind_fx.scale_amount_min = 0.05; wind_fx.scale_amount_max = 0.09
				wind_fx.local_coords = false; L_fx.add_child(wind_fx)
			wind_fx.direction = dir; wind_fx.color = Color(0.9, 0.75, 0.5, 0.35) if stage == 9 else Color(0.85, 0.9, 1.0, 0.25)
			wind_fx.position = cam.get_screen_center_position(); wind_fx.emitting = true; Sfx.play("dash", 0.0)
			_float_text(Data.L("RÜZGÂR!"), Color(1.6, 1.8, 2.4))

func _haz_mark(h: Dictionary) -> void:
	var r := Sprite2D.new(); r.texture = Data.tex("ring"); r.material = ADD; r.position = h.pos; r.modulate = Color(h.col, 0.4); L_fx.add_child(r)
	var core := Sprite2D.new(); core.texture = T_GLOW; core.material = ADD; core.modulate = Color(h.col, 0.12); core.scale = Vector2.ONE * 1.4; r.add_child(core)
	h.node = r; h.tot = h.life
	hazs.append(h)

func _haz_hit(h: Dictionary) -> void:
	var d: float = haz.dmg * dmult
	var edmg := 40.0 * hmult # tehlikeler düşmanlara da vurur (sürüyü işarete çek)
	if h.has("pos"):
		var pos: Vector2 = h.pos
		if player.position.distance_to(pos) < h.r + 10.0: hurt_player(d)
		if h.k != "ice":
			for e in near(pos, h.r + 50.0):
				if not e.dead and e.position.distance_to(pos) < h.r + e.r: hurt(e, edmg, (e.position - pos).normalized(), 120.0, false)
		match h.k:
			"bolt":
				var pts := [pos + Vector2(randf_range(-60, 60), -700)]
				for i in 6: pts.append(pts[-1].lerp(pos, 0.35) + Vector2(randf_range(-40, 40), 0))
				pts.append(pos); _bolt(pts); screen_flash(Color(0.8, 0.85, 1.0), 0.25, 0.25); Sfx.play("zap", 0.0); explosion(pos, Color(0.6, 0.7, 1.0), 1.2)
			"lava":
				explosion(pos, Color(1.0, 0.4, 0.1), 2.2); _ring(pos, 10, 170.0, randf() * TAU, Color("ff7a3c"), 9.0); shake = maxf(shake, 7.0)
			"arty":
				explosion(pos, Color(1.0, 0.5, 0.25), 1.8); shake = maxf(shake, 5.0)
			"ice":
				_puff(pos, Color(0.85, 0.95, 1.0, 0.8), 1.4, Vector2.ZERO, 0.5); _spray(pos, 1.0, Color(0.9, 0.97, 1.0), Color(0.5, 0.7, 0.9), 300.0, 14, false); Sfx.play("hit", 0.0)
	else:
		var a: Vector2 = h.a; var dir: Vector2 = h.dir
		if h.k == "debris": # ağır parça çizgi boyunca uçar
			var b := _eb(a, dir.angle(), 640.0, Color("c8c4d8"), 16.0, {"tier": 2})
			if b: b.dmg = d; b.life = 4.0
		else: # ışın: anında vurur
			var rel := player.position - a
			var off := (rel - dir * rel.dot(dir)).length()
			if off < h.w + 8.0 and rel.dot(dir) > 0.0: hurt_player(d)
			_beam_fx(a, dir, 1800.0, h.w)
			Sfx.play("laser", 0.0)

func _beam_fx(a: Vector2, dir: Vector2, ln_len: float, w: float) -> void:
	var ln := Line2D.new(); ln.points = PackedVector2Array([a, a + dir * ln_len]); ln.width = w * 2.0; ln.material = ADD
	ln.default_color = Color(2.2, 0.8, 2.8, 0.85); L_fx.add_child(ln)
	var tw := ln.create_tween().set_parallel(); tw.tween_property(ln, "width", 2.0, 0.35); tw.tween_property(ln, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(ln.queue_free)

# ================= Bosslar =================
func _boss_warning() -> void:
	warn_fx = WarnFX.new(); warn_fx.set_anchors_preset(Control.PRESET_FULL_RECT); warn_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(warn_fx); warn_last = 0
	var w := UI.lbl(Data.L("WARNING"), 96, Color(2.2, 0.22, 0.16), true, HORIZONTAL_ALIGNMENT_CENTER)
	w.add_theme_font_override("font", Data.font_warn); w.add_theme_constant_override("outline_size", 10); w.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	w.set_anchors_and_offsets_preset(Control.PRESET_CENTER); w.offset_left = -600; w.offset_right = 600; w.offset_top = -92; w.offset_bottom = 20
	warn_fx.add_child(w)
	var sub := UI.lbl(Data.L("VAHAR KOMUTA GEMİSİ YAKLAŞIYOR  //  ") + Data.L(Data.BOSSES[stg.boss].name), 20, Color(1.9, 1.4, 0.4), true, HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER); sub.offset_left = -600; sub.offset_right = 600; sub.offset_top = 26; sub.offset_bottom = 60
	warn_fx.add_child(sub)
	warn_num = UI.lbl("", 120, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	warn_num.add_theme_font_override("font", Data.font_warn); warn_num.add_theme_constant_override("outline_size", 12); warn_num.add_theme_color_override("font_outline_color", Color(0.4, 0, 0, 0.95))
	warn_num.set_anchors_and_offsets_preset(Control.PRESET_CENTER); warn_num.offset_left = -200; warn_num.offset_right = 200; warn_num.offset_top = 110; warn_num.offset_bottom = 260
	warn_num.pivot_offset = Vector2(200, 75)
	warn_fx.add_child(warn_num)
	var blink := w.create_tween().set_loops() # yanıp sönen başlık
	blink.tween_property(w, "modulate:a", 0.35, 0.25); blink.tween_property(w, "modulate:a", 1.0, 0.25)
	Sfx.play_music("")

func _update_warning() -> void:
	if warn_fx == null: return
	var left := ceili(boss_t - t)
	if left >= 1 and left != warn_last:
		warn_last = left; warn_num.text = str(left); Sfx.play("warn", 0.0); shake = maxf(shake, 4.0)
		warn_num.scale = Vector2.ONE * 1.6
		warn_num.create_tween().tween_property(warn_num, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if boss_spawned:
		var fx := warn_fx; warn_fx = null
		var tw := fx.create_tween(); tw.tween_property(fx, "modulate:a", 0.0, 0.4); tw.tween_callback(fx.queue_free)

func _spawn_boss(id: String) -> void:
	var d: Dictionary = Data.BOSSES[id]
	var be := make_enemy(id, d, player.position + Vector2.from_angle(randf() * TAU) * 520.0, true)
	be.tm = 1.6; be.tm2 = 1.6 # iniş bitene kadar ateş etmez
	var bsc := be.scale; be.scale = bsc * 2.4; be.modulate.a = 0.0 # yüksekten iner: büyükten küçülerek, gölgeden belirerek
	var bt := be.create_tween().set_parallel()
	bt.tween_property(be, "scale", bsc, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bt.tween_property(be, "modulate:a", 1.0, 0.9)
	bt.chain().tween_callback(func(): if is_instance_valid(be): shake = maxf(shake, 10.0); explosion(be.position, Color(1.0, 0.6, 0.3), 0.8))
	boss_t0 = t
	boss_box.visible = true; boss_lbl.text = Data.L(d.name); boss_lbl.add_theme_color_override("font_color", d.col)
	banner(Data.L(d.name), Data.L(Data.STAGES[stage].sub), Color(2.4, 0.6, 0.5))
	Sfx.play("warn", 0.0); Sfx.play_music("music_final" if stg.boss in ["sefine", "varek"] else "music_boss")
	var bl: Array = [Data.L(d.line)]
	for s in Data.LINES.boss.get(id, []): if not s.begins_with("!"): bl.append(s)
	radio("varek" if id == "varek" else "vahar", bl[Save.pick_line("boss_" + id, bl.size())], 2, "" if id == "varek" else Data.L(d.name))

## Boss saldırıları desen kütüphanesinden gelir (data.gd -> BOSSES.pats). 7 sn'de bir desen değişir.
## Bölüm ilerledikçe desenler yoğunlaşır. 2. FAZ (canın %50'si): 1.2 sn kükreme (ateş yok, ekrandaki mermiler silinir,
## oyuncu %15 onarılır), sonra saldırılar %25 sık, hareket %15 hızlı; canı %25'in altında %43 sık (eski öfke).
func _boss_ai(e: Enemy, dir: Vector2, dist: float) -> void:
	var d: Dictionary = e.d
	var rage := 0.7 if e.hp < e.maxhp * 0.25 else (0.8 if e.hp < e.maxhp * 0.5 else 1.0)
	if rage < 1.0 and not e.has_meta("raged"): # 2. faza geçiş: bir kez
		e.set_meta("raged", true)
		_boss_phase2(e)
		for s in Data.LINES.boss.get(e.kind, []):
			if s.begins_with("!"): radio("varek" if e.kind == "varek" else "vahar", s.substr(1), 2, "" if e.kind == "varek" else Data.L(d.name))
		return
	var pats: Array = d.pats
	var pat: String = pats[int(e.t / 7.0) % pats.size()]
	var lv := 1.0 + stage * 0.08
	var c: Color = d.col
	var spd0: float = e.spd
	if rage < 1.0: e.spd = spd0 * 1.15
	match d.move:
		"chase": e.vel = dir * e.spd if dist > 230.0 else dir.orthogonal() * e.spd
		"hover": e.vel = dir * e.spd if dist > 320.0 else dir.orthogonal() * e.spd * 0.4
		_: e.vel = dir.orthogonal() * e.spd + dir * (dist - 300.0) * 0.6
	if pat != "dash" and e.st != 0: e.st = 0
	var kind := pat.get_slice(":", 0)
	match kind:
		"fan":
			if e.tm <= 0.0: e.tm = 0.75 * rage; _fan(e.position, int(7 + 2 * lv), 1.05, 235.0, dir.angle(), c, 8.0)
		"spiral":
			if e.tm <= 0.0:
				e.tm = 0.055 * rage; e.ang += 0.22
				for k in 2: _eb(e.position, e.ang + k * PI, 185.0, c.lightened(0.3))
		"ring":
			if e.tm <= 0.0: e.tm = 0.65 * rage; _ring(e.position, int(14 + 4 * lv), 155.0, randf() * TAU, c, 7.0)
		"curve":
			if e.tm <= 0.0: e.tm = 0.5 * rage; e.flip = -e.flip; _ring(e.position, int(14 + 3 * lv), 140.0, e.t, c.lightened(0.35), 7.0, {"av": 0.55 * e.flip})
		"dash":
			if e.st == 2:
				e.vel = e.lock * 640.0
				if e.tm2 <= 0.0: e.tm2 = 0.05; _eb(e.position, e.lock.angle() + PI + randf_range(-0.6, 0.6), 90.0, c, 6.0)
				if e.tm <= 0.0: e.st = 0; e.tm = 0.5
			elif e.st == 1:
				e.vel = e.vel.lerp(Vector2.ZERO, 0.1)
				e.modulate = Color(3, 1.5, 3) if fmod(e.t, 0.12) < 0.06 else Color.WHITE
				if e.tm <= 0.0: e.st = 2; e.tm = 0.75; e.lock = dir; Sfx.play("dash")
			elif e.tm <= 0.0: e.st = 1; e.tm = 0.6 * rage
		"summon":
			if e.tm <= 0.0:
				e.tm = 3.2 * rage
				var mk := pat.get_slice(":", 1)
				for k in 6: make_enemy(mk, Data.ENEMIES[mk], e.position + Vector2.from_angle(k * TAU / 6.0) * 150.0)
			if e.tm2 <= 0.0: e.tm2 = 0.9 * rage; _fan(e.position, 3, 0.3, 240.0, dir.angle(), Color(0.95, 0.97, 1.0), 11.0)
		"pull":
			pull = -dir * (110.0 + 15.0 * lv)
			beam.visible = true; beam.points = PackedVector2Array([e.position, player.position])
			if e.tm <= 0.0: e.tm = 0.55 * rage; _ring(e.position, int(10 + 2 * lv), 120.0, randf() * TAU, c, 7.0)
		"mines":
			if e.tm <= 0.0:
				e.tm = 0.9 * rage
				for k in 3: _eb(e.position, dir.angle() + randf_range(-1.2, 1.2), 60.0, c, 12.0, {"split": 1.6})
		"quad":
			if e.tm <= 0.0:
				e.tm = 0.05 * rage; e.ang += 0.13
				for k in 4: _eb(e.position, e.ang + k * PI / 2.0, 70.0, c.lightened(0.2), 7.0, {"acc": 170.0, "max": 300.0})
		"split":
			if e.tm <= 0.0: e.tm = 1.25 * rage; _ring(e.position, 8, 160.0, randf() * TAU, c, 12.0, {"split": 1.1})
		"walls": # oyuncuya doğru ilerleyen, tek boşluklu mermi duvarı
			if e.tm <= 0.0:
				e.tm = 1.35 * rage
				var gap := randi_range(-8, 8)
				var base := e.position + dir * 80.0
				for i in range(-13, 14):
					if absi(i - gap) > 1: _eb(base + dir.orthogonal() * i * 30.0, dir.angle(), 150.0, c, 6.0)
		"stream": # hızlı nişanlı mermi seli, aralıklı
			if e.tm <= 0.0:
				e.tm = 0.075 * rage
				if fmod(e.t, 1.6) < 0.9: _eb(e.position, dir.angle() + randf_range(-0.06, 0.06), 330.0, c, 6.0)
	if dist > 520.0: e.vel = dir * maxf(e.spd, pd.speed * st.speed * 0.95) # kaçan oyuncuya yetiş
	e.spd = spd0

func _boss_phase2(e: Enemy) -> void:
	e.tm = 1.2; e.tm2 = 1.2; e.st = 0 # kükreme: kısa nefes payı
	for b in ebs: b.dead = true; b.queue_free()
	var heal := max_hp * 0.15; hp = minf(max_hp, hp + heal)
	_float_text(Data.L("2. FAZ") + "  +%d " % int(heal) + Data.L("CAN"), Color(2.4, 0.6, 0.4))
	shake = maxf(shake, 14.0); screen_flash(Color(1.0, 0.25, 0.15), 0.35, 0.7); ca_pulse = 1.2; Sfx.play("warn", 0.0)
	explosion(e.position, e.d.col, 2.6)
	var tw := e.create_tween().set_loops() # gövde öfkeyle kızıl nabız atar
	tw.tween_property(e, "self_modulate", Color(1.8, 0.7, 0.6), 0.35); tw.tween_property(e, "self_modulate", Color.WHITE, 0.35)

func _boss_killed(e: Enemy) -> void:
	bosses.erase(e); bosses_killed += 1; score += 5000 * (stage + 1)
	if dev.has("log"): print("BOSS bolum=%d sure=%.1f alinan=%.0f darbe=%d maxcan=%.0f etkin_can=%.0f" % [stage + 1, t - boss_t0, boss_taken, boss_hits, max_hp, e.maxhp])
	won = true
	shake = 22.0; screen_flash(Color(1.0, 0.8, 0.6), 0.5, 1.2); Sfx.play("bigboom", 0.0); hitstop = 0.18; ca_pulse = 2.0
	var bw := wreck_from(e, Vector2.ZERO, 4.0, 2.6); bw.spin = 1.1 # dev gövde zincirleme patlamalarla dönerek düşer
	var bpos := e.position
	var bcol: Color = e.d.col
	for k in 8:
		get_tree().create_timer(0.15 * k).timeout.connect(func(): explosion(bpos + Vector2(randf_range(-100, 100), randf_range(-80, 80)), bcol, 2.8))
	for k in 30: _drop_gem(e.position + Vector2(randf_range(-90, 90), randf_range(-90, 90)), 5)
	for o in gems: o.mag = true
	boss_box.visible = false
	Sfx.play_music(_battle_music())
	banner(Data.L(e.d.name) + Data.L(" DÜŞTÜ!"), Data.L("BÖLÜM %d TAMAMLANDI") % (stage + 1), Color(0.6, 2.6, 1.0))
	var bk := _line("boss_kill"); radio(bk[0], bk[1], 2)
	clear_c = bpos; clear_r = 0.0 # şok dalgası: boss noktasından yayılıp sürüyü zincirleme patlatır
	var ring := Sprite2D.new(); ring.texture = Data.tex("ring"); ring.material = ADD; ring.position = bpos; ring.modulate = Color(2.0, 1.6, 1.0, 0.9); L_fx.add_child(ring)
	var rt := ring.create_tween().set_parallel()
	rt.tween_property(ring, "scale", Vector2.ONE * 30.0, 1.4).from(Vector2.ONE * 0.5); rt.tween_property(ring, "modulate:a", 0.0, 1.4)
	rt.chain().tween_callback(ring.queue_free)
	get_tree().create_timer(2.2, false).timeout.connect(_next_wave if endless else _win_screen)

func _update_clear(dt: float) -> void:
	clear_r += 1400.0 * dt
	for o in enemies:
		if not o.dead and not o.boss and o.position.distance_squared_to(clear_c) < clear_r * clear_r:
			o.dead = true; explosion(o.position, o.d.col, 0.6 + o.r / 40.0); _drop_gem(o.position, o.xpv); o.queue_free()
	for b in ebs:
		if not b.dead and b.position.distance_squared_to(clear_c) < clear_r * clear_r: b.dead = true; b.queue_free()
	for o in gems: o.mag = true
	if clear_r > 2400.0: clear_r = -1.0

## Zafer gösterisi: duman izli bir hava gösterisi manevrası, ardından ses duvarı ve haritadan çıkış
const OUTRO_D := {"eight": 3.6, "roll": 2.6, "spiral": 3.2}
func _win_screen() -> void:
	if phase != "play": return
	phase = "outro"; tt = 0.0
	outro_m = str(dev.get("outro", ["eight", "eight", "roll", "spiral"].pick_random()))
	outro_c = player.position; outro_head = vel.angle() if vel.length() > 20.0 else -PI / 2.0
	Sfx.play("engine", 0.0)

## Manevra yolu (kamera merkezine göre), u: 0..1
func _outro_path(u: float) -> Vector2:
	var s := TAU * u
	match outro_m:
		"eight": return Vector2(170.0 * sin(2.0 * s), -190.0 * sin(s)) # dikey 8
		"roll": return Vector2(70.0 * sin(s), -260.0 * u * u) # yılankavi tırmanışta iki tono
		_: # sarmal tırmanış: daireler çizerek kameraya yaklaşır
			var a := s * 1.5
			return Vector2(150.0 * sin(a), -150.0 * (1.0 - cos(a)) - 90.0 * u)

func _update_outro(dt: float) -> void:
	tt += dt
	_update_gems(dt); gems = gems.filter(func(g): return not g.dead) # toplanan kristaller listeden çıksın
	var d: float = OUTRO_D[outro_m]
	var sc := 1.0
	if tt < d:
		var p := outro_c + _outro_path(tt / d)
		var nv := (p - player.position) / maxf(dt, 0.001)
		if nv.length() > 30.0:
			var h := nv.angle()
			var w := angle_difference(outro_head, h) / maxf(dt, 0.001); outro_head = h
			bank = lerpf(bank, clampf(atan(nv.length() * w / 900.0) / deg_to_rad(55.0), -1.0, 1.0), 1.0 - exp(-dt * 10.0))
			player.rotation = lerp_angle(player.rotation, h + PI / 2.0, 1.0 - exp(-dt * 18.0))
		vel = nv; player.position = p; throttle = 0.75
		if outro_m == "roll": bank = sin(tt / d * TAU * 2.0)
		if outro_m == "spiral": sc = 1.0 + 0.4 * tt / d
		_smoke_trail()
	else: # ses duvarı: buhar halkası, art yakıcı ve haritanın dışına fırlayış
		var x := tt - d
		if x - dt <= 0.0:
			Sfx.play("sonicboom", 0.0); Sfx.play("afterburner", 0.0); shake = 8.0; ca_pulse = 1.2
			var r := Sprite2D.new(); r.texture = Data.tex("ring"); r.material = ADD; r.position = player.position; r.modulate = Color(1.6, 1.7, 1.9, 0.9); L_fx.add_child(r)
			var tw := r.create_tween().set_parallel()
			tw.tween_property(r, "scale", Vector2.ONE * 4.0, 0.6).from(Vector2.ONE * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw.tween_property(r, "modulate:a", 0.0, 0.6); tw.chain().tween_callback(r.queue_free)
		player.rotation = lerp_angle(player.rotation, 0.0, 1.0 - exp(-dt * 6.0))
		vel = vel.lerp(Vector2(0, -400.0 - 2600.0 * x * x), 1.0 - exp(-dt * 5.0))
		player.position += vel * dt
		bank = lerpf(bank, 0.0, 1.0 - exp(-dt * 6.0)); throttle = 1.0
		sc = (1.4 if outro_m == "spiral" else 1.0) + 0.35 * smoothstep(0.0, 1.0, x)
		if x < 0.6: _smoke_trail()
		if x > 1.6: _results(true)
	player.scale = Vector2.ONE * PS * psc * sc

## Kanat uçlarından gösteri dumanı (uçağın kendi rengi + beyaz)
func _smoke_trail() -> void:
	var side := Vector2.from_angle(player.rotation) * 26.0 * player.scale.y / psc
	_puff(player.position + side, Color(pd.color.lightened(0.35), 0.5), 0.32, Vector2(randf_range(-5, 5), randf_range(-5, 5)), 2.4)
	_puff(player.position - side, Color(0.92, 0.93, 0.96, 0.5), 0.32, Vector2(randf_range(-5, 5), randf_range(-5, 5)), 2.4)

# ================= Harekât (3 bölüm, build taşınır) =================
func _carry_state() -> Dictionary:
	return {"weapons": weapons.duplicate(true), "passives": passives.duplicate(), "lvl": lvl, "xp": xp, "hp": hp / max_hp,
		"rerolls": rerolls, "bans": bans, "banned": banned.duplicate(), "curse": curse.duplicate(),
		"pending": pending_lv, "chest_picks": chest_picks, "offered": offered.duplicate(), "tac": tac.duplicate()} # gösteride toplanan kristallerin seviyeleri kaybolmasın

func _apply_carry() -> void:
	weapons = carry.weapons.duplicate(true); passives = carry.passives.duplicate()
	lvl = carry.lvl; xp = carry.xp; pending_lv = carry.get("pending", 0); chest_picks = carry.get("chest_picks", 0); rerolls = carry.rerolls; bans = carry.bans; banned = carry.banned.duplicate(); curse = carry.curse.duplicate()
	offered = carry.get("offered", {}).duplicate(); tac = carry.get("tac", {}).duplicate()
	_recalc()
	for id in weapons:
		if id != "sig": _weapon_changed(id)
	hp = max_hp * minf(1.0, carry.hp + Data.OP_HEAL)

## Harekât içinde sonraki bölüm mü? (son bölümde harekât biter)
func _op_continues() -> bool: return not endless and op_pos < Data.OP_LEN - 1 and stage < Data.STAGES.size() - 1

# ================= Sonsuz mod =================
## Dalga verisi: 15 bölgeyi sırayla döner; her tam turda düşman canı x1.5, hasarı x1.25
func _wave_data() -> void:
	stage = wave % Data.STAGES.size(); stg = Data.STAGES[stage]
	boss_t = wave_t0 + ENDLESS_WAVE
	var loop := int(wave / float(Data.STAGES.size()))
	# baskı: oyuncu ~10. dakikada silahlarını tamamlar, sonrası sadece düşman büyür. Her dalga can x1.16, hasar x1.10
	hmult = Data.enemy_hp_mult(stage + 1) * pow(1.5, loop) * pow(1.16, wave); dmult = Data.enemy_dmg_mult(stage + 1) * pow(1.25, loop) * pow(1.10, wave)

func _next_wave() -> void:
	if phase != "play": return
	wave += 1; wave_t0 = t
	_wave_data()
	swarms_done = 0; boss_spawned = false; warned = false; won = false
	radio_sched.clear(); elite_times.clear(); _plan_radio()
	hp = minf(max_hp, hp + max_hp * 0.3)
	screen_flash(Color(0.85, 0.9, 1.0), 0.7, 1.4) # bulutların içinden yeni bölgeye geçiş
	sky_mat.set_shader_parameter("biome", stg.biome); sky_mat.set_shader_parameter("tint", Vector3(stg.tint.r, stg.tint.g, stg.tint.b))
	if bg3: _bg_world(stg.biome)
	var gr: Array = Data.GRADE[stg.biome]
	post_mat.set_shader_parameter("shadow_col", gr[0]); post_mat.set_shader_parameter("high_col", gr[1])
	post_mat.set_shader_parameter("sat", gr[2]); post_mat.set_shader_parameter("contrast", gr[3])
	cloud_mat.set_shader_parameter("amount", gr[4]); cloud_mat.set_shader_parameter("col", gr[5])
	var loop := int(wave / float(Data.STAGES.size()))
	banner(Data.L("DALGA %d") % (wave + 1), Data.L(stg.sub) + (Data.L("  •  TUR %d: düşmanlar güçlendi") % (loop + 1) if loop > 0 and stage == 0 else ""), Color(1.9, 1.4, 0.4))
	var l := _line("cmd"); radio(l[0], l[1], 1)

func _endless_results() -> void:
	get_tree().paused = true
	Sfx.play_music(""); Sfx.play("gameover", 0.0)
	var gained := int((kills + int(t / 2.0) + lvl * 5) * (1.0 + 0.15 * wave))
	Save.xp += gained
	var rank := Save.add_endless({"wave": wave + 1, "time": int(t), "kills": kills, "score": score, "plane": Data.L(pd.name), "lvl": lvl, "date": Time.get_date_string_from_system()})
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); ui.add_child(root); overlay = root
	var dim := ColorRect.new(); dim.color = Color(0, 0.02, 0.06, 0.82); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.set_anchors_preset(Control.PRESET_FULL_RECT); v.add_theme_constant_override("separation", 12); root.add_child(v)
	v.add_child(UI.lbl(Data.L("SONSUZ MOD"), 64, Color(1.9, 1.4, 0.4), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl(Data.L("Şahin-1, %d. dalgada %s üzerinde düştü.") % [wave + 1, Data.L(stg.sub)], 18, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	var g := GridContainer.new(); g.columns = 5; g.add_theme_constant_override("h_separation", 56)
	var gc := CenterContainer.new(); gc.add_child(g); v.add_child(gc)
	for st2 in [[Data.L("DAYANMA"), UI.mmss(t)], [Data.L("DALGA"), str(wave + 1)], [Data.L("DÜŞÜRÜLEN"), str(kills)], [Data.L("SEVİYE"), str(lvl)], [Data.L("SKOR"), str(score)]]:
		var c := VBoxContainer.new(); c.add_child(UI.lbl(st2[0], 14, UI.DIM, true, HORIZONTAL_ALIGNMENT_CENTER)); c.add_child(UI.lbl(st2[1], 38, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)); g.add_child(c)
	if rank == 1: v.add_child(UI.lbl(Data.L("★ YENİ REKOR! ★"), 30, Color(2.6, 2.1, 0.6), true, HORIZONTAL_ALIGNMENT_CENTER))
	elif not Save.endless.is_empty():
		var best: Dictionary = Save.endless[0]
		v.add_child(UI.lbl(Data.L("Rekorun: %s  •  Dalga %d  •  Bu uçuş %d. sırada") % [UI.mmss(best.time), int(best.wave), rank] if rank > 0 else Data.L("Rekorun: %s  •  Dalga %d") % [UI.mmss(best.time), int(best.wave)], 20, UI.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl(Data.L("+%d rütbe XP   •   Sonsuz mod pilot puanı vermez, sadece rekor ve rütbe") % gained, 16, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	if not cos_got.is_empty(): # kazanılan kozmetik jetonları
		var parts := []
		for c in ["g", "o", "r"]:
			var n := cos_got.count(c)
			if n > 0: parts.append("%d %s" % [n, Data.L(Data.COS_COLORS[c][1])])
		v.add_child(UI.lbl(Data.L("%s KAPSÜL JETONU: ") % Data.L(pd.name) + ", ".join(parts) + Data.L("   •   Hangar > BOYAHANE'de aç"), 20, Color(2.0, 1.7, 0.6), true, HORIZONTAL_ALIGNMENT_CENTER))
	else: v.add_child(UI.lbl(Data.L("Her 4 dakika dayanış bir kapsül jetonu verir (12. dk'dan sonra turuncu, 20. dk'dan sonra kırmızı)."), 15, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 16); v.add_child(hb)
	var again := UI.button(Data.L("TEKRAR UÇ"), func(): main.start_endless(), 22, 240); hb.add_child(again)
	hb.add_child(UI.button(Data.L("REKORLAR"), func(): main.show_records(), 22, 220))
	hb.add_child(UI.button(Data.L("ANA MENÜ"), func(): main.show_menu(), 22, 220))
	again.grab_focus.call_deferred()

# ================= Seviye kartları =================
## Kart havuzu. Kapsül (chest) kartları 2 seviye verir; evrim yalnızca kapsülden çıkar
## (silah 5. seviye + eş pasif en az EVO_PAS). Pasif kartları bazen LANETLİ gelir: +2 seviye, kalıcı bedel.
## Kart havuzu (v0.13, "hep aynı kartlar geliyor"): gösterilip seçilmeyen kart her seferinde daha seyrek gelir (Save'de değil,
## harekât boyunca), boş yuva varken en az bir YENİ kart, sahip olunan bir şey varken en az bir YÜKSELTME garanti;
## yuvalar dolunca havuza tek seferlik taktik kartları (Data.TACTICS) karışır.
func _card_options(chest := false) -> Array:
	var news := []; var ups := []
	for id in Data.WEAPONS:
		if banned.has(id): continue
		if weapons.has(id):
			if weapons[id].lvl < Data.MAX_LV: ups.append(["w", id])
		elif weapons.size() - 1 < Data.SLOTS: news.append(["w", id])
	for id in Data.PASSIVES:
		if banned.has(id): continue
		var cur: int = passives.get(id, 0)
		var o := ["c" if cur <= Data.MAX_LV - 2 and not chest and randf() < Data.CURSE_CHANCE else "p", id]
		if cur > 0 and cur < Data.MAX_LV: ups.append(o)
		elif cur == 0 and passives.size() < Data.SLOTS: news.append(o)
	var full := weapons.size() - 1 >= Data.SLOTS or passives.size() >= Data.SLOTS
	var tacs := []
	if full and not chest:
		for id in Data.TACTICS: tacs.append(["t", id])
	var n := (4 if pd.id == "serce" else 3) + (1 if chest else 0) # kapsül: +1 seçenek
	var out := []
	if chest:
		for id in weapons:
			if id != "sig" and weapons[id].lvl == Data.MAX_LV and passives.get(Data.WEAPONS[id].evo.pas, 0) >= Data.EVO_PAS: out.append(["e", id]); break
	if not news.is_empty() and out.size() < n: out.append(_wdraw(news))
	if not ups.is_empty() and out.size() < n: out.append(_wdraw(ups))
	var rest := news + ups + tacs
	while out.size() < n and not rest.is_empty(): out.append(_wdraw(rest))
	out.shuffle()
	for o in out: offered[o[1]] = offered.get(o[1], 0) + 1
	if out.is_empty(): out = [["heal", ""], ["gold", ""]]
	return out

## Ağırlıklı çekiliş (çekileni listeden çıkarır): her gösterilip seçilmeyişte ağırlık x0.5; taktik kartları daha seyrek
func _wdraw(arr: Array) -> Array:
	var ws := []; var tot := 0.0
	for o in arr:
		var w := pow(0.5, minf(offered.get(o[1], 0), 4)) * (0.45 if o[0] == "t" else 1.0)
		ws.append(w); tot += w
	var r := randf() * tot
	var i := 0
	while i < arr.size() - 1 and r > ws[i]: r -= ws[i]; i += 1
	var o: Array = arr[i]
	arr.remove_at(i)
	return o

func _open_levelup() -> void:
	card_chest = chest_picks > 0
	var opts := _card_options(card_chest)
	if autoplay: # test pilotu lanetli kartı ancak başka seçenek yoksa alır
		var safe := opts.filter(func(o): return o[0] != "c")
		_pick(safe[0] if not safe.is_empty() else opts[0]); return
	get_tree().paused = true
	Sfx.play("chest" if card_chest else "levelup", 0.0)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); ui.add_child(root); overlay = root
	var dim := ColorRect.new(); dim.color = Color(0, 0.02, 0.06, 0.6); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.set_anchors_preset(Control.PRESET_FULL_RECT); v.add_theme_constant_override("separation", 18); root.add_child(v)
	v.add_child(UI.lbl(Data.L("İKMAL KAPSÜLÜ") if card_chest else Data.L("SEVİYE %d!") % lvl, 64, Color(2.4, 1.5, 0.4) if card_chest else Color(2.6, 2.1, 0.7), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl(Data.L("Kapsülden 4 seçenek çıkar. Evrimler yalnızca kapsülden çıkar.") if card_chest else Data.L("Mühendislik topladığın Vahar çekirdeklerinden yeni bir sistem çözdü. Birini seç."), 18, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 24); v.add_child(h)
	var first: Button = null
	for k in opts.size():
		var b := _card(opts[k], k)
		h.add_child(b)
		if first == null: first = b
		b.scale = Vector2(0.6, 0.6); b.modulate.a = 0.0; b.pivot_offset = Vector2(150, 190)
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_delay(0.06 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(0.06 * k)
	v.add_child(UI.lbl(Data.L("YASAKLA seçiliyken tıkladığın kart bu harekâtta bir daha gelmez") if ban_mode else Data.L("Fare ile tıkla  •  1 / 2 / 3  •  R: yeniden çek  •  B: yasakla  •  S: atla"), 14, Color(2.4, 0.6, 0.5) if ban_mode else Color(0.45, 0.55, 0.7), false, HORIZONTAL_ALIGNMENT_CENTER))
	var tools := HBoxContainer.new(); tools.alignment = BoxContainer.ALIGNMENT_CENTER; tools.add_theme_constant_override("separation", 12); v.add_child(tools)
	var rb := UI.button(Data.L("YENİDEN ÇEK (%d)") % rerolls, _reroll, 18, 250); rb.disabled = rerolls <= 0; rb.set_meta("key", KEY_R); tools.add_child(rb)
	var bb := UI.button((Data.L("İPTAL") if ban_mode else Data.L("YASAKLA (%d)") % bans), _toggle_ban, 18, 230); bb.disabled = bans <= 0 and not ban_mode; bb.set_meta("key", KEY_B); tools.add_child(bb)
	var sb := UI.button(Data.L("ATLA (+%d can)") % int(max_hp * 0.1), _skip_card, 18, 230); sb.set_meta("key", KEY_S); tools.add_child(sb)
	first.grab_focus.call_deferred()

func _reopen_cards() -> void:
	if overlay: overlay.queue_free(); overlay = null
	_open_levelup()

func _reroll() -> void:
	if rerolls <= 0: return
	rerolls -= 1; ban_mode = false; _reopen_cards()

func _toggle_ban() -> void:
	if bans <= 0 and not ban_mode: return
	ban_mode = not ban_mode
	var keep := overlay # aynı kartlarla yeniden çizmek yerine yalnızca ipucunu güncelle
	var v: VBoxContainer = keep.get_child(1)
	var hint: Label = v.get_child(3)
	hint.text = Data.L("YASAKLA: tıkladığın kart bu harekâtta bir daha gelmez") if ban_mode else Data.L("Fare ile tıkla  •  1 / 2 / 3  •  R: yeniden çek  •  B: yasakla  •  S: atla")
	hint.add_theme_color_override("font_color", Color(2.4, 0.6, 0.5) if ban_mode else Color(0.45, 0.55, 0.7))
	var bb: Button = v.get_child(4).get_child(1)
	bb.text = "    " + (Data.L("İPTAL") if ban_mode else Data.L("YASAKLA (%d)") % bans)

func _skip_card() -> void:
	hp = minf(max_hp, hp + max_hp * 0.1)
	pending_lv -= 1
	if card_chest: chest_picks -= 1
	ban_mode = false
	if overlay: overlay.queue_free(); overlay = null
	get_tree().paused = false

func _card_click(o: Array) -> void:
	if ban_mode and o[0] in ["w", "p", "c"]:
		banned[o[1]] = true; bans -= 1; ban_mode = false
		Sfx.play("hurt", 0.0); _reopen_cards(); return
	_pick(o)

func _card(o: Array, idx: int) -> Button:
	var up := 1
	var title := ""; var icon := ""; var lv_txt := ""; var desc := ""; var col := UI.CYAN
	match o[0]:
		"w":
			var w: Dictionary = Data.WEAPONS[o[1]]
			var cur: int = weapons[o[1]].lvl if weapons.has(o[1]) else 0
			title = Data.L(w.name); icon = w.icon; desc = Data.L(w.desc[0]) + "\n" + Data.wdiff(o[1], 0, 1) if cur == 0 else Data.wdiff(o[1], cur, cur + up)
			lv_txt = Data.L("YENİ SİLAH!") if cur == 0 else Data.L("SEVİYE %d → %d") % [cur, mini(cur + up, Data.MAX_LV)]
			col = Color("ff9a3c") if cur == 0 else UI.CYAN
			if cur >= Data.MAX_LV - up: desc += Data.L("\nEVRİM: + %s (sv %d), ikmal kapsülünden") % [Data.L(Data.PASSIVES[w.evo.pas].name), Data.EVO_PAS]
		"e":
			var w: Dictionary = Data.WEAPONS[o[1]]
			title = Data.L(w.evo.name); icon = w.icon; desc = Data.L(w.evo.desc) + "\n" + Data.wdiff(o[1], Data.MAX_LV, Data.MAX_LV + 1); lv_txt = Data.L("★ EVRİM ★"); col = Color(2.4, 1.9, 0.6)
		"p":
			var p: Dictionary = Data.PASSIVES[o[1]]
			var cur: int = passives.get(o[1], 0)
			title = Data.L(p.name); icon = p.icon; desc = Data.L(p.desc)
			lv_txt = Data.L("YENİ SİSTEM!") if cur == 0 else Data.L("SEVİYE %d → %d") % [cur, mini(cur + up, Data.MAX_LV)]
			col = Color("57ff9a")
		"c":
			var p: Dictionary = Data.PASSIVES[o[1]]
			var cur: int = passives.get(o[1], 0)
			title = Data.L("LANETLİ ") + Data.L(p.name); icon = p.icon; desc = Data.L(p.desc) + Data.L("\nBEDEL: ") + Data.L(p.curse[2])
			lv_txt = Data.L("☠ +2 SEVİYE ☠"); col = Color(2.4, 0.3, 0.4)
		"t":
			var tk: Dictionary = Data.TACTICS[o[1]]
			title = Data.L(tk.name); icon = tk.icon; desc = Data.L(tk.desc) + Data.L("
Yuva tutmaz, birikir.")
			lv_txt = Data.L("TAKTİK"); col = Color("c9a6ff")
		"heal": title = Data.L("Onarım Kiti"); icon = "p_onarim"; desc = Data.L("+50 can"); lv_txt = Data.L("TAMİR")
		"gold": title = "Prim"; icon = "p_kalibre"; desc = Data.L("+3000 puan"); lv_txt = Data.L("ÖDÜL")
	var b := Button.new(); b.custom_minimum_size = Vector2(270 if pd.id == "serce" else 300, 380)
	b.add_theme_stylebox_override("normal", UI.box(Color(0.03, 0.06, 0.12, 0.95), Color(col, 0.6), 14, 2))
	b.add_theme_stylebox_override("hover", UI.box(Color(0.06, 0.14, 0.24, 0.98), col, 14, 4))
	b.add_theme_stylebox_override("focus", UI.box(Color(0.06, 0.14, 0.24, 0.98), col, 14, 4))
	b.add_theme_stylebox_override("pressed", UI.box(Color(0.1, 0.2, 0.3, 1), Color.WHITE, 14, 4))
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_FULL_RECT); v.offset_left = 18; v.offset_right = -18; v.offset_top = 22; v.offset_bottom = -18
	b.clip_contents = true
	v.add_theme_constant_override("separation", 12); v.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(v)
	v.add_child(UI.lbl(str(idx + 1), 16, Color(0.45, 0.55, 0.7), true))
	var ic := UI.pic(Data.tex(icon), Vector2(110, 110)); v.add_child(ic)
	v.add_child(UI.lbl(lv_txt, 15, col, true, HORIZONTAL_ALIGNMENT_CENTER))
	# yazılar kartın içinde kalır: uzun adlar küçülüp alt satıra geçer (diğer dillerde de taşmasın)
	var iw: float = b.custom_minimum_size.x - 44.0
	var tl := UI.lbl(title, 26 if title.length() <= 18 else (22 if title.length() <= 26 else 19), Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.custom_minimum_size = Vector2(iw, 0); v.add_child(tl)
	var d := UI.lbl(desc, 17 if desc.length() < 70 else 15, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.custom_minimum_size = Vector2(iw, 0); v.add_child(d)
	b.pressed.connect(func(): _card_click(o))
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play("click", 0.0))
	b.set_meta("key", KEY_1 + idx)
	return b

func _input(e: InputEvent) -> void:
	var tut_skip: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_TAB]) or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_BACK)
	if tut_i >= 0 and tut_skip and overlay == null:
		_end_tutorial(); get_viewport().set_input_as_handled(); return
	var code := 0
	if e is InputEventKey and e.pressed and not e.echo: code = e.keycode
	elif e is InputEventJoypadButton and e.pressed: code = {JOY_BUTTON_X: KEY_R, JOY_BUTTON_Y: KEY_B}.get(e.button_index, 0)
	if overlay and Data.L(overlay.name) != "Pause" and code != 0:
		var v: Control = overlay.get_child(1)
		for row in [2, 4]:
			if v.get_child_count() <= row: continue
			for b in v.get_child(row).get_children():
				if b is Button and not b.disabled and b.get_meta("key", 0) == code: b.emit_signal("pressed"); get_viewport().set_input_as_handled(); return

func _pick(o: Array) -> void:
	Sfx.play("card", 0.0)
	offered.erase(o[1])
	match o[0]:
		"w":
			var up := 1
			if not weapons.has(o[1]): add_weapon(o[1]); up -= 1
			if up > 0: weapons[o[1]].lvl = mini(weapons[o[1]].lvl + up, Data.MAX_LV); _weapon_changed(o[1])
		"p":
			passives[o[1]] = mini(passives.get(o[1], 0) + 1, Data.MAX_LV); _recalc()
		"c": # lanetli: +2 seviye, bedel kalıcı (bu harekât boyunca)
			passives[o[1]] = mini(passives.get(o[1], 0) + 2, Data.MAX_LV)
			var cu: Array = Data.PASSIVES[o[1]].curse
			curse[cu[0]] = curse.get(cu[0], 0.0) + cu[1]
			_recalc(); screen_flash(Color(0.8, 0.1, 0.2), 0.35, 0.5); _float_text(Data.L("LANET: ") + Data.L(cu[2]), Color(2.4, 0.4, 0.5))
		"e":
			weapons[o[1]].lvl = Data.MAX_LV + 1; _weapon_changed(o[1])
			var ev: Dictionary = Data.WEAPONS[o[1]].evo
			banner(Data.L("EVRİM: ") + Data.L(ev.name), Data.L(ev.desc), Color(2.6, 2.0, 0.6)); screen_flash(Color(1.0, 0.85, 0.4), 0.4, 0.6)
		"t": # taktik: tek seferlik küçük kalıcı bonus (yuva tutmaz)
			var tk: Dictionary = Data.TACTICS[o[1]]
			tac[tk.k] = tac.get(tk.k, 0.0) + tk.v
			if tk.k == "reroll": rerolls += 1; bans += 1
			_recalc()
			if tk.k == "hp": hp = minf(max_hp, hp + max_hp * 0.3)
		"heal": hp = minf(max_hp, hp + 50.0)
		"gold": score += 3000
	pending_lv -= 1
	if card_chest: chest_picks -= 1
	ban_mode = false
	if overlay: overlay.queue_free(); overlay = null
	get_tree().paused = false

# ================= Duraklat =================
func _open_pause() -> void:
	get_tree().paused = true
	var root := Control.new(); root.name = "Pause"; root.set_anchors_preset(Control.PRESET_FULL_RECT); ui.add_child(root); overlay = root
	var dim := ColorRect.new(); dim.color = Color(0, 0.02, 0.06, 0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.set_anchors_preset(Control.PRESET_FULL_RECT); v.add_theme_constant_override("separation", 14); root.add_child(v)
	v.add_child(UI.lbl(Data.L("DURAKLATILDI"), 60, Color(1.2, 2.0, 2.6), true, HORIZONTAL_ALIGNMENT_CENTER))
	var names := []
	for id in weapons: names.append(Data.L(Data.SIGS[pd.sig].name) if id == "sig" else Data.L("%s %d") % [Data.L(Data.WEAPONS[id].name), weapons[id].lvl])
	for id in passives: names.append(Data.L("%s %d") % [Data.L(Data.PASSIVES[id].name), passives[id]])
	var info := UI.lbl("  •  ".join(names), 16, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(info)
	var bc := CenterContainer.new(); v.add_child(bc)
	var bv := VBoxContainer.new(); bv.add_theme_constant_override("separation", 10); bc.add_child(bv)
	var cont := UI.button(Data.L("DEVAM"), _close_pause); bv.add_child(cont)
	var sb := UI.button(Data.L("AYARLAR"), func(): pass); bv.add_child(sb)
	sb.pressed.connect(func(): # oyun içi ayarlar: duraklat ekranının üstünde açılır
		UI.settings(root, func(): if is_instance_valid(sb): sb.grab_focus.call_deferred()))
	bv.add_child(UI.button(Data.L("GÖREVİ BIRAK"), func(): _results(false)))
	bv.add_child(UI.button(Data.L("ANA MENÜ"), func(): main.show_menu()))
	cont.grab_focus.call_deferred()

func _close_pause() -> void:
	if overlay: overlay.queue_free(); overlay = null
	get_tree().paused = false

# ================= Ölüm / sonuç =================
func _die() -> void:
	phase = "dead"; dead_t = 0.0
	Sfx.play("bigboom", 0.0); Sfx.play_music("")
	explosion(player.position, Color(1.0, 0.5, 0.2), 1.6)
	shake = 14.0; hitstop = 0.0
	crash = wreck_from(player, vel * 0.7, 2.2, 1.9) # uçak dönerek düşer, gölgesiyle buluştuğu yerde çarpar
	crash.player = true; crash.spin = 3.2 * (1.0 if bank >= 0.0 else -1.0)
	player.visible = false; hpbar.visible = false
	for o in orbs: o.visible = false
	emp_ring.visible = false

func _update_dead(dt: float) -> void:
	dead_t += dt
	if is_instance_valid(crash):
		player.position = crash.position # kamera düşen uçağı izler
		var f := clampf(crash.t / crash.life, 0.0, 1.0)
		shadow.visible = true; shadow.frame = crash.frame; shadow.rotation = crash.rotation; shadow.scale = crash.scale * 0.9
		shadow.position = crash.position + Vector2(60, 90) * (1.0 - f) # yere yaklaştıkça gölge altına kayar
		if randf() < 0.08: explosion(crash.position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), Color(1.0, 0.5, 0.2), 0.5)
	else:
		shadow.visible = false
	if dead_t > 3.8: _results(false)

func _results(win: bool) -> void:
	if phase == "end": return
	phase = "end"
	if dev.has("log") and endless: print("SONSUZ dalga=%d sure=%.0f" % [wave + 1, t])
	if dev.has("log"): print("SONUC bolum=%d puan=%s kazandi=%s sure=%.0f seviye=%d olum=%d sandik=%d" % [stage + 1, dev.get("pts", "0"), win, t, lvl, kills, chests])
	if dev.has("op") and win and _op_continues(): # test: harekâtı aynı süreçte sürdür
		main.start_game(stage + 1, true, diff, _carry_state()); return
	if dev.has("log"): get_tree().quit()
	if overlay: overlay.queue_free(); overlay = null
	if endless: _endless_results(); return
	get_tree().paused = true
	Sfx.play_music(""); Sfx.play("victory" if win else "gameover", 0.0)
	var gained := int((kills + int(t / 2.0) + lvl * 5 + (400 if win else 0)) * (1.0 + 0.3 * stage))
	var before: int = Save.level()
	Save.xp += gained
	var after: int = Save.level()
	var first := win and stage not in Save.cleared
	var bossk := 0.0
	for b2 in bosses: bossk = maxf(bossk, 1.0 - b2.hp / b2.maxhp)
	var progress := 1.0 if win else clampf(t / boss_t, 0.0, 1.0) * 0.85 + bossk * 0.15
	var pts_got: float = Save.award(stage, progress, win, diff)
	var got_stars := [win, win and chests >= Data.chest_count(stage + 1), win and not boss_hit]
	var had: Array = Save.stars_of(stage, diff)
	var new_stars := Save.add_stars(stage, diff, got_stars)
	pts_got += new_stars * Data.STAR_PTS
	# uçak ustalığı: düşürülen + zafer + boss hasarı (Data.MASTERY_XP)
	var mx0: int = int(Save.mastery.get(pd.id, 0))
	var mgain := int(kills + (400 if win else 0) + 300.0 * bossk)
	Save.mastery[pd.id] = mx0 + mgain; Save.write()
	var ml0 := Data.mastery_level(mx0); var ml1 := Data.mastery_level(mx0 + mgain)
	var rank := 0 if score <= 0 else Save.add_record({"score": score, "time": int(t), "kills": kills, "plane": Data.L(pd.name), "lvl": lvl, "won": win, "stage": stage + 1, "date": Time.get_date_string_from_system()})
	var final := win and stage == Data.STAGES.size() - 1
	var gift := final and not Save.campaign_gift # seferi ilk bitiriş hediyesi: tek seferlik turuncu jeton
	if gift: Save.campaign_gift = true; Save.add_token(pd.id, "o")
	banner_q.clear() # sonuç ekranı kendi duyurularını gösterir; arkada büyük yazı kalmasın
	if banner_tw: banner_tw.kill()
	banner_box.modulate.a = 0.0
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); ui.add_child(root); overlay = root
	var dim := ColorRect.new(); dim.color = Color(0, 0.02, 0.06, 0.8); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.set_anchors_preset(Control.PRESET_FULL_RECT); v.add_theme_constant_override("separation", 10); root.add_child(v)
	var head := Data.L("ZAFER!") if final else (Data.L("BÖLÜM TAMAMLANDI!") if win else Data.L("GÖREV BAŞARISIZ"))
	v.add_child(UI.lbl(head, 64, Color(0.6, 2.6, 1.0) if win else Color(2.6, 0.4, 0.5), true, HORIZONTAL_ALIGNMENT_CENTER))
	# zafer sözü her seferinde farklı (boss düştü havuzu); son bölümde savaş biter
	var quote: String = (Data.L("Bitti, Şahin-1. Savaş bitti. Eve dön, dünya seni bekliyor.") if final else Data.L(_line("boss_kill")[1])) if win else Data.STORY.game_over.pick_random()
	v.add_child(UI.lbl("\"" + Data.L(quote) + Data.L("\"  — Komutan Atlas"), 16, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	var g := GridContainer.new(); g.columns = 4; g.add_theme_constant_override("h_separation", 60)
	var gc := CenterContainer.new(); gc.add_child(g); v.add_child(gc)
	for st2 in [[Data.L("SÜRE"), UI.mmss(t)], [Data.L("DÜŞÜRÜLEN"), str(kills)], [Data.L("SEVİYE"), str(lvl)], [Data.L("SKOR"), str(score)]]:
		var c := VBoxContainer.new(); c.add_child(UI.lbl(st2[0], 14, UI.DIM, true, HORIZONTAL_ALIGNMENT_CENTER)); c.add_child(UI.lbl(st2[1], 36, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)); g.add_child(c)
	if rank == 1: v.add_child(UI.lbl(Data.L("★ YENİ REKOR! ★"), 24, Color(2.6, 2.1, 0.6), true, HORIZONTAL_ALIGNMENT_CENTER))
	var sh := HBoxContainer.new(); sh.alignment = BoxContainer.ALIGNMENT_CENTER; sh.add_theme_constant_override("separation", 30); v.add_child(sh)
	for k in 3: # bölüm yıldızları (Data.STARS); bu uçuşta yeni kazanılan parlar
		var on: bool = got_stars[k] or had[k]
		var fresh: bool = got_stars[k] and not had[k]
		sh.add_child(UI.lbl(("★ " if on else "☆ ") + Data.L(Data.STARS[k]) + (Data.L("  YENİ!") if fresh else ""), 17, Color(2.6, 2.0, 0.5) if fresh else (UI.GOLD if on else UI.DIM), true))
	if diff > 0: v.add_child(UI.lbl(Data.L("ZORLUK: ") + Data.L(Data.DIFF[diff].name) + Data.L("  •  puan x%.1f") % Data.DIFF[diff].pts, 15, Data.DIFF[diff].col, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl(Data.L("+%.1f PİLOT PUANI%s") % [pts_got, Data.L("  (ilk geçiş bonusu dahil)") if first else ("" if stage == Save.next_stage() or win else Data.L("  (tekrar oynanan bölüm: %25)"))], 28, Color(2.2, 1.9, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl(Data.L("Bölüm %d: %d. deneme   •   Önerilen güç %d, senin gücün %d   •   +%d rütbe XP") % [stage + 1, Save.tries_of(stage), int(round(Data.REQ[stage + 1])), Save.power(), gained], 16, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	var mtxt := Data.L("%s USTALIĞI +%d") % [Data.L(pd.name), mgain] + ("   •   " + Data.L("KADEME %d: ") % ml1 + Data.L(Data.MASTERY[pd.id][ml1 - 1].d) if ml1 > ml0 else "")
	v.add_child(UI.lbl(mtxt, 18 if ml1 > ml0 else 15, Color(pd.color.r * 1.8, pd.color.g * 1.8, pd.color.b * 1.8) if ml1 > ml0 else UI.DIM, ml1 > ml0, HORIZONTAL_ALIGNMENT_CENTER))
	var info: Dictionary = Data.rank_info(Save.xp)
	v.add_child(UI.lbl((Data.L("SEVİYE %d → %d   ") % [before, after] if after > before else Data.L("SEVİYE %d   ") % after) + Data.rank_name(after), 18, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER))
	var bc := CenterContainer.new(); v.add_child(bc)
	var b := UI.bar(420, 10, UI.GOLD); b.value = float(info.into) / info.need; bc.add_child(b)
	for p in Data.PLANES:
		if first and p.unlock == stage + 1:
			v.add_child(UI.lbl(Data.L("YENİ UÇAK AÇILDI: ") + Data.L(p.name) + " — " + Data.L(p.trait), 22, Color(p.color.r * 1.8, p.color.g * 1.8, p.color.b * 1.8), true, HORIZONTAL_ALIGNMENT_CENTER))
	if gift: v.add_child(UI.lbl(Data.L("SEFER HEDİYESİ: 1 TURUNCU KAPSÜL JETONU (%s)  •  Hangar > BOYAHANE") % Data.L(pd.name), 20, Color(2.4, 1.6, 0.5), true, HORIZONTAL_ALIGNMENT_CENTER))
	var pts := Save.tree_points()
	if pts > 0: v.add_child(UI.lbl(Data.L("PİLOT AĞACI: %d puan harcanmayı bekliyor") % pts, 18, Color(2.2, 1.9, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER))
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 16); v.add_child(hb)
	var first_btn: Button
	if win and not final and Save.stage_open(stage + 1):
		# sefer akışı: birkaç saniye sonra kendiliğinden sonraki bölüme geçer
		var cs := _carry_state() if _op_continues() else {}
		var nd := diff if Save.diff_open(stage + 1, diff) or not cs.is_empty() else 0
		# bu sahne sinematikte silinir: geri çağrı game'e değil main'e bağlı olmalı (yoksa geçişte donar)
		var nxt := func(): main.play_cine(stg.boss, main.start_game.bind(stage + 1, true, nd, cs))
		first_btn = UI.button(Data.L("BÖLÜM %d  ▶") % (stage + 2), nxt, 22, 320); hb.add_child(first_btn)
		var fb := first_btn
		var cd := create_tween()
		cd.tween_method(func(x: float): fb.text = Data.L("    BÖLÜM %d  ▶  %d") % [stage + 2, ceili(x)], 8.0, 0.0, 8.0)
		cd.tween_callback(nxt)
		hb.add_child(UI.button(Data.L("HAREKÂTI BIRAK") if not cs.is_empty() else Data.L("SEFER HARİTASI"), func(): cd.kill(); main.show_stages(), 22, 280))
	elif win:
		first_btn = UI.button(Data.L("DEVAM  ▶"), func(): main.play_cine(stg.boss, main.show_menu if final else main.show_stages), 22, 260); hb.add_child(first_btn)
	else:
		first_btn = UI.button(Data.L("HAREKÂTI TEKRARLA") if op_pos > 0 else Data.L("TEKRAR UÇ"), func(): main.start_game(Data.op_start(stage), false, diff), 22, 300); hb.add_child(first_btn)
		hb.add_child(UI.button(Data.L("SEFER HARİTASI"), func(): main.show_stages(), 22, 260))
	hb.add_child(UI.button(Data.L("PİLOT AĞACI"), func(): main.show_tree(), 22, 240))
	first_btn.grab_focus.call_deferred()

## Her harekâtın kendi parçası (tools/make_music.js); sonsuz modda dalgaya göre döner
func _battle_music() -> String:
	var k: int = wave if endless else int(stage / Data.OP_LEN)
	return "music_op%d" % (k % 5 + 1)

func _keys_text() -> String:
	if Data.pad: return Data.L("SOL ÇUBUK: UÇ   •   SİLAHLAR OTOMATİK   •   ") + (Data.L("RB / A: ATILIM   •   ") if pd.id == "simsek" else "") + Data.L("START: DURAKLAT")
	return Data.L("FARE veya WASD: UÇ   •   SİLAHLAR OTOMATİK   •   ") + (Data.L("SPACE / SAĞ TIK: ATILIM   •   ") if pd.id == "simsek" else "") + Data.L("ESC: DURAKLAT   •   F: TAM EKRAN")

# ================= Mini eğitim =================
## İlk uçuşta, oyun akarken alt ortada adım adım tuşları öğretir. Her adım ya görev yapılınca ya süre dolunca geçer.
func _tut_steps() -> Array:
	var a := [
		[Data.L("Sol çubukla uç: uçak çubuğun yönüne döner.") if Data.pad else Data.L("Fareyi hareket ettir: uçağın imleci takip eder."), 0.0],
		[Data.L("Yön tuşları da olur. Çubuğu bırakınca uçak düz devam eder.") if Data.pad else Data.L("Klavye de olur: WASD veya yön tuşlarıyla uç."), 7.0],
		[Data.L("Silahların OTOMATİK ateş eder. Düşmanlara yaklaş, gerisini onlar halleder."), 9.0],
		[Data.L("Düşenlerden kalan kristalleri topla: çubuk dolunca seviye atlar, yeni silah seçersin."), 9.0],
	]
	if pd.id == "simsek": a.append([(Data.L("RB veya A") if Data.pad else Data.L("SPACE veya SAĞ TIK")) + Data.L(": atılım. Düşman sürüsünü yarıp geç."), 8.0])
	a.append([(Data.L("START") if Data.pad else Data.L("ESC")) + Data.L(" ile duraklat. Hazırsın, Şahin-1. İyi avlar!"), 4.0])
	return a

func _start_tutorial() -> void:
	if not ((not Save.tutorial_done and dev.is_empty()) or dev.has("tut")): return
	tut_i = 0; _show_tut()

func _show_tut() -> void:
	var a := _tut_steps()
	tut_t = 0.0; tut_p = player.position
	tut_tag.text = Data.L("EĞİTİM  %d / %d") % [tut_i + 1, a.size()]
	tut_lbl.text = a[tut_i][0]
	tut_box.visible = true; tut_box.modulate.a = 0.0
	tut_box.create_tween().tween_property(tut_box, "modulate:a", 1.0, 0.25)
	Sfx.play("click", 0.0)

func _update_tutorial(dt: float) -> void:
	tut_t += dt
	var a := _tut_steps()
	var lim: float = a[tut_i][1]
	var done := lim > 0.0 and tut_t >= lim
	match tut_i:
		0: done = player.position.distance_to(tut_p) > 320.0 or tut_t > 12.0
		1: done = done or (tut_t > 1.0 and Input.get_vector("left", "right", "up", "down").length() > 0.1)
		2: done = done or (tut_t > 2.0 and kills >= 3)
		3: done = done or (tut_t > 2.0 and lvl > 1)
	if pd.id == "simsek" and tut_i == 4: done = done or dash_t > 0.0
	if done:
		tut_i += 1
		if tut_i >= a.size(): _end_tutorial()
		else: _show_tut()

func _end_tutorial() -> void:
	tut_i = -1; tut_box.visible = false
	Save.tutorial_done = true; Save.write()

# ================= HUD =================
func _update_hud(dt: float) -> void:
	if tok_lbl:
		var nc: String = Data.cos_color(cos_next + Data.COS_EVERY); var col: Color = Data.COS_COLORS[nc][2]
		tok_lbl.text = Data.L("%s JETON  %s") % [Data.L(Data.COS_COLORS[nc][1]), UI.mmss(maxf(0.0, cos_next + Data.COS_EVERY - t))] + ("   ×%d" % cos_got.size() if not cos_got.is_empty() else "")
		tok_lbl.add_theme_color_override("font_color", col); tok_bar.value = clampf((t - cos_next) / Data.COS_EVERY, 0.0, 1.0); tok_bar.modulate = Color(col.r * 1.5, col.g * 1.5, col.b * 1.5)
	L_fx.modulate.a = Save.fx_alpha / 100.0 # ayarlar oyun içinde değişebilir
	xp_bar.value = float(xp) / Data.run_need(lvl)
	lvl_lbl.text = Data.L("SV %d") % lvl
	time_lbl.text = UI.mmss(t)
	stage_lbl.text = (Data.L("SONSUZ  •  DALGA %d  •  %s") % [wave + 1, Data.L(stg.sub)] if endless else Data.L("HAREKÂT %d (%d/%d)  •  BÖLÜM %d  •  %s") % [stage / Data.OP_LEN + 1, op_pos + 1, Data.OP_LEN, stage + 1, Data.L(stg.name)] + ("  •  " + Data.L(Data.DIFF[diff].name) if diff > 0 else "")) + ("" if boss_spawned else Data.L("   •   BOSS  ") + UI.mmss(maxf(0.0, boss_t - t)))
	kill_lbl.text = Data.L("DÜŞÜRÜLEN  %d") % kills
	score_lbl.text = Data.L("SKOR  %d") % score
	if not bosses.is_empty():
		var b: Enemy = bosses[0]
		boss_bar.value = b.hp / b.maxhp
	if radio_panel.visible:
		radio_t -= dt
		radio_pic.talking = radio_lbl.visible_ratio < 1.0
		if radio_who == "varek" or radio_who == "vahar": # yakalanan yayın: parazit titremesi
			radio_panel.modulate.a = 0.75 if randf() < 0.06 else 1.0
		if radio_t <= 0.0:
			radio_panel.visible = false; radio_panel.modulate.a = 1.0
			if not radio_q.is_empty():
				var q: Array = radio_q.pop_front(); _show_radio(q[0], q[1], q[2])
	if not lowhp_said and phase == "play" and hp < max_hp * 0.3 and hp > 0.0:
		lowhp_said = true; var lh := _line("lowhp"); radio(lh[0], lh[1], 2)
	pointer.queue_redraw()
	_update_warning()
	hint_lbl.visible = Save.hints and phase == "play" and tut_i < 0
	if hint_lbl.visible: hint_lbl.text = _keys_text()
	if tut_i >= 0 and phase == "play" and not get_tree().paused: _update_tutorial(dt)
