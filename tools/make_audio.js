// ARKFALL ses efektleri: tamamen kendi sentezimiz. Yumuşak dalgalar (sinüs/üçgen), filtreli gürültü, katmanlı patlamalar, kısa yankı.
// Sık çalan sesler (atış, vuruş, kristal) bilerek kısa, alçak ve tizlikten arındırılmış: kulak yormasın.
// Çalıştır: node tools/make_audio.js   (müzikler: tools/make_music.js)
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, '..', 'audio');
fs.mkdirSync(OUT, { recursive: true });
const SR = 32000;
let seed = 3; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
const buf = sec => new Float32Array(Math.ceil(sec * SR));

// ton: frekans kayması, atak, üstel sönüm, 2 kutuplu alçak geçiren
function tone(B, { t = 0, f = 440, f2 = null, dur = .1, wave = 'sine', vol = .2, att = .004, decay = 6, lp = 0 }) {
  let ph = 0, y1 = 0, y2 = 0; const n = Math.floor(dur * SR), s0 = Math.floor(t * SR), a = lp ? 1 - Math.exp(-2 * Math.PI * lp / SR) : 1;
  for (let i = 0; i < n && s0 + i < B.length; i++) {
    const k = i / n, tt = i / SR, fr = f2 ? f * Math.pow(f2 / f, k) : f; ph += fr / SR; const p = ph % 1;
    const s = wave === 'sine' ? Math.sin(2 * Math.PI * p) : wave === 'tri' ? 1 - 4 * Math.abs(p - .5) : 2 * p - 1;
    y1 += a * (s - y1); y2 += a * (y1 - y2);
    B[s0 + i] += y2 * Math.min(1, tt / att) * Math.exp(-tt * decay) * (1 - k) * vol;
  }
}
// gürültü: alçak + yüksek geçiren, kesim frekansı zamanla kayabilir
function noise(B, { t = 0, dur = .2, vol = .2, lp = 2000, lp2 = null, hp = 0, att = .002, decay = 8 }) {
  let y1 = 0, y2 = 0, h = 0; const n = Math.floor(dur * SR), s0 = Math.floor(t * SR), b = hp ? 1 - Math.exp(-2 * Math.PI * hp / SR) : 0;
  for (let i = 0; i < n && s0 + i < B.length; i++) {
    const k = i / n, tt = i / SR, cut = lp2 ? lp * Math.pow(lp2 / lp, k) : lp, a = 1 - Math.exp(-2 * Math.PI * cut / SR);
    y1 += a * (rnd() * 2 - 1 - y1); y2 += a * (y1 - y2); h += b * (y2 - h);
    B[s0 + i] += (y2 - h) * Math.min(1, tt / att) * Math.exp(-tt * decay) * (1 - k) * vol * 1.8;
  }
}
function reverb(B, wet = .2, size = .6) { // Schroeder: 4 tarak + 2 tüm geçiren
  const out = new Float32Array(B.length);
  for (const d0 of [1557, 1617, 1491, 1422]) { const d = Math.floor(d0 * size * SR / 44100), b = new Float32Array(d); let i = 0, lz = 0;
    for (let n = 0; n < B.length; n++) { const y = b[i]; lz = y * .7 + lz * .3; b[i] = B[n] + lz * .8; out[n] += y * .25; i = (i + 1) % d; } }
  for (const d0 of [225, 556]) { const d = Math.floor(d0 * SR / 44100), b = new Float32Array(d); let i = 0;
    for (let n = 0; n < B.length; n++) { const bo = b[i], y = -out[n] + bo; b[i] = out[n] + bo * .5; out[n] = y; i = (i + 1) % d; } }
  for (let n = 0; n < B.length; n++) B[n] += out[n] * wet;
  return B;
}
function save(name, B, peak = .8) {
  let pk = 0; for (const v of B) pk = Math.max(pk, Math.abs(v));
  const g = peak / Math.max(pk, 1e-6), n = B.length, d = Buffer.alloc(44 + n * 2);
  d.write('RIFF', 0); d.writeUInt32LE(36 + n * 2, 4); d.write('WAVEfmt ', 8); d.writeUInt32LE(16, 16);
  d.writeUInt16LE(1, 20); d.writeUInt16LE(1, 22); d.writeUInt32LE(SR, 24); d.writeUInt32LE(SR * 2, 28);
  d.writeUInt16LE(2, 32); d.writeUInt16LE(16, 34); d.write('data', 36); d.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) d.writeInt16LE(Math.round(Math.tanh(B[i] * g * 1.1) * 30000), 44 + i * 2);
  fs.writeFileSync(path.join(OUT, name + '.wav'), d);
}
const mf = m => 440 * Math.pow(2, (m - 69) / 12);

const S = {};
// --- savaş (sık çalanlar: yumuşak ve kısa) ---
S.shoot = [.08, B => { noise(B, { dur: .05, vol: .35, lp: 2600, lp2: 900, decay: 40 }); tone(B, { f: 220, f2: 110, dur: .06, vol: .5, decay: 35 }); }, .55];
S.hit = [.07, B => { noise(B, { dur: .05, vol: .5, lp: 1400, decay: 45 }); tone(B, { f: 150, f2: 90, dur: .05, vol: .5, decay: 40 }); }, .5];
S.gem = [.25, B => { tone(B, { f: mf(88), dur: .2, vol: .35, decay: 18 }); tone(B, { t: .03, f: mf(95), dur: .18, vol: .18, decay: 20 }); reverb(B, .15, .4); }, .45];
S.boom = [.7, B => { tone(B, { f: 95, f2: 38, dur: .5, vol: .9, decay: 6 }); noise(B, { dur: .55, vol: .7, lp: 1100, lp2: 250, decay: 6 });
  for (let i = 0; i < 6; i++) noise(B, { t: .02 + rnd() * .2, dur: .03, vol: .25, lp: 3000, decay: 60 }); reverb(B, .18, .7); }, .75];
S.bigboom = [2.2, B => { tone(B, { f: 70, f2: 28, dur: 1.4, vol: 1, decay: 2.2 }); noise(B, { dur: 1.6, vol: .8, lp: 900, lp2: 140, decay: 2.2 });
  noise(B, { t: .05, dur: .5, vol: .35, lp: 4000, lp2: 600, decay: 6 }); for (let i = 0; i < 14; i++) noise(B, { t: rnd() * .9, dur: .05, vol: .3, lp: 2500, decay: 40 });
  reverb(B, .35, 1); }, .85];
S.mine = [.7, B => { tone(B, { f: 120, f2: 45, dur: .45, vol: .9, decay: 7 }); noise(B, { dur: .4, vol: .55, lp: 1300, lp2: 300, decay: 8 }); reverb(B, .15, .6); }, .7];
S.missile = [.45, B => { noise(B, { dur: .4, vol: .45, lp: 900, lp2: 3200, hp: 400, att: .03, decay: 5 }); tone(B, { f: 300, f2: 520, dur: .35, wave: 'tri', vol: .08, decay: 6 }); }, .45];
S.laser = [.55, B => { tone(B, { f: 1100, f2: 260, dur: .45, wave: 'tri', vol: .35, decay: 6, lp: 3000 }); tone(B, { f: 90, dur: .4, vol: .5, decay: 7 });
  noise(B, { dur: .35, vol: .15, lp: 6000, hp: 2500, decay: 9 }); reverb(B, .2, .6); }, .6];
S.zap = [.35, B => { for (let i = 0; i < 5; i++) noise(B, { t: i * .045, dur: .04, vol: .4, lp: 7000, hp: 1800, decay: 50 }); tone(B, { f: 600, f2: 180, dur: .25, wave: 'tri', vol: .15, decay: 10 }); }, .5];
S.hurt = [.4, B => { tone(B, { f: 180, f2: 70, dur: .3, wave: 'tri', vol: .7, decay: 9, lp: 1200 }); noise(B, { dur: .25, vol: .55, lp: 1600, lp2: 500, decay: 12 }); }, .75];
S.dash = [.35, B => { noise(B, { dur: .3, vol: .5, lp: 1200, lp2: 5000, hp: 600, att: .05, decay: 6 }); }, .55];
S.warn = [1.6, B => { for (let k = 0; k < 3; k++) { tone(B, { t: k * .52, f: 620, dur: .24, wave: 'tri', vol: .45, decay: 2, lp: 2500 }); tone(B, { t: k * .52 + .24, f: 470, dur: .24, wave: 'tri', vol: .45, decay: 2, lp: 2500 }); } reverb(B, .2, .7); }, .7];
// --- motor: engine / afterburner / sonicboom gerçek kayıtlardan (tools/jet_sounds.py, CREDITS.md) ---
S.whoosh = [1.2, B => { noise(B, { dur: 1.1, vol: .6, lp: 400, lp2: 3500, hp: 250, att: .35, decay: 2.5 }); }, .55];
// --- arayüz ---
S.click = [.05, B => { tone(B, { f: 1100, dur: .03, vol: .4, decay: 80 }); }, .35];
S.select = [.25, B => { tone(B, { f: mf(79), dur: .1, vol: .35, decay: 25 }); tone(B, { t: .07, f: mf(86), dur: .14, vol: .35, decay: 20 }); reverb(B, .12, .4); }, .45];
S.card = [.6, B => { noise(B, { dur: .25, vol: .25, lp: 800, lp2: 4000, hp: 400, att: .08, decay: 8 }); [79, 83, 86].forEach((m, i) => tone(B, { t: .05 + i * .05, f: mf(m), dur: .35, wave: 'tri', vol: .22, decay: 9 })); reverb(B, .22, .6); }, .55];
S.levelup = [1.1, B => { [72, 76, 79, 84].forEach((m, i) => { tone(B, { t: i * .08, f: mf(m), dur: .5, vol: .4, decay: 5 }); tone(B, { t: i * .08, f: mf(m + 12), dur: .3, vol: .1, decay: 9 }); }); reverb(B, .35, .8); }, .65];
S.chest = [1.3, B => { [76, 79, 83, 86, 91].forEach((m, i) => tone(B, { t: i * .07, f: mf(m), dur: .5, vol: .3, decay: 6 })); noise(B, { dur: .6, vol: .12, lp: 8000, hp: 4000, att: .1, decay: 4 }); reverb(B, .4, .9); }, .65];
S.victory = [2.8, B => { [[60, 0], [64, .16], [67, .32], [72, .48]].forEach(([m, t]) => { tone(B, { t, f: mf(m), dur: .45, wave: 'saw', vol: .18, decay: 4, lp: 1800 }); tone(B, { t, f: mf(m), dur: .45, vol: .25, decay: 4 }); });
  [60, 64, 67, 72].forEach(m => { tone(B, { t: .7, f: mf(m), dur: 1.9, wave: 'saw', vol: .1, att: .05, decay: 1.2, lp: 1500 }); tone(B, { t: .7, f: mf(m), dur: 1.9, vol: .18, att: .05, decay: 1.2 }); }); reverb(B, .4, 1); }, .75];
S.gameover = [2.2, B => { [69, 65, 62, 57].forEach((m, i) => tone(B, { t: i * .3, f: mf(m), dur: .7, wave: 'tri', vol: .4, decay: 3, lp: 1500 })); tone(B, { t: 1.2, f: mf(45), dur: 1, vol: .4, decay: 2 }); reverb(B, .45, 1); }, .7];

for (const [k, [sec, fn, pk]] of Object.entries(S)) { const B = buf(sec); fn(B); save(k, B, pk); }
console.log('ses efektleri: ' + Object.keys(S).length);
