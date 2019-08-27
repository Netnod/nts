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

module nts_rx_nuffer__testbench;
  parameter ADDR_WIDTH = 8;

  reg                     i_areset;
  reg                     i_clk;
  reg                     i_clear;
  reg  [ADDR_WIDTH-1:0]   i_addr; //TODO: make internal
  reg                     dispatch_fifo_rd_en;
  reg  [63:0]             dispatch_fifo_rd_data;

  wire                    access_port_wait;
  reg  [ADDR_WIDTH+3-1:0] access_port_addr;
  reg  [2:0]              access_port_wordsize;
  reg                     access_port_rd_en;
  wire                    access_port_rd_dv;
  wire  [63:0]            access_port_rd_data;

  nts_rx_buffer #(ADDR_WIDTH) buffer (
     .i_areset(i_areset),
     .i_clk(i_clk),
     .i_clear(i_clear),
     .i_addr(i_addr),
     .i_dispatch_fifo_rd_en(dispatch_fifo_rd_en),
     .i_dispatch_fifo_rd_data(dispatch_fifo_rd_data),
     .o_access_port_wait(access_port_wait),
     .i_access_port_addr(access_port_addr),
     .i_access_port_wordsize(access_port_wordsize),
     .i_access_port_rd_en(access_port_rd_en),
     .o_access_port_rd_dv(access_port_rd_dv),
     .o_access_port_rd_data(access_port_rd_data)
  );

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  task read ( input [10:0] addr, [2:0] ws );
    begin
      #10
      `assert(access_port_wait == 'b0);
      access_port_addr = addr;
      access_port_rd_en = 1;
      access_port_wordsize = ws;
      #10
      `assert(access_port_wait);
      access_port_rd_en = 0;
      #10
      while(access_port_wait) begin
        `assert(access_port_rd_dv == 'b0);
        //$display("%s:%0d %h.", `__FILE__, `__LINE__, access_port_rd_data);
        #10 ;
      end
      `assert(access_port_rd_dv == 'b1);
      //$display("%s:%0d %h.", `__FILE__, `__LINE__, access_port_rd_data);
    end
  endtask

    initial
      begin
        $display("Test start: %s:%0d.", `__FILE__, `__LINE__);
        i_clk = 1;
        i_areset = 1;
        i_clear = 1;
        access_port_addr = 'b0;
        access_port_wordsize = 'b0;
        access_port_rd_en = 'b0;
        dispatch_fifo_rd_en = 'b0;
        dispatch_fifo_rd_data = 'b00;
        i_addr = 0;

        #10 i_areset = 0;
        #10 i_clear = 0;

        #10 dispatch_fifo_rd_en = 1;
        i_addr = 0;
        dispatch_fifo_rd_en = 1;
        dispatch_fifo_rd_data = 64'hdeadbeef00000000;
        #10 i_addr = 1;
        dispatch_fifo_rd_data = 64'habad1deac0fef00d;
        #10 i_addr = 2;
        dispatch_fifo_rd_data = 64'h0123456789abcdef;
        #10 dispatch_fifo_rd_en = 0;

        #100
        read('b00_000, 3);
        `assert(access_port_rd_data == 64'hdeadbeef00000000);
        read('b00_000, 3);
        `assert(access_port_rd_data == 64'hdeadbeef00000000);
        read('b01_000, 3);
        `assert(access_port_rd_data == 64'habad1deac0fef00d);
        read('b01_000, 3);
        `assert(access_port_rd_data == 64'habad1deac0fef00d);
        read('b10_000, 3);
        `assert(access_port_rd_data == 64'h0123456789abcdef);
        read('b10_000, 3);
        `assert(access_port_rd_data == 64'h0123456789abcdef);
        read('b00_001, 3);
        `assert(access_port_rd_data == 64'hadbeef00000000ab);
        read('b01_010, 3);
        `assert(access_port_rd_data == 64'h1deac0fef00d0123);
        read('b01_011, 3);
        `assert(access_port_rd_data == 64'heac0fef00d012345);
        read('b01_111, 3);
        `assert(access_port_rd_data == 64'h0d0123456789abcd);

        #100
        read('b00_000, 0);
        `assert(access_port_rd_data == 64'hde);
        read('b00_001, 0);
        `assert(access_port_rd_data == 64'had);
        read('b10_111, 0);
        `assert(access_port_rd_data == 64'hef);


        #100
        read('b01_000, 1);
        `assert(access_port_rd_data == 64'habad);
        read('b01_111, 1);
        `assert(access_port_rd_data == 64'h0d01);

        #100
        read('b01_000, 2);
        `assert(access_port_rd_data == 64'habad1dea);
        read('b01_100, 2);
        `assert(access_port_rd_data == 64'hc0fef00d);
        read('b01_101, 2);
        `assert(access_port_rd_data == 64'hfef00d01);
        read('b01_110, 2);
        `assert(access_port_rd_data == 64'hf00d0123);
        read('b01_111, 2);
        `assert(access_port_rd_data == 64'h0d012345);


        //$display("%s:%0d access_port_rd_data %h.", `__FILE__, `__LINE__,access_port_rd_data);
        //$display("%s:%0d.", `__FILE__, `__LINE__);
        //$display("%s:%0d.", `__FILE__, `__LINE__);
        //$display("%s:%0d.", `__FILE__, `__LINE__);
        //$display("%s:%0d.", `__FILE__, `__LINE__);
        //$display("%s:%0d.", `__FILE__, `__LINE__);
        //$display("%s:%0d access_port_rd_data %h.", `__FILE__, `__LINE__,access_port_rd_data);
        //$display("access_port_rd_data == %h", access_port_rd_data);
        //$display("access_port_rd_data == %h", access_port_rd_data);
        //$display("access_port_rd_data == %h", access_port_rd_data);


        $display("Test stop: %s:%0d.", `__FILE__, `__LINE__);
        #40 $finish;
      end

  always begin
    #5 i_clk = ~i_clk;
  end

endmodule
