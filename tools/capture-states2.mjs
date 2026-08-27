import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=2','--disable-gpu','--font-render-hinting=none','--mute-audio'],
  defaultViewport:{width:1440,height:1400,deviceScaleFactor:2}});
const p=await b.newPage();
await p.emulateMediaFeatures([{name:'prefers-color-scheme',value:'light'}]);
await p.goto('https://tryklack.com/',{waitUntil:'networkidle2',timeout:60000});
await new Promise(r=>setTimeout(r,3500));
await p.evaluate(()=>window.scrollTo(0,0));
await new Promise(r=>setTimeout(r,400));
const R=await p.evaluate(()=>{
  const q=s=>{const r=document.querySelector(s).getBoundingClientRect();return {x:r.x+scrollX,y:r.y+scrollY,w:r.width,h:r.height};};
  return {pop:q('div.top-24.right-11'), sw:q('div[class*="w-\\[19.5rem\\]"]')};
});
const clip=r=>({x:Math.round(r.x),y:Math.round(r.y),width:Math.round(r.w),height:Math.round(r.h)});
const shot=(n,c)=>p.screenshot({path:`shots/${n}.png`,clip:c,captureBeyondViewport:true});
const freeze=()=>p.addStyleTag({content:`*,*::before,*::after{transition-duration:0s!important;
  animation-play-state:paused!important;animation-delay:0s!important}`});

// ---- 1. slider thumb PRESSED, volume unchanged at 70%
// track spans x 1068..1308; press exactly at 70% so the value does not move
const trackX0 = R.pop.x + 24, trackW = 240;
await p.mouse.move(trackX0 + trackW*0.70, R.pop.y + 94.5);
await p.mouse.down();
await new Promise(r=>setTimeout(r,500));
await freeze();
await shot('ref-pop-thumb-press', clip(R.pop));
const press=await p.evaluate(()=>{const t=document.querySelector('[role=slider]').children[2].firstElementChild;
  return {cls:t.className, transform:getComputedStyle(t).transform, scale:getComputedStyle(t).scale};});
console.log('THUMB_PRESS='+JSON.stringify(press));
await p.mouse.up();
await new Promise(r=>setTimeout(r,600));

// ---- 2. slider dragged to 40%
await p.mouse.move(trackX0 + trackW*0.40, R.pop.y + 94.5);
await p.mouse.down(); await new Promise(r=>setTimeout(r,400)); await p.mouse.up();
await new Promise(r=>setTimeout(r,700));
await p.mouse.move(720,60); await new Promise(r=>setTimeout(r,400));
await shot('ref-pop-vol40', clip(R.pop));
const v=await p.evaluate(()=>{const s=document.querySelector('[role=slider]');
  return {now:s.getAttribute('aria-valuenow'), fill:s.children[1].style.width, left:s.children[2].style.left};});
console.log('VOL40='+JSON.stringify(v));
// restore 70
await p.mouse.move(trackX0 + trackW*0.70, R.pop.y + 94.5);
await p.mouse.down(); await new Promise(r=>setTimeout(r,300)); await p.mouse.up();
await new Promise(r=>setTimeout(r,700));
await p.mouse.move(720,60); await new Promise(r=>setTimeout(r,400));

// ---- 3. a switch row PLAYING (click its play button)
const row2 = 'div[class*="w-\\[19.5rem\\]"] ul li:nth-child(2)';
const btn = await p.evaluate(s=>{const e=document.querySelector(s).querySelector('div.relative.flex');
  const r=e.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2};}, row2);
await p.mouse.move(btn.x, btn.y);
await p.mouse.down(); await p.mouse.up();
await new Promise(r=>setTimeout(r,700));
const play=await p.evaluate(s=>{const li=document.querySelector(s);
  return {html: li.querySelector('div.relative.flex').outerHTML.slice(0,400),
          preview: !!li.querySelector('div.mr-2')};}, row2);
console.log('PLAYING='+JSON.stringify(play));
await shot('ref-sw-playing', clip(R.sw));
await b.close();
