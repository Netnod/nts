//======================================================================
//
// memory_ctrl_tb.v
// ----------------
// Testbench for the memory comtroller.
//
// Author: Peter Magnusson
//
//
//
// Copyright 2019 Netnod Internet Exchange i Sverige AB
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module memory_ctrl_tb;
  localparam VERBOSE=1; //0: Silent, 1: Write test name, 2: Write traces
  localparam ADDR_WIDTH=8;
  localparam DEPTH = 2**ADDR_WIDTH;
  reg                  i_clk;
  reg                  i_areset;
  reg                  i_read_64;
  reg                  i_write_64;
  reg           [63:0] i_write_data;
  reg [ADDR_WIDTH-1:0] i_addr_hi;
  reg            [2:0] i_addr_lo;

  wire        o_error;
  wire        o_busy;
  wire [63:0] o_data;

  memory_ctrl #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INIT_ON_RESET(1),
    .INIT_VALUE(64'hF0F1_F2F3_F4F5_F6F7)
  )
  dut
  (
    .i_clk(i_clk),
    .i_areset(i_areset),
    .i_read_64(i_read_64),
    .i_write_64(i_write_64),
    .i_write_data(i_write_data),
    .i_addr_hi(i_addr_hi),
    .i_addr_lo(i_addr_lo),
    .o_error(o_error),
    .o_busy(o_busy),
    .o_data(o_data)
  );

  function [63:0] generate_testpattern ( input integer i );
  begin : testpattern_scope
      reg [63:0] a;
      a[63:56] = 8'h10 ^ i[31:24] ^ i[23:16] ^ i[15:8] ^ i[7:0];
      a[55:48] = 8'h20 ^ i[7:0];
      a[47:40] = 8'h30 ^ i[7:0];
      a[39:32] = 8'h40 ^ i[7:0];
      a[31:24] = 8'h50 ^ i[7:0];
      a[23:16] = 8'h60 ^ i[7:0];
      a[15: 8] = 8'h70 ^ i[7:0];
      a[ 7: 0] = 8'h80 ^ i[7:0];
      generate_testpattern = a;
    end
  endfunction

  task wait_busy;
  begin
    while (o_busy) #10;
  end
  endtask

  task write_append( inout [ADDR_WIDTH+3-1:0] address, input [63:0] data );
  begin
    if (VERBOSE > 1)
      $display("%s:%0d write_append(%h, %h)", `__FILE__, `__LINE__, address, data);
    i_write_64 = 1;
    { i_addr_hi, i_addr_lo } = address;
    i_write_data = data;
    #10;
    i_write_64 = 0;
    address = address + 8;
  end
  endtask

  task dump_ram_row(input integer row);
    $display("%s:%0d ram[%h] = %h.", `__FILE__, `__LINE__, row, dut.ram.ram[row]);
  endtask

  task dump_ram(input integer from, input integer to);
  begin : dumpy
    integer i;
    for ( i = from; i <= to; i = i + 1)
      dump_ram_row(i);
  end
  endtask

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk        = 0;
    i_areset     = 1;
    i_read_64    = 0;
    i_write_64   = 0;
    i_write_data = 0;
    i_addr_hi    = 0;
    i_addr_lo    = 0;

    #20 ;
    i_areset = 0;
    #10 ;

    wait_busy();

    begin : read_aligned_test
      integer i;
      if (VERBOSE>0) $display("%s:%0d Test aligned read64.", `__FILE__, `__LINE__);
      for (i = 0; i < DEPTH; i = i + 1) begin
        i_addr_hi     = i[ADDR_WIDTH-1:0];
        i_write_64    = 1;
        i_write_data  = generate_testpattern(i);
        if (VERBOSE>1) $display("%s:%0d WRITE %2d %h", `__FILE__, `__LINE__, i, i_write_data);
        #10 ;
      end
      i_write_64  = 0;
      #10 ;
      for (i = 0; i < DEPTH; i = i + 1) begin
        i_addr_hi = i[ADDR_WIDTH-1:0];
        i_read_64 = 1;
        #10 ;
        if (VERBOSE>1) $display("%s:%0d READ %2d %h", `__FILE__, `__LINE__, i, o_data);
        `assert( o_data == generate_testpattern(i) );
      end
      i_read_64     = 0;
      #10 ;
    end

    wait_busy();

    begin : read_unligned_test
      integer i;
      integer offset;
      /* verilator lint_off UNUSED */
      reg [127:0] pattern; //some bits not used in test
      /* verilator lint_on UNUSED */
      reg  [63:0] expected;
      for (offset = 1; offset < 8; offset = offset + 1) begin
        if (VERBOSE>0) $display("%s:%0d Test unaligned read64: %0d", `__FILE__, `__LINE__, offset);
        for (i = 0; i < DEPTH-1; i = i + 1) begin
          i_addr_hi = i[ADDR_WIDTH-1:0];
          i_addr_lo = offset[2:0];
          i_read_64 = 1;
          #10 ;
          pattern = { generate_testpattern(i), generate_testpattern(i+1) };
          case (offset)
            1: expected = pattern[ 119:56 ];
            2: expected = pattern[ 111:48 ];
            3: expected = pattern[ 103:40 ];
            4: expected = pattern[  95:32 ];
            5: expected = pattern[  87:24 ];
            6: expected = pattern[  79:16 ];
            7: expected = pattern[  71: 8 ];
            default: expected = 0;
          endcase
          if (VERBOSE>1) $display("%s:%0d READ %2d %h", `__FILE__, `__LINE__, i, o_data);
          `assert( o_data == expected );
        end
      end
      i_read_64     = 0;
      #10 ;
    end

    wait_busy();

    begin : write_unligned_test
      integer i;
      integer offset;
      //reg [127:0] pattern;
      //reg  [63:0] expected;
      for (offset = 1; offset < 8; offset = offset + 1) begin
        if (VERBOSE>0) $display("%s:%0d Test unaligned write64: %0d", `__FILE__, `__LINE__, offset);
        for (i = 0; i < DEPTH; i = i + 1) begin
          i_addr_hi     = i[ADDR_WIDTH-1:0];
          i_addr_lo     = 0;
          i_write_64    = 1;
          i_write_data  = 64'hF8F9_FAFB_FCFD_FEFF;
          if (VERBOSE>1) $display("%s:%0d WRITE %2d %h", `__FILE__, `__LINE__, i, i_write_data);
          #10 ;
        end
        i_write_64  = 0;
        #30
        for (i = 0; i < DEPTH-1; i = i + 1) begin
          i_addr_hi = i[ADDR_WIDTH-1:0];
          i_addr_lo = offset[2:0];
          i_write_64 = 1;
          i_write_data  = generate_testpattern(i);
          #10 ;
          if (VERBOSE>1) $display("%s:%0d WRITE %2d:%0d %h", `__FILE__, `__LINE__, i, i_addr_lo, i_write_data);
        end
        i_write_64 = 0;
        #20;
        for (i = 0; i < DEPTH; i = i + 1) begin
          i_addr_hi = i[ADDR_WIDTH-1:0];
          i_addr_lo = 0;
          i_read_64 = 1;
          #10 ;
          if (VERBOSE>1) $display("%s:%0d READ %2d %h", `__FILE__, `__LINE__, i, o_data);
        end
        i_read_64 = 0;
        #20;
        for (i = 0; i < DEPTH-1; i = i + 1) begin
          i_addr_hi = i[ADDR_WIDTH-1:0];
          i_addr_lo = offset[2:0];
          i_read_64 = 1;
          #10 ;
          if (VERBOSE>1) $display("%s:%0d READ %0d %h (expected: %h)", `__FILE__, `__LINE__, i, o_data, generate_testpattern(i));
          `assert( o_data == generate_testpattern(i) );
        end
        begin : check_first_offset
          reg[63:0] expected;

          expected = generate_testpattern(0);
          case (offset)
            1: expected = { 8'hF8, expected[63:8] };
            2: expected = { 16'hF8F9, expected[63:16] };
            3: expected = { 24'hF8F9_FA, expected[63:24] };
            4: expected = { 32'hF8F9_FAFB, expected[63:32] };
            5: expected = { 40'hF8F9_FAFB_FC, expected[63:40] };
            6: expected = { 48'hF8F9_FAFB_FCFD, expected[63:48] };
            7: expected = { 56'hF8F9_FAFB_FCFD_FE, expected[63:56] };
          endcase
          i_addr_hi = 0;
          i_addr_lo = 0;
          i_read_64 = 1;
          #10 ;
          if (VERBOSE>3) $display("%s:%0d o_data = %h expected = %h", `__FILE__, `__LINE__, o_data, expected );
          `assert( o_data == expected );
        end
        begin : check_last_offset
          reg [63:0] expected;
          expected = generate_testpattern(DEPTH-2);
          case (offset)
            1: expected = { expected[ 7:0], 56'hF9_FAFB_FCFD_FEFF };
            2: expected = { expected[15:0], 48'hFAFB_FCFD_FEFF };
            3: expected = { expected[23:0], 40'hFB_FCFD_FEFF };
            4: expected = { expected[31:0], 32'hFCFD_FEFF };
            5: expected = { expected[39:0], 24'hFD_FEFF };
            6: expected = { expected[47:0], 16'hFEFF };
            7: expected = { expected[55:0],  8'hFF };
          endcase
          i_addr_hi = DEPTH-1;
          i_addr_lo = 0;
          i_read_64 = 1;
          #10 ;
          if (VERBOSE>1) $display("%s:%0d o_data = %h expected = %h", `__FILE__, `__LINE__, o_data, expected );
          `assert( o_data == expected );
        end
        i_read_64     = 0;
        #10 ;
      end
    end

    i_areset = 1;
    #20;
    i_areset = 0;
    wait_busy();

    begin : test_from_engine_sims
      reg [ADDR_WIDTH+3-1:0] addr;
      if (VERBOSE>0) $display("%s:%0d Test aligned write, unaligned write, unaligned read64: %0d", `__FILE__, `__LINE__, addr);
      addr = 0;
      write_append( addr, 64'h525400cdcd23001c );
      write_append( addr, 64'h7300009908004500 );
      write_append( addr, 64'h000000004000ff11 );
      write_append( addr, 64'h1f99c23acad34d48 );
      write_append( addr, 64'he37e101b12670000 );
      write_append( addr, 64'h0000000000000000 );
      `assert( addr == 'h30 );
      addr = 'h2a;
      if (VERBOSE>0) $display("%s:%0d Test aligned write, unaligned write, unaligned read64: %0d", `__FILE__, `__LINE__, addr);
      write_append( addr, 64'h2401000000000000 ); //NTP
      write_append( addr, 64'h0000000000000000 );
      write_append( addr, 64'h0000000000000000 );
      write_append( addr, 64'h71cc4c8cdb00980b );
      write_append( addr, 64'h0000000100017b81 );
      write_append( addr, 64'h0000000100018441 );
      wait_busy();
      write_append( addr, 64'h0104002492ae9b06 ); //NTS UI
      write_append( addr, 64'he29f638497f018b5 );
      write_append( addr, 64'h812485cbef5f811f );
      write_append( addr, 64'h516a620ed8024546 );
      write_append( addr, 64'hbb3edb5900000000 );
      wait_busy();
      addr = 'h7e;
      if (VERBOSE>0) $display("%s:%0d Test aligned write, unaligned write, unaligned read64: %0d", `__FILE__, `__LINE__, addr);
      write_append( addr, 64'h0204006830a8dce1 ); // This write used to bug out due to:
                                                  // memctrl not supporting 1 single unaligned write
                                                  // (did not jump to STATE_UNALIGNED_WRITE64_LAST as necessary)
      wait_busy();

      if (VERBOSE>1)
        dump_ram(0, 20);

      i_read_64 = 1;
      { i_addr_hi, i_addr_lo } = 'h7e;
      #10;

      if (VERBOSE>1)
         $display("%s:%0d o_data = %h expected = %h", `__FILE__, `__LINE__, o_data, 64'h0204006830a8dce1 );

      `assert(o_data == 64'h0204006830a8dce1);
      i_read_64 = 0;
      //write_append( addr, 64'h );
      //write_append( addr, 64'h );
      //write_append( addr, 64'h );
      //write_append( addr, 64'h );

    end
/*
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 05a = 0104002492ae9b06
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 062 = e29f638497f018b5
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 06a = 812485cbef5f811f
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 072 = 516a620ed8024546
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 07a = bb3edb5900000000

../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 07e = 0204006830a8dce1
../src/tb/nts_top_tb.v:614 dut.engine.parser.state_reg: 14
../src/tb/nts_top_tb.v:707 dut.engine.parser.state_reg(19)->(20): 1 ticks
../src/tb/nts_top_tb.v:589 State: 14 CRYPTO_FSM state 00 => 0f [....]
../src/tb/nts_top_tb.v:714 dut.engine.parser.crypto_fsm_reg(0)->(15): 2 ticks
../src/tb/nts_top_tb.v:589 State: 14 CRYPTO_FSM state 0f => 10 [....]
../src/tb/nts_top_tb.v:714 dut.engine.parser.crypto_fsm_reg(15)->(16): 1 ticks
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 086 = 000000000000002e
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 08e = 000000000000002f
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 096 = 01cca8833de77a0c
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 09e = e9e7d6b2081e2bc6
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 0a6 = c418b4e5b15e6b78
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 0ae = 03a1003738f723ad
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 0b6 = 3e0f2c3c67012d97
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 0be = be5fba1aa63feb15
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 0c6 = dccb1ec93b470602
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 0ce = 3701f7ed0b795138
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 0d6 = 197428c797dfa8b9
../src/tb/nts_top_tb.v:630 dut.engine.mux_tx 0 0de = 27b1c6a832704bb3
 */


    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  always begin
    #5 i_clk = ~i_clk;
  end

  always @(posedge i_clk or posedge i_areset)
    if (i_areset == 0)
      if (o_error)
        $display("s:%0d WARNING: o_error", `__FILE__, `__LINE__);

endmodule
