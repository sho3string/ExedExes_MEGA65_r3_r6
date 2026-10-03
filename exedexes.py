#!/usr/bin/env python3
"""Build MEGA65-ready Exed Exes ROM images from a MAME exedexes.zip.

The outputs follow the logical ROM buses described by JTEXED mem.yaml rather
than JTFRAME's packed SDRAM image. Address permutations performed by
jtexed_game during JTFRAME download are applied here once, offline.
"""
from pathlib import Path
import argparse, zipfile, zlib

EXPECTED = {
    '11m_ee04.bin': (0x4000, 0x44140dbd),
    '10m_ee03.bin': (0x4000, 0xbf72cfba),
    '09m_ee02.bin': (0x4000, 0x7ad95e2f),
    '11e_ee01.bin': (0x4000, 0x73cdf3b2),
    '05c_ee00.bin': (0x2000, 0xcadb75bd),
    'h01_ee08.bin': (0x4000, 0x96a65c1d),
    'a03_ee06.bin': (0x4000, 0x6039bdd1),
    'a02_ee05.bin': (0x4000, 0xb32d8252),
    'j11_ee10.bin': (0x4000, 0xbc83e265),
    'j12_ee11.bin': (0x4000, 0x0e0f300d),
    'c01_ee07.bin': (0x4000, 0x3625a68d),
    'h04_ee09.bin': (0x2000, 0x6057c907),
    '06l_e-06.bin': (0x0100, 0x712ac508),
    '02d_e-02.bin': (0x0100, 0x8d0d5935),
    '03d_e-03.bin': (0x0100, 0xd3c17efc),
    '04d_e-04.bin': (0x0100, 0x58ba964c),
    '06f_e-05.bin': (0x0100, 0x35a03579),
    'l04_e-10.bin': (0x0100, 0x1dfad87a),
    'c04_e-07.bin': (0x0100, 0x850064e0),
    'l09_e-11.bin': (0x0100, 0x2bb68710),
    'l10_e-12.bin': (0x0100, 0x173184ef),
    'k06_e-08.bin': (0x0100, 0x0eaf5158),
    'l03_e-09.bin': (0x0100, 0x0d968558),
    '03e_e-01.bin': (0x0020, 0x1acee376),
}

def read_checked(z, name):
    b = z.read(name)
    size, crc = EXPECTED[name]
    got = zlib.crc32(b) & 0xffffffff
    if len(b) != size or got != crc:
        raise ValueError(f'{name}: expected size={size:#x} crc={crc:08x}, got size={len(b):#x} crc={got:08x}')
    return b

def permute(data, fn):
    out = bytearray(len(data))
    seen = set()
    for src, value in enumerate(data):
        dst = fn(src)
        if dst >= len(out):
            raise ValueError(f'address permutation produced {dst:#x} for {src:#x}')
        if dst in seen:
            raise ValueError(f'address permutation collision at {dst:#x}')
        seen.add(dst)
        out[dst] = value
    return bytes(out)

def map2_pre_addr(a):
    # jtexed_game: pre_addr[6:0] = { ioctl_addr[5:0], ioctl_addr[6] }
    return (a & ~0x7f) | ((a & 0x3f) << 1) | ((a >> 6) & 1)

def scr2_pre_addr(a):
    # jtexed_game: pre_addr[7:1] = { ioctl_addr[5:1], ioctl_addr[7:6] }
    return (a & ~0xff) | ((a & 1)) | ((a & 0x3e) << 2) | ((a & 0xc0) >> 5)

def post_addr_16(a):
    # jtexed_game: post_addr[5:1] = { prog_addr[4:1], prog_addr[5] }
    return (a & ~0x3f) | (a & 1) | ((a & 0x1e) << 1) | ((a >> 5) & 1) << 1

def swap_bytes16(data):
    if len(data) & 1: raise ValueError('16-bit byte swap requires even length')
    out = bytearray(len(data))
    for i in range(0, len(data), 2): out[i], out[i+1] = data[i+1], data[i]
    return bytes(out)

def interleave16(lo, hi):
    """Pack two equal plane ROMs into 16-bit words: byte0=lo, byte1=hi."""
    if len(lo) != len(hi): raise ValueError('interleave inputs differ in size')
    out = bytearray(len(lo)*2)
    out[0::2] = lo
    out[1::2] = hi
    return bytes(out)

def write(outdir, name, data):
    p = outdir/name
    p.write_bytes(data)
    print(f'{name:20s} {len(data):6X} bytes  crc={zlib.crc32(data)&0xffffffff:08x}')


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('zip', nargs='?', default='exedexes.zip')
    ap.add_argument('-o','--out', default='exedexes_roms')
    args=ap.parse_args()
    out=Path(args.out); out.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(args.zip) as z:
        R=lambda n: read_checked(z,n)

        # 8-bit CPU buses
        main = R('11m_ee04.bin') + R('10m_ee03.bin') + R('09m_ee02.bin')
        snd  = R('11e_ee01.bin')

        # tilerom is split by mem.yaml at byte $4000:
        # map1 = front tile map (8-bit), map2 = back tile map (16-bit).
        map1 = R('c01_ee07.bin')
        map2 = permute(R('h04_ee09.bin'), map2_pre_addr)

        # mame2mra marks chars reverse=true. On the 16-bit runtime bus this is
        # the byte-lane reversal performed by the JTFRAME ROM packer.
        char = swap_bytes16(R('05c_ee00.bin'))

        # 16x16 tiles and sprites are width=16, reverse=true, no_offset=true.
        # Form the 16-bit plane words with the later MAME half in the low lane,
        # matching the reverse ordering, then apply jtexed_game post_addr.
        scr1_raw = interleave16(R('a02_ee05.bin'), R('a03_ee06.bin'))
        scr1 = permute(scr1_raw, post_addr_16)

        # 32x32 tile ROM is a single byte stream on a 32-bit runtime bus.
        # jtexed_game applies the SCR2 pre-address permutation during download.
        scr2 = permute(R('h01_ee08.bin'), scr2_pre_addr)

        obj_raw = interleave16(R('j12_ee11.bin'), R('j11_ee10.bin'))
        obj = permute(obj_raw, post_addr_16)

        irq = R('06l_e-06.bin')
        # PROM order is exactly MAME/JTEXED programming order after IRQ PROM.
        prom_names = ['02d_e-02.bin','03d_e-03.bin','04d_e-04.bin','06f_e-05.bin',
                      'l04_e-10.bin','c04_e-07.bin','l09_e-11.bin','l10_e-12.bin',
                      'k06_e-08.bin','l03_e-09.bin','03e_e-01.bin']
        proms = b''.join(R(n) for n in prom_names)

    write(out,'exed_main.rom', main)
    write(out,'exed_sound.rom', snd)
    write(out,'exed_map1.rom', map1)
    write(out,'exed_map2.rom', map2)
    write(out,'exed_char.rom', char)
    write(out,'exed_scr1.rom', scr1)
    write(out,'exed_scr2.rom', scr2)
    write(out,'exed_obj.rom', obj)
    write(out,'exed_irq.rom', irq)
    write(out,'exed_prom.rom', proms)

    # Also produce one convenient M2M aggregate with a simple contiguous layout.
    parts=[('main',main),('sound',snd),('map1',map1),('map2',map2),('char',char),
           ('scr1',scr1),('scr2',scr2),('obj',obj),('irq',irq),('prom',proms)]
    agg=bytearray(); manifest=[]
    for name,data in parts:
        off=len(agg); agg += data
        manifest.append((name,off,len(data)))
    write(out,'exedexes_m2m.rom',bytes(agg))
    with (out/'layout.txt').open('w') as f:
        for name,off,size in manifest:
            f.write(f'{name:8s} offset=${off:06X} size=${size:06X} end=${off+size-1:06X}\n')
    print('\nM2M aggregate layout:')
    print((out/'layout.txt').read_text(), end='')

if __name__=='__main__': main()
