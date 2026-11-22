extends Control
## DEFTER: karşılaşılan Vahar gemileri ve bosslar. Bir tür ilk kez düşürülünce kaydı açılır (Save.seen).
## Kayda tıklayınca özellikleri, saldırısı ve nasıl yenileceği görünür.

const UI = preload("res://scripts/ui.gd")
const PATS := {"fan": "Yelpaze atış", "spiral": "Spiral", "ring": "Halka", "curve": "Kıvrık akış", "dash": "Hücum",
	"pull": "Çekim alanı", "mines": "Mayın tarlası", "quad": "Dört yönlü ivmeli atış", "split": "Bölünen mermi",
	"walls": "Mermi duvarı", "stream": "Mermi seli", "summon": "Destek çağırır"}
var main
var sky_mat: ShaderMaterial
var t := 0.0
var grid: GridContainer
var detail: VBoxContainer
var tab := "enemy"
var tabs: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sky := UI.sky(12); add_child(sky); sky_mat = sky.material
	var title := UI.lbl(Data.L("DEFTER"), 54, Color(2.4, 2.0, 0.8), true); title.position = Vector2(30, 6); add_child(title)
	var sub := UI.lbl(Data.L("VAHAR FİLOSU İSTİHBARAT KAYITLARI"), 16, UI.DIM, true); sub.position = Vector2(34, 70); add_child(sub)
	var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 14); tb.position = Vector2(30, 100); add_child(tb)
	for m in [[Data.L("DÜŞMANLAR"), "enemy"], [Data.L("BOSSLAR"), "boss"]]:
		var b := UI.button(m[0], _show.bind(m[1]), 20, 210); tb.add_child(b); tabs.append(b)
	var left := ScrollContainer.new(); left.position = Vector2(30, 160); left.size = Vector2(560, 500); left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.set_anchors_preset(PRESET_LEFT_WIDE); left.offset_top = 160; left.offset_bottom = -70; left.offset_left = 30; left.offset_right = 600; add_child(left)
	grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12); left.add_child(grid)
	var p := UI.panel(); p.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE); p.offset_left = -640; p.offset_right = -20; p.offset_top = 20; p.offset_bottom = -20; add_child(p)
	var ps := ScrollContainer.new(); ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; p.add_child(ps)
	detail = VBoxContainer.new(); detail.add_theme_constant_override("separation", 8); detail.custom_minimum_size = Vector2(580, 0); ps.add_child(detail)
	var back := UI.button(Data.L("GERİ"), func(): main.show_menu(), 20, 160); UI.at(back, PRESET_BOTTOM_LEFT, Vector2(20, -16)); add_child(back)
	add_child(UI.scanlines())
	_show("enemy")
	tabs[0].grab_focus.call_deferred()

func _ids() -> Array:
	if tab == "boss":
		var out := []
		for s in Data.STAGES: out.append(s.boss)
		return out
	var ids := Data.ENEMIES.keys()
	ids.sort_custom(func(a, b): return _first(a) < _first(b))
	return ids

## Türün ilk görüldüğü bölüm (Kıvılcım: Bölünen ile)
func _first(id: String) -> int: return Data.ENEMIES.bolunen.from if Data.ENEMIES[id].from > 15 else Data.ENEMIES[id].from

## Kayıt resmi: 3D yatış şeridinin düz karesi
static func pic_of(tex: String) -> Texture2D:
	var sh := Data.sheet(tex)
	if sh == null: return Data.tex(tex)
	var a := AtlasTexture.new(); a.atlas = sh
	var w := sh.get_width() / 7.0
	a.region = Rect2(w * 3, 0, w, sh.get_height())
	return a

func _show(m: String) -> void:
	tab = m
	for c in grid.get_children(): c.queue_free()
	var ids := _ids()
	var open := 0
	for id in ids:
		var d: Dictionary = Data.BOSSES[id] if tab == "boss" else Data.ENEMIES[id]
		var known: bool = Save.seen.has(id)
		if known: open += 1
		var b := Button.new(); b.custom_minimum_size = Vector2(128, 128)
		b.add_theme_stylebox_override("normal", UI.box(Color(0.03, 0.05, 0.08, 0.9), Color(d.col, 0.55) if known else Color(0.3, 0.32, 0.36, 0.4), 8, 2))
		b.add_theme_stylebox_override("hover", UI.box(Color(0.06, 0.1, 0.14, 0.95), d.col if known else UI.DIM, 8, 3))
		b.add_theme_stylebox_override("focus", UI.box(Color(0.06, 0.1, 0.14, 0.95), d.col if known else UI.DIM, 8, 3))
		b.add_theme_stylebox_override("pressed", UI.box(Color(0.1, 0.14, 0.2, 1.0), Color.WHITE, 8, 3))
		var pic := UI.pic(pic_of(d.tex), Vector2(96, 96)); pic.position = Vector2(16, 8); pic.mouse_filter = MOUSE_FILTER_IGNORE
		if not known: pic.modulate = Color(0, 0, 0, 0.85) # kilitli: siluet
		b.add_child(pic)
		var nl := UI.lbl(Data.L(d.name) if known else "? ? ?", 12, Color.WHITE if known else UI.DIM, true, HORIZONTAL_ALIGNMENT_CENTER)
		nl.position = Vector2(0, 106); nl.size = Vector2(128, 18); nl.clip_text = true; nl.mouse_filter = MOUSE_FILTER_IGNORE; b.add_child(nl)
		b.pressed.connect(_detail.bind(id)); b.focus_entered.connect(_detail.bind(id))
		grid.add_child(b)
	_detail(ids[0])
	tabs[0 if tab == "enemy" else 1].text = "    " + (Data.L("DÜŞMANLAR") if tab == "enemy" else Data.L("BOSSLAR"))
	var cnt := UI.lbl(Data.L("%d / %d kayıt açıldı") % [open, ids.size()], 14, UI.GOLD, true)
	cnt.position = Vector2(480, 112); cnt.name = "Count"
	if has_node("Count"): get_node("Count").queue_free()
	add_child(cnt)

func _row(k: String, v: String, col := Color.WHITE) -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); detail.add_child(h)
	var a := UI.lbl(k, 14, UI.DIM, true); a.custom_minimum_size = Vector2(170, 0); h.add_child(a)
	var b := UI.lbl(v, 17, col, true); b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.custom_minimum_size = Vector2(380, 0); h.add_child(b)

func _text(s: String, size: int, col: Color) -> void:
	var l := UI.lbl(s, size, col); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(570, 0); detail.add_child(l)

func _detail(id: String) -> void:
	for c in detail.get_children(): c.queue_free()
	var boss := tab == "boss"
	var d: Dictionary = Data.BOSSES[id] if boss else Data.ENEMIES[id]
	var known: bool = Save.seen.has(id)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 18); detail.add_child(h)
	var pic := UI.pic(pic_of(d.tex), Vector2(180, 180)); h.add_child(pic)
	if not known: pic.modulate = Color(0, 0, 0, 0.85)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(v)
	v.add_child(UI.lbl(Data.L("BOSS") if boss else Data.L("VAHAR GEMİSİ"), 13, UI.DIM, true))
	var nm := UI.lbl(Data.L(d.name) if known else "? ? ?", 30, d.col if known else UI.DIM, true); nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nm.custom_minimum_size = Vector2(360, 0); v.add_child(nm)
	if known: v.add_child(UI.lbl(Data.L("Düşürülen: %d") % int(Save.seen[id]), 15, UI.GOLD, true))
	if not known:
		_text(Data.L("Bu kayıt kapalı. Bu gemiyi ilk kez düşürdüğünde istihbarat dosyası açılır."), 17, UI.DIM)
		var st := -1
		for i in Data.STAGES.size():
			if (boss and Data.STAGES[i].boss == id) or (not boss and _first(id) == i + 1): st = i
		if st >= 0: _text(Data.L("İlk görüldüğü yer: Bölüm %d") % (st + 1), 15, UI.DIM)
		return
	if boss:
		var si := 0
		for i in Data.STAGES.size():
			if Data.STAGES[i].boss == id: si = i
		_text("\"" + Data.L(d.line) + "\"", 17, Color(1.6, 1.5, 1.6))
		_row(Data.L("BÖLÜM"), Data.L("%d  •  %s") % [si + 1, Data.L(Data.STAGES[si].name)])
		_row(Data.L("CAN"), Data.L("%d (temel)") % int(d.hp * Data.BOSS_HP * d.get("hpk", 1.0)))
		_row(Data.L("TEMAS HASARI"), str(int(d.dmg)))
		_row(Data.L("HAREKET"), {"chase": "Kovalar", "hover": Data.L("Yavaşça süzülür"), "orbit": Data.L("Etrafında döner")}.get(d.move, d.move))
		var ps := []
		for p in d.pats: ps.append(PATS.get(p.split(":")[0], p))
		_row(Data.L("SALDIRILAR"), "  •  ".join(ps), Color(2.2, 0.9, 0.7))
	else:
		_text(Data.L(d.desc), 17, Color(1.5, 1.5, 1.55))
		_row(Data.L("CAN"), str(int(d.hp)))
		_row(Data.L("HIZ"), Data.L("%d  (%s)") % [int(d.spd), Data.L("çok hızlı") if d.spd >= 140 else (Data.L("hızlı") if d.spd >= 100 else ("orta" if d.spd >= 65 else Data.L("yavaş")))])
		_row(Data.L("TEMAS HASARI"), str(int(d.dmg)))
		if d.get("armor", 0.0) > 0.0: _row(Data.L("EK ZIRH"), Data.L("+%d") % int(d.armor))
		_row(Data.L("SALDIRI"), Data.L(d.atk), Color(2.2, 0.9, 0.7))
		_row(Data.L("İLK GÖRÜLDÜĞÜ"), Data.L("Bölüm %d") % _first(id))
		_row(Data.L("İPUCU"), Data.L(d.tip), Color(0.7, 1.6, 2.0))

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"): main.show_menu()

func _process(dt: float) -> void:
	t += dt
	sky_mat.set_shader_parameter("cam", Vector2(t * 14.0, -t * 30.0))
	sky_mat.set_shader_parameter("view_size", get_viewport_rect().size)
