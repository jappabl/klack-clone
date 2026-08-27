import puppeteer from 'puppeteer-core';
import fs from 'node:fs';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const url = process.argv[2] || 'https://tryklack.com/';
const outPrefix = process.argv[3] || 'ref';
const width = parseInt(process.argv[4] || '1440', 10);
const height = parseInt(process.argv[5] || '900', 10);
const scheme = process.argv[6] || 'light';

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: ['--hide-scrollbars','--force-device-scale-factor=1','--disable-gpu','--font-render-hinting=none'],
  defaultViewport: { width, height, deviceScaleFactor: 1 },
});
const page = await browser.newPage();
await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: scheme }]);
await page.goto(url, { waitUntil: 'networkidle2', timeout: 60000 });
await new Promise(r => setTimeout(r, 2500));

// trigger scroll animations
const full = await page.evaluate(async () => {
  const h = document.documentElement.scrollHeight;
  for (let y = 0; y < h; y += 400) { window.scrollTo(0, y); await new Promise(r => setTimeout(r, 60)); }
  window.scrollTo(0, h); await new Promise(r => setTimeout(r, 800));
  window.scrollTo(0, 0); await new Promise(r => setTimeout(r, 1200));
  return { scrollHeight: document.documentElement.scrollHeight, innerWidth: window.innerWidth };
});
console.log('page metrics', JSON.stringify(full));

await page.screenshot({ path: `shots/${outPrefix}-${width}-fold.png` });
await page.screenshot({ path: `shots/${outPrefix}-${width}-full.png`, fullPage: true });

const dom = await page.content();
fs.writeFileSync(`ref/${outPrefix}-${width}-hydrated.html`, dom);

const PROPS = ['display','position','top','left','right','bottom','width','height','margin','padding','fontFamily','fontSize','fontWeight','fontStyle','lineHeight','letterSpacing','textAlign','textTransform','color','backgroundColor','backgroundImage','borderRadius','borderTopWidth','borderColor','borderStyle','boxShadow','opacity','transform','transitionProperty','transitionDuration','transitionTimingFunction','transitionDelay','animationName','animationDuration','animationTimingFunction','flexDirection','justifyContent','alignItems','gap','gridTemplateColumns','zIndex','overflow','maxWidth','minHeight','textDecoration','textDecorationColor','outlineWidth','outlineColor','backdropFilter','filter','mixBlendMode','objectFit','whiteSpace'];

const tree = await page.evaluate((PROPS) => {
  function walk(el, depth) {
    if (depth > 14) return null;
    const cs = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0 && el.children.length === 0) return null;
    const style = {};
    for (const p of PROPS) style[p] = cs[p];
    const ownText = Array.from(el.childNodes).filter(n=>n.nodeType===3).map(n=>n.textContent.trim()).filter(Boolean).join(' ');
    return {
      tag: el.tagName.toLowerCase(),
      cls: el.getAttribute('class') || '',
      id: el.id || undefined,
      src: el.getAttribute('src') || el.getAttribute('href') || undefined,
      alt: el.getAttribute('alt') || undefined,
      text: ownText || undefined,
      rect: { x: +r.x.toFixed(2), y: +(r.y + window.scrollY).toFixed(2), w: +r.width.toFixed(2), h: +r.height.toFixed(2) },
      style,
      children: Array.from(el.children).map(c => walk(c, depth+1)).filter(Boolean),
    };
  }
  return walk(document.body, 0);
}, PROPS);
fs.writeFileSync(`ref/${outPrefix}-${width}-tree.json`, JSON.stringify(tree, null, 1));

// collect all asset urls
const assets = await page.evaluate(() => {
  const out = new Set();
  document.querySelectorAll('img,source,video,link[rel=icon]').forEach(e => {
    ['src','srcset','href','poster'].forEach(a => { const v = e.getAttribute(a); if (v) out.add(a+':'+v); });
  });
  document.querySelectorAll('*').forEach(e => {
    const bi = getComputedStyle(e).backgroundImage;
    if (bi && bi !== 'none') out.add('bg:'+bi);
  });
  return [...out];
});
fs.writeFileSync(`ref/${outPrefix}-assets.txt`, assets.join('\n'));

// fonts actually used
const fonts = await page.evaluate(() => {
  const s = new Set();
  document.querySelectorAll('*').forEach(e => s.add(getComputedStyle(e).fontFamily));
  return [...s];
});
console.log('FONTS:', JSON.stringify(fonts, null, 1));
await browser.close();
