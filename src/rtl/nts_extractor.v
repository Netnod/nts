//
// Copyright (c) 2020, The Swedish Post and Telecom Authority (PTS)
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

module nts_extractor #(
  parameter API_ADDR_WIDTH = 12,
  parameter API_ADDR_BASE  = 'h400,
  parameter ENGINES        = 1
) (
  input  wire        i_areset, // async reset
  input  wire        i_clk,

  input  wire                        i_api_cs,
  input  wire                        i_api_we,
  input  wire [API_ADDR_WIDTH - 1:0] i_api_address,
  input  wire                 [31:0] i_api_write_data,
  output wire                 [31:0] o_api_read_data,

  input  wire      [ENGINES - 1 : 0] i_engine_packet_available,
  output wire      [ENGINES - 1 : 0] o_engine_packet_read,
  input  wire      [ENGINES - 1 : 0] i_engine_fifo_empty,
  output wire      [ENGINES - 1 : 0] o_engine_fifo_rd_start,
  input  wire      [ENGINES - 1 : 0] i_engine_fifo_rd_valid,
  input  wire [64 * ENGINES - 1 : 0] i_engine_fifo_rd_data,
  input  wire  [4 * ENGINES - 1 : 0] i_engine_bytes_last_word,

  output wire        o_mac_tx_start,
  input  wire        i_mac_tx_ack,
  output wire  [7:0] o_mac_tx_data_valid,
  output wire [63:0] o_mac_tx_data
);
  //----------------------------------------------------------------
  // Local parameters, constants, definitions etc
  //----------------------------------------------------------------

  localparam BRAM_WIDTH = 10;
  localparam ADDR_WIDTH = 8;

  localparam BUFFER_SELECT_ADDRESS_WIDTH = BRAM_WIDTH - ADDR_WIDTH;
  localparam BUFFERS = 1<<BUFFER_SELECT_ADDRESS_WIDTH;
  localparam [BUFFER_SELECT_ADDRESS_WIDTH-1:0] BUFFER_FIRST = 0;
  localparam [BUFFER_SELECT_ADDRESS_WIDTH-1:0] BUFFER_LAST = ~ BUFFER_FIRST;

  localparam [0:0] ENGINE_READER_IDLE    = 1'b0;
  localparam [0:0] ENGINE_READER_READING = 1'b1;

  localparam [1:0] BUFFER_STATE_UNUSED  = 2'b00;
  localparam [1:0] BUFFER_STATE_WRITING = 2'b01;
  localparam [1:0] BUFFER_STATE_LOADED  = 2'b10;
  localparam [1:0] BUFFER_STATE_READING = 2'b11;

  localparam TX_IDLE         = 3'd0;
  localparam TX_AWAIT_ACK    = 3'd1;
  localparam TX_WRITE        = 3'd2;
  localparam TX_SILENT_CYCLE = 3'd3;

  localparam ADDR_NAME0             = API_ADDR_BASE + 0;
  localparam ADDR_NAME1             = API_ADDR_BASE + 1;
  localparam ADDR_VERSION           = API_ADDR_BASE + 2;
  localparam ADDR_DUMMY             = API_ADDR_BASE + 3;
  localparam ADDR_BYTES             = API_ADDR_BASE + 'ha;
  localparam ADDR_PACKETS           = API_ADDR_BASE + 'hc;
  localparam ADDR_MUX_STATE         = API_ADDR_BASE + 'h20;
  localparam ADDR_MUX_INDEX         = API_ADDR_BASE + 'h21;
  localparam ADDR_DEBUG_TX          = API_ADDR_BASE + 'h30;
  localparam ADDR_ERROR_STARTS      = API_ADDR_BASE + 'h40;
  localparam ADDR_ERROR_DISCARDS    = API_ADDR_BASE + 'h41;

  localparam CORE_NAME    = 64'h4e_54_53_2d_45_58_54_52; //NTS-EXTR
  localparam CORE_VERSION = 32'h30_2e_30_34; //0.04

  localparam MUX_SEARCH = 0;
  localparam MUX_REMAIN = 1;

  //----------------------------------------------------------------
  // Asynchrononous registers
  //----------------------------------------------------------------

  reg                  buffer_initilized_we;
  reg    [BUFFERS-1:0] buffer_initilized_new;
  reg    [BUFFERS-1:0] buffer_initilized_reg;
  reg [ADDR_WIDTH-1:0] buffer_addr_reg  [0:BUFFERS-1];
  reg            [3:0] buffer_lwdv_reg  [0:BUFFERS-1];
  reg            [1:0] buffer_state_reg [0:BUFFERS-1];

  reg                   buffer_engine_addr_we;
  reg  [ADDR_WIDTH-1:0] buffer_engine_addr_new;

  reg       buffer_engine_lwdv_we;
  reg [3:0] buffer_engine_lwdv_new;

  reg                                   buffer_engine_selected_we;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_engine_selected_new;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_engine_selected_reg;

  reg        buffer_engine_state_we;
  reg  [1:0] buffer_engine_state_new;
  reg                                   buffer_mac_selected_we;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_mac_selected_new;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_mac_selected_reg;

  reg [ADDR_WIDTH-1:0] buffer_mac_addr;

  reg        buffer_mac_state_we;
  reg  [1:0] buffer_mac_state_new;

  reg        counter_bytes_rst;
  reg        counter_bytes_we;
  reg [63:0] counter_bytes_new;
  reg [63:0] counter_bytes_reg;
  reg        counter_bytes_lsb_we;
  reg [31:0] counter_bytes_lsb_reg;

  reg        counter_packets_rst;
  reg        counter_packets_we;
  reg [63:0] counter_packets_new;
  reg [63:0] counter_packets_reg;
  reg        counter_packets_lsb_we;
  reg [31:0] counter_packets_lsb_reg;

  reg [31:0] debug_tx_new;
  reg [31:0] debug_tx_reg;

  reg        dummy_we;
  reg [31:0] dummy_new;
  reg [31:0] dummy_reg;

  reg        engine_reader_fsm_we;
  reg  [0:0] engine_reader_fsm_new;
  reg  [0:0] engine_reader_fsm_reg;
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

  //internal logic errors. Should never occur.
  reg        error_illegal_discard_inc;
  reg [31:0] error_illegal_discard_reg;
  reg        error_illegal_start_inc;
  reg [31:0] error_illegal_start_reg;

  reg engine_packet_read_new;
  reg engine_packet_read_reg;
  reg engine_fifo_rd_start_new;
  reg engine_fifo_rd_start_reg;

  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] tx_buffer;
  reg                  [ADDR_WIDTH-1:0] tx_count;
  reg                  [ADDR_WIDTH-1:0] tx_last;
  reg                             [7:0] tx_lwdv;

  reg           [63:0] txmem [ 0 : (1<<BRAM_WIDTH)-1 ];
  reg [BRAM_WIDTH-1:0] txmem_addr;
  reg           [63:0] txmem_wdata;
  reg                  txmem_wren;

  reg [2:0] tx_state;

  //----------------------------------------------------------------
  // Synchrononous registers
  //----------------------------------------------------------------

  //Reset wires
  reg sync_reset_metastable;
  reg sync_reset;

  // Registers between engine input read and ram writes to relax timing requirements
  reg [BRAM_WIDTH-1:0] write_addr_new;
  reg [BRAM_WIDTH-1:0] write_addr_reg;
  reg                  write_wren_new;
  reg                  write_wren_reg;
  reg           [63:0] write_wdata_new;
  reg           [63:0] write_wdata_reg;

  //----------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------

  reg [31:0] api_read_data;

  reg [ADDR_WIDTH-1:0] buffer_engine_addr;
  reg            [1:0] buffer_engine_state;
  reg            [1:0] buffer_mac_state;

  reg  [7:0] mac_data_valid;
  reg [63:0] mac_data;
  reg        mac_start;

  reg                                   tx_start;
  reg                  [ADDR_WIDTH-1:0] tx_start_last;
  reg                             [7:0] tx_start_lwdv;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] tx_start_buffer;
  reg                                   tx_stop;

  //----------------------------------------------------------------
  // Extractor MUX - Search Registers
  //----------------------------------------------------------------

  reg               engine_mux_start_ready_search;
  reg [ENGINES-1:0] engine_mux_ready_engines_new;
  reg [ENGINES-1:0] engine_mux_ready_engines_reg;
  reg engine_mux_ready_found_new;
  reg engine_mux_ready_found_reg;
  integer engine_mux_ready_index_new;
  integer engine_mux_ready_index_reg;

  //----------------------------------------------------------------
  // Extractor MUX - Registers
  //----------------------------------------------------------------

  reg      mux_in_ctrl_we;
  reg      mux_in_ctrl_new;
  reg      mux_in_ctrl_reg;
  reg      mux_in_index_we;
  integer  mux_in_index_new;
  integer  mux_in_index_reg;

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

  //----------------------------------------------------------------
  // Wire assignments
  //----------------------------------------------------------------

  assign o_api_read_data = api_read_data;

  assign o_mac_tx_data = mac_data;
  assign o_mac_tx_data_valid = mac_data_valid;
  assign o_mac_tx_start = mac_start;

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
      engine_mux_ready_index_new = ENGINES - 1;
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
      if (mux_in_index_reg == 0) begin
        engine_mux_ready_index_new = ENGINES - 1;
      end else begin
        engine_mux_ready_index_new = mux_in_index_reg - 1;
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

    error_illegal_start_inc = 0;
    error_illegal_discard_inc = 0;

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
          if (start) error_illegal_start_inc = 1;
          if (discard) error_illegal_discard_inc = 1;
        end
      default: ;
    endcase

    if (forward_mux) begin
      if (engine_mux_ready_found_reg) begin
        mux_in_index_we  = 1;
        mux_in_index_new = engine_mux_ready_index_reg;
      end
    end
  end

  //----------------------------------------------------------------
  // Buffers
  //----------------------------------------------------------------

  always @*
  begin
    buffer_engine_addr = 0;
    buffer_engine_state = BUFFER_STATE_UNUSED;
    buffer_mac_addr = 0;
    buffer_mac_state = BUFFER_STATE_UNUSED;

    if (buffer_initilized_reg[buffer_engine_selected_reg]) begin
      buffer_engine_addr = buffer_addr_reg[buffer_engine_selected_reg];
      buffer_engine_state = buffer_state_reg[buffer_engine_selected_reg];
    end

    if (buffer_initilized_reg[buffer_mac_selected_reg]) begin
      buffer_mac_addr = buffer_addr_reg[buffer_mac_selected_reg];
      buffer_mac_state = buffer_state_reg[buffer_mac_selected_reg];
    end

  end

  //----------------------------------------------------------------
  // API
  //----------------------------------------------------------------

  always @*
  begin : api
    api_read_data = 0;
    counter_bytes_rst = 0;
    counter_bytes_lsb_we = 0;
    counter_packets_rst = 0;
    counter_packets_lsb_we = 0;
    dummy_we = 0;
    dummy_new = 0;

    if (i_api_cs) begin
      if (i_api_we) begin
        case (i_api_address)
          ADDR_DUMMY:
            begin
              dummy_we  = 1;
              dummy_new = i_api_write_data;
            end
          ADDR_BYTES: counter_bytes_rst = 1;
          ADDR_PACKETS: counter_packets_rst = 1;
          default: ;
        endcase
      end else begin
        case (i_api_address)
          ADDR_NAME0: api_read_data = CORE_NAME[63:32];
          ADDR_NAME1: api_read_data = CORE_NAME[31:0];
          ADDR_VERSION: api_read_data = CORE_VERSION;
          ADDR_DUMMY: api_read_data = dummy_reg;
          ADDR_BYTES:
            begin
              counter_bytes_lsb_we = 1;
              api_read_data = counter_bytes_reg[63:32];
            end
          ADDR_BYTES + 1: api_read_data = counter_bytes_lsb_reg;
          ADDR_PACKETS:
            begin
              counter_packets_lsb_we = 1;
              api_read_data = counter_packets_reg[63:32];
            end
          ADDR_PACKETS + 1: api_read_data = counter_packets_lsb_reg;
          ADDR_MUX_STATE: api_read_data[0] = mux_in_ctrl_reg;
          ADDR_MUX_INDEX: api_read_data = mux_in_index_reg;
          ADDR_DEBUG_TX: api_read_data = debug_tx_reg;
          ADDR_ERROR_STARTS: api_read_data = error_illegal_start_reg;
          ADDR_ERROR_DISCARDS: api_read_data = error_illegal_discard_reg;
          default: ;
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // API counters
  //----------------------------------------------------------------

  always @*
  begin : api_counters
    counter_bytes_we = 0;
    counter_bytes_new = 0;
    counter_packets_we = 0;
    counter_packets_new = 0;

    if (counter_bytes_rst) begin
      counter_bytes_we = 1;
      counter_bytes_new = 0;
    end else begin
      counter_bytes_we = 1;
      case (o_mac_tx_data_valid)
        default: counter_bytes_we = 0;
        8'b0000_0001: counter_bytes_new = counter_bytes_reg + 1;
        8'b0000_0011: counter_bytes_new = counter_bytes_reg + 2;
        8'b0000_0111: counter_bytes_new = counter_bytes_reg + 3;
        8'b0000_1111: counter_bytes_new = counter_bytes_reg + 4;
        8'b0001_1111: counter_bytes_new = counter_bytes_reg + 5;
        8'b0011_1111: counter_bytes_new = counter_bytes_reg + 6;
        8'b0111_1111: counter_bytes_new = counter_bytes_reg + 7;
        8'b1111_1111: counter_bytes_new = counter_bytes_reg + 8;
      endcase
    end

    if (counter_packets_rst) begin
      counter_packets_we = 1;
      counter_packets_new = 0;
    end else if (mac_start) begin
      counter_packets_we = 1;
      counter_packets_new = counter_packets_reg + 1;
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

    case (engine_reader_fsm_reg)
      ENGINE_READER_IDLE:
        if (mux_in_packet_available && mux_in_fifo_empty==1'b0) begin
          engine_fifo_rd_start_new = 1;

          engine_reader_fsm_we = 1;
          engine_reader_fsm_new = ENGINE_READER_READING;
          engine_reader_lwdv_we = 1;
          engine_reader_lwdv_new = mux_in_bytes_last_word;
          engine_reader_start_new = 1;
        end
      ENGINE_READER_READING:
        if (mux_in_fifo_rd_valid) begin
          engine_reader_data_we = 1;
          engine_reader_data_new = mux_in_fifo_rd_data;
          engine_reader_data_valid_new = 1;
        end else if (mux_in_fifo_empty) begin
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
    buffer_engine_addr_we = 0;
    buffer_engine_addr_new = 0;
    buffer_engine_lwdv_we = 0;
    buffer_engine_lwdv_new = 0;
    buffer_engine_selected_we = 0;
    buffer_engine_selected_new = 0;
    buffer_engine_state_we = 0;
    buffer_engine_state_new = 0;
    buffer_initilized_we = 0;
    buffer_initilized_new = 0;
    write_wdata_new = 0;
    write_wren_new = 0;
    write_addr_new = 0;
    case (buffer_engine_state)
      BUFFER_STATE_UNUSED:
        if (engine_reader_start_reg) begin
          buffer_engine_addr_we = 1;
          buffer_engine_addr_new = 0;
          buffer_engine_lwdv_we = 1;
          buffer_engine_lwdv_new = engine_reader_lwdv_reg;
          buffer_engine_state_we = 1;
          buffer_engine_state_new = BUFFER_STATE_WRITING;
          buffer_initilized_we = 1;
          buffer_initilized_new = buffer_initilized_reg;
          buffer_initilized_new[buffer_engine_selected_reg] = 1;
        end
      BUFFER_STATE_WRITING:
        if (engine_reader_data_valid_reg) begin
          buffer_engine_addr_we = 1;
          buffer_engine_addr_new = buffer_engine_addr + 1;
          write_addr_new[BRAM_WIDTH-1:ADDR_WIDTH] = buffer_engine_selected_reg;
          write_addr_new[ADDR_WIDTH-1:0] = buffer_engine_addr;
          write_wdata_new = engine_reader_data_reg;
          write_wren_new = 1;
        end else if (engine_reader_stop_reg) begin
          buffer_engine_state_we = 1;
          buffer_engine_state_new = BUFFER_STATE_LOADED;
          buffer_engine_selected_we = 1;
          buffer_engine_selected_new = buffer_engine_selected_reg + 1;
        end
      BUFFER_STATE_LOADED: ;
      BUFFER_STATE_READING: ;
    endcase
  end

  //----------------------------------------------------------------
  // MAC Media Access Controller
  //----------------------------------------------------------------

  function [63:0] mac_byte_txreverse( input [63:0] txd, input [7:0] txv );
  begin : txreverse
    reg [63:0] out;
    out[0+:8]  = txv[0] ? txd[56+:8] : 8'h00;
    out[8+:8]  = txv[1] ? txd[48+:8] : 8'h00;
    out[16+:8] = txv[2] ? txd[40+:8] : 8'h00;
    out[24+:8] = txv[3] ? txd[32+:8] : 8'h00;
    out[32+:8] = txv[4] ? txd[24+:8] : 8'h00;
    out[40+:8] = txv[5] ? txd[16+:8] : 8'h00;
    out[48+:8] = txv[6] ? txd[8+:8]  : 8'h00;
    out[56+:8] = txv[7] ? txd[0+:8]  : 8'h00;
    mac_byte_txreverse = out;
  end
  endfunction

  function [7:0] mac_last_word_data_valid_expander( input [3:0] lwdv );
  begin : lwdv_expander
    reg [7:0] x;
    case (lwdv)
      default: x = 8'b0000_0000;
      1: x = 8'b0000_0001;
      2: x = 8'b0000_0011;
      3: x = 8'b0000_0111;
      4: x = 8'b0000_1111;
      5: x = 8'b0001_1111;
      6: x = 8'b0011_1111;
      7: x = 8'b0111_1111;
      8: x = 8'b1111_1111;
    endcase
    mac_last_word_data_valid_expander = x;
  end
  endfunction

  //----------------------------------------------------------------
  // MAC Media Access Controller
  //----------------------------------------------------------------

  always @(posedge i_clk, posedge i_areset)
    if (i_areset == 1'b1) begin
      mac_data_valid <= 0;
      mac_data <= 0;
      mac_start <= 0;
      tx_buffer <= 0;
      tx_count <= 0;
      tx_last <= 0;
      tx_lwdv <= 0;
      tx_state <= 0;
      tx_stop <= 0;
    end else begin
      mac_data_valid <= 0;
      mac_start <= 0;
      case (tx_state)
        TX_IDLE:
          if (tx_start) begin : tx_idle_scope
            reg [BRAM_WIDTH-1:0] addr;

            addr[ADDR_WIDTH-1:0] = 0;
            addr[BRAM_WIDTH-1:ADDR_WIDTH] = tx_start_buffer;

            mac_start <= 1;
            mac_data <= mac_byte_txreverse( txmem[addr], 8'hff );
            mac_data_valid <= 8'hff;

            tx_buffer <= tx_start_buffer;
            tx_last <= tx_start_last;
            tx_lwdv <= tx_start_lwdv;
            tx_count <= 2;
            tx_state <= TX_AWAIT_ACK;
          end
        TX_AWAIT_ACK:
          if (i_mac_tx_ack) begin : tx_await_ack_scope
            reg [BRAM_WIDTH-1:0] addr;

            addr[ADDR_WIDTH-1:0] = 1;
            addr[BRAM_WIDTH-1:ADDR_WIDTH] = tx_buffer;

            mac_data <= mac_byte_txreverse( txmem[addr], 8'hff );
            mac_data_valid <= 8'hff;

            tx_state <= TX_WRITE;
          end else begin
            mac_data <= mac_data;
            mac_data_valid <= mac_data_valid;
          end
        TX_WRITE:
          begin : tx_write_scoope
            reg [BRAM_WIDTH-1:0] addr;

            addr[ADDR_WIDTH-1:0] = tx_count;
            addr[BRAM_WIDTH-1:ADDR_WIDTH] = tx_buffer;

            tx_count <= tx_count + 1;
            if (tx_count >= tx_last) begin
              mac_data <= mac_byte_txreverse( txmem[addr], tx_lwdv );
              mac_data_valid <= tx_lwdv;

              tx_state <= TX_SILENT_CYCLE;
              tx_stop <= 1;
            end else begin
              mac_data <= mac_byte_txreverse( txmem[addr], 8'hff );
              mac_data_valid <= 8'hff;
            end
          end
        TX_SILENT_CYCLE: //just ensure we do feed D: 64'h0, DV: 8'h0 one cycle so MAC gets packet end.
          begin
            tx_state <= TX_IDLE;
          end
        default:
          begin
            mac_data       <= 0;
            mac_data_valid <= 0;
            tx_count       <= 0;
            tx_last        <= 0;
            tx_lwdv        <= 0;
            tx_state       <= TX_IDLE;
         end
     endcase
    end //not async reset

  always @*
    begin
      debug_tx_new = { 7'b1000_000, mac_start, 8'h00, mac_data_valid, 5'b0, tx_state };
    end

  //----------------------------------------------------------------
  // MAC Media Access Controller - txmem writer
  //----------------------------------------------------------------

  always @(posedge i_clk)
  if (txmem_wren) begin
    txmem[txmem_addr] <= txmem_wdata;
  end

  always @*
  begin
    txmem_addr = write_addr_reg;
    txmem_wren = write_wren_reg;
    txmem_wdata = write_wdata_reg;
  end

  //----------------------------------------------------------------
  // MAC buffer selector
  //----------------------------------------------------------------

  always @*
  begin : mac_buff_select
    reg [7:0] lwdv_expanded;

    lwdv_expanded = mac_last_word_data_valid_expander( buffer_lwdv_reg[buffer_mac_selected_reg] );

    buffer_mac_selected_we = 0;
    buffer_mac_selected_new = 0;
    buffer_mac_state_we = 0;
    buffer_mac_state_new = 0;

    tx_start        = 0;
    tx_start_buffer = 0;
    tx_start_last   = 0;
    tx_start_lwdv   = 0;

    case (buffer_mac_state)
      BUFFER_STATE_UNUSED: ;
      BUFFER_STATE_WRITING: ;
      BUFFER_STATE_LOADED:
        if (tx_state == TX_IDLE) begin
          buffer_mac_state_we = 1;
          buffer_mac_state_new = BUFFER_STATE_READING;
          tx_start = 1;
          tx_start_buffer = buffer_mac_selected_reg;
          tx_start_lwdv = lwdv_expanded;
          tx_start_last = buffer_mac_addr - 1;
        end
      BUFFER_STATE_READING:
        if (tx_stop) begin
          buffer_mac_selected_we = 1;
          buffer_mac_selected_new = buffer_mac_selected_reg + 1;
          buffer_mac_state_we = 1;
          buffer_mac_state_new = BUFFER_STATE_UNUSED;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Synchronous reset conversion
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      sync_reset_metastable <= 1;
      sync_reset <= 1;
    end else begin
      sync_reset_metastable <= 0;
      sync_reset <= sync_reset_metastable;
    end
  end

  //----------------------------------------------------------------
  // BRAM Register Update (synchronous reset)
  //----------------------------------------------------------------

  always @(posedge i_clk)
  begin : bram_reg_update
    if (sync_reset) begin
      write_addr_reg  <= 0;
      write_wdata_reg <= 0;
      write_wren_reg  <= 0;
    end else begin
      write_addr_reg  <= write_addr_new;
      write_wdata_reg <= write_wdata_new;
      write_wren_reg  <= write_wren_new;
    end
  end

  //----------------------------------------------------------------
  // Register Update (no reset)
  //----------------------------------------------------------------

  always @(posedge i_clk)
  begin
    if (buffer_engine_addr_we)
      buffer_addr_reg[buffer_engine_selected_reg] <= buffer_engine_addr_new;

    if (buffer_engine_lwdv_we)
      buffer_lwdv_reg[buffer_engine_selected_reg] <= buffer_engine_lwdv_new;

    if (buffer_engine_state_we)
      buffer_state_reg[buffer_engine_selected_reg] <= buffer_engine_state_new;

    if (buffer_mac_state_we)
      buffer_state_reg[buffer_mac_selected_reg] <= buffer_mac_state_new;
  end

  //----------------------------------------------------------------
  // Register Update (asynchronous reset)
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      buffer_engine_selected_reg <= 0;
      buffer_mac_selected_reg <= 0;
      buffer_initilized_reg <= 0;
      counter_bytes_reg <= 0;
      counter_bytes_lsb_reg <= 0;
      counter_packets_reg <= 0;
      counter_packets_lsb_reg <= 0;
      debug_tx_reg <= 0;
      dummy_reg <= 0;
      engine_fifo_rd_start_reg <= 0;
      engine_mux_ready_engines_reg <= 0;
      engine_mux_ready_found_reg <= 0;
      engine_mux_ready_index_reg <= 0;
      engine_packet_read_reg <= 0;
      engine_reader_fsm_reg <= 0;
      engine_reader_data_reg <= 0;
      engine_reader_data_valid_reg <= 0;
      engine_reader_lwdv_reg <= 0;
      engine_reader_start_reg <= 0;
      engine_reader_stop_reg <= 0;
      error_illegal_discard_reg <= 0;
      error_illegal_start_reg <= 0;
      mux_in_ctrl_reg  <= MUX_SEARCH;
      mux_in_index_reg <= 0;
      //note: mac moved to its own clocked process to get timing, behaivor etc very similar to pp_tx
    end else begin
      if (buffer_initilized_we)
        buffer_initilized_reg <= buffer_initilized_new;

      if (counter_bytes_we)
        counter_bytes_reg <= counter_bytes_new;

      if (counter_bytes_lsb_we)
        counter_bytes_lsb_reg <= counter_bytes_reg[31:0];

      if (counter_packets_we)
        counter_packets_reg <= counter_packets_new;

      if (counter_packets_lsb_we)
        counter_packets_lsb_reg <= counter_packets_reg[31:0];

      if (buffer_engine_selected_we)
        buffer_engine_selected_reg <= buffer_engine_selected_new;

      if (buffer_mac_selected_we)
        buffer_mac_selected_reg <= buffer_mac_selected_new;

      debug_tx_reg <= debug_tx_new;

      if (dummy_we)
        dummy_reg <= dummy_new;

      engine_fifo_rd_start_reg <= engine_fifo_rd_start_new;

      engine_mux_ready_engines_reg <= engine_mux_ready_engines_new;
      engine_mux_ready_found_reg <= engine_mux_ready_found_new;
      engine_mux_ready_index_reg <= engine_mux_ready_index_new;

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

      if (error_illegal_discard_inc)
        error_illegal_discard_reg <= error_illegal_discard_reg + 1;

      if (error_illegal_start_inc)
        error_illegal_start_reg <= error_illegal_start_reg + 1;

      if (mux_in_ctrl_we)
        mux_in_ctrl_reg <= mux_in_ctrl_new;

      if (mux_in_index_we)
        mux_in_index_reg <= mux_in_index_new;

      //mac moved to its own clocked process to get timing, behaivor etc very similar to pp_tx
    end
  end


endmodule
