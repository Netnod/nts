//======================================================================
//
// counter32.v
// -----------
// 64-bit counter.
//
// Author: Peter Magnusson
//
//
// Copyright (c) 2019, Netnod Internet Exchange i Sverige AB (Netnod).
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
//======================================================================
//

module counter32 (
  input  wire i_areset, // async reset
  input  wire i_clk,

  input  wire i_inc,
  input  wire i_rst,

  output wire [31:0] o_lsb
);
  reg        op_inc_reg;
  reg        op_rst_reg;

  reg        counter_lsb_we;
  reg [31:0] counter_lsb_new;
  reg [31:0] counter_lsb_reg;

  assign o_lsb = counter_lsb_reg;

  //----------------------------------------------------------------
  // Counter MSB, LSB outs
  //----------------------------------------------------------------

  always @*
  begin
    counter_lsb_we  = 0;
    counter_lsb_new = 0;

    counter_lsb_we  = 1;
    counter_lsb_new = counter_lsb_reg + 1;

    if (op_rst_reg) begin
      counter_lsb_we  = 1;
      counter_lsb_new = 0;
    end
  end

  //----------------------------------------------------------------
  // Register update
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_up
    if (i_areset) begin
      op_inc_reg          <= 0;
      op_rst_reg          <= 0;
      counter_lsb_reg     <= 0;
    end else begin
      op_inc_reg       <= i_inc;
      op_rst_reg       <= i_rst;

      if (counter_lsb_we)
       counter_lsb_reg <= counter_lsb_new;
    end
  end

endmodule
