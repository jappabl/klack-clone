import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const RUNS=[
 {t:'Klack',            x:24,  y:20,  fs:15, lh:22.5, w:700, c:'#292524', bg:0},
 {t:'Klack Settings...',x:24,  y:60,  fs:15, lh:22.5, w:500, c:'#292524', bg:0},
 {t:'Quit Klack',       x:24,  y:100, fs:15, lh:22.5, w:500, c:'#292524', bg:0},
 {t:'Sound',            x:24,  y:140, fs:14, lh:20,   w:600, c:'rgba(121,113,107,0.75)', bg:0},
 {t:'Switches',         x:24,  y:180, fs:14, lh:20,   w:600, c:'rgba(121,113,107,0.75)', bg:0},
 {t:'Version 2.2',      x:24,  y:220, fs:14, lh:20,   w:600, c:'rgba(121,113,107,0.75)', bg:0},
 {t:'Japanese Black',   x:324, y:20,  fs:15, lh:22.5, w:500, c:'#fff7ed', bg:1},
 {t:'Crystal Purple',   x:324, y:60,  fs:15, lh:22.5, w:500, c:'#fff7ed', bg:1},
 {t:'CherryMX™',   x:324, y:100, fs:14, lh:20,   w:600, c:'rgba(255,247,237,0.4)', bg:1},
 {t:'NovelKeys™',  x:324, y:140, fs:14, lh:20,   w:600, c:'rgba(255,247,237,0.4)', bg:1},
 {t:'New',              x:324, y:180, fs:12, lh:16,   w:600, c:'rgba(243,88,115,0.9)', bg:1},
];
const html=`<style>
html,body{margin:0;padding:0}
body{width:600px;height:260px;background:#fff7ed;
 font-family:ui-sans-serif,system-ui,sans-serif;position:relative}
#dark{position:absolute;left:300px;top:0;width:300px;height:260px;background:#292524}
span{position:absolute;white-space:pre;display:block}
</style><div id=dark></div>`+
RUNS.map(r=>`<span style="left:${r.x}px;top:${r.y}px;font-size:${r.fs}px;line-height:${r.lh}px;font-weight:${r.w};color:${r.c}">${r.t}</span>`).join('');
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=2','--disable-gpu','--font-render-hinting=none'],
  defaultViewport:{width:600,height:260,deviceScaleFactor:2}});
const p=await b.newPage();
await p.setContent(html); await new Promise(r=>setTimeout(r,600));
await p.screenshot({path:'shots/glyphfloor-chrome.png'});
console.log(JSON.stringify(RUNS));
await b.close();
