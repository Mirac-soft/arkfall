'use strict';
// Tüm görseller kodla çizilir (neon vektör tarzı).
const F = "'Segoe UI', 'Trebuchet MS', Arial, sans-serif";
const MONO = "Consolas, 'Courier New', monospace";

function makeCanvas(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function rnd(a, b) { return a + Math.random() * (b - a); }
function hexA(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`;
}
function pathPts(g, p) { g.beginPath(); g.moveTo(p[0][0], p[0][1]); for (let i = 1; i < p.length; i++) g.lineTo(p[i][0], p[i][1]); g.closePath(); }
function mirrorPts(g, h) {
  g.beginPath(); g.moveTo(h[0][0], h[0][1]);
  for (let i = 1; i < h.length; i++) g.lineTo(h[i][0], h[i][1]);
  for (let i = h.length - 1; i >= 0; i--) g.lineTo(-h[i][0], h[i][1]);
  g.closePath();
}
function rrect(g, x, y, w, h, r) {
  g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r);
  g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
}
function txt(g, s, x, y, size, color, align = 'left', weight = 700, glow = 0, fam = F) {
  g.font = `${weight} ${size}px ${fam}`; g.textAlign = align; g.textBaseline = 'middle'; g.fillStyle = color;
  if (glow) { g.shadowColor = color; g.shadowBlur = glow; }
  g.fillText(s, x, y); g.shadowBlur = 0;
}
function bar(g, x, y, w, h, v, col, bg = 'rgba(255,255,255,.08)') {
  g.fillStyle = bg; g.fillRect(x, y, w, h);
  g.fillStyle = col; g.shadowColor = col; g.shadowBlur = 8; g.fillRect(x, y, w * Math.max(0, Math.min(1, v)), h); g.shadowBlur = 0;
}
function star(g, x, y, r, col) {
  g.beginPath();
  for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * .45 : r; g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
  g.closePath(); g.fillStyle = col; g.fill();
}
const _wrap = new Map();
function wrap(g, s, maxW, font) {
  const key = font + '|' + maxW + '|' + s;
  if (_wrap.has(key)) return _wrap.get(key);
  g.font = font; const lines = []; let cur = '';
  for (const w of s.split(' ')) {
    const t = cur ? cur + ' ' + w : w;
    if (g.measureText(t).width > maxW && cur) { lines.push(cur); cur = w; } else cur = t;
  }
  if (cur) lines.push(cur);
  _wrap.set(key, lines); return lines;
}

// ---------- Mermi sprite önbelleği ----------
const _bs = {};
function bulletSprite(color, r) {
  const key = color + r; if (_bs[key]) return _bs[key];
  const R = r * 2.2, sz = Math.ceil(R * 2) + 2, c = makeCanvas(sz * 2, sz * 2), g = c.getContext('2d'), m = sz / 2;
  g.scale(2, 2);
  const gr = g.createRadialGradient(m, m, 0, m, m, R);
  gr.addColorStop(0, '#fff'); gr.addColorStop(r / R * .55, '#fff'); gr.addColorStop(r / R, color); gr.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = gr; g.beginPath(); g.arc(m, m, R, 0, TAU); g.fill();
  c.sz = sz; return _bs[key] = c;
}

// ---------- Uçak şekilleri (burun yukarı) ----------
const PSHAPE = {
  serce: { body: [[0, -24], [4, -15], [5, 4], [4, 15], [0, 18]], parts: [[[4, -5], [22, 8], [22, 13], [4, 11]], [[3, 11], [10, 18], [10, 21], [3, 18]]], cockpit: [0, -11, 2.6, 6], eng: [[0, 19, 4]] },
  dogan: { body: [[0, -28], [4, -18], [6, 2], [5, 16], [0, 20]], parts: [[[5, 2], [25, -8], [27, -4], [6, 13]], [[3, -15], [10, -12], [10, -9], [3, -9]], [[4, 12], [12, 20], [12, 23], [4, 20]]], cockpit: [0, -14, 2.8, 6], eng: [[0, 21, 5]] },
  simsek: { body: [[0, -36], [3, -22], [4, 8], [3, 22], [0, 25]], parts: [[[3, -3], [21, 13], [21, 17], [4, 12]], [[2, -19], [8, -12], [2, -12]], [[3, 14], [10, 25], [8, 27], [3, 23]]], cockpit: [0, -18, 2.2, 7], eng: [[-2.5, 26, 3], [2.5, 26, 3]] },
  kartal: { body: [[0, -28], [6, -18], [8, 8], [7, 20], [0, 23]], parts: [[[7, -8], [33, 9], [33, 15], [18, 15], [8, 13]], [[6, 14], [17, 22], [17, 26], [6, 22]], [[22, -2], [25, -2], [25, 14], [22, 14]]], cockpit: [0, -15, 3.4, 7], eng: [[-4.5, 24, 4], [4.5, 24, 4]] },
  anka: { body: [[0, -32], [5, -20], [6, 6], [4, 18], [0, 24]], parts: [[[5, -10], [20, -6], [36, 6], [31, 9], [38, 14], [27, 14], [31, 20], [18, 16], [6, 12]], [[4, 14], [13, 27], [7, 25], [3, 22]]], cockpit: [0, -17, 3, 7], eng: [[-3, 25, 4], [3, 25, 4]] },
};

function drawPlane(g, pl, x, y, sc, t, bank = 0, o = {}) {
  const sh = PSHAPE[pl.id];
  g.save(); g.translate(x, y); g.scale(sc * (1 - Math.abs(bank) * .18), sc);
  if (o.alpha !== undefined) g.globalAlpha *= o.alpha;
  g.lineJoin = 'round';
  if (o.shadow) {
    g.fillStyle = 'rgba(0,0,0,.45)';
    for (const p of sh.parts) for (const sx of [1, -1]) { g.save(); g.scale(sx, 1); pathPts(g, p); g.fill(); g.restore(); }
    mirrorPts(g, sh.body); g.fill(); g.restore(); return;
  }
  const col = o.locked ? '#3a4050' : pl.color;
  if (!o.locked) { // motor alevi
    g.globalCompositeOperation = 'lighter';
    for (const [ex, ey, er] of sh.eng) {
      const L = (o.flame ?? 1) * (10 + er * 2.2) * (1 + .25 * Math.sin(t * 50 + ex));
      const gr = g.createLinearGradient(0, ey, 0, ey + L * 1.2);
      gr.addColorStop(0, '#fff'); gr.addColorStop(.25, col); gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr; g.beginPath(); g.moveTo(ex - er, ey); g.quadraticCurveTo(ex, ey + L * 1.4, ex + er, ey); g.fill();
    }
    g.globalCompositeOperation = 'source-over';
  }
  const fA = o.locked ? '#0c0e14' : '#18202e', fB = o.locked ? '#10131a' : '#2e3d56';
  g.strokeStyle = col; g.lineWidth = 1.3 / Math.sqrt(sc);
  g.shadowColor = col; g.shadowBlur = o.locked ? 0 : 10;
  for (const p of sh.parts) for (const sx of [1, -1]) {
    g.save(); g.scale(sx, 1); pathPts(g, p); g.fillStyle = fA; g.fill(); g.stroke(); g.restore();
  }
  mirrorPts(g, sh.body);
  const bg = g.createLinearGradient(-6, 0, 6, 0); bg.addColorStop(0, fA); bg.addColorStop(.5, fB); bg.addColorStop(1, fA);
  g.fillStyle = bg; g.fill(); g.stroke(); g.shadowBlur = 0;
  if (!o.locked) {
    const [cx, cy, rx, ry] = sh.cockpit, cg = g.createLinearGradient(0, cy - ry, 0, cy + ry);
    cg.addColorStop(0, '#fff'); cg.addColorStop(1, col);
    g.fillStyle = cg; g.beginPath(); g.ellipse(cx, cy, rx, ry, 0, 0, TAU); g.fill();
    if (Math.floor(t * 2) % 2) { // kanat ucu ışıkları
      const tip = sh.parts[0].reduce((a, b) => b[0] > a[0] ? b : a);
      g.fillStyle = '#ff4f4f'; g.fillRect(-tip[0] - 1, tip[1] - 1, 2, 2);
      g.fillStyle = '#4fff7a'; g.fillRect(tip[0] - 1, tip[1] - 1, 2, 2);
    }
  }
  g.restore();
}

// ---------- Düşman şekilleri (burun yukarı, çizerken döndürülür) ----------
const ESHAPE = {
  drone: { body: [[0, -13], [4, -3], [4, 8], [0, 6]], parts: [[[4, -3], [14, 6], [12, 9], [4, 6]]] },
  fighter: { body: [[0, -18], [4, -8], [5, 10], [0, 13]], parts: [[[5, -4], [19, 7], [19, 11], [5, 9]], [[4, 9], [9, 15], [4, 14]]] },
  dart: { body: [[0, -19], [3, -5], [2, 12], [0, 9]], parts: [[[2, -2], [11, 13], [2, 8]]] },
  sniper: { body: [[0, -24], [2, -12], [6, 6], [0, 11]], parts: [[[5, -1], [17, -4], [17, 3], [5, 8]]] },
  bomber: { body: [[0, -30], [9, -20], [11, 14], [0, 19]], parts: [[[9, -18], [40, 6], [38, 13], [24, 10], [10, 12]], [[16, -2], [20, -2], [20, 9], [16, 9]]] },
};

function drawEnemy(g, e, t) {
  const d = e.d, fl = e.flash > 0, col = fl ? '#fff' : d.color;
  g.save(); g.translate(e.x, e.y);
  g.strokeStyle = col; g.lineWidth = 1.5; g.shadowColor = d.color; g.shadowBlur = 9; g.lineJoin = 'round';
  g.fillStyle = fl ? '#fff' : '#2a0d18';
  if (d.shape === 'spinner') {
    g.rotate(t * 3);
    for (let k = 0; k < 3; k++) { g.rotate(TAU / 3); pathPts(g, [[0, -6], [24, -2], [26, 4], [0, 7]]); g.fill(); g.stroke(); }
    g.beginPath(); g.arc(0, 0, 11, 0, TAU); g.fill(); g.stroke();
  } else {
    g.rotate(e.rot);
    if (e.type === 'kamikaze' && !e.go && e.t > .4 && Math.floor(t * 16) % 2) g.strokeStyle = '#fff';
    const sh = ESHAPE[d.shape];
    for (const p of sh.parts) for (const sx of [1, -1]) { g.save(); g.scale(sx, 1); pathPts(g, p); g.fill(); g.stroke(); g.restore(); }
    mirrorPts(g, sh.body); g.fill(); g.stroke();
  }
  g.shadowBlur = 0;
  g.fillStyle = d.color; g.beginPath(); g.arc(0, 0, 3.5, 0, TAU); g.fill();
  g.fillStyle = '#fff'; g.beginPath(); g.arc(0, 0, 1.5, 0, TAU); g.fill();
  g.restore();
}

function drawBoss(g, B, t, px, py) {
  const fl = B.flash > 0 && Math.floor(t * 30) % 3 === 0, c = fl ? '#fff' : B.d.color;
  g.save(); g.translate(B.x + (B.dying > 0 ? rnd(-4, 4) : 0), B.y + (B.dying > 0 ? rnd(-4, 4) : 0));
  g.lineJoin = 'round'; g.lineWidth = 2; g.strokeStyle = c; g.shadowColor = B.d.color; g.shadowBlur = 16;
  const hull = fl ? '#fff' : '#1c0e10';
  if (B.id === 'ironwing') {
    g.save(); g.scale(1, -1); // burun aşağı
    mirrorPts(g, [[0, -44], [22, -32], [78, -2], [74, 14], [46, 10], [28, 26], [0, 20]]); g.fillStyle = hull; g.fill(); g.stroke();
    mirrorPts(g, [[0, -30], [14, -22], [16, 10], [0, 14]]); g.fillStyle = fl ? '#fff' : '#3a1a14'; g.fill(); g.stroke();
    g.globalCompositeOperation = 'lighter';
    for (const ex of [-20, 0, 20]) { g.fillStyle = hexA('#ff9a3c', .6 + .3 * Math.sin(t * 40 + ex)); g.beginPath(); g.ellipse(ex, 24, 4, 10 + 3 * Math.sin(t * 50), 0, 0, TAU); g.fill(); }
    g.globalCompositeOperation = 'source-over';
    g.restore();
    for (const s of [-1, 1]) { // taretler oyuncuya döner
      g.save(); g.translate(s * 46, -4); g.rotate(Math.atan2(py - (B.y - 4), px - (B.x + s * 46)) - Math.PI / 2);
      g.fillStyle = hull; g.fillRect(-3, 0, 6, 18); g.strokeRect(-3, 0, 6, 18);
      g.beginPath(); g.arc(0, 0, 9, 0, TAU); g.fill(); g.stroke(); g.restore();
    }
  } else if (B.id === 'tempest') {
    for (let k = 0; k < 8; k++) {
      g.save(); g.rotate(t * .6 + k * TAU / 8);
      g.beginPath(); g.arc(0, 0, 66, -.3, .3); g.arc(0, 0, 52, .3, -.3, true); g.closePath(); g.fillStyle = hull; g.fill(); g.stroke(); g.restore();
    }
    g.save(); g.rotate(-t * .3);
    g.beginPath(); for (let k = 0; k < 8; k++) { const a = k * TAU / 8; g.lineTo(Math.cos(a) * 42, Math.sin(a) * 42); } g.closePath();
    g.fillStyle = fl ? '#fff' : '#0e1626'; g.fill(); g.stroke();
    for (let k = 0; k < 4; k++) { g.rotate(TAU / 4); g.strokeRect(30, -4, 16, 8); }
    g.restore();
  } else { // sentinel — Kara Güneş
    const pulse = 1 + .08 * Math.sin(t * 4);
    const cg = g.createRadialGradient(0, 0, 30, 0, 0, 100 * pulse);
    cg.addColorStop(0, hexA('#ff3355', .7)); cg.addColorStop(.5, hexA('#ff8a3c', .2)); cg.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = cg; g.beginPath(); g.arc(0, 0, 100 * pulse, 0, TAU); g.fill();
    g.save(); g.rotate(t * .7);
    for (let k = 0; k < 12; k++) { g.rotate(TAU / 12); pathPts(g, [[-6, 40], [0, 60 + 6 * Math.sin(t * 5 + k)], [6, 40]]); g.fillStyle = c; g.fill(); }
    g.restore();
    g.beginPath(); g.arc(0, 0, 40, 0, TAU); g.fillStyle = fl ? '#fff' : '#060006'; g.fill(); g.lineWidth = 3; g.stroke();
    g.save(); g.rotate(-t * 1.4); g.setLineDash([10, 8]); g.lineWidth = 2; g.beginPath(); g.arc(0, 0, 28, 0, TAU); g.stroke(); g.restore();
    const a = Math.atan2(py - B.y, px - B.x);
    g.fillStyle = c; g.beginPath(); g.arc(Math.cos(a) * 8, Math.sin(a) * 8, 8 + 2 * Math.sin(t * 8), 0, TAU); g.fill();
  }
  g.shadowBlur = 0;
  if (B.id !== 'sentinel') { g.fillStyle = '#fff'; g.beginPath(); g.arc(0, 0, 5 + 2 * Math.sin(t * 6), 0, TAU); g.fill(); }
  g.restore();
}

// ---------- Hologram portreler ----------
function drawPortrait(g, who, x, y, s, t) {
  const col = WHO[who].c;
  g.save(); g.translate(x, y);
  g.fillStyle = '#03060c'; g.fillRect(0, 0, s, s);
  g.save(); g.beginPath(); g.rect(0, 0, s, s); g.clip();
  g.strokeStyle = col; g.globalAlpha = .08; g.lineWidth = 1;
  for (let i = 0; i < s; i += 12) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i, s); g.moveTo(0, i); g.lineTo(s, i); g.stroke(); }
  g.globalAlpha = .85 + .15 * Math.sin(t * 23);
  g.save(); g.translate(s / 2, s / 2 + 6); g.scale(s / 150, s / 150);
  g.lineWidth = 2; g.strokeStyle = col; g.fillStyle = hexA(col, .16); g.shadowColor = col; g.shadowBlur = 8;
  const shoulders = () => { g.beginPath(); g.moveTo(-72, 80); g.quadraticCurveTo(-62, 36, -22, 30); g.lineTo(22, 30); g.quadraticCurveTo(62, 36, 72, 80); g.closePath(); g.fill(); g.stroke(); };
  if (who === 'cmd') {
    shoulders();
    g.fillStyle = col; g.fillRect(-58, 40, 22, 5); g.fillRect(36, 40, 22, 5); g.fillRect(-40, 52, 5, 9); g.fillRect(-32, 52, 5, 9); g.fillRect(-24, 52, 5, 9);
    g.fillStyle = hexA(col, .16); g.fillRect(-10, 18, 20, 14);
    g.beginPath(); g.ellipse(0, -5, 24, 30, 0, 0, TAU); g.fill(); g.stroke();
    g.beginPath(); g.moveTo(-31, -22); g.lineTo(-25, -44); g.quadraticCurveTo(0, -58, 25, -44); g.lineTo(31, -22); g.closePath(); g.fill(); g.stroke();
    g.beginPath(); g.moveTo(-33, -22); g.quadraticCurveTo(0, -14, 33, -22); g.lineTo(29, -17); g.quadraticCurveTo(0, -9, -29, -17); g.closePath(); g.fillStyle = col; g.fill();
    star(g, 0, -37, 6, col);
    g.fillRect(-14, -6, 9, 2.5); g.fillRect(5, -6, 9, 2.5);
    g.beginPath(); g.moveTo(-12, 11); g.quadraticCurveTo(0, 4, 12, 11); g.stroke();
    g.beginPath(); g.moveTo(-9, 19); g.lineTo(9, 19); g.stroke();
  } else if (who === 'pilot') {
    shoulders();
    g.beginPath(); g.arc(0, -6, 34, 0, TAU); g.fill(); g.stroke();
    g.beginPath(); g.moveTo(-28, -14); g.quadraticCurveTo(0, -26, 28, -14); g.quadraticCurveTo(26, 8, 0, 10); g.quadraticCurveTo(-26, 8, -28, -14);
    g.fillStyle = hexA(col, .55); g.fill(); g.stroke();
    g.strokeStyle = '#fff'; g.beginPath(); g.moveTo(-18, -14); g.lineTo(-6, -18); g.stroke(); g.strokeStyle = col;
    g.beginPath(); g.moveTo(0, -40); g.lineTo(0, -26); g.stroke();
    g.fillStyle = hexA(col, .16); g.beginPath(); g.ellipse(0, 18, 12, 8, 0, 0, TAU); g.fill(); g.stroke();
  } else {
    g.rotate(t * .5);
    g.beginPath(); for (let k = 0; k < 6; k++) { const a = k * TAU / 6; g.lineTo(Math.cos(a) * 52, Math.sin(a) * 52); } g.closePath(); g.fill(); g.stroke();
    g.rotate(-t * 1.3); g.setLineDash([12, 7]); g.beginPath(); g.arc(0, 0, 36, 0, TAU); g.stroke(); g.setLineDash([]);
    const r = 14 + 3 * Math.sin(t * 7), eg = g.createRadialGradient(0, 0, 0, 0, 0, r);
    eg.addColorStop(0, '#fff'); eg.addColorStop(.4, col); eg.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = eg; g.beginPath(); g.arc(0, 0, r, 0, TAU); g.fill();
  }
  g.restore();
  g.fillStyle = 'rgba(0,0,0,.35)'; for (let yy = 0; yy < s; yy += 3) g.fillRect(0, yy, s, 1);
  g.fillStyle = hexA(col, .12); g.fillRect(0, (t * 60) % s, s, 10);
  g.restore();
  g.strokeStyle = col; g.lineWidth = 2; g.shadowColor = col; g.shadowBlur = 10; g.strokeRect(0, 0, s, s); g.shadowBlur = 0;
  g.restore();
}

// ---------- Arka plan ----------
function cloudSprite(w, h, col, n) {
  const c = makeCanvas(w, h), g = c.getContext('2d');
  for (let i = 0; i < n; i++) {
    const x = rnd(w * .25, w * .75), y = rnd(h * .3, h * .7), r = rnd(h * .18, h * .38);
    const gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, col); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.beginPath(); g.arc(x, y, r, 0, TAU); g.fill();
  }
  return c;
}
function islandSprite(R) {
  const s = Math.ceil(R * 3), c = makeCanvas(s, s), g = c.getContext('2d'), m = s / 2, a = [rnd(0, 6), rnd(0, 6), rnd(0, 6)];
  const shape = k => {
    g.beginPath();
    for (let i = 0; i <= 48; i++) {
      const th = i / 48 * TAU, r = R * k * (1 + .22 * Math.sin(3 * th + a[0]) + .12 * Math.sin(5 * th + a[1]) + .07 * Math.sin(9 * th + a[2]));
      g.lineTo(m + Math.cos(th) * r, m + Math.sin(th) * r);
    }
    g.closePath();
  };
  shape(1.3); g.fillStyle = 'rgba(80,210,200,.22)'; g.fill();
  shape(1.08); g.fillStyle = '#d8c58a'; g.fill();
  shape(1); g.fillStyle = '#2f6b3a'; g.fill();
  shape(.6); g.fillStyle = '#24552d'; g.fill();
  shape(.22); g.fillStyle = '#6b6f5a'; g.fill();
  return c;
}

const THEMES = {
  dawn: { top: '#0a3550', bot: '#13707c', L: [{ k: 'glint', r: 28, sp: 110 }, { k: 'island', r: .22, sp: 70 }, { k: 'cloud', r: .55, sp: 240, a: .5 }] },
  storm: { top: '#0e1422', bot: '#222b3f', L: [{ k: 'dark', r: 1.1, sp: 110, a: .8 }, { k: 'rain', r: 70, sp: 950 }, { k: 'cloud', r: .6, sp: 320, a: .2 }], bolt: true },
  orbit: { top: '#020309', bot: '#0b0e26', L: [{ k: 'star', r: 20, sp: 35 }, { k: 'star2', r: 8, sp: 110 }, { k: 'nebula', r: .07, sp: 22, a: 1 }, { k: 'debris', r: .35, sp: 190 }], planet: true },
};
const BG = {
  theme: 'orbit', objs: [], acc: {}, boltT: 3, flash: 0, bolt: null, spr: null,
  init() {
    this.spr = { cloud: [], dark: [], island: [], nebula: [] };
    const neb = ['rgba(140,60,220,.3)', 'rgba(40,120,220,.3)', 'rgba(220,60,140,.25)', 'rgba(60,200,180,.22)'];
    for (let i = 0; i < 4; i++) {
      this.spr.cloud.push(cloudSprite(260, 160, 'rgba(255,255,255,.55)', 10));
      this.spr.dark.push(cloudSprite(420, 260, 'rgba(30,36,52,.9)', 14));
      this.spr.island.push(islandSprite(rnd(40, 80)));
      this.spr.nebula.push(cloudSprite(500, 400, neb[i], 12));
    }
  },
  set(th) { this.theme = th; this.objs = []; this.acc = {}; for (let i = 0; i < 600; i++) this.update(1 / 24, 1); },
  spawn(L) {
    const o = { k: L.k, a: L.a || 1, nx: Math.random(), y: -10, sp: L.sp * rnd(.85, 1.15), rot: rnd(0, 6), vr: 0, s: rnd(.7, 1.3), spr: null };
    const list = this.spr[L.k];
    if (list) { o.spr = list[Math.floor(Math.random() * list.length)]; o.y = -o.spr.height * o.s; }
    if (L.k === 'debris') { o.vr = rnd(-3, 3); o.s = rnd(2, 5); }
    this.objs.push(o);
  },
  update(dt, mul = 1) {
    const th = THEMES[this.theme];
    for (const L of th.L) { this.acc[L.k] = (this.acc[L.k] || 0) + L.r * dt; while (this.acc[L.k] >= 1) { this.acc[L.k] -= 1; this.spawn(L); } }
    for (const o of this.objs) { o.y += o.sp * mul * dt; o.rot += o.vr * dt; }
    this.objs = this.objs.filter(o => o.y < H + 20);
    if (th.bolt) {
      this.boltT -= dt;
      if (this.boltT <= 0) {
        this.boltT = rnd(3, 7); this.flash = .35;
        let x = Math.random(), y = 0; this.bolt = [[x, y]];
        while (y < 420) { x += rnd(-.05, .05); y += rnd(20, 50); this.bolt.push([x, y]); }
      }
      this.flash = Math.max(0, this.flash - dt * 1.2);
    }
  },
  draw(g, w, h) {
    const th = THEMES[this.theme], gr = g.createLinearGradient(0, 0, 0, h);
    gr.addColorStop(0, th.top); gr.addColorStop(1, th.bot); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    if (th.planet) {
      const px = w * .85, py = h + 380, pg = g.createRadialGradient(px, py, 420, px, py, 560);
      pg.addColorStop(0, '#0b1f3a'); pg.addColorStop(.75, '#1d4f8a'); pg.addColorStop(.8, 'rgba(80,180,255,.5)'); pg.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = pg; g.beginPath(); g.arc(px, py, 560, 0, TAU); g.fill();
    }
    for (const L of th.L) for (const o of this.objs) {
      if (o.k !== L.k) continue;
      const x = o.nx * w;
      switch (o.k) {
        case 'glint': g.fillStyle = 'rgba(255,255,255,.16)'; g.fillRect(x, o.y, 8 * o.s, 1.5); break;
        case 'rain': g.strokeStyle = 'rgba(170,190,230,.25)'; g.lineWidth = 1; g.beginPath(); g.moveTo(x, o.y); g.lineTo(x - 4, o.y + 18); g.stroke(); break;
        case 'star': g.fillStyle = 'rgba(255,255,255,.6)'; g.fillRect(x, o.y, 1.3 * o.s, 1.3 * o.s); break;
        case 'star2': g.fillStyle = '#cfe8ff'; g.fillRect(x, o.y, 2, 2); break;
        case 'debris': g.save(); g.translate(x, o.y); g.rotate(o.rot); g.fillStyle = '#3a4258'; g.fillRect(-o.s, -o.s / 2, o.s * 2, o.s); g.restore(); break;
        default: g.globalAlpha = o.a; g.drawImage(o.spr, x - o.spr.width * o.s / 2, o.y, o.spr.width * o.s, o.spr.height * o.s); g.globalAlpha = 1;
      }
    }
    if (this.flash > 0 && this.bolt) {
      g.fillStyle = `rgba(200,210,255,${this.flash * .45})`; g.fillRect(0, 0, w, h);
      g.strokeStyle = `rgba(255,255,255,${Math.min(1, this.flash * 3)})`; g.lineWidth = 2; g.shadowColor = '#aaccff'; g.shadowBlur = 12;
      g.beginPath(); for (const [bx, by] of this.bolt) g.lineTo(bx * w, by); g.stroke(); g.shadowBlur = 0;
    }
  },
};
