// Gökkalkan denge simülasyonu: 15 bölümlük seferde oyuncu kaç denemede ilerler?
// Çalıştır: node tools/denge_sim.js
// Model (data.gd ile aynı formüller):
//   T(k)  = hedef deneme sayısı      = min(7, 1.2 + 0.55(k-1))
//   V(k)  = bir denemenin puan değeri = 1 + 0.08(k-1)   (deneme puanı = V * ilerleme)
//   İlk geçiş bonusu = 2 puan. Geçilmiş bölüm tekrarı = %25 puan.
//   A(k)  = bölüme gelindiğindeki puan,  R(k) = bölümü geçmek için gereken puan
//   R(k)  = A(k) + (T(k)-1) * 0.7 * V(k)     (başarısız denemelerin ortalama ilerlemesi ~%70)
//   A(k+1)= R(k) + V(k) + 2
//   Düşman canı  x (1 + R/130)^2.6 (data.gd ENEMY_SCALE; oyun içi testle ayarlandı)
//   Düşman hasarı x (1 + R/130)^1.8
const K = 15;
const T = k => Math.min(7, 1.2 + 0.55 * (k - 1));
const V = k => 1 + 0.08 * (k - 1);
const R = [], A = [0, 0];
for (let k = 1; k <= K; k++) { R[k] = A[k] + (T(k) - 1) * 0.7 * V(k); A[k + 1] = R[k] + V(k) + 2; }

console.log('Bölüm | Gelişte puan | Gereken puan | Düşman canı | Düşman hasarı');
for (let k = 1; k <= K; k++) console.log(`${String(k).padStart(5)} | ${A[k].toFixed(1).padStart(12)} | ${R[k].toFixed(1).padStart(12)} | x${Math.pow(1 + R[k] / 130, 2.6).toFixed(2).padStart(9)} | x${Math.pow(1 + R[k] / 130, 1.8).toFixed(2)}`);

// Monte Carlo: oyuncu becerisi (puan cinsinden) ve her denemedeki şans
function gauss() { let u = 0, v = 0; while (!u) u = Math.random(); while (!v) v = Math.random(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); }
function play(skill) {
  let pts = 3; const tries = []; // herkes 3 başlangıç puanıyla başlar
  for (let k = 1; k <= K; k++) {
    let n = 0;
    for (;;) {
      n++; if (n > 60) return null;
      const eff = pts + skill + gauss() * 2.5;  // o günkü performans
      const m = eff - R[k];
      if (m >= 0) { pts += V(k) + 2; break; }
      const prog = Math.max(0.15, Math.min(0.95, 1 + m / (0.4 * R[k] + 6)));
      pts += V(k) * prog;
    }
    tries.push(n);
  }
  return tries;
}
for (const [name, sk] of [['zayıf oyuncu (-1σ)', -4], ['ortalama oyuncu', 0], ['iyi oyuncu (+1σ)', 4], ['usta (+2σ)', 8]]) {
  const N = 4000, sum = Array(K).fill(0); let done = 0;
  for (let i = 0; i < N; i++) { const r = play(sk); if (!r) continue; done++; r.forEach((n, j) => sum[j] += n); }
  const avg = sum.map(s => s / done);
  const total = avg.reduce((a, b) => a + b, 0);
  console.log(`\n${name}: ortalama deneme/bölüm = ${avg.map(x => x.toFixed(1)).join(' ')}`);
  console.log(`  toplam ~${total.toFixed(0)} uçuş, ~${(total * 5 / 60).toFixed(1)} saat (uçuş başı ~5 dk)`);
}
