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

module bram_tb;
  parameter AW = 8;
  parameter DW = 64;

  reg clk;
  reg [AW-1:0] address;
  reg write_enable;
  reg [DW-1:0] data_in;
  wire [DW-1:0] data_out;

  bram #(.ADDR_WIDTH(8),.DATA_WIDTH(64)) ram_test (
    .i_clk(clk),
    .i_addr(address),
    .i_write(write_enable),
    .i_data(data_in),
    .o_data(data_out));

    initial
      begin
        $display("bram test.");
        clk = 1;

        #10 write_enable = 1;
        address = 0;
        data_in = 64'hdeadbeef00000000;
        #10 address = 1;
        data_in = 64'habad1deac0fef00d;

        #10 write_enable = 0;
        #10 $display("0x%08h", data_out);
        #10 address = 0;
        #10 $display("0x%08h", data_out);
        #10 address = 1;
        #10 $display("0x%08h", data_out);
        #40 $finish;
      end

  always begin
    #5 clk = ~clk;
  end

endmodule
