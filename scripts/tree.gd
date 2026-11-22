extends Control
## Pilot Ağacı (Path of Exile tarzı kalıcı yetenek ağı)

const UI = preload("res://scripts/ui.gd")
const R := {"start": 18.0, "small": 9.0, "notable": 15.0, "keystone": 20.0}
var main
var hover := ""
var center := Vector2.ZERO
var sc := 1.0
var t := 0.0
var tip: PanelContainer
var tip_name: Label
var tip_kind: Label
var tip_txt: Label
var pts_lbl: Label
var sum_lbl: Label
var sky_mat: ShaderMaterial
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var view: Control # ağaç bunun üstüne çizilir (arka planın önünde)

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sky := UI.sky(12); add_child(sky); sky_mat = sky.material
	var dim := ColorRect.new(); dim.color = Color(0, 0.01, 0.04, 0.55); dim.set_anchors_preset(PRESET_FULL_RECT); dim.mouse_filter = MOUSE_FILTER_IGNORE; add_child(dim)
	add_child(UI.girih(0.04))
	view = Control.new(); view.set_anchors_preset(PRESET_FULL_RECT); view.mouse_filter = MOUSE_FILTER_STOP; add_child(view)
	view.draw.connect(_paint); view.gui_input.connect(_view_input)
	var title := UI.lbl(Data.L("PİLOT AĞACI"), 44, Color(2.2, 1.9, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_and_offsets_preset(PRESET_TOP_WIDE); title.offset_top = 10; title.offset_bottom = 70; add_child(title)
	pts_lbl = UI.lbl("", 18, UI.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	pts_lbl.set_anchors_and_offsets_preset(PRESET_TOP_WIDE); pts_lbl.offset_top = 64; pts_lbl.offset_bottom = 92; add_child(pts_lbl)
	sum_lbl = UI.lbl("", 14, UI.DIM)
	sum_lbl.position = Vector2(24, 110); add_child(sum_lbl)
	var back := UI.button(Data.L("GERİ"), func(): main.show_menu(), 22, 200)
	UI.at(back, PRESET_BOTTOM_LEFT, Vector2(24, -20)); add_child(back)
	var go := UI.button(Data.L("SEFER HARİTASI"), func(): main.show_stages(), 22, 280)
	UI.at(go, PRESET_BOTTOM_RIGHT, Vector2(-24, -20)); add_child(go)
	var reset := UI.button(Data.L("SIFIRLA (ücretsiz)"), _reset, 18, 240)
	UI.at(reset, PRESET_TOP_RIGHT, Vector2(-24, 20)); add_child(reset)
	tip = UI.panel(); tip.visible = false; tip.z_index = 10; add_child(tip)
	var tv := VBoxContainer.new(); tip.add_child(tv)
	tip_name = UI.lbl("", 20, Color.WHITE, true); tv.add_child(tip_name)
	tip_kind = UI.lbl("", 12, UI.DIM, true); tv.add_child(tip_kind)
	tip_txt = UI.lbl("", 16); tv.add_child(tip_txt)
	_refresh()

func _refresh() -> void:
	pts_lbl.text = Data.L("Harcanabilir puan: %d      (her uçuş puan kazandırır • tekerlek: yakınlaş • sürükle: kaydır)") % Save.tree_points()
	var lines := Data.stat_lines(Data.tree_stats(Save.tree))
	sum_lbl.text = Data.L("TOPLAM BONUSLAR\n") + ("\n".join(lines) if lines.size() else Data.L("Henüz yok"))
	view.queue_redraw()

func _reset() -> void:
	Save.tree.clear(); Save.write(); _refresh()

func _pos(id: String) -> Vector2: return center + Data.TREE[id].pos * sc

## Ağaç uçağın "beyni" gibi: tepeden uçak silüeti içinde devre kartı, merkezde işlemci çipi,
## bağlantılar devre yolu; alınan yollarda merkezden dışarı akan yumuşak ışık darbeleri. Renkler bilerek sönük (göz yormasın).
const JET := [[0, -820], [70, -560], [95, -180], [520, 120], [1150, 330], [1150, 420], [110, 330], [120, 560], [430, 720], [430, 790], [70, 760], [0, 820]]
func _paint() -> void:
	var size := view.size
	center = size / 2.0 + Vector2(40, 24) + pan
	sc = minf((size.x - 300.0) / 2300.0, (size.y - 170.0) / 1560.0) * zoom
	var taken: Array = Save.tree
	# uçak gövdesi (iki yarım simetrik)
	var body := PackedVector2Array()
	for q in JET: body.append(center + Vector2(q[0], q[1]) * sc)
	for i in range(JET.size() - 2, 0, -1): body.append(center + Vector2(-JET[i][0], JET[i][1]) * sc)
	view.draw_colored_polygon(body, Color(0.05, 0.09, 0.11, 0.85))
	view.draw_polyline(body + PackedVector2Array([body[0]]), Color(0.25, 0.55, 0.6, 0.35), 2.0, true)
	for i in 14: # devre kartı ızgarası (çok sönük)
		var y := center.y + (-760.0 + i * 120.0) * sc
		view.draw_line(Vector2(center.x - 1150.0 * sc, y), Vector2(center.x + 1150.0 * sc, y), Color(0.3, 0.6, 0.65, 0.04), 1.0)
	# devre yolları
	for id in Data.TREE:
		for l in Data.TREE[id].links:
			if id > l: continue
			var a_on: bool = id == "start" or id in taken
			var b_on: bool = l == "start" or l in taken
			var pa := _pos(id); var pb := _pos(l)
			if (Data.TREE[id].pos as Vector2).length() > (Data.TREE[l].pos as Vector2).length(): var tmp := pa; pa = pb; pb = tmp # akış merkezden dışarı
			view.draw_line(pa, pb, Color(0.02, 0.04, 0.05, 0.9), 6.0, true) # yol yatağı
			if a_on and b_on:
				view.draw_line(pa, pb, Color(0.95, 0.7, 0.35, 0.55), 2.5, true)
				var ln := pa.distance_to(pb)
				for k in maxi(1, int(ln / 120.0)): # kablodan geçen ışık
					var u := fmod(t * 140.0 / maxf(ln, 1.0) + k / maxf(1.0, int(ln / 120.0)) + pa.x * 0.001, 1.0)
					var q := pa.lerp(pb, u)
					view.draw_circle(q, 5.0, Color(1.0, 0.8, 0.45, 0.12)); view.draw_circle(q, 2.2, Color(1.1, 0.95, 0.7, 0.75))
			elif a_on or b_on: view.draw_line(pa, pb, Color(0.35, 0.6, 0.7, 0.4), 2.0, true)
			else: view.draw_line(pa, pb, Color(0.25, 0.3, 0.34, 0.35), 1.5, true)
	for id in Data.TREE:
		var n: Dictionary = Data.TREE[id]
		var p := _pos(id); var r: float = R[n.kind] * clampf(sc * 1.4, 0.8, 1.3)
		var on: bool = id == "start" or id in taken
		var can := Save.can_take(id)
		var col: Color = n.col
		if n.kind == "start": # merkez: işlemci çipi
			var cs := r * 1.6
			view.draw_rect(Rect2(p - Vector2(cs, cs), Vector2(cs, cs) * 2.0), Color(0.08, 0.1, 0.12), true)
			view.draw_rect(Rect2(p - Vector2(cs, cs), Vector2(cs, cs) * 2.0), Color(0.6, 0.75, 0.8, 0.6), false, 2.0)
			for i in 5: for sgn in [-1.0, 1.0]: # bacaklar
				var o := -cs * 0.7 + i * cs * 0.35
				view.draw_line(p + Vector2(o, sgn * cs), p + Vector2(o, sgn * (cs + 7.0)), Color(0.6, 0.65, 0.7, 0.7), 2.0)
				view.draw_line(p + Vector2(sgn * cs, o), p + Vector2(sgn * (cs + 7.0), o), Color(0.6, 0.65, 0.7, 0.7), 2.0)
			view.draw_circle(p, cs * 0.45, Color(1.0, 0.75, 0.4, 0.35 + 0.15 * sin(t * 2.0))); continue
		if can: view.draw_arc(p, r + 4 + 1.5 * sin(t * 3.0), 0, TAU, 32, Color(col, 0.6), 1.5, true)
		var fill: Color = Color(col.r * 0.85, col.g * 0.85, col.b * 0.85) if on else (Color(col, 0.22) if can else Color(0.08, 0.1, 0.12))
		if n.kind == "small": view.draw_circle(p, r, fill)
		else: # önemli ve anahtar düğümler: altıgen lehim pedi
			var hx := PackedVector2Array()
			for i in 6: hx.append(p + Vector2.from_angle(PI / 6 + i * PI / 3) * r * 1.1)
			view.draw_colored_polygon(hx, fill); view.draw_polyline(hx + PackedVector2Array([hx[0]]), Color(col, 0.7) if on else Color(0.4, 0.45, 0.5, 0.7), 1.5, true)
		view.draw_arc(p, r, 0, TAU, 32, Color(0.9, 0.95, 1.0) if id == hover else (Color(1, 0.85, 0.5, 0.7) if on else Color(0.38, 0.42, 0.48, 0.8)), 1.5, true)
	for br in Data.TREE_BRANCHES:
		var d := Vector2(cos(br.ang) * 1.35, sin(br.ang) * 0.9)
		var lp := center + d * 250.0 * sc + Vector2(-90, 0)
		view.draw_string(Data.font_bold, lp + d.normalized() * 30.0 * sc + Vector2(0, 6), Data.L(br.name), HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Color(br.col, 0.75))

func _node_at(pos: Vector2) -> String:
	for id in Data.TREE:
		if pos.distance_to(_pos(id)) < R[Data.TREE[id].kind] * clampf(sc * 1.4, 0.8, 1.3) + 5: return id
	return ""

func _view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var old := zoom
		zoom = clampf(zoom * (1.15 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.7, 3.5)
		var c0 := view.size / 2.0 + Vector2(40, 24)
		pan = (pan + c0 - e.position) * (zoom / old) - c0 + e.position # imlecin altındaki nokta sabit kalsın
		view.queue_redraw(); return
	if e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and hover == ""):
		dragging = e.pressed
	if e is InputEventMouseMotion and dragging:
		pan += e.relative; view.queue_redraw(); return
	if e is InputEventMouseMotion:
		var h := _node_at(e.position)
		if h != hover: hover = h; _tip(); view.queue_redraw()
		if tip.visible: tip.position = (e.position + Vector2(18, 18)).clamp(Vector2.ZERO, size - tip.size)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and hover != "":
		if Save.can_take(hover):
			Save.tree.append(hover); Save.write(); Sfx.play("card", 0.0); _refresh(); _tip()
		else: Sfx.play("click", 0.0)

func _tip() -> void:
	tip.visible = hover != ""
	if hover == "": return
	var n: Dictionary = Data.TREE[hover]
	tip_name.text = Data.L(n.name)
	tip_name.add_theme_color_override("font_color", n.col)
	tip_kind.text = {"start": Data.L("BAŞLANGIÇ"), "small": Data.L("KÜÇÜK DÜĞÜM"), "notable": Data.L("ÖNEMLİ DÜĞÜM"), "keystone": Data.L("ANAHTAR TAŞ — güçlü ama bedeli var")}[n.kind]
	var lines := Data.stat_lines(n.stats)
	var state := Data.L("✔ ALINDI") if (hover == "start" or hover in Save.tree) else (Data.L("Tıkla: al") if Save.can_take(hover) else (Data.L("Puan yok") if Save.tree_points() <= 0 else Data.L("Önce bağlı bir düğümü al")))
	tip_txt.text = "\n".join(lines) + ("\n\n" if lines.size() else "") + state
	tip.reset_size()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"): main.show_menu()

func _process(dt: float) -> void:
	t += dt
	sky_mat.set_shader_parameter("cam", Vector2(t * 10.0, -t * 20.0))
	sky_mat.set_shader_parameter("view_size", get_viewport_rect().size)
	view.queue_redraw()
