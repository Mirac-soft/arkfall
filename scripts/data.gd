extends Node
## ARKFALL — tüm denge ve hikaye verisi. Sayıları buradan değiştirin.
## Zorluk matematiğinin açıklaması: docs/DENGE.md   •   Simülasyonu: node tools/denge_sim.js

# ---------- Rütbe (sadece unvan; güç Pilot Ağacı'ndan gelir) ----------
func rank_need(l: int) -> int: return int(round(100.0 * pow(l, 1.5)))
func rank_info(total: int) -> Dictionary:
	var l := 1
	while total >= rank_need(l):
		total -= rank_need(l)
		l += 1
	return {"level": l, "into": total, "need": rank_need(l)}
var RANKS := [[1, "ASTEĞMEN"], [2, "TEĞMEN"], [4, "ÜSTEĞMEN"], [7, "YÜZBAŞI"], [10, "BİNBAŞI"], [14, "YARBAY"], [18, "ALBAY"], [25, "TUĞGENERAL"], [35, "KORGENERAL"], [50, "ORGENERAL"]]
func rank_name(l: int) -> String:
	var n: String = RANKS[0][1]
	for r in RANKS:
		if l >= r[0]: n = r[1]
	return n

# ---------- Uçuş içi seviye ----------
func run_need(l: int) -> int: return int(8 + 8 * (l - 1) + 1.5 * (l - 1) * (l - 1)) # v0.9: ilerledikçe dikleşir; bölüm başına ~10-20 seviye (eskiden 16-28)
## İkmal kapsülü: rastgele değil, bölüme göre sabit sayıda elit gemi gelir; her biri 3 sistemlik kapsül düşürür.
## Eski sistem (her düşmanda %2.5 elit) uçuş başına 9-14 kapsül veriyordu; yükseltmelerin yarısı buradan geliyordu.
func chest_count(k: int) -> int: return 2 + int(k / 5.0)  # 1-4: 2, 5-9: 3, 10-14: 4, 15: 5
const CHEST_LV := 3

# ---------- ZORLUK MATEMATİĞİ (tools/denge_sim.js ile aynı) ----------
# T(k): bölüm k için hedef deneme sayısı, V(k): bir denemenin pilot puanı değeri
# R(k): bölümü geçmek için gereken pilot puanı. Oyuncu bölüme R(k)'dan daha az puanla gelir;
#       aradaki farkı o bölümü tekrar tekrar deneyerek (her denemede puan kazanarak) kapatır.
## v0.13 ölçüm (ölmeyen ama kaçan bot, önerilen güç): savaş 11-25 sn (ort. 18), savaşta can kaybı ort. %48 (saniyede ~%2.7).
## Hedef: normal boss 28-35 sn, final ~40 sn (Sky Force / Halls of Torment / DRG Survivor 30-60 sn). x1.67 can + 2. faz
## geçişinde mermi temizliği ve %15 onarım: beklenen can kaybı ~%48 -> ~%65 (gergin ama geçilebilir). Hasar ARTMAZ (tek atış ölümleri).
const BOSS_HP := 2.5
## Harekât: 3 bölüm üst üste, build taşınır. Taşınan güç kadar düşman da güçlenir (bölümün harekâttaki sırası 0/1/2).
## Hesap: taşınan build 2. bölüme ~12, 3. bölüme ~18 seçimle girer (taze bölümde ortalama ~6). Kart gücü azalan getirili
## (yeni silah 1. seviyede zayıf), bu yüzden etkili güç ~x1.6 / x2.0 -> düşman canı x1.5 / x1.9, hasar ve yoğunluk daha az.
const OP_LEN := 3
const OP_HP := [1.0, 1.25, 1.5]
const OP_DMG := [1.0, 1.05, 1.1]
const OP_DENS := [1.0, 1.05, 1.1]
const OP_HEAL := 0.4          # bölümler arası onarım (maks. canın oranı)
func op_start(i: int) -> int: return i - i % OP_LEN
const REROLLS := 2            # harekât başına yeniden çekme (Serçe +2)
const BANS := 2               # harekât başına yasaklama
const CURSE_CHANCE := 0.18    # pasif kartının lanetli gelme şansı
const EVO_PAS := 5            # evrim için eş pasifin en az seviyesi (evrim sadece ikmal kapsülünden)
const STAR_PTS := 0.5         # her yeni yıldız pilot puanı verir
const STARS := ["Bölümü geç", "Bütün ikmal kapsüllerini al", "Boss'u hasar almadan düşür"]
## Zorluk kademeleri: ZOR bölüm geçilince, KÂBUS ZOR'da geçilince açılır
const DIFF := [
	{"name": "NORMAL", "hp": 1.0, "dmg": 1.0, "pts": 1.0, "col": Color("57ff9a")},
	{"name": "ZOR", "hp": 1.6, "dmg": 1.35, "pts": 1.5, "col": Color("ffb03c")},
	{"name": "KÂBUS", "hp": 2.5, "dmg": 1.8, "pts": 2.0, "col": Color("ff3a4a")},
]
const START_POINTS := 3      # herkes 3 lisans puanıyla başlar
const FIRST_CLEAR := 2.0     # bölümü ilk geçişte bonus puan
const REPLAY_RATE := 0.25    # geçilmiş bölümü tekrar oynamak daha az puan verir
func tries(k: int) -> float: return minf(7.0, 1.2 + 0.55 * (k - 1))
func run_value(k: int) -> float: return 1.0 + 0.08 * (k - 1)
var REQ := [] # REQ[k] (1'den başlar)
func _build_req() -> void:
	REQ = [0.0]
	var a := 0.0
	for k in range(1, 16):
		var r := a + (tries(k) - 1.0) * 0.7 * run_value(k)
		REQ.append(r)
		a = r + run_value(k) + FIRST_CLEAR
func enemy_hp_mult(k: int) -> float: return pow(1.0 + REQ[k] / ENEMY_SCALE, 2.6)   # testle: üs 3 -> 2.6
func enemy_dmg_mult(k: int) -> float: return pow(1.0 + REQ[k] / ENEMY_SCALE, 1.8)  # testle: üs 2 -> 1.8
## ölçek: 120 (v0.5) -> 90 (imza silahları) -> 115 (v0.7: test pilotu önerilen gücün ~1.3-1.45 katında geçiyordu)
const ENEMY_SCALE := 185.0

# ---------- Uçaklar ----------
# Her uçağın KENDİNE ÖZGÜ başlangıç silahı (sig, kartlarda çıkmaz, seviyeyle güçlenir) ve yeteneği (trait) var.
# UÇUŞ FİZİĞİ (game.gd -> _move_player):
#   ivme a = itki / kütle (px/s²)          -> ne kadar çabuk hızlanır/yavaşlar
#   yanal limit L = kaldırma / kütle (px/s²) -> en fazla ne kadar keskin döner
#   dönüş hızı ω = L / v  (hızlıyken geniş, yavaşken dar dönüş — gerçek uçak gibi)
#   yatış açısı φ = atan(v·ω / g)  (koordineli dönüş formülü, g = 900 px/s²)
#   Ekranda gösterilen manevra = L / 140  "G"
# noz: egzoz lüleleri [x, y, yarıçap] model biriminde (blender_studio.py P.eng: x*k, y*k+4.1, r*k*0.62)
var PLANES := [
	{"id": "serce", "name": "SPARROW", "title": "VX-1 Hafif Önleyici", "unlock": 0, "color": Color("4fd8ff"),
		"hp": 110, "speed": 250.0, "thrust": 700.0, "lift": 1250.0, "might": 1.0, "armor": 0, "magnet": 1.1, "sig": "vulcan", "bar": "pill", "noz": [[0.0, 39.1, 3.7]],
		"trait": "ADAPTİF AVİYONİK", "trait_desc": "Seviye atlarken 4 kart görürsün ve harekât başına 2 ek yeniden çekme hakkın olur. En istikrarlı build.",
		"desc": "Filonun emektarı. Dengeli, öngörülebilir, affedici."},
	{"id": "dogan", "name": "FALCON", "title": "HX-7 Füze Taşıyıcı Avcı", "unlock": 2, "color": Color("57ff9a"),
		"hp": 95, "speed": 280.0, "thrust": 820.0, "lift": 1400.0, "might": 1.0, "armor": 0, "magnet": 1.0, "sig": "rockets", "bar": "arc", "noz": [[0.0, 40.4, 4.1]],
		"trait": "HEDEF KİLİDİ", "trait_desc": "Her 5 sn'de en güçlü hedefe 4 ağır füze salvosu. Bosslara ve elitlere +%30 hasar.",
		"desc": "Sinop üssünün gizli prototipi. Boss avcısı."},
	{"id": "simsek", "name": "VOLT", "title": "EX-9 Elektrikli Atılım Önleyicisi", "unlock": 4, "color": Color("ffe14f"),
		"hp": 80, "speed": 315.0, "thrust": 1100.0, "lift": 1750.0, "might": 0.95, "armor": 0, "magnet": 1.0, "sig": "arc", "bar": "bolt", "noz": [[-4.0, 46.0, 2.5], [4.0, 46.0, 2.5]],
		"trait": "FAZ ATILIMI", "trait_desc": "SAĞ TIK / SPACE: 270 px ileri atıl, 0.4 sn dokunulmaz ol, yolundaki düşmanları çarp. 2.5 sn bekleme.",
		"desc": "En hızlı ve en çevik. Mermi yağmurunun içinden geçer."},
	{"id": "kartal", "name": "AEGIS", "title": "AX-12 Ağır Zırhlı Muhafız", "unlock": 6, "color": Color("ff9a3c"),
		"hp": 150, "speed": 215.0, "thrust": 420.0, "lift": 800.0, "might": 1.15, "armor": 3, "magnet": 1.0, "sig": "flak", "bar": "armor", "noz": [[-7.7, 44.1, 3.6], [7.7, 44.1, 3.6]],
		"trait": "PLAZMA KALKANI", "trait_desc": "Her 7 sn'de bir darbeyi tamamen emer. Çarptığı düşmanlara gücüyle orantılı hasar verir.",
		"desc": "Uçan bir kale. Yavaş döner ama alan hasarıyla sürüleri eritir."},
	{"id": "anka", "name": "PHOENIX", "title": "Ω-1 Deneysel Prototip", "unlock": 10, "color": Color("ff4fd8"),
		"hp": 120, "speed": 270.0, "thrust": 760.0, "lift": 1300.0, "might": 1.25, "armor": 1, "magnet": 1.2, "sig": "solar", "bar": "flame", "noz": [[-5.0, 44.4, 3.3], [5.0, 44.4, 3.3]],
		"trait": "KÜLLERİNDEN DOĞUŞ", "trait_desc": "Uçuş başına bir kez, düşünce %60 canla dirilir ve etrafı yakıp yıkar. En yüksek ham güç.",
		"desc": "Sahra'daki terk edilmiş tesiste bulunan efsane."},
]
## UÇAK USTALIĞI (v0.13): Pilot Ağacı hesaba genel güç verir; ustalık o uçağı uçurdukça açılan 5 kademelik, uçağa özel
## yetenek gelişimidir (DRG Survivor / Hades silah yönleri gibi). Toplam etki ~%15-20 güç: ağaçtan küçük, ama her uçağı farklı oynatır.
## XP = düşürülen + kazanılan bölümde 400 + boss hasarı; ortalama uçuş ~900-1800 -> 5. kademe ~15-20 uçuş.
const MASTERY_XP := [1500, 4500, 9000, 15000, 24000] # kademe eşikleri (birikimli)
var MASTERY := {
	"serce": [{"k": "sig_dmg", "v": 0.10, "d": "Vulcan +%10 hasar"}, {"k": "reroll", "v": 1, "d": "+1 yeniden çekme"}, {"k": "xp", "v": 0.08, "d": "+%8 deneyim"},
		{"k": "ban", "v": 1, "d": "+1 yasaklama"}, {"k": "sig_pierce", "v": 1, "d": "Vulcan mermileri 1 düşmanı deler"}],
	"dogan": [{"k": "sig_dmg", "v": 0.10, "d": "Roketler +%10 hasar"}, {"k": "salvo_n", "v": 1, "d": "Hedef kilidi salvosu 5 füze"}, {"k": "hp", "v": 15, "d": "+15 maks. can"},
		{"k": "salvo_cd", "v": 1.0, "d": "Salvo her 4 sn'de"}, {"k": "boss_dmg", "v": 0.10, "d": "Boss ve elitlere +%10 daha"}],
	"simsek": [{"k": "sig_dmg", "v": 0.10, "d": "Ark +%10 hasar"}, {"k": "dash_cd", "v": 0.5, "d": "Atılım bekleme 2 sn"}, {"k": "dmg", "v": 0.05, "d": "+%5 hasar"},
		{"k": "sig_chain", "v": 1, "d": "Ark 1 hedefe daha sıçrar"}, {"k": "dash_dmg", "v": 0.5, "d": "Atılım çarpma hasarı +%50"}],
	"kartal": [{"k": "sig_dmg", "v": 0.10, "d": "Flak +%10 hasar"}, {"k": "shield_cd", "v": 1.0, "d": "Kalkan her 6 sn'de"}, {"k": "hp", "v": 20, "d": "+20 maks. can"},
		{"k": "sig_n", "v": 2, "d": "Flak 7 şarapnel"}, {"k": "shield_blast", "v": 1, "d": "Kalkan darbeyi emince şok dalgası"}],
	"anka": [{"k": "sig_dmg", "v": 0.10, "d": "Güneş ışını +%10 hasar"}, {"k": "revive", "v": 0.2, "d": "Dirilişte %80 can"}, {"k": "dmg", "v": 0.05, "d": "+%5 hasar"},
		{"k": "sig_cd", "v": 0.15, "d": "Güneş ışını %15 daha sık"}, {"k": "revive_blast", "v": 1.0, "d": "Diriliş patlaması 2 kat"}],
}
func mastery_level(x: int) -> int:
	var l := 0
	for need in MASTERY_XP:
		if x >= need: l += 1
	return l
## Açılmış kademelerin toplam bonusları: {"sig_dmg": 0.1, ...}
func mastery_stats(id: String, x: int) -> Dictionary:
	var out := {}
	var arr: Array = MASTERY.get(id, [])
	for i in mini(mastery_level(x), arr.size()): out[arr[i].k] = out.get(arr[i].k, 0.0) + float(arr[i].v)
	return out

## KOZMETİK (v0.14): uçak başına 19 parça (boya 7, iz 4, alev 4, arma 3, efsane set 1). Güç vermez.
## Jeton SADECE sonsuz modda kazanılır: her COS_EVERY saniyede 1, rengi süreye göre (yeşil < 12 dk, turuncu < 20 dk, kırmızı).
## Jeton o uçuşta uçulan uçağa aittir, ölünce kaybolmaz. Seferi ilk kez bitirene tek seferlik 1 turuncu jeton hediye.
## Kapsül: COS_DROP[renk] = nadirlik 1-5 olasılıkları. Aynısı çıkarsa hurda (COS_SCRAP hurda = 1-3. nadirlikten seçim),
## COS_PITY kapsül üst üste 4+ çıkmazsa sonraki en az 4. Simülasyon: orta oyuncu bir uçağın tam setini ~16-22 sonsuz uçuşta toplar.
const COS_EVERY := 240.0
const COS_COLORS := {"g": [0.0, "YEŞİL", Color("57ff9a")], "o": [720.0, "TURUNCU", Color("ffb03c")], "r": [1200.0, "KIRMIZI", Color("ff3a4a")]}
const COS_DROP := {"g": [0.60, 0.28, 0.09, 0.025, 0.005], "o": [0.40, 0.32, 0.18, 0.08, 0.02], "r": [0.20, 0.30, 0.27, 0.17, 0.06]}
const COS_SCRAP := 5
const COS_PITY := 10
const COS_RARITY := ["", "STANDART", "ASKERÎ", "ELİT", "AS", "EFSANE"]
const COS_RCOL := [Color.WHITE, Color("a9b3bd"), Color("57ff9a"), Color("4fb8ff"), Color("c88cff"), Color("ffd34f")]
const COS_SLOTS := ["boya", "iz", "alev", "arma"]
const COS_SLOT_NAME := {"boya": "GÖVDE BOYASI", "iz": "KUYRUK İZİ", "alev": "EGZOZ ALEVİ", "arma": "ARMA"}
## renk: jeton rengi, süre (saniye) -> renk kodu
func cos_color(t_sec: float) -> String: return "r" if t_sec >= COS_COLORS.r[0] else ("o" if t_sec >= COS_COLORS.o[0] else "g")
## parça kimliği: "uçak:sıra"
func cos_item(key: String) -> Dictionary:
	var parts := key.split(":")
	if parts.size() != 2 or not COSMETICS.has(parts[0]): return {}
	var arr: Array = COSMETICS[parts[0]]
	var i := int(parts[1])
	return arr[i] if i >= 0 and i < arr.size() else {}
var COSMETICS := {
	"serce": [
		{"s": "boya", "r": 1, "n": "Gri Kamuflaj", "k": "blob", "c": [Color("#5c6269"), Color("#7c838b"), Color("#9aa1a8")], "m": [Color("#c8d0d8"), Color("#ffffff")]},
		{"s": "boya", "r": 1, "n": "Kıyı Parçalı", "k": "splinter", "c": [Color("#6a7468"), Color("#87907f"), Color("#525a50")], "m": [Color("#b8c4a8"), Color("#ffffff")]},
		{"s": "boya", "r": 2, "n": "Ege Dalgası", "k": "blob", "c": [Color("#14507e"), Color("#3fa0d8"), Color("#e2f0f8")], "m": [Color("#4fd8ff"), Color("#e2f0f8")]},
		{"s": "boya", "r": 2, "n": "Mercan Piksel", "k": "pixel", "c": [Color("#0a8ea0"), Color("#ff7a5a"), Color("#ffe0b0")], "m": [Color("#ff7a5a"), Color("#ffe0b0")]},
		{"s": "boya", "r": 3, "n": "Dalga Kıran", "k": "waves", "c": [Color("#0c2a48"), Color("#2fa8e8"), Color("#ffffff")], "m": [Color("#2fa8e8"), Color("#ffffff")]},
		{"s": "boya", "r": 3, "n": "Hayalet", "k": "ghost", "c": [Color("#23262c"), Color("#353a42"), Color("#e8eef4")], "m": [Color("#e8eef4"), Color("#9fb4c8")]},
		{"s": "boya", "r": 4, "n": "Buz Kristali", "k": "candy", "c": [Color("#1f8cff"), Color("#9ff0ff"), Color("#ffffff")], "m": [Color("#9ff0ff"), Color("#ffffff")]},
		{"s": "iz", "r": 1, "n": "Beyaz Kontrail", "k": "contrail", "c": [Color("#ffffff"), Color("#ffffff")]},
		{"s": "iz", "r": 2, "n": "Sarmal", "k": "helix", "c": [Color("#4fd8ff"), Color("#ffffff")]},
		{"s": "iz", "r": 3, "n": "Çift Kurdele", "k": "ribbon", "c": [Color("#4fd8ff"), Color("#ffffff")]},
		{"s": "iz", "r": 4, "n": "Kuyruklu Yıldız", "k": "comet", "c": [Color("#9ff0ff"), Color("#ffffff")]},
		{"s": "alev", "r": 1, "n": "Mavi Yanma", "k": "basic", "c": [Color("#5fb8ff"), Color("#ffffff")]},
		{"s": "alev", "r": 2, "n": "Çift Çekirdek", "k": "twin", "c": [Color("#ff9a50"), Color("#7fd0ff")]},
		{"s": "alev", "r": 3, "n": "Şok Elmasları", "k": "diamond", "c": [Color("#4fd8ff"), Color("#ffffff")]},
		{"s": "alev", "r": 4, "n": "Nova", "k": "nova", "c": [Color("#bff4ff"), Color("#ffffff")]},
		{"s": "arma", "r": 1, "n": "Filo Numarası", "k": "number", "c": [Color("#f2f4f6"), Color("#1a1d22")]},
		{"s": "arma", "r": 2, "n": "Kanat Şevronu", "k": "chevron", "c": [Color("#4fd8ff"), Color("#f2f4f6")]},
		{"s": "arma", "r": 3, "n": "Köpekbalığı Ağzı", "k": "shark", "c": [Color("#c8202a"), Color("#ffffff")]},
		{"s": "set", "r": 5, "n": "Gök Kalkanı", "k": "legend", "c": [Color("#0a1830"), Color("#4fd8ff"), Color("#ffd34f")], "m": [Color("#4fd8ff"), Color("#ffd34f")]},
	],
	"dogan": [
		{"s": "boya", "r": 1, "n": "Zeytin Kamuflaj", "k": "blob", "c": [Color("#4a5532"), Color("#626e42"), Color("#7a8456")], "m": [Color("#b8c48a"), Color("#ffffff")]},
		{"s": "boya", "r": 1, "n": "Çalı Parçalı", "k": "splinter", "c": [Color("#58603e"), Color("#757e56"), Color("#40472c")], "m": [Color("#a8b480"), Color("#ffffff")]},
		{"s": "boya", "r": 2, "n": "Orman", "k": "blob", "c": [Color("#174a24"), Color("#46a044"), Color("#d0dc60")], "m": [Color("#57ff9a"), Color("#d0dc60")]},
		{"s": "boya", "r": 2, "n": "Zehir Piksel", "k": "pixel", "c": [Color("#123820"), Color("#57ff9a"), Color("#ffd34f")], "m": [Color("#57ff9a"), Color("#ffd34f")]},
		{"s": "boya", "r": 3, "n": "Kaplan", "k": "tiger", "c": [Color("#e07a20"), Color("#141210"), Color("#ffd8a0")], "m": [Color("#ff9a3c"), Color("#ffd8a0")]},
		{"s": "boya", "r": 3, "n": "Pençe İzi", "k": "claw", "c": [Color("#2a3320"), Color("#57ff9a"), Color("#e8ffe0")], "m": [Color("#57ff9a"), Color("#e8ffe0")]},
		{"s": "boya", "r": 4, "n": "Zümrüt", "k": "candy", "c": [Color("#06a050"), Color("#7dffb0"), Color("#ffffff")], "m": [Color("#7dffb0"), Color("#ffffff")]},
		{"s": "iz", "r": 1, "n": "Kesik Çizgi", "k": "dash", "c": [Color("#ffffff"), Color("#ffffff")]},
		{"s": "iz", "r": 2, "n": "Zümrüt Duman", "k": "smoke", "c": [Color("#57ff9a"), Color("#ffffff")]},
		{"s": "iz", "r": 3, "n": "Dalga", "k": "wave", "c": [Color("#57ff9a"), Color("#ffd34f")]},
		{"s": "iz", "r": 4, "n": "Kuyruklu Yıldız", "k": "comet", "c": [Color("#b0ffb8"), Color("#ffffff")]},
		{"s": "alev", "r": 1, "n": "Yeşil Yanma", "k": "basic", "c": [Color("#7dff9a"), Color("#ffffff")]},
		{"s": "alev", "r": 2, "n": "Uzun Yanma", "k": "long", "c": [Color("#ffb060"), Color("#ffffff")]},
		{"s": "alev", "r": 3, "n": "Çatallı Alev", "k": "forked", "c": [Color("#57ff9a"), Color("#ffffff")]},
		{"s": "alev", "r": 4, "n": "Asit Plazması", "k": "plasma", "c": [Color("#c8ff7d"), Color("#2cc84a")]},
		{"s": "arma", "r": 1, "n": "Filo Numarası", "k": "number", "c": [Color("#f2f4f6"), Color("#1a1d22")]},
		{"s": "arma", "r": 2, "n": "Av Bantları", "k": "bands", "c": [Color("#f2f4f6"), Color("#141614")]},
		{"s": "arma", "r": 3, "n": "Doğan Gözü", "k": "eyes", "c": [Color("#ffd34f"), Color("#141210")]},
		{"s": "set", "r": 5, "n": "Avcı Doğan", "k": "legend", "c": [Color("#06180c"), Color("#57ff9a"), Color("#ffd34f")], "m": [Color("#57ff9a"), Color("#ffd34f")]},
	],
	"simsek": [
		{"s": "boya", "r": 1, "n": "Kum Kamuflaj", "k": "blob", "c": [Color("#8a7a56"), Color("#a8956c"), Color("#c2b088")], "m": [Color("#e8d8a8"), Color("#ffffff")]},
		{"s": "boya", "r": 1, "n": "Taş Parçalı", "k": "splinter", "c": [Color("#7a7870"), Color("#98968c"), Color("#5e5c56")], "m": [Color("#c8c6b8"), Color("#ffffff")]},
		{"s": "boya", "r": 2, "n": "Fırtına", "k": "blob", "c": [Color("#1e2a48"), Color("#5a6ab0"), Color("#ffe14f")], "m": [Color("#ffe14f"), Color("#8fd0ff")]},
		{"s": "boya", "r": 2, "n": "Neon Piksel", "k": "pixel", "c": [Color("#16162a"), Color("#ffe14f"), Color("#8a7bff")], "m": [Color("#ffe14f"), Color("#8a7bff")]},
		{"s": "boya", "r": 3, "n": "Yıldırım Kamuflajı", "k": "bolts", "c": [Color("#1a1c24"), Color("#ffe14f"), Color("#ffffff")], "m": [Color("#ffe14f"), Color("#ffffff")]},
		{"s": "boya", "r": 3, "n": "Devre Kartı", "k": "circuit", "c": [Color("#0e2a1e"), Color("#ffe14f"), Color("#7dffd0")], "m": [Color("#ffe14f"), Color("#7dffd0")]},
		{"s": "boya", "r": 4, "n": "Elektrik Sarısı", "k": "candy", "c": [Color("#ffb800"), Color("#fff27a"), Color("#ffffff")], "m": [Color("#fff27a"), Color("#ffffff")]},
		{"s": "iz", "r": 1, "n": "Beyaz Kontrail", "k": "contrail", "c": [Color("#ffffff"), Color("#ffffff")]},
		{"s": "iz", "r": 2, "n": "Sarı Duman", "k": "smoke", "c": [Color("#ffe14f"), Color("#ffffff")]},
		{"s": "iz", "r": 3, "n": "Şimşek İzi", "k": "zigzag", "c": [Color("#ffe14f"), Color("#ffffff")]},
		{"s": "iz", "r": 4, "n": "Kuyruklu Yıldız", "k": "comet", "c": [Color("#fff27a"), Color("#ffffff")]},
		{"s": "alev", "r": 1, "n": "Elektrik Mavisi", "k": "basic", "c": [Color("#8fd0ff"), Color("#ffffff")]},
		{"s": "alev", "r": 2, "n": "Çift Çekirdek", "k": "twin", "c": [Color("#ffd060"), Color("#8fd0ff")]},
		{"s": "alev", "r": 3, "n": "Şok Elmasları", "k": "diamond", "c": [Color("#ffe14f"), Color("#ffffff")]},
		{"s": "alev", "r": 4, "n": "Ark Plazması", "k": "plasma", "c": [Color("#ffffff"), Color("#8a7bff")]},
		{"s": "arma", "r": 1, "n": "Filo Numarası", "k": "number", "c": [Color("#1a1d22"), Color("#ffe14f")]},
		{"s": "arma", "r": 2, "n": "Kanat Şevronu", "k": "chevron", "c": [Color("#ffe14f"), Color("#1a1d22")]},
		{"s": "arma", "r": 3, "n": "Şimşek Burun", "k": "boltnose", "c": [Color("#ffe14f"), Color("#1a1d22")]},
		{"s": "set", "r": 5, "n": "Tufan", "k": "legend", "c": [Color("#14142a"), Color("#ffe14f"), Color("#8fd0ff")], "m": [Color("#ffe14f"), Color("#8fd0ff")]},
	],
	"kartal": [
		{"s": "boya", "r": 1, "n": "Pas Kamuflaj", "k": "blob", "c": [Color("#5e4434"), Color("#7a5a44"), Color("#946e54")], "m": [Color("#d8a888"), Color("#ffffff")]},
		{"s": "boya", "r": 1, "n": "Toprak Parçalı", "k": "splinter", "c": [Color("#6e604c"), Color("#8c7c64"), Color("#544838")], "m": [Color("#c8b498"), Color("#ffffff")]},
		{"s": "boya", "r": 2, "n": "Kapadokya", "k": "blob", "c": [Color("#a04c22"), Color("#e09a58"), Color("#f4dcb0")], "m": [Color("#ff9a3c"), Color("#f4dcb0")]},
		{"s": "boya", "r": 2, "n": "Kor Piksel", "k": "pixel", "c": [Color("#2e140c"), Color("#ff7a2a"), Color("#ffd34f")], "m": [Color("#ff7a2a"), Color("#ffd34f")]},
		{"s": "boya", "r": 3, "n": "Alev Yalımı", "k": "flames", "c": [Color("#1a1614"), Color("#ff4a1a"), Color("#ffd34f")], "m": [Color("#ff7a2a"), Color("#ffd34f")]},
		{"s": "boya", "r": 3, "n": "Kale Zırhı", "k": "hex", "c": [Color("#4a4440"), Color("#ff9a3c"), Color("#7a726a")], "m": [Color("#ff9a3c"), Color("#ffd8a0")]},
		{"s": "boya", "r": 4, "n": "Döküm Bakırı", "k": "candy", "c": [Color("#d0602a"), Color("#ffb070"), Color("#ffffff")], "m": [Color("#ffb070"), Color("#ffffff")]},
		{"s": "iz", "r": 1, "n": "Kesik Çizgi", "k": "dash", "c": [Color("#ffffff"), Color("#ffffff")]},
		{"s": "iz", "r": 2, "n": "Kor Dumanı", "k": "smoke", "c": [Color("#ff7a3c"), Color("#ffffff")]},
		{"s": "iz", "r": 3, "n": "Ateş Kurdelesi", "k": "ribbon", "c": [Color("#ff9a3c"), Color("#ff3a2a")]},
		{"s": "iz", "r": 4, "n": "Kıvılcım Yağmuru", "k": "embers", "c": [Color("#ffb050"), Color("#ffe0a0")]},
		{"s": "alev", "r": 1, "n": "Turuncu Yanma", "k": "basic", "c": [Color("#ff9a3c"), Color("#ffffff")]},
		{"s": "alev", "r": 2, "n": "Uzun Yanma", "k": "long", "c": [Color("#ff9050"), Color("#ffffff")]},
		{"s": "alev", "r": 3, "n": "Çatallı Alev", "k": "forked", "c": [Color("#ff7a2a"), Color("#ffd34f")]},
		{"s": "alev", "r": 4, "n": "Lav Plazması", "k": "plasma", "c": [Color("#ffd080"), Color("#ff3a1a")]},
		{"s": "arma", "r": 1, "n": "Filo Numarası", "k": "number", "c": [Color("#f2f4f6"), Color("#1a1d22")]},
		{"s": "arma", "r": 2, "n": "Hedef Halkaları", "k": "rings", "c": [Color("#ff9a3c"), Color("#f2f4f6")]},
		{"s": "arma", "r": 3, "n": "Kale Arması", "k": "shield", "c": [Color("#ff9a3c"), Color("#f2f4f6")]},
		{"s": "set", "r": 5, "n": "Kale", "k": "legend", "c": [Color("#1e100a"), Color("#ff9a3c"), Color("#ffd34f")], "m": [Color("#ff9a3c"), Color("#ffd34f")]},
	],
	"anka": [
		{"s": "boya", "r": 1, "n": "Kül Kamuflaj", "k": "blob", "c": [Color("#46434c"), Color("#5a5660"), Color("#726d78")], "m": [Color("#c8c0d0"), Color("#ffffff")]},
		{"s": "boya", "r": 1, "n": "Duman Parçalı", "k": "splinter", "c": [Color("#5c5862"), Color("#7a7480"), Color("#44404a")], "m": [Color("#c0b8c8"), Color("#ffffff")]},
		{"s": "boya", "r": 2, "n": "Gün Batımı", "k": "blob", "c": [Color("#4a1a38"), Color("#d0506a"), Color("#ffb060")], "m": [Color("#ff6a8a"), Color("#ffb060")]},
		{"s": "boya", "r": 2, "n": "Lale Piksel", "k": "pixel", "c": [Color("#3a0f2a"), Color("#ff4fd8"), Color("#ffd0e8")], "m": [Color("#ff4fd8"), Color("#ffd0e8")]},
		{"s": "boya", "r": 3, "n": "Alev Tüyü", "k": "feather", "c": [Color("#3a0e1e"), Color("#ff4f8a"), Color("#ffb03c")], "m": [Color("#ff4f8a"), Color("#ffb03c")]},
		{"s": "boya", "r": 3, "n": "Ateş Çizgisi", "k": "tiger", "c": [Color("#b02870"), Color("#1a0a12"), Color("#ffb0d8")], "m": [Color("#ff4fd8"), Color("#ffb0d8")]},
		{"s": "boya", "r": 4, "n": "Gül Şekeri", "k": "candy", "c": [Color("#e0208a"), Color("#ff9ad0"), Color("#ffffff")], "m": [Color("#ff9ad0"), Color("#ffffff")]},
		{"s": "iz", "r": 1, "n": "Beyaz Kontrail", "k": "contrail", "c": [Color("#ffffff"), Color("#ffffff")]},
		{"s": "iz", "r": 2, "n": "Sarmal", "k": "helix", "c": [Color("#ff4fd8"), Color("#ffb03c")]},
		{"s": "iz", "r": 3, "n": "Dalga", "k": "wave", "c": [Color("#ff4fd8"), Color("#ffb03c")]},
		{"s": "iz", "r": 4, "n": "Kıvılcım Yağmuru", "k": "embers", "c": [Color("#ff7ad0"), Color("#ffd080")]},
		{"s": "alev", "r": 1, "n": "Pembe Yanma", "k": "basic", "c": [Color("#ff7ad8"), Color("#ffffff")]},
		{"s": "alev", "r": 2, "n": "Çift Çekirdek", "k": "twin", "c": [Color("#ff9060"), Color("#ff7ad8")]},
		{"s": "alev", "r": 3, "n": "Çatallı Alev", "k": "forked", "c": [Color("#ff4fd8"), Color("#ffd34f")]},
		{"s": "alev", "r": 4, "n": "Nova", "k": "nova", "c": [Color("#ffd0f0"), Color("#ffffff")]},
		{"s": "arma", "r": 1, "n": "Filo Numarası", "k": "number", "c": [Color("#f2f4f6"), Color("#1a1d22")]},
		{"s": "arma", "r": 2, "n": "Kanat Bantları", "k": "bands", "c": [Color("#ff4fd8"), Color("#1a0a12")]},
		{"s": "arma", "r": 3, "n": "Anka Kanatları", "k": "phoenix", "c": [Color("#ff4f2a"), Color("#ffd34f")]},
		{"s": "set", "r": 5, "n": "Ezelî Anka", "k": "legend", "c": [Color("#1e0818"), Color("#ff4fd8"), Color("#ffd34f")], "m": [Color("#ff4fd8"), Color("#ffd34f")]},
	],
}

func plane(id: String) -> Dictionary:
	for p in PLANES:
		if p.id == id: return p
	return PLANES[0]
func maneuver_g(p: Dictionary) -> float: return p.lift / 140.0

# ---------- Uçağa özel imza silahları (kartlarda çıkmaz; oyuncu seviyesiyle büyür) ----------
# Hasar x (1 + 0.07·(sv-1)), bekleme x 1/(1 + 0.02·(sv-1))
var SIGS := {
	"vulcan": {"name": "VX Twin Vulcan", "icon": "w_top", "dmg": 8.0, "cd": 0.13, "desc": "İki paralel namludan hedefe kilitli yüksek hızlı mermi akışı."},
	"rockets": {"name": "HX Swarm Rockets", "icon": "w_fuze", "dmg": 15.0, "cd": 0.85, "rad": 42.0, "desc": "Sürekli fırlatılan güdümlü mikro roketler, küçük patlama alanı."},
	"arc": {"name": "EX Arc Lancer", "icon": "w_simsek", "dmg": 10.0, "cd": 0.22, "range": 280.0, "desc": "Yakındaki düşmana sürekli elektrik arkı; 2 hedefe sıçrar."},
	"flak": {"name": "AX Flak Battery", "icon": "w_emp", "dmg": 16.0, "cd": 0.85, "rad": 60.0, "desc": "Hedef yönüne 5 şarapnel mermisi; 220 px'de patlar. Sürü ve zırha karşı etkili."},
	"solar": {"name": "Ω Solar Lance", "icon": "w_lazer", "dmg": 42.0, "cd": 1.5, "w": 26.0, "len": 780.0, "desc": "Hedefe kilitlenen, her şeyi delen güneş ışını."},
}

# ---------- Silahlar (5 seviye; her seviye öncekilerin üstüne eklenir) ----------
var WEAPONS := {
	"top": {"name": "RX-20 Rotary Autocannon", "icon": "w_top", "lv": [
		{"dmg": 10, "cd": 0.5, "n": 1, "pierce": 0, "spd": 780}, {"dmg": 13.5}, {"n": 2, "dmg": 9}, {"cd": 0.42, "dmg": 10}, {"n": 3, "dmg": 8, "pierce": 1}],
		"desc": ["En yakın düşmana otomatik ateş eder.", "+1 mermi", "+%40 hasar", "+1 mermi, daha hızlı atış", "Mermiler 1 düşmanı deler, +hasar"],
		"evo": {"pas": "kalibre", "name": "Tungsten Fırtınası", "desc": "5 namlu, 3 düşmanı delen mermiler, çok daha hızlı atış", "st": {"n": 5, "dmg": 10, "pierce": 3, "cd": 0.34}}},
	"fuze": {"name": "HMX Seeker Missiles", "icon": "w_fuze", "lv": [
		{"dmg": 24, "cd": 1.4, "n": 1, "rad": 55}, {"dmg": 32}, {"n": 2, "dmg": 24}, {"rad": 80, "cd": 1.15}, {"n": 3, "dmg": 22}],
		"desc": ["Hedefe kilitlenen, patlayan füzeler. Zırha karşı iyi.", "+1 füze", "+%40 hasar", "Patlama alanı büyür, daha sık", "+2 füze"],
		"evo": {"pas": "sogutucu", "name": "Sürü Füzesi", "desc": "7 füzelik salvolar, geniş patlama", "st": {"n": 5, "cd": 1.0, "rad": 100, "dmg": 26}}},
	"kalkan": {"name": "Orbital Drone Array", "icon": "w_kalkan", "lv": [
		{"dmg": 10, "n": 2, "r": 85, "spd": 3.0, "on": 4.0, "off": 2.5}, {"dmg": 12}, {"n": 3}, {"r": 100, "dmg": 14, "spd": 3.6}, {"on": 999.0}],
		"desc": ["Uçağın etrafında dönen saldırı dronları.", "+1 dron", "+hasar, daha geniş yörünge", "+1 dron, daha hızlı", "Dronlar hiç kapanmaz"],
		"evo": {"pas": "motor", "name": "Kılıç Halkası", "desc": "6 dron, geniş ve çok hızlı yörünge", "st": {"n": 5, "dmg": 20, "r": 125, "spd": 5.0}}},
	"emp": {"name": "EMP Field Emitter", "icon": "w_emp", "lv": [
		{"dmg": 6, "r": 75, "tick": 0.5}, {"r": 90}, {"dmg": 8}, {"r": 105}, {"dmg": 9, "tick": 0.42}],
		"desc": ["Yakındaki düşmanlara sürekli hasar verir, iter. Zırhlıya zayıf.", "Alan büyür", "+hasar", "Alan büyür", "+hasar, daha sık vuruş"],
		"evo": {"pas": "zirh", "name": "Fırtına Çekirdeği", "desc": "Dev EMP alanı, çok sık ve sert vuruş", "st": {"r": 135, "dmg": 11, "tick": 0.32}}},
	"simsek": {"name": "Tesla Arc Coil", "icon": "w_simsek", "lv": [
		{"dmg": 22, "cd": 1.5, "n": 1, "chain": 2}, {"chain": 3}, {"dmg": 28}, {"n": 2, "dmg": 22}, {"chain": 4, "dmg": 24}],
		"desc": ["Düşmandan düşmana sıçrayan yıldırım.", "+1 sıçrama", "+1 yıldırım", "+%45 hasar", "+1 yıldırım, +2 sıçrama"],
		"evo": {"pas": "miknatis", "name": "Yıldırım Ağı", "desc": "5 yıldırım, her biri 8 düşmana sıçrar", "st": {"n": 3, "chain": 6, "dmg": 26}}},
	"lazer": {"name": "Photon Lance", "icon": "w_lazer", "lv": [
		{"dmg": 34, "cd": 2.2, "w": 20, "len": 700, "back": false}, {"dmg": 44}, {"w": 30, "cd": 2.0}, {"dmg": 56}, {"back": true}],
		"desc": ["Hedefe kilitlenen, sıradaki her şeyi delen ışın.", "+hasar", "Daha kalın, daha sık", "+hasar", "Ters yöne ikinci ışın"],
		"evo": {"pas": "onarim", "name": "Güneş Mızrağı", "desc": "Kalın, uzun ve çok sık ateşlenen çift ışın", "st": {"w": 48, "dmg": 80, "cd": 1.4, "len": 900}}},
	"mayin": {"name": "Graviton Mines", "icon": "w_mayin", "lv": [
		{"dmg": 40, "cd": 1.3, "rad": 75, "n": 1}, {"dmg": 50}, {"rad": 95}, {"n": 2, "dmg": 42}, {"dmg": 48, "cd": 1.05}],
		"desc": ["Arkana temasla patlayan mayınlar bırakır.", "+hasar", "Patlama alanı büyür", "+1 mayın", "+hasar, daha sık"],
		"evo": {"pas": "zirh", "name": "Kara Delik Mayını", "desc": "3 mayın, dev patlama alanı", "st": {"n": 3, "rad": 140, "dmg": 60, "cd": 0.9}}},
	"napalm": {"name": "Napalm Trail Pods", "icon": "w_napalm", "lv": [
		{"dmg": 5, "cd": 0.3, "rad": 34, "dur": 2.5, "tick": 0.4}, {"dur": 3.5}, {"dmg": 7}, {"rad": 44}, {"dmg": 8.5, "dur": 4.2}],
		"desc": ["Arkanda yanan bir yakıt izi bırakır. Kovalayan sürüye karşı ideal.", "İz daha uzun yanar", "+%60 hasar", "İz genişler", "+hasar, daha uzun iz"],
		"evo": {"pas": "alan", "name": "Cehennem Koridoru", "desc": "Geniş, uzun ve çok sıcak bir alev koridoru", "st": {"dmg": 11, "rad": 58, "dur": 5.0, "tick": 0.35}}},
	"ray": {"name": "Mag-Rail Cannon", "icon": "w_ray", "lv": [
		{"dmg": 70, "cd": 3.2, "n": 1, "w": 10}, {"dmg": 95}, {"cd": 2.6}, {"n": 2, "dmg": 75}, {"dmg": 90, "w": 16}],
		"desc": ["Ekranı boydan boya delen yavaş ama ağır atış. Zırhlı hedeflere karşı güçlü.", "+hasar", "Daha sık", "+1 atış", "+hasar, daha kalın"],
		"evo": {"pas": "delici", "name": "Yörünge Topu", "desc": "Üç atışlık yelpaze, devasa hasar", "st": {"n": 3, "dmg": 120, "cd": 2.2, "w": 22}}},
	"glaive": {"name": "Boomerang Glaive", "icon": "w_glaive", "lv": [
		{"dmg": 18, "cd": 1.7, "n": 1, "range": 360, "spd": 620}, {"dmg": 24}, {"n": 2, "dmg": 20}, {"range": 440, "cd": 1.45}, {"n": 3, "dmg": 18}],
		"desc": ["Hedefe fırlayıp geri dönen, her şeyi delen bıçak.", "+1 bıçak", "+%50 hasar", "Daha uzağa, daha sık", "+1 bıçak, +hasar"],
		"evo": {"pas": "nisan", "name": "Kasırga Bıçakları", "desc": "5 bıçak, geniş menzil, kritik vuruşa yatkın", "st": {"n": 5, "dmg": 20, "range": 520, "cd": 1.3}}},
	"hava": {"name": "Orbital Artillery Uplink", "icon": "w_hava", "lv": [
		{"dmg": 34, "cd": 2.6, "n": 2, "rad": 64}, {"dmg": 44}, {"n": 3, "dmg": 38}, {"rad": 78, "cd": 2.3}, {"n": 4, "dmg": 40}],
		"desc": ["Komuta düşmanların üstüne topçu atışı yağdırır (kısa gecikmeyle).", "+1 atış", "+%40 hasar", "Patlama büyür, daha sık", "+2 atış"],
		"evo": {"pas": "coklayici", "name": "Ateş Halısı", "desc": "Ekranı patlamalarla örten topçu yağmuru", "st": {"n": 6, "dmg": 50, "rad": 88, "cd": 2.0}}},
	"taret": {"name": "Sentry Drop Turrets", "icon": "w_taret", "lv": [
		{"dmg": 7, "cd": 5.0, "n": 1, "rate": 0.45, "dur": 6.0}, {"dmg": 9}, {"rate": 0.36}, {"n": 2, "dmg": 7}, {"dur": 7.5, "dmg": 8}],
		"desc": ["Kendi kendine ateş eden taretler bırakır.", "+hasar", "Daha hızlı atış", "+1 taret", "Daha uzun ömür, +hasar"],
		"evo": {"pas": "deflektor", "name": "Kale Ağı", "desc": "3 ağır taret, çok hızlı ateş", "st": {"n": 3, "dmg": 9, "rate": 0.3, "dur": 8.0}}},
}
## Kart metni: iki seviye arasındaki gerçek değişim ("Hasar 10 → 13"). a == 0: yeni silahın temel değerleri
const WSTAT_TXT := {"dmg": "Hasar", "n": "Adet", "cd": "Atış aralığı", "rate": "Atış aralığı", "tick": "Vuruş aralığı", "chain": "Sıçrama",
	"pierce": "Delme", "rad": "Patlama alanı", "r": "Yarıçap", "range": "Menzil", "w": "Kalınlık", "len": "Uzunluk", "dur": "Süre", "on": "Açık kalma", "spd": "Hız", "back": "Ters ışın"}
const STAT_SEC := ["cd", "rate", "tick", "dur", "on"]
func wdiff(id: String, a: int, b: int) -> String:
	var sa: Dictionary = wstats(id, a) if a > 0 else {}
	var sb: Dictionary = wstats(id, b)
	var out := []
	for k in WSTAT_TXT:
		if not sb.has(k) or (a > 0 and sa.get(k) == sb[k]) or (a == 0 and not k in ["dmg", "n", "cd", "rate", "chain", "dur", "r", "rad", "tick"]): continue
		if k == "spd" and sb[k] > 100: continue # mermi hızı kartı kalabalıklaştırmasın
		out.append(L(WSTAT_TXT[k]) + " " + (_fmt(k, sa[k]) + " → " if a > 0 and sa.has(k) else "") + _fmt(k, sb[k]))
	if a > 0: # toplam güç (saniye başı hasar yaklaşığı): bölünen değerler yanıltmasın
		var g := _power(sb) / maxf(_power(sa), 0.001) - 1.0
		if absf(g) >= 0.01: out.append(L("Toplam güç") + " %+d%%" % roundi(g * 100.0))
	return "\n".join(out)
## Silah gücü yaklaşığı: hasar x adet x sıçrama / aralık x alan x süre etkileri
func _power(s: Dictionary) -> float:
	var iv: float = s.get("cd", s.get("rate", s.get("tick", 1.0)))
	var p: float = s.get("dmg", 1.0) * maxf(1.0, s.get("n", 1.0)) * (1.0 + s.get("chain", 0.0)) / maxf(iv, 0.05)
	if s.has("rad") or s.has("r") or s.has("w"): p *= s.get("rad", s.get("r", s.get("w", 50.0))) / 50.0
	p *= (1.0 + 0.3 * s.get("pierce", 0.0)) * (1.6 if s.get("back", false) else 1.0) * minf(s.get("on", 4.0), 6.0) / 4.0
	return p * s.get("dur", 1.0) * s.get("range", 360.0) / 360.0
func _fmt(k: String, v) -> String:
	if typeof(v) == TYPE_BOOL: return L("AÇIK") if v else L("KAPALI")
	if k == "on" and v >= 999: return L("sürekli")
	var s := str(snappedf(v, 0.01)).trim_suffix(".0")
	return s + (L(" sn") if k in STAT_SEC else "")

func wstats(id: String, lvl: int) -> Dictionary:
	var s := {}
	for i in mini(lvl, MAX_LV):
		s.merge(WEAPONS[id].lv[i], true)
	if lvl > MAX_LV: s.merge(WEAPONS[id].evo.st, true) # evrim: 5. seviye + eş pasif
	return s

var PASSIVES := {
	"motor": {"name": "Afterburner Stage II", "icon": "p_motor", "desc": "+%10 uçuş hızı", "curse": ["espd", 0.08, "Düşmanlar %8 hızlı"]},
	"zirh": {"name": "Ceramic-Composite Plating", "icon": "p_zirh", "desc": "+20 maks. can, +1 zırh", "curse": ["pspd", -0.08, "Uçuş hızı -%8"]},
	"miknatis": {"name": "Magnetic Salvage Collector", "icon": "p_miknatis", "desc": "+%40 toplama alanı", "curse": ["ehp", 0.08, "Düşman canı +%8"]},
	"sogutucu": {"name": "Cryogenic Coolant Loop", "icon": "p_sogutucu", "desc": "Silahlar %8 daha sık ateşler", "curse": ["bspd", 0.10, "Düşman mermileri %10 hızlı"]},
	"kalibre": {"name": "Tungsten-Core Rounds", "icon": "p_kalibre", "desc": "+%10 hasar", "curse": ["maxhp", -15.0, "Maks. can -15"]},
	"onarim": {"name": "Nanite Repair Swarm", "icon": "p_onarim", "desc": "Saniyede +0.5 can yenilenir", "curse": ["edmg", 0.10, "Düşman hasarı +%10"]},
	"nisan": {"name": "Targeting Computer", "icon": "p_nisan", "desc": "+%4 kritik şansı, +%10 kritik hasarı", "curse": ["ehp", 0.10, "Düşman canı +%10"]},
	"alan": {"name": "Blast Core Expander", "icon": "p_alan", "desc": "+%10 etki alanı", "curse": ["pspd", -0.06, "Uçuş hızı -%6"]},
	"ogrenme": {"name": "Tactical Data Link", "icon": "p_ogrenme", "desc": "+%10 deneyim", "curse": ["edmg", 0.08, "Düşman hasarı +%8"]},
	"deflektor": {"name": "Deflector Screen", "icon": "p_deflektor", "desc": "Belli aralıklarla bir darbeyi tamamen engeller (16 sn, seviyeyle kısalır)", "curse": ["xp", -0.12, "Deneyim -%12"]},
	"coklayici": {"name": "Ammo Multiplexer", "icon": "p_coklayici", "desc": "Her 2 seviyede +1 mermi / füze / dron / taret", "curse": ["maxhp", -20.0, "Maks. can -20"]},
	"sonnefes": {"name": "Last Stand Protocol", "icon": "p_sonnefes", "desc": "Canın yarının altındayken +%8 hasar", "curse": ["maxhp", -15.0, "Maks. can -15"]},
	"avci": {"name": "Hunter's Mark", "icon": "p_avci", "desc": "Elit ve bosslara +%10 hasar", "curse": ["espd", 0.06, "Düşmanlar %6 hızlı"]},
	"delici": {"name": "AP Penetrators", "icon": "p_delici", "desc": "+2 zırh delme", "curse": ["bspd", 0.10, "Düşman mermileri %10 hızlı"]},
}
## Taktik kartları: yuvalar dolunca havuza karışan, yuva tutmayan tek seferlik küçük bonuslar (harekât boyunca birikir).
## Değerler bir pasif seviyesinin ~%40'ı: dolu build'e çeşitlilik verir ama gücü patlatmaz.
const TACTICS := {
	"t_dmg": {"name": "Saha Ayarı: Namlu", "icon": "p_kalibre", "k": "dmg", "v": 0.04, "desc": "+%4 hasar"},
	"t_rate": {"name": "Saha Ayarı: Besleme", "icon": "p_sogutucu", "k": "rate", "v": 0.04, "desc": "+%4 atış hızı"},
	"t_hp": {"name": "Gövde Yaması", "icon": "p_zirh", "k": "hp", "v": 12.0, "desc": "+12 maks. can ve %30 onarım"},
	"t_crit": {"name": "Nişangâh Kalibrasyonu", "icon": "p_nisan", "k": "crit", "v": 3.0, "desc": "+%3 kritik şansı"},
	"t_mag": {"name": "Toplama Ağı", "icon": "p_miknatis", "k": "mag", "v": 0.15, "desc": "+%15 toplama alanı"},
	"t_xp": {"name": "Veri Paketi", "icon": "p_ogrenme", "k": "xp", "v": 0.05, "desc": "+%5 deneyim"},
	"t_reroll": {"name": "Yedek Plan", "icon": "p_deflektor", "k": "reroll", "v": 1.0, "desc": "+1 yeniden çekme, +1 yasaklama"},
}
const MAX_LV := 5
const SLOTS := 4 # v0.9: 6 -> 4, build bir bölümde tamamlanmasın; seçimler anlam kazansın

# ---------- Düşmanlar: Vahar filosu ----------
# ai: chase, dash, gun, spin, bomber + v0.9: shield, split, ghost, blink, sniper, mines, healer, hive, tank, orbit
# from: ilk göründüğü bölüm (her bölge bir yeni tür getirir). w: doğma ağırlığı. desc/atk/tip: Defter (codex) yazıları
var ENEMIES := {
	"drone": {"name": "Gözcü", "tex": "e_drone", "hp": 8.0, "spd": 95.0, "dmg": 6.0, "xp": 1, "r": 16.0, "ai": "chase", "col": Color("b46cff"), "from": 1, "w": 3.0,
		"desc": "Sefine'nin ucuz, sayısız gözü. Tek başına zararsız, sürü halinde boğucu.", "atk": "Çarpma", "tip": "Alan silahları (EMP, napalm) sürüyü eritir."},
	"avci": {"name": "Avcı", "tex": "e_avci", "hp": 16.0, "spd": 150.0, "dmg": 9.0, "xp": 2, "r": 18.0, "ai": "chase", "col": Color("ff4fd8"), "from": 1, "w": 2.0,
		"desc": "Hızlı önleme gemisi. Öncü Avcı'nın filosundan.", "atk": "Yüksek hızla çarpma", "tip": "Düz kaçma: dönüşte yakalar. Yay çizerek kaç."},
	"kamikaze": {"name": "Dalıcı", "tex": "e_kamikaze", "hp": 12.0, "spd": 120.0, "dmg": 16.0, "xp": 2, "r": 16.0, "ai": "dash", "col": Color("ffe14f"), "from": 2, "w": 1.5,
		"desc": "Pilotu olmayan patlayıcı dart. Yanıp sönerek kilitlenir, sonra dalar.", "atk": "Kilitlenip dalış (ağır temas hasarı)", "tip": "Sarı yanıp sönmeyi görünce yana kır."},
	"topcu": {"name": "Topçu", "tex": "e_topcu", "hp": 40.0, "spd": 75.0, "dmg": 8.0, "xp": 4, "r": 24.0, "ai": "gun", "col": Color("3cffd8"), "from": 3, "w": 1.0,
		"desc": "Mesafe koruyan ikiz namlulu platform.", "atk": "3'lü yelpaze atış (orta mermi)", "tip": "Yaklaşınca geri çekilir: sıkıştır ve bitir."},
	"kalkanli": {"name": "Kalkancı", "tex": "e_kalkanli", "hp": 45.0, "spd": 70.0, "dmg": 12.0, "xp": 4, "r": 22.0, "ai": "shield", "col": Color("8fd0ff"), "from": 4, "w": 0.9,
		"desc": "Önünde enerji kalkanı taşıyan ağır savaşçı. Sürünün ön safı.", "atk": "Çarpma", "tip": "Önden gelen mermilerin %75'ini emer. Yandan / arkadan vur: dronlar, mayın, napalm, bıçak."},
	"girdap": {"name": "Girdap", "tex": "e_girdap", "hp": 60.0, "spd": 60.0, "dmg": 10.0, "xp": 6, "r": 26.0, "ai": "spin", "col": Color("b46cff"), "from": 5, "w": 0.7,
		"desc": "Dönen üç kanatlı mermi tarlası.", "atk": "Sürekli spiral (hafif mermi)", "tip": "Spiralin boşluklarından geç; uzak durma, yakın daha güvenli."},
	"bolunen": {"name": "Bölünen", "tex": "e_bolunen", "hp": 34.0, "spd": 90.0, "dmg": 10.0, "xp": 3, "r": 22.0, "ai": "split", "col": Color("ff9a3c"), "from": 6, "w": 1.0,
		"desc": "Üç Kıvılcım'ın kenetlendiği bileşik gemi.", "atk": "Çarpma; ölünce 3 Kıvılcım'a ayrılır", "tip": "Uzaktan öldür: parçalar dağılarak üstüne gelir."},
	"kivilcim": {"name": "Kıvılcım", "tex": "e_kivilcim", "hp": 7.0, "spd": 165.0, "dmg": 6.0, "xp": 1, "r": 12.0, "ai": "chase", "col": Color("ff9a3c"), "from": 99, "w": 0.0, "scale": 0.9,
		"desc": "Bölünen'in parçası. Küçük, çok hızlı.", "atk": "Çarpma", "tip": "Tek vuruşta düşer; dronlar ve EMP yeter."},
	"bombardiman": {"name": "Ağır Gemi", "tex": "e_bombardiman", "hp": 180.0, "spd": 45.0, "dmg": 18.0, "xp": 12, "r": 44.0, "ai": "bomber", "col": Color("6aa8ff"), "from": 7, "w": 0.4,
		"desc": "Yavaş ama zırhlı bombardıman gemisi.", "atk": "16'lı halka (ağır mermi)", "tip": "Halka açılmadan önce uzaklaş; halkalar aralıklı gelir."},
	"hayalet": {"name": "Hayalet", "tex": "e_hayalet", "hp": 30.0, "spd": 130.0, "dmg": 16.0, "xp": 4, "r": 18.0, "ai": "ghost", "col": Color("c8c4d8"), "from": 8, "w": 0.9,
		"desc": "Işığı büken kaplamalı suikastçı. Sadece kenar parıltısı görünür.", "atk": "Yakında belirip dalış", "tip": "İnce parıltıyı izle; belirdiği an yana kır."},
	"isinlanan": {"name": "Sıçrayan", "tex": "e_isinlanan", "hp": 40.0, "spd": 60.0, "dmg": 10.0, "xp": 5, "r": 20.0, "ai": "blink", "col": Color("6a7bff"), "from": 9, "w": 0.7,
		"desc": "Kısa mesafe ışınlanma motoru taşıyan gemi.", "atk": "Yanına ışınlanıp 10'lu halka (orta mermi)", "tip": "Mavi işaret halkası çıkınca oradan uzaklaş."},
	"keskin": {"name": "Keskin Nişancı", "tex": "e_keskin", "hp": 36.0, "spd": 80.0, "dmg": 8.0, "xp": 5, "r": 20.0, "ai": "sniper", "col": Color("ff3355"), "from": 10, "w": 0.6,
		"desc": "Uzun namlulu menzil gemisi. Uzaktan kilitlenir.", "atk": "Kırmızı nişan çizgisi, ardından hızlı ağır atış", "tip": "Kırmızı çizgi kilitlenmeyi gösterir: çizgiden çık."},
	"mayinci": {"name": "Mayın Gemisi", "tex": "e_mayinci", "hp": 70.0, "spd": 70.0, "dmg": 12.0, "xp": 6, "r": 26.0, "ai": "mines", "col": Color("ff7a3c"), "from": 11, "w": 0.6,
		"desc": "Etrafında dolaşıp duran mayın bırakan gemi.", "atk": "Duran mayınlar (ağır)", "tip": "Önce onu düşür, yoksa alan mayınla dolar."},
	"tamirci": {"name": "Onarıcı", "tex": "e_tamirci", "hp": 55.0, "spd": 75.0, "dmg": 8.0, "xp": 7, "r": 22.0, "ai": "healer", "col": Color("57ff9a"), "from": 12, "w": 0.45,
		"desc": "Sürünün arkasında kalan destek gemisi.", "atk": "Yakındaki düşmanları yeşil ışınla onarır", "tip": "Öncelikli hedef: o yaşarken sürü ölmez."},
	"ana": {"name": "Kovan", "tex": "e_ana", "hp": 260.0, "spd": 35.0, "dmg": 20.0, "xp": 16, "r": 46.0, "ai": "hive", "col": Color("e070ff"), "from": 13, "w": 0.3,
		"desc": "Gövdesinde dron yuvaları taşıyan ağır taşıyıcı.", "atk": "Sürekli Kıvılcım dronu üretir", "tip": "Uzun kalırsa ekranı doldurur: ağır silahlarla hızlı indir."},
	"zirhli": {"name": "Zırhlı Tank", "tex": "e_zirhli", "hp": 320.0, "spd": 40.0, "dmg": 24.0, "xp": 18, "r": 40.0, "ai": "tank", "col": Color("b8b8c8"), "from": 14, "w": 0.3, "armor": 6.0,
		"desc": "Kalın plakalı yürüyen kale.", "atk": "12'li yavaş halka (ağır mermi)", "tip": "Zırh +6: raylı top, lazer ve zırh delici şart."},
	"orak": {"name": "Orakçı", "tex": "e_orak", "hp": 70.0, "spd": 160.0, "dmg": 18.0, "xp": 7, "r": 22.0, "ai": "orbit", "col": Color("ff2a8a"), "from": 15, "w": 0.6,
		"desc": "Varek'in muhafızı. Avının etrafında döner, sonra biçer.", "atk": "Daire çizip aniden dalış", "tip": "Dönerken öldürmeye çalış; dalış anında yana kaç."},
}

# ---------- Bosslar: desen kütüphanesinden saldırılar (game.gd -> _boss_ai) ----------
# pats: fan, spiral, ring, curve, dash, summon:<tür>, pull, mines, quad, split, walls, stream
# move: chase (kovalar), hover (yavaş süzülür), orbit (etrafında döner). spin: sprite döner
var BOSSES := {
	"oncu": {"name": "ÖNCÜ AVCI", "tex": "b_oncu", "hp": 1500.0, "spd": 115.0, "dmg": 20.0, "r": 62.0, "col": Color("b46cff"), "scale": 0.8, "move": "chase", "pats": ["fan", "dash", "ring"],
		"line": "Küçük gezegenin küçük pilotu. Varek seni bekliyor... ama önce benimle dans et."},
	"kusatma": {"name": "KUŞATMA GEMİSİ", "tex": "b_indirme", "hp": 1800.0, "spd": 55.0, "dmg": 22.0, "r": 100.0, "col": Color("6aa8ff"), "scale": 0.9, "move": "hover", "pats": ["summon:drone", "stream", "curve"],
		"line": "Son üssünüzü bulduk. Kapılarınızı açın, belki birkaçınız yaşar."},
	"matkap": {"name": "MATKAP", "tex": "b_matkap", "hp": 2000.0, "spd": 80.0, "dmg": 24.0, "r": 80.0, "col": Color("ff9a3c"), "scale": 0.9, "move": "chase", "pats": ["walls", "mines", "fan"],
		"line": "Taşın altına saklanmak... ne ilkel. Kazın onları!"},
	"goz": {"name": "GÖZCÜ KULE", "tex": "b_goz", "hp": 2200.0, "spd": 45.0, "dmg": 24.0, "r": 90.0, "col": Color("3cffd8"), "scale": 0.9, "spin": true, "move": "hover", "pats": ["stream", "ring", "split"],
		"line": "Her hareketini görüyorum, pilot. Her birini."},
	"su_hasat": {"name": "SU HASATÇISI", "tex": "b_hasat", "hp": 2400.0, "spd": 50.0, "dmg": 26.0, "r": 115.0, "col": Color("57ff9a"), "scale": 0.9, "spin": true, "move": "hover", "pats": ["pull", "curve", "split"],
		"line": "Bu göl bir medeniyeti bir yıl yaşatır. Sizinkini değil, bizimkini."},
	"buz": {"name": "BUZ KIRICI", "tex": "b_buz", "hp": 2600.0, "spd": 70.0, "dmg": 28.0, "r": 85.0, "col": Color("a8e8ff"), "scale": 0.9, "move": "chase", "pats": ["quad", "walls", "fan"],
		"line": "Dağlarınızın kalbi buzdan. Erittiğimizde içinde ne kalacak?"},
	"kizil_kanat": {"name": "KIZIL KANAT", "tex": "b_kizil_kanat", "hp": 2800.0, "spd": 80.0, "dmg": 28.0, "r": 85.0, "col": Color("ff5a3c"), "scale": 0.9, "move": "chase", "pats": ["fan", "spiral", "mines"],
		"line": "Bulutların üstü bize aittir. Kanatlarını yakacağım."},
	"firtina_kalesi": {"name": "FIRTINA KALESİ", "tex": "b_firtina_kalesi", "hp": 3000.0, "spd": 60.0, "dmg": 30.0, "r": 120.0, "col": Color("3cffd8"), "scale": 0.9, "spin": true, "move": "orbit", "pats": ["spiral", "curve", "summon:avci"],
		"line": "Fırtınanın gözüne hoş geldin. Buradan kimse sağ çıkmadı."},
	"ikiz": {"name": "İKİZ AVCILAR", "tex": "b_ikiz", "hp": 3200.0, "spd": 130.0, "dmg": 30.0, "r": 75.0, "col": Color("ff4fd8"), "scale": 0.9, "move": "chase", "pats": ["dash", "stream", "ring"],
		"line": "Biz iki kişiyiz, sen bir. Matematik basit."},
	"kum": {"name": "KUM YILANI", "tex": "b_kum", "hp": 3400.0, "spd": 95.0, "dmg": 32.0, "r": 90.0, "col": Color("ffd34f"), "scale": 0.95, "move": "chase", "pats": ["walls", "mines", "curve"],
		"line": "Çölün altında bin yıl uyuyabilirim. Senin bir saatin bile yok."},
	"dokumhane": {"name": "DÖKÜMHANE", "tex": "b_ates", "hp": 3600.0, "spd": 40.0, "dmg": 34.0, "r": 120.0, "col": Color("ff7a3c"), "scale": 0.95, "spin": true, "move": "hover", "pats": ["quad", "split", "summon:bombardiman"],
		"line": "Volkanlarınız bizim fırınımız. Her dakika yeni bir gemi dökülüyor."},
	"emici": {"name": "ATMOSFER EMİCİ", "tex": "b_emici", "hp": 3800.0, "spd": 45.0, "dmg": 36.0, "r": 120.0, "col": Color("8fd0ff"), "scale": 0.95, "spin": true, "move": "hover", "pats": ["pull", "quad", "ring"],
		"line": "Nefes al, pilot. Alabildiğin kadar. Yakında hava kalmayacak."},
	"copcu": {"name": "ÇÖPÇÜ", "tex": "b_enkaz", "hp": 4000.0, "spd": 70.0, "dmg": 36.0, "r": 110.0, "col": Color("c8c4d8"), "scale": 0.95, "move": "orbit", "pats": ["summon:kamikaze", "split", "walls"],
		"line": "Uydularınızın enkazından ne güzel silahlar yaptım."},
	"sefine": {"name": "SEFİNE — YAŞAM GEMİSİ", "tex": "b_sefine", "hp": 4500.0, "spd": 40.0, "dmg": 40.0, "r": 150.0, "col": Color("ffd34f"), "scale": 1.0, "spin": true, "move": "hover", "hpk": 1.25, "pats": ["quad", "pull", "spiral", "summon:kamikaze"],
		"line": "Halkımın son umudu bu gemide. Onu düşürürsen ne olacağını biliyor musun?"},
	"varek": {"name": "VAREK'İN TAHTI", "tex": "b_varek", "hp": 5200.0, "spd": 100.0, "dmg": 45.0, "r": 95.0, "col": Color("ff3355"), "scale": 1.0, "move": "chase", "hpk": 1.4, "pats": ["dash", "quad", "split", "walls", "curve"],
		"line": "Her şey burada başladı, pilot. Lyra'nın elini sıktığınız meydanda. Burada da bitecek."},
}

# ---------- 15 BÖLÜM (her biri hikayede bir yer) ----------
# biome: gökyüzü shader'ında harita türü. armor: düşman zırhı (düz hasar azaltma),
# bspd: mermi hızı çarpanı, dens: düşman yoğunluğu. Sayılar zorluk eğrisinin ÜSTÜNE eklenen "karakter"dir.
var STAGES := [
	{"name": "İLK SALDIRI", "sub": "Ege Denizi", "biome": 0, "tint": Color(1, 1, 1), "boss": "oncu", "armor": 0, "bspd": 1, "dens": 1, "swarm": "drone",
		"story": "Sefine'nin ilk avcıları Ege'nin üstünde belirdi. Adalar, tekneler, limanlar... her şey hedefte.",
		"tip": "Isınma turu. Kristal topla, kartları dene.",
		"brief": [["cmd", "Şahin-1, Vahar avcıları Ege'yi vuruyor. Bu ilk dalga."], ["cmd", "Öncü filolarının lideri hızlı ve acımasız. Onu düşür."]]},
	{"name": "SON KALE", "sub": "Sinop Hava Üssü", "biome": 1, "tint": Color(1, 1, 1), "boss": "kusatma", "armor": 0, "bspd": 1, "dens": 1.25, "swarm": "avci",
		"story": "Dağların gölgesindeki eski üs, Vahar tarayıcılarının göremediği tek yer. Direniş burada toplandı. Şimdi kuşatma altında.",
		"tip": "Kalabalık sürüler: Teknoloji dalındaki ETKİ ALANI işe yarar.",
		"brief": [["cmd", "Üssü bulmuşlar. Kuşatma gemisi kapıya dayandı."], ["cmd", "Hangarda yarım kalmış bir prototip var. Üssü kurtarırsan senin olur."]]},
	{"name": "PERİBACALARI", "sub": "Kapadokya", "biome": 2, "tint": Color(1, 1, 1), "boss": "matkap", "armor": 2, "bspd": 1, "dens": 1.1, "swarm": "kamikaze",
		"story": "Siviller binlerce yıllık yeraltı şehirlerine saklandı. Vahar'ın matkap gemisi onları kazıp çıkarmaya çalışıyor.",
		"tip": "Zırhlı gemiler (zırh 2): küçük vuruşlar zayıflar. Ateş Gücü ve ZIRH DELME al.",
		"brief": [["cmd", "Kapadokya'nın altında on bin sivil var. Matkap sesi her yerden duyuluyor."], ["pilot", "Kazmalarına izin vermeyeceğim."]]},
	{"name": "RADAR TEPESİ", "sub": "Toros Dağları", "biome": 3, "tint": Color(1, 1, 1), "boss": "goz", "armor": 1, "bspd": 1.3, "dens": 1.1, "swarm": "avci",
		"story": "Dağdaki son radar istasyonu düşerse kör kalırız. Vahar bunu biliyor: tepeye dev bir Gözcü Kule dikti.",
		"tip": "Hızlı mermiler: Motor dalında HIZ ve ÇEVİKLİK al.",
		"brief": [["cmd", "Gözcü Kule'nin mermileri çok hızlı. Durma, sürekli hareket et."], ["cmd", "Radarı kurtar, gözlerimiz açılsın."]]},
	{"name": "SU SAVAŞI", "sub": "Van Gölü", "biome": 4, "tint": Color(1, 1, 1), "boss": "su_hasat", "armor": 1, "bspd": 1.1, "dens": 1.3, "swarm": "drone",
		"story": "Oksijenden sonra en çok istedikleri şey tatlı su. Hasatçı gemi Van Gölü'nü kurutuyor.",
		"tip": "Çekim ışınına dikkat: uzaklaşmak için HIZ gerekir.",
		"brief": [["cmd", "Gölün seviyesi her saat bir metre düşüyor."], ["cmd", "Hasatçının ışınına kapılma. Seni de içeri çeker."]]},
	{"name": "ZİRVE", "sub": "Ağrı Dağı", "biome": 5, "tint": Color(1, 1, 1), "boss": "buz", "armor": 3, "bspd": 1.15, "dens": 1.2, "swarm": "kamikaze",
		"story": "Buz Kırıcı, Ağrı'nın buzullarını eritip suyunu çalıyor. Zirvede hava ince, mermiler sert.",
		"tip": "Zırh 3: düşük hasarlı silahlar (EMP, kalkan) zorlanır.",
		"brief": [["cmd", "Ağrı'da kar fırtınası var ama Buz Kırıcı durmuyor."], ["pilot", "Ben de durmayacağım."]]},
	{"name": "BULUT DUVARI", "sub": "8.000 metre", "biome": 6, "tint": Color(1, 1, 1), "boss": "kizil_kanat", "armor": 2, "bspd": 1.2, "dens": 1.1, "swarm": "avci",
		"story": "Vahar hava kuvvetleri bulutların üstünde toplanıyor. Onları Kızıl Kanat yönetiyor.",
		"tip": "Hızlı mermi + kalabalık: dengeli build şart.",
		"brief": [["cmd", "Kızıl Kanat'ın altında mayınlar var. Arkasında kalma."], ["cmd", "Bu bölümü ilk denemede geçen pilot görmedim. Gerekirse geri dön, güçlen."]]},
	{"name": "FIRTINA", "sub": "Karadeniz üzeri", "biome": 7, "tint": Color(1, 1, 1), "boss": "firtina_kalesi", "armor": 3, "bspd": 1.2, "dens": 1.3, "swarm": "kamikaze",
		"story": "İklimi değiştiriyorlar. Karadeniz'in üstünde dönen yapay bir fırtına ve ortasında bir kale.",
		"tip": "Çok kalabalık: ALAN ve CAN birlikte.",
		"brief": [["cmd", "Şimşekler gerçek değil, onların silahı."], ["cmd", "Kaleyi sustur, fırtına dağılsın."]]},
	{"name": "BEYAZ SESSİZLİK", "sub": "Kuzey Kutbu", "biome": 8, "tint": Color(1, 1, 1), "boss": "ikiz", "armor": 4, "bspd": 1.2, "dens": 1.2, "swarm": "avci",
		"story": "Kutup buzunun altında bir Vahar üssü: gezegeni kendi iklimlerine göre soğutuyorlar. İki avcı nöbet tutuyor.",
		"tip": "Zırh 4: ZIRH DELME ve büyük tek vuruşlar (lazer, füze, mayın).",
		"brief": [["cmd", "İkiz Avcılar birlikte saldırır. Biri dalarken diğeri ateş eder."], ["pilot", "İkisini de indireceğim."]]},
	{"name": "KUM DENİZİ", "sub": "Sahra Çölü", "biome": 9, "tint": Color(1, 1, 1), "boss": "kum", "armor": 3, "bspd": 1.2, "dens": 1.1, "swarm": "kamikaze",
		"story": "Çölün altında yılan gibi kıvrılan bir gemi kumdan silikon topluyor. Yakında terk edilmiş bir test tesisi var.",
		"tip": "Mermi duvarları: ÇEVİKLİK ve HIZ ile aradaki boşluğu yakala.",
		"brief": [["cmd", "Kum Yılanı'nın etrafında mermi duvarları örülüyor. Boşluğu bul."], ["cmd", "Tesisteki eski proje dosyalarında bir isim geçiyor: ANKA."]]},
	{"name": "DEMİRCİ ADASI", "sub": "Volkanik Ada", "biome": 10, "tint": Color(1, 1, 1), "boss": "dokumhane", "armor": 5, "bspd": 1.25, "dens": 1.3, "swarm": "avci",
		"story": "Volkanların ısısıyla yeni filolar döküyorlar. Dökümhane durmazsa savaş hiç bitmez.",
		"tip": "Zırh 5 + ağır gemiler: hasar ve zırh delme olmadan geçilmez.",
		"brief": [["cmd", "Dökümhane her dakika yeni gemi basıyor. Önce onu durdur."], ["pilot", "Lavın üstünde uçmak... harika."]]},
	{"name": "İNCE HAVA", "sub": "Stratosfer", "biome": 11, "tint": Color(1, 1, 1), "boss": "emici", "armor": 4, "bspd": 1.3, "dens": 1.3, "swarm": "kamikaze",
		"story": "Atmosfer Emici, gökyüzünün en üst katmanından oksijen topluyor. Dünya'da nefes almak zorlaşıyor.",
		"tip": "Çok hızlı mermi + çekim ışını: Motor dalı şart.",
		"brief": [["cmd", "Oksijen seviyeleri yüzde on beş düştü. Zaman yok."], ["cmd", "Emiciyi düşür, Şahin-1. Nefesimizi geri al."]]},
	{"name": "ENKAZ KUŞAĞI", "sub": "Alçak Yörünge", "biome": 12, "tint": Color(1, 1, 1), "boss": "copcu", "armor": 4, "bspd": 1.3, "dens": 1.3, "swarm": "kamikaze",
		"story": "Uydularımızın enkazı yörüngede dönüyor. Vahar çöpçüleri bu hurdadan silah yapıyor.",
		"tip": "En kalabalık bölüm: ALAN + CAN + REJENERASYON.",
		"brief": [["cmd", "Uzaydasın. Geri dönüş yakıtın var, ama fazlası yok."], ["pilot", "Fazlasına ihtiyacım olmayacak."]]},
	{"name": "SEFİNE", "sub": "Yaşam Gemisi", "biome": 13, "tint": Color(1, 1, 1), "boss": "sefine", "armor": 5, "bspd": 1.3, "dens": 1.3, "swarm": "avci",
		"story": "Ay büyüklüğündeki gemi. Kalkanları düştü. Gövdesinin üstünde uçuyorsun; çekirdek tam altında.",
		"tip": "Her şey zor: dengeli ve güçlü bir ağaç gerekir.",
		"brief": [["cmd", "Dünya'nın bütün umudu senin kanatlarında."], ["pilot", "Eve döndüğümde bir kahve borcun var, Komutan."], ["cmd", "İki tane. Git ve bitir şunu."]]},
	{"name": "İLK TEMAS ŞEHRİ", "sub": "İstanbul — Harabeler", "biome": 14, "tint": Color(1, 1, 1), "boss": "varek", "armor": 6, "bspd": 1.3, "dens": 1.3, "swarm": "avci",
		"story": "Sefine düşerken Varek kaçtı ve her şeyin başladığı yere indi: Lyra'nın ilk el sıkıştığı meydana. Şehir artık harabe. Son savaş burada.",
		"tip": "Son savaş. Her dalda derinleşmiş bir ağaç ve doğru uçak gerekir.",
		"brief": [["varek", "Burası ilk el sıkıştığımız yer, pilot. Hatırlıyor musun?"], ["pilot", "Hatırlıyorum. Sonra ne yaptığınızı da."], ["cmd", "Bitir şunu, Şahin-1. Herkes için."]]},
]
## ORTAM TEHLİKELERİ (v0.13): 6. bölümden itibaren her bölgenin kendi tehlikesi. Hepsi önceden işaretlenir (daralan halka /
## kırmızı çizgi), kaçılabilir; yıldırım, lav ve topçu düşmanlara da vurur (taktik: sürüyü işaretin içine çek).
## dmg: oyuncuya taban hasar (x bölümün düşman hasar çarpanı; ağır mermi 15 ile aynı sınıf), cd: saniye, n: bir dalgadaki vuruş
var HAZARDS := {
	5: {"k": "ice", "cd": 9.0, "n": 3, "dmg": 13.0, "name": "Buz sarkıtları", "say": "Zirvede buz sarkıtları kopuyor! Mavi halkalardan uzak dur."},
	6: {"k": "wind", "cd": 13.0, "n": 1, "dmg": 0.0, "name": "Türbülans", "say": "Bulut duvarında türbülans var. Rüzgâr seni savuracak, karşı yönde uç."},
	7: {"k": "bolt", "cd": 6.0, "n": 2, "dmg": 18.0, "name": "Yapay yıldırım", "say": "Şimşekler geliyor! Halka daralınca vurur. Düşmanları içine çek, onları da yakar."},
	8: {"k": "ice", "cd": 8.0, "n": 4, "dmg": 14.0, "name": "Buz yağmuru", "say": "Kutup fırtınası buz yağdırıyor. Halkaları izle."},
	9: {"k": "wind", "cd": 11.0, "n": 1, "dmg": 0.0, "name": "Kum fırtınası", "say": "Kum fırtınası yaklaşıyor. Rüzgâra karşı koy."},
	10: {"k": "lava", "cd": 7.0, "n": 2, "dmg": 20.0, "name": "Lav püskürmesi", "say": "Yanardağ uyanıyor! Turuncu halkalardan lav fışkıracak."},
	11: {"k": "wind", "cd": 10.0, "n": 1, "dmg": 0.0, "name": "Jet akımı", "say": "Jet akımına girdik. Güçlü rüzgâr, dikkat."},
	12: {"k": "debris", "cd": 5.0, "n": 2, "dmg": 20.0, "name": "Uydu enkazı", "say": "Enkaz parçaları kırmızı çizgiyle işaretleniyor. Çizgiden çık!"},
	13: {"k": "beam", "cd": 6.5, "n": 1, "dmg": 24.0, "name": "Savunma ışınları", "say": "Sefine'nin savunma taretleri bizi gördü. Işın çizgilerinden uzak dur!"},
	14: {"k": "arty", "cd": 8.0, "n": 5, "dmg": 18.0, "name": "Vahar topçusu", "say": "Varek şehri bombalıyor! Patlama hattı sana doğru yürüyor."},
}

const BOSS_T0 := 150.0 # 1. bölümde boss 2:30'da gelir, her bölüm +10 sn
func boss_time(k: int) -> float: return BOSS_T0 + 10.0 * (k - 1)

# ---------- Karakterler ----------
var WHO := {
	"cmd": {"n": "KOMUTAN ATLAS", "r": "Dünya Savunma Hava Komutanlığı", "c": Color("4fd8ff"), "tex": "portrait_cmd"},
	"pilot": {"n": "ŞAHİN-1", "r": "Dünyanın en iyi pilotu", "c": Color("ffd34f"), "tex": "portrait_pilot"},
	"lyra": {"n": "ELÇİ LYRA", "r": "Vahar Diplomatı", "c": Color("c9a6ff"), "tex": "portrait_lyra"},
	"varek": {"n": "SAVAŞ LORDU VAREK", "r": "Sefine Komutanı", "c": Color("ff3355"), "tex": "portrait_varek"},
	"vahar": {"n": "VAHAR PİLOTU", "r": "Yakalanan düşman yayını", "c": Color("ff5566"), "tex": "e_avci"},
}
var STORY := {
	"radio": [
		[12, "cmd", "Silahların otomatik ateş eder. Sen sadece uç, kaç ve düşen çekirdekleri topla."],
	],
	"game_over": [
		"Şahin-1 düştü... ama her deneme seni güçlendirir. Pilot Ağacı'na bak ve geri dön.",
		"Bugün kaybettik, ama savaşı değil. Kazandığın puanları harca, tekrar uç.",
		"Her düşüş bir derstir, pilot. Ağacındaki eksik dalı bul.",
		"Varek bu gece kutlama yapıyor. Yarın sabah o kutlamayı yasa çevir.",
		"Paraşütün açıldı, kurtarma ekibi yolda. Uçak hurda ama sen sağlamsın. Yeniden.",
		"Hangar ekibi yeni bir gövde hazırlıyor. Bu sefer neyi farklı yapacaksın, pilot?",
	],
}


# ---------- Telsiz replikleri (her uçuşta havuzlardan rastgele, son duyulanlar tekrar edilmez: Save.heard) ----------
# Lyra'nın gizli kanalı 3. bölümde başlar, 10. bölümde Varek onu yakalar, 14. bölümde kaçar. Kızıl Kanat onun kardeşidir.
var LINES := {
	"takeoff": [
		"Kule: Şahin-1, pist temiz. Kalkış serbest, yolun açık olsun.",
		"Kule: Rüzgar arkadan, yakıt dolu, şarjörler tam. Kalkış serbest!",
		"Kule: Bu pistten kalkan son dört pilot geri dönmedi. Beşinci sen olma, Şahin-1.",
		"Kule: Radar kıpkırmızı. Kalkış serbest, Allah yardımcın olsun.",
		"Kule: Hangar ekibi kokpite bir not bırakmış: \"Geri getir.\" Kalkış serbest.",
		"Kule: Şehirde sirenler susmuyor. Herkes seni izliyor, Şahin-1. Kalkış serbest.",
		"Kule: Pist ışıkları son jeneratörle yanıyor. Hemen kalk, hemen!",
		"Kule: Vahar frekanslarını dinliyoruz, ne duyarsak sana aktaracağız. Kalkış serbest.",
	],
	# her bölüme özel: uçuş başına 2 tanesi seçilir
	"stage": [
		[["cmd", "Midilli'den imdat çağrısı: balıkçı tekneleri ateş altında. Gökyüzünü temizle."],
			["pilot", "Bu sular benim çocukluğum. Kimse burayı yakamaz."],
			["varek", "İlk dalga sadece bir selamdı, pilot. Asıl ordum daha uyanmadı."],
			["vahar", "Avcı Üç'ten Sefine'ye: dünyalılar tek bir uçak gönderdi. Gülünç."],
			["cmd", "Bütün filolar bugün aynı frekansta. Dünya ilk kez tek bayrak altında uçuyor."]],
		[["cmd", "Üssün kapıları kırk dakika dayanır. Sonrası bize kalmaz."],
			["cmd", "Hangarda yaralılar var, Şahin-1. O kapı açılırsa..."],
			["varek", "Saklandığınız deliği bulmak üç gün sürdü. Sizi silmek üç dakika sürecek."],
			["pilot", "Üs düşerse dönecek yerim kalmaz. O yüzden düşmeyecek."],
			["vahar", "Kuşatma hattı kuruldu. Kaçan olursa vurun. Hepsini."]],
		[["cmd", "Derinkuyu'dan sinyal: yeraltında çocuklar var. Matkap her vuruşta yaklaşıyor."],
			["lyra", "...bu frekansı kimse dinlememeli. Şahin-1, matkabın soğutma halkası arkada. Bunu ben söylemedim."],
			["varek", "Binlerce yıl taşın altına saklandınız. Biz binlerce yıl yıldızların altında savaştık."],
			["pilot", "Komutan, şifreli bir kanaldan biri bana yardım ediyor. Bir Vahar."],
			["cmd", "Kim olursa olsun, şimdilik dinle. Ama arkanı ona dönme."]],
		[["cmd", "Radar istasyonunda üç teknisyen kaldı. Kule düşerse onlar da düşer."],
			["varek", "Gözcü Kule'nin gözünden kaçan tek şey merhamettir. Onu zaten kullanmıyoruz."],
			["lyra", "Gözcünün mermileri hızlı ama düz gider. Bir yerde durma, pilot."],
			["pilot", "Dağların arasında rüzgar kesik kesik. Uçak titriyor, ben titremiyorum."],
			["vahar", "Gözcü'den filoya: hedef işaretlendi. Kaçacak yeri yok."]],
		[["cmd", "Kıyıdaki köyler susuz kaldı. Hasatçı her saniye bir havuz dolusu su içiyor."],
			["lyra", "Bizim gezegenimizde son göl de böyle kurudu. Ben oradaydım. Durdur onu."],
			["varek", "Su mu? Biz kendi dünyamızda suyu kanla takas ettik. Sizinki daha ucuz."],
			["vahar", "Hasatçı'dan filoya: tanklar yüzde altmış. Dünyalıyı oyalayın!"],
			["pilot", "Göl her saat bir metre çekiliyor. Bugün çekilmeyecek."]],
		[["cmd", "Zirvede sıcaklık eksi kırk. Motorların buzlanmasın, sürekli hareket et."],
			["pilot", "Nuh'un gemisi burada karaya oturmuş derler. Benimki oturmayacak."],
			["varek", "Dağınızın kalbinde buz, sizin kalbinizde korku var. İkisini de eriteceğim."],
			["lyra", "Varek beni izliyor, kısa konuşacağım: Buz Kırıcı'nın sol yanında zırh ince."],
			["vahar", "Kar körlüğü! Dünyalıyı göremiyorum! Sadece motor sesini duyuyorum!"]],
		[["cmd", "Sekiz bin metredesin. Burada düşersen paraşüt bile seni kurtarmaz."],
			["vahar", "Kızıl Kanat filosu, avcı düzenine geçin. Dünyalının adı Şahin. Avınızı tanıyın."],
			["varek", "Bulutların üstü bizimdir. Burası senin mezarın olacak, pilot."],
			["lyra", "Kızıl Kanat'ın pilotu benim kardeşim, Şahin-1. Lütfen... hızlı olsun."],
			["pilot", "Bulutların üstünde güneş hâlâ doğuyor. Onu da almalarına izin vermem."]],
		[["cmd", "Yıldırımlar kalenin jeneratöründen geliyor. Karadeniz'de dalgalar on metre."],
			["pilot", "Gökyüzü kırmızı yanıp sönüyor. Bu fırtınanın kalbi atıyor sanki."],
			["varek", "Gezegeninizin iklimini bir haftada değiştirdik. Sizin bin yılınız vardı."],
			["vahar", "Kale'den filoya: dünyalı fırtınanın içine girdi. Delilik... ya da cesaret."],
			["lyra", "Kardeşimi düşürdün. Seni affetmeye çalışıyorum. Kalenin kalkanı yıldırımdan sonra iki saniye kapalı."]],
		[["cmd", "Pusula çıldırdı, Şahin-1. Kutupta kör uçuyorsun, gözlerine güven."],
			["lyra", "İkizler aynı zihni paylaşır. Birini yaralarsan diğeri sendeler."],
			["varek", "Gezegeninizi soğutuyoruz. Biz buz dünyalarında büyüdük, siz büyüyemezsiniz."],
			["pilot", "Burada sessizlik o kadar derin ki kendi kalp atışımı duyuyorum."],
			["vahar", "Kutup üssü alarm durumunda! Dünyalı buzun altını görmemeli!"]],
		[["cmd", "Kum fırtınası radarı kör ediyor. Yerdeki gölgelerden gözünü ayırma."],
			["varek", "Lyra... seni duyuyorum. Gizli kanalın artık gizli değil."],
			["lyra", "Beni buldu. Bu son mesajım olabilir, Şahin-1. Tesise git. ANKA hâlâ orada."],
			["pilot", "Çölün ortasında bir parıltı... Komutan, aşağıda bir tesis var."],
			["vahar", "Hain Elçi gözaltında! Tekrar ediyorum, Lyra gözaltında!"]],
		[["cmd", "Dökümhane her dakika bir gemi basıyor. Burada geçen her saniye yeni bir düşman demek."],
			["varek", "Lyra'yı hücreye attım. Sıradaki sensin, pilot."],
			["pilot", "Lyra'yı oradan çıkaracağız, Komutan. Bunu ona borçluyuz."],
			["vahar", "Döküm hattı tam kapasite! Dünyalıyı lavın içine sürün!"],
			["cmd", "Adanın termal haritası kızıl. Lavın üstünde alçak uçma, motorların boğulur."]],
		[["cmd", "Şehirlerde insanlar sokağa oksijen maskesiyle çıkıyor. Bu hava bizim, geri al onu."],
			["varek", "Sizin bir nefesiniz bizim bir çocuğumuzu yaşatıyor. Bunu hiç düşündün mü?"],
			["pilot", "Düşündüm, Varek. Paylaşmayı teklif ettik. Sen almayı seçtin."],
			["lyra", "...hücredeyim ama dinliyorum. Emici'nin ışını kesilirken bir an durur. O an vur."],
			["vahar", "Burada hava yok, dünyalı. Nefesini tut, belki biraz daha yaşarsın."]],
		[["cmd", "Yörüngedesin. Ses yok, rüzgar yok. Sadece sen ve hurda."],
			["pilot", "Bu enkazın içinde bizim hava durumu uydumuz da var. Annem her sabah ona bakardı."],
			["varek", "Çöpçü göğünüzü yiyor, pilot. Yakında yıldızları bile göremeyeceksiniz."],
			["vahar", "Hurdadan yeni avcılar hazır! Sefine'ye yaklaşan tek dünyalı bu, durdurun!"],
			["cmd", "Geri dönüş yakıtın tam ölçülü, Şahin-1. Fazlası yok. Hata payı da yok."]],
		[["cmd", "Gemide milyonlarca sivil Vahar var, Şahin-1. Sadece çekirdeği vur."],
			["lyra", "Hücremden çıktım. Çekirdeğe giden yolu açıyorum. Halkımı değil, Varek'i durdur."],
			["varek", "Gemimi düşürürsen halkımı da öldürürsün. O zaman canavar kim?"],
			["pilot", "Ben yolcuları değil silahları vuruyorum, Varek. Aramızdaki fark bu."],
			["vahar", "Sefine'nin içine girdi! Bütün savunma hatları, ateş serbest!"]],
		[["cmd", "Galata'nın gölgesinden geçiyorsun. Bu şehir bin kez yıkıldı ve bin kez ayağa kalktı."],
			["varek", "Burada Lyra'nın elini sıktınız. O el titriyordu. Benimki titremeyecek."],
			["lyra", "Şahin-1... ne olursa olsun, bu savaştan sonra bir dünya kalsın. İkimiz için de."],
			["pilot", "Her şey burada başladı. Burada bitiyor."],
			["vahar", "Son muhafızlar meydanda! Lord Varek için! Sefine için!"]],
	],
	"varek": [
		"Her düşürdüğün gemi için on tane daha gönderiyorum. Matematik benden yana.",
		"Sana bir teklif: inişe geç, teslim ol. Belki seni bir müzede sergilerim.",
		"Dünyamız öldüğünde ağlamadım, pilot. Seninki için de ağlamayacağım.",
		"Pilotlarım senin adını fısıldıyor. Korkuyla değil, merakla. Ne kadar dayanacaksın?",
		"Yoruluyorsun. Ellerin titriyor. Buradan bile hissediyorum.",
		"Sefine'de bir milyar insan nefes bekliyor. Sen kaç kişiyi kurtarabilirsin?",
		"Komutanın seni ölüme gönderdi ve buna kahramanlık dedi. Ne güzel bir yalan.",
	],
	"vahar": [
		"Kanat lideri, dünyalı arkamızda! Kırın, kırın!",
		"Bu bir pilot değil, bir şeytan! Düzeni bozmayın!",
		"Avcı Yedi düştü! Tekrar ediyorum, Avcı Yedi düştü!",
		"Yakıt yarıda, mermi yarıda... ama emir emirdir. Saldırıya devam.",
		"Lord Varek'in emri açık: dünyalıyı canlı istemiyor.",
		"Eve dönmek istiyorum... dönecek bir ev yok ki.",
		"Sağdan yaklaşın, sağ kanadı zayıf! ...hayır, değilmiş!",
		"Elçi Lyra haklı mıydı? Ya bu savaş... sus, frekans açık!",
	],
	"cmd": [
		"Güzel uçuş, Şahin-1. Yer ekipleri seni ekrandan alkışlıyor.",
		"Sivil tahliye yüzde altmış. Biraz daha oyala onları.",
		"Yakıtın iyi, mühimmat otomatik. Senin tek işin hayatta kalmak.",
		"Uydu görüntüsü: arkanda büyük bir sürü toplanıyor. Başını çevir.",
		"Hangar ekibi bahse girdi: Şahin-1 bugün yüz düşürür. Beni mahcup etme.",
		"Vahar frekansında panik var. Onları korkutuyorsun, pilot.",
		"Kızım ekrandan seni izliyor, Şahin-1. Ona iyi bir son göster.",
	],
	"swarm": [
		"Dikkat! Seni çevreliyorlar!",
		"Radarda kızıl bir halka! Kuşatma geliyor, bir açıklık bul!",
		"Dört bir yandan geliyorlar, Şahin-1! Bir yön seç ve del geç!",
		"Vahar kapanı! Çember daralıyor!",
		"Sürü düzen değiştirdi, etrafını sarıyorlar. Kırıl, kırıl!",
	],
	"boss_near": [
		"Büyük bir sinyal yaklaşıyor. Boss geliyor, Şahin-1. Hazır ol.",
		"Radarda dev bir gölge. Ne topladıysan topla, asıl savaş başlıyor.",
		"Sürü geri çekiliyor... bu iyiye işaret değil. Büyük olan geliyor.",
		"Komuta gemisi atmosfere girdi. Otuz saniye.",
		"Bütün Vahar frekansları sustu. Fırtınadan önceki sessizlik bu.",
	],
	"lowhp": [
		["cmd", "Şahin-1, gövden delik deşik! Oradan çık!"],
		["pilot", "Hidrolik kaybediyorum... ama hâlâ uçuyorum."],
		["cmd", "Hasar raporun kırmızı! Kaçın, toparlan, sonra vur!"],
		["pilot", "Ekranda kırmızı uyarı... sus artık, biliyorum."],
		["varek", "İşte o ses. Bir dünyalının son nefesleri."],
		["pilot", "Bu kadar mı? Daha ısınıyordum."],
	],
	"elite": [
		["cmd", "Altın zırhlı bir gemi! İkmal kapsülü taşıyor. Onu düşür!"],
		["cmd", "Elit sinyal! Taşıdığı kapsülde güçlü bir yükseltme var, belki bir evrim."],
		["vahar", "İkmal gemisinden filoya: kapsülü koruyun, dünyalıya bırakmayın!"],
		["cmd", "Radarda altın renkli bir hedef. Kaçırma, Şahin-1, değeri büyük."],
		["pilot", "Şu parıltı... Vahar ikmal gemisi. O kapsül benim."],
	],
	"chest": [
		["pilot", "Kapsül bende! Mühendisler, iş başına."],
		["cmd", "Mühendislik kapsülü çözdü. Yeni sistemler uçağına aktarılıyor."],
		["pilot", "Onların silahlarını söküp onlara karşı kullanacağım."],
		["cmd", "Vahar teknolojisi... Lyra'nın bahsettiği buydu. Hemen yükle."],
		["vahar", "Kapsülü aldı! İkmal kaybedildi, tekrar ediyorum, ikmal kaybedildi!"],
	],
	"streak": [
		["pilot", "Bir... iki... saymayı bıraktım."],
		["cmd", "Radardaki kızıl noktalar birer birer sönüyor. Devam, Şahin-1!"],
		["vahar", "Filo eriyor! Kim bu pilot?!"],
		["pilot", "Gelin bakalım. Hepiniz gelin."],
		["varek", "Etkileyici. Ölümün daha da etkileyici olacak."],
		["cmd", "Hangar ekibi bahsi kaybetti. Herkes sana borçlu artık."],
	],
	"boss_kill": [
		["cmd", "Hedef düştü! Harika iş, Şahin-1!"],
		["pilot", "Bir tane daha. Sıradaki gelsin."],
		["cmd", "Komuta merkezinde herkes ayakta. Eve dön, pilot."],
		["varek", "Bunun bedelini ödeyeceksin, pilot. Kanla."],
	],
	# bosslar: giriş (biri seçilir) ve canı %30'un altına inince öfke
	"boss": {
		"oncu": ["Ben Öncü'yüm. Benden sonra gelenler benim kadar nazik olmayacak.", "Sefine'nin ilk kılıcıyım. Sen de ilk kurbanım olacaksın.", "!Kanatlarım yanıyor... ama son darbeyi ben vuracağım!"],
		"kusatma": ["Duvarlarınız kâğıttan, kapılarınız camdan.", "Teslim olun da üssünüzü mezara çevirmeyeyim.", "!Bütün bataryalar! Ne kaldıysa dünyalıya ateşleyin!"],
		"matkap": ["Toprağınızın altında ne saklıyorsanız çıkaracağım.", "Her taşı kalkan sanıyorsunuz. Taş delinir.", "!Matkap kırıldı ama seni de yerin dibine götürürüm!"],
		"goz": ["Ben uyumam, göz kırpmam, unutmam.", "Uçuş rotanı üç saniye önceden biliyorum.", "!Merceklerim çatlıyor... ama hâlâ görüyorum!"],
		"su_hasat": ["Her damla bir Vahar çocuğu demek. Geri adım atmayacağım.", "Gölünüz bize bir yıl, size bir hatıra.", "!Tanklarım patlıyor! Ama gölün yarısı çoktan bizim!"],
		"buz": ["Buz sabırlıdır, pilot. Ben de öyle.", "Zirvede tek bir hata, ve sonsuza dek burada kalırsın.", "!Gövdem çatlıyor! Çığ olup seni gömeceğim!"],
		"kizil_kanat": ["Lyra seni bana mı gönderdi? Hain kardeşim artık dünyalılarla mı uçuyor?", "Kızıl Kanat'tan kimse kaçamadı. Sen de kaçamayacaksın.", "!Kanadım koptu... ama alevlerim seni bulacak!"],
		"firtina_kalesi": ["Ben bir fırtınayım. Fırtınalar pazarlık etmez.", "Gökyüzünüz artık benim ritmimle atıyor.", "!Jeneratörler aşırı yükte! Yıldırım hepimizi alsın!"],
		"ikiz": ["Sen bir zihinsin, biz iki. Sen bir kalpsin, biz iki.", "Biri düşerse diğeri intikam alır. Hangisini önce vuracaksın?", "!Kardeşimi yaraladın! Şimdi ikimiz de öfkeliyiz!"],
		"kum": ["Kum her şeyi yutar. İmparatorlukları, şehirleri, pilotları.", "Altında ne saklı olduğunu bilmiyorsun, pilot.", "!Kumun altına çekiliyorum... seni de yanımda götüreceğim!"],
		"dokumhane": ["Ölen her avcım için iki yenisini döküyorum.", "Lavın sıcaklığı benim nefesim.", "!Döküm hattı çöküyor! Son gemileri ateşle!"],
		"emici": ["Her nefesin bana bir hediye.", "Göğünüzün mavisi soluyor. Fark ettin mi?", "!Tanklarım deliniyor! Havanızı geri alamayacaksınız!"],
		"copcu": ["Sizin çöpünüz, benim zırhım.", "Uzay boşluğunda çığlık duyulmaz, pilot.", "!Hurdalarım dağılıyor! Her parça bir mermi olsun!"],
		"sefine": ["Ben bir gemi değilim. Bir halkın son eviyim.", "Milyarlarca Vahar seni izliyor. Onlar için ne olacaksın: katil mi, kurtarıcı mı?", "!Çekirdek kritik! Varek... bizi terk mi ediyorsun?!"],
		"varek": ["Tahtım bu meydanın taşlarından yapıldı. Senin mezarın da öyle olacak.", "Lyra'yı kaybettim, gemimi kaybettim. Kaybedecek hiçbir şeyi kalmamış biriyle savaşıyorsun.", "!Diz çökmeyeceğim! Bir halkın son kralı diz çökmez!"],
	},
}

# ---------- Ara sahneler (fragman tarzı) ----------
var CINE := {
	"intro": [
		{"img": "cine_earth", "text": "2041. Dünya her zamanki gibi dönüyordu..."},
		{"img": "cine_ark", "text": "Ta ki gökyüzünde Ay büyüklüğünde bir gölge belirene kadar. Adını sonradan öğrendik: SEFİNE."},
		{"img": "cine_envoy", "text": "Gemiden inenler bize benziyordu. Aynı genler, aynı yüzler... neredeyse. \"Barış için geldik,\" dedi Elçi Lyra. \"Dünyamız öldü. Sadece nefes almak istiyoruz.\""},
		{"img": "cine_betrayal", "tint": Color(1.2, 0.75, 0.75), "text": "Yalandı. Kendi gezegenlerinin oksijenini ve besinini tüketen Vahar halkı şimdi bizimkini istiyordu. Hepsini."},
		{"img": "cine_squadron", "text": "Orduların çöktüğü gün, bir filo hâlâ uçuyordu."},
		{"img": "cine_pilot", "text": "Şahin-1. Dünyanın en iyi pilotu. Son umut.", "title": "ARKFALL"},
	],
	"oncu": [{"img": "cine_boss_down", "text": "Öncü Avcı Ege'nin sularına gömüldü. İlk zafer bizimdi."},
		{"img": "cine_base", "text": "Hayatta kalanlar Sinop'taki gizli üste toplandı. Ama Vahar peşimizdeydi."}],
	"kusatma": [{"img": "cine_boss_down", "tint": Color(0.9, 1.0, 0.9), "text": "Kuşatma kırıldı. Üs ayakta. Hangardaki prototip artık senin: DOĞAN."},
		{"img": "cine_mountain", "tint": Color(1.15, 0.9, 0.75), "text": "Kapadokya'dan imdat çağrısı geldi. Siviller yeraltında, matkaplar yukarıda."}],
	"matkap": [{"img": "cine_boss_down", "tint": Color(1.2, 0.9, 0.7), "text": "Matkap peribacalarının arasına çakıldı. Yeraltı şehirleri kurtuldu."},
		{"img": "cine_mountain", "text": "Ama Toros'taki son radarımız susmak üzereydi."}],
	"goz": [{"img": "cine_boss_down", "tint": Color(0.8, 1.1, 1.1), "text": "Gözcü Kule devrildi. Radarlarımız yeniden görüyor."},
		{"img": "cine_harvest", "text": "Gördüğümüz şey korkunçtu: Van Gölü'nün suyu göğe doğru emiliyordu."}],
	"su_hasat": [{"img": "cine_boss_down", "tint": Color(0.8, 1.15, 0.9), "text": "Hasatçı düştü, göl kurtuldu. Hangarda bir ses: ŞİMŞEK hazır."},
		{"img": "cine_mountain", "tint": Color(0.85, 0.95, 1.2), "text": "Ağrı'nın buzulları eriyordu. Bir Buz Kırıcı dağın kalbine iniyordu."}],
	"buz": [{"img": "cine_boss_down", "tint": Color(0.85, 0.95, 1.2), "text": "Buz Kırıcı kar yığınlarının altında kaldı. KARTAL artık filoda."},
		{"img": "cine_squadron", "text": "Tırmanma vakti. Vahar hava kuvvetleri bulutların üstünde bekliyor."}],
	"kizil_kanat": [{"img": "cine_boss_down", "tint": Color(1.2, 0.8, 0.7), "text": "Kızıl Kanat bulutların arasında parçalandı."},
		{"img": "cine_squadron", "tint": Color(0.65, 0.72, 0.9), "text": "Radarlarımız Karadeniz'in üstünde dönen yapay bir fırtına gördü."}],
	"firtina_kalesi": [{"img": "cine_boss_down", "tint": Color(0.7, 0.9, 1.1), "text": "Fırtına dağıldı, kale sustu."},
		{"img": "cine_ice", "text": "Ama kutuplardan gelen veriler yanlıştı: buzulların altında bir Vahar üssü vardı."}],
	"ikiz": [{"img": "cine_boss_down", "tint": Color(0.85, 0.95, 1.2), "text": "İkiz Avcılar kutup buzuna gömüldü."},
		{"img": "cine_desert", "text": "Sıradaki sinyal çölden geliyordu. Kumun altında bir şey kıpırdıyordu."}],
	"kum": [{"img": "cine_boss_down", "tint": Color(1.2, 1.05, 0.75), "text": "Kum Yılanı'nın gövdesi çölde kilometrelerce uzandı. Terk edilmiş tesiste efsanevi ANKA bulundu."},
		{"img": "cine_forge", "text": "Vahar filolarının nereden geldiğini öğrendik: volkanik bir adada döküm yapıyorlardı."}],
	"dokumhane": [{"img": "cine_boss_down", "tint": Color(1.25, 0.8, 0.6), "text": "Dökümhane lavın içine çöktü. Yeni gemi gelmeyecek."},
		{"img": "cine_harvest", "tint": Color(0.75, 0.85, 1.2), "text": "Ama gökyüzü inceliyordu. Stratosferde bir emici, havamızı içiyordu."}],
	"emici": [{"img": "cine_boss_down", "tint": Color(0.8, 0.9, 1.2), "text": "Atmosfer Emici düştü. Oksijen seviyeleri yükselmeye başladı."},
		{"img": "cine_space", "text": "Geriye yörünge kaldı. Enkaz kuşağının ardında: SEFİNE."}],
	"copcu": [{"img": "cine_boss_down", "tint": Color(0.85, 0.85, 1.0), "text": "Çöpçü kendi hurdasının içinde parçalandı."},
		{"img": "cine_ark", "text": "Ve işte karşında: Ay büyüklüğünde bir gemi. Kalkanları düşmüş, çekirdeği açıkta."}],
	"sefine": [{"img": "cine_victory", "text": "Sefine'nin çekirdeği çöktü. Gemi parça parça Ay'ın arkasına sürüklendi."},
		{"img": "cine_ruins", "text": "Ama Varek kaçtı. Her şeyin başladığı yere indi: İstanbul'un harabe meydanına."}],
	"varek": [
		{"img": "cine_victory", "tint": Color(1.1, 0.9, 0.85), "text": "Varek'in Tahtı, ilk temas meydanının ortasına çakıldı. Savaş bitti."},
		{"img": "cine_envoy", "tint": Color(0.8, 0.9, 1.15), "text": "Lyra son kez yayına çıktı: \"Hayatta kalanlarımız barış istiyor. Gerçek barış. Bu sefer söz veriyorum.\""},
		{"img": "cine_earth", "text": "Dünya yeniden nefes alıyordu. Ve gökyüzünde, bir pilot eve dönüyordu.", "title": "SON"},
	],
}

# ---------- Pilot Ağacı (Path of Exile tarzı, 129 düğüm) ----------
# Puanlar kategoriler içinde TOPLANIR, kategoriler arası ÇARPILIR: dengeli dağıtım tek kategoriye yığmaktan daha güçlüdür.
const STAT_TXT := {
	"dmg": "+%d%% hasar", "rate": "+%d%% atış hızı", "crit": "+%d%% kritik şansı", "critm": "+%d%% kritik hasarı",
	"area": "+%d%% etki alanı", "xp": "+%d%% çekirdek verimi", "amount": "+%d mermi / füze / dron", "hp": "+%d maks. can",
	"hpp": "%+d%% maks. can", "armor": "+%d zırh", "regen": "+%.1f can/sn", "speed": "%+d%% uçuş hızı", "magnet": "+%d%% toplama menzili",
	"agi": "+%d%% çeviklik", "pen": "+%d zırh delme", "dodge": "+%d%% ıskalatma şansı",
}
# main: ana kol (12), a ve b: çatallar (10). notables: indeks -> düğüm. Son düğümler: a = önemli, b = anahtar taş
var TREE_BRANCHES := [
	{"key": "ates", "name": "BALLISTICS", "ang": -PI / 2, "col": Color("ff7a3c"),
		"main": [{"dmg": 5}, {"crit": 2}, {"dmg": 5}, {"rate": 4}, {"critm": 10}], "main_n": {5: {"n": "TRIGGER DISCIPLINE", "rate": 8, "dmg": 6}, 11: {"n": "WEAPONS MASTER", "dmg": 15}},
		"a": [{"crit": 2}, {"critm": 12}], "a_n": {4: {"n": "MARKSMAN", "crit": 6, "critm": 25}, 9: {"n": "DEADEYE", "crit": 10, "critm": 50}},
		"b": [{"dmg": 5}, {"pen": 1}], "b_n": {4: {"n": "ARMOR PIERCER", "pen": 4}, 9: {"n": "GLASS CANNON", "k": true, "dmg": 40, "hpp": -25}}},
	{"key": "tek", "name": "AVIONICS", "ang": 0.0, "col": Color("b46cff"),
		"main": [{"rate": 4}, {"area": 5}, {"xp": 4}, {"rate": 4}, {"area": 5}], "main_n": {5: {"n": "OVERCLOCK", "rate": 10, "area": 8}, 11: {"n": "SYSTEMS ENGINEER", "area": 15, "rate": 6}},
		"a": [{"area": 6}, {"rate": 4}], "a_n": {4: {"n": "FOCUS ARRAY", "area": 12}, 9: {"n": "WIDE FRONT", "area": 25}},
		"b": [{"xp": 6}, {"rate": 3}], "b_n": {4: {"n": "DATA LINK", "xp": 15}, 9: {"n": "MULTI-FIRE", "k": true, "amount": 1, "rate": -15}}},
	{"key": "govde", "name": "AIRFRAME", "ang": PI / 2, "col": Color("57ff9a"),
		"main": [{"hp": 10}, {"armor": 1}, {"hp": 10}, {"regen": 0.3}], "main_n": {5: {"n": "HEAVY PLATING", "armor": 3}, 11: {"n": "SECOND REACTOR", "hp": 40}},
		"a": [{"armor": 1}, {"hp": 10}], "a_n": {4: {"n": "REACTIVE ARMOR", "armor": 3, "hp": 20}, 9: {"n": "TITANIUM WING", "armor": 6}},
		"b": [{"regen": 0.3}, {"hp": 10}], "b_n": {4: {"n": "REPAIR DRONE", "regen": 1.0}, 9: {"n": "FORTRESS", "k": true, "hp": 80, "armor": 5, "speed": -15}}},
	{"key": "motor", "name": "PROPULSION", "ang": PI, "col": Color("4fd8ff"),
		"main": [{"speed": 3}, {"magnet": 8}, {"agi": 5}, {"speed": 3}], "main_n": {5: {"n": "REHEAT", "speed": 8, "agi": 8}, 11: {"n": "ACROBAT", "agi": 15, "dodge": 4}},
		"a": [{"magnet": 10}, {"xp": 4}], "a_n": {4: {"n": "SALVAGE HUNTER", "magnet": 30}, 9: {"n": "XENO SCAVENGER", "xp": 20, "magnet": 20}},
		"b": [{"speed": 3}, {"dodge": 2}], "b_n": {4: {"n": "EVASION MASTER", "dodge": 6}, 9: {"n": "SOUND BARRIER", "k": true, "speed": 25, "agi": 20, "dmg": 10, "hpp": -15}}},
]
var TREE := {} # id -> {pos, links, stats, name, kind, col}

func _build_tree() -> void:
	TREE["start"] = {"pos": Vector2.ZERO, "links": [], "stats": {}, "name": "PILOT LICENSE", "kind": "start", "col": Color.WHITE}
	for br in TREE_BRANCHES:
		var ang: float = br.ang
		var prev := "start"
		for i in 12:
			var id: String = "%s_m%d" % [br.key, i]
			var spec: Dictionary = br.main_n[i] if br.main_n.has(i) else br.main[i % br.main.size()]
			_tree_node(id, Vector2(cos(ang) * 1.35, sin(ang) * 0.9) * (60.0 + i * 36.0), spec, br, prev); prev = id
		for side in ["a", "b"]:
			var p2 := prev
			var off := -0.28 if side == "a" else 0.28
			var d2 := Vector2(cos(ang + off) * 1.35, sin(ang + off) * 0.9)
			for i in 10:
				var id: String = "%s_%s%d" % [br.key, side, i]
				var nd: Dictionary = br[side + "_n"]
				_tree_node(id, d2 * (500.0 + i * 36.0), nd[i] if nd.has(i) else br[side][i % br[side].size()], br, p2); p2 = id
	for i in TREE_BRANCHES.size(): # komşu dallar arasında halka bağlantıları (iki kat)
		for m in [3, 8]:
			_link("%s_m%d" % [TREE_BRANCHES[i].key, m], "%s_m%d" % [TREE_BRANCHES[(i + 1) % TREE_BRANCHES.size()].key, m])

func _tree_node(id: String, pos: Vector2, spec: Dictionary, br: Dictionary, parent: String) -> void:
	var stats := spec.duplicate(); stats.erase("n"); stats.erase("k")
	var kind := "keystone" if spec.get("k", false) else ("notable" if spec.has("n") else "small")
	TREE[id] = {"pos": pos, "links": [], "stats": stats, "name": spec.get("n", br.name), "kind": kind, "col": br.col}
	_link(id, parent)

func _link(a: String, b: String) -> void:
	if b in TREE[a].links: return
	TREE[a].links.append(b); TREE[b].links.append(a)

func tree_stats(alloc: Array) -> Dictionary:
	var s := {}
	for id in alloc:
		if not TREE.has(id): continue
		for k in TREE[id].stats: s[k] = s.get(k, 0.0) + TREE[id].stats[k]
	return s

func stat_lines(stats: Dictionary) -> Array:
	var out := []
	for k in stats: out.append(STAT_TXT[k] % stats[k])
	return out

# ---------- Girdi ve tema ----------
# ---------- Dil ----------
# Kaynak metinler Türkçe yazılır; lang/<kod>.json dosyaları Türkçe -> çeviri eşlemesidir.
# Çevirisi olmayan metin önce İngilizceye, o da yoksa Türkçeye düşer.
const LANGS := [["tr", "Türkçe"], ["en", "English"], ["de", "Deutsch"], ["fr", "Français"], ["es", "Español"], ["pt_BR", "Português (BR)"], ["ru", "Русский"], ["zh_CN", "简体中文"]]
var lang := "tr"
var _tr := {}
var _en := {}
var _cjk := false
func set_lang(code: String) -> void:
	lang = code
	if code.begins_with("zh") and not _cjk and F_MENU: # Çince: Noto Sans SC (OFL) yedek yazı tipi, sadece gerektiğinde yüklenir
		_cjk = true
		var cjk: FontFile = load("res://fonts/NotoSansSC.ttf")
		var exo: Font = F_MENU.fallbacks[0]
		exo.fallbacks = [cjk]
	_tr = _load_lang(code) if code != "tr" else {}
	_en = _load_lang("en") if code != "tr" and code != "en" else {}
## lang/source.json: Türkçe kaynak metinlerin sabit sıralı listesi; lang/<kod>.txt: "sıra<TAB>çeviri" satırları
## (\n satır sonu). Yeni metin source.json'un SONUNA eklenir, sıra asla değişmez.
var _src: Array = []
func _load_lang(code: String) -> Dictionary:
	if _src.is_empty():
		var sf := FileAccess.open("res://lang/source.json", FileAccess.READ)
		if sf: _src = JSON.parse_string(sf.get_as_text())
	var f := FileAccess.open("res://lang/%s.txt" % code, FileAccess.READ)
	var out := {}
	if f == null: return out
	while not f.eof_reached():
		var ln := f.get_line()
		var tab := ln.find("\t")
		if tab <= 0: continue
		var i := ln.substr(0, tab).to_int()
		if i >= 0 and i < _src.size(): out[_src[i]] = ln.substr(tab + 1).replace("\\n", "\n").replace("\\\"", "\"")
	return out
## Ekrana giden her metin buradan geçer
func L(s) -> String:
	var t := str(s)
	if lang == "tr": return t
	var r: String = _tr.get(t, _en.get(t, t))
	if r == t:
		if OS.get_cmdline_user_args().has("--i18n") and t.strip_edges() != "": print("I18N_MISSING	", t.c_escape())
		return t
	# kaynak metnin baş/son boşlukları korunur (çeviri dosyaları bunları kaybedebilir)
	var core := t.strip_edges()
	return t.substr(0, t.find(core)) + r.strip_edges() + t.substr(t.find(core) + core.length()) if core != "" else r
## İlk açılış: sistem dili destekleniyorsa onu seç
func system_lang() -> String:
	var loc := OS.get_locale()
	for l in LANGS:
		if loc.begins_with(l[0]) or (l[0] == "pt_BR" and loc.begins_with("pt")) or (l[0] == "zh_CN" and loc.begins_with("zh")): return l[0]
	return "en"

var font: FontVariation
var font_bold: FontVariation
var font_warn: FontVariation
var F_MENU: FontFile
var F_GAME: FontFile

## Ekran değişince çağrılır: aynı FontVariation nesnelerinin temeli değişir, tüm yazılar birlikte güncellenir.
func use_fonts(mode: String) -> void:
	var menu := mode == "menu"
	font.base_font = F_MENU if menu else F_GAME; font_bold.base_font = font.base_font
	var W := TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {} if menu else {W: 600}
	font_bold.variation_opentype = {} if menu else {W: 760}

# ---------- Görsel kimlik: bölge renk tonu ----------
# [gölge tonu, ışık tonu, doygunluk, kontrast, üst bulut miktarı, bulut rengi]
var GRADE := [
	[Vector3(0.92, 1.0, 1.06), Vector3(1.07, 1.02, 0.93), 1.12, 1.08, 0.22, Color.WHITE],
	[Vector3(0.95, 1.0, 0.96), Vector3(1.06, 1.03, 0.94), 1.05, 1.1, 0.18, Color.WHITE],
	[Vector3(0.98, 0.92, 0.95), Vector3(1.1, 1.0, 0.86), 1.15, 1.08, 0.12, Color(1, 0.95, 0.9)],
	[Vector3(0.9, 0.98, 1.05), Vector3(1.05, 1.03, 0.95), 1.1, 1.08, 0.25, Color.WHITE],
	[Vector3(0.9, 1.0, 1.08), Vector3(1.05, 1.03, 0.95), 1.12, 1.06, 0.22, Color.WHITE],
	[Vector3(0.88, 0.95, 1.12), Vector3(1.0, 1.02, 1.06), 0.95, 1.1, 0.3, Color.WHITE],
	[Vector3(0.9, 0.95, 1.08), Vector3(1.08, 1.04, 0.96), 1.05, 1.05, 0.16, Color.WHITE],
	[Vector3(0.8, 0.86, 1.05), Vector3(0.95, 0.98, 1.08), 0.8, 1.15, 0.28, Color(0.55, 0.6, 0.7)],
	[Vector3(0.85, 0.95, 1.15), Vector3(1.0, 1.03, 1.08), 0.9, 1.1, 0.2, Color.WHITE],
	[Vector3(1.0, 0.9, 0.85), Vector3(1.12, 1.02, 0.84), 1.15, 1.08, 0.08, Color(1, 0.92, 0.8)],
	[Vector3(0.95, 0.82, 0.85), Vector3(1.15, 0.95, 0.8), 1.2, 1.15, 0.15, Color(0.25, 0.2, 0.2)],
	[Vector3(0.85, 0.9, 1.15), Vector3(1.02, 1.0, 1.05), 1.0, 1.1, 0.12, Color(0.8, 0.85, 1)],
	[Vector3(0.9, 0.9, 1.12), Vector3(1.05, 1.0, 1.05), 1.05, 1.12, 0.0, Color.WHITE],
	[Vector3(0.95, 0.88, 1.1), Vector3(1.08, 1.0, 1.05), 1.08, 1.1, 0.0, Color.WHITE],
	[Vector3(0.92, 0.85, 0.9), Vector3(1.15, 0.95, 0.82), 0.95, 1.15, 0.18, Color(0.3, 0.26, 0.26)],
]

func _ready() -> void:
	_build_req()
	_build_tree()
	assert(TREE.size() == 1 + 4 * 32, "pilot ağacı bozuk")
	assert(SIGS.has(plane("kartal").sig), "imza silahı eksik")
	assert(absf(REQ[7] - 30.9) < 1.5 and REQ[1] < 0.5, "zorluk eğrisi denge_sim.js ile uyuşmuyor")
	assert(rank_info(0).level == 1 and rank_info(100).level == 2, "rütbe eğrisi bozuk")
	assert(wstats("top", 3).n == 2 and wstats("top", 3).dmg == 9 and wstats("top", 2).dmg == 13.5, "silah seviyesi birleştirme bozuk")
	assert(wdiff("top", 1, 2) == "Hasar 10 → 13.5\nToplam güç +35%" or lang != "tr", "kart sayıları bozuk")
	_add_keys("up", [KEY_W, KEY_UP]); _add_keys("down", [KEY_S, KEY_DOWN])
	_add_keys("left", [KEY_A, KEY_LEFT]); _add_keys("right", [KEY_D, KEY_RIGHT])
	_add_keys("pause", [KEY_ESCAPE, KEY_P]); _add_keys("ok", [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER])
	_add_keys("fullscreen", [KEY_F11, KEY_F])
	_add_keys("dash", [KEY_SPACE, KEY_SHIFT])
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_RIGHT; InputMap.action_add_event("dash", mb)
	# gamepad (Xbox düzeni; PlayStation / Switch / Steam Deck aynı fiziksel konumlar): sol çubuk + yön tuşları uçuş,
	# A onay, RB / A atılım, START duraklat, B geri
	_add_axis("left", JOY_AXIS_LEFT_X, -1.0); _add_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("up", JOY_AXIS_LEFT_Y, -1.0); _add_axis("down", JOY_AXIS_LEFT_Y, 1.0)
	_add_pad("left", [JOY_BUTTON_DPAD_LEFT]); _add_pad("right", [JOY_BUTTON_DPAD_RIGHT]); _add_pad("up", [JOY_BUTTON_DPAD_UP]); _add_pad("down", [JOY_BUTTON_DPAD_DOWN])
	_add_pad("ok", [JOY_BUTTON_A]); _add_pad("dash", [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_A]); _add_pad("pause", [JOY_BUTTON_START, JOY_BUTTON_B])
	# Yazı tipleri (hepsi SIL Open Font License, ticari kullanım serbest):
	#   menüler: Black Ops One (askeri şablon) • oyun içi: Oxanium (dijital) • boss uyarısı: Orbitron Black
	var exo: FontFile = load("res://fonts/Exo2.ttf")
	F_MENU = load("res://fonts/BlackOpsOne.ttf"); F_MENU.fallbacks = [exo]
	F_GAME = load("res://fonts/Oxanium.ttf"); F_GAME.fallbacks = [exo]
	var orb: FontFile = load("res://fonts/Orbitron.ttf"); orb.fallbacks = [F_GAME]
	font = FontVariation.new(); font_bold = FontVariation.new()
	font_warn = FontVariation.new(); font_warn.base_font = orb; font_warn.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 900}
	use_fonts("menu")
	ThemeDB.fallback_font = font
	var th := Theme.new(); th.default_font = font; th.default_font_size = 18
	get_tree().root.theme = th

func _add_pad(action: String, bs: Array) -> void:
	for b in bs:
		var e := InputEventJoypadButton.new(); e.button_index = b; e.device = -1; InputMap.action_add_event(action, e)
func _add_axis(action: String, axis: int, v: float) -> void:
	var e := InputEventJoypadMotion.new(); e.axis = axis; e.axis_value = v; e.device = -1; InputMap.action_add_event(action, e)
	InputMap.action_set_deadzone(action, 0.25)

## Son kullanılan cihaz gamepad mi? (ipucu yazıları ve fare yönlendirmesi buna göre değişir)
var pad := false

func _add_keys(action: String, ks: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for k in ks:
		var e := InputEventKey.new(); e.physical_keycode = k; InputMap.action_add_event(action, e)

## 3D stüdyoda çekilmiş 7 karelik yatış şeridi (yoksa null -> SVG kullanılır)
func sheet(name: String) -> Texture2D:
	var p := "res://art/3d/%s.png" % name
	return load(p) if ResourceLoader.exists(p) else null

func tex(name: String) -> Texture2D:
	return load("res://art/%s.svg" % name)
