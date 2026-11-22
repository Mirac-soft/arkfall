extends Node
## Ses efektleri (havuzlu) ve döngüsel müzik

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var last := {}
var music: AudioStreamPlayer
var music_name := ""
const THROTTLE := {"shoot": 0.06, "hit": 0.04, "gem": 0.03, "boom": 0.05, "zap": 0.1, "missile": 0.1}
const VOL := {"shoot": -14.0, "hit": -12.0, "gem": -14.0, "boom": -6.0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new(); add_child(p); pool.append(p)
	music = AudioStreamPlayer.new(); music.volume_db = -8.0; add_child(music)
	music.finished.connect(func(): if music_name != "": music.play()) # döngü
	set_volume(Save.volume)

## Genel ses yüzdesi: ana veri yolunun seviyesi (algıya yakın olsun diye karesel)
func set_volume(pct: int) -> void:
	AudioServer.set_bus_mute(0, pct <= 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(pow(pct / 100.0, 2.0)) if pct > 0 else -80.0)

func stream_of(name: String) -> AudioStream:
	if not streams.has(name): streams[name] = load("res://audio/%s.wav" % name)
	return streams[name]

func play(name: String, pitch_var := 0.08) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last.get(name, -9.0) < THROTTLE.get(name, 0.0): return
	last[name] = now
	for p in pool:
		if not p.playing:
			p.stream = stream_of(name); p.volume_db = VOL.get(name, -4.0)
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play(); return

## Müzik geçişi: eski parça kısılarak biter, yenisi yükselerek başlar (kesinti hissi yok)
func play_music(name: String) -> void:
	if name == music_name: return
	music_name = name
	var tw := create_tween()
	if music.playing: tw.tween_property(music, "volume_db", -40.0, 0.6)
	tw.tween_callback(func():
		if name == "": music.stop(); return
		music.stream = stream_of(name); music.volume_db = -40.0; music.play())
	if name != "": tw.tween_property(music, "volume_db", -8.0, 0.9)
