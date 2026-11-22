extends Control
## Kişisel rekorlar: sefer (skora göre) ve sonsuz mod (dayanma süresine göre). Dünya sıralaması Steam aşamasında.

const UI = preload("res://scripts/ui.gd")
var main
var sky_mat: ShaderMaterial
var t := 0.0
var panel: PanelContainer
var tabs: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sky := UI.sky(12); add_child(sky); sky_mat = sky.material
	var title := UI.lbl(Data.L("REKORLAR"), 54, Color(2.4, 2.0, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_and_offsets_preset(PRESET_TOP_WIDE); title.offset_top = 20; title.offset_bottom = 100
	add_child(title)
	var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 20)
	UI.at(tb, PRESET_CENTER_TOP, Vector2(0, 100)); add_child(tb)
	for m in [[Data.L("SEFER"), "sefer"], [Data.L("SONSUZ MOD"), "endless"]]:
		var b := UI.button(m[0], _show.bind(m[1]), 22, 240); tb.add_child(b); tabs.append(b)
	panel = UI.panel(); panel.custom_minimum_size = Vector2(960, 0)
	UI.at(panel, PRESET_CENTER_TOP, Vector2(0, 170)); add_child(panel)
	var back := UI.button(Data.L("GERİ"), func(): main.show_menu(), 22, 200)
	UI.at(back, PRESET_BOTTOM_LEFT, Vector2(30, -24)); add_child(back)
	_show("endless" if Save.records.is_empty() and not Save.endless.is_empty() else "sefer")
	tabs[0].grab_focus.call_deferred()

func _show(mode: String) -> void:
	for c in panel.get_children(): c.queue_free()
	var endless := mode == "endless"
	var rows: Array = Save.endless if endless else Save.records
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); panel.add_child(v)
	v.add_child(UI.lbl(Data.L("En uzun 10 dayanış  •  her dalgada düşmanlar güçlenir") if endless else Data.L("Kişisel en iyi 10 uçuş  •  Dünya sıralaması Steam sürümünde"), 15, UI.DIM))
	if rows.is_empty():
		v.add_child(UI.lbl(Data.L("Henüz kayıt yok. Göklere çık, pilot!"), 20, UI.DIM)); return
	var heads := ["#", Data.L("DAYANMA"), Data.L("DALGA"), Data.L("DÜŞÜRÜLEN"), Data.L("SKOR"), Data.L("UÇAK"), Data.L("TARİH")] if endless else ["#", Data.L("SKOR"), Data.L("SÜRE"), Data.L("DÜŞÜRÜLEN"), Data.L("SEVİYE"), Data.L("UÇAK"), Data.L("TARİH")]
	var g := GridContainer.new(); g.columns = heads.size(); g.add_theme_constant_override("h_separation", 34); g.add_theme_constant_override("v_separation", 10); v.add_child(g)
	for h in heads: g.add_child(UI.lbl(h, 13, UI.DIM, true))
	for k in rows.size():
		var r: Dictionary = rows[k]
		var c := UI.GOLD if k == 0 else (Color.WHITE if k < 3 else UI.DIM)
		var cells := [str(k + 1), UI.mmss(r.get("time", 0)), str(int(r.get("wave", 1))), str(int(r.get("kills", 0))), str(int(r.get("score", 0))), str(r.get("plane", "-")), str(r.get("date", ""))] if endless else \
			[str(k + 1), str(int(r.get("score", 0))), UI.mmss(r.get("time", 0)) + (" ★" if r.get("won", false) else ""), str(int(r.get("kills", 0))), str(int(r.get("lvl", 1))), str(r.get("plane", "-")), str(r.get("date", ""))]
		for s in cells: g.add_child(UI.lbl(s, 18, c, k < 3))

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"): main.show_menu()

func _process(dt: float) -> void:
	t += dt
	sky_mat.set_shader_parameter("cam", Vector2(-t * 20.0, -t * 40.0))
	sky_mat.set_shader_parameter("view_size", get_viewport_rect().size)
