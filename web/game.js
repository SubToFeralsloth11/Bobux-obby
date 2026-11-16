/*
  game.js — the engine: rendering (three.js), a small character controller
  with moving-platform support, hazards, power-ups, camera, input for
  keyboard + mouse + touch + gamepad, sound, saving and the HUD.
  Units match the level data: 16 studs/s walk, 50 jump, 196.2 gravity.
*/
'use strict';
(function () {
  const $ = (id) => document.getElementById(id);
  const V3 = THREE.Vector3;
  const WALK = 16, JUMP = 50, GRAVITY = 196.2, PH = 5, PR = 0.6, CLIMB = 13;
  const SKINS = [
    { id: 'blue', name: 'Classic Blue', price: 0, color: 0x3c8cff },
    { id: 'green', name: 'Meadow', price: 20, color: 0x46c85a },
    { id: 'red', name: 'Ember', price: 45, color: 0xff5a3c },
    { id: 'ice', name: 'Frost', price: 80, color: 0x8ce1ff },
    { id: 'pink', name: 'Neon Pink', price: 120, color: 0xff46c8 },
    { id: 'purple', name: 'Galaxy', price: 170, color: 0x8c5aff },
    { id: 'gold', name: 'Solid Gold', price: 250, color: 0xffc828 },
  ];

  // ------------------------------------------------------------ save
  const SAVE_KEY = 'bobux-obby-v1';
  let save = { stage: 1, max: 1, coins: 0, got: [], skins: ['blue'], skin: 'blue', best: 0, wins: 0, elapsed: 0, finished: false, sound: true };
  try { const raw = localStorage.getItem(SAVE_KEY); if (raw) save = Object.assign(save, JSON.parse(raw)); } catch (e) { /* storage unavailable */ }
  let lastSave = 0;
  function persist() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* ignore */ } }

  // ------------------------------------------------------------ sound
  let audio = null;
  function beep(freq, dur, type, vol, slide) {
    if (!save.sound) return;
    try {
      audio = audio || new (window.AudioContext || window.webkitAudioContext)();
      const o = audio.createOscillator(), g = audio.createGain(), t = audio.currentTime;
      o.type = type || 'sine'; o.frequency.setValueAtTime(freq, t);
      if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq * slide), t + dur);
      g.gain.setValueAtTime(vol || 0.12, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
      o.connect(g); g.connect(audio.destination); o.start(t); o.stop(t + dur);
    } catch (e) { /* no audio */ }
  }
  const sfx = {
    jump: () => beep(380, 0.12, 'square', 0.05, 1.6), coin: () => { beep(990, 0.08, 'square', 0.06); setTimeout(() => beep(1320, 0.12, 'square', 0.06), 70); },
    die: () => beep(220, 0.35, 'sawtooth', 0.1, 0.3), check: () => [523, 659, 784].forEach((f, i) => setTimeout(() => beep(f, 0.16, 'triangle', 0.12), i * 90)),
    power: () => beep(440, 0.3, 'triangle', 0.12, 2.2), powerEnd: () => beep(500, 0.25, 'triangle', 0.08, 0.5), bounce: () => beep(200, 0.25, 'sine', 0.14, 3),
    click: () => beep(700, 0.05, 'square', 0.05), crumble: () => beep(140, 0.2, 'sawtooth', 0.07, 0.6), air: () => beep(600, 0.15, 'sine', 0.1, 1.8),
    win: () => [523, 659, 784, 1047, 784, 1047].forEach((f, i) => setTimeout(() => beep(f, 0.22, 'triangle', 0.13), i * 130)), zone: () => beep(300, 0.5, 'sine', 0.1, 2),
  };

  // ------------------------------------------------------------ scene
  const renderer = new THREE.WebGLRenderer({ canvas: $('view'), antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(ZONES[0].sky);
  scene.fog = new THREE.Fog(ZONES[0].fog, 60, ZONES[0].far);
  const camera = new THREE.PerspectiveCamera(70, 1, 0.5, 2400);
  const hemi = new THREE.HemisphereLight(0xffffff, 0x556070, 0.95);
  const sun = new THREE.DirectionalLight(0xfff2d6, 0.75);
  sun.position.set(0.5, 1, 0.3);
  scene.add(hemi, sun);

  const starGeo = new THREE.BufferGeometry();
  const starPos = [];
  for (let i = 0; i < 900; i++) { const v = new V3().randomDirection().multiplyScalar(1500); if (v.y > -300) starPos.push(v.x, v.y, v.z); }
  starGeo.setAttribute('position', new THREE.Float32BufferAttribute(starPos, 3));
  const stars = new THREE.Points(starGeo, new THREE.PointsMaterial({ color: 0xffffff, size: 5, sizeAttenuation: false, transparent: true, opacity: 0, fog: false }));
  scene.add(stars);

  const GEO = { box: new THREE.BoxGeometry(1, 1, 1), cyl: new THREE.CylinderGeometry(0.5, 0.5, 1, 20), ball: new THREE.SphereGeometry(0.5, 16, 12), coin: new THREE.CylinderGeometry(0.5, 0.5, 1, 16).rotateX(Math.PI / 2), plane: new THREE.PlaneGeometry(1, 1) };
  const matCache = {};
  function material(color, neon, alpha) {
    const key = color + (neon ? 'n' : 'l') + (alpha || 1);
    if (!matCache[key]) {
      const opts = { color, transparent: alpha !== undefined && alpha < 1, opacity: alpha === undefined ? 1 : alpha };
      matCache[key] = neon ? new THREE.MeshBasicMaterial(opts) : new THREE.MeshLambertMaterial(opts);
    }
    return matCache[key];
  }
  function textTexture(lines, w, h) {
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    const g = c.getContext('2d'); g.textAlign = 'center'; g.textBaseline = 'middle'; g.lineJoin = 'round';
    lines.forEach((l) => {
      let size = l.size; g.font = '900 ' + size + 'px system-ui, "Segoe UI", sans-serif';
      while (g.measureText(l.text).width > w * 0.94 && size > 10) { size -= 4; g.font = '900 ' + size + 'px system-ui, "Segoe UI", sans-serif'; }
      g.lineWidth = size * 0.16; g.strokeStyle = '#0a0c18'; g.strokeText(l.text, w / 2, l.y * h);
      g.fillStyle = l.color; g.fillText(l.text, w / 2, l.y * h);
    });
    const tex = new THREE.CanvasTexture(c); tex.anisotropy = 4; return tex;
  }
  const hex = (n) => '#' + n.toString(16).padStart(6, '0');

  // ------------------------------------------------------------ world
  const world = buildWorld();
  const cps = world.checkpoints;
  const ents = world.ents;
  const byStage = [];
  const qYaw = new THREE.Quaternion(), qTmp = new THREE.Quaternion(), UP = new V3(0, 1, 0), eul = new THREE.Euler();

  ents.forEach((e) => {
    let mesh;
    if (e.shape === 'label') {
      mesh = new THREE.Sprite(new THREE.SpriteMaterial({ map: textTexture([{ text: e.title, size: 150, y: 0.36, color: hex(e.color) }, { text: e.sub, size: 60, y: 0.82, color: '#ffffff' }], 512, 256), transparent: true, fog: false }));
      mesh.scale.set(e.s[0], e.s[1], 1);
    } else {
      mesh = new THREE.Mesh(GEO[e.shape], material(e.color, e.neon, e.alpha));
      mesh.scale.set(e.s[0], e.s[1], e.s[2]);
      qYaw.setFromAxisAngle(UP, -e.yaw);
      const sp = e.spin || e.spinLocal;
      if (sp) qYaw.multiply(qTmp.setFromEuler(eul.set(sp[0], sp[1], sp[2])));
      mesh.quaternion.copy(qYaw);
      if (e.sign) {
        const tex = textTexture([{ text: e.sign, size: 96, y: 0.5, color: hex(e.signColor) }], 1024, 128);
        for (const side of [1, -1]) {
          const plane = new THREE.Mesh(GEO.plane, new THREE.MeshBasicMaterial({ map: tex, transparent: true }));
          plane.position.z = side * 0.52; plane.rotation.y = side === 1 ? 0 : Math.PI; plane.scale.set(0.96, 0.8, 1);
          mesh.add(plane);
        }
      }
      if (e.label) {
        const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: textTexture([{ text: e.label, size: 100, y: 0.5, color: '#ffffff' }], 128, 128), transparent: true }));
        s.position.y = 1.1; s.scale.set(0.9, 0.9, 1); mesh.add(s);
      }
    }
    mesh.position.set(e.c[0], e.c[1], e.c[2]);
    e.pos = mesh.position; e.mesh = mesh; e.baseQ = mesh.quaternion.clone();
    e.cos = Math.cos(e.yaw); e.sin = Math.sin(e.yaw);
    e.dx = 0; e.dy = 0; e.dz = 0; e.dth = 0; e.on = true;
    if (e.anim && e.anim.type === 'rotor') {
      const a = e.anim; a.pv = new V3().fromArray(a.pivot); a.ax = new V3().fromArray(a.axis).normalize(); a.rel = e.pos.clone().sub(a.pv);
      a.vertical = Math.abs(a.ax.y) > 0.99;
    }
    if (e.anim && e.anim.type === 'mover') { e.anim.p = new V3().fromArray(e.anim.p0); e.anim.dv = new V3().fromArray(e.anim.d); }
    e.dynamic = !!(e.anim || e.blink || e.kind === 'coin' || (e.kind === 'power' && !e.pad));
    if (!e.dynamic) { mesh.matrixAutoUpdate = false; mesh.updateMatrix(); }
    mesh.visible = false;
    scene.add(mesh);
    (byStage[e.stage] = byStage[e.stage] || []).push(e);
  });

  let visible = [], active = [], dynamics = [], lamps = ents.filter((e) => e.lamp);
  function refreshActive() {
    const s = save.stage;
    visible.forEach((e) => { e.mesh.visible = false; });
    visible = []; active = []; dynamics = [];
    for (let i = Math.max(1, s - 2); i <= Math.min(FINISH, s + 3); i++) {
      (byStage[i] || []).forEach((e) => {
        e.mesh.visible = !(e.kind === 'coin' && save.got.indexOf(e.id) >= 0) && !e.hidden;
        visible.push(e);
        if (e.dynamic) dynamics.push(e);
        if (Math.abs(i - s) <= 1 || i === s + 1) active.push(e);
      });
    }
    lamps.forEach((e) => { e.mesh.material = material(e.lamp === save.stage ? 0x5aff8c : e.lamp <= save.max ? 0x3cbe6e : 0xffffff, true); });
  }

  // ------------------------------------------------------------ player
  const P = { pos: new V3(), vel: new V3(), yaw: 0, ground: null, coyote: 0, jumpBuf: 0, airJump: false, nearLadder: false, climbing: false, ladderLock: 0, dead: 0, powers: {}, powerDur: {} };
  const avatar = new THREE.Group();
  const skinMat = new THREE.MeshLambertMaterial({ color: 0x3c8cff });
  const part = (w, h, d, x, y, z, mat) => { const m = new THREE.Mesh(GEO.box, mat); m.scale.set(w, h, d); m.position.set(x, y, z); return m; };
  const skinTone = new THREE.MeshLambertMaterial({ color: 0xffd9a8 }), dark = new THREE.MeshLambertMaterial({ color: 0x2a3050 });
  const torso = part(2, 2, 1, 0, 3, 0, skinMat), head = part(1.3, 1.3, 1.3, 0, 4.7, 0, skinTone);
  const cap = part(1.5, 0.4, 1.7, 0, 5.4, -0.15, skinMat);
  const pivot = (x, y) => { const g = new THREE.Group(); g.position.set(x, y, 0); return g; };
  const armL = pivot(-1.5, 4), armR = pivot(1.5, 4), legL = pivot(-0.5, 2), legR = pivot(0.5, 2);
  armL.add(part(1, 2, 1, 0, -1, 0, skinTone)); armR.add(part(1, 2, 1, 0, -1, 0, skinTone));
  legL.add(part(1, 2, 1, 0, -1, 0, dark)); legR.add(part(1, 2, 1, 0, -1, 0, dark));
  const eyeL = part(0.22, 0.3, 0.1, -0.3, 4.8, -0.66, dark), eyeR = part(0.22, 0.3, 0.1, 0.3, 4.8, -0.66, dark);
  avatar.add(torso, head, cap, armL, armR, legL, legR, eyeL, eyeR);
  scene.add(avatar);
  const shield = new THREE.Mesh(GEO.ball, new THREE.MeshBasicMaterial({ color: 0x46dcff, transparent: true, opacity: 0.25 }));
  shield.scale.setScalar(7.5); shield.position.y = 2.6; shield.visible = false; avatar.add(shield);
  const shadow = new THREE.Mesh(new THREE.CircleGeometry(1.3, 20).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.35, depthWrite: false }));
  scene.add(shadow);
  function applySkin() { skinMat.color.setHex((SKINS.find((s) => s.id === save.skin) || SKINS[0]).color); }

  // particles (simple pooled sprites)
  const sparks = [];
  const sparkMat = {};
  function burst(pos, color, count, speed) {
    sparkMat[color] = sparkMat[color] || new THREE.MeshBasicMaterial({ color });
    for (let i = 0; i < count; i++) {
      const m = new THREE.Mesh(GEO.box, sparkMat[color]); m.scale.setScalar(0.45); m.position.copy(pos);
      scene.add(m); sparks.push({ m, v: new V3().randomDirection().multiplyScalar(speed * (0.4 + Math.random() * 0.6)), life: 0.6 + Math.random() * 0.4 });
    }
  }

  // ------------------------------------------------------------ state
  let clock = 0, runStart = 0, started = false, paused = false, camYaw = 0, camPitch = 0.3, camDist = 24, shake = 0, zoneNow = 0, fov = 70;
  const camTarget = new V3();
  const has = (k) => (P.powers[k] || 0) > clock;

  function respawn() {
    const cp = cps[save.stage] || cps[1];
    P.pos.set(cp.p[0], cp.p[1] + 0.1, cp.p[2]); P.vel.set(0, 0, 0); P.ground = null; P.dead = 0; P.powers = {}; P.climbing = false; P.yaw = cp.yaw;
    camYaw = cp.yaw; camTarget.copy(P.pos); avatar.visible = true;
    ents.forEach((e) => { if (e.kind === 'power') { e.cool = 0; e.hidden = false; } if (e.vanishAt) { e.vanishAt = 0; e.on = true; e.mesh.material = material(e.color); } });
    refreshActive(); updateHud();
  }
  function die(reason) {
    if (P.dead) return;
    P.dead = 0.9; avatar.visible = false; sfx.die(); shake = 1.2;
    burst(P.pos.clone().add(new V3(0, 2.5, 0)), 0xff4e60, 26, 26);
    $('flash').classList.remove('go'); void $('flash').offsetWidth; $('flash').classList.add('go');
  }
  function reach(i) {
    if (i <= save.stage || i > save.max + 1) return;
    save.stage = i;
    const isNew = i > save.max;
    if (isNew) { save.max = i; save.coins += 5; }
    burst(P.pos.clone().add(new V3(0, 2, 0)), 0x46dc78, 30, 22);
    if (i === FINISH && !save.finished) {
      save.finished = true; save.elapsed = clock - runStart; save.wins++; save.coins += 100;
      const best = !save.best || save.elapsed < save.best; if (best) save.best = save.elapsed;
      sfx.win();
      $('winTime').textContent = 'Time  ' + fmt(save.elapsed); $('winDetail').textContent = (best ? 'New personal best!  ' : '') + '+105 coins';
      openMenu('win');
    } else if (isNew) { toast('CHECKPOINT!  +5 🪙', '#46dc78'); sfx.check(); }
    persist(); refreshActive(); updateHud();
  }
  function grant(kind, time) {
    // one power-up at a time: a new one replaces whatever you had
    const until = Math.max(P.powers[kind] || 0, clock + (time || POWERS[kind].time));
    P.powers = {}; P.powers[kind] = until;
    P.powerDur[kind] = time || POWERS[kind].time;
  }

  // ------------------------------------------------------------ animation of the world
  const TAU = Math.PI * 2;
  function ease(kind, u) {
    if (kind === 'linear') return u < 0.5 ? u * 2 : 2 - u * 2;
    if (kind === 'hold') { const h = 0.15, sp = 0.5 - h; if (u < h) return 0; if (u < 0.5) { const s = (u - h) / sp; return s * s * (3 - 2 * s); } if (u < 0.5 + h) return 1; const s = (u - 0.5 - h) / sp; return 1 - s * s * (3 - 2 * s); }
    if (kind === 'slam') { if (u < 0.45) return 0; if (u < 0.53) { const s = (u - 0.45) / 0.08; return s * s; } if (u < 0.68) return 1; const s = (u - 0.68) / 0.32; return 1 - s * s * (3 - 2 * s); }
    if (kind === 'loop') return u;
    return 0.5 - 0.5 * Math.cos(TAU * u);
  }
  const vTmp = new V3();
  function animate(dt) {
    for (let i = 0; i < dynamics.length; i++) {
      const e = dynamics[i], a = e.anim, p = e.pos;
      const ox = p.x, oy = p.y, oz = p.z;
      e.dth = 0;
      if (a && a.type === 'mover') {
        const k = ease(a.ease, (((clock / a.period + a.phase) % 1) + 1) % 1);
        p.set(a.p.x + a.dv.x * k, a.p.y + a.dv.y * k, a.p.z + a.dv.z * k);
      } else if (a) {
        let angle;
        if (a.swing) angle = a.swing * Math.sin(TAU * (clock / a.period + a.phase));
        else angle = a.speed * clock + a.phase * TAU;
        qTmp.setFromAxisAngle(a.ax, angle);
        vTmp.copy(a.rel).applyQuaternion(qTmp); p.copy(a.pv).add(vTmp);
        if (!a.upright) e.mesh.quaternion.copy(qTmp).multiply(e.baseQ);
        if (a.vertical && !a.swing) e.dth = a.speed * dt;
      } else if (e.kind === 'coin') {
        e.mesh.rotation.y = clock * 2.4 + e.id; p.y = e.c[1] + Math.sin(clock * 2 + e.id) * 0.25;
      } else if (e.kind === 'power') {
        p.y = e.c[1] + Math.sin(clock * 2.2 + e.c[0]) * 0.4;
      }
      e.dx = p.x - ox; e.dy = p.y - oy; e.dz = p.z - oz;
      if (e.blink) {
        const b = e.blink, cycle = b.on + b.off, u = (clock + b.phase * cycle) % cycle;
        let st;
        if (b.tile) st = u < b.on - 0.6 ? 2 : u < b.on ? 1 : 0; else st = u < b.on ? 2 : u > cycle - 0.5 ? 1 : 0;
        e.on = b.tile ? st > 0 : st === 2;
        const flick = Math.floor(clock * 14) % 2 === 0;
        e.mesh.visible = st === 2 || (st === 1 && flick) || (b.tile && st === 0 && flick && false);
        if (b.tile && st === 0) { e.mesh.visible = true; e.mesh.material = material(e.color, e.neon, 0.15); } else if (b.tile) e.mesh.material = material(e.color, e.neon, e.alpha);
      }
      if (e.vanishAt) {
        const t = clock - e.vanishAt;
        if (t < e.delay) { e.mesh.material = material(Math.floor(clock * 16) % 2 ? 0xff5a46 : e.color); }
        else if (t < e.delay + e.respawn) { e.on = false; e.mesh.visible = false; }
        else { e.on = true; e.mesh.visible = true; e.mesh.material = material(e.color); e.vanishAt = 0; const k = dynamics.indexOf(e); if (!e.dynamic && k >= 0) { /* stays listed until refresh */ } }
      }
    }
  }

  // ------------------------------------------------------------ input
  const keys = {};
  const input = { x: 0, z: 0, jump: false, jumpPressed: false };
  addEventListener('keydown', (ev) => {
    if (ev.repeat) return;
    keys[ev.code] = true;
    if (ev.code === 'Space') { input.jumpPressed = true; ev.preventDefault(); }
    if (!started) return;
    if (ev.code === 'KeyR') die('reset');
    if (ev.code === 'KeyM') openMenu('stages');
    if (ev.code === 'KeyT') openMenu('skins');
    if (ev.code === 'KeyP' || ev.code === 'Escape') openMenu(menuOpen ? null : 'settings');
  });
  addEventListener('keyup', (ev) => { keys[ev.code] = false; });
  addEventListener('blur', () => { for (const k in keys) keys[k] = false; });

  const view = $('view');
  let stick = null, look = null;
  const stickEl = $('stick'), knobEl = $('knob');
  view.addEventListener('pointerdown', (ev) => {
    view.setPointerCapture(ev.pointerId);
    if (ev.pointerType === 'touch' && ev.clientX < innerWidth * 0.45 && !stick) {
      stick = { id: ev.pointerId, x: ev.clientX, y: ev.clientY, dx: 0, dy: 0 };
      stickEl.style.display = 'block'; stickEl.style.left = ev.clientX - 60 + 'px'; stickEl.style.top = ev.clientY - 60 + 'px'; knobEl.style.transform = 'translate(0,0)';
    } else if (!look) look = { id: ev.pointerId, x: ev.clientX, y: ev.clientY };
  });
  view.addEventListener('pointermove', (ev) => {
    if (stick && ev.pointerId === stick.id) {
      let dx = ev.clientX - stick.x, dy = ev.clientY - stick.y; const m = Math.hypot(dx, dy), max = 50;
      if (m > max) { dx *= max / m; dy *= max / m; }
      stick.dx = dx / max; stick.dy = dy / max; knobEl.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';
    } else if (look && ev.pointerId === look.id) {
      const k = ev.pointerType === 'touch' ? 0.008 : 0.006;
      camYaw += (ev.clientX - look.x) * k; camPitch = Math.max(-0.5, Math.min(1.3, camPitch + (ev.clientY - look.y) * k));
      look.x = ev.clientX; look.y = ev.clientY;
    }
  });
  const release = (ev) => {
    if (stick && ev.pointerId === stick.id) { stick = null; stickEl.style.display = 'none'; }
    if (look && ev.pointerId === look.id) look = null;
  };
  view.addEventListener('pointerup', release); view.addEventListener('pointercancel', release);
  view.addEventListener('wheel', (ev) => { camDist = Math.max(8, Math.min(50, camDist + ev.deltaY * 0.02)); ev.preventDefault(); }, { passive: false });
  view.addEventListener('contextmenu', (ev) => ev.preventDefault());
  let touchJump = false;
  const jb = $('jumpBtn');
  jb.addEventListener('pointerdown', (ev) => { touchJump = true; input.jumpPressed = true; ev.preventDefault(); });
  ['pointerup', 'pointercancel', 'pointerleave'].forEach((n) => jb.addEventListener(n, () => { touchJump = false; }));
  let padJumpWas = false;
  function readInput() {
    let x = (keys.KeyD || keys.ArrowRight ? 1 : 0) - (keys.KeyA || keys.ArrowLeft ? 1 : 0);
    let z = (keys.KeyW || keys.ArrowUp ? 1 : 0) - (keys.KeyS || keys.ArrowDown ? 1 : 0);
    if (keys.KeyQ) camYaw -= 0.04; if (keys.KeyE) camYaw += 0.04;
    if (stick) { x += stick.dx; z -= stick.dy; }
    let padJump = false;
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    for (const gp of pads) {
      if (!gp) continue;
      if (Math.abs(gp.axes[0]) > 0.2) x += gp.axes[0];
      if (Math.abs(gp.axes[1]) > 0.2) z -= gp.axes[1];
      if (Math.abs(gp.axes[2]) > 0.2) camYaw += gp.axes[2] * 0.05;
      if (Math.abs(gp.axes[3]) > 0.2) camPitch = Math.max(-0.5, Math.min(1.3, camPitch + gp.axes[3] * 0.03));
      if (gp.buttons[0] && gp.buttons[0].pressed) padJump = true;
    }
    if (padJump && !padJumpWas) input.jumpPressed = true;
    padJumpWas = padJump;
    const m = Math.hypot(x, z); if (m > 1) { x /= m; z /= m; }
    input.x = x; input.z = z; input.jump = !!keys.Space || touchJump || padJump;
  }

  // ------------------------------------------------------------ physics
  function solidOn(e) { return e.solid && e.on && !e.hidden; }
  function collide(e, dt) {
    const p = P.pos, c = e.pos;
    const top = c.y + e.s[1] / 2, bottom = c.y - e.s[1] / 2;
    if (p.y >= top || p.y + PH <= bottom) return;
    const dx = p.x - c.x, dz = p.z - c.z;
    let lx = 0, lz = 0, hx = 0, hz = 0, dist = 0;
    if (e.shape === 'cyl') {
      dist = Math.hypot(dx, dz); if (dist >= e.r + PR) return;
    } else {
      lx = dx * e.cos + dz * e.sin; lz = dx * e.sin - dz * e.cos;
      hx = e.s[0] / 2 + PR; hz = e.s[2] / 2 + PR;
      if (Math.abs(lx) >= hx || Math.abs(lz) >= hz) return;
    }
    const pen = top - p.y;
    const platVy = e.dy / frameDt, rel = P.vel.y - platVy;
    if (P.vel.y <= Math.max(platVy, 0) + 0.5 && pen <= Math.max(1.3, Math.abs(rel) * dt + 0.7)) { p.y = top; P.vel.y = 0; P.ground = e; return; }
    // only bump your head when you are really underneath, not when brushing past a ledge
    const under = e.shape === 'cyl' ? dist < e.r : Math.abs(lx) < e.s[0] / 2 && Math.abs(lz) < e.s[2] / 2;
    if (under && P.vel.y > 0 && p.y + PH - bottom <= P.vel.y * dt + 0.7) { p.y = bottom - PH; P.vel.y = 0; return; }
    if (e.ladder) P.touchLadder = true;
    if (e.shape === 'cyl') {
      const k = (e.r + PR) / (dist || 1); p.x = c.x + dx * k; p.z = c.z + dz * k;
    } else if (hx - Math.abs(lx) < hz - Math.abs(lz)) {
      const push = (hx - Math.abs(lx)) * Math.sign(lx || 1); p.x += e.cos * push; p.z += e.sin * push;
    } else {
      const push = (hz - Math.abs(lz)) * Math.sign(lz || 1); p.x += e.sin * push; p.z -= e.cos * push;
    }
  }
  const qInv = new THREE.Quaternion(), local = new V3();
  function touches(e, expand) {
    // exact test for any orientation: sample three points up the body in the object's own space
    qInv.copy(e.mesh.quaternion).invert();
    for (let i = 0; i < 3; i++) {
      local.set(P.pos.x - e.pos.x, P.pos.y + 0.9 + i * 1.6 - e.pos.y, P.pos.z - e.pos.z);
      if (e.shape === 'ball') { if (local.length() < e.r + expand) return true; continue; }
      local.applyQuaternion(qInv);
      if (Math.abs(local.x) < e.s[0] / 2 + expand && Math.abs(local.y) < e.s[1] / 2 + expand && Math.abs(local.z) < e.s[2] / 2 + expand) return true;
    }
    return false;
  }

  let frameDt = 1 / 60;
  function physics(dt) {
    frameDt = dt;
    const p = P.pos, g = P.ground;
    // ride whatever we were standing on
    if (g && solidOn(g)) {
      if (g.dth) { const a = g.anim, s = Math.sin(g.dth), c = Math.cos(g.dth), rx = p.x - a.pv.x, rz = p.z - a.pv.z; p.x = a.pv.x + rx * c + rz * s; p.z = a.pv.z - rx * s + rz * c; P.yaw -= g.dth; }
      else { p.x += g.dx; p.z += g.dz; }
      if (g.dy !== 0 && P.vel.y <= 0) p.y = g.pos.y + g.s[1] / 2;
      if (g.conveyor) { p.x += g.conveyor[0] * dt; p.z += g.conveyor[2] * dt; }
    }
    const speed = has('Speed') ? POWERS.Speed.speed : WALK;
    const fx = Math.sin(camYaw), fz = -Math.cos(camYaw), rx = Math.cos(camYaw), rz = Math.sin(camYaw);
    const wx = (rx * input.x + fx * input.z) * speed, wz = (rz * input.x + fz * input.z) * speed;
    const moving = Math.abs(input.x) + Math.abs(input.z) > 0.05;
    if (g && g.ice) { const k = Math.min(1, 1.4 * dt); P.vel.x += (wx - P.vel.x) * k; P.vel.z += (wz - P.vel.z) * k; }
    else { const k = Math.min(1, (g ? 18 : 9) * dt); P.vel.x += (wx - P.vel.x) * k; P.vel.z += (wz - P.vel.z) * k; }
    if (moving) { const target = Math.atan2(wx, -wz); let d = target - P.yaw; d = Math.atan2(Math.sin(d), Math.cos(d)); P.yaw += d * Math.min(1, 14 * dt); }

    P.coyote = g ? 0.1 : P.coyote - dt;
    P.jumpBuf = input.jumpPressed ? 0.12 : P.jumpBuf - dt;
    P.ladderLock -= dt;
    const jumpPower = has('Jump') ? POWERS.Jump.jump : JUMP;
    P.climbing = P.nearLadder && P.ladderLock <= 0 && (moving || P.climbing) && !g;
    if (P.nearLadder && P.ladderLock <= 0 && moving) P.climbing = true;
    if (P.climbing) { P.vel.y = moving ? CLIMB : 0; P.airJump = false; }
    else P.vel.y = Math.max(-220, P.vel.y - GRAVITY * (has('Feather') ? POWERS.Feather.gravity : 1) * dt);
    if (P.jumpBuf > 0 || (input.jump && g)) {
      if (P.coyote > 0 || P.climbing) { P.vel.y = jumpPower; P.coyote = 0; P.jumpBuf = 0; P.airJump = false; if (P.climbing) { P.climbing = false; P.ladderLock = 0.3; } sfx.jump(); }
      else if (P.jumpBuf > 0 && has('DoubleJump') && !P.airJump) { P.airJump = true; P.vel.y = jumpPower; P.jumpBuf = 0; sfx.air(); burst(p.clone(), 0xff6edc, 12, 12); }
    }
    input.jumpPressed = false;

    const steps = 2, h = dt / steps;
    P.ground = null; P.touchLadder = false;
    for (let s = 0; s < steps; s++) {
      p.x += P.vel.x * h; p.y += P.vel.y * h; p.z += P.vel.z * h;
      for (let i = 0; i < active.length; i++) { const e = active[i]; if (solidOn(e)) collide(e, h); }
    }
    // stay glued to a platform that is dropping away beneath us
    if (!P.ground && g && solidOn(g) && P.vel.y <= 0 && !P.climbing) {
      const top = g.pos.y + g.s[1] / 2, ddx = p.x - g.pos.x, ddz = p.z - g.pos.z;
      const over = g.shape === 'cyl' ? Math.hypot(ddx, ddz) < g.r + PR : Math.abs(ddx * g.cos + ddz * g.sin) < g.s[0] / 2 + PR && Math.abs(ddx * g.sin - ddz * g.cos) < g.s[2] / 2 + PR;
      if (over && p.y - top >= 0 && p.y - top < 0.5 + Math.abs(g.dy) * 2) { p.y = top; P.vel.y = 0; P.ground = g; }
    }
    // ladders also count when you are right next to them
    P.nearLadder = P.touchLadder;
    if (P.ground) P.airJump = false;

    // things we are touching
    const shielded = has('Shield');
    for (let i = 0; i < active.length; i++) {
      const e = active[i];
      if (e.hidden || !e.on) continue;
      if (e.kill) { if (!shielded && touches(e, 0.75)) { die('hazard'); return; } }
      else if (e.kind === 'coin') {
        if (save.got.indexOf(e.id) < 0 && Math.abs(e.pos.y - p.y - 2.5) < 5 && Math.hypot(e.pos.x - p.x, e.pos.z - p.z) < 3.6) {
          save.got.push(e.id); save.coins++; e.mesh.visible = false; sfx.coin(); burst(e.pos.clone(), 0xffd028, 8, 10); updateHud();
        }
      } else if (e.kind === 'power') {
        if ((e.cool || 0) < clock && Math.abs(e.pos.y - p.y - 2.5) < 4.5 && Math.hypot(e.pos.x - p.x, e.pos.z - p.z) < (e.pad ? 3.2 : 4)) {
          e.cool = clock + (e.pad ? 0.6 : 3.5);
          grant(e.power, e.time); sfx.power(); burst(e.pos.clone(), POWERS[e.power].color, 20, 18);
          if (!e.pad) { e.hidden = true; e.mesh.visible = false; setTimeout(() => { e.hidden = false; e.mesh.visible = visible.indexOf(e) >= 0; }, 3500); toast(POWERS[e.power].icon + ' ' + POWERS[e.power].name + '!  ' + POWERS[e.power].desc, hex(POWERS[e.power].color)); }
        }
      }
    }
    const gr = P.ground;
    if (gr) {
      if (gr.kind === 'bounce') { P.vel.y = gr.power; P.ground = null; P.coyote = 0; sfx.bounce(); shake = 0.4; burst(p.clone(), 0xff50aa, 12, 14); }
      else if (gr.kind === 'vanish' && !gr.vanishAt) { gr.vanishAt = clock; sfx.crumble(); if (dynamics.indexOf(gr) < 0) dynamics.push(gr); }
    }
    // checkpoints and the void
    const next = cps[save.stage + 1];
    for (let i = Math.max(1, save.stage - 1); i <= Math.min(FINISH, save.max + 1); i++) {
      const cp = cps[i];
      if (i > save.stage && p.y - cp.p[1] > -3 && p.y - cp.p[1] < 24 && Math.hypot(p.x - cp.p[0], p.z - cp.p[2]) < cp.radius) reach(i);
    }
    const floorY = Math.min(cps[save.stage].p[1], next ? next.p[1] : 1e9) - 45;
    if (p.y < floorY) die('void');
  }

  // ------------------------------------------------------------ HUD
  const fmt = (s) => { s = Math.max(0, s); const m = Math.floor(s / 60), r = s - m * 60; return m + ':' + String(Math.floor(r)).padStart(2, '0') + '.' + Math.floor((r % 1) * 10); };
  let toastTimer = 0;
  function toast(text, color) { const t = $('toast'); t.textContent = text; t.style.color = color || '#46dc78'; t.classList.remove('show'); void t.offsetWidth; t.classList.add('show'); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('show'), 1900); }
  function updateHud() {
    const s = Math.min(save.stage, STAGES.length), info = STAGES[s - 1], zone = ZONES[zoneOf(save.stage) - 1];
    const done = save.stage >= FINISH;
    $('stageTitle').textContent = done ? 'FINISHED!' : 'STAGE ' + s + ' / ' + STAGES.length;
    $('stageName').textContent = done ? 'You beat every stage' : info.name + '  ·  ' + zone.name;
    $('badge').textContent = done ? '🏁' : s; $('badge').style.background = hex(zone.color);
    $('fill').style.width = ((save.stage - 1) / STAGES.length) * 100 + '%'; $('fill').style.background = hex(zone.color);
    $('coins').textContent = save.coins;
  }
  function showZone(zi) {
    const z = ZONES[zi - 1], card = $('zoneCard');
    $('zoneSub').textContent = 'ZONE ' + zi; $('zoneTitle').textContent = z.name.toUpperCase(); $('zoneTitle').style.color = hex(z.color); $('zoneTag').textContent = z.tag;
    card.classList.remove('show'); void card.offsetWidth; card.classList.add('show'); sfx.zone();
  }
  const trayEls = {};
  Object.keys(POWERS).forEach((k) => {
    const el = document.createElement('div'); el.className = 'tile'; el.style.display = 'none';
    el.innerHTML = '<span class="ico">' + POWERS[k].icon + '</span><div><b style="color:' + hex(POWERS[k].color) + '">' + POWERS[k].name + '</b><div class="bar"><i style="background:' + hex(POWERS[k].color) + '"></i></div></div>';
    $('tray').appendChild(el); trayEls[k] = el;
  });

  let menuOpen = null;
  function openMenu(name) {
    if (name === menuOpen) name = null;
    menuOpen = name; paused = !!name;
    $('modal').style.display = name ? 'flex' : 'none';
    ['stages', 'skins', 'settings', 'win'].forEach((n) => { $('page-' + n).style.display = n === name ? 'block' : 'none'; });
    if (!name) return;
    sfx.click();
    $('modalTitle').textContent = { stages: 'STAGES', skins: 'SKINS', settings: 'SETTINGS', win: 'YOU WIN!' }[name];
    if (name === 'stages') {
      const grid = $('page-stages'); grid.innerHTML = '';
      STAGES.forEach((st, i) => {
        const n = i + 1, b = document.createElement('button'), open = n <= save.max;
        b.className = 'cell'; b.textContent = open ? (n === save.stage ? '▶ ' + n : n) : '🔒'; b.style.background = open ? hex(ZONES[st.zone - 1].color) : '#464c68'; b.title = st.name;
        b.onclick = () => { if (open) { save.stage = n; persist(); openMenu(null); respawn(); } };
        grid.appendChild(b);
      });
    }
    if (name === 'skins') {
      const list = $('page-skins'); list.innerHTML = '';
      SKINS.forEach((sk) => {
        const row = document.createElement('div'); row.className = 'row';
        const owned = save.skins.indexOf(sk.id) >= 0, eq = save.skin === sk.id;
        row.innerHTML = '<span class="swatch" style="background:' + hex(sk.color) + '"></span><b>' + sk.name + '</b>';
        const b = document.createElement('button'); b.className = 'btn small'; b.textContent = eq ? 'WEARING' : owned ? 'WEAR' : '🪙 ' + sk.price;
        b.style.background = eq ? '#464c68' : owned ? '#46aaff' : save.coins >= sk.price ? '#46dc78' : '#ff4e60';
        b.onclick = () => {
          if (!owned) { if (save.coins < sk.price) { toast('Not enough coins!', '#ff4e60'); return; } save.coins -= sk.price; save.skins.push(sk.id); }
          save.skin = sk.id; applySkin(); persist(); updateHud(); menuOpen = null; openMenu('skins');
        };
        row.appendChild(b); list.appendChild(row);
      });
    }
    if (name === 'settings') $('soundBtn').textContent = save.sound ? 'ON' : 'OFF';
  }
  function restartRun() { save.stage = 1; save.max = 1; save.finished = false; save.elapsed = 0; save.got = []; runStart = clock; persist(); openMenu(null); respawn(); }
  $('closeBtn').onclick = () => openMenu(null);
  $('bStages').onclick = () => openMenu('stages'); $('bSkins').onclick = () => openMenu('skins'); $('bSettings').onclick = () => openMenu('settings');
  $('bReset').onclick = () => die('reset');
  $('soundBtn').onclick = () => { save.sound = !save.sound; $('soundBtn').textContent = save.sound ? 'ON' : 'OFF'; persist(); sfx.click(); };
  let armed = 0;
  $('restartBtn').onclick = () => { if (performance.now() - armed < 3000) { $('restartBtn').textContent = 'RESTART'; restartRun(); } else { armed = performance.now(); $('restartBtn').textContent = 'SURE?'; } };
  $('againBtn').onclick = restartRun; $('keepBtn').onclick = () => openMenu(null);
  $('playBtn').onclick = () => {
    started = true; $('title').classList.add('gone'); sfx.check();
    runStart = clock - (save.elapsed || 0); showZone(zoneOf(save.stage));
  };
  if (!('ontouchstart' in window) && !(navigator.maxTouchPoints > 0)) document.body.classList.add('desktop');
  else $('hint').textContent = 'Left thumb to move  ·  drag to look  ·  tap JUMP';

  // ------------------------------------------------------------ frame loop
  const cA = new THREE.Color(), cB = new THREE.Color();
  function ambience(dt) {
    const zi = zoneOf(save.stage), z = ZONES[zi - 1], k = Math.min(1, dt * 1.2);
    if (zi !== zoneNow) { if (zoneNow && started) showZone(zi); zoneNow = zi; }
    scene.background.lerp(cA.setHex(z.sky), k); scene.fog.color.lerp(cB.setHex(z.fog), k); scene.fog.far += (z.far - scene.fog.far) * k;
    sun.color.lerp(cA.setHex(z.sun), k); hemi.intensity += (z.amb - hemi.intensity) * k;
    const dark = zi === 4 || zi === 5 ? 1 : zi === 2 ? 0.4 : 0;
    stars.material.opacity += (dark - stars.material.opacity) * k; stars.position.copy(camera.position);
  }
  function resize() { const w = innerWidth, h = innerHeight; renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix(); }
  addEventListener('resize', resize); resize();

  let last = performance.now(), walkT = 0;
  function frame(now) {
    requestAnimationFrame(frame);
    let dt = Math.min(0.05, (now - last) / 1000); last = now;
    if (!paused) {
      clock += dt;
      readInput();
      animate(dt);
      if (started) {
        if (P.dead) { P.dead -= dt; if (P.dead <= 0) respawn(); }
        else physics(dt);
      }
      // avatar
      avatar.position.copy(P.pos); avatar.rotation.y = -P.yaw;
      const hs = Math.hypot(P.vel.x, P.vel.z);
      walkT += dt * hs * 0.6;
      const sw = P.ground ? Math.sin(walkT) * Math.min(1, hs / 8) * 0.9 : 0;
      legL.rotation.x = sw; legR.rotation.x = -sw; armL.rotation.x = P.ground ? -sw : -2.6; armR.rotation.x = P.ground ? sw : -2.6;
      if (P.climbing) { armL.rotation.x = -2.2 + Math.sin(clock * 12) * 0.5; armR.rotation.x = -2.2 - Math.sin(clock * 12) * 0.5; }
      shield.visible = has('Shield');
      // blob shadow on whatever is below
      let best = -1e9;
      for (let i = 0; i < active.length; i++) {
        const e = active[i]; if (!solidOn(e)) continue;
        const top = e.pos.y + e.s[1] / 2; if (top > P.pos.y + 0.5 || top < best) continue;
        const dx = P.pos.x - e.pos.x, dz = P.pos.z - e.pos.z;
        const inside = e.shape === 'cyl' ? Math.hypot(dx, dz) < e.r : Math.abs(dx * e.cos + dz * e.sin) < e.s[0] / 2 && Math.abs(dx * e.sin - dz * e.cos) < e.s[2] / 2;
        if (inside) best = top;
      }
      shadow.visible = best > -1e8 && !P.dead; shadow.position.set(P.pos.x, best + 0.06, P.pos.z);
      const sc = Math.max(0.4, 1 - (P.pos.y - best) / 40); shadow.scale.setScalar(sc);
      for (let i = sparks.length - 1; i >= 0; i--) { const s = sparks[i]; s.life -= dt; s.v.y -= 40 * dt; s.m.position.addScaledVector(s.v, dt); s.m.scale.setScalar(Math.max(0.01, s.life * 0.6)); if (s.life <= 0) { scene.remove(s.m); sparks.splice(i, 1); } }
      // HUD numbers
      $('timer').textContent = fmt(save.finished ? save.elapsed : started ? clock - runStart : 0);
      for (const k in trayEls) {
        const left = (P.powers[k] || 0) - clock;
        if (left > 0) { trayEls[k].style.display = 'flex'; trayEls[k].querySelector('i').style.width = Math.min(100, (left / (P.powerDur[k] || 1)) * 100) + '%'; trayEls[k].style.opacity = left < 2 && Math.floor(clock * 8) % 2 ? 0.5 : 1; }
        else if (trayEls[k].style.display !== 'none') { trayEls[k].style.display = 'none'; sfx.powerEnd(); }
      }
      if (now - lastSave > 5000) { lastSave = now; if (!save.finished && started) save.elapsed = clock - runStart; persist(); }
    }
    ambience(dt);
    // camera
    camTarget.lerp(vTmp.set(P.pos.x, P.pos.y + 4, P.pos.z), Math.min(1, dt * 12));
    if (!started) camYaw += dt * 0.15;
    const cp = Math.cos(camPitch), sp = Math.sin(camPitch);
    camera.position.set(camTarget.x - Math.sin(camYaw) * cp * camDist, camTarget.y + sp * camDist, camTarget.z + Math.cos(camYaw) * cp * camDist);
    if (shake > 0.01) { camera.position.x += (Math.random() - 0.5) * shake; camera.position.y += (Math.random() - 0.5) * shake; shake *= Math.max(0, 1 - dt * 9); }
    camera.lookAt(camTarget);
    const wantFov = has('Speed') ? 82 : 70; if (Math.abs(fov - wantFov) > 0.1) { fov += (wantFov - fov) * Math.min(1, dt * 6); camera.fov = fov; camera.updateProjectionMatrix(); }
    renderer.render(scene, camera);
  }

  applySkin();
  if (save.stage > FINISH || !cps[save.stage]) save.stage = 1;
  respawn();
  requestAnimationFrame(frame);
  // hooks for automated tests
  window.__obby = { P, save, cps, ents, input, keys, reach, respawn, grant, step(dt) { clock += dt; animate(dt); if (P.dead) { P.dead -= dt; if (P.dead <= 0) respawn(); } else physics(dt); }, look(yaw) { camYaw = yaw; }, get clock() { return clock; }, start() { $('playBtn').click(); }, active: () => active };
})();
