# ARKFALL — The Last Sky (v0.14, Godot)

Vampire Survivors tarzı uçak oyunu. Sonsuz gökyüzünde fareyle uçuyorsun, silahlar kendiliğinden ateş ediyor, sürü üstüne geliyor. Kristal toplayıp seviye atladıkça kart seçiyorsun; her uçuş sana kalıcı **pilot puanı** kazandırıyor.

## Çalıştırma
- **Oyunu Baslat.bat** → oyunu açar
- **Godot Editorde Ac.bat** → projeyi Godot editöründe açar
- Godot yoksa: `winget install GodotEngine.GodotEngine`

## Kontroller
| | |
|---|---|
| Uçmak | Fare (uçak imleci takip eder) veya WASD / yön tuşları |
| Ateş | Otomatik |
| Atılım (sadece ŞİMŞEK) | Sağ tık / SPACE / SHIFT |
| Kart seçmek | Tıkla, 1-4 tuşları ya da yön tuşları + SPACE |
| Pilot Ağacı | Tekerlek: yakınlaş, sürükle: kaydır |
| Duraklat / Tam ekran | ESC / F |

## v0.14 değişiklikleri: kozmetik
- **BOYAHANE** (Hangar > BOYAHANE, scripts/locker.gd): uçak başına 19 parça (7 boya, 4 iz, 4 alev, 3 arma, 1 efsane set), 5 nadirlik, canlı önizleme
- **Jeton sadece SONSUZ MOD'da**: her 4 dakika dayanışta 1 jeton; ilk 12 dk yeşil, 12-20 dk turuncu, sonrası kırmızı (daha nadir parça şansı). Jeton uçulan uçağa yazılır, anında kaydedilir (ölünce kaybolmaz). Seferi ilk bitirene tek seferlik 1 turuncu jeton
- Kapsül olasılıkları Data.COS_DROP; aynısı çıkarsa hurda (5 hurda = 1-3. nadirlikten seçim); 10 kapsül 4+ çıkmazsa sonraki en az AS
- Boya ve arma scripts/skin.gd ressamıyla çizilip skin.gdshader ile uçağın kendi gölge/parlamasıyla birleşir; iz (SkinS.TrailFx) ve alev (Exhaust.kind) stilleri; "iz ve alev boyaya uysun" ayarı
- Boss savaşı ölçümle uzatıldı ve 2. faz eklendi (docs/DENGE.md §14)

## v0.13 değişiklikleri
- **Oyun içi 3D arka plan** (shots.gd backdrop): bölgenin 3D dünyası tepeden, katmanlı derinlikle akar (zemin ~%26, bulutlar ~%50 hızla). Kalkışta 2D üs görünür, bulut tabakası delinince 3D dünyaya geçilir. Ayarlar'dan kapatılabilir
- **Okunurluk**: oyuncu uçağı efektlerin üstünde ve renkli dış çizgili; efekt opaklığı ayarı; hasar sayıları KAPALI / SADECE KRİTİK / HEPSİ; büyük duyurular sıraya girer ve ekranın üstünde çıkar, telsiz kutusu boss çubuğuyla çakışmaz
- **His**: güçlü namlu alevi, her düşüşte gövde renginde enkaz kıvılcımı
- **Kart çeşitliliği**: gösterilip seçilmeyen kart her seferinde yarı olasılıkla gelir; boş yuva varken en az bir yeni, sahip olunan varken en az bir yükseltme garanti; yuvalar dolunca tek seferlik TAKTİK kartları (Data.TACTICS)
- **Uçak ustalığı** (Data.MASTERY): her uçağın 5 kademesi, o uçakla uçtukça açılır (Hangar'da görünür, sonuç ekranında XP)
- **Ortam tehlikeleri** (Data.HAZARDS, 6. bölümden itibaren): buz sarkıtı, türbülans / kum fırtınası / jet akımı (rüzgâr), yapay yıldırım, lav püskürmesi, uydu enkazı, savunma ışınları, topçu hattı. Hepsi önceden işaretlenir; yıldırım, lav ve topçu düşmanlara da vurur
- **Boss savaşı** (ölçümle, docs/DENGE.md §14): can x1.67 (Sefine x2.1, Varek x2.3), %50'de 2. faz (kükreme, mermi temizliği, +%15 onarım, saldırı %25 sık), %25'te öfke. Savaş 18 -> ~29 sn. Garajdan çıkışta uçak artık çatının altında
- **Müzik v2** (tools/make_music.js): her harekâtın kendi parçası, boss ve final boss teması, menü; hicaz / frigyen dizileri, ney benzeri nefesli ses, taiko. Eski sürümde davul gürültüsü hiç yazılmıyordu (düzeltildi)

## v0.12 değişiklikleri
- **3D ara sahneler** (scripts/shots.gd + c3d_*.gdshader): gerçek zamanlı gökyüzü, gürültüden arazi / deniz / lav / kum, bulut kümeleri, Dünya ve atmosfer, stüdyonun 3D uçak ve boss modelleri, parçacık duman / ateş / patlama, kontrail, Catmull-Rom sinematik kamera. Her bölüm sonu o bölgenin haritasında, sonraki slayt bir sonraki bölgenin üstünden uçuş
- Kusursuz geçişler: oyun -> sinema çapraz geçiş (son kare erir), sinema bantları kayarak girer, çekim oyunun tepeden bakışıyla biter ve bölüm oradan başlar; müzik geçişleri yumuşak
- Gerçek jet sesleri (CC BY, CREDITS.md): motor, art yakıcı, ses duvarı patlaması; oyun içi AYARLAR (duraklat menüsü); pilot ağacı devre görünümü

## v0.11 değişiklikleri
- Yüzdelik ses ayarı; jet motoru ve art yakıcı sesleri (tools/make_audio.js artık müziğe dokunmuyor)
- Bulut geçişinden sonra üs gizlenir; harita okundaki yazı kesilmez; mıknatıs kristalleri doğrudan çeker
- Boss ölünce şok dalgası haritayı temizler, sonra gösteri ve sonraki harita (gösteride toplanan seviyeler taşınır)
- Silah dengesi yeniden hesaplandı (DENGE.md §12): kartlarda gerçek sayılar ve "Toplam güç %", kapsül +1 sv / 4 seçenek, evrim için silah 5 + pasif 5; 2 yeni pasif
- Bölüm sonu sahnesi canlı: haritanın gökyüzü, bossun 3D modeli düşer, zemine göre çarpma, uçak geçişi; zafer sözleri çeşitlendi

## v0.10 değişiklikleri
- **Harekât:** 15 bölüm 5 harekâta ayrıldı (3'er bölüm). Build harekât boyunca taşınır; harekât içi düşman ölçeği Data.OP_HP/OP_DMG/OP_DENS (DENGE.md §11)
- **Kartlar:** kapsül tek ekran (2 seviye), evrim yalnızca kapsülden (silah 5 + eş pasif 3); yeniden çek / yasakla / atla; lanetli pasif kartları (+2 seviye, kalıcı bedel)
- **İçerik:** 12 silah (+napalm, raylı top, bumerang, topçu, taret), 12 pasif, 12 evrim; 17 düşman türü (her bölge bir yeni tür) ve **Defter** (öldürünce açılan ansiklopedi)
- **Dil:** TR, EN tam; DE, FR, ES, PT-BR, RU, ZH arayüz + oynanış (hikâye İngilizce). Kaynak: lang/source.json (sıra sabit, yeni metin sona), çeviri: lang/<kod>.txt. Ayarlar > DİL
- **Gamepad:** sol çubuk uçuş, A/RB atılım, START duraklat, X/Y kart araçları, sağ çubuk + RT imleç
- **Müzik:** tools/make_music.js (tamamen kendi sentezimiz): menü, iki savaş parçası (harekâta göre), boss
- **Hikâye animasyonu:** konuşan portreler (ağız / göz kırpma / nefes kareleri), sahne parçacıkları (kar, kıvılcım, duman...), şimşek ve ateş ışığı
- Kart yazıları kutuya sığar, sefer haritasında UÇ butonu sabit

## v0.9 değişiklikleri
- Sefer akışı: boss düşünce gösteri manevrası (8 / tono / sarmal) + ses duvarı, sonuç ekranı 8 sn sonra sonraki bölüme geçer, yeni bölüme bulutlardan dalış
- Düşmanlar tür renginde dış çizgi + motor ve çekirdek ışığı; mermiler ateş edenin renginde, 3 sınıf (iğne 6 / kapsül 9 / ok ucu 15 hasar), hiçbiri yuvarlak değil
- Mini eğitim (ilk uçuş, ENTER/TAB ile geçilir), alt kenarda tuş ipuçları, menüde AYARLAR paneli
- Yuvalar 4+4, seviye eğrisi ilerledikçe dikleşir, 7 silah evrimi (5. seviye + eş pasif)
- Bölüm başına 3 yıldız (geç / bütün kapsüller / boss'a hasarsız, her biri +0.5 puan), NORMAL / ZOR / KÂBUS
- Oyuncu uçağı %10 büyük; mermi dokuları savaştan önce üretilir

## v0.8 değişiklikleri
- **Yazı tipleri:** menüler Black Ops One (askeri şablon), oyun içi Oxanium (dijital), boss uyarısı Orbitron. Hepsi SIL OFL, `fonts/` klasöründe lisanslarıyla.
- **Hangardan kalkış:** Blender'da modellenmiş hava üssü (`tools/blender_base.py`). Sığınak kapıları açılır, uçak çatının altından taksi yapar, pist başında art yakıcı yakar, havalanır, bulut tabakasından geçer. Tıkla / SPACE ile atlanır.
- **Düşüş efektleri:** vurulan büyük gemiler, bosslar ve oyuncu dönerek düşer; gölgesiyle buluştuğu yerde haritaya göre çarpar (su sıçraması, toprak, kar, lav, bulut, uzay kıvılcımı, metal).
- **WARNING:** boss gelmeden 3 sn geri sayım, tehlike şeritleri, siren. Boss yüksekten inerek gelir; bölüm sonunda uçak art yakıcıyla ekrandan çıkar.
- **Sonsuz mod:** dalgalar 15 bölgeyi döner (110 sn + boss), her dalgada düşman canı x1.16, hasarı x1.10, sürü %5 kalabalık. Rekorlar dayanma süresine göre ayrı tabloda. Pilot puanı vermez.
- **Renkler:** Vahar gemileri koyu çelik + asit yeşili ışık; tüm düşman mermileri beyaz çekirdekli pembe. Artık karışmıyorlar.
- **İkmal kapsülü:** daha küçük ve sade bir model, ışık sütunu kaldırıldı.
- Geliştirici: `--scene=endless`, `--crash` (düşüş testi), `--pod` (kapsül testi), `--noelite`.

## v0.7 değişiklikleri
- **Telsiz:** ~200 replik. Her uçuşta bölüme özel 2 replik, Varek'in tehditleri, Vahar pilotlarından yakalanan yayınlar, olaylara tepki (kuşatma, düşük can, seri düşürme, elit, kapsül, boss öfkesi). Son duyulanlar sonraki uçuşlarda tekrar edilmez. Lyra'nın gizli kanalı 3. bölümde başlar.
- **İkmal kapsülü:** Blender'da modellenmiş Vahar kapsülü, ışık sütunu ve ekran kenarında yön oku. Bölüm başına 2-5 adet, her biri 3 sistem.
- **Karanlık atmosfer:** pozlama %70, parlak noktalar yumuşatılıyor, patlamalar beyaz değil turuncu ateş ve duman.
- **Jet egzozu:** her uçağın gerçek lülesinden çıkar; hızlanırken art yakıcı, seyirde kısa alev, dönüşte ve yavaşlarken rölanti.

## v0.6 değişiklikleri
- Oyunun adı **ARKFALL — The Last Sky** (Steam'de çakışan isim yok; Ark = Sefine).
- **Uçuş fiziği:** ivme = itki/kütle, en keskin dönüş = kaldırma/hız, yatış = atan(v·ω/g). Her uçağın manevrası farklı: Sparrow 8.9 G, Falcon 10 G, Volt 12.5 G, Aegis 5.7 G, Phoenix 9.3 G.
- **İmza silahları** (kartlarda çıkmaz, seviyeyle güçlenir): VX Twin Vulcan, HX Swarm Rockets, EX Arc Lancer, AX Flak Battery, Ω Solar Lance.
- **Teknik isimler:** uçaklar SPARROW / FALCON / VOLT / AEGIS / PHOENIX; silahlar ve sistemler askeri-bilimsel adlarla; ağaç dalları BALLISTICS / AVIONICS / AIRFRAME / PROPULSION.
- **Toplananlar:** düşen Vahar enerji çekirdekleri (turkuaz < kehribar < kızıl). Mühendislik çözdükçe yeni sistem gelir.
- **Düşmanlar:** koyu kızıl-siyah gövde, neon parlamalar, her zeminde görünen kızıl dış çizgi.
- **15 boss 3D:** Starblast esinli köşeli uzay gemileri (scripts/studio.gd).
- **Arayüz:** Teko yazı tipi, kutusuz düğmeler + süpürülen turuncu bar, kepenk geçişleri, glitch başlık, tarama çizgileri, taktik savaş masası haritası.

## Görsel üretim
- Oyuncu uçakları ve Vahar gemileri: Blender 5.2 + Cycles. Komut: blender -b -P tools/blender_studio.py -- [--only=kartal] [--samples=48]
- Bosslar: Godot stüdyosu (scripts/studio.gd). Blender'a taşınması planda: docs/PLAN_A_KALITE.md

## Hikaye
2041. Bize genetik olarak çok benzeyen ama bizden zalim **Vahar** halkı, kendi gezegenlerinin oksijenini ve besinini tüketip Ay büyüklüğündeki yaşam gemisi **SEFİNE** ile gelir. Elçi Lyra barış vaat eder; Savaş Lordu Varek saldırır. Sen Şahin-1'sin, dünyanın en iyi pilotu. Ara sahneler açılışta, her boss sonrasında ve finalde oynar.

## Sefer haritası (15 bölüm)
Harita aşağıdan yukarıya ilerler; her bölüm hikayede bir yer, kendi zemini, kendi bossu ve kendi tehdidi var:

| # | Yer | Boss | Tehdit → doğru dal |
|---|---|---|---|
| 1 | Ege Denizi | Öncü Avcı | Isınma |
| 2 | Sinop Hava Üssü | Kuşatma Gemisi | Kalabalık → Teknoloji (alan) |
| 3 | Kapadokya | Matkap | Zırh → Ateş Gücü (zırh delme) |
| 4 | Toros Dağları | Gözcü Kule | Hızlı mermi → Motor |
| 5 | Van Gölü | Su Hasatçısı | Çekim ışını → Motor |
| 6 | Ağrı Dağı | Buz Kırıcı | Zırh |
| 7 | Bulut Duvarı | Kızıl Kanat | Hızlı + kalabalık |
| 8 | Fırtına | Fırtına Kalesi | Kalabalık |
| 9 | Kuzey Kutbu | İkiz Avcılar | Zırh |
| 10 | Sahra | Kum Yılanı | Mermi duvarları |
| 11 | Volkanik Ada | Dökümhane | Ağır zırh |
| 12 | Stratosfer | Atmosfer Emici | Hızlı mermi + çekim |
| 13 | Enkaz Kuşağı | Çöpçü | En kalabalık |
| 14 | Sefine | Sefine — Yaşam Gemisi | Her şey |
| 15 | **İlk Temas Şehri** (İstanbul harabeleri) | Varek'in Tahtı | Son savaş |

## Pilot gücü ve zorluk
Ayrıntı ve testler: **docs/DENGE.md** • simülasyon: `node tools/denge_sim.js`
- Güç **Pilot Ağacı**'ndan gelir (129 düğüm, Path of Exile tarzı, 4 dal). Puanı **her uçuş** verir (ilerlemene göre), ilk geçişte +2 bonus. Geçilmiş bölüm tekrarı %25 puan verir; en verimli yol sıradaki zor bölümü tekrar tekrar denemek.
- Haritada her bölümün **önerilen gücü** yazar. Ortalama oyuncu ilk bölümleri 1-2, 7. bölümü ~4, son bölümleri ~6 denemede geçer.

## Uçaklar (kartlarda çıkmayan, uçağa özel yetenekler)
| Uçak | Açılış | Öne çıkan | Yetenek |
|---|---|---|---|
| SERÇE | Başlangıç | Dengeli | 4 kart seçeneği + uçuş başına 2 yeniden çekme |
| DOĞAN | Bölüm 2 | Boss avcısı | 5 sn'de bir 4 ağır füze salvosu, boss/elitlere +%30 hasar |
| ŞİMŞEK | Bölüm 4 | En hızlı/çevik | Atılım: dokunulmaz ileri sıçrama, yolundakileri çarpar |
| KARTAL | Bölüm 6 | En dayanıklı | Her 7 sn'de bir darbeyi emen kalkan + çarpma hasarı |
| ANKA | Bölüm 10 | En güçlü | Uçuş başına bir kez diriliş + büyük patlama |

Her uçağın can barı kendi tarzında: Serçe kapsül, Doğan yay, Şimşek ince çizgi + atılım göstergesi, Kartal plakalı bar + kalkan halkası, Anka halka + diriliş tüyü.

## Düşman sayısı
Sınırsız değil. Vampire Survivors'taki gibi zamanla artan bir hedef sayı var (1. bölümde 10'dan ~47'ye) ve sert bir tavan. Boss gelince sürü ~14'e iner. %2.5 ihtimalle altın renkli **elit** düşman çıkar (6 kat can, sandık düşürür).

## Görsel kimlik (v0.5)
- **3D uçaklar:** Oyuncu uçakları ve Vahar gemileri Godot içinde 3D modellenip profesyonel ışıkla (ana/dolgu/kenar ışığı, gölge, metal-cam malzeme, kamuflaj, nişan) yukarıdan çekilir. Her gemi 7 yatış açısında çekildiği için dönüşlerde kanat gerçekten yatar. Yeniden çekmek için: `godot --path . -- --scene=studio` (tek model: `--only=kartal`). Modeller `scripts/studio.gd` içinde.
- **Efektler:** Bölgeye göre sinematik renk tonu, vinyet, film greni, vuruşta renk kayması ve kırmızı kenar, oyuncunun üstünden geçen bulutlar, kanat ucu kontrailleri, şok dalgaları, duman ve enkaz, vuruşta donma (hit-stop), namlu ateşi.
- **Kimlik:** Exo 2 yazı tipi (SIL OFL, `fonts/` klasörü), Selçuklu yıldızlı kanatlı logo, köşeleri sekiz köşeli yıldızlı arayüz çerçeveleri, menülerde girih deseni. Renk imzası: bizim taraf kehribar + turkuaz, Vahar fildişi + mor.

## Görseller ve sesler
Hepsini kod üretiyor, telif sorunu yok:
- `node tools/make_art.js` → `art/*.svg` (uçaklar, 6 düşman, 15 boss, ikonlar, portreler, 16 ara sahne resmi, sefer haritası)
- `node tools/make_audio.js` → `audio/*.wav`
- Her bölümün zemini `scripts/sky.gdshader` içinde çiziliyor (15 harita türü)

Elle düzenleme için ücretsiz programlar: **Inkscape** (SVG), **Krita** (boyama), **LibreSprite** (piksel). `make_art.js` tekrar çalışırsa elle düzenlenen SVG'lerin üzerine yazar.

## Geliştirici testleri
Bu argümanlarla açılan oyunlar kayıt dosyasına dokunmaz:
```
godot --path . -- --scene=game --stage=6 --time=170                 # 7. bölüm, 2:50'den başla
godot --path . -- --scene=game --auto --lvl                          # otopilot, ölümsüz, tüm silahlar
godot --headless --path . --fixed-fps 60 -- --scene=game --auto --mortal --log --stage=6 --pts=31   # ölebilen test pilotu, 31 puanla
godot --path . -- --scene=game --time=60 --haz=10                    # 10. bölgenin ortam tehlikesini 2 sn'de başlat
godot --path . -- --scene=game --plane=kartal --mast=5               # ustalık kademesi 5 ile uç
godot --path . -- --scene=game --no3d                                # 3D arka planı kapat (2D gökyüzü)
godot --path . -- --scene=locker --tokens --own --wear=6,10,14,17   # BOYAHANE: 5'er jeton, bütün parçalar, takılı parçalar (boya,iz,alev,arma sırası)
godot --path . -- --scene=locker --tokens --open=r                  # kırmızı kapsül açılışı
```
