extends Control
## BOYAHANE (v0.14): uçak başına kozmetik kapsülleri (jetonla), hurda, parça takma, canlı önizleme.
## Jetonlar sadece sonsuz modda kazanılır (Data.COS_EVERY); kurallar ve olasılıklar data.gd -> COSMETICS bölümünde.

const UI = preload("res://scripts/ui.gd")
const SkinS = preload("res://scripts/skin.gd")
const GameS = preload("res://scripts/game.gd")
var main
var i := 0
var pid := "serce"
var t := 0.0
var sky_mat: ShaderMaterial
var info: VBoxContainer
var slots: VBoxContainer
var title: Label
var popup: Control = null
# önizleme
var vp: SubViewport
var host: Node
var ship: Sprite2D
var flame
var trail
var first: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sky := UI.sky(12); add_child(sky); sky_mat = sky.material
	add_child(UI.girih(0.04))
	for k in Data.PLANES.size():
		if Data.PLANES[k].id == Save.plane: i = k
	title = UI.lbl("", 46, Color(2.4, 1.5, 0.6), true); UI.at(title, PRESET_TOP_LEFT, Vector2(30, 14)); add_child(title)
	var root := HBoxContainer.new(); root.add_theme_constant_override("separation", 18); UI.at(root, PRESET_TOP_LEFT, Vector2(24, 76)); add_child(root)
	var left := VBoxContainer.new(); left.add_theme_constant_override("separation", 8); root.add_child(left)
	var nav := HBoxContainer.new(); nav.alignment = BoxContainer.ALIGNMENT_CENTER; left.add_child(nav)
	nav.add_child(UI.button("◄", func(): _go(-1), 26, 60))
	var svc := SubViewportContainer.new(); svc.custom_minimum_size = Vector2(280, 280); svc.stretch = true; nav.add_child(svc)
	vp = SubViewport.new(); vp.transparent_bg = false; vp.disable_3d = true; svc.add_child(vp)
	nav.add_child(UI.button("►", func(): _go(1), 26, 60))
	info = VBoxContainer.new(); info.add_theme_constant_override("separation", 6); left.add_child(info)
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(650, 620); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(sc)
	slots = VBoxContainer.new(); slots.add_theme_constant_override("separation", 5); slots.custom_minimum_size = Vector2(630, 0); sc.add_child(slots)
	var back := UI.button(Data.L("GERİ"), func(): main.show_hangar(), 20, 180)
	UI.at(back, PRESET_TOP_RIGHT, Vector2(-24, 18)); add_child(back)
	_build_preview()
	_refresh()
	if main and main.dev.has("open"): _open.call_deferred(str(main.dev.open)) # test: --open=g|o|r kapsül aç

func _go(d: int) -> void:
	i = posmod(i + d, Data.PLANES.size()); _refresh()

func _unhandled_input(e: InputEvent) -> void:
	if popup:
		if e.is_action_pressed("pause"): _close_popup()
		return
	if e.is_action_pressed("left"): _go(-1)
	elif e.is_action_pressed("right"): _go(1)
	elif e.is_action_pressed("pause"): main.show_hangar()

# ---------- canlı önizleme: yatış animasyonu, kozmetik alev ve iz, akan zemin ----------
class Grid extends Node2D:
	var t := 0.0
	func _process(dt: float) -> void: t += dt; queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 280, 280), Color(0.02, 0.03, 0.045))
		var off := fmod(t * 140.0, 40.0)
		for k in 10:
			draw_line(Vector2(0, k * 40 - 40 + off), Vector2(280, k * 40 - 40 + off), Color(0.24, 1.0, 0.85, 0.07))
			draw_line(Vector2(k * 40 + 10, 0), Vector2(k * 40 + 10, 280), Color(0.24, 1.0, 0.85, 0.07))

func _build_preview() -> void:
	vp.add_child(Grid.new())
	host = Node.new(); vp.add_child(host)

func _rebuild_ship() -> void:
	for c in host.get_children(): c.queue_free()
	if ship: ship.queue_free(); flame.queue_free(); trail.queue_free()
	var pd: Dictionary = Data.PLANES[i]
	var add := CanvasItemMaterial.new(); add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail = SkinS.TrailFx.new(); vp.add_child(trail)
	var ts: String = SkinS.style(pid, "iz"); var tc: Array = SkinS.colors(pid, "iz")
	trail.kind = ts if ts != "" else "contrail"; trail.c0 = tc[0] if not tc.is_empty() else Color.WHITE; trail.c1 = tc[1] if not tc.is_empty() else Color.WHITE
	if trail.kind != "smoke": trail.material = add
	flame = GameS.Exhaust.new(); flame.noz = pd.noz; flame.electric = pid == "simsek"; flame.material = add; flame.thr = 1.0; vp.add_child(flame)
	var fs: String = SkinS.style(pid, "alev"); var fc: Array = SkinS.colors(pid, "alev")
	if fs != "" or not fc.is_empty(): flame.kind = fs if fs != "" else "basic"; flame.c0 = fc[0]; flame.c1 = fc[1]
	ship = Sprite2D.new(); var sh := Data.sheet("plane_" + pid)
	ship.texture = sh; ship.hframes = 7; ship.frame = 3; ship.position = Vector2(140, 118); ship.scale = Vector2.ONE * 0.8
	ship.material = SkinS.material(host, pid, 7, pd.color.lerp(Color.WHITE, 0.35))
	vp.add_child(ship)
	trail.pts = [[], []]

func _process(dt: float) -> void:
	t += dt
	sky_mat.set_shader_parameter("cam", Vector2(t * 20.0, -t * 60.0)); sky_mat.set_shader_parameter("view_size", get_viewport_rect().size)
	if ship == null: return
	var bank := sin(t * 0.7) * 0.85
	ship.frame = clampi(int(round((bank + 1.0) * 3.0)), 0, 6)
	var S := ship.scale.y
	flame.position = ship.position; flame.sc = S / 0.5 * 0.77 / 0.77; flame.roll = bank; flame.thr = 0.75 + 0.25 * sin(t * 1.3); flame.queue_redraw()
	var ws := S / 0.5 / 0.7
	var tips := []
	for k in 2: tips.append(ship.position + Vector2((k * 2 - 1) * 26.0 * (1.0 - 0.3 * absf(bank)), 8.0) * ws)
	tips.append(Vector2.RIGHT)
	trail.push(tips, dt, true, Vector2(0, 260))

# ---------- bilgi ve parçalar ----------
func _rc(r: int) -> Color: return Data.COS_RCOL[r]

func _refresh() -> void:
	var pd: Dictionary = Data.PLANES[i]; pid = pd.id
	title.text = Data.L("BOYAHANE") + "  •  " + Data.L(pd.name)
	_rebuild_ship()
	for c in info.get_children(): c.queue_free()
	var own: Array = Save.owned.get(pid, [])
	info.add_child(UI.lbl(Data.L("PARÇALAR: %d / %d") % [own.size(), Data.COSMETICS[pid].size()], 17, Color.WHITE, true))
	var tr := HBoxContainer.new(); tr.add_theme_constant_override("separation", 6); info.add_child(tr)
	first = null
	for c in ["g", "o", "r"]:
		var n := Save.tok(pid, c); var col: Color = Data.COS_COLORS[c][2]
		var b := Button.new(); b.text = Data.L("%s ×%d\nAÇ") % [Data.L(Data.COS_COLORS[c][1]), n]; b.custom_minimum_size = Vector2(110, 58)
		b.add_theme_font_override("font", Data.font_bold); b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", col); b.add_theme_color_override("font_hover_color", Color.WHITE); b.add_theme_color_override("font_disabled_color", Color(col, 0.35))
		b.add_theme_stylebox_override("normal", UI.box(Color(0.03, 0.05, 0.08, 0.92), Color(col, 0.6), 6, 2))
		b.add_theme_stylebox_override("hover", UI.box(Color(0.06, 0.1, 0.14, 0.95), col, 6, 3)); b.add_theme_stylebox_override("focus", UI.box(Color(0.06, 0.1, 0.14, 0.95), col, 6, 3))
		b.add_theme_stylebox_override("disabled", UI.box(Color(0.03, 0.04, 0.06, 0.7), Color(col, 0.2), 6, 1))
		b.disabled = n <= 0; b.pressed.connect(_open.bind(c)); tr.add_child(b)
		if first == null and not b.disabled: first = b
	var scr := int(Save.scrap.get(pid, 0))
	var sb := UI.button(Data.L("HURDA %d/%d: PARÇA SEÇ") % [scr, Data.COS_SCRAP], _scrap_pick, 12, 400); sb.disabled = scr < Data.COS_SCRAP; info.add_child(sb)
	info.add_child(UI.lbl(Data.L("Garanti: %d kapsül daha 4+ çıkmazsa sıradaki en az AS") % maxi(0, Data.COS_PITY - int(Save.dry.get(pid, 0))), 13, UI.DIM))
	var mb := UI.button(Data.L("İZ VE ALEV BOYAYA UYSUN: ") + (Data.L("AÇIK") if Save.skin_match else Data.L("KAPALI")), func(): Save.skin_match = not Save.skin_match; Save.write(); _refresh(), 12, 400); info.add_child(mb)
	var hint := UI.lbl(Data.L("Jetonlar SONSUZ MOD'da kazanılır: her 4 dakika dayanış 1 jeton (12. dk'dan sonra turuncu, 20. dk'dan sonra kırmızı). Jeton, uçtuğun uçağın kapsülünü açar."), 13, UI.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.custom_minimum_size = Vector2(400, 0); info.add_child(hint)
	_slots()
	if first: first.grab_focus.call_deferred()

func _slots() -> void:
	for c in slots.get_children(): c.queue_free()
	var list: Array = Data.COSMETICS[pid]
	var e: Dictionary = Save.equip.get(pid, {})
	for sl in Data.COS_SLOTS + ["set"]:
		slots.add_child(UI.lbl(Data.L("EFSANE TAM SET") if sl == "set" else Data.L(Data.COS_SLOT_NAME[sl]), 16, UI.ORANGE, true))
		var g := GridContainer.new(); g.columns = 4; g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 6); slots.add_child(g)
		if sl != "set": # varsayılan
			var d := _item_btn(Data.L("VARSAYILAN"), Color(0.6, 0.65, 0.72), not e.has(sl), true)
			d.pressed.connect(func():
				if e.has(sl): Save.equip_item(pid, e[sl])
				_refresh())
			g.add_child(d)
		for k in list.size():
			var it: Dictionary = list[k]
			if it.s != sl: continue
			var own := Save.has_item(pid, k)
			var b := _item_btn(("%d • " % it.r) + (Data.L(it.n) if own else "???"), _rc(it.r), e.get(sl if sl != "set" else "boya", -1) == k, own)
			if own: b.pressed.connect(func(): Save.equip_item(pid, k); _refresh())
			b.tooltip_text = Data.L(it.n) + "  •  " + Data.L(Data.COS_RARITY[it.r])
			g.add_child(b)

func _item_btn(txt: String, col: Color, on: bool, own: bool) -> Button:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = Vector2(150, 40); b.clip_text = true
	b.add_theme_font_override("font", Data.font_bold); b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", col if own else Color(col, 0.35)); b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.1, 0.14, 0.95) if on else Color(0.03, 0.04, 0.07, 0.85), Color(col, 1.0 if on else (0.45 if own else 0.15)), 4, 3 if on else 1))
	b.add_theme_stylebox_override("hover", UI.box(Color(0.07, 0.12, 0.17, 0.95), col, 4, 2)); b.add_theme_stylebox_override("focus", UI.box(Color(0.07, 0.12, 0.17, 0.95), col, 4, 2))
	b.disabled = not own
	b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))
	b.add_theme_color_override("font_disabled_color", Color(col, 0.35))
	return b

# ---------- kapsül açma ----------
func _open(c: String) -> void:
	var res := Save.open_capsule(pid, c)
	if res.is_empty(): return
	var it: Dictionary = Data.COSMETICS[pid][res.i]
	var col := _rc(it.r)
	Sfx.play("chest", 0.0)
	_popup()
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.set_anchors_preset(PRESET_FULL_RECT); v.add_theme_constant_override("separation", 14); popup.add_child(v)
	var rl := UI.lbl(Data.L(Data.COS_RARITY[it.r]), 26, Color(col.r * 1.6, col.g * 1.6, col.b * 1.6), true, HORIZONTAL_ALIGNMENT_CENTER); v.add_child(rl)
	var nl := UI.lbl(Data.L(it.n), 54, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER); v.add_child(nl)
	v.add_child(UI.lbl(Data.L(Data.COS_SLOT_NAME.get(it.s, "EFSANE TAM SET")), 18, UI.DIM, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl(Data.L("AYNISI ÇIKTI: +1 HURDA") if res.dup else Data.L("YENİ PARÇA!"), 22, UI.GOLD if res.dup else Color(0.6, 2.4, 1.0), true, HORIZONTAL_ALIGNMENT_CENTER))
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 16); v.add_child(hb)
	var ok := UI.button(Data.L("TAK") if not res.dup else Data.L("TAMAM"), func():
		if not res.dup: Save.equip_item(pid, res.i)
		_close_popup(), 22, 220); hb.add_child(ok)
	if not res.dup: hb.add_child(UI.button(Data.L("SONRA"), _close_popup, 22, 200))
	ok.grab_focus.call_deferred()
	# açılış: nadirliğe göre parlama ve büyüme
	for n in [rl, nl]: n.pivot_offset = Vector2(400, 30); n.scale = Vector2(0.3, 0.3); n.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(rl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tw.tween_property(rl, "modulate:a", 1.0, 0.3)
	tw.tween_property(nl, "scale", Vector2.ONE, 0.45).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tw.tween_property(nl, "modulate:a", 1.0, 0.3).set_delay(0.25)
	var fl := ColorRect.new(); fl.color = Color(col, 0.0); fl.set_anchors_preset(PRESET_FULL_RECT); fl.mouse_filter = MOUSE_FILTER_IGNORE; popup.add_child(fl)
	var ft := create_tween(); ft.tween_property(fl, "color:a", 0.25 + 0.1 * it.r, 0.12); ft.tween_property(fl, "color:a", 0.0, 0.6)
	if it.r >= 4: Sfx.play("levelup", 0.0)

func _scrap_pick() -> void:
	_popup()
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.set_anchors_preset(PRESET_FULL_RECT); v.add_theme_constant_override("separation", 10); popup.add_child(v)
	v.add_child(UI.lbl(Data.L("HURDAYLA PARÇA SEÇ (%d hurda)") % Data.COS_SCRAP, 34, UI.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var g := GridContainer.new(); g.columns = 4; g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8)
	var cc := CenterContainer.new(); cc.add_child(g); v.add_child(cc)
	var any := false
	for k in Data.COSMETICS[pid].size():
		var it: Dictionary = Data.COSMETICS[pid][k]
		if it.r > 3 or Save.has_item(pid, k): continue
		any = true
		var b := _item_btn("%d • %s" % [it.r, Data.L(it.n)], _rc(it.r), false, true); b.custom_minimum_size = Vector2(200, 44)
		b.pressed.connect(func(): Save.buy_with_scrap(pid, k); _close_popup())
		g.add_child(b)
	if not any: v.add_child(UI.lbl(Data.L("1-3. nadirlikte eksik parça yok."), 18, UI.DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	var cl := UI.button(Data.L("VAZGEÇ"), _close_popup, 22, 220); var c2 := CenterContainer.new(); c2.add_child(cl); v.add_child(c2)
	cl.grab_focus.call_deferred()

func _popup() -> void:
	if popup: popup.queue_free()
	popup = Control.new(); popup.set_anchors_preset(PRESET_FULL_RECT); add_child(popup)
	var dim := ColorRect.new(); dim.color = Color(0, 0.02, 0.06, 0.88); dim.set_anchors_preset(PRESET_FULL_RECT); popup.add_child(dim)

func _close_popup() -> void:
	if popup: popup.queue_free(); popup = null
	_refresh()
