import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',args:['--disable-gpu']});
const p=await b.newPage();
await p.setContent('<canvas id=c width=8 height=8></canvas>');
const COLORS={
 'orange-50':'oklch(0.98 0.016 73.684)',
 'stone-200':'oklch(0.923 0.003 48.717)',
 'stone-400':'oklch(0.709 0.01 56.259)',
 'stone-500':'oklch(0.553 0.013 58.071)',
 'stone-800':'oklch(0.268 0.007 34.298)',
 'stone-900':'oklch(0.216 0.006 56.043)',
 'stone-950':'oklch(0.147 0.004 49.25)',
 'teal-500':'oklch(0.704 0.14 182.503)',
 'fuchsia-300':'oklch(0.833 0.145 321.434)',
 'purple-400':'oklch(0.714 0.203 305.504)',
};
const out=await p.evaluate((COLORS)=>{
  const c=document.getElementById('c'),x=c.getContext('2d',{willReadFrequently:true});
  const r={};
  for(const [k,v] of Object.entries(COLORS)){
    x.clearRect(0,0,8,8); x.fillStyle=v; x.fillRect(0,0,8,8);
    const d=x.getImageData(4,4,1,1).data;
    r[k]={rgb:[d[0],d[1],d[2]],hex:'#'+[d[0],d[1],d[2]].map(n=>n.toString(16).padStart(2,'0')).join(''),css:v,resolved:x.fillStyle};
  }
  return r;
},COLORS);
console.log(JSON.stringify(out,null,1));
await b.close();
