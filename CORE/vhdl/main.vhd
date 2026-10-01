----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;
use work.globals.all;
library work;
use work.video_modes_pkg.all;
library xpm;
use xpm.vcomponents.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(3 downto 0);
      video_green_o           : out std_logic_vector(3 downto 0);
      video_blue_o            : out std_logic_vector(3 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0);
      
       -- ROM download bus from QNICE
      dn_clk_i                : in  std_logic;
      dn_addr_i               : in  std_logic_vector(24 downto 0);
      dn_data_i               : in  std_logic_vector(7 downto 0);
      dn_wr_i                 : in  std_logic;
      
      
      osm_control_i           : in  std_logic_vector(255 downto 0)
   );
end entity main;

architecture synthesis of main is

-- @TODO: Remove these demo core signals
signal keyboard_n          : std_logic_vector(79 downto 0);


-- -------------------------------------------------------------------------
-- Exed Exes core signals
-- -------------------------------------------------------------------------

-- Reset
signal reset       : std_logic;

-- Cabinet / controls
signal ee_cab_1p   : std_logic_vector(1 downto 0);
signal ee_coin     : std_logic_vector(1 downto 0);
signal service     : std_logic;
signal joystick1   : std_logic_vector(5 downto 0);
signal joystick2   : std_logic_vector(5 downto 0);

-- DIP switches
signal ee_dipsw_a  : std_logic_vector(7 downto 0);
signal ee_dipsw_b  : std_logic_vector(7 downto 0);
signal ee_dipsw    : std_logic_vector(31 downto 0);

signal dip_pause   : std_logic;
signal dip_flip    : std_logic;

-- Debug / layer controls
signal ee_debug_view: std_logic_vector(7 downto 0);

-- Pixel enables
signal ee_pxl2_cen  : std_logic;

-- Audio
signal psg0        : std_logic_vector(9 downto 0);
signal psg1        : std_logic_vector(10 downto 0);
signal psg2        : std_logic_vector(10 downto 0);

-- Main CPU ROM
signal main_cs     : std_logic;
signal main_addr   : std_logic_vector(16 downto 0);
signal main_data   : std_logic_vector(7 downto 0);
signal main_ok     : std_logic;

-- Sound CPU ROM
signal snd_cs      : std_logic;
signal snd_addr    : std_logic_vector(14 downto 0);
signal snd_data    : std_logic_vector(7 downto 0);
signal snd_ok      : std_logic;

-- MAP 1 ROM
signal map1_cs     : std_logic;
signal map1_addr   : std_logic_vector(13 downto 0);
signal map1_data   : std_logic_vector(7 downto 0);
signal map1_ok     : std_logic;

-- MAP 2 ROM
signal map2_cs     : std_logic;
signal map2_addr   : std_logic_vector(12 downto 0);
signal map2_data   : std_logic_vector(15 downto 0);
signal map2_ok     : std_logic;

-- Character ROM
signal char_addr   : std_logic_vector(13 downto 0);
signal char_data   : std_logic_vector(15 downto 0);
signal char_ok     : std_logic;

-- Scroll 1 ROM
signal scr1_addr   : std_logic_vector(14 downto 0);
signal scr1_data   : std_logic_vector(31 downto 0);
signal scr1_ok     : std_logic;

-- Scroll 2 ROM
signal scr2_addr   : std_logic_vector(13 downto 0);
signal scr2_data   : std_logic_vector(31 downto 0);
signal scr2_ok     : std_logic;

-- Object / sprite ROM
signal obj_addr    : std_logic_vector(14 downto 0);
signal obj_data    : std_logic_vector(15 downto 0);
signal obj_ok      : std_logic;

-- ROM download / PROM programming
signal ioctl_addr  : std_logic_vector(25 downto 0);
signal prog_addr   : std_logic_vector(25 downto 0);
signal prog_data   : std_logic_vector(7 downto 0);
signal prom_we     : std_logic;
signal pre_addr    : std_logic_vector(25 downto 0);
signal post_addr   : std_logic_vector(25 downto 0);

constant m65_1     : integer := 56; --Player 1 Start
constant m65_2     : integer := 59; --Player 2 Start
constant m65_5     : integer := 16; --Insert coin 1
constant m65_6     : integer := 19; --Insert coin 2
constant m65_9     : integer := 32; --Service button


component jtexed_game is
   port (
      -- Clock / reset
      clk             : in  std_logic;
      rst             : in  std_logic;

      -- Clock enables
      pxl_cen         : out std_logic;
      pxl2_cen        : out std_logic;

      -- Controls / framework
      joystick1       : in  std_logic_vector(9 downto 0);
      joystick2       : in  std_logic_vector(9 downto 0);
      coin            : in  std_logic_vector(1 downto 0);
      start           : in  std_logic_vector(1 downto 0);
      service         : in  std_logic;
      tilt            : in  std_logic;
      dipsw           : in  std_logic_vector(23 downto 0);
      dip_pause       : in  std_logic;
      flip            : in  std_logic;

      -- Video
      red             : out std_logic_vector(3 downto 0);
      green           : out std_logic_vector(3 downto 0);
      blue            : out std_logic_vector(3 downto 0);
      LHBL            : out std_logic;
      LVBL            : out std_logic;
      HS              : out std_logic;
      VS              : out std_logic;

      -- Audio
      snd             : out signed(15 downto 0);
      sample          : out std_logic;

      -- Main CPU ROM
      main_addr       : out std_logic_vector(16 downto 0);
      main_data       : in  std_logic_vector(7 downto 0);
      main_ok         : in  std_logic;

      -- Sound CPU ROM
      snd_addr        : out std_logic_vector(14 downto 0);
      snd_data        : in  std_logic_vector(7 downto 0);
      snd_ok          : in  std_logic;

      -- MAP 1 ROM
      map1_addr       : out std_logic_vector(13 downto 0);
      map1_data       : in  std_logic_vector(7 downto 0);
      map1_ok         : in  std_logic;

      -- MAP 2 ROM
      map2_addr       : out std_logic_vector(12 downto 0);
      map2_data       : in  std_logic_vector(15 downto 0);
      map2_ok         : in  std_logic;

      -- Character ROM
      char_addr       : out std_logic_vector(13 downto 0);
      char_data       : in  std_logic_vector(15 downto 0);
      char_ok         : in  std_logic;

      -- Scroll 1 ROM
      scr1_addr       : out std_logic_vector(14 downto 0);
      scr1_data       : in  std_logic_vector(31 downto 0);
      scr1_ok         : in  std_logic;

      -- Scroll 2 ROM
      scr2_addr       : out std_logic_vector(13 downto 0);
      scr2_data       : in  std_logic_vector(31 downto 0);
      scr2_ok         : in  std_logic;

      -- Object / sprite ROM
      obj_addr        : out std_logic_vector(14 downto 0);
      obj_data        : in  std_logic_vector(15 downto 0);
      obj_ok          : in  std_logic
   );
end component;

begin

    -- SW1
    ee_dipsw_a <= not (
    osm_control_i(C_MENU_SW1_7) &
    osm_control_i(C_MENU_SW1_6) &
    osm_control_i(C_MENU_SW1_5) &
    osm_control_i(C_MENU_SW1_4) &
    osm_control_i(C_MENU_SW1_3) &
    osm_control_i(C_MENU_SW1_2) &
    osm_control_i(C_MENU_SW1_1) &
    osm_control_i(C_MENU_SW1_0));
    
    ee_dipsw_b <= not (
    osm_control_i(C_MENU_SW2_7) &
    osm_control_i(C_MENU_SW2_6) &
    osm_control_i(C_MENU_SW2_5) &
    osm_control_i(C_MENU_SW2_4) &
    osm_control_i(C_MENU_SW2_3) &
    osm_control_i(C_MENU_SW2_2) &
    osm_control_i(C_MENU_SW2_1) &
    osm_control_i(C_MENU_SW2_0));
    
    ee_dipsw <=  x"0000" & ee_dipsw_b & ee_dipsw_a;
    ee_cab_1p(0) <= keyboard_n(m65_1); -- 1P Start
    ee_coin(0) <= keyboard_n(m65_6);   -- Coin 1
    ee_coin(1) <= keyboard_n(m65_5);   -- Coin 2
   
   i_jtexed_game : entity work.jtexed_game
   port map (
      -- Clock / reset
      clk         => clk_main_i,
      rst         => reset,

      -- Cabinet inputs
      cab_1p      => ee_cab_1p,
      coin        => ee_coin,
      service     => keyboard_n(m65_9),
      joystick1   => joystick1,
      joystick2   => joystick2,

      -- DIP switches
      dipsw       => ee_dipsw,
      dip_pause   => dip_pause,
      dip_flip    => dip_flip,

      -- Debug / layer controls
      gfx_en      => "1111",
      debug_bus   => (others => '0'),
      debug_view  => ee_debug_view,

      -- Pixel enables
      pxl_cen     => video_ce_o,
      pxl2_cen    => ee_pxl2_cen,

      -- Video
      red         => video_red_o,
      green       => video_green_o,
      blue        => video_blue_o,
      LHBL        => video_hblank_o,
      LVBL        => video_vblank_o,
      HS          => video_hs_o,
      VS          => video_vs_o,

      -- Audio
      psg0        => psg0,
      psg1        => psg1,
      psg2        => psg2,

      -- Main CPU ROM
      main_cs     => main_cs,
      main_addr   => main_addr,
      main_data   => main_data,
      main_ok     => main_ok,

      -- Sound CPU ROM
      snd_cs      => snd_cs,
      snd_addr    => snd_addr,
      snd_data    => snd_data,
      snd_ok      => snd_ok,

      -- MAP 1 ROM
      map1_cs     => map1_cs,
      map1_addr   => map1_addr,
      map1_data   => map1_data,
      map1_ok     => map1_ok,

      -- MAP 2 ROM
      map2_cs     => map2_cs,
      map2_addr   => map2_addr,
      map2_data   => map2_data,
      map2_ok     => map2_ok,

      -- Character ROM
      char_addr   => char_addr,
      char_data   => char_data,
      char_ok     => char_ok,

      -- Scroll 1 ROM
      scr1_addr   => scr1_addr,
      scr1_data   => scr1_data,
      scr1_ok     => scr1_ok,

      -- Scroll 2 ROM
      scr2_addr   => scr2_addr,
      scr2_data   => scr2_data,
      scr2_ok     => scr2_ok,

      -- Object / sprite ROM
      obj_addr    => obj_addr,
      obj_data    => obj_data,
      obj_ok      => obj_ok,

      -- PROM / ROM programming
      ioctl_addr  => ioctl_addr,
      prog_addr   => prog_addr,
      prog_data   => prog_data,
      prom_we     => prom_we,

      pre_addr    => pre_addr,
      post_addr   => post_addr
   );

  
   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,

         -- Interface to the MEGA65 keyboard
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,

         -- @TODO: Create the kind of keyboard output that your core needs
         -- "example_n_o" is a low active register and used by the demo core:
         --    bit 0: Space
         --    bit 1: Return
         --    bit 2: Run/Stop
         example_n_o          => keyboard_n
      ); -- i_keyboard

end architecture synthesis;

