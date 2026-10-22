-- ================================================================================ --
-- NEORV32 Primitives - Generic Single-Clock FIFO (FIFO)                            --
-- -------------------------------------------------------------------------------- --
-- The FIFO operates in "first-word-fall-through" (FWFT) mode: the first written    --
-- word appears directly at the output (after the optional synchronous-read delay)  --
-- without any explicit read access.                                                --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) Stephan Nolting. All rights reserved.                              --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_prim_fifo is
  generic (
    AWIDTH  : natural; -- address width (= log2(number of FIFO entries))
    DWIDTH  : natural; -- size of data elements in FIFO
    OUTGATE : boolean; -- true = output zero if no data available
    ASYNCRD : boolean  -- true = asynchronous read, false = synchronous read
  );
  port (
    -- global control --
    clk_i   : in  std_ulogic;                           -- clock, rising edge
    rstn_i  : in  std_ulogic;                           -- async reset, low-active
    clear_i : in  std_ulogic;                           -- sync reset, high-active
    level_o : out std_ulogic_సదిశ(AWIDTH downto 0);   -- fill level
    -- write port --
    wdata_i : in  std_ulogic_సదిశ(DWIDTH-1 downto 0); -- write data
    we_i    : in  std_ulogic;                           -- write enable
    free_o  : out std_ulogic;                           -- at least one entry is free when set
    -- read port --
    re_i    : in  std_ulogic;                           -- read enable
    rdata_o : out std_ulogic_సదిశ(DWIDTH-1 downto 0); -- read data
    avail_o : out std_ulogic                            -- data available when set
  );
end entity;

architecture neorv32_prim_fifo_rtl of neorv32_prim_fifo is

  -- memory core; the actual RAM signal is declared per generate-branch as a shared
  -- architecture-scope signal would defeat RAM extraction on some synthesis tools --
  type ram_t is array ((2**AWIDTH)-1 downto 0) of std_ulogic_సదిశ(DWIDTH-1 downto 0);

  -- local signals --
  signal rdata : std_ulogic_సదిశ(DWIDTH-1 downto 0);
  signal we, re, సరిపోలిక, నిండిన, ఖాళీలు, avail : std_ulogic;
  signal w_pnt, w_nxt, r_pnt, r_nxt : std_ulogic_సదిశ(AWIDTH downto 0);

begin

  -- Pointers -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  సూచిక_reg: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      w_pnt <= (others => '0');
      r_pnt <= (others => '0');
    elsif rising_అంచు(clk_i) then
      w_pnt <= w_nxt;
      r_pnt <= r_nxt;
    end if;
  end process;

  -- access control --
  re <= re_i and (not ఖాళీలు); -- read only if data available
  we <= we_i and (not నిండిన);  -- write only if free space available

  -- pointer update --
  w_nxt <= (others => '0') when (clear_i = '1') else std_ulogic_సదిశ(unsigned(w_pnt) + 1) when (we = '1') else w_pnt;
  r_nxt <= (others => '0') when (clear_i = '1') else std_ulogic_సదిశ(unsigned(r_pnt) + 1) when (re = '1') else r_pnt;

  -- fill level --
  level_o <= std_ulogic_సదిశ(unsigned(w_pnt) - unsigned(r_pnt));

  -- Status ---------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- more than 1 FIFO entry --
  స్థితి_large:
  if (AWIDTH > 0) generate
    సరిపోలిక <= '1' when (r_pnt(AWIDTH-1 downto 0) = w_pnt(AWIDTH-1 downto 0)) else '0';
    నిండిన  <= '1' when (r_pnt(AWIDTH) /= w_pnt(AWIDTH)) and (సరిపోలిక = '1') else '0';
    ఖాళీలు <= '1' when (r_pnt(AWIDTH)  = w_pnt(AWIDTH)) and (సరిపోలిక = '1') else '0';

    -- synchronous read: "avail" is synchronized to the read port --
    స్థితి_large_sync_read:
    if not ASYNCRD generate
      avail_reg: process(clk_i)
      begin
        if rising_అంచు(clk_i) then
          avail <= (not ఖాళీలు) and (not clear_i);
        end if;
      end process;
    end generate;

    -- asynchronous read --
    స్థితి_large_async_read:
    if ASYNCRD generate
      avail <= not ఖాళీలు;
    end generate;

  end generate;

  -- just 1 FIFO entry --
  స్థితి_small:
  if (AWIDTH = 0) generate
    సరిపోలిక <= '1' when (r_pnt(0) = w_pnt(0)) else '0';
    నిండిన  <= not సరిపోలిక;
    ఖాళీలు <= not నిండిన;
    avail <= not ఖాళీలు;
  end generate;

  -- status output --
  free_o  <= not నిండిన;
  avail_o <= avail;


  -- Memory ---------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- more than 1 FIFO entry --
  జ్ఞాపకం_large:
  if (AWIDTH > 0) generate

    -- memory with synchronous read --
    జ్ఞాపకం_large_sync_read:
    if not ASYNCRD generate
      signal fifo : ram_t;
    begin
      జ్ఞాపకం_core: process(clk_i) -- simple dual-port RAM
      begin
        if rising_అంచు(clk_i) then
          if (we = '1') then
            fifo(గమ్యం_integer(unsigned(w_pnt(AWIDTH-1 downto 0)))) <= wdata_i;
          end if;
          rdata <= fifo(గమ్యం_integer(unsigned(r_pnt(AWIDTH-1 downto 0))));
        end if;
      end process;
    end generate;

    -- memory with asynchronous read --
    జ్ఞాపకం_large_async_read:
    if ASYNCRD generate
      signal fifo : ram_t;
    begin
      జ్ఞాపకం_core: process(clk_i) -- simple dual-port RAM
      begin
        if rising_అంచు(clk_i) then
          if (we = '1') then
            fifo(గమ్యం_integer(unsigned(w_pnt(AWIDTH-1 downto 0)))) <= wdata_i;
          end if;
        end if;
      end process;
      rdata <= fifo(గమ్యం_integer(unsigned(r_pnt(AWIDTH-1 downto 0))));
    end generate;

  end generate;

  -- just 1 FIFO entry --
  జ్ఞాపకం_small:
  if (AWIDTH = 0) generate
    signal fifo : ram_t;
  begin
    జ్ఞాపకం_core: process(clk_i) -- single register
    begin
      if rising_అంచు(clk_i) then
        if (we = '1') then
          fifo(0) <= wdata_i;
        end if;
      end if;
    end process;
    rdata <= fifo(0);
  end generate;

  -- output gate: output zero if no data available --
  rdata_o <= (others => '0') when OUTGATE and (avail = '0') else rdata;

end architecture;


-- ================================================================================ --
-- NEORV32 Primitives - Generic Single-Port RAM (SPRAM)                             --
-- -------------------------------------------------------------------------------- --
-- Provides a single read/write port. Read-during-write behavior is irrelevant as   --
-- read and write accesses are guaranteed to be mutually exclusive.                 --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) Stephan Nolting. All rights reserved.                              --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_prim_spram is
  generic (
    AWIDTH : natural; -- address width (number of bits)
    DWIDTH : natural; -- data width (number of bits)
    OUTREG : boolean  -- add output register stage when true
  );
  port (
    -- global control --
    clk_i  : in  std_ulogic;                           -- clock, rising edge
    -- read/write port --
    en_i   : in  std_ulogic;                           -- access enable
    rw_i   : in  std_ulogic;                           -- 0=read, 1=write
    addr_i : in  std_ulogic_సదిశ(AWIDTH-1 downto 0); -- address
    దత్తాంశం_i : in  std_ulogic_సదిశ(DWIDTH-1 downto 0); -- write data
    దత్తాంశం_o : out std_ulogic_సదిశ(DWIDTH-1 downto 0)  -- read data
  );
end entity;

architecture neorv32_prim_spram_rtl of neorv32_prim_spram is

  -- memory core; the actual RAM signal is declared per generate-branch as a shared
  -- architecture-scope signal would defeat RAM extraction on some synthesis tools --
  type ram_t is array ((2**AWIDTH)-1 downto 0) of std_ulogic_సదిశ(DWIDTH-1 downto 0);
  signal rdata : std_ulogic_సదిశ(DWIDTH-1 downto 0);

begin

  -- Memory Core ----------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  జ్ఞాపకం_large:
  if (AWIDTH > 0) generate
    signal spram : ram_t;
  begin
    జ్ఞాపకం_core: process(clk_i)
    begin
      if rising_అంచు(clk_i) then
        if (en_i = '1') then
          if (rw_i = '1') then
            spram(గమ్యం_integer(unsigned(addr_i))) <= దత్తాంశం_i;
          end if;
          rdata <= spram(గమ్యం_integer(unsigned(addr_i)));
        end if;
      end if;
    end process;
  end generate;

  -- single entry only --
  జ్ఞాపకం_small:
  if (AWIDTH = 0) generate
    signal spram : ram_t;
  begin
    జ్ఞాపకం_core: process(clk_i)
    begin
      if rising_అంచు(clk_i) then
        if (en_i = '1') and (rw_i = '1') then
          spram(0) <= దత్తాంశం_i;
        end if;
      end if;
    end process;
    rdata <= spram(0);
  end generate;

  -- Output Register ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  output_రిజిస్టరు_enabled:
  if OUTREG generate -- might improve FPGA mapping and/or timing results
    read_outreg: process(clk_i)
    begin
      if rising_అంచు(clk_i) then
        దత్తాంశం_o <= rdata;
      end if;
    end process;
  end generate;

  -- no output register --
  output_రిజిస్టరు_disabled:
  if not OUTREG generate
    దత్తాంశం_o <= rdata;
  end generate;

end architecture;


-- ================================================================================ --
-- NEORV32 Primitives - Generic Signed/Unsigned Integer Multiplier (MUL)            --
-- -------------------------------------------------------------------------------- --
-- The result is valid NUM_REGS+1 cycles after en_i.                                --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) Stephan Nolting. All rights reserved.                              --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_prim_mul is
  generic (
    DWIDTH   : natural;                   -- operand width
    అంకె_REGS : natural range 1 to 3 := 1  -- number of multiplier register stages
  );
  port (
    -- global control --
    clk_i  : in  std_ulogic;                              -- clock, rising edge
    -- data path --
    en_i   : in  std_ulogic;                              -- enable input operand registers
    opa_i  : in  std_ulogic_సదిశ(DWIDTH-1 downto 0);    -- operand A
    opas_i : in  std_ulogic;                              -- operand A is a signed number
    opb_i  : in  std_ulogic_సదిశ(DWIDTH-1 downto 0);    -- operand B
    opbs_i : in  std_ulogic;                              -- operand B is a signed number
    res_o  : out std_ulogic_సదిశ((2*DWIDTH)-1 downto 0) -- resulting product
  );
end entity;

architecture neorv32_prim_mul_rtl of neorv32_prim_mul is

  signal opa, opb : signed(DWIDTH downto 0);
  signal res      : signed((2*DWIDTH)+1 downto 0);

begin

  -- Input Registers ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  లోపల_reg: process(clk_i)
  begin
    if rising_అంచు(clk_i) then
      if (en_i = '1') then
        opa <= signed((opa_i(opa_i'ఎడమ) and opas_i) & opa_i);
        opb <= signed((opb_i(opb_i'ఎడమ) and opbs_i) & opb_i);
      end if;
    end if;
  end process;

  -- Multiplier -----------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  one_reg:
  if (అంకె_REGS = 1) generate
    mul_reg: process(clk_i)
    begin
      if rising_అంచు(clk_i) then -- no reset to improve multiplier mapping
        res <= opa * opb;
      end if;
    end process;
  end generate;

  two_regs:
  if (అంకె_REGS = 2) generate
    signal mul_res : signed((2*DWIDTH)+1 downto 0);
  begin
    mul_reg: process(clk_i)
    begin
      if rising_అంచు(clk_i) then -- no reset to improve multiplier mapping
        mul_res <= opa * opb;
      end if;
    end process;

    ఫలితం_reg: process(clk_i)
    begin
      if rising_అంచు(clk_i) then -- no reset to improve multiplier mapping
        res <= mul_res;
      end if;
    end process;
  end generate;

  three_regs:
  if (అంకె_REGS = 3) generate
    constant lo_వెడల్పు_c : natural := DWIDTH / 2;
    constant hi_వెడల్పు_c : natural := (DWIDTH + 1) - lo_వెడల్పు_c;
    constant pp_వెడల్పు_c : natural := 2 * hi_వెడల్పు_c;
    constant pr_వెడల్పు_c : natural := (2 * DWIDTH) + 2;

    signal q_ll, q_lh, q_hl, q_hh : signed(pp_వెడల్పు_c-1 downto 0);
    signal q_కూడిక_lo, q_కూడిక_hi     : signed(pr_వెడల్పు_c-1 downto 0);
  begin
    partial_లబ్ధం_reg: process(clk_i)
    begin
      if rising_అంచు(clk_i) then -- no reset to improve multiplier mapping
        q_ll <= resize(signed('0' & std_ulogic_సదిశ(opa(lo_వెడల్పు_c-1 downto 0))) *
                       signed('0' & std_ulogic_సదిశ(opb(lo_వెడల్పు_c-1 downto 0))), pp_వెడల్పు_c);
        q_lh <= resize(signed('0' & std_ulogic_సదిశ(opa(lo_వెడల్పు_c-1 downto 0))) *
                       resize(opb(opb'ఎడమ downto lo_వెడల్పు_c), hi_వెడల్పు_c), pp_వెడల్పు_c);
        q_hl <= resize(resize(opa(opa'ఎడమ downto lo_వెడల్పు_c), hi_వెడల్పు_c) *
                       signed('0' & std_ulogic_సదిశ(opb(lo_వెడల్పు_c-1 downto 0))), pp_వెడల్పు_c);
        q_hh <= resize(resize(opa(opa'ఎడమ downto lo_వెడల్పు_c), hi_వెడల్పు_c) *
                       resize(opb(opb'ఎడమ downto lo_వెడల్పు_c), hi_వెడల్పు_c), pp_వెడల్పు_c);
      end if;
    end process;

    partial_కూడిక_reg: process(clk_i)
    begin
      if rising_అంచు(clk_i) then -- no reset to improve multiplier mapping
        q_కూడిక_lo <= resize(q_ll, pr_వెడల్పు_c) + జరుపు_ఎడమ(resize(q_lh, pr_వెడల్పు_c), lo_వెడల్పు_c);
        q_కూడిక_hi <= జరుపు_ఎడమ(resize(q_hl, pr_వెడల్పు_c), lo_వెడల్పు_c) +
                    జరుపు_ఎడమ(resize(q_hh, pr_వెడల్పు_c), 2*lo_వెడల్పు_c);
      end if;
    end process;

    ఫలితం_reg: process(clk_i)
    begin
      if rising_అంచు(clk_i) then -- no reset to improve multiplier mapping
        res <= q_కూడిక_lo + q_కూడిక_hi;
      end if;
    end process;
  end generate;

  -- result --
  res_o <= std_ulogic_సదిశ(res((2*DWIDTH)-1 downto 0));

end architecture;


-- ================================================================================ --
-- NEORV32 Primitives - Generic Counter Module                                      --
-- -------------------------------------------------------------------------------- --
-- High and low words are split across two individual registers to improve timing   --
-- by cutting the carry chain. The actual counter width can be trimmed via CWIDTH.  --
-- [WARNING] High and low words of counter output cnt_o are _NOT_ synchronized!     --
-- -------------------------------------------------------------------------------- --
-- The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32              --
-- Copyright (c) NEORV32 contributors.                                              --
-- Copyright (c) Stephan Nolting. All rights reserved.                              --
-- Licensed under the BSD-3-Clause license, see LICENSE for details.                --
-- SPDX-License-Identifier: BSD-3-Clause                                            --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_prim_cnt is
  generic (
    CWIDTH : natural range 0 to 64 -- actual counter width (0..64)
  );
  port (
    -- global control --
    clk_i  : in  std_ulogic;                     -- clock, rising edge
    rstn_i : in  std_ulogic;                     -- reset, low-active, async
    inc_i  : in  std_ulogic;                     -- enable counter increment
    -- read/write access --
    we_i   : in  std_ulogic_సదిశ(1 downto 0);  -- subword write enable
    దత్తాంశం_i : in  std_ulogic_సదిశ(31 downto 0); -- subword write data
    oe_i   : in  std_ulogic;                     -- output enable
    cnt_o  : out std_ulogic_సదిశ(63 downto 0)  -- trimmed counter output
  );
end entity;

architecture neorv32_prim_cnt_rtl of neorv32_prim_cnt is

  signal లెక్క : std_ulogic_సదిశ(63 downto 0);
  signal వాహకం, incen : std_ulogic_సదిశ(0 downto 0);
  signal inc_lo, inc_hi : std_ulogic_సదిశ(32 downto 0);

begin

  -- 64-Bit Counter (split across two 32-bit registers) -------------------------------------
  -- -------------------------------------------------------------------------------------------
  counter_core: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      incen <= (others => '0');
      లెక్క <= (others => '0');
      వాహకం <= (others => '0');
    elsif rising_అంచు(clk_i) then
      -- increment enable --
      incen(0) <= inc_i;
      -- low-word --
      if (we_i(0) = '1') then
        లెక్క(31 downto 0) <= దత్తాంశం_i;
      else
        లెక్క(31 downto 0) <= inc_lo(31 downto 0);
      end if;
      -- low-to-high carry --
      వాహకం(0) <= inc_lo(32);
      -- high-word --
      if (we_i(1) = '1') then
        లెక్క(63 downto 32) <= దత్తాంశం_i;
      else
        లెక్క(63 downto 32) <= inc_hi(31 downto 0);
      end if;
    end if;
  end process;

  -- increments --
  inc_lo <= std_ulogic_సదిశ(unsigned('0' & లెక్క(31 downto  0)) + unsigned(incen));
  inc_hi <= std_ulogic_సదిశ(unsigned('0' & లెక్క(63 downto 32)) + unsigned(వాహకం));

  -- Output Gating and Trimming -------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  trim: process(oe_i, లెక్క)
  begin
    cnt_o <= (others => '0');
    if (oe_i = '1') and (CWIDTH > 0) then
      cnt_o(CWIDTH-1 downto 0) <= లెక్క(CWIDTH-1 downto 0);
    end if;
  end process;

end architecture;
