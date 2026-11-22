# ARKFALL — "A Kalite" Yeniden Tasarım Planı

İstek: oyunun içindeki her şeyi (karakterler, uçaklar, silahlar, özellikler, bosslar) hikayeye uygun, büyük bir stüdyodan çıkmış gibi baştan tasarlamak.

Bu tek seferlik bir iş değil, sırayla yürütülecek bir proje. Her aşama bitince oyun oynanabilir kalır ve birlikte değerlendiririz.

## Durum (v0.6 sonu)
- **Blender kurulu (5.2).** `tools/blender_studio.py` ile oyuncu uçakları ve 6 Vahar gemisi Cycles ile render ediliyor. 15 boss hâlâ Godot stüdyosunda (`scripts/studio.gd`) üretiliyor.
- **Zorluk eğrisi imza silahlarından sonra yeniden ayarlandı:** düşman ölçeği R/120 → R/90. Ayrıntı `docs/DENGE.md` içinde.

## Aşamalar (önerilen sıra)
1. **Sanat kitabı (art bible).** İki tarafın görsel dili, renk paletleri, silüet kuralları, malzeme listesi.
   - Dünya Savunma: kehribar, turkuaz, askeri gri, kamuflaj.
   - Vahar: kızıl, siyah, organik-metal, neon.
   - Her şey bu kurallara göre üretilir. Önce tek sayfalık bir referans panosu hazırlanıp onaylanır.
2. **Uçaklar (Blender, yüksek detay).**
   - 5 uçak yeniden modellenir: gerçek kanat profili, hava girişleri, iniş takımı kapakları, yazı/numara, kirlenme ve aşınma dokusu.
   - Her uçağın imza silahı model üzerinde görünür (taret, roket kapsülü, ark bobini…).
3. **Vahar filosu ve 15 boss (Blender).**
   - Düşmanlar kademeli bir aile olarak tasarlanır (gözcü → avcı → ağır gemi).
   - Her boss bölgesinin hikayesine göre tasarlanır ve birden çok aşamalı (parçalanan zırh, açılan çekirdek) görsellere sahip olur.
4. **Karakterler.**
   - Komutan Atlas, Şahin-1, Lyra ve Varek Blender'da 3D büst olarak modellenir; portreler ve ara sahne kareleri bu modellerden render edilir.
   - Her karakter için konuşurken değişen 2-3 ifade karesi hazırlanır.
5. **Silahlar ve sistemler.**
   - Her silaha bir "evrim" eklenir: 5. seviye + belirli bir sistem = süper silah (örnek: Photon Lance + Cryogenic Coolant → Solar Flare).
   - Silah efektleri (mermi, iz, isabet) Blender'da render edilen sprite'larla yenilenir.
6. **Hikaye ve ara sahneler.**
   - Senaryo bölüm bölüm yeniden yazılır.
   - Ara sahne kareleri Blender'da kurulan sahnelerden render edilir (SVG çizimlerin yerine).
7. **Ses.** Sentez seslerin yerine kaliteli, telifsiz (CC0) ses paketleri ve bölge temalı müzikler.
8. **Arayüz ve dil.** HUD'un son tasarımı, İngilizce ve Türkçe dil desteği (uluslararası çıkış için).

## Dürüst not
Kodla ve Blender betikleriyle "iyi bir bağımsız oyun" kalitesine çıkabiliriz. Gerçek AAA görünüm (el ile modellenmiş, dokulanmış karakterler; özel bestelenmiş müzik) için ilerde bir 3D sanatçı ve bir besteci ile çalışmak gerekir. Bu boru hattı (Blender → sprite şeridi → oyun) sanatçının modellerini de olduğu gibi kabul edecek şekilde hazır.

## Sonraki oturumda ilk adım
1. aşama: sanat kitabı ve referans panosu. Onaylandıktan sonra 2. aşamaya (uçaklar) geçilir.
