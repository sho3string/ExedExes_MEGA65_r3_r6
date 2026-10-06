#!/usr/bin/env bash
set -euo pipefail

usage() { echo "Usage: $0 [exedexes.zip] [-o output-directory]"; exit 1; }

ZIP_PATH="exedexes.zip"
OUTDIR="exedexes_roms"
if [[ $# -gt 0 && "$1" != "-o" && "$1" != "--out" ]]; then ZIP_PATH=$1; shift; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--out) [[ $# -ge 2 ]] || usage; OUTDIR=$2; shift 2;;
    *) usage;;
  esac
done

[[ -f "$ZIP_PATH" ]] || { echo "ERROR: $ZIP_PATH does not exist" >&2; exit 1; }
for cmd in unzip perl cat wc mkdir mktemp; do command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: required command '$cmd' was not found" >&2; exit 1; }; done
mkdir -p "$OUTDIR"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

read_rom() {
  local name=$1 expected_size=$2 expected_crc=$3 output=$4
  unzip -p "$ZIP_PATH" "$name" > "$output" 2>/dev/null || { echo "ERROR: Missing ROM: $name" >&2; exit 1; }
  local size crc
  size=$(wc -c < "$output")
  crc=$(unzip -v "$ZIP_PATH" "$name" | awk -v n="$name" '$NF==n {print $(NF-1); exit}')
  crc=${crc,,}
  if (( size != expected_size )) || [[ "$crc" != "${expected_crc,,}" ]]; then
    printf 'ERROR: %s: expected size=0x%X crc=%s, got size=0x%X crc=%s\n' "$name" "$expected_size" "$expected_crc" "$size" "${crc:-unknown}" >&2
    exit 1
  fi
}

swap_bytes16() {
  perl -e 'use strict; use warnings; local $/; my $d=<>; die "16-bit byte swap requires even length\n" if length($d)&1; for(my $i=0;$i<length($d);$i+=2){print substr($d,$i+1,1),substr($d,$i,1)}' < "$1" > "$2"
}
interleave16() {
  perl -e 'use strict; use warnings; my($a,$b,$o)=@ARGV; open A,"<:raw",$a or die $!; open B,"<:raw",$b or die $!; open O,">:raw",$o or die $!; local $/; my$x=<A>;my$y=<B>;die "interleave inputs differ in size\n" unless length($x)==length($y);for(my$i=0;$i<length($x);$i++){print O substr($x,$i,1),substr($y,$i,1)}' "$1" "$2" "$3"
}
write_rom() { cp "$1" "$OUTDIR/$2"; local s; s=$(wc -c < "$OUTDIR/$2"); local c; c=$(unzip -v /dev/null 2>/dev/null || true); printf '%-20s %6X bytes\n' "$2" "$s"; }

# Extract and validate exactly the ROM set used by exedexes.py
read_rom '11m_ee04.bin' 0x4000 44140dbd "$TMP/main0"
read_rom '10m_ee03.bin' 0x4000 bf72cfba "$TMP/main1"
read_rom '09m_ee02.bin' 0x4000 7ad95e2f "$TMP/main2"
read_rom '11e_ee01.bin' 0x4000 73cdf3b2 "$TMP/sound"
read_rom '05c_ee00.bin' 0x2000 cadb75bd "$TMP/charraw"
read_rom 'h01_ee08.bin' 0x4000 96a65c1d "$TMP/scr2"
read_rom 'a03_ee06.bin' 0x4000 6039bdd1 "$TMP/a03"
read_rom 'a02_ee05.bin' 0x4000 b32d8252 "$TMP/a02"
read_rom 'j11_ee10.bin' 0x4000 bc83e265 "$TMP/j11"
read_rom 'j12_ee11.bin' 0x4000 0e0f300d "$TMP/j12"
read_rom 'c01_ee07.bin' 0x4000 3625a68d "$TMP/map1"
read_rom 'h04_ee09.bin' 0x2000 6057c907 "$TMP/map2"
read_rom '06l_e-06.bin' 0x0100 712ac508 "$TMP/irq"
read_rom '02d_e-02.bin' 0x0100 8d0d5935 "$TMP/p0"
read_rom '03d_e-03.bin' 0x0100 d3c17efc "$TMP/p1"
read_rom '04d_e-04.bin' 0x0100 58ba964c "$TMP/p2"
read_rom '06f_e-05.bin' 0x0100 35a03579 "$TMP/p3"
read_rom 'l04_e-10.bin' 0x0100 1dfad87a "$TMP/p4"
read_rom 'c04_e-07.bin' 0x0100 850064e0 "$TMP/p5"
read_rom 'l09_e-11.bin' 0x0100 2bb68710 "$TMP/p6"
read_rom 'l10_e-12.bin' 0x0100 173184ef "$TMP/p7"
read_rom 'k06_e-08.bin' 0x0100 0eaf5158 "$TMP/p8"
read_rom 'l03_e-09.bin' 0x0100 0d968558 "$TMP/p9"
read_rom '03e_e-01.bin' 0x0020 1acee376 "$TMP/p10"

cat "$TMP/main0" "$TMP/main1" "$TMP/main2" > "$TMP/main"
swap_bytes16 "$TMP/charraw" "$TMP/char"
interleave16 "$TMP/a02" "$TMP/a03" "$TMP/scr1"
interleave16 "$TMP/j12" "$TMP/j11" "$TMP/obj"
cat "$TMP/p0" "$TMP/p1" "$TMP/p2" "$TMP/p3" "$TMP/p4" "$TMP/p5" "$TMP/p6" "$TMP/p7" "$TMP/p8" "$TMP/p9" "$TMP/p10" > "$TMP/prom"

cp "$TMP/main"  "$OUTDIR/exed_main.rom"
cp "$TMP/sound" "$OUTDIR/exed_sound.rom"
cp "$TMP/map1"  "$OUTDIR/exed_map1.rom"
cp "$TMP/map2"  "$OUTDIR/exed_map2.rom"
cp "$TMP/char"  "$OUTDIR/exed_char.rom"
cp "$TMP/scr1"  "$OUTDIR/exed_scr1.rom"
cp "$TMP/scr2"  "$OUTDIR/exed_scr2.rom"
cp "$TMP/obj"   "$OUTDIR/exed_obj.rom"
cp "$TMP/irq"   "$OUTDIR/exed_irq.rom"
cp "$TMP/prom"  "$OUTDIR/exed_prom.rom"

cat "$TMP/main" "$TMP/sound" "$TMP/map1" "$TMP/map2" "$TMP/char" "$TMP/scr1" "$TMP/scr2" "$TMP/obj" "$TMP/irq" "$TMP/prom" > "$OUTDIR/exedexes_m2m.rom"

cat > "$OUTDIR/layout.txt" <<'LAYOUT'
main     offset=$000000 size=$00C000 end=$00BFFF
sound    offset=$00C000 size=$004000 end=$00FFFF
map1     offset=$010000 size=$004000 end=$013FFF
map2     offset=$014000 size=$002000 end=$015FFF
char     offset=$016000 size=$002000 end=$017FFF
scr1     offset=$018000 size=$008000 end=$01FFFF
scr2     offset=$020000 size=$004000 end=$023FFF
obj      offset=$024000 size=$008000 end=$02BFFF
irq      offset=$02C000 size=$000100 end=$02C0FF
prom     offset=$02C100 size=$000A20 end=$02CB1F
LAYOUT

echo "Built $OUTDIR/exedexes_m2m.rom"
echo "M2M aggregate layout:"
cat "$OUTDIR/layout.txt"
