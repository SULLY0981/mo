'use strict';
// ============================================================
//  THE LAST LANTERN — survive the endless night.
//  A survivors-like roguelite. No dependencies, runs offline.
// ============================================================

// ---------- Utilities ----------
const TAU = Math.PI * 2;
const rand = (a, b) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(rand(a, b + 1));
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const pick = (arr) => arr[(Math.random() * arr.length) | 0];
const dist2 = (ax, ay, bx, by) => { const dx = ax - bx, dy = ay - by; return dx * dx + dy * dy; };
const fmtTime = (s) => { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); };
const fmtNum = (n) => Math.round(n).toLocaleString('en-US');
function hash2(x, y) {
  let h = (Math.imul(x, 374761393) + Math.imul(y, 668265263)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}
function hexToRgb(h) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function rgba(h, a) { const [r, g, b] = hexToRgb(h); return `rgba(${r},${g},${b},${a})`; }
function mix(h1, h2, t) {
  const a = hexToRgb(h1), b = hexToRgb(h2);
  return '#' + a.map((v, i) => Math.round(lerp(v, b[i], t)).toString(16).padStart(2, '0')).join('');
}
function weightedPick(list) {
  let total = 0; for (const it of list) total += it.weight;
  let r = Math.random() * total;
  for (const it of list) { r -= it.weight; if (r <= 0) return it; }
  return list[list.length - 1];
}
function roundRectPath(g, x, y, w, h, r) {
  g.beginPath(); g.moveTo(x + r, y); g.lineTo(x + w - r, y); g.quadraticCurveTo(x + w, y, x + w, y + r);
  g.lineTo(x + w, y + h - r); g.quadraticCurveTo(x + w, y + h, x + w - r, y + h); g.lineTo(x + r, y + h);
  g.quadraticCurveTo(x, y + h, x, y + h - r); g.lineTo(x, y + r); g.quadraticCurveTo(x, y, x + r, y); g.closePath();
}
const $ = (id) => document.getElementById(id);

// ---------- Save data ----------
const SAVE_KEY = 'last_lantern_save_v1';
function defaultSave() {
  return {
    coins: 0, shop: {}, ach: {},
    best: { time: 0, kills: 0, level: 0 },
    totals: { kills: 0, runs: 0, bosses: 0, wins: 0, time: 0 },
    settings: { sfx: 7, music: 5, shake: true, dmgNums: true },
  };
}
function loadSave() {
  const d = defaultSave();
  try {
    const s = JSON.parse(localStorage.getItem(SAVE_KEY));
    if (s) for (const k in d) {
      if (s[k] === undefined) continue;
      d[k] = (typeof d[k] === 'object' && d[k] !== null) ? Object.assign(d[k], s[k]) : s[k];
    }
  } catch (e) { /* corrupt or unavailable storage: start fresh */ }
  return d;
}
let save = loadSave();
function persist() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* ignore */ } }

// ---------- Audio (all synthesized, no asset files) ----------
const Sound = {
  ctx: null, master: null, sfx: null, music: null, noiseBuf: null, last: {}, gemCombo: 0, gemT: 0,
  init() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    this.ctx = new AC();
    this.master = this.ctx.createGain(); this.master.connect(this.ctx.destination);
    const comp = this.ctx.createDynamicsCompressor(); comp.connect(this.master);
    this.sfx = this.ctx.createGain(); this.sfx.connect(comp);
    const lp = this.ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2600; lp.connect(this.master);
    this.music = this.ctx.createGain(); this.music.connect(lp);
    const len = this.ctx.sampleRate; this.noiseBuf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const d = this.noiseBuf.getChannelData(0); for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    this.applyVolumes();
    this.startMusic();
  },
  applyVolumes() {
    if (!this.ctx) return;
    this.sfx.gain.value = (save.settings.sfx / 10) * 0.9;
    this.music.gain.value = (save.settings.music / 10) * 0.55;
  },
  tone(freq, dur, type = 'sine', vol = 0.1, slide = 1, when = 0, dest) {
    const c = this.ctx, t = c.currentTime + when;
    const o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.setValueAtTime(freq, t);
    if (slide !== 1) o.frequency.exponentialRampToValueAtTime(Math.max(20, freq * slide), t + dur);
    g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(vol, t + 0.005);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(dest || this.sfx); o.start(t); o.stop(t + dur + 0.05);
  },
  noise(dur, vol, freq = 2000, type = 'lowpass', when = 0, dest) {
    const c = this.ctx, t = c.currentTime + when;
    const s = c.createBufferSource(); s.buffer = this.noiseBuf;
    const f = c.createBiquadFilter(); f.type = type; f.frequency.value = freq;
    const g = c.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(f); f.connect(g); g.connect(dest || this.sfx); s.start(t, Math.random() * 0.5, dur + 0.05);
  },
  play(name) {
    if (!this.ctx || save.settings.sfx <= 0) return;
    const now = performance.now();
    const gap = { hit: 45, kill: 35, shoot: 60, gem: 28, zap: 70, explode: 60, pulse: 80, coin: 40, hurt: 120 }[name] || 0;
    if (gap && this.last[name] && now - this.last[name] < gap) return;
    this.last[name] = now;
    switch (name) {
      case 'shoot': this.tone(rand(620, 700), 0.07, 'triangle', 0.05, 0.55); break;
      case 'hit': this.noise(0.04, 0.05, 2500); this.tone(rand(180, 220), 0.05, 'square', 0.02, 0.6); break;
      case 'kill': this.tone(rand(280, 340), 0.08, 'square', 0.03, 0.45); break;
      case 'gem': {
        if (now - this.gemT > 450) this.gemCombo = 0; this.gemT = now; this.gemCombo = Math.min(this.gemCombo + 1, 30);
        this.tone(520 * Math.pow(2, this.gemCombo / 24), 0.07, 'sine', 0.06, 1.4); break;
      }
      case 'coin': this.tone(1320, 0.05, 'square', 0.03); this.tone(1760, 0.09, 'square', 0.03, 1, 0.05); break;
      case 'pickup': this.tone(600, 0.15, 'sine', 0.1, 2); break;
      case 'levelup': [523, 659, 784, 1047].forEach((f, i) => this.tone(f, 0.18, 'triangle', 0.09, 1, i * 0.07)); break;
      case 'chest': [392, 523, 659, 784, 1047, 1319].forEach((f, i) => this.tone(f, 0.22, 'triangle', 0.08, 1, i * 0.06)); break;
      case 'hurt': this.tone(170, 0.2, 'sawtooth', 0.12, 0.5); this.noise(0.15, 0.12, 900); break;
      case 'pulse': this.tone(240, 0.35, 'sine', 0.13, 2.2); this.noise(0.25, 0.06, 700); break;
      case 'explode': this.noise(0.35, 0.18, 800); this.tone(95, 0.3, 'sine', 0.2, 0.4); break;
      case 'zap': this.noise(0.1, 0.06, 5000, 'highpass'); this.tone(1100, 0.09, 'sawtooth', 0.03, 0.3); break;
      case 'freeze': this.tone(1500, 0.12, 'sine', 0.05, 0.6); this.noise(0.1, 0.04, 6000, 'highpass'); break;
      case 'whoosh': this.noise(0.25, 0.07, 1200, 'bandpass'); break;
      case 'boss': this.tone(55, 1.6, 'sawtooth', 0.16, 0.8); this.tone(82, 1.6, 'sawtooth', 0.1, 0.8); this.noise(1.2, 0.12, 400); break;
      case 'bossShot': this.tone(330, 0.25, 'square', 0.05, 0.5); break;
      case 'dash': this.noise(0.4, 0.14, 600, 'bandpass'); this.tone(120, 0.4, 'sawtooth', 0.08, 2); break;
      case 'ach': this.tone(784, 0.2, 'triangle', 0.1); this.tone(1175, 0.35, 'triangle', 0.1, 1, 0.12); break;
      case 'click': this.tone(520, 0.05, 'triangle', 0.06); break;
      case 'buy': this.tone(660, 0.08, 'triangle', 0.08); this.tone(990, 0.12, 'triangle', 0.08, 1, 0.07); break;
      case 'deny': this.tone(140, 0.15, 'square', 0.06); break;
      case 'death': this.tone(220, 1.2, 'sawtooth', 0.12, 0.25); this.noise(1.0, 0.12, 500); break;
      case 'victory': [523, 659, 784, 1047, 784, 1047, 1319].forEach((f, i) => this.tone(f, 0.4, 'triangle', 0.09, 1, i * 0.12)); break;
    }
  },
  // --- Procedural music: a moody minor progression that intensifies with the night ---
  step: 0, nextT: 0, timer: null,
  startMusic() {
    this.nextT = this.ctx.currentTime + 0.1;
    if (!this.timer) this.timer = setInterval(() => this.schedule(), 50);
  },
  schedule() {
    if (!this.ctx || this.ctx.state !== 'running') return;
    const sp = 60 / 100 / 2;
    while (this.nextT < this.ctx.currentTime + 0.25) {
      this.musicStep(this.step, this.nextT - this.ctx.currentTime);
      this.nextT += sp; this.step++;
    }
  },
  musicStep(step, when) {
    if (save.settings.music <= 0) return;
    const chords = [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]];
    const bar = Math.floor(step / 8) % 4, ch = chords[bar], root = 110 * Math.pow(2, ch[0] / 12);
    const playing = G.state === 'play' && run && !run.over;
    const intensity = playing ? Math.min(3, Math.floor(run.time / 150) + (run.bosses.length ? 1 : 0)) : 0;
    const dest = this.music;
    if (step % 8 === 0) { this.tone(root / 2, 2.4, 'triangle', 0.16, 1, when, dest); this.tone(root, 2.4, 'sine', 0.05, 1, when, dest); }
    const arp = [0, 1, 2, 3, 2, 1, 0, 2][step % 8];
    const semis = arp === 3 ? ch[0] + 12 : ch[arp];
    if (!(step % 2) || intensity >= 1) this.tone(220 * Math.pow(2, semis / 12) * 2, 0.35, 'sine', 0.035, 1, when, dest);
    if (playing) {
      if (step % 4 === 0 || (intensity >= 3 && step % 2 === 0)) this.tone(130, 0.18, 'sine', 0.22, 0.3, when, dest);
      if (intensity >= 1 && step % 2 === 1) this.noise(0.04, 0.05, 7000, 'highpass', when, dest);
      if (intensity >= 2 && step % 8 === 4) this.noise(0.16, 0.12, 1500, 'bandpass', when, dest);
    }
  },
};

// ---------- Canvas ----------
const canvas = $('game');
const ctx = canvas.getContext('2d');
let W = 0, H = 0, DPR = 1, ZOOM = 1, VW = 0, VH = 0;
const darkC = document.createElement('canvas');
const dctx = darkC.getContext('2d');
function resize() {
  DPR = Math.min(2, window.devicePixelRatio || 1);
  W = window.innerWidth; H = window.innerHeight;
  canvas.width = Math.floor(W * DPR); canvas.height = Math.floor(H * DPR);
  canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
  ZOOM = clamp(Math.max(W, H) / 1500, 0.6, 1.6);
  VW = W / ZOOM; VH = H / ZOOM;
  darkC.width = Math.ceil(W / 2); darkC.height = Math.ceil(H / 2);
}
window.addEventListener('resize', resize);
resize();

// ---------- Sprite factory ----------
const glowCache = {};
function glow(color, r) {
  r = Math.max(2, Math.round(r));
  const k = color + r; if (glowCache[k]) return glowCache[k];
  const c = document.createElement('canvas'); c.width = c.height = r * 2;
  const g = c.getContext('2d'); const gr = g.createRadialGradient(r, r, 0, r, r, r);
  gr.addColorStop(0, rgba(mix(color, '#ffffff', 0.7), 1)); gr.addColorStop(0.18, rgba(color, 0.9));
  gr.addColorStop(0.45, rgba(color, 0.3)); gr.addColorStop(1, rgba(color, 0));
  g.fillStyle = gr; g.fillRect(0, 0, r * 2, r * 2);
  return (glowCache[k] = c);
}
function makeSprite(r, color, draw, white) {
  const half = Math.ceil(r * 1.7) + 10, size = half * 2;
  const c = document.createElement('canvas'); c.width = c.height = size;
  const g = c.getContext('2d'); g.translate(half, half);
  if (white) g.fillStyle = '#ffffff';
  else {
    const gr = g.createRadialGradient(-r * 0.3, -r * 0.45, r * 0.1, 0, 0, r * 1.3);
    gr.addColorStop(0, mix(color, '#ffffff', 0.45)); gr.addColorStop(0.55, color); gr.addColorStop(1, mix(color, '#000000', 0.55));
    g.fillStyle = gr; g.shadowColor = color; g.shadowBlur = 10;
  }
  draw(g, r, color, white);
  return { c, half };
}
const SHAPES = {
  wisp(g, r) {
    g.beginPath(); g.arc(0, 0, r, Math.PI, 0); g.lineTo(r, r * 0.9); g.lineTo(r * 0.5, r * 0.55);
    g.lineTo(0, r * 0.95); g.lineTo(-r * 0.5, r * 0.55); g.lineTo(-r, r * 0.9); g.closePath(); g.fill();
  },
  bat(g, r) {
    g.beginPath(); g.moveTo(0, -r * 0.5); g.lineTo(r * 0.5, -r * 0.8); g.lineTo(r * 1.5, -r * 0.6); g.lineTo(r * 0.9, 0);
    g.lineTo(r * 1.15, r * 0.45); g.lineTo(r * 0.4, r * 0.3); g.lineTo(0, r * 0.8); g.lineTo(-r * 0.4, r * 0.3);
    g.lineTo(-r * 1.15, r * 0.45); g.lineTo(-r * 0.9, 0); g.lineTo(-r * 1.5, -r * 0.6); g.lineTo(-r * 0.5, -r * 0.8); g.closePath(); g.fill();
  },
  brute(g, r, c, white) {
    roundRectPath(g, -r, -r * 0.85, r * 2, r * 1.8, r * 0.45); g.fill();
    g.beginPath(); g.moveTo(-r * 0.8, -r * 0.6); g.lineTo(-r * 1.05, -r * 1.35); g.lineTo(-r * 0.35, -r * 0.8); g.closePath();
    g.moveTo(r * 0.8, -r * 0.6); g.lineTo(r * 1.05, -r * 1.35); g.lineTo(r * 0.35, -r * 0.8); g.closePath(); g.fill();
    if (!white) { g.shadowBlur = 0; g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(-r * 0.6, r * 0.35, r * 1.2, r * 0.15); }
  },
  spitter(g, r, c, white) {
    g.beginPath(); g.arc(0, 0, r, 0, TAU); g.fill();
    if (!white) { g.shadowBlur = 0; g.fillStyle = 'rgba(10,20,5,.8)'; g.beginPath(); g.arc(0, r * 0.35, r * 0.38, 0, TAU); g.fill(); }
  },
  splitter(g, r, c, white) {
    g.beginPath(); g.moveTo(0, -r * 1.2); g.lineTo(r, 0); g.lineTo(0, r * 1.2); g.lineTo(-r, 0); g.closePath(); g.fill();
    if (!white) { g.shadowBlur = 0; g.strokeStyle = 'rgba(0,0,0,.35)'; g.lineWidth = 2; g.beginPath(); g.moveTo(0, -r); g.lineTo(0, r); g.stroke(); }
  },
  ghoul(g, r) {
    g.beginPath(); const n = 9;
    for (let i = 0; i < n * 2; i++) { const a = (i / (n * 2)) * TAU - Math.PI / 2; const rr = i % 2 ? r * 0.72 : r * 1.12; g.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); }
    g.closePath(); g.fill();
  },
  warden(g, r, c, white) {
    SHAPES.brute(g, r, c, white);
    g.beginPath(); for (let i = 0; i < 5; i++) { const x = -r * 0.6 + i * r * 0.3; g.moveTo(x - r * 0.12, -r * 0.8); g.lineTo(x, -r * 1.25); g.lineTo(x + r * 0.12, -r * 0.8); }
    g.fill();
  },
  choir(g, r) {
    SHAPES.wisp(g, r);
    for (const s of [-1, 1]) { g.beginPath(); g.arc(s * r * 1.05, r * 0.1, r * 0.4, 0, TAU); g.fill(); }
  },
  king(g, r) {
    SHAPES.ghoul(g, r);
    g.beginPath(); g.moveTo(-r * 0.7, -r * 0.7);
    for (let i = 0; i <= 6; i++) { const x = -r * 0.7 + i * (r * 1.4 / 6); g.lineTo(x, i % 2 ? -r * 0.95 : -r * 1.55); }
    g.lineTo(r * 0.7, -r * 0.7); g.closePath(); g.fill();
  },
};

// ---------- Content definitions ----------
const ENEMY_TYPES = {
  wisp:     { hp: 9,   speed: 74,  r: 11, dmg: 7,  xp: 1, color: '#8a5cff', shape: 'wisp' },
  bat:      { hp: 5,   speed: 132, r: 9,  dmg: 5,  xp: 1, color: '#ff4d8d', shape: 'bat', erratic: true },
  spitter:  { hp: 20,  speed: 62,  r: 12, dmg: 6,  xp: 2, color: '#8dff5c', shape: 'spitter', ranged: true },
  brute:    { hp: 70,  speed: 46,  r: 20, dmg: 14, xp: 4, color: '#4dc3ff', shape: 'brute', heavy: 0.75 },
  splitter: { hp: 28,  speed: 64,  r: 14, dmg: 9,  xp: 2, color: '#ffc933', shape: 'splitter', splits: true },
  mite:     { hp: 7,   speed: 104, r: 8,  dmg: 5,  xp: 1, color: '#ffdd66', shape: 'splitter', noEyes: true },
  ghoul:    { hp: 110, speed: 60,  r: 17, dmg: 18, xp: 6, color: '#ff7a3d', shape: 'ghoul', heavy: 0.5 },
};
const BOSSES = {
  warden: { name: 'The Ashen Warden', hp: 1800,  r: 42, speed: 74, dmg: 24, xp: 120, color: '#ff3d6e', moves: ['dash', 'dash', 'ring'] },
  choir:  { name: 'The Hollow Choir', hp: 4500,  r: 46, speed: 56, dmg: 22, xp: 220, color: '#a46bff', moves: ['ring', 'summon', 'spiral'] },
  king:   { name: 'The Hollow King',  hp: 22000, r: 62, speed: 64, dmg: 32, xp: 600, color: '#ffd166', moves: ['dash', 'ring', 'summon', 'spiral'] },
};
const BOSS_SCHEDULE = [
  { t: 180, type: 'warden', mult: 1 },
  { t: 360, type: 'choir', mult: 1 },
  { t: 540, type: 'warden', mult: 3.5 },
  { t: 720, type: 'king', mult: 1 },
];
const DAWN_TIME = 720;
const EVENTS = [
  { t: 90,  type: 'bat',   n: 28, msg: 'A swarm approaches!' },
  { t: 250, type: 'wisp',  n: 46, msg: 'They surround you...' },
  { t: 430, type: 'bat',   n: 60, msg: 'A great swarm descends!' },
  { t: 600, type: 'brute', n: 32, msg: 'The night closes in...' },
  { t: 680, type: 'ghoul', n: 40, msg: 'The final hour!' },
];

const sprites = {};
function buildSprites() {
  for (const k in ENEMY_TYPES) { const t = ENEMY_TYPES[k]; const d = SHAPES[t.shape]; sprites[k] = makeSprite(t.r, t.color, d); sprites[k + '_w'] = makeSprite(t.r, t.color, d, true); }
  for (const k in BOSSES) { const b = BOSSES[k]; sprites[k] = makeSprite(b.r, b.color, SHAPES[k]); sprites[k + '_w'] = makeSprite(b.r, b.color, SHAPES[k], true); }
}

// --- Weapons ---
// up[i] describes the upgrade to level i+2.
const WEAPONS = {
  bolt: {
    name: 'Ember Bolt', color: '#ffaa44', max: 6,
    desc: 'Hurls homing embers at the nearest enemies.',
    up: ['+5 Damage', '+1 Ember', '+1 Pierce', '+1 Ember', '+10 Damage, faster casting'],
    update(w, dt) {
      w.cd -= dt; if (w.cd > 0) return;
      const L = w.lvl, n = 1 + (L >= 3) + (L >= 5) + P.amount;
      const tg = nearestEnemies(P.x, P.y, n, 560);
      if (!tg.length) { w.cd = 0.1; return; }
      w.cd = (L >= 6 ? 0.62 : 0.95) * P.cd;
      const dmg = 10 + (L >= 2 ? 5 : 0) + (L >= 6 ? 10 : 0);
      for (let i = 0; i < n; i++) {
        const e = tg[i % tg.length]; let a = Math.atan2(e.y - P.y, e.x - P.x);
        if (i >= tg.length) a += (i - tg.length + 1) * 0.2 * (i % 2 ? 1 : -1);
        spawnProj({ kind: 'bolt', w, x: P.x, y: P.y, a, speed: 540, r: 7 * Math.sqrt(P.area), dmg, pierce: 1 + (L >= 4), life: 1.3, color: '#ffaa44', home: e });
      }
      Sound.play('shoot');
    },
  },
  halo: {
    name: 'Sun Halo', color: '#ffd24a', max: 6,
    desc: 'Orbs of flame circle around you, scorching all they touch.',
    up: ['+1 Orb', '+35% Damage', '+1 Orb, +15% Radius', '+35% Damage, faster spin', '+2 Orbs'],
    update(w, dt) {
      const L = w.lvl;
      const n = [2, 3, 3, 4, 4, 6][L - 1] + P.amount;
      const dmg = [8, 8, 11, 11, 15, 15][L - 1];
      const rad = [72, 72, 72, 83, 83, 83][L - 1] * P.area;
      const spin = [2.6, 2.6, 2.6, 2.6, 3.6, 3.6][L - 1];
      const orbR = 12 * Math.sqrt(P.area);
      w.ang = (w.ang || 0) + spin * dt;
      w.orbs = w.orbs || []; w.orbs.length = n;
      for (let i = 0; i < n; i++) {
        const a = w.ang + (i / n) * TAU, ox = P.x + Math.cos(a) * rad, oy = P.y + Math.sin(a) * rad;
        w.orbs[i] = { x: ox, y: oy, r: orbR };
        for (const e of query(ox, oy, orbR, qbuf)) {
          if ((e.hitCd.halo || 0) > run.time) continue;
          e.hitCd.halo = run.time + 0.45;
          const dx = e.x - P.x, dy = e.y - P.y, d = Math.hypot(dx, dy) || 1;
          hurtEnemy(e, dmg, dx / d, dy / d, 140, w);
        }
      }
    },
  },
  pulse: {
    name: 'Lantern Pulse', color: '#ff6bd6', max: 6,
    desc: 'Releases a burst of light that damages and repels nearby foes.',
    up: ['+15% Radius', '+8 Damage', '-15% Cooldown', '+15% Radius, +8 Damage', 'Pulses twice'],
    fire(w) {
      const L = w.lvl;
      const rad = [100, 115, 115, 115, 132, 132][L - 1] * P.area;
      const dmg = [15, 15, 23, 23, 31, 31][L - 1];
      aoe(P.x, P.y, rad, dmg, 300, '#ff6bd6', w);
      Sound.play('pulse');
    },
    update(w, dt) {
      const L = w.lvl;
      if (w.second > 0) { w.second -= dt; if (w.second <= 0) this.fire(w); }
      w.cd -= dt; if (w.cd > 0) return;
      const rad = [100, 115, 115, 115, 132, 132][L - 1] * P.area;
      if (!nearestEnemies(P.x, P.y, 1, rad).length) { w.cd = 0.2; return; }
      w.cd = (L >= 4 ? 2.55 : 3) * P.cd;
      this.fire(w);
      if (L >= 6) w.second = 0.3;
    },
  },
  arc: {
    name: 'Storm Arc', color: '#7fd8ff', max: 6,
    desc: 'Lightning that leaps from enemy to enemy.',
    up: ['+1 Chain', '+6 Damage', '+2 Chains', '-20% Cooldown', '+2 Chains, +8 Damage'],
    update(w, dt) {
      w.cd -= dt; if (w.cd > 0) return;
      const L = w.lvl;
      const chains = [3, 4, 4, 6, 6, 8][L - 1] + P.amount * 2;
      const dmg = [14, 14, 20, 20, 20, 28][L - 1];
      const first = nearestEnemies(P.x, P.y, 1, 420)[0];
      if (!first) { w.cd = 0.15; return; }
      w.cd = (L >= 5 ? 1.2 : 1.5) * P.cd;
      const hit = new Set(); const pts = [[P.x, P.y - 6]];
      let cur = first;
      for (let i = 0; i < chains && cur; i++) {
        hit.add(cur.id); pts.push([cur.x, cur.y]);
        const cx = cur.x, cy = cur.y;
        hurtEnemy(cur, dmg, 0, 0, 0, w);
        let best = null, bd = 1e12;
        for (const e of query(cx, cy, 170 * P.area, qbuf)) {
          if (hit.has(e.id) || e.dead) continue;
          const dd = dist2(cx, cy, e.x, e.y); if (dd < bd) { bd = dd; best = e; }
        }
        cur = best;
      }
      run.fx.push({ kind: 'bolt', pts: jaggedPath(pts), life: 0.18, max: 0.18, color: '#7fd8ff' });
      Sound.play('zap');
    },
  },
  scythe: {
    name: 'Moon Scythe', color: '#c9a0ff', max: 6,
    desc: 'Spectral blades fly out in your path and return to you.',
    up: ['+8 Damage', '+1 Scythe', '+25% Size', '+1 Scythe, +8 Damage', '+12 Damage, faster throws'],
    update(w, dt) {
      w.cd -= dt; if (w.cd > 0) return;
      const L = w.lvl;
      const n = [1, 1, 2, 2, 3, 3][L - 1] + P.amount;
      const dmg = [18, 26, 26, 26, 34, 46][L - 1];
      const size = (L >= 4 ? 1.25 : 1) * Math.sqrt(P.area);
      w.cd = (L >= 6 ? 1.3 : 1.7) * P.cd;
      const tgt = nearestEnemies(P.x, P.y, 1, 420)[0];
      const base = tgt ? Math.atan2(tgt.y - P.y, tgt.x - P.x) + rand(-0.25, 0.25) : Math.atan2(P.fy, P.fx);
      for (let i = 0; i < n; i++) {
        const a = base + (i - (n - 1) / 2) * 0.55;
        spawnProj({ kind: 'scythe', w, x: P.x, y: P.y, a, speed: 560, r: 20 * size, dmg, pierce: Infinity, life: 3, color: '#c9a0ff', rot: 0, hitT: new Map() });
      }
      Sound.play('whoosh');
    },
  },
  mines: {
    name: 'Lantern Seeds', color: '#9dff5c', max: 6,
    desc: 'Plants seeds of fire that burst when enemies draw near.',
    up: ['+10 Damage', '+1 Seed', '+20% Blast Radius', '-20% Cooldown', '+1 Seed, +20 Damage'],
    update(w, dt) {
      w.cd -= dt; if (w.cd > 0) return;
      const L = w.lvl;
      const n = [1, 1, 2, 2, 2, 3][L - 1] + P.amount;
      w.cd = (L >= 5 ? 1.76 : 2.2) * P.cd;
      const active = run.projs.reduce((c, p) => c + (p.kind === 'mine' && !p.dead), 0);
      if (active >= 8 + L * 2) return;
      for (let i = 0; i < n; i++) {
        const a = Math.random() * TAU, d = rand(20, 110);
        spawnProj({ kind: 'mine', w, x: P.x + Math.cos(a) * d, y: P.y + Math.sin(a) * d, a: 0, speed: 0, r: 10,
          dmg: [22, 30, 30, 30, 30, 45][L - 1], blast: (L >= 4 ? 80 : 66) * P.area, life: 6, arm: 0.45, color: '#9dff5c' });
      }
    },
  },
  frost: {
    name: 'Frost Shards', color: '#a0e9ff', max: 6,
    desc: 'Bursts icy shards in every direction, slowing enemies.',
    up: ['+2 Shards', '+5 Damage', '+1 Pierce', '+4 Shards', '+8 Damage, -20% Cooldown'],
    update(w, dt) {
      w.cd -= dt; if (w.cd > 0) return;
      const L = w.lvl;
      if (!nearestEnemies(P.x, P.y, 1, 480).length) { w.cd = 0.15; return; }
      const n = [6, 8, 8, 8, 12, 12][L - 1] + P.amount * 2;
      const dmg = [12, 12, 18, 18, 18, 28][L - 1];
      w.cd = (L >= 6 ? 1.6 : 2.0) * P.cd;
      w.rot = (w.rot || 0) + 0.35;
      for (let i = 0; i < n; i++) {
        spawnProj({ kind: 'frost', w, x: P.x, y: P.y, a: w.rot + (i / n) * TAU, speed: 420, r: 7 * Math.sqrt(P.area), dmg, pierce: L >= 4 ? 4 : 3, life: 1.0, color: '#a0e9ff' });
      }
      Sound.play('freeze');
    },
  },
};

const PASSIVES = {
  vigor:   { name: 'Hearthstone', color: '#ff5d73', desc: '+20% Max HP', max: 5 },
  swift:   { name: 'Wind Boots',  color: '#7cf5c8', desc: '+8% Move Speed', max: 5 },
  might:   { name: 'Ember Heart', color: '#ff8a3d', desc: '+10% Damage', max: 5 },
  haste:   { name: 'Hourglass',   color: '#ffd166', desc: '-7% Cooldowns', max: 5 },
  reach:   { name: 'Wide Lens',   color: '#b38cff', desc: '+10% Area', max: 5 },
  multi:   { name: 'Twin Wick',   color: '#ffe08a', desc: '+1 Projectile', max: 2 },
  magnet:  { name: 'Lodestone',   color: '#6ec6ff', desc: '+30% Pickup Range', max: 5 },
  wisdom:  { name: 'Old Tome',    color: '#c4f07a', desc: '+8% XP Gain', max: 5 },
  plating: { name: 'Iron Ward',   color: '#b0b8c8', desc: '+1 Armor', max: 5 },
  renewal: { name: 'Sap Vial',    color: '#7dff9a', desc: '+0.3 HP/s Recovery', max: 5 },
  luck:    { name: 'Four-Leaf',   color: '#5dff8f', desc: '+10% Luck', max: 5 },
  light:   { name: 'Bright Oil',  color: '#fff3b0', desc: '+15% Light Radius. Enemies in your light take +15% damage.', max: 3 },
};

const CHARS = {
  keeper:    { name: 'The Keeper',     weapon: 'bolt',   color: '#ffb347', desc: 'Balanced in all things.' },
  warden:    { name: 'The Warden',     weapon: 'halo',   color: '#ff7b54', desc: '+30% HP, +1 Armor, -10% Speed.', hp: 1.3, armor: 1, speed: 0.9, unlock: 'ACH_SURVIVE_5' },
  reaper:    { name: 'The Reaper',     weapon: 'scythe', color: '#c77dff', desc: '+15% Damage, +10% Speed, -25% HP.', hp: 0.75, might: 1.15, speed: 1.1, unlock: 'ACH_BOSS' },
  seer:      { name: 'The Seer',       weapon: 'arc',    color: '#5ce1e6', desc: '+25% XP gain, -20% HP.', hp: 0.8, growth: 0.25, unlock: 'ACH_KILLS_1000' },
  alchemist: { name: 'The Alchemist',  weapon: 'mines',  color: '#9dff5c', desc: '+20% Area, +10% Luck.', area: 1.2, luck: 0.1, unlock: 'ACH_SURVIVE_10' },
  saint:     { name: 'The Pale Saint', weapon: 'frost',  color: '#a0d8ff', desc: '-15% Cooldowns, -15% HP.', hp: 0.85, cd: 0.85, unlock: 'ACH_DAWN' },
  ember:     { name: 'The Ember Child', weapon: 'pulse', color: '#ff6bd6', desc: '+1 Projectile, +20% Light, -10% Damage.', amount: 1, light: 1.2, might: 0.9, unlock: 'ACH_ENDLESS_20' },
};

const SHOP = [
  { id: 'hp',     name: 'Vitality',     desc: '+10 Max HP',          max: 5, base: 60 },
  { id: 'might',  name: 'Might',        desc: '+5% Damage',          max: 5, base: 100 },
  { id: 'armor',  name: 'Armor',        desc: '+1 Armor',            max: 3, base: 150 },
  { id: 'regen',  name: 'Recovery',     desc: '+0.1 HP/s',           max: 5, base: 80 },
  { id: 'speed',  name: 'Swiftness',    desc: '+4% Move Speed',      max: 3, base: 90 },
  { id: 'cd',     name: 'Haste',        desc: '-3% Cooldowns',       max: 3, base: 200 },
  { id: 'area',   name: 'Reach',        desc: '+4% Area',            max: 3, base: 150 },
  { id: 'magnet', name: 'Attraction',   desc: '+15% Pickup Range',   max: 3, base: 50 },
  { id: 'growth', name: 'Growth',       desc: '+4% XP Gain',         max: 5, base: 120 },
  { id: 'greed',  name: 'Greed',        desc: '+10% Embers earned',  max: 5, base: 80 },
  { id: 'luck',   name: 'Luck',         desc: '+5% Luck',            max: 3, base: 120 },
  { id: 'reroll', name: 'Fate',         desc: '+1 Reroll per run',   max: 3, base: 150 },
  { id: 'revive', name: 'Second Flame', desc: 'Revive once per run', max: 1, base: 1000 },
];
const shopCost = (it, l) => Math.round(it.base * (1 + l) * Math.pow(1.35, l));

const ACHIEVEMENTS = [
  { id: 'ACH_FIRST_NIGHT',  name: 'First Night',         desc: 'Finish your first run.' },
  { id: 'ACH_SURVIVE_5',    name: 'Holding the Line',    desc: 'Survive for 5 minutes.' },
  { id: 'ACH_SURVIVE_10',   name: 'Deep Night',          desc: 'Survive for 10 minutes.' },
  { id: 'ACH_BOSS',         name: 'Wardenbane',          desc: 'Defeat a boss.' },
  { id: 'ACH_DAWN',         name: 'Dawnbringer',         desc: 'Defeat the Hollow King and bring the dawn.' },
  { id: 'ACH_ENDLESS_20',   name: 'Endless Night',       desc: 'Survive for 20 minutes.' },
  { id: 'ACH_KILLS_1000',   name: 'Thousand Shadows',    desc: 'Defeat 1,000 enemies in a single run.' },
  { id: 'ACH_KILLS_TOTAL',  name: 'Lightkeeper',         desc: 'Defeat 10,000 enemies in total.' },
  { id: 'ACH_LEVEL_30',     name: 'Radiant',             desc: 'Reach level 30 in a single run.' },
  { id: 'ACH_MAX_WEAPON',   name: 'Perfected',           desc: 'Upgrade a weapon to its maximum level.' },
  { id: 'ACH_ARSENAL',      name: 'Full Arsenal',        desc: 'Hold 6 weapons at once.' },
  { id: 'ACH_RICH',         name: 'Hoarder',             desc: 'Have 2,000 Embers saved.' },
  { id: 'ACH_NO_HIT_3',     name: 'Untouchable',         desc: 'Survive the first 3 minutes without taking damage.' },
  { id: 'ACH_ALL_CHARS',    name: 'Fellowship of Flame', desc: 'Unlock every Keeper.' },
];
const isCharUnlocked = (id) => !CHARS[id].unlock || !!save.ach[CHARS[id].unlock];

// ---------- Icons (drawn procedurally so the game ships with zero asset files) ----------
const ICON_DRAW = {
  bolt(g) { g.beginPath(); g.arc(5, -5, 11, 0, TAU); g.fill(); g.beginPath(); g.moveTo(-3, 3); g.lineTo(-20, 20); g.lineTo(1, -10); g.lineTo(14, 4); g.closePath(); g.globalAlpha = 0.6; g.fill(); },
  halo(g) { g.beginPath(); g.arc(0, 0, 15, 0, TAU); g.stroke(); for (let i = 0; i < 3; i++) { const a = i / 3 * TAU; g.beginPath(); g.arc(Math.cos(a) * 15, Math.sin(a) * 15, 6, 0, TAU); g.fill(); } },
  pulse(g) { for (const r of [6, 13, 20]) { g.beginPath(); g.arc(0, 0, r, 0, TAU); g.globalAlpha = 1.2 - r / 22; g.stroke(); } },
  arc(g) { g.beginPath(); g.moveTo(6, -22); g.lineTo(-8, 2); g.lineTo(3, 2); g.lineTo(-6, 22); g.lineTo(10, -4); g.lineTo(-1, -4); g.closePath(); g.fill(); },
  scythe(g) { g.beginPath(); g.arc(0, 0, 18, -2.4, 1.1); g.arc(6, -4, 13, 1.0, -2.2, true); g.closePath(); g.fill(); },
  mines(g) { g.beginPath(); g.arc(0, 0, 10, 0, TAU); g.fill(); for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; g.beginPath(); g.moveTo(Math.cos(a) * 12, Math.sin(a) * 12); g.lineTo(Math.cos(a) * 19, Math.sin(a) * 19); g.stroke(); } },
  frost(g) { for (let i = 0; i < 3; i++) { g.save(); g.rotate(i / 3 * Math.PI); g.beginPath(); g.moveTo(0, -20); g.lineTo(0, 20); g.moveTo(-6, -14); g.lineTo(0, -8); g.lineTo(6, -14); g.moveTo(-6, 14); g.lineTo(0, 8); g.lineTo(6, 14); g.stroke(); g.restore(); } },
  vigor(g) { g.beginPath(); g.moveTo(0, 18); g.bezierCurveTo(-26, 0, -12, -22, 0, -8); g.bezierCurveTo(12, -22, 26, 0, 0, 18); g.fill(); },
  swift(g) { g.lineWidth = 5; for (const x of [-10, 4]) { g.beginPath(); g.moveTo(x, -14); g.lineTo(x + 12, 0); g.lineTo(x, 14); g.stroke(); } },
  might(g) { g.beginPath(); g.moveTo(0, -22); g.quadraticCurveTo(14, -6, 10, 8); g.quadraticCurveTo(6, 20, 0, 20); g.quadraticCurveTo(-6, 20, -10, 8); g.quadraticCurveTo(-12, -2, -4, -8); g.quadraticCurveTo(-2, 0, 0, -22); g.fill(); },
  haste(g) { g.beginPath(); g.moveTo(-12, -18); g.lineTo(12, -18); g.lineTo(-12, 18); g.lineTo(12, 18); g.closePath(); g.stroke(); g.beginPath(); g.moveTo(-6, 13); g.lineTo(6, 13); g.lineTo(0, 4); g.closePath(); g.fill(); },
  reach(g) { g.beginPath(); g.arc(0, 0, 8, 0, TAU); g.fill(); for (let i = 0; i < 4; i++) { g.save(); g.rotate(i * Math.PI / 2); g.beginPath(); g.moveTo(0, -12); g.lineTo(0, -21); g.moveTo(-5, -16); g.lineTo(0, -21); g.lineTo(5, -16); g.stroke(); g.restore(); } },
  multi(g) { for (const [x, y] of [[0, -11], [-11, 8], [11, 8]]) { g.beginPath(); g.arc(x, y, 7, 0, TAU); g.fill(); } },
  magnet(g) { g.lineWidth = 7; g.beginPath(); g.arc(0, 0, 12, Math.PI, 0, true); g.moveTo(-12, 0); g.lineTo(-12, -14); g.moveTo(12, 0); g.lineTo(12, -14); g.stroke(); },
  wisdom(g) { g.beginPath(); g.moveTo(-20, 0); g.quadraticCurveTo(0, -18, 20, 0); g.quadraticCurveTo(0, 18, -20, 0); g.stroke(); g.beginPath(); g.arc(0, 0, 6, 0, TAU); g.fill(); },
  plating(g) { g.beginPath(); g.moveTo(0, -20); g.lineTo(17, -12); g.quadraticCurveTo(16, 10, 0, 21); g.quadraticCurveTo(-16, 10, -17, -12); g.closePath(); g.fill(); },
  renewal(g) { g.fillRect(-5, -18, 10, 36); g.fillRect(-18, -5, 36, 10); },
  luck(g) { for (const [x, y] of [[0, -8], [8, 0], [0, 8], [-8, 0]]) { g.beginPath(); g.arc(x, y, 8, 0, TAU); g.fill(); } },
  light(g) { g.beginPath(); g.moveTo(-9, -12); g.lineTo(9, -12); g.lineTo(12, 14); g.lineTo(-12, 14); g.closePath(); g.stroke(); g.beginPath(); g.arc(0, 2, 5, 0, TAU); g.fill(); g.beginPath(); g.moveTo(-5, -12); g.lineTo(0, -19); g.lineTo(5, -12); g.stroke(); },
};
const iconCache = {}, iconURL = {};
function getIcon(id) {
  if (iconCache[id]) return iconCache[id];
  const size = 64, c = document.createElement('canvas'); c.width = c.height = size;
  const g = c.getContext('2d'); const def = WEAPONS[id] || PASSIVES[id];
  g.fillStyle = '#1a1328'; roundRectPath(g, 3, 3, size - 6, size - 6, 13); g.fill();
  g.strokeStyle = rgba(def.color, 0.8); g.lineWidth = 2.5; g.stroke();
  g.save(); g.translate(size / 2, size / 2);
  g.strokeStyle = def.color; g.fillStyle = def.color; g.lineWidth = 4; g.lineCap = 'round'; g.lineJoin = 'round';
  g.shadowColor = def.color; g.shadowBlur = 10;
  ICON_DRAW[id](g); g.restore();
  iconCache[id] = c; iconURL[id] = c.toDataURL();
  return c;
}

// ---------- Background tiles & decor ----------
let groundPattern = null;
const decorSprites = [];
function buildBackground() {
  const s = 256, c = document.createElement('canvas'); c.width = c.height = s;
  const g = c.getContext('2d');
  g.fillStyle = '#0f0c17'; g.fillRect(0, 0, s, s);
  for (let i = 0; i < 260; i++) { g.fillStyle = Math.random() < 0.5 ? '#151120' : '#0b0912'; const r = rand(1, 3.5); g.fillRect(Math.random() * s, Math.random() * s, r, r); }
  g.strokeStyle = 'rgba(60,90,60,0.22)'; g.lineWidth = 1.2;
  for (let i = 0; i < 60; i++) { const x = Math.random() * s, y = Math.random() * s; g.beginPath(); g.moveTo(x, y); g.lineTo(x + rand(-3, 3), y - rand(3, 8)); g.stroke(); }
  groundPattern = ctx.createPattern(c, 'repeat');
  const mk = (w, h, fn) => { const cc = document.createElement('canvas'); cc.width = w; cc.height = h; const gg = cc.getContext('2d'); fn(gg, w, h); decorSprites.push(cc); };
  mk(40, 52, (g, w, h) => { // gravestone
    g.fillStyle = 'rgba(0,0,0,.4)'; g.beginPath(); g.ellipse(20, 48, 16, 4, 0, 0, TAU); g.fill();
    g.fillStyle = '#2a2438'; g.beginPath(); g.moveTo(6, 48); g.lineTo(6, 18); g.arc(20, 18, 14, Math.PI, 0); g.lineTo(34, 48); g.closePath(); g.fill();
    g.fillStyle = '#3a3250'; g.fillRect(17, 16, 6, 20); g.fillRect(12, 21, 16, 5);
  });
  mk(70, 80, (g) => { // dead tree
    g.strokeStyle = '#1f1a2b'; g.lineCap = 'round';
    const br = (x, y, a, l, wd) => { if (l < 5) return; const x2 = x + Math.cos(a) * l, y2 = y + Math.sin(a) * l; g.lineWidth = wd; g.beginPath(); g.moveTo(x, y); g.lineTo(x2, y2); g.stroke(); br(x2, y2, a - 0.5, l * 0.68, wd * 0.65); br(x2, y2, a + 0.45, l * 0.62, wd * 0.65); };
    br(35, 78, -Math.PI / 2, 26, 7);
  });
  mk(40, 26, (g) => { // rocks
    g.fillStyle = '#211c2e'; g.beginPath(); g.ellipse(14, 16, 12, 8, 0, 0, TAU); g.fill();
    g.fillStyle = '#2b2540'; g.beginPath(); g.ellipse(27, 18, 9, 6, 0, 0, TAU); g.fill();
  });
  mk(36, 30, (g) => { // glowing mushrooms
    for (const [x, y, r] of [[10, 20, 6], [22, 16, 8], [30, 23, 4]]) {
      g.fillStyle = '#3a2f4a'; g.fillRect(x - 1.5, y, 3, 8);
      g.shadowColor = '#5ce1e6'; g.shadowBlur = 8; g.fillStyle = '#4fb8c4'; g.beginPath(); g.arc(x, y, r, Math.PI, 0); g.fill(); g.shadowBlur = 0;
    }
  });
}

// ---------- Input ----------
const keys = {};
let lastInput = 'kb';
const gp = { prev: [], navDir: null, navNext: 0, connected: false };
window.addEventListener('keydown', (e) => {
  Sound.init();
  lastInput = 'kb';
  keys[e.code] = true;
  if (e.code === 'F11') { e.preventDefault(); toggleFullscreen(); return; }
  if (e.code === 'Escape' || e.code === 'KeyP') {
    if (G.state === 'play' && (!G.overlay || G.overlay === 'pause')) togglePause();
    else if (G.overlay !== 'level' && G.overlay !== 'victory' && G.overlay !== 'over') goBack();
    return;
  }
  if (uiActive()) {
    const dir = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' }[e.code];
    if (dir) { e.preventDefault(); navigate(dir); }
    if (G.overlay === 'level' && /^Digit[1-4]$/.test(e.code)) { const b = $('cards').children[+e.code.slice(5) - 1]; if (b) b.click(); }
  }
});
window.addEventListener('keyup', (e) => { keys[e.code] = false; });
window.addEventListener('blur', () => { for (const k in keys) keys[k] = false; if (G.state === 'play' && !G.overlay) togglePause(); });
window.addEventListener('pointerdown', () => { Sound.init(); lastInput = 'mouse'; });

function getMove() {
  let x = 0, y = 0;
  if (keys.KeyW || keys.ArrowUp) y -= 1;
  if (keys.KeyS || keys.ArrowDown) y += 1;
  if (keys.KeyA || keys.ArrowLeft) x -= 1;
  if (keys.KeyD || keys.ArrowRight) x += 1;
  if (gp.pad) {
    const ax = gp.pad.axes[0] || 0, ay = gp.pad.axes[1] || 0;
    if (Math.hypot(ax, ay) > 0.2) { x += ax; y += ay; }
    const b = (i) => gp.pad.buttons[i] && gp.pad.buttons[i].pressed;
    if (b(12)) y -= 1; if (b(13)) y += 1; if (b(14)) x -= 1; if (b(15)) x += 1;
  }
  const l = Math.hypot(x, y);
  if (l > 1) { x /= l; y /= l; }
  return { x, y };
}

function pollGamepad() {
  const pads = navigator.getGamepads ? navigator.getGamepads() : [];
  let pad = null; for (const p of pads) if (p && p.connected) { pad = p; break; }
  gp.pad = pad; if (!pad) return;
  const held = (i) => !!(pad.buttons[i] && pad.buttons[i].pressed);
  const pressed = []; for (let i = 0; i < pad.buttons.length; i++) { const h = held(i); pressed[i] = h && !gp.prev[i]; gp.prev[i] = h; }
  if (pressed.some(Boolean) || Math.hypot(pad.axes[0] || 0, pad.axes[1] || 0) > 0.5) { lastInput = 'pad'; Sound.init(); }
  const ax = pad.axes[0] || 0, ay = pad.axes[1] || 0;
  let dir = null;
  if (held(12) || ay < -0.6) dir = 'up'; else if (held(13) || ay > 0.6) dir = 'down';
  else if (held(14) || ax < -0.6) dir = 'left'; else if (held(15) || ax > 0.6) dir = 'right';
  const now = performance.now();
  if (dir && uiActive()) {
    if (dir !== gp.navDir || now > gp.navNext) { navigate(dir); gp.navNext = now + (dir !== gp.navDir ? 380 : 150); }
  }
  gp.navDir = dir;
  if (pressed[9]) { if (G.state === 'play' && (!G.overlay || G.overlay === 'pause')) togglePause(); }
  if (uiActive()) {
    if (pressed[0]) { const el = document.activeElement; if (el && el.tagName === 'BUTTON' && !el.disabled) el.click(); else focusFirst(); }
    if (pressed[1]) { if (G.overlay === 'pause') togglePause(); else if (!G.overlay) goBack(); }
    if (pressed[2] && G.overlay === 'level') $('rerollBtn').click();
  }
}

// ---------- UI navigation (keyboard / gamepad) ----------
function currentScreen() { return document.querySelector('.screen.show'); }
function uiActive() { return !!currentScreen(); }
function focusables() {
  const s = currentScreen(); if (!s) return [];
  return [...s.querySelectorAll('button:not([disabled]), input')].filter((el) => el.offsetParent !== null && !el.closest('.cards.locked'));
}
function focusFirst() { const f = focusables(); if (f.length) f[0].focus({ preventScroll: false }); }
function navigate(dir) {
  const list = focusables(); if (!list.length) return;
  const cur = document.activeElement;
  if (!list.includes(cur)) { list[0].focus(); return; }
  if (cur.type === 'range' && (dir === 'left' || dir === 'right')) {
    cur.value = +cur.value + (dir === 'left' ? -1 : 1) * (+cur.step || 1);
    cur.dispatchEvent(new Event('input', { bubbles: true })); return;
  }
  const r0 = cur.getBoundingClientRect(), cx = r0.left + r0.width / 2, cy = r0.top + r0.height / 2;
  let best = null, bs = Infinity;
  for (const el of list) {
    if (el === cur) continue;
    const r = el.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
    const dx = x - cx, dy = y - cy;
    let main, side;
    if (dir === 'up') { main = -dy; side = Math.abs(dx); } else if (dir === 'down') { main = dy; side = Math.abs(dx); }
    else if (dir === 'left') { main = -dx; side = Math.abs(dy); } else { main = dx; side = Math.abs(dy); }
    if (main <= 4) continue;
    const score = main + side * 2.2;
    if (score < bs) { bs = score; best = el; }
  }
  if (best) { best.focus(); best.scrollIntoView({ block: 'nearest' }); Sound.play('click'); }
}
document.addEventListener('mouseover', (e) => { const b = e.target.closest && e.target.closest('button'); if (b && !b.disabled && lastInput === 'mouse') b.focus({ preventScroll: true }); });
document.addEventListener('mousemove', () => { lastInput = 'mouse'; });

// ---------- Game state ----------
const G = { state: 'menu', overlay: null, paused: false, backFn: null, settingsFrom: 'menu', lastChar: 'keeper', time: 0 };
let run = null, P = null, eid = 0;
const cam = { x: 0, y: 0 };
const qbuf = [];

// ---------- Spatial grid ----------
const CELL = 64;
const grid = new Map();
const gkey = (cx, cy) => cx * 100003 + cy;
function buildGrid() {
  grid.clear();
  for (const e of run.enemies) {
    if (e.dead || e.boss) continue;
    const k = gkey(Math.floor(e.x / CELL), Math.floor(e.y / CELL));
    let a = grid.get(k); if (!a) { a = []; grid.set(k, a); } a.push(e);
  }
}
function query(x, y, r, out) {
  out = out || []; out.length = 0;
  const pad = r + 24;
  const x0 = Math.floor((x - pad) / CELL), x1 = Math.floor((x + pad) / CELL), y0 = Math.floor((y - pad) / CELL), y1 = Math.floor((y + pad) / CELL);
  for (let cx = x0; cx <= x1; cx++) for (let cy = y0; cy <= y1; cy++) {
    const a = grid.get(gkey(cx, cy)); if (!a) continue;
    for (const e of a) { if (!e.dead) { const rr = r + e.r; if (dist2(x, y, e.x, e.y) < rr * rr) out.push(e); } }
  }
  for (const e of run.bosses) { if (!e.dead) { const rr = r + e.r; if (dist2(x, y, e.x, e.y) < rr * rr) out.push(e); } }
  return out;
}
function nearestEnemies(x, y, n, range) {
  const r2 = range * range, list = [];
  for (const e of run.enemies) { if (e.dead) continue; const d = dist2(x, y, e.x, e.y); if (d < r2) list.push([d, e]); }
  if (list.length > n) list.sort((a, b) => a[0] - b[0]);
  const out = []; for (let i = 0; i < Math.min(n, list.length); i++) out.push(list[i][1]);
  return out;
}

// ---------- Run setup ----------
function newRun(charId) {
  G.lastChar = charId;
  const ch = CHARS[charId];
  eid = 0;
  P = { x: 0, y: 0, r: 13, fx: 1, fy: 0, side: 1, moving: false, iframe: 0, level: 1, xp: 0, xpNext: xpFor(1),
    revives: save.shop.revive || 0, rerolls: save.shop.reroll || 0, maxHp: 0, hp: 0, lastHit: -1 };
  run = { char: charId, time: 0, kills: 0, coins: 0, weapons: [], passives: {}, passiveOrder: [], enemies: [], bosses: [], projs: [], eprojs: [],
    gems: [], pickups: [], fx: [], parts: [], nums: [], toasts: [], banner: null, spawnAcc: 0, bossDone: {}, evDone: {}, eliteT: 70,
    shake: 0, hurt: 0, pendingLevels: 0, over: false, won: false, endless: false, dying: 0, victoryT: 0, achT: 1, anyDead: false,
    tookDamage: false, choices: [] };
  recalcStats();
  P.hp = P.maxHp;
  addWeapon(ch.weapon);
  cam.x = 0; cam.y = 0;
  G.state = 'play'; G.overlay = null; G.paused = false;
  hideScreens();
  document.body.classList.add('playing');
  toast('Survive until dawn', '#ffd166');
}
function xpFor(l) { return Math.floor(4 + l * 3 + l * l * 0.2); }
function recalcStats() {
  const c = CHARS[run.char], sh = save.shop, pl = (id) => run.passives[id] || 0;
  const oldMax = P.maxHp;
  P.maxHp = (100 + (sh.hp || 0) * 10) * (c.hp || 1) * (1 + 0.2 * pl('vigor'));
  P.speed = 165 * (1 + (sh.speed || 0) * 0.04) * (c.speed || 1) * (1 + 0.08 * pl('swift'));
  P.might = (1 + (sh.might || 0) * 0.05) * (c.might || 1) * (1 + 0.1 * pl('might'));
  P.cd = (1 - (sh.cd || 0) * 0.03) * (c.cd || 1) * Math.pow(0.93, pl('haste'));
  P.area = (1 + (sh.area || 0) * 0.04) * (c.area || 1) * (1 + 0.1 * pl('reach'));
  P.amount = pl('multi') + (c.amount || 0);
  P.magnet = 80 * (1 + (sh.magnet || 0) * 0.15) * (1 + 0.3 * pl('magnet'));
  P.growth = (1 + (sh.growth || 0) * 0.04 + (c.growth || 0)) * (1 + 0.08 * pl('wisdom'));
  P.armor = (sh.armor || 0) + (c.armor || 0) + pl('plating');
  P.regen = (sh.regen || 0) * 0.1 + 0.3 * pl('renewal');
  P.luck = 1 + (sh.luck || 0) * 0.05 + (c.luck || 0) + 0.1 * pl('luck');
  P.greed = 1 + (sh.greed || 0) * 0.1;
  P.light = 300 * (c.light || 1) * (1 + 0.15 * pl('light'));
  P.lightBonus = pl('light') > 0 ? 1.15 : 1;
  if (oldMax) P.hp = Math.min(P.maxHp, P.hp + Math.max(0, P.maxHp - oldMax));
}
function addWeapon(id) { run.weapons.push({ id, lvl: 1, cd: 0.4, dmg: 0 }); }

// ---------- Spawning ----------
function spawnRadius() { return Math.hypot(VW, VH) / 2 + 50; }
function spawnPoint(scale = 1) { const a = Math.random() * TAU, r = spawnRadius() * scale; return { x: P.x + Math.cos(a) * r, y: P.y + Math.sin(a) * r }; }
function hpScale() { const m = run.time / 60; return 1 + m * 0.22 + m * m * 0.011; }
function spawnEnemy(type, x, y, elite = false) {
  const T = ENEMY_TYPES[type];
  if (x === undefined) { const p = spawnPoint(); x = p.x; y = p.y; }
  const m = run.time / 60, hs = hpScale();
  const e = { id: ++eid, type, x, y, r: T.r * (elite ? 1.45 : 1), hp: T.hp * hs * (elite ? 8 : 1), maxHp: 0,
    speed: T.speed * rand(0.9, 1.1) * (elite ? 0.92 : 1), dmg: T.dmg * (1 + m * 0.07) * (elite ? 1.4 : 1),
    xp: T.xp * (1 + m * 0.08) * (elite ? 12 : 1), kx: 0, ky: 0, flash: 0, slow: 0, hitCd: {}, elite, boss: false,
    t: Math.random() * 10, shootT: rand(1.5, 3), dir: Math.random() < 0.5 ? 1 : -1, heavy: T.heavy || 0 };
  e.maxHp = e.hp;
  run.enemies.push(e);
  return e;
}
function spawnBoss(type, mult) {
  const B = BOSSES[type], p = spawnPoint(0.75);
  const hs = run.endless ? hpScale() / 4 : 1;
  const e = { id: ++eid, type, boss: true, x: p.x, y: p.y, r: B.r, hp: B.hp * mult * hs, maxHp: 0, speed: B.speed,
    dmg: B.dmg * (mult > 1 ? 1.3 : 1) * (run.endless ? 1.5 : 1), xp: B.xp, kx: 0, ky: 0, flash: 0, slow: 0, hitCd: {}, t: 0,
    atk: 2.5, state: null, stT: 0, name: B.name, isKing: type === 'king', heavy: 1 };
  e.maxHp = e.hp;
  run.enemies.push(e); run.bosses.push(e);
  showBanner(B.name.toUpperCase(), 'has awakened', B.color);
  Sound.play('boss'); addShake(14);
}
function pickType(m) {
  return weightedPick([
    { id: 'wisp', weight: Math.max(2, 10 - m * 0.8) },
    { id: 'bat', weight: m >= 0.75 ? 5 : 0 },
    { id: 'spitter', weight: m >= 2 ? 2.5 : 0 },
    { id: 'brute', weight: m >= 3 ? 2 + m * 0.25 : 0 },
    { id: 'splitter', weight: m >= 4 ? 3 : 0 },
    { id: 'ghoul', weight: m >= 7 ? 2 + (m - 7) * 0.6 : 0 },
  ]).id;
}
function ringSpawn(type, n, msg) {
  const r = spawnRadius() * 0.85;
  for (let i = 0; i < n; i++) { const a = (i / n) * TAU; spawnEnemy(type, P.x + Math.cos(a) * r, P.y + Math.sin(a) * r); }
  toast(msg, '#ff7b9a');
}
function director(dt) {
  const t = run.time, m = t / 60;
  for (const b of BOSS_SCHEDULE) if (t >= b.t && !run.bossDone[b.t]) { run.bossDone[b.t] = true; spawnBoss(b.type, b.mult); }
  for (const ev of EVENTS) if (t >= ev.t && !run.evDone[ev.t]) { run.evDone[ev.t] = true; ringSpawn(ev.type, ev.n, ev.msg); }
  if (run.endless) {
    const k = Math.floor((t - DAWN_TIME) / 120);
    if (k >= 1 && !run.bossDone['e' + k]) { run.bossDone['e' + k] = true; spawnBoss(pick(['warden', 'choir', 'king']), 1 + k * 0.5); }
  }
  run.eliteT -= dt;
  if (run.eliteT <= 0) { run.eliteT = Math.max(35, 70 - m * 3); spawnEnemy(pickType(m), undefined, undefined, true); }
  const target = Math.min(500, 22 + t * 0.75);
  const rate = Math.min(45, 1.6 + t / 12) * (run.bosses.length ? 0.6 : 1);
  run.spawnAcc += rate * dt;
  while (run.spawnAcc >= 1) {
    run.spawnAcc -= 1;
    if (run.enemies.length < target) spawnEnemy(pickType(m), undefined, undefined, Math.random() < 0.004);
  }
}

// ---------- Combat ----------
function spawnProj(o) {
  o.vx = Math.cos(o.a) * o.speed; o.vy = Math.sin(o.a) * o.speed;
  o.hit = new Set(); o.t = 0; o.dead = false;
  run.projs.push(o);
}
function fireEBullet(x, y, a, speed, dmg) {
  run.eprojs.push({ x, y, vx: Math.cos(a) * speed, vy: Math.sin(a) * speed, r: 7, dmg, life: 6 });
}
function hurtEnemy(e, base, kx, ky, kb, w) {
  if (e.dead) return;
  let dmg = base * P.might;
  if (P.lightBonus > 1 && dist2(e.x, e.y, P.x, P.y) < P.light * P.light * 0.36) dmg *= P.lightBonus;
  const crit = Math.random() < 0.05 * P.luck;
  if (crit) dmg *= 2;
  dmg *= rand(0.92, 1.08);
  e.hp -= dmg; e.flash = 0.08;
  if (w) w.dmg += Math.min(dmg, dmg + e.hp);
  if (kb && !e.boss) { const k = kb * (1 - e.heavy); e.kx += kx * k; e.ky += ky * k; }
  if (save.settings.dmgNums) addNum(e.x + rand(-6, 6), e.y - e.r, dmg, crit);
  Sound.play('hit');
  if (e.hp <= 0) killEnemy(e);
}
function aoe(x, y, r, dmg, kb, color, w) {
  for (const e of query(x, y, r, [])) {
    const dx = e.x - x, dy = e.y - y, d = Math.hypot(dx, dy) || 1;
    hurtEnemy(e, dmg, dx / d, dy / d, kb, w);
  }
  run.fx.push({ kind: 'ring', x, y, r, life: 0.35, max: 0.35, color });
}
function killEnemy(e) {
  e.dead = true; run.anyDead = true; run.kills++;
  const col = e.boss ? BOSSES[e.type].color : ENEMY_TYPES[e.type].color;
  burst(e.x, e.y, e.boss ? 80 : e.elite ? 24 : 6, col, e.boss ? 360 : 140);
  if (e.boss) {
    Sound.play('explode'); addShake(22);
    dropGem(e.x, e.y, e.xp);
    spawnPickup('chest', e.x, e.y);
    for (let i = 0; i < 12; i++) spawnPickup('coin', e.x + rand(-60, 60), e.y + rand(-60, 60));
    save.totals.bosses++;
    unlockAch('ACH_BOSS');
    if (e.isKing && !run.won) {
      run.won = true; run.victoryT = 2.8; save.totals.wins++;
      unlockAch('ACH_DAWN');
      showBanner('DAWN BREAKS', 'The Hollow King has fallen', '#ffd166');
      Sound.play('victory');
      for (const o of run.enemies) if (!o.boss && !o.dead) { o.dead = true; burst(o.x, o.y, 3, '#ffd166', 120); }
      run.anyDead = true;
    } else showBanner('BOSS DEFEATED', e.name, '#ffd166');
    return;
  }
  Sound.play('kill');
  dropGem(e.x, e.y, e.xp);
  if (e.elite) spawnPickup('chest', e.x, e.y);
  if (ENEMY_TYPES[e.type].splits) for (let i = 0; i < 2; i++) spawnEnemy('mite', e.x + rand(-10, 10), e.y + rand(-10, 10));
  const L = P.luck, r = Math.random();
  if (r < 0.022 * L) spawnPickup('coin', e.x, e.y);
  else if (r < 0.022 * L + 0.0035) spawnPickup('heart', e.x, e.y);
  else if (r < 0.022 * L + 0.0048) spawnPickup('magnet', e.x, e.y);
  else if (r < 0.022 * L + 0.0058) spawnPickup('bomb', e.x, e.y);
}
function damagePlayer(raw) {
  if (P.iframe > 0 || run.over || run.dying > 0 || run.won && run.victoryT > 0) return;
  const d = Math.max(1, raw - P.armor);
  P.hp -= d; P.iframe = 0.5; run.hurt = 1; run.tookDamage = true;
  addShake(7); Sound.play('hurt');
  if (P.hp <= 0) {
    if (P.revives > 0) {
      P.revives--; P.hp = P.maxHp * 0.6; P.iframe = 2.5;
      nuke(true); showBanner('SECOND FLAME', 'You rise again', '#ffb347'); Sound.play('levelup');
    } else {
      P.hp = 0; run.dying = 1.6; Sound.play('death'); burst(P.x, P.y, 60, '#ffb347', 260); addShake(16);
    }
  }
}
function nuke(includeElites) {
  for (const e of run.enemies) {
    if (e.dead || e.boss) continue;
    if (Math.abs(e.x - P.x) < VW / 2 + 40 && Math.abs(e.y - P.y) < VH / 2 + 40 && (includeElites || !e.elite)) killEnemy(e);
  }
  for (const b of run.eprojs) b.life = 0;
  run.fx.push({ kind: 'ring', x: P.x, y: P.y, r: Math.max(VW, VH), life: 0.6, max: 0.6, color: '#fff3b0' });
  Sound.play('explode'); addShake(16);
}
function jaggedPath(pts) {
  const out = [pts[0]];
  for (let i = 1; i < pts.length; i++) {
    const [x0, y0] = pts[i - 1], [x1, y1] = pts[i];
    const segs = 4;
    for (let s = 1; s < segs; s++) { const t = s / segs; out.push([lerp(x0, x1, t) + rand(-9, 9), lerp(y0, y1, t) + rand(-9, 9)]); }
    out.push([x1, y1]);
  }
  return out;
}

// ---------- Pickups / XP ----------
function dropGem(x, y, v) {
  if (run.gems.length > 380) { const g = run.gems[(Math.random() * run.gems.length) | 0]; g.v += v; return; }
  run.gems.push({ x, y, v, mag: false, sp: 0 });
}
function spawnPickup(kind, x, y) { run.pickups.push({ kind, x, y, mag: false, sp: 0, t: Math.random() * 6, v: kind === 'coin' ? randi(1, 3) : 0 }); }
function addXP(v) {
  P.xp += v;
  while (P.xp >= P.xpNext) { P.xp -= P.xpNext; P.level++; P.xpNext = xpFor(P.level); run.pendingLevels++; }
}
function collectPickup(p) {
  switch (p.kind) {
    case 'coin': run.coins += Math.max(1, Math.round(p.v * P.greed)); Sound.play('coin'); break;
    case 'heart': P.hp = Math.min(P.maxHp, P.hp + Math.max(30, P.maxHp * 0.3)); Sound.play('pickup'); toast('+HP', '#ff5d73'); break;
    case 'magnet': for (const g of run.gems) g.mag = true; Sound.play('pickup'); toast('Lodestar!', '#6ec6ff'); break;
    case 'bomb': nuke(false); toast('Flashbang!', '#fff3b0'); break;
    case 'chest': openChest(); break;
  }
  burst(p.x, p.y, 10, '#ffd166', 120);
}
function upgradables() {
  const opts = [];
  for (const w of run.weapons) if (w.lvl < WEAPONS[w.id].max) opts.push({ type: 'w', id: w.id });
  for (const id in run.passives) if (run.passives[id] < PASSIVES[id].max) opts.push({ type: 'p', id });
  return opts;
}
function openChest() {
  const n = Math.random() < 0.1 * P.luck ? 3 : 1, got = [];
  for (let i = 0; i < n; i++) {
    const opts = upgradables(); if (!opts.length) break;
    const o = pick(opts); applyChoice(o);
    const lvl = o.type === 'w' ? run.weapons.find((w) => w.id === o.id).lvl : run.passives[o.id];
    got.push((o.type === 'w' ? WEAPONS[o.id].name : PASSIVES[o.id].name) + ' Lv' + lvl);
  }
  const c = Math.round(randi(10, 25) * P.greed); run.coins += c;
  showBanner(n === 3 ? 'BLESSED TREASURE!' : 'TREASURE!', (got.length ? got.join('  ·  ') + '  ·  ' : '') + '+' + c + ' Embers', '#ffd166');
  Sound.play('chest');
  burst(P.x, P.y, 40, '#ffd166', 260);
}

// ---------- Effects ----------
function burst(x, y, n, color, speed = 140) {
  for (let i = 0; i < n; i++) {
    if (run.parts.length > 700) run.parts.shift();
    const a = Math.random() * TAU, s = rand(0.2, 1) * speed;
    run.parts.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: rand(0.3, 0.7), max: 0.7, size: rand(3, 7), color });
  }
}
function addNum(x, y, v, crit) {
  if (run.nums.length > 90) run.nums.shift();
  run.nums.push({ x, y, v: Math.max(1, Math.round(v)), life: 0.65, crit });
}
function addShake(v) { if (save.settings.shake) run.shake = Math.max(run.shake, v); }
function toast(text, color = '#f3e9ff') { run.toasts.push({ text, color, life: 2.4, max: 2.4 }); if (run.toasts.length > 4) run.toasts.shift(); }
function showBanner(title, sub, color) { run.banner = { title, sub, color, life: 3.2, max: 3.2 }; }

// ---------- Update ----------
function update(dt) {
  const R = run;
  if (R.dying > 0) { R.dying -= dt; dt *= 0.3; if (R.dying <= 0) { endRun('death'); return; } }
  if (R.victoryT > 0) { R.victoryT -= dt; if (R.victoryT <= 0) openVictory(); }
  R.time += dt;

  if (!(R.dying > 0)) {
    const m = getMove();
    P.x += m.x * P.speed * dt; P.y += m.y * P.speed * dt;
    P.moving = !!(m.x || m.y);
    if (P.moving) { const l = Math.hypot(m.x, m.y); P.fx = m.x / l; P.fy = m.y / l; }
    if (m.x) P.side = m.x > 0 ? 1 : -1;
  }
  P.iframe -= dt;
  if (P.hp > 0 && P.hp < P.maxHp) P.hp = Math.min(P.maxHp, P.hp + P.regen * dt);

  if (!R.won || R.endless) director(dt);
  buildGrid();
  if (!(R.dying > 0)) for (const w of R.weapons) WEAPONS[w.id].update(w, dt);
  updateEnemies(dt);
  updateProjs(dt);
  updateEProjs(dt);
  updateGems(dt);
  updatePickups(dt);
  updateFx(dt);

  if (R.anyDead) { R.enemies = R.enemies.filter((e) => !e.dead); R.bosses = R.bosses.filter((e) => !e.dead); R.anyDead = false; }
  R.projs = R.projs.filter((p) => !p.dead);

  const k = 1 - Math.exp(-dt * 10);
  cam.x = lerp(cam.x, P.x, k); cam.y = lerp(cam.y, P.y, k);
  R.shake = Math.max(0, R.shake - dt * 40);
  R.hurt = Math.max(0, R.hurt - dt * 2.2);
  R.achT -= dt; if (R.achT <= 0) { R.achT = 1; runAchChecks(); }
  if (R.pendingLevels > 0 && !G.overlay && !(R.dying > 0) && !R.over) openLevelUp();
}

function updateEnemies(dt) {
  const sr = spawnRadius();
  for (const e of run.enemies) {
    if (e.dead) continue;
    e.t += dt; if (e.flash > 0) e.flash -= dt; if (e.slow > 0) e.slow -= dt;
    let dx = P.x - e.x, dy = P.y - e.y; const dist = Math.hypot(dx, dy) || 1; dx /= dist; dy /= dist;
    let sp = e.speed * (e.slow > 0 ? 0.5 : 1), mx = dx, my = dy;
    if (e.boss) { bossAI(e, dt, dx, dy, dist); mx = e.mx; my = e.my; sp = e.curSpeed; }
    else {
      const T = ENEMY_TYPES[e.type];
      if (T.erratic) { const w = Math.sin(e.t * 5 + e.id) * 0.8; mx = dx - dy * w; my = dy + dx * w; }
      if (T.ranged) {
        if (dist < 220) { mx = -dx; my = -dy; sp *= 0.6; }
        else if (dist < 330) { mx = -dy * e.dir; my = dx * e.dir; sp *= 0.55; }
        e.shootT -= dt;
        if (e.shootT <= 0 && dist < 440) { e.shootT = rand(2.4, 3.4); fireEBullet(e.x, e.y, Math.atan2(dy, dx), 190, e.dmg); }
      }
    }
    const ml = Math.hypot(mx, my) || 1;
    e.x += (mx / ml * sp + e.kx) * dt; e.y += (my / ml * sp + e.ky) * dt;
    const decay = Math.exp(-dt * 9); e.kx *= decay; e.ky *= decay;
    if (!e.boss) {
      separate(e);
      if (dist > sr * 1.5) { const p = spawnPoint(); e.x = p.x; e.y = p.y; }
    } else if (dist > sr * 1.15 && e.state !== 'dash') {
      // Bosses never get left behind: they re-emerge from the dark near the player.
      const p = spawnPoint(0.7); e.x = p.x; e.y = p.y; burst(e.x, e.y, 30, BOSSES[e.type].color, 220);
    }
    if (dist < e.r + P.r - 2) damagePlayer(e.dmg);
  }
}
function separate(e) {
  const a = grid.get(gkey(Math.floor(e.x / CELL), Math.floor(e.y / CELL))); if (!a) return;
  let n = 0;
  for (const o of a) {
    if (o === e || o.dead) continue;
    const dx = e.x - o.x, dy = e.y - o.y, r = e.r + o.r, dd = dx * dx + dy * dy;
    if (dd < r * r && dd > 0.01) { const d = Math.sqrt(dd), push = (r - d) * 0.25; e.x += dx / d * push; e.y += dy / d * push; if (++n > 5) break; }
  }
}
function bossAI(e, dt, dx, dy, dist) {
  const B = BOSSES[e.type];
  e.mx = dx; e.my = dy; e.curSpeed = e.speed;
  const enraged = e.hp < e.maxHp * 0.5;
  if (e.state === 'dashPrep') { e.curSpeed = 0; e.stT -= dt; e.dashX = dx; e.dashY = dy; if (e.stT <= 0) { e.state = 'dash'; e.stT = 0.55; Sound.play('dash'); } return; }
  if (e.state === 'dash') {
    e.mx = e.dashX; e.my = e.dashY; e.curSpeed = enraged ? 640 : 560; e.stT -= dt;
    if (Math.random() < 0.5) burst(e.x, e.y, 1, B.color, 60);
    if (e.stT <= 0) e.state = null; return;
  }
  if (e.spiral > 0) {
    e.spiral -= dt; e.curSpeed = e.speed * 0.3; e.spT = (e.spT || 0) - dt;
    if (e.spT <= 0) { e.spT = 0.09; e.spA = (e.spA || 0) + 0.45; for (let k = 0; k < (enraged ? 3 : 2); k++) fireEBullet(e.x, e.y, e.spA + k * TAU / (enraged ? 3 : 2), 190, e.dmg * 0.5); }
  }
  e.atk -= dt;
  if (e.atk <= 0) {
    const mv = pick(B.moves);
    if (mv === 'dash') { e.state = 'dashPrep'; e.stT = 0.75; e.atk = 3.2; }
    else if (mv === 'ring') {
      const n = e.isKing ? 26 : 18, off = Math.random() * TAU;
      for (let i = 0; i < n; i++) fireEBullet(e.x, e.y, off + (i / n) * TAU, 165, e.dmg * 0.55);
      if (enraged) for (let i = 0; i < n; i++) fireEBullet(e.x, e.y, off + ((i + 0.5) / n) * TAU, 120, e.dmg * 0.55);
      e.atk = 2.6; Sound.play('bossShot');
    } else if (mv === 'summon') {
      for (let i = 0; i < 10; i++) { const a = (i / 10) * TAU; spawnEnemy(e.isKing ? 'ghoul' : 'bat', e.x + Math.cos(a) * 90, e.y + Math.sin(a) * 90); }
      e.atk = 3; burst(e.x, e.y, 30, B.color, 200);
    } else if (mv === 'spiral') { e.spiral = 2.2; e.atk = 3.6; }
    if (enraged) e.atk *= 0.7;
  }
}
function updateProjs(dt) {
  for (const p of run.projs) {
    if (p.dead) continue;
    p.t += dt; p.life -= dt;
    if (p.life <= 0) { if (p.kind === 'mine') explodeMine(p); p.dead = true; continue; }
    if (p.kind === 'bolt') {
      if (p.home && !p.home.dead) {
        const want = Math.atan2(p.home.y - p.y, p.home.x - p.x), cur = Math.atan2(p.vy, p.vx);
        let da = want - cur; while (da > Math.PI) da -= TAU; while (da < -Math.PI) da += TAU;
        const na = cur + clamp(da, -6 * dt, 6 * dt); p.vx = Math.cos(na) * p.speed; p.vy = Math.sin(na) * p.speed;
      }
      if (Math.random() < 0.6) run.parts.push({ x: p.x, y: p.y, vx: rand(-20, 20), vy: rand(-20, 20), life: 0.25, max: 0.25, size: 4, color: '#ff7b3d' });
    } else if (p.kind === 'scythe') {
      p.rot += dt * 16; p.speed -= 900 * dt;
      if (p.speed >= 0) { const a = Math.atan2(p.vy, p.vx); p.vx = Math.cos(a) * p.speed; p.vy = Math.sin(a) * p.speed; }
      else {
        const dx = P.x - p.x, dy = P.y - p.y, d = Math.hypot(dx, dy) || 1, s = Math.min(720, -p.speed + 150);
        p.vx = dx / d * s; p.vy = dy / d * s;
        if (d < 22) { p.dead = true; continue; }
      }
    } else if (p.kind === 'mine') {
      p.arm -= dt;
      if (p.arm <= 0 && query(p.x, p.y, 30, qbuf).length) { explodeMine(p); p.dead = true; }
      continue;
    }
    p.x += p.vx * dt; p.y += p.vy * dt;
    for (const e of query(p.x, p.y, p.r, qbuf)) {
      if (p.kind === 'scythe') {
        const last = p.hitT.get(e.id); if (last !== undefined && run.time - last < 0.4) continue;
        p.hitT.set(e.id, run.time);
        const d = Math.hypot(p.vx, p.vy) || 1; hurtEnemy(e, p.dmg, p.vx / d, p.vy / d, 90, p.w);
        continue;
      }
      if (p.hit.has(e.id)) continue;
      p.hit.add(e.id);
      const d = Math.hypot(p.vx, p.vy) || 1;
      hurtEnemy(e, p.dmg, p.vx / d, p.vy / d, p.kind === 'bolt' ? 120 : 60, p.w);
      if (p.kind === 'frost') e.slow = 1.6;
      burst(p.x, p.y, 2, p.color, 90);
      if (--p.pierce <= 0) { p.dead = true; break; }
    }
  }
}
function explodeMine(p) {
  aoe(p.x, p.y, p.blast, p.dmg, 260, '#9dff5c', p.w);
  burst(p.x, p.y, 18, '#c6ff7a', 220);
  run.fx.push({ kind: 'flash', x: p.x, y: p.y, r: p.blast * 1.2, life: 0.25, max: 0.25, color: '#9dff5c' });
  Sound.play('explode'); addShake(3);
}
function updateEProjs(dt) {
  for (const b of run.eprojs) {
    b.life -= dt; b.x += b.vx * dt; b.y += b.vy * dt;
    const rr = b.r + P.r - 3;
    if (b.life > 0 && dist2(b.x, b.y, P.x, P.y) < rr * rr) { damagePlayer(b.dmg); b.life = 0; burst(b.x, b.y, 6, '#ff4dd2', 100); }
  }
  run.eprojs = run.eprojs.filter((b) => b.life > 0);
}
function updateGems(dt) {
  const m2 = P.magnet * P.magnet;
  for (const g of run.gems) {
    const d = dist2(g.x, g.y, P.x, P.y);
    if (!g.mag && d < m2) g.mag = true;
    if (g.mag) {
      g.sp = Math.min(900, g.sp + 1400 * dt);
      const dd = Math.sqrt(d) || 1;
      g.x += (P.x - g.x) / dd * g.sp * dt; g.y += (P.y - g.y) / dd * g.sp * dt;
      if (dd < P.r + 6) { g.dead = true; addXP(g.v * P.growth); Sound.play('gem'); }
    }
  }
  run.gems = run.gems.filter((g) => !g.dead);
}
function updatePickups(dt) {
  const m2 = Math.pow(P.magnet * 0.8, 2);
  for (const p of run.pickups) {
    p.t += dt;
    const d = dist2(p.x, p.y, P.x, P.y);
    if (!p.mag && d < m2) p.mag = true;
    if (p.mag) {
      p.sp = Math.min(800, p.sp + 1200 * dt); const dd = Math.sqrt(d) || 1;
      p.x += (P.x - p.x) / dd * p.sp * dt; p.y += (P.y - p.y) / dd * p.sp * dt;
      if (dd < P.r + 10) { p.dead = true; collectPickup(p); }
    }
  }
  run.pickups = run.pickups.filter((p) => !p.dead);
}
function updateFx(dt) {
  for (const f of run.fx) f.life -= dt;
  run.fx = run.fx.filter((f) => f.life > 0);
  for (const p of run.parts) { p.life -= dt; p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= 0.92; p.vy *= 0.92; }
  run.parts = run.parts.filter((p) => p.life > 0);
  for (const n of run.nums) { n.life -= dt; n.y -= 40 * dt; }
  run.nums = run.nums.filter((n) => n.life > 0);
  for (const t of run.toasts) t.life -= dt;
  run.toasts = run.toasts.filter((t) => t.life > 0);
  if (run.banner) { run.banner.life -= dt; if (run.banner.life <= 0) run.banner = null; }
}

// ---------- Rendering ----------
function worldBegin(sx = 0, sy = 0) {
  ctx.save();
  ctx.translate(W / 2 + sx, H / 2 + sy); ctx.scale(ZOOM, ZOOM); ctx.translate(-cam.x, -cam.y);
}
function onScreen(x, y, m = 60) { return Math.abs(x - cam.x) < VW / 2 + m && Math.abs(y - cam.y) < VH / 2 + m; }

function drawGround(time) {
  ctx.fillStyle = groundPattern;
  ctx.fillRect(cam.x - VW / 2 - 4, cam.y - VH / 2 - 4, VW + 8, VH + 8);
  const C = 190;
  const x0 = Math.floor((cam.x - VW / 2) / C) - 1, x1 = Math.floor((cam.x + VW / 2) / C) + 1;
  const y0 = Math.floor((cam.y - VH / 2) / C) - 1, y1 = Math.floor((cam.y + VH / 2) / C) + 1;
  for (let cx = x0; cx <= x1; cx++) for (let cy = y0; cy <= y1; cy++) {
    const h = hash2(cx, cy); if (h > 0.22) continue;
    const s = decorSprites[Math.floor(hash2(cy + 7, cx - 3) * decorSprites.length)];
    const ox = hash2(cx * 3, cy) * (C - 70), oy = hash2(cx, cy * 5) * (C - 70);
    ctx.drawImage(s, cx * C + ox, cy * C + oy);
  }
}

function drawKeeper(g, x, y, s, color, side, t, moving) {
  const bob = moving ? Math.sin(t * 12) * 1.5 : Math.sin(t * 2) * 0.8;
  g.save(); g.translate(x, y); g.scale(s, s);
  g.fillStyle = 'rgba(0,0,0,.45)'; g.beginPath(); g.ellipse(0, 13, 13, 4.5, 0, 0, TAU); g.fill();
  g.fillStyle = '#211832'; g.strokeStyle = mix(color, '#000000', 0.25); g.lineWidth = 2;
  g.beginPath(); g.moveTo(0, -17 + bob); g.quadraticCurveTo(11, -10 + bob, 13, 12); g.lineTo(-13, 12); g.quadraticCurveTo(-11, -10 + bob, 0, -17 + bob); g.closePath(); g.fill(); g.stroke();
  g.fillStyle = '#0a0710'; g.beginPath(); g.ellipse(side * 2, -6 + bob, 6.5, 5.5, 0, 0, TAU); g.fill();
  g.fillStyle = color; g.beginPath(); g.arc(side * 2 - 2.3, -6 + bob, 1.4, 0, TAU); g.arc(side * 2 + 2.3, -6 + bob, 1.4, 0, TAU); g.fill();
  g.strokeStyle = '#6a5a7a'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(side * 10, -2 + bob); g.lineTo(side * 14, 2 + bob); g.stroke();
  g.fillStyle = '#ffd98a'; g.strokeStyle = '#7a5a2a'; g.lineWidth = 1.2;
  roundRectPath(g, side * 14 - 3.5, 2 + bob, 7, 9, 2); g.fill(); g.stroke();
  g.restore();
}

function render(realDt) {
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
  ctx.fillStyle = '#07050d'; ctx.fillRect(0, 0, W, H);
  if (G.state !== 'play' || !run) { renderMenuBG(); return; }
  const R = run, t = R.time;
  const sx = R.shake ? rand(-R.shake, R.shake) : 0, sy = R.shake ? rand(-R.shake, R.shake) : 0;

  // --- World (lit by darkness afterwards) ---
  worldBegin(sx, sy);
  drawGround(t);
  for (const p of R.projs) if (p.kind === 'mine' && onScreen(p.x, p.y)) {
    const blink = p.arm > 0 ? 0.5 : (Math.sin(t * 14) > 0 ? 1 : 0.6);
    ctx.fillStyle = '#2a4a1a'; ctx.beginPath(); ctx.arc(p.x, p.y, 8, 0, TAU); ctx.fill();
    ctx.fillStyle = rgba('#9dff5c', blink); ctx.beginPath(); ctx.arc(p.x, p.y, 4, 0, TAU); ctx.fill();
  }
  for (const g of R.gems) if (onScreen(g.x, g.y)) drawGem(g, t);
  for (const p of R.pickups) if (onScreen(p.x, p.y)) drawPickup(p);
  for (const e of R.enemies) {
    if (!onScreen(e.x, e.y, e.r * 2)) continue;
    const spr = sprites[e.type + (e.flash > 0 ? '_w' : '')];
    const sc = e.r / (e.boss ? BOSSES[e.type].r : ENEMY_TYPES[e.type].r);
    const sq = 1 + Math.sin(e.t * 8) * 0.05;
    const hw = spr.half * sc;
    ctx.drawImage(spr.c, e.x - hw, e.y - hw * sq, hw * 2, hw * 2 * sq);
    if (e.elite) { ctx.strokeStyle = rgba('#ffd166', 0.6 + Math.sin(t * 6) * 0.3); ctx.lineWidth = 2.5; ctx.beginPath(); ctx.arc(e.x, e.y, e.r + 6, 0, TAU); ctx.stroke(); }
    if (e.slow > 0) { ctx.fillStyle = 'rgba(160,233,255,.28)'; ctx.beginPath(); ctx.arc(e.x, e.y, e.r + 2, 0, TAU); ctx.fill(); }
    if (e.boss && e.state === 'dashPrep') {
      ctx.strokeStyle = rgba('#ff3d6e', 0.3 + Math.sin(t * 30) * 0.2); ctx.lineWidth = e.r * 1.4; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(e.x, e.y); ctx.lineTo(e.x + e.dashX * 330, e.y + e.dashY * 330); ctx.stroke(); ctx.lineCap = 'butt';
    }
  }
  if (!(R.dying > 0)) {
    const blink = P.iframe > 0 && Math.floor(t * 20) % 2;
    ctx.globalAlpha = blink ? 0.45 : 1;
    drawKeeper(ctx, P.x, P.y, 1, CHARS[R.char].color, P.side, t, P.moving);
    ctx.globalAlpha = 1;
  }
  ctx.restore();

  // --- Darkness: the core of the look. The lantern carves a pool of light out of the night. ---
  const psx = (P.x - cam.x) * ZOOM + W / 2 + sx, psy = (P.y - cam.y) * ZOOM + H / 2 + sy;
  const nightAlpha = R.won && !R.endless ? 0.35 : 0.8;
  dctx.globalCompositeOperation = 'source-over';
  dctx.clearRect(0, 0, darkC.width, darkC.height);
  dctx.fillStyle = `rgba(4,2,12,${nightAlpha})`; dctx.fillRect(0, 0, darkC.width, darkC.height);
  dctx.globalCompositeOperation = 'destination-out';
  const hole = (x, y, r, a) => {
    const gr = dctx.createRadialGradient(x / 2, y / 2, 0, x / 2, y / 2, r / 2);
    gr.addColorStop(0, `rgba(0,0,0,${a})`); gr.addColorStop(0.55, `rgba(0,0,0,${a * 0.8})`); gr.addColorStop(1, 'rgba(0,0,0,0)');
    dctx.fillStyle = gr; dctx.fillRect(x / 2 - r / 2, y / 2 - r / 2, r, r);
  };
  const flick = 1 + Math.sin(G.time * 9) * 0.015 + Math.sin(G.time * 23) * 0.01;
  if (!(R.dying > 0)) hole(psx, psy, P.light * ZOOM * 2 * flick, 1);
  for (const f of R.fx) if (f.kind === 'flash' || f.kind === 'ring') {
    const fx = (f.x - cam.x) * ZOOM + W / 2, fy = (f.y - cam.y) * ZOOM + H / 2;
    hole(fx, fy, Math.min(f.r, 900) * ZOOM * 2, 0.7 * (f.life / f.max));
  }
  ctx.drawImage(darkC, 0, 0, W, H);

  // --- Light pass: glowing things shine through the dark ---
  worldBegin(sx, sy);
  ctx.globalCompositeOperation = 'lighter';
  const eye = glow('#ffe9b0', 5);
  for (const e of R.enemies) {
    if (!onScreen(e.x, e.y) || (!e.boss && ENEMY_TYPES[e.type].noEyes)) continue;
    const ex = e.r * 0.36, ey = e.r * 0.15, es = e.r < 12 ? 7 : e.r * 0.6;
    ctx.drawImage(eye, e.x - ex - es / 2, e.y - ey - es / 2, es, es);
    ctx.drawImage(eye, e.x + ex - es / 2, e.y - ey - es / 2, es, es);
  }
  for (const g of R.gems) if (onScreen(g.x, g.y)) { const gl = glow(gemColor(g.v), 14); ctx.globalAlpha = 0.5; ctx.drawImage(gl, g.x - 14, g.y - 14); ctx.globalAlpha = 1; }
  for (const p of R.projs) {
    if (!onScreen(p.x, p.y)) continue;
    if (p.kind === 'bolt') { const gl = glow('#ff9a3d', p.r * 3.2); ctx.drawImage(gl, p.x - p.r * 3.2, p.y - p.r * 3.2); }
    else if (p.kind === 'frost') {
      const a = Math.atan2(p.vy, p.vx); ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(a);
      ctx.fillStyle = '#d8f6ff'; ctx.beginPath(); ctx.moveTo(p.r * 2.2, 0); ctx.lineTo(-p.r, -p.r * 0.7); ctx.lineTo(-p.r * 0.4, 0); ctx.lineTo(-p.r, p.r * 0.7); ctx.closePath(); ctx.fill();
      ctx.restore(); const gl = glow('#a0e9ff', p.r * 2.5); ctx.drawImage(gl, p.x - p.r * 2.5, p.y - p.r * 2.5);
    } else if (p.kind === 'scythe') {
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
      ctx.fillStyle = 'rgba(201,160,255,.85)'; ctx.beginPath(); ctx.arc(0, 0, p.r, -2.4, 1.1); ctx.arc(p.r * 0.35, -p.r * 0.2, p.r * 0.72, 1.0, -2.2, true); ctx.closePath(); ctx.fill();
      ctx.restore(); const gl = glow('#a46bff', p.r * 1.6); ctx.globalAlpha = 0.6; ctx.drawImage(gl, p.x - p.r * 1.6, p.y - p.r * 1.6); ctx.globalAlpha = 1;
    } else if (p.kind === 'mine') { const gl = glow('#9dff5c', 16); ctx.globalAlpha = 0.5; ctx.drawImage(gl, p.x - 16, p.y - 16); ctx.globalAlpha = 1; }
  }
  for (const w of R.weapons) if (w.id === 'halo' && w.orbs) for (const o of w.orbs) {
    const gl = glow('#ffcc33', o.r * 2.6); ctx.drawImage(gl, o.x - o.r * 2.6, o.y - o.r * 2.6);
  }
  for (const f of R.fx) {
    const a = f.life / f.max;
    if (f.kind === 'ring') {
      const rr = f.r * (1 - a * a * 0.6);
      ctx.strokeStyle = rgba(f.color, a * 0.8); ctx.lineWidth = 3 + 10 * a; ctx.beginPath(); ctx.arc(f.x, f.y, rr, 0, TAU); ctx.stroke();
      ctx.fillStyle = rgba(f.color, a * 0.08); ctx.fill();
    } else if (f.kind === 'flash') {
      const gl = glow(f.color, f.r); ctx.globalAlpha = a; ctx.drawImage(gl, f.x - f.r, f.y - f.r); ctx.globalAlpha = 1;
    } else if (f.kind === 'bolt') {
      ctx.strokeStyle = rgba(f.color, a); ctx.lineJoin = 'round';
      for (const [lw, al] of [[7, 0.3], [2.5, 1]]) {
        ctx.lineWidth = lw; ctx.globalAlpha = al; ctx.beginPath(); ctx.moveTo(f.pts[0][0], f.pts[0][1]);
        for (const pt of f.pts) ctx.lineTo(pt[0], pt[1]); ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }
  }
  for (const p of R.parts) {
    if (!onScreen(p.x, p.y)) continue;
    const a = p.life / p.max, s = p.size * (0.5 + a);
    ctx.globalAlpha = a; ctx.drawImage(glow(p.color, 8), p.x - s, p.y - s, s * 2, s * 2);
  }
  ctx.globalAlpha = 1;
  for (const b of R.eprojs) {
    if (!onScreen(b.x, b.y)) continue;
    ctx.drawImage(glow('#ff4dd2', 16), b.x - 16, b.y - 16);
  }
  if (!(R.dying > 0)) {
    const lx = P.x + P.side * 14, ly = P.y + 6;
    const lg = glow('#ffb347', 34 * flick); ctx.drawImage(lg, lx - 34 * flick, ly - 34 * flick);
  }
  ctx.globalCompositeOperation = 'source-over';
  // Enemy bullets need a solid core so they read clearly.
  ctx.fillStyle = '#ffd1f4';
  for (const b of R.eprojs) if (onScreen(b.x, b.y)) { ctx.beginPath(); ctx.arc(b.x, b.y, 4, 0, TAU); ctx.fill(); }
  for (const p of R.projs) if (p.kind === 'bolt' && onScreen(p.x, p.y)) { ctx.fillStyle = '#fff2d0'; ctx.beginPath(); ctx.arc(p.x, p.y, p.r * 0.6, 0, TAU); ctx.fill(); }
  for (const w of R.weapons) if (w.id === 'halo' && w.orbs) for (const o of w.orbs) { ctx.fillStyle = '#fff1b8'; ctx.beginPath(); ctx.arc(o.x, o.y, o.r * 0.55, 0, TAU); ctx.fill(); }

  // Damage numbers
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  for (const n of R.nums) {
    const a = Math.min(1, n.life / 0.3);
    ctx.globalAlpha = a; ctx.font = n.crit ? 'bold 18px "Trebuchet MS",sans-serif' : 'bold 13px "Trebuchet MS",sans-serif';
    ctx.lineWidth = 3; ctx.strokeStyle = 'rgba(0,0,0,.8)'; ctx.strokeText(n.v, n.x, n.y);
    ctx.fillStyle = n.crit ? '#ffd166' : '#ffffff'; ctx.fillText(n.v, n.x, n.y);
  }
  ctx.globalAlpha = 1;
  // Player HP bar
  if (!(R.dying > 0)) {
    const bw = 34, bx = P.x - bw / 2, by = P.y + 18;
    ctx.fillStyle = 'rgba(0,0,0,.7)'; ctx.fillRect(bx - 1, by - 1, bw + 2, 6);
    ctx.fillStyle = P.hp / P.maxHp < 0.3 ? '#ff3d5a' : '#ff6b7f'; ctx.fillRect(bx, by, bw * clamp(P.hp / P.maxHp, 0, 1), 4);
  }
  ctx.restore();

  drawHUD();
}

function gemColor(v) { return v < 5 ? '#5ce1e6' : v < 25 ? '#7dff9a' : '#ff5d73'; }
function drawGem(g, t) {
  const c = gemColor(g.v), s = g.v < 5 ? 5 : g.v < 25 ? 7 : 9, bob = Math.sin(t * 4 + g.x) * 1.5;
  ctx.fillStyle = c; ctx.beginPath(); ctx.moveTo(g.x, g.y - s + bob); ctx.lineTo(g.x + s * 0.7, g.y + bob); ctx.lineTo(g.x, g.y + s + bob); ctx.lineTo(g.x - s * 0.7, g.y + bob); ctx.closePath(); ctx.fill();
  ctx.fillStyle = 'rgba(255,255,255,.6)'; ctx.beginPath(); ctx.moveTo(g.x, g.y - s + bob); ctx.lineTo(g.x + s * 0.35, g.y + bob); ctx.lineTo(g.x, g.y + bob); ctx.closePath(); ctx.fill();
}
function drawPickup(p) {
  const bob = Math.sin(p.t * 3) * 2, x = p.x, y = p.y + bob;
  ctx.save();
  ctx.shadowBlur = 14;
  switch (p.kind) {
    case 'coin': ctx.shadowColor = '#ffd166'; ctx.fillStyle = '#ffd166'; ctx.beginPath(); ctx.moveTo(x, y - 7); ctx.lineTo(x + 6, y); ctx.lineTo(x, y + 7); ctx.lineTo(x - 6, y); ctx.closePath(); ctx.fill(); break;
    case 'heart': ctx.shadowColor = '#ff5d73'; ctx.fillStyle = '#ff5d73'; ctx.translate(x, y); ctx.scale(0.55, 0.55); ICON_DRAW.vigor(ctx); break;
    case 'magnet': ctx.shadowColor = '#6ec6ff'; ctx.strokeStyle = '#6ec6ff'; ctx.lineCap = 'round'; ctx.translate(x, y); ctx.scale(0.55, 0.55); ICON_DRAW.magnet(ctx); break;
    case 'bomb': ctx.shadowColor = '#fff3b0'; ctx.fillStyle = '#fff3b0'; ctx.beginPath(); ctx.arc(x, y, 8, 0, TAU); ctx.fill(); ctx.fillStyle = '#7a5a2a'; ctx.fillRect(x - 2, y - 13, 4, 6); break;
    case 'chest':
      ctx.shadowColor = '#ffd166'; ctx.fillStyle = '#7a4a1e'; roundRectPath(ctx, x - 14, y - 10, 28, 20, 4); ctx.fill();
      ctx.fillStyle = '#ffd166'; ctx.fillRect(x - 14, y - 3, 28, 4); ctx.fillRect(x - 3, y - 6, 6, 9); break;
  }
  ctx.restore();
}

function drawHUD() {
  const R = run;
  ctx.textBaseline = 'middle';
  // XP bar
  ctx.fillStyle = 'rgba(10,6,18,.85)'; ctx.fillRect(0, 0, W, 16);
  const xg = ctx.createLinearGradient(0, 0, W, 0); xg.addColorStop(0, '#5ce1e6'); xg.addColorStop(1, '#b38cff');
  ctx.fillStyle = xg; ctx.fillRect(0, 2, W * clamp(P.xp / P.xpNext, 0, 1), 12);
  ctx.font = 'bold 13px "Trebuchet MS",sans-serif'; ctx.textAlign = 'right'; ctx.fillStyle = '#fff';
  ctx.fillText('LV ' + P.level, W - 8, 8.5);
  // Timer
  ctx.textAlign = 'center'; ctx.font = 'bold 30px "Trebuchet MS",sans-serif';
  ctx.lineWidth = 4; ctx.strokeStyle = 'rgba(0,0,0,.6)';
  const timeStr = fmtTime(R.time);
  ctx.strokeText(timeStr, W / 2, 40); ctx.fillStyle = '#f3e9ff'; ctx.fillText(timeStr, W / 2, 40);
  ctx.font = '13px "Trebuchet MS",sans-serif'; ctx.fillStyle = '#a99bc4';
  const sub = R.won ? (R.endless ? 'Endless Night' : 'Dawn') : (R.time < DAWN_TIME ? 'Dawn in ' + fmtTime(DAWN_TIME - R.time) : 'Slay the Hollow King');
  ctx.fillText(sub, W / 2, 62);
  // Kills / coins
  ctx.textAlign = 'right'; ctx.font = 'bold 17px "Trebuchet MS",sans-serif';
  ctx.fillStyle = '#f3e9ff'; ctx.fillText('☠ ' + fmtNum(R.kills), W - 14, 34);
  ctx.fillStyle = '#ffd166'; ctx.fillText('◆ ' + fmtNum(R.coins), W - 14, 56);
  // Build icons
  let x = 10;
  for (const w of R.weapons) { drawSlot(getIcon(w.id), x, 24, w.lvl, WEAPONS[w.id].max); x += 40; }
  x = 10;
  for (const id of R.passiveOrder) { drawSlot(getIcon(id), x, 66, R.passives[id], PASSIVES[id].max, 28); x += 32; }
  // Boss bars
  let by = H - 40;
  for (const b of R.bosses) {
    const bw = Math.min(560, W - 80), bx = (W - bw) / 2;
    ctx.fillStyle = 'rgba(0,0,0,.7)'; ctx.fillRect(bx - 2, by - 2, bw + 4, 16);
    const bg = ctx.createLinearGradient(bx, 0, bx + bw, 0); bg.addColorStop(0, '#ff3d6e'); bg.addColorStop(1, BOSSES[b.type].color);
    ctx.fillStyle = bg; ctx.fillRect(bx, by, bw * clamp(b.hp / b.maxHp, 0, 1), 12);
    ctx.textAlign = 'center'; ctx.font = 'bold 14px "Trebuchet MS",sans-serif'; ctx.fillStyle = '#fff'; ctx.fillText(b.name, W / 2, by - 12);
    by -= 40;
    // Off-screen arrow
    if (!onScreen(b.x, b.y, -20)) {
      const a = Math.atan2(b.y - P.y, b.x - P.x), rx = W / 2 - 40, ry = H / 2 - 50;
      const ax = W / 2 + Math.cos(a) * rx, ay = H / 2 + Math.sin(a) * ry;
      ctx.save(); ctx.translate(ax, ay); ctx.rotate(a); ctx.fillStyle = BOSSES[b.type].color;
      ctx.beginPath(); ctx.moveTo(16, 0); ctx.lineTo(-8, -10); ctx.lineTo(-8, 10); ctx.closePath(); ctx.fill(); ctx.restore();
    }
  }
  // Toasts
  ctx.textAlign = 'center';
  R.toasts.forEach((t, i) => {
    ctx.globalAlpha = Math.min(1, t.life / 0.4, (t.max - t.life) / 0.2 + 0.2);
    ctx.font = 'bold 20px "Trebuchet MS",sans-serif'; ctx.lineWidth = 4; ctx.strokeStyle = 'rgba(0,0,0,.7)';
    ctx.strokeText(t.text, W / 2, 96 + i * 26); ctx.fillStyle = t.color; ctx.fillText(t.text, W / 2, 96 + i * 26);
  });
  ctx.globalAlpha = 1;
  if (R.banner) {
    const b = R.banner, a = Math.min(1, b.life / 0.5, (b.max - b.life) / 0.25);
    ctx.globalAlpha = a;
    ctx.fillStyle = 'rgba(5,3,10,.55)'; ctx.fillRect(0, H * 0.28 - 40, W, 86);
    ctx.font = `900 ${Math.min(52, W / 14)}px "Trebuchet MS",sans-serif`; ctx.fillStyle = b.color;
    ctx.shadowColor = b.color; ctx.shadowBlur = 20; ctx.fillText(b.title, W / 2, H * 0.28 - 8); ctx.shadowBlur = 0;
    ctx.font = '17px "Trebuchet MS",sans-serif'; ctx.fillStyle = '#f3e9ff'; ctx.fillText(b.sub, W / 2, H * 0.28 + 28);
    ctx.globalAlpha = 1;
  }
  // Damage / low-HP vignette
  const low = P.hp / P.maxHp < 0.3 && P.hp > 0 ? 0.25 + Math.sin(G.time * 6) * 0.12 : 0;
  const va = Math.max(R.hurt * 0.55, low);
  if (va > 0.01) {
    const vg = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.3, W / 2, H / 2, Math.max(W, H) * 0.7);
    vg.addColorStop(0, 'rgba(255,0,40,0)'); vg.addColorStop(1, `rgba(255,0,40,${va})`);
    ctx.fillStyle = vg; ctx.fillRect(0, 0, W, H);
  }
  if (R.dying > 0) { ctx.fillStyle = `rgba(0,0,0,${0.6 * (1 - R.dying / 1.6)})`; ctx.fillRect(0, 0, W, H); }
}
function drawSlot(icon, x, y, lvl, max, size = 36) {
  ctx.drawImage(icon, x, y, size, size);
  const pw = (size - 4) / max;
  for (let i = 0; i < max; i++) { ctx.fillStyle = i < lvl ? '#ffb347' : 'rgba(255,255,255,.15)'; ctx.fillRect(x + 2 + i * pw, y + size + 1, pw - 1.5, 3); }
}

// Animated title-screen backdrop: a lone lantern drifting through the dark.
const menuEmbers = [];
function renderMenuBG() {
  const t = G.time;
  cam.x = t * 22; cam.y = Math.sin(t * 0.2) * 60;
  ctx.save(); ctx.translate(W / 2, H / 2); ctx.scale(ZOOM, ZOOM); ctx.translate(-cam.x, -cam.y);
  drawGround(t);
  const onTitle = $('s-menu').classList.contains('show');
  if (onTitle) drawKeeper(ctx, cam.x, cam.y + VH * 0.22, 2.2, CHARS[G.lastChar] ? CHARS[G.lastChar].color : '#ffb347', 1, t, true);
  ctx.restore();
  const px = W / 2, py = H / 2 + VH * 0.22 * ZOOM;
  dctx.globalCompositeOperation = 'source-over'; dctx.clearRect(0, 0, darkC.width, darkC.height);
  dctx.fillStyle = 'rgba(4,2,12,0.88)'; dctx.fillRect(0, 0, darkC.width, darkC.height);
  dctx.globalCompositeOperation = 'destination-out';
  const r = (Math.min(W, H) * 0.55) * (1 + Math.sin(t * 9) * 0.015);
  const gr = dctx.createRadialGradient(px / 2, py / 2, 0, px / 2, py / 2, r / 2);
  gr.addColorStop(0, 'rgba(0,0,0,1)'); gr.addColorStop(0.5, 'rgba(0,0,0,.75)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
  dctx.fillStyle = gr; dctx.fillRect(0, 0, darkC.width, darkC.height);
  ctx.drawImage(darkC, 0, 0, W, H);
  ctx.globalCompositeOperation = 'lighter';
  if (menuEmbers.length < 70 && Math.random() < 0.5) menuEmbers.push({ x: rand(0, W), y: H + 10, vy: rand(20, 60), vx: rand(-10, 10), s: rand(2, 6), life: rand(5, 12) });
  for (const e of menuEmbers) { e.y -= e.vy / 60; e.x += e.vx / 60 + Math.sin(t + e.s) * 0.3; e.life -= 1 / 60; ctx.globalAlpha = Math.min(1, e.life / 2) * 0.8; ctx.drawImage(glow('#ff9a3d', 8), e.x - e.s, e.y - e.s, e.s * 2, e.s * 2); }
  for (let i = menuEmbers.length - 1; i >= 0; i--) if (menuEmbers[i].life <= 0 || menuEmbers[i].y < -20) menuEmbers.splice(i, 1);
  ctx.globalAlpha = 1;
  if (onTitle) ctx.drawImage(glow('#ffb347', 60), px + 30 * ZOOM - 60, py + 13 * ZOOM - 60);
  ctx.globalCompositeOperation = 'source-over';
  // eyes lurking at the edges of the light
  for (let i = 0; i < 7; i++) {
    const a = i * 0.9 + 0.3, rr = Math.min(W, H) * (0.42 + (i % 3) * 0.08);
    const ex = W / 2 + Math.cos(a + t * 0.05) * rr * 1.4, ey = H / 2 + Math.sin(a + t * 0.05) * rr * 0.8;
    if (Math.sin(t * 0.7 + i * 2.1) > 0.92) continue; // blink
    ctx.globalCompositeOperation = 'lighter';
    ctx.drawImage(glow('#ff4d8d', 5), ex - 8, ey - 2, 7, 7); ctx.drawImage(glow('#ff4d8d', 5), ex + 2, ey - 2, 7, 7);
    ctx.globalCompositeOperation = 'source-over';
  }
}

// ---------- Level-up ----------
function buildChoices() {
  const pool = [];
  for (const w of run.weapons) if (w.lvl < WEAPONS[w.id].max) pool.push({ type: 'w', id: w.id, weight: 3 });
  if (run.weapons.length < 6) for (const id in WEAPONS) if (!run.weapons.find((w) => w.id === id)) pool.push({ type: 'w', id, weight: 1.8 });
  for (const id in run.passives) if (run.passives[id] < PASSIVES[id].max) pool.push({ type: 'p', id, weight: 2.4 });
  if (Object.keys(run.passives).length < 6) for (const id in PASSIVES) if (!(id in run.passives)) pool.push({ type: 'p', id, weight: 1.3 });
  const n = Math.random() < 0.08 * P.luck + (P.luck - 1) * 0.3 ? 4 : 3;
  const out = [];
  while (out.length < n && pool.length) { const c = weightedPick(pool); out.push(c); pool.splice(pool.indexOf(c), 1); }
  if (!out.length) out.push({ type: 'heal' }, { type: 'gold' });
  return out;
}
function applyChoice(c) {
  if (c.type === 'w') {
    const w = run.weapons.find((x) => x.id === c.id);
    if (w) w.lvl++; else addWeapon(c.id);
    if (run.weapons.some((x) => x.lvl >= WEAPONS[x.id].max)) unlockAch('ACH_MAX_WEAPON');
    if (run.weapons.length >= 6) unlockAch('ACH_ARSENAL');
  } else if (c.type === 'p') {
    run.passives[c.id] = (run.passives[c.id] || 0) + 1;
    if (!run.passiveOrder.includes(c.id)) run.passiveOrder.push(c.id);
    recalcStats();
  } else if (c.type === 'heal') P.hp = Math.min(P.maxHp, P.hp + P.maxHp * 0.3);
  else if (c.type === 'gold') run.coins += Math.round(25 * P.greed);
}
function openLevelUp() {
  run.choices = buildChoices();
  if (run.choices[0].type === 'heal') {
    // Build is complete: don't interrupt play, just pay out.
    const n = run.pendingLevels; run.pendingLevels = 0;
    run.coins += Math.round(5 * n * P.greed); P.hp = Math.min(P.maxHp, P.hp + P.maxHp * 0.1 * n);
    toast('MAX POWER  +' + Math.round(5 * n * P.greed) + ' Embers', '#ffd166'); Sound.play('coin');
    return;
  }
  G.overlay = 'level'; G.paused = true;
  renderCards();
  showScreen('s-level');
  Sound.play('levelup');
}
function renderCards() {
  const box = $('cards'); box.innerHTML = '';
  run.choices.forEach((c, i) => {
    const b = document.createElement('button'); b.className = 'card';
    let name, tag, desc, icon, isNew = false;
    if (c.type === 'w' || c.type === 'p') {
      const def = c.type === 'w' ? WEAPONS[c.id] : PASSIVES[c.id];
      const cur = c.type === 'w' ? (run.weapons.find((w) => w.id === c.id) || {}).lvl || 0 : run.passives[c.id] || 0;
      getIcon(c.id); icon = iconURL[c.id]; name = def.name; isNew = cur === 0;
      tag = isNew ? (c.type === 'w' ? 'NEW WEAPON' : 'NEW RELIC') : `LV ${cur} → ${cur + 1}${cur + 1 === def.max ? ' (MAX)' : ''}`;
      desc = c.type === 'w' ? (isNew ? def.desc : def.up[cur - 1]) : def.desc;
    } else if (c.type === 'heal') { name = 'Warm Meal'; tag = 'RESTORE'; desc = 'Recover 30% of your HP.'; }
    else { name = 'Ember Pouch'; tag = 'TREASURE'; desc = 'Gain 25 Embers.'; }
    b.innerHTML = (icon ? `<img src="${icon}" alt="">` : '<div style="height:72px;font-size:52px;line-height:72px">✦</div>') +
      `<div class="c-name">${name}</div><div class="c-tag${isNew ? ' new' : ''}">${tag}</div><div class="c-desc">${desc}</div><div class="c-key">[${i + 1}]</div>`;
    b.addEventListener('click', () => chooseCard(i));
    box.appendChild(b);
  });
  $('rerollBtn').textContent = `Reroll (${P.rerolls})`;
  $('rerollBtn').disabled = P.rerolls <= 0;
  // Brief input lock so a held key or button doesn't pick a card by accident.
  box.classList.add('locked');
  setTimeout(() => { box.classList.remove('locked'); if (G.overlay === 'level' && lastInput !== 'mouse') focusFirst(); }, 350);
}
function chooseCard(i) {
  if (G.overlay !== 'level' || $('cards').classList.contains('locked')) return;
  applyChoice(run.choices[i]);
  Sound.play('buy');
  nextLevelOrClose();
}
function nextLevelOrClose() {
  run.pendingLevels--;
  if (run.pendingLevels > 0) { run.choices = buildChoices(); renderCards(); }
  else closeOverlay();
}
$('rerollBtn').addEventListener('click', () => {
  if (P.rerolls <= 0 || G.overlay !== 'level') return;
  P.rerolls--; run.choices = buildChoices(); renderCards(); Sound.play('click');
});
$('skipBtn').addEventListener('click', () => {
  if (G.overlay !== 'level' || $('cards').classList.contains('locked')) return;
  run.coins += 10; nextLevelOrClose();
});

// ---------- Screens ----------
function hideScreens() { document.querySelectorAll('.screen').forEach((s) => s.classList.remove('show')); }
function showScreen(id) {
  hideScreens(); $(id).classList.add('show');
  if (lastInput !== 'mouse') setTimeout(focusFirst, 30);
}
function closeOverlay() { hideScreens(); G.overlay = null; G.paused = false; document.body.classList.add('playing'); }
function togglePause() {
  if (G.state !== 'play' || run.over) return;
  if (G.overlay === 'pause') { closeOverlay(); return; }
  if (G.overlay) return;
  G.overlay = 'pause'; G.paused = true;
  const pb = $('pauseBuild'); pb.innerHTML = '';
  for (const w of run.weapons) { getIcon(w.id); pb.insertAdjacentHTML('beforeend', `<img src="${iconURL[w.id]}" title="${WEAPONS[w.id].name} Lv${w.lvl}">`); }
  for (const id of run.passiveOrder) { getIcon(id); pb.insertAdjacentHTML('beforeend', `<img src="${iconURL[id]}" title="${PASSIVES[id].name} Lv${run.passives[id]}">`); }
  document.body.classList.remove('playing');
  showScreen('s-pause');
}
function openVictory() { G.overlay = 'victory'; G.paused = true; document.body.classList.remove('playing'); showScreen('s-victory'); }
function goMenu() {
  G.state = 'menu'; G.overlay = null; G.paused = false; run = null;
  document.body.classList.remove('playing');
  $('menuCoins').textContent = fmtNum(save.coins);
  showScreen('s-menu');
}
function goBack() {
  const s = currentScreen(); if (!s) return;
  Sound.play('click');
  if (s.id === 's-settings' && G.settingsFrom === 'pause') { G.overlay = null; G.paused = true; togglePauseReopen(); return; }
  if (['s-chars', 's-shop', 's-ach', 's-settings'].includes(s.id)) goMenu();
}
function togglePauseReopen() { G.overlay = null; togglePause(); }

function openChars() {
  const grid = $('charGrid'); grid.innerHTML = '';
  for (const id in CHARS) {
    const c = CHARS[id], un = isCharUnlocked(id);
    const b = document.createElement('button'); b.className = 'tile' + (un ? '' : ' locked');
    const cv = document.createElement('canvas'); cv.width = 90; cv.height = 90;
    const g = cv.getContext('2d');
    if (un) { g.fillStyle = rgba(c.color, 0.12); g.beginPath(); g.arc(45, 48, 40, 0, TAU); g.fill(); drawKeeper(g, 45, 50, 2.3, c.color, 1, 0, false); }
    else { g.fillStyle = '#2a2040'; g.font = 'bold 50px sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('?', 45, 48); }
    b.appendChild(cv);
    const ach = c.unlock && ACHIEVEMENTS.find((a) => a.id === c.unlock);
    b.insertAdjacentHTML('beforeend', `<div class="t-name">${un ? c.name : '???'}</div>
      <div class="t-desc">${un ? c.desc : 'Locked — ' + ach.desc}</div>
      <div class="t-meta">${un ? 'Starts with ' + WEAPONS[c.weapon].name : ''}</div>`);
    b.addEventListener('click', () => { if (!un) { Sound.play('deny'); return; } Sound.play('buy'); newRun(id); });
    grid.appendChild(b);
  }
  showScreen('s-chars');
}
function openShop() {
  $('shopCoins').textContent = fmtNum(save.coins);
  const grid = $('shopGrid'); grid.innerHTML = '';
  for (const it of SHOP) {
    const l = save.shop[it.id] || 0, maxed = l >= it.max, cost = shopCost(it, l);
    const b = document.createElement('button'); b.className = 'tile' + (maxed ? ' maxed' : '');
    let pips = '<div class="pips">'; for (let i = 0; i < it.max; i++) pips += `<div class="pip${i < l ? ' on' : ''}"></div>`; pips += '</div>';
    b.innerHTML = `<div class="t-name">${it.name}</div><div class="t-desc">${it.desc}</div>${pips}<div class="t-meta">${maxed ? 'MAXED' : '◆ ' + fmtNum(cost)}</div>`;
    b.addEventListener('click', () => {
      if (maxed || save.coins < cost) { Sound.play('deny'); return; }
      save.coins -= cost; save.shop[it.id] = l + 1; persist(); Sound.play('buy');
      const idx = SHOP.indexOf(it); openShop(); const btn = $('shopGrid').children[idx]; if (btn) btn.focus();
    });
    grid.appendChild(b);
  }
  if (!currentScreen() || currentScreen().id !== 's-shop') showScreen('s-shop');
}
$('refundBtn').addEventListener('click', () => {
  let back = 0;
  for (const it of SHOP) { const l = save.shop[it.id] || 0; for (let i = 0; i < l; i++) back += shopCost(it, i); }
  if (!back) { Sound.play('deny'); return; }
  save.coins += back; save.shop = {}; persist(); Sound.play('coin'); openShop();
});
function openAch() {
  const grid = $('achGrid'); grid.innerHTML = '';
  let got = 0;
  for (const a of ACHIEVEMENTS) {
    const has = !!save.ach[a.id]; if (has) got++;
    const unlocksChar = Object.values(CHARS).find((c) => c.unlock === a.id);
    const d = document.createElement('div'); d.className = 'tile' + (has ? ' got' : ' locked');
    d.innerHTML = `<div class="t-name">${has ? '★ ' : ''}${a.name}</div><div class="t-desc">${a.desc}</div>${unlocksChar ? `<div class="t-meta">Unlocks ${has ? unlocksChar.name : 'a Keeper'}</div>` : ''}`;
    grid.appendChild(d);
  }
  $('achCount').textContent = `${got} / ${ACHIEVEMENTS.length} unlocked`;
  const s = save;
  $('statsBox').innerHTML = `<div>Runs<b>${fmtNum(s.totals.runs)}</b></div><div>Total Kills<b>${fmtNum(s.totals.kills)}</b></div>
    <div>Bosses Slain<b>${fmtNum(s.totals.bosses)}</b></div><div>Dawns Reached<b>${fmtNum(s.totals.wins)}</b></div>
    <div>Longest Night<b>${fmtTime(s.best.time)}</b></div><div>Highest Level<b>${s.best.level}</b></div>`;
  showScreen('s-ach');
}
function openSettings(from) {
  G.settingsFrom = from;
  if (from === 'pause') G.overlay = 'settings';
  $('optSfx').value = save.settings.sfx; $('optMusic').value = save.settings.music;
  $('optShake').textContent = 'Screen Shake: ' + (save.settings.shake ? 'On' : 'Off');
  $('optNums').textContent = 'Damage Numbers: ' + (save.settings.dmgNums ? 'On' : 'Off');
  $('optReset').textContent = 'Reset Save Data'; $('optReset').dataset.confirm = '';
  $('optReset').style.display = from === 'pause' ? 'none' : '';
  showScreen('s-settings');
}
$('optSfx').addEventListener('input', (e) => { save.settings.sfx = +e.target.value; Sound.applyVolumes(); Sound.play('click'); persist(); });
$('optMusic').addEventListener('input', (e) => { save.settings.music = +e.target.value; Sound.applyVolumes(); persist(); });
$('optShake').addEventListener('click', () => { save.settings.shake = !save.settings.shake; persist(); openSettingsRefresh(); });
$('optNums').addEventListener('click', () => { save.settings.dmgNums = !save.settings.dmgNums; persist(); openSettingsRefresh(); });
$('optFull').addEventListener('click', toggleFullscreen);
$('optReset').addEventListener('click', (e) => {
  const b = e.currentTarget;
  if (b.dataset.confirm !== 'yes') { b.dataset.confirm = 'yes'; b.textContent = 'Press again to erase ALL progress'; Sound.play('deny'); return; }
  const settings = save.settings; save = defaultSave(); save.settings = settings; persist();
  b.dataset.confirm = ''; b.textContent = 'Save data erased'; Sound.play('explode');
});
function openSettingsRefresh() {
  $('optShake').textContent = 'Screen Shake: ' + (save.settings.shake ? 'On' : 'Off');
  $('optNums').textContent = 'Damage Numbers: ' + (save.settings.dmgNums ? 'On' : 'Off');
  Sound.play('click');
}
function toggleFullscreen() {
  if (window.desktop && window.desktop.toggleFullscreen) { window.desktop.toggleFullscreen(); return; }
  if (document.fullscreenElement) document.exitFullscreen(); else if (document.documentElement.requestFullscreen) document.documentElement.requestFullscreen().catch(() => {});
}

document.addEventListener('click', (e) => {
  const b = e.target.closest('[data-act]'); if (!b) return;
  Sound.init();
  const act = b.dataset.act;
  if (act !== 'back') Sound.play('click');
  switch (act) {
    case 'play': openChars(); break;
    case 'shop': openShop(); break;
    case 'ach': openAch(); break;
    case 'settings': openSettings(G.state === 'play' ? 'pause' : 'menu'); break;
    case 'quit': if (window.desktop) window.desktop.quit(); else window.close(); break;
    case 'back': goBack(); break;
    case 'resume': togglePause(); break;
    case 'abandon': endRun('abandon'); break;
    case 'endless': run.endless = true; closeOverlay(); showBanner('THE ENDLESS NIGHT', 'How long can your light last?', '#b38cff'); break;
    case 'finish': endRun('victory'); break;
    case 'again': newRun(G.lastChar); break;
    case 'menu': goMenu(); break;
  }
});

// ---------- End of run ----------
function endRun(reason) {
  if (run.over) return;
  run.over = true; G.paused = true; G.overlay = 'over';
  const bonus = Math.floor((Math.floor(run.time / 10) + Math.floor(run.kills / 25) + (run.won ? 400 : 0)) * P.greed);
  const total = run.coins + bonus;
  save.coins += total;
  save.totals.kills += run.kills; save.totals.runs++; save.totals.time += run.time;
  save.best.time = Math.max(save.best.time, run.time); save.best.kills = Math.max(save.best.kills, run.kills); save.best.level = Math.max(save.best.level, P.level);
  runAchChecks();
  unlockAch('ACH_FIRST_NIGHT');
  if (save.coins >= 2000) unlockAch('ACH_RICH');
  persist();
  $('overTitle').textContent = run.won ? 'The Dawn Remembers You' : reason === 'abandon' ? 'You Retreat Into the Dark' : 'Your Light Fades';
  $('overTitle').className = run.won ? 'gold' : '';
  $('overStats').innerHTML = `<div>Survived<b>${fmtTime(run.time)}</b></div><div>Enemies<b>${fmtNum(run.kills)}</b></div>
    <div>Level<b>${P.level}</b></div><div>Embers<b>+${fmtNum(total)}</b></div>`;
  const maxD = Math.max(1, ...run.weapons.map((w) => w.dmg));
  $('overDmg').innerHTML = run.weapons.slice().sort((a, b) => b.dmg - a.dmg).map((w) => {
    getIcon(w.id);
    return `<div class="dmgrow"><img src="${iconURL[w.id]}" alt=""><div>${WEAPONS[w.id].name} <small>Lv${w.lvl}</small><div class="dmgbar" style="width:${(w.dmg / maxD) * 100}%"></div></div><div>${fmtNum(w.dmg)}</div></div>`;
  }).join('');
  document.body.classList.remove('playing');
  showScreen('s-over');
}

// ---------- Achievements ----------
function runAchChecks() {
  if (!run) return;
  const t = run.time;
  if (t >= 300) unlockAch('ACH_SURVIVE_5');
  if (t >= 600) unlockAch('ACH_SURVIVE_10');
  if (t >= 1200) unlockAch('ACH_ENDLESS_20');
  if (t >= 180 && !run.tookDamage) unlockAch('ACH_NO_HIT_3');
  if (run.kills >= 1000) unlockAch('ACH_KILLS_1000');
  if (P.level >= 30) unlockAch('ACH_LEVEL_30');
  if (save.totals.kills + run.kills >= 10000) unlockAch('ACH_KILLS_TOTAL');
}
const achQueue = [];
let achShowing = false;
function unlockAch(id) {
  if (save.ach[id]) return;
  save.ach[id] = Date.now(); persist();
  try { if (window.desktop && window.desktop.achievement) window.desktop.achievement(id); } catch (e) { /* steam unavailable */ }
  const a = ACHIEVEMENTS.find((x) => x.id === id);
  const ch = Object.values(CHARS).find((c) => c.unlock === id);
  achQueue.push({ name: a.name, sub: ch ? 'New Keeper unlocked: ' + ch.name : a.desc });
  if (!achShowing) showNextAch();
  if (id !== 'ACH_ALL_CHARS' && Object.keys(CHARS).every(isCharUnlocked)) unlockAch('ACH_ALL_CHARS');
}
function showNextAch() {
  const a = achQueue.shift(); if (!a) { achShowing = false; return; }
  achShowing = true;
  const el = $('achToast'); el.querySelector('.at-name').textContent = a.name; el.querySelector('.at-sub').textContent = a.sub;
  el.classList.add('show'); Sound.play('ach');
  setTimeout(() => { el.classList.remove('show'); setTimeout(showNextAch, 400); }, 3200);
}

// ---------- Main loop ----------
let lastT = performance.now();
function frame(now) {
  const realDt = Math.min(0.05, (now - lastT) / 1000); lastT = now;
  G.time += realDt;
  pollGamepad();
  if (G.state === 'play' && run && !G.paused && !run.over) update(realDt);
  render(realDt);
  requestAnimationFrame(frame);
}

// ---------- Boot ----------
buildSprites();
buildBackground();
for (const id in WEAPONS) getIcon(id);
for (const id in PASSIVES) getIcon(id);
if (!window.desktop) $('quitBtn').style.display = 'none';
goMenu();
requestAnimationFrame(frame);

// Debug hooks for automated testing (harmless in production).
window.__LL = { get run() { return run; }, get P() { return P; }, G, newRun, update, applyChoice, buildChoices, closeOverlay, save: () => save };
