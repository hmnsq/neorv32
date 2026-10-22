-- ================================================================================ --
-- NEORV32 SoC - Generic Cache - Tag and Data RAM Primitive Wrapper                 --
-- -------------------------------------------------------------------------------- --
-- Replace this file by a more efficient technology-specific IP wrapper. The read-  --
-- during-write behavior is irrelevant as read/write accesses are mutual exclusive. --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) Stephan Nolting. All rights reserved.                              --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_cache_ram is
  generic (
    ٽيگ_ويڪر : natural; -- tag width
    IDX_ويڪر : natural; -- index width
    OFS_ويڪر : natural  -- offset width
  );
  port (
    -- global control --
    clk_i     : in  std_ulogic;                     -- global clock, rising edge
    addr_i    : in  std_ulogic_ويڪٽر(31 downto 0); -- full byte address
    -- tag memory --
    ٽيگ_we_i  : in  std_ulogic;                     -- tag write-enable
    ٽيگ_o     : out std_ulogic_ويڪٽر(31 downto 0); -- zero-extended tag output
    -- data memory --
    معلومات_we_i : in  std_ulogic_ويڪٽر(3 downto 0);  -- byte-wise data write-enable
    معلومات_i    : in  std_ulogic_ويڪٽر(31 downto 0); -- write data
    معلومات_o    : out std_ulogic_ويڪٽر(31 downto 0)  -- read data
  );
end entity;

architecture neorv32_cache_ram_rtl of neorv32_cache_ram is

  signal ٽيگ_rd : std_ulogic_ويڪٽر(ٽيگ_ويڪر-1 downto 0);

begin

  -- Tag RAM --------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ٽيگ_ram_inst: entity neorv32.neorv32_prim_spram
  generic map (
    AWIDTH => IDX_ويڪر,
    DWIDTH => ٽيگ_ويڪر,
    OUTREG => false
  )
  port map (
    clk_i  => clk_i,
    en_i   => '1',
    rw_i   => ٽيگ_we_i,
    addr_i => addr_i(31-ٽيگ_ويڪر downto 2+OFS_ويڪر), -- index
    معلومات_i => addr_i(31 downto 31-(ٽيگ_ويڪر-1)), -- tag
    معلومات_o => ٽيگ_rd
  );

  ٽيگ_o(ٽيگ_ويڪر-1 downto 0) <= ٽيگ_rd(ٽيگ_ويڪر-1 downto 0); -- actual tag
  ٽيگ_o(31 downto ٽيگ_ويڪر)  <= (others => '0'); -- zero-extend

  -- Data RAM -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  معلومات_ram_gen:
  for i in 0 to 3 generate -- four individual byte RAMs per word
    معلومات_ram_inst: entity neorv32.neorv32_prim_spram
    generic map (
      AWIDTH => IDX_ويڪر + OFS_ويڪر,
      DWIDTH => 8,
      OUTREG => false
    )
    port map (
      clk_i  => clk_i,
      en_i   => '1',
      rw_i   => معلومات_we_i(i),
      addr_i => addr_i(IDX_ويڪر+OFS_ويڪر+1 downto 2), -- index & word-offset
      معلومات_i => معلومات_i(i*8+7 downto i*8),
      معلومات_o => معلومات_o(i*8+7 downto i*8)
    );
  end generate;

end architecture;
