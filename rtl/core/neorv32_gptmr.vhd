-- ================================================================================ --
-- NEORV32 SoC - General Purpose Timer (GPTMR)                                      --
-- -------------------------------------------------------------------------------- --
-- Up to 16 individual timer slices providing 32-bit count and threshold registers. --
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

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_gptmr is
  generic (
    عدد_SLICES : natural range 0 to 16 -- number of timer slices
  );
  port (
    clk_i     : in  std_ulogic;                    -- global clock line
    rstn_i    : in  std_ulogic;                    -- global reset line, low-active
    bus_req_i : in  bus_req_t;                     -- bus request
    bus_rsp_o : out bus_rsp_t;                     -- bus response
    clkgen_i  : in  std_ulogic_سمتیہ(7 downto 0); -- prescaled clocks
    irq_o     : out std_ulogic                     -- timer match interrupt
  );
end entity;

architecture neorv32_gptmr_rtl of neorv32_gptmr is

  -- counter slice --
  component neorv32_gptmr_قاش
  port (
    clk_i   : in  std_ulogic;
    rstn_i  : in  std_ulogic;
    clken_i : in  std_ulogic;
    en_i    : in  std_ulogic;
    منوال_i  : in  std_ulogic;
    cs_i    : in  std_ulogic;
    we_i    : in  std_ulogic;
    addr_i  : in  std_ulogic;
    wdata_i : in  std_ulogic_سمتیہ(31 downto 0);
    rdata_o : out std_ulogic_سمتیہ(31 downto 0);
    irq_o   : out std_ulogic
  );
  end component;

  -- slice configuration --
  signal acc_addr : std_ulogic_سمتیہ(1 downto 0);
  signal clkprsc : std_ulogic_سمتیہ(2 downto 0);
  signal enable, منوال, irq : std_ulogic_سمتیہ(عدد_SLICES-1 downto 0);
  signal clken : std_ulogic;

  -- slice wiring --
  type rdata_t is array (عدد_SLICES-1 downto 0) of std_ulogic_سمتیہ(31 downto 0);
  signal rdata : rdata_t;
  signal rdata_مجموع : std_ulogic_سمتیہ(31 downto 0);
  signal cs, trig : std_ulogic_سمتیہ(عدد_SLICES-1 downto 0);

begin

  -- Bus Handshake --------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  bus_handshake: process(clk_i)
  begin
    if rising_کنارہ(clk_i) then
      bus_rsp_o.ack <= bus_req_i.stb;
    end if;
  end process;

  -- no access errors supported --
  bus_rsp_o.err <= '0';

  -- access helper --
  acc_addr <= bus_req_i.addr(7) & bus_req_i.addr(2);


  -- Configuration Registers ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  control_regs: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      enable  <= (others => '0');
      منوال    <= (others => '0');
      clkprsc <= (others => '0');
    elsif rising_کنارہ(clk_i) then
      if (bus_req_i.stb = '1') and (bus_req_i.rw = '1') then -- write access
        -- CSR0: control and status register 0 --
        if (acc_addr = "00") then
          if (bus_req_i.ben(1 downto 0) = "11") then -- low half: per-slice enable
            enable <= bus_req_i.ڈیٹا((عدد_SLICES-1)+0 downto 0);
          end if;
          if (bus_req_i.ben(3 downto 2) = "11") then -- high half: per-slice mode
            منوال <= bus_req_i.ڈیٹا((عدد_SLICES-1)+16 downto 16);
          end if;
        end if;
        -- CSR1: control and status register 1 --
        if (acc_addr = "01") then
          if (bus_req_i.ben(3 downto 2) = "11") then -- high half: clock prescaler
            clkprsc <= bus_req_i.ڈیٹا(18 downto 16);
          end if;
        end if;
      end if;
    end if;
  end process;

  -- clock generator --
  clk_gen: process(clk_i)
  begin
    if rising_کنارہ(clk_i) then
      clken <= clkgen_i(مقصد_integer(unsigned(clkprsc)));
    end if;
  end process;


  -- Bus Read Access ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  bus_read: process(clk_i)
  begin
    if rising_کنارہ(clk_i) then
      bus_rsp_o.ڈیٹا <= (others => '0');
      if (bus_req_i.stb = '1') and (bus_req_i.rw = '0') then -- read access
        case acc_addr is
          when "00" => -- CSR0
            bus_rsp_o.ڈیٹا((عدد_SLICES-1)+0 downto 0)   <= enable;
            bus_rsp_o.ڈیٹا((عدد_SLICES-1)+16 downto 16) <= منوال;
          when "01" => -- CSR1
            bus_rsp_o.ڈیٹا((عدد_SLICES-1)+0 downto  0) <= irq;
            bus_rsp_o.ڈیٹا(18 downto 16)               <= clkprsc;
          when others => -- slice registers
            bus_rsp_o.ڈیٹا <= rdata_مجموع;
        end case;
      end if;
    end if;
  end process;


  -- Timer Slices ---------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  timer_قاش_gen:
  for i in 0 to عدد_SLICES-1 generate
    neorv32_gptmr_قاش_inst: neorv32_gptmr_قاش
    port map (
      -- global control --
      clk_i   => clk_i,
      rstn_i  => rstn_i,
      clken_i => clken,
      en_i    => enable(i),
      منوال_i  => منوال(i),
      -- register access --
      cs_i    => cs(i),
      we_i    => bus_req_i.rw,
      addr_i  => bus_req_i.addr(2),
      wdata_i => bus_req_i.ڈیٹا,
      rdata_o => rdata(i),
      -- IRQ output --
      irq_o   => trig(i)
    );
    cs(i) <= bus_req_i.stb when (bus_req_i.addr(7) = '1') and
                                (bus_req_i.addr(6 downto 3) = std_ulogic_سمتیہ(مقصد_unsigned(i, 4))) else '0';
  end generate;

  -- channel read-back --
  read_عقب: process(rdata)
    variable tmp_v : std_ulogic_سمتیہ(31 downto 0);
  begin
    tmp_v := (others => '0');
    for i in 0 to عدد_SLICES-1 loop
      tmp_v := tmp_v or rdata(i);
    end loop;
    rdata_مجموع <= tmp_v;
  end process;


  -- Interrupt Generator --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  irq_generator: process(clk_i)
  begin
    if rising_کنارہ(clk_i) then
      for i in 0 to عدد_SLICES-1 loop
        if (enable(i) = '0') then
          irq(i) <= '0';
        elsif (trig(i) = '1') then
          irq(i) <= '1';
        elsif (bus_req_i.stb = '1') and (bus_req_i.rw = '1') and (acc_addr = "01") and
              (bus_req_i.ben(i/8) = '1') and (bus_req_i.ڈیٹا(i) = '0') then -- write 0 to clear/ACK
          irq(i) <= '0';
        end if;
      end loop;
    end if;
  end process;

  -- CPU interrupt --
  irq_o <= or_reduce_f(irq);

end architecture;


-- ================================================================================ --
-- NEORV32 SoC - General Purpose Timer (GPTMR) - Timer Slice                        --
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

entity neorv32_gptmr_قاش is
  port (
    -- global control --
    clk_i   : in  std_ulogic;                     -- global clock line
    rstn_i  : in  std_ulogic;                     -- global reset line, low-active, async
    clken_i : in  std_ulogic;                     -- counter clock-enable
    en_i    : in  std_ulogic;                     -- slice enable
    منوال_i  : in  std_ulogic;                     -- operation mode
    -- register access --
    cs_i    : in  std_ulogic;                     -- access enable
    we_i    : in  std_ulogic;                     -- write-enable
    addr_i  : in  std_ulogic;                     -- register select
    wdata_i : in  std_ulogic_سمتیہ(31 downto 0); -- write data
    rdata_o : out std_ulogic_سمتیہ(31 downto 0); -- read data
    -- IRQ output --
    irq_o   : out std_ulogic                      -- counter reached zero
  );
end entity;

architecture neorv32_gptmr_قاش_rtl of neorv32_gptmr_قاش is

  signal thr, cnt : std_ulogic_سمتیہ(31 downto 0);
  signal مطابقت, trig : std_ulogic;

begin

  -- Counter Core ---------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  cnt_core: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      thr  <= (others => '0');
      cnt  <= (others => '0');
      trig <= '0';
    elsif rising_کنارہ(clk_i) then
      -- threshold value --
      if (cs_i = '1') and (we_i = '1') and (addr_i = '1') then
        thr <= wdata_i;
      end if;
      -- cycle counter --
      if (cs_i = '1') and (we_i = '1') and (addr_i = '0') then
        cnt <= wdata_i;
      elsif (en_i = '1') and (clken_i = '1') then
        if (مطابقت = '0') then
          cnt <= std_ulogic_سمتیہ(unsigned(cnt) + 1);
        elsif (منوال_i = '1') then -- continuous mode
          cnt <= (others => '0');
        end if;
      end if;
      -- interrupt --
      trig <= مطابقت;
    end if;
  end process;

  -- read-back --
  rdata_o <= (others => '0') when (cs_i = '0') else cnt when (addr_i = '0') else thr;

  -- match detector --
  مطابقت <= '1' when (cnt = thr) else '0';

  -- match interrupt --
  irq_o <= مطابقت and (not trig);

end architecture;
