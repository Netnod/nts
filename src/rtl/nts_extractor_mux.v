//======================================================================
//
// nts_extractor_mux.v
// -------------------
// MUX for the NTS packet extractor.
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

module nts_extractor_mux #(
  parameter ADDR_WIDTH = 8,
  parameter ENGINES = 1
) (
  input  wire i_areset, // async reset
  input  wire i_clk,

  input  wire      [ENGINES - 1 : 0] i_engine_packet_available,
  output wire      [ENGINES - 1 : 0] o_engine_packet_read,
  input  wire      [ENGINES - 1 : 0] i_engine_fifo_empty,
  output wire      [ENGINES - 1 : 0] o_engine_fifo_rd_start,
  input  wire      [ENGINES - 1 : 0] i_engine_fifo_rd_valid,
  input  wire [64 * ENGINES - 1 : 0] i_engine_fifo_rd_data,
  input  wire  [4 * ENGINES - 1 : 0] i_engine_bytes_last_word,

  output wire o_buffer_ready,
  input  wire i_buffer_start,
  input  wire i_buffer_stop,

  output wire [ADDR_WIDTH-1:0] o_buffer_length,
  output wire            [3:0] o_buffer_lwdv,

  output wire [ADDR_WIDTH-1:0] o_buffer_wr_addr,
  output wire                  o_buffer_wr_en,
  output wire           [63:0] o_buffer_wr_data

);
  localparam [1:0] BUFFER_STATE_UNUSED  = 2'b00;
  localparam [1:0] BUFFER_STATE_WRITING = 2'b01;
  localparam [1:0] BUFFER_STATE_LOADED  = 2'b10;
  localparam [1:0] BUFFER_STATE_READING = 2'b11;

  localparam [1:0] ENGINE_READER_IDLE    = 2'b00;
  localparam [1:0] ENGINE_READER_START   = 2'b01;
  localparam [1:0] ENGINE_READER_READING = 2'b10;
  localparam [1:0] ENGINE_READER_STOP    = 2'b11;

  localparam ENGINESELBITS =
     (ENGINES>128) ? 8 :
     (ENGINES>64)  ? 7 :
     (ENGINES>32)  ? 6 :
     (ENGINES>16)  ? 5 :
     (ENGINES>8)   ? 4 :
     (ENGINES>4)   ? 3 :
     (ENGINES>2)   ? 2 : 1;

  localparam              [31:0] ENGINE_LAST32 = ENGINES - 1;
  localparam [ENGINESELBITS-1:0] ENGINE_LAST   = ENGINE_LAST32[ENGINESELBITS-1:0];

  localparam MUX_SEARCH = 0;
  localparam MUX_REMAIN = 1;

  //----------------------------------------------------------------
  // Buffer Wires
  //----------------------------------------------------------------

  reg [ADDR_WIDTH-1:0] buffer_wr_addr;
  reg                  buffer_wr_en;
  reg           [63:0] buffer_wr_data;

  //----------------------------------------------------------------
  // Buffer Regs
  //----------------------------------------------------------------

  reg                  buffer_addr_we;
  reg [ADDR_WIDTH-1:0] buffer_addr_new;
  reg [ADDR_WIDTH-1:0] buffer_addr_reg;

  reg       buffer_lwdv_we;
  reg [3:0] buffer_lwdv_new;
  reg [3:0] buffer_lwdv_reg;

  reg       buffer_state_we;
  reg [1:0] buffer_state_new;
  reg [1:0] buffer_state_reg;

  assign o_buffer_wr_addr = buffer_wr_addr;
  assign o_buffer_wr_en   = buffer_wr_en;
  assign o_buffer_wr_data = buffer_wr_data;

  assign o_buffer_ready  = buffer_state_reg == BUFFER_STATE_LOADED;
  assign o_buffer_lwdv   = buffer_lwdv_reg;
  assign o_buffer_length = buffer_addr_reg;

  //reg error_illegal_start_inc;
  //reg error_illegal_discard_inc;

  //----------------------------------------------------------------
  // Engine Reader Regs
  //----------------------------------------------------------------

  //Delay inputs to reduce timing requirements on engines
  reg        engine_reader_delay_ready_new;
  reg        engine_reader_delay_ready_reg;
  reg  [3:0] engine_reader_delay_lwdv_new;
  reg  [3:0] engine_reader_delay_lwdv_reg;
  reg        engine_reader_delay_valid_new;
  reg        engine_reader_delay_valid_reg;
  reg [63:0] engine_reader_delay_data_new;
  reg [63:0] engine_reader_delay_data_reg;
  reg        engine_reader_delay_empty_new;
  reg        engine_reader_delay_empty_reg;


  reg        engine_reader_fsm_we;
  reg  [1:0] engine_reader_fsm_new;
  reg  [1:0] engine_reader_fsm_reg;
  reg        engine_reader_data_we;
  reg [63:0] engine_reader_data_new;
  reg [63:0] engine_reader_data_reg;
  reg        engine_reader_data_valid_new;
  reg        engine_reader_data_valid_reg;
  reg        engine_reader_lwdv_we;
  reg  [3:0] engine_reader_lwdv_new;
  reg  [3:0] engine_reader_lwdv_reg;
  reg        engine_reader_start_new;
  reg        engine_reader_start_reg;
  reg        engine_reader_stop_new;
  reg        engine_reader_stop_reg;

  reg engine_packet_read_new;
  reg engine_packet_read_reg;
  reg engine_fifo_rd_start_new;
  reg engine_fifo_rd_start_reg;

  //----------------------------------------------------------------
  // Extractor MUX - Search Registers
  //----------------------------------------------------------------

  reg               engine_mux_start_ready_search;
  reg [ENGINES-1:0] engine_mux_ready_engines_new;
  reg [ENGINES-1:0] engine_mux_ready_engines_reg;

  reg engine_mux_ready_found_new;
  reg engine_mux_ready_found_reg;

  reg [ENGINESELBITS-1:0] engine_mux_ready_index_new;
  reg [ENGINESELBITS-1:0] engine_mux_ready_index_reg;

  reg engine_mux_ready_fast_found_new;
  reg engine_mux_ready_fast_found_reg;

  reg [ENGINESELBITS-1:0] engine_mux_ready_fast_index_new;
  reg [ENGINESELBITS-1:0] engine_mux_ready_fast_index_reg;

  //----------------------------------------------------------------
  // Extractor MUX - Registers
  //----------------------------------------------------------------

  reg      mux_in_ctrl_we;
  reg      mux_in_ctrl_new;
  reg      mux_in_ctrl_reg;

  reg                     mux_in_index_we;
  reg [ENGINESELBITS-1:0] mux_in_index_new;
  reg [ENGINESELBITS-1:0] mux_in_index_reg;

  //----------------------------------------------------------------
  // Extractor MUX - Wires
  //----------------------------------------------------------------

  reg [ENGINES - 1 : 0] mux_out_packet_read;
  reg [ENGINES - 1 : 0] mux_out_fifo_rd_start;

  reg           mux_in_packet_available;
  reg           mux_in_fifo_empty;
  reg           mux_in_fifo_rd_valid;
  reg  [63 : 0] mux_in_fifo_rd_data;
  reg   [3 : 0] mux_in_bytes_last_word;

  assign o_engine_packet_read   = mux_out_packet_read;
  assign o_engine_fifo_rd_start = mux_out_fifo_rd_start;

  //----------------------------------------------------------------
  // Extractor MUX - Search
  //----------------------------------------------------------------

  always @*
  begin : extractor_mux_ready_search1
    integer i;
    for (i = 0; i < ENGINES; i = i + 1) begin
      engine_mux_ready_engines_new[i] = i_engine_packet_available[i] && i_engine_fifo_empty[i] == 1'b0;
    end
  end

  always @*
  begin : extractor_mux_ready_search2
    reg found;

    engine_mux_ready_found_new = 0;

    if (engine_mux_ready_index_reg == 0) begin
      engine_mux_ready_index_new = ENGINE_LAST;
    end else begin
      engine_mux_ready_index_new = engine_mux_ready_index_reg - 1;
    end

    found = 0;

    if (engine_mux_ready_engines_reg[engine_mux_ready_index_reg]) begin
      found = 1;
    end

    if (engine_mux_ready_index_reg == mux_in_index_reg) begin
      if (mux_in_ctrl_reg == MUX_REMAIN) begin
        found = 0; //Do not find your self while processing yourself
      end
    end

    if (found) begin
      engine_mux_ready_found_new = 1;
      engine_mux_ready_index_new = engine_mux_ready_index_reg;
    end

    if (engine_mux_start_ready_search) begin
      engine_mux_ready_found_new = 0;
    end
  end

  always @*
  begin : extractor_mux_ready_search3
    integer i;
    reg [ENGINESELBITS-1:0] index;
    engine_mux_ready_fast_found_new = 0;
    engine_mux_ready_fast_index_new = 0;
    for (i = 0; i < ENGINES; i = i + 1) begin
      index = i[ENGINESELBITS-1:0];
      if (engine_mux_ready_engines_reg[index]) begin
        if (mux_in_ctrl_reg == MUX_SEARCH) begin
          engine_mux_ready_fast_found_new = 1;
          engine_mux_ready_fast_index_new = index;
        end else begin
          if (index != mux_in_index_reg) begin
            engine_mux_ready_fast_found_new = 1;
            engine_mux_ready_fast_index_new = index;
          end
        end
      end
    end
  end

  //----------------------------------------------------------------
  // Extractor MUX
  //----------------------------------------------------------------

  always @*
  begin : extractor_mux
    reg        available;
    reg        discard;
    reg [63:0] fifo_data;
    reg        fifo_empty;
    reg        fifo_valid;
    reg        forward_mux;
    reg  [3:0] lwdv; //last word data valid, value 1..8 (bytes).
    reg        start;

    available   = i_engine_packet_available[mux_in_index_reg];
    discard     = engine_packet_read_reg;
    fifo_data   = i_engine_fifo_rd_data[64*mux_in_index_reg+:64];
    fifo_empty  = i_engine_fifo_empty[mux_in_index_reg];
    fifo_valid  = i_engine_fifo_rd_valid[mux_in_index_reg];
    forward_mux = 0;
    lwdv        = i_engine_bytes_last_word[4*mux_in_index_reg+:4];
    start       = engine_fifo_rd_start_reg;

    //error_illegal_start_inc = 0;
    //error_illegal_discard_inc = 0;

    engine_mux_start_ready_search = 0;

    mux_in_ctrl_we = 0;
    mux_in_ctrl_new = MUX_SEARCH;
    mux_in_index_we = 0;
    mux_in_index_new = 0;

    mux_in_packet_available = 0;
    mux_in_fifo_empty       = 0;
    mux_in_fifo_rd_valid    = 0;
    mux_in_fifo_rd_data     = 0;
    mux_in_bytes_last_word  = 0;

    mux_out_fifo_rd_start = 0;
    mux_out_fifo_rd_start[mux_in_index_reg] = start;

    mux_out_packet_read = 0;
    mux_out_packet_read[mux_in_index_reg] = discard;

    case (mux_in_ctrl_reg)
      MUX_REMAIN:
        begin
          mux_in_fifo_empty       = fifo_empty;
          mux_in_fifo_rd_data     = fifo_data;
          mux_in_fifo_rd_valid    = fifo_valid;
          mux_in_packet_available = available;
          mux_in_bytes_last_word  = lwdv;
          if (discard) begin
            forward_mux = 1;
            mux_in_ctrl_we = 1;
            mux_in_ctrl_new = MUX_SEARCH;
          end
        end
      MUX_SEARCH:
        begin
          if (available) begin
            mux_in_ctrl_we = 1;
            mux_in_ctrl_new = MUX_REMAIN;
            engine_mux_start_ready_search = 1;
          end else begin
            forward_mux = 1;
          end
          //if (start) error_illegal_start_inc = 1;
          //if (discard) error_illegal_discard_inc = 1;
        end
      default: ;
    endcase

    if (forward_mux) begin
      if (engine_mux_ready_found_reg) begin
        mux_in_index_we  = 1;
        mux_in_index_new = engine_mux_ready_index_reg;
      end else if (engine_mux_ready_fast_found_reg) begin
        mux_in_index_we  = 1;
        mux_in_index_new = engine_mux_ready_fast_index_reg;
      end
    end
  end

  //----------------------------------------------------------------
  // Engine_reader process
  // Copies data from engine to internal temporary register
  //----------------------------------------------------------------

  always @*
  begin : engine_reader
    engine_fifo_rd_start_new = 0;
    engine_packet_read_new = 0;

    engine_reader_fsm_we = 0;
    engine_reader_fsm_new = 0;

    engine_reader_data_we = 0;
    engine_reader_data_new = 0;

    engine_reader_data_valid_new = 0;

    engine_reader_lwdv_we = 0;
    engine_reader_lwdv_new = 0;

    engine_reader_start_new = 0;

    engine_reader_stop_new = 0;

    engine_reader_delay_ready_new = mux_in_packet_available && mux_in_fifo_empty==1'b0;
    engine_reader_delay_lwdv_new = mux_in_bytes_last_word;
    engine_reader_delay_valid_new = mux_in_fifo_rd_valid;
    engine_reader_delay_data_new = mux_in_fifo_rd_data;
    engine_reader_delay_empty_new = mux_in_fifo_empty;

    case (engine_reader_fsm_reg)
      ENGINE_READER_IDLE:
        if (buffer_state_reg == BUFFER_STATE_UNUSED) begin
          if (engine_reader_delay_ready_reg) begin
            engine_reader_fsm_we = 1;
            engine_reader_fsm_new = ENGINE_READER_START;
          end
        end
      ENGINE_READER_START:
        begin
          engine_fifo_rd_start_new = 1;
          engine_reader_fsm_we = 1;
          engine_reader_fsm_new = ENGINE_READER_READING;
          engine_reader_lwdv_we = 1;
          engine_reader_lwdv_new = engine_reader_delay_lwdv_reg;
          engine_reader_start_new = 1;
        end
      ENGINE_READER_READING:
        if (engine_reader_delay_valid_reg) begin
          engine_reader_data_we = 1;
          engine_reader_data_new = engine_reader_delay_data_reg;
          engine_reader_data_valid_new = 1;
        end else if (engine_reader_delay_empty_reg) begin
          engine_reader_fsm_we = 1;
          engine_reader_fsm_new = ENGINE_READER_STOP;
        end
      ENGINE_READER_STOP:
        begin
          engine_packet_read_new = 1;
          engine_reader_stop_new = 1;
          engine_reader_fsm_we = 1;
          engine_reader_fsm_new = ENGINE_READER_IDLE;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Buffer writer process
  // Copies data from internal temporary register to buffers
  //----------------------------------------------------------------

  always @*
  begin : buffer_writer
    buffer_addr_we = 0;
    buffer_addr_new = 0;
    buffer_lwdv_we = 0;
    buffer_lwdv_new = 0;
    buffer_state_we = 0;
    buffer_state_new = 0;

    buffer_wr_addr = 0;
    buffer_wr_en = 0;
    buffer_wr_data = 0;

    case (buffer_state_reg)
      BUFFER_STATE_UNUSED:
        if (engine_reader_start_reg) begin
          buffer_addr_we = 1;
          buffer_addr_new = 0;
          buffer_lwdv_we = 1;
          buffer_lwdv_new = engine_reader_lwdv_reg;
          buffer_state_we = 1;
          buffer_state_new = BUFFER_STATE_WRITING;
        end
      BUFFER_STATE_WRITING:
        if (engine_reader_data_valid_reg) begin
          buffer_addr_we = 1;
          buffer_addr_new = buffer_addr_reg + 1;
          buffer_wr_addr = buffer_addr_reg;
          buffer_wr_en = 1'b1;
          buffer_wr_data = engine_reader_data_reg;
        end else if (engine_reader_stop_reg) begin
          buffer_state_we = 1;
          buffer_state_new = BUFFER_STATE_LOADED;
        end
      BUFFER_STATE_LOADED: ;
      BUFFER_STATE_READING: ;
    endcase

    if (i_buffer_stop) begin
      buffer_state_we = 1;
      buffer_state_new = BUFFER_STATE_UNUSED;
    end

    if (i_buffer_start) begin
      buffer_state_we = 1;
      buffer_state_new = BUFFER_STATE_READING;
    end
  end

  //----------------------------------------------------------------
  // Register Update
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      buffer_addr_reg <= 0;
      buffer_state_reg <= 0;
      buffer_lwdv_reg <= 0;
      engine_reader_delay_ready_reg <= 0;
      engine_reader_delay_lwdv_reg  <= 0;
      engine_reader_delay_valid_reg <= 0;
      engine_reader_delay_data_reg  <= 0;
      engine_reader_delay_empty_reg <= 0;
      engine_fifo_rd_start_reg <= 0;
      engine_packet_read_reg <= 0;
      engine_reader_fsm_reg <= 0;
      engine_reader_data_reg <= 0;
      engine_reader_data_valid_reg <= 0;
      engine_reader_lwdv_reg <= 0;
      engine_reader_start_reg <= 0;
      engine_reader_stop_reg <= 0;
      engine_mux_ready_engines_reg <= 0;
      engine_mux_ready_found_reg <= 0;
      engine_mux_ready_index_reg <= 0;
      engine_mux_ready_fast_found_reg <= 0;
      engine_mux_ready_fast_index_reg <= 0;
      mux_in_ctrl_reg  <= MUX_SEARCH;
      mux_in_index_reg <= 0;

    end else begin

      if (buffer_addr_we)
        buffer_addr_reg <= buffer_addr_new;

      if (buffer_lwdv_we)
        buffer_lwdv_reg <= buffer_lwdv_new;

      if (buffer_state_we)
        buffer_state_reg <= buffer_state_new;

      engine_reader_delay_ready_reg <= engine_reader_delay_ready_new;
      engine_reader_delay_lwdv_reg  <= engine_reader_delay_lwdv_new;
      engine_reader_delay_valid_reg <= engine_reader_delay_valid_new;
      engine_reader_delay_data_reg  <= engine_reader_delay_data_new;
      engine_reader_delay_empty_reg <= engine_reader_delay_empty_new;

      engine_fifo_rd_start_reg <= engine_fifo_rd_start_new;

      engine_mux_ready_engines_reg <= engine_mux_ready_engines_new;
      engine_mux_ready_found_reg <= engine_mux_ready_found_new;
      engine_mux_ready_index_reg <= engine_mux_ready_index_new;
      engine_mux_ready_fast_found_reg <= engine_mux_ready_fast_found_new;
      engine_mux_ready_fast_index_reg <= engine_mux_ready_fast_index_new;

      engine_packet_read_reg <= engine_packet_read_new;

      if (engine_reader_fsm_we)
        engine_reader_fsm_reg <= engine_reader_fsm_new;

      if (engine_reader_data_we)
        engine_reader_data_reg <= engine_reader_data_new;

      engine_reader_data_valid_reg <= engine_reader_data_valid_new;

      if (engine_reader_lwdv_we)
        engine_reader_lwdv_reg <= engine_reader_lwdv_new;

      engine_reader_start_reg <= engine_reader_start_new;
      engine_reader_stop_reg <= engine_reader_stop_new;

      if (mux_in_ctrl_we)
        mux_in_ctrl_reg <= mux_in_ctrl_new;

      if (mux_in_index_we)
        mux_in_index_reg <= mux_in_index_new;

    end
  end

endmodule
