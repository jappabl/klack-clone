import puppeteer from 'puppeteer-core';
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser = await puppeteer.launch({ executablePath: CHROME, headless:'new',
  args:['--hide-scrollbars','--force-device-scale-factor=1','--disable-gpu','--font-render-hinting=none'],
  defaultViewport:{width:1440,height:900,deviceScaleFactor:1}});
const page = await browser.newPage();
await page.goto('https://tryklack.com/', {waitUntil:'networkidle2'});
await new Promise(r=>setTimeout(r,2500));
const out = await page.evaluate(() => {
  const res = {};
  const g = (el,ps) => { const cs=getComputedStyle(el); const o={}; for(const p of ps) o[p]=cs[p]; return o; };
  const pg = (el,pe,ps)=>{ const cs=getComputedStyle(el,pe); const o={}; for(const p of ps) o[p]=cs[p]; return o; };
  const BASE=['content','position','inset','width','height','background','backgroundColor','backgroundImage','borderRadius','boxShadow','transform','opacity','zIndex','top','left','right','bottom','mixBlendMode','filter','backdropFilter','border','borderTop','padding','margin'];
  const mark = document.querySelector('h1 mark');
  res.mark = { outer: g(mark, ['backgroundColor','backgroundImage','color','fontWeight','position','display','padding','margin']),
    before: pg(mark,'::before',BASE), after: pg(mark,'::after',BASE), html: mark.outerHTML.slice(0,600) };
  // feature grid
  const grid = document.querySelector('section.mt-28');
  res.gridHTML = grid ? grid.outerHTML.slice(0,2500) : null;
  // footer big text
  const big = document.querySelector('footer span');
  res.big = big ? {style:g(big,['fontSize','fontWeight','lineHeight','letterSpacing','color','backgroundImage','backgroundClip','webkitBackgroundClip','webkitTextFillColor']), parent:g(big.parentElement,['backgroundImage','height','marginTop','overflow','maskImage','webkitMaskImage'])} : null;
  res.footerHTML = document.querySelector('footer').outerHTML.slice(0,3000);
  // header on scroll
  res.headerCls = document.querySelector('header').className;
  // settings popover html
  const pop = document.querySelector('.top-24.right-11');
  res.popHTML = pop ? pop.outerHTML.slice(0,6000) : null;
  return res;
});
console.log(JSON.stringify(out,null,1));
await browser.close();
