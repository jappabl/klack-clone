import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=2','--disable-gpu','--font-render-hinting=none'],
  defaultViewport:{width:1440,height:1400,deviceScaleFactor:2}});
const p=await b.newPage();
await p.emulateMediaFeatures([{name:'prefers-color-scheme',value:'light'}]);
await p.goto('https://tryklack.com/',{waitUntil:'networkidle2',timeout:60000});
await new Promise(r=>setTimeout(r,3500));
await p.evaluate(()=>window.scrollTo(0,0));
await new Promise(r=>setTimeout(r,400));

const R=await p.evaluate(()=>{const r=document.querySelector('div.top-24.right-11').getBoundingClientRect();
  return {x:r.x+scrollX,y:r.y+scrollY,w:r.width,h:r.height};});
const clip={x:Math.round(R.x),y:Math.round(R.y),width:Math.round(R.w),height:Math.round(R.h)};

// --- measure the declared transitions BEFORE freezing anything
const motion=await p.evaluate(()=>{
  const pop=document.querySelector('div.top-24.right-11');
  const g=e=>({prop:getComputedStyle(e).transitionProperty,dur:getComputedStyle(e).transitionDuration,
               ease:getComputedStyle(e).transitionTimingFunction,delay:getComputedStyle(e).transitionDelay});
  const sw=document.querySelector('div[class*="w-[19.5rem]"]');
  return {
    toggle:g(pop.querySelector('button[role=switch]')),
    knob:g(pop.querySelector('button[role=switch]').firstElementChild),
    sliderFill:g(pop.querySelector('[role=slider]').children[1]),
    sliderThumbBox:g(pop.querySelector('[role=slider]').children[2]),
    sliderThumb:g(pop.querySelector('[role=slider]').children[2].firstElementChild),
    popRow:g(pop.querySelectorAll('ul>li')[6]),
    swRow:g(sw.querySelectorAll('ul>li')[1]),
    swPreviewLabel:g(sw.querySelectorAll('ul>li')[1].querySelector('div.mr-2')),
    swPlay:g(sw.querySelectorAll('ul>li')[1].querySelector('div.relative.flex')),
  };
});
console.log('MOTION='+JSON.stringify(motion));

// --- toggle OFF (real interaction on the live reference)
await p.evaluate(()=>document.querySelector('div.top-24.right-11 button[role=switch]').click());
await new Promise(r=>setTimeout(r,900));
await p.screenshot({path:'shots/ref-pop-toggle-off.png',clip,captureBeyondViewport:true});
const offStyle=await p.evaluate(()=>{
  const b=document.querySelector('div.top-24.right-11 button[role=switch]');
  return {bg:getComputedStyle(b).backgroundColor, checked:b.getAttribute('aria-checked'),
          knob:getComputedStyle(b.firstElementChild).transform};
});
console.log('OFF='+JSON.stringify(offStyle));

// back on
await p.evaluate(()=>document.querySelector('div.top-24.right-11 button[role=switch]').click());
await new Promise(r=>setTimeout(r,900));

// --- focus-visible ring
await p.evaluate(()=>{const b=document.querySelector('div.top-24.right-11 button[role=switch]');
  b.setAttribute('tabindex','0');});
await p.keyboard.press('Tab');
await p.evaluate(()=>document.querySelector('div.top-24.right-11 button[role=switch]').focus());
await new Promise(r=>setTimeout(r,400));
await p.evaluate(()=>window.scrollTo(0,0));
await new Promise(r=>setTimeout(r,300));
await p.screenshot({path:'shots/ref-pop-focus.png',clip,captureBeyondViewport:true});
const foc=await p.evaluate(()=>{const b=document.querySelector('div.top-24.right-11 button[role=switch]');
  return {fv:b.matches(':focus-visible'),shadow:getComputedStyle(b).boxShadow};});
console.log('FOCUS='+JSON.stringify(foc));
await b.close();
