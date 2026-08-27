import fs from 'node:fs';
const tree = JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const match = process.argv[3];       // substring of "tag.cls" to root at
const maxDepth = parseInt(process.argv[4]||'6',10);
function key(n){ return `${n.tag}${n.cls?'.'+n.cls.trim().split(/\s+/).join('.'):''}`; }
let found=[];
(function find(n){ if(key(n).includes(match)) found.push(n); n.children.forEach(find); })(tree);
console.log(`# matches: ${found.length}`);
function line(n, d) {
  const s = n.style, r = n.rect;
  let out = `${'  '.repeat(d)}${n.tag}${n.id?'#'+n.id:''}${n.cls?'.'+n.cls.trim().split(/\s+/).join('.'):''}`;
  out += ` [${r.x},${r.y} ${r.w}x${r.h}]`;
  if (n.src) out += ` src=${n.src.slice(0,70)}`;
  if (n.text) out += ` "${n.text.slice(0,70)}"`;
  const st=[];
  if (n.text) st.push(`fs=${s.fontSize}/${s.lineHeight} w=${s.fontWeight} c=${s.color} ls=${s.letterSpacing} ta=${s.textAlign}`);
  if (s.backgroundColor!=='rgba(0, 0, 0, 0)') st.push(`bg=${s.backgroundColor}`);
  if (s.backgroundImage!=='none') st.push(`bgi=${s.backgroundImage.slice(0,90)}`);
  if (s.borderRadius!=='0px') st.push(`r=${s.borderRadius}`);
  if (s.borderTopWidth!=='0px') st.push(`bw=${s.borderTopWidth} bc=${s.borderColor}`);
  if (s.boxShadow!=='none') st.push(`sh=${s.boxShadow}`);
  if (s.opacity!=='1') st.push(`op=${s.opacity}`);
  if (s.transform!=='none') st.push(`tf=${s.transform}`);
  if (s.padding!=='0px') st.push(`p=${s.padding}`);
  if (s.gap!=='normal'&&s.gap) st.push(`gap=${s.gap}`);
  if (s.backdropFilter!=='none') st.push(`bd=${s.backdropFilter}`);
  if (s.filter!=='none') st.push(`fl=${s.filter}`);
  if (s.overflow!=='visible') st.push(`ov=${s.overflow}`);
  if (s.transitionDuration!=='0s') st.push(`trDur=${s.transitionDuration} tf=${s.transitionTimingFunction} dl=${s.transitionDelay}`);
  if (st.length) out += '  {'+st.join('; ')+'}';
  return out;
}
function walk(n,d){ if(d>maxDepth) return; console.log(line(n,d)); n.children.forEach(c=>walk(c,d+1)); }
found.forEach(n=>{ walk(n,0); console.log('---'); });
