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
    ట్యాగ్_వెడల్పు : natural; -- tag width
    IDX_వెడల్పు : natural; -- index width
    OFS_వెడల్పు : natural  -- offset width
  );
  port (
    -- global control --
    clk_i     : in  std_ulogic;                     -- global clock, rising edge
    addr_i    : in  std_ulogic_సదిశ(31 downto 0); -- full byte address
    -- tag memory --
    ట్యాగ్_we_i  : in  std_ulogic;                     -- tag write-enable
    ట్యాగ్_o     : out std_ulogic_సదిశ(31 downto 0); -- zero-extended tag output
    -- data memory --
    దత్తాంశం_we_i : in  std_ulogic_సదిశ(3 downto 0);  -- byte-wise data write-enable
    దత్తాంశం_i    : in  std_ulogic_సదిశ(31 downto 0); -- write data
    దత్తాంశం_o    : out std_ulogic_సదిశ(31 downto 0)  -- read data
  );
end entity;

architecture neorv32_cache_ram_rtl of neorv32_cache_ram is

  signal ట్యాగ్_rd : std_ulogic_సదిశ(ట్యాగ్_వెడల్పు-1 downto 0);

begin

  -- Tag RAM --------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ట్యాగ్_ram_inst: entity neorv32.neorv32_prim_spram
  generic map (
    AWIDTH => IDX_వెడల్పు,
    DWIDTH => ట్యాగ్_వెడల్పు,
    OUTREG => false
  )
  port map (
    clk_i  => clk_i,
    en_i   => '1',
    rw_i   => ట్యాగ్_we_i,
    addr_i => addr_i(31-ట్యాగ్_వెడల్పు downto 2+OFS_వెడల్పు), -- index
    దత్తాంశం_i => addr_i(31 downto 31-(ట్యాగ్_వెడల్పు-1)), -- tag
    దత్తాంశం_o => ట్యాగ్_rd
  );

  ట్యాగ్_o(ట్యాగ్_వెడల్పు-1 downto 0) <= ట్యాగ్_rd(ట్యాగ్_వెడల్పు-1 downto 0); -- actual tag
  ట్యాగ్_o(31 downto ట్యాగ్_వెడల్పు)  <= (others => '0'); -- zero-extend

  -- Data RAM -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  దత్తాంశం_ram_gen:
  for i in 0 to 3 generate -- four individual byte RAMs per word
    దత్తాంశం_ram_inst: entity neorv32.neorv32_prim_spram
    generic map (
      AWIDTH => IDX_వెడల్పు + OFS_వెడల్పు,
      DWIDTH => 8,
      OUTREG => false
    )
    port map (
      clk_i  => clk_i,
      en_i   => '1',
      rw_i   => దత్తాంశం_we_i(i),
      addr_i => addr_i(IDX_వెడల్పు+OFS_వెడల్పు+1 downto 2), -- index & word-offset
      దత్తాంశం_i => దత్తాంశం_i(i*8+7 downto i*8),
      దత్తాంశం_o => దత్తాంశం_o(i*8+7 downto i*8)
    );
  end generate;

end architecture;
