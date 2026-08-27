import fs from 'node:fs';
const tree = JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const rows=[];
(function walk(n){
  if(n.text) rows.push({y:n.rect.y,x:n.rect.x,w:n.rect.w,h:n.rect.h,t:n.text,fs:n.style.fontSize,lh:n.style.lineHeight,fw:n.style.fontWeight,c:n.style.color,ls:n.style.letterSpacing,tag:n.tag,cls:n.cls.slice(0,80)});
  n.children.forEach(walk);
})(tree);
rows.sort((a,b)=>a.y-b.y||a.x-b.x);
for(const r of rows) console.log(`y=${r.y.toFixed(1)} x=${r.x.toFixed(1)} ${r.w.toFixed(1)}x${r.h.toFixed(1)} ${r.fs}/${r.lh} w${r.fw} ls=${r.ls} ${r.c}  <${r.tag}> "${r.t}"`);
