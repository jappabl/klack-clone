import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
// "H" sits exactly on the baseline; its ink bottom row locates the baseline.
const CASES=[[15,22.5,700],[15,22.5,500],[14,20,600],[12,16,600]];
const html=`<style>html,body{margin:0;background:#fff}
body{font-family:ui-sans-serif,system-ui,sans-serif}
div{position:absolute;left:0;width:200px;color:#000;white-space:pre}</style>`+
CASES.map((c,i)=>`<div style="top:${i*60}px;font-size:${c[0]}px;line-height:${c[1]}px;font-weight:${c[2]}">HHHH</div>`).join('');
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=2','--disable-gpu','--font-render-hinting=none'],
  defaultViewport:{width:220,height:CASES.length*60,deviceScaleFactor:2}});
const p=await b.newPage(); await p.setContent(html);
await new Promise(r=>setTimeout(r,500));
await p.screenshot({path:'shots/baseline-chrome.png'});
console.log(JSON.stringify(CASES));
await b.close();
