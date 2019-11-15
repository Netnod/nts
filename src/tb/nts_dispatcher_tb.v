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

module nts_dispatcher_tb;

  localparam ADDR_WIDTH=3;

  reg                   i_areset;
  reg                   i_clk;
  reg [7:0]             i_rx_data_valid;
  reg [63:0]            i_rx_data;
  reg                   i_rx_bad_frame;
  reg                   i_rx_good_frame;
  reg                   i_process_frame;
  wire                  o_dispatch_packet_available;
  reg                   i_dispatch_packet_read_discard;
  wire [ADDR_WIDTH-1:0] o_dispatch_counter;
  wire [7:0]            o_dispatch_data_valid;
  wire                  o_dispatch_fifo_empty;
  reg                   i_dispatch_fifo_rd_en;
  wire [63:0]           o_dispatch_fifo_rd_data;

  nts_dispatcher #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),
    .i_rx_data_valid(i_rx_data_valid),
    .i_rx_data(i_rx_data),
    .i_rx_bad_frame(i_rx_bad_frame),
    .i_rx_good_frame(i_rx_good_frame),
    .i_process_frame(i_process_frame),
    .o_dispatch_packet_available(o_dispatch_packet_available),
    .i_dispatch_packet_read_discard(i_dispatch_packet_read_discard),
    .o_dispatch_counter(o_dispatch_counter),
    .o_dispatch_data_valid(o_dispatch_data_valid),
    .o_dispatch_fifo_empty(o_dispatch_fifo_empty),
    .i_dispatch_fifo_rd_en(i_dispatch_fifo_rd_en),
    .o_dispatch_fifo_rd_data(o_dispatch_fifo_rd_data)
  );
  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s %d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end
  initial begin
    $display("Test start: %s %d", `__FILE__, `__LINE__);
    i_clk = 1;
    i_areset = 0;
    i_dispatch_packet_read_discard = 'b0;
    i_dispatch_fifo_rd_en = 'b0;
    i_rx_data_valid = 'b0;
    i_rx_data = 'b0;
    i_rx_bad_frame = 'b0;
    i_rx_good_frame = 'b0;
    i_process_frame = 'b0;
    #10 i_areset = 1;
    #10 i_areset = 0;
    `assert((o_dispatch_packet_available == 'b0));
    `assert((o_dispatch_counter == 'b0));
    `assert((o_dispatch_data_valid == 'b0));
    `assert((o_dispatch_fifo_empty == 'b1));
/*
    $display("%h", o_dispatch_packet_available);
    $display("%h", o_dispatch_counter);
    $display("%h", o_dispatch_data_valid);
    $display("%h", o_dispatch_rdata);
*/
    #10
    i_rx_data[63:32] = 'h01020304; i_rx_data[31:0] = 'h05060708;
    i_rx_data_valid = 'hff;
    `assert((o_dispatch_packet_available == 'b0));
    `assert((o_dispatch_counter == 'b0));

    #10
    i_rx_data[63:32] = 'h00000002; i_rx_data[31:0] = 'h20202020;
    i_rx_data_valid = 'hff;
    `assert(o_dispatch_packet_available == 'b0);

    #10
    i_rx_data[63:32] = 'h00000003; i_rx_data[31:0] = 'h30303030;
    i_rx_data_valid = 'hff;
    i_rx_good_frame = 'b1;
    `assert((o_dispatch_packet_available == 'b0));

    #10
    i_rx_data = 'b0;
    i_rx_data_valid = 'h00;
    i_rx_good_frame = 'b0;
    i_process_frame = 'b1;
    `assert((o_dispatch_packet_available == 'b0));

    #10
    `assert((o_dispatch_packet_available == 'b0));
    i_rx_data = 'b0;
    i_rx_data_valid = 'h00;
    i_rx_good_frame = 'b0;
    i_process_frame = 'b0;

    #10
    `assert((o_dispatch_packet_available == 'b1));
    `assert((o_dispatch_counter == 'h2));
    `assert((o_dispatch_data_valid == 'hff));
    `assert((o_dispatch_fifo_empty == 'b0));
    i_dispatch_fifo_rd_en = 'b1;

    #10
    `assert((o_dispatch_packet_available == 'b1));
    `assert((o_dispatch_counter == 'h2));
    `assert((o_dispatch_data_valid == 'hff));
    `assert((o_dispatch_fifo_empty == 'b0));
    `assert((o_dispatch_fifo_rd_data[63:32] == 'h01020304));
    `assert((o_dispatch_fifo_rd_data[31:0] == 'h05060708));
    i_dispatch_fifo_rd_en = 'b1;

    #10
    `assert((o_dispatch_packet_available == 'b1));
    `assert((o_dispatch_counter == 'h2));
    `assert((o_dispatch_data_valid == 'hff));
    `assert((o_dispatch_fifo_empty == 'b0));
    `assert((o_dispatch_fifo_rd_data[63:32] == 'h00000002));
    `assert((o_dispatch_fifo_rd_data[31:0] == 'h20202020));
    i_dispatch_fifo_rd_en = 'b1;

    #10
    `assert((o_dispatch_packet_available == 'b1));
    `assert((o_dispatch_counter == 'h2));
    `assert((o_dispatch_data_valid == 'hff));
    `assert((o_dispatch_fifo_empty == 'b1));
    `assert((o_dispatch_fifo_rd_data[63:32] == 'h00000003));
    `assert((o_dispatch_fifo_rd_data[31:0] == 'h30303030));
    i_dispatch_packet_read_discard = 'b1;
    i_dispatch_fifo_rd_en = 'b0;

    #10
    `assert((o_dispatch_packet_available == 'b0));
    i_dispatch_packet_read_discard = 'b0;
    $display("Test stop: %s %d", `__FILE__, `__LINE__);
    $finish;
  end
  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
