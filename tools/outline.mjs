import fs from 'node:fs';
const tree = JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const maxDepth = parseInt(process.argv[3]||'6',10);
const filter = process.argv[4] || '';
function line(n, d) {
  const s = n.style, r = n.rect;
  const bits = [];
  bits.push(`${'  '.repeat(d)}${n.tag}${n.id?'#'+n.id:''}${n.cls?'.'+n.cls.trim().split(/\s+/).slice(0,6).join('.'):''}`);
  bits.push(` [${r.x},${r.y} ${r.w}x${r.h}]`);
  if (n.text) bits.push(` "${n.text.slice(0,60)}"`);
  const st=[];
  if (s.fontSize && n.text) st.push(`fs=${s.fontSize}/${s.lineHeight} w=${s.fontWeight} c=${s.color} ls=${s.letterSpacing}`);
  if (s.backgroundColor && s.backgroundColor!=='rgba(0, 0, 0, 0)') st.push(`bg=${s.backgroundColor}`);
  if (s.borderRadius && s.borderRadius!=='0px') st.push(`r=${s.borderRadius}`);
  if (s.boxShadow && s.boxShadow!=='none') st.push(`sh=${s.boxShadow.slice(0,70)}`);
  if (s.transitionDuration && s.transitionDuration!=='0s') st.push(`tr=${s.transitionProperty}|${s.transitionDuration}|${s.transitionTimingFunction}|${s.transitionDelay}`);
  if (s.opacity!=='1') st.push(`op=${s.opacity}`);
  if (s.transform!=='none') st.push(`tf=${s.transform}`);
  if (st.length) bits.push('  {'+st.join('; ')+'}');
  return bits.join('');
}
function walk(n,d){
  if(d>maxDepth) return;
  const l = line(n,d);
  if(!filter || l.toLowerCase().includes(filter.toLowerCase())) console.log(l);
  n.children.forEach(c=>walk(c,d+1));
}
walk(tree,0);
