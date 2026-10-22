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
    ٹیگ_چوڑائی : natural; -- tag width
    IDX_چوڑائی : natural; -- index width
    OFS_چوڑائی : natural  -- offset width
  );
  port (
    -- global control --
    clk_i     : in  std_ulogic;                     -- global clock, rising edge
    addr_i    : in  std_ulogic_سمتیہ(31 downto 0); -- full byte address
    -- tag memory --
    ٹیگ_we_i  : in  std_ulogic;                     -- tag write-enable
    ٹیگ_o     : out std_ulogic_سمتیہ(31 downto 0); -- zero-extended tag output
    -- data memory --
    انکڑے_we_i : in  std_ulogic_سمتیہ(3 downto 0);  -- byte-wise data write-enable
    انکڑے_i    : in  std_ulogic_سمتیہ(31 downto 0); -- write data
    انکڑے_o    : out std_ulogic_سمتیہ(31 downto 0)  -- read data
  );
end entity;

architecture neorv32_cache_ram_rtl of neorv32_cache_ram is

  signal ٹیگ_rd : std_ulogic_سمتیہ(ٹیگ_چوڑائی-1 downto 0);

begin

  -- Tag RAM --------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ٹیگ_ram_inst: entity neorv32.neorv32_prim_spram
  generic map (
    AWIDTH => IDX_چوڑائی,
    DWIDTH => ٹیگ_چوڑائی,
    OUTREG => false
  )
  port map (
    clk_i  => clk_i,
    en_i   => '1',
    rw_i   => ٹیگ_we_i,
    addr_i => addr_i(31-ٹیگ_چوڑائی downto 2+OFS_چوڑائی), -- index
    انکڑے_i => addr_i(31 downto 31-(ٹیگ_چوڑائی-1)), -- tag
    انکڑے_o => ٹیگ_rd
  );

  ٹیگ_o(ٹیگ_چوڑائی-1 downto 0) <= ٹیگ_rd(ٹیگ_چوڑائی-1 downto 0); -- actual tag
  ٹیگ_o(31 downto ٹیگ_چوڑائی)  <= (others => '0'); -- zero-extend

  -- Data RAM -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  انکڑے_ram_gen:
  for i in 0 to 3 generate -- four individual byte RAMs per word
    انکڑے_ram_inst: entity neorv32.neorv32_prim_spram
    generic map (
      AWIDTH => IDX_چوڑائی + OFS_چوڑائی,
      DWIDTH => 8,
      OUTREG => false
    )
    port map (
      clk_i  => clk_i,
      en_i   => '1',
      rw_i   => انکڑے_we_i(i),
      addr_i => addr_i(IDX_چوڑائی+OFS_چوڑائی+1 downto 2), -- index & word-offset
      انکڑے_i => انکڑے_i(i*8+7 downto i*8),
      انکڑے_o => انکڑے_o(i*8+7 downto i*8)
    );
  end generate;

end architecture;
