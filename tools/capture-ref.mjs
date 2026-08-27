import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const tag = process.argv[2] || 'a';
const browser=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=2','--disable-gpu','--font-render-hinting=none'],
  defaultViewport:{width:1440,height:900,deviceScaleFactor:2}});
const page=await browser.newPage();
await page.emulateMediaFeatures([{name:'prefers-color-scheme',value:'light'}]);
await page.goto('https://tryklack.com/',{waitUntil:'networkidle2',timeout:60000});
await new Promise(r=>setTimeout(r,3500));
// freeze: disable transitions so nothing is mid-flight
await page.addStyleTag({content:`*,*::before,*::after{transition-duration:0s!important;animation-duration:0s!important;}`});
await new Promise(r=>setTimeout(r,600));
const rects = await page.evaluate(()=>{
  const q=s=>{const e=document.querySelector(s); if(!e) return null; const r=e.getBoundingClientRect();
    return {x:r.x+scrollX,y:r.y+scrollY,w:r.width,h:r.height};};
  return {
    hero: q('div.relative.size-full'),
    pop:  q('div.top-24.right-11'),
    sw:   q('div[class*="w-\\[19.5rem\\]"]'),
    clock: document.querySelector('.tabular-nums')?.textContent,
  };
});
console.log(JSON.stringify(rects));
const pad=(r,p)=>({x:Math.round(r.x-p),y:Math.round(r.y-p),width:Math.round(r.w+2*p),height:Math.round(r.h+2*p)});
await page.screenshot({path:`shots/ref2x-hero-${tag}.png`, clip:pad(rects.hero,0), captureBeyondViewport:true});
await page.screenshot({path:`shots/ref2x-pop-${tag}.png`,  clip:pad(rects.pop,40), captureBeyondViewport:true});
await page.screenshot({path:`shots/ref2x-sw-${tag}.png`,   clip:pad(rects.sw,40),  captureBeyondViewport:true});
fs.writeFileSync(`ref/rects-${tag}.json`, JSON.stringify(rects,null,1));
await browser.close();
