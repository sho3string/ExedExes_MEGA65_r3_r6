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
signal joystick1   : std_logic_vector(5 downto 0);
signal joystick2   : std_logic_vector(5 downto 0);

-- DIP switches
signal ee_dipsw_a  : std_logic_vector(7 downto 0);
signal ee_dipsw_b  : std_logic_vector(7 downto 0);
signal ee_dipsw    : std_logic_vector(31 downto 0);

-- Audio
signal psg0        : std_logic_vector(9 downto 0);
signal psg1        : std_logic_vector(10 downto 0);
signal psg2        : std_logic_vector(10 downto 0);

signal audio_mixed : signed(15 downto 0);

-- Main CPU ROM
--signal main_cs     : std_logic;
signal main_addr   : std_logic_vector(16 downto 0);
signal main_data   : std_logic_vector(7 downto 0);
signal main_ok     : std_logic;

-- Sound CPU ROM
signal snd_addr    : std_logic_vector(14 downto 0);
signal snd_data    : std_logic_vector(7 downto 0);
signal snd_ok      : std_logic;

-- MAP 1 ROM
signal map1_addr   : std_logic_vector(13 downto 0);
signal map1_data   : std_logic_vector(7 downto 0);
signal map1_ok     : std_logic;

-- MAP 2 ROM
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
signal shoot2_button1_n : std_logic := '1';
signal shoot2_button2_n : std_logic := '1';
signal pot1_val    : std_logic_vector(7 downto 0);
signal pot2_val    : std_logic_vector(7 downto 0);
signal potxy1_sw   : std_logic;
signal potxy2_sw   : std_logic;
signal pot_pol1_sw : std_logic;
signal pot_pol2_sw : std_logic;


-- Offer some keyboard controls in addition to Joy 1 Controls
constant m65_1          : integer := 56; --Player 1 Start
constant m65_2          : integer := 59; --Player 2 Start
constant m65_5          : integer := 16; --Insert coin 1
constant m65_6          : integer := 19; --Insert coin 2
constant m65_9          : integer := 32; --Service button

constant m65_up_crsr    : integer := 73; --Player up
constant m65_vert_crsr  : integer := 7;  --Player down
constant m65_left_crsr  : integer := 74; --Player left
constant m65_horz_crsr  : integer := 2;  --Player right
constant m65_z          : integer := 12; --Fire 1
constant m65_x          : integer := 23; --Fire 2
constant m65_capslock   : integer := 72; --Pause




-- -------------------------------------------------------------------------
-- Exed Exes ROM download map
-- -------------------------------------------------------------------------
constant C_MAIN_START : natural := 16#000000#;
constant C_SND_START  : natural := 16#00C000#;
constant C_MAP1_START : natural := 16#010000#;
constant C_MAP2_START : natural := 16#014000#;
constant C_CHAR_START : natural := 16#016000#;
constant C_SCR1_START : natural := 16#018000#;
constant C_SCR2_START : natural := 16#020000#;
constant C_OBJ_START  : natural := 16#024000#;
constant C_PROM_START : natural := 16#02C000#;
constant C_ROM_END    : natural := 16#02D000#;

signal dl_main_off : std_logic_vector(25 downto 0);
signal dl_snd_off  : std_logic_vector(25 downto 0);
signal dl_map1_off : std_logic_vector(25 downto 0);
signal dl_map2_off : std_logic_vector(25 downto 0);
signal dl_char_off : std_logic_vector(25 downto 0);
signal dl_scr2_off : std_logic_vector(25 downto 0);

signal main_we, snd_we, map1_we : std_logic;
signal map2_we0, map2_we1 : std_logic;
signal char_we0, char_we1 : std_logic;
signal scr1_we0, scr1_we1, scr1_we2, scr1_we3 : std_logic;
signal scr2_we0, scr2_we1, scr2_we2, scr2_we3 : std_logic;
signal obj_we0, obj_we1 : std_logic;

signal map2_q0, map2_q1 : std_logic_vector(7 downto 0);
signal char_q0, char_q1 : std_logic_vector(7 downto 0);
signal scr1_q0, scr1_q1, scr1_q2, scr1_q3 : std_logic_vector(7 downto 0);
signal scr2_q0, scr2_q1, scr2_q2, scr2_q3 : std_logic_vector(7 downto 0);
signal obj_q0, obj_q1 : std_logic_vector(7 downto 0);

signal main_addr_d : std_logic_vector(main_addr'range);
signal snd_addr_d  : std_logic_vector(snd_addr'range);
signal map1_addr_d : std_logic_vector(map1_addr'range);
signal map2_addr_d : std_logic_vector(map2_addr'range);
signal char_addr_d : std_logic_vector(char_addr'range);
signal scr1_addr_d : std_logic_vector(scr1_addr'range);
signal scr2_addr_d : std_logic_vector(scr2_addr'range);
signal obj_addr_d  : std_logic_vector(obj_addr'range);


-- Object ROM download address after converting the physical graphics
-- layout into the layout expected by jtgng_objdraw.
signal dl_obj_word : std_logic_vector(14 downto 0);

-- Scroll 1 ROM download address after converting the physical 16x16
-- graphics layout into the layout expected by jtexed_scr1.
signal dl_scr1_word : std_logic_vector(14 downto 0);

begin

    -- Core reset
    reset <= reset_soft_i or reset_hard_i;

    -- Feed the raw QNICE byte address through Jotego's original download
    -- address transforms. pre_addr handles MAP2/SCR2; post_addr handles
    -- SCR1/OBJ. The resulting post_addr is the byte address stored in BRAM.
    ioctl_addr <= '0' & dn_addr_i;
    prog_addr  <= pre_addr;
    prog_data  <= dn_data_i;
    prom_we    <= dn_wr_i when unsigned(dn_addr_i) >= C_PROM_START and
                               unsigned(dn_addr_i) <  C_ROM_END else '0';

    dl_main_off <= std_logic_vector(unsigned(post_addr) - C_MAIN_START);
    dl_snd_off  <= std_logic_vector(unsigned(post_addr) - C_SND_START);
    dl_map1_off <= std_logic_vector(unsigned(post_addr) - C_MAP1_START);
    dl_map2_off <= std_logic_vector(unsigned(post_addr) - C_MAP2_START);
    dl_char_off <= std_logic_vector(unsigned(post_addr) - C_CHAR_START);
    dl_scr2_off <= std_logic_vector(unsigned(post_addr) - C_SCR2_START);


    main_we <= dn_wr_i when unsigned(post_addr) >= C_MAIN_START and unsigned(post_addr) < C_SND_START else '0';
    snd_we  <= dn_wr_i when unsigned(post_addr) >= C_SND_START  and unsigned(post_addr) < C_MAP1_START else '0';
    map1_we <= dn_wr_i when unsigned(post_addr) >= C_MAP1_START and unsigned(post_addr) < C_MAP2_START else '0';

    map2_we0 <= dn_wr_i when unsigned(post_addr) >= C_MAP2_START and unsigned(post_addr) < C_CHAR_START and post_addr(0)='0' else '0';
    map2_we1 <= dn_wr_i when unsigned(post_addr) >= C_MAP2_START and unsigned(post_addr) < C_CHAR_START and post_addr(0)='1' else '0';
    char_we0 <= dn_wr_i when unsigned(post_addr) >= C_CHAR_START and unsigned(post_addr) < C_SCR1_START and post_addr(0)='0' else '0';
    char_we1 <= dn_wr_i when unsigned(post_addr) >= C_CHAR_START and unsigned(post_addr) < C_SCR1_START and post_addr(0)='1' else '0';

   
    -- SCR1 byte lanes come directly from the original download byte address.
    -- Address reordering is performed on the 32-bit word address above.
    scr1_we0 <= dn_wr_i when unsigned(dn_addr_i) >= C_SCR1_START and unsigned(dn_addr_i) <  C_SCR2_START and dn_addr_i(1 downto 0) = "00" else '0';
    scr1_we1 <= dn_wr_i when unsigned(dn_addr_i) >= C_SCR1_START and unsigned(dn_addr_i) <  C_SCR2_START and dn_addr_i(1 downto 0) = "01" else '0';    
    scr1_we2 <= dn_wr_i when unsigned(dn_addr_i) >= C_SCR1_START and  unsigned(dn_addr_i) <  C_SCR2_START and dn_addr_i(1 downto 0) = "10" else '0';    
    scr1_we3 <= dn_wr_i when unsigned(dn_addr_i) >= C_SCR1_START and unsigned(dn_addr_i) <  C_SCR2_START and dn_addr_i(1 downto 0) = "11" else '0';
    
    
    scr2_we0 <= dn_wr_i when unsigned(post_addr) >= C_SCR2_START and unsigned(post_addr) < C_OBJ_START and post_addr(1 downto 0)="00" else '0';
    scr2_we1 <= dn_wr_i when unsigned(post_addr) >= C_SCR2_START and unsigned(post_addr) < C_OBJ_START and post_addr(1 downto 0)="01" else '0';
    scr2_we2 <= dn_wr_i when unsigned(post_addr) >= C_SCR2_START and unsigned(post_addr) < C_OBJ_START and post_addr(1 downto 0)="10" else '0';
    scr2_we3 <= dn_wr_i when unsigned(post_addr) >= C_SCR2_START and unsigned(post_addr) < C_OBJ_START and post_addr(1 downto 0)="11" else '0';
    obj_we0 <= dn_wr_i when unsigned(dn_addr_i) >= C_OBJ_START and unsigned(dn_addr_i) <  C_PROM_START and dn_addr_i(0) = '0' else '0';
    obj_we1 <= dn_wr_i when unsigned(dn_addr_i) >= C_OBJ_START and unsigned(dn_addr_i) <  C_PROM_START and dn_addr_i(0) = '1' else '0';
   

    map2_data <= map2_q1 & map2_q0;
    char_data <= char_q1 & char_q0;
    scr1_data <= scr1_q3 & scr1_q2 & scr1_q1 & scr1_q0;
    scr2_data <= scr2_q3 & scr2_q2 & scr2_q1 & scr2_q0;
    obj_data  <= obj_q1 & obj_q0;
    
    
    
    -- -------------------------------------------------------------------------
    -- Object ROM address reordering
    -- -------------------------------------------------------------------------
    -- The Exed Exes sprite ROM stores each 16x16 sprite as two 8-pixel-wide
    -- halves. Within a sprite the physical 16-bit word address is:
    --
    --     ID | HALF | ROW | SUBGROUP
    --
    -- jtgng_objdraw addresses sprite data as:
    --
    --     ID | ROW | HALF | SUBGROUP
    --
    -- Reorder the word-address bits while loading the OBJ BRAM so that its
    -- runtime address directly matches the { ID, row, group } address generated
    -- by jtgng_objdraw.
    --
    -- dn_addr_i is a byte address, so first remove C_OBJ_START and divide by 2
    -- to obtain the 16-bit source word address.
    --
    -- Source:       [13:6] ID, [5] HALF, [4:1] ROW, [0] SUBGROUP
    -- Destination:  [13:6] ID, [5:2] ROW, [1] HALF, [0] SUBGROUP
    -- -------------------------------------------------------------------------    
    process(all)
       variable src : unsigned(13 downto 0);
    begin
       -- dn_addr_i is a BYTE address.
       --
       -- Remove OBJ_START and divide by two because the packed OBJ image
       -- contains two bytes per 16-bit word.
       src := resize(
          (unsigned(dn_addr_i) - C_OBJ_START) srl 1,
          src'length
       );
    
       -- MAME physical layout:
       --   src[13:6] = sprite ID
       --   src[5]    = left/right half
       --   src[4:1]  = row
       --   src[0]    = 4-pixel subgroup
       --
       -- jtgng_objdraw layout:
       --   dst[13:6] = sprite ID
       --   dst[5:2]  = row
       --   dst[1]    = left/right half
       --   dst[0]    = subgroup
    
       dl_obj_word <= '0' & std_logic_vector(
           src(13 downto 6) &
           src(4 downto 1) &
           src(5) &
           src(0)
        );
    end process;
    
    -- -------------------------------------------------------------------------
    -- Scroll 1 ROM address reordering
    -- -------------------------------------------------------------------------
    -- SCR1 uses the same physical 16x16 graphics layout as the object ROM.
    -- Each SCR1 BRAM word is 32 bits and therefore contains both 4-pixel
    -- subgroups for one 8-pixel half of a tile.
    --
    -- Physical source word layout:
    --
    --     ID | HALF | ROW
    --
    -- jtexed_scr1 addresses the graphics as:
    --
    --     ID | ROW | HALF
    --
    -- dn_addr_i is a byte address. Remove C_SCR1_START and divide by four
    -- to obtain the 32-bit source word address.
    --
    -- Source:       [12:5] ID, [4] HALF, [3:0] ROW
    -- Destination:  [12:5] ID, [4:1] ROW, [0] HALF
    -- -------------------------------------------------------------------------
    process(all)
       variable src : unsigned(12 downto 0);
    begin
       src := resize(
          (unsigned(dn_addr_i) - C_SCR1_START) srl 2,
          src'length
       );
    
       dl_scr1_word <= "00" & std_logic_vector(
          src(12 downto 5) &
          src(3 downto 0) &
          src(4)
       );
    end process;
    

    -- Synchronous BRAMs return the requested word one main clock later.
    -- Hold *_ok low for the first cycle after an address change.
    process(clk_main_i)
    begin
       if rising_edge(clk_main_i) then
          main_ok <= '1' when main_addr = main_addr_d else '0';
          snd_ok  <= '1' when snd_addr  = snd_addr_d  else '0';
          map1_ok <= '1' when map1_addr = map1_addr_d else '0';
          map2_ok <= '1' when map2_addr = map2_addr_d else '0';
          char_ok <= '1' when char_addr = char_addr_d else '0';
          scr1_ok <= '1' when scr1_addr = scr1_addr_d else '0';
          scr2_ok <= '1' when scr2_addr = scr2_addr_d else '0';
          obj_ok  <= '1' when obj_addr  = obj_addr_d  else '0';

          main_addr_d <= main_addr;
          snd_addr_d  <= snd_addr;
          map1_addr_d <= map1_addr;
          map2_addr_d <= map2_addr;
          char_addr_d <= char_addr;
          scr1_addr_d <= scr1_addr;
          scr2_addr_d <= scr2_addr;
          obj_addr_d  <= obj_addr;
       end if;
    end process;

    -- SW1
    ee_dipsw_a <= not (
    osm_control_i(C_MENU_SW1_0) &
    osm_control_i(C_MENU_SW1_1) &
    osm_control_i(C_MENU_SW1_2) &
    osm_control_i(C_MENU_SW1_3) &
    osm_control_i(C_MENU_SW1_4) &
    osm_control_i(C_MENU_SW1_5) &
    osm_control_i(C_MENU_SW1_6) &
    osm_control_i(C_MENU_SW1_7));
    
    ee_dipsw_b <= not (
    osm_control_i(C_MENU_SW2_0) &
    osm_control_i(C_MENU_SW2_1) &
    osm_control_i(C_MENU_SW2_2) &
    osm_control_i(C_MENU_SW2_3) &
    osm_control_i(C_MENU_SW2_4) &
    osm_control_i(C_MENU_SW2_5) &
    osm_control_i(C_MENU_SW2_6) &
    osm_control_i(C_MENU_SW2_7));
    
    ee_dipsw <=  x"0000" & ee_dipsw_b & ee_dipsw_a;
    ee_cab_1p(0) <= keyboard_n(m65_1); -- 1P Start
    ee_cab_1p(1) <= keyboard_n(m65_2); -- 2P Start
    ee_coin(0) <= keyboard_n(m65_6);   -- Coin 1
    ee_coin(1) <= keyboard_n(m65_5);   -- Coin 2
    
    potxy1_sw   <= osm_control_i(C_MENU_SECOND_FIRE_1); -- Joy 1: 0 = POTX, 1 = POTY
    potxy2_sw   <= osm_control_i(C_MENU_SECOND_FIRE_2); -- Joy 2: 0 = POTX, 1 = POTY
    pot_pol1_sw <= osm_control_i(C_MENU_POTPOL_1);      -- Joy 1 polarity
    pot_pol2_sw <= osm_control_i(C_MENU_POTPOL_2);      -- Joy 2 polarity
    
    second_button_proc : process(all)
    begin
    
       -------------------------------------------------------------------------
       -- Select POTX/POTY independently for both joystick ports
       ------------------------------------------------------------------------
        
        -- Player 1
        if potxy1_sw = '0' then
           pot1_val <= pot1_x_i;
        else
           pot1_val <= pot1_y_i;
        end if;
        
        -- Player 2
        if potxy2_sw = '0' then
           pot2_val <= pot2_x_i;
        else
           pot2_val <= pot2_y_i;
        end if;
    
       ------------------------------------------------------------------------
       -- Player 1 second fire
       ------------------------------------------------------------------------
       if pot_pol1_sw = '1' then
    
          -- Active-low POT button
          if unsigned(pot1_val) < unsigned'(x"80") then
             shoot2_button1_n <= '0';
          else
             shoot2_button1_n <= '1';
          end if;
       else
          -- Active-high POT button
          if unsigned(pot1_val) >= unsigned'(x"80") then
             shoot2_button1_n <= '0';
          else
             shoot2_button1_n <= '1';
          end if;
       end if;
       
       -----------------------------------------------------------------------
       -- Player 2 second fire
       ------------------------------------------------------------------------
       if pot_pol2_sw = '1' then
    
          -- Active-low POT button
          if unsigned(pot2_val) < unsigned'(x"80") then
             shoot2_button2_n <= '0';
          else
             shoot2_button2_n <= '1';
          end if;
       else
          -- Active-high POT button
          if unsigned(pot2_val) >= unsigned'(x"80") then
             shoot2_button2_n <= '0';
          else
             shoot2_button2_n <= '1';
          end if;
       end if;
    end process;
    
    -- -------------------------------------------------------------------------
    -- Player 1 controls
    -- Active low
    -- -------------------------------------------------------------------------
    
    -- Player 1 joystick - active low
    joystick1(0) <= joy_1_right_n_i and keyboard_n(m65_horz_crsr);
    joystick1(1) <= joy_1_left_n_i  and keyboard_n(m65_left_crsr);
    joystick1(2) <= joy_1_down_n_i  and keyboard_n(m65_vert_crsr);
    joystick1(3) <= joy_1_up_n_i    and keyboard_n(m65_up_crsr);
    -- Button 1 = Z / joystick fire
    joystick1(4) <= joy_1_fire_n_i and keyboard_n(m65_z);
    -- Button 2 = X / second joystick button
    joystick1(5) <=  keyboard_n(m65_x) and shoot2_button1_n;
    
    -- Player 2 joystick - active low
    joystick2(0) <= joy_2_right_n_i;
    joystick2(1) <= joy_2_left_n_i;
    joystick2(2) <= joy_2_down_n_i;
    joystick2(3) <= joy_2_up_n_i;
    -- Button 1 = Z / joystick fire
    joystick2(4) <= joy_2_fire_n_i;
    -- Button 2 = X / second joystick button
    joystick2(5) <=  keyboard_n(m65_x) and shoot2_button2_n;
   
   i_jtexed_game : entity work.jtexed_game
   port map (
      -- Clock / reset
      clk         => clk_main_i,
      prog_clk    => dn_clk_i,
      rst         => reset,

      -- Cabinet inputs
      cab_1p      => ee_cab_1p,
      coin        => ee_coin,
      service     => keyboard_n(m65_9),
      joystick1   => joystick1,
      joystick2   => joystick2, -- temporary

      -- DIP switches
      dipsw       => ee_dipsw,
      dip_pause   => keyboard_n(m65_capslock),-- '1',     -- pause is active low, active high run
      dip_flip    => '1',                      -- active low flip screen

      -- Debug / layer controls
      gfx_en      => "1111",
      debug_bus   => (others => '0'),
      debug_view  => open,

      -- Pixel enables
      pxl_cen     => video_ce_o,
      pxl2_cen    => open,

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
      main_cs     => open,
      main_addr   => main_addr,
      main_data   => main_data,
      main_ok     => main_ok,

      -- Sound CPU ROM
      snd_cs      => open,
      snd_addr    => snd_addr,
      snd_data    => snd_data,
      snd_ok      => snd_ok,

      -- MAP 1 ROM
      map1_cs     => open,
      map1_addr   => map1_addr,
      map1_data   => map1_data,
      map1_ok     => map1_ok,

      -- MAP 2 ROM
      map2_cs     => open,
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
   
   -- Jotego audio path.
   -- Use the audio mixer
   i_audio_mixer : entity work.jtframe_mixer
   generic map (
      W0   => 11,
      W1   => 11,
      W2   => 11,
      W3   => 16,
      WOUT => 16
   )
   port map (
      rst   => reset,
      clk   => clk_main_i,
      cen   => '1',

      ch0   => signed(psg0),
      ch1   => signed(psg1),
      ch2   => signed(psg2),
      ch3   => to_signed(0, 16),

      gain0 => x"10",
      gain1 => x"10",
      gain2 => x"10",
      gain3 => x"00",

      mixed => audio_mixed,
      peak  => open
   );
   
    audio_left_o  <= audio_mixed;
    audio_right_o <= audio_mixed;


   -- ----------------------------------------------------------------------
   -- Exed Exes ROM BRAMs. Port A = 48 MHz core read, Port B = QNICE write.
   -- Wide JTFRAME buses are assembled from byte lanes.
   -- ----------------------------------------------------------------------
    

   i_rom_main : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 17, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map 
      (clock_a => clk_main_i, 
      address_a => main_addr, 
      data_a => (others=>'0'), 
      wren_a => '0', 
      q_a => main_data,

      clock_b => dn_clk_i, 
      address_b => dl_main_off(16 downto 0), 
      data_b => dn_data_i, 
      wren_b => main_we, 
      q_b => open);


   i_rom_snd : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map 
      (clock_a => clk_main_i, 
      address_a => snd_addr, 
      data_a => (others=>'0'), 
      wren_a => '0', 
      q_a => snd_data,

      clock_b => dn_clk_i,
      address_b => dl_snd_off(14 downto 0), 
      data_b => dn_data_i, 
      wren_b => snd_we, 
      q_b => open);


   i_rom_map1 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 14, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map 
      (clock_a => clk_main_i, 
      address_a => map1_addr, 
      data_a => (others=>'0'), 
      wren_a => '0', 
      q_a => map1_data,

      clock_b => dn_clk_i, 
      address_b => dl_map1_off(13 downto 0), 
      data_b => dn_data_i, 
      wren_b => map1_we, 
      q_b => open);


   i_rom_map2_0 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 13, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => map2_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => map2_q0,

      clock_b => dn_clk_i,
      address_b => dl_map2_off(13 downto 1),
      data_b => dn_data_i,
      wren_b => map2_we0,
      q_b => open
      );

   i_rom_map2_1 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 13, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => map2_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => map2_q1,

      clock_b => dn_clk_i,
      address_b => dl_map2_off(13 downto 1),
      data_b => dn_data_i,
      wren_b => map2_we1,
      q_b => open
      );


   i_rom_char_0 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 14, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => char_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => char_q0,

      clock_b => dn_clk_i,
      address_b => dl_char_off(14 downto 1),
      data_b => dn_data_i,
      wren_b => char_we0,
      q_b => open
      );

   i_rom_char_1 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 14, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => char_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => char_q1,

      clock_b => dn_clk_i,
      address_b => dl_char_off(14 downto 1),
      data_b => dn_data_i,
      wren_b => char_we1,
      q_b => open
      );


   i_rom_scr1_0 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => scr1_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => scr1_q0,

      clock_b => dn_clk_i,
      address_b => dl_scr1_word,
      data_b => dn_data_i,
      wren_b => scr1_we0,
      q_b => open
      );

   i_rom_scr1_1 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => scr1_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => scr1_q1,

      clock_b => dn_clk_i,
      address_b => dl_scr1_word,
      data_b => dn_data_i,
      wren_b => scr1_we1,
      q_b => open
      );

   i_rom_scr1_2 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => scr1_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => scr1_q2,

      clock_b => dn_clk_i,
      address_b => dl_scr1_word,
      data_b => dn_data_i,
      wren_b => scr1_we2,
      q_b => open
      );

   i_rom_scr1_3 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => scr1_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => scr1_q3,

      clock_b => dn_clk_i,
      address_b => dl_scr1_word,
      data_b => dn_data_i,
      wren_b => scr1_we3,
      q_b => open
      );


   i_rom_scr2_0 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 14, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => scr2_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => scr2_q0,

      clock_b => dn_clk_i,
      address_b => dl_scr2_off(15 downto 2),
      data_b => dn_data_i,
      wren_b => scr2_we0,
      q_b => open
      );

   i_rom_scr2_1 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 14, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => scr2_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => scr2_q1,

      clock_b => dn_clk_i,
      address_b => dl_scr2_off(15 downto 2),
      data_b => dn_data_i,
      wren_b => scr2_we1,
      q_b => open
      );

   i_rom_scr2_2 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 14, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => scr2_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => scr2_q2,

      clock_b => dn_clk_i,
      address_b => dl_scr2_off(15 downto 2),
      data_b => dn_data_i,
      wren_b => scr2_we2,
      q_b => open
      );

   i_rom_scr2_3 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 14, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => scr2_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => scr2_q3,

      clock_b => dn_clk_i,
      address_b => dl_scr2_off(15 downto 2),
      data_b => dn_data_i,
      wren_b => scr2_we3,
      q_b => open
      );


   -- OBJ graphics are pre-arranged during download so the runtime obj_addr
   -- from jtgng_objdraw can be connected directly to the BRAM read ports.
   i_rom_obj_0 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => obj_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => obj_q0,

      clock_b => dn_clk_i,
      address_b => dl_obj_word,
      data_b => dn_data_i,
      wren_b => obj_we0,
      q_b => open
      );

   i_rom_obj_1 : entity work.dualport_2clk_ram
      generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, FALLING_A => false, FALLING_B => true)
      port map
      (clock_a => clk_main_i,
      address_a => obj_addr,
      data_a => (others=>'0'),
      wren_a => '0',
      q_a => obj_q1,

      clock_b => dn_clk_i,
      address_b => dl_obj_word,
      data_b => dn_data_i,
      wren_b => obj_we1,
      q_b => open
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

