extends Control
## Hangar: uçak seçimi

const UI = preload("res://scripts/ui.gd")
var main
var i := 0
var t := 0.0
var preview: TextureRect
var info: VBoxContainer
var dots: HBoxContainer
var sky_mat: ShaderMaterial

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sky := UI.sky(11); add_child(sky); sky_mat = sky.material
	add_child(UI.girih(0.04))
	for k in Data.PLANES.size():
		if Data.PLANES[k].id == Save.plane: i = k
	var title := UI.lbl(Data.L("HANGAR"), 54, Color(1.2, 2.0, 2.6), true, HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_and_offsets_preset(PRESET_TOP_WIDE); title.offset_top = 20; title.offset_bottom = 100
	add_child(title)

	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 40)
	UI.at(row, PRESET_CENTER, Vector2(0, 20)); add_child(row)
	var left := VBoxContainer.new(); left.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_child(left)
	var nav := HBoxContainer.new(); nav.alignment = BoxContainer.ALIGNMENT_CENTER; left.add_child(nav)
	nav.add_child(UI.button("◄", func(): _go(-1), 32, 64))
	preview = UI.pic(null, Vector2(380, 380)); preview.pivot_offset = Vector2(190, 190); nav.add_child(preview)
	nav.add_child(UI.button("►", func(): _go(1), 32, 64))
	dots = HBoxContainer.new(); dots.alignment = BoxContainer.ALIGNMENT_CENTER; dots.add_theme_constant_override("separation", 10); left.add_child(dots)
	var p := UI.panel(); p.custom_minimum_size = Vector2(440, 560); row.add_child(p)
	info = VBoxContainer.new(); info.add_theme_constant_override("separation", 5); p.add_child(info)

	var back := UI.button(Data.L("GERİ"), func(): main.show_menu(), 22, 200)
	UI.at(back, PRESET_BOTTOM_LEFT, Vector2(30, -24)); add_child(back)
	var lk := UI.button(Data.L("BOYAHANE"), func(): main.show_locker(), 22, 260) # kozmetik kapsülleri
	UI.at(lk, PRESET_BOTTOM_LEFT, Vector2(250, -24)); add_child(lk)
	var card := UI.pilot_card(); UI.at(card, PRESET_TOP_LEFT, Vector2(24, 20)); add_child(card)
	_refresh()

func _go(d: int) -> void:
	i = posmod(i + d, Data.PLANES.size()); _refresh()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("left"): _go(-1)
	elif e.is_action_pressed("right"): _go(1)
	elif e.is_action_pressed("pause"): main.show_menu()

func _refresh() -> void:
	var pd: Dictionary = Data.PLANES[i]
	var ok := Save.unlocked(pd)
	preview.texture = UI.plane_tex(pd.id)
	preview.modulate = Color(1, 1, 1) if ok else Color(0.05, 0.06, 0.09)
	for c in dots.get_children(): c.queue_free()
	for k in Data.PLANES.size():
		var q: Dictionary = Data.PLANES[k]
		var dot := ColorRect.new(); dot.custom_minimum_size = Vector2(14, 14) if k == i else Vector2(10, 10)
		dot.color = q.color if k == i else (Color(0.4, 0.5, 0.6) if Save.unlocked(q) else Color(0.15, 0.17, 0.22))
		dots.add_child(dot)
	for c in info.get_children(): c.queue_free()
	info.add_child(UI.lbl(Data.L(pd.name), 48, pd.color if ok else UI.DIM, true))
	info.add_child(UI.lbl(Data.L(pd.title), 16, UI.DIM, true))
	var d := UI.lbl(Data.L(pd.desc), 16); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.custom_minimum_size = Vector2(400, 0); info.add_child(d)
	for s in [[Data.L("HIZ  %d") % pd.speed, pd.speed / 320.0], [Data.L("MANEVRA  %.1f G") % Data.maneuver_g(pd), pd.lift / 1750.0], [Data.L("İVME  %d px/s²") % int(pd.thrust), pd.thrust / 1100.0], [Data.L("GÜÇ  x%.2f") % pd.might, pd.might / 1.25], [Data.L("DAYANIKLILIK  %d can + %d zırh") % [pd.hp, pd.armor], (pd.hp + pd.armor * 15.0) / 195.0]]:
		info.add_child(UI.lbl(s[0], 13, UI.DIM, true))
		var b := UI.bar(400, 10, pd.color if ok else Color(0.3, 0.32, 0.38)); b.value = s[1]; info.add_child(b)
	var w: Dictionary = Data.SIGS[pd.sig]
	var wr := HBoxContainer.new(); wr.add_theme_constant_override("separation", 10); info.add_child(wr)
	wr.add_child(UI.pic(Data.tex(w.icon), Vector2(48, 48)))
	var wl := VBoxContainer.new(); wr.add_child(wl)
	wl.add_child(UI.lbl(Data.L("İMZA SİLAHI: ") + Data.L(w.name), 15, Color.WHITE, true))
	var wd := UI.lbl(Data.L(w.desc), 13, UI.DIM); wd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; wd.custom_minimum_size = Vector2(340, 0); wl.add_child(wd)
	var tr := UI.lbl(Data.L("YETENEK: ") + Data.L(pd.trait), 16, pd.color if ok else UI.DIM, true); info.add_child(tr)
	var td := UI.lbl(pd.trait_desc, 14); td.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; td.custom_minimum_size = Vector2(400, 0); info.add_child(td)
	# uçak ustalığı: 5 kademe, uçtukça açılır (Data.MASTERY)
	var mx: int = int(Save.mastery.get(pd.id, 0))
	var ml := Data.mastery_level(mx)
	var mh := HBoxContainer.new(); mh.add_theme_constant_override("separation", 10); info.add_child(mh)
	mh.add_child(UI.lbl(Data.L("USTALIK %d/5") % ml, 15, pd.color if ok else UI.DIM, true))
	var mb := UI.bar(260, 8, pd.color if ok else Color(0.3, 0.32, 0.38)); mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; mh.add_child(mb)
	var lo: int = 0 if ml == 0 else Data.MASTERY_XP[ml - 1]
	mb.value = 1.0 if ml >= 5 else float(mx - lo) / (Data.MASTERY_XP[ml] - lo)
	for k in 5:
		var m: Dictionary = Data.MASTERY[pd.id][k]
		var got := k < ml
		info.add_child(UI.lbl(("● " if got else "○ ") + Data.L(m.d) + ("" if got else "  (%d)" % Data.MASTERY_XP[k]), 12, Color(pd.color.r * 1.5, pd.color.g * 1.5, pd.color.b * 1.5) if got else Color(0.42, 0.45, 0.52), got))
	var txt := Data.L("✔ AKTİF UÇAK") if Save.plane == pd.id else (Data.L("SEÇ") if ok else Data.L("BÖLÜM %d'İ GEÇİNCE AÇILIR") % pd.unlock)
	var sel := UI.button(txt, _select, 24, 400)
	sel.disabled = not ok or Save.plane == pd.id
	info.add_child(sel)

func _select() -> void:
	Save.plane = Data.PLANES[i].id; Save.write(); _refresh()

func _process(dt: float) -> void:
	t += dt
	sky_mat.set_shader_parameter("cam", Vector2(t * 20.0, -t * 60.0))
	sky_mat.set_shader_parameter("view_size", get_viewport_rect().size)
	preview.rotation = sin(t * 0.8) * 0.06
	preview.scale = Vector2.ONE * (1.0 + sin(t * 1.4) * 0.02)
