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

module nts_rx_buffer_tb;
  parameter ADDR_WIDTH = 8;
  parameter VERBOSE=1;

  reg                     i_areset;
  reg                     i_clk;
  reg                     i_parser_busy;
  reg                     dispatch_packet_avialable;
  wire                    dispatch_packet_read;
  reg                     dispatch_fifo_empty;
  wire                    dispatch_fifo_rd_start;
  reg                     dispatch_fifo_rd_valid;
  reg  [63:0]             dispatch_fifo_rd_data;

  wire                    access_port_wait;
  reg  [ADDR_WIDTH+3-1:0] access_port_addr;
  reg  [2:0]              access_port_wordsize;
  reg                     access_port_rd_en;
  wire                    access_port_rd_dv;
  wire  [63:0]            access_port_rd_data;

  reg rd_start_recieved;
  reg rd_read_recieved;

  nts_rx_buffer #(ADDR_WIDTH) dut (
     .i_areset(i_areset),
     .i_clk(i_clk),
     .i_parser_busy(i_parser_busy),
     .i_dispatch_packet_available(dispatch_packet_avialable),
     .o_dispatch_packet_read(dispatch_packet_read),
     .i_dispatch_fifo_empty(dispatch_fifo_empty),
     .o_dispatch_fifo_rd_start(dispatch_fifo_rd_start),
     .i_dispatch_fifo_rd_valid(dispatch_fifo_rd_valid),
     .i_dispatch_fifo_rd_data(dispatch_fifo_rd_data),
     .o_access_port_wait(access_port_wait),
     .i_access_port_addr(access_port_addr),
     .i_access_port_wordsize(access_port_wordsize),
     .i_access_port_rd_en(access_port_rd_en),
     .o_access_port_rd_dv(access_port_rd_dv),
     .o_access_port_rd_data(access_port_rd_data)
  );

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  task read ( input [10:0] addr, input [2:0] ws );
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
        #10 ;
      end
      `assert(access_port_rd_dv == 'b1);
    end
  endtask

  initial
      begin
        $display("Test start: %s:%0d.", `__FILE__, `__LINE__);
        i_clk = 1;
        i_areset = 1;
        i_parser_busy = 1;
        access_port_addr = 'b0;
        access_port_wordsize = 'b0;
        access_port_rd_en = 'b0;
        dispatch_fifo_empty = 'b0;
        dispatch_fifo_rd_valid = 0;
        dispatch_fifo_rd_data = 'b00;
        dispatch_packet_avialable = 0;

        #10 i_areset = 0;

        #10 dispatch_packet_avialable = 'b1;
        #10 dispatch_fifo_empty = 'b0;
        #10 `assert(dispatch_fifo_rd_start == 'b0);
        #10 `assert(dispatch_fifo_rd_start == 'b0);
        i_parser_busy = 0;
        if (VERBOSE>0) $display("%s:%0d Waiting for dut to signal ready to receive.", `__FILE__, `__LINE__);
        while (rd_start_recieved == 'b0) #10;
        dispatch_packet_avialable = 'b0;

        if (VERBOSE>0) $display("%s:%0d Populate test values.", `__FILE__, `__LINE__);
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, 64'hdeadbeef00000000 };
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, 64'habad1deac0fef00d };
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, 64'h0123456789abcdef };
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b0, 64'h0 };
        #10 dispatch_fifo_empty = 'b1;
        if (VERBOSE>0) $display("%s:%0d Waiting for dut to signal ACK fifo read.", `__FILE__, `__LINE__);
        while (rd_read_recieved == 'b0) #10;
        dispatch_fifo_empty = 'b0;

        if (VERBOSE>0) $display("%s:%0d 64 bit access port tests.", `__FILE__, `__LINE__);
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
        read('b01_100, 3);
        `assert(access_port_rd_data == 64'hc0fef00d01234567);
        read('b01_101, 3);
        `assert(access_port_rd_data == 64'hfef00d0123456789);
        read('b01_110, 3);
        `assert(access_port_rd_data == 64'hf00d0123456789ab);
        read('b01_111, 3);
        `assert(access_port_rd_data == 64'h0d0123456789abcd);

        if (VERBOSE>0) $display("%s:%0d 8 bit access port tests.", `__FILE__, `__LINE__);
        #100
        read('b00_000, 0);
        `assert(access_port_rd_data == 64'hde);
        read('b00_001, 0);
        `assert(access_port_rd_data == 64'had);
        read('b01_010, 0);
        `assert(access_port_rd_data == 64'h1d);
        read('b01_011, 0);
        `assert(access_port_rd_data == 64'hea);
        read('b01_110, 0);
        `assert(access_port_rd_data == 64'hf0);
        read('b10_111, 0);
        `assert(access_port_rd_data == 64'hef);


        if (VERBOSE>0) $display("%s:%0d 16 bit access port tests.", `__FILE__, `__LINE__);
        #100
        read('b01_000, 1);
        `assert(access_port_rd_data == 64'habad);
        read('b00_001, 1);
        `assert(access_port_rd_data == 64'hadbe);
        read('b01_010, 1);
        `assert(access_port_rd_data == 64'h1dea);
        read('b01_011, 1);
        `assert(access_port_rd_data == 64'heac0);
        read('b01_110, 1);
        `assert(access_port_rd_data == 64'hf00d);
        read('b01_111, 1);
        `assert(access_port_rd_data == 64'h0d01);

        if (VERBOSE>0) $display("%s:%0d 32 bit access port tests.", `__FILE__, `__LINE__);
        #100
        read('b01_000, 2);
        `assert(access_port_rd_data == 64'habad1dea);
        read('b00_001, 2);
        `assert(access_port_rd_data == 64'hadbeef00);
        read('b01_010, 2);
        `assert(access_port_rd_data == 64'h1deac0fe);
        read('b01_011, 2);
        `assert(access_port_rd_data == 64'heac0fef0);
        read('b01_100, 2);
        `assert(access_port_rd_data == 64'hc0fef00d);
        read('b01_101, 2);
        `assert(access_port_rd_data == 64'hfef00d01);
        read('b01_110, 2);
        `assert(access_port_rd_data == 64'hf00d0123);
        read('b01_111, 2);
        `assert(access_port_rd_data == 64'h0d012345);

        $display("Test stop: %s:%0d.", `__FILE__, `__LINE__);
        #40 $finish;
      end

  always @(posedge i_clk or posedge i_areset)
  if (i_areset) begin
    rd_start_recieved <= 0;
    rd_read_recieved <= 0;
  end else if (dispatch_fifo_rd_start) begin
    rd_start_recieved <= 1;
  end else if (dispatch_packet_read) begin
    rd_read_recieved <= 1;
  end

  if (VERBOSE>1) begin
    always @(posedge i_clk)
      if (dispatch_packet_read==1) $display("%s:%0d dispatch_packet_read.", `__FILE__, `__LINE__);

    always @*
      $display("%s:%0d dispatch_packet_avialable: %b",  `__FILE__, `__LINE__, dispatch_packet_avialable);

    always @*
      $display("%s:%0d dispatch_fifo_empty: %b",  `__FILE__, `__LINE__, dispatch_fifo_empty);

    always @*
      $display("%s:%0d dispatch_fifo_rd_start: %b",  `__FILE__, `__LINE__, dispatch_fifo_rd_start);

    always @*
      $display("%s:%0d dut.memctrl_reg=%h", `__FILE__, `__LINE__, dut.memctrl_reg);
  end

  always begin
    #5 i_clk = ~i_clk;
  end

endmodule
