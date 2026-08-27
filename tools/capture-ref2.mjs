import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=2','--disable-gpu','--font-render-hinting=none'],
  defaultViewport:{width:1440,height:900,deviceScaleFactor:2}});
const page=await browser.newPage();
await page.emulateMediaFeatures([{name:'prefers-color-scheme',value:'light'}]);
await page.goto('https://tryklack.com/',{waitUntil:'networkidle2',timeout:60000});
await new Promise(r=>setTimeout(r,3500));
await page.addStyleTag({content:`*,*::before,*::after{transition-duration:0s!important;animation-duration:0s!important}`});
await new Promise(r=>setTimeout(r,500));

const SEL={ pop:'div.top-24.right-11', sw:'div[class*="w-\\[19.5rem\\]"]', hero:'div.relative.size-full' };
const rect = async (sel)=> page.evaluate(s=>{const r=document.querySelector(s).getBoundingClientRect();
  return {x:r.x+scrollX,y:r.y+scrollY,w:r.width,h:r.height};}, sel);

const R={}; for(const k of Object.keys(SEL)) R[k]=await rect(SEL[k]);
fs.writeFileSync('ref/rects.json',JSON.stringify(R,null,1));
console.log(JSON.stringify(R));

const clip=(r,{t=0,l=0,b=0,rr=0}={})=>({x:Math.round(r.x-l),y:Math.round(r.y-t),
  width:Math.round(r.w+l+rr),height:Math.round(r.h+t+b)});

const shot=(name,c)=>page.screenshot({path:`shots/${name}.png`,clip:c,captureBeyondViewport:true});

// exact panels
await shot('ref-pop',   clip(R.pop));
await shot('ref-sw',    clip(R.sw));
// shadow-inclusive (no top pad: menubar pill / privacy btn live there)
await shot('ref-pop-sh',clip(R.pop,{l:36,rr:36,b:44}));
await shot('ref-sw-sh', clip(R.sw, {l:36,rr:36,b:44}));

// ---- states ----
async function hoverShot(name, sel, clipRect){
  const el=await page.$(sel); await el.hover(); await new Promise(r=>setTimeout(r,260));
  await shot(name, clipRect);
}
// popover rows: 7th li = Klack Settings..., 8th = Quit Klack
await hoverShot('ref-pop-hover-settings','div.top-24.right-11 ul li:nth-child(7)',clip(R.pop));
await hoverShot('ref-pop-hover-quit',    'div.top-24.right-11 ul li:nth-child(8)',clip(R.pop));
// switches rows: 2nd li = Japanese Black
const swSel='div[class*="w-\\[19.5rem\\]"] ul li:nth-child(2)';
await hoverShot('ref-sw-hover-row', swSel, clip(R.sw));
// move away, capture rest state again to confirm reversibility
await page.mouse.move(5,5); await new Promise(r=>setTimeout(r,300));
await shot('ref-sw-rest2', clip(R.sw));
await shot('ref-pop-rest2', clip(R.pop));

// measured state deltas from DOM
const states = await page.evaluate(()=>{
  const out={};
  const g=(el,ps)=>{const cs=getComputedStyle(el);const o={};for(const p of ps)o[p]=cs[p];return o;};
  const P=['backgroundColor','color','opacity','transform','transitionProperty','transitionDuration','transitionTimingFunction','boxShadow','borderRadius','width','height','fontSize','fontWeight','lineHeight','letterSpacing','padding','margin','marginTop','paddingTop'];
  const pop=document.querySelector('div.top-24.right-11');
  out.panel=g(pop,['width','height','borderRadius','backgroundColor','borderTopWidth','borderTopColor','boxShadow','backdropFilter','padding']);
  const lis=[...pop.querySelectorAll('ul>li')];
  out.rows=lis.map((li,i)=>({i,text:li.textContent.trim().slice(0,24),...g(li,P)}));
  const tog=pop.querySelector('button[role=switch]');
  out.toggle={...g(tog,P), knob:g(tog.firstElementChild,P)};
  const sl=pop.querySelector('[role=slider]');
  out.slider={...g(sl,P), track:g(sl.children[0],P), fill:g(sl.children[1],P), thumbBox:g(sl.children[2],P), thumb:g(sl.children[2].firstElementChild,P),
    rects:[...sl.children].map(c=>{const r=c.getBoundingClientRect();return {x:+r.x.toFixed(2),y:+r.y.toFixed(2),w:+r.width.toFixed(2),h:+r.height.toFixed(2)};})};
  const sw=document.querySelector('div[class*="w-[19.5rem]"]');
  out.swPanel=g(sw,['width','height','borderRadius','backgroundColor','borderTopWidth','borderTopColor','boxShadow','backdropFilter','padding']);
  const slis=[...sw.querySelectorAll('ul>li')];
  out.swRows=slis.map((li,i)=>{const r=li.getBoundingClientRect();return {i,text:li.textContent.trim().slice(0,24),h:+r.height.toFixed(2),y:+(r.y+scrollY).toFixed(2),...g(li,['paddingTop','paddingBottom','marginTop','borderRadius','fontSize','fontWeight','color','lineHeight'])};});
  return out;
});
fs.writeFileSync('ref/states.json',JSON.stringify(states,null,1));
await browser.close();
console.log('done');
