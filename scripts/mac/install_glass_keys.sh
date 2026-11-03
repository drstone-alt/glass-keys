#!/bin/bash
# Glass Keys installer: builds a real Mac app (works offline) using only Terminal tools.
set -e
APP="$HOME/Applications/Glass Keys.app"
WORK="$HOME/GlassKeysBuild"

if ! command -v swiftc >/dev/null 2>&1; then
  echo ""
  echo "Apple's free command line tools are missing. Run this, wait for it to finish,"
  echo "then run this installer again:   xcode-select --install"
  exit 1
fi

mkdir -p "$WORK/icongen" "$HOME/Applications"
cd "$WORK"

cat > index.html <<'GLASSKEYS_HTML_END'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Glass Keys</title>
<style>
  :root{ --ink:#26314a; --muted:#6a7a95; --accent:#6a9cff; --glass:rgba(255,255,255,.34); --stroke:rgba(255,255,255,.7); }
  *{box-sizing:border-box;}
  html,body{height:100%;margin:0;}
  body{
    font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Arial,sans-serif;
    color:var(--ink);
    background:linear-gradient(160deg,#eef3fc 0%,#e2e9f6 45%,#eee6f7 100%);
    overflow:hidden; display:flex; align-items:center; justify-content:center;
    -webkit-user-select:none; user-select:none; cursor:default;
  }
  body::before,body::after{content:"";position:fixed;border-radius:50%;filter:blur(90px);opacity:.6;z-index:0;}
  body::before{width:520px;height:520px;background:#a9c3ff;top:-140px;left:-120px;}
  body::after{width:560px;height:560px;background:#ffd5ea;bottom:-180px;right:-140px;}

  .app{
    position:relative;z-index:1;width:min(1120px,96vw);height:min(730px,96vh);
    display:grid;grid-template-rows:68px minmax(0,1fr) 314px;gap:14px;
  }
  .glass{
    background:var(--glass);
    -webkit-backdrop-filter:blur(26px) saturate(180%); backdrop-filter:blur(26px) saturate(180%);
    border:1px solid var(--stroke); border-radius:22px;
    box-shadow:0 12px 34px rgba(40,60,100,.10), inset 0 1px 0 rgba(255,255,255,.8);
  }

  /* stats */
  .stats{display:flex;justify-content:space-around;align-items:center;padding:0 24px;}
  .stat{display:flex;align-items:baseline;gap:10px;}
  .stat span{font-size:12px;color:var(--muted);font-weight:600;letter-spacing:.04em;}
  .stat b{font-size:24px;font-weight:600;font-variant-numeric:tabular-nums;min-width:2ch;}

  /* text to type */
  .stage{display:flex;align-items:center;justify-content:center;padding:20px 48px;}
  .prompt{
    font-family:ui-monospace,"SF Mono",Menlo,Consolas,monospace;
    font-size:30px;line-height:1.9;text-align:center;white-space:pre-wrap;
    letter-spacing:.02em;color:#44526f;max-width:900px;
  }
  .ch{border-radius:6px;}
  .ch.ok{color:#2f9e63;}
  .ch.cur{background:rgba(106,160,255,.30);box-shadow:inset 0 0 0 1px rgba(106,160,255,.5);}
  .ch.bad{color:#e04b4b;background:rgba(224,75,75,.18);}

  /* bottom row */
  .bottom{display:grid;grid-template-columns:196px minmax(0,1fr) 196px;gap:14px;}
  .panel{padding:22px 18px 18px;display:flex;flex-direction:column;gap:12px;}
  .panel-title{font-size:13px;font-weight:600;color:#3b4863;padding:0 12px;}
  
  /* row selector */
  .rows{display:flex;flex-direction:column;gap:6px;flex:1;justify-content:center;}
  .row{display:flex;align-items:center;gap:12px;cursor:pointer;height:42px;padding:0 12px;border-radius:13px;
       transition:background .15s;}
  .row:hover{background:rgba(255,255,255,.35);}
  .row.sel{background:rgba(255,255,255,.5);box-shadow:inset 0 0 0 1px rgba(255,255,255,.8);}
  .row input{position:absolute;opacity:0;pointer-events:none;}
  .box{width:18px;height:18px;border-radius:6px;border:1.5px solid rgba(90,120,180,.4);background:rgba(255,255,255,.6);
       display:flex;align-items:center;justify-content:center;transition:all .15s;flex:none;}
  .box::after{content:"";width:4px;height:9px;border:solid #fff;border-width:0 2px 2px 0;transform:rotate(45deg) scale(0);margin-top:-2px;transition:transform .15s;}
  .row input:checked + .box{background:linear-gradient(160deg,#78a8ff,#9a8cff);border-color:transparent;}
  .row input:checked + .box::after{transform:rotate(45deg) scale(1);}
  .row .name{font-size:14px;font-weight:500;color:#3b4863;flex:1;}
  .row .hint{font-size:11.5px;color:var(--muted);letter-spacing:.04em;}

  /* keyboard panel */
  .kbwrap{position:relative;overflow:hidden;}
  .keys{position:absolute;left:0;right:0;top:26px;display:flex;flex-direction:column;gap:6px;align-items:center;}
  .krow{display:flex;gap:6px;justify-content:center;}
  .key{
    width:46px;height:42px;border-radius:10px;display:flex;align-items:center;justify-content:center;
    font-size:13px;font-weight:600;color:#4a5872;text-transform:uppercase;
    background:rgba(255,255,255,.5);border:1px solid rgba(255,255,255,.85);
    box-shadow:0 2px 6px rgba(40,60,100,.08), inset 0 -2px 0 rgba(255,255,255,.55);
    transition:transform .09s ease,background .09s ease,box-shadow .12s ease,color .09s;
  }
  .key.space{width:310px;font-size:11px;letter-spacing:.2em;color:#7d8aa3;}
  .key.next{box-shadow:0 0 0 2px rgba(106,160,255,.7), 0 0 16px rgba(106,160,255,.45);background:rgba(190,213,255,.7);}
  .key.active{background:rgba(120,168,255,.9);color:#fff;transform:translateY(3px);box-shadow:0 0 22px rgba(110,160,255,.75);}
  #hands{position:absolute;left:0;top:0;pointer-events:none;z-index:5;}

  /* sound-bar word length */
  .meter{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:22px;}
  .lenval{text-align:center;line-height:1;}
  .lenval b{display:block;font-size:40px;font-weight:600;font-variant-numeric:tabular-nums;color:#3b4863;}
  .lenval span{display:block;font-size:12px;color:var(--muted);margin-top:6px;}
  .eq{display:flex;align-items:flex-end;justify-content:center;gap:6px;height:68px;cursor:pointer;touch-action:none;padding:0 4px;}
  .bar{width:10px;border-radius:5px;background:rgba(106,156,255,.2);transition:background .18s;transform-origin:bottom;}
  .bar.on{background:linear-gradient(0deg,#6a9cff,#b58cff);animation:pulse 2s ease-in-out infinite;}
  @keyframes pulse{0%,100%{transform:scaleY(1);}50%{transform:scaleY(.95);}}
  @media (prefers-reduced-motion:reduce){ .bar.on{animation:none;} }
</style>
</head>
<body>
<div class="app">

  <div class="glass stats">
    <div class="stat"><span>Speed (WPM)</span><b id="wpm">0</b></div>
    <div class="stat"><span>Accuracy</span><b id="acc">100%</b></div>
    <div class="stat"><span>Time</span><b id="time">0s</b></div>
    <div class="stat"><span>Mistakes</span><b id="err">0</b></div>
  </div>

  <div class="glass stage"><div class="prompt" id="prompt"></div></div>

  <div class="bottom">
    <aside class="glass panel">
      <div class="panel-title">Rows to practice</div>
      <div class="rows">
        <label class="row"><input type="checkbox" class="rowbox" data-row="num"><span class="box"></span><span class="name">Number row</span><span class="hint">1–0</span></label>
        <label class="row"><input type="checkbox" class="rowbox" data-row="top" checked><span class="box"></span><span class="name">Top row</span><span class="hint">Q–P</span></label>
        <label class="row"><input type="checkbox" class="rowbox" data-row="home" checked><span class="box"></span><span class="name">Home row</span><span class="hint">A–L</span></label>
        <label class="row"><input type="checkbox" class="rowbox" data-row="bottom" checked><span class="box"></span><span class="name">Bottom row</span><span class="hint">Z–M</span></label>
      </div>
    </aside>

    <div class="glass kbwrap" id="kbwrap">
      <div class="keys" id="keys"></div>
      <canvas id="hands"></canvas>
    </div>

    <aside class="glass panel">
      <div class="panel-title">Word length</div>
      <div class="meter">
        <div class="lenval"><b id="lenVal">5</b><span>letters</span></div>
        <div class="eq" id="eq"></div>
      </div>
    </aside>
  </div>
</div>

<script>
(function(){
  "use strict";
  var $ = function(id){ return document.getElementById(id); };

  /* ---------- words ---------- */
  var WORDS = ("the be of and to in he have it that for they with as not on she at by this we you do but from or " +
    "which one would all will there say who make when can more if no man out other so what time up go about than into " +
    "could state only new year some take come these know see use get like then first any work now may such give over " +
    "think most even find day also after way many must look before great back through much where your own down should " +
    "because each just those people how too little world still nation hand old life tell write become here show house " +
    "both between need mean call develop under last right move thing general school never same another begin while " +
    "number part turn real leave might want point form off child few small since against ask late home interest large " +
    "person end open public follow during present without again hold around possible head consider word program " +
    "problem however lead system set order eye plan run keep face fact group play stand increase early course change " +
    "help line add did far fix ask sad dad all fall flag glass half hall salad shall slash shaft jazz zoom ice mix " +
    "quiet query quite quote tower trip type power pretty proper puppy report write wrote tree true your you").split(/\s+/);
  var ROW_LETTERS = { top:"qwertyuiop", home:"asdfghjkl", bottom:"zxcvbnm" };
  var DIGITS = "1234567890";

  /* ---------- keyboard ---------- */
  var KEYS = [
    ['1','2','3','4','5','6','7','8','9','0','-','='],
    ['q','w','e','r','t','y','u','i','o','p','[',']'],
    ['a','s','d','f','g','h','j','k','l',';',"'"],
    ['z','x','c','v','b','n','m',',','.','/'],
    [' ']
  ];
  var FINGER = {
    '1':'L4','2':'L3','3':'L2','4':'L1','5':'L1','q':'L4','w':'L3','e':'L2','r':'L1','t':'L1',
    'a':'L4','s':'L3','d':'L2','f':'L1','g':'L1','z':'L4','x':'L3','c':'L2','v':'L1','b':'L1',
    '6':'R1','7':'R1','8':'R2','9':'R3','0':'R4','-':'R4','=':'R4',
    'y':'R1','u':'R1','i':'R2','o':'R3','p':'R4','[':'R4',']':'R4',
    'h':'R1','j':'R1','k':'R2','l':'R3',';':'R4',"'":'R4','n':'R1','m':'R1',',':'R2','.':'R3','/':'R4',' ':'RT'
  };
  var HOME = {L4:'a',L3:'s',L2:'d',L1:'f',R1:'j',R2:'k',R3:'l',R4:';'};
  var RAD  = {L4:.235,L3:.275,L2:.30,L1:.295,R1:.295,R2:.30,R3:.275,R4:.235,LT:.35,RT:.35};
  var BASEY= {L4:1.38,L3:1.54,L2:1.50,L1:1.56,R1:1.56,R2:1.50,R3:1.54,R4:1.38};

  var keyEls = {}, keysEl = $('keys');
  KEYS.forEach(function(row){
    var r = document.createElement('div'); r.className = 'krow';
    row.forEach(function(k){
      var el = document.createElement('div');
      el.className = 'key' + (k === ' ' ? ' space' : '');
      el.textContent = (k === ' ') ? 'space' : k;
      r.appendChild(el); keyEls[k] = el;
    });
    keysEl.appendChild(r);
  });

  /* ---------- sound-bar word length ---------- */
  var eq = $('eq'), bars = [], wordLen = 5;
  for (var i = 0; i < 9; i++){
    var b = document.createElement('div'); b.className = 'bar';
    b.style.height = (16 + i * 6.5) + 'px';
    eq.appendChild(b); bars.push(b);
  }
  function setLen(n){
    n = Math.max(2, Math.min(10, n));
    var changed = n !== wordLen; wordLen = n;
    bars.forEach(function(b, i){ b.classList.toggle('on', i + 2 <= wordLen); });
    $('lenVal').textContent = wordLen;
    return changed;
  }
  function lenFromPointer(e){
    var r = eq.getBoundingClientRect();
    var idx = Math.floor((e.clientX - r.left) / (r.width / 9));
    if (setLen(idx + 2)) reset();
  }
  var dragging = false;
  eq.addEventListener('pointerdown', function(e){ dragging = true; eq.setPointerCapture(e.pointerId); lenFromPointer(e); });
  eq.addEventListener('pointermove', function(e){ if (dragging) lenFromPointer(e); });
  eq.addEventListener('pointerup',   function(){ dragging = false; });

  /* ---------- typing ---------- */
  var line = '', cursor = 0, correct = 0, totalKeys = 0, errors = 0, startTime = null, tickId = null;
  var rowBoxes = Array.prototype.slice.call(document.querySelectorAll('.rowbox'));

  function allowed(){
    var on = rowBoxes.filter(function(b){ return b.checked; }).map(function(b){ return b.dataset.row; });
    if (!on.length){ rowBoxes[2].checked = true; on = ['home']; }
    var s = new Set(); var digits = on.indexOf('num') >= 0;
    on.forEach(function(r){ if (ROW_LETTERS[r]) ROW_LETTERS[r].split('').forEach(function(c){ s.add(c); }); });
    return { letters: s, digits: digits };
  }
  function rnd(a){ return a[(Math.random() * a.length) | 0]; }
  function pickToken(len, al){
    if (al.digits && (al.letters.size === 0 || Math.random() < 0.4)){
      var d = ''; for (var i = 0; i < len; i++) d += rnd(DIGITS); return d;
    }
    var pool = WORDS.filter(function(w){
      if (w.length !== len) return false;
      for (var i = 0; i < w.length; i++) if (!al.letters.has(w[i])) return false;
      return true;
    });
    if (pool.length) return rnd(pool);
    var arr = Array.from(al.letters), s = '';
    for (var j = 0; j < len; j++) s += rnd(arr);
    return s;
  }
  function newLine(){
    var al = allowed(), words = [], n = 0;
    while (n < 54){ var w = pickToken(wordLen, al); words.push(w); n += w.length + 1; }
    line = words.join(' '); cursor = 0; renderLine();
  }
  function renderLine(){
    var p = $('prompt'); p.innerHTML = '';
    for (var i = 0; i < line.length; i++){
      var sp = document.createElement('span'); sp.className = 'ch'; sp.textContent = line[i]; p.appendChild(sp);
    }
    paint();
  }
  var hinted = null;
  function paint(){
    var sp = $('prompt').children;
    for (var i = 0; i < sp.length; i++)
      sp[i].className = 'ch' + (i < cursor ? ' ok' : '') + (i === cursor ? ' cur' : '');
    if (hinted) hinted.classList.remove('next');
    hinted = keyEls[line[cursor]] || null;
    if (hinted) hinted.classList.add('next');
  }
  function updateStats(){
    var mins = startTime ? (Date.now() - startTime) / 60000 : 0;
    $('wpm').textContent = mins > 0.001 ? Math.round((correct / 5) / mins) : 0;
    $('acc').textContent = (totalKeys ? Math.round(correct / totalKeys * 100) : 100) + '%';
    $('err').textContent = errors;
    $('time').textContent = (startTime ? Math.floor((Date.now() - startTime) / 1000) : 0) + 's';
  }
  function reset(){
    correct = totalKeys = errors = 0; startTime = null;
    if (tickId){ clearInterval(tickId); tickId = null; }
    updateStats(); newLine();
  }

  /* ---------- the hands ---------- */
  var cv = $('hands'), cx = cv.getContext('2d');
  var off = document.createElement('canvas'), ox = off.getContext('2d');
  var kb = $('kbwrap'), W = 0, H = 0, dpr = 1, P = 52, KC = {};
  var hands = { L:{side:'L',sx:0,sy:0,tsx:0,tsy:0,last:0,f:[]}, R:{side:'R',sx:0,sy:0,tsx:0,tsy:0,last:0,f:[]} };

  function avg(a){ return a.reduce(function(x,y){ return x + y; }, 0) / a.length; }

  function layoutHands(){
    var br = kb.getBoundingClientRect();
    W = br.width; H = br.height; dpr = window.devicePixelRatio || 1;
    cv.width = off.width = Math.round(W * dpr); cv.height = off.height = Math.round(H * dpr);
    cv.style.width = W + 'px'; cv.style.height = H + 'px';
    KC = {};
    Object.keys(keyEls).forEach(function(k){
      var r = keyEls[k].getBoundingClientRect();
      KC[k] = { x: r.left - br.left + r.width / 2, y: r.top - br.top + r.height / 2 };
    });
    P = KC.s.x - KC.a.x;
    var hy = KC.f.y, sp = KC[' '];
    ['L','R'].forEach(function(side){
      var h = hands[side];
      var ids = side === 'L' ? ['L4','L3','L2','L1'] : ['R1','R2','R3','R4'];
      var hc = avg(ids.map(function(id){ return KC[HOME[id]].x; }));
      h.hc = hc; h.hy = hy; h.f = [];
      ids.forEach(function(id){
        var home = KC[HOME[id]];
        h.f.push({ id:id, thumb:false, r:RAD[id]*P,
          home:{x:home.x,y:home.y}, tip:{x:home.x,y:home.y}, active:null, press:0, pT:0,
          base:{ x: hc + (home.x - hc) * 0.80, y: hy + BASEY[id] * P },
          ph: Math.random() * 6 });
      });
      var inner = side === 'L' ? 1 : -1;
      var ib = side === 'L' ? h.f[3].base : h.f[0].base;
      var th = { x: sp.x + (side === 'L' ? -0.9 : 0.85) * P, y: sp.y - 0.04 * P };
      h.f.push({ id: side + 'T', thumb:true, r:RAD[side+'T']*P, home:th, tip:{x:th.x,y:th.y}, active:null, press:0, pT:0,
        base:{ x: ib.x + inner * 0.30 * P, y: hy + 2.5 * P }, ph: Math.random() * 6 });
      h.f.forEach(function(f){ f.rest = Math.sqrt(Math.pow(f.home.x-f.base.x,2)+Math.pow(f.home.y-f.base.y,2)); });
    });
  }

  function findFinger(id){
    var h = hands[id[0]];
    for (var i = 0; i < h.f.length; i++) if (h.f[i].id === id) return h.f[i];
  }

  function pressKey(k){
    var id = FINGER[k]; if (!id || !KC[k]) return;
    var h = hands[id[0]], f = findFinger(id);
    var K = KC[k];
    if (f.thumb){ f.active = { x: f.home.x, y: f.home.y + 4 }; h.tsx = 0; h.tsy = 0.08 * P; }
    else {
      f.active = { x: K.x, y: K.y + 2 };
      h.tsx = (K.x - f.home.x) * 0.6; h.tsy = (K.y - f.home.y) * 0.7;
    }
    f.pT = 1; h.last = performance.now();
    setTimeout(function(){ f.active = null; f.pT = 0; }, 150);
  }

  function mix(a, b, t){ return 'rgb(' + a.map(function(v,i){ return Math.round(v + (b[i]-v)*t); }).join(',') + ')'; }
  var SKIN = [248,236,238], PRESS = [150,186,255];

  /* one finger: a gently bowed chain of circles whose width follows a real finger */
  function curve(f, h){
    var bx = f.base.x + h.sx, by = f.base.y + h.sy, tx = f.tip.x, ty = f.tip.y;
    var dx = tx - bx, dy = ty - by, d = Math.sqrt(dx*dx + dy*dy) || 1;
    var bow = Math.max(-2, Math.min(f.rest * 0.28, (f.rest * 1.12 - d) * 0.32));
    var sgn = f.thumb ? (h.side === 'L' ? -0.7 : 0.7) : (h.side === 'L' ? 1 : -1);
    var nx = -dy / d * bow * sgn, ny = dx / d * bow * sgn;
    var qx = (bx + tx) / 2 + nx, qy = (by + ty) / 2 + ny;
    var n = Math.max(12, Math.ceil(d / (f.r * 0.32))), pts = [];
    for (var i = 0; i <= n; i++){
      var t = i / n, u = 1 - t;
      pts.push({ t:t, x: u*u*bx + 2*t*u*qx + t*t*tx, y: u*u*by + 2*t*u*qy + t*t*ty,
                 tx: 2*u*(qx-bx) + 2*t*(tx-qx), ty: 2*u*(qy-by) + 2*t*(ty-qy),
                 r: f.r * (1 - 0.26 * t) * (t < 0.1 ? 1 + 0.07 * (1 - t / 0.1) : 1) });
    }
    pts.curl = Math.min(1, d / f.rest);
    return pts;
  }
  function circle(c, x, y, r){ c.beginPath(); c.arc(x, y, r, 0, 6.2832); c.fill(); }

  function smoothClosed(c, pts){
    var n = pts.length;
    c.beginPath(); c.moveTo((pts[n-1].x + pts[0].x) / 2, (pts[n-1].y + pts[0].y) / 2);
    for (var i = 0; i < n; i++){
      var p = pts[i], q = pts[(i + 1) % n];
      c.quadraticCurveTo(p.x, p.y, (p.x + q.x) / 2, (p.y + q.y) / 2);
    }
    c.closePath();
  }

  function palmPts(h){
    var s = h.side === 'L' ? 1 : -1, sx = h.sx, sy = h.sy, hc = h.hc + sx, hy = h.hy + sy, fs = h.f;
    var fL = fs[0].base, fR = fs[3].base;
    var lp = s === 1 ? 0.20 : 0.42, rp = s === 1 ? 0.42 : 0.20, wy = hy + 2.9 * P, pts = [];
    for (var i = 0; i < 4; i++) pts.push({ x: fs[i].base.x + sx, y: fs[i].base.y + sy });
    pts.push({ x: fR.x + sx + rp * 0.55 * P, y: fR.y + sy + 0.3 * P });
    pts.push({ x: fR.x + sx + rp * P,        y: hy + 2.1 * P });
    pts.push({ x: hc + 0.36 * P, y: wy });
    pts.push({ x: hc - 0.36 * P, y: wy });
    pts.push({ x: fL.x + sx - lp * P,        y: hy + 2.1 * P });
    pts.push({ x: fL.x + sx - lp * 0.55 * P, y: fL.y + sy + 0.3 * P });
    return { pts: pts, hc: hc, hy: hy, wy: wy };
  }

  function drawHand(h){
    var curves = h.f.map(function(f){ return curve(f, h); });
    var pm = palmPts(h);
    ox.lineJoin = 'round'; ox.lineCap = 'round';

    /* white rim around the whole hand */
    ox.fillStyle = ox.strokeStyle = 'rgb(255,255,255)'; ox.lineWidth = 0.16 * P + 3;
    smoothClosed(ox, pm.pts); ox.fill(); ox.stroke();
    curves.forEach(function(pts){ pts.forEach(function(p){ circle(ox, p.x, p.y, p.r + 1.8); }); });

    /* skin */
    ox.fillStyle = ox.strokeStyle = mix(SKIN, SKIN, 0); ox.lineWidth = 0.16 * P;
    smoothClosed(ox, pm.pts); ox.fill(); ox.stroke();
    curves.forEach(function(pts, i){
      ox.fillStyle = mix(SKIN, PRESS, h.f[i].press);
      pts.forEach(function(p){ circle(ox, p.x, p.y, p.r); });
    });

    /* soft volume on the back of the hand */
    ox.save(); smoothClosed(ox, pm.pts); ox.clip();
    var gy = pm.hy + 1.9 * P;
    var g = ox.createRadialGradient(pm.hc - 6, gy - 8, 4, pm.hc, gy, 1.9 * P);
    g.addColorStop(0, 'rgba(255,255,255,.65)'); g.addColorStop(1, 'rgba(200,160,185,.22)');
    ox.fillStyle = g; ox.fillRect(0, 0, W, H); ox.restore();

    /* tendons running from the knuckles toward the wrist */
    ox.strokeStyle = 'rgba(165,120,150,.22)'; ox.lineWidth = 1.4;
    for (var i = 0; i < 4; i++){
      var b = h.f[i].base;
      ox.beginPath(); ox.moveTo(b.x + h.sx, b.y + h.sy + 0.4 * P);
      ox.quadraticCurveTo(b.x + h.sx + (pm.hc - b.x - h.sx) * 0.15, pm.hy + 2.0 * P, pm.hc + (b.x + h.sx - pm.hc) * 0.35, pm.wy - 0.35 * P);
      ox.stroke();
    }

    /* finger details */
    curves.forEach(function(pts, i){
      var f = h.f[i], n = pts.length, k0 = Math.floor(n * 0.10), k1 = Math.floor(n * 0.88);
      function side(off){
        ox.beginPath();
        for (var k = k0; k < k1; k++){
          var p = pts[k], m = Math.sqrt(p.tx*p.tx + p.ty*p.ty) || 1;
          var ex = p.x + p.ty / m * p.r * off, ey = p.y - p.tx / m * p.r * off;
          if (k === k0) ox.moveTo(ex, ey); else ox.lineTo(ex, ey);
        }
        ox.stroke();
      }
      ox.strokeStyle = 'rgba(190,140,165,.30)'; ox.lineWidth = Math.max(2, f.r * 0.40); side(-0.62);   /* shaded side */
      ox.strokeStyle = 'rgba(255,255,255,.9)';  ox.lineWidth = Math.max(1.6, f.r * 0.30); side(0.42);  /* lit side */

      ox.strokeStyle = 'rgba(165,120,150,.48)'; ox.lineWidth = 1.1;
      (f.thumb ? [0.5] : [0.40, 0.44, 0.74]).forEach(function(tt){
        var p = pts[Math.round(tt * (n - 1))], m = Math.sqrt(p.tx*p.tx + p.ty*p.ty) || 1;
        var nx = p.ty / m, ny = -p.tx / m, hw = p.r * 0.55;
        ox.beginPath(); ox.moveTo(p.x - nx * hw, p.y - ny * hw);
        ox.quadraticCurveTo(p.x + p.tx / m * 1.5, p.y + p.ty / m * 1.5, p.x + nx * hw, p.y + ny * hw); ox.stroke();
      });

      /* nail */
      var q = pts[n - 1], q0 = pts[Math.max(0, n - 5)], ang = Math.atan2(q.y - q0.y, q.x - q0.x);
      ox.save(); ox.translate(q.x - Math.cos(ang) * q.r * 0.38, q.y - Math.sin(ang) * q.r * 0.38); ox.rotate(ang);
      ox.fillStyle = 'rgba(255,255,255,.92)'; ox.strokeStyle = 'rgba(190,140,165,.5)'; ox.lineWidth = 1;
      ox.beginPath(); ox.ellipse(0, 0, q.r * 0.66 * (0.55 + 0.45 * pts.curl), q.r * 0.52, 0, 0, 6.2832); ox.fill(); ox.stroke();
      ox.restore();

      /* knuckle */
      if (!f.thumb){ ox.fillStyle = 'rgba(255,255,255,.5)'; circle(ox, f.base.x + h.sx, f.base.y + h.sy, f.r * 0.5); }
    });

    /* the wrist fades away at the bottom */
    ox.globalCompositeOperation = 'destination-out';
    var y0 = pm.hy + 2.7 * P, fade = ox.createLinearGradient(0, y0, 0, y0 + 0.65 * P);
    fade.addColorStop(0, 'rgba(0,0,0,0)'); fade.addColorStop(1, 'rgba(0,0,0,1)');
    ox.fillStyle = fade; ox.fillRect(0, y0, W, H); ox.globalCompositeOperation = 'source-over';
  }

  var last = 0;
  function frame(t){
    var dt = Math.min(0.05, (t - last) / 1000 || 0.016); last = t;
    var T = t / 1000, now = performance.now();
    var kh = 1 - Math.exp(-dt * 11), kt = 1 - Math.exp(-dt * 22), kp = 1 - Math.exp(-dt * 30);
    ['L','R'].forEach(function(side, si){
      var h = hands[side];
      if (now - h.last > 300){ h.tsx = 0; h.tsy = 0; }
      h.sx += (h.tsx + Math.sin(T * 1.1 + si * 2) * 1.2 - h.sx) * kh;
      h.sy += (h.tsy + Math.sin(T * 1.4 + si * 2) * 1.8 - h.sy) * kh;
      h.f.forEach(function(f){
        var tx, ty;
        if (f.active){ tx = f.active.x; ty = f.active.y; }
        else {
          tx = f.home.x + (f.thumb ? 0 : h.tsx * 0.55) + Math.sin(T * 1.7 + f.ph) * 0.9;
          ty = f.home.y + (f.thumb ? 0 : h.tsy * 0.55) + Math.cos(T * 1.5 + f.ph) * 0.9;
        }
        f.tip.x += (tx - f.tip.x) * kt; f.tip.y += (ty - f.tip.y) * kt;
        f.press += (f.pT - f.press) * kp;
      });
    });
    ox.setTransform(dpr, 0, 0, dpr, 0, 0); ox.clearRect(0, 0, W, H);
    drawHand(hands.L); drawHand(hands.R);
    cx.setTransform(1, 0, 0, 1, 0, 0); cx.clearRect(0, 0, cv.width, cv.height);
    cx.save();
    cx.globalAlpha = 0.62; cx.shadowColor = 'rgba(70,100,170,.32)';
    cx.shadowBlur = 18 * dpr; cx.shadowOffsetY = 7 * dpr;
    cx.drawImage(off, 0, 0);
    cx.restore();
    requestAnimationFrame(frame);
  }

  /* ---------- keyboard events ---------- */
  window.addEventListener('keydown', function(e){
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.key === 'Escape'){ reset(); return; }
    var k = e.key; if (k.length === 1) k = k.toLowerCase();
    if (k.length === 1 || k === 'Backspace') e.preventDefault();
    if (e.repeat) return;

    var ke = keyEls[k];
    if (ke){ ke.classList.add('active'); setTimeout(function(){ ke.classList.remove('active'); }, 120); pressKey(k); }
    if (k.length !== 1) return;

    if (!startTime){ startTime = Date.now(); tickId = setInterval(updateStats, 250); }
    totalKeys++;
    if (k === line[cursor]){
      correct++; cursor++;
      if (cursor >= line.length) newLine(); else paint();
    } else {
      errors++;
      var sp = $('prompt').children[cursor];
      if (sp){ sp.classList.add('bad'); setTimeout(function(){ sp.classList.remove('bad'); }, 220); }
    }
    updateStats();
  });

  function syncSel(){ rowBoxes.forEach(function(b){ b.parentNode.classList.toggle('sel', b.checked); }); }
  rowBoxes.forEach(function(b){ b.addEventListener('change', function(){ b.blur(); syncSel(); reset(); }); });
  syncSel();
  window.addEventListener('resize', layoutHands);

  /* ---------- start ---------- */
  setLen(5);
  layoutHands();
  reset();
  requestAnimationFrame(frame);
})();
</script>
</body>
</html>
GLASSKEYS_HTML_END

cat > main.swift <<'GLASSKEYS_SWIFT_END'
import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var web: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 1200, height: 800)
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Glass Keys"
        window.minSize = NSSize(width: 1040, height: 720)
        window.center()

        web = WKWebView(frame: rect, configuration: WKWebViewConfiguration())
        web.autoresizingMask = [.width, .height]
        web.setValue(false, forKey: "drawsBackground")
        window.contentView = web

        let dir = Bundle.main.resourceURL!
        web.loadFileURL(dir.appendingPathComponent("index.html"), allowingReadAccessTo: dir)

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(web)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)

let mainMenu = NSMenu()
let appItem = NSMenuItem()
mainMenu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(NSMenuItem(title: "Quit Glass Keys",
                           action: #selector(NSApplication.terminate(_:)),
                           keyEquivalent: "q"))
appItem.submenu = appMenu
app.mainMenu = mainMenu

app.run()
GLASSKEYS_SWIFT_END

cat > icongen/main.swift <<'GLASSKEYS_ICON_END'
import Cocoa

func keycap(_ rect: NSRect, hot: Bool) {
    let p = NSBezierPath(roundedRect: rect, xRadius: 26, yRadius: 26)
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow()
    if hot {
        sh.shadowColor = NSColor(calibratedRed: 0.2, green: 0.3, blue: 1.0, alpha: 0.6)
        sh.shadowBlurRadius = 30
        sh.shadowOffset = NSSize(width: 0, height: 0)
    } else {
        sh.shadowColor = NSColor(calibratedRed: 0.2, green: 0.25, blue: 0.6, alpha: 0.25)
        sh.shadowBlurRadius = 12
        sh.shadowOffset = NSSize(width: 0, height: -7)
    }
    sh.set()
    if hot {
        NSColor(calibratedRed: 0.31, green: 0.5, blue: 1.0, alpha: 1).setFill()
    } else {
        NSColor(calibratedWhite: 1, alpha: 0.55).setFill()
    }
    p.fill()
    NSGraphicsContext.restoreGraphicsState()
    if hot {
        let g = NSGradient(colors: [NSColor(calibratedRed: 0.52, green: 0.68, blue: 1.0, alpha: 1),
                                    NSColor(calibratedRed: 0.36, green: 0.42, blue: 0.98, alpha: 1)])!
        g.draw(in: p, angle: -90)
    }
    NSColor(calibratedWhite: 1, alpha: 0.85).setStroke()
    p.lineWidth = 3
    p.stroke()
}

func drawIcon() {
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let path = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow()
    sh.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.28)
    sh.shadowBlurRadius = 30
    sh.shadowOffset = NSSize(width: 0, height: -16)
    sh.set()
    NSColor(calibratedRed: 0.55, green: 0.62, blue: 1.0, alpha: 1).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    let bg = NSGradient(colors: [NSColor(calibratedRed: 0.47, green: 0.66, blue: 1.0, alpha: 1),
                                 NSColor(calibratedRed: 0.67, green: 0.56, blue: 1.0, alpha: 1),
                                 NSColor(calibratedRed: 1.0, green: 0.71, blue: 0.86, alpha: 1)])!
    bg.draw(in: path, angle: -50)

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let gloss = NSGradient(starting: NSColor(calibratedWhite: 1, alpha: 0.38),
                           ending: NSColor(calibratedWhite: 1, alpha: 0.0))!
    gloss.draw(in: NSRect(x: 100, y: 480, width: 824, height: 444), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let kw: CGFloat = 104, kh: CGFloat = 96, gap: CGFloat = 20
    let x0: CGFloat = 512 - (5 * kw + 4 * gap) / 2
    let ys: [CGFloat] = [650, 534, 418]
    for (r, y) in ys.enumerated() {
        for c in 0..<5 {
            let rect = NSRect(x: x0 + CGFloat(c) * (kw + gap), y: y, width: kw, height: kh)
            keycap(rect, hot: r == 1 && c == 2)
        }
    }
    let sw: CGFloat = 3 * kw + 2 * gap
    keycap(NSRect(x: 512 - sw / 2, y: 302, width: sw, height: kh), hot: false)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let t = NSAffineTransform()
    t.scale(by: CGFloat(px) / 1024.0)
    t.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "GlassKeys.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for (name, px) in sizes {
    try! render(px).write(to: URL(fileURLWithPath: out + "/" + name + ".png"))
}
GLASSKEYS_ICON_END

echo "Building Glass Keys..."
pkill -x GlassKeys 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift -o "$APP/Contents/MacOS/GlassKeys"
cp index.html "$APP/Contents/Resources/index.html"

echo "Drawing the app icon..."
rm -rf GlassKeys.iconset AppIcon.icns
if swiftc -O icongen/main.swift -o icongen/icongen \
   && ./icongen/icongen GlassKeys.iconset \
   && iconutil -c icns GlassKeys.iconset -o AppIcon.icns; then
  cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
  echo "(The icon could not be made, but the app will still work.)"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST_END'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GlassKeys</string>
<key>CFBundleIdentifier</key><string>local.glasskeys.app</string>
<key>CFBundleName</key><string>Glass Keys</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1</string>
<key>LSMinimumSystemVersion</key><string>10.13</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST_END

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
touch "$APP"
echo ""
echo "Done! Opening Glass Keys. It is saved in the Applications folder inside your home folder."
open "$APP"
