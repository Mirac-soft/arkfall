// ARKFALL müzik bestecisi v2: tamamen kendi sentezimiz (telif yok, örnek ses yok).
// Her harekâtın kendi parçası + boss + final boss + menü. Türk kimliği: hicaz / frigyen dizileri, ney benzeri nefesli ses, taiko-davul.
// Çalıştır: node tools/make_music.js  ->  audio/music_*.wav (kusursuz döngü; Godot içe aktarırken QOA ile sıkıştırır)
// v2 düzeltmesi: eski sürümde gürültü (trampet / zil / rüzgar) yazan satır yorumda kalmıştı, davullar eksik çalıyordu.
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, '..', 'audio');
const SR = 32000;
let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647; // tekrarlanabilir rastgelelik
const mf = m => 440 * Math.pow(2, (m - 69) / 12);
const track = sec => ({ L: new Float32Array(Math.ceil(sec * SR)), R: new Float32Array(Math.ceil(sec * SR)) });
const SCALES = { minor: [0, 2, 3, 5, 7, 8, 10], hicaz: [0, 1, 4, 5, 7, 8, 10], dorian: [0, 2, 3, 5, 7, 9, 10], phryg: [0, 1, 3, 5, 7, 8, 10], harm: [0, 2, 3, 5, 7, 8, 11] };
const deg = (sc, d) => { const n = sc.length, o = Math.floor(d / n); return sc[((d % n) + n) % n] + 12 * o; };

// ---------- sesler ----------
// süpersaw / kare / üçgen / sinüs; unison (uni) sesleri stereoya yayılır; vib: vibrato (cent); swell: filtre yavaş açılır (pirinç)
function voice(T, { t, f, dur, wave = 'saw', vol = .1, att = .01, rel = .2, lp = 3000, lpEnv = 0, swell = 0, det = 0, uni = 3, pan = 0, glide = 0, vib = 0, vibR = 5.5, drive = 0 }) {
  const n = Math.floor((dur + rel) * SR), s0 = Math.floor(t * SR);
  const dets = det ? Array.from({ length: uni }, (_, k) => uni === 1 ? 0 : -det + 2 * det * k / (uni - 1)) : [0];
  const ph = dets.map(() => rnd()), pk = dets.map((_, k) => dets.length > 1 ? (k / (dets.length - 1) * 2 - 1) * .7 : 0);
  let l1 = 0, l2 = 0, r1 = 0, r2 = 0;
  for (let i = 0; i < n && s0 + i < T.L.length; i++) {
    const tt = i / SR;
    const env = Math.min(1, tt / att) * (tt < dur ? 1 : Math.max(0, 1 - (tt - dur) / rel));
    const vb = vib ? Math.pow(2, vib / 1200 * Math.sin(2 * Math.PI * vibR * tt) * Math.min(1, tt / .35)) : 1;
    const fr = f * vb * (glide ? Math.pow(2, glide * Math.max(0, 1 - tt * 8)) : 1);
    let sl = 0, sr = 0;
    for (let k = 0; k < dets.length; k++) {
      ph[k] = (ph[k] + fr * Math.pow(2, dets[k] / 1200) / SR) % 1;
      const p = ph[k];
      const s = wave === 'saw' ? 2 * p - 1 : wave === 'sq' ? (p < .5 ? .8 : -.8) : wave === 'sine' ? Math.sin(2 * Math.PI * p) : 1 - 4 * Math.abs(p - .5);
      sl += s * Math.sqrt((1 - pk[k]) / 2); sr += s * Math.sqrt((1 + pk[k]) / 2);
    }
    sl /= dets.length; sr /= dets.length;
    const cut = Math.min(SR * .45, lp * (1 + lpEnv * Math.exp(-tt * 6)) * (swell ? .35 + swell * Math.min(1, tt / .18) : 1));
    const a = 1 - Math.exp(-2 * Math.PI * cut / SR);
    l1 += a * (sl - l1); l2 += a * (l1 - l2); r1 += a * (sr - r1); r2 += a * (r1 - r2);
    let vl = l2, vr = r2;
    if (drive) { vl = Math.tanh(vl * (1 + drive * 4)) / (1 + drive); vr = Math.tanh(vr * (1 + drive * 4)) / (1 + drive); }
    const gl = Math.sqrt((1 - pan) / 2) * 1.41, gr = Math.sqrt((1 + pan) / 2) * 1.41;
    T.L[s0 + i] += vl * env * vol * gl; T.R[s0 + i] += vr * env * vol * gr;
  }
}
// ney benzeri nefesli: sinüs + zayıf harmonikler + perdeye ayarlı nefes gürültüsü, geç başlayan vibrato
function ney(T, { t, f, dur, vol = .08, pan = 0, rel = .25 }) {
  const n = Math.floor((dur + rel) * SR), s0 = Math.floor(t * SR); let ph = 0, y = 0, z = 0;
  const a = 1 - Math.exp(-2 * Math.PI * Math.min(9000, f * 2.5) / SR);
  for (let i = 0; i < n && s0 + i < T.L.length; i++) {
    const tt = i / SR, env = Math.min(1, tt / .07) * (tt < dur ? 1 : Math.max(0, 1 - (tt - dur) / rel));
    const vb = Math.pow(2, 16 / 1200 * Math.sin(2 * Math.PI * 5.2 * tt) * Math.min(1, Math.max(0, tt - .15) / .3));
    ph = (ph + f * vb * (1 + .006 * Math.exp(-tt * 20)) / SR) % 1;
    y += a * (rnd() * 2 - 1 - y); z += a * (y - z);
    const s = Math.sin(2 * Math.PI * ph) + .22 * Math.sin(4 * Math.PI * ph) + .07 * Math.sin(6 * Math.PI * ph) + z * (.55 + .5 * Math.exp(-tt * 12));
    const v = s * env * vol;
    T.L[s0 + i] += v * Math.sqrt((1 - pan) / 2) * 1.41; T.R[s0 + i] += v * Math.sqrt((1 + pan) / 2) * 1.41;
  }
}
// FM çan: uzay / kristal tınısı
function bell(T, { t, f, dur = 1.5, vol = .06, ratio = 3.5, idx = 3, dec = 2.2, pan = 0 }) {
  const n = Math.floor(dur * SR), s0 = Math.floor(t * SR); let pc = 0, pm = 0;
  for (let i = 0; i < n && s0 + i < T.L.length; i++) {
    const tt = i / SR, env = Math.min(1, tt / .002) * Math.exp(-tt * dec), I = idx * Math.exp(-tt * dec * 1.6);
    pc = (pc + f / SR) % 1; pm = (pm + f * ratio / SR) % 1;
    const v = Math.sin(2 * Math.PI * pc + I * Math.sin(2 * Math.PI * pm)) * env * vol;
    T.L[s0 + i] += v * Math.sqrt((1 - pan) / 2) * 1.41; T.R[s0 + i] += v * Math.sqrt((1 + pan) / 2) * 1.41;
  }
}
// gürültü vuruşu (eğri < 0: yükselen)
function noiseHit(T, { t, dur, vol, lp = 8000, hp = 0, pan = 0, curve = 3 }) {
  const n = Math.floor(dur * SR), s0 = Math.floor(t * SR); let y = 0, h = 0;
  const a = 1 - Math.exp(-2 * Math.PI * lp / SR), b = hp ? 1 - Math.exp(-2 * Math.PI * hp / SR) : 0;
  const gl = Math.sqrt((1 - pan) / 2) * 1.41, gr = Math.sqrt((1 + pan) / 2) * 1.41;
  for (let i = 0; i < n && s0 + i < T.L.length; i++) {
    y += a * (rnd() * 2 - 1 - y); h += b * (y - h);
    const v = (y - h) * (curve < 0 ? Math.pow(i / n, -curve) : Math.pow(1 - i / n, curve)) * vol;
    T.L[s0 + i] += v * gl; T.R[s0 + i] += v * gr;
  }
}
function sine(T, t, f0, f1, dur, k, vol) { // perdesi düşen sinüs (kick / tom / taiko gövdesi)
  const n = Math.floor(dur * SR), s0 = Math.floor(t * SR); let ph = 0;
  for (let i = 0; i < n && s0 + i < T.L.length; i++) {
    const tt = i / SR, f = f1 + (f0 - f1) * Math.exp(-tt * k); ph += f / SR;
    const v = Math.sin(2 * Math.PI * ph) * Math.exp(-tt * (6 / dur)) * vol; T.L[s0 + i] += v; T.R[s0 + i] += v;
  }
}
const kick = (T, t, v = 1) => { sine(T, t, 170, 44, .42, 30, .95 * v); noiseHit(T, { t, dur: .012, vol: .3 * v, lp: 7000 }); };
const snare = (T, t, v = 1) => { noiseHit(T, { t, dur: .2, vol: .5 * v, lp: 8000, hp: 1200, curve: 2.6 }); sine(T, t, 260, 180, .1, 30, .3 * v); };
const clap = (T, t, v = 1) => { for (let k = 0; k < 3; k++) noiseHit(T, { t: t + k * .009, dur: .03, vol: .35 * v, lp: 6000, hp: 1400, curve: 1.5 }); noiseHit(T, { t: t + .027, dur: .18, vol: .25 * v, lp: 5000, hp: 1400, curve: 3 }); };
const hat = (T, t, v = 1, open = false) => noiseHit(T, { t, dur: open ? .2 : .035, vol: .13 * v, lp: 13000, hp: 7500, pan: .25 });
const crash = (T, t, v = 1) => noiseHit(T, { t, dur: 2.4, vol: .22 * v, lp: 14000, hp: 4000, curve: 2.2, pan: -.2 });
const taiko = (T, t, f = 62, v = 1) => { sine(T, t, f * 1.7, f, .9, 14, .85 * v); noiseHit(T, { t, dur: .1, vol: .3 * v, lp: 900, curve: 2 }); };
const impact = (T, t, v = 1) => { sine(T, t, 90, 32, 1.8, 6, 1.0 * v); noiseHit(T, { t, dur: 1.2, vol: .35 * v, lp: 2500, curve: 2.5 }); crash(T, t, v); };
const riser = (T, t, dur, v = 1) => noiseHit(T, { t, dur, vol: .22 * v, lp: 10000, hp: 1800, curve: -1.2 });

// ---------- işleme ----------
function reverb(x, wet, size = 1) { // Schroeder: 4 tarak + 2 tüm geçiren
  const combs = [1557, 1617, 1491, 1422].map(d => Math.floor(d * size * SR / 44100)), out = new Float32Array(x.length);
  for (const d of combs) { const b = new Float32Array(d); let i = 0, lpz = 0; for (let n = 0; n < x.length; n++) { const y = b[i]; lpz = y * .8 + lpz * .2; b[i] = x[n] + lpz * .84; out[n] += y * .25; i = (i + 1) % d; } }
  for (const d of [225, 556].map(d => Math.floor(d * SR / 44100))) { const b = new Float32Array(d); let i = 0; for (let n = 0; n < x.length; n++) { const bo = b[i], y = -out[n] + bo; b[i] = out[n] + bo * .5; out[n] = y; i = (i + 1) % d; } }
  for (let n = 0; n < x.length; n++) x[n] += out[n] * wet;
}
function pingpong(T, dt, fb = .35, mix = .3) { // stereo gecikme: sol -> sağ -> sol
  const d = Math.floor(dt * SR), L = T.L, R = T.R, n = L.length, oL = new Float32Array(n), oR = new Float32Array(n);
  for (let i = d; i < n; i++) { oL[i] = R[i - d] * mix + oR[i - d] * fb; oR[i] = L[i - d] * mix + oL[i - d] * fb; }
  for (let i = 0; i < n; i++) { L[i] += oL[i]; R[i] += oR[i]; }
}
function mixIn(dst, src, g = 1, duck = null) {
  for (let i = 0; i < dst.L.length && i < src.L.length; i++) { const k = g * (duck ? duck[i] : 1); dst.L[i] += src.L[i] * k; dst.R[i] += src.R[i] * k; }
}
function duckEnv(len, kicks, depth = .65, rel = .16) { // kick'lere göre "nefes alan" pad / bas
  const e = new Float32Array(len).fill(1);
  for (const tk of kicks) { const s0 = Math.floor(tk * SR); for (let i = 0; i < rel * 3 * SR && s0 + i < len; i++) e[s0 + i] = Math.min(e[s0 + i], 1 - depth * Math.exp(-i / SR / rel)); }
  return e;
}
function save(name, T, loopLen, gain = 1) {
  const n = Math.floor(loopLen * SR); // kuyruk başa sarılır: kusursuz döngü
  for (const ch of [T.L, T.R]) for (let i = n; i < ch.length; i++) ch[i - n] += ch[i];
  let peak = 0; for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(T.L[i]), Math.abs(T.R[i]));
  const g = gain * .95 / Math.max(peak, 1e-6) * 1.5;
  const d = Buffer.alloc(44 + n * 4);
  d.write('RIFF', 0); d.writeUInt32LE(36 + n * 4, 4); d.write('WAVEfmt ', 8); d.writeUInt32LE(16, 16);
  d.writeUInt16LE(1, 20); d.writeUInt16LE(2, 22); d.writeUInt32LE(SR, 24); d.writeUInt32LE(SR * 4, 28);
  d.writeUInt16LE(4, 32); d.writeUInt16LE(16, 34); d.write('data', 36); d.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) { d.writeInt16LE(Math.round(Math.tanh(T.L[i] * g) * 30000), 44 + i * 4); d.writeInt16LE(Math.round(Math.tanh(T.R[i] * g) * 30000), 46 + i * 4); }
  fs.writeFileSync(path.join(OUT, name + '.wav'), d);
  console.log(name, loopLen.toFixed(1) + ' sn', (d.length / 1e6).toFixed(1) + ' MB');
}

// ---------- davul kalıpları (16'lık adımlar) ----------
const DRUMS = {
  four: { k: [0, 4, 8, 12], s: [4, 12], h: [2, 6, 10, 14], ghost: [7, 15] },
  brk: { k: [0, 3, 6, 10], s: [4, 12], h: [0, 2, 4, 6, 8, 10, 12, 14], ghost: [9, 14] },
  taiko: { k: [0, 8], s: [8], h: [2, 6, 10, 14], tk: [0, 3, 6, 10, 11, 14] },
  half: { k: [0, 7, 10], s: [8], h: [0, 2, 4, 6, 8, 10, 12, 14], ghost: [15] },
};
const BASS = { drive: [0, 2, 4, 6, 8, 10, 12, 14], gallop: [0, 3, 6, 8, 11, 14], sync: [0, 3, 6, 10, 12], pulse: [...Array(16).keys()], slow: [0, 7, 10] };

// ---------- harekât parçası: giriş / yükseliş / A / ara / B / doruk (32 ölçü) ----------
function battle(name, c) {
  seed = c.seed;
  const beat = 60 / c.bpm, st = beat / 4, bars = 32, len = bars * 4 * beat, pad = len + 5;
  const D = track(pad), B = track(pad), P = track(pad), L = track(pad), F = track(pad);
  const sc = SCALES[c.scale], note = d => c.key + deg(sc, d), kicks = [];
  const dr = DRUMS[c.drums];
  const lead = (T, mel, t0, oct, k) => { // 2 ölçülük melodi; nota bir sonrakine kadar uzar
    for (let s = 0; s < 32; s++) {
      if (mel[s] === null) continue;
      let h = 1; while (s + h < 32 && mel[s + h] === null && h < 8) h++;
      const f = mf(note(mel[s]) + 12 * oct), t = t0 + s * st, du = h * st * .92;
      if (c.lead === 'ney') ney(T, { t, f, dur: du, vol: .075 * k });
      else if (c.lead === 'bell') { bell(T, { t, f, dur: 1.4, vol: .06 * k }); voice(T, { t, f, dur: du, wave: 'tri', vol: .03 * k, att: .02, rel: .2, lp: 2500 }); }
      else voice(T, { t, f, dur: du, wave: c.lead || 'saw', vol: .05 * k, att: .012, rel: .18, lp: 3400, det: 9, uni: 3, vib: 14 });
    }
  };
  for (let b = 0; b < bars; b++) {
    const sec = b < 4 ? 0 : b < 8 ? 1 : b < 16 ? 2 : b < 20 ? 3 : b < 28 ? 4 : 5;
    const dg = c.prog[b % c.prog.length], ch = [0, 2, 4].map(x => note(dg + x)), t0 = b * 4 * beat;
    // yaylı pad (her yerde), arada ve dorukta tiz koro katmanı
    for (const n of ch) voice(P, { t: t0, f: mf(n + 12), dur: 4 * beat, wave: 'saw', vol: sec === 3 ? .045 : .03, att: sec === 0 ? 1.2 : .3, rel: .7, lp: sec === 3 ? 1500 : 850 + 350 * (sec >= 4), det: 18, uni: 5, vib: 5 });
    if (sec === 3 || sec === 5) for (const n of ch) voice(P, { t: t0, f: mf(n + 24), dur: 4 * beat, wave: 'tri', vol: .028, att: .7, rel: 1.2, lp: 3500, det: 9, uni: 3, vib: 9 });
    voice(B, { t: t0, f: mf(ch[0] - 24), dur: 4 * beat, wave: 'sine', vol: sec === 0 || sec === 3 ? .2 : .13, att: .05, rel: .3 }); // alt bas
    // davul
    for (let s = 0; s < 16; s++) {
      const t = t0 + s * st;
      if (sec === 0) { if (s === 0 && b % 2 === 0) { taiko(D, t, 58); kicks.push(t); } if (s === 8 && b === 3) taiko(D, t, 52, .8); continue; }
      if (sec === 3) { if (s === 0) taiko(D, t, 55, .7); if (b === 19) { snare(D, t, .25 + s / 20); } continue; } // ara: trampet sarması dorukla
      if (dr.k.includes(s)) { kick(D, t); kicks.push(t); }
      if (dr.s.includes(s)) { (c.clap ? clap : snare)(D, t); if (sec >= 4) snare(D, t, .5); }
      if (dr.h.includes(s) || (sec === 5 && s % 2 === 0)) hat(D, t, s % 4 === 2 ? 1 : .6, s === 14 && b % 2 === 1);
      if (dr.ghost && dr.ghost.includes(s) && sec >= 2) snare(D, t, .18);
      if (dr.tk && dr.tk.includes(s) && sec >= 2) taiko(D, t, s % 8 < 4 ? 64 : 56, .55);
    }
    // bas hattı
    if (sec !== 0 && sec !== 3) for (const s of BASS[c.bass]) {
      const up = c.bass === 'pulse' && s % 4 === 3 ? 12 : 0;
      voice(B, { t: t0 + s * st, f: mf(ch[0] - 12 + up), dur: (c.bass === 'slow' ? 3 : .9) * st, wave: 'saw', vol: .17, att: .003, rel: .05, lp: 420, lpEnv: 2.6, drive: c.drive || 0 });
    }
    // arpej (stereo sekme)
    if (sec >= 1 && sec !== 3 || (sec === 3 && b >= 18)) {
      const nn = [ch[0], ch[1], ch[2], ch[0] + 12, ch[1] + 12, ch[2] + 12];
      for (let s = 0; s < 16; s++) {
        if (c.arpRate === 8 && s % 2) continue;
        const n = nn[c.arp[s % c.arp.length]] + 12;
        if (c.arpWave === 'bell') bell(L, { t: t0 + s * st, f: mf(n + 12), dur: .5, vol: .028, ratio: 2, idx: 1.5, dec: 6, pan: s % 2 ? .4 : -.4 });
        else voice(L, { t: t0 + s * st, f: mf(n), dur: st * .6, wave: c.arpWave || 'sq', vol: sec === 1 ? .018 : .024, att: .002, rel: .06, lp: 2400 + 900 * (sec >= 4), lpEnv: 1, pan: s % 2 ? .45 : -.45 });
      }
    }
    // melodi: A bölümü, B bölümü (ikinci tema), doruk (A bir oktav yukarı + pirinç)
    if (b % 2 === 0) {
      if (sec === 2) lead(L, c.A, t0, 1, b >= 12 ? 1.1 : .9);
      if (sec === 4) lead(L, c.B, t0, 1, 1);
      if (sec === 5) { lead(L, c.A, t0, 2, .8); lead(L, c.A, t0, 1, .7); }
    }
    if (sec >= 4 && s0brass(b)) for (const n of ch) voice(P, { t: t0, f: mf(n), dur: beat * 1.5, wave: 'saw', vol: .05, att: .04, rel: .35, lp: 1300, swell: 1.4, det: 10, uni: 3 }); // pirinç vuruşu
    // geçiş efektleri
    if (b === 7 || b === 19 || b === 27) riser(F, t0, 4 * beat, b === 19 ? 1.3 : 1);
    if (b === 8 || b === 20 || b === 28) impact(F, t0, b === 20 ? 1 : .8);
    if (b === 0) crash(F, t0, .6);
  }
  const de = duckEnv(D.L.length, kicks);
  for (const ch of [P.L, P.R]) reverb(ch, .5, 1.15);
  pingpong(L, st * 3, .32, .28);
  for (const ch of [L.L, L.R]) reverb(ch, .32, 1);
  for (const ch of [D.L, D.R]) reverb(ch, .12, .7);
  for (const ch of [F.L, F.R]) reverb(ch, .45, 1.2);
  const T = track(pad);
  mixIn(T, D, 1); mixIn(T, B, .9, de); mixIn(T, P, .9, de); mixIn(T, L, .95); mixIn(T, F, .7);
  save(name, T, len, c.gain || 1.5); // +3.5 dB: yoğun miks, tepe noktaları tanh ile yumuşak kırpılır
}
const s0brass = b => b % 2 === 0;

// ---------- menü: ağır, hüzünlü, umutlu. Yaylılar + ney + uzak taikolar (hicaz) ----------
function menu() {
  seed = 3;
  const bpm = 68, beat = 60 / bpm, bars = 16, len = bars * 4 * beat, pad = len + 6;
  const P = track(pad), L = track(pad), D = track(pad);
  const sc = SCALES.hicaz, K = 50, note = d => K + deg(sc, d);
  const prog = [0, 0, 6, 6, 5, 5, 0, 0, 3, 3, 6, 6, 5, 4, 0, 0];
  const mel = [[4, 3, 2, 1], [2, 1, 0, null], [6, 5, 4, 5], [4, 3, 2, null], [7, 6, 5, 4], [5, 4, 3, 2], [3, 2, 1, 2], [1, null, 0, null]];
  for (let b = 0; b < bars; b++) {
    const dg = prog[b], ch = [0, 2, 4].map(x => note(dg + x)), t0 = b * 4 * beat;
    for (const n of ch) voice(P, { t: t0, f: mf(n + 12), dur: 4 * beat, wave: 'saw', vol: .035, att: 1.5, rel: 2, lp: 900, det: 16, uni: 5, vib: 5 });
    voice(P, { t: t0, f: mf(ch[0] - 12), dur: 4 * beat, wave: 'sine', vol: .2, att: .6, rel: 1.5 });
    if (b >= 4) for (let k = 0; k < 8; k++) bell(L, { t: t0 + k * beat / 2, f: mf([ch[0], ch[1], ch[2], ch[1]][k % 4] + 24), dur: 1.6, vol: .022, ratio: 3, idx: 1.2, dec: 2.5, pan: k % 2 ? .4 : -.4 });
    if (b >= 6 && b % 2 === 0) { taiko(D, t0, 50, .55); taiko(D, t0 + 3 * beat, 44, .4); }
    if (b >= 8) { const m = mel[b - 8]; for (let k = 0; k < 4; k++) if (m[k] !== null) ney(L, { t: t0 + k * beat, f: mf(note(m[k]) + 12), dur: (m[k + 1] === null ? 2 : 1) * beat * .95, vol: .07 }); }
  }
  for (const ch of [P.L, P.R]) reverb(ch, .65, 1.3);
  pingpong(L, beat * .75, .3, .25);
  for (const ch of [L.L, L.R]) reverb(ch, .55, 1.3);
  for (const ch of [D.L, D.R]) reverb(ch, .5, 1.2);
  const T = track(pad); mixIn(T, P, 1); mixIn(T, L, 1); mixIn(T, D, .8);
  save('music_menu', T, len, .85);
}

const _ = null;
menu();
// 1. harekât (Ege / Sinop / Kapadokya): kahramanca ilk karşılaşma, re minör
battle('music_op1', { seed: 11, bpm: 132, key: 50, scale: 'minor', prog: [0, 5, 3, 4], drums: 'four', bass: 'drive', arp: [0, 2, 4, 2, 1, 3, 5, 3], arpWave: 'sq',
  A: [0, _, _, _, 2, _, 4, _, 3, _, 2, _, 1, _, _, _, 4, _, _, 5, 4, _, 2, _, 3, _, _, _, _, _, _, _],
  B: [7, _, _, 6, 5, _, 4, _, 5, _, _, 4, 3, _, 2, _, 1, _, 2, _, 3, _, 4, _, 2, _, _, _, _, _, _, _] });
// 2. harekât (Toros / Van / Ağrı): dağlar, mi hicaz, taiko + ney
battle('music_op2', { seed: 23, bpm: 120, key: 52, scale: 'hicaz', prog: [0, 0, 6, 5], drums: 'taiko', bass: 'gallop', arp: [0, 1, 2, 1, 3, 2, 1, 2], arpWave: 'tri', lead: 'ney',
  A: [4, _, _, _, 5, 4, 3, _, 2, _, 1, _, 2, _, _, _, 1, _, _, 0, 1, _, 2, _, 1, _, 0, _, 0, _, _, _],
  B: [7, _, 6, _, 5, _, 4, _, 5, 6, 5, 4, 3, _, _, _, 4, _, 3, 2, 1, _, 2, _, 1, _, _, _, 0, _, _, _] });
// 3. harekât (bulutlar / fırtına / kutup): hızlı, havadar, la dorian, kırık ritim
battle('music_op3', { seed: 37, bpm: 146, key: 45, scale: 'dorian', prog: [0, 3, 5, 4], drums: 'brk', bass: 'sync', arp: [0, 1, 2, 3, 4, 3, 2, 1], arpWave: 'bell', clap: true,
  A: [0, _, 2, _, 4, _, 7, _, 6, _, 4, _, 5, _, 4, 2, 3, _, _, _, 4, _, 5, _, 4, _, 2, _, 1, _, _, _],
  B: [9, _, 7, _, 8, _, 7, _, 6, _, 4, _, 5, _, _, _, 4, _, 5, _, 6, _, 7, _, 6, _, _, _, 4, _, _, _] });
// 4. harekât (Sahra / volkan / stratosfer): karanlık, endüstriyel, do# frigyen, bozuk bas
battle('music_op4', { seed: 41, bpm: 126, key: 49, scale: 'phryg', prog: [0, 1, 0, 6], drums: 'half', bass: 'pulse', drive: .8, arp: [0, 3, 1, 4, 2, 5, 1, 3], arpWave: 'saw', lead: 'saw', arpRate: 8,
  A: [0, _, _, 1, 0, _, _, _, 3, _, 2, _, 1, _, 0, _, 0, _, _, 1, 2, _, 3, _, 4, _, _, 3, 1, _, _, _],
  B: [4, _, 5, 4, 3, _, _, _, 2, _, 1, _, 2, _, 3, _, 4, _, _, _, 5, _, 4, _, 1, _, _, _, 0, _, _, _] });
// 5. harekât (enkaz kuşağı / Sefine / İstanbul): uzay destanı, si minör, çan + koro
battle('music_op5', { seed: 53, bpm: 138, key: 47, scale: 'minor', prog: [0, 5, 2, 6], drums: 'four', bass: 'drive', arp: [0, 2, 4, 5, 4, 2, 1, 3], arpWave: 'bell', lead: 'bell', clap: true,
  A: [4, _, _, _, 3, _, 4, _, 5, _, _, _, 4, _, 2, _, 3, _, _, _, 2, _, 1, _, 0, _, _, _, _, _, _, _],
  B: [7, _, _, _, 9, _, 8, _, 7, _, _, _, 5, _, 4, _, 5, _, _, _, 4, _, 2, _, 4, _, _, _, _, _, _, _] });
// boss: armonik minör gerilim, kırık ritim, galop bas
battle('music_boss', { seed: 99, bpm: 152, key: 40, scale: 'harm', prog: [0, 0, 5, 4], drums: 'brk', bass: 'pulse', drive: .4, arp: [0, 1, 2, 1, 3, 2, 4, 2], arpWave: 'sq', gain: 1.4,
  A: [7, _, 6, 7, 9, _, 8, 7, 6, _, 4, _, 5, _, 6, _, 7, _, 9, 10, 11, _, 10, 9, 8, _, 6, _, 7, _, _, _],
  B: [4, _, 4, 5, 6, _, 7, _, 5, _, 4, _, 3, _, 2, _, 1, _, 2, 3, 4, _, 6, _, 7, _, _, _, _, _, _, _] });
// final (Sefine / Varek): re hicaz, en hızlı; ney teması + pirinç + taiko
battle('music_final', { seed: 77, bpm: 156, key: 50, scale: 'hicaz', prog: [0, 6, 5, 4], drums: 'four', bass: 'gallop', drive: .5, arp: [0, 1, 2, 4, 3, 2, 1, 2], arpWave: 'sq', lead: 'ney', clap: true,
  A: [4, _, 5, 4, 3, _, 2, _, 1, _, 2, _, 0, _, _, _, 4, _, _, 5, 6, _, 5, 4, 5, _, 4, 3, 2, _, _, _],
  B: [7, _, 8, 7, 6, _, 5, _, 4, _, 5, 6, 7, _, _, _, 8, _, 7, 6, 5, _, 4, _, 2, _, 1, _, 0, _, _, _] });
