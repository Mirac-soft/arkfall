extends Node
## Ekran yöneticisi + geliştirici argümanları
## Geliştirici: godot --path . -- --scene=game --auto --time=170 --frames=600 --shot=out.png --plane=anka

const MenuS = preload("res://scripts/menu.gd")
const HangarS = preload("res://scripts/hangar.gd")
const RecordsS = preload("res://scripts/records.gd")
const GameS = preload("res://scripts/game.gd")
const CineS = preload("res://scripts/cine.gd")
const StagesS = preload("res://scripts/stages.gd")
const TreeS = preload("res://scripts/tree.gd")
const StudioS = preload("res://scripts/studio.gd")
const CodexS = preload("res://scripts/codex.gd")
const LockerS = preload("res://scripts/locker.gd")

var cur: Node
var dev := {}
var frame := 0
var ui_layer: CanvasLayer
var sh_top: Control
var sh_bot: Control
var swapping := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	we.environment = e
	add_child(we)
	ui_layer = CanvasLayer.new(); add_child(ui_layer) # menü ekranları ekran boyutunu buradan alır
	_build_shutter()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		dev[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# test: kozmetik  --tokens (5'er jeton)  --own (bütün parçalar)  --wear=boya,iz,alev,arma (sıra; -1 boş)
	if dev.has("tokens"):
		for p in Data.PLANES: Save.tokens[p.id] = {"g": 5, "o": 5, "r": 5}
	if dev.has("own"):
		for p in Data.PLANES: Save.owned[p.id] = range(Data.COSMETICS[p.id].size())
	if dev.has("wear"):
		var w: PackedStringArray = str(dev.wear).split(",")
		for p in Data.PLANES:
			var eq := {}
			for k in mini(w.size(), 4):
				if int(w[k]) >= 0: eq[Data.COS_SLOTS[k]] = int(w[k])
			Save.equip[p.id] = eq
	match dev.get("scene", "menu"):
		"game": start_game()
		"endless": start_endless()
		"hangar": show_hangar()
		"locker": show_locker()
		"records": show_records()
		"stages": show_stages()
		"tree": show_tree()
		"studio": swap(StudioS.new())
		"codex":
			if dev.has("seenall"): # test: bütün kayıtlar açık
				for id in Data.ENEMIES.keys() + Data.BOSSES.keys(): Save.seen[id] = 3
			show_codex()
		"cine":
			if dev.has("kind"): # test: tek çekim  --kind=cine_flyover --boss=oncu --i=1
				var c = CineS.new(); c.slides = [{"img": dev.kind, "text": "test"}, {"img": dev.kind, "text": "test"}]; c.done = show_menu; c.key = dev.get("boss", ""); c.i = int(dev.get("i", "0")) - 1
				swap(c)
			else: play_cine(dev.get("cine", "intro"), show_menu)
		_:
			if Save.seen_intro or not dev.is_empty(): show_menu()
			else: play_cine("intro", _after_intro) # ilk açılışta hikaye fragmanı

func _process(dt: float) -> void:
	frame += 1
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.2 and DisplayServer.get_name() != "headless":
		var mp := get_viewport().get_mouse_position() + rs * 900.0 * dt
		get_viewport().warp_mouse(mp)
	if dev.has("log") and frame % 600 == 0 and cur and "kills" in cur:
		print("DEV t=%.0f lvl=%d kills=%d dusman=%d mermi=%d kristal=%d boss=%d hp=%.0f silah=%s islem=%.1fms bosshp=%s dalga=%d" % [cur.t, cur.lvl, cur.kills,
			cur.enemies.size(), cur.ebs.size(), cur.gems.size(), cur.bosses_killed, cur.hp, str(cur.weapons.keys()),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, str(cur.bosses.map(func(b): return [b.kind, int(b.hp), int(b.position.distance_to(cur.player.position))])), cur.wave + 1])
	if dev.has("fps") and frame % 120 == 0: print("FPS ", Engine.get_frames_per_second(), " draw ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " ms ", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if dev.has("frames") and frame == int(dev.frames):
		if dev.has("shot"): get_viewport().get_texture().get_image().save_png(dev.shot)
		get_tree().quit()

## Gamepad: sağ çubuk fare imlecini sürer, RT sol tık (harita ve ağaç gibi serbest ekranlar için)
func _input(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.4): Data.pad = true
	elif ev is InputEventMouseMotion and ev.relative.length() > 2.0 and not ev.has_meta("pad"): Data.pad = false
	if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_TRIGGER_RIGHT:
		var down: bool = ev.axis_value > 0.6
		if down != rt_down:
			rt_down = down
			var c := InputEventMouseButton.new(); c.button_index = MOUSE_BUTTON_LEFT; c.pressed = down
			c.position = get_viewport().get_mouse_position(); c.global_position = c.position
			Input.parse_input_event(c)

var rt_down := false

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

## Ekran geçişi: üstten ve alttan kepenk kapanır, ekran değişir, kepenk açılır
func swap(n: Node, xfade := false) -> void:
	if cur == null or dev.has("frames"): _do_swap(n); return
	if xfade: _xfade(n); return
	if swapping: return
	swapping = true
	await _shutter(true)
	_do_swap(n)
	await _shutter(false)
	swapping = false

## Çapraz geçiş (oyun <-> ara sahne): son kare yakalanır, yeni sahnenin üstünde yavaşça erir. Siyah ekran yok.
func _xfade(n: Node) -> void:
	if swapping: return
	swapping = true
	var shot := TextureRect.new(); shot.texture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	shot.set_anchors_preset(Control.PRESET_FULL_RECT); shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh_top.get_parent().add_child(shot)
	_do_swap(n)
	var tw := shot.create_tween(); tw.tween_property(shot, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE); tw.tween_callback(shot.queue_free)
	await tw.finished
	swapping = false

func _build_shutter() -> void:
	var l := CanvasLayer.new(); l.layer = 100; add_child(l)
	for top in [true, false]:
		var p := ColorRect.new(); p.color = Color(0.03, 0.03, 0.04); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		var e := ColorRect.new(); e.color = Color(1.0, 0.42, 0.1); e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if top else Control.PRESET_TOP_WIDE)
		if top: e.offset_top = -3
		else: e.offset_bottom = 3
		p.add_child(e); l.add_child(p)
		if top: sh_top = p
		else: sh_bot = p
	_place_shutter(0.0)

func _place_shutter(k: float) -> void:
	var h := get_viewport().get_visible_rect().size.y / 2.0 + 2.0
	sh_top.offset_top = -h + h * k; sh_top.offset_bottom = h * k
	sh_bot.offset_bottom = h - h * k; sh_bot.offset_top = h - h * k - h

func _shutter(close: bool) -> void:
	var tw := create_tween()
	tw.tween_method(_place_shutter, 0.0 if close else 1.0, 1.0 if close else 0.0, 0.16 if close else 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN if close else Tween.EASE_OUT)
	if close: Sfx.play("dash", 0.0)
	await tw.finished

func _do_swap(n: Node) -> void:
	Data.use_fonts("game" if n is GameS else "menu") # menü: askeri şablon, oyun içi: dijital
	get_tree().paused = false
	if cur: cur.queue_free()
	cur = n
	n.set("main", self)
	if n is Control: ui_layer.add_child(n)
	else: add_child(n)

func show_menu() -> void: swap(MenuS.new())
func show_hangar() -> void: swap(HangarS.new())
func show_records() -> void: swap(RecordsS.new())
func show_stages() -> void: swap(StagesS.new())
func show_tree() -> void: swap(TreeS.new())
func show_codex() -> void: swap(CodexS.new())
func show_locker() -> void: swap(LockerS.new())
func play_cine(key: String, then: Callable) -> void:
	var c = CineS.new(); c.slides = Data.CINE[key]; c.done = then; c.key = key
	swap(c, true)
func _after_intro() -> void:
	Save.seen_intro = true; Save.write(); show_menu()

func start_endless() -> void:
	var g = GameS.new(); g.dev = dev; g.endless = true; g.stage = 0
	swap(g)

func start_game(stage := -1, chain := false, diff := 0, carry := {}) -> void:
	var g = GameS.new()
	g.dev = dev; g.chain = chain or dev.has("chain"); g.diff = int(dev.get("diff", diff)); g.carry = carry
	g.stage = int(dev.get("stage", Save.next_stage())) if stage < 0 else stage
	swap(g, chain) # ara sahneden sonraki bölüme: çapraz geçiş
