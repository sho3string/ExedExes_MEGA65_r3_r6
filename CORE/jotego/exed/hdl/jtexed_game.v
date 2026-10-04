/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Exed Exes - MEGA65 / MiSTer2MEGA65 adaptation
 *
 * Original JTFRAME top-level adapted to remove
 * jtframe_game_ports.inc and expose the required
 * interfaces explicitly.
 */

module jtexed_game(
    // ------------------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------------------
    input               clk,
    input               prog_clk,
    input               rst,

    // ------------------------------------------------------------------------
    // Cabinet inputs
    // ------------------------------------------------------------------------
    input       [1:0]   cab_1p,
    input       [1:0]   coin,
    input               service,

    input       [5:0]   joystick1,
    input       [5:0]   joystick2,

    // ------------------------------------------------------------------------
    // DIP switches
    // ------------------------------------------------------------------------
    input       [15:0]  dipsw,
    input               dip_pause,
    input               dip_flip,

    // ------------------------------------------------------------------------
    // Debug / layer controls
    // ------------------------------------------------------------------------
    input       [3:0]   gfx_en,
    input       [7:0]   debug_bus,
    output      [7:0]   debug_view,

    // ------------------------------------------------------------------------
    // Pixel enables
    // ------------------------------------------------------------------------
    output              pxl_cen,
    output              pxl2_cen,

    // ------------------------------------------------------------------------
    // Video
    // ------------------------------------------------------------------------
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue,

    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,

    // ------------------------------------------------------------------------
    // Audio
    // ------------------------------------------------------------------------
    output      [9:0]   psg0,
    output      [10:0]  psg1,
    output      [10:0]  psg2,

    // ------------------------------------------------------------------------
    // Main CPU ROM
    // ------------------------------------------------------------------------
    output              main_cs,
    output      [16:0]  main_addr,
    input       [7:0]   main_data,
    input               main_ok,

    // ------------------------------------------------------------------------
    // Sound CPU ROM
    // ------------------------------------------------------------------------
    output              snd_cs,
    output      [14:0]  snd_addr,
    input       [7:0]   snd_data,
    input               snd_ok,

    // ------------------------------------------------------------------------
    // MAP 1 ROM
    // ------------------------------------------------------------------------
    output              map1_cs,
    output      [13:0]  map1_addr,
    input       [7:0]   map1_data,
    input               map1_ok,

    // ------------------------------------------------------------------------
    // MAP 2 ROM
    // ------------------------------------------------------------------------
    output              map2_cs,
    output      [12:0]  map2_addr,
    input       [15:0]  map2_data,
    input               map2_ok,

    // ------------------------------------------------------------------------
    // Character ROM
    // ------------------------------------------------------------------------
    output      [13:0]  char_addr,
    input       [15:0]  char_data,
    input               char_ok,

    // ------------------------------------------------------------------------
    // Scroll 1 ROM
    // ------------------------------------------------------------------------
    output      [14:0]  scr1_addr,
    input       [31:0]  scr1_data,
    input               scr1_ok,

    // ------------------------------------------------------------------------
    // Scroll 2 ROM
    // ------------------------------------------------------------------------
    output      [13:0]  scr2_addr,
    input       [31:0]  scr2_data,
    input               scr2_ok,

    // ------------------------------------------------------------------------
    // Object / sprite ROM
    // ------------------------------------------------------------------------
    output      [14:0]  obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,

    // ------------------------------------------------------------------------
    // ROM programming / PROM loader
    //
    // Keep these for the small PROMs instantiated inside the core.
    // ------------------------------------------------------------------------
    input       [25:0]  ioctl_addr,
    input       [25:0]  prog_addr,
    input       [7:0]   prog_data,
    input               prom_we,

    output reg  [25:0]  pre_addr,
    output reg  [25:0]  post_addr
);


// ============================================================================
// Debug
// ============================================================================

assign debug_view = { 7'd0, dip_flip };


// ============================================================================
// Internal signals
// ============================================================================

wire [8:0] V;
wire [8:0] H;

wire [12:0] cpu_AB;
wire [7:0]  cpu_dout;
wire [7:0]  char_dout;

wire [15:0] scr2_hpos;
wire [10:0] scr1_hpos;
wire [10:0] scr1_vpos;

wire        char_cs;
wire        cpu_cen;
wire        char_busy;

wire [2:0]  scr1_pal;
wire [2:0]  scr2_pal;

wire cen12;
wire cen8;
wire cen6;
wire cen3;
wire cen1p5;

wire char_on;
wire scr1_on;
wire scr2_on;
wire obj_on;


// ============================================================================
// PROM programming
// ============================================================================

localparam PROM_IRQ = 0;

reg [11:0] prom;

always @(*) begin
    prom = 12'd0;

    if (prom_we)
        prom[prog_addr[11:8]] = 1'b1;
end


// ============================================================================
// Pixel clock enables
// ============================================================================

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;


// ============================================================================
// Clock enables
//
// JTFRAME core expects a 48 MHz master clock.
// ============================================================================

jtframe_cen48 u_cen(
    .clk     ( clk       ),

    .cen12   ( cen12     ),
    .cen8    ( cen8      ),
    .cen6    ( cen6      ),
    .cen3    ( cen3      ),
    .cen1p5  ( cen1p5    ),

    // unused
    .cen16   (           ),
    .cen4    (           ),
    .cen4_12 (           ),
    .cen3q   (           ),

    .cen16b  (           ),
    .cen12b  (           ),
    .cen6b   (           ),
    .cen3b   (           ),
    .cen3qb  (           ),
    .cen1p5b (           )
);


// ============================================================================
// Main CPU / sound interface
// ============================================================================

wire       RnW;
wire       sres_b;
wire       snd_int;
wire [7:0] snd_latch;


// ============================================================================
// Object system
// ============================================================================

wire       OKOUT;
wire       blcnten;
wire       bus_req;
wire       bus_ack;

wire [8:0] obj_AB;
wire [7:0] main_ram;


// ============================================================================
// ROM layout
//
// From cores/exed/cfg/macros.def
// ============================================================================

localparam [25:0] MAP2_START = 26'h014000;
localparam [25:0] CHAR_START = 26'h016000;

localparam [25:0] SCR1_START = 26'h018000;
localparam [25:0] SCR2_START = 26'h020000;

localparam [25:0] OBJ_START  = 26'h024000;
localparam [25:0] PROM_START = 26'h02C000;


// ============================================================================
// ROM download address transformations
//
// These transformations are part of the original Exed Exes JTFRAME core.
// Do not remove until the M2M ROM loading path reproduces them elsewhere.
// ============================================================================

always @(*) begin

    // ------------------------------------------------------------------------
    // Pre-address transformation
    // ------------------------------------------------------------------------

    pre_addr = ioctl_addr;

    // MAP 2
    if (ioctl_addr >= MAP2_START &&
        ioctl_addr <  CHAR_START)
    begin
        pre_addr[6:0] = {
            ioctl_addr[5:0],
            ioctl_addr[6]
        };
    end

    // Scroll 2
    if (ioctl_addr >= SCR2_START &&
        ioctl_addr <  OBJ_START)
    begin
        pre_addr[7:1] = {
            ioctl_addr[5:1],
            ioctl_addr[7:6]
        };
    end


    // ------------------------------------------------------------------------
    // Post-address transformation
    // ------------------------------------------------------------------------

    post_addr = prog_addr;

    // Scroll 1
    if (ioctl_addr >= SCR1_START &&
        ioctl_addr <  SCR2_START)
    begin
        post_addr[5:1] = {
            prog_addr[4:1],
            prog_addr[5]
        };
    end

    // Objects
    if (ioctl_addr >= OBJ_START &&
        ioctl_addr <  PROM_START)
    begin
        post_addr[5:1] = {
            prog_addr[4:1],
            prog_addr[5]
        };
    end
end


// ============================================================================
// Main CPU
// ============================================================================

jtcommnd_main #(
    .GAME(3)
) u_main(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .prog_clk   ( prog_clk       ),

    .cen6       ( cen6           ),
    .cen3       ( cen3           ),

    .cpu_cen    ( cpu_cen        ),
    .cen_sel    ( 1'b0           ), // 3 MHz CPU

    // Timing
    .flip       (                ),
    .V          ( V              ),
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    .H1         ( H[0]           ),

    // Sound
    .sres_b     ( sres_b         ),
    .snd_latch  ( snd_latch      ),
    .snd2_latch (                ),
    .snd_int    ( snd_int        ),

    // Palette - unused by Exed
    .redgreen_cs(                ),
    .blue_cs    (                ),

    // Layer enables
    .char_on    ( char_on        ),
    .scr1_on    ( scr1_on        ),
    .scr2_on    ( scr2_on        ),
    .obj_on     ( obj_on         ),

    // Character RAM
    .char_dout  ( char_dout      ),
    .cpu_dout   ( cpu_dout       ),
    .char_cs    ( char_cs        ),
    .char_busy  ( char_busy      ),

    // Scroll
    .scr_dout   ( 8'd0           ),
    .scr_cs     (                ),
    .scr_busy   ( 1'b0           ),

    .scr_hpos   ( scr1_hpos      ),
    .scr_vpos   ( scr1_vpos      ),

    .scr1_pal   ( scr1_pal       ),
    .scr2_pal   ( scr2_pal       ),

    // Scroll 2
    .scr2_hpos  ( scr2_hpos      ),

    // Object bus sharing
    .obj_AB     ( obj_AB         ),
    .cpu_AB     ( cpu_AB         ),
    .ram_dout   ( main_ram       ),

    .OKOUT      ( OKOUT          ),
    .blcnten    ( blcnten        ),

    .bus_req    ( bus_req        ),
    .bus_ack    ( bus_ack        ),

    // Main ROM
    .rom_cs     ( main_cs        ),
    .rom_addr   ( main_addr      ),
    .rom_data   ( main_data      ),
    .rom_ok     ( main_ok        ),

    // Cabinet
    .cab_1p     ( cab_1p         ),
    .coin       ( coin           ),
    .service    ( service        ),

    .joystick1  ( joystick1      ),
    .joystick2  ( joystick2      ),

    .RnW        ( RnW            ),

    // IRQ PROM
    .prog_addr  ( prog_addr[7:0] ),
    .prom_6l_we ( prom[PROM_IRQ] ),
    .prog_din   ( prog_data[3:0] ),

    // DIP switches
    .dip_pause  ( dip_pause      ),
    .dipsw_a    ( dipsw[7:0]     ),
    .dipsw_b    ( dipsw[15:8]    )
);


// ============================================================================
// Sound
// ============================================================================

jtexed_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cen3       ( cen3      ),
    .cen1p5     ( cen1p5    ),

    .sres_b     ( 1'b1      ),

    .main_dout  ( cpu_dout  ),
    .snd_latch  ( snd_latch ),
    .snd_int    ( snd_int   ),

    .rom_cs     ( snd_cs    ),
    .rom_addr   ( snd_addr  ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    .psg0       ( psg0      ),
    .psg1       ( psg1      ),
    .psg2       ( psg2      )
);


// ============================================================================
// Video
// ============================================================================

jtexed_video u_video(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .prog_clk   ( prog_clk       ),
    .cen12      ( cen12          ),
    .cen8       ( cen8           ),
    .cen6       ( cen6           ),
    .cen3       ( cen3           ),

    .cpu_cen    ( cpu_cen        ),

    .cpu_AB     ( cpu_AB[11:0]   ),

    .V          ( V              ),
    .H          ( H              ),

    .RnW        ( RnW            ),

    .flip       ( dip_flip       ),

    .cpu_dout   ( cpu_dout       ),

    // Layer enables
    .char_on    ( char_on        ),
    .scr1_on    ( scr1_on        ),
    .scr2_on    ( scr2_on        ),
    .obj_on     ( obj_on         ),

    // Character layer
    .char_cs    ( char_cs        ),
    .char_dout  ( char_dout      ),

    .char_addr  ( char_addr      ),
    .char_data  ( char_data      ),
    .char_busy  ( char_busy      ),
    .char_ok    ( char_ok        ),

    // Scroll 1
    .scr1_addr  ( scr1_addr      ),
    .scr1_data  ( scr1_data      ),
    .scr1_ok    ( scr1_ok        ),

    .scr1_hpos  ( scr1_hpos      ),
    .scr1_vpos  ( scr1_vpos      ),
    .scr1_pal   ( scr1_pal       ),

    .map1_addr  ( map1_addr      ),
    .map1_data  ( map1_data      ),
    .map1_cs    ( map1_cs        ),
    .map1_ok    ( map1_ok        ),

    // Scroll 2
    .scr2_hpos  ( scr2_hpos      ),
    .scr2_pal   ( scr2_pal       ),

    .scr2_addr  ( scr2_addr      ),
    .scr2_data  ( scr2_data      ),
    .scr2_ok    ( scr2_ok        ),

    .map2_addr  ( map2_addr      ),
    .map2_data  ( map2_data      ),
    .map2_cs    ( map2_cs        ),
    .map2_ok    ( map2_ok        ),

    // Objects
    .obj_AB     ( obj_AB         ),
    .main_ram   ( main_ram       ),

    .obj_addr   ( obj_addr       ),
    .obj_data   ( obj_data       ),
    .obj_ok     ( obj_ok         ),

    .OKOUT      ( OKOUT          ),

    .bus_req    ( bus_req        ),
    .bus_ack    ( bus_ack        ),
    .blcnten    ( blcnten        ),

    // PROMs
    .prog_addr  ( prog_addr[7:0] ),
    .prom_we    ( prom           ),
    .prom_din   ( prog_data      ),

    // Video timing
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    .HS         ( HS             ),
    .VS         ( VS             ),

    // Debug
    .gfx_en     ( gfx_en         ),
    .debug_bus  ( debug_bus      ),

    // RGB
    .red        ( red            ),
    .green      ( green          ),
    .blue       ( blue           )
);

endmodule