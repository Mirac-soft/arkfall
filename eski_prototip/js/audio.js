'use strict';
// Tüm sesler ve müzik kodla üretilir (WebAudio) — dosya gerekmez.
const SONGS = {
  menu:  { bpm: 92, calm: true, prog: [[57, 'm'], [53, 'M'], [48, 'M'], [55, 'M']] },
  dawn:  { bpm: 138, prog: [[57, 'm'], [53, 'M'], [48, 'M'], [55, 'M']] },
  storm: { bpm: 148, prog: [[50, 'm'], [46, 'M'], [53, 'M'], [48, 'M']] },
  orbit: { bpm: 128, prog: [[52, 'm'], [48, 'M'], [55, 'M'], [50, 'M']] },
  boss:  { bpm: 164, prog: [[45, 'm'], [45, 'm'], [43, 'M'], [41, 'M']] },
};
const THR = { shoot: .07, hit: .045, graze: .04, item: .03, blip: .035, boom: .04, lock: .1 };
const BASS = [1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1];
const mf = m => 440 * Math.pow(2, (m - 69) / 12);

const AU = {
  ctx: null, master: null, sfxG: null, musG: null, nbuf: null,
  song: null, songName: null, step: 0, next: 0, last: {}, on: true,

  unlock() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    try {
      const c = this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      this.master = c.createGain(); this.master.connect(c.destination);
      const comp = c.createDynamicsCompressor(); comp.connect(this.master);
      this.sfxG = c.createGain(); this.sfxG.gain.value = .55; this.sfxG.connect(comp);
      this.musG = c.createGain(); this.musG.gain.value = .3; this.musG.connect(comp);
      this.nbuf = c.createBuffer(1, c.sampleRate, c.sampleRate);
      const d = this.nbuf.getChannelData(0);
      for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      this.setOn(this.on);
      if (this.songName) this.music(this.songName, true);
    } catch (e) { this.ctx = null; }
  },
  setOn(on) { this.on = on; if (this.master) this.master.gain.value = on ? .8 : 0; },

  // tek osilatör
  v({ f = 440, t, dur = .1, type = 'square', vol = .1, slide = 0, lp = 0, dest = null }) {
    const c = this.ctx, o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.setValueAtTime(f, t);
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(20, f * slide), t + dur);
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(.0008, t + dur);
    let n = o;
    if (lp) { const fl = c.createBiquadFilter(); fl.type = 'lowpass'; fl.frequency.value = lp; o.connect(fl); n = fl; }
    n.connect(g); g.connect(dest || this.sfxG); o.start(t); o.stop(t + dur + .05);
  },
  // gürültü
  n({ t, dur = .2, vol = .2, f = 1200, type = 'lowpass', dest = null }) {
    const c = this.ctx, s = c.createBufferSource(), fl = c.createBiquadFilter(), g = c.createGain();
    s.buffer = this.nbuf; fl.type = type; fl.frequency.value = f;
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(.0008, t + dur);
    s.connect(fl); fl.connect(g); g.connect(dest || this.sfxG);
    s.start(t, Math.random() * .5); s.stop(t + dur + .05);
  },

  sfx(name) {
    const c = this.ctx; if (!c || !this.on) return;
    const t = c.currentTime;
    if (this.last[name] && t - this.last[name] < (THR[name] || 0)) return;
    this.last[name] = t;
    switch (name) {
      case 'shoot': this.v({ f: 1400, t, dur: .05, vol: .022, slide: .4 }); break;
      case 'hit': this.v({ f: 240, t, dur: .04, vol: .03, slide: .7 }); break;
      case 'boom': this.n({ t, dur: .35, vol: .32, f: 900 }); this.v({ f: 120, t, dur: .3, type: 'sine', vol: .22, slide: .3 }); break;
      case 'bigboom': this.n({ t, dur: 1.6, vol: .6, f: 500 }); this.v({ f: 70, t, dur: 1.4, type: 'sawtooth', vol: .25, slide: .25, lp: 400 }); break;
      case 'death': this.n({ t, dur: .9, vol: .5, f: 700 }); this.v({ f: 600, t, dur: .8, type: 'sawtooth', vol: .15, slide: .1, lp: 1500 }); break;
      case 'graze': this.v({ f: 2200, t, dur: .03, type: 'sine', vol: .03 }); break;
      case 'item': this.v({ f: 1300, t, dur: .06, type: 'sine', vol: .05, slide: 1.5 }); break;
      case 'power': [660, 880, 1320].forEach((f, i) => this.v({ f, t: t + i * .06, dur: .1, vol: .05 })); break;
      case 'bomb': this.n({ t, dur: 1.6, vol: .6, f: 1600 }); this.v({ f: 50, t, dur: 1.5, type: 'sawtooth', vol: .3, slide: 4, lp: 800 }); break;
      case 'levelup': [523, 659, 784, 1047].forEach((f, i) => this.v({ f, t: t + i * .09, dur: .3, type: 'triangle', vol: .14 })); break;
      case 'warn': for (let k = 0; k < 3; k++) this.v({ f: 440, t: t + k * .5, dur: .45, type: 'sawtooth', vol: .12, slide: 2, lp: 2000 }); break;
      case 'select': this.v({ f: 700, t, dur: .05, vol: .05 }); break;
      case 'confirm': this.v({ f: 880, t, dur: .08, vol: .06 }); this.v({ f: 1320, t: t + .07, dur: .12, vol: .06 }); break;
      case 'back': this.v({ f: 500, t, dur: .08, vol: .05, slide: .6 }); break;
      case 'deny': this.v({ f: 150, t, dur: .15, vol: .08 }); break;
      case 'blip': this.v({ f: 900 + Math.random() * 200, t, dur: .025, vol: .018 }); break;
      case 'lock': this.v({ f: 1800, t, dur: .3, type: 'sine', vol: .04, slide: 1.2 }); break;
      case 'dash': this.n({ t, dur: .3, vol: .15, f: 3000, type: 'highpass' }); break;
      case 'phase': this.n({ t, dur: .6, vol: .4, f: 1200 }); this.v({ f: 300, t, dur: .6, vol: .1, slide: 3, lp: 2500 }); break;
      case 'whoosh': this.n({ t, dur: 1.2, vol: .35, f: 2500, type: 'bandpass' }); break;
      case 'engine': this.v({ f: 70, t, dur: 3.4, type: 'sawtooth', vol: .12, slide: 3.5, lp: 900 }); this.n({ t, dur: 3.4, vol: .18, f: 700 }); break;
      case 'over': [440, 349, 294, 220].forEach((f, i) => this.v({ f, t: t + i * .22, dur: .4, type: 'triangle', vol: .12 })); break;
    }
  },

  music(name, force) {
    if (this.songName === name && !force) return;
    this.songName = name; this.song = name ? SONGS[name] : null;
    if (this.ctx) { this.step = 0; this.next = this.ctx.currentTime + .1; }
  },
  tick() {
    const c = this.ctx; if (!c || !this.song || !this.on) return;
    if (this.next < c.currentTime - .25) this.next = c.currentTime + .05; // sekme arka plandayken birikmeyi önle
    const sp = 60 / this.song.bpm / 4;
    while (this.next < c.currentTime + .15) { this.play(this.step, this.next, this.song); this.next += sp; this.step++; }
  },
  play(st, t, s) {
    const i = st % 16, [root, q] = s.prog[Math.floor(st / 16) % s.prog.length], th = q === 'm' ? 3 : 4, D = this.musG;
    if (s.calm) {
      if (i === 0) for (const n of [0, th, 7]) this.v({ f: mf(root + n), t, dur: 2.6, type: 'triangle', vol: .05, dest: D });
      if (i === 0 || i === 8) this.v({ f: mf(root - 12), t, dur: 1.2, type: 'sawtooth', vol: .08, lp: 400, dest: D });
      if (i % 2 === 0) this.v({ f: mf(root + 12 + [0, th, 7, 12, 7, th, 0, 7][(i / 2) % 8]), t, dur: .25, type: 'sine', vol: .04, dest: D });
      return;
    }
    if (i % 4 === 0) this.v({ f: 150, t, dur: .18, type: 'sine', vol: .55, slide: .25, dest: D });
    if (i % 4 === 2) this.n({ t, dur: .04, vol: .1, f: 7000, type: 'highpass', dest: D });
    if (i === 4 || i === 12) this.n({ t, dur: .15, vol: .2, f: 2200, type: 'bandpass', dest: D });
    if (BASS[i]) this.v({ f: mf(root - 12), t, dur: .13, type: 'sawtooth', vol: .14, lp: 800, dest: D });
    this.v({ f: mf(root + 12 + [0, th, 7, 12, 7, th, 12, 7][i % 8]), t, dur: .09, vol: .03, lp: 3000, dest: D });
  },
};
