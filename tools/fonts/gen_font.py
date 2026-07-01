#!/usr/bin/env python3
"""
Generate a Connect IQ bitmap font (AngelCode .fnt + PNG atlas) from a TTF.

Renders printable ASCII (32-126) as white glyphs with an alpha-coverage mask,
packed into a single atlas, and emits the .fnt descriptor Connect IQ expects
(mirrors the SDK's Analog sample: aa=1, packed=0, alphaChnl=1, chnl=15).

Usage: gen_font.py <ttf> <size> <out_dir> <name> [face]
  e.g. gen_font.py ~/Library/Fonts/0xProtoNerdFontMono-Regular.ttf 22 \
         apps/watch/resources/fonts claudemono_med "ClaudeMono"
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ttf, size, out_dir, name = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
face = sys.argv[5] if len(sys.argv) > 5 else "ClaudeMono"

CHARS = [chr(c) for c in range(32, 127)]

font = ImageFont.truetype(ttf, size)
ascent, descent = font.getmetrics()
line_h = ascent + descent
adv = round(font.getlength("0"))  # monospace: every glyph advances the same
cell_w, cell_h = adv, line_h

atlas_w = 256
per_row = max(1, atlas_w // (cell_w + 1))
rows = (len(CHARS) + per_row - 1) // per_row
atlas_h = rows * (cell_h + 1)
atlas = Image.new("RGBA", (atlas_w, atlas_h), (255, 255, 255, 0))

meta = []
for i, ch in enumerate(CHARS):
    x = (i % per_row) * (cell_w + 1)
    y = (i // per_row) * (cell_h + 1)
    cover = Image.new("L", (cell_w, cell_h), 0)
    ImageDraw.Draw(cover).text((0, 0), ch, font=font, fill=255, anchor="la")
    glyph = Image.new("RGBA", (cell_w, cell_h), (255, 255, 255, 0))
    glyph.putalpha(cover)  # white RGB, alpha = antialiased coverage
    atlas.paste(glyph, (x, y))
    meta.append((ord(ch), x, y, cell_w, cell_h))

os.makedirs(out_dir, exist_ok=True)
png = f"{name}_0.png"
atlas.save(os.path.join(out_dir, png))

with open(os.path.join(out_dir, f"{name}.fnt"), "w") as f:
    f.write(f'info face="{face}" size=-{size} bold=0 italic=0 charset="" unicode=1 '
            f'stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0\n')
    f.write(f'common lineHeight={line_h} base={ascent} scaleW={atlas_w} scaleH={atlas_h} '
            f'pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0\n')
    f.write(f'page id=0 file="{png}"\n')
    f.write(f'chars count={len(meta)}\n')
    for cid, x, y, w, h in meta:
        f.write(f'char id={cid} x={x} y={y} width={w} height={h} '
                f'xoffset=0 yoffset=0 xadvance={adv} page=0 chnl=15\n')

print(f"{name}: {len(meta)} glyphs, cell {cell_w}x{cell_h}, atlas {atlas_w}x{atlas_h}")
