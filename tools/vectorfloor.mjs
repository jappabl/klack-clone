import puppeteer from 'puppeteer-core';
const CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
// The same vector shapes the panels use, at the same sizes, on the same fills.
const html=`<style>
html,body{margin:0;padding:0}
body{width:600px;height:260px;background:#fff7ed;position:relative}
#dark{position:absolute;left:300px;top:0;width:300px;height:260px;background:#292524}
.a{position:absolute}
</style><div id=dark></div>
<!-- toggle: 44x20 pill, teal, knob 26x16 offset 14 -->
<div class="a" style="left:24px;top:20px;width:44px;height:20px;border-radius:9999px;background:#00bba7;padding:2px;box-sizing:border-box">
  <div style="height:16px;width:26px;border-radius:9999px;background:#fff7ed;transform:translateX(14px)"></div></div>
<!-- slider: 240x4 track + 168 fill + 20x16 thumb -->
<div class="a" style="left:24px;top:60px;width:240px;height:4px;border-radius:9999px;background:rgba(41,37,36,.1)"></div>
<div class="a" style="left:24px;top:60px;width:168px;height:4px;border-radius:9999px;background:#292524"></div>
<div class="a" style="left:178px;top:54px;width:20px;height:16px;border-radius:9999px;background:#fff7ed"></div>
<!-- 18x18 r6 chip + 6px bar -->
<div class="a" style="left:24px;top:100px;width:18px;height:18px;border-radius:6px;background:rgba(41,37,36,.15)"></div>
<div class="a" style="left:52px;top:106px;width:96px;height:6px;border-radius:6px;background:rgba(41,37,36,.1)"></div>
<!-- panel corner: 200x80 r24 with border-top -->
<div class="a" style="left:24px;top:140px;width:200px;height:80px;border-radius:24px;background:rgba(255,247,237,.8);border-top:1px solid rgba(255,247,237,.3)"></div>
<!-- dark side -->
<div class="a" style="left:324px;top:20px;width:24px;height:24px;border-radius:9999px;background:rgba(255,247,237,.1);border-top:1px solid rgba(255,247,237,.15)"></div>
<div class="a" style="left:324px;top:60px;width:18px;height:18px;border-radius:6px;overflow:hidden;position:absolute">
  <div style="position:absolute;inset:0;border-radius:6px;background:linear-gradient(#878078,#44403c)"></div>
  <div style="position:absolute;inset:0;border-radius:6px;border:1px solid rgba(255,247,237,.15)"></div>
  <div style="position:absolute;inset:0;border-radius:6px;border-top:1px solid rgba(255,247,237,.35)"></div></div>
<div class="a" style="left:324px;top:100px;width:36px;height:20px;border-radius:6px;border:1.5px solid rgba(243,88,115,.75);box-sizing:border-box"></div>
<div class="a" style="left:324px;top:140px;width:200px;height:80px;border-radius:24px;background:rgba(41,37,36,.8);border-top:1px solid rgba(255,247,237,.15)"></div>
`;
const b=await puppeteer.launch({executablePath:CHROME,headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=2','--disable-gpu'],
  defaultViewport:{width:600,height:260,deviceScaleFactor:2}});
const p=await b.newPage(); await p.setContent(html);
await new Promise(r=>setTimeout(r,500));
await p.screenshot({path:'shots/vectorfloor-chrome.png'});
await b.close();
