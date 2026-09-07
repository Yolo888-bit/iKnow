# -*- coding: utf-8 -*-
"""Generate placeholder PNG icons for iKnow (pure stdlib, no PIL)."""
import zlib, struct, os


def png_chunk(tag, data):
    c = struct.pack('>I', len(data)) + tag + data
    c += struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    return c


def make_png(path, size, pixel_fn):
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)  # 8-bit RGB
    rows = b''
    for y in range(size):
        row = b'\x00'
        for x in range(size):
            r, g, b = pixel_fn(x, y, size)
            row += bytes((r, g, b))
        rows += row
    idat = zlib.compress(rows, 9)
    data = sig + png_chunk(b'IHDR', ihdr) + png_chunk(b'IDAT', idat) + png_chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(data)


def icon_pixel(x, y, s):
    # warm-orange rounded look: cream dot on warm orange disc
    cx = cy = s / 2.0
    d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
    if d < s * 0.24:
        return (0xFA, 0xF6, 0xF1)   # cream centre
    if d < s * 0.46:
        return (0xE8, 0x87, 0x5A)   # warm orange ring
    return (0xE8, 0x87, 0x5A)


os.makedirs('AppScope/resources/base/media', exist_ok=True)
os.makedirs('entry/src/main/resources/base/media', exist_ok=True)
make_png('AppScope/resources/base/media/app_icon.png', 108, icon_pixel)
make_png('entry/src/main/resources/base/media/startIcon.png', 216, icon_pixel)
print('icons generated OK')
