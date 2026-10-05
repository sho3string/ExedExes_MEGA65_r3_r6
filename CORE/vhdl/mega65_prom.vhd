library ieee;
use ieee.std_logic_1164.all;

entity mega65_prom is
   generic (
      AW : positive := 8;
      DW : positive := 4
   );
   port (
      -- Runtime/core read side
      clk     : in  std_logic;
      cen     : in  std_logic;
      rd_addr : in  std_logic_vector(AW-1 downto 0);
      q       : out std_logic_vector(DW-1 downto 0);

      -- QNICE/download write side
      prog_clk : in  std_logic;
      data     : in  std_logic_vector(DW-1 downto 0);
      wr_addr  : in  std_logic_vector(AW-1 downto 0);
      we       : in  std_logic
   );
end entity;

architecture synthesis of mega65_prom is

   signal ram_q : std_logic_vector(DW-1 downto 0);

begin

   i_ram : entity work.dualport_2clk_ram
      generic map (
         ADDR_WIDTH => AW,
         DATA_WIDTH => DW,
         FALLING_A  => false,
         FALLING_B  => true
      )
      port map (
         -- Core/runtime side
         clock_a   => clk,
         clen_a    => cen,
         address_a => rd_addr,
         data_a    => (others => '0'),
         wren_a    => '0',
         q_a       => ram_q,

         -- QNICE/download side
         clock_b   => prog_clk,
         clen_b    => '1',
         address_b => wr_addr,
         data_b    => data,
         wren_b    => we,
         q_b       => open
      );

   q <= ram_q;

end architecture;