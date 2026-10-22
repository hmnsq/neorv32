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
    ಟ್ಯಾಗ್_ಅಗಲ : natural; -- tag width
    IDX_ಅಗಲ : natural; -- index width
    OFS_ಅಗಲ : natural  -- offset width
  );
  port (
    -- global control --
    clk_i     : in  std_ulogic;                     -- global clock, rising edge
    addr_i    : in  std_ulogic_ಸದಿಶ(31 downto 0); -- full byte address
    -- tag memory --
    ಟ್ಯಾಗ್_we_i  : in  std_ulogic;                     -- tag write-enable
    ಟ್ಯಾಗ್_o     : out std_ulogic_ಸದಿಶ(31 downto 0); -- zero-extended tag output
    -- data memory --
    ದತ್ತಾಂಶ_we_i : in  std_ulogic_ಸದಿಶ(3 downto 0);  -- byte-wise data write-enable
    ದತ್ತಾಂಶ_i    : in  std_ulogic_ಸದಿಶ(31 downto 0); -- write data
    ದತ್ತಾಂಶ_o    : out std_ulogic_ಸದಿಶ(31 downto 0)  -- read data
  );
end entity;

architecture neorv32_cache_ram_rtl of neorv32_cache_ram is

  signal ಟ್ಯಾಗ್_rd : std_ulogic_ಸದಿಶ(ಟ್ಯಾಗ್_ಅಗಲ-1 downto 0);

begin

  -- Tag RAM --------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ಟ್ಯಾಗ್_ram_inst: entity neorv32.neorv32_prim_spram
  generic map (
    AWIDTH => IDX_ಅಗಲ,
    DWIDTH => ಟ್ಯಾಗ್_ಅಗಲ,
    OUTREG => false
  )
  port map (
    clk_i  => clk_i,
    en_i   => '1',
    rw_i   => ಟ್ಯಾಗ್_we_i,
    addr_i => addr_i(31-ಟ್ಯಾಗ್_ಅಗಲ downto 2+OFS_ಅಗಲ), -- index
    ದತ್ತಾಂಶ_i => addr_i(31 downto 31-(ಟ್ಯಾಗ್_ಅಗಲ-1)), -- tag
    ದತ್ತಾಂಶ_o => ಟ್ಯಾಗ್_rd
  );

  ಟ್ಯಾಗ್_o(ಟ್ಯಾಗ್_ಅಗಲ-1 downto 0) <= ಟ್ಯಾಗ್_rd(ಟ್ಯಾಗ್_ಅಗಲ-1 downto 0); -- actual tag
  ಟ್ಯಾಗ್_o(31 downto ಟ್ಯಾಗ್_ಅಗಲ)  <= (others => '0'); -- zero-extend

  -- Data RAM -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ದತ್ತಾಂಶ_ram_gen:
  for i in 0 to 3 generate -- four individual byte RAMs per word
    ದತ್ತಾಂಶ_ram_inst: entity neorv32.neorv32_prim_spram
    generic map (
      AWIDTH => IDX_ಅಗಲ + OFS_ಅಗಲ,
      DWIDTH => 8,
      OUTREG => false
    )
    port map (
      clk_i  => clk_i,
      en_i   => '1',
      rw_i   => ದತ್ತಾಂಶ_we_i(i),
      addr_i => addr_i(IDX_ಅಗಲ+OFS_ಅಗಲ+1 downto 2), -- index & word-offset
      ದತ್ತಾಂಶ_i => ದತ್ತಾಂಶ_i(i*8+7 downto i*8),
      ದತ್ತಾಂಶ_o => ದತ್ತಾಂಶ_o(i*8+7 downto i*8)
    );
  end generate;

end architecture;
