-------------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Clock Generator using the Xilinx specific MMCME2_ADV:
--
--   @TODO YOURCORE expects 54 MHz
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
-------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;


entity clk is
   port (
      sys_clk_i       : in  std_logic;   -- 100 MHz

      main_clk_o      : out std_logic;   -- 48 MHz JTFRAME master clock
      main_rst_o      : out std_logic
   );
end entity clk;

architecture rtl of clk is

signal clkfb1             : std_logic;
signal clkfb1_mmcm        : std_logic;
signal clkfb2             : std_logic;
signal clkfb2_mmcm        : std_logic;
signal clkfb3             : std_logic;
signal clkfb3_mmcm        : std_logic;
signal main_clk_mmcm      : std_logic;

signal main_locked        : std_logic;

begin

   -------------------------------------------------------------------------------------
   -- Generate QNICE and HyperRAM clock
   -------------------------------------------------------------------------------------

   -- Black Tiger / JTFRAME expects 48 MHz
    i_clk_main : MMCME2_ADV
    generic map (
       BANDWIDTH            => "OPTIMIZED",
       CLKOUT4_CASCADE      => FALSE,
       COMPENSATION         => "ZHOLD",
       STARTUP_WAIT         => FALSE,
    
       CLKIN1_PERIOD        => 10.0,       -- 100 MHz
       REF_JITTER1          => 0.010,
    
       DIVCLK_DIVIDE        => 1,
       CLKFBOUT_MULT_F      => 6.000,      -- VCO = 600 MHz
       CLKFBOUT_PHASE       => 0.000,
       CLKFBOUT_USE_FINE_PS => FALSE,
    
       -- Exed Exes / JTFRAME master clock
       CLKOUT0_DIVIDE_F     => 12.500,     -- 600 / 12.5 = 48 MHz
       CLKOUT0_PHASE        => 0.000,
       CLKOUT0_DUTY_CYCLE   => 0.500,
       CLKOUT0_USE_FINE_PS  => FALSE
    )
    port map (
       CLKFBOUT      => clkfb3_mmcm,
       CLKOUT0       => main_clk_mmcm,
    
       CLKFBIN       => clkfb3,
       CLKIN1        => sys_clk_i,
       CLKIN2        => '0',
       CLKINSEL      => '1',
    
       DADDR         => (others => '0'),
       DCLK          => '0',
       DEN           => '0',
       DI            => (others => '0'),
       DO            => open,
       DRDY          => open,
       DWE           => '0',
    
       PSCLK         => '0',
       PSEN          => '0',
       PSINCDEC      => '0',
       PSDONE        => open,
    
       LOCKED        => main_locked,
       CLKINSTOPPED  => open,
       CLKFBSTOPPED  => open,
       PWRDWN        => '0',
       RST           => '0'
    );

    -------------------------------------------------------------------------------------
    -- Output buffering
    -------------------------------------------------------------------------------------
    
    clkfb3_bufg : BUFG
       port map (
          I => clkfb3_mmcm,
          O => clkfb3
       );
    
    -- 48 MHz JTFRAME / Black Tiger master clock
    main_clk_bufg : BUFG
       port map (
          I => main_clk_mmcm,
          O => main_clk_o
       );
    
    -------------------------------------------------------------------------------------
    -- Reset generation
    -------------------------------------------------------------------------------------
    
    -- 48 MHz domain
    i_xpm_cdc_async_rst_main : xpm_cdc_async_rst
    generic map (
      RST_ACTIVE_HIGH => 1,
      DEST_SYNC_FF    => 6
    )
    port map (
      src_arst  => not main_locked,
      dest_clk  => main_clk_o,
      dest_arst => main_rst_o
    );
    
   
    
end architecture rtl;