extends Node
## Kalıcı kayıt (user://save.json): rütbe XP, pilot puanı, geçilen bölümler, deneme sayıları, ağaç, uçak, rekorlar

const PATH := "user://save.json"
var xp := 0
var sp := 0.0                # uçuşlardan kazanılan pilot puanı (kesirli birikir)
var plane := "serce"
var records: Array = []
var endless: Array = []      # sonsuz mod rekorları (en uzun dayanma süresine göre)
var cleared: Array = []      # geçilen bölüm indeksleri (0'dan)
var attempts := {}           # "bölüm" -> deneme sayısı
var tree: Array = []
var seen_intro := false
var volume := 80              # genel ses yüzdesi (0 = kapalı)
var lang := ""               # boşsa ilk açılışta sistem dili
var hints := true            # oyun içinde alttaki tuş ipuçları
var tutorial_done := false   # ilk uçuştaki mini eğitim görüldü/geçildi
var seen := {}               # Defter: tür / boss -> düşürülen sayısı (ilk düşürüşte kilit açılır)
var stars := {}              # "bölüm:zorluk" -> [geç, kapsüller, boss'a hasarsız]
var mastery := {}            # uçak -> ustalık XP (Data.MASTERY)
var fx_alpha := 100          # efekt opaklığı % (oyuncu uçağı kalabalıkta görünsün)
var dmg_nums := 1            # hasar sayıları: 0 kapalı, 1 sadece kritik, 2 hepsi
var bg3d := true             # oyun içinde 3D arka plan (zayıf ekran kartında kapatılabilir)
var tokens := {}             # kozmetik: uçak -> {"g": n, "o": n, "r": n} jeton
var owned := {}              # uçak -> [parça sırası] (Data.COSMETICS)
var equip := {}              # uçak -> {"boya": sıra, "iz": ..., "alev": ..., "arma": ...}
var scrap := {}              # uçak -> hurda (aynı parça çıkınca)
var dry := {}                # uçak -> 4+ çıkmadan açılan kapsül sayısı (garanti)
var skin_match := true       # iz ve alev rengi boyaya uysun
var campaign_gift := false   # seferi ilk bitiriş hediyesi verildi mi
var heard := {}              # telsiz havuzu -> son duyulan replik indeksleri (tekrar etmesin)

func _ready() -> void:
	_load()
	var code := lang if lang != "" else Data.system_lang()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="): code = a.trim_prefix("--lang=") # test
	Data.set_lang(code)

func _load() -> void:
	# oyunun adı Gökkalkan -> ARKFALL oldu; Godot kayıt klasörü de değişti, eski kaydı bir kez taşı
	var old := OS.get_data_dir() + "/Godot/app_userdata/Gökkalkan/save.json"
	if not FileAccess.file_exists(PATH) and FileAccess.file_exists(old): DirAccess.copy_absolute(old, ProjectSettings.globalize_path(PATH))
	if not FileAccess.file_exists(PATH): return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null: return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return # bozuk kayıt: varsayılanlarla devam
	xp = maxi(0, int(d.get("xp", 0)))
	sp = maxf(0.0, float(d.get("sp", 0.0)))
	plane = str(d.get("plane", "serce"))
	seen_intro = bool(d.get("seen_cine", false))
	volume = clampi(int(d.get("volume", 80 if bool(d.get("sound", true)) else 0)), 0, 100) # eski kayıt: açık/kapalı
	lang = str(d.get("lang", ""))
	hints = bool(d.get("hints", true))
	tutorial_done = bool(d.get("tutorial", false))
	var sd = d.get("stars", {})
	if typeof(sd) == TYPE_DICTIONARY:
		for k in sd:
			if typeof(sd[k]) == TYPE_ARRAY and sd[k].size() == 3: stars[str(k)] = sd[k].map(func(x): return bool(x))
	var sn = d.get("seen", {})
	if typeof(sn) == TYPE_DICTIONARY:
		for k in sn: seen[str(k)] = int(sn[k])
	var ms = d.get("mastery", {})
	if typeof(ms) == TYPE_DICTIONARY:
		for k in ms: mastery[str(k)] = maxi(0, int(ms[k]))
	fx_alpha = clampi(int(d.get("fx_alpha", 100)), 20, 100)
	dmg_nums = clampi(int(d.get("dmg_nums", 1)), 0, 2)
	bg3d = bool(d.get("bg3d", true))
	for k in ["tokens", "owned", "equip", "scrap", "dry"]:
		var v = d.get(k, {})
		if typeof(v) == TYPE_DICTIONARY: set(k, _clean_cos(k, v))
	skin_match = bool(d.get("skin_match", true))
	campaign_gift = bool(d.get("campaign_gift", false))
	var hd = d.get("heard", {})
	if typeof(hd) == TYPE_DICTIONARY: heard = hd
	for r in d.get("endless", []):
		if typeof(r) == TYPE_DICTIONARY and r.has("time"): endless.append(r)
	for r in d.get("records", []):
		if typeof(r) == TYPE_DICTIONARY and r.has("score"): records.append(r)
	for c in d.get("cleared", []):
		if int(c) not in cleared and int(c) < Data.STAGES.size(): cleared.append(int(c))
	var at = d.get("attempts", {})
	if typeof(at) == TYPE_DICTIONARY:
		for k in at: attempts[str(k)] = int(at[k])
	for n in d.get("tree", []):
		if Data.TREE.has(str(n)) and str(n) not in tree: tree.append(str(n))
	while tree_points() < 0: tree.pop_back() # eski/bozuk kayıtta fazla düğüm varsa bırak
	if not unlocked(Data.plane(plane)): plane = "serce" # eski sistemde açılmış ama artık kilitli uçak

func write() -> void:
	if not OS.get_cmdline_user_args().is_empty(): return # geliştirici testleri gerçek kaydı bozmasın
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"xp": xp, "sp": sp, "plane": plane, "records": records, "cleared": cleared,
		"attempts": attempts, "tree": tree, "seen_cine": seen_intro, "volume": volume, "lang": lang, "hints": hints, "tutorial": tutorial_done, "heard": heard, "stars": stars, "seen": seen, "endless": endless, "mastery": mastery, "fx_alpha": fx_alpha, "dmg_nums": dmg_nums, "bg3d": bg3d, "tokens": tokens, "owned": owned, "equip": equip, "scrap": scrap, "dry": dry, "skin_match": skin_match, "campaign_gift": campaign_gift}))

func level() -> int: return Data.rank_info(xp).level
func unlocked(p: Dictionary) -> bool: return p.unlock == 0 or (p.unlock - 1) in cleared

func next_stage() -> int:
	for i in Data.STAGES.size():
		if i not in cleared: return i
	return Data.STAGES.size() - 1
func stage_open(i: int) -> bool: return i in cleared or i == next_stage()
func tries_of(i: int) -> int: return attempts.get(str(i), 0)

func stars_of(i: int, d: int) -> Array: return stars.get("%d:%d" % [i, d], [false, false, false])
func star_total(i: int) -> int:
	var n := 0
	for d in Data.DIFF.size(): n += stars_of(i, d).count(true)
	return n
func diff_open(i: int, d: int) -> bool:
	match d:
		0: return stage_open(i)
		1: return i in cleared
		_: return stars_of(i, 1)[0]
## Uçuşta kazanılan yıldızları işler; yeni yıldız sayısını döner (her biri pilot puanı verir)
func add_stars(i: int, d: int, got: Array) -> int:
	var cur := stars_of(i, d).duplicate()
	var n := 0
	for k in 3:
		if got[k] and not cur[k]: cur[k] = true; n += 1
	stars["%d:%d" % [i, d]] = cur
	sp += n * Data.STAR_PTS
	write()
	return n

## Uçuş sonu: pilot puanı ver. Sıradaki bölüm tam değer, geçilmiş bölüm %25. İlk geçişte +2.
func award(i: int, progress: float, won: bool, diff := 0) -> float:
	var k := i + 1
	var first := won and i not in cleared
	var rate: float = (1.0 if i == next_stage() else Data.REPLAY_RATE) * Data.DIFF[diff].pts
	var got := Data.run_value(k) * clampf(progress, 0.0, 1.0) * rate + (Data.FIRST_CLEAR if first else 0.0)
	sp += got
	attempts[str(i)] = tries_of(i) + 1
	if won and i not in cleared: cleared.append(i)
	write()
	return got

## Pilot ağacı puanı: 3 lisans puanı + kazanılan puanlar - harcanan
func tree_points() -> int: return Data.START_POINTS + int(floor(sp + 0.0001)) - tree.size()
func power() -> int: return tree.size() # yatırılmış puan = "güç"
func can_take(id: String) -> bool:
	if id in tree or tree_points() <= 0: return false
	for l in Data.TREE[id].links:
		if l == "start" or l in tree: return true
	return false

func add_endless(r: Dictionary) -> int:
	endless.append(r)
	endless.sort_custom(func(a, b): return a.time > b.time or (a.time == b.time and a.score > b.score))
	if endless.size() > 10: endless.resize(10)
	write()
	return endless.find(r) + 1

func add_record(r: Dictionary) -> int:
	records.append(r)
	records.sort_custom(func(a, b): return a.score > b.score)
	if records.size() > 10: records.resize(10)
	write()
	return records.find(r) + 1

## Havuzdan rastgele bir replik indeksi; son duyulan yarısı (uçuşlar arası da) tekrar seçilmez.
func pick_line(pool: String, n: int) -> int:
	var recent: Array = heard.get(pool, [])
	var free := []
	for i in n:
		if not recent.has(float(i)) and not recent.has(i): free.append(i)
	var i: int = free.pick_random() if not free.is_empty() else randi() % n
	recent.append(i)
	while recent.size() > int(n / 2.0): recent.pop_front()
	heard[pool] = recent
	return i

# ---------- KOZMETİK ----------
## kayıttan gelen kozmetik verisini doğrula (JSON sayıları float gelir, bozuk/eski kayıt güvenli)
func _clean_cos(k: String, v: Dictionary) -> Dictionary:
	var out := {}
	for pid in v:
		if not Data.COSMETICS.has(str(pid)): continue
		var n: int = Data.COSMETICS[str(pid)].size()
		var x = v[pid]
		match k:
			"tokens":
				if typeof(x) == TYPE_DICTIONARY: out[str(pid)] = {"g": maxi(0, int(x.get("g", 0))), "o": maxi(0, int(x.get("o", 0))), "r": maxi(0, int(x.get("r", 0)))}
			"owned":
				if typeof(x) == TYPE_ARRAY:
					var arr := []
					for i in x:
						if int(i) >= 0 and int(i) < n and not arr.has(int(i)): arr.append(int(i))
					out[str(pid)] = arr
			"equip":
				if typeof(x) == TYPE_DICTIONARY:
					var e := {}
					for sl in x:
						if str(sl) in Data.COS_SLOTS and int(x[sl]) >= 0 and int(x[sl]) < n: e[str(sl)] = int(x[sl])
					out[str(pid)] = e
			_: out[str(pid)] = maxi(0, int(x))
	return out

func tok(pid: String, c: String) -> int: return int(tokens.get(pid, {}).get(c, 0))
func add_token(pid: String, c: String) -> void:
	var t: Dictionary = tokens.get(pid, {"g": 0, "o": 0, "r": 0})
	t[c] = int(t.get(c, 0)) + 1; tokens[pid] = t
	write()
func has_item(pid: String, i: int) -> bool: return owned.get(pid, []).has(i)

## Kapsül aç: jetonu harca, nadirlik çek (garanti dahil), parçayı ver ya da hurdaya çevir. -> {"i": sıra, "dup": bool}
func open_capsule(pid: String, c: String) -> Dictionary:
	if tok(pid, c) <= 0: return {}
	tokens[pid][c] -= 1
	var p: Array = Data.COS_DROP[c]
	var r := 0
	if int(dry.get(pid, 0)) >= Data.COS_PITY: r = 3 if randf() < p[3] / (p[3] + p[4]) else 4
	else:
		var x := randf()
		while r < 4 and x > p[r]: x -= p[r]; r += 1
	dry[pid] = 0 if r >= 3 else int(dry.get(pid, 0)) + 1
	var pool := []
	for i in Data.COSMETICS[pid].size():
		if int(Data.COSMETICS[pid][i].r) == r + 1: pool.append(i)
	var i: int = pool.pick_random()
	var dup := has_item(pid, i)
	if dup: scrap[pid] = int(scrap.get(pid, 0)) + 1
	else:
		var o: Array = owned.get(pid, []); o.append(i); owned[pid] = o
	write()
	return {"i": i, "dup": dup}

## Hurdayla eksik bir 1-3. nadirlik parçası al
func buy_with_scrap(pid: String, i: int) -> bool:
	if int(scrap.get(pid, 0)) < Data.COS_SCRAP or has_item(pid, i) or int(Data.COSMETICS[pid][i].r) > 3: return false
	scrap[pid] -= Data.COS_SCRAP
	var o: Array = owned.get(pid, []); o.append(i); owned[pid] = o
	write()
	return true

## Tak / çıkar. Efsane set dört yuvayı birden doldurur.
func equip_item(pid: String, i: int) -> void:
	var it: Dictionary = Data.COSMETICS[pid][i]
	var e: Dictionary = equip.get(pid, {})
	if it.s == "set":
		var on: bool = e.get("boya", -1) == i
		for sl in Data.COS_SLOTS:
			if on: e.erase(sl)
			else: e[sl] = i
	else:
		for sl in Data.COS_SLOTS: # set takılıysa önce seti çöz
			if e.has(sl) and Data.COSMETICS[pid][e[sl]].s == "set": e.erase(sl)
		if e.get(it.s, -1) == i: e.erase(it.s)
		else: e[it.s] = i
	equip[pid] = e
	write()
func equipped(pid: String, slot: String) -> Dictionary:
	var e: Dictionary = equip.get(pid, {})
	return Data.COSMETICS[pid][e[slot]] if e.has(slot) else {}
