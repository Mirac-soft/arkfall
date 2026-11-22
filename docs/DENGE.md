# Gökkalkan — Denge ve Zorluk Matematiği (v0.4)

Hedef: Oyuncu her bölümü ilk denemede geçemesin. Zorluk arttıkça aynı bölümü birkaç kez oynayıp, her uçuşta kazandığı **pilot puanıyla** Pilot Ağacı'nı geliştirerek ilerlesin. Örneğin 7. bölüm ortalama 4 deneme sürsün. Doğru dala yatırım yapmayan oyuncu zorlansın.

## 1. Esinlenilen oyunlar
| Oyun | Aldığımız fikir |
|---|---|
| Vampire Survivors | Düşman sayısı sınırsız değil: her dakika için "en az şu kadar canlı düşman" hedefi; altına düşünce hızlı doldurur, üstündeyse doğurmaz. |
| Brotato / Halls of Torment | Boss dalgasında normal doğum kısılır; boss kendi çağırdıklarını getirir. |
| Baldur's Gate 3 | Gücü bir eşiğin altındaysan boss gerçekten duvar gibidir; doğru gelişim yapmadan geçilmez. |
| Path of Exile | Pasif ağaç: bağlı düğümlere puan harcanır. Kategoriler içinde bonuslar toplanır, kategoriler arasında çarpılır, böylece dengeli dağıtım tek kategoriye yığmaktan güçlüdür. Anahtar taşlar güçlü ama bedelli. |

## 2. Formüller (`scripts/data.gd` ve `tools/denge_sim.js` aynı)
- `T(k) = min(7, 1.2 + 0.55·(k−1))`: bölüm k için hedef deneme sayısı.
- `V(k) = 1 + 0.08·(k−1)`: bir uçuşun puan değeri. Kazanılan puan = `V · ilerleme`, ilk geçişte +2. Geçilmiş bölüm tekrarı ×0.25.
- `A(k)`: bölüme gelindiğindeki puan. `R(k) = A(k) + (T(k)−1)·0.7·V(k)`: geçmek için gereken puan (önerilen güç). `A(k+1) = R(k) + V(k) + 2`.
- Düşman canı `× (1 + R/120)^2.6`, düşman hasarı `× (1 + R/120)^1.8`.
  Mantık: Ağaçta saldırı puanları üç kategoriye (hasar, atış hızı, kritik) bölünür ve bunlar çarpılır, dolayısıyla oyuncu hasarı da yaklaşık bu üsle büyür. Üsler önce 3 ve 2 seçildi; oyun içi testten sonra 2.6 ve 1.8'e çekildi (bölüm 5).
- Herkes 3 lisans puanıyla başlar. Bu, zayıf oyuncunun 1. bölümde 6 kez takılmasını önler.

| Bölüm | Gelişte puan | Gereken (R) | Düşman canı | Düşman hasarı |
|---|---|---|---|---|
| 1 | 0 | 0 | ×1.0 | ×1.0 |
| 4 | 11 | 13 | ×1.3 | ×1.2 |
| 7 | 28 | 31 | ×1.8 | ×1.5 |
| 10 | 51 | 57 | ×2.7 | ×2.0 |
| 13 | 82 | 89 | ×4.2 | ×2.7 |
| 15 | 109 | 118 | ×5.9 | ×3.4 |

## 3. Simülasyon (Monte Carlo, 4000 oyuncu × 4 beceri düzeyi)
`node tools/denge_sim.js`. Ortalama deneme sayısı:

| Oyuncu | B1 | B3 | B5 | B7 | B10 | B15 | Toplam |
|---|---|---|---|---|---|---|---|
| Zayıf | 2.4 | 2.3 | 3.0 | 4.0 | 5.4 | 5.8 | ~64 uçuş |
| Ortalama | 1.1 | 1.3 | 2.3 | **4.0** | 5.4 | 5.8 | ~59 uçuş (~5 saat) |
| İyi | 1.0 | 1.0 | 1.3 | 3.5 | 5.4 | 5.8 | ~55 uçuş |
| Usta | 1.0 | 1.0 | 1.0 | 2.0 | 5.4 | 5.8 | ~52 uçuş |

Beceri ilk bölümleri hızlandırır, ama 8. bölümden sonra herkes ağacı geliştirmek zorundadır.

## 4. Bölüm karakteri (eğrinin üstüne eklenen tehdit)
Zırh (düz hasar azaltma, en az %25 geçer), mermi hızı (en fazla ×1.3), yoğunluk (en fazla ×1.3). Bunlar doğru dalı seçmeyi gerektirir:
- **Zırhlı bölgeler** (Kapadokya, Ağrı, Kutup, Volkan, Sefine): Ateş Gücü dalındaki zırh delme ve büyük tek vuruşlar (lazer, füze, mayın). EMP ve kalkan dronları zayıflar.
- **Hızlı mermili bölgeler** (Toros, Bulut, Stratosfer): Motor dalı (hız, çeviklik, ıskalatma).
- **Kalabalık bölgeler** (Sinop, Fırtına, Enkaz): Teknoloji dalı (etki alanı, ek mermi).

## 5. Oyun içi doğrulama (gerçek oyun, ölebilen test pilotu)
Test pilotu (`--auto --mortal`) mermi ve düşmanlardan kaçar, kartları otomatik seçer. Ağaç puanları dallara sırayla dağıtılır (`--pts=N`).

**1. tur (üsler 3 / 2, eski tehditler):** 7. bölüm: 31 ❌, 45 ✅. 10. bölüm: 75'te bile ❌. 13. bölüm: 110 ✅. Oyun modelden ~%25 zordu.
→ Üsler 2.6 / 1.8'e çekildi; geç bölümlerin zırh, mermi hızı ve yoğunluk değerleri yumuşatıldı.

**2. tur (şu anki ayarlar):**
| Bölüm | R | Altında | Üstünde |
|---|---|---|---|
| 4 | 13 | 6 ✅ | |
| 7 | 31 | 25 ❌ | 34 ✅ |
| 10 | 57 | 50 ✅ | 62 ✅ |
| 13 | 89 | 85 ❌ (boss'a ulaştı) | 98 ✅ |
| 15 | 118 | 105 ❌ (boss'a ulaştı) | 125 ✅ |

Sonuç: Eşikler modelle örtüşüyor. Test pilotu iyi bir oyuncuya yakın; ortalama bir insan biraz daha fazla denemeye ihtiyaç duyacaktır. Bu tasarımın amacıyla uyumlu.

## 6. Uçak dengesi
Her uçağın kartlarda çıkmayan bir yeteneği var ve her biri farklı bir oyun tarzına hitap ediyor:
- **SERÇE:** 4 kart + 2 yeniden çekme sayesinde en tutarlı build. Yeni başlayana uygun.
- **DOĞAN:** Boss ve elitlere +%30 hasar ve otomatik ağır füze salvosu. Boss bölümlerinde en hızlı.
- **ŞİMŞEK:** Atılımla mermi duvarlarından geçer. Hızlı mermili bölgelerde en iyisi; canı en düşük.
- **KARTAL:** 7 sn'de bir darbeyi emen kalkan ve çarpma hasarı. Kalabalık ve zırhlı bölgelerde en güvenlisi; en yavaşı.
- **ANKA:** En yüksek ham güç ve bir kez diriliş. Geç oyunun güvencesi.

Lazer artık burun yönüne değil en yakın hedefe (boss öncelikli) kilitleniyor; füze hasarı artırıldı.

## 7. Açık noktalar
- Gerçek oyuncu testleri: arkadaşlarınızın deneme sayılarını not edin (oyun her bölüm için deneme sayısını kaydediyor). Ortalama `T(k)`'den çok saparsa `tries()` eğrisi veya üsler ayarlanır.
- Uçak dengesi, uçak başına ayrı test turuyla doğrulanmadı; şu an tasarım mantığına dayanıyor.

## 8. v0.6 yeniden ayar (imza silahları sonrası)
İmza silahları oyuncuyu güçlendirdi: test pilotu önerilen gücün ~%75'iyle geçmeye başladı (B7: 25 ✅, B13: 85 ✅). Düşman ölçeği R/120 → R/90 yapıldı.
Doğrulama (tek uçuş, rastgelelik payı var): B4 6 ✅ · B7 25 ✅ 34 ✅ · B10 50 ✅ 62 ❌ · B13 80 ❌ 98 ❌ · B15 105 ❌ 125 ✅. Eşikler önerilen güç civarında. B7 hafif kolay, B13 hafif zor; gerçek oyuncu testine göre ince ayar yapılacak.

## 9. v0.7: ikmal kapsülleri ve yeniden ayar
**Kapsül (sandık) matematiği.** Eski sistemde her düşman %2.5 ihtimalle elit oluyordu. Ölçüm: 4. bölümde bir uçuşta 14 kapsül, yani kart seçimlerinin yarısı kapsülden geliyordu. Yeni sistem:
- Kapsül = elit gemi. Bölüm başına sabit sayıda gelir: `C(k) = 2 + ⌊k/5⌋` (B1-4: 2, B5-9: 3, B10-14: 4, B15: 5).
- Elitler uçuşa yayılır: `t_i = boss_t · (0.15 + 0.7 · i/(C−1))`, ±%5 sapma. Boss geldikten sonra elit gelmez.
- Her kapsül 3 sistem verir (`Data.CHEST_LV`). Az ama değerli: Vampire Survivors'taki gibi.
- Kaybolan yükseltmelerin bir kısmı seviyeden gelir: uçuş içi seviye eğrisi `5 + 8(l−1)` → `5 + 6(l−1)`.
- Yeni düşman türleri ilk çıktıkları bölümden itibaren 3 bölümde tam ağırlığa çıkar (7. bölümdeki Ağır Gemi sıçramasını yumuşatır).

**Ölçüm sırasında bulunan sorun.** Test pilotu önerilen güçte geç bölümleri geçemiyordu: B7 ~45 (R=31), B10 ~70 (R=57), B13 110'da bile ❌. Bu, 7. bölümün 4-5 deneme yerine 10+ deneme istemesi demekti.
→ Düşman ölçeği R/90 → R/130 (`ENEMY_SCALE`). Bulut Duvarı yoğunluk 1.25→1.1, mermi hızı 1.3→1.2; Sahra yoğunluk 1.2→1.1.

**Doğrulama (her satır ayrı uçuşlar):**
| Bölüm | R | Altında | R'de |
|---|---|---|---|
| 5 | ~18 | | 20 ✅✅ |
| 7 | 31 | 25 ❌❌ | 31 ✅✅❌❌ |
| 10 | 57 | 50 ✅ | 57 ✅❌❌❌ |
| 13 | 89 | 80 ❌ | 89 ✅✅✅ |

Eşikler yeniden önerilen gücün üstüne oturdu. Test pilotunun sonuçları aynı ayarla bile çok dağınık (aynı puanla 70. saniyede de düşebiliyor, bossu da yenebiliyor); gerçek oyuncu deneme sayıları toplandıkça ince ayar yapılmalı.

## 10. v0.9: yavaş build, evrim, zorluk kademeleri

Değişenler: yuva 6+6 → 4+4, `run_need` = 8 + 8(l-1) + 1.5(l-1)² (bölüm başına ~10-20 seviye, eskiden 16-28),
silah evrimi (5. seviye + eş pasif), mermi hasarı sınıfa göre 6/9/15, başlangıç yoğunluğu 10 → 13, boss canı x1.5.
Daha az yükseltmeyle geç bölümler sertleşti; `ENEMY_SCALE` 130 → 170.

| Bölüm | Önerilen | Sonuç (önerilen güçte) |
|---|---|---|
| 1 | 0 | ✅ (boss ~36 sn) |
| 4 | 8 | ✅ |
| 7 | 31 | ✅✅ |
| 10 | 58 | ✅❌ |
| 13 | 93 | ✅❌ |

Zorluk kademeleri (Data.DIFF): ZOR can x1.6 hasar x1.35 puan x1.5, KÂBUS can x2.5 hasar x1.8 puan x2. Bot ile test edilmedi.

## 11. v0.10: harekât sistemi (build 3 bölüm taşınır)

Tasarım: Deep Rock Galactic: Survivor'ın "dalış" yapısından esinlendi. Hedef: zorlasın ama sıkmasın.
- Taşınan build 2. bölüme ~12, 3. bölüme ~18 seçimle girer (taze bölümde ortalama ~6). Kart gücü azalan getirili olduğu için
  etkili güç yaklaşık x1.4 / x1.7. Düşmanlar buna göre: can x1.35 / x1.65, hasar x1.08 / x1.15, yoğunluk x1.05 / x1.1.
- Bölümler arası %40 onarım. Seviye eğrisi devam eder (8 + 8(l-1) + 1.5(l-1)²): harekât başına ~17 seviye + ~6 kapsül, ~26 sn'de bir seçim.
- Kapsül 3 kart yerine tek seçim (2 seviye); kayıp güç ENEMY_SCALE 170 -> 185 ile karşılandı.

Test pilotu, harekâtın İLK bölümünün önerilen gücüyle (en kötü durum):

| Harekât | Güç | Sonuç |
|---|---|---|
| 1 (1-3) | 0 | ✅ |
| 2 (4-6) | 8 | 6. bölümde boss civarı ❌❌ |
| 3 (7-9) | 31 | 8. ve 9. bölümde ❌❌ |
| 4 (10-12) | 58 | ✅ / 11'de ❌ |
| 5 (13-15) | 93 | ✅ / 15'te ❌ |

İlk bölümler her zaman geçiliyor, kayıplar harekât finalinde (boss civarı) yoğunlaşıyor: istenen eğri. Gerçek oyuncu
sonraki bölümlere daha yüksek güçle gelir. ZOR / KÂBUS ve yeni düşman türleri tek tek ölçülmedi.

## 12. v0.11: yükseltme matematiği (türün 20 oyunuyla kıyas)

Şikâyet: bazı kartlar gücü bir anda ikiye katlıyor, kapsül +2 seviyeyle sıçrama büyüyor, evrim kolay geliyor.
Ölçüm (saniye başı hasar yaklaşığı, `Data._power`): v0.10'da L5/L1 oranı Tesla 8.7, EMP 9, taret 8, top 6.8; evrim/L5 3-4.

Kıyaslanan oyunlar ve ortak kalıplar (tasarım kalıpları; birebir sayı kopyalanmadı):
Vampire Survivors, Brotato, HoloCure, Halls of Torment, 20 Minutes Till Dawn, Deep Rock Galactic: Survivor, Soulstone Survivors,
Magic Survival, Death Must Die, Army of Ruin, Bio Prototype, Spirit Hunters, Nova Drift, Hades, Risk of Rain 2,
The Binding of Isaac, Enter the Gungeon, Dead Cells, Slay the Spire, Megabonk.
- Seviye başına artış küçük ve düzenli; "adet +1" gibi büyük sıçramalar, o seviyede hasar düşürülerek dengelenir.
- Evrim / birleşme (VS evrimleri, HoloCure "collab"ları, Brotato aynı kademede iki silah, Hades "duo" lütufları) her zaman
  iki şartın birlikte TAMAMLANMASINI ister ve koşu ortasından önce gelmez.
- Sandık / ödül güç verir ama sıçratmaz: seçenek sayısı ya da nadirlik artar, tek seferde birden çok seviye nadirdir.
- Pasif yüzdeleri çoğunlukla seviye başı %8-10; kalıcı bonuslar azalan getiriyle yığılır.

Yeni kurallar:
- Her silah L1 -> L5 ≈ x3.5, seviye başı ≈ +%25-40 (kartta "Toplam güç %+d" olarak gösterilir).
- Evrim ≈ x2-2.5 (L5'e göre); şart: silah 5 + eş pasif 5 (EVO_PAS) ve yalnızca ikmal kapsülünden.
- Kapsül +1 seviye ama 4 seçenek. Lanetli kart +2 seviye kalır (bedeli var).
- Kalibre %12 -> %10. Yeni pasifler: Son Nefes (yarı canın altında +%8 hasar / sv), Avcı İşareti (elit / boss +%10 / sv).
Harekât içi ölçek yumuşatıldı (OP_HP 1.25 / 1.5, OP_DMG 1.05 / 1.1). Test (harekât başı önerilen güç): ölümler çoğunlukla boss civarında,
2. harekât bir kez baştan sona geçildi.

## 13. v0.13: ortam tehlikeleri, taktik kartları, uçak ustalığı
- **Tehlikeler** (Data.HAZARDS, 6. bölümden): taban hasar 13-24 x bölümün düşman hasar çarpanı (ağır mermiyle aynı sınıf), 5-13 sn'de bir, hepsi 1-1.6 sn önceden işaretli. Rüzgâr: 105 + 4·bölüm px/s, 2.8 sn (oyuncu hızının ~%50'si).
- Bot karşılaştırması (aynı güç, 2'şer deneme): 7. bölüm tehlikeli 1/2, tehlikesiz 1/1; 10. bölüm tehlikeli 1/2, tehlikesiz 0/1. Fark rastlantı payının içinde: tehlikeler bölümü az zorlaştırır, eşikleri kaydırmaz. Harekât 5 (93 puan): 13 ve 14 geçildi, 15'te kayıp (v0.12 ile aynı).
- **Taktik kartları**: bir pasif seviyesinin ~%40'ı (+%4 hasar / atış hızı, +12 can...), sadece yuvalar dolunca ve x0.45 ağırlıkla gelir.
- **Kart tekrarı**: gösterilip seçilmeyen kartın ağırlığı her seferinde x0.5 (en fazla 4 kez: x0.06); seçilince sıfırlanır.
- **Ustalık**: 5 kademe toplamı ~%15-20 güç (ağaçtan küçük); eşikler 1500 / 4500 / 9000 / 15000 / 24000 XP, uçuş başına ~900-1800.

## 14. v0.13: boss savaşı uzunluğu ve 2. faz (ölçümle)
Ölçüm: ölmeyen ama kaçan bot (`--mortal --god --log`), önerilen güç, her bölüm `BOSS` satırı.

| | Önce (BOSS_HP 1.5) | Sonra (2.5, Sefine x1.25, Varek x1.4, 2. faz) |
|---|---|---|
| Savaş süresi | 11-25 sn, ort. 18 | 20-44 sn, ort. 29 |
| Hedef (Sky Force / HoloCure / DRG Survivor) | 30-60 sn | normal 28-35, final ~40 |

- İlk öneri (can x3) reddedildi: bot savaşta saniyede ~%2.7 can kaybediyor, x3 sürede ortalama %145 can kaybı = çoğu boss ölümcül.
- 2. faz (%50 can): 1.2 sn ateşsiz kükreme, ekrandaki mermiler silinir, oyuncu %15 onarılır; sonra saldırı %25 sık, hareket %15 hızlı. %25 canda eski öfke (%43 sık). Boss hasarı artmaz.
- Ölümlü bot harekâtları: 1-3 ✓, 4-6 ✓ (önce 5'te kayıp), 7-8 ✓ 9 ✗, 10-12 ✓ (önce 11'de kayıp), 13-14 ✓ 15 ✗ (3 denemenin 2'si; öncekiyle aynı). Eşikler kaymadı.
- Yeni desenler (her boss'a 2. fazda bir tane) kullanıcı onayı bekliyor.

## 15. v0.14: kozmetik ekonomisi (sadece sonsuz mod)
- Sonsuz modda dayanma (ölümlü bot): 8 puan 10 dk, 31 puan 15 dk, 58 puan 17 dk, 93 puan 24 dk, 129 puan 24 dk.
- Jeton her 240 sn; renk süreye göre (< 12 dk yeşil, < 20 dk turuncu, sonrası kırmızı) -> uçuş başına 2 / 3 / 4 / 5 / 6 jeton.
- Uçak başına 19 parça (nadirlik dağılımı 5/5/5/3/1). Simülasyon (4000 deneme, hurda 5 + 10'lu garanti) tam set:
  zayıf oyuncu ~38 uçuş (~6 sa), orta ~16-22 uçuş (~5 sa), güçlü ~8 uçuş (~3 sa). İlk efsane orta oyuncuda 8-12. uçuşta.
- Kozmetik güç vermez; denge etkisi yok.
