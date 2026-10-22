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
    चिह्नकम्_विस्तारः : natural; -- tag width
    IDX_विस्तारः : natural; -- index width
    OFS_विस्तारः : natural  -- offset width
  );
  port (
    -- global control --
    clk_i     : in  std_ulogic;                     -- global clock, rising edge
    addr_i    : in  std_ulogic_सदिशम्(31 downto 0); -- full byte address
    -- tag memory --
    चिह्नकम्_we_i  : in  std_ulogic;                     -- tag write-enable
    चिह्नकम्_o     : out std_ulogic_सदिशम्(31 downto 0); -- zero-extended tag output
    -- data memory --
    दत्त_we_i : in  std_ulogic_सदिशम्(3 downto 0);  -- byte-wise data write-enable
    दत्त_i    : in  std_ulogic_सदिशम्(31 downto 0); -- write data
    दत्त_o    : out std_ulogic_सदिशम्(31 downto 0)  -- read data
  );
end entity;

architecture neorv32_cache_ram_rtl of neorv32_cache_ram is

  signal चिह्नकम्_rd : std_ulogic_सदिशम्(चिह्नकम्_विस्तारः-1 downto 0);

begin

  -- Tag RAM --------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  चिह्नकम्_ram_inst: entity neorv32.neorv32_prim_spram
  generic map (
    AWIDTH => IDX_विस्तारः,
    DWIDTH => चिह्नकम्_विस्तारः,
    OUTREG => false
  )
  port map (
    clk_i  => clk_i,
    en_i   => '1',
    rw_i   => चिह्नकम्_we_i,
    addr_i => addr_i(31-चिह्नकम्_विस्तारः downto 2+OFS_विस्तारः), -- index
    दत्त_i => addr_i(31 downto 31-(चिह्नकम्_विस्तारः-1)), -- tag
    दत्त_o => चिह्नकम्_rd
  );

  चिह्नकम्_o(चिह्नकम्_विस्तारः-1 downto 0) <= चिह्नकम्_rd(चिह्नकम्_विस्तारः-1 downto 0); -- actual tag
  चिह्नकम्_o(31 downto चिह्नकम्_विस्तारः)  <= (others => '0'); -- zero-extend

  -- Data RAM -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  दत्त_ram_gen:
  for i in 0 to 3 generate -- four individual byte RAMs per word
    दत्त_ram_inst: entity neorv32.neorv32_prim_spram
    generic map (
      AWIDTH => IDX_विस्तारः + OFS_विस्तारः,
      DWIDTH => 8,
      OUTREG => false
    )
    port map (
      clk_i  => clk_i,
      en_i   => '1',
      rw_i   => दत्त_we_i(i),
      addr_i => addr_i(IDX_विस्तारः+OFS_विस्तारः+1 downto 2), -- index & word-offset
      दत्त_i => दत्त_i(i*8+7 downto i*8),
      दत्त_o => दत्त_o(i*8+7 downto i*8)
    );
  end generate;

end architecture;
