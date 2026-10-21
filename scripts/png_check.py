# -*- coding: utf-8 -*-
"""M3 对账脚本：mdc_sample.png PNG 结构校验（纯 stdlib：struct/zlib）。

用法（Windows 需 py -3）：
  py -3 scripts/png_check.py <path/to/mdc_sample.png>

校验规则：
- 8 字节 PNG 签名；
- 逐 chunk：长度/CRC32 校验、IHDR 首位、IEND 末位且无尾部垃圾；
- IHDR：宽高 > 0 且 <= PngRender.MAX_SIDE(4096)，bit depth 8；
- IDAT：拼接后 zlib 可解压，解压后字节数 == h * (1 + w * channels)
  （RGBA_8888 经 ImagePacker 输出 color type 6 → channels=4；
   若打包器产出其它 color type，按其通道数推导并给出告警）；
- 输出与 mm_check/docx_check 同风格的 PASS/FAIL 行，供人工对账记录。
"""
import struct
import sys
import zlib

MAX_SIDE = 4096
SIGNATURE = bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def main():
    if len(sys.argv) < 2:
        print('PNG_CHECK: usage: py -3 scripts/png_check.py <png>')
        return 2
    path = sys.argv[1]
    with open(path, 'rb') as f:
        data = f.read()
    problems = []
    if data[:8] != SIGNATURE:
        print('PNG_CHECK: FAIL bad signature')
        return 1
    pos = 8
    ihdr = None
    idat = b''
    iend_pos = None
    chunk_count = 0
    while pos < len(data):
        if pos + 8 > len(data):
            problems.append('truncated chunk header at %d' % pos)
            break
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8].decode('ascii', 'replace')
        body_end = pos + 8 + length
        if body_end + 4 > len(data):
            problems.append('truncated %s body (len=%d)' % (ctype, length))
            break
        body = data[pos + 8:body_end]
        (crc_stored,) = struct.unpack('>I', data[body_end:body_end + 4])
        crc_calc = zlib.crc32(data[pos + 4:body_end]) & 0xFFFFFFFF
        if crc_stored != crc_calc:
            problems.append('CRC mismatch in %s (stored=%08x calc=%08x)'
                            % (ctype, crc_stored, crc_calc))
        if chunk_count == 0 and ctype != 'IHDR':
            problems.append('first chunk is %s, not IHDR' % ctype)
        if ctype == 'IHDR':
            if ihdr is not None:
                problems.append('duplicate IHDR')
            w, h, depth, color = struct.unpack('>IIBB', body[:10])
            ihdr = (w, h, depth, color)
        elif ctype == 'IDAT':
            idat += body
        elif ctype == 'IEND':
            iend_pos = pos
            if length != 0:
                problems.append('IEND has nonzero length %d' % length)
        pos = body_end + 4
        chunk_count += 1
    if ihdr is None:
        problems.append('missing IHDR')
    else:
        w, h, depth, color = ihdr
        if w <= 0 or h <= 0:
            problems.append('non-positive dims %dx%d' % (w, h))
        if w > MAX_SIDE or h > MAX_SIDE:
            problems.append('dims %dx%d exceed MAX_SIDE %d' % (w, h, MAX_SIDE))
        if depth != 8:
            problems.append('bit depth %d != 8' % depth)
        if color not in CHANNELS:
            problems.append('unknown color type %d' % color)
        elif color != 6:
            print('PNG_CHECK: note color type %d (expected 6 RGBA), '
                  'verifying with %d channel(s)' % (color, CHANNELS[color]))
        if not idat:
            problems.append('missing IDAT')
        else:
            try:
                raw = zlib.decompress(idat)
            except zlib.error as e:
                problems.append('IDAT inflate failed: %s' % e)
                raw = b''
            if ihdr is not None and color in CHANNELS:
                expected = h * (1 + w * CHANNELS[color])
                if len(raw) != expected:
                    problems.append('raw size %d != expected %d '
                                    '(h=%d w=%d ch=%d)'
                                    % (len(raw), expected, h, w, CHANNELS[color]))
    if iend_pos is None:
        problems.append('missing IEND')
    elif iend_pos is not None and pos != len(data):
        problems.append('%d trailing byte(s) after IEND' % (len(data) - pos))
    if problems:
        for p in problems:
            print('PNG_CHECK: FAIL ' + p)
        return 1
    w, h, depth, color = ihdr
    print('PNG_CHECK: PASS w=%d h=%d colortype=%d bitdepth=%d '
          'chunks=%d idat=%dB' % (w, h, color, depth, chunk_count, len(idat)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
