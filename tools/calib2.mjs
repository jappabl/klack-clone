import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=1','--disable-gpu'],
  defaultViewport:{width:1200,height:1200,deviceScaleFactor:1}});
const p=await b.newPage();
// big box, shadow only (box fill white on white -> only shadow visible)
await p.setContent(`<style>html,body{margin:0;background:#fff}
#s{position:absolute;left:300px;top:300px;width:600px;height:600px;background:#fff;
   box-shadow:0 0 50px 0 rgba(0,0,0,1)}</style><div id=s></div>`);
await new Promise(r=>setTimeout(r,500));
await p.screenshot({path:'shots/calib-shadow2.png'});
// backdrop blur over a big half-plane, big element
await p.setContent(`<style>html,body{margin:0;background:#fff}
#l{position:absolute;left:0;top:0;bottom:0;width:600px;background:#000}
#bd{position:absolute;left:100px;top:100px;width:1000px;height:1000px;backdrop-filter:blur(24px)}
</style><div id=l></div><div id=bd></div>`);
await new Promise(r=>setTimeout(r,500));
await p.screenshot({path:'shots/calib-backdrop2.png'});
await b.close();
