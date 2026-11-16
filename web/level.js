/*
  level.js — the course. A "Kit" owns a cursor (a point on the walking
  surface, looking down the course) and every helper builds relative to it
  with (right, up, forward) offsets, so the course can bend and climb freely.
  It produces plain data objects; game.js turns them into meshes and physics.
*/
'use strict';

const POWERS = {
  Speed: { name: 'TURBO', icon: '⚡', desc: 'Run super fast', time: 8, color: 0xffd028, speed: 30 },
  Jump: { name: 'MEGA JUMP', icon: '🚀', desc: 'Leap over tall walls', time: 8, color: 0x50e678, jump: 85 },
  DoubleJump: { name: 'DOUBLE JUMP', icon: '✨', desc: 'Jump again in mid-air', time: 12, color: 0xff6edc },
  Feather: { name: 'MOON BOOTS', icon: '🌙', desc: 'Float through the air', time: 10, color: 0x96beff, gravity: 0.35 },
  Shield: { name: 'SHIELD', icon: '🛡', desc: "Hazards can't hurt you", time: 6, color: 0x46dcff },
};

const ZONES = [
  { name: 'Sunny Meadows', tag: 'Warm up those legs!', color: 0x6edc5a, sky: 0x8fd3ff, fog: 0xcfe9ff, sun: 0xfff2d6, amb: 0.95, far: 520 },
  { name: 'Magma Caverns', tag: 'The floor is lava. Literally.', color: 0xff7828, sky: 0x3a1410, fog: 0x5a1e12, sun: 0xff9a5a, amb: 0.7, far: 400 },
  { name: 'Frostbite Peaks', tag: "Careful... it's slippery up here.", color: 0x82d7ff, sky: 0xbfe2ff, fog: 0xe4f1ff, sun: 0xe6f2ff, amb: 1.0, far: 480 },
  { name: 'Neon City', tag: 'Lights on. Lasers on. Good luck.', color: 0x00f0e6, sky: 0x120a2e, fog: 0x24104a, sun: 0x9a7cff, amb: 0.75, far: 420 },
  { name: 'Starlight Sanctum', tag: 'Almost there. Reach for the stars!', color: 0xbe96ff, sky: 0x070618, fog: 0x15123a, sun: 0xc4b8ff, amb: 0.8, far: 600 },
];

const STAGES = [
  ['FirstSteps', 1, 'First Steps', 0, 'Jump from stone to stone!'],
  ['LadderCliffs', 1, 'Ladder Cliffs', 20, 'Walk into a ladder to climb it.'],
  ['SlidingStones', 1, 'Sliding Stones', -30, 'Moving blocks carry you along.'],
  ['TurboRunway', 1, 'Turbo Runway', 0, 'Grab the ⚡ and clear the big gaps!'],
  ['SpinCycle', 1, 'Spin Cycle', 30, 'Hop over the spinning bars.'],
  ['SkylineBeams', 1, 'Skyline Beams', -20, 'Keep your balance!'],
  ['HotFeet', 2, 'Hot Feet', 60, "Don't touch the lava."],
  ['CrumbleBridge', 2, 'Crumble Bridge', -25, 'Cracked tiles fall. Keep moving!'],
  ['MegaJumpCliffs', 2, 'Mega Jump Cliffs', 0, 'The 🚀 lets you jump HUGE walls.'],
  ['FireJets', 2, 'Fire Jets', 25, 'Run when the flames go out.'],
  ['LavaFerry', 2, 'Lava Ferry', 0, 'Ride the ferry. Dodge everything red.'],
  ['PendulumPass', 2, 'Pendulum Pass', -25, 'Time your run between the blades.'],
  ['SlipNSlide', 3, "Slip 'n Slide", -60, 'Ice is slippery. Brake early!'],
  ['ConveyorChaos', 3, 'Conveyor Chaos', 20, 'The arrows show where belts push you.'],
  ['IcicleGauntlet', 3, 'Icicle Gauntlet', 0, 'Grab the 🛡 and sprint through!'],
  ['BouncyGlaciers', 3, 'Bouncy Glaciers', -20, 'Bounce pads launch you sky high.'],
  ['CrusherHall', 3, 'Crusher Hall', 0, 'Wait for the crusher to rise.'],
  ['SpikeballAlley', 3, 'Spikeball Alley', 20, 'Watch both sides!'],
  ['LaserGrid', 4, 'Laser Grid', -60, 'Jump low lasers. Never jump under high ones.'],
  ['BoostBoulevard', 4, 'Boost Boulevard', -20, 'Hit the boost pad, then jump late.'],
  ['Carousel', 4, 'Carousel', 0, 'Ride the ring halfway round.'],
  ['DoubleTrouble', 4, 'Double Trouble', 20, 'With ✨ press jump again in mid-air.'],
  ['LadderLasers', 4, 'Ladder Lasers', 0, 'Climb between the laser pulses.'],
  ['NeonRush', 4, 'Neon Rush', 25, 'Line up the sliders, then go!'],
  ['MoonBoots', 5, 'Moon Boots', 60, 'The 🌙 makes you floaty. Jump far!'],
  ['StarWheel', 5, 'Star Wheel', -20, 'Ride the wheel over the top.'],
  ['PhaseTiles', 5, 'Phase Tiles', 0, 'Tiles flicker before they vanish.'],
  ['SpinnerGauntlet', 5, 'Spinner Gauntlet', 20, 'Low bar: jump. High bar: stay down.'],
  ['PowerTrip', 5, 'Power Trip', 0, 'Every power-up, one after another!'],
  ['TheAscent', 5, 'The Ascent', -20, "The final climb. You've got this!"],
].map((s) => ({ key: s[0], zone: s[1], name: s[2], turn: s[3], tip: s[4] }));
const FINISH = STAGES.length + 1;
const zoneOf = (i) => (STAGES[i - 1] ? STAGES[i - 1].zone : ZONES.length);

const THEMES = [
  { style: 'island', thick: 1.5, floor: 0x62be56, body: 0x866248, body2: 0x705a4c, plaza: 0xdeccaa, accent: 0xffd640, accent2: 0xff963c, mover: 0xe8aa54, vanish: 0xc8a06e, ladder: 0xfacd50, hazard: 0xff3842, post: 0x7a563c },
  { style: 'basalt', thick: 1.5, floor: 0x5a5058, body: 0x2e2a30, body2: 0x242026, plaza: 0x6a5c5e, accent: 0xff821e, accent2: 0xffc83c, mover: 0x966046, vanish: 0xaa6e46, ladder: 0xffaa3c, hazard: 0xff3228, lava: 0xff6014, post: 0x28262e },
  { style: 'ice', thick: 1.5, floor: 0xeef6ff, body: 0x8cc3eb, body2: 0x78b4e6, plaza: 0xd6e6f6, accent: 0x78dcff, accent2: 0xc8f0ff, mover: 0x5a96d7, vanish: 0xbedcf0, ladder: 0x5ac8ff, hazard: 0xff3264, post: 0x465a78 },
  { style: 'tech', thick: 1.2, floor: 0x343656, body: 0x141422, body2: 0x10101c, plaza: 0x403e68, accent: 0x00f0e6, accent2: 0xff00c8, mover: 0x6046be, vanish: 0xffdc3c, ladder: 0x00f0e6, hazard: 0xff1e46, post: 0x1c1c2e },
  { style: 'crystal', thick: 1.2, floor: 0xc4b2ff, body: 0x604caa, body2: 0x46388c, plaza: 0x7864c8, accent: 0xffe278, accent2: 0x82dcff, mover: 0x78c8ff, vanish: 0xffaae6, ladder: 0xffe278, hazard: 0xff325a, post: 0x322c60 },
];

function buildWorld() {
  const ents = [];
  const checkpoints = [];
  const rad = (d) => (d * Math.PI) / 180;
  let seed = 2024;
  const rnd = (a, b) => {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    const f = seed / 2147483648;
    return a === undefined ? f : a + (b - a) * f;
  };

  const K = {
    p: [0, 120, 0], yaw: 0, stage: 0, coins: 0, theme: THEMES[0], trail: [], stack: [],
    dirs() { return { r: [Math.cos(this.yaw), 0, Math.sin(this.yaw)], f: [Math.sin(this.yaw), 0, -Math.cos(this.yaw)] }; },
    w(x, y, z) { const d = this.dirs(); return [this.p[0] + d.r[0] * x + d.f[0] * z, this.p[1] + y, this.p[2] + d.r[2] * x + d.f[2] * z]; },
    wv(x, y, z) { const d = this.dirs(); return [d.r[0] * x + d.f[0] * z, y, d.r[2] * x + d.f[2] * z]; },
    move(x, y, z) { this.p = this.w(x, y, z); },
    fwd(d) { this.move(0, 0, d); },
    up(h) { this.move(0, h, 0); },
    turn(deg) { this.yaw += rad(deg); },
    push() { this.stack.push([this.p.slice(), this.yaw]); },
    pop() { const s = this.stack.pop(); this.p = s[0]; this.yaw = s[1]; },
    mark(clear, z) { this.trail.push({ p: this.w(0, 0, z || 0), yaw: this.yaw, clear }); },

    add(o) { o.stage = this.stage; o.yaw = o.yaw === undefined ? this.yaw : o.yaw; ents.push(o); return o; },
    block(sx, sy, sz, x, y, z, color, extra) {
      return this.add(Object.assign({ shape: 'box', c: this.w(x, y, z), s: [sx, sy, sz], color, solid: true }, extra));
    },
    deco(sx, sy, sz, x, y, z, color, extra) { return this.block(sx, sy, sz, x, y, z, color, Object.assign({ solid: false }, extra)); },
    cyl(d, h, x, y, z, color, extra) {
      return this.add(Object.assign({ shape: 'cyl', c: this.w(x, y, z), r: d / 2, h, s: [d, h, d], color, solid: true }, extra));
    },
    decoCyl(d, h, x, y, z, color, extra) { return this.cyl(d, h, x, y, z, color, Object.assign({ solid: false }, extra)); },
    ball(d, x, y, z, color, extra) {
      return this.add(Object.assign({ shape: 'ball', c: this.w(x, y, z), r: d / 2, s: [d, d, d], color, solid: false }, extra));
    },

    underside(wid, len, x, y, zc) {
      const t = this.theme, big = wid >= 5 && len >= 5;
      if (t.style === 'island') {
        this.deco(wid - 0.6, 2.2, len - 0.6, x, y - 1.1, zc, t.body);
        if (big) { this.deco(wid * 0.62, 2, len * 0.62, x, y - 3.2, zc, t.body2); this.deco(wid * 0.3, 1.6, len * 0.3, x, y - 5, zc, t.body2); }
      } else if (t.style === 'basalt') {
        this.deco(wid - 0.5, 2.4, len - 0.5, x, y - 1.2, zc, t.body);
        this.deco(wid + 0.12, 0.3, len + 0.12, x, y - 0.7, zc, t.accent, { neon: true });
        if (big) this.deco(wid * 0.6, 2.2, len * 0.6, x, y - 3.5, zc, t.body2);
      } else if (t.style === 'ice') {
        this.deco(wid - 0.4, 2, len - 0.4, x, y - 1, zc, t.body, { alpha: 0.85 });
        if (big) { const h = rnd(1.5, 3.2); this.deco(0.9, h, 0.9, x + rnd(-0.3, 0.3) * wid, y - 2 - h / 2, zc + rnd(-0.3, 0.3) * len, t.body2, { alpha: 0.8 }); }
      } else if (t.style === 'tech') {
        this.deco(wid - 0.6, 0.8, len - 0.6, x, y - 0.4, zc, t.body);
        this.deco(0.25, 0.4, len, x - wid / 2 - 0.12, y + t.thick / 2, zc, t.accent, { neon: true });
        this.deco(0.25, 0.4, len, x + wid / 2 + 0.12, y + t.thick / 2, zc, t.accent2, { neon: true });
      } else {
        this.deco(wid * 0.6, 0.5, len * 0.6, x, y - 0.3, zc, t.accent, { neon: true });
        if (big) this.deco(wid * 0.34, 2.6, len * 0.34, x, y - 1.9, zc, t.body, { alpha: 0.9, spin: [0, rad(45), 0] });
      }
    },
    floor(len, wid, o) {
      o = o || {};
      const t = this.theme, x = o.x || 0, thick = o.thick || t.thick;
      const top = this.block(wid, thick, len, x, -thick / 2, len / 2, o.color || t.floor, o.extra);
      if (!o.bare) this.underside(wid, len, x, -thick, len / 2);
      const marks = Math.max(1, Math.round(len / 14));
      for (let i = 1; i <= marks; i++) this.mark(Math.abs(x) + wid / 2, (len * (i - 0.5)) / marks);
      if (!o.stay) this.fwd(len);
      return top;
    },
    hop(gap, rise, len, wid, o) { this.move(0, rise, gap); return this.floor(len, wid, o); },
    slab(len, wid, x, y, zc, o) {
      o = o || {};
      const part = this.block(wid, 1.2, len, x, y - 0.6, zc, o.color || this.theme.mover);
      this.mark(Math.abs(x) + wid / 2 + 6, zc);
      return part;
    },
    ice(len, wid, o) { o = Object.assign({}, o, { color: 0xa0e1ff, extra: { ice: true, alpha: 0.92 } }); return this.floor(len, wid, o); },
    vanish(len, wid, x, o) {
      o = o || {}; x = x || 0;
      const part = this.block(wid, 1, len, x, -0.5, len / 2, this.theme.vanish, { kind: 'vanish', delay: o.delay || 0.55, respawn: 3 });
      this.mark(Math.abs(x) + wid / 2, len / 2);
      this.fwd(len);
      return part;
    },
    conveyor(len, wid, vx, vz) {
      const t = this.theme;
      this.block(wid, 1.2, len, 0, -0.6, len / 2, 0x2c303e, { conveyor: this.wv(vx, 0, vz) });
      this.deco(0.5, 0.6, len, -(wid / 2 + 0.25), -0.3, len / 2, t.accent, { neon: true });
      this.deco(0.5, 0.6, len, wid / 2 + 0.25, -0.3, len / 2, t.accent, { neon: true });
      if (Math.abs(vz) >= Math.abs(vx)) {
        const n = Math.max(2, Math.floor(len / 6)), travel = len - 1;
        for (let i = 0; i < n; i++) {
          const a = this.deco(wid * 0.55, 0.08, 0.7, 0, 0.05, vz > 0 ? 0.5 : len - 0.5, t.accent, { neon: true });
          this.mover(a, 0, 0, vz > 0 ? travel : -travel, travel / Math.abs(vz), i / n, 'loop');
        }
      } else {
        const n = Math.max(2, Math.floor(wid / 3)), travel = wid - 1;
        for (let i = 0; i < n; i++) {
          const a = this.deco(0.7, 0.08, len * 0.6, vx > 0 ? -(wid / 2 - 0.5) : wid / 2 - 0.5, 0.05, len / 2, t.accent, { neon: true });
          this.mover(a, vx > 0 ? travel : -travel, 0, 0, travel / Math.abs(vx), i / n, 'loop');
        }
      }
      this.mark(wid / 2, len / 2);
      this.fwd(len);
    },
    cliff(h, wid) {
      const t = this.theme; wid = wid || 10;
      this.block(wid - 0.4, h + 3 - t.thick, 3, 0, (h - t.thick - 3) / 2, 1.5, t.body);
      this.up(h);
    },
    truss(h, x, y0, z) {
      return this.block(2, h, 2, x, y0 + h / 2, z, this.theme.ladder, { ladder: true });
    },
    ladder(h, wid) {
      const t = this.theme; wid = wid || 8;
      this.block(wid, t.thick, 2, 0, -t.thick / 2, 1, t.floor);
      this.truss(h, 0, 0, 1);
      this.block(wid - 0.4, h + 3 - t.thick, 2.5, 0, (h - t.thick - 3) / 2, 3.25, t.body);
      this.mark(wid / 2, 1);
      this.move(0, h, 2);
    },

    mover(part, dx, dy, dz, period, phase, ease) {
      const d = this.wv(dx, dy, dz);
      part.anim = { type: 'mover', p0: part.c.slice(), d, period, phase: phase || 0, ease: ease || 'sine' };
      return part;
    },
    rotor(part, px, py, pz, ax, ay, az, speed, o) {
      o = o || {};
      part.anim = { type: 'rotor', pivot: this.w(px, py, pz), axis: this.wv(ax, ay, az), speed, swing: o.swing, period: o.period || 3, phase: o.phase || 0, upright: !!o.upright };
      return part;
    },
    blink(part, on, off, phase, solidTile) { part.blink = { on, off, phase: phase || 0, tile: !!solidTile }; return part; },

    kill(sx, sy, sz, x, y, z, extra) {
      return this.block(sx, sy, sz, x, y, z, this.theme.hazard, Object.assign({ solid: false, kill: true, neon: true }, extra));
    },
    killBall(d, x, y, z) { return this.ball(d, x, y, z, this.theme.hazard, { kill: true, neon: true }); },
    lavaSea(len, wid, depth) {
      return this.block(wid, 2, len, 0, -depth - 1, len / 2 - 6, this.theme.lava || this.theme.hazard, { solid: false, kill: true, neon: true });
    },
    laser(sx, sy, sz, x, y, z, on, off, phase) { return this.blink(this.kill(sx, sy, sz, x, y, z), on, off, phase); },
    jet(z, wid, on, off, phase) {
      this.deco(wid, 0.2, 2.4, 0, 0.1, z, 0x222432);
      this.deco(wid - 1, 0.1, 0.6, 0, 0.22, z, this.theme.accent, { neon: true });
      return this.blink(this.kill(wid, 7, 1.6, 0, 3.7, z, { color: 0xff821e, alpha: 0.8 }), on, off, phase);
    },
    spinner(z, len, speed, o) {
      o = o || {};
      const y = o.high ? 7.6 : 1.1, thick = o.high ? 0.8 : 1;
      if (!o.noHub) this.cyl(2.2, y + 0.9, 0, (y + 0.9) / 2, z, this.theme.post);
      this.rotor(this.kill(len, thick, thick, 0, y, z), 0, y, z, 0, 1, 0, speed);
      if (o.cross) this.rotor(this.kill(thick, thick, len, 0, y, z), 0, y, z, 0, 1, 0, speed);
    },
    pendulum(z, o) {
      const t = this.theme, arm = 13, pivotY = arm + 2, base = o.base || -8, span = 7.5, ph = pivotY - base + 0.6;
      this.deco(0.9, ph, 0.9, -span, base + ph / 2, z, t.post);
      this.deco(0.9, ph, 0.9, span, base + ph / 2, z, t.post);
      this.deco(span * 2 + 0.9, 0.9, 0.9, 0, pivotY + 0.3, z, t.post);
      const sw = { swing: rad(55), period: 3.2, phase: o.phase || 0 };
      this.rotor(this.deco(0.5, arm, 0.5, 0, pivotY - arm / 2, z, t.post), 0, pivotY, z, 0, 0, 1, 0, sw);
      this.rotor(this.kill(5, 3.2, 1, 0, pivotY - arm, z), 0, pivotY, z, 0, 0, 1, 0, sw);
    },
    crusher(z, o) {
      const t = this.theme, wid = 8, len = 5, h = 7, clear = 9, drop = -(clear - 0.4);
      const m = (p) => this.mover(p, 0, drop, 0, o.period, o.phase, 'slam');
      m(this.block(wid, h, len, 0, clear + h / 2, z, t.post, { solid: false, kill: true }));
      m(this.kill(wid + 0.3, 0.7, len + 0.3, 0, clear + 0.2, z));
      m(this.deco(wid + 0.2, 0.6, len + 0.2, 0, clear + h / 2 + 1, z, 0xffc828, { neon: true }));
      for (const side of [-1, 1]) this.deco(0.7, 20, 0.7, side * (wid / 2 + 0.7), 9, z, t.post);
    },

    coin(x, y, z) { this.coins++; return this.add({ shape: 'coin', c: this.w(x, y, z), r: 1.2, h: 0.35, s: [2.4, 2.4, 0.35], color: 0xffc828, neon: true, kind: 'coin', id: this.coins, solid: false }); },
    coinRow(n, x, y, z, dx, dy, dz) { for (let i = 0; i < n; i++) this.coin(x + (dx || 0) * i, y + (dy || 0) * i, z + (dz || 0) * i); },
    powerup(kind, x, y, z) {
      const cfg = POWERS[kind];
      this.decoCyl(4.4, 0.2, x, y - 2.9, z, cfg.color, { neon: true, alpha: 0.55 });
      return this.ball(3, x, y, z, cfg.color, { neon: true, alpha: 0.85, kind: 'power', power: kind, label: cfg.icon });
    },
    boostPad(x, z, kind, time) {
      const cfg = POWERS[kind];
      for (let i = -1; i <= 1; i++) this.deco(3.4, 0.1, 0.5, x, 0.34, z + i * 1.2, 0xffffff, { neon: true });
      return this.block(5, 0.3, 4, x, 0.15, z, cfg.color, { solid: false, neon: true, kind: 'power', power: kind, pad: true, time: time || 2.5 });
    },
    bounce(x, z, power, d) {
      d = d || 5;
      this.cyl(d + 0.8, 0.2, x, 0.1, z, 0x222432);
      return this.cyl(d, 0.3, x, 0.35, z, 0xff50aa, { neon: true, kind: 'bounce', power });
    },

    gate(radius, text, color) {
      const t = this.theme, span = radius + 2.5;
      for (const side of [-1, 1]) {
        this.deco(2.6, 19, 2.6, side * span, 8.5, 0, t.post);
        this.deco(2.9, 0.5, 2.9, side * span, 15.5, 0, color, { neon: true });
        this.deco(2.9, 0.5, 2.9, side * span, 3, 0, color, { neon: true });
      }
      this.deco(span * 2 + 6, 3.6, 2.4, 0, 19.6, 0, t.post, { sign: text, signColor: color });
      this.deco(span * 2 + 6.4, 0.4, 2.7, 0, 21.6, 0, color, { neon: true });
      this.deco(span * 2 + 6.4, 0.4, 2.7, 0, 17.6, 0, color, { neon: true });
    },
    checkpoint() {
      this.stage++;
      const index = this.stage, info = STAGES[index - 1], finish = index === FINISH;
      const zi = zoneOf(index), zone = ZONES[zi - 1], prev = STAGES[index - 2];
      const newZone = index === 1 || (prev && prev.zone !== zi);
      this.theme = THEMES[zi - 1];
      const t = this.theme;
      this.trail = [];
      const radius = newZone || finish ? 13 : 8;
      const centre = this.w(0, 0, radius - 1);
      const exitYaw = this.yaw + rad(info ? info.turn : 0);
      this.push();
      this.p = centre;
      this.cyl(radius * 2, 1.7, 0, -0.65, 0, t.plaza);
      this.decoCyl(radius * 2 + 0.7, 0.5, 0, -0.75, 0, zone.color, { neon: true });
      this.decoCyl(radius * 1.5, 2.4, 0, -2.7, 0, t.body);
      this.decoCyl(radius * 0.8, 2.2, 0, -5, 0, t.body2);
      this.decoCyl(7, 0.2, 0, 0.3, 0, 0xffffff, { neon: true, lamp: index });
      for (const side of [-1, 1]) {
        this.deco(0.8, 7.4, 0.8, side * (radius - 1.4), 3.9, 0, t.post);
        this.ball(1.8, side * (radius - 1.4), 8.2, 0, 0xffffff, { neon: true, lamp: index });
      }
      this.add({ shape: 'label', c: this.w(0, 17, 0), s: [13, 6.5, 1], solid: false,
        title: finish ? '🏁 FINISH' : index === 1 ? 'START' : String(index), sub: info ? info.name : 'You made it!', color: zone.color });
      if (finish) this.gate(radius, '🏆  FINISH  🏆', 0xffc828);
      else if (newZone) this.gate(radius, 'ZONE ' + zi + '  ·  ' + zone.name.toUpperCase(), zone.color);
      this.pop();
      checkpoints[index] = { index, p: [centre[0], centre[1] + 0.2, centre[2]], yaw: exitYaw, radius };
      this.p = centre; this.yaw = exitYaw;
      this.fwd(radius - 1);
      this.mark(radius, -(radius - 1));
    },
  };

  // ------------------------------------------------------------ scenery
  const D = {
    tree(x, y, z, s) {
      K.decoCyl(1.3 * s, 5 * s, x, y + 2.5 * s, z, 0x7a563c);
      K.ball(6.4 * s, x, y + 6.4 * s, z, 0x46aa46);
      K.ball(4.6 * s, x + 1.7 * s, y + 5.2 * s, z + 0.9 * s, 0x5cbe50);
      K.ball(4.8 * s, x - 1.5 * s, y + 5.5 * s, z - s, 0x3a9642);
    },
    pine(x, y, z, s) {
      K.decoCyl(1.1 * s, 3 * s, x, y + 1.5 * s, z, 0x604636);
      [6.5, 5, 3.4, 1.8].forEach((d, i) => {
        const h = y + (2.4 + (i + 1) * 1.9) * s;
        K.decoCyl(d * s, 1.9 * s, x, h, z, 0x2e6e56);
        K.decoCyl(d * s * 0.8, 0.4 * s, x, h + 1.1 * s, z, 0xf0f8ff);
      });
    },
    rock(x, y, z, s, color) {
      for (let i = 0; i < 2; i++) K.deco(s * rnd(0.7, 1.2), s * rnd(0.6, 1), s * rnd(0.7, 1.2), x + rnd(-0.3, 0.3) * s, y + s * 0.3, z + rnd(-0.3, 0.3) * s, color, { spin: [rnd(-0.3, 0.3), rnd(0, 1.5), rnd(-0.3, 0.3)] });
    },
    cloud(x, y, z, s) {
      const e = { alpha: 0.9 };
      K.ball(12 * s, x, y, z, 0xffffff, e); K.ball(9 * s, x + 7 * s, y - s, z + 2 * s, 0xffffff, e);
      K.ball(8 * s, x - 7 * s, y - 1.5 * s, z - s, 0xffffff, e);
    },
    islet(x, y, z, r) {
      K.decoCyl(r * 2, 1.2, x, y, z, 0x62be56); K.decoCyl(r * 1.5, 2.6, x, y - 1.9, z, 0x866248); K.decoCyl(r * 0.8, 2.2, x, y - 4.3, z, 0x705a4c);
      if (rnd() < 0.7) D.tree(x, y + 0.6, z, rnd(0.8, 1.3) * Math.min(1.4, r / 6)); else D.rock(x, y + 0.6, z, r * 0.5, 0x96969e);
    },
    spire(x, y, z, w, h) {
      K.deco(w, h * 0.5, w, x, y + h * 0.25, z, 0x302c32, { spin: [0, rnd(0, 1.5), 0] });
      K.deco(w * 0.68, h * 0.35, w * 0.68, x, y + h * 0.66, z, 0x302c32, { spin: [0.07, rnd(0, 1.5), 0.07] });
      K.deco(w * 0.4, h * 0.25, w * 0.4, x, y + h * 0.92, z, 0x242026, { spin: [-0.1, rnd(0, 1.5), 0.1] });
      K.deco(w * 0.72, 0.4, w * 0.72, x, y + h * 0.5, z, 0xff781e, { neon: true });
    },
    iceIslet(x, y, z, r) {
      K.decoCyl(r * 2, 1.2, x, y, z, 0xf0f8ff); K.decoCyl(r * 1.4, 3, x, y - 2.1, z, 0x8cc3eb, { alpha: 0.9 });
      if (rnd() < 0.6) D.pine(x, y + 0.6, z, rnd(0.8, 1.3)); else D.crystals(x, y + 0.6, z, r * 0.8, 0x96e1ff);
    },
    crystals(x, y, z, s, color) {
      for (let i = 0; i < 3; i++) { const h = s * rnd(0.8, 1.6); K.deco(s * 0.3, h, s * 0.3, x + (i - 1) * s * 0.3, y + h * 0.4, z + rnd(-0.2, 0.2) * s, color, { neon: true, alpha: 0.75, spin: [rnd(-0.4, 0.4), 0.78, rnd(-0.4, 0.4)] }); }
    },
    building(x, y, z, w, d) {
      const bottom = -150, h = y - bottom;
      K.deco(w, h, d, x, bottom + h / 2, z, 0x141422);
      const color = [0x00f0e6, 0xff00c8, 0xffdc28, 0x785aff][Math.floor(rnd() * 4)];
      for (let i = 0; i < 4; i++) K.deco(w + 0.3, 0.7, d + 0.3, x, y - 4 - i * 9, z, color, { neon: true });
      K.ball(1.4, x, y + 1, z, 0xff283c, { neon: true });
    },
    planet(x, y, z, d, color, ring) {
      K.ball(d, x, y, z, color);
      if (ring) K.decoCyl(d * 1.9, 0.5, x, y, z, ring, { neon: true, alpha: 0.55, spin: [0, 0, 0.42] });
    },
    peak(x, y, z, base, h, color, top) {
      for (let i = 0; i < 5; i++) K.decoCyl(base * (1 - (i / 5) * 0.82), h / 5 + 0.5, x, y + h * (i / 5 + 0.1), z, color);
      if (top) K.decoCyl(base * 0.2, 2, x, y + h + 0.6, z, top, { neon: true });
    },
    scatter(zi) {
      const saved = [K.p, K.yaw];
      K.trail.forEach((pt, i) => {
        if (i % 2 === 0 || rnd() < 0.3) {
          const side = rnd() < 0.5 ? -1 : 1;
          K.p = pt.p; K.yaw = pt.yaw;
          const x = side * (pt.clear + 13 + rnd(0, 14));
          if (zi === 1) D.islet(x, rnd(-12, 3), 0, rnd(5, 8));
          else if (zi === 2) D.spire(x, -14, 0, rnd(5, 9), rnd(16, 34));
          else if (zi === 3) D.iceIslet(x, rnd(-12, 3), 0, rnd(5, 8));
          else if (zi === 4) D.building(x + (x > 0 ? 4 : -4), rnd(-6, 36), 0, rnd(10, 17), rnd(10, 17));
          else { const y = rnd(-14, 8); if (rnd() < 0.5) D.rock(x, y, 0, rnd(4, 8), 0x544a78); D.crystals(x, y + 2, 0, rnd(4, 7), [0x9ad0ff, 0xc8a0ff, 0xffb0e8][Math.floor(rnd() * 3)]); }
        }
      });
      K.p = saved[0]; K.yaw = saved[1];
    },
    backdrop(zi) {
      if (zi === 1) {
        D.islet(-24, -3, -4, 8); D.islet(24, -2, -18, 9);
        K.deco(30, 10, 1, 0, 14, -56, 0x96683e, { sign: 'BOBUX OBBY', signColor: 0xffd640 });
        for (let i = 1; i <= 12; i++) D.cloud((i % 2 ? -1 : 1) * rnd(70, 220), rnd(-50, 60), i * 50, rnd(1.5, 3.5));
        for (let i = 1; i <= 4; i++) D.islet((i % 2 ? -1 : 1) * rnd(150, 210), rnd(-30, 30), 60 + i * 120, rnd(26, 40));
      } else if (zi === 2) {
        D.peak(-190, -130, 160, 150, 230, 0x2c262a, 0xff6e14); D.peak(200, -150, 380, 170, 260, 0x2c262a, 0xff6e14); D.peak(-170, -140, 560, 130, 200, 0x2c262a, 0xff6e14);
      } else if (zi === 3) {
        D.peak(-200, -160, 140, 170, 280, 0xe8f0fa); D.peak(210, -170, 330, 190, 320, 0xe8f0fa); D.peak(-190, -150, 520, 150, 250, 0xe8f0fa);
      } else if (zi === 4) {
        for (let i = 1; i <= 14; i++) D.building((i % 2 ? -1 : 1) * rnd(120, 200), rnd(60, 200), i * 40, rnd(26, 44), rnd(26, 44));
      } else {
        D.planet(-230, 90, 200, 110, 0xe6965a, 0xffdca0); D.planet(260, 20, 420, 150, 0x5a78dc); D.planet(-200, 180, 600, 70, 0xbe6edc, 0xa0e6ff); D.planet(170, 220, 120, 40, 0xe6e6f0);
      }
    },
  };

  // ------------------------------------------------------------ stages
  const S = {
    FirstSteps() {
      K.hop(4, 0, 7, 7); K.coin(0, 3.5, -3.5);
      K.hop(4, 1, 6, 6, { x: 3 }); K.coin(3, 3.5, -3);
      K.hop(4.5, 1, 6, 6, { x: -3 }); K.coin(-3, 3.5, -3);
      K.hop(5, 0, 6, 6, { x: 2 });
      K.hop(5, 1, 5, 5, { x: -2 }); K.coin(-2, 3.5, -2.5);
      K.hop(5.5, 0, 5, 5); K.coin(0, 5.5, 2.5);
      K.fwd(4.5);
    },
    LadderCliffs() {
      K.floor(8, 8); K.ladder(10); K.floor(8, 8); K.coin(0, 3.5, -4);
      K.hop(4, 0, 6, 6);
      K.fwd(3); K.truss(14, 0, -4, 1); K.coinRow(3, 2.6, 1, 1, 0, 3.5, 0); K.move(0, 10, 2);
      K.hop(3, 0, 7, 7); K.coin(0, 3.5, -3.5);
      K.hop(4.5, 0, 5, 8); K.ladder(16); K.floor(7, 8); K.coinRow(2, -3, 3.5, -3.5, 6, 0, 0);
      K.fwd(4);
    },
    SlidingStones() {
      K.floor(7, 8);
      K.fwd(3); K.mover(K.slab(6, 6, -7, 0, 3), 14, 0, 0, 5, 0); K.coin(0, 4, 3); K.fwd(6);
      K.hop(3, 0, 5, 6);
      K.fwd(2); K.mover(K.slab(6, 6, 0, 0, 3), 0, 0, 16, 6.5, 0, 'hold'); K.coinRow(3, 0, 4.5, 8, 0, 0, 5); K.fwd(22);
      K.hop(2, 0, 6, 6);
      K.fwd(2); K.mover(K.slab(6, 6, 0, 0, 3), 0, 10, 0, 6.5, 0.5, 'hold'); K.move(0, 10, 6);
      K.hop(2, 0, 6, 8); K.coin(0, 3.5, -3);
      K.fwd(3); K.mover(K.slab(5, 5, -6, 0, 2.5), 12, 0, 0, 4.5, 0); K.fwd(8);
      K.mover(K.slab(5, 5, 6, 0, 2.5), -12, 0, 0, 4.5, 0); K.coin(0, 4, 2.5); K.fwd(5);
      K.hop(3, 0, 5, 6); K.fwd(4);
    },
    TurboRunway() {
      K.floor(36, 8);
      for (const z of [-28, -20, -12]) K.kill(8, 1.2, 1, 0, 0.6, z);
      K.coinRow(3, 0, 5.5, -28, 0, 0, 8);
      K.powerup('Speed', 0, 3, -5);
      K.hop(13, 0, 10, 8); K.powerup('Speed', 0, 3, -5); K.coin(0, 6, -16.5);
      K.hop(13, 0, 9, 8); K.powerup('Speed', 0, 3, -4.5);
      K.hop(12, 1, 8, 8); K.coinRow(2, -2, 3.5, -4, 4, 0, 0);
      K.fwd(4);
    },
    SpinCycle() {
      const t = K.theme;
      K.floor(5, 8);
      for (const spec of [[1.5, false], [-2, false], [1.3, true]]) {
        K.fwd(4);
        K.cyl(16, 1.5, 0, -0.75, 8, t.floor); K.decoCyl(12, 2.6, 0, -2.8, 8, t.body); K.mark(8, 8);
        K.spinner(8, 15, spec[0], { cross: spec[1] });
        K.coin(5, 3.5, 8); K.coin(-5, 3.5, 8);
        K.fwd(16);
      }
      K.fwd(4);
    },
    SkylineBeams() {
      const wood = 0xc48c54;
      K.floor(5, 8);
      K.hop(2, 0, 18, 2, { bare: true, color: wood }); K.coinRow(3, 0, 3.5, -14, 0, 0, 5);
      K.hop(3, 0, 5, 5);
      K.hop(2, 0, 14, 1.6, { bare: true, color: wood, x: -1.5 });
      K.floor(14, 1.6, { bare: true, color: wood, x: 1.5 }); K.coin(1.5, 3.5, -7);
      K.hop(3, 0, 5, 5);
      K.fwd(3); K.mover(K.slab(14, 2, -4, 0, 7, { color: wood }), 8, 0, 0, 5, 0); K.fwd(14);
      K.hop(3, 0, 6, 8);
      K.fwd(2); K.mover(K.slab(7, 7, 0, 0, 3.5), 0, 16, 0, 8, 0, 'hold'); K.move(0, 16, 7); K.fwd(2);
    },
    HotFeet() {
      const t = K.theme;
      K.floor(5, 8); K.lavaSea(106, 56, 5);
      [[4, 0, 5, 0], [4.5, 1, 4, 3], [4.5, 1, 4, -2], [5, -1, 4, 2], [5, 0, 4, -3], [5, 1, 4, 0], [5.5, 0, 3.5, 3], [5, -1, 4, -1], [4, 0, 6, 0]].forEach((h, i) => {
        K.hop(h[0], h[1], h[2], h[2], { x: h[3] });
        K.deco(h[2] - 1.4, 9, h[2] - 1.4, h[3], -8.5, -h[2] / 2, t.body2);
        if (i % 2 === 1) K.coin(h[3], 3.5, -h[2] / 2);
      });
      K.fwd(4);
    },
    CrumbleBridge() {
      K.floor(5, 8); K.lavaSea(136, 56, 6);
      for (let i = 1; i <= 8; i++) { K.fwd(0.5); K.vanish(5, 6, 0); if (i % 3 === 0) K.coin(0, 3.5, -2.5); }
      K.hop(3, 0, 5, 6);
      for (let i = 1; i <= 6; i++) { K.fwd(4); const x = i % 2 === 0 ? 2.5 : -2.5; K.vanish(4.5, 4.5, x, { delay: 0.8 }); if (i % 2 === 0) K.coin(x, 3.5, -2.25); }
      K.hop(4, 0, 5, 6); K.fwd(4);
    },
    MegaJumpCliffs() {
      K.floor(12, 10); K.powerup('Jump', 0, 3, -5);
      for (let i = 0; i < 3; i++) { K.cliff(13, 10); K.floor(11, 10); K.powerup('Jump', 0, 3, -4); K.coin(-3, 3.5, -8); K.coin(3, 3.5, -8); }
      K.fwd(4);
    },
    FireJets() {
      K.floor(6, 8); K.lavaSea(84, 56, 6); K.floor(58, 6);
      for (let i = 0; i < 7; i++) { const z = -52 + i * 7.5; K.jet(z, 6, 1.3, 1.7, (((-i * 0.14) % 1) + 1) % 1); if (i < 6) K.coin(0, 3.5, z + 3.75); }
      K.fwd(4);
    },
    LavaFerry() {
      K.floor(7, 10); K.lavaSea(114, 56, 6);
      K.fwd(2); K.mover(K.slab(8, 8, 0, 0, 4), 0, 0, 66, 24, 0, 'hold');
      K.kill(10, 1, 1, 0, 0.9, 16); K.kill(5.5, 6, 1, -2.75, 3, 27); K.kill(5.5, 6, 1, 2.75, 3, 37);
      K.kill(10, 1, 1, 0, 0.9, 47); K.kill(5.5, 6, 1, -2.75, 3, 56); K.kill(10, 1, 1, 0, 0.9, 64);
      K.coin(2.5, 4, 27); K.coin(-2.5, 4, 37); K.coin(0, 6.5, 47); K.coin(2.5, 4, 56);
      K.fwd(74); K.hop(2, 0, 8, 10); K.fwd(4);
    },
    PendulumPass() {
      K.floor(6, 8); K.lavaSea(92, 56, 8); K.floor(50, 5);
      for (let i = 0; i < 4; i++) K.pendulum(-42 + i * 10, { phase: i * 0.27, base: -8 });
      K.coinRow(3, 0, 3.5, -37, 0, 0, 10);
      K.ladder(14, 8); K.floor(8, 8); K.coin(0, 3.5, -4); K.fwd(4);
    },
    SlipNSlide() {
      K.floor(5, 8); K.ice(20, 7); K.coinRow(3, 0, 3.5, -15, 0, 0, 5);
      K.fwd(4); K.ice(14, 6, { x: 2 });
      K.fwd(4.5); K.ice(12, 5, { x: -2 }); K.coin(-2, 3.5, -6);
      K.fwd(4.5); K.ice(10, 4.5, { x: 1 });
      K.fwd(5); K.ice(8, 4); K.coin(0, 3.5, -4);
      K.hop(4, 0, 5, 6); K.fwd(4);
    },
    ConveyorChaos() {
      K.floor(5, 8); K.conveyor(22, 6, 0, -9); K.coinRow(3, 0, 3.5, -17, 0, 0, 6);
      K.hop(3, 0, 4, 6); K.conveyor(20, 8, 7, 0); K.kill(0.8, 2.5, 20, 4.9, 1.25, -10); K.coin(-2, 3.5, -10);
      K.hop(3, 0, 4, 6); K.conveyor(20, 8, -7, 0); K.kill(0.8, 2.5, 20, -4.9, 1.25, -10); K.kill(8, 1, 1, 0, 0.6, -13); K.kill(8, 1, 1, 0, 0.6, -6);
      K.hop(3, 0, 4, 6); K.conveyor(18, 6, 0, 13); K.coinRow(2, 0, 3.5, -12, 0, 0, 6);
      K.hop(6.5, 0, 6, 8); K.fwd(4);
    },
    IcicleGauntlet() {
      const t = K.theme;
      K.floor(9, 8); K.powerup('Shield', 0, 3, -3); K.floor(34, 6);
      for (let i = 0; i <= 8; i++) { const z = -31 + i * 3.5; K.kill(6, 6.5, 0.5, 0, 3.25, z, { alpha: 0.65 }); K.deco(0.6, 7, 0.8, -3.3, 3.5, z, t.post); K.deco(0.6, 7, 0.8, 3.3, 3.5, z, t.post); }
      K.floor(7, 8); K.coinRow(3, -2.5, 3.5, -3.5, 2.5, 0, 0); K.fwd(4);
    },
    BouncyGlaciers() {
      K.floor(8, 8); K.bounce(0, -3, 90); K.cliff(14, 8); K.floor(8, 8); K.coin(0, 3.5, -4);
      for (let i = 1; i <= 3; i++) { K.fwd(i === 1 ? 5 : 8); K.floor(5, 5, { stay: true }); K.bounce(0, 2.5, 75, 4.6); K.coin(0, 12, 2.5); K.fwd(5); }
      K.fwd(8); K.floor(8, 8); K.bounce(0, -3, 95); K.cliff(16, 8); K.floor(8, 8); K.coinRow(2, -2, 3.5, -4, 4, 0, 0); K.fwd(4);
    },
    CrusherHall() {
      K.floor(6, 8); K.floor(46, 8);
      for (let i = 0; i < 4; i++) K.crusher(-38 + i * 9.5, { phase: i * 0.23 + 0.1, period: 3.4 });
      K.coinRow(3, 0, 3, -33.25, 0, 0, 9.5); K.fwd(4);
    },
    SpikeballAlley() {
      const t = K.theme;
      K.floor(6, 8); K.floor(20, 4.5); K.ice(24, 4.5); K.floor(20, 4.5);
      for (let i = 1; i <= 6; i++) {
        const z = -57 + (i - 1) * 10;
        K.mover(K.killBall(4.6, -10, 2.4, z), 20, 0, 0, 2.6 + (i % 3) * 0.5, (i * 0.37) % 1);
        K.deco(24, 0.2, 0.8, 0, -0.1, z, t.accent, { neon: true, alpha: 0.5 });
        if (i < 6) K.coin(0, 3.5, z + 5);
      }
      K.fwd(4);
    },
    LaserGrid() {
      const t = K.theme;
      K.floor(6, 8); K.floor(48, 12);
      for (const z of [-40, -30, -20, -10]) { K.kill(12.4, 0.5, 0.5, 0, 7.5, z); K.deco(0.6, 8.2, 0.6, -6.5, 4, z, t.post); K.deco(0.6, 8.2, 0.6, 6.5, 4, z, t.post); }
      K.mover(K.kill(12.4, 0.6, 0.6, 0, 0.8, -44), 0, 0, 18, 5, 0);
      K.mover(K.kill(12.4, 0.6, 0.6, 0, 0.8, -6), 0, 0, -18, 5.6, 0.3);
      K.mover(K.kill(1, 7, 1, -5, 3.5, -35), 10, 0, 0, 4, 0);
      K.mover(K.kill(1, 7, 1, 5, 3.5, -15), -10, 0, 0, 4.4, 0.5);
      K.coinRow(4, -3, 3, -35, 2, 0, 8); K.fwd(4);
    },
    BoostBoulevard() {
      K.floor(14, 8); K.boostPad(0, -7, 'Speed', 2.5);
      for (let i = 1; i <= 4; i++) { K.hop(12.5 + (i > 2 ? 0.5 : 0), i === 3 ? 1 : 0, 14, 7); if (i < 4) K.boostPad(0, -7, 'Speed', 2.5); K.coin(0, 6, -20); }
      K.fwd(4);
    },
    Carousel() {
      const t = K.theme;
      K.floor(6, 8); K.fwd(3);
      K.rotor(K.cyl(26, 1.5, 0, -0.75, 13, t.mover), 0, -0.75, 13, 0, 1, 0, 0.7); K.mark(19, 13);
      for (let i = 0; i < 3; i++) { const a = (i * Math.PI * 2) / 3; K.rotor(K.kill(1.6, 7, 1.6, Math.sin(a) * 8, 3.5, 13 + Math.cos(a) * 8), 0, 3.5, 13, 0, 1, 0, 0.7); }
      K.cyl(3, 3, 0, 1.5, 13, t.post); K.coin(-6, 3.5, 13); K.coin(6, 3.5, 13);
      K.fwd(26); K.hop(3, 0, 5, 6);
      K.fwd(3);
      const R = 13, cz = 3.25 + R;
      K.decoCyl(5, 34, 0, 2, cz, t.post); K.decoCyl(6, 0.6, 0, 8, cz, t.accent, { neon: true }); K.decoCyl(6, 0.6, 0, 14, cz, t.accent2, { neon: true });
      K.rotor(K.deco(0.6, 0.4, R * 2 - 6, 0, -1, cz, t.accent, { neon: true }), 0, -1, cz, 0, 1, 0, 0.55);
      K.rotor(K.deco(R * 2 - 6, 0.4, 0.6, 0, -1, cz, t.accent, { neon: true }), 0, -1, cz, 0, 1, 0, 0.55);
      for (let i = 0; i < 4; i++) { const a = (i * Math.PI) / 2; K.rotor(K.cyl(6.5, 1.2, Math.sin(a) * R, -0.6, cz - Math.cos(a) * R, t.mover), 0, -0.6, cz, 0, 1, 0, 0.55); }
      K.mark(R + 4, cz); K.coin(0, 4, cz - R); K.coin(0, 4, cz + R);
      K.fwd(6.5 + R * 2); K.hop(3, 0, 6, 8); K.fwd(4);
    },
    DoubleTrouble() {
      K.floor(9, 8); K.powerup('DoubleJump', 0, 3, -4);
      K.hop(12, 0, 8, 7); K.powerup('DoubleJump', 0, 3, -4); K.coin(0, 8, -14);
      K.hop(12, 2, 8, 7); K.powerup('DoubleJump', 0, 3, -4); K.coin(0, 8, -14);
      K.hop(6, 8, 8, 7); K.powerup('DoubleJump', 0, 3, -4);
      K.hop(12.5, 0, 9, 8); K.coinRow(2, -2, 3.5, -4.5, 4, 0, 0); K.fwd(4);
    },
    LadderLasers() {
      const t = K.theme;
      K.floor(6, 8); K.ladder(12); K.floor(7, 8); K.coin(0, 3.5, -3.5); K.ladder(18);
      [-13, -5].forEach((y, i) => { K.laser(7, 0.5, 3.4, 0, y, -1.2, 1.2, 1.6, i * 0.5); K.deco(0.8, 1, 1, -3.9, y, -1.2, t.post); K.deco(0.8, 1, 1, 3.9, y, -1.2, t.post); });
      K.floor(7, 8);
      K.fwd(3); K.truss(12, 0, -2, 1); K.move(0, 10, 2);
      K.fwd(3); K.truss(12, 0, -6, 1); K.coinRow(2, 2.6, -3, 1, 0, 4, 0); K.move(0, 6, 2);
      K.hop(3, 0, 7, 8); K.fwd(4);
    },
    NeonRush() {
      K.floor(6, 8);
      for (let i = 1; i <= 5; i++) {
        K.fwd(3);
        if (i > 1) K.laser(20, 6, 0.4, 0, 3, -1.5, 1, 2, (i * 0.31) % 1);
        const dir = i % 2 === 0 ? 1 : -1;
        K.mover(K.slab(5, 6, dir * 6, 0, 2.5), -dir * 12, 0, 0, 5, 0);
        if (i % 2 === 1) K.coin(0, 4, 2.5);
        K.fwd(5);
      }
      K.hop(3, 0, 5, 6);
      for (let i = 1; i <= 5; i++) { K.fwd(3.5); K.vanish(4, 4, i % 2 === 0 ? 2 : -2, { delay: 0.7 }); }
      K.hop(3.5, 0, 5, 6); K.fwd(4);
    },
    MoonBoots() {
      K.floor(9, 8); K.powerup('Feather', 0, 3, -4);
      [[18, 2], [19, 4], [18, -2], [16, 8]].forEach((h, i, all) => { K.hop(h[0], h[1], 9, 8); K.coin(0, 9, -9 - h[0] / 2); if (i < all.length - 1) K.powerup('Feather', 0, 3, -4); });
      K.fwd(4);
    },
    StarWheel() {
      const t = K.theme;
      K.floor(6, 8); K.fwd(3);
      const R = 14, cz = 3 + R, speed = -0.45;
      K.deco(1, 60, 1, -1.6, -30.6, cz, t.post); K.deco(1, 60, 1, 1.6, -30.6, cz, t.post);
      for (let i = 0; i < 3; i++) K.rotor(K.deco(0.5, 0.5, R * 2, 0, -0.6, cz, t.accent2, { neon: true, spinLocal: [(i * Math.PI) / 3, 0, 0] }), 0, -0.6, cz, 1, 0, 0, speed);
      for (let i = 0; i < 6; i++) { const a = (i * Math.PI) / 3; K.rotor(K.slab(6, 6, 0, Math.sin(a) * R, cz - Math.cos(a) * R), 0, -0.6, cz, 1, 0, 0, speed, { upright: true }); }
      K.mark(9, cz); K.coin(0, R + 4, cz);
      K.fwd(6 + R * 2); K.hop(3, 0, 6, 8);
      K.hop(5, 1, 5, 5, { x: 2 }); K.coin(2, 3.5, -2.5);
      K.hop(5, 1, 5, 5, { x: -2 }); K.coin(-2, 3.5, -2.5); K.fwd(4);
    },
    PhaseTiles() {
      const xs = [0, 3, 0, -3, 0, 3, 0, -3];
      K.floor(6, 8);
      for (let i = 1; i <= 8; i++) {
        K.fwd(3);
        K.blink(K.slab(6, 6, xs[i - 1], 0, 3, { color: K.theme.accent2 }), 2.2, 1.8, i % 2 === 0 ? 0.5 : 0, true);
        if (i % 2 === 0) K.coin(xs[i - 1], 3.5, 3);
        K.fwd(6);
      }
      K.hop(3, 0, 5, 6); K.fwd(4);
    },
    SpinnerGauntlet() {
      K.floor(6, 8); K.floor(88, 8);
      [{ s: 1.6 }, { s: -2 }, { s: 1.5, high: -1.1 }, { s: 1.4, cross: true }, { s: 2.1, high: -1.3, highCross: true }].forEach((sp, i, all) => {
        const z = -78 + i * 17;
        K.spinner(z, 16, sp.s, { cross: sp.cross, noHub: sp.high !== undefined });
        if (sp.high) K.spinner(z, 16, sp.high, { high: true, cross: sp.highCross });
        if (i < all.length - 1) K.coin(0, 3.5, z + 8.5);
      });
      K.fwd(4);
    },
    PowerTrip() {
      K.floor(9, 8); K.powerup('Speed', 0, 3, -4);
      K.hop(13, 0, 10, 8); K.powerup('Jump', 0, 3, -5);
      K.cliff(13, 8); K.floor(10, 8); K.powerup('Shield', 0, 3, -3);
      K.floor(26, 6);
      for (let i = 0; i <= 6; i++) K.kill(6, 6.5, 0.5, 0, 3.25, -24 + i * 3.5, { alpha: 0.65 });
      K.floor(9, 8); K.powerup('DoubleJump', 0, 3, -4); K.coin(0, 3.5, -7);
      K.hop(12, 1, 9, 8); K.powerup('Feather', 0, 3, -4);
      K.hop(19, 3, 9, 8); K.coinRow(2, -2, 3.5, -4.5, 4, 0, 0); K.fwd(4);
    },
    TheAscent() {
      const t = K.theme;
      K.floor(6, 8);
      const sx = -16.8, sz = 4.5;
      K.decoCyl(12, 40, sx, -10, sz, t.body2, { alpha: 0.9 }); K.decoCyl(8, 40, sx, 30, sz, t.body, { alpha: 0.9 }); K.decoCyl(4, 30, sx, 65, sz, t.accent2, { neon: true, alpha: 0.8 });
      for (let i = 0; i < 4; i++) K.decoCyl(14 - i * 2.5, 0.8, sx, i * 20, sz, t.accent, { neon: true });
      const kinds = { 4: 'truss', 10: 'truss', 15: 'truss', 6: 'lift', 12: 'lift', 8: 'vanish', 14: 'vanish' };
      for (let i = 1; i <= 18; i++) {
        const kind = kinds[i];
        if (kind === 'truss') { K.fwd(2); K.truss(8, 0, -2, 1); K.move(0, 6, 2); K.floor(5, 5); }
        else if (kind === 'lift') { K.fwd(4); K.mover(K.slab(5, 5, 0, 0, 2.5), 0, 5, 0, 5, 0, 'hold'); K.move(0, 5, 5); }
        else if (kind === 'vanish') { K.move(0, 2.5, 4); K.vanish(5, 5, 0, { delay: 0.8 }); }
        else { K.hop(4, 2.5, 5, 5); if (i % 2 === 1) K.coin(0, 3.5, -2.5); }
        K.turn(-30);
      }
      K.turn(90); K.hop(4, 2, 10, 6); K.fwd(3);
    },
  };

  let lastZone = 0;
  STAGES.forEach((stage) => {
    K.checkpoint();
    if (stage.zone !== lastZone) { lastZone = stage.zone; K.push(); D.backdrop(stage.zone); K.pop(); }
    S[stage.key]();
    D.scatter(stage.zone);
  });
  K.checkpoint();
  // trophy beyond the finish line
  K.decoCyl(10, 1.2, 0, -0.4, 9, 0x3c326e); K.decoCyl(5, 1.4, 0, 0.9, 9, 0xffc828); K.decoCyl(1.6, 4, 0, 3.6, 9, 0xffc828);
  K.ball(6, 0, 8, 9, 0xffc828); K.decoCyl(7, 1, 0, 10.6, 9, 0xffc828); K.ball(2.4, 0, 13.4, 9, 0xfff5aa, { neon: true });

  return { ents, checkpoints, coinCount: K.coins };
}
