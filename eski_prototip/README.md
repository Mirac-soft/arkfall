# GÖKKALKAN — Operasyon: Demir Sürü  (v0.1 prototip)

Uçaklı bullet hell. Pistten kalkış animasyonu, komutanlı hikaye, seviye/rütbe sistemi, açılan uçaklar, 3 bölüm + 3 boss, sonsuz tur.

## Nasıl oynanır
- **Hızlı yol:** `index.html` ya da `Oyunu Baslat.bat` dosyasına çift tıkla (tarayıcıda açılır, kurulum yok).
- **Masaüstü uygulaması (Steam'e giden yol):** `npm install` sonra `npm start` (Electron, ~200 MB indirir).

| Eylem | Klavye | Gamepad |
|---|---|---|
| Hareket | Yön tuşları / WASD | Sol analog / D-Pad |
| Ateş | Z / SPACE (basılı tut) | A / RT |
| Hassas uçuş | SHIFT | LB / RB |
| Bomba | X | B / X |
| Duraklat | ESC / P | START |
| Tam ekran | F | – |

## Sistemler
- **Seviye eğrisi:** L → L+1 için `100 × L^1.5` XP. Toplam: Sv3 ≈ 380, Sv6 ≈ 2.800, Sv10 ≈ 11.000, Sv15 ≈ 31.000.
  İlk tam tur (3 bölüm) yaklaşık 3.000–4.000 XP verir.
- **Uçaklar:** SERÇE (başlangıç) → DOĞAN (Sv3) → ŞİMŞEK (Sv6) → KARTAL (Sv10) → ANKA (Sv15).
- **Rütbeler:** Asteğmen → Teğmen → Üsteğmen → Yüzbaşı → Binbaşı → … → Orgeneral.
- **Düşmanlar:** Drone, Kamikaze (kilitlenip dalar), Avcı (3'lü yelpaze), Keskin (lazerle nişan alır), Girdap (spiral), Bombardıman (halka atışı).
- **Bosslar:** Demir Kanat, Fırtına Kalesi, Kara Güneş. Her biri çok aşamalı.
- **Tur sistemi:** 3. boss'tan sonra oyun 1. bölüme döner. Her turda düşmanlar %30 daha dayanıklı olur, mermiler hızlanır, kazanılan XP ×1.5 artar.
- **Rekorlar:** Kişisel en iyi 10 skor (tarayıcıda saklanır). Dünya sıralaması sonraki adımda eklenecek.

## Denge ayarları
Bütün sayılar `js/data.js` içinde: uçak hızı ve ateş gücü, düşman canı ve XP değerleri, boss canları, dalga zamanlamaları, hikaye metinleri.

## Geliştirici kısayolu
`index.html#dev=1` → girişi atlayıp doğrudan 2. bölümden başlar (0, 1, 2).

## Sonraki adımlar (öneri)
1. Steam: Electron + `steamworks.js` (başarımlar, Steam Leaderboard = dünya sıralaması)
2. Daha fazla bölüm/boss, uçaklara özel bomba türleri
3. Ayarlar menüsü (ses seviyesi, tuş atama), dil seçeneği (EN)
