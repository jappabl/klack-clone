import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const VH=1400;
const browser=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=2','--disable-gpu','--font-render-hinting=none'],
  defaultViewport:{width:1440,height:VH,deviceScaleFactor:2}});
const page=await browser.newPage();
await page.emulateMediaFeatures([{name:'prefers-color-scheme',value:'light'}]);
await page.goto('https://tryklack.com/',{waitUntil:'networkidle2',timeout:60000});
await new Promise(r=>setTimeout(r,3500));
await page.addStyleTag({content:`*,*::before,*::after{transition-duration:0s!important;animation-duration:0s!important}`});
await page.evaluate(()=>window.scrollTo(0,0));
await new Promise(r=>setTimeout(r,600));

const SEL={pop:'div.top-24.right-11', sw:'div[class*="w-\\[19.5rem\\]"]', hero:'div.relative.size-full'};
const rects=async()=>page.evaluate(S=>{const o={};for(const k in S){const r=document.querySelector(S[k]).getBoundingClientRect();
  o[k]={x:r.x+scrollX,y:r.y+scrollY,w:r.width,h:r.height};} o._scrollY=scrollY; return o;},SEL);
const R=await rects(); console.log('rects',JSON.stringify(R));
fs.writeFileSync('ref/rects.json',JSON.stringify(R,null,1));

const clip=(r,p={})=>({x:Math.round(r.x-(p.l||0)),y:Math.round(r.y-(p.t||0)),
  width:Math.round(r.w+(p.l||0)+(p.r||0)),height:Math.round(r.h+(p.t||0)+(p.b||0))});
const shot=(n,c)=>page.screenshot({path:`shots/${n}.png`,clip:c,captureBeyondViewport:true});

const away=async()=>{await page.mouse.move(720,60);await new Promise(r=>setTimeout(r,250));};
const over=async(sel)=>{const b=await page.evaluate(s=>{const r=document.querySelector(s).getBoundingClientRect();
  return {x:r.x+r.width/2,y:r.y+r.height/2};},sel); await page.mouse.move(b.x,b.y); await new Promise(r=>setTimeout(r,280));};

await away();
await shot('ref-pop',clip(R.pop)); await shot('ref-sw',clip(R.sw));
await shot('ref-pop-sh',clip(R.pop,{l:36,r:36,b:44}));
await shot('ref-sw-sh', clip(R.sw ,{l:36,r:36,b:44}));
await shot('ref-hero',  clip(R.hero));

await over('div.top-24.right-11 ul li:nth-child(7)'); await shot('ref-pop-hover-settings',clip(R.pop));
await over('div.top-24.right-11 ul li:nth-child(8)'); await shot('ref-pop-hover-quit',clip(R.pop));
await over('div[class*="w-\\[19.5rem\\]"] ul li:nth-child(2)'); await shot('ref-sw-hover-row',clip(R.sw));
await away(); await shot('ref-pop-rest2',clip(R.pop)); await shot('ref-sw-rest2',clip(R.sw));

// focus-visible on the toggle (keyboard)
await page.evaluate(()=>{const b=document.querySelector('div.top-24.right-11 button[role=switch]'); b.setAttribute('tabindex','0'); b.focus();});
await page.keyboard.press('Tab'); await page.keyboard.press('Tab');
await page.evaluate(()=>{const b=document.querySelector('div.top-24.right-11 button[role=switch]'); b.focus();});
await new Promise(r=>setTimeout(r,250));
await shot('ref-pop-focus-toggle',clip(R.pop));
const foc=await page.evaluate(()=>{const b=document.querySelector('div.top-24.right-11 button[role=switch]');
  return {matches:b.matches(':focus-visible'), boxShadow:getComputedStyle(b).boxShadow, outline:getComputedStyle(b).outline};});
console.log('focus',JSON.stringify(foc));
const after=await rects(); console.log('rects_after',JSON.stringify(after));
await browser.close();
