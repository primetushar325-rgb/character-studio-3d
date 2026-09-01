import 'dart:convert';

import 'art/character_catalog.dart';
import 'art/palettes.dart';
import 'character_json.dart';

/// Generates ONE self-contained HTML file: SVG-style vector character
/// (canvas-rendered from the same shape data), the full rig, baked keyframe
/// animations, a tiny animation engine, premium dark controls — zero external
/// dependencies. Works by just opening it in any browser.
String buildSingleFileHtml(Character2DSpec spec, PaletteColors palette) {
  final json = jsonEncode(buildCharacterJson(spec, palette));
  return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${spec.name} — 2D Rigged Character</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }
  body { background: #0A0C11; color: #EDEFF7; min-height: 100vh; display: flex; flex-direction: column; align-items: center; }
  h1 { font-size: 18px; margin: 16px 0 4px; letter-spacing: .4px; }
  .sub { color: #9AA3B8; font-size: 12px; margin-bottom: 12px; }
  #stageWrap { position: relative; width: min(92vw, 640px); aspect-ratio: 16/10; border-radius: 18px; overflow: hidden;
    background: #171B26; border: 1px solid rgba(255,255,255,.08); }
  canvas { width: 100%; height: 100%; display: block; }
  #controls { width: min(92vw, 640px); padding: 14px; display: flex; flex-direction: column; gap: 10px; }
  .row { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
  button { background: #171B26; color: #9AA3B8; border: 1px solid rgba(255,255,255,.08); border-radius: 11px;
    padding: 8px 12px; font-size: 12.5px; font-weight: 600; cursor: pointer; transition: all .15s; }
  button:hover { color: #EDEFF7; }
  button.active { background: rgba(123,155,255,.14); color: #7B9BFF; border-color: #7B9BFF; }
  input[type=range] { accent-color: #7B9BFF; width: 130px; }
  .timeline { height: 34px; background: #12151D; border-radius: 10px; position: relative; overflow: hidden;
    border: 1px solid rgba(255,255,255,.06); cursor: pointer; }
  #playhead { position: absolute; top: 0; bottom: 0; width: 2px; background: #7B9BFF; }
  .tick { position: absolute; top: 2px; font-size: 8.5px; color: #6B7385; }
  .kf { position: absolute; bottom: 3px; width: 5px; height: 5px; border-radius: 50%; background: #FFC46B; }
  label { font-size: 11px; color: #6B7385; text-transform: uppercase; letter-spacing: 1px; font-weight: 700; }
</style>
</head>
<body>
<h1>${spec.name}</h1>
<div class="sub">2D rigged character · rig: ${spec.rigKind} · self-contained export</div>
<div id="stageWrap"><canvas id="stage"></canvas></div>
<div id="controls">
  <div class="row" id="animButtons"></div>
  <div class="timeline" id="timeline"><div id="playhead"></div></div>
  <div class="row">
    <button id="play">⏸ Pause</button>
    <button id="stop">⏹ Stop</button>
    <button id="loop" class="active">🔁 Loop</button>
    <button id="prev">⏮ Frame</button>
    <button id="next">Frame ⏭</button>
    <label>Speed</label>
    <select id="speed" style="background:#171B26;color:#9AA3B8;border:1px solid rgba(255,255,255,.1);border-radius:8px;padding:6px">
      <option value="0.25">0.25x</option><option value="0.5">0.5x</option>
      <option value="1" selected>1x</option><option value="1.5">1.5x</option><option value="2">2x</option>
    </select>
    <button id="expr">🙂 Expression</button>
    <button id="dir">↔ Direction</button>
  </div>
</div>
<script>
const CHAR = $json;

// ---------- rig solver ----------
const D2R = Math.PI/180;
function solve(rig, angles){
  const out = {a:{}, j:{}};
  function walk(bone, jx, jy, parentRad){
    const worldDeg = parentRad/D2R + bone.rotation + (angles[bone.name]||0);
    const rad = worldDeg*D2R;
    out.a[bone.name]=rad; out.j[bone.name]=[jx,jy];
    for(const c of rig){ if(c.parent===bone.name){
      const lx = c.x*Math.cos(rad)-c.y*Math.sin(rad);
      const ly = c.x*Math.sin(rad)+c.y*Math.cos(rad);
      walk(c, jx+lx, jy+ly, rad);
    }}
  }
  walk(rig[0],0,0,0);
  return out;
}

// ---------- keyframe sampling ----------
const EASE = {
  linear: u=>u,
  easeIn: u=>u*u,
  easeOut: u=>1-(1-u)*(1-u),
  easeInOut: u=> u<.5 ? 2*u*u : 1-Math.pow(-2*u+2,2)/2,
};
function sampleClip(clip, t){
  const tt = clip.loop ? ((t%clip.duration)+clip.duration)%clip.duration : Math.min(Math.max(t,0),clip.duration);
  const u = clip.duration<=0?0:tt/clip.duration;
  const pose = {angles:{},dx:0,dy:0,tilt:0,extras:{}};
  for(const tr of clip.tracks){
    const ks = tr.keyframes; let k = ks[ks.length-1];
    if(u<=ks[0].time) k = ks[0];
    else for(let i=0;i<ks.length-1;i++){
      if(u>=ks[i].time && u<=ks[i+1].time){
        const span = ks[i+1].time-ks[i].time;
        const e = EASE[tr.interp]((u-ks[i].time)/(span||1));
        k = {rotation: ks[i].rotation+(ks[i+1].rotation-ks[i].rotation)*e,
             x:(ks[i].x||0)+((ks[i+1].x||0)-(ks[i].x||0))*e,
             y:(ks[i].y||0)+((ks[i+1].y||0)-(ks[i].y||0))*e};
        break;
      }
    }
    if(tr.bone==='root'){ pose.dx+=k.x||0; pose.dy+=k.y||0; }
    else pose.angles[tr.bone]=k.rotation;
  }
  return pose;
}

// ---------- shape renderer ----------
function hex(c){ return c; }
function resolveFill(f, pal){
  if(f.const) return f.const;
  return pal[f.slot] || pal.outline || '#000';
}
function drawShape(ctx, s, pal){
  const fill = resolveFill(s.fill, pal);
  const stroke = s.stroke ? (pal[s.stroke]||'#000') : null;
  ctx.globalAlpha = s.opacity ?? 1;
  ctx.beginPath();
  switch(s.kind){
    case 'ellipse': {
      const [cx,cy,rx,ry]=s.args;
      ctx.ellipse(cx,cy,rx,ry,0,0,Math.PI*2); break;
    }
    case 'capsule': {
      const [ax,ay,bx,by,r]=s.args;
      const dx=bx-ax, dy=by-ay, len=Math.hypot(dx,dy)||.001;
      const nx=-dy/len*r, ny=dx/len*r;
      ctx.arc(ax+nx,ay+ny,r,Math.atan2(ny,nx),Math.atan2(ny,nx)+Math.PI);
      ctx.arc(bx+nx,by+ny,r,Math.atan2(ny,nx)+Math.PI,Math.atan2(ny,nx)+Math.PI*2);
      ctx.arc(bx-nx,by-ny,r,0,Math.PI*2); break;
    }
    case 'rrect': {
      const [l,t,w,h,r]=s.args;
      ctx.roundRect(l,t,w,h,r); break;
    }
    case 'poly': {
      s.points.forEach((p,i)=> i? ctx.lineTo(p[0],p[1]) : ctx.moveTo(p[0],p[1]));
      ctx.closePath(); break;
    }
    case 'path': {
      let i=0;
      for(const op of (s.ops||[])){
        if(op==='M'){ ctx.moveTo(s.points[i][0],s.points[i][1]); i++; }
        else if(op==='L'){ ctx.lineTo(s.points[i][0],s.points[i][1]); i++; }
        else if(op==='Q'){ ctx.quadraticCurveTo(s.points[i][0],s.points[i][1],s.points[i+1][0],s.points[i+1][1]); i+=2; }
        else if(op==='Z'){ ctx.closePath(); }
      }
      break;
    }
    case 'checks': {
      const [l,t,w,h,cell]=s.args;
      ctx.save(); ctx.clip();
      ctx.fillStyle = pal.bottom||'#333'; ctx.fillRect(l,t,w,h);
      ctx.fillStyle = pal.shirtPattern||'#555';
      for(let x=l;x<l+w;x+=cell) for(let y=t;y<t+h;y+=cell){
        if(((Math.floor((x-l)/cell)+Math.floor((y-t)/cell))%2)===0) ctx.fillRect(x,y,cell,cell);
      }
      ctx.restore(); return;
    }
  }
  if(stroke){ ctx.lineWidth=(s.strokeWidth||1.6)*2; ctx.strokeStyle=stroke; ctx.lineJoin='round'; ctx.stroke(); }
  ctx.fillStyle=fill; ctx.fill();
  ctx.globalAlpha=1;
}

// ---------- face renderer (human + animal) ----------
function drawFace(ctx, fs, f, pal, kind){
  const closed = f.squint>0.55 || f.blink>0.8;
  const lx = Math.max(-1,Math.min(1,f.lookX)), ly = Math.max(-1,Math.min(1,f.lookY));
  for(let side=-1;side<=1;side+=2){
    const cx=side*fs.eyeDx, cy=fs.eyeY;
    if(closed){
      ctx.beginPath(); ctx.moveTo(cx-fs.eyeRx, cy+ (f.squint>0.55?-2.6:2));
      ctx.quadraticCurveTo(cx, cy+(f.squint>0.55?-5:3.4), cx+fs.eyeRx, cy+(f.squint>0.55?-2.6:2));
      ctx.lineWidth=2.2; ctx.strokeStyle=pal.outline||'#000'; ctx.stroke();
    } else {
      ctx.beginPath(); ctx.ellipse(cx,cy,fs.eyeRx,fs.eyeRy,0,0,7);
      ctx.fillStyle='#FFFFFF'; ctx.fill(); ctx.lineWidth=1.4; ctx.strokeStyle=pal.outline||'#000'; ctx.stroke();
      const pr=2.6*(f.pupil||1);
      ctx.beginPath(); ctx.ellipse(cx+lx*fs.eyeRx*.45, cy-ly*fs.eyeRy*.4, pr,pr,0,0,7);
      ctx.fillStyle=pal.outline||'#000'; ctx.fill();
      if(f.blink>0.02){
        const h=fs.eyeRy*2*Math.max(f.blink, f.lid||0);
        ctx.save(); ctx.beginPath(); ctx.rect(cx-fs.eyeRx-1, cy-fs.eyeRy-1, fs.eyeRx*2+2, h+1); ctx.clip();
        ctx.beginPath(); ctx.ellipse(cx,cy,fs.eyeRx+1,fs.eyeRy+1,0,0,7);
        ctx.fillStyle=pal.skin||pal.fur||'#000'; ctx.fill(); ctx.restore();
      }
    }
    const lift=(f.browLift||0)+(side>0?(f.browAsym||0):0);
    const y=fs.browY+lift;
    ctx.beginPath();
    ctx.moveTo(side*2.8, y-(f.browAngle||0)*.16);
    ctx.quadraticCurveTo(side*(fs.eyeDx+fs.browLen*.35), y+1.8, side*(fs.eyeDx+fs.browLen*.7), y+1);
    ctx.lineWidth=fs.browThick; ctx.strokeStyle=pal.hair||pal.stripe||'#000'; ctx.stroke();
  }
  const mw=fs.mouthW*(f.mouthW||1);
  if((f.mouthOpen||0)>0.04){
    const rx=mw*(.85+f.mouthOpen*.35), ry=1.6+f.mouthOpen*7.2;
    ctx.beginPath(); ctx.ellipse(0, fs.mouthY-f.mouthOpen*1.5, rx, ry,0,0,7);
    ctx.fillStyle='#57231F'; ctx.fill();
    if((f.teeth||0)>0.05){ ctx.save(); ctx.beginPath();
      ctx.ellipse(0, fs.mouthY-f.mouthOpen*1.5-ry*.7, rx*.8, ry*.5,0,0,7);
      ctx.fillStyle='#FFF'; ctx.fill(); ctx.restore(); }
  } else {
    ctx.beginPath();
    ctx.moveTo(-mw*.8, fs.mouthY-f.smile*3.6);
    ctx.quadraticCurveTo(0, fs.mouthY+f.smile*2.2-.6, mw*.8, fs.mouthY-f.smile*3.6);
    ctx.lineWidth=2; ctx.strokeStyle='#57231F'; ctx.stroke();
  }
}

// ---------- puppet renderer ----------
const EXPRS = {
  neutral:{}, happy:{browAngle:-6,browLift:1.5,squint:.25,smile:.85,mouthW:1.08},
  sad:{browAngle:-16,smile:-.7,lid:.28,mouthW:.94},
  angry:{browAngle:16,browLift:-2.5,smile:-.6,mouthOpen:.2,lid:.22},
  surprised:{browLift:5.5,mouthOpen:.78,mouthW:.74,pupil:.72},
  thinking:{browAsym:3.5,lookBiasX:.55,lookBiasY:.6,smile:-.1},
};
let exprName='neutral', blinkT=0, nextBlink=2.2, blinkPhase=-1;

const canvas = document.getElementById('stage');
const ctx = canvas.getContext('2d');
const animIds = [...new Set(CHAR.animations.map(a=>a.id.replace(/_start|_stop|_idle|_loop|stand_to_|sit_to_|to_|wake_/g,'')))];
const orderedIds = ['idle','walk','run','sit','sleep','talk','jump','wave','action','happy','sad','think','turn','fall'].filter(id=>CHAR.animations.some(a=>a.id===id));
let current = orderedIds[0]||CHAR.animations[0].id;
let playing=true, looping=true, speed=1, t=0, last=performance.now(), dirLeft=false;

function clipById(id){
  return CHAR.animations.find(a=>a.id===id) || CHAR.animations.find(a=>a.id===id+'_loop') || CHAR.animations[0];
}
function curClip(){ return clipById(current); }

const btnRow = document.getElementById('animButtons');
for(const id of orderedIds){
  const b=document.createElement('button');
  b.textContent = id.toUpperCase();
  b.className = id===current?'active':'';
  b.onclick=()=>{ current=id; t=0; [...btnRow.children].forEach(c=>c.className=''); b.className='active'; };
  btnRow.appendChild(b);
}

function frame(){
  const clip=curClip();
  if(playing){ t += (last? (performance.now()-last):0)/1000*speed; }
  last=performance.now();
  // blink scheduler
  if(playing){
    if(blinkPhase>=0){ blinkPhase += (performance.now()-last+16)/220; if(blinkPhase>=1){blinkPhase=-1; nextBlink=2+Math.random()*3.6;} }
    else { blinkT += 1/60; if(blinkT>=nextBlink){ blinkT=0; blinkPhase=0; } }
  }
  const blink = blinkPhase<0?0:(blinkPhase<0.45? blinkPhase/0.45 : 1-(blinkPhase-0.45)/0.55);
  const pose = sampleClip(clip, t);
  draw(pose, blink);
  updateTimeline(clip);
  requestAnimationFrame(frame);
}

function draw(pose, blink){
  const W=canvas.width=canvas.clientWidth*devicePixelRatio, H=canvas.height=canvas.clientHeight*devicePixelRatio;
  ctx.clearRect(0,0,W,H);
  const scl = Math.min(W/380, H/360);
  ctx.save();
  ctx.translate(W/2, H-14);
  ctx.scale(scl,scl);
  if(dirLeft) ctx.scale(-1,1);
  ctx.translate(pose.dx, pose.dy);
  if(pose.tilt) ctx.rotate(pose.tilt*D2R);
  const sol = solve(CHAR.bones, pose.angles);
  const face = Object.assign({}, EXPRS[exprName]);
  const lookX = Math.max(-1,Math.min(1,(face.lookBiasX||0)));
  const lookY = Math.max(-1,Math.min(1,(face.lookBiasY||0)));
  const groundY = CHAR.rigKind==='quadruped_v1' ? 0 : 148;
  for(const layer of CHAR.layers){
    const j = sol.j[layer.bone]; if(!j) continue;
    ctx.save();
    ctx.translate(j[0], j[1]-groundY);
    ctx.rotate(sol.a[layer.bone]);
    if(layer.dynamic){
      if(CHAR.faceStyle) drawFace(ctx, CHAR.faceStyle,
        {blink, lookX, lookY, browAngle:face.browAngle||0, browLift:face.browLift||0,
         browAsym:face.browAsym||0, smile:face.smile||0, mouthOpen:face.mouthOpen||0,
         mouthW:face.mouthW||1, squint:face.squint||0, pupil:face.pupil||1, lid:face.lid||0},
        CHAR.palette, CHAR.faceStyleKind);
    } else {
      for(const s of layer.shapes) drawShape(ctx, s, CHAR.palette);
    }
    ctx.restore();
  }
  ctx.restore();
}

// timeline
const tl = document.getElementById('timeline');
const ph = document.getElementById('playhead');
function updateTimeline(clip){
  const u = ((t%clip.duration)+clip.duration)%clip.duration/clip.duration;
  ph.style.left = (u*100)+'%';
  const ks = clip.tracks[0]?.keyframes||[];
  tl.querySelectorAll('.kf').forEach(e=>e.remove());
  for(const k of ks){ const d=document.createElement('div'); d.className='kf'; d.style.left=(k.time*100)+'%'; tl.appendChild(d); }
}
tl.onclick = e=>{
  const clip=curClip();
  const r=tl.getBoundingClientRect();
  t = ((e.clientX-r.left)/r.width)*clip.duration;
};
setInterval(()=>{ // second ticks
  tl.querySelectorAll('.tick').forEach(e=>e.remove());
  const clip=curClip();
  for(let s=0;s<=clip.duration;s++){
    const d=document.createElement('div'); d.className='tick';
    d.style.left=(s/clip.duration*100)+'%'; d.textContent='0:0'+s;
    tl.appendChild(d);
  }
},1000);

document.getElementById('play').onclick=e=>{ playing=!playing; e.target.textContent=playing?'⏸ Pause':'▶ Play'; };
document.getElementById('stop').onclick=()=>{ t=0; playing=false; document.getElementById('play').textContent='▶ Play'; };
document.getElementById('loop').onclick=e=>{ looping=!looping; e.target.className=looping?'active':''; };
document.getElementById('prev').onclick=()=>{ playing=false; t=Math.max(0,t-1/30); };
document.getElementById('next').onclick=()=>{ playing=false; t+=1/30; };
document.getElementById('speed').onchange=e=>{ speed=parseFloat(e.target.value); };
const exprNames=Object.keys(EXPRS); let ei=0;
document.getElementById('expr').onclick=e=>{ ei=(ei+1)%exprNames.length; exprName=exprNames[ei]; e.target.textContent='Expr: '+exprName; };
document.getElementById('dir').onclick=()=>{ dirLeft=!dirLeft; };
requestAnimationFrame(frame);
</script>
</body>
</html>''';
}
