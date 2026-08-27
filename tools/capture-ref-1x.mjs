import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=1','--disable-gpu','--font-render-hinting=none'],
  defaultViewport:{width:1440,height:1400,deviceScaleFactor:1}});
const p=await b.newPage();
await p.emulateMediaFeatures([{name:'prefers-color-scheme',value:'light'}]);
await p.goto('https://tryklack.com/',{waitUntil:'networkidle2',timeout:60000});
await new Promise(r=>setTimeout(r,3500));
await p.addStyleTag({content:`*,*::before,*::after{transition-duration:0s!important;animation-duration:0s!important}`});
await p.evaluate(()=>window.scrollTo(0,0));
await p.mouse.move(720,60);
await new Promise(r=>setTimeout(r,500));
const c=(x,y,w,h)=>({x:Math.round(x),y:Math.round(y),width:Math.round(w),height:Math.round(h)});
await p.screenshot({path:'shots/ref1x-pop.png',clip:c(1044,668,288,370.5),captureBeyondViewport:true});
await p.screenshot({path:'shots/ref1x-sw.png', clip:c(176,664.5,328,551),captureBeyondViewport:true});
await b.close();
