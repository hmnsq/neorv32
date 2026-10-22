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
    అంకె_ఖండాలు : natural range 1 to 4096;       -- number of cache blocks, has to be a power of 2
    ఖండం_కొలత : natural range 4 to 1024;       -- cache block size in bytes, has to be a power of 2
    UC_BEGIN   : std_ulogic_సదిశ(3 downto 0); -- begin of uncached address space (4 MSBs of address)
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
  constant ఖండం_అంకె_c    : natural := 2**సూచీ_కొలత_f(అంకె_ఖండాలు);  -- extend if not a power of two
  constant ఖండం_కొలత_c   : natural := 2**సూచీ_కొలత_f(ఖండం_కొలత);  -- extend if not a power of two
  constant స్థానభ్రంశం_వెడల్పు_c : natural := సూచీ_కొలత_f(ఖండం_కొలత_c/4); -- word offset
  constant సూచీ_వెడల్పు_c  : natural := సూచీ_కొలత_f(ఖండం_అంకె_c);
  constant ట్యాగ్_వెడల్పు_c    : natural := 32 - (స్థానభ్రంశం_వెడల్పు_c + సూచీ_వెడల్పు_c + 2);

  -- control -> cache interface --
  type cache_o_t is record
    సమితి  : std_ulogic;
    vld  : std_ulogic;
    drt  : std_ulogic;
    addr : std_ulogic_సదిశ(31 downto 0);
    దత్తాంశం : std_ulogic_సదిశ(31 downto 0);
    we   : std_ulogic_సదిశ(3 downto 0);
  end record;
  signal cache_o : cache_o_t;

  -- cache -> control interface --
  type cache_i_t is record
    drt  : std_ulogic;
    తగిలింది  : std_ulogic;
    ట్యాగ్  : std_ulogic_సదిశ(31 downto 0);
    దత్తాంశం : std_ulogic_సదిశ(31 downto 0);
  end record;
  signal cache_i : cache_i_t;

  -- control arbiter --
  type state_t is (
    S_IDLE, S_CHECK, S_BYPASS,
    S_SYNC_ప్రారంభం, S_SYNC_DELAY, S_SYNC_CHECK, S_SYNC_తదుపరి,
    S_READ_ప్రారంభం, S_READ_WAIT, S_READ_వ్యవధి, S_READ_పూర్తి,
    S_WRITE_ప్రారంభం, S_WRITE_REQ, S_WRITE_RSP, S_WRITE_WAIT, S_WRITE_వ్యవధి, S_WRITE_పూర్తి
  );
  type ctrl_t is record
    state   : state_t;    -- FSM state
    sync    : std_ulogic; -- synchronization operation in progress
    bus_err : std_ulogic; -- bus error accumulator
    pnd_req : std_ulogic; -- pending bus request
    pnd_syn : std_ulogic; -- pending synchronization request
    pnd_bp  : std_ulogic; -- pending bypass bus request
    bp_req  : std_ulogic; -- cache bypass bus request (STB)
    తగిలింది     : std_ulogic; -- forced cache hit (to skip status update latency)
    cln     : std_ulogic; -- forced clean status (to skip status update latency)
    ట్యాగ్     : std_ulogic_సదిశ(ట్యాగ్_వెడల్పు_c-1 downto 0);    -- tag
    idx     : std_ulogic_సదిశ(సూచీ_వెడల్పు_c-1 downto 0);  -- index
    ofs_int : std_ulogic_సదిశ(స్థానభ్రంశం_వెడల్పు_c-1 downto 0); -- cache address offset
    ofs_ext : std_ulogic_సదిశ(స్థానభ్రంశం_వెడల్పు_c downto 0);   -- bus address offset + overflow bit
    ofs_buf : std_ulogic_సదిశ(స్థానభ్రంశం_వెడల్పు_c downto 0);   -- delayed bus address offset + overflow bit
  end record;
  signal ctrl, ctrl_nxt : ctrl_t; -- FSM

  -- status memory --
  signal valid,    dirty    : std_ulogic_సదిశ(ఖండం_అంకె_c-1 downto 0);
  signal valid_rd, dirty_rd : std_ulogic;

begin

  -- Configuration Checks -------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  assert not (BURSTS_EN and (ఖండం_కొలత < 8)) report
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
      ctrl.తగిలింది     <= '0';
      ctrl.cln     <= '0';
      ctrl.ట్యాగ్     <= (others => '0');
      ctrl.idx     <= (others => '0');
      ctrl.ofs_int <= (others => '0');
      ctrl.ofs_ext <= (others => '0');
      ctrl.ofs_buf <= (others => '0');
    elsif rising_అంచు(clk_i) then
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
    ctrl_nxt.తగిలింది     <= '0';
    ctrl_nxt.cln     <= '0';
    ctrl_nxt.ట్యాగ్     <= ctrl.ట్యాగ్;
    ctrl_nxt.idx     <= ctrl.idx;
    ctrl_nxt.ofs_int <= ctrl.ofs_int;
    ctrl_nxt.ofs_ext <= ctrl.ofs_ext;
    ctrl_nxt.ofs_buf <= ctrl.ofs_ext;

    -- cache access defaults --
    cache_o.సమితి  <= '0';
    cache_o.vld  <= '0';
    cache_o.drt  <= '0';
    cache_o.addr <= host_req_i.addr;
    cache_o.we   <= (others => '0');
    cache_o.దత్తాంశం <= host_req_i.దత్తాంశం;

    -- host response defaults --
    host_rsp_o      <= rsp_terminate_c; -- default: all off
    host_rsp_o.దత్తాంశం <= cache_i.దత్తాంశం; -- cache read data (for cache hit)

    -- bus interface defaults --
    bus_req_o      <= req_terminate_c; -- default: all off
    bus_req_o.meta <= host_req_i.meta;
    bus_req_o.addr <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_ext(స్థానభ్రంశం_వెడల్పు_c-1 downto 0) & "00"; -- cache access
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
          ctrl_nxt.state <= S_SYNC_ప్రారంభం;
        elsif (host_req_i.stb = '1') or (ctrl.pnd_req = '1') then -- (pending) access request
          if (unsigned(host_req_i.addr(31 downto 28)) >= unsigned(UC_BEGIN)) or (host_req_i.amo = '1') then
            ctrl_nxt.pnd_bp <= '1'; -- uncached address space access / atomic operation -> bypass cache
          end if;
          ctrl_nxt.state <= S_CHECK;
        end if;

      when S_CHECK => -- check access request
      -- ------------------------------------------------------------
        ctrl_nxt.ట్యాగ్     <= host_req_i.addr(31 downto 31-(ట్యాగ్_వెడల్పు_c-1));
        ctrl_nxt.idx     <= host_req_i.addr(31-ట్యాగ్_వెడల్పు_c downto 32-(ట్యాగ్_వెడల్పు_c + సూచీ_వెడల్పు_c));
        ctrl_nxt.ofs_ext <= (others => '0');
        ctrl_nxt.ofs_int <= (others => '0');
        ctrl_nxt.pnd_req <= '0'; -- access request accepted
        ctrl_nxt.bp_req  <= '1'; -- in case we are doing a bypass request (set STB for one cycle)
        --
        if (ctrl.pnd_bp = '1') then -- cache bypass (uncached or atomic memory operation)
          if (cache_i.తగిలింది = '1') then -- do we have a cached copy of the accessed address (#1540)?
            if (cache_i.drt = '1') and (READ_ONLY = false) then
              ctrl_nxt.state <= S_WRITE_ప్రారంభం; -- copy modified line to main memory
            else
              cache_o.vld    <= '0'; -- invalidate the cached copy so post-BYPASS reads refill from memory
              cache_o.సమితి    <= '1';
              ctrl_nxt.state <= S_BYPASS;
            end if;
          else
            ctrl_nxt.state <= S_BYPASS;
          end if;
        elsif (cache_i.తగిలింది = '1') then -- cache HIT: read/write from/to cache
          if (host_req_i.rw = '1') and (READ_ONLY = false) then -- modify cache
            cache_o.we  <= host_req_i.ben;
            cache_o.drt <= '1';
          end if;
          host_rsp_o.ack <= '1';
          ctrl_nxt.state <= S_IDLE;
        elsif (cache_i.drt = '1') and (READ_ONLY = false) then -- cache MISS: evicted block is dirty
          ctrl_nxt.state <= S_WRITE_ప్రారంభం;
        else -- cache MISS: evicted block is clean
          ctrl_nxt.state <= S_READ_ప్రారంభం;
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

      when S_SYNC_ప్రారంభం => -- start synchronization
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
          cache_o.addr   <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
          ctrl_nxt.state <= S_SYNC_CHECK;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_SYNC_CHECK => -- check if current block is dirty
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr     <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
          ctrl_nxt.ofs_ext <= (others => '0');
          ctrl_nxt.ofs_int <= (others => '0');
          ctrl_nxt.bus_err <= '0'; -- reset bus error flag
          if (cache_i.drt = '1') and (READ_ONLY = false) then -- block is dirty: upload to memory
            ctrl_nxt.state <= S_WRITE_ప్రారంభం;
          else -- block is clean: go to next block
            ctrl_nxt.state <= S_SYNC_తదుపరి;
          end if;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_SYNC_తదుపరి => -- update block status and prepare next block
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
          cache_o.సమితి  <= '1'; -- update cache block status
          cache_o.drt  <= ctrl.bus_err; -- block is still dirty if there was a bus error
          cache_o.vld  <= ctrl.bus_err; -- keep block valid if there was a bus error (skip block)
          ctrl_nxt.idx <= std_ulogic_సదిశ(unsigned(ctrl.idx) + 1);
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

      when S_READ_ప్రారంభం => -- start block download / send single request (if no bursts)
      -- ------------------------------------------------------------
        bus_req_o.rw    <= '0'; -- read access
        bus_req_o.stb   <= '1'; -- send request
        bus_req_o.తాళం  <= '1'; -- locked transfer
        bus_req_o.వ్యవధి <= bool_గమ్యం_ulogic_f(BURSTS_EN); -- burst transfer
        ctrl_nxt.state  <= S_READ_WAIT;

      when S_READ_WAIT => -- wait for exclusive bus access / single response (if no bursts)
      -- ------------------------------------------------------------
        cache_o.addr    <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
        cache_o.దత్తాంశం    <= bus_rsp_i.దత్తాంశం;
        cache_o.we      <= (others => '1'); -- write full words
        bus_req_o.rw    <= '0'; -- read access
        bus_req_o.తాళం  <= '1'; -- locked transfer
        bus_req_o.వ్యవధి <= bool_గమ్యం_ulogic_f(BURSTS_EN); -- burst transfer
        -- wait for initial ACK to start actual bursting or to issue next single request --
        if (bus_rsp_i.ack = '1') then
          ctrl_nxt.bus_err <= ctrl.bus_err or bus_rsp_i.err; -- accumulate bus errors
          ctrl_nxt.ofs_int <= std_ulogic_సదిశ(unsigned(ctrl.ofs_int) + 1);
          ctrl_nxt.ofs_ext <= std_ulogic_సదిశ(unsigned(ctrl.ofs_ext) + 1);
          if BURSTS_EN then
            ctrl_nxt.state <= S_READ_వ్యవధి;
          elsif (and_reduce_f(ctrl.ofs_int) = '1') then -- block completed
            ctrl_nxt.state <= S_READ_పూర్తి;
          else
            ctrl_nxt.state <= S_READ_ప్రారంభం;
          end if;
        end if;

      when S_READ_వ్యవధి => -- issue read burst
      -- ------------------------------------------------------------
        if BURSTS_EN then
          cache_o.addr   <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
          cache_o.దత్తాంశం   <= bus_rsp_i.దత్తాంశం;
          cache_o.we     <= (others => '1'); -- write full words
          bus_req_o.rw   <= '0'; -- read access
          bus_req_o.తాళం <= '1'; -- locked transfer
          -- send requests --
          if (ctrl.ofs_ext(స్థానభ్రంశం_వెడల్పు_c) = '0') then -- request next transfer
            bus_req_o.stb    <= '1';
            ctrl_nxt.ofs_ext <= std_ulogic_సదిశ(unsigned(ctrl.ofs_ext) + 1);
            if (and_reduce_f(ctrl.ofs_ext(స్థానభ్రంశం_వెడల్పు_c-1 downto 0)) = '0') then
              bus_req_o.వ్యవధి <= '1'; -- set burst indicator; except for the very last transfer
            end if;
          end if;
          -- receive responses --
          if (bus_rsp_i.ack = '1') then -- received cache word
            ctrl_nxt.bus_err <= ctrl.bus_err or bus_rsp_i.err; -- accumulate bus errors
            ctrl_nxt.ofs_int <= std_ulogic_సదిశ(unsigned(ctrl.ofs_int) + 1);
            if (and_reduce_f(ctrl.ofs_int) = '1') then -- block completed
              ctrl_nxt.state <= S_READ_పూర్తి;
            end if;
          end if;
        else -- single transfers only
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_READ_పూర్తి => -- update status of downloaded block + host miss access latency delay
      -- ------------------------------------------------------------
        cache_o.vld  <= not ctrl.bus_err; -- make valid if no error; invalidate otherwise
        cache_o.సమితి  <= '1'; -- update cache block status
        ctrl_nxt.తగిలింది <= '1'; -- force cache hit to skip status flag read latency
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

      when S_WRITE_ప్రారంభం => -- start block upload: get data word from cache
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr    <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
          bus_req_o.దత్తాంశం  <= cache_i.దత్తాంశం;
          bus_req_o.rw    <= '1'; -- write access
          bus_req_o.తాళం  <= '1'; -- locked transfer
          bus_req_o.వ్యవధి <= bool_గమ్యం_ulogic_f(BURSTS_EN); -- burst transfer
          if (or_reduce_f(ctrl.ofs_int) = '0') then -- first write operation?
            ctrl_nxt.ట్యాగ్ <= cache_i.ట్యాగ్(ట్యాగ్_వెడల్పు_c-1 downto 0); -- get tag of evicted block
          end if;
          ctrl_nxt.state <= S_WRITE_REQ;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_REQ => -- start block upload / send single request (if no bursts)
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr    <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
          bus_req_o.దత్తాంశం  <= cache_i.దత్తాంశం;
          bus_req_o.rw    <= '1'; -- write access
          bus_req_o.తాళం  <= '1'; -- locked transfer
          bus_req_o.వ్యవధి <= bool_గమ్యం_ulogic_f(BURSTS_EN); -- burst transfer
          bus_req_o.stb   <= '1'; -- send request
          ctrl_nxt.state  <= S_WRITE_RSP;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_RSP => -- wait for exclusive bus access / single response (if no bursts)
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr    <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
          bus_req_o.దత్తాంశం  <= cache_i.దత్తాంశం;
          bus_req_o.rw    <= '1'; -- write access
          bus_req_o.తాళం  <= '1'; -- locked transfer
          bus_req_o.వ్యవధి <= bool_గమ్యం_ulogic_f(BURSTS_EN); -- burst transfer
          -- wait for ACK --
          if (bus_rsp_i.ack = '1') then
            ctrl_nxt.bus_err <= ctrl.bus_err or bus_rsp_i.err; -- accumulate bus errors
            ctrl_nxt.ofs_int <= std_ulogic_సదిశ(unsigned(ctrl.ofs_int) + 1);
            ctrl_nxt.ofs_ext <= std_ulogic_సదిశ(unsigned(ctrl.ofs_ext) + 1);
            if BURSTS_EN then
              ctrl_nxt.state <= S_WRITE_WAIT;
            elsif (and_reduce_f(ctrl.ofs_int) = '1') then -- block completed
              ctrl_nxt.state <= S_WRITE_పూర్తి;
            else
              ctrl_nxt.state <= S_WRITE_ప్రారంభం;
            end if;
          end if;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_WAIT => -- cache read latency
      -- ------------------------------------------------------------
        if BURSTS_EN and (not READ_ONLY) then
          cache_o.addr     <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_ext(స్థానభ్రంశం_వెడల్పు_c-1 downto 0) & "00";
          bus_req_o.addr   <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_buf(స్థానభ్రంశం_వెడల్పు_c-1 downto 0) & "00";
          bus_req_o.దత్తాంశం   <= cache_i.దత్తాంశం;
          bus_req_o.rw     <= '1'; -- write access
          bus_req_o.తాళం   <= '1'; -- locked transfer
          bus_req_o.వ్యవధి  <= '1'; -- burst transfer
          ctrl_nxt.ofs_ext <= std_ulogic_సదిశ(unsigned(ctrl.ofs_ext) + 1);
          ctrl_nxt.state   <= S_WRITE_వ్యవధి;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_వ్యవధి => -- issue write burst
      -- ------------------------------------------------------------
        if BURSTS_EN and (not READ_ONLY) then
          cache_o.addr   <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_ext(స్థానభ్రంశం_వెడల్పు_c-1 downto 0) & "00";
          bus_req_o.addr <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_buf(స్థానభ్రంశం_వెడల్పు_c-1 downto 0) & "00";
          bus_req_o.దత్తాంశం <= cache_i.దత్తాంశం;
          bus_req_o.rw   <= '1'; -- write access
          bus_req_o.తాళం <= '1'; -- locked transfer
          -- send requests --
          if (ctrl.ofs_buf(స్థానభ్రంశం_వెడల్పు_c) = '0') then -- request next transfer
            bus_req_o.stb    <= '1';
            ctrl_nxt.ofs_ext <= std_ulogic_సదిశ(unsigned(ctrl.ofs_ext) + 1);
            if (and_reduce_f(ctrl.ofs_buf(స్థానభ్రంశం_వెడల్పు_c-1 downto 0)) = '0') then
              bus_req_o.వ్యవధి <= '1'; -- set burst indicator; except for the very last transfer
            end if;
          end if;
          -- receive responses --
          if (bus_rsp_i.ack = '1') then -- received cache word
            ctrl_nxt.bus_err <= ctrl.bus_err or bus_rsp_i.err; -- accumulate bus errors
            ctrl_nxt.ofs_int <= std_ulogic_సదిశ(unsigned(ctrl.ofs_int) + 1);
            if (and_reduce_f(ctrl.ofs_int) = '1') then -- block completed
              ctrl_nxt.state <= S_WRITE_పూర్తి;
            end if;
          end if;
        else
          ctrl_nxt.state <= S_IDLE;
        end if;

      when S_WRITE_పూర్తి => -- update status of uploaded block
      -- ------------------------------------------------------------
        if not READ_ONLY then
          cache_o.addr <= ctrl.ట్యాగ్ & ctrl.idx & ctrl.ofs_int & "00";
          ctrl_nxt.cln <= '1'; -- force cache clean to skip status flag read latency (for S_CHECK only)
          if (ctrl.sync = '1') then -- block upload caused by cache synchronization
            ctrl_nxt.state <= S_SYNC_తదుపరి;
          elsif (ctrl.bus_err = '1') then -- block upload caused by cache miss or AMO pre-flush: BUS ERROR during upload
            cache_o.సమితి    <= '1'; -- update cache block status
            cache_o.vld    <= '0'; -- invalidate cache block
            host_rsp_o.err <= '1';
            host_rsp_o.ack <= '1'; -- terminate current request and return bus error
            ctrl_nxt.state <= S_IDLE;
          else -- block upload caused by cache miss or AMO pre-flush: upload successful
            cache_o.సమితి    <= '1'; -- update cache block status
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
  స్థితి_valid: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      valid <= (others => '0');
    elsif rising_అంచు(clk_i) then
      if READ_ONLY and (ctrl.state = S_SYNC_ప్రారంభం) then -- full parallel clear for i-cache
        valid <= (others => '0');
      elsif (cache_o.సమితి = '1') then
        valid(గమ్యం_integer(unsigned(cache_o.addr(31-ట్యాగ్_వెడల్పు_c downto 2+స్థానభ్రంశం_వెడల్పు_c)))) <= cache_o.vld;
      end if;
    end if;
  end process;

  -- synchronous read --
  స్థితి_valid_read: process(clk_i)
  begin
    if rising_అంచు(clk_i) then
      valid_rd <= valid(గమ్యం_integer(unsigned(cache_o.addr(31-ట్యాగ్_వెడల్పు_c downto 2+స్థానభ్రంశం_వెడల్పు_c))));
    end if;
  end process;


  -- Status Memory: Block Dirty -------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  స్థితి_dirty_enabled:
  if not READ_ONLY generate
    స్థితి_dirty: process(clk_i)
    begin
      if rising_అంచు(clk_i) then -- no reset required; readout guarded by valid flag
        if (cache_o.సమితి = '1') or (cache_o.drt = '1') then
          dirty(గమ్యం_integer(unsigned(cache_o.addr(31-ట్యాగ్_వెడల్పు_c downto 2+స్థానభ్రంశం_వెడల్పు_c)))) <= cache_o.drt;
        end if;
        dirty_rd <= dirty(గమ్యం_integer(unsigned(cache_o.addr(31-ట్యాగ్_వెడల్పు_c downto 2+స్థానభ్రంశం_వెడల్పు_c))));
      end if;
    end process;
    cache_i.drt <= '0' when (ctrl.cln = '1') else (dirty_rd and valid_rd); -- block dirty?
  end generate;

  -- blocks cannot be modified --
  స్థితి_dirty_disabled:
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
    ట్యాగ్_వెడల్పు => ట్యాగ్_వెడల్పు_c,
    IDX_వెడల్పు => సూచీ_వెడల్పు_c,
    OFS_వెడల్పు => స్థానభ్రంశం_వెడల్పు_c
  )
  port map (
    clk_i     => clk_i,
    addr_i    => cache_o.addr,
    ట్యాగ్_we_i  => cache_o.సమితి,
    ట్యాగ్_o     => cache_i.ట్యాగ్,
    దత్తాంశం_we_i => cache_o.we,
    దత్తాంశం_i    => cache_o.దత్తాంశం,
    దత్తాంశం_o    => cache_i.దత్తాంశం
  );

  -- cache hit --
  cache_i.తగిలింది <= '1' when ((cache_i.ట్యాగ్(ట్యాగ్_వెడల్పు_c-1 downto 0) = host_req_i.addr(31 downto 31-(ట్యాగ్_వెడల్పు_c-1))) and
                           (valid_rd = '1')) or (ctrl.తగిలింది = '1') else '0';

end architecture;
