//======================================================================
//
// bram_dp2w.v
// ------------
// Dual-Port RAM.
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


module bram_dp2w #(
    //Parameters
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 64
  ) (
    input i_clk,
    input i_en_a,
    input i_en_b,
    input i_we_a,
    input i_we_b,

    input  [ADDR_WIDTH-1:0] i_addr_a,
    input  [ADDR_WIDTH-1:0] i_addr_b,

    input  [DATA_WIDTH-1:0] i_data_a,
    input  [DATA_WIDTH-1:0] i_data_b,

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
    if (i_en_a)
      begin
        if (i_we_a)
          ram[i_addr_a] <= i_data_a;
        doa <= ram[i_addr_a];
      end
  end

  always @(posedge i_clk)
  begin
    if (i_en_b)
      begin
        if (i_we_b)
          ram[i_addr_b] <= i_data_b;
        dob <= ram[i_addr_b];
      end
  end

endmodule
