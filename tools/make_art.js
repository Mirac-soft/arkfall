// Gökkalkan görsel üretici: tüm sprite'ları SVG olarak art/ klasörüne yazar.
// Çalıştır: node tools/make_art.js   (SVG'ler Inkscape ile de düzenlenebilir — ama bu script tekrar çalışırsa üzerine yazar)
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, '..', 'art');
fs.mkdirSync(OUT, { recursive: true });

let gid = 0;
const P = p => p.map(([x, y]) => `${(+x).toFixed(1)},${(+y).toFixed(1)}`).join(' ');
const mir = h => [...h, ...h.slice().reverse().map(([x, y]) => [-x, y])];
const flip = p => p.map(([x, y]) => [-x, y]);
const scl = (p, k) => p.map(([x, y]) => [x * k, y * k]);
const cen = p => [p.reduce((s, q) => s + q[0], 0) / p.length, p.reduce((s, q) => s + q[1], 0) / p.length];
const inset = (p, k) => { const [cx, cy] = cen(p); return p.map(([x, y]) => [cx + (x - cx) * k, cy + (y - cy) * k]); };
const stops = s => s.map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`).join('');
function lin(defs, s, x1 = 0, y1 = 0, x2 = 0, y2 = 1) { const id = 'g' + gid++; defs.push(`<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">${stops(s)}</linearGradient>`); return `url(#${id})`; }
function rad(defs, s, cx = .5, cy = .5, r = .5, fx = cx, fy = cy) { const id = 'g' + gid++; defs.push(`<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}" fx="${fx}" fy="${fy}">${stops(s)}</radialGradient>`); return `url(#${id})`; }
const poly = (p, fill, stroke = 'none', sw = 0, extra = '') => `<polygon points="${P(p)}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round" ${extra}/>`;
const circ = (x, y, r, fill, stroke = 'none', sw = 0, extra = '') => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" ${extra}/>`;
const ell = (x, y, rx, ry, fill, extra = '') => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${fill}" ${extra}/>`;
const line = (a, b, stroke, sw, extra = '') => `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${stroke}" stroke-width="${sw}" stroke-linecap="round" ${extra}/>`;
function write(name, w, h, body, defs) {
  if (process.env.ONLY && !process.env.ONLY.split(',').includes(name)) return; // ONLY=a,b: yalnız bu görselleri yeniden üret
  fs.writeFileSync(path.join(OUT, name + '.svg'),
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="${-w / 2} ${-h / 2} ${w} ${h}"><defs>${defs.join('')}</defs>${body}</svg>`);
}
const shade = (hex, k) => { // k<1 koyulaştır, k>1 aç
  const n = parseInt(hex.slice(1), 16); let r = n >> 16, g = (n >> 8) & 255, b = n & 255;
  const f = v => Math.max(0, Math.min(255, Math.round(k < 1 ? v * k : v + (255 - v) * (k - 1))));
  return '#' + [f(r), f(g), f(b)].map(v => v.toString(16).padStart(2, '0')).join('');
};
const OUTL = '#070a10';

// ---------------- Oyuncu uçakları (burun yukarı, 128x128) ----------------
const PLANES = {
  serce: { main: '#8fa3b5', camo: '#6c7f92', acc: '#4fd8ff', k: 1.75,
    body: [[0, -26], [4, -16], [5.5, 4], [4.5, 15], [0, 19]], wing: [[4.5, -5], [24, 8], [24, 13], [4.5, 11]],
    extra: [[[3.5, 11], [11, 18], [11, 21], [3.5, 18]]], cockpit: [0, -12, 2.8, 6.5], eng: [[0, 20, 3.4]] },
  dogan: { main: '#7d8f6a', camo: '#56653f', acc: '#57ff9a', k: 1.65,
    body: [[0, -30], [4.5, -19], [6.5, 2], [5.5, 17], [0, 21]], wing: [[5.5, 2], [27, -9], [29, -4], [6.5, 14]],
    extra: [[[3.5, -16], [11, -13], [11, -10], [3.5, -10]], [[4.5, 13], [13, 21], [13, 24], [4.5, 21]]], cockpit: [0, -15, 3, 6.5], eng: [[0, 22, 4]] },
  simsek: { main: '#c8c2a8', camo: '#9e9474', acc: '#ffe14f', k: 1.55,
    body: [[0, -38], [3.4, -23], [4.5, 8], [3.4, 23], [0, 26]], wing: [[3.4, -3], [22, 14], [22, 18], [4.5, 13]],
    extra: [[[2.4, -20], [9, -12], [2.4, -12]], [[3.4, 15], [11, 26], [9, 28], [3.4, 24]]], cockpit: [0, -19, 2.4, 7.5], eng: [[-2.6, 27, 2.6], [2.6, 27, 2.6]] },
  kartal: { main: '#7a6e62', camo: '#544a42', acc: '#ff9a3c', k: 1.6,
    body: [[0, -29], [6.5, -19], [8.5, 8], [7.5, 21], [0, 24]], wing: [[7.5, -8], [34, 9], [34, 15], [19, 15], [8.5, 13]],
    extra: [[[6.5, 14], [18, 22], [18, 27], [6.5, 23]], [[22, -3], [26, -3], [26, 15], [22, 15]]], cockpit: [0, -16, 3.6, 7.5], eng: [[-4.8, 25, 3.6], [4.8, 25, 3.6]] },
  anka: { main: '#3e2a4a', camo: '#2a1d33', acc: '#ff4fd8', k: 1.55, gold: '#ffd34f',
    body: [[0, -33], [5.5, -21], [6.5, 6], [4.5, 19], [0, 25]],
    wing: [[5.5, -10], [21, -6], [38, 6], [32, 9], [39, 14], [28, 14], [32, 20], [19, 16], [6.5, 12]],
    extra: [[[4.5, 15], [14, 28], [7.5, 26], [3.4, 23]]], cockpit: [0, -18, 3.2, 7.5], eng: [[-3.2, 26, 3.4], [3.2, 26, 3.4]] },
};
function planeSVG(id, d, opt = {}) {
  // Askeri jet stili: metal gövde, kamuflaj lekeleri, nişan, perçinler, panel çizgileri, kanat altı füzeler
  const defs = [], k = d.k, B = [];
  const wing = scl(d.wing, k), body = scl(mir(d.body), k);
  const gWing = lin(defs, [[0, shade(d.main, 1.3)], [.5, d.main], [1, shade(d.main, .5)]]);
  const gBody = lin(defs, [[0, shade(d.main, .4)], [.45, shade(d.main, 1.4)], [.55, shade(d.main, 1.2)], [1, shade(d.main, .4)]], 0, 0, 1, 0);
  const camo = d.camo || shade(d.main, .72);
  for (const sx of [1, -1]) {
    const w = sx > 0 ? wing : flip(wing);
    const [cx, cy] = cen(w);
    // kanat altı füze (gövdenin altında görünür)
    B.push(`<rect x="${cx - 1.6 + sx * 2}" y="${cy - 9}" width="3.2" height="15" rx="1.4" fill="#e8ecf2" stroke="${OUTL}" stroke-width=".8"/>`);
    B.push(circ(cx + sx * 2, cy - 9, 1.6, '#ff3355'));
    B.push(poly(w, gWing, OUTL, 1.6));
    // kamuflaj lekeleri
    B.push(poly(inset(w, .48).map(([x, y]) => [x + (cx - x) * .15 + sx * 3, y - 2]), camo, 'none', 0, 'opacity="0.75"'));
    B.push(poly(inset(w, .3).map(([x, y]) => [x - sx * 4, y + 3]), camo, 'none', 0, 'opacity="0.6"'));
    // panel çizgileri
    for (const f of [.35, .65]) { const a = w[0], b = w[w.length - 1], c = w[1], e = w[2]; B.push(line([a[0] + (c[0] - a[0]) * f, a[1] + (c[1] - a[1]) * f], [b[0] + (e[0] - b[0]) * f, b[1] + (e[1] - b[1]) * f], OUTL, .6, 'opacity="0.45"')); }
    // ön kenar + perçinler
    B.push(line(w[0], w[1], d.acc, 2.2));
    for (let i = 1; i < 6; i++) { const f = i / 6; B.push(circ(w[0][0] + (w[1][0] - w[0][0]) * f + sx * .2, w[0][1] + (w[1][1] - w[0][1]) * f + 2.4, .45, OUTL, 'none', 0, 'opacity="0.55"')); }
    // nişan: lacivert disk, beyaz halka, yıldız
    const rx = cx + sx * 4, ry = cy + 1;
    B.push(circ(rx, ry, 4.4, '#ffffff')); B.push(circ(rx, ry, 3.6, '#16325c'));
    B.push(`<polygon points="${[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => { const a = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 ? 1.1 : 2.6; return (rx + Math.cos(a) * r).toFixed(2) + ',' + (ry + Math.sin(a) * r).toFixed(2); }).join(' ')}" fill="#ffffff"/>`);
    if (d.gold) B.push(line(w[w.length - 2], w[w.length - 1], d.gold, 1.6));
    for (const e of d.extra) { // kuyruk / kanard
      const q = scl(sx > 0 ? e : flip(e), k);
      B.push(poly(q, gWing, OUTL, 1.4)); B.push(poly(inset(q, .5), camo, 'none', 0, 'opacity="0.7"'));
      B.push(line(q[0], q[1], d.acc, 1.2, 'opacity="0.8"'));
    }
  }
  // motor nozulları (petalli)
  for (const [ex, ey, er] of d.eng) {
    B.push(circ(ex * k, ey * k, er * k * 1.08, '#2a2e36', OUTL, 1.2));
    for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; B.push(line([ex * k + Math.cos(a) * er * k * .65, ey * k + Math.sin(a) * er * k * .65], [ex * k + Math.cos(a) * er * k * 1.02, ey * k + Math.sin(a) * er * k * 1.02], '#555b66', .7)); }
    B.push(circ(ex * k, ey * k, er * k * .58, rad(defs, [[0, '#fff3c0'], [.45, '#ff9a3c'], [1, '#6a200a']])));
  }
  B.push(poly(body, gBody, OUTL, 1.8));
  const [cx, cy, crx, cry] = d.cockpit, tail = d.body[3][1];
  // burun konisi + omurga + hava girişleri
  B.push(poly(scl([[0, d.body[0][1]], [d.body[1][0] * .55, d.body[1][1] + 2], [-d.body[1][0] * .55, d.body[1][1] + 2]], k), shade(d.main, .45)));
  B.push(line([0, (cy + cry + 2) * k], [0, tail * k], shade(d.main, .45), 1.1));
  for (const sx of [1, -1]) {
    B.push(poly([[sx * 3.2 * k, (cy + 2) * k], [sx * 5.4 * k, (cy + 5) * k], [sx * 5.4 * k, (cy + 10) * k], [sx * 3.4 * k, (cy + 9) * k]], '#14171d'));
    for (let i = 0; i < 4; i++) B.push(circ(sx * 2.2 * k, (cy + cry + 4 + i * 4) * k, .45, OUTL, 'none', 0, 'opacity="0.5"'));
  }
  B.push(poly([[0, (tail - 6) * k], [3 * k, (tail - 2) * k], [0, (tail - 3.6) * k], [-3 * k, (tail - 2) * k]], d.acc));
  // kokpit camı + çerçeve
  B.push(ell(cx * k, cy * k, crx * k + 1.4, cry * k + 1.4, OUTL));
  B.push(ell(cx * k, cy * k, crx * k, cry * k, rad(defs, [[0, '#f2fdff'], [.3, shade(d.acc, 1.2)], [1, '#06182c']], .4, .28, .75)));
  B.push(line([-crx * k, (cy + cry * .2) * k], [crx * k, (cy + cry * .2) * k], '#20242c', 1.1));
  B.push(ell((cx - crx * .3) * k, (cy - cry * .4) * k, crx * k * .32, cry * k * .28, '#ffffff', 'opacity="0.8"'));
  const tip = d.wing.reduce((a, b) => b[0] > a[0] ? b : a);
  B.push(circ(-tip[0] * k, tip[1] * k, 1.9, '#ff4040')); B.push(circ(tip[0] * k, tip[1] * k, 1.9, '#40ff70'));
  if (d.gold) B.push(poly(scl([[0, -30], [2, -24], [0, -22], [-2, -24]], k), d.gold));
  return { defs, body: B.join('') };
}
for (const [id, d] of Object.entries(PLANES)) { const r = planeSVG(id, d); write('plane_' + id, 128, 128, r.body, r.defs); }

// ---------------- Vahar filosu: fildişi gövde, mor/turkuaz parlama ----------------
const AOUT = '#1a1426';
function alienBase(defs, main = '#e4dff0') {
  return {
    hull: lin(defs, [[0, '#ffffff'], [.35, main], [1, shade(main, .55)]]),
    side: lin(defs, [[0, shade(main, .6)], [.5, '#ffffff'], [1, shade(main, .6)]], 0, 0, 1, 0),
    dark: lin(defs, [[0, '#3a2f52'], [1, '#14101e']]),
    core: c => rad(defs, [[0, '#ffffff'], [.35, c], [1, shade(c, .25)]]),
  };
}
const seam = (a, b, c, w = 1.4) => line(a, b, c, w, 'opacity="0.9"');
{ // Gözcü (drone)
  const defs = [], b = alienBase(defs), B = [];
  for (let i = 0; i < 3; i++) {
    const a = -Math.PI / 2 + i * 2 * Math.PI / 3, x = Math.cos(a) * 21, y = Math.sin(a) * 21;
    B.push(`<path d="M 0 0 Q ${x * .4 - y * .3} ${y * .4 + x * .3} ${x} ${y}" stroke="${AOUT}" stroke-width="7" fill="none"/>`);
    B.push(`<path d="M 0 0 Q ${x * .4 - y * .3} ${y * .4 + x * .3} ${x} ${y}" stroke="#cfc8e0" stroke-width="4.5" fill="none"/>`);
    B.push(circ(x, y, 5.5, b.core('#b46cff'), AOUT, 1.2));
  }
  B.push(circ(0, 0, 13, b.hull, AOUT, 2)); B.push(circ(0, 0, 8.5, b.dark));
  B.push(ell(0, -1, 6, 3.4, b.core('#b46cff')));
  write('e_drone', 64, 64, B.join(''), defs);
}
{ // Avcı
  const defs = [], b = alienBase(defs), B = [];
  for (const s of [1, -1]) {
    B.push(`<path d="M ${6 * s} -8 C ${26 * s} -4, ${36 * s} 10, ${30 * s} 26 C ${22 * s} 16, ${14 * s} 14, ${7 * s} 16 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="1.6"/>`);
    B.push(`<path d="M ${10 * s} -4 C ${24 * s} 0, ${30 * s} 10, ${28 * s} 20" stroke="#ff4fd8" stroke-width="1.6" fill="none"/>`);
  }
  B.push(poly(mir([[0, -36], [6, -16], [8, 14], [0, 24]]), b.side, AOUT, 1.8));
  B.push(ell(0, -12, 3.4, 8, b.core('#ff4fd8')));
  for (const s of [1, -1]) B.push(circ(4 * s, 22, 3, b.core('#b46cff')));
  write('e_avci', 80, 80, B.join(''), defs);
}
{ // Dalıcı (kamikaze)
  const defs = [], b = alienBase(defs), B = [];
  for (const s of [1, -1]) B.push(poly([[5, 2], [17, 28], [5, 19]].map(([x, y]) => [x * s, y]), b.hull, AOUT, 1.4));
  B.push(poly(mir([[0, -36], [7, -8], [5.5, 22], [0, 17]]), b.side, AOUT, 1.8));
  B.push(poly(mir([[0, -36], [5, -18], [0, -21]]), b.core('#ffe14f'), AOUT, 1));
  for (let i = 0; i < 3; i++) B.push(seam([-5, -6 + i * 8], [5, -6 + i * 8], '#ffe14f', 1.4));
  B.push(circ(0, 17, 3.6, b.core('#ffb03c')));
  write('e_kamikaze', 72, 72, B.join(''), defs);
}
{ // Topçu
  const defs = [], b = alienBase(defs), B = [];
  for (const s of [1, -1]) { B.push(`<rect x="${s > 0 ? 8 : -14}" y="-44" width="6" height="30" rx="2" fill="#cfc8e0" stroke="${AOUT}" stroke-width="1.4"/>`); B.push(circ(s * 11, -44, 3, '#3cffd8')); }
  B.push(`<path d="M 0 -30 C 28 -30, 34 -4, 30 12 C 24 28, -24 28, -30 12 C -34 -4, -28 -30, 0 -30 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="2"/>`);
  B.push(`<path d="M 0 -20 C 18 -20, 22 -2, 20 8 C 16 18, -16 18, -20 8 C -22 -2, -18 -20, 0 -20 Z" fill="${b.dark}"/>`);
  for (let i = 0; i < 5; i++) { const a = Math.PI * (1.1 + i * .2); B.push(circ(Math.cos(a) * 25, Math.sin(a) * 22 + 2, 2.2, '#3cffd8')); }
  B.push(circ(0, 0, 8, b.core('#3cffd8')));
  write('e_topcu', 96, 96, B.join(''), defs);
}
{ // Girdap
  const defs = [], b = alienBase(defs), B = [];
  for (let i = 0; i < 3; i++) {
    const r = i * 120;
    B.push(`<path d="M 6 -8 C 30 -30, 44 -10, 40 12 C 30 0, 18 -4, 8 6 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="1.6" transform="rotate(${r})"/>`);
    B.push(`<path d="M 14 -14 C 30 -24, 40 -10, 38 6" fill="none" stroke="#b46cff" stroke-width="2.2" transform="rotate(${r})"/>`);
  }
  B.push(circ(0, 0, 14, b.hull, AOUT, 2)); B.push(circ(0, 0, 8, b.core('#b46cff')));
  write('e_girdap', 96, 96, B.join(''), defs);
}
{ // Ağır gemi (bombardıman)
  const defs = [], b = alienBase(defs), B = [];
  B.push(`<path d="M 0 -52 C 30 -44, 60 -10, 74 14 C 60 20, 44 14, 30 24 C 18 30, 6 26, 0 26 C -6 26, -18 30, -30 24 C -44 14, -60 20, -74 14 C -60 -10, -30 -44, 0 -52 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="2.2"/>`);
  B.push(poly(mir([[0, -40], [12, -30], [14, 14], [0, 18]]), b.side, AOUT, 1.6));
  for (const s of [1, -1]) {
    B.push(`<path d="M ${16 * s} -26 C ${40 * s} -14, ${56 * s} 0, ${66 * s} 12" stroke="#6aa8ff" stroke-width="1.6" fill="none"/>`);
    for (const x of [28, 48]) { B.push(circ(s * x, 12, 6, b.dark, AOUT, 1.2)); B.push(circ(s * x, 12, 3.5, b.core('#6aa8ff'))); }
  }
  B.push(ell(0, -16, 5, 9, b.core('#b46cff')));
  write('e_bombardiman', 160, 128, B.join(''), defs);
}

// ---------------- Bosslar ----------------
{ // Öncü Avcı: hilal kanatlı hızlı av gemisi
  const defs = [], b = alienBase(defs), B = [];
  for (const s of [1, -1]) {
    B.push(`<path d="M ${10 * s} -30 C ${60 * s} -50, ${110 * s} -20, ${112 * s} 30 C ${90 * s} 10, ${60 * s} 6, ${16 * s} 30 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="2.5"/>`);
    B.push(`<path d="M ${20 * s} -26 C ${60 * s} -40, ${98 * s} -14, ${104 * s} 18" stroke="#b46cff" stroke-width="3" fill="none"/>`);
    B.push(`<path d="M ${30 * s} 0 C ${60 * s} -8, ${80 * s} 4, ${90 * s} 14" stroke="${AOUT}" stroke-width="1.2" fill="none" opacity="0.5"/>`);
    for (const x of [40, 70]) B.push(circ(s * x, 18, 5, b.core('#ff4fd8')));
  }
  B.push(poly(mir([[0, -80], [14, -50], [18, 30], [10, 56], [0, 50]]), b.side, AOUT, 2.5));
  B.push(ell(0, -36, 7, 16, b.core('#b46cff'), `stroke="${AOUT}" stroke-width="2"`));
  for (const x of [-8, 0, 8]) B.push(circ(x, 50, 4.5, b.core('#3cffd8')));
  write('b_oncu', 240, 180, B.join(''), defs);
}
{ // İndirme Gemisi: geniş nakliye, bölmeli
  const defs = [], b = alienBase(defs, '#d8d2e8'), B = [];
  B.push(`<path d="M 0 -110 C 70 -104, 120 -70, 128 0 C 130 60, 100 100, 0 108 C -100 100, -130 60, -128 0 C -120 -70, -70 -104, 0 -110 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="3"/>`);
  for (let r = 0; r < 2; r++) for (let c = 0; c < 3; c++) {
    const x = -66 + c * 44, y = -40 + r * 56;
    B.push(`<rect x="${x}" y="${y}" width="44" height="44" rx="6" fill="${b.dark}" stroke="${AOUT}" stroke-width="2"/>`);
    B.push(`<rect x="${x + 6}" y="${y + 6}" width="32" height="32" rx="4" fill="none" stroke="#6aa8ff" stroke-width="1.5" opacity="0.7"/>`);
    B.push(circ(x + 22, y + 22, 5, b.core('#b46cff')));
  }
  for (const [x, y] of [[-118, -40], [118, -40], [-110, 60], [110, 60]]) { B.push(ell(x, y, 16, 26, b.side, `stroke="${AOUT}" stroke-width="2"`)); B.push(circ(x, y + 18, 7, b.core('#6aa8ff'))); }
  B.push(ell(0, -86, 26, 10, b.core('#3cffd8')));
  write('b_indirme', 300, 240, B.join(''), defs);
}
{ // Kızıl Kanat: ağır bombardıman kanat
  const defs = [], b = alienBase(defs, '#e8d6d6'), B = [];
  const w = [[0, -70], [30, -56], [130, -8], [150, 24], [110, 18], [86, 34], [56, 26], [40, 48], [0, 40]];
  B.push(poly(mir(w), b.hull, AOUT, 3));
  B.push(poly(mir([[0, -56], [22, -42], [26, 24], [0, 32]]), b.side, AOUT, 2));
  for (const s of [1, -1]) {
    B.push(poly(inset(w.slice(1, 6).map(([x, y]) => [x * s, y]), .7), '#3a1a22', '#ff5a3c', 1.2, 'stroke-opacity="0.6"'));
    B.push(line([s * 30, -56], [s * 130, -8], '#ff3355', 3.4));
    for (const x of [70, 100]) { B.push(circ(s * x, 6, 9, b.dark, AOUT, 2)); B.push(circ(s * x, 6, 5, b.core('#ff5a3c'))); }
    for (const x of [16, 40]) { B.push(circ(s * x, 40, 6.5, b.dark, AOUT, 1.4)); B.push(circ(s * x, 40, 4.5, b.core('#ffb03c'))); }
  }
  B.push(ell(0, -14, 11, 18, b.core('#ff3355'), `stroke="${AOUT}" stroke-width="2.5"`));
  write('b_kizil_kanat', 320, 200, B.join(''), defs);
}
{ // Fırtına Kalesi: dönen halka kale
  const defs = [], b = alienBase(defs, '#dfe6ee'), B = [];
  for (let i = 0; i < 8; i++) {
    const a0 = (i * 45 - 17) * Math.PI / 180, a1 = (i * 45 + 17) * Math.PI / 180, R = 140, r = 110;
    const p = (a, R) => `${(Math.cos(a) * R).toFixed(1)} ${(Math.sin(a) * R).toFixed(1)}`;
    B.push(`<path d="M ${p(a0, R)} A ${R} ${R} 0 0 1 ${p(a1, R)} L ${p(a1, r)} A ${r} ${r} 0 0 0 ${p(a0, r)} Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="2.5"/>`);
    B.push(circ(Math.cos((a0 + a1) / 2) * 125, Math.sin((a0 + a1) / 2) * 125, 4.5, '#3cffd8'));
  }
  const oct = []; for (let i = 0; i < 8; i++) { const a = Math.PI / 8 + i * Math.PI / 4; oct.push([Math.cos(a) * 92, Math.sin(a) * 92]); }
  B.push(poly(oct, b.side, AOUT, 3)); B.push(poly(inset(oct, .75), b.dark, '#3cffd8', 1.5, 'stroke-opacity="0.6"'));
  for (let i = 0; i < 4; i++) B.push(`<rect x="60" y="-9" width="40" height="18" rx="4" fill="#cfc8e0" stroke="${AOUT}" stroke-width="2" transform="rotate(${i * 90})"/>`);
  B.push(circ(0, 0, 34, b.core('#3cffd8'), AOUT, 3)); B.push(circ(0, 0, 14, '#eafffa', 'none', 0, 'opacity="0.85"'));
  write('b_firtina_kalesi', 300, 300, B.join(''), defs);
}
{ // Hasat Gemisi: emici girdaplı daire
  const defs = [], b = alienBase(defs), B = [];
  for (let i = 0; i < 6; i++) {
    B.push(`<g transform="rotate(${i * 60})"><rect x="-10" y="-150" width="20" height="60" rx="6" fill="${b.side}" stroke="${AOUT}" stroke-width="2"/>${circ(0, -150, 16, b.hull, AOUT, 2)}${circ(0, -150, 8, b.core('#57ff9a'))}</g>`);
  }
  B.push(circ(0, 0, 100, b.hull, AOUT, 3));
  B.push(circ(0, 0, 78, b.dark, '#57ff9a', 2, 'stroke-opacity="0.5"'));
  for (let i = 0; i < 5; i++) B.push(`<path d="M 0 0 C ${30 + i * 4} -10, ${50} ${-40 + i * 8}, ${70 - i * 6} ${-30 - i * 6}" fill="none" stroke="#57ff9a" stroke-width="${3 - i * .4}" opacity="${.9 - i * .12}" transform="rotate(${i * 72})"/>`);
  B.push(circ(0, 0, 30, rad(defs, [[0, '#ffffff'], [.3, '#a8ffcc'], [.7, '#57ff9a'], [1, '#0a3a20']])));
  write('b_hasat', 320, 320, B.join(''), defs);
}
{ // SEFİNE: yaşam gemisi (ana gemi) — üstten şehir ışıklı dev gövde
  const defs = [], b = alienBase(defs, '#e8e2d0'), B = [];
  B.push(circ(0, 0, 196, rad(defs, [[0, '#ffd34f', .35], [.7, '#ff9a3c', .1], [1, '#ff9a3c', 0]])));
  B.push(`<path d="M 0 -190 C 90 -180, 150 -100, 160 0 C 150 100, 90 180, 0 190 C -90 180, -150 100, -160 0 C -150 -100, -90 -180, 0 -190 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="4"/>`);
  for (const r of [150, 118, 86]) B.push(circ(0, 0, r, 'none', AOUT, 2, 'opacity="0.35"'));
  for (let i = 0; i < 12; i++) B.push(`<g transform="rotate(${i * 30})"><rect x="-6" y="-176" width="12" height="40" rx="3" fill="${b.dark}"/>${circ(0, -170, 3.5, '#ffd34f')}</g>`);
  for (let i = 0; i < 220; i++) { const a = Math.random() * 6.283, r = 60 + Math.random() * 95; B.push(circ((Math.cos(a) * r).toFixed(1), (Math.sin(a) * r).toFixed(1), (Math.random() * 1.4 + .6).toFixed(1), Math.random() < .7 ? '#ffd34f' : '#3cffd8', 'none', 0, `opacity="${(.5 + Math.random() * .5).toFixed(2)}"`)); }
  B.push(circ(0, 0, 58, b.dark, '#ffd34f', 3));
  B.push(circ(0, 0, 40, rad(defs, [[0, '#ffffff'], [.3, '#fff0b0'], [.6, '#ffd34f'], [1, '#7a4a00']])));
  for (let i = 0; i < 4; i++) B.push(`<g transform="rotate(${45 + i * 90})"><rect x="-18" y="-206" width="36" height="34" rx="8" fill="${b.side}" stroke="${AOUT}" stroke-width="2.5"/>${circ(0, -190, 9, b.core('#ff9a3c'))}</g>`);
  write('b_sefine', 420, 420, B.join(''), defs);
}

// ---------------- Mermiler, eşyalar, efektler ----------------
{ const defs = []; write('p_bullet', 16, 44, ell(0, 0, 5, 19, rad(defs, [[0, '#ffffff'], [.5, '#ffffff', .9], [1, '#ffffff', 0]])), defs); }
{ const defs = [], B = [];
  B.push(poly([[0, -18], [4, -10], [4, 12], [0, 14], [-4, 12], [-4, -10]], lin(defs, [[0, '#7a8494'], [.5, '#e6ebf2'], [1, '#7a8494']], 0, 0, 1, 0), OUTL, 1));
  B.push(poly([[0, -18], [4, -10], [-4, -10]], '#ff3355'));
  for (const s of [1, -1]) B.push(poly([[s * 4, 6], [s * 9, 14], [s * 4, 12]], '#5a6272', OUTL, 1));
  write('p_missile', 20, 40, B.join(''), defs); }
{ const defs = [], B = [];
  for (let i = 0; i < 8; i++) B.push(`<polygon points="-3,-11 0,-16 3,-11" fill="#5a6272" stroke="${OUTL}" stroke-width="1" transform="rotate(${i * 45})"/>`);
  B.push(circ(0, 0, 11, lin(defs, [[0, '#6a7282'], [1, '#262a32']]), OUTL, 1.5)); B.push(circ(0, 0, 4, rad(defs, [[0, '#fff'], [.4, '#ff3355'], [1, '#600010']])));
  write('p_mine', 36, 36, B.join(''), defs); }
{ const defs = [], B = []; // kalkan dronu
  B.push(circ(0, 0, 13, lin(defs, [[0, '#cfe8ff'], [1, '#3a5a80']]), OUTL, 1.5)); B.push(circ(0, 0, 7, rad(defs, [[0, '#fff'], [.4, '#4fd8ff'], [1, '#0a3050']])));
  for (let i = 0; i < 4; i++) B.push(`<rect x="11" y="-2" width="6" height="4" fill="#4fd8ff" transform="rotate(${i * 90})"/>`);
  write('p_orb', 40, 40, B.join(''), defs); }
{ const defs = []; write('orb', 32, 32, circ(0, 0, 15, rad(defs, [[0, '#ffffff'], [.42, '#ffffff'], [.55, '#d8d8d8'], [.75, '#9a9a9a', .8], [1, '#808080', 0]])), defs); }
{ const defs = []; write('glow', 64, 64, circ(0, 0, 31, rad(defs, [[0, '#ffffff'], [.25, '#ffffff', .7], [1, '#ffffff', 0]])), defs); }
{ const defs = []; write('ring', 128, 128, circ(0, 0, 62, rad(defs, [[0, '#ffffff', 0], [.78, '#ffffff', 0], [.9, '#ffffff', .9], [.96, '#ffffff', .4], [1, '#ffffff', 0]])), defs); }
{ const defs = [], B = [];
  B.push(poly([[0, -15], [9, -4], [0, 15], [-9, -4]], lin(defs, [[0, '#ffffff'], [1, '#9a9a9a']]), '#ffffff', 1));
  B.push(poly([[0, -15], [9, -4], [0, -1]], '#ffffff', 'none', 0, 'opacity="0.85"')); B.push(poly([[0, -1], [-9, -4], [0, 15]], '#6a6a6a', 'none', 0, 'opacity="0.6"'));
  write('gem', 24, 34, B.join(''), defs); }
{ const defs = [], B = []; B.push(circ(0, 0, 14, '#f2fff6', OUTL, 1.5)); B.push(poly([[-3.5, -9], [3.5, -9], [3.5, -3.5], [9, -3.5], [9, 3.5], [3.5, 3.5], [3.5, 9], [-3.5, 9], [-3.5, 3.5], [-9, 3.5], [-9, -3.5], [-3.5, -3.5]], '#2ed06a')); write('heal', 32, 32, B.join(''), defs); }
{ const defs = [], B = []; B.push(`<path d="M -10 -10 L -10 2 A 10 10 0 0 0 10 2 L 10 -10 L 4 -10 L 4 2 A 4 4 0 0 1 -4 2 L -4 -10 Z" fill="#ff3355" stroke="${OUTL}" stroke-width="1.5"/>`); B.push(`<rect x="-10" y="-13" width="6" height="5" fill="#dfe8f5"/><rect x="4" y="-13" width="6" height="5" fill="#dfe8f5"/>`); write('magnet', 32, 32, B.join(''), defs); }
{ const defs = [], B = []; B.push(`<rect x="-20" y="-14" width="40" height="28" rx="3" fill="${lin(defs, [[0, '#ffd34f'], [1, '#a0661a']])}" stroke="${OUTL}" stroke-width="2"/>`);
  B.push(`<rect x="-20" y="-4" width="40" height="5" fill="#5a3a10"/><rect x="-4" y="-8" width="8" height="12" rx="1" fill="#fff3c0" stroke="${OUTL}" stroke-width="1"/>`); write('chest', 48, 36, B.join(''), defs); }

// ---------------- Silah / pasif ikonları (64) ----------------
function icon(name, col, glyph) {
  const defs = [], B = [];
  B.push(`<rect x="-30" y="-30" width="60" height="60" rx="10" fill="${lin(defs, [[0, '#1a2436'], [1, '#070b14']])}" stroke="${col}" stroke-width="2.5"/>`);
  B.push(glyph(defs)); write(name, 64, 64, B.join(''), defs);
}
icon('w_top', '#4fd8ff', () => [-8, 8].map(x => `<rect x="${x - 3}" y="-16" width="6" height="26" rx="3" fill="#4fd8ff"/>` + `<rect x="${x - 3}" y="12" width="6" height="5" fill="#ffd34f"/>`).join(''));
icon('w_fuze', '#ff7a3c', () => `<g transform="rotate(35)">${poly([[0, -20], [5, -10], [5, 12], [0, 15], [-5, 12], [-5, -10]], '#dfe8f5', OUTL, 1)}${poly([[0, -20], [5, -10], [-5, -10]], '#ff3355')}${poly([[5, 6], [11, 16], [5, 13]], '#7a8494')}${poly([[-5, 6], [-11, 16], [-5, 13]], '#7a8494')}${ell(0, 20, 3, 6, '#ffb03c')}</g>`);
icon('w_kalkan', '#4fd8ff', () => circ(0, 0, 17, 'none', '#4fd8ff', 1.5, 'stroke-dasharray="4 4" opacity="0.7"') + circ(0, 0, 6, '#dfe8f5') + [0, 120, 240].map(a => circ(Math.cos(a * Math.PI / 180) * 17, Math.sin(a * Math.PI / 180) * 17, 5, '#4fd8ff')).join(''));
icon('w_emp', '#b46cff', () => [8, 14, 20].map((r, i) => circ(0, 0, r, 'none', '#b46cff', 3 - i * .6, `opacity="${1 - i * .25}"`)).join('') + circ(0, 0, 4, '#ffffff'));
icon('w_simsek', '#ffe14f', () => poly([[4, -22], [-10, 2], [-1, 2], [-5, 22], [10, -4], [1, -4]], '#ffe14f', OUTL, 1.2));
icon('w_lazer', '#ff4fd8', () => `<rect x="-3" y="-24" width="6" height="34" fill="#ff4fd8"/><rect x="-1.2" y="-24" width="2.4" height="34" fill="#fff"/>` + poly([[-10, 10], [10, 10], [7, 20], [-7, 20]], '#7a8494', OUTL, 1));
icon('w_mayin', '#ff3355', () => [0, 45, 90, 135, 180, 225, 270, 315].map(a => `<rect x="-2" y="-19" width="4" height="8" fill="#9aa4b8" transform="rotate(${a})"/>`).join('') + circ(0, 0, 12, '#3a404c', OUTL, 1.5) + circ(0, 0, 4.5, '#ff3355'));
icon('p_motor', '#ff9a3c', () => [0, 9, 18].map(y => `<polyline points="-12,${y - 6} 0,${y - 16} 12,${y - 6}" fill="none" stroke="#ff9a3c" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>`).join(''));
icon('p_zirh', '#9fb3c8', d => `<path d="M 0 -20 L 16 -13 L 14 6 C 11 15, 4 19, 0 21 C -4 19, -11 15, -14 6 L -16 -13 Z" fill="${lin(d, [[0, '#dfe8f5'], [1, '#5a6a80']])}" stroke="${OUTL}" stroke-width="1.5"/>` + line([0, -14], [0, 14], '#3a4a60', 2));
icon('p_miknatis', '#ff3355', () => `<path d="M -12 -14 L -12 2 A 12 12 0 0 0 12 2 L 12 -14 L 5 -14 L 5 2 A 5 5 0 0 1 -5 2 L -5 -14 Z" fill="#ff3355"/><rect x="-12" y="-19" width="7" height="6" fill="#dfe8f5"/><rect x="5" y="-19" width="7" height="6" fill="#dfe8f5"/>`);
icon('p_sogutucu', '#4fd8ff', () => [0, 60, 120].map(a => `<g transform="rotate(${a})">${line([0, -19], [0, 19], '#4fd8ff', 3)}${line([0, -12], [-5, -17], '#4fd8ff', 2)}${line([0, -12], [5, -17], '#4fd8ff', 2)}${line([0, 12], [-5, 17], '#4fd8ff', 2)}${line([0, 12], [5, 17], '#4fd8ff', 2)}</g>`).join(''));
icon('p_kalibre', '#ffe14f', () => circ(0, 0, 14, 'none', '#ffe14f', 3) + line([0, -22], [0, -8], '#ffe14f', 3) + line([0, 8], [0, 22], '#ffe14f', 3) + line([-22, 0], [-8, 0], '#ffe14f', 3) + line([8, 0], [22, 0], '#ffe14f', 3) + circ(0, 0, 3, '#ff3355'));
icon('p_onarim', '#2ed06a', () => poly([[-5, -18], [5, -18], [5, -5], [18, -5], [18, 5], [5, 5], [5, 18], [-5, 18], [-5, 5], [-18, 5], [-18, -5], [-5, -5]], '#2ed06a', OUTL, 1.2));

// v0.9: yeni silahlar
icon('w_napalm', '#ff7a1a', d => `<path d="M -14 18 C -20 6, -8 0, -6 -10 C -2 -2, 2 -4, 0 -20 C 10 -10, 18 2, 12 18 Z" fill="${lin(d, [[0, '#ffe14f'], [1, '#ff5a1a']])}" stroke="${OUTL}" stroke-width="1.2"/>` + ell(0, 21, 16, 3, '#ff7a1a', 'opacity="0.6"'));
icon('w_ray', '#8fe8ff', () => `<rect x="-20" y="-3" width="40" height="6" fill="#8fe8ff"/><rect x="-20" y="-1" width="40" height="2" fill="#fff"/>` + [-14, -4, 6].map(x => `<rect x="${x}" y="-9" width="4" height="18" rx="1" fill="#3a4a60" stroke="#8fe8ff" stroke-width="1"/>`).join(''));
icon('w_glaive', '#57ff9a', () => [0, 120, 240].map(a => `<path d="M 0 0 C 6 -6, 8 -14, 2 -22 C 12 -14, 12 -4, 4 2 Z" fill="#57ff9a" stroke="${OUTL}" stroke-width="1" transform="rotate(${a})"/>`).join('') + circ(0, 0, 4, '#dfe8f5', OUTL, 1));
icon('w_hava', '#ff3355', () => circ(0, 4, 14, 'none', '#ff3355', 2, 'stroke-dasharray="5 3"') + line([0, -12], [0, 20], '#ff3355', 1.5) + line([-16, 4], [16, 4], '#ff3355', 1.5) + poly([[-4, -24], [4, -24], [4, -12], [0, -6], [-4, -12]], '#dfe8f5', OUTL, 1));
icon('w_taret', '#ffb03c', () => poly([[-14, 18], [14, 18], [10, 6], [-10, 6]], '#7a8494', OUTL, 1) + circ(0, 2, 9, '#3a404c', OUTL, 1.5) + `<rect x="-2.5" y="-22" width="5" height="20" fill="#ffb03c" stroke="${OUTL}" stroke-width="1"/>`);
// v0.9: yeni pasifler
icon('p_nisan', '#ff4fd8', () => circ(0, 0, 16, 'none', '#ff4fd8', 2.5) + circ(0, 0, 7, 'none', '#ff4fd8', 2) + circ(0, 0, 2.5, '#fff') + line([-22, -22], [-12, -12], '#ff4fd8', 2.5) + line([22, 22], [12, 12], '#ff4fd8', 2.5));
icon('p_alan', '#b46cff', () => [7, 13, 19].map((r, i) => circ(0, 0, r, 'none', '#b46cff', 2.5, `stroke-dasharray="${6 + i * 3} 4" opacity="${1 - i * .2}"`)).join('') + circ(0, 0, 3, '#fff'));
icon('p_ogrenme', '#4fd8ff', () => [-12, 0, 12].map((x, i) => `<rect x="${x - 4}" y="${8 - i * 8}" width="8" height="${12 + i * 8}" fill="#4fd8ff" opacity="${0.6 + i * 0.2}"/>`).join('') + `<polyline points="-16,-4 -4,-12 6,-6 18,-20" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/>`);
icon('p_deflektor', '#8fd0ff', d => `<path d="M -20 -6 A 24 24 0 0 1 20 -6" fill="none" stroke="#8fd0ff" stroke-width="4" stroke-linecap="round"/>` + `<path d="M -14 4 A 16 16 0 0 1 14 4" fill="none" stroke="#8fd0ff" stroke-width="2.5" opacity="0.7" stroke-linecap="round"/>` + poly([[0, 22], [6, 10], [-6, 10]], '#ff3355'));
icon('p_coklayici', '#ffe14f', () => [-10, 0, 10].map(x => `<rect x="${x - 3}" y="-18" width="6" height="22" rx="3" fill="#ffe14f" stroke="${OUTL}" stroke-width="1"/>`).join('') + `<text x="0" y="22" font-size="14" font-family="sans-serif" font-weight="bold" fill="#fff" text-anchor="middle">+1</text>`);
icon('p_delici', '#ff9a3c', () => poly([[0, -22], [7, -6], [3, -6], [3, 20], [-3, 20], [-3, -6], [-7, -6]], '#dfe8f5', OUTL, 1) + poly([[0, -22], [7, -6], [-7, -6]], '#ff9a3c') + `<rect x="-16" y="4" width="32" height="5" fill="#5a6a80" opacity="0.8"/>`);
// v0.11: yeni pasifler
icon('p_sonnefes', '#ff3355', () => `<path d="M 0 20 C -26 2, -22 -20, -8 -20 C -2 -20, 0 -14, 0 -12 C 0 -14, 2 -20, 8 -20 C 22 -20, 26 2, 0 20 Z" fill="#3a0a14" stroke="#ff3355" stroke-width="2.5"/>` + `<polyline points="-18,-2 -8,-2 -3,-12 3,8 8,-2 18,-2" fill="none" stroke="#ff8a3c" stroke-width="2.5" stroke-linejoin="round"/>`);
icon('p_avci', '#ffd34f', () => circ(0, 0, 17, 'none', '#ffd34f', 2) + poly([[0, -22], [5, -8], [0, -12], [-5, -8]], '#ffd34f') + poly([[0, 22], [5, 8], [0, 12], [-5, 8]], '#ffd34f') + poly([[-22, 0], [-8, 5], [-12, 0], [-8, -5]], '#ffd34f') + poly([[22, 0], [8, 5], [12, 0], [8, -5]], '#ffd34f') + circ(0, 0, 4, '#ff3355'));
// v0.9: yeni mermi/nesne görselleri
{ const defs = []; write('p_glaive', 40, 40, [0, 120, 240].map(a => `<path d="M 0 0 C 6 -6, 8 -14, 2 -19 C 12 -12, 12 -3, 4 2 Z" fill="#c8ffe0" stroke="#57ff9a" stroke-width="1.5" transform="rotate(${a})"/>`).join('') + circ(0, 0, 4, '#ffffff'), defs); }
{ const defs = []; write('p_turret', 40, 40, circ(0, 0, 15, '#3a404c', OUTL, 2) + circ(0, 0, 9, '#7a8494', OUTL, 1) + `<rect x="-2.5" y="-19" width="5" height="16" fill="#ffb03c" stroke="${OUTL}" stroke-width="1"/>` + circ(0, 0, 3, '#ffb03c'), defs); }

// ---------------- Portreler (256) ----------------
function portraitFrame(defs, col) {
  return `<rect x="-128" y="-128" width="256" height="256" fill="${lin(defs, [[0, shade(col, .25)], [1, '#04060c']])}"/>` +
    circ(0, -10, 110, rad(defs, [[0, col, .35], [1, col, 0]]));
}
// Konuşan portre kareleri: '' (sakin), '_talk' (ağız açık), '_blink' (göz kapalı) — oyunda sınırlı animasyonla değişir
for (const fr of ['', '_talk', '_blink']) { // Komutan Atlas
  const defs = [], B = [], skin = lin(defs, [[0, '#e8b896'], [1, '#b07a5a']]), uni = lin(defs, [[0, '#4a5a3a'], [1, '#26301e']]);
  B.push(portraitFrame(defs, '#4fd8ff'));
  B.push(`<path d="M -120 128 C -110 60, -70 48, -30 42 L 30 42 C 70 48, 110 60, 120 128 Z" fill="${uni}" stroke="${OUTL}" stroke-width="3"/>`);
  B.push(`<path d="M -30 42 L 0 90 L 30 42 Z" fill="#dfe3d0"/><path d="M -8 52 L 8 52 L 4 100 L 0 108 L -4 100 Z" fill="#7a1a1a"/>`);
  for (const s of [1, -1]) B.push(`<rect x="${s > 0 ? 50 : -96}" y="54" width="46" height="12" rx="3" fill="#ffd34f" stroke="${OUTL}" stroke-width="2"/>`);
  [['#ff3355', -78], ['#4fd8ff', -64], ['#ffd34f', -50]].forEach(([c, x]) => B.push(`<rect x="${x}" y="80" width="12" height="18" fill="${c}" stroke="${OUTL}" stroke-width="1.5"/>`));
  B.push(`<rect x="-16" y="16" width="32" height="30" fill="${skin}"/>`);
  B.push(ell(0, -10, 44, 54, skin, `stroke="${OUTL}" stroke-width="3"`));
  B.push(ell(-46, -8, 7, 12, '#c48a6a', `stroke="${OUTL}" stroke-width="2"`) + ell(46, -8, 7, 12, '#c48a6a', `stroke="${OUTL}" stroke-width="2"`));
  B.push(`<path d="M -52 -40 C -52 -86, 52 -86, 52 -40 L 58 -36 L -58 -36 Z" fill="${uni}" stroke="${OUTL}" stroke-width="3"/>`);
  B.push(`<path d="M -62 -38 C -30 -24, 30 -24, 62 -38 L 56 -28 C 30 -16, -30 -16, -56 -28 Z" fill="#141a10" stroke="${OUTL}" stroke-width="2"/>`);
  B.push(`<polygon points="0,-72 5,-60 18,-60 8,-52 12,-40 0,-48 -12,-40 -8,-52 -18,-60 -5,-60" fill="#ffd34f" stroke="${OUTL}" stroke-width="1.5"/>`);
  B.push(`<path d="M -32 -18 L -10 -14" stroke="#5a5a5a" stroke-width="5" stroke-linecap="round"/><path d="M 32 -18 L 10 -14" stroke="#5a5a5a" stroke-width="5" stroke-linecap="round"/>`);
  B.push(fr === '_blink' ? line([-27, -4], [-15, -3], '#3a2a20', 2.5) + line([15, -3], [27, -4], '#3a2a20', 2.5) : ell(-21, -4, 6, 4, '#1a1a1a') + ell(21, -4, 6, 4, '#1a1a1a'));
  B.push(`<path d="M 0 -2 L -6 18 L 6 18" fill="none" stroke="#8a5a40" stroke-width="2.5"/>`);
  B.push(`<path d="M -26 28 C -14 18, 14 18, 26 28 C 14 26, -14 26, -26 28 Z" fill="#9a9a9a" stroke="${OUTL}" stroke-width="2"/>`);
  B.push(fr === '_talk' ? ell(0, 37, 10, 6, '#3a1410', 'stroke="#7a3a2a" stroke-width="2"') : `<path d="M -12 36 L 12 36" stroke="#7a3a2a" stroke-width="3" stroke-linecap="round"/>`);
  B.push(`<path d="M 26 8 L 34 22" stroke="#9a6a50" stroke-width="2"/>`);
  write('portrait_cmd' + fr, 256, 256, B.join(''), defs);
}
for (const fr of ['', '_talk', '_blink']) { // Pilot Şahin-1
  const defs = [], B = [], suit = lin(defs, [[0, '#5a6a50'], [1, '#2a3224']]);
  B.push(portraitFrame(defs, '#ffd34f'));
  B.push(`<path d="M -120 128 C -110 60, -70 50, -30 44 L 30 44 C 70 50, 110 60, 120 128 Z" fill="${suit}" stroke="${OUTL}" stroke-width="3"/>`);
  B.push(`<rect x="-80" y="70" width="40" height="22" rx="3" fill="#2a3224" stroke="${OUTL}" stroke-width="2"/><rect x="-74" y="76" width="28" height="10" fill="#c83a3a"/>`);
  B.push(circ(0, -14, 70, lin(defs, [[0, '#e6ebf2'], [1, '#7a8494']]), OUTL, 3));
  B.push(`<path d="M -60 -30 C -60 -64, 60 -64, 60 -30" fill="none" stroke="#ffd34f" stroke-width="7"/>`);
  B.push(`<path d="M -54 -20 C -30 -36, 30 -36, 54 -20 C 52 18, 30 34, 0 36 C -30 34, -52 18, -54 -20 Z" fill="${lin(defs, [[0, '#ffd34f'], [.5, '#ff8a3c'], [1, '#3a1a0a']])}" stroke="${OUTL}" stroke-width="3"/>`);
  B.push(`<path d="M -40 -18 C -20 -26, 0 -26, 10 -24" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity="${fr === '_blink' ? 0.35 : 0.75}" ${fr === '_blink' ? 'transform="translate(14 4)"' : ''}/>`);
  B.push(`<path d="M -24 36 L 24 36 L 18 60 L -18 60 Z" fill="#3a404c" stroke="${OUTL}" stroke-width="2.5"/>`);
  B.push(`<path d="M 18 52 C 40 60, 50 76, 48 96" fill="none" stroke="#2a2f3a" stroke-width="7"/>`);
  B.push(`<text x="0" y="-62" font-family="Arial" font-weight="900" font-size="16" fill="#2a2f3a" text-anchor="middle">Ş-1</text>`);
  if (fr === '_talk') B.push(circ(14, 48, 5, '#57ff9a', OUTL, 1.5) + circ(14, 48, 10, rad(defs, [[0, '#57ff9a', .8], [1, '#57ff9a', 0]]))); // telsiz ışığı
  write('portrait_pilot' + fr, 256, 256, B.join(''), defs);
}
// ---------------- Vahar portreleri: insana benzer ama tam insan değil ----------------
function alienFace(defs, B, o) {
  // o: skin, eye, hair (null = kel), crest, collar, marks, scar
  const skin = lin(defs, [[0, shade(o.skin, 1.15)], [1, shade(o.skin, .7)]]);
  B.push(`<path d="M -120 128 C -110 70, -70 52, -34 46 L 34 46 C 70 52, 110 70, 120 128 Z" fill="${o.collar}" stroke="${OUTL}" stroke-width="3"/>`);
  B.push(`<path d="M -40 46 L -26 10 L 26 10 L 40 46 L 26 70 L -26 70 Z" fill="${shade(o.collar, 1.25)}" stroke="${OUTL}" stroke-width="2.5"/>`);
  if (o.hair) B.push(`<path d="M -52 -40 C -70 10, -66 70, -40 110 L -20 40 L 20 40 L 40 110 C 66 70, 70 10, 52 -40 Z" fill="${o.hair}" stroke="${OUTL}" stroke-width="2"/>`);
  B.push(`<rect x="-14" y="10" width="28" height="40" fill="${skin}"/>`);
  // uzun kafatası, dar çene
  B.push(`<path d="M 0 -96 C 46 -96, 54 -40, 46 0 C 40 34, 18 50, 0 52 C -18 50, -40 34, -46 0 C -54 -40, -46 -96, 0 -96 Z" fill="${skin}" stroke="${OUTL}" stroke-width="3"/>`);
  if (o.crest) for (const x of [-14, 0, 14]) B.push(`<path d="M ${x} -94 C ${x * 1.3} -70, ${x * 1.2} -50, ${x} -34" stroke="${shade(o.skin, .6)}" stroke-width="5" fill="none" stroke-linecap="round"/>`);
  if (o.hair) B.push(`<path d="M -46 -50 C -40 -100, 40 -100, 46 -50 C 30 -70, -30 -70, -46 -50 Z" fill="${o.hair}" stroke="${OUTL}" stroke-width="2"/>`);
  // biyolüminesan işaretler
  for (const s of [1, -1]) for (let i = 0; i < 4; i++) B.push(circ(s * (36 - i * 2), -26 + i * 9, 2.3 - i * .3, o.marks, 'none', 0, 'opacity="0.95"'));
  // büyük badem gözler
  for (const s of [1, -1]) {
    if (o.fr === '_blink') { B.push(`<path d="M ${s * 6} -10 C ${s * 16} -6, ${s * 30} -6, ${s * 38} -10" stroke="${shade(o.skin, .4)}" stroke-width="2.5" fill="none"/>`); continue; }
    B.push(`<path d="M ${s * 6} -12 C ${s * 14} -26, ${s * 34} -24, ${s * 38} -10 C ${s * 32} -2, ${s * 14} -2, ${s * 6} -12 Z" fill="#0a0612" stroke="${OUTL}" stroke-width="1.5"/>`);
    B.push(ell(s * 23, -12, 6.5, 5.5, rad(defs, [[0, '#ffffff'], [.25, o.eye], [1, shade(o.eye, .2)]])));
    B.push(circ(s * 20, -15, 1.8, '#ffffff', 'none', 0, 'opacity="0.9"'));
  }
  B.push(`<path d="M -3 4 C -1 14, 1 14, 3 4" stroke="${shade(o.skin, .55)}" stroke-width="2" fill="none"/>`);
  B.push(o.fr === '_talk' ? ell(0, 30, 8, 5, '#1a0c22', `stroke="${shade(o.skin, .4)}" stroke-width="2"`) : `<path d="M -11 28 C -4 ${o.smile ? 33 : 26}, 4 ${o.smile ? 33 : 26}, 11 28" stroke="${shade(o.skin, .4)}" stroke-width="2.5" fill="none" stroke-linecap="round"/>`);
  if (o.scar) B.push(`<path d="M 26 -40 L 14 6" stroke="#5a1a2a" stroke-width="3" stroke-linecap="round"/>`);
}
for (const fr of ['', '_talk', '_blink']) { // Elçi Lyra
  const defs = [], B = [];
  B.push(portraitFrame(defs, '#c9a6ff'));
  alienFace(defs, B, { skin: '#c9c0dc', eye: '#b46cff', hair: '#e8e6f2', collar: lin(defs, [[0, '#f2eefa'], [1, '#9a90b5']]), marks: '#3cffd8', smile: true, fr });
  write('portrait_lyra' + fr, 256, 256, B.join(''), defs);
}
for (const fr of ['', '_talk', '_blink']) { // Savaş Lordu Varek
  const defs = [], B = [];
  B.push(portraitFrame(defs, '#ff3355'));
  alienFace(defs, B, { skin: '#8f9bb0', eye: '#ff3355', hair: null, crest: true, collar: lin(defs, [[0, '#3a3046'], [1, '#100c18']]), marks: '#ff4fd8', scar: true, fr });
  for (const s of [1, -1]) B.push(`<polygon points="${s * 60},60 ${s * 96},40 ${s * 80},74" fill="#5a4a6a" stroke="${OUTL}" stroke-width="2"/>`);
  write('portrait_varek' + fr, 256, 256, B.join(''), defs);
}

// ---------------- Ara sahne resimleri (1280x720) ----------------
const CW = 1280, CH = 720;
const rndStars = (n, B, w = CW, h = CH) => { for (let i = 0; i < n; i++) B.push(circ((Math.random() - .5) * w, (Math.random() - .5) * h, (Math.random() * 1.6 + .3).toFixed(1), '#ffffff', 'none', 0, `opacity="${(Math.random() * .8 + .2).toFixed(2)}"`)); };
const skyRect = (defs, s) => `<rect x="${-CW / 2}" y="${-CH / 2}" width="${CW}" height="${CH}" fill="${lin(defs, s)}"/>`;
const jet = (id, x, y, sc, rot) => { const r = planeSVG(id, PLANES[id]); return { defs: r.defs, g: `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${sc})">${r.body}</g>` }; };
function earth(defs, B, x, y, r) {
  B.push(circ(x, y, r * 1.06, rad(defs, [[.85, '#4fd8ff', .6], [1, '#4fd8ff', 0]])));
  B.push(circ(x, y, r, rad(defs, [[0, '#2a7ad8'], [.7, '#123a7a'], [1, '#061430']], .35, .35, .8)));
  for (let i = 0; i < 9; i++) { const a = Math.random() * 6.28, d = Math.random() * r * .7; B.push(ell(x + Math.cos(a) * d, y + Math.sin(a) * d, r * (.08 + Math.random() * .12), r * (.05 + Math.random() * .08), '#3a8a4a', `opacity="0.85" transform="rotate(${(Math.random() * 180) | 0} ${x + Math.cos(a) * d} ${y + Math.sin(a) * d})"`)); }
  for (let i = 0; i < 14; i++) { const a = Math.random() * 6.28, d = Math.random() * r * .85; B.push(ell(x + Math.cos(a) * d, y + Math.sin(a) * d, r * (.1 + Math.random() * .15), r * .03, '#ffffff', `opacity="0.6" transform="rotate(${(Math.random() * 60 - 30) | 0} ${x + Math.cos(a) * d} ${y + Math.sin(a) * d})"`)); }
  B.push(circ(x, y, r, rad(defs, [[.55, '#000', 0], [1, '#000', .75]], .3, .3, .9)));
}
function ark(defs, B, x, y, s, lit = true) {
  B.push(`<g transform="translate(${x} ${y}) scale(${s})">`);
  B.push(ell(0, 0, 300, 90, lin(defs, [[0, '#d8d2c0'], [.5, '#6a6458'], [1, '#1a1814']]), `stroke="${OUTL}" stroke-width="4"`));
  B.push(ell(0, -10, 220, 50, lin(defs, [[0, '#f2ecd8'], [1, '#8a8270']]), `stroke="${OUTL}" stroke-width="3"`));
  for (const r of [260, 180]) B.push(ell(0, 4, r, r * .28, 'none', `stroke="${OUTL}" stroke-width="2" opacity="0.4"`));
  if (lit) for (let i = 0; i < 160; i++) { const a = Math.random() * 6.28, d = Math.random(); B.push(circ((Math.cos(a) * 280 * d).toFixed(0), (Math.sin(a) * 75 * d).toFixed(0), 1.6, Math.random() < .7 ? '#ffd34f' : '#3cffd8', 'none', 0, 'opacity="0.85"')); }
  B.push(ell(0, 30, 40, 16, rad(defs, [[0, '#ffffff'], [.4, '#ffd34f'], [1, '#ffd34f', 0]])));
  B.push('</g>');
}
function city(B, y, col, seed = 1) {
  let x = -CW / 2; const lights = [];
  while (x < CW / 2) { const w = 30 + ((x * 7 + seed * 13) % 50 + 50) % 50, h = 60 + ((x * 13 + seed * 31) % 170 + 170) % 170; B.push(`<rect x="${x}" y="${y - h}" width="${w}" height="${h + 400}" fill="${col}"/>`); for (let i = 0; i < 6; i++) lights.push([x + 5 + Math.random() * (w - 10), y - h + 10 + Math.random() * (h - 10)]); x += w + 2; }
  for (const [lx, ly] of lights) B.push(`<rect x="${lx.toFixed(0)}" y="${ly.toFixed(0)}" width="3" height="4" fill="#ffd38a" opacity="0.7"/>`);
}
const save = (name, defs, B) => write(name, CW, CH, B.join(''), defs);

{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#000006'], [1, '#03081a']])); rndStars(260, B);
  B.push(circ(-480, -250, 120, rad(defs, [[0, '#ffffff'], [.1, '#fff6d8', .9], [1, '#ffd38a', 0]])));
  earth(defs, B, 280, 260, 420); save('cine_earth', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#000004'], [1, '#081028']])); rndStars(200, B);
  earth(defs, B, 0, 1050, 820); ark(defs, B, -60, -120, 1.25);
  B.push(ell(-60, 30, 380, 40, '#000', 'opacity="0.35"')); save('cine_ark', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#2a1840'], [.6, '#c86a4a'], [1, '#ffb070']]));
  B.push(`<polygon points="-640,-360 640,-360 640,-200 -640,-120" fill="#5a5048" opacity="0.9"/>`); // gemi gövdesi
  for (let i = 0; i < 20; i++) B.push(circ(-600 + i * 64, -170 + i * 2, 4, '#ffd34f', 'none', 0, 'opacity="0.8"'));
  B.push(`<polygon points="-90,-140 90,-140 260,360 -260,360" fill="${lin(defs, [[0, '#fff6d8', .7], [1, '#fff6d8', 0]])}"/>`);
  B.push(`<polygon points="-120,360 -60,120 60,120 120,360" fill="#3a3046"/>`); // rampa
  // elçi silueti: uzun, ince, ışıklı
  B.push(`<path d="M 0 -20 C 16 -20, 18 0, 12 14 L 22 120 L 8 126 L 4 200 L -4 200 L -8 126 L -22 120 L -12 14 C -18 0, -16 -20, 0 -20 Z" fill="#e8e2f2" stroke="#1a1426" stroke-width="2"/>`);
  B.push(ell(0, -2, 13, 18, '#c9c0dc', 'stroke="#1a1426" stroke-width="2"')); for (const s of [1, -1]) B.push(ell(s * 5, -4, 4, 2.5, '#2a1040'));
  B.push(`<path d="M 12 30 L 44 0" stroke="#e8e2f2" stroke-width="7" stroke-linecap="round"/>`);
  for (let i = 0; i < 40; i++) { const x = -640 + Math.random() * 1280; if (Math.abs(x) < 150) continue; const h = 50 + Math.random() * 40; B.push(`<path d="M ${x} 360 L ${x} ${360 - h} C ${x} ${345 - h}, ${x + 18} ${345 - h}, ${x + 18} ${360 - h} L ${x + 18} 360 Z" fill="#1a1020"/>`); B.push(circ(x + 9, 352 - h - 12, 10, '#1a1020')); }
  save('cine_envoy', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#08040e'], [.7, '#3a0a1a'], [1, '#ff5a3c']])); rndStars(60, B, CW, 300);
  ark(defs, B, 0, -250, .9, true);
  for (const x of [-420, -120, 200, 470]) { B.push(`<polygon points="${x - 6},-200 ${x + 6},-200 ${x + 40},260 ${x - 40},260" fill="${lin(defs, [[0, '#ff4fd8', .9], [1, '#ff3355', .3]])}"/>`); B.push(circ(x, 250, 70, rad(defs, [[0, '#ffe0a0'], [.4, '#ff7a3c', .8], [1, '#ff3355', 0]]))); }
  city(B, 300, '#120810', 2); save('cine_betrayal', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#0a2a5a'], [.6, '#ff9a5a'], [1, '#ffd38a']]));
  B.push(circ(0, 300, 160, rad(defs, [[0, '#ffffff'], [.3, '#fff0c0'], [1, '#ffb070', 0]])));
  for (const [id, x, y, s] of [['serce', 0, 20, 2.2], ['dogan', -230, 140, 1.7], ['simsek', 230, 140, 1.7], ['kartal', -420, 260, 1.4], ['anka', 420, 260, 1.4]]) {
    B.push(`<polygon points="${x - 3},${y + 40 * s / 2} ${x + 3},${y + 40 * s / 2} ${x + 14},400 ${x - 14},400" fill="#ffffff" opacity="0.35"/>`);
    const j = jet(id, x, y, s, 0); defs.push(...j.defs); B.push(j.g);
  }
  save('cine_squadron', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#0a1018'], [1, '#1a2430']]));
  for (let i = 0; i < 7; i++) B.push(`<rect x="${-640 + i * 200}" y="-360" width="60" height="720" fill="#ffffff" opacity="0.04"/>`);
  B.push(`<rect x="-640" y="250" width="1280" height="110" fill="#14181e"/>`);
  const j = jet('serce', 330, 40, 5.2, -30); defs.push(...j.defs); B.push(j.g);
  B.push(`<g transform="translate(-330 40) scale(2.3)">`); const pd = [], pb = []; // pilot portresi (büyük)
  pb.push(`<path d="M -120 128 C -110 60, -70 50, -30 44 L 30 44 C 70 50, 110 60, 120 128 Z" fill="${lin(pd, [[0, '#5a6a50'], [1, '#2a3224']])}" stroke="${OUTL}" stroke-width="3"/>`);
  pb.push(circ(0, -14, 70, lin(pd, [[0, '#e6ebf2'], [1, '#7a8494']]), OUTL, 3));
  pb.push(`<path d="M -54 -20 C -30 -36, 30 -36, 54 -20 C 52 18, 30 34, 0 36 C -30 34, -52 18, -54 -20 Z" fill="${lin(pd, [[0, '#ffd34f'], [.5, '#ff8a3c'], [1, '#3a1a0a']])}" stroke="${OUTL}" stroke-width="3"/>`);
  pb.push(`<path d="M -40 -18 C -20 -26, 0 -26, 10 -24" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity="0.75"/>`);
  pb.push(`<path d="M -24 36 L 24 36 L 18 60 L -18 60 Z" fill="#3a404c" stroke="${OUTL}" stroke-width="2.5"/>`);
  defs.push(...pd); B.push(...pb, '</g>');
  save('cine_pilot', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#0a1a12'], [.55, '#3a6a6a'], [1, '#0a3a4a']]));
  B.push(`<rect x="-640" y="160" width="1280" height="200" fill="${lin(defs, [[0, '#1a5a6a'], [1, '#062030']])}"/>`);
  B.push(`<polygon points="-110,-120 110,-120 220,200 -220,200" fill="${lin(defs, [[0, '#57ff9a', .55], [1, '#57ff9a', .1]])}"/>`);
  B.push(`<path d="M -150 200 C -80 60, 80 60, 150 200 Z" fill="#7ad0c0" opacity="0.6"/>`);
  for (let i = 0; i < 30; i++) B.push(circ(-120 + Math.random() * 240, -100 + Math.random() * 280, 2 + Math.random() * 3, '#bfffe0', 'none', 0, 'opacity="0.7"'));
  B.push(ell(0, -170, 300, 70, lin(defs, [[0, '#f0ecf8'], [1, '#6a6480']]), `stroke="${OUTL}" stroke-width="3"`));
  B.push(ell(0, -140, 110, 26, rad(defs, [[0, '#ffffff'], [.4, '#57ff9a'], [1, '#0a3a20']])));
  for (let i = 0; i < 8; i++) B.push(circ(-250 + i * 71, -175, 6, '#57ff9a'));
  save('cine_harvest', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#2a1a3a'], [.6, '#ff8a5a'], [1, '#ffcf8a']]));
  B.push(`<rect x="-640" y="120" width="1280" height="240" fill="${lin(defs, [[0, '#ff9a6a'], [.2, '#1a3a5a'], [1, '#061a2a']])}"/>`);
  B.push(`<path d="M -500 -300 C -300 -200, -150 -50, -40 80" stroke="#2a2030" stroke-width="60" fill="none" opacity="0.55" stroke-linecap="round"/>`);
  B.push(`<path d="M -500 -300 C -300 -200, -150 -50, -40 80" stroke="#ff9a3c" stroke-width="16" fill="none" opacity="0.6" stroke-linecap="round"/>`);
  B.push(circ(-40, 80, 140, rad(defs, [[0, '#ffffff'], [.2, '#ffe0a0'], [.5, '#ff7a3c', .8], [1, '#ff3355', 0]])));
  B.push(`<g transform="translate(-40 80) rotate(35) scale(.7)"><path d="M 0 -60 C 40 -60, 70 0, 60 40 L -60 40 C -70 0, -40 -60, 0 -60 Z" fill="#cfc8e0" stroke="${OUTL}" stroke-width="4"/></g>`);
  const j = jet('serce', 380, -160, 2.6, 60); defs.push(...j.defs); B.push(j.g);
  save('cine_boss_down', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#000004'], [1, '#06102a']])); rndStars(220, B);
  earth(defs, B, 0, 1200, 980); ark(defs, B, 0, -250, .7);
  B.push(`<polygon points="-3,260 3,260 18,420 -18,420" fill="#4fd8ff" opacity="0.5"/>`);
  const j = jet('anka', 0, 200, 2.4, 0); defs.push(...j.defs); B.push(j.g);
  save('cine_space', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#000004'], [1, '#0a0a20']])); rndStars(220, B);
  earth(defs, B, -200, 900, 760);
  B.push(circ(-640, 260, 220, rad(defs, [[0, '#ffffff'], [.15, '#fff0c0'], [1, '#ffb070', 0]])));
  for (let i = 0; i < 6; i++) { const x = 140 + (i % 3) * 150 - 150, y = -170 + Math.floor(i / 3) * 120 - 40; B.push(`<g transform="translate(${x} ${y}) rotate(${i * 37}) scale(.42)">`); ark(defs, B, 0, 0, .5, i % 2 == 0); B.push('</g>'); }
  B.push(circ(150, -150, 230, rad(defs, [[0, '#ffffff', .9], [.3, '#ffd34f', .6], [1, '#ff7a3c', 0]])));
  save('cine_victory', defs, B); }

// ================= v0.4: yeni bosslar, ara sahneler, sefer haritası =================
{ // MATKAP: önde dönen matkap ucu, paletli gövde
  const defs = [], b = alienBase(defs, '#e8dcc8'), B = [];
  for (const s of [1, -1]) B.push(`<rect x="${s > 0 ? 40 : -64}" y="-40" width="24" height="110" rx="8" fill="${b.dark}" stroke="${AOUT}" stroke-width="2"/>`);
  for (let i = 0; i < 9; i++) for (const s of [1, -1]) B.push(`<rect x="${s > 0 ? 42 : -62}" y="${-36 + i * 12}" width="20" height="5" fill="#5a4a6a"/>`);
  B.push(`<path d="M -42 -30 C -42 -60, 42 -60, 42 -30 L 46 60 C 30 80, -30 80, -46 60 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="3"/>`);
  B.push(`<polygon points="0,-118 30,-50 -30,-50" fill="${lin(defs, [[0, '#ffffff'], [1, '#8a7a6a']], 0, 0, 1, 0)}" stroke="${AOUT}" stroke-width="2.5"/>`);
  for (let i = 0; i < 4; i++) B.push(line([-26 + i * 4, -54 - i * 14], [24 - i * 6, -60 - i * 14], AOUT, 2));
  B.push(circ(0, 10, 18, b.core('#ff9a3c'), AOUT, 2)); for (const x of [-22, 22]) B.push(circ(x, 52, 7, b.core('#ffb03c')));
  write('b_matkap', 160, 250, B.join(''), defs);
}
{ // GÖZCÜ KULE: dev göz, etrafında taret halkası
  const defs = [], b = alienBase(defs), B = [];
  for (let i = 0; i < 6; i++) B.push(`<g transform="rotate(${i * 60})"><rect x="-12" y="-128" width="24" height="44" rx="6" fill="${b.side}" stroke="${AOUT}" stroke-width="2"/>${circ(0, -126, 6, '#3cffd8')}</g>`);
  B.push(circ(0, 0, 96, b.hull, AOUT, 3)); B.push(circ(0, 0, 74, b.dark));
  B.push(`<path d="M -66 0 C -30 -44, 30 -44, 66 0 C 30 44, -30 44, -66 0 Z" fill="#f2fffc" stroke="${AOUT}" stroke-width="3"/>`);
  B.push(circ(0, 0, 30, rad(defs, [[0, '#ffffff'], [.25, '#3cffd8'], [.8, '#0a6a5a'], [1, '#02201a']])));
  B.push(ell(0, 0, 9, 26, '#03130f')); B.push(circ(-10, -12, 6, '#ffffff', 'none', 0, 'opacity="0.8"'));
  write('b_goz', 280, 280, B.join(''), defs);
}
{ // BUZ KIRICI: kristal kanatlı sivri gemi
  const defs = [], B = [];
  const ice = lin(defs, [[0, '#ffffff'], [.5, '#bfe8ff'], [1, '#4a8ab0']]);
  for (const s of [1, -1]) for (let i = 0; i < 3; i++) B.push(poly([[s * 20, -20 + i * 30], [s * (100 - i * 18), -40 + i * 38], [s * (60 - i * 8), 10 + i * 30]], ice, AOUT, 2));
  B.push(poly([[0, -110], [28, -30], [22, 70], [0, 90], [-22, 70], [-28, -30]], lin(defs, [[0, '#e8f6ff'], [1, '#6a9ac0']], 0, 0, 1, 0), AOUT, 3));
  for (let i = 0; i < 5; i++) B.push(line([0, -90 + i * 32], [0, -70 + i * 32], '#a8e8ff', 3));
  B.push(circ(0, 0, 16, rad(defs, [[0, '#ffffff'], [.4, '#a8e8ff'], [1, '#2a5a80']]), AOUT, 2));
  write('b_buz', 220, 220, B.join(''), defs);
}
{ // İKİZ AVCILAR: bağlı iki av gemisi
  const defs = [], b = alienBase(defs, '#efe0f0'), B = [];
  B.push(`<rect x="-60" y="-6" width="120" height="12" rx="6" fill="${b.dark}" stroke="${AOUT}" stroke-width="2"/>`);
  B.push(circ(0, 0, 14, b.core('#ff4fd8'), AOUT, 2));
  for (const s of [1, -1]) {
    B.push(`<g transform="translate(${s * 70} 0)">`);
    B.push(`<path d="M 0 -70 C 18 -40, 50 -10, 52 30 C 30 18, 14 20, 8 40 L -8 40 C -14 20, -30 18, -52 30 C -50 -10, -18 -40, 0 -70 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="2.5"/>`);
    B.push(`<path d="M 0 -60 C 14 -30, 40 -6, 46 22" fill="none" stroke="#ff4fd8" stroke-width="2.5"/>`);
    B.push(ell(0, -26, 6, 14, b.core('#ff4fd8'))); B.push(circ(0, 38, 6, b.core('#b46cff')));
    B.push('</g>');
  }
  write('b_ikiz', 280, 160, B.join(''), defs);
}
{ // KUM YILANI: halka halka gövde (üstten)
  const defs = [], b = alienBase(defs, '#e8d8b0'), B = [];
  for (let i = 6; i >= 1; i--) { const y = i * 26, r = 34 - i * 3; B.push(circ(0, y, r, b.hull, AOUT, 2)); B.push(circ(0, y, r * .45, b.core('#ffd34f'))); }
  B.push(`<path d="M 0 -70 C 46 -66, 52 -10, 40 14 C 20 30, -20 30, -40 14 C -52 -10, -46 -66, 0 -70 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="3"/>`);
  for (const s of [1, -1]) { B.push(poly([[s * 20, -60], [s * 38, -96], [s * 30, -54]], '#5a4a30', AOUT, 2)); B.push(ell(s * 18, -30, 8, 5, b.core('#ff7a3c'))); }
  B.push(`<path d="M -20 -10 L 20 -10" stroke="${AOUT}" stroke-width="3"/>`);
  write('b_kum', 160, 300, B.join(''), defs);
}
{ // DÖKÜMHANE: lavla dolu pota, dört baca
  const defs = [], b = alienBase(defs, '#d8c8c0'), B = [];
  for (let i = 0; i < 4; i++) B.push(`<g transform="rotate(${i * 90 + 45})"><rect x="-20" y="-150" width="40" height="70" rx="6" fill="${b.dark}" stroke="${AOUT}" stroke-width="2"/>${circ(0, -146, 14, rad(defs, [[0, '#fff0b0'], [.5, '#ff7a3c'], [1, '#400800']]))}</g>`);
  B.push(circ(0, 0, 110, b.hull, AOUT, 3)); B.push(circ(0, 0, 86, '#2a1a14', AOUT, 2));
  B.push(circ(0, 0, 70, rad(defs, [[0, '#fff6c0'], [.35, '#ffb03c'], [.75, '#ff5a1c'], [1, '#601000']])));
  for (let i = 0; i < 7; i++) { const a = i * .9; B.push(`<path d="M ${Math.cos(a) * 20} ${Math.sin(a) * 20} Q ${Math.cos(a + .5) * 50} ${Math.sin(a + .5) * 50} ${Math.cos(a + .2) * 66} ${Math.sin(a + .2) * 66}" stroke="#2a0a04" stroke-width="3" fill="none" opacity="0.6"/>`); }
  write('b_ates', 320, 320, B.join(''), defs);
}
{ // ATMOSFER EMİCİ: dev huni, dönen kepçeler
  const defs = [], b = alienBase(defs, '#e0e8f4'), B = [];
  for (let i = 0; i < 8; i++) B.push(`<path d="M 0 -60 C 40 -90, 90 -110, 130 -80 C 100 -70, 60 -60, 30 -40 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="2" transform="rotate(${i * 45})"/>`);
  B.push(circ(0, 0, 80, b.side, AOUT, 3));
  for (let r = 64; r > 10; r -= 12) B.push(circ(0, 0, r, r % 24 ? '#0a1430' : '#162a50', 'none'));
  B.push(circ(0, 0, 16, rad(defs, [[0, '#ffffff'], [.4, '#8fd0ff'], [1, '#0a1430']])));
  write('b_emici', 300, 300, B.join(''), defs);
}
{ // ÇÖPÇÜ: hurdadan yapılmış, uydu panelleri ve kollar
  const defs = [], b = alienBase(defs, '#c8c4d8'), B = [];
  for (const [x, y, w, h, r] of [[-130, -30, 70, 30, -15], [60, -40, 80, 26, 12], [-100, 40, 60, 24, 20], [50, 50, 70, 22, -18]]) {
    B.push(`<g transform="rotate(${r} ${x + w / 2} ${y + h / 2})"><rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#1a2a5a" stroke="${AOUT}" stroke-width="2"/>${[1, 2, 3].map(i => `<line x1="${x + i * w / 4}" y1="${y}" x2="${x + i * w / 4}" y2="${y + h}" stroke="#4a6aaa" stroke-width="1.5"/>`).join('')}</g>`);
  }
  B.push(`<path d="M -70 -50 L 20 -70 L 80 -20 L 60 60 L -20 74 L -80 20 Z" fill="${b.hull}" stroke="${AOUT}" stroke-width="3"/>`);
  for (const [x, y] of [[-30, -30], [30, 10], [-10, 40], [40, -40]]) B.push(`<rect x="${x - 12}" y="${y - 8}" width="24" height="16" rx="3" fill="${b.dark}" stroke="${AOUT}" stroke-width="1.5"/>`);
  for (const s of [1, -1]) B.push(`<path d="M ${s * 50} 40 L ${s * 110} 110 L ${s * 96} 120" stroke="#8a86a0" stroke-width="7" fill="none" stroke-linecap="round"/>`);
  B.push(circ(0, 0, 20, b.core('#c8c4d8'), AOUT, 2)); B.push(circ(0, 0, 8, '#ff3355'));
  write('b_enkaz', 300, 280, B.join(''), defs);
}
{ // VAREK'İN TAHTI: taç biçimli amiral gemisi
  const defs = [], b = alienBase(defs, '#2a2034'), B = [];
  const gold = lin(defs, [[0, '#fff0b0'], [.5, '#d8a030'], [1, '#6a4010']]);
  for (const s of [1, -1]) {
    B.push(`<path d="M ${s * 20} -40 C ${s * 80} -90, ${s * 140} -60, ${s * 150} 10 C ${s * 120} -10, ${s * 90} 0, ${s * 60} 40 L ${s * 24} 60 Z" fill="${lin(defs, [[0, '#5a4a6a'], [1, '#1a1426']])}" stroke="#d8a030" stroke-width="2.5"/>`);
    for (let i = 0; i < 4; i++) B.push(poly([[s * (40 + i * 26), -50 - i * 6], [s * (50 + i * 26), -96 - i * 4], [s * (58 + i * 26), -46 - i * 6]], gold, AOUT, 1.5));
    B.push(ell(s * 90, 10, 10, 6, b.core('#ff3355')));
  }
  B.push(`<path d="M 0 -110 C 30 -80, 36 -20, 30 60 C 20 90, -20 90, -30 60 C -36 -20, -30 -80, 0 -110 Z" fill="${lin(defs, [[0, '#4a3a5a'], [.5, '#8a7a9a'], [1, '#4a3a5a']], 0, 0, 1, 0)}" stroke="#d8a030" stroke-width="3"/>`);
  for (let i = 0; i < 5; i++) B.push(poly([[-24 + i * 12, -78], [-18 + i * 12, -112 + (i === 2 ? -14 : 0)], [-12 + i * 12, -78]], gold, AOUT, 1.2));
  B.push(circ(0, -20, 18, b.core('#ff3355'), '#d8a030', 3)); B.push(circ(0, 40, 9, b.core('#b46cff')));
  write('b_varek', 320, 240, B.join(''), defs);
}

// ---- yeni ara sahne resimleri ----
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#1a2a3a'], [.6, '#5a6a6a'], [1, '#8a8a70']]));
  B.push(`<polygon points="-640,40 -400,-160 -200,-40 0,-220 260,-60 460,-180 640,-20 640,360 -640,360" fill="#2a3428"/>`);
  B.push(`<rect x="-640" y="120" width="1280" height="240" fill="#3a4430"/><rect x="-640" y="200" width="1280" height="60" fill="#26282c"/>`);
  for (let i = 0; i < 12; i++) B.push(`<rect x="${-620 + i * 110}" y="226" width="50" height="6" fill="#d8d8d8" opacity="0.8"/>`);
  for (const x of [-480, -140, 220]) { B.push(`<path d="M ${x} 180 L ${x} 120 Q ${x + 90} 70 ${x + 180} 120 L ${x + 180} 180 Z" fill="#4a4e54" stroke="${OUTL}" stroke-width="3"/>`); B.push(`<rect x="${x + 50}" y="140" width="80" height="40" fill="#14161a"/>`); }
  const j = jet('dogan', 470, 140, 1.8, -20); defs.push(...j.defs); B.push(j.g);
  for (let i = 0; i < 4; i++) B.push(`<polygon points="${-300 + i * 200},-300 ${-290 + i * 200},-300 ${-200 + i * 200},200 ${-240 + i * 200},200" fill="#ffffff" opacity="0.05"/>`);
  save('cine_base', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#2a4a7a'], [.7, '#a8c0d8'], [1, '#e0e8f0']]));
  for (const [x, h, c] of [[-500, 300, '#4a5a6a'], [-150, 420, '#3a4858'], [250, 360, '#465464'], [560, 280, '#52606e']]) { B.push(`<polygon points="${x - 320},360 ${x},${360 - h - 200} ${x + 320},360" fill="${c}"/>`); B.push(`<polygon points="${x - 80},${360 - h - 100} ${x},${360 - h - 200} ${x + 80},${360 - h - 100} ${x + 30},${360 - h - 120} ${x - 20},${360 - h - 95}" fill="#f2f6fa"/>`); }
  B.push(`<rect x="-640" y="250" width="1280" height="110" fill="#1e3a22"/>`);
  for (let i = 0; i < 40; i++) { const x = -640 + i * 33; B.push(`<polygon points="${x},300 ${x + 14},230 ${x + 28},300" fill="#16301a"/>`); }
  B.push(`<rect x="60" y="-60" width="10" height="120" fill="#c8ccd2"/>`); B.push(ell(65, -70, 50, 20, '#e8ecf0', `stroke="${OUTL}" stroke-width="3"`));
  save('cine_mountain', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#0a1a2e'], [.5, '#3a6a8a'], [1, '#cfe8f8']])); rndStars(60, B, CW, 260);
  B.push(`<path d="M -640 -60 C -300 -140, 100 -20, 640 -100" stroke="#57ff9a" stroke-width="40" fill="none" opacity="0.25"/><path d="M -640 0 C -200 -80, 200 40, 640 -40" stroke="#b46cff" stroke-width="30" fill="none" opacity="0.2"/>`);
  B.push(`<rect x="-640" y="120" width="1280" height="240" fill="#e8f4fc"/>`);
  for (let i = 0; i < 10; i++) B.push(`<polygon points="${-620 + i * 130},120 ${-560 + i * 130},${60 - (i % 3) * 20} ${-500 + i * 130},120" fill="#cfe4f2" stroke="#9ac0dc" stroke-width="2"/>`);
  B.push(`<path d="M -200 250 L 200 250 L 160 200 L -160 200 Z" fill="#3a2f52" stroke="#b46cff" stroke-width="3"/>`); for (let i = 0; i < 6; i++) B.push(circ(-130 + i * 52, 225, 6, '#b46cff'));
  save('cine_ice', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#f0b060'], [.5, '#ffd890'], [1, '#e8b870']]));
  B.push(circ(300, -200, 90, rad(defs, [[0, '#ffffff'], [.4, '#fff4c0'], [1, '#ffd890', 0]])));
  for (let i = 0; i < 5; i++) B.push(`<path d="M -640 ${40 + i * 70} C -300 ${-10 + i * 70}, 200 ${90 + i * 70}, 640 ${30 + i * 70} L 640 360 L -640 360 Z" fill="${['#e0a860', '#d49850', '#c88844', '#bc7a3a', '#b06e32'][i]}"/>`);
  for (let i = 0; i < 7; i++) { const x = -420 + i * 110, y = 120 + Math.sin(i) * 30; B.push(circ(x, y, 34 - i * 2, '#d8c8a0', OUTL, 2)); B.push(circ(x, y, 12, '#ffd34f')); }
  B.push(`<rect x="320" y="60" width="160" height="80" fill="#8a7a64" stroke="${OUTL}" stroke-width="3"/><rect x="340" y="80" width="40" height="40" fill="#2a2420"/><text x="400" y="54" font-family="Arial" font-weight="900" font-size="18" fill="#5a4a30">TEST-7</text>`);
  save('cine_desert', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#1a0a08'], [.6, '#5a1a0a'], [1, '#ff5a1c']]));
  B.push(`<polygon points="-500,360 -260,-120 -160,-110 60,360" fill="#2a1a16"/><polygon points="-260,-120 -210,-60 -160,-110" fill="#ff7a3c"/>`);
  B.push(`<path d="M -210 -60 C -230 60, -180 200, -240 360" stroke="#ff7a3c" stroke-width="18" fill="none"/>`);
  B.push(`<polygon points="100,360 330,-40 420,-30 640,360" fill="#22140f"/>`);
  for (let i = 0; i < 30; i++) B.push(circ(-260 + Math.random() * 120, -140 - Math.random() * 200, 3 + Math.random() * 6, '#ffb03c', 'none', 0, 'opacity="0.7"'));
  B.push(`<rect x="160" y="80" width="300" height="140" rx="20" fill="#d8c8c0" stroke="${OUTL}" stroke-width="4"/>`); for (let i = 0; i < 4; i++) B.push(`<rect x="${180 + i * 70}" y="40" width="30" height="60" fill="#2a1a14" stroke="${OUTL}" stroke-width="2"/>`);
  B.push(circ(310, 150, 40, rad(defs, [[0, '#fff6c0'], [.5, '#ff7a3c'], [1, '#601000']])));
  save('cine_forge', defs, B); }
{ const defs = [], B = []; B.push(skyRect(defs, [[0, '#1a1018'], [.6, '#4a2a2a'], [1, '#8a4a30']]));
  for (const x of [-500, -20, 420]) B.push(`<path d="M ${x} 360 C ${x - 40} 100, ${x + 60} -100, ${x + 10} -300" stroke="#2a2024" stroke-width="80" fill="none" opacity="0.6"/>`);
  let x = -640; while (x < 640) { const w = 50 + Math.random() * 80, h = 80 + Math.random() * 220; const cut = Math.random() * 60; B.push(`<polygon points="${x},360 ${x},${360 - h} ${x + w * .4},${360 - h + cut} ${x + w},${360 - h + 20} ${x + w},360" fill="#1a1416"/>`); x += w + 4; }
  B.push(`<path d="M -60 300 C -60 240, 60 240, 60 300 Z" fill="#2a2024"/><rect x="-6" y="140" width="12" height="110" fill="#2a2024"/>`); // yıkık anıt
  for (let i = 0; i < 8; i++) B.push(circ(-560 + i * 160, 300 - Math.random() * 60, 30 + Math.random() * 30, rad(defs, [[0, '#ffe0a0'], [.4, '#ff7a3c', .7], [1, '#ff3355', 0]])));
  B.push(`<g transform="translate(0 -170) scale(.9)"><path d="M 0 -50 C 22 -40, 26 -10, 22 30 L -22 30 C -26 -10, -22 -40, 0 -50 Z" fill="#4a3a5a" stroke="#d8a030" stroke-width="3"/><circle cx="0" cy="-10" r="9" fill="#ff3355"/></g>`);
  save('cine_ruins', defs, B); }

// ---- sefer haritası (1280x3000; 1. bölüm altta, 15. bölüm üstte) ----
{ const defs = [], B = [], W = 1280, Hh = 3000, band = 200;
  const yb = k => Hh / 2 - k * band; // bandın üst kenarı (merkez koordinat)
  const BAND = [ // [renk üst, renk alt]
    ['#0e4a62', '#0a3550'], ['#3a5a2a', '#2a4420'], ['#c88a54', '#a8683a'], ['#3a6a3a', '#2a4a2a'], ['#2a6a7a', '#3a6a4a'],
    ['#dfe8f2', '#b8c8d8'], ['#c8d6ea', '#8aa0c0'], ['#3a4258', '#5a6a88'], ['#e8f2fa', '#1a2a3a'], ['#e8c070', '#c89850'],
    ['#2a1410', '#4a1a0e'], ['#1a2a5a', '#5a7ab0'], ['#06081a', '#141a3a'], ['#8a8270', '#5a5448'], ['#2a1a1e', '#4a2a24']];
  for (let k = 0; k < 15; k++) B.push(`<rect x="${-W / 2}" y="${yb(k + 1)}" width="${W}" height="${band + 2}" fill="${lin(defs, [[0, BAND[k][0]], [1, BAND[k][1]]])}"/>`);
  const R = (a, b) => a + Math.random() * (b - a);
  const inB = k => [yb(k + 1), yb(k)];
  { const [t, b] = inB(0); for (let i = 0; i < 9; i++) B.push(ell(R(-600, 600), R(t + 30, b - 30), R(30, 80), R(15, 35), '#3a7a3a', 'stroke="#d8c58a" stroke-width="5"')); }
  { const [t, b] = inB(1); for (let i = 0; i < 3; i++) B.push(`<rect x="${-560 + i * 420}" y="${t + 90}" width="320" height="26" fill="#26282c"/>`); for (let i = 0; i < 6; i++) B.push(`<rect x="${R(-600, 560)}" y="${R(t + 20, b - 60)}" width="50" height="30" fill="#4a4e54"/>`); }
  { const [t, b] = inB(2); for (let i = 0; i < 26; i++) { const x = R(-610, 610), y = R(t + 30, b - 20); B.push(`<path d="M ${x - 12} ${y + 20} Q ${x} ${y - 40} ${x + 12} ${y + 20} Z" fill="#e8d0b0" stroke="#8a5a3a" stroke-width="2"/>`); } }
  for (const k of [3, 5]) { const [t, b] = inB(k); for (let i = 0; i < 12; i++) { const x = R(-620, 620), y = R(t + 50, b); B.push(`<polygon points="${x - 50},${y} ${x},${y - 80} ${x + 50},${y}" fill="${k === 5 ? '#9aa8b8' : '#4a5a4a'}"/><polygon points="${x - 18},${y - 52} ${x},${y - 80} ${x + 18},${y - 52}" fill="#f2f6fa"/>`); } }
  { const [t, b] = inB(4); B.push(ell(0, (t + b) / 2, 360, 70, '#1a5a7a', 'stroke="#c8b888" stroke-width="6"')); }
  { const [t, b] = inB(6); for (let i = 0; i < 14; i++) B.push(ell(R(-620, 620), R(t + 20, b - 20), R(60, 120), R(20, 40), '#ffffff', 'opacity="0.7"')); }
  { const [t, b] = inB(7); for (let i = 0; i < 10; i++) B.push(ell(R(-620, 620), R(t + 20, b - 20), R(60, 130), R(20, 40), '#2a3044', 'opacity="0.8"')); B.push(`<polyline points="-200,${t + 20} -170,${t + 80} -210,${t + 100} -160,${t + 170}" stroke="#e8f0ff" stroke-width="4" fill="none"/>`); }
  { const [t, b] = inB(8); for (let i = 0; i < 14; i++) { const x = R(-600, 600), y = R(t + 30, b - 30); B.push(`<polygon points="${x - 50},${y} ${x - 20},${y - 30} ${x + 40},${y - 20} ${x + 55},${y + 15} ${x},${y + 30}" fill="#f2f8fc" stroke="#9ac0dc" stroke-width="2"/>`); } }
  { const [t, b] = inB(9); for (let i = 0; i < 6; i++) B.push(`<path d="M -640 ${t + 30 + i * 30} C -200 ${t + i * 30}, 200 ${t + 60 + i * 30}, 640 ${t + 20 + i * 30}" stroke="#a87a40" stroke-width="3" fill="none" opacity="0.6"/>`); }
  { const [t, b] = inB(10); for (const x of [-300, 200]) { B.push(`<polygon points="${x - 110},${b} ${x},${t + 30} ${x + 110},${b}" fill="#1a0e0a"/>`); B.push(`<path d="M ${x} ${t + 30} C ${x + 20} ${t + 90}, ${x - 30} ${t + 140}, ${x + 10} ${b}" stroke="#ff7a3c" stroke-width="8" fill="none"/>`); } }
  { const [t, b] = inB(11); for (let i = 0; i < 10; i++) B.push(ell(R(-620, 620), R(t + 120, b), R(80, 140), R(10, 20), '#a8c0e0', 'opacity="0.35"')); }
  for (const k of [12, 13]) { const [t, b] = inB(k); for (let i = 0; i < 70; i++) B.push(circ(R(-630, 630), R(t, b), R(.6, 1.8), '#ffffff', 'none', 0, `opacity="${R(.3, 1).toFixed(2)}"`)); }
  { const [t, b] = inB(12); for (let i = 0; i < 16; i++) B.push(`<rect x="${R(-600, 600)}" y="${R(t + 10, b - 20)}" width="${R(10, 30)}" height="${R(4, 12)}" fill="#6a6a78" transform="rotate(${R(0, 180)})"/>`); }
  { const [t, b] = inB(13); B.push(ell(0, (t + b) / 2 + 30, 560, 110, '#c8c0a8', `stroke="${OUTL}" stroke-width="4" opacity="0.9"`)); for (let i = 0; i < 60; i++) B.push(circ(R(-500, 500), R(t + 80, b - 10), 2, '#ffd34f')); }
  { const [t, b] = inB(14); for (let i = 0; i < 40; i++) { const x = R(-620, 600), w = R(20, 50), h = R(30, 90); B.push(`<rect x="${x}" y="${b - h - R(0, 60)}" width="${w}" height="${h}" fill="#1a1214"/>`); } for (let i = 0; i < 6; i++) B.push(circ(R(-600, 600), R(t + 60, b - 20), R(14, 26), rad(defs, [[0, '#ffd090'], [.5, '#ff6a2c', .7], [1, '#ff3355', 0]]))); }
  // bant geçişlerini yumuşat
  for (let k = 1; k < 15; k++) B.push(`<rect x="${-W / 2}" y="${yb(k) - 30}" width="${W}" height="60" fill="${lin(defs, [[0, BAND[k][1], 0], [.5, BAND[k][1], .5], [1, BAND[k - 1][0], 0]])}"/>`);
  write('map_campaign', W, Hh, B.join(''), defs);
}

// Proje ikonu
{ const r = planeSVG('serce', PLANES.serce), defs = r.defs;
  write('icon', 128, 128, `<rect x="-64" y="-64" width="128" height="128" rx="24" fill="${lin(defs, [[0, '#0a3550'], [1, '#02030a']])}"/><g transform="scale(0.9)">${r.body}</g>`, defs); }

console.log('art: ' + fs.readdirSync(OUT).filter(f => f.endsWith('.svg')).length + ' svg');

// ================= v0.5: KİMLİK — Selçuklu yıldızlı logo, desenli arayüz çerçeveleri =================
const AMBER = '#ffb547', TEAL = '#38d9c8';
const star8 = (cx, cy, r, rot = 0) => { const p = []; for (let i = 0; i < 16; i++) { const a = rot + i * Math.PI / 8, rr = i % 2 ? r * 0.55 : r; p.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]); } return p; };
const sq = (cx, cy, r, rot) => [0, 1, 2, 3].map(i => [cx + Math.cos(rot + i * Math.PI / 2) * r, cy + Math.sin(rot + i * Math.PI / 2) * r]);
{ // LOGO: iç içe iki kareden Selçuklu yıldızı + kanatlar
  const defs = [], B = [];
  const gA = lin(defs, [[0, '#fff0c8'], [.5, AMBER], [1, '#a8600a']]), gT = lin(defs, [[0, '#d8fff8'], [.5, TEAL], [1, '#0a5a54']]);
  for (const s of [1, -1]) for (let i = 0; i < 5; i++) {
    const y = -18 + i * 13, x0 = s * 46, len = 120 - i * 18;
    B.push(`<polygon points="${x0},${y} ${x0 + s * len},${y - 14 + i * 2} ${x0 + s * (len - 14)},${y + 8} ${x0},${y + 9}" fill="${i % 2 ? gT : gA}" stroke="#1a1006" stroke-width="2"/>`);
  }
  B.push(poly(sq(0, 0, 58, Math.PI / 4), gA, '#1a1006', 3)); B.push(poly(sq(0, 0, 58, 0), gA, '#1a1006', 3));
  B.push(poly(sq(0, 0, 44, Math.PI / 4), '#0a1420', TEAL, 2.5)); B.push(poly(sq(0, 0, 44, 0), '#0a1420', TEAL, 2.5));
  B.push(poly(star8(0, 0, 30, Math.PI / 8), gT, '#06302c', 2));
  B.push(poly([[0, -22], [6, 4], [0, 0], [-6, 4]], '#ffffff')); // içte stilize uçak
  B.push(poly([[0, -6], [18, 8], [0, 4], [-18, 8]], '#ffffff', 'none', 0, 'opacity="0.9"'));
  write('logo', 340, 150, B.join(''), defs);
}
{ // Arayüz çerçevesi (9-parça, köşe payı 28): çift çizgi + köşelerde 8 köşeli yıldız
  const defs = [], B = [], S = 96, h = S / 2;
  B.push(`<rect x="${-h + 4}" y="${-h + 4}" width="${S - 8}" height="${S - 8}" fill="#050a14" fill-opacity="0.9" stroke="${TEAL}" stroke-width="2"/>`);
  B.push(`<rect x="${-h + 9}" y="${-h + 9}" width="${S - 18}" height="${S - 18}" fill="none" stroke="${AMBER}" stroke-opacity="0.45" stroke-width="1"/>`);
  for (const [x, y] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
    B.push(poly(star8(x * (h - 12), y * (h - 12), 10, Math.PI / 8), AMBER, '#2a1606', 1));
    B.push(circ(x * (h - 12), y * (h - 12), 3, '#050a14'));
  }
  write('ui_frame', S, S, B.join(''), defs);
}
for (const [name, fill, edge, glow] of [['ui_btn', '#071220', '#2f6a78', 0], ['ui_btn_hi', '#0d2a36', TEAL, 1], ['ui_btn_on', '#2a1c06', AMBER, 1]]) {
  const defs = [], B = [], W = 96, H = 48; // köşeleri kırık (pahlı) düğme
  const p = [[-W / 2 + 10, -H / 2 + 2], [W / 2 - 2, -H / 2 + 2], [W / 2 - 2, H / 2 - 10], [W / 2 - 10, H / 2 - 2], [-W / 2 + 2, H / 2 - 2], [-W / 2 + 2, -H / 2 + 10]];
  B.push(poly(p, lin(defs, [[0, shade(fill, 1.4)], [1, fill]]), edge, 2));
  if (glow) B.push(poly(star8(-W / 2 + 14, 0, 6, Math.PI / 8), edge));
  B.push(line([-W / 2 + 12, H / 2 - 6], [W / 2 - 14, H / 2 - 6], edge, 1, 'opacity="0.35"'));
  write(name, W, H, B.join(''), defs);
}
{ // Girih deseni (döşenebilir): 8 köşeli yıldız ızgarası
  const defs = [], B = [], S = 160;
  for (const [x, y] of [[0, 0], [-80, -80], [80, -80], [-80, 80], [80, 80]]) {
    B.push(poly(star8(x, y, 34, Math.PI / 8), 'none', '#ffffff', 1.5));
    B.push(poly(sq(x, y, 52, Math.PI / 4), 'none', '#ffffff', 1));
  }
  for (const [a, b] of [[[-80, 0], [80, 0]], [[0, -80], [0, 80]]]) B.push(line(a, b, '#ffffff', 0.8, 'opacity="0.6"'));
  write('girih', S, S, B.join(''), defs);
}
console.log('kimlik görselleri tamam');
{ // Vahar enerji çekirdeği (toplanan parça): altıgen çerçeve içinde parlayan kristal — oyunda renklendirilir
  const defs = [], B = [];
  const hex = r => [0, 1, 2, 3, 4, 5].map(i => [Math.cos(Math.PI / 6 + i * Math.PI / 3) * r, Math.sin(Math.PI / 6 + i * Math.PI / 3) * r]);
  B.push(circ(0, 0, 15, rad(defs, [[0, '#ffffff', .5], [1, '#ffffff', 0]])));
  B.push(poly(hex(11), lin(defs, [[0, '#d8d8d8'], [1, '#6a6a6a']]), '#202020', 1.5));
  B.push(poly(hex(7.5), '#2a2a2a'));
  B.push(poly([[0, -6], [4.5, 0], [0, 6], [-4.5, 0]], rad(defs, [[0, '#ffffff'], [.6, '#e0e0e0'], [1, '#9a9a9a']])));
  for (let i = 0; i < 6; i++) { const a = Math.PI / 6 + i * Math.PI / 3; B.push(circ(Math.cos(a) * 11, Math.sin(a) * 11, 1.4, '#ffffff')); }
  write('core', 32, 32, B.join(''), defs);
}
