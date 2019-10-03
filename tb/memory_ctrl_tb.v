//
// Copyright (c) 2019, The Swedish Post and Telecom Authority (PTS)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

//
// Author: Peter Magnusson, Assured AB
//

module memory_ctrl_tb;
  localparam VERBOSE=1; //0: Silent, 1: Write test name, 2: Write traces
  localparam ADDR_WIDTH=4;
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

  memory_ctrl #( .ADDR_WIDTH(ADDR_WIDTH) ) memctrl (
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
      a[63:56] = 8'h10 ^ i[7:0];
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

    #10 ;
    i_areset = 0;
    #10 ;



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

     begin : read_unligned_test
      integer i;
      integer offset;
      reg [127:0] pattern;
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

     begin : write_unligned_test
      integer i;
      integer offset;
      reg [127:0] pattern;
      reg  [63:0] expected;
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

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
