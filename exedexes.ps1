param(
    [Parameter(Position=0)][string]$ZipPath = "exedexes.zip",
    [Alias("o")][string]$Out = "exedexes_roms"
)
$ErrorActionPreference = "Stop"

# Resolve relative paths against the directory the script was launched from.
# .NET APIs can otherwise resolve them against PowerShell's process working
# directory (commonly C:\Windows\System32).
$LaunchDir = (Get-Location).ProviderPath
if (-not [IO.Path]::IsPathRooted($ZipPath)) { $ZipPath = Join-Path $LaunchDir $ZipPath }
if (-not [IO.Path]::IsPathRooted($Out))     { $Out     = Join-Path $LaunchDir $Out }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Expected = @{
'11m_ee04.bin'=@(0x4000,'44140dbd'); '10m_ee03.bin'=@(0x4000,'bf72cfba'); '09m_ee02.bin'=@(0x4000,'7ad95e2f');
'11e_ee01.bin'=@(0x4000,'73cdf3b2'); '05c_ee00.bin'=@(0x2000,'cadb75bd'); 'h01_ee08.bin'=@(0x4000,'96a65c1d');
'a03_ee06.bin'=@(0x4000,'6039bdd1'); 'a02_ee05.bin'=@(0x4000,'b32d8252'); 'j11_ee10.bin'=@(0x4000,'bc83e265');
'j12_ee11.bin'=@(0x4000,'0e0f300d'); 'c01_ee07.bin'=@(0x4000,'3625a68d'); 'h04_ee09.bin'=@(0x2000,'6057c907');
'06l_e-06.bin'=@(0x100,'712ac508'); '02d_e-02.bin'=@(0x100,'8d0d5935'); '03d_e-03.bin'=@(0x100,'d3c17efc');
'04d_e-04.bin'=@(0x100,'58ba964c'); '06f_e-05.bin'=@(0x100,'35a03579'); 'l04_e-10.bin'=@(0x100,'1dfad87a');
'c04_e-07.bin'=@(0x100,'850064e0'); 'l09_e-11.bin'=@(0x100,'2bb68710'); 'l10_e-12.bin'=@(0x100,'173184ef');
'k06_e-08.bin'=@(0x100,'0eaf5158'); 'l03_e-09.bin'=@(0x100,'0d968558'); '03e_e-01.bin'=@(0x20,'1acee376')
}

function Get-Crc32([byte[]]$Data) {
    # Use UInt64 for the arithmetic because Windows PowerShell parses
    # 0xFFFFFFFF as signed Int32 (-1), which cannot be cast directly to UInt32.
    [uint64]$crc = 0xFFFFFFFFL
    foreach ($b in $Data) {
        $crc = $crc -bxor [uint64]$b
        for ($i = 0; $i -lt 8; $i++) {
            if (($crc -band 1) -ne 0) {
                $crc = (($crc -shr 1) -bxor 0xEDB88320L) -band 0xFFFFFFFFL
            }
            else {
                $crc = ($crc -shr 1) -band 0xFFFFFFFFL
            }
        }
    }
    return [uint32](($crc -bxor 0xFFFFFFFFL) -band 0xFFFFFFFFL)
}
function Read-Rom($Zip,$Name) {
    $entry=$Zip.GetEntry($Name); if($null -eq $entry){throw "Missing ROM: $Name"}
    $s=$entry.Open(); $m=New-Object IO.MemoryStream
    try{$s.CopyTo($m); [byte[]]$d=$m.ToArray()} finally{$s.Dispose();$m.Dispose()}
    $e=$Expected[$Name]; $crc=(Get-Crc32 $d).ToString('x8')
    if($d.Length -ne $e[0] -or $crc -ne $e[1]){throw ("{0}: expected size=0x{1:X} crc={2}, got size=0x{3:X} crc={4}" -f $Name,$e[0],$e[1],$d.Length,$crc)}
    return ,$d
}
function Join-Bytes([byte[][]]$Arrays) { $n=0;foreach($a in $Arrays){$n+=$a.Length};[byte[]]$o=New-Object byte[] $n;$p=0;foreach($a in $Arrays){[Array]::Copy($a,0,$o,$p,$a.Length);$p+=$a.Length};return ,$o }
function Swap16([byte[]]$d){if($d.Length-band 1){throw '16-bit byte swap requires even length'};[byte[]]$o=New-Object byte[] $d.Length;for($i=0;$i-lt$d.Length;$i+=2){$o[$i]=$d[$i+1];$o[$i+1]=$d[$i]};return ,$o}
function Interleave16([byte[]]$lo,[byte[]]$hi){if($lo.Length-ne$hi.Length){throw 'interleave inputs differ in size'};[byte[]]$o=New-Object byte[] ($lo.Length*2);for($i=0;$i-lt$lo.Length;$i++){$o[2*$i]=$lo[$i];$o[2*$i+1]=$hi[$i]};return ,$o}
function Write-Rom($Dir,$Name,[byte[]]$Data){$p=Join-Path $Dir $Name;[IO.File]::WriteAllBytes($p,$Data);Write-Host ("{0,-20} {1,6:X} bytes  crc={2}" -f $Name,$Data.Length,(Get-Crc32 $Data).ToString('x8'))}

if(-not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){throw "$ZipPath does not exist"}
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$zip=[IO.Compression.ZipFile]::OpenRead((Resolve-Path $ZipPath))
try {
 $R=@{}; foreach($n in $Expected.Keys){$R[$n]=Read-Rom $zip $n}
} finally {$zip.Dispose()}

$main=Join-Bytes @($R['11m_ee04.bin'],$R['10m_ee03.bin'],$R['09m_ee02.bin'])
$sound=$R['11e_ee01.bin']; $map1=$R['c01_ee07.bin']; $map2=$R['h04_ee09.bin']
$char=Swap16 $R['05c_ee00.bin']; $scr1=Interleave16 $R['a02_ee05.bin'] $R['a03_ee06.bin']; $scr2=$R['h01_ee08.bin']; $obj=Interleave16 $R['j12_ee11.bin'] $R['j11_ee10.bin']; $irq=$R['06l_e-06.bin']
$prom=Join-Bytes @($R['02d_e-02.bin'],$R['03d_e-03.bin'],$R['04d_e-04.bin'],$R['06f_e-05.bin'],$R['l04_e-10.bin'],$R['c04_e-07.bin'],$R['l09_e-11.bin'],$R['l10_e-12.bin'],$R['k06_e-08.bin'],$R['l03_e-09.bin'],$R['03e_e-01.bin'])

Write-Rom $Out 'exed_main.rom' $main; Write-Rom $Out 'exed_sound.rom' $sound; Write-Rom $Out 'exed_map1.rom' $map1; Write-Rom $Out 'exed_map2.rom' $map2; Write-Rom $Out 'exed_char.rom' $char; Write-Rom $Out 'exed_scr1.rom' $scr1; Write-Rom $Out 'exed_scr2.rom' $scr2; Write-Rom $Out 'exed_obj.rom' $obj; Write-Rom $Out 'exed_irq.rom' $irq; Write-Rom $Out 'exed_prom.rom' $prom
$agg=Join-Bytes @($main,$sound,$map1,$map2,$char,$scr1,$scr2,$obj,$irq,$prom); Write-Rom $Out 'exedexes_m2m.rom' $agg
$layout=@'
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
'@
[IO.File]::WriteAllText((Join-Path $Out 'layout.txt'),$layout,[Text.Encoding]::ASCII)
Write-Host "`nM2M aggregate layout:"; Write-Host $layout
