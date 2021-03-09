//======================================================================
//
// counter64.v
// -----------
// 64-bit counter.
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
//

module counter64 (
  input  wire i_areset, // async reset
  input  wire i_clk,

  input  wire i_inc,
  input  wire i_rst,
  input  wire i_lsb_sample,

  output wire [31:0] o_msb,
  output wire [31:0] o_lsb
);
  reg        op_inc_reg;
  reg        op_rst_reg;

  reg        counter_lsb_we;
  reg [31:0] counter_lsb_new;
  reg [31:0] counter_lsb_reg;

  reg        counter_msb_we;
  reg [31:0] counter_msb_new;
  reg [31:0] counter_msb_reg;

  reg        sample_lsb_we;
  reg [31:0] sample_lsb_new;
  reg [31:0] sample_lsb_reg;

  assign o_msb = counter_msb_reg;
  assign o_lsb = sample_lsb_reg;

  //----------------------------------------------------------------
  // Counter MSB, LSB outs
  //----------------------------------------------------------------

  always @*
  begin
    counter_lsb_we  = 0;
    counter_lsb_new = 0;
    counter_msb_we  = 0;
    counter_msb_new = 0;
    sample_lsb_we   = 0;
    sample_lsb_new  = 0;

    if (op_inc_reg) begin
      if (counter_lsb_reg == 32'hffff_ffff) begin
        counter_msb_we  = 1;
        counter_msb_new = counter_msb_reg + 1;
      end
      counter_lsb_we  = 1;
      counter_lsb_new = counter_lsb_reg + 1;
    end

    if (i_lsb_sample) begin
      sample_lsb_we  = 1;
      sample_lsb_new = counter_lsb_reg;
    end

    if (op_rst_reg) begin
      counter_lsb_we  = 1;
      counter_lsb_new = 0;
      counter_msb_we  = 1;
      counter_msb_new = 0;
      sample_lsb_we   = 1;
      sample_lsb_new  = 0;
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
      counter_msb_reg     <= 0;
      sample_lsb_reg      <= 0;
    end else begin
      op_inc_reg       <= i_inc;
      op_rst_reg       <= i_rst;

      if (counter_lsb_we)
       counter_lsb_reg <= counter_lsb_new;

      if (counter_msb_we)
       counter_msb_reg <= counter_msb_new;

      if (sample_lsb_we)
        sample_lsb_reg <= sample_lsb_new;

    end
  end

endmodule
