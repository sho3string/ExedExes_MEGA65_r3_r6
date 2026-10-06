# Exed Exes - for MEGA65

Exed Exes is Capcom's 1985 vertically scrolling arcade shooter. The
player pilots a combat craft through waves of airborne enemies and
ground targets, using separate attacks while progressing through
increasingly intense stages.

This project ports the **Exed Exes** FPGA core from **Jotego's JTCORES
project** to the MEGA65.

The upstream Exed Exes core used as the basis of this port is:

[Jotego JTCORES - Exed
Exes](https://github.com/jotego/jtcores/tree/master/cores/exed)

The original Exed Exes FPGA implementation, JTFRAME infrastructure and
associated supporting cores are the work of **Jotego and the JTCORES
contributors**.

The MEGA65 port uses the
[MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework and
[QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for integration with
the MEGA65, including FAT32 ROM loading and the on-screen menu.

## Credits

Exed Exes was originally developed and released by **Capcom** in 1985.

This MEGA65 core would not exist without the work of **Jotego and the
JTCORES contributors**. The MEGA65 version is based on the JTCORES Exed
Exes implementation linked above.

Additional credit goes to **sy2002, MJoergen and the MiSTer2MEGA65
contributors** for the MiSTer2MEGA65 framework and QNICE-FPGA
integration used by this port.

## How to install the core

### 1. Obtain the Exed Exes ROM set

You need the MAME **Exed Exes** ROM set:

`exedexes.zip`

ROM files are **not included** with this repository.

The ROM conversion scripts expect the ZIP to contain the following
files:

``` text
11m_ee04.bin
10m_ee03.bin
09m_ee02.bin
11e_ee01.bin
05c_ee00.bin
h01_ee08.bin
a03_ee06.bin
a02_ee05.bin
j11_ee10.bin
j12_ee11.bin
c01_ee07.bin
h04_ee09.bin
06l_e-06.bin
02d_e-02.bin
03d_e-03.bin
04d_e-04.bin
06f_e-05.bin
l04_e-10.bin
c04_e-07.bin
l09_e-11.bin
l10_e-12.bin
k06_e-08.bin
l03_e-09.bin
03e_e-01.bin
```

The conversion will stop with an error if one of the required ROMs is
missing, has an unexpected size, or does not match the expected CRC.

### 2. Generate the MEGA65 ROM images

Three equivalent ROM conversion scripts are provided:

-   `exedexes.py` - Python
-   `exedexes.ps1` - Windows PowerShell
-   `exedexes.sh` - Linux/macOS shell

The scripts read the files directly from `exedexes.zip`; you do **not**
need to extract the MAME ZIP first.

They also perform the transformations required by the MEGA65 port,
including the JTFRAME/JTEXED ROM layout, character byte ordering and
graphics ROM interleaving. The generated aggregate image is laid out in
the format expected by the MEGA65 core.

#### Windows / PowerShell

Place `exedexes.ps1` and `exedexes.zip` in the same directory and run:

``` powershell
.\exedexes.ps1 exedexes.zip
```

If Windows marks the downloaded PowerShell script as coming from the
Internet, you can unblock it with:

``` powershell
Unblock-File .\exedexes.ps1
```

#### Linux / macOS

Place `exedexes.sh` and `exedexes.zip` in the same directory.

Make the script executable if necessary:

``` bash
chmod +x exedexes.sh
```

Then run:

``` bash
./exedexes.sh exedexes.zip
```

The shell version requires `bash`, `unzip`, `perl`, `cat` and `wc`.

#### Python

The Python version can be run with:

``` bash
python3 exedexes.py exedexes.zip
```

On Windows, depending on your Python installation, you can also use:

``` powershell
python .\exedexes.py exedexes.zip
```

### 3. Generated ROM files

By default the scripts create a directory named:

``` text
exedexes_roms
```

containing:

``` text
exed_main.rom
exed_sound.rom
exed_map1.rom
exed_map2.rom
exed_char.rom
exed_scr1.rom
exed_scr2.rom
exed_obj.rom
exed_irq.rom
exed_prom.rom
exedexes_m2m.rom
layout.txt
```

The expected ROM sizes are:

  File                        Size
  -------------------- -----------
  `exed_main.rom`        `0x0C000`
  `exed_sound.rom`       `0x04000`
  `exed_map1.rom`        `0x04000`
  `exed_map2.rom`        `0x02000`
  `exed_char.rom`        `0x02000`
  `exed_scr1.rom`        `0x08000`
  `exed_scr2.rom`        `0x04000`
  `exed_obj.rom`         `0x08000`
  `exed_irq.rom`         `0x00100`
  `exed_prom.rom`        `0x00A20`
  `exedexes_m2m.rom`     `0x2CB20`

`layout.txt` records the offset and size of each region within
`exedexes_m2m.rom`.

You can optionally specify another output directory.

PowerShell:

``` powershell
.\exedexes.ps1 exedexes.zip -Out my_roms
```

Linux/macOS:

``` bash
./exedexes.sh exedexes.zip -o my_roms
```

Python:

``` bash
python3 exedexes.py exedexes.zip -o my_roms
```

### 4. Copy the ROMs to the MEGA65 SD card

Copy the generated Exed Exes ROM files to the directory expected by the
core on your MEGA65 SD card.

The folder where the ROMs reside must be:

``` text
/arcade/exedexes
```

Also copy the supplied `exedcfg` configuration file to this directory.

Both the bottom SD card slot and the rear SD card slot can be used. As
with other MEGA65 cores, the rear SD card takes precedence when both are
present.

Install the Exed Exes `.cor` file using the normal MEGA65 core
installation procedure.

## Game setup

Press the **HELP** key while the core is running to open the
MiSTer2MEGA65 on-screen menu.

The menu provides display, control and DIP-switch settings for the core.

### Video output

Exed Exes is a vertically oriented arcade game. The MEGA65 port uses the
MiSTer2MEGA65 rotation/frame-buffer support to present the arcade
display in the correct orientation.

The core supports the MiSTer2MEGA65 digital video modes as well as
analog/VGA output modes.

The VGA menu provides:

-   Standard output
-   Retro 15 kHz mode with separate HS/VS
-   Retro 15 kHz mode with CSYNC

### Controls

The MEGA65 joystick ports are used for the arcade controls.

Exed Exes supports simultaneous two-player play, so joystick ports 1 and
2 are handled independently.

The second fire button can be connected through the MEGA65 POT lines.
The on-screen menu provides independent configuration for each joystick:

-   Joy 1 second fire: POTX or POTY
-   Joy 2 second fire: POTX or POTY
-   Joy 1 second-fire polarity
-   Joy 2 second-fire polarity

If a second fire button appears permanently pressed or behaves
backwards, change the polarity setting for that joystick port.

### DIP switches

The original Exed Exes arcade DIP switches can be configured from the
on-screen menu.

The DIP-switch menus expose the individual SW1 and SW2 settings so the
arcade configuration can be adjusted from the MEGA65.

## Upstream projects

This port builds upon the work of several open-source FPGA projects:

-   [Jotego JTCORES](https://github.com/jotego/jtcores)
-   [Exed Exes core in
    JTCORES](https://github.com/jotego/jtcores/tree/master/cores/exed)
-   [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
-   [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA)

Please support the upstream projects and developers whose work made this
MEGA65 port possible.

## Status

This is an initial MEGA65 release of the Exed Exes core.

Please report MEGA65-specific problems through the Exed Exes MEGA65
project rather than to the upstream JTCORES project unless the problem
has also been reproduced on the original upstream implementation.
