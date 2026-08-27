import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=1','--disable-gpu'],
  defaultViewport:{width:1200,height:600,deviceScaleFactor:1}});
const p=await b.newPage();
// black half-plane ends at x=600. Backdrop element starts exactly at x=600.
await p.setContent(`<style>html,body{margin:0;background:#fff}
#l{position:absolute;left:0;top:0;bottom:0;width:600px;background:#000}
#bd{position:absolute;left:600px;top:100px;width:400px;height:400px;backdrop-filter:blur(24px)}
</style><div id=l></div><div id=bd></div>`);
await new Promise(r=>setTimeout(r,500));
await p.screenshot({path:'shots/calib-edge.png'});
await b.close();
