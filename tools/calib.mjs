import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=1','--disable-gpu'],
  defaultViewport:{width:800,height:400,deviceScaleFactor:1}});
const p=await b.newPage();
await p.setContent(`<style>
html,body{margin:0;background:#fff}
#bg{position:absolute;inset:0}
#bg .l{position:absolute;left:0;top:0;bottom:0;width:400px;background:#000}
#bd{position:absolute;left:100px;top:100px;width:600px;height:200px;backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px)}
</style>
<div id=bg><div class=l></div></div><div id=bd></div>`);
await new Promise(r=>setTimeout(r,400));
await p.screenshot({path:'shots/calib-backdrop.png'});
await p.setContent(`<style>html,body{margin:0;background:#fff}
#s{position:absolute;left:300px;top:150px;width:200px;height:100px;background:#fff;
   box-shadow:0 0 50px 0 rgba(0,0,0,1)}</style><div id=s></div>`);
await new Promise(r=>setTimeout(r,400));
await p.screenshot({path:'shots/calib-shadow.png'});
await b.close();
