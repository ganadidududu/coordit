// Reproduce filtered SVG artwork without discarding blur, blend, or shadow nodes.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Resvg } = require('@resvg/resvg-js');
const root = path.resolve(__dirname, '../..');
const source = path.join(root, 'coordit/coordit/Assets.xcassets');
const target = path.join(root, 'android/app/src/main/res/drawable-nodpi');
const rows = [];
const resourceName = name => name.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
for (const set of fs.readdirSync(source).filter(s => s.endsWith('.imageset'))) {
  const asset = fs.readdirSync(path.join(source, set)).find(f => /\.(svg|png)$/.test(f));
  if (!asset) continue;
  const input = fs.readFileSync(path.join(source, set, asset));
  const name = resourceName(set.replace('.imageset', ''));
  let dimensions;
  if (asset.endsWith('.svg')) {
    const svg = input.toString();
    const viewBox = svg.match(/viewBox="([^"]+)"/)[1].split(/\s+/).map(Number);
    const explicit = svg.replace(/width="[^"]+"/, `width="${viewBox[2]}"`).replace(/height="[^"]+"/, `height="${viewBox[3]}"`);
    const render = new Resvg(explicit, { fitTo: { mode: 'zoom', value: 4 } }).render();
    fs.writeFileSync(path.join(target, name + '.png'), render.asPng());
    dimensions = `${render.width} × ${render.height} (4× viewBox)`;
  } else {
    fs.copyFileSync(path.join(source, set, asset), path.join(target, name + '.png'));
    dimensions = `${input.readUInt32BE(16)} × ${input.readUInt32BE(20)} (original)`;
  }
  rows.push(`| ${set}/${asset} | \`${name}\` | ${dimensions} | \`${crypto.createHash('sha256').update(input).digest('hex').slice(0,16)}\` |`);
}
fs.writeFileSync(path.join(root, 'android/docs/ASSET_MAPPING.md'), `# Native asset provenance\n\nSource: coordit/coordit/Assets.xcassets at bd1f931. Artwork only, never entire UI screenshots. PNGs are in drawable-nodpi: Compose gives them the original design dimensions. SVGs are rasterized transparently at 4× viewBox size with @resvg/resvg-js 2.6.2, retaining SVG filter nodes. Original SVG content is not altered except explicit viewport width/height replacing percentage dimensions. Reproduce with \`npm install --prefix tools\` then \`node tools/render-assets.cjs\`.\n\n| Source | Android resource | Pixel dimensions | Source SHA256 prefix |\n|---|---|---|---|\n${rows.join('\n')}\n\nFonts are byte-for-byte copies: GmarketSansLight.otf → gmarket_sans_light.otf, GmarketSansMedium.otf → gmarket_sans_medium.otf, GmarketSansBold.otf → gmarket_sans_bold.otf, Mona12TextHK.otf → mona12_text_hk.otf, ClimateCrisisKRVF.ttf → climate_crisis_kr.ttf. Named Climate instances use actual YEAR values 2012 (2010), 2019 (2019), 2028 (2030). Android glyph rasterization and baselines still require device comparison.\n\nLiquid Glass limitation: native Foundation capsule geometry, tint, stroke, and selected pill are implemented. Apple refraction/backdrop sampling has no identical Android renderer; current translucent surfaces do not claim equivalent glass rendering.\n`);
