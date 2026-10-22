-- ================================================================================ --
-- NEORV32 SoC - Processor Bus Infrastructure: 2-to-1 Bus Switch                    --
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

entity neorv32_bus_switch is
  generic (
    ਗੇੜਾ_ROBIN_EN : boolean := false; -- enable round-robin arbitration
    A_READ_ONLY    : boolean := false; -- set if port A is read-only
    B_READ_ONLY    : boolean := false  -- set if port B is read-only
  );
  port (
    clk_i   : in  std_ulogic; -- global clock, rising edge
    rstn_i  : in  std_ulogic; -- global reset, low-active, async
    a_req_i : in  bus_req_t;  -- host port A request bus
    a_rsp_o : out bus_rsp_t;  -- host port A response bus
    b_req_i : in  bus_req_t;  -- host port B request bus
    b_rsp_o : out bus_rsp_t;  -- host port B response bus
    x_req_o : out bus_req_t;  -- device port request bus
    x_rsp_i : in  bus_rsp_t   -- device port response bus
  );
end entity;

architecture neorv32_bus_switch_rtl of neorv32_bus_switch is

  type state_t is (S_IDLE, S_BUSY_A, S_BUSY_B);
  signal state, state_nxt : state_t;
  signal a_req, b_req, sel, sel_q, stb : std_ulogic;
  signal ਤਾਲਾ, ਤਾਲਾ_nxt : std_ulogic_ਸਦਿਸ਼(1 downto 0);

begin

  -- Access Arbiter Sync --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  arbiter_sync: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      state <= S_IDLE;
      sel_q <= '0';
      ਤਾਲਾ  <= "00";
      a_req <= '0';
      b_req <= '0';
    elsif rising_ਕਿਨਾਰਾ(clk_i) then
      state <= state_nxt;
      sel_q <= sel;
      ਤਾਲਾ  <= ਤਾਲਾ_nxt;
      if (state = S_BUSY_A) then
        a_req <= '0';
      elsif (a_req_i.stb = '1') then
        a_req <= '1';
      end if;
      if (state = S_BUSY_B) then
        b_req <= '0';
      elsif (b_req_i.stb = '1') then
        b_req <= '1';
      end if;
    end if;
  end process;

  -- Access Arbiter Comb --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  arbiter_fsm: process(state, ਤਾਲਾ, sel_q, a_req, b_req, a_req_i, b_req_i, x_rsp_i)
  begin
    -- defaults --
    state_nxt <= state;
    ਤਾਲਾ_nxt  <= ਤਾਲਾ;
    sel       <= '0';
    stb       <= '0';

    -- state machine --
    case state is

      when S_BUSY_A => -- A: wait for response (lock-release or single-access ACK)
      -- ------------------------------------------------------------
        sel <= '0';
        stb <= a_req_i.stb;
        if ((ਤਾਲਾ(0) = '1') and (a_req_i.ਤਾਲਾ = '0')) or ((ਤਾਲਾ(0) = '0') and (x_rsp_i.ack = '1')) then
          state_nxt <= S_IDLE;
        end if;

      when S_BUSY_B => -- B: wait for response (lock-release or single-access ACK)
      -- ------------------------------------------------------------
        sel <= '1';
        stb <= b_req_i.stb;
        if ((ਤਾਲਾ(1) = '1') and (b_req_i.ਤਾਲਾ = '0')) or ((ਤਾਲਾ(1) = '0') and (x_rsp_i.ack = '1')) then
          state_nxt <= S_IDLE;
        end if;

      when S_IDLE => -- wait for requests
      -- ------------------------------------------------------------
        ਤਾਲਾ_nxt <= b_req_i.ਤਾਲਾ & a_req_i.ਤਾਲਾ;
        if (sel_q = '1') or (not ਗੇੜਾ_ROBIN_EN) then
          if (a_req_i.stb = '1') or (a_req = '1') then -- request from port A (prioritized)?
            sel       <= '0';
            stb       <= '1';
            state_nxt <= S_BUSY_A;
          elsif (b_req_i.stb = '1') or (b_req = '1') then -- request from port B?
            sel       <= '1';
            stb       <= '1';
            state_nxt <= S_BUSY_B;
          end if;
        else
          if (b_req_i.stb = '1') or (b_req = '1') then -- request from port B (prioritized)?
            sel       <= '1';
            stb       <= '1';
            state_nxt <= S_BUSY_B;
          elsif (a_req_i.stb = '1') or (a_req = '1') then -- request from port A?
            sel       <= '0';
            stb       <= '1';
            state_nxt <= S_BUSY_A;
          end if;
        end if;

    end case;
  end process;

  -- Request Switch -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  x_req_o.meta  <= a_req_i.meta  when (sel = '0') else b_req_i.meta;
  x_req_o.addr  <= a_req_i.addr  when (sel = '0') else b_req_i.addr;
  x_req_o.ਅੰਕੜੇ  <= b_req_i.ਅੰਕੜੇ  when A_READ_ONLY else
                   a_req_i.ਅੰਕੜੇ  when B_READ_ONLY else
                   a_req_i.ਅੰਕੜੇ  when (sel = '0') else b_req_i.ਅੰਕੜੇ;
  x_req_o.ben   <= a_req_i.ben   when (sel = '0') else b_req_i.ben;
  x_req_o.rw    <= a_req_i.rw    when (sel = '0') else b_req_i.rw;
  x_req_o.amo   <= a_req_i.amo   when (sel = '0') else b_req_i.amo;
  x_req_o.amoop <= a_req_i.amoop when (sel = '0') else b_req_i.amoop;
  x_req_o.ਮਿਆਦ <= a_req_i.ਮਿਆਦ when (sel = '0') else b_req_i.ਮਿਆਦ;
  x_req_o.ਤਾਲਾ  <= a_req_i.ਤਾਲਾ  when (sel = '0') else b_req_i.ਤਾਲਾ;
  x_req_o.stb   <= stb;

  -- Response Switch ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  a_rsp_o.ack  <= x_rsp_i.ack when (sel_q = '0') else '0';
  a_rsp_o.err  <= x_rsp_i.err when (sel_q = '0') else '0';
  a_rsp_o.ਅੰਕੜੇ <= x_rsp_i.ਅੰਕੜੇ;

  b_rsp_o.ack  <= x_rsp_i.ack when (sel_q = '1') else '0';
  b_rsp_o.err  <= x_rsp_i.err when (sel_q = '1') else '0';
  b_rsp_o.ਅੰਕੜੇ <= x_rsp_i.ਅੰਕੜੇ;

end architecture;


-- ================================================================================ --
-- NEORV32 SoC - Processor Bus Infrastructure: Bus Register Stage                   --
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

entity neorv32_bus_reg is
  port (
    -- global control --
    clk_i        : in  std_ulogic; -- global clock, rising edge
    rstn_i       : in  std_ulogic; -- global reset, low-active, async
    -- bus ports --
    host_req_i   : in  bus_req_t; -- host request
    host_rsp_o   : out bus_rsp_t; -- host response
    device_req_o : out bus_req_t; -- device request
    device_rsp_i : in  bus_rsp_t  -- device response
  );
end entity;

architecture neorv32_bus_reg_rtl of neorv32_bus_reg is

begin

  -- Request Register Stage -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  request_reg: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then -- full reset required
      device_req_o <= req_terminate_c;
    elsif rising_ਕਿਨਾਰਾ(clk_i) then
      if (host_req_i.stb = '1') then -- reduce switching activity on downstream bus system
        device_req_o <= host_req_i;
      end if;
      -- pass-through access control signals --
      device_req_o.stb   <= host_req_i.stb;
      device_req_o.ਮਿਆਦ <= host_req_i.ਮਿਆਦ;
      device_req_o.ਤਾਲਾ  <= host_req_i.ਤਾਲਾ;
    end if;
  end process;

  -- Response Register Stage ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  response_reg: process(clk_i)
  begin
    if rising_ਕਿਨਾਰਾ(clk_i) then -- no reset required
      host_rsp_o.ack  <= device_rsp_i.ack;
      host_rsp_o.err  <= device_rsp_i.err;
      host_rsp_o.ਅੰਕੜੇ <= device_rsp_i.ਅੰਕੜੇ;
    end if;
  end process;

end architecture;


-- ================================================================================ --
-- NEORV32 SoC - Processor Bus Infrastructure: Bus Gateway                          --
-- -------------------------------------------------------------------------------- --
-- Bus gateway to distribute accesses to 4 non-overlapping address sub-spaces       --
-- (A to C). Note that the sub-spaces have to be aligned to their individual sizes. --
-- All accesses that do not match any of these sections are redirected to the X     --
-- port. The gateway-internal bus monitor ensures that ALL accesses are completed   --
-- within a port-specific bound time window (*_TMO). Otherwise, a bus error         --
-- exception is raised.                                                             --
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

entity neorv32_bus_gateway is
  generic (
    -- device port A --
    A_EN    : boolean;                        -- port enable
    A_ਅਧਾਰ  : std_ulogic_ਸਦਿਸ਼(31 downto 0); -- port address space base address (aligned to size)
    A_ਮਾਪ  : natural;                        -- port address space size in bytes (power of two)
    A_TMO   : natural;                        -- port access timeout (power of two, 0 = disabled)
    -- device port B --
    B_EN    : boolean;
    B_ਅਧਾਰ  : std_ulogic_ਸਦਿਸ਼(31 downto 0);
    B_ਮਾਪ  : natural;
    B_TMO   : natural;
    -- device port C --
    C_EN    : boolean;
    C_ਅਧਾਰ  : std_ulogic_ਸਦਿਸ਼(31 downto 0);
    C_ਮਾਪ  : natural;
    C_TMO   : natural;
    -- device port D --
    D_EN    : boolean;
    D_ਅਧਾਰ  : std_ulogic_ਸਦਿਸ਼(31 downto 0);
    D_ਮਾਪ  : natural;
    D_TMO   : natural;
    -- device port X (the void) --
    X_EN    : boolean;
    X_TMO   : natural
  );
  port (
    -- global control --
    clk_i   : in  std_ulogic; -- global clock, rising edge
    rstn_i  : in  std_ulogic; -- global reset, low-active, async
    ਪਦ_o  : out std_ulogic; -- terminate current bus access
    -- host port --
    req_i   : in  bus_req_t;  -- host request
    rsp_o   : out bus_rsp_t;  -- host response
    -- device/section ports --
    a_req_o : out bus_req_t;
    a_rsp_i : in  bus_rsp_t;
    b_req_o : out bus_req_t;
    b_rsp_i : in  bus_rsp_t;
    c_req_o : out bus_req_t;
    c_rsp_i : in  bus_rsp_t;
    d_req_o : out bus_req_t;
    d_rsp_i : in  bus_rsp_t;
    x_req_o : out bus_req_t;
    x_rsp_i : in  bus_rsp_t
  );
end entity;

architecture neorv32_bus_gateway_rtl of neorv32_bus_gateway is

  -- port select --
  constant a_lo_c : natural := ਸੂਚਕਾਂਕ_ਮਾਪ_f(A_ਮਾਪ);
  constant b_lo_c : natural := ਸੂਚਕਾਂਕ_ਮਾਪ_f(B_ਮਾਪ);
  constant c_lo_c : natural := ਸੂਚਕਾਂਕ_ਮਾਪ_f(C_ਮਾਪ);
  constant d_lo_c : natural := ਸੂਚਕਾਂਕ_ਮਾਪ_f(D_ਮਾਪ);
  signal ਪੋਰਟ_sel : std_ulogic_ਸਦਿਸ਼(4 downto 0);

  -- port enable list --
  type ਪੋਰਟ_bool_list_t is array (4 downto 0) of boolean;
  constant ਪੋਰਟ_en_list_c : ਪੋਰਟ_bool_list_t := (
    0 => A_EN,
    1 => B_EN,
    2 => C_EN,
    3 => D_EN,
    4 => X_EN
  );

  -- port timeout enable list --
  type ਪੋਰਟ_tmo_en_list_t is array (4 downto 0) of boolean;
  constant ਪੋਰਟ_tmo_en_list_c : ਪੋਰਟ_tmo_en_list_t := (
    0 => boolean(A_TMO > 0),
    1 => boolean(B_TMO > 0),
    2 => boolean(C_TMO > 0),
    3 => boolean(D_TMO > 0),
    4 => boolean(X_TMO > 0)
  );

  -- port timeout counter bit list --
  type ਪੋਰਟ_tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_list_t is array (4 downto 0) of natural;
  constant ਪੋਰਟ_tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_list_c : ਪੋਰਟ_tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_list_t := (
    0 => ਸੂਚਕਾਂਕ_ਮਾਪ_f(A_TMO),
    1 => ਸੂਚਕਾਂਕ_ਮਾਪ_f(B_TMO),
    2 => ਸੂਚਕਾਂਕ_ਮਾਪ_f(C_TMO),
    3 => ਸੂਚਕਾਂਕ_ਮਾਪ_f(D_TMO),
    4 => ਸੂਚਕਾਂਕ_ਮਾਪ_f(X_TMO)
  );
  signal tmo_ਬਿੱਟ : std_ulogic_ਸਦਿਸ਼(4 downto 0);
  signal tmo_fire : std_ulogic;

  -- find highest bit index in port_tmo_bit_list_c to determine counter width --
  function max_tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_f(tmo_ਦੋਆਧਾਰੀ_ਅੰਕ : ਪੋਰਟ_tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_list_t) return natural is
    variable res_v : natural;
  begin
    res_v := 0;
    for i in tmo_ਦੋਆਧਾਰੀ_ਅੰਕ'range loop
      if tmo_ਦੋਆਧਾਰੀ_ਅੰਕ(i) > res_v then
        res_v := tmo_ਦੋਆਧਾਰੀ_ਅੰਕ(i);
      end if;
    end loop;
    return res_v;
  end function;
  constant tmo_cnt_ਮਾਪ_c : natural := max_tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_f(ਪੋਰਟ_tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_list_c);

  -- gateway ports combined as arrays --
  type ਪੋਰਟ_req_t is array (4 downto 0) of bus_req_t;
  type ਪੋਰਟ_rsp_t is array (4 downto 0) of bus_rsp_t;
  signal ਪੋਰਟ_req : ਪੋਰਟ_req_t;
  signal ਪੋਰਟ_rsp : ਪੋਰਟ_rsp_t;

  -- summarized response --
  signal int_rsp : bus_rsp_t;

  -- bus monitor --
  type state_t is (S_IDLE, S_BUSY, S_ERROR);
  type keeper_t is record
    state : state_t;
    ਤਾਲਾ  : std_ulogic;
    sel   : std_ulogic_ਸਦਿਸ਼(4 downto 0);
    cnt   : std_ulogic_ਸਦਿਸ਼(tmo_cnt_ਮਾਪ_c downto 0);
  end record;
  signal keeper  : keeper_t;
  signal bus_err : std_ulogic;

begin

  -- Address Section Decoder ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ਪੋਰਟ_sel(0) <= '1' when A_EN and (req_i.addr(31 downto a_lo_c) = A_ਅਧਾਰ(31 downto a_lo_c)) else '0';
  ਪੋਰਟ_sel(1) <= '1' when B_EN and (req_i.addr(31 downto b_lo_c) = B_ਅਧਾਰ(31 downto b_lo_c)) else '0';
  ਪੋਰਟ_sel(2) <= '1' when C_EN and (req_i.addr(31 downto c_lo_c) = C_ਅਧਾਰ(31 downto c_lo_c)) else '0';
  ਪੋਰਟ_sel(3) <= '1' when D_EN and (req_i.addr(31 downto d_lo_c) = D_ਅਧਾਰ(31 downto d_lo_c)) else '0';
  ਪੋਰਟ_sel(4) <= '1' when X_EN and (ਪੋਰਟ_sel(3 downto 0) = "0000") else '0'; -- access to the "void"

  -- Gateway Ports --------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  a_req_o <= ਪੋਰਟ_req(0); ਪੋਰਟ_rsp(0) <= a_rsp_i;
  b_req_o <= ਪੋਰਟ_req(1); ਪੋਰਟ_rsp(1) <= b_rsp_i;
  c_req_o <= ਪੋਰਟ_req(2); ਪੋਰਟ_rsp(2) <= c_rsp_i;
  d_req_o <= ਪੋਰਟ_req(3); ਪੋਰਟ_rsp(3) <= d_rsp_i;
  x_req_o <= ਪੋਰਟ_req(4); ਪੋਰਟ_rsp(4) <= x_rsp_i;

  -- bus request --
  request: process(req_i, ਪੋਰਟ_sel)
  begin
    for i in 0 to 4 loop
      ਪੋਰਟ_req(i) <= req_terminate_c;
      if ਪੋਰਟ_en_list_c(i) then -- port enabled
        ਪੋਰਟ_req(i) <= req_i;
        ਪੋਰਟ_req(i).stb <= req_i.stb and ਪੋਰਟ_sel(i);
      end if;
    end loop;
  end process;

  -- bus response --
  response: process(ਪੋਰਟ_rsp)
    variable tmp_v : bus_rsp_t;
  begin
    tmp_v := rsp_terminate_c; -- start with all-zero
    for i in 0 to 4 loop -- OR all response signals
      if ਪੋਰਟ_en_list_c(i) then -- port enabled
        tmp_v.ਅੰਕੜੇ := tmp_v.ਅੰਕੜੇ or ਪੋਰਟ_rsp(i).ਅੰਕੜੇ;
        tmp_v.ack  := tmp_v.ack  or ਪੋਰਟ_rsp(i).ack;
        tmp_v.err  := tmp_v.err  or ਪੋਰਟ_rsp(i).err;
      end if;
    end loop;
    int_rsp <= tmp_v;
  end process;

  -- host response --
  rsp_o.ਅੰਕੜੇ <= int_rsp.ਅੰਕੜੇ;
  rsp_o.ack  <= '0' when (keeper.state = S_IDLE) else (int_rsp.ack or bus_err); -- filter spurious response
  rsp_o.err  <= '0' when (keeper.state = S_IDLE) else (int_rsp.err or bus_err); -- filter spurious response

  -- Bus Monitor (aka "the KEEPER") ---------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  bus_monitor: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      keeper.state <= S_IDLE;
      keeper.ਤਾਲਾ  <= '0';
      keeper.sel   <= (others => '0');
      keeper.cnt   <= (others => '0');
    elsif rising_ਕਿਨਾਰਾ(clk_i) then
      case keeper.state is

        when S_IDLE => -- idle, waiting for new access request
        -- ------------------------------------------------------------
          keeper.ਤਾਲਾ <= req_i.ਤਾਲਾ;
          keeper.sel  <= ਪੋਰਟ_sel;
          keeper.cnt  <= (others => '0');
          if (req_i.stb = '1') then
            keeper.state <= S_BUSY;
          end if;

        when S_BUSY => -- busy, transfer in progress
        -- ------------------------------------------------------------
          -- timeout counter --
          if (int_rsp.ack = '1') then -- reset for each burst element
            keeper.cnt <= (others => '0');
          else
            keeper.cnt <= std_ulogic_ਸਦਿਸ਼(unsigned(keeper.cnt) + 1);
          end if;
          -- bus status --
          if (tmo_fire = '1') then -- timeout
            keeper.state <= S_ERROR;
          elsif (keeper.ਤਾਲਾ = '1') then -- locked / burst transfer
            if (req_i.ਤਾਲਾ = '0') then
              keeper.state <= S_IDLE;
            end if;
          elsif (int_rsp.ack = '1') then -- end of single transfer
            keeper.state <= S_IDLE;
          end if;

        when S_ERROR => -- return error response until end of (locked) transfer
        -- ------------------------------------------------------------
          if (keeper.ਤਾਲਾ = '0') or (req_i.ਤਾਲਾ = '0') then
            keeper.state <= S_IDLE;
          end if;

      end case;
    end if;
  end process;

  -- timeout counter bit select; fire also if no port is selected at all (#1633) --
  tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_gen:
  for i in 0 to 4 generate
    tmo_ਬਿੱਟ(i) <= keeper.cnt(ਪੋਰਟ_tmo_ਦੋਆਧਾਰੀ_ਅੰਕ_list_c(i)) when ਪੋਰਟ_tmo_en_list_c(i) else '0';
  end generate;
  tmo_fire <= or_reduce_f(tmo_ਬਿੱਟ and keeper.sel) or (not or_reduce_f(keeper.sel));

  -- bus keeper error --
  bus_err <= '1' when (keeper.state = S_ERROR) else '0'; -- send error to host
  ਪਦ_o  <= '1' when (keeper.state = S_ERROR) else '0'; -- terminate pending (external) bus access

  -- external timeout notification --
  assert ((not X_EN) or (X_TMO > 0)) report
    "[NEORV32] External bus timeout disabled! Can cause permanent system stall!" severity warning;

end architecture;


-- ================================================================================ --
-- NEORV32 SoC - Processor Bus Infrastructure: IO Switch                            --
-- -------------------------------------------------------------------------------- --
-- Simple switch for accessing one out of several (IO) devices. The main request    --
-- input bus provides a partial register stage to relax timing. Thus, accesses      --
-- require an additional clock cycle.                                               --
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

entity neorv32_bus_io_switch is
  generic (
    DEV_ਮਾਪ  : natural; -- size of each IO device, has to be a power of two
    -- device port enable and base address; enabled ports do not have to be contiguous --
    DEV_00_EN : boolean := false; DEV_00_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_01_EN : boolean := false; DEV_01_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_02_EN : boolean := false; DEV_02_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_03_EN : boolean := false; DEV_03_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_04_EN : boolean := false; DEV_04_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_05_EN : boolean := false; DEV_05_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_06_EN : boolean := false; DEV_06_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_07_EN : boolean := false; DEV_07_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_08_EN : boolean := false; DEV_08_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_09_EN : boolean := false; DEV_09_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_10_EN : boolean := false; DEV_10_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_11_EN : boolean := false; DEV_11_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_12_EN : boolean := false; DEV_12_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_13_EN : boolean := false; DEV_13_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_14_EN : boolean := false; DEV_14_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_15_EN : boolean := false; DEV_15_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_16_EN : boolean := false; DEV_16_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_17_EN : boolean := false; DEV_17_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_18_EN : boolean := false; DEV_18_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_19_EN : boolean := false; DEV_19_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_20_EN : boolean := false; DEV_20_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_21_EN : boolean := false; DEV_21_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_22_EN : boolean := false; DEV_22_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_23_EN : boolean := false; DEV_23_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_24_EN : boolean := false; DEV_24_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_25_EN : boolean := false; DEV_25_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_26_EN : boolean := false; DEV_26_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_27_EN : boolean := false; DEV_27_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_28_EN : boolean := false; DEV_28_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_29_EN : boolean := false; DEV_29_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_30_EN : boolean := false; DEV_30_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0');
    DEV_31_EN : boolean := false; DEV_31_ਅਧਾਰ : std_ulogic_ਸਦਿਸ਼(31 downto 0) := (others => '0')
  );
  port (
    -- global control --
    clk_i        : in  std_ulogic; -- global clock, rising edge
    rstn_i       : in  std_ulogic; -- global reset, low-active, async
    -- host port --
    main_req_i   : in  bus_req_t; -- host request
    main_rsp_o   : out bus_rsp_t; -- host response
    -- device ports --
    dev_00_req_o : out bus_req_t; dev_00_rsp_i : in bus_rsp_t;
    dev_01_req_o : out bus_req_t; dev_01_rsp_i : in bus_rsp_t;
    dev_02_req_o : out bus_req_t; dev_02_rsp_i : in bus_rsp_t;
    dev_03_req_o : out bus_req_t; dev_03_rsp_i : in bus_rsp_t;
    dev_04_req_o : out bus_req_t; dev_04_rsp_i : in bus_rsp_t;
    dev_05_req_o : out bus_req_t; dev_05_rsp_i : in bus_rsp_t;
    dev_06_req_o : out bus_req_t; dev_06_rsp_i : in bus_rsp_t;
    dev_07_req_o : out bus_req_t; dev_07_rsp_i : in bus_rsp_t;
    dev_08_req_o : out bus_req_t; dev_08_rsp_i : in bus_rsp_t;
    dev_09_req_o : out bus_req_t; dev_09_rsp_i : in bus_rsp_t;
    dev_10_req_o : out bus_req_t; dev_10_rsp_i : in bus_rsp_t;
    dev_11_req_o : out bus_req_t; dev_11_rsp_i : in bus_rsp_t;
    dev_12_req_o : out bus_req_t; dev_12_rsp_i : in bus_rsp_t;
    dev_13_req_o : out bus_req_t; dev_13_rsp_i : in bus_rsp_t;
    dev_14_req_o : out bus_req_t; dev_14_rsp_i : in bus_rsp_t;
    dev_15_req_o : out bus_req_t; dev_15_rsp_i : in bus_rsp_t;
    dev_16_req_o : out bus_req_t; dev_16_rsp_i : in bus_rsp_t;
    dev_17_req_o : out bus_req_t; dev_17_rsp_i : in bus_rsp_t;
    dev_18_req_o : out bus_req_t; dev_18_rsp_i : in bus_rsp_t;
    dev_19_req_o : out bus_req_t; dev_19_rsp_i : in bus_rsp_t;
    dev_20_req_o : out bus_req_t; dev_20_rsp_i : in bus_rsp_t;
    dev_21_req_o : out bus_req_t; dev_21_rsp_i : in bus_rsp_t;
    dev_22_req_o : out bus_req_t; dev_22_rsp_i : in bus_rsp_t;
    dev_23_req_o : out bus_req_t; dev_23_rsp_i : in bus_rsp_t;
    dev_24_req_o : out bus_req_t; dev_24_rsp_i : in bus_rsp_t;
    dev_25_req_o : out bus_req_t; dev_25_rsp_i : in bus_rsp_t;
    dev_26_req_o : out bus_req_t; dev_26_rsp_i : in bus_rsp_t;
    dev_27_req_o : out bus_req_t; dev_27_rsp_i : in bus_rsp_t;
    dev_28_req_o : out bus_req_t; dev_28_rsp_i : in bus_rsp_t;
    dev_29_req_o : out bus_req_t; dev_29_rsp_i : in bus_rsp_t;
    dev_30_req_o : out bus_req_t; dev_30_rsp_i : in bus_rsp_t;
    dev_31_req_o : out bus_req_t; dev_31_rsp_i : in bus_rsp_t
  );
end entity;

architecture neorv32_bus_io_switch_rtl of neorv32_bus_io_switch is

  -- module configuration --
  constant ਅੰਕ_devs_c : natural := 32; -- number of device ports

  -- address bit boundaries for access decoding --
  constant addr_lo_c : natural := ਸੂਚਕਾਂਕ_ਮਾਪ_f(DEV_ਮਾਪ); -- low address boundary bit
  constant addr_hi_c : natural := (ਸੂਚਕਾਂਕ_ਮਾਪ_f(DEV_ਮਾਪ) + ਸੂਚਕਾਂਕ_ਮਾਪ_f(ਅੰਕ_devs_c)) - 1; -- high address boundary bit

  -- list of enabled device ports --
  type dev_en_list_t is array (ਅੰਕ_devs_c-1 downto 0) of boolean;
  constant dev_en_list_c : dev_en_list_t := (
    0  => DEV_00_EN, 1  => DEV_01_EN, 2  => DEV_02_EN, 3  => DEV_03_EN,
    4  => DEV_04_EN, 5  => DEV_05_EN, 6  => DEV_06_EN, 7  => DEV_07_EN,
    8  => DEV_08_EN, 9  => DEV_09_EN, 10 => DEV_10_EN, 11 => DEV_11_EN,
    12 => DEV_12_EN, 13 => DEV_13_EN, 14 => DEV_14_EN, 15 => DEV_15_EN,
    16 => DEV_16_EN, 17 => DEV_17_EN, 18 => DEV_18_EN, 19 => DEV_19_EN,
    20 => DEV_20_EN, 21 => DEV_21_EN, 22 => DEV_22_EN, 23 => DEV_23_EN,
    24 => DEV_24_EN, 25 => DEV_25_EN, 26 => DEV_26_EN, 27 => DEV_27_EN,
    28 => DEV_28_EN, 29 => DEV_29_EN, 30 => DEV_30_EN, 31 => DEV_31_EN
  );

  -- list of device base addresses --
  type dev_ਅਧਾਰ_list_t is array (ਅੰਕ_devs_c-1 downto 0) of std_ulogic_ਸਦਿਸ਼(31 downto 0);
  constant dev_ਅਧਾਰ_list_c : dev_ਅਧਾਰ_list_t := (
    0  => DEV_00_ਅਧਾਰ, 1  => DEV_01_ਅਧਾਰ, 2  => DEV_02_ਅਧਾਰ, 3  => DEV_03_ਅਧਾਰ,
    4  => DEV_04_ਅਧਾਰ, 5  => DEV_05_ਅਧਾਰ, 6  => DEV_06_ਅਧਾਰ, 7  => DEV_07_ਅਧਾਰ,
    8  => DEV_08_ਅਧਾਰ, 9  => DEV_09_ਅਧਾਰ, 10 => DEV_10_ਅਧਾਰ, 11 => DEV_11_ਅਧਾਰ,
    12 => DEV_12_ਅਧਾਰ, 13 => DEV_13_ਅਧਾਰ, 14 => DEV_14_ਅਧਾਰ, 15 => DEV_15_ਅਧਾਰ,
    16 => DEV_16_ਅਧਾਰ, 17 => DEV_17_ਅਧਾਰ, 18 => DEV_18_ਅਧਾਰ, 19 => DEV_19_ਅਧਾਰ,
    20 => DEV_20_ਅਧਾਰ, 21 => DEV_21_ਅਧਾਰ, 22 => DEV_22_ਅਧਾਰ, 23 => DEV_23_ਅਧਾਰ,
    24 => DEV_24_ਅਧਾਰ, 25 => DEV_25_ਅਧਾਰ, 26 => DEV_26_ਅਧਾਰ, 27 => DEV_27_ਅਧਾਰ,
    28 => DEV_28_ਅਧਾਰ, 29 => DEV_29_ਅਧਾਰ, 30 => DEV_30_ਅਧਾਰ, 31 => DEV_31_ਅਧਾਰ
  );

  -- device ports combined as arrays --
  type dev_req_t is array (ਅੰਕ_devs_c-1 downto 0) of bus_req_t;
  type dev_rsp_t is array (ਅੰਕ_devs_c-1 downto 0) of bus_rsp_t;
  signal dev_req : dev_req_t;
  signal dev_rsp : dev_rsp_t;

  -- register stages --
  signal main_req : bus_req_t;
  signal main_rsp : bus_rsp_t;

begin

  -- In/Out Register Stages -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_bus_reg_inst: entity neorv32.neorv32_bus_reg
  port map (
    -- global control --
    clk_i        => clk_i,
    rstn_i       => rstn_i,
    -- bus ports --
    host_req_i   => main_req_i,
    host_rsp_o   => main_rsp_o,
    device_req_o => main_req,
    device_rsp_i => main_rsp
  );

  -- Combine Device Ports -------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  dev_00_req_o <= dev_req(0);  dev_rsp(0)  <= dev_00_rsp_i;
  dev_01_req_o <= dev_req(1);  dev_rsp(1)  <= dev_01_rsp_i;
  dev_02_req_o <= dev_req(2);  dev_rsp(2)  <= dev_02_rsp_i;
  dev_03_req_o <= dev_req(3);  dev_rsp(3)  <= dev_03_rsp_i;
  dev_04_req_o <= dev_req(4);  dev_rsp(4)  <= dev_04_rsp_i;
  dev_05_req_o <= dev_req(5);  dev_rsp(5)  <= dev_05_rsp_i;
  dev_06_req_o <= dev_req(6);  dev_rsp(6)  <= dev_06_rsp_i;
  dev_07_req_o <= dev_req(7);  dev_rsp(7)  <= dev_07_rsp_i;
  dev_08_req_o <= dev_req(8);  dev_rsp(8)  <= dev_08_rsp_i;
  dev_09_req_o <= dev_req(9);  dev_rsp(9)  <= dev_09_rsp_i;
  dev_10_req_o <= dev_req(10); dev_rsp(10) <= dev_10_rsp_i;
  dev_11_req_o <= dev_req(11); dev_rsp(11) <= dev_11_rsp_i;
  dev_12_req_o <= dev_req(12); dev_rsp(12) <= dev_12_rsp_i;
  dev_13_req_o <= dev_req(13); dev_rsp(13) <= dev_13_rsp_i;
  dev_14_req_o <= dev_req(14); dev_rsp(14) <= dev_14_rsp_i;
  dev_15_req_o <= dev_req(15); dev_rsp(15) <= dev_15_rsp_i;
  dev_16_req_o <= dev_req(16); dev_rsp(16) <= dev_16_rsp_i;
  dev_17_req_o <= dev_req(17); dev_rsp(17) <= dev_17_rsp_i;
  dev_18_req_o <= dev_req(18); dev_rsp(18) <= dev_18_rsp_i;
  dev_19_req_o <= dev_req(19); dev_rsp(19) <= dev_19_rsp_i;
  dev_20_req_o <= dev_req(20); dev_rsp(20) <= dev_20_rsp_i;
  dev_21_req_o <= dev_req(21); dev_rsp(21) <= dev_21_rsp_i;
  dev_22_req_o <= dev_req(22); dev_rsp(22) <= dev_22_rsp_i;
  dev_23_req_o <= dev_req(23); dev_rsp(23) <= dev_23_rsp_i;
  dev_24_req_o <= dev_req(24); dev_rsp(24) <= dev_24_rsp_i;
  dev_25_req_o <= dev_req(25); dev_rsp(25) <= dev_25_rsp_i;
  dev_26_req_o <= dev_req(26); dev_rsp(26) <= dev_26_rsp_i;
  dev_27_req_o <= dev_req(27); dev_rsp(27) <= dev_27_rsp_i;
  dev_28_req_o <= dev_req(28); dev_rsp(28) <= dev_28_rsp_i;
  dev_29_req_o <= dev_req(29); dev_rsp(29) <= dev_29_rsp_i;
  dev_30_req_o <= dev_req(30); dev_rsp(30) <= dev_30_rsp_i;
  dev_31_req_o <= dev_req(31); dev_rsp(31) <= dev_31_rsp_i;

  -- Request --------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  bus_request_gen:
  for i in 0 to (ਅੰਕ_devs_c-1) generate

    bus_request_ਪੋਰਟ_enabled:
    if dev_en_list_c(i) generate
      bus_request: process(main_req)
      begin
        dev_req(i) <= main_req;
        if (main_req.addr(addr_hi_c downto addr_lo_c) = dev_ਅਧਾਰ_list_c(i)(addr_hi_c downto addr_lo_c)) then
          dev_req(i).stb <= main_req.stb; -- propagate transaction strobe if address match
        else
          dev_req(i).stb <= '0';
        end if;
      end process;
    end generate;

    bus_request_ਪੋਰਟ_disabled:
    if not dev_en_list_c(i) generate
      dev_req(i) <= req_terminate_c;
    end generate;

  end generate;

  -- Response -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  bus_response: process(dev_rsp)
    variable tmp_v : bus_rsp_t;
  begin
    tmp_v := rsp_terminate_c; -- start with all-zero
    for i in 0 to (ਅੰਕ_devs_c-1) loop -- OR all enabled response buses
      if dev_en_list_c(i) then
        tmp_v.ਅੰਕੜੇ := tmp_v.ਅੰਕੜੇ or dev_rsp(i).ਅੰਕੜੇ;
        tmp_v.ack  := tmp_v.ack  or dev_rsp(i).ack;
        tmp_v.err  := tmp_v.err  or dev_rsp(i).err;
      end if;
    end loop;
    main_rsp <= tmp_v;
  end process;

end architecture;


-- ================================================================================ --
-- NEORV32 SoC - Processor Bus Infrastructure: Atomic Memory Operations Controller  --
-- -------------------------------------------------------------------------------- --
-- Read-modify-write controller for the RISC-V A/Zaamo ISA extension.               --
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

entity neorv32_bus_amo_rmw is
  port (
    -- global control --
    clk_i      : in  std_ulogic; -- global clock, rising edge
    rstn_i     : in  std_ulogic; -- global reset, low-active, async
    -- core port --
    core_req_i : in  bus_req_t;
    core_rsp_o : out bus_rsp_t;
    -- system port --
    sys_req_o  : out bus_req_t;
    sys_rsp_i  : in  bus_rsp_t
  );
end entity;

architecture neorv32_bus_amo_rmw_rtl of neorv32_bus_amo_rmw is

  -- arbiter --
  type state_t is (S_IDLE, S_READ_WAIT, S_READ_ERROR, S_EXECUTE, S_WRITE, S_WRITE_WAIT);
  type arbiter_t is record
    state : state_t;
    cmd   : std_ulogic_ਸਦਿਸ਼(3 downto 0);
    rdata : std_ulogic_ਸਦਿਸ਼(31 downto 0);
    wdata : std_ulogic_ਸਦਿਸ਼(31 downto 0);
  end record;
  signal arbiter, arbiter_nxt : arbiter_t;

  -- internal data ALU --
  signal alu_res, cmp_res : std_ulogic_ਸਦਿਸ਼(31 downto 0);
  signal cmp_opa, cmp_opb : std_ulogic_ਸਦਿਸ਼(32 downto 0);
  signal cmp_less : std_ulogic;

begin

  -- Arbiter Sync ---------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  arbiter_sync: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      arbiter.state <= S_IDLE;
      arbiter.cmd   <= (others => '0');
      arbiter.rdata <= (others => '0');
      arbiter.wdata <= (others => '0');
    elsif rising_ਕਿਨਾਰਾ(clk_i) then
      arbiter <= arbiter_nxt;
    end if;
  end process;

  -- Arbiter Comb ---------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  arbiter_comb: process(arbiter, core_req_i, sys_rsp_i)
  begin
    arbiter_nxt <= arbiter; -- default
    case arbiter.state is

      when S_IDLE => -- wait for RMW request; pass-through current request
      -- ------------------------------------------------------------
        if (core_req_i.stb = '1') and (core_req_i.amo = '1') and (core_req_i.amoop(3 downto 2) /= "10") then
          arbiter_nxt.cmd   <= core_req_i.amoop;
          arbiter_nxt.wdata <= core_req_i.ਅੰਕੜੇ;
          arbiter_nxt.state <= S_READ_WAIT;
        end if;

      when S_READ_WAIT => -- wait for read-access to complete
      -- ------------------------------------------------------------
        arbiter_nxt.rdata <= sys_rsp_i.ਅੰਕੜੇ;
        if (sys_rsp_i.ack = '1') then
          if (sys_rsp_i.err = '1') then
            arbiter_nxt.state <= S_READ_ERROR;
          else
            arbiter_nxt.state <= S_EXECUTE;
          end if;
        end if;

      when S_READ_ERROR => -- read error signaling cycle
      -- ------------------------------------------------------------
        arbiter_nxt.state <= S_IDLE; -- abort access

      when S_EXECUTE => -- execute atomic data operation
      -- ------------------------------------------------------------
        arbiter_nxt.state <= S_WRITE;

      when S_WRITE => -- write operation result
      -- ------------------------------------------------------------
        arbiter_nxt.state <= S_WRITE_WAIT;

      when S_WRITE_WAIT => -- wait for write-access to complete
      -- ------------------------------------------------------------
        if (sys_rsp_i.ack = '1') then
          arbiter_nxt.state <= S_IDLE;
        end if;

    end case;
  end process;

  -- request switch --
  sys_req_o.meta  <= core_req_i.meta;
  sys_req_o.addr  <= core_req_i.addr;
  sys_req_o.ਅੰਕੜੇ  <= alu_res when (arbiter.state = S_WRITE) or (arbiter.state = S_WRITE_WAIT) else core_req_i.ਅੰਕੜੇ;
  sys_req_o.ben   <= core_req_i.ben;
  sys_req_o.stb   <= '1' when (arbiter.state = S_WRITE) else core_req_i.stb;
  sys_req_o.rw    <= '1' when (arbiter.state = S_WRITE) or (arbiter.state = S_WRITE_WAIT) else core_req_i.rw;
  sys_req_o.amo   <= core_req_i.amo;
  sys_req_o.amoop <= core_req_i.amoop;
  sys_req_o.ਮਿਆਦ <= core_req_i.ਮਿਆਦ;
  sys_req_o.ਤਾਲਾ  <= core_req_i.ਤਾਲਾ;

  -- response switch --
  rsp_switch: process(arbiter, sys_rsp_i)
  begin
    if (arbiter.state = S_IDLE) or (arbiter.state = S_WRITE_WAIT) then
      core_rsp_o.err <= sys_rsp_i.err;
      core_rsp_o.ack <= sys_rsp_i.ack;
    elsif (arbiter.state = S_READ_ERROR) then
      core_rsp_o.err <= '1';
      core_rsp_o.ack <= '1';
    else
      core_rsp_o.err <= '0';
      core_rsp_o.ack <= '0';
    end if;
  end process;
  core_rsp_o.ਅੰਕੜੇ <= sys_rsp_i.ਅੰਕੜੇ when (arbiter.state = S_IDLE) else arbiter.rdata;

  -- Data ALU -------------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  amo_alu: process(clk_i)
  begin
    if rising_ਕਿਨਾਰਾ(clk_i) then
      case arbiter.cmd(2 downto 0) is
        when "000"  => alu_res <= arbiter.wdata; -- AMOSWAP.W
        when "001"  => alu_res <= std_ulogic_ਸਦਿਸ਼(unsigned(arbiter.rdata) + unsigned(arbiter.wdata)); -- AMOADD.W
        when "010"  => alu_res <= arbiter.rdata xor arbiter.wdata; -- AMOXOR.W
        when "011"  => alu_res <= arbiter.rdata and arbiter.wdata; -- AMOAND.W
        when "100"  => alu_res <= arbiter.rdata or arbiter.wdata; -- AMOOR.W
        when others => alu_res <= cmp_res; -- AMOMIN[U].W / AMOMAX[U].W
      end case;
    end if;
  end process;

  -- comparator logic (min/max for signed/unsigned) --
  cmp_opa  <= (arbiter.rdata(arbiter.rdata'ਖੱਬਾ) and arbiter.cmd(3)) & arbiter.rdata; -- sign-extend if signed operation
  cmp_opb  <= (arbiter.wdata(arbiter.wdata'ਖੱਬਾ) and arbiter.cmd(3)) & arbiter.wdata; -- sign-extend if signed operation
  cmp_less <= '1' when (signed(cmp_opa) < signed(cmp_opb)) else '0';
  cmp_res  <= cmp_opa(31 downto 0) when ((cmp_less xor arbiter.cmd(0)) = '1') else cmp_opb(31 downto 0);

end architecture;


-- ================================================================================ --
-- NEORV32 SoC - Processor Bus Infrastructure: Reservation Station                  --
-- -------------------------------------------------------------------------------- --
-- Reservation set controller for the RISC-V A/Zalrsc ISA extension.                --
-- [NOTE] Only a single 64-byte-wide reservation set is implemented. A simple turn- --
-- based arbitration ensures forward progress during consecutive SMP accesses.      --
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

entity neorv32_bus_amo_rvs is
  port (
    -- global control --
    clk_i      : in  std_ulogic; -- global clock, rising edge
    rstn_i     : in  std_ulogic; -- global reset, low-active, async
    -- core port --
    core_req_i : in  bus_req_t;
    core_rsp_o : out bus_rsp_t;
    -- system port --
    sys_req_o  : out bus_req_t;
    sys_rsp_i  : in  bus_rsp_t
  );
end entity;

architecture neorv32_bus_amo_rvs_rtl of neorv32_bus_amo_rvs is

  type rsv_t is record
    ਸੈੱਟ  : std_ulogic; -- valid
    id   : std_ulogic; -- core ID
    addr : std_ulogic_ਸਦਿਸ਼(31 downto 6); -- base address (64-byte granule)
  end record;
  signal rsv : rsv_t;

  signal lr, sc, turn, lr_allow, sc_valid, sc_pend_pass, sc_pend_fail : std_ulogic;

begin

  -- Reservation Station --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  reservation_station: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      rsv.ਸੈੱਟ  <= '0';
      rsv.id   <= '0';
      rsv.addr <= (others => '0');
      turn     <= '0';
    elsif rising_ਕਿਨਾਰਾ(clk_i) then
      if (core_req_i.stb = '1') and (core_req_i.meta(0) = '0') then -- data access request
        if (lr = '1') then -- set new reservation
          if (lr_allow = '1') then -- allowed by scheduling?
            rsv.ਸੈੱਟ  <= '1';
            rsv.id   <= core_req_i.meta(3);
            rsv.addr <= core_req_i.addr(31 downto 6);
          end if;
        elsif (sc = '1') then -- evaluate reservation
          if (sc_valid = '1') then -- successful SC
            rsv.ਸੈੱਟ <= '0';
            turn    <= not turn; -- flip turn for "fairness"
          elsif (rsv.ਸੈੱਟ = '1') and (rsv.id = core_req_i.meta(3)) then -- failed SC from owning core
            rsv.ਸੈੱਟ <= '0';
          end if;
        elsif (core_req_i.rw = '1') then -- any other write access
          if (core_req_i.addr(31 downto 6) = rsv.addr) then -- invalidate on address match
            rsv.ਸੈੱਟ <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- check if reservation-set operation --
  lr <= '1' when (core_req_i.amo = '1') and (core_req_i.amoop = "1000") else '0';
  sc <= '1' when (core_req_i.amo = '1') and (core_req_i.amoop = "1001") else '0';

  -- LR can set reservation if: no reservation yet OR same owner OR this core has turn priority --
  lr_allow <= '1' when (rsv.ਸੈੱਟ = '0')               else -- no active reservation
              '1' when (rsv.id = core_req_i.meta(3)) else -- same owner (update reservation)
              '1' when (turn = core_req_i.meta(3))   else -- priority: allowed to steal
              '0';                                        -- blocked

  -- SC valid if sent by the same core to the same address granule and reservation still active --
  sc_valid <= rsv.ਸੈੱਟ when (rsv.id = core_req_i.meta(3)) and (rsv.addr = core_req_i.addr(31 downto 6)) else '0';

  -- System Bus Interface -------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- [NOTE] the SC decision has to stay stable for the entire bus transfer: the reservation is
  -- updated with the request strobe, so sc_valid is only meaningful in the STB cycle; afterwards the
  -- registered decision (sc_pend_fail) is used
  bus_request: process(core_req_i, sc, sc_valid, sc_pend_fail)
  begin
    sys_req_o <= core_req_i; -- default: pass-through
    if (sc = '1') and (((core_req_i.stb = '1') and (sc_valid = '0')) or (sc_pend_fail = '1')) then -- SC fails: issue bus request, but as READ to check for access faults
      sys_req_o.rw  <= '0'; -- read instead of write
      sys_req_o.amo <= '0'; -- no longer an AMO operation
    end if;
  end process;

  -- track pending SC operation --
  sc_ਨਤੀਜਾ: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      sc_pend_pass <= '0';
      sc_pend_fail <= '0';
    elsif rising_ਕਿਨਾਰਾ(clk_i) then
      if (core_req_i.stb = '1') and (sc = '1') then -- set on SC request
        if (sc_valid = '1') then
          sc_pend_pass <= '1';
        else
          sc_pend_fail <= '1';
        end if;
      elsif (sys_rsp_i.ack = '1') then -- clear on bus response
        sc_pend_pass <= '0';
        sc_pend_fail <= '0';
      end if;
    end if;
  end process;

  -- response --
  -- SC fail + bus ok    -> access OK, reservation invalid -> return 1
  -- SC success + bus ok -> write completed                -> return 0
  -- SC any + bus err    -> propagate access fault         -> trap
  core_rsp_o.err  <= sys_rsp_i.err;
  core_rsp_o.ack  <= sys_rsp_i.ack;
  core_rsp_o.ਅੰਕੜੇ <= x"00000001" when (sc_pend_fail = '1') else -- SC failed: return 1
                     x"00000000" when (sc_pend_pass = '1') else -- SC passed: return 0
                     sys_rsp_i.ਅੰਕੜੇ;                            -- normal access / pass-through

end architecture;
