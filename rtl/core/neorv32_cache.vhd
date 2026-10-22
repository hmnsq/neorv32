-- ================================================================================ --
-- NEORV32 SoC - Generic Cache                                                      --
-- -------------------------------------------------------------------------------- --
-- The cache is direct-mapped and implements "write-back" & "write-allocate" write  --
-- policies. Burst transfers are used if BURSTS_EN is enabled. Otherwise, block     --
-- transfers are split into individual single-word transfers. Total cache size in   --
-- bytes is NUM_BLOCKS x BLOCK_SIZE.                                                --
--                                                                                  --
-- Handling of (uncached) AMO operations (#1540):                                   --
-- * AMO cache miss            -> directly execute bypass                           --
-- * AMO cache hit, line clean -> invalidate line, execute bypass                   --
-- * AMO cache hit, line dirty -> write back line, invalidate line, execute bypass  --
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

entity neorv32_cache is
  generic (
    عدد_بلاکیں : natural range 1 to 4096;       -- number of cache blocks, has to be a power of 2
    بلاک_سائز : natural range 4 to 1024;       -- cache block size in bytes, has to be a power of 2
    UC_BEGIN   : std_ulogic_سمتیہ(3 downto 0); -- begin of uncached address space (4 MSBs of address)
    READ_ONLY  : boolean;                       -- cache is read-only accesses for host
    BURSTS_EN  : boolean                        -- enable issuing of burst transfers
  );
  port (
    clk_i      : in  std_ulogic; -- global clock, rising edge
    rstn_i     : in  std_ulogic; -- global reset, low-active, async
    sync_i     : in  std_ulogic; -- perform full synchronization with main memory
    host_req_i : in  bus_req_t;  -- host request
    host_rsp_o : out bus_rsp_t;  -- host response
    bus_req_o  : out bus_req_t;  -- bus request
    bus_rsp_i  : in  bus_rsp_t   -- bus response
  );
end entity;

architecture neorv32_cache_rtl of neorv32_cache is

  -- cache layout --
  constant بلاک_عدد_c    : natural := 2**اشاریہ_سائز_f(عدد_بلاکیں);  -- extend if not a power of two
  constant بلاک_سائز_c   : natural := 2**اشاریہ_سائز_f(بلاک_سائز);  -- extend if not a power of two
  constant انحراف_چوڑائی_c : natural := اشاریہ_سائز_f(بلاک_سائز_c/4); -- word offset
  constant اشاریہ_چوڑائی_c  : natural := اشاریہ_سائز_f(بلاک_عدد_c);
  constant لیبل_چوڑائی_c    : natural := 32 - (انحراف_چوڑائی_c + اشاریہ_چوڑائی_c + 2);

  -- control -> cache interface --
  type cache_o_t is record
    سیٹ  : std_ulogic;
    vld  : std_ulogic;
    drt  : std_ulogic;
    addr : std_ulogic_سمتیہ(31 downto 0);
    ڈیٹا : std_ulogic_سمتیہ(31 downto 0);
    we   : std_ulogic_سمتیہ(3 downto 0);
  end record;
  signal cache_o : cache_o_t;

  -- cache -> control interface --
  type cache_i_t is record
    drt  : std_ulogic;
    کامیابی  : std_ulogic;
    لیبل  : std_ulogic_سمتیہ(31 downto 0);
    ڈیٹا : std_ulogic_سمتیہ(31 downto 0);
  end record;
  signal cache_i : cache_i_t;

  -- control arbiter --
  type state_t is (
    S_IDLE, S_CHECK, S_BYPASS,
    S_SYNC_آغاز, S_SYNC_DELAY, S_SYNC_CHECK, S_SYNC_اگلا,
    S_READ_آغاز, S_READ_WAIT, S_READ_مدت, S_READ_مکمل,
    S_WRITE_آغاز, S_WRITE_REQ, S_WRITE_RSP, S_WRITE_WAIT, S_WRITE_مدت, S_WRITE_مکمل
  );
  type ctrl_t is record
    state   : state_t;    -- FSM state
    sync    : std_ulogic; -- synchronization operation in progress
    bus_err : std_ulogic; -- bus error accumulator
    pnd_req : std_ulogic; -- pending bus request
    pnd_syn : std_ulogic; -- pending synchronization request
    pnd_bp  : std_ulogic; -- pending bypass bus request
    bp_req  : std_ulogic; -- cache bypass bus request (STB)
    کامیابی     : std_ulogic; -- forced cache hit (to skip status update latency)
    cln     : std_ulogic; -- forced clean status (to skip status update latency)
    لیبل     : std_ulogic_سمتیہ(لیبل_چوڑائی_c-1 downto 0);    -- tag
    idx     : std_ulogic_سمتیہ(اشاریہ_چوڑائی_c-1 downto 0);  -- index
    ofs_int : std_ulogic_سمتیہ(انحراف_چوڑائی_c-1 downto 0); -- cache address offset
    ofs_ext : std_ulogic_سمتیہ(انحراف_چوڑائی_c downto 0);   -- bus address offset + overflow bit
    ofs_buf : std_ulogic_سمتیہ(انحراف_چوڑائی_c downto 0);   -- delayed bus address offset + overflow bit
  end record;
  signal ctrl, ctrl_nxt : ctrl_t; -- FSM

  -- status memory --
  signal valid,    dirty    : std_ulogic_سمتیہ(بلاک_عدد_c-1 downto 0);
  signal valid_rd, dirty_rd : std_ulogic;

begin

  -- Configuration Checks -------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  assert not (BURSTS_EN and (بلاک_سائز < 8)) report
    "[NEORV32] Cache cannot emit burst if BLOCK_SIZE < 8." severity error;


  -- Control Engine Sync --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ctrl_engine_sync: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      ctrl.state   <= S_IDLE;
      ctrl.sync    <= '0';
      ctrl.bus_err <= '0';
      ctrl.pnd_req <= '0';
      ctrl.pnd_syn <= '0';
      ctrl.pnd_bp  <= '0';
      ctrl.bp_req  <= '0';
      ctrl.کامیابی     <= '0';
      ctrl.cln     <= '0';
      ctrl.لیبل     <= (others => '0');
      ctrl.idx     <= (others => '0');
      ctrl.ofs_int <= (others => '0');
      ctrl.ofs_ext <= (others => '0');
      ctrl.ofs_buf <= (others => '0');
    elsif rising_کنارہ(clk_i) then
      ctrl <= ctrl_nxt;
    end if;
  end process;


  -- Control Engine Comb --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ctrl_engine_comb: process(ctrl, sync_i, host_req_i, cache_i, bus_rsp_i)
  begin
    -- control engine defaults --
    ctrl_nxt.state   <= ctrl.state;
    ctrl_nxt.sync    <= ctrl.sync;
    ctrl_nxt.bus_err <= ctrl.bus_err;
    ctrl_nxt.pnd_req <= ctrl.pnd_req or host_req_i.stb;
    ctrl_nxt.pnd_syn <= ctrl.pnd_syn or sync_i;
    ctrl_nxt.pnd_bp  <= ctrl.pnd_bp;
    ctrl_nxt.bp_req  <= '0';
    ctrl_nxt.کامیابی     <= '0';
    ctrl_nxt.cln     <= '0';
    ctrl_nxt.لیبل     <= ctrl.لیبل;
    ctrl_nxt.idx     <= ctrl.idx;
    ctrl_nxt.ofs_int <= ctrl.ofs_int;
    ctrl_nxt.ofs_ext <= ctrl.ofs_ext;
    ctrl_nxt.ofs_buf <= ctrl.ofs_ext;

    -- cache access defaults --
    cache_o.سیٹ  <= '0';
    cache_o.vld  <= '0';
    cache_o.drt  <= '0';
    cache_o.addr <= host_req_i.addr;
    cache_o.we   <= (others => '0');
    cache_o.ڈیٹا <= host_req_i.ڈیٹا;

    -- host response defaults --
    host_rsp_o      <= rsp_terminate_c; -- default: all off
    host_rsp_o.ڈیٹا <= cache_i.ڈیٹا; -- cache read data (for cache hit)

    -- bus interface defaults --
    bus_req_o      <= req_terminate_c; -- default: all off
    bus_req_o.meta <= host_req_i.meta;
    bus_req_o.addr <= ctrl.لیبل & ctrl.idx & ctrl.ofs_ext(انحراف_چوڑائی_c-1 downto 0) & "00"; -- cache access
    bus_req_o.ben  <= (others => '1'); -- cache updates use full-word accesses only

    -- fsm --
    case ctrl.state is

      -- ==========================================================================
      -- Access check: hit/miss/bypass
      -- ==========================================================================

      when S_IDLE => -- wait for request
      -- ------------------------------------------------------------
        ctrl_nxt.bus_err <= '0'; -- reset bus error flag
        ctrl_nxt.sync    <= '0'; -- reset sync-in-progress flag
        ctrl_nxt.pnd_bp  <= '0'; -- default: no bypass request
        if (ctrl.pnd_syn = '1') then -- pending sync request: invalidate clean blocks & write-back dirty blocks
          ctrl_nxt.state <= S_SYNC_آغاز;
        elsif (host_req_i.stb = '1') or (ctrl.pnd_req = '1') then -- (pending) access request
          if (unsigned(host_req_i.addr(31 downto 28)) >= unsigned(UC_BEGIN)) or (host_req_i.amo = '1') then
            ctrl_nxt.pnd_bp <= '1'; -- uncached address space access / atomic operation -> bypass cache
          end if;
          ctrl_nxt.state <= S_CHECK;
        end if;

      when S_CHECK => -- check access request
      -- ------------------------------------------------------------
        ctrl_nxt.لیبل     <= host_req_i.addr(31 downto 31-(لیبل_چوڑائی_c-1));
        ctrl_nxt.idx     <= host_req_i.addr(31-لیبل_چوڑائی_c downto 32-(لیبل_چوڑائی_c + اشاریہ_چوڑائی_c));
        ctrl_nxt.ofs_ext <= (others => '0');
        ctrl_nxt.ofs_int <= (others => '0');
        ctrl_nxt.pnd_req <= '0'; -- access request accepted
        ctrl_nxt.bp_req  <= '1'; -- in case we are doing a bypass request (set STB for one cycle)
        --
        if (ctrl.pnd_bp = '1') then -- cache bypass (uncached or atomic memory operation)
          if (cache_i.کامیابی = '1') then -- do we have a cached copy of the accessed address (#1540)?
            if (cache_i.drt = '1') and (READ_ONLY = false) then
              ctrl_nxt.state <= S_WRITE_آغاز; -- copy modified line to main memory
            else
              cache_o.vld    <= '0'; -- invalidate the cached copy so post-BYPASS reads refill from memory
              cache_o.سیٹ    <= '1';
              ctrl_nxt.state <= S_BYPASS;
            end if;
          else
            ctrl_nxt.state <= S_BYPASS;
          end if;
        elsif (cache_i.کامیابی = '1') then -- cache HIT: read/write from/to cache
          if (host_req_i.rw = '1') and (READ_ONLY = false) then -- modify cache
            cache_o.we  <= host_req_i.ben;
            cache_o.drt <= '1';
          end if;
          host_rsp_o.ack <= '1';
          ctrl_nxt.state <= S_IDLE;
        elsif (cache_i.drt = '1') and (READ_ONLY = false) then -- cache MISS: evicted block is dirty
          ctrl_nxt.state <= S_WRITE_آغاز;
        else -- cache MISS: evicted block is clean
          ctrl_nxt.state <= S_READ_آغاز;
        end if;

      when S_BYPASS => -- cache bypass
      -- ------------------------------------------------------------
        bus_req_o     <= host_req_i;
        bus_req_o.stb <= ctrl.bp_req; -- one-shot
        host_rsp_o    <= bus_rsp_i;
        if (bus_rsp_i.ack = '1') then
          ctrl_nxt.state <= S_IDLE;
        end if;

      -- ==========================================================================
      -- Cache synchronization: invalidate all blocks & write back dirty blocks
      -- ==========================================================================

      when S_SYNC_آغاز => -- start synchronization
      -- ------------------------------------------------------------
        ctrl_nxt.pnd_syn <= '0'; -- sync request accepted
        if READ_ONLY then
          ctrl_nxt.state <= S_IDLE;
        else
          ctrl_nxt.sync  <= '1'; -- syncing in progress
          ctrl_nxt.idx   <= (others => '0');
          ctrl_nxt.state <= S_SYNC_DELAY;
        end if;

      when S_SYNC_DELAY => -- cache read access latency
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr   <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
          ctrl_nxt.state <= S_SYNC_CHECK;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_SYNC_CHECK => -- check if current block is dirty
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr     <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
          ctrl_nxt.ofs_ext <= (others => '0');
          ctrl_nxt.ofs_int <= (others => '0');
          ctrl_nxt.bus_err <= '0'; -- reset bus error flag
          if (cache_i.drt = '1') and (READ_ONLY = false) then -- block is dirty: upload to memory
            ctrl_nxt.state <= S_WRITE_آغاز;
          else -- block is clean: go to next block
            ctrl_nxt.state <= S_SYNC_اگلا;
          end if;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_SYNC_اگلا => -- update block status and prepare next block
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
          cache_o.سیٹ  <= '1'; -- update cache block status
          cache_o.drt  <= ctrl.bus_err; -- block is still dirty if there was a bus error
          cache_o.vld  <= ctrl.bus_err; -- keep block valid if there was a bus error (skip block)
          ctrl_nxt.idx <= std_ulogic_سمتیہ(unsigned(ctrl.idx) + 1);
          if (and_reduce_f(ctrl.idx) = '1') then -- all blocks checked
            ctrl_nxt.state <= S_IDLE;
          else -- access next block
            ctrl_nxt.state <= S_SYNC_DELAY;
          end if;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      -- ==========================================================================
      -- Download: read block from main memory
      -- ==========================================================================

      when S_READ_آغاز => -- start block download / send single request (if no bursts)
      -- ------------------------------------------------------------
        bus_req_o.rw    <= '0'; -- read access
        bus_req_o.stb   <= '1'; -- send request
        bus_req_o.تالا  <= '1'; -- locked transfer
        bus_req_o.مدت <= bool_مقصد_ulogic_f(BURSTS_EN); -- burst transfer
        ctrl_nxt.state  <= S_READ_WAIT;

      when S_READ_WAIT => -- wait for exclusive bus access / single response (if no bursts)
      -- ------------------------------------------------------------
        cache_o.addr    <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
        cache_o.ڈیٹا    <= bus_rsp_i.ڈیٹا;
        cache_o.we      <= (others => '1'); -- write full words
        bus_req_o.rw    <= '0'; -- read access
        bus_req_o.تالا  <= '1'; -- locked transfer
        bus_req_o.مدت <= bool_مقصد_ulogic_f(BURSTS_EN); -- burst transfer
        -- wait for initial ACK to start actual bursting or to issue next single request --
        if (bus_rsp_i.ack = '1') then
          ctrl_nxt.bus_err <= ctrl.bus_err or bus_rsp_i.err; -- accumulate bus errors
          ctrl_nxt.ofs_int <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_int) + 1);
          ctrl_nxt.ofs_ext <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_ext) + 1);
          if BURSTS_EN then
            ctrl_nxt.state <= S_READ_مدت;
          elsif (and_reduce_f(ctrl.ofs_int) = '1') then -- block completed
            ctrl_nxt.state <= S_READ_مکمل;
          else
            ctrl_nxt.state <= S_READ_آغاز;
          end if;
        end if;

      when S_READ_مدت => -- issue read burst
      -- ------------------------------------------------------------
        if BURSTS_EN then
          cache_o.addr   <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
          cache_o.ڈیٹا   <= bus_rsp_i.ڈیٹا;
          cache_o.we     <= (others => '1'); -- write full words
          bus_req_o.rw   <= '0'; -- read access
          bus_req_o.تالا <= '1'; -- locked transfer
          -- send requests --
          if (ctrl.ofs_ext(انحراف_چوڑائی_c) = '0') then -- request next transfer
            bus_req_o.stb    <= '1';
            ctrl_nxt.ofs_ext <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_ext) + 1);
            if (and_reduce_f(ctrl.ofs_ext(انحراف_چوڑائی_c-1 downto 0)) = '0') then
              bus_req_o.مدت <= '1'; -- set burst indicator; except for the very last transfer
            end if;
          end if;
          -- receive responses --
          if (bus_rsp_i.ack = '1') then -- received cache word
            ctrl_nxt.bus_err <= ctrl.bus_err or bus_rsp_i.err; -- accumulate bus errors
            ctrl_nxt.ofs_int <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_int) + 1);
            if (and_reduce_f(ctrl.ofs_int) = '1') then -- block completed
              ctrl_nxt.state <= S_READ_مکمل;
            end if;
          end if;
        else -- single transfers only
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_READ_مکمل => -- update status of downloaded block + host miss access latency delay
      -- ------------------------------------------------------------
        cache_o.vld  <= not ctrl.bus_err; -- make valid if no error; invalidate otherwise
        cache_o.سیٹ  <= '1'; -- update cache block status
        ctrl_nxt.کامیابی <= '1'; -- force cache hit to skip status flag read latency
        if (ctrl.bus_err = '1') then -- bus error during block download (caused by cache miss)
          host_rsp_o.err <= '1';
          host_rsp_o.ack <= '1'; -- terminate current request and return bus error
          ctrl_nxt.state <= S_IDLE;
        else
          ctrl_nxt.state <= S_CHECK;
        end if;

      -- ==========================================================================
      -- Upload: write block to main memory
      -- ==========================================================================

      when S_WRITE_آغاز => -- start block upload: get data word from cache
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr    <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
          bus_req_o.ڈیٹا  <= cache_i.ڈیٹا;
          bus_req_o.rw    <= '1'; -- write access
          bus_req_o.تالا  <= '1'; -- locked transfer
          bus_req_o.مدت <= bool_مقصد_ulogic_f(BURSTS_EN); -- burst transfer
          if (or_reduce_f(ctrl.ofs_int) = '0') then -- first write operation?
            ctrl_nxt.لیبل <= cache_i.لیبل(لیبل_چوڑائی_c-1 downto 0); -- get tag of evicted block
          end if;
          ctrl_nxt.state <= S_WRITE_REQ;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_REQ => -- start block upload / send single request (if no bursts)
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr    <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
          bus_req_o.ڈیٹا  <= cache_i.ڈیٹا;
          bus_req_o.rw    <= '1'; -- write access
          bus_req_o.تالا  <= '1'; -- locked transfer
          bus_req_o.مدت <= bool_مقصد_ulogic_f(BURSTS_EN); -- burst transfer
          bus_req_o.stb   <= '1'; -- send request
          ctrl_nxt.state  <= S_WRITE_RSP;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_RSP => -- wait for exclusive bus access / single response (if no bursts)
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr    <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
          bus_req_o.ڈیٹا  <= cache_i.ڈیٹا;
          bus_req_o.rw    <= '1'; -- write access
          bus_req_o.تالا  <= '1'; -- locked transfer
          bus_req_o.مدت <= bool_مقصد_ulogic_f(BURSTS_EN); -- burst transfer
          -- wait for ACK --
          if (bus_rsp_i.ack = '1') then
            ctrl_nxt.bus_err <= ctrl.bus_err or bus_rsp_i.err; -- accumulate bus errors
            ctrl_nxt.ofs_int <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_int) + 1);
            ctrl_nxt.ofs_ext <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_ext) + 1);
            if BURSTS_EN then
              ctrl_nxt.state <= S_WRITE_WAIT;
            elsif (and_reduce_f(ctrl.ofs_int) = '1') then -- block completed
              ctrl_nxt.state <= S_WRITE_مکمل;
            else
              ctrl_nxt.state <= S_WRITE_آغاز;
            end if;
          end if;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_WAIT => -- cache read latency
      -- ------------------------------------------------------------
        if BURSTS_EN and (not READ_ONLY) then
          cache_o.addr     <= ctrl.لیبل & ctrl.idx & ctrl.ofs_ext(انحراف_چوڑائی_c-1 downto 0) & "00";
          bus_req_o.addr   <= ctrl.لیبل & ctrl.idx & ctrl.ofs_buf(انحراف_چوڑائی_c-1 downto 0) & "00";
          bus_req_o.ڈیٹا   <= cache_i.ڈیٹا;
          bus_req_o.rw     <= '1'; -- write access
          bus_req_o.تالا   <= '1'; -- locked transfer
          bus_req_o.مدت  <= '1'; -- burst transfer
          ctrl_nxt.ofs_ext <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_ext) + 1);
          ctrl_nxt.state   <= S_WRITE_مدت;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_مدت => -- issue write burst
      -- ------------------------------------------------------------
        if BURSTS_EN and (not READ_ONLY) then
          cache_o.addr   <= ctrl.لیبل & ctrl.idx & ctrl.ofs_ext(انحراف_چوڑائی_c-1 downto 0) & "00";
          bus_req_o.addr <= ctrl.لیبل & ctrl.idx & ctrl.ofs_buf(انحراف_چوڑائی_c-1 downto 0) & "00";
          bus_req_o.ڈیٹا <= cache_i.ڈیٹا;
          bus_req_o.rw   <= '1'; -- write access
          bus_req_o.تالا <= '1'; -- locked transfer
          -- send requests --
          if (ctrl.ofs_buf(انحراف_چوڑائی_c) = '0') then -- request next transfer
            bus_req_o.stb    <= '1';
            ctrl_nxt.ofs_ext <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_ext) + 1);
            if (and_reduce_f(ctrl.ofs_buf(انحراف_چوڑائی_c-1 downto 0)) = '0') then
              bus_req_o.مدت <= '1'; -- set burst indicator; except for the very last transfer
            end if;
          end if;
          -- receive responses --
          if (bus_rsp_i.ack = '1') then -- received cache word
            ctrl_nxt.bus_err <= ctrl.bus_err or bus_rsp_i.err; -- accumulate bus errors
            ctrl_nxt.ofs_int <= std_ulogic_سمتیہ(unsigned(ctrl.ofs_int) + 1);
            if (and_reduce_f(ctrl.ofs_int) = '1') then -- block completed
              ctrl_nxt.state <= S_WRITE_مکمل;
            end if;
          end if;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_مکمل => -- update status of uploaded block
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr <= ctrl.لیبل & ctrl.idx & ctrl.ofs_int & "00";
          ctrl_nxt.cln <= '1'; -- force cache clean to skip status flag read latency (for S_CHECK only)
          if (ctrl.sync = '1') then -- block upload caused by cache synchronization
            ctrl_nxt.state <= S_SYNC_اگلا;
          elsif (ctrl.bus_err = '1') then -- block upload caused by cache miss or AMO pre-flush: BUS ERROR during upload
            cache_o.سیٹ    <= '1'; -- update cache block status
            cache_o.vld    <= '0'; -- invalidate cache block
            host_rsp_o.err <= '1';
            host_rsp_o.ack <= '1'; -- terminate current request and return bus error
            ctrl_nxt.state <= S_IDLE;
          else -- block upload caused by cache miss or AMO pre-flush: upload successful
            cache_o.سیٹ    <= '1'; -- update cache block status
            cache_o.drt    <= '0'; -- cache block is clean now
            cache_o.vld    <= '1'; -- cache block is still valid
            ctrl_nxt.state <= S_CHECK;
          end if;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when others => -- undefined
      -- ------------------------------------------------------------
        ctrl_nxt.state <= S_IDLE;

    end case;
  end process;


  -- Status Memory: Block Valid -------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  حالت_valid: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      valid <= (others => '0');
    elsif rising_کنارہ(clk_i) then
      if READ_ONLY and (ctrl.state = S_SYNC_آغاز) then -- full parallel clear for i-cache
        valid <= (others => '0');
      elsif (cache_o.سیٹ = '1') then
        valid(مقصد_integer(unsigned(cache_o.addr(31-لیبل_چوڑائی_c downto 2+انحراف_چوڑائی_c)))) <= cache_o.vld;
      end if;
    end if;
  end process;

  -- synchronous read --
  حالت_valid_read: process(clk_i)
  begin
    if rising_کنارہ(clk_i) then
      valid_rd <= valid(مقصد_integer(unsigned(cache_o.addr(31-لیبل_چوڑائی_c downto 2+انحراف_چوڑائی_c))));
    end if;
  end process;


  -- Status Memory: Block Dirty -------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  حالت_dirty_enabled:
  if not READ_ONLY generate
    حالت_dirty: process(clk_i)
    begin
      if rising_کنارہ(clk_i) then -- no reset required; readout guarded by valid flag
        if (cache_o.سیٹ = '1') or (cache_o.drt = '1') then
          dirty(مقصد_integer(unsigned(cache_o.addr(31-لیبل_چوڑائی_c downto 2+انحراف_چوڑائی_c)))) <= cache_o.drt;
        end if;
        dirty_rd <= dirty(مقصد_integer(unsigned(cache_o.addr(31-لیبل_چوڑائی_c downto 2+انحراف_چوڑائی_c))));
      end if;
    end process;
    cache_i.drt <= '0' when (ctrl.cln = '1') else (dirty_rd and valid_rd); -- block dirty?
  end generate;

  -- blocks cannot be modified --
  حالت_dirty_disabled:
  if READ_ONLY generate
    dirty       <= (others => '0');
    dirty_rd    <= '0';
    cache_i.drt <= '0';
  end generate;


  -- Cache Data and Tag Memory (Wrapper) ----------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- [NOTE] Use component instantiation here to allow easy replacement by external (Verilog) IP.
  neorv32_cache_ram_inst: neorv32_cache_ram -- component declaration in package file
  generic map (
    لیبل_چوڑائی => لیبل_چوڑائی_c,
    IDX_چوڑائی => اشاریہ_چوڑائی_c,
    OFS_چوڑائی => انحراف_چوڑائی_c
  )
  port map (
    clk_i     => clk_i,
    addr_i    => cache_o.addr,
    لیبل_we_i  => cache_o.سیٹ,
    لیبل_o     => cache_i.لیبل,
    ڈیٹا_we_i => cache_o.we,
    ڈیٹا_i    => cache_o.ڈیٹا,
    ڈیٹا_o    => cache_i.ڈیٹا
  );

  -- cache hit --
  cache_i.کامیابی <= '1' when ((cache_i.لیبل(لیبل_چوڑائی_c-1 downto 0) = host_req_i.addr(31 downto 31-(لیبل_چوڑائی_c-1))) and
                           (valid_rd = '1')) or (ctrl.کامیابی = '1') else '0';

end architecture;
