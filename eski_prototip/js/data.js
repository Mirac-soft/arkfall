'use strict';
// ============================================================
//  GÖKKALKAN — oyun verisi (denge ayarlarının hepsi burada)
// ============================================================
const W = 1280, H = 720;          // mantıksal ekran
const FX = 320, FW = 640, FH = 720; // oyun alanı (ortadaki dikey şerit)
const TAU = Math.PI * 2;

// ---------- Seviye eğrisi ----------
// L -> L+1 için gereken XP = 100 * L^1.5
// Erken seviyeler hızlı gelir (ilk uçuşta 2-4 seviye), sonra yavaşlar (RPG'lerdeki polinom eğri).
// Toplam XP: Sv3 = 383, Sv6 ≈ 2.800, Sv10 ≈ 11.000, Sv15 ≈ 31.000
const LEVEL = {
  need: L => Math.round(100 * Math.pow(L, 1.5)),
  info(total) {
    let L = 1;
    while (total >= LEVEL.need(L)) { total -= LEVEL.need(L); L++; }
    return { level: L, into: total, need: LEVEL.need(L) };
  },
  totalFor(L) { let s = 0; for (let i = 1; i < L; i++) s += LEVEL.need(i); return s; },
};
console.assert(LEVEL.info(0).level === 1 && LEVEL.info(99).level === 1 && LEVEL.info(100).level === 2
  && LEVEL.info(LEVEL.totalFor(10)).level === 10 && LEVEL.info(LEVEL.totalFor(10) - 1).level === 9, 'seviye eğrisi bozuk');

const RANKS = [[1, 'ASTEĞMEN'], [3, 'TEĞMEN'], [6, 'ÜSTEĞMEN'], [10, 'YÜZBAŞI'], [15, 'BİNBAŞI'],
  [20, 'YARBAY'], [25, 'ALBAY'], [30, 'TUĞGENERAL'], [40, 'KORGENERAL'], [50, 'ORGENERAL']];
const rankOf = L => RANKS.filter(r => L >= r[0]).pop()[1];

// ---------- Uçaklar ----------
// w: silah. base = güç 0'daki mermi sayısı, per = her güç seviyesinde eklenen mermi,
// spread/fspread = normal/odak modunda yelpaze açısı, mFrom = füzelerin açıldığı güç seviyesi
const PLANES = [
  { id: 'serce', name: 'SERÇE', title: 'T-1 Standart Önleyici', unlock: 1, color: '#4fd8ff', speed: 300, hp: 3, bombs: 2,
    stats: { hiz: 4, ates: 3, zirh: 3, bomba: 2 }, desc: 'Filonun emektarı. Basit, dengeli ve affedici.',
    w: { rate: .085, dmg: 1, base: 2, per: 1, spread: .16, fspread: .04, width: 20, speed: 1100, kind: 'bolt', mFrom: 3, mN: 2, mRate: .6 } },
  { id: 'dogan', name: 'DOĞAN', title: 'F-7 Geniş Açılı Avcı', unlock: 3, color: '#57ff9a', speed: 320, hp: 3, bombs: 3,
    stats: { hiz: 5, ates: 5, zirh: 3, bomba: 3 }, desc: 'Geniş ateş yelpazesiyle sürüleri biçer.',
    w: { rate: .08, dmg: 1, base: 3, per: 1, spread: .75, fspread: .12, width: 16, speed: 1100, kind: 'bolt', mFrom: 4, mN: 2, mRate: .6 } },
  { id: 'simsek', name: 'ŞİMŞEK', title: 'X-9 Delici Önleyici', unlock: 6, color: '#ffe14f', speed: 355, hp: 4, bombs: 3,
    stats: { hiz: 8, ates: 6, zirh: 4, bomba: 3 }, desc: 'Düşmanı delip geçen iğne mermiler ve güdümlü füzeler. Çok hızlı.',
    w: { rate: .06, dmg: .9, base: 2, per: 1, spread: .18, fspread: .02, width: 26, speed: 1500, kind: 'needle', pierce: true, mFrom: 2, mN: 2, mRate: .45 } },
  { id: 'kartal', name: 'KARTAL', title: 'B-12 Ağır Saldırı', unlock: 10, color: '#ff9a3c', speed: 325, hp: 4, bombs: 4,
    stats: { hiz: 6, ates: 8, zirh: 7, bomba: 4 }, desc: 'Ağır zırh, yıkıcı ateş gücü ve füze bataryası.',
    w: { rate: .075, dmg: 1.35, base: 3, per: 2, spread: .85, fspread: .14, width: 22, speed: 1150, kind: 'bolt', mFrom: 1, mN: 2, mRate: .45 } },
  { id: 'anka', name: 'ANKA', title: 'Ω-1 Efsanevi Prototip', unlock: 15, color: '#ff4fd8', speed: 370, hp: 5, bombs: 4,
    stats: { hiz: 9, ates: 10, zirh: 8, bomba: 4 }, desc: 'Küllerinden doğan efsane. Delici alev mermileri, durmayan füze yağmuru.',
    w: { rate: .06, dmg: 1.4, base: 4, per: 2, spread: .8, fspread: .1, width: 24, speed: 1400, kind: 'needle', pierce: true, mFrom: 0, mN: 4, mRate: .35 } },
];

// ---------- Düşmanlar ----------
// drops: P = güç, S = puan (ondalık kısım = şans), B = bomba şansı
const ENEMIES = {
  drone:    { name: 'Drone',     hp: 3,  r: 14, score: 100,  xp: 4,  color: '#ff4f6a', shape: 'drone',   drops: { P: .35, S: .2 } },
  kamikaze: { name: 'Kamikaze',  hp: 5,  r: 14, score: 250,  xp: 8,  color: '#ffe14f', shape: 'dart',    drops: { P: .5, S: .3 } },
  fighter:  { name: 'Avcı',      hp: 10, r: 18, score: 300,  xp: 10, color: '#ff9a3c', shape: 'fighter', drops: { P: 1.3, S: 1 } },
  sniper:   { name: 'Keskin',    hp: 14, r: 17, score: 600,  xp: 16, color: '#57ff9a', shape: 'sniper',  drops: { P: 1.5, S: 1 } },
  spinner:  { name: 'Girdap',    hp: 28, r: 22, score: 800,  xp: 22, color: '#b46cff', shape: 'spinner', drops: { P: 2.5, S: 2 } },
  bomber:   { name: 'Bombardıman', hp: 90, r: 38, score: 2500, xp: 60, color: '#6aa8ff', shape: 'bomber', drops: { P: 4, S: 4, B: .35 } },
};

// ---------- Bosslar ----------
const BOSSES = {
  ironwing: { name: 'DEMİR KANAT', r: 56, color: '#ff5a3c', phases: [350, 450, 550], score: 50000, xp: 400,
    line: 'KIYI HATTI SÜRÜYE AİTTİR. GERİ ÇEKİL, İNSAN.' },
  tempest: { name: 'FIRTINA KALESİ', r: 62, color: '#6aa8ff', phases: [550, 650, 800], score: 80000, xp: 700,
    line: 'FIRTINANIN GÖZÜNE HOŞ GELDİN, ŞAHİN-1.' },
  sentinel: { name: 'KARA GÜNEŞ', r: 50, color: '#ff3355', phases: [700, 800, 950, 1150], score: 150000, xp: 1200,
    line: 'BEN SÜRÜYÜM. SÜRÜ BENİM. VE SEN... YALNIZSIN.' },
};

// ---------- Bölümler ----------
// Dalga: t = saniye, e = düşman, n = adet, x/dx = yatay konum (0-1), dt = aralık,
// m = hareket: down | sine | stop | swoopL | swoopR | dive
const STAGES = [
  { name: 'KIYI HATTI', sub: 'Ege Kıyısı • 06:40', theme: 'dawn', boss: 'ironwing', waves: [
    { t: 1, e: 'drone', n: 5, x: .2, dx: .15, dt: .25, vy: 170 },
    { t: 4, e: 'drone', n: 6, x: .75, dt: .3, m: 'sine', vy: 150, amp: 110 },
    { t: 7.5, e: 'drone', n: 6, x: .25, dt: .3, m: 'sine', vy: 150, amp: 110 },
    { t: 11, e: 'fighter', n: 2, x: .3, dx: .4, m: 'stop', ty: .22, stay: 4 },
    { t: 15, e: 'drone', n: 8, y: .08, dt: .18, m: 'swoopL' },
    { t: 17, e: 'drone', n: 8, y: .12, dt: .18, m: 'swoopR' },
    { t: 20, e: 'fighter', n: 3, x: .2, dx: .3, dt: .4, m: 'stop', ty: .18, stay: 4 },
    { t: 24, e: 'kamikaze', n: 4, x: .15, dx: .23, dt: .5, m: 'dive', ty: .15 },
    { t: 28, e: 'spinner', x: .5, m: 'stop', ty: .25, stay: 6 },
    { t: 29, e: 'drone', n: 6, x: .1, dx: .16, dt: .15, vy: 200 },
    { t: 36, e: 'fighter', n: 4, x: .12, dx: .25, dt: .3, m: 'stop', ty: .2, stay: 3.5 },
    { t: 40, e: 'drone', n: 10, y: .05, dt: .15, m: 'swoopL' },
    { t: 41, e: 'drone', n: 10, y: .1, dt: .15, m: 'swoopR' },
    { t: 45, e: 'kamikaze', n: 6, x: .1, dx: .16, dt: .35, m: 'dive', ty: .12 },
    { t: 49, e: 'spinner', n: 2, x: .25, dx: .5, m: 'stop', ty: .2, stay: 6 },
    { t: 56, e: 'bomber', x: .5, vy: 45 },
    { t: 57, e: 'drone', n: 8, x: .1, dx: .11, dt: .25, vy: 180 },
    { t: 63, e: 'fighter', n: 5, x: .1, dx: .2, dt: .25, m: 'stop', ty: .18, stay: 3 },
  ] },
  { name: 'FIRTINA CEPHESİ', sub: 'Kuzey Denizi • 14:15', theme: 'storm', boss: 'tempest', waves: [
    { t: 1, e: 'drone', n: 8, x: .1, dx: .11, dt: .15, vy: 200 },
    { t: 4, e: 'sniper', n: 2, x: .2, dx: .6, m: 'stop', ty: .15, stay: 6 },
    { t: 6, e: 'drone', n: 8, y: .1, dt: .15, m: 'swoopL' },
    { t: 10, e: 'fighter', n: 4, x: .15, dx: .23, dt: .3, m: 'stop', ty: .25, stay: 4 },
    { t: 14, e: 'kamikaze', n: 6, x: .1, dx: .16, dt: .3, m: 'dive', ty: .12 },
    { t: 18, e: 'bomber', x: .3, vy: 50 },
    { t: 20, e: 'bomber', x: .7, vy: 50 },
    { t: 22, e: 'drone', n: 6, x: .5, dt: .25, m: 'sine', vy: 170, amp: 220, f: 1.6 },
    { t: 27, e: 'spinner', n: 2, x: .2, dx: .6, m: 'stop', ty: .18, stay: 6 },
    { t: 28, e: 'sniper', x: .5, m: 'stop', ty: .1, stay: 7 },
    { t: 35, e: 'drone', n: 10, y: .06, dt: .14, m: 'swoopR' },
    { t: 36, e: 'drone', n: 10, y: .16, dt: .14, m: 'swoopL' },
    { t: 40, e: 'fighter', n: 6, x: .08, dx: .168, dt: .2, m: 'stop', ty: .22, stay: 3.5 },
    { t: 45, e: 'kamikaze', n: 8, x: .06, dx: .125, dt: .25, m: 'dive', ty: .1 },
    { t: 50, e: 'sniper', n: 3, x: .2, dx: .3, dt: .3, m: 'stop', ty: .12, stay: 6 },
    { t: 52, e: 'spinner', x: .5, m: 'stop', ty: .3, stay: 6 },
    { t: 60, e: 'bomber', n: 2, x: .25, dx: .5, dt: 1, vy: 55 },
    { t: 62, e: 'drone', n: 12, x: .05, dx: .08, dt: .12, vy: 220 },
  ] },
  { name: 'YÖRÜNGE KAPISI', sub: 'Atmosfer Sınırı • 23:59', theme: 'orbit', boss: 'sentinel', waves: [
    { t: 1, e: 'fighter', n: 5, x: .1, dx: .2, dt: .2, m: 'stop', ty: .2, stay: 3.5 },
    { t: 5, e: 'drone', n: 12, y: .05, dt: .12, m: 'swoopL' },
    { t: 6, e: 'drone', n: 12, y: .12, dt: .12, m: 'swoopR' },
    { t: 10, e: 'spinner', n: 3, x: .2, dx: .3, m: 'stop', ty: .2, stay: 6 },
    { t: 13, e: 'kamikaze', n: 8, x: .06, dx: .125, dt: .2, m: 'dive', ty: .1 },
    { t: 18, e: 'sniper', n: 4, x: .12, dx: .25, dt: .3, m: 'stop', ty: .1, stay: 6 },
    { t: 20, e: 'bomber', x: .5, vy: 45 },
    { t: 25, e: 'drone', n: 8, x: .3, dt: .2, m: 'sine', vy: 180, amp: 180, f: 2 },
    { t: 26, e: 'drone', n: 8, x: .7, dt: .2, m: 'sine', vy: 180, amp: 180, f: 2 },
    { t: 31, e: 'fighter', n: 6, x: .08, dx: .168, dt: .15, m: 'stop', ty: .25, stay: 4 },
    { t: 33, e: 'spinner', n: 2, x: .3, dx: .4, m: 'stop', ty: .15, stay: 6 },
    { t: 40, e: 'kamikaze', n: 10, x: .05, dx: .1, dt: .18, m: 'dive', ty: .12 },
    { t: 44, e: 'bomber', n: 2, x: .2, dx: .6, vy: 50 },
    { t: 46, e: 'sniper', n: 2, x: .35, dx: .3, m: 'stop', ty: .1, stay: 6 },
    { t: 52, e: 'spinner', n: 4, x: .12, dx: .25, dt: .3, m: 'stop', ty: .2, stay: 5 },
    { t: 58, e: 'drone', n: 14, x: .04, dx: .07, dt: .1, vy: 240 },
    { t: 60, e: 'fighter', n: 6, x: .08, dx: .168, dt: .15, m: 'stop', ty: .2, stay: 3 },
  ] },
];

// ---------- Hikaye ----------
const WHO = {
  cmd:   { n: 'KOMUTAN ATLAS', r: 'Gökkalkan Hava Komutanlığı', c: '#4fd8ff' },
  pilot: { n: 'ŞAHİN-1', r: 'Sen', c: '#ffd34f' },
  enemy: { n: 'DEMİR SÜRÜ', r: 'Bilinmeyen Sinyal', c: '#ff3355' },
};
const L_ = (w, t) => ({ w, t });
const STORY = {
  intro: [
    L_('cmd', 'Şahin-1, uyan. Saat 06:40. Gökkalkan Hava Üssü\'ne hoş geldin.'),
    L_('cmd', 'Üç gün önce Demir Sürü adını verdiğimiz otonom savaş ağı kontrolden çıktı. Kendini üretiyor, kendini yönetiyor.'),
    L_('cmd', 'Kıyı radarlarımızı tek tek kör ettiler. Ege hattında elimizde kalan son filo biziz.'),
    L_('pilot', 'Emirleriniz, Komutan?'),
    L_('cmd', 'Kıyı hattını temizle. Sürünün öncü birliklerini "Demir Kanat" adlı ağır bir saldırı uçağı yönetiyor. Onu düşür.'),
    L_('cmd', 'Unutma: uçağın büyük ama vurulabilen noktası küçük. SHIFT ile hassas uçuşa geç, mermilerin arasından süzül. Sıkışırsan X ile bombayı ateşle.'),
    L_('cmd', 'Düşürdüğün her düşman sana tecrübe kazandırır. Rütben yükseldikçe mühendislik yeni uçakları sana açacak.'),
    L_('cmd', 'Pist senin, Şahin-1. Kalkış izni verildi.'),
  ],
  introShort: [
    L_('cmd', 'Tekrar hoş geldin, Şahin-1. Kıyı hattı yine sürüyle dolu.'),
    L_('cmd', 'Pist senin. Bu sefer daha ileri git.'),
  ],
  bossDown: [
    [
      L_('cmd', 'Demir Kanat düştü! Kıyı radarları yeniden açılıyor... İyi iş, pilot.'),
      L_('enemy', '...ANALİZ TAMAMLANDI. TEHDİT SEVİYESİ GÜNCELLENDİ. ŞAHİN-1 HEDEF OLARAK İŞARETLENDİ.'),
      L_('cmd', 'Bu... sürü bizimle konuşuyor. Bunu daha önce hiç yapmamışlardı.'),
      L_('cmd', 'Sinyalin kaynağı kuzeydeki fırtına cephesinin içinde. Orada bir taşıyıcı kale saklanıyor: Fırtına Kalesi.'),
      L_('cmd', 'Fırtına sensörlerini bozacak. Gözlerine güven. Git ve o kaleyi denize göm.'),
    ],
    [
      L_('cmd', 'Kale çöktü! Ama Şahin-1... kalenin veri çekirdeğinden bir şey çıkardık.'),
      L_('cmd', 'Demir Sürü dünyada değil, yörüngede doğmuş. Eski bir savunma uydusu: KARA GÜNEŞ. Bütün sürü ondan emir alıyor.'),
      L_('pilot', 'O zaman yukarı çıkıyoruz.'),
      L_('cmd', 'Uçağın atmosfer sınırına dayanacak şekilde güçlendirildi. Ama bu tek yönlü bir bilet olabilir, pilot.'),
      L_('enemy', 'YUKARI GEL, KÜÇÜK KUŞ. GÜNEŞE YAKLAŞAN KANATLAR ERİR.'),
      L_('cmd', '...Onu dinleme. Ve geri dön, Şahin-1. Bu bir emir.'),
    ],
    [
      L_('enemy', 'HATA... HATA... ÇEKİRDEK... ÇÖKÜYOR... SÜRÜ... YENİDEN... DOĞAR...'),
      L_('cmd', 'Kara Güneş sustu! Bütün sürü sinyalleri kesildi... Başardın, Şahin-1!'),
      L_('cmd', '...Bir dakika. Radarda yeni imzalar var. Sürünün yedek kopyaları yeniden toplanıyor. Daha hızlı, daha sert.'),
      L_('pilot', 'Yakıtım var, mermim var. Devam ediyorum.'),
      L_('cmd', 'Bu savaş bitmedi pilot. Kıyı hattına dön. Bu sefer kolay olmayacak.'),
    ],
  ],
  unlock: {
    dogan: 'Şahin-1, mühendislik DOĞAN\'ı hazırladı. Geniş açılı ateş, daha çevik. Hangarda seni bekliyor.',
    simsek: 'ŞİMŞEK\'in kilidi açıldı. Delici mermiler ve güdümlü füzeler. Hızına yetişebilirsen tabii.',
    kartal: 'KARTAL hangarda. Ağır zırh, yıkıcı ateş gücü. Sürü artık senden korkacak.',
    anka: 'Pilot... ANKA projesine erişimin onaylandı. Küllerinden doğan bir efsane. Ona iyi bak.',
  },
  takeoff: 'Kule: Şahin-1, pist temiz, rüzgar sakin. Kalkış serbest!',
  loop: 'Sürü yeniden toplandı ve güçlendi. Gözünü dört aç, Şahin-1!',
  hit: ['Şahin-1, hasar aldın! Yedek uçak fırlatılıyor!', 'Toparlan pilot, sürü acımaz!', 'Kalkanların gitti! Yeni uçak yolda!'],
  gameOver: [
    'Şahin-1 düştü... Kurtarma ekibi yolda. Dinlen pilot, gökyüzü seni bekleyecek.',
    'Bugün kaybettik, ama savaşı değil. Hangara dön ve yeniden hazırlan.',
    'Her düşüş bir derstir, pilot. Kalk ve tekrar uç.',
  ],
};
