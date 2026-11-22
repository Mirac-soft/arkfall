'use strict';
// ============================================================
//  GÖKKALKAN — oyun çekirdeği
// ============================================================
const cv = document.getElementById('game'), ctx = cv.getContext('2d');
let S = 1;
function resize() {
  const k = Math.min(innerWidth / W, innerHeight / H), dpr = window.devicePixelRatio || 1;
  cv.style.width = W * k + 'px'; cv.style.height = H * k + 'px';
  cv.width = Math.round(W * k * dpr); cv.height = Math.round(H * k * dpr); S = cv.width / W;
}
addEventListener('resize', resize); resize();

const rand = (a, b) => b === undefined ? Math.random() * a : a + Math.random() * (b - a);
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const ease = t => t <= 0 ? 0 : t >= 1 ? 1 : t * t * (3 - 2 * t);
const pick = a => a[Math.floor(Math.random() * a.length)];
const d2 = (a, b) => (a.x - b.x) ** 2 + (a.y - b.y) ** 2;
const angDiff = (a, b) => { let d = a - b; while (d > Math.PI) d -= TAU; while (d < -Math.PI) d += TAU; return d; };
const fmt = n => String(Math.floor(n)).padStart(10, '0');

// ---------- Girdi (klavye + gamepad) ----------
const keys = {};
addEventListener('keydown', e => {
  keys[e.code] = true; AU.unlock();
  if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(e.code)) e.preventDefault();
});
addEventListener('keyup', e => { keys[e.code] = false; });
addEventListener('mousedown', () => AU.unlock());
addEventListener('blur', () => { for (const k in keys) keys[k] = false; if (scene === 'game' && G && G.phase === 'play' && !G.dialog) G.paused = true; });

const MAP = {
  up: ['ArrowUp', 'KeyW'], down: ['ArrowDown', 'KeyS'], left: ['ArrowLeft', 'KeyA'], right: ['ArrowRight', 'KeyD'],
  ok: ['Enter', 'KeyZ', 'Space'], back: ['Escape', 'KeyX', 'Backspace'], pause: ['Escape', 'KeyP'],
  fire: ['KeyZ', 'Space', 'KeyJ'], focus: ['ShiftLeft', 'ShiftRight', 'KeyK'], bomb: ['KeyX', 'KeyL'], full: ['KeyF'],
};
const GPMAP = { up: [12], down: [13], left: [14], right: [15], ok: [0], back: [1], pause: [9], fire: [0, 7], focus: [5, 6], bomb: [1, 2], full: [] };
let held = {}, prevHeld = {};
const mv = { x: 0, y: 0 };
function pollInput() {
  prevHeld = held; held = {};
  const gp = navigator.getGamepads ? Array.from(navigator.getGamepads()).find(Boolean) : null;
  for (const k in MAP) held[k] = MAP[k].some(c => keys[c]) || (!!gp && GPMAP[k].some(i => gp.buttons[i] && gp.buttons[i].pressed));
  let mx = (held.right ? 1 : 0) - (held.left ? 1 : 0), my = (held.down ? 1 : 0) - (held.up ? 1 : 0);
  if (gp) {
    const ax = gp.axes[0] || 0, ay = gp.axes[1] || 0;
    if (ax < -.5) held.left = true; if (ax > .5) held.right = true; if (ay < -.5) held.up = true; if (ay > .5) held.down = true;
    if (Math.hypot(ax, ay) > .2) { mx = ax; my = ay; }
  }
  const l = Math.hypot(mx, my); if (l > 1) { mx /= l; my /= l; }
  mv.x = mx; mv.y = my;
}
const hit = k => held[k] && !prevHeld[k];

// ---------- Kayıt ----------
const SAVE_KEY = 'gokkalkan_save_v1';
const save = { xp: 0, plane: 'serce', records: [], seenIntro: false, sound: true };
try {
  const s = JSON.parse(localStorage.getItem(SAVE_KEY));
  if (s && typeof s === 'object') {
    if (Number.isFinite(s.xp) && s.xp >= 0) save.xp = s.xp;
    if (typeof s.plane === 'string') save.plane = s.plane;
    if (Array.isArray(s.records)) save.records = s.records.filter(r => r && Number.isFinite(r.score)).slice(0, 10);
    save.seenIntro = !!s.seenIntro; save.sound = s.sound !== false;
  }
} catch (e) { /* bozuk kayıt: varsayılanlarla devam */ }
function persist() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { } }
const level = () => LEVEL.info(save.xp).level;
const unlocked = p => level() >= p.unlock;
AU.setOn(save.sound);

// ---------- Sahne durumu ----------
let scene = 'menu', menuI = 0, hangarI = 0, pauseI = 0, overI = 0, T = 0, G = null, errMsg = '';
const isElectron = navigator.userAgent.includes('Electron');
function menuItems() {
  const a = ['OYNA', 'HANGAR', 'REKORLAR', 'KONTROLLER', 'SES: ' + (save.sound ? 'AÇIK' : 'KAPALI'), 'TAM EKRAN'];
  if (isElectron) a.push('ÇIKIŞ');
  return a;
}
function goMenu() { scene = 'menu'; G = null; BG.set('orbit'); AU.music('menu'); }
function toggleFull() {
  try { if (document.fullscreenElement) document.exitFullscreen(); else document.documentElement.requestFullscreen(); } catch (e) { }
}

// ---------- Koşu (bir uçuş) ----------
function startRun(stage = 0) {
  const plane = PLANES.find(p => p.id === save.plane && unlocked(p)) || PLANES[0];
  G = {
    plane, stage, loop: 0, score: 0, graze: 0, runXP: 0, levelStart: level(),
    enemies: [], eb: [], pb: [], items: [], parts: [], banners: [], radioQ: [], radio: null, dialog: null, pending: [],
    boss: null, bossWarn: 0, bossDown: 0, bossSpawned: false, stageT: 0, waveI: 0,
    phase: 'brief', to: 0, toDist: 0, shake: 0, flash: 0, bombT: 0, autoT: 0, overT: 0, paused: false,
    P: { x: FW / 2, y: FH - 150, lives: plane.hp, bombs: plane.bombs, power: 0, inv: 0, cd: 0, mcd: 0, bank: 0, focus: false, dead: false, enter: 0 },
  };
  setDifficulty();
  scene = 'game'; BG.set(STAGES[stage].theme); AU.music('menu');
  const lines = save.seenIntro ? STORY.introShort : STORY.intro;
  save.seenIntro = true; persist();
  openDialog(lines, beginTakeoff);
}
function setDifficulty() { const l = G.loop; G.fr = 1 + .15 * l; G.bs = 1 + .1 * l; G.hp = 1 + .3 * l; G.xm = 1 + .5 * l; }
function beginTakeoff() { G.phase = 'takeoff'; G.to = 0; AU.music(STAGES[G.stage].theme); AU.sfx('engine'); radio('cmd', STORY.takeoff); }

function banner(text, sub, color, dur = 2.6) { G.banners.push({ text, sub, color, t: 0, dur }); }
function radio(who, text) { G.radioQ.push({ who, text }); }
function stageBanner() { const st = STAGES[G.stage]; banner('BÖLÜM ' + (G.stage + 1), st.name + '  —  ' + st.sub, '#4fd8ff', 3.2); }

function openDialog(lines, done) { G.dialog = { lines, i: 0, ch: 0, done }; }
function updDialog(dt) {
  const d = G.dialog, line = d.lines[d.i];
  const prev = Math.floor(d.ch); d.ch += dt * 48;
  if (Math.floor(d.ch) > prev && d.ch < line.t.length && Math.floor(d.ch) % 2 === 0) AU.sfx('blip');
  const finish = () => { G.dialog = null; if (d.done) d.done(); };
  if (hit('pause')) return finish();
  if (hit('ok')) {
    if (d.ch < line.t.length) d.ch = line.t.length;
    else { d.i++; d.ch = 0; AU.sfx('select'); if (d.i >= d.lines.length) finish(); }
  }
}

// ---------- XP / seviye ----------
function addXP(n) {
  n = Math.round(n); const before = level();
  save.xp += n; G.runXP += n;
  const after = level();
  for (let L = before + 1; L <= after; L++) {
    banner('SEVİYE ' + L, 'RÜTBE: ' + rankOf(L), '#ffe14f', 2.4); AU.sfx('levelup');
    const pl = PLANES.find(p => p.unlock === L);
    if (pl) { banner('YENİ UÇAK: ' + pl.name, 'Hangarda kullanılabilir', pl.color, 3); radio('cmd', STORY.unlock[pl.id]); }
  }
  if (after > before) persist();
}

// ---------- Parçacıklar ----------
function part(x, y, vx, vy, life, size, color, kind = 'spark') {
  if (G.parts.length < 1800) G.parts.push({ x, y, vx, vy, life, max: life, size, color, kind });
}
function explode(x, y, color, sc = 1) {
  for (let i = 0; i < 12 * sc; i++) { const a = rand(TAU), s = rand(60, 320) * Math.sqrt(sc); part(x, y, Math.cos(a) * s, Math.sin(a) * s, rand(.3, .7), rand(2, 4), color); }
  for (let i = 0; i < 4 * sc; i++) { const a = rand(TAU), s = rand(10, 60); part(x, y, Math.cos(a) * s, Math.sin(a) * s, rand(.6, 1.1), rand(8, 16) * Math.sqrt(sc), '#000', 'smoke'); }
  part(x, y, 0, 0, .45, 14 * sc, color, 'ring');
  part(x, y, 0, 0, .18, 40 * sc, color, 'flash');
  AU.sfx('boom');
}
function updParts(dt) {
  for (const p of G.parts) { p.life -= dt; p.x += p.vx * dt; p.y += p.vy * dt; if (p.kind === 'spark') { p.vx *= .96; p.vy *= .96; } }
  G.parts = G.parts.filter(p => p.life > 0);
}

// ---------- Mermi desenleri ----------
const aim = (x, y) => Math.atan2(G.P.y - y, G.P.x - x);
function eShot(x, y, a, sp, o = {}) {
  if (G.eb.length > 2500) return;
  sp *= G.bs;
  G.eb.push({ x, y, a, sp, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, r: o.r || 5, c: o.c || '#ff4f6a', k: o.k || 'orb',
    acc: o.acc || 0, max: (o.max || 600) * G.bs, av: o.av || 0, split: o.split || null, life: 0, gr: false, dead: false });
}
function ring(x, y, n, sp, off, o) { for (let i = 0; i < n; i++) eShot(x, y, off + i * TAU / n, sp, o); }
function fan(x, y, n, spread, sp, a, o) { for (let i = 0; i < n; i++) eShot(x, y, a + (n > 1 ? (i / (n - 1) - .5) * spread : 0), sp, o); }
// tekrarlayan zamanlayıcı; tur zorluğu atış hızını artırır
function ev(o, k, int, dt) {
  o.tm[k] = (o.tm[k] ?? int * .5) - dt;
  if (o.tm[k] <= 0) { o.tm[k] += int / G.fr; return true; }
  return false;
}
function clearBullets(toScore) {
  let n = 0;
  for (const b of G.eb) {
    if (b.dead) continue; b.dead = true;
    if (toScore && n++ < 120) dropItem(b.x, b.y, 's');
    if (Math.random() < .3) part(b.x, b.y, 0, 0, .25, 8, b.c, 'ring');
  }
}

// ---------- Eşyalar ----------
function dropItem(x, y, k) { G.items.push({ x, y, k, vx: rand(-50, 50), vy: k === 's' ? rand(-30, 0) : rand(-200, -120), t: 0, dead: false }); }
function dropN(x, y, k, v) { const n = Math.floor(v) + (Math.random() < v % 1 ? 1 : 0); for (let i = 0; i < n; i++) dropItem(x + rand(-10, 10), y + rand(-10, 10), k); }
function collect(it) {
  const P = G.P;
  switch (it.k) {
    case 'P': {
      const before = Math.floor(P.power);
      if (P.power >= 4) G.score += 1000; else P.power = Math.min(4, P.power + .08);
      if (Math.floor(P.power) > before) { AU.sfx('power'); banner(P.power >= 4 ? 'GÜÇ MAKSİMUM!' : 'GÜÇ SEVİYESİ ' + Math.floor(P.power), '', G.plane.color, 1.4); }
      else AU.sfx('item');
      break;
    }
    case 'S': G.score += Math.round((500 + 1500 * (1 - P.y / FH)) * G.xm); AU.sfx('item'); break;
    case 's': G.score += 100; AU.sfx('item'); break;
    case 'B': P.bombs = Math.min(8, P.bombs + 1); AU.sfx('power'); banner('+1 BOMBA', '', '#57ff9a', 1.4); break;
    case 'L': P.lives = Math.min(8, P.lives + 1); AU.sfx('levelup'); banner('+1 CAN', '', '#ff4fd8', 1.6); break;
  }
}
function updItems(dt) {
  const P = G.P; G.autoT = Math.max(0, G.autoT - dt);
  for (const it of G.items) {
    it.t += dt;
    const dx = P.x - it.x, dy = P.y - it.y, d = Math.hypot(dx, dy) || 1;
    const magnet = !P.dead && P.enter <= 0 && it.t > .25 && (it.k === 's' || G.autoT > 0 || P.y < FH * .3 || d < (P.focus ? 90 : 55));
    if (magnet) { it.x += dx / d * 650 * dt; it.y += dy / d * 650 * dt; }
    else { it.vy = Math.min(it.vy + 320 * dt, 130); it.vx *= .97; it.x += it.vx * dt; it.y += it.vy * dt; }
    if (!P.dead && d < 22) { collect(it); it.dead = true; } else if (it.y > FH + 20) it.dead = true;
  }
  G.items = G.items.filter(i => !i.dead);
}

// ---------- Oyuncu ----------
function playerFire() {
  const P = G.P, w = G.plane.w, p = Math.floor(P.power), f = P.focus;
  const n = w.base + p * w.per, spread = f ? w.fspread : w.spread, width = w.width * (f ? .55 : 1);
  for (let i = 0; i < n; i++) {
    const u = n === 1 ? 0 : i / (n - 1) - .5, a = -Math.PI / 2 + u * spread;
    G.pb.push({ x: P.x + u * width, y: P.y - 14, vx: Math.cos(a) * w.speed, vy: Math.sin(a) * w.speed, a, dmg: w.dmg,
      r: w.kind === 'needle' ? 4 : 5, k: w.kind, pierce: !!w.pierce, hit: w.pierce ? new Set() : null, life: 0, dead: false });
  }
  if (p >= w.mFrom && P.mcd <= 0) {
    P.mcd = w.mRate;
    for (let i = 0; i < w.mN; i++) {
      const s = i % 2 ? 1 : -1, a = -Math.PI / 2 + s * (.6 + .3 * Math.floor(i / 2));
      G.pb.push({ x: P.x + s * 14, y: P.y, a, sp: 200, vx: 0, vy: 0, dmg: 2.5 * w.dmg, r: 6, k: 'missile', hit: null, life: 0, dead: false });
    }
  }
  AU.sfx('shoot');
}
function useBomb() {
  const P = G.P; P.bombs--; G.bombT = 2; G.bombX = P.x; G.bombY = P.y;
  P.inv = Math.max(P.inv, 3); clearBullets(true); G.autoT = 1.5; G.flash = .8; G.shake = 12; AU.sfx('bomb');
}
function playerHit() {
  const P = G.P; if (P.inv > 0 || P.dead || P.enter > 0) return;
  explode(P.x, P.y, G.plane.color, 2.2); AU.sfx('death'); G.shake = 14; G.flash = .5;
  clearBullets(false);
  P.lives--;
  const drop = Math.min(4, Math.ceil(P.power * 2)); P.power = Math.max(0, P.power - 1);
  for (let i = 0; i < drop; i++) dropItem(P.x, P.y - 20, 'P');
  if (P.lives <= 0) { P.dead = true; G.overT = 2.2; return; }
  P.bombs = Math.max(P.bombs, G.plane.bombs); P.inv = 3.2; P.enter = 1; P.x = FW / 2; P.y = FH + 40;
  radio('cmd', pick(STORY.hit));
}
function updPlayer(dt) {
  const P = G.P; if (P.dead) return;
  P.inv = Math.max(0, P.inv - dt); P.cd = Math.max(P.cd - dt, -.02); P.mcd -= dt;
  P.focus = held.focus;
  if (P.enter > 0) { P.enter = Math.max(0, P.enter - dt); P.y = lerp(FH - 110, FH + 40, ease(P.enter)); }
  else {
    const sp = G.plane.speed * (P.focus ? .42 : 1);
    P.x = clamp(P.x + mv.x * sp * dt, 12, FW - 12); P.y = clamp(P.y + mv.y * sp * dt, 20, FH - 20);
  }
  P.bank = lerp(P.bank, mv.x, Math.min(1, dt * 10));
  if (held.fire && P.cd <= 0 && P.enter <= 0) { P.cd += G.plane.w.rate; playerFire(); } // += : ateş hızı kare süresine yuvarlanmasın
  if (hit('bomb') && P.bombs > 0 && G.bombT <= 0) useBomb();
  if (Math.random() < .7) part(P.x + rand(-3, 3), P.y + 22, rand(-15, 15), rand(120, 220), .18, rand(2, 3.5), G.plane.color);
  if (G.plane.id === 'anka' && Math.random() < .6) part(P.x + rand(-22, 22), P.y + 10, rand(-30, 30), rand(60, 140), .45, rand(2, 4), '#ff9a3c');
}

// ---------- Oyuncu mermileri ----------
function nearestTarget(x, y) {
  let best = null, bd = 1e12;
  for (const e of G.enemies) { if (e.dead || e.y < 0) continue; const d = (e.x - x) ** 2 + (e.y - y) ** 2; if (d < bd) { bd = d; best = e; } }
  const B = G.boss; if (B && B.entered && !B.dying) { const d = (B.x - x) ** 2 + (B.y - y) ** 2; if (d < bd) best = B; }
  return best;
}
function updPB(dt) {
  for (const b of G.pb) {
    b.life += dt;
    if (b.k === 'missile') {
      const tg = nearestTarget(b.x, b.y);
      if (tg) b.a += clamp(angDiff(Math.atan2(tg.y - b.y, tg.x - b.x), b.a), -7 * dt, 7 * dt);
      b.sp = Math.min(b.sp + 900 * dt, 750); b.vx = Math.cos(b.a) * b.sp; b.vy = Math.sin(b.a) * b.sp;
      if (Math.random() < .5) part(b.x, b.y, rand(-20, 20), rand(20, 60), .3, 2.5, '#ffb070');
    }
    b.x += b.vx * dt; b.y += b.vy * dt;
    if (b.y < -30 || b.x < -30 || b.x > FW + 30 || b.y > FH + 30 || b.life > 3) { b.dead = true; continue; }
    for (const e of G.enemies) {
      if (e.dead || e.y < -10 || (b.hit && b.hit.has(e))) continue;
      if (d2(b, e) < (e.r + b.r) ** 2) {
        damageEnemy(e, b.dmg); part(b.x, b.y, rand(-60, 60), rand(-120, -40), .15, 2, '#fff');
        if (b.pierce) b.hit.add(e); else { b.dead = true; break; }
      }
    }
    const B = G.boss;
    if (!b.dead && B && B.entered && !B.dying && !(b.hit && b.hit.has(B)) && d2(b, B) < (B.r + b.r) ** 2) {
      damageBoss(b.dmg); part(b.x, b.y, rand(-60, 60), rand(-120, -40), .15, 2, B.inv > 0 ? '#888' : '#fff');
      if (b.pierce) b.hit.add(B); else b.dead = true;
    }
  }
  G.pb = G.pb.filter(b => !b.dead);
}

// ---------- Düşmanlar ----------
function spawnEnemy(type, x, y, extra) {
  const d = ENEMIES[type];
  const e = Object.assign({ type, d, x, y, hp: d.hp * G.hp, r: d.r, t: 0, m: 'down', vx: 0, vy: 150, tm: {}, flash: 0,
    rot: Math.PI, ang: rand(TAU), stay: 99, dead: false }, extra);
  e.max = e.hp; if (e.m === 'sine') e.x0 = e.x;
  G.enemies.push(e); return e;
}
function spawnFromWave(p) {
  const w = p.w; let x = ((w.x ?? .5) + p.i * (w.dx || 0)) * FW, y = -30;
  const ex = { m: w.m || 'down', vy: w.vy || 150 };
  if (w.m === 'stop' || w.m === 'dive') { ex.ty = (w.ty || .2) * FH; ex.stay = w.stay || 4; }
  if (w.m === 'sine') { ex.amp = w.amp || 100; ex.f = w.f || 2; }
  if (w.m === 'swoopL' || w.m === 'swoopR') { const L = w.m === 'swoopL'; x = L ? -30 : FW + 30; y = (w.y || .1) * FH; ex.vx = L ? 280 : -280; ex.vy = 30; }
  spawnEnemy(w.e, x, y, ex);
}
function damageEnemy(e, dmg) {
  e.hp -= dmg; e.flash = .05; AU.sfx('hit');
  if (e.hp <= 0 && !e.dead) { e.dead = true; killEnemy(e); }
}
function killEnemy(e) {
  explode(e.x, e.y, e.d.color, e.r / 16);
  G.score += Math.round(e.d.score * G.xm); addXP(e.d.xp * G.xm);
  const dr = e.d.drops; dropN(e.x, e.y, 'P', dr.P || 0); dropN(e.x, e.y, 'S', dr.S || 0);
  if (dr.B && Math.random() < dr.B) dropItem(e.x, e.y, 'B');
  if (e.type === 'kamikaze') ring(e.x, e.y, 8, 110, rand(TAU), { c: '#ffe14f', r: 5 });
  if (e.type === 'bomber') G.shake = 8;
}
function enemyFire(e, dt) {
  if (e.y < 0 || e.y > FH * .75) return;
  const active = e.t < e.stay;
  switch (e.type) {
    case 'drone':
      if (e.t > .6 && ev(e, 'f', 1.8, dt) && Math.random() < .7) eShot(e.x, e.y, aim(e.x, e.y), 190, { c: '#ff4f6a', r: 5 });
      break;
    case 'fighter':
      if (active && e.t > .8 && ev(e, 'f', 1.25, dt)) fan(e.x, e.y + 8, 3, .32, 230, aim(e.x, e.y), { c: '#ff9a3c', k: 'rice', r: 5 });
      break;
    case 'spinner':
      if (active && e.t > 1 && ev(e, 'f', .09, dt)) {
        e.ang += .37;
        for (let k = 0; k < (G.loop > 0 ? 2 : 1); k++) eShot(e.x, e.y, e.ang + k * Math.PI, 150, { c: '#b46cff', r: 5 });
      }
      break;
    case 'sniper':
      if (!active || e.t < 1) break;
      if (e.aimT > 0) { if (e.aimT > .3) e.aimA = aim(e.x, e.y); e.aimT -= dt; if (e.aimT <= 0) { e.burst = 5; e.bt = 0; } }
      else if (e.burst > 0) { e.bt -= dt; if (e.bt <= 0) { e.bt = .06; e.burst--; eShot(e.x, e.y, e.aimA, 520, { c: '#57ff9a', k: 'rice', r: 5 }); } }
      else if (ev(e, 'f', 2.2, dt)) { e.aimT = .8; e.aimA = aim(e.x, e.y); AU.sfx('lock'); }
      break;
    case 'bomber':
      if (ev(e, 'r', 1.5, dt)) ring(e.x, e.y, 18, 140, rand(TAU), { c: '#6aa8ff', r: 7 });
      if (ev(e, 'g', .55, dt)) for (const s of [-1, 1]) eShot(e.x + s * 30, e.y + 6, aim(e.x + s * 30, e.y), 220, { c: '#9fd0ff', k: 'rice', r: 4 });
      break;
  }
}
function updEnemies(dt) {
  const P = G.P;
  for (const e of G.enemies) {
    if (e.dead) continue;
    e.t += dt; e.flash -= dt;
    switch (e.m) {
      case 'down': e.x += e.vx * dt; e.y += e.vy * dt; break;
      case 'sine': e.y += e.vy * dt; e.x = e.x0 + Math.sin(e.t * e.f) * e.amp; break;
      case 'stop':
        if (e.t < e.stay) e.y += (e.ty - e.y) * Math.min(1, dt * 2.5);
        else { if (!e.leaving) { e.leaving = true; e.vy = -20; } e.vy -= 260 * dt; e.y += e.vy * dt; }
        break;
      case 'swoopL': case 'swoopR':
        e.vy += 140 * dt; e.x += e.vx * dt; e.y += e.vy * dt; e.rot = Math.atan2(e.vy, e.vx) + Math.PI / 2; break;
      case 'dive':
        if (!e.go) {
          e.y += (e.ty - e.y) * Math.min(1, dt * 3); e.rot = aim(e.x, e.y) + Math.PI / 2;
          if (e.t > .9) { e.go = true; const a = aim(e.x, e.y); e.vx = Math.cos(a) * 520 * G.bs; e.vy = Math.sin(a) * 520 * G.bs; e.rot = a + Math.PI / 2; AU.sfx('dash'); }
        } else { e.x += e.vx * dt; e.y += e.vy * dt; }
        break;
    }
    enemyFire(e, dt);
    if (!P.dead && P.inv <= 0 && P.enter <= 0 && d2(e, P) < (e.r * .6 + 3) ** 2) playerHit();
    if (G.bombT > 0 && e.y > 0) damageEnemy(e, 45 * dt);
    if (e.t > 1.5 && (e.y > FH + 60 || e.y < -80 || e.x < -80 || e.x > FW + 80)) e.dead = true;
  }
  G.enemies = G.enemies.filter(e => !e.dead);
}

// ---------- Bosslar ----------
const BOSS_AI = {
  ironwing(B, dt) {
    const p = B.ph;
    B.x = lerp(B.x, p === 1 ? FW / 2 : FW / 2 + Math.sin(B.pt * .6) * 150, Math.min(1, dt * 2));
    if (p === 0) {
      if (ev(B, 'fan', 1, dt)) fan(B.x, B.y + 20, 7, .9, 210, aim(B.x, B.y), { c: '#ff9a3c', k: 'rice', r: 6 });
      if (ev(B, 'w', .2, dt)) for (const s of [-1, 1]) eShot(B.x + s * 46, B.y + 12, Math.PI / 2 + s * .25 * Math.sin(B.pt * 2.2), 260, { c: '#ff4f6a', r: 5 });
    } else if (p === 1) {
      if (ev(B, 'sp', .055, dt)) { B.ang += .21; for (let k = 0; k < 2; k++) eShot(B.x, B.y, B.ang + k * Math.PI, 170, { c: '#ffb03c', r: 5 }); }
      if (ev(B, 'ring', 1.5, dt)) ring(B.x, B.y, 20, 140, aim(B.x, B.y), { c: '#ff3355', r: 9 });
    } else {
      if (ev(B, 'r', .5, dt)) { B.flip *= -1; ring(B.x, B.y, 22, 150, rand(TAU), { c: '#ff6ad5', k: 'rice', r: 5, av: .45 * B.flip }); }
      if (ev(B, 'a', .9, dt)) fan(B.x, B.y, 5, .3, 300, aim(B.x, B.y), { c: '#fff27a', r: 4 });
    }
  },
  tempest(B, dt) {
    const p = B.ph;
    B.x = lerp(B.x, FW / 2 + Math.sin(B.pt * .4) * (p === 1 ? 60 : 120), Math.min(1, dt * 2));
    if (p === 0) {
      if (ev(B, 'rain', .06, dt)) eShot(rand(-120, FW), -8, Math.PI / 2 - .22, rand(140, 220), { c: '#8fc8ff', r: 4, k: 'rice' });
      if (ev(B, 'c', 1.1, dt)) fan(B.x, B.y + 20, 3, .22, 250, aim(B.x, B.y), { c: '#e8f4ff', r: 9 });
    } else if (p === 1) {
      if (ev(B, 's', .075, dt)) { const base = Math.PI / 2 + Math.sin(B.pt * 1.3); for (let k = -1; k <= 1; k++) eShot(B.x, B.y + 20, base + k * .65, 280, { c: '#4fd8ff', k: 'rice', r: 5 }); }
      if (ev(B, 'b', 2, dt)) ring(B.x, B.y, 14, 120, rand(TAU), { c: '#6aa8ff', r: 8 });
    } else {
      if (ev(B, 'f', .33, dt)) { B.flip *= -1; ring(B.x, B.y, 16, 130, B.pt, { c: '#b46cff', r: 6, av: .7 * B.flip }); }
      if (ev(B, 'sum', 4, dt)) for (const s of [-1, 1]) spawnEnemy('drone', B.x + s * 60, B.y, { vy: 150, vx: s * 60 });
    }
  },
  sentinel(B, dt) {
    const p = B.ph;
    B.x = lerp(B.x, FW / 2 + Math.sin(B.pt * .5) * 110, Math.min(1, dt * 2));
    B.y = lerp(B.y, 150 + Math.sin(B.pt * .8) * 20, Math.min(1, dt * 2));
    if (p === 0) {
      if (ev(B, 'wall', 1.15, dt)) { const gap = rand(70, FW - 70); for (let x = 8; x < FW; x += 22) if (Math.abs(x - gap) > 48) eShot(x, -6, Math.PI / 2, 115, { c: '#ff5a7a', r: 5 }); }
      if (ev(B, 'a', .8, dt)) eShot(B.x, B.y, aim(B.x, B.y), 230, { c: '#ffd0d8', r: 9 });
    } else if (p === 1) {
      if (ev(B, 'q', .045, dt)) { B.ang += .13; for (let k = 0; k < 4; k++) eShot(B.x, B.y, B.ang + k * Math.PI / 2, 50, { c: '#ff8a3c', r: 5, acc: 140, max: 260 }); }
    } else if (p === 2) {
      if (ev(B, 'o', 1.25, dt)) ring(B.x, B.y, 7, 150, rand(TAU), { c: '#ff3355', r: 11, split: { at: 1.1, n: 10, sp: 120, c: '#ffb0c0' } });
      if (ev(B, 'a', .55, dt)) fan(B.x, B.y, 3, .25, 260, aim(B.x, B.y), { c: '#ffffff', r: 4 });
    } else {
      if (ev(B, 's', .05, dt)) {
        B.ang += .29; B.ang2 -= .23;
        eShot(B.x, B.y, B.ang, 180, { c: '#ff3355', r: 5 }); eShot(B.x, B.y, B.ang + Math.PI, 180, { c: '#ff3355', r: 5 });
        eShot(B.x, B.y, B.ang2, 150, { c: '#ffd34f', k: 'rice', r: 5 });
      }
      if (ev(B, 'r', 1.4, dt)) ring(B.x, B.y, 28, 110, rand(TAU), { c: '#b46cff', r: 6 });
    }
  },
};
function spawnBoss(id) {
  const d = BOSSES[id];
  G.boss = { id, d, x: FW / 2, y: -90, r: d.r, t: 0, pt: 0, ph: 0, hp: d.phases[0] * G.hp, max: d.phases[0] * G.hp,
    tm: {}, ang: 0, ang2: 0, flip: 1, inv: 0, entered: false, dying: 0, flash: 0 };
}
function damageBoss(dmg) {
  const B = G.boss; if (!B || B.inv > 0 || !B.entered || B.dying) return;
  B.hp -= dmg; B.flash = .04; AU.sfx('hit'); G.score += Math.round(dmg * 10);
  if (B.hp > 0) return;
  if (B.ph < B.d.phases.length - 1) {
    B.ph++; B.max = B.hp = B.d.phases[B.ph] * G.hp; B.tm = {}; B.pt = 0; B.inv = 1.5;
    clearBullets(true); G.autoT = 1; G.flash = .4; explode(B.x, B.y, B.d.color, 2.5); AU.sfx('phase');
  } else {
    B.dying = 2.4; clearBullets(true);
    G.score += Math.round(B.d.score * G.xm); addXP(B.d.xp * G.xm);
    for (let i = 0; i < 12; i++) { dropItem(B.x + rand(-50, 50), B.y + rand(-30, 30), 'P'); dropItem(B.x + rand(-50, 50), B.y + rand(-30, 30), 'S'); }
    dropItem(B.x, B.y, 'B'); if (Math.random() < .5 || G.P.lives < 2) dropItem(B.x, B.y, 'L');
  }
}
function updBoss(dt) {
  const B = G.boss; if (!B) return;
  B.t += dt; B.flash -= dt; B.inv = Math.max(0, B.inv - dt);
  if (B.dying > 0) {
    B.dying -= dt; G.shake = Math.max(G.shake, 6);
    if (Math.random() < .35) explode(B.x + rand(-B.r, B.r), B.y + rand(-B.r, B.r), B.d.color, 1.2);
    if (B.dying <= 0) {
      explode(B.x, B.y, '#ffffff', 5); explode(B.x, B.y, B.d.color, 4);
      G.shake = 20; G.flash = 1; AU.sfx('bigboom'); G.boss = null; G.autoT = 3;
      const bonus = 10000 * (G.stage + 1) * (G.loop + 1); G.score += bonus;
      banner('BÖLÜM TAMAMLANDI', '+' + bonus + ' BONUS', '#57ff9a', 3);
      G.bossDown = 3;
    }
    return;
  }
  if (!B.entered) { B.y += (150 - B.y) * Math.min(1, dt * 1.5); if (B.y > 140) { B.entered = true; B.pt = 0; } return; }
  B.pt += dt;
  BOSS_AI[B.id](B, dt);
  if (G.bombT > 0) damageBoss(30 * dt);
  const P = G.P;
  if (!P.dead && P.inv <= 0 && P.enter <= 0 && d2(P, B) < (B.r * .7) ** 2) playerHit();
}

// ---------- Düşman mermileri ----------
function updEB(dt) {
  const P = G.P, alive = !P.dead && P.enter <= 0;
  for (const b of G.eb) {
    if (b.dead) continue;
    b.life += dt;
    if (b.acc || b.av) { b.sp = clamp(b.sp + b.acc * dt, 20, b.max); b.a += b.av * dt; b.vx = Math.cos(b.a) * b.sp; b.vy = Math.sin(b.a) * b.sp; }
    b.x += b.vx * dt; b.y += b.vy * dt;
    if (b.split && b.life >= b.split.at) { b.dead = true; ring(b.x, b.y, b.split.n, b.split.sp, rand(TAU), { c: b.split.c, r: 5 }); part(b.x, b.y, 0, 0, .3, 14, b.c, 'ring'); continue; }
    if (b.x < -40 || b.x > FW + 40 || b.y < -60 || b.y > FH + 40 || b.life > 14) { b.dead = true; continue; }
    if (!alive) continue;
    const dx = b.x - P.x, dy = b.y - P.y, dd = dx * dx + dy * dy;
    if (P.inv <= 0 && dd < (b.r * .65 + 3) ** 2) { b.dead = true; playerHit(); }
    else if (!b.gr && dd < 24 * 24) { b.gr = true; G.graze++; G.score += 50; part(P.x + dx * .5, P.y + dy * .5, rand(-80, 80), rand(-80, 80), .2, 2, '#ffffff'); AU.sfx('graze'); }
  }
  G.eb = G.eb.filter(b => !b.dead);
}

// ---------- Bölüm akışı ----------
function updStage(dt) {
  const st = STAGES[G.stage]; G.stageT += dt;
  while (G.waveI < st.waves.length && st.waves[G.waveI].t <= G.stageT) {
    const w = st.waves[G.waveI++];
    for (let i = 0; i < (w.n || 1); i++) G.pending.push({ at: G.stageT + i * (w.dt || 0), w, i });
  }
  for (let i = G.pending.length - 1; i >= 0; i--) if (G.pending[i].at <= G.stageT) { spawnFromWave(G.pending[i]); G.pending.splice(i, 1); }
  const lastT = st.waves[st.waves.length - 1].t;
  if (!G.bossSpawned && G.waveI >= st.waves.length && !G.pending.length && G.stageT > lastT + 4 && (G.enemies.length === 0 || G.stageT > lastT + 14)) {
    G.bossSpawned = true; G.bossWarn = 3;
    banner('⚠ UYARI ⚠', BOSSES[st.boss].name + ' YAKLAŞIYOR', '#ff3355', 3);
    AU.sfx('warn'); AU.music('boss'); radio('enemy', BOSSES[st.boss].line);
  }
  if (G.bossWarn > 0) { G.bossWarn -= dt; if (G.bossWarn <= 0) spawnBoss(st.boss); }
  if (G.bossDown > 0) {
    G.bossDown -= dt;
    if (G.bossDown <= 0) { const lines = G.loop === 0 ? STORY.bossDown[G.stage] : null; if (lines) openDialog(lines, nextStage); else nextStage(); }
  }
}
function nextStage() {
  G.stage++;
  if (G.stage >= STAGES.length) {
    G.stage = 0; G.loop++; setDifficulty();
    banner('TUR ' + (G.loop + 1), 'SÜRÜ GÜÇLENDİ — ZORLUK ARTTI', '#ff9a3c', 3); radio('cmd', STORY.loop);
  }
  G.stageT = 0; G.waveI = 0; G.pending = []; G.bossSpawned = false; G.flash = .8;
  BG.set(STAGES[G.stage].theme); AU.music(STAGES[G.stage].theme); stageBanner(); AU.sfx('whoosh');
}

// ---------- Kalkış animasyonu ----------
function updTakeoff(dt) {
  const P = G.P, t = (G.to += dt);
  const spd = t < .6 ? 0 : 60 + 1100 * Math.pow(Math.min(t - .6, 2.4) / 2.4, 1.7);
  G.toDist += spd * dt;
  P.y = lerp(FH - 150, FH - 110, ease((t - 2.6) / 1.2));
  if (t > .6 && t < 2.4 && Math.random() < .8) part(P.x + rand(-14, 14), P.y + 26, rand(-40, 40), rand(80, 200), .6, rand(5, 10), '#888', 'smoke');
  if (t > 2.5 && t < 3.5) for (let i = 0; i < 2; i++) part(rand(FW), -30, 0, rand(900, 1400), .9, rand(20, 50), '#ffffff', 'puff');
  G.shake = t > .6 && t < 2.6 ? 1.5 : G.shake;
  if (t >= 3 && !G.toFlash) { G.toFlash = true; G.flash = .6; AU.sfx('whoosh'); }
  if (t >= 3.6 && !G.toBanner) { G.toBanner = true; stageBanner(); }
  if (t >= 4.2) { G.phase = 'play'; P.inv = 1; }
}
function toScale() { return G.phase === 'play' ? 1 : lerp(.72, 1, ease((G.to - 2) / 1.4)); }

// ---------- Oyun güncelleme ----------
const PAUSE_ITEMS = ['DEVAM', 'YENİDEN BAŞLA', 'ANA MENÜ'];
const OVER_ITEMS = ['TEKRAR DENE', 'HANGAR', 'ANA MENÜ'];
function updGame(dt) {
  const g = G;
  BG.update(dt, g.phase === 'takeoff' ? (g.to > 2.6 ? 1 + 2.5 * (1 - ease((g.to - 2.6) / 1.6)) : 0) : 1);
  if (g.paused) {
    if (hit('up')) { pauseI = (pauseI + 2) % 3; AU.sfx('select'); }
    if (hit('down')) { pauseI = (pauseI + 1) % 3; AU.sfx('select'); }
    if (hit('pause')) { g.paused = false; return; }
    if (hit('ok')) {
      AU.sfx('confirm');
      if (pauseI === 0) g.paused = false; else if (pauseI === 1) startRun(); else goMenu();
    }
    return;
  }
  if (g.dialog) { updDialog(dt); updParts(dt); return; }
  if (g.phase === 'over') {
    updParts(dt);
    if (T - G.overAt < 1) return; // ateş tuşuna basılıyken yanlışlıkla seçim olmasın
    if (hit('up')) { overI = (overI + 2) % 3; AU.sfx('select'); }
    if (hit('down')) { overI = (overI + 1) % 3; AU.sfx('select'); }
    if (hit('ok')) {
      AU.sfx('confirm');
      if (overI === 0) startRun(); else if (overI === 1) { goMenu(); scene = 'hangar'; hangarI = Math.max(0, PLANES.findIndex(p => p.id === save.plane)); } else goMenu();
    }
    return;
  }
  for (const b of g.banners) b.t += dt;
  g.banners = g.banners.filter(b => b.t < b.dur);
  if (!g.radio && g.radioQ.length) { const r = g.radioQ.shift(); g.radio = { ...r, t: 0, dur: 2.2 + r.text.length * .045 }; }
  if (g.radio && (g.radio.t += dt) > g.radio.dur) g.radio = null;
  g.shake = Math.max(0, g.shake - 25 * dt); g.flash = Math.max(0, g.flash - 2 * dt);
  if (g.phase === 'brief') return;
  if (g.phase === 'takeoff') { updTakeoff(dt); updParts(dt); return; }
  if (hit('pause')) { g.paused = true; pauseI = 0; AU.sfx('select'); return; }
  g.bombT = Math.max(0, g.bombT - dt);
  if (g.bombT > 1) clearBullets(true);
  updStage(dt); updPlayer(dt); updPB(dt); updEnemies(dt); updBoss(dt); updEB(dt); updItems(dt); updParts(dt);
  if (g.overT > 0 && (g.overT -= dt) <= 0) gameOver();
}
function gameOver() {
  const g = G; g.phase = 'over'; g.overAt = T; overI = 0; AU.music(null); AU.sfx('over');
  const rec = { score: g.score, plane: g.plane.name, stage: g.stage + 1, loop: g.loop + 1, date: new Date().toLocaleDateString('tr-TR') };
  if (g.score > 0) save.records.push(rec);
  save.records.sort((a, b) => b.score - a.score); save.records = save.records.slice(0, 10);
  g.rank = save.records.indexOf(rec) + 1; g.newRecord = g.rank === 1 && g.score > 0;
  g.overLine = pick(STORY.gameOver); persist();
}

// ---------- Menüler ----------
function updMenu(dt) {
  BG.update(dt, 1);
  const items = menuItems();
  if (hit('up')) { menuI = (menuI + items.length - 1) % items.length; AU.sfx('select'); }
  if (hit('down')) { menuI = (menuI + 1) % items.length; AU.sfx('select'); }
  if (!hit('ok')) return;
  AU.sfx('confirm');
  const it = items[menuI];
  if (it === 'OYNA') startRun();
  else if (it === 'HANGAR') { scene = 'hangar'; hangarI = Math.max(0, PLANES.findIndex(p => p.id === save.plane)); }
  else if (it === 'REKORLAR') scene = 'records';
  else if (it === 'KONTROLLER') scene = 'controls';
  else if (it.startsWith('SES')) { save.sound = !save.sound; AU.setOn(save.sound); persist(); }
  else if (it === 'TAM EKRAN') toggleFull();
  else if (it === 'ÇIKIŞ') window.close();
}
function updHangar(dt) {
  BG.update(dt, 1);
  if (hit('left')) { hangarI = (hangarI + PLANES.length - 1) % PLANES.length; AU.sfx('select'); }
  if (hit('right')) { hangarI = (hangarI + 1) % PLANES.length; AU.sfx('select'); }
  if (hit('ok')) {
    const p = PLANES[hangarI];
    if (unlocked(p)) { save.plane = p.id; persist(); AU.sfx('confirm'); } else AU.sfx('deny');
  }
  if (hit('back')) { AU.sfx('back'); scene = 'menu'; }
}

function update(dt) {
  if (hit('full')) toggleFull();
  switch (scene) {
    case 'menu': updMenu(dt); break;
    case 'hangar': updHangar(dt); break;
    case 'records': case 'controls': BG.update(dt, 1); if (hit('back') || hit('ok')) { AU.sfx('back'); scene = 'menu'; } break;
    case 'game': updGame(dt); break;
  }
}

// ============================================================
//  ÇİZİM
// ============================================================
function drawAirbase(g) {
  const t = G.to, a = 1 - ease((t - 2.6) / .8); if (a <= 0) return;
  const d = G.toDist, rx = FW / 2 - 70, rw = 140;
  g.save(); g.globalAlpha = a;
  g.fillStyle = '#22381f'; g.fillRect(0, 0, FW, FH);
  g.fillStyle = '#284425'; for (let y = d % 80 - 80; y < FH; y += 80) g.fillRect(0, y, FW, 40);
  for (let k = Math.floor((d - 200) / 300); k < Math.floor((d + FH + 200) / 300); k++) { // pist kenarı binalar
    const sy = FH - (k * 300 + 100 - d), hsh = Math.abs(Math.sin(k * 12.9898) * 43758.5) % 1;
    if (sy < -120 || sy > FH + 120) continue;
    const left = hsh < .5, bx = left ? 40 + hsh * 80 : FW - 200 + hsh * 60;
    g.fillStyle = '#3b4048'; g.fillRect(bx, sy - 50, 110, 80);
    g.fillStyle = '#4b525c'; for (let i = 0; i < 5; i++) g.fillRect(bx + 4, sy - 46 + i * 16, 102, 6);
    g.fillStyle = '#5a6b4a'; g.beginPath(); g.arc(left ? bx + 160 : bx - 40, sy + 10, 16 + hsh * 8, 0, TAU); g.fill();
  }
  g.fillStyle = '#3a3d42'; g.fillRect(rx - 10, 0, rw + 20, FH);
  g.fillStyle = '#26282d'; g.fillRect(rx, 0, rw, FH);
  g.fillStyle = '#d9dde3'; g.fillRect(rx + 6, 0, 3, FH); g.fillRect(rx + rw - 9, 0, 3, FH);
  for (let y = d % 60 - 60; y < FH; y += 60) g.fillRect(FW / 2 - 2, y, 4, 30);
  const ty = FH - 50 + d;
  if (ty < FH + 40) {
    for (let i = 0; i < 8; i++) g.fillRect(rx + 12 + i * 15 + (i >= 4 ? 4 : 0), ty, 8, 34);
    txt(g, '27', FW / 2, ty - 40, 34, '#d9dde3', 'center', 900);
  }
  const blink = Math.floor(T * 4) % 2;
  for (let y = d % 40 - 40; y < FH; y += 40) {
    g.fillStyle = blink ? '#ffe9a0' : '#a08850'; g.fillRect(rx - 7, y, 4, 4); g.fillRect(rx + rw + 3, y, 4, 4);
  }
  g.restore();
}

function drawItem(g, it) {
  const x = it.x, y = it.y;
  if (it.k === 's') { g.fillStyle = '#9fd8ff'; g.fillRect(x - 2, y - 2, 4, 4); return; }
  if (it.k === 'S') {
    g.fillStyle = '#4fa8ff'; g.strokeStyle = '#fff'; g.lineWidth = 1.5;
    g.beginPath(); g.moveTo(x, y - 8); g.lineTo(x + 7, y); g.lineTo(x, y + 8); g.lineTo(x - 7, y); g.closePath(); g.fill(); g.stroke(); return;
  }
  const col = { P: '#ff4f6a', B: '#57ff9a', L: '#ff4fd8' }[it.k], lab = it.k === 'L' ? '1UP' : it.k, w = it.k === 'L' ? 26 : 16;
  g.fillStyle = col; g.shadowColor = col; g.shadowBlur = 8; g.fillRect(x - w / 2, y - 8, w, 16); g.shadowBlur = 0;
  g.strokeStyle = '#fff'; g.lineWidth = 1.2; g.strokeRect(x - w / 2, y - 8, w, 16);
  txt(g, lab, x, y + 1, 11, '#fff', 'center', 900);
}

function drawParts(g) {
  for (const p of G.parts) {
    const k = p.life / p.max;
    if (p.kind === 'smoke') { g.globalAlpha = k * .35; g.fillStyle = p.color === '#000' ? '#1a1a1a' : p.color; g.beginPath(); g.arc(p.x, p.y, p.size * (1.6 - k * .6), 0, TAU); g.fill(); }
  }
  g.globalAlpha = 1; g.globalCompositeOperation = 'lighter';
  for (const p of G.parts) {
    const k = p.life / p.max;
    g.globalAlpha = k;
    switch (p.kind) {
      case 'spark': g.strokeStyle = p.color; g.lineWidth = p.size * .7; g.beginPath(); g.moveTo(p.x, p.y); g.lineTo(p.x - p.vx * .03, p.y - p.vy * .03); g.stroke(); break;
      case 'ring': g.strokeStyle = p.color; g.lineWidth = 3 * k; g.beginPath(); g.arc(p.x, p.y, p.size * (1 + (1 - k) * 4), 0, TAU); g.stroke(); break;
      case 'flash': { const gr = g.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.size); gr.addColorStop(0, '#fff'); gr.addColorStop(.4, p.color); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.beginPath(); g.arc(p.x, p.y, p.size, 0, TAU); g.fill(); break; }
      case 'puff': { const c = BG.spr.cloud[0]; g.globalAlpha = k * .45; g.drawImage(c, p.x - p.size * 2, p.y - p.size * 1.2, p.size * 4, p.size * 2.5); break; }
    }
  }
  g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
}

function drawPB(g) {
  g.globalCompositeOperation = 'lighter'; g.lineCap = 'round';
  const col = G.plane.color;
  for (const b of G.pb) {
    if (b.k === 'missile') {
      g.save(); g.translate(b.x, b.y); g.rotate(b.a); g.fillStyle = '#ffb070';
      g.beginPath(); g.moveTo(8, 0); g.lineTo(-5, -3.5); g.lineTo(-5, 3.5); g.closePath(); g.fill(); g.restore();
      continue;
    }
    const L = b.k === 'needle' ? .022 : .014;
    g.strokeStyle = col; g.lineWidth = b.k === 'needle' ? 3 : 5; g.beginPath(); g.moveTo(b.x, b.y); g.lineTo(b.x - b.vx * L, b.y - b.vy * L); g.stroke();
    g.strokeStyle = '#fff'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(b.x, b.y); g.lineTo(b.x - b.vx * L * .8, b.y - b.vy * L * .8); g.stroke();
  }
  g.globalCompositeOperation = 'source-over'; g.lineCap = 'butt';
}

function drawEB(g) {
  for (const b of G.eb) {
    const s = bulletSprite(b.c, b.r), z = s.sz;
    if (b.k === 'rice') {
      g.save(); g.translate(b.x, b.y); g.rotate(Math.atan2(b.vy, b.vx)); g.scale(1.5, .65); g.drawImage(s, -z / 2, -z / 2, z, z); g.restore();
    } else g.drawImage(s, b.x - z / 2, b.y - z / 2, z, z);
  }
}

function drawPlayer(g) {
  const P = G.P; if (P.dead) return;
  const sc = toScale();
  let flame = 1;
  if (G.phase !== 'play') {
    const t = G.to, off = (sc - .72) * 140;
    drawPlane(g, G.plane, P.x + 5 + off, P.y + 6 + off * 1.3, sc * .95, T, 0, { shadow: true, alpha: 1 - ease((t - 2.4) / 1) });
    flame = t < .6 ? .2 + t : 1.6;
  }
  if (G.bombT > 0) {
    const k = 1 - G.bombT / 2; g.strokeStyle = hexA(G.plane.color, 1 - k); g.lineWidth = 6;
    for (let i = 0; i < 3; i++) { g.beginPath(); g.arc(G.bombX, G.bombY, (k * 900 - i * 60) > 0 ? k * 900 - i * 60 : 0, 0, TAU); g.stroke(); }
  }
  g.save();
  if (P.inv > 0 && Math.floor(T * 14) % 2) g.globalAlpha = .35;
  drawPlane(g, G.plane, P.x, P.y, sc, T, P.bank, { flame: P.focus ? .6 : flame });
  g.restore();
  if (P.focus && P.enter <= 0) {
    g.save(); g.translate(P.x, P.y); g.rotate(T * 2);
    g.strokeStyle = hexA(G.plane.color, .6); g.lineWidth = 1; g.setLineDash([4, 4]); g.beginPath(); g.arc(0, 0, 24, 0, TAU); g.stroke(); g.setLineDash([]);
    g.restore();
    g.fillStyle = '#ff3355'; g.beginPath(); g.arc(P.x, P.y, 5, 0, TAU); g.fill();
    g.fillStyle = '#fff'; g.beginPath(); g.arc(P.x, P.y, 3, 0, TAU); g.fill();
  }
}

function drawBanners(g) {
  let y = FH * .38;
  for (const b of G.banners) {
    const a = Math.min(1, b.t * 4, (b.dur - b.t) * 2.5), s = 1 + .3 * (1 - ease(b.t * 4));
    g.save(); g.globalAlpha = a; g.translate(FW / 2, y); g.scale(s, s);
    txt(g, b.text, 0, 0, 40, b.color, 'center', 900, 18);
    if (b.sub) txt(g, b.sub, 0, 34, 16, '#dfe8f5', 'center', 600);
    g.restore(); y += b.sub ? 82 : 56;
  }
}

function drawRadio(g) {
  const r = G.radio; if (!r) return;
  const a = Math.min(1, r.t * 5, (r.dur - r.t) * 4), y = G.boss ? 52 : 12;
  g.save(); g.globalAlpha = a;
  g.fillStyle = 'rgba(4,8,16,.82)'; rrect(g, 10, y, FW - 20, 74, 6); g.fill();
  g.strokeStyle = hexA(WHO[r.who].c, .7); g.lineWidth = 1; g.stroke();
  drawPortrait(g, r.who, 18, y + 7, 60, T);
  txt(g, WHO[r.who].n, 90, y + 16, 12, WHO[r.who].c, 'left', 800);
  const font = `600 14px ${F}`, lines = wrap(g, r.text, FW - 120, font), shown = Math.floor(r.t * 70);
  g.font = font; g.fillStyle = '#e8eef8'; g.textAlign = 'left'; g.textBaseline = 'middle';
  let left = shown; lines.slice(0, 3).forEach((ln, i) => { if (left > 0) g.fillText(ln.slice(0, left), 90, y + 36 + i * 17); left -= ln.length + 1; });
  g.restore();
}

function drawBossBar(g) {
  const B = G.boss; if (!B) return;
  const fill = B.entered ? B.hp / B.max : ease(B.t / 2.5);
  txt(g, B.d.name, 14, 14, 13, B.d.color, 'left', 900, 8);
  for (let k = 0; k < B.d.phases.length - B.ph - 1; k++) star(g, FW - 20 - k * 16, 14, 6, B.d.color);
  bar(g, 12, 26, FW - 24, 7, fill, B.d.color, 'rgba(255,255,255,.12)');
}

function panel(g, x, w) {
  const gr = g.createLinearGradient(x, 0, x + w, 0);
  gr.addColorStop(0, '#05070e'); gr.addColorStop(1, '#0a0f1c');
  g.fillStyle = gr; g.fillRect(x, 0, w, H);
  g.strokeStyle = 'rgba(79,216,255,.05)'; g.lineWidth = 1;
  for (let y = 0; y < H; y += 24) { g.beginPath(); g.moveTo(x, y); g.lineTo(x + w, y); g.stroke(); }
}
function label(g, s, x, y) { txt(g, s, x, y, 11, '#6f86a8', 'left', 800); }

function drawHUD(g) {
  const P = G.P, pl = G.plane, li = LEVEL.info(save.xp), best = Math.max(save.records[0] ? save.records[0].score : 0, G.score);
  panel(g, 0, FX); panel(g, FX + FW, W - FX - FW);
  g.fillStyle = pl.color; g.shadowColor = pl.color; g.shadowBlur = 12; g.fillRect(FX - 2, 0, 2, H); g.fillRect(FX + FW, 0, 2, H); g.shadowBlur = 0;
  txt(g, 'GÖKKALKAN', FX / 2, 48, 30, '#4fd8ff', 'center', 900, 14);
  txt(g, 'OPERASYON: DEMİR SÜRÜ', FX / 2, 76, 11, '#6f86a8', 'center', 700);
  label(g, 'SKOR', 36, 128); txt(g, fmt(G.score), 36, 156, 30, '#ffffff', 'left', 700, 0, MONO);
  label(g, 'REKOR', 36, 200); txt(g, fmt(best), 36, 224, 22, '#ffe14f', 'left', 700, 0, MONO);
  label(g, 'PİLOT', 36, 270); txt(g, rankOf(li.level) + '  •  SV ' + li.level, 36, 294, 18, '#ffffff', 'left', 800);
  bar(g, 36, 312, 248, 8, li.into / li.need, '#ffe14f');
  txt(g, li.into + ' / ' + li.need + ' XP', 36, 334, 11, '#6f86a8', 'left', 600);
  txt(g, '+' + G.runXP + ' bu uçuşta', 284, 334, 11, '#ffe14f', 'right', 700);
  label(g, 'UÇAK', 36, 384);
  drawPlane(g, pl, FX / 2, 450, 1.7, T, 0);
  txt(g, pl.name, FX / 2, 520, 22, pl.color, 'center', 900, 10);
  txt(g, pl.title, FX / 2, 544, 11, '#6f86a8', 'center', 600);
  ['YÖN TUŞLARI / WASD  hareket', 'Z / SPACE  ateş', 'SHIFT  hassas uçuş', 'X  bomba     ESC  duraklat'].forEach((s, i) => txt(g, s, 36, 610 + i * 20, 12, '#4a5d7a', 'left', 600));

  const x0 = FX + FW + 36;
  label(g, 'CAN', x0, 60);
  for (let i = 0; i < P.lives; i++) drawPlane(g, pl, x0 + 14 + i * 34, 96, .7, 0, 0, { flame: 0 });
  label(g, 'BOMBA', x0, 146);
  for (let i = 0; i < P.bombs; i++) star(g, x0 + 12 + i * 30, 176, 11, '#57ff9a');
  label(g, 'GÜÇ', x0, 226); bar(g, x0, 244, 248, 10, P.power / 4, pl.color);
  for (let i = 1; i < 4; i++) { g.fillStyle = '#05070e'; g.fillRect(x0 + 62 * i, 244, 2, 10); }
  txt(g, P.power >= 4 ? 'MAKSİMUM' : P.power.toFixed(2) + ' / 4.00', x0, 270, 13, '#dfe8f5', 'left', 700, 0, MONO);
  label(g, 'SIYIRMA', x0, 316); txt(g, String(G.graze), x0, 340, 22, '#ffffff', 'left', 700, 0, MONO);
  label(g, 'BÖLÜM', x0, 392); txt(g, (G.stage + 1) + ' / ' + STAGES.length, x0, 418, 24, '#4fd8ff', 'left', 900);
  txt(g, STAGES[G.stage].name, x0, 444, 12, '#6f86a8', 'left', 700);
  label(g, 'TUR', x0, 492); txt(g, String(G.loop + 1), x0, 518, 24, G.loop ? '#ff9a3c' : '#ffffff', 'left', 900);
  txt(g, 'ZORLUK ×' + G.hp.toFixed(2) + '   XP ×' + G.xm.toFixed(1), x0, 544, 12, '#6f86a8', 'left', 700);
  txt(g, 'Mermiye değmeden yakın geçmek', x0, 620, 11, '#4a5d7a', 'left', 600);
  txt(g, '(SIYIRMA) ekstra puan verir.', x0, 638, 11, '#4a5d7a', 'left', 600);
}

function drawDialog(g, d) {
  const line = d.lines[d.i], who = WHO[line.w];
  g.fillStyle = 'rgba(0,0,0,.45)'; g.fillRect(0, 0, W, H);
  const bx = 170, by = 490, bw = 940, bh = 200;
  g.fillStyle = 'rgba(5,9,18,.95)'; rrect(g, bx, by, bw, bh, 10); g.fill();
  g.strokeStyle = who.c; g.lineWidth = 2; g.shadowColor = who.c; g.shadowBlur = 14; g.stroke(); g.shadowBlur = 0;
  drawPortrait(g, line.w, bx + 22, by + 25, 150, T);
  txt(g, who.n, bx + 196, by + 38, 22, who.c, 'left', 900, 8);
  txt(g, who.r, bx + 196, by + 62, 12, '#6f86a8', 'left', 600);
  txt(g, (d.i + 1) + ' / ' + d.lines.length + '    ESC: Atla', bx + bw - 20, by + 30, 11, '#4a5d7a', 'right', 700);
  const font = `600 20px ${F}`, lines = wrap(g, line.t, bw - 230, font);
  g.font = font; g.fillStyle = '#eef3fb'; g.textAlign = 'left'; g.textBaseline = 'middle';
  let left = Math.floor(d.ch);
  lines.forEach((ln, i) => { if (left > 0) g.fillText(ln.slice(0, left), bx + 196, by + 98 + i * 28); left -= ln.length + 1; });
  if (d.ch >= line.t.length && Math.floor(T * 3) % 2) txt(g, '▼  Z / ENTER', bx + bw - 20, by + bh - 22, 12, who.c, 'right', 800);
}

function menuList(g, items, sel, x, y, gap = 48, size = 24, align = 'left') {
  items.forEach((s, i) => {
    const on = i === sel;
    if (on) {
      g.fillStyle = 'rgba(79,216,255,.1)'; g.fillRect(align === 'center' ? x - 160 : x - 20, y + i * gap - 20, 320, 40);
      g.fillStyle = '#4fd8ff'; g.fillRect(align === 'center' ? x - 160 : x - 20, y + i * gap - 20, 4, 40);
    }
    txt(g, s, x + (on && align === 'left' ? 10 : 0), y + i * gap, size, on ? '#ffffff' : '#7f93b0', align, on ? 900 : 700, on ? 12 : 0);
  });
}

function drawOverlayGame(g) {
  if (G.paused) {
    g.fillStyle = 'rgba(0,0,0,.6)'; g.fillRect(0, 0, W, H);
    txt(g, 'DURAKLATILDI', W / 2, 250, 48, '#4fd8ff', 'center', 900, 20);
    menuList(g, PAUSE_ITEMS, pauseI, W / 2, 340, 52, 24, 'center');
  }
  if (G.phase === 'over') {
    g.fillStyle = 'rgba(0,0,0,.72)'; g.fillRect(0, 0, W, H);
    txt(g, 'GÖREV BAŞARISIZ', W / 2, 110, 56, '#ff3355', 'center', 900, 24);
    txt(g, '"' + G.overLine + '"', W / 2, 160, 15, '#9fb4d0', 'center', 600);
    txt(g, 'SKOR', W / 2, 215, 13, '#6f86a8', 'center', 800);
    txt(g, fmt(G.score), W / 2, 248, 40, '#ffffff', 'center', 700, 0, MONO);
    if (G.newRecord) txt(g, '★ YENİ REKOR! ★', W / 2, 290, 22, '#ffe14f', 'center', 900, 14);
    else if (G.rank) txt(g, 'Rekor tablosunda ' + G.rank + '. sıra', W / 2, 290, 16, '#9fb4d0', 'center', 700);
    txt(g, 'Ulaşılan: Bölüm ' + (G.stage + 1) + '  •  Tur ' + (G.loop + 1) + '  •  Sıyırma ' + G.graze, W / 2, 322, 14, '#9fb4d0', 'center', 600);
    const li = LEVEL.info(save.xp);
    txt(g, '+' + G.runXP + ' XP', W / 2, 362, 24, '#ffe14f', 'center', 900, 10);
    txt(g, (li.level > G.levelStart ? 'SEVİYE ' + G.levelStart + ' → ' + li.level + '   ' : 'SEVİYE ' + li.level + '   ') + rankOf(li.level), W / 2, 392, 15, '#ffffff', 'center', 800);
    bar(g, W / 2 - 200, 408, 400, 8, li.into / li.need, '#ffe14f');
    const news = PLANES.filter(p => p.unlock > G.levelStart && p.unlock <= li.level);
    if (news.length) txt(g, 'YENİ UÇAK AÇILDI: ' + news.map(p => p.name).join(', '), W / 2, 438, 16, news[0].color, 'center', 900, 10);
    menuList(g, OVER_ITEMS, overI, W / 2, 500, 50, 22, 'center');
  }
}

function renderGame(g) {
  const sx = (Math.random() - .5) * G.shake, sy = (Math.random() - .5) * G.shake;
  g.save(); g.translate(FX + sx, sy); g.beginPath(); g.rect(0, 0, FW, FH); g.clip();
  BG.draw(g, FW, FH);
  if (G.phase === 'brief' || G.phase === 'takeoff') drawAirbase(g);
  for (const it of G.items) drawItem(g, it);
  for (const e of G.enemies) {
    if (e.type === 'sniper' && e.aimT > 0) {
      g.strokeStyle = `rgba(87,255,154,${Math.floor(T * 20) % 2 ? .8 : .35})`; g.lineWidth = 1;
      g.beginPath(); g.moveTo(e.x, e.y); g.lineTo(e.x + Math.cos(e.aimA) * 900, e.y + Math.sin(e.aimA) * 900); g.stroke();
    }
    drawEnemy(g, e, T);
  }
  if (G.boss) drawBoss(g, G.boss, T, G.P.x, G.P.y);
  drawPB(g);
  drawPlayer(g);
  drawParts(g);
  drawEB(g);
  if (G.flash > 0) { g.fillStyle = `rgba(255,255,255,${G.flash * .6})`; g.fillRect(0, 0, FW, FH); }
  drawBossBar(g); drawBanners(g); drawRadio(g);
  g.restore();
  drawHUD(g);
  if (G.dialog) drawDialog(g, G.dialog);
  drawOverlayGame(g);
}

function pilotCard(g, x, y) {
  const li = LEVEL.info(save.xp), next = PLANES.find(p => p.unlock > li.level);
  g.fillStyle = 'rgba(5,9,18,.8)'; rrect(g, x, y, 300, 150, 8); g.fill(); g.strokeStyle = 'rgba(79,216,255,.4)'; g.lineWidth = 1; g.stroke();
  label(g, 'PİLOT ŞAHİN-1', x + 20, y + 24);
  txt(g, rankOf(li.level), x + 20, y + 52, 22, '#ffffff', 'left', 900);
  txt(g, 'SV ' + li.level, x + 280, y + 52, 22, '#ffe14f', 'right', 900, 8);
  bar(g, x + 20, y + 74, 260, 8, li.into / li.need, '#ffe14f');
  txt(g, li.into + ' / ' + li.need + ' XP', x + 20, y + 96, 11, '#6f86a8', 'left', 600);
  txt(g, next ? 'Sonraki uçak: ' + next.name + ' (Sv ' + next.unlock + ')' : 'Tüm uçaklar açık!', x + 20, y + 124, 13, next ? next.color : '#57ff9a', 'left', 800);
}

function renderMenu(g) {
  BG.draw(g, W, H);
  const pl = PLANES.find(p => p.id === save.plane) || PLANES[0];
  drawPlane(g, pl, W / 2 + 80, 460 + Math.sin(T * 1.5) * 8, 2.6, T, Math.sin(T * .8) * .3);
  txt(g, 'GÖKKALKAN', W / 2, 130, 100, '#4fd8ff', 'center', 900, 36);
  txt(g, 'GÖKKALKAN', W / 2, 130, 100, 'rgba(255,255,255,.85)', 'center', 900);
  txt(g, 'OPERASYON: DEMİR SÜRÜ', W / 2, 200, 18, '#9fb4d0', 'center', 700);
  menuList(g, menuItems(), menuI, 120, 300);
  pilotCard(g, 940, 300);
  txt(g, '↑↓ seç   Z / ENTER onayla   F tam ekran', W / 2, 690, 12, '#4a5d7a', 'center', 600);
  txt(g, 'v0.1 prototip', W - 16, 700, 11, '#3a4a64', 'right', 600);
}

function renderHangar(g) {
  BG.draw(g, W, H);
  const p = PLANES[hangarI], ok = unlocked(p), active = save.plane === p.id;
  txt(g, 'HANGAR', W / 2, 60, 44, '#4fd8ff', 'center', 900, 18);
  g.fillStyle = 'rgba(79,216,255,.06)'; g.beginPath(); g.ellipse(460, 560, 230, 40, 0, 0, TAU); g.fill();
  g.strokeStyle = hexA(ok ? p.color : '#3a4050', .5); g.lineWidth = 2; g.stroke();
  drawPlane(g, p, 460, 360 + Math.sin(T * 1.4) * 6, 4.2, T, Math.sin(T * .7) * .25, { locked: !ok });
  if (!ok) {
    txt(g, '🔒', 460, 360, 54, '#fff', 'center', 400);
    txt(g, 'SEVİYE ' + p.unlock + '\'TE AÇILIR', 460, 440, 22, '#ff9a3c', 'center', 900, 10);
  }
  txt(g, '◄', 160, 360, 40, '#7f93b0', 'center', 900); txt(g, '►', 760, 360, 40, '#7f93b0', 'center', 900);
  PLANES.forEach((q, i) => { g.fillStyle = i === hangarI ? q.color : unlocked(q) ? '#4a5d7a' : '#222a38'; g.beginPath(); g.arc(460 + (i - 2) * 24, 620, i === hangarI ? 6 : 4, 0, TAU); g.fill(); });
  const x = 860;
  g.fillStyle = 'rgba(5,9,18,.85)'; rrect(g, x - 24, 130, 400, 470, 10); g.fill(); g.strokeStyle = hexA(p.color, .5); g.lineWidth = 1.5; g.stroke();
  txt(g, p.name, x, 172, 40, ok ? p.color : '#7f93b0', 'left', 900, ok ? 14 : 0);
  txt(g, p.title, x, 208, 14, '#9fb4d0', 'left', 700);
  const lines = wrap(g, p.desc, 340, `600 14px ${F}`);
  lines.forEach((l, i) => txt(g, l, x, 244 + i * 20, 14, '#dfe8f5', 'left', 600));
  [['HIZ', 'hiz'], ['ATEŞ GÜCÜ', 'ates'], ['ZIRH', 'zirh'], ['BOMBA', 'bomba']].forEach(([n, k], i) => {
    label(g, n, x, 320 + i * 46); bar(g, x, 334 + i * 46, 340, 8, p.stats[k] / 10, ok ? p.color : '#3a4050');
  });
  txt(g, 'CAN ' + p.hp + '   •   BOMBA ' + p.bombs + '   •   MERMİ ' + (p.w.pierce ? 'DELİCİ' : 'STANDART'), x, 520, 13, '#9fb4d0', 'left', 700);
  txt(g, active ? '✔ AKTİF UÇAK' : ok ? 'Z / ENTER: SEÇ' : 'KİLİTLİ', x, 562, 18, active ? '#57ff9a' : ok ? '#ffffff' : '#ff9a3c', 'left', 900, active ? 10 : 0);
  pilotCard(g, 20, 120);
  txt(g, '◄ ► gez   Z / ENTER seç   ESC geri', W / 2, 690, 12, '#4a5d7a', 'center', 600);
}

function renderRecords(g) {
  BG.draw(g, W, H);
  txt(g, 'REKORLAR', W / 2, 70, 44, '#ffe14f', 'center', 900, 18);
  txt(g, 'Kişisel en iyi 10 uçuş  •  Dünya sıralaması yakında', W / 2, 110, 13, '#6f86a8', 'center', 600);
  const cols = [300, 400, 640, 790, 960];
  ['#', 'SKOR', 'UÇAK', 'BÖLÜM / TUR', 'TARİH'].forEach((h, i) => label(g, h, cols[i], 160));
  if (!save.records.length) txt(g, 'Henüz kayıt yok. Göklere çık, pilot!', W / 2, 300, 20, '#9fb4d0', 'center', 700);
  save.records.forEach((r, i) => {
    const y = 196 + i * 42, c = i === 0 ? '#ffe14f' : i < 3 ? '#ffffff' : '#9fb4d0';
    if (i % 2 === 0) { g.fillStyle = 'rgba(255,255,255,.03)'; g.fillRect(280, y - 18, 760, 36); }
    txt(g, String(i + 1), cols[0], y, 18, c, 'left', 900);
    txt(g, fmt(r.score), cols[1], y, 18, c, 'left', 700, 0, MONO);
    txt(g, r.plane || '-', cols[2], y, 16, c, 'left', 800);
    txt(g, (r.stage || 1) + ' / ' + (r.loop || 1), cols[3], y, 16, c, 'left', 700);
    txt(g, r.date || '', cols[4], y, 14, c, 'left', 600);
  });
  txt(g, 'ESC geri', W / 2, 690, 12, '#4a5d7a', 'center', 600);
}

function renderControls(g) {
  BG.draw(g, W, H);
  txt(g, 'KONTROLLER', W / 2, 70, 44, '#4fd8ff', 'center', 900, 18);
  const rows = [
    ['Hareket', 'Yön tuşları / WASD', 'Sol analog / D-Pad'], ['Ateş', 'Z / SPACE (basılı tut)', 'A / RT'],
    ['Hassas uçuş', 'SHIFT (yavaşlar, isabet noktası görünür)', 'LB / RB'], ['Bomba', 'X (ekrandaki mermileri siler)', 'B / X'],
    ['Duraklat', 'ESC / P', 'START'], ['Tam ekran', 'F', '-'],
  ];
  label(g, 'EYLEM', 220, 150); label(g, 'KLAVYE', 440, 150); label(g, 'GAMEPAD', 900, 150);
  rows.forEach((r, i) => { const y = 192 + i * 46; txt(g, r[0], 220, y, 18, '#ffffff', 'left', 800); txt(g, r[1], 440, y, 16, '#dfe8f5', 'left', 600); txt(g, r[2], 900, y, 16, '#dfe8f5', 'left', 600); });
  const tips = ['İpucu: Vurulabilen tek nokta uçağın ortasındaki küçük çekirdek. Kanatlara mermi değmesi sorun değil.',
    'İpucu: Ekranın üst kısmına çıkarsan düşen bütün eşyalar sana çekilir.',
    'İpucu: Kırmızı P kutuları ateş gücünü artırır. Vurulunca güç kaybedersin.'];
  tips.forEach((t, i) => txt(g, t, W / 2, 500 + i * 30, 14, '#9fb4d0', 'center', 600));
  txt(g, 'ESC geri', W / 2, 690, 12, '#4a5d7a', 'center', 600);
}

function render() {
  ctx.setTransform(S, 0, 0, S, 0, 0);
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  switch (scene) {
    case 'game': renderGame(ctx); break;
    case 'menu': renderMenu(ctx); break;
    case 'hangar': renderHangar(ctx); break;
    case 'records': renderRecords(ctx); break;
    case 'controls': renderControls(ctx); break;
  }
  if (errMsg) { ctx.fillStyle = 'rgba(120,0,0,.85)'; ctx.fillRect(0, 0, W, 30); txt(ctx, 'HATA: ' + errMsg, 10, 15, 13, '#fff', 'left', 700, 0, MONO); }
}

// ---------- Ana döngü ----------
addEventListener('error', e => { errMsg = e.message + ' @' + (e.lineno || '?'); });
let last = performance.now();
function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(1 / 30, (now - last) / 1000); last = now; T += dt;
  pollInput(); AU.tick();
  update(dt); render();
  cv.style.cursor = scene === 'game' ? 'none' : 'default';
}
BG.init(); goMenu();
// Geliştirici kısayolu: index.html#dev=2 → doğrudan 3. bölümden, girişsiz başlar
const devM = location.hash.match(/dev=(\d)/);
if (devM) {
  save.seenIntro = true; startRun(+devM[1] % STAGES.length); G.dialog = null; G.phase = 'play'; AU.music(STAGES[G.stage].theme);
  // #dev=0&ff=90 → 90 sn'yi ölümsüz + sürekli ateşle simüle et (otomatik test)
  const ff = +(location.hash.match(/ff=(\d+)/) || [0, 0])[1];
  try {
    for (let i = 0; i < ff * 60; i++) { held = { fire: true }; G.P.inv = 9; if (G.dialog) { G.dialog = null; nextStage(); } update(1 / 60); T += 1 / 60; }
  } catch (e) { errMsg = e.message + ' | ' + (e.stack || '').split('\n')[1]; }
}
requestAnimationFrame(frame);
