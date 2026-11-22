extends Control
## Sefer haritası: 15 bölüm, her biri hikayede bir yer. Harita aşağıdan (Ege) yukarıya (İlk Temas Şehri) ilerler.

const UI = preload("res://scripts/ui.gd")
const MAP_H := 3000.0
const XS := [480, 300, 200, 380, 620, 760, 600, 380, 220, 360, 600, 760, 560, 340, 480] # düğümlerin harita x konumu
var main
var sel := 0
var t := 0.0
var scroll: ScrollContainer
var content: Control
var nodes: Array = []
var info: VBoxContainer
var panel: PanelContainer
var foot: HBoxContainer # UÇ / AĞAÇ: panelin altında sabit, kaydırmadan erişilir
var diff_sel := 0 # seçili zorluk kademesi
var route_t := 0.0 # yol çizim animasyonu (0..1)

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.02, 0.03, 0.06); bg.set_anchors_preset(PRESET_FULL_RECT); add_child(bg)
	add_child(UI.girih(0.05))
	scroll = ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT); scroll.offset_right = -430
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	var center := CenterContainer.new(); center.size_flags_horizontal = SIZE_EXPAND_FILL; scroll.add_child(center)
	content = Control.new(); content.custom_minimum_size = Vector2(850, MAP_H); center.add_child(content)
	var map := TextureRect.new(); map.texture = Data.tex("map_campaign"); map.position = Vector2(-215, 0); map.size = Vector2(1280, MAP_H)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; map.mouse_filter = MOUSE_FILTER_IGNORE; content.add_child(map)
	map.modulate = Color(0.62, 0.56, 0.54) # harita kısılır, taktik katman öne çıkar
	var tac := ColorRect.new(); tac.position = Vector2(-215, 0); tac.size = Vector2(1280, MAP_H); tac.mouse_filter = MOUSE_FILTER_IGNORE
	var tm := ShaderMaterial.new(); tm.shader = load("res://scripts/tactical.gdshader"); tac.material = tm; content.add_child(tac)
	var path := Control.new(); path.set_anchors_preset(PRESET_FULL_RECT); path.mouse_filter = MOUSE_FILTER_IGNORE; content.add_child(path)
	path.draw.connect(_draw_path.bind(path))
	for k in Data.STAGES.size(): nodes.append(_node(k))
	# sağ panel
	var p := UI.panel(); panel = p; p.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE); p.offset_left = -420; p.offset_right = -10; p.offset_top = 10; p.offset_bottom = -10
	add_child(p)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 10); p.add_child(pv)
	var ps := ScrollContainer.new(); ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; ps.size_flags_vertical = SIZE_EXPAND_FILL; pv.add_child(ps)
	foot = HBoxContainer.new(); foot.add_theme_constant_override("separation", 10); pv.add_child(foot)
	info = VBoxContainer.new(); info.add_theme_constant_override("separation", 8); info.custom_minimum_size = Vector2(380, 0); ps.add_child(info)
	var title := UI.lbl(Data.L("SEFER HARİTASI"), 54, UI.ORANGE, true); title.position = Vector2(26, 0); add_child(title)
	var sub := UI.lbl(Data.L("TAKTİK HAREKÂT MASASI  //  15 BÖLGE"), 17, Color(0.75, 0.75, 0.78), true); sub.position = Vector2(30, 58); add_child(sub)
	add_child(UI.scanlines())
	create_tween().tween_property(self, "route_t", 1.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var back := UI.button(Data.L("GERİ"), func(): main.show_menu(), 20, 160)
	UI.at(back, PRESET_BOTTOM_LEFT, Vector2(20, -16)); add_child(back)
	sel = Save.next_stage()
	_select(sel)
	_scroll_to.call_deferred(sel)

func _pos(k: int) -> Vector2: return Vector2(XS[k] - 215.0, MAP_H - 100.0 - k * 200.0)

func _node(k: int) -> Button:
	var b := Button.new(); b.text = str(k + 1); b.custom_minimum_size = Vector2(64, 64); b.size = Vector2(64, 64)
	b.position = _pos(k) - Vector2(32, 32)
	b.add_theme_font_override("font", Data.font_bold); b.add_theme_font_size_override("font_size", 24)
	var done := k in Save.cleared
	var open := Save.stage_open(k)
	var col: Color = Color("57ff9a") if done else (UI.GOLD if open else Color(0.35, 0.38, 0.45))
	for st in ["normal", "hover", "focus", "pressed"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 30)
	for fc in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]: b.add_theme_color_override(fc, Color.WHITE if open else Color(0.45, 0.46, 0.5))
	b.mouse_entered.connect(func(): Sfx.play("click", 0.0))
	b.pressed.connect(func(): _select(k); Sfx.play("click", 0.0))
	content.add_child(b)
	var ns := Save.star_total(k)
	if ns > 0: # toplam yıldız (3 zorluk x 3)
		var sl := UI.lbl(Data.L("★ %d/9") % ns, 14, UI.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER); sl.position = _pos(k) + Vector2(-40, 34); sl.custom_minimum_size = Vector2(80, 0); content.add_child(sl)
	if open or done: # boss ikonu
		var ic := UI.pic(Data.tex(Data.BOSSES[Data.STAGES[k].boss].tex), Vector2(58, 58))
		ic.position = _pos(k) + Vector2(38, -30); content.add_child(ic)
	return b

func _draw_path(c: Control) -> void:
	var total := Data.STAGES.size() - 1
	for k in range(total):
		var vis := clampf(route_t * total - k, 0.0, 1.0) # yol açılışta aşağıdan yukarı çizilir
		if vis <= 0.0: break
		var a := _pos(k)
		var b := a.lerp(_pos(k + 1), vis)
		var on := k in Save.cleared
		var col := Color(1.0, 0.45, 0.1, 0.95) if on else Color(0.85, 0.85, 0.9, 0.35)
		var shift := fmod(t * 1.5, 2.0) if on else 0.0
		for i in 15: # akan kesikli çizgi
			var f0 := (i + shift - 1.0) / 14.0
			var f1 := (i + shift) / 14.0
			if i % 2 == 0 and f1 > 0.0 and f0 < 1.0: c.draw_line(a.lerp(b, maxf(f0, 0.0)), a.lerp(b, minf(f1, 1.0)), col, 5.0 if on else 3.0, true)
	for k in Data.STAGES.size(): # altıgen işaretçiler
		var p := _pos(k)
		var done := k in Save.cleared
		var open := Save.stage_open(k)
		var col: Color = Color(1.0, 0.45, 0.1) if done else (Color(1.0, 0.8, 0.3) if open else Color(0.3, 0.32, 0.36))
		var r := 30.0 * (1.15 if k == sel else 1.0)
		var hx := PackedVector2Array()
		for i in 7: hx.append(p + Vector2.from_angle(PI / 6 + i * PI / 3) * r)
		c.draw_colored_polygon(hx, Color(0.04, 0.03, 0.03, 0.92))
		c.draw_polyline(hx, col, 4.0 if k == sel else 2.5, true)
		if k == sel:
			var hx2 := PackedVector2Array()
			for q in hx: hx2.append(p + (q - p) * 1.28)
			c.draw_polyline(hx2, Color(col, 0.5), 1.5, true)
	var cur := _pos(Save.next_stage())
	for i in 2: # sıradaki göreve radar halkaları
		var ph := fmod(t * 0.8 + i * 0.5, 1.0)
		c.draw_arc(cur, 34.0 + ph * 50.0, 0, TAU, 40, Color(1.0, 0.6, 0.2, 0.7 * (1.0 - ph)), 2.5, true)

func _scroll_to(k: int) -> void:
	scroll.scroll_vertical = int(_pos(k).y - scroll.size.y * 0.55)

func _select(k: int) -> void:
	sel = k
	panel.modulate.a = 0.0 # bilgi paneli yeniden belirir
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.22)
	for c in info.get_children(): c.queue_free()
	var st: Dictionary = Data.STAGES[k]
	var bs: Dictionary = Data.BOSSES[st.boss]
	var done := k in Save.cleared
	var open := Save.stage_open(k)
	info.add_child(UI.lbl(Data.L("BÖLÜM %d  •  %s") % [k + 1, Data.L(st.sub)], 15, UI.DIM, true))
	info.add_child(UI.lbl(Data.L(st.name), 34, Color.WHITE if open else UI.DIM, true))
	var story := UI.lbl(Data.L(st.story) if open else Data.L("Bu bölgeye henüz ulaşamadın."), 16); story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; story.custom_minimum_size = Vector2(370, 0); info.add_child(story)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); info.add_child(h)
	var pic := UI.pic(Data.tex(bs.tex), Vector2(96, 96)); h.add_child(pic)
	if not open: pic.modulate = Color(0.05, 0.05, 0.08)
	var r := VBoxContainer.new(); r.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(r)
	r.add_child(UI.lbl(Data.L("BOSS"), 12, UI.DIM, true))
	r.add_child(UI.lbl(Data.L(bs.name) if open else "? ? ?", 19, bs.col if open else UI.DIM, true))
	r.add_child(UI.lbl(Data.L("Gelir: ") + UI.mmss(Data.boss_time(k + 1)), 13, UI.DIM))
	# tehditler
	var th := []
	if st.armor > 0: th.append(Data.L("Zırh %d") % st.armor)
	if st.bspd > 1.05: th.append(Data.L("Mermi hızı x%.2f") % st.bspd)
	if st.dens > 1.05: th.append(Data.L("Yoğunluk x%.2f") % st.dens)
	th.append(Data.L("Düşman canı x%.1f") % Data.enemy_hp_mult(k + 1))
	th.append(Data.L("Düşman hasarı x%.1f") % Data.enemy_dmg_mult(k + 1))
	info.add_child(UI.lbl(Data.L("TEHDİTLER"), 12, UI.DIM, true))
	var tl := UI.lbl("  •  ".join(th), 15, Color(2.2, 0.9, 0.7)); tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.custom_minimum_size = Vector2(370, 0); info.add_child(tl)
	var tip := UI.lbl(Data.L("İpucu: ") + Data.L(st.tip), 15, Color(0.7, 1.6, 2.0)); tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tip.custom_minimum_size = Vector2(370, 0); info.add_child(tip)
	# güç karşılaştırması
	var req := int(round(Data.REQ[k + 1]))
	var pw := Save.power()
	info.add_child(UI.lbl(Data.L("PİLOT GÜCÜ"), 12, UI.DIM, true))
	var g := UI.lbl(Data.L("Önerilen: %d   •   Senin: %d") % [req, pw], 20, Color(0.6, 2.4, 1.0) if pw >= req else Color(2.4, 0.8, 0.6), true); info.add_child(g)
	var b := UI.bar(370, 10, Color(0.4, 2.0, 0.9) if pw >= req else Color(2.2, 0.8, 0.5)); b.value = clampf(float(pw) / maxf(1.0, req), 0.0, 1.0); info.add_child(b)
	if pw < req: info.add_child(UI.lbl(Data.L("Gücün yetersiz: denemeye devam et, her uçuş puan kazandırır."), 13, UI.DIM))
	if Save.tree_points() > 0: info.add_child(UI.lbl(Data.L("Harcanmamış %d pilot puanın var!") % Save.tree_points(), 15, UI.GOLD, true))
	info.add_child(UI.lbl(Data.L("Deneme: %d   •   %s") % [Save.tries_of(k), Data.L("✔ GEÇİLDİ (tekrar: %25 puan)") if done else (Data.L("▶ SIRADAKİ GÖREV") if open else Data.L("KİLİTLİ"))], 15, Color("57ff9a") if done else (UI.GOLD if open else UI.DIM), true))
	for p in Data.PLANES:
		if p.unlock == k + 1: info.add_child(UI.lbl(Data.L("Ödül: %s uçağı (%s)") % [Data.L(p.name), Data.L(p.trait)], 15, p.color, true))
	# zorluk ve yıldızlar
	if not Save.diff_open(k, diff_sel): diff_sel = 0
	info.add_child(UI.lbl(Data.L("ZORLUK"), 12, UI.DIM, true))
	var dh := HBoxContainer.new(); dh.add_theme_constant_override("separation", 6); info.add_child(dh)
	for d in Data.DIFF.size():
		var dd: Dictionary = Data.DIFF[d]
		var db := Button.new(); db.text = Data.L(dd.name); db.custom_minimum_size = Vector2(118, 40); db.disabled = not Save.diff_open(k, d)
		db.add_theme_font_override("font", Data.font_bold); db.add_theme_font_size_override("font_size", 18)
		db.add_theme_stylebox_override("normal", UI.box(Color(0.03, 0.05, 0.08, 0.9), Color(dd.col, 0.9 if d == diff_sel else 0.25), 6, 3 if d == diff_sel else 1))
		db.add_theme_stylebox_override("hover", UI.box(Color(0.06, 0.1, 0.14, 0.95), dd.col, 6, 2))
		db.add_theme_stylebox_override("disabled", UI.box(Color(0.02, 0.02, 0.03, 0.8), Color(0.3, 0.3, 0.35, 0.3), 6, 1))
		db.add_theme_color_override("font_color", dd.col if d == diff_sel else Color(0.75, 0.76, 0.8))
		db.pressed.connect(func(): diff_sel = d; Sfx.play("click", 0.0); _select(k))
		dh.add_child(db)
	if diff_sel > 0: info.add_child(UI.lbl(Data.L("Düşman canı x%.1f, hasarı x%.2f  •  puan x%.1f") % [Data.DIFF[diff_sel].hp, Data.DIFF[diff_sel].dmg, Data.DIFF[diff_sel].pts], 13, Data.DIFF[diff_sel].col))
	elif done and not Save.diff_open(k, 2): info.add_child(UI.lbl(Data.L("KÂBUS: bölümü ZOR'da geçince açılır"), 13, UI.DIM))
	var have: Array = Save.stars_of(k, diff_sel)
	for s in 3: info.add_child(UI.lbl(("★ " if have[s] else "☆ ") + Data.L(Data.STARS[s]) + ("" if have[s] else Data.L("   (+%.1f puan)") % Data.STAR_PTS), 15, UI.GOLD if have[s] else UI.DIM, true))
	for c in foot.get_children(): c.queue_free()
	var hb := foot
	var os := Data.op_start(k)
	info.add_child(UI.lbl(Data.L("HAREKÂT %d: BÖLÜM %d-%d  •  build 3 bölüm boyunca taşınır, harekât her zaman ilk bölümünden başlar") % [k / Data.OP_LEN + 1, os + 1, os + Data.OP_LEN], 13, UI.CYAN, true))
	var fly := UI.button(Data.L("UÇ  ▶") if os == k else Data.L("HAREKÂT  ▶"), func(): main.start_game(Data.op_start(sel), false, diff_sel if Save.diff_open(Data.op_start(sel), diff_sel) else 0), 24, 220); fly.disabled = not Save.stage_open(os) and not open; hb.add_child(fly)
	hb.add_child(UI.button(Data.L("AĞAÇ"), func(): main.show_tree(), 18, 150))
	if open: fly.grab_focus.call_deferred()
	for c in info.get_children(): # askeri şablon fontu geniş: uzun satırlar panelden taşmasın
		if c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF: c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; c.custom_minimum_size.x = 370

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"): main.show_menu()

func _process(dt: float) -> void:
	t += dt
	content.get_child(1).queue_redraw()
	for k in nodes.size():
		var n: Button = nodes[k]
		n.scale = Vector2.ONE * (1.12 if k == sel else 1.0)
		n.pivot_offset = Vector2(32, 32)
