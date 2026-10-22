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
    ਟੈਗ_ਚੌੜਾਈ : natural; -- tag width
    IDX_ਚੌੜਾਈ : natural; -- index width
    OFS_ਚੌੜਾਈ : natural  -- offset width
  );
  port (
    -- global control --
    clk_i     : in  std_ulogic;                     -- global clock, rising edge
    addr_i    : in  std_ulogic_ਸਦਿਸ਼(31 downto 0); -- full byte address
    -- tag memory --
    ਟੈਗ_we_i  : in  std_ulogic;                     -- tag write-enable
    ਟੈਗ_o     : out std_ulogic_ਸਦਿਸ਼(31 downto 0); -- zero-extended tag output
    -- data memory --
    ਅੰਕੜੇ_we_i : in  std_ulogic_ਸਦਿਸ਼(3 downto 0);  -- byte-wise data write-enable
    ਅੰਕੜੇ_i    : in  std_ulogic_ਸਦਿਸ਼(31 downto 0); -- write data
    ਅੰਕੜੇ_o    : out std_ulogic_ਸਦਿਸ਼(31 downto 0)  -- read data
  );
end entity;

architecture neorv32_cache_ram_rtl of neorv32_cache_ram is

  signal ਟੈਗ_rd : std_ulogic_ਸਦਿਸ਼(ਟੈਗ_ਚੌੜਾਈ-1 downto 0);

begin

  -- Tag RAM --------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ਟੈਗ_ram_inst: entity neorv32.neorv32_prim_spram
  generic map (
    AWIDTH => IDX_ਚੌੜਾਈ,
    DWIDTH => ਟੈਗ_ਚੌੜਾਈ,
    OUTREG => false
  )
  port map (
    clk_i  => clk_i,
    en_i   => '1',
    rw_i   => ਟੈਗ_we_i,
    addr_i => addr_i(31-ਟੈਗ_ਚੌੜਾਈ downto 2+OFS_ਚੌੜਾਈ), -- index
    ਅੰਕੜੇ_i => addr_i(31 downto 31-(ਟੈਗ_ਚੌੜਾਈ-1)), -- tag
    ਅੰਕੜੇ_o => ਟੈਗ_rd
  );

  ਟੈਗ_o(ਟੈਗ_ਚੌੜਾਈ-1 downto 0) <= ਟੈਗ_rd(ਟੈਗ_ਚੌੜਾਈ-1 downto 0); -- actual tag
  ਟੈਗ_o(31 downto ਟੈਗ_ਚੌੜਾਈ)  <= (others => '0'); -- zero-extend

  -- Data RAM -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ਅੰਕੜੇ_ram_gen:
  for i in 0 to 3 generate -- four individual byte RAMs per word
    ਅੰਕੜੇ_ram_inst: entity neorv32.neorv32_prim_spram
    generic map (
      AWIDTH => IDX_ਚੌੜਾਈ + OFS_ਚੌੜਾਈ,
      DWIDTH => 8,
      OUTREG => false
    )
    port map (
      clk_i  => clk_i,
      en_i   => '1',
      rw_i   => ਅੰਕੜੇ_we_i(i),
      addr_i => addr_i(IDX_ਚੌੜਾਈ+OFS_ਚੌੜਾਈ+1 downto 2), -- index & word-offset
      ਅੰਕੜੇ_i => ਅੰਕੜੇ_i(i*8+7 downto i*8),
      ਅੰਕੜੇ_o => ਅੰਕੜੇ_o(i*8+7 downto i*8)
    );
  end generate;

end architecture;
