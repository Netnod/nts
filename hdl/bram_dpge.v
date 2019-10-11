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

// Dual-Port RAM with One Enable Controlling Both Ports
// Derived from Xilinx X9744

module bram_dpge #(
    //Parameters
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 64
  ) (
    input i_clk,
    input i_en,
    input i_we_a,

    input  [ADDR_WIDTH-1:0] i_addr_a,
    input  [ADDR_WIDTH-1:0] i_addr_b,
    input  [DATA_WIDTH-1:0] i_data,

    output [DATA_WIDTH-1:0] o_data_a,
    output [DATA_WIDTH-1:0] o_data_b
 );
  //Parameterized constant
  localparam DEPTH = 2**ADDR_WIDTH;

  //Synchronios clocked registers
  (* ram_style = "block" *) reg  [DATA_WIDTH-1:0] ram [DEPTH-1:0]; /* Xilinx: will map to Block RAM */

  reg [DATA_WIDTH-1:0] doa;
  reg [DATA_WIDTH-1:0] dob;

  //Outputs
  assign o_data_a = doa;
  assign o_data_b = dob;

  always @(posedge i_clk)
  begin
    if (i_en)
      begin
        if (i_we_a)
          ram[i_addr_a] <= i_data;
        doa <= ram[i_addr_a];
      end
  end

  always @(posedge i_clk)
  begin
    if (i_en)
      begin
        dob <= ram[i_addr_b];
      end
  end

endmodule
