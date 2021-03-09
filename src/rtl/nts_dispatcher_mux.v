//======================================================================
//
// nts_dispatcher_mux.v
// --------------------
// NTS packet dispatcher MUX.
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

module nts_dispatcher_mux #(
  parameter ENGINES = 1
) (
  input wire         i_clk,
  input wire         i_areset,

  output wire        o_busy,
  output wire        o_ready,

  input  wire        i_discard,
  input  wire        i_start,
  input  wire        i_valid,
  input  wire  [3:0] i_valid4bit,
  input  wire [63:0] i_data,

  input  wire [ENGINES      - 1 : 0 ] i_dispatch_busy,
  input  wire [ENGINES      - 1 : 0 ] i_dispatch_ready,
  output wire [ENGINES * 4  - 1 : 0 ] o_dispatch_data_valid,
  output wire [ENGINES      - 1 : 0 ] o_dispatch_fifo_empty,
  output wire [ENGINES      - 1 : 0 ] o_dispatch_fifo_rd_start,
  output wire [ENGINES      - 1 : 0 ] o_dispatch_fifo_rd_valid,
  output wire [ENGINES * 64 - 1 : 0 ] o_dispatch_fifo_rd_data
);

  //----------------------------------------------------------------
  // Parameters
  //----------------------------------------------------------------

  localparam MUX_SEARCH = 0;
  localparam MUX_REMAIN = 1;

  //----------------------------------------------------------------
  // Engine(s) data bus wires
  //----------------------------------------------------------------

  reg  [4 * ENGINES - 1 : 0] engine_out_data_last_valid;
  reg      [ENGINES - 1 : 0] engine_out_fifo_empty;
  reg      [ENGINES - 1 : 0] engine_out_fifo_rd_start;
  reg      [ENGINES - 1 : 0] engine_out_fifo_rd_valid;
  reg [64 * ENGINES - 1 : 0] engine_out_fifo_rd_data;

  //----------------------------------------------------------------
  // Dispatcher MUX. Registers used to search for ready engine.
  //----------------------------------------------------------------

  reg engine_mux_ready_found_new;
  reg engine_mux_ready_found_reg;
  integer engine_mux_ready_index_new;
  integer engine_mux_ready_index_reg;
  reg [ENGINES-1:0] engine_mux_ready_engines_new;
  reg [ENGINES-1:0] engine_mux_ready_engines_reg;

  //----------------------------------------------------------------
  // Dispatcher MUX. Used to select one engine from many.
  //----------------------------------------------------------------

  reg             mux_ctrl_we;
  reg             mux_ctrl_new;
  reg             mux_ctrl_reg;
  reg             mux_index_we;
  integer         mux_index_new;
  integer         mux_index_reg;

  reg             mux_in_ready;

  //----------------------------------------------------------------
  // Wire assignments
  //----------------------------------------------------------------

  assign o_busy = mux_ctrl_reg != MUX_REMAIN;
  assign o_ready = mux_in_ready;

  assign o_dispatch_data_valid        = engine_out_data_last_valid;
  assign o_dispatch_fifo_rd_start     = engine_out_fifo_rd_start;
  assign o_dispatch_fifo_empty        = engine_out_fifo_empty;
  assign o_dispatch_fifo_rd_valid     = engine_out_fifo_rd_valid;
  assign o_dispatch_fifo_rd_data      = engine_out_fifo_rd_data;

  //----------------------------------------------------------------
  // Dispatcher MUX - Search
  //----------------------------------------------------------------

  always @*
  begin : dispatcher_mux_ready_search1
    integer i;
    for (i = 0; i < ENGINES; i = i + 1) begin
      engine_mux_ready_engines_new[i] = ~ i_dispatch_busy[i];
    end
  end

  always @*
  begin : dispatcher_mux_ready_search2
    integer i;
    integer j;

    engine_mux_ready_found_new = 0;
    engine_mux_ready_index_new = 0;

    for (i = 0; i < ENGINES; i = i + 1) begin
      j = ENGINES - 1 - i;
      if (engine_mux_ready_engines_reg[j]) begin
        engine_mux_ready_found_new = 1;
        engine_mux_ready_index_new = j;
      end
    end
  end

  //----------------------------------------------------------------
  // Dispatcher MUX
  //----------------------------------------------------------------

  always @*
  begin : dispatcher_mux
    reg        discard;
    reg        ready;
    reg        forward_mux;

    ready   = i_dispatch_ready[mux_index_reg];
    discard = i_discard;

    forward_mux = 0;

    mux_ctrl_we = 0;
    mux_ctrl_new = MUX_SEARCH;
    mux_index_we = 0;
    mux_index_new = 0;

    mux_in_ready                = 0;

    engine_out_data_last_valid  = 'h0;
    engine_out_fifo_rd_start    = 'b0;
    engine_out_fifo_empty       = {ENGINES{1'b1}};
    engine_out_fifo_rd_valid    = 'h0;
    engine_out_fifo_rd_data     = 'h0;


    case (mux_ctrl_reg)
      MUX_REMAIN:
        begin
          mux_in_ready                = ready;

          engine_out_data_last_valid[4*mux_index_reg+:4] = i_valid4bit;
          engine_out_fifo_empty[mux_index_reg]           = 0;
          engine_out_fifo_rd_start[mux_index_reg]        = i_start;
          engine_out_fifo_rd_valid[mux_index_reg]        = i_valid;
          engine_out_fifo_rd_data[64*mux_index_reg+:64]  = i_data;

          if (discard) begin
            engine_out_fifo_empty[mux_index_reg]         = 1;
            forward_mux = 1;
            mux_ctrl_we = 1;
            mux_ctrl_new = MUX_SEARCH;
          end
        end

      MUX_SEARCH:
        forward_mux = 1;

      default: ;
    endcase

    if (forward_mux) begin
      if (engine_mux_ready_found_reg) begin
        mux_ctrl_we = 1;
        mux_ctrl_new = MUX_REMAIN;
        mux_index_we  = 1;
        mux_index_new = engine_mux_ready_index_reg;
      end
    end
  end

  //----------------------------------------------------------------
  // Register Update
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin

      engine_mux_ready_engines_reg <= 0;
      engine_mux_ready_found_reg   <= 0;
      engine_mux_ready_index_reg   <= 0;

      mux_ctrl_reg  <= MUX_SEARCH;
      mux_index_reg <= ENGINES - 1;

    end else begin

      engine_mux_ready_engines_reg <= engine_mux_ready_engines_new;
      engine_mux_ready_found_reg   <= engine_mux_ready_found_new;
      engine_mux_ready_index_reg   <= engine_mux_ready_index_new;


      if (mux_ctrl_we)
        mux_ctrl_reg <= mux_ctrl_new;

      if (mux_index_we)
        mux_index_reg <= mux_index_new;

    end
  end

endmodule
