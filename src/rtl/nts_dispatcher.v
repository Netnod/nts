//
// Copyright (c) 2019-2020, The Swedish Post and Telecom Authority (PTS)
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

module nts_dispatcher #(
  parameter ADDR_WIDTH = 8,
  parameter ENGINES = 2,
  parameter ENGINES_NTS = 1,
  parameter ENGINES_MINI = 1,
  parameter DEBUG = 0
) (
  input  wire        i_areset, // async reset
  input  wire        i_clk,

  input wire [63:0] i_ntp_time,

  // MAC
  input  wire [7:0]  i_rx_data_valid,
  input  wire [63:0] i_rx_data,
  input  wire        i_rx_bad_frame,
  input  wire        i_rx_good_frame,

  input  wire [ENGINES      - 1 : 0 ] i_dispatch_busy,
  input  wire [ENGINES      - 1 : 0 ] i_dispatch_ready,
  output wire [ENGINES * 4  - 1 : 0 ] o_dispatch_data_valid,
  output wire [ENGINES      - 1 : 0 ] o_dispatch_fifo_empty,
  output wire [ENGINES      - 1 : 0 ] o_dispatch_fifo_rd_start,
  output wire [ENGINES      - 1 : 0 ] o_dispatch_fifo_rd_valid,
  output wire [ENGINES * 64 - 1 : 0 ] o_dispatch_fifo_rd_data,

  input  wire                  i_api_cs,
  input  wire                  i_api_we,
  input  wire [11:0]           i_api_address,
  input  wire [31:0]           i_api_write_data,
  output wire [31:0]           o_api_read_data,

  input  wire [ENGINES-1:0]    i_engine_api_busy,
  output wire [ENGINES-1:0]    o_engine_cs,
  output wire                  o_engine_we,
  output wire [11:0]           o_engine_address,
  output wire [31:0]           o_engine_write_data,
  input  wire [ENGINES*32-1:0] i_engine_read_data,
  input  wire [ENGINES-1:0]    i_engine_read_data_valid
);
  //----------------------------------------------------------------
  // API constants
  //----------------------------------------------------------------

  localparam ADDR_NAME0             = 0;
  localparam ADDR_NAME1             = 1;
  localparam ADDR_VERSION           = 2;
  localparam ADDR_DUMMY             = 3;
  localparam ADDR_SYSTICK32         = 4;
  localparam ADDR_STATES_INSPECT    = 5;
  localparam ADDR_NTPTIME_MSB       = 6;
  localparam ADDR_NTPTIME_LSB       = 7;
  localparam ADDR_CTRL              = 8;
  localparam ADDR_STATUS            = 9;
  localparam ADDR_BYTES_RX_MSB      = 10;
  localparam ADDR_BYTES_RX_LSB      = 11;
  localparam ADDR_NTS_REC_MSB       = 12;
  localparam ADDR_NTS_REC_LSB       = 13;
  localparam ADDR_NTS_DISCARDED_MSB = 14;
  localparam ADDR_NTS_DISCARDED_LSB = 15;
  localparam ADDR_NTS_ENGINES_READY = 16;
  localparam ADDR_NTS_ENGINES_ALL   = 17;

  localparam ADDR_COUNTER_FRAMES_MSB     = 'h20;
  localparam ADDR_COUNTER_FRAMES_LSB     = 'h21;
  localparam ADDR_COUNTER_GOOD_MSB       = 'h22;
  localparam ADDR_COUNTER_GOOD_LSB       = 'h23;
  localparam ADDR_COUNTER_BAD_MSB        = 'h24;
  localparam ADDR_COUNTER_BAD_LSB        = 'h25;
  localparam ADDR_COUNTER_DISPATCHED_MSB = 'h26;
  localparam ADDR_COUNTER_DISPATCHED_LSB = 'h27;
  localparam ADDR_COUNTER_ERROR_MSB      = 'h28;
  localparam ADDR_COUNTER_ERROR_LSB      = 'h29;

  localparam ADDR_BUS_ID_CMD_ADDR = 80;
  localparam ADDR_BUS_STATUS      = 81;
  localparam ADDR_BUS_DATA        = 82;

  localparam ADDR_LAST            = 'hFFF;

  localparam BUS_READ  = 8'h55;
  localparam BUS_WRITE = 8'hAA;

  localparam CORE_NAME    = 64'h4e_54_53_2d_44_49_53_50; //NTS-DISP
  localparam CORE_VERSION = 32'h30_2e_30_35;


  //----------------------------------------------------------------
  // State constants
  //----------------------------------------------------------------

  localparam STATE_IDLE       = 0;
  localparam STATE_FORWARDING = 1;

  //----------------------------------------------------------------
  // Misc. constants
  //----------------------------------------------------------------

  localparam [ADDR_WIDTH-1:0] ADDR_ZERO = 0;

  //----------------------------------------------------------------
  // Registers
  //----------------------------------------------------------------

  reg        mini_discard_new; //internal
  reg        mini_discard_reg; //internal
  reg        mini_rd_start_new; //out
  reg        mini_rd_start_reg; //out
  reg [63:0] mini_rd_data_new;  //out
  reg [63:0] mini_rd_data_reg;  //out
  reg        mini_rd_valid_new; //out
  reg        mini_rd_valid_reg; //out
  reg  [3:0] mini_rd_lwdv_new;
  reg  [3:0] mini_rd_lwdv_reg;

  reg mini_state_we;
  reg mini_state_new;
  reg mini_state_reg;

  reg        nts_discard_new; //internal
  reg        nts_discard_reg; //internal
  reg        nts_rd_start_new; //out
  reg        nts_rd_start_reg; //out
  reg [63:0] nts_rd_data_new;  //out
  reg [63:0] nts_rd_data_reg;  //out
  reg        nts_rd_valid_new; //out
  reg        nts_rd_valid_reg; //out
  reg  [3:0] nts_rd_lwdv_new;
  reg  [3:0] nts_rd_lwdv_reg;

  reg nts_state_we;
  reg nts_state_new;
  reg nts_state_reg;

  //----------------------------------------------------------------
  // Preprocessor decode wires
  //----------------------------------------------------------------

  wire [63:0] d_data0;
  wire d_is_nts;
  wire d_is_other;
  /* verilator lint_off UNUSED */
  wire d_is_drop;
  /* verilator lint_on UNUSED */
  wire d_bad;
  wire d_good;
  wire [3:0] d_valid4bits;
  wire d_start_of_frame;

  //----------------------------------------------------------------
  // Misc. wires
  //----------------------------------------------------------------

  reg [31:0] api_read_data;

  wire error_state;

  //----------------------------------------------------------------
  // API Debug, counter etc registers
  //----------------------------------------------------------------

  reg        api_dummy_we;
  reg [31:0] api_dummy_new;
  reg [31:0] api_dummy_reg;

  wire [31:0] counter_sof_detect_msb;
  wire [31:0] counter_sof_detect_lsb;
  reg         counter_sof_detect_lsb_we;

  wire [31:0] counter_bad_msb;
  wire [31:0] counter_bad_lsb;
  reg         counter_bad_lsb_we;

  reg        counter_bytes_rx_rst;
  reg        counter_bytes_rx_we;
  reg [63:0] counter_bytes_rx_new;
  reg [63:0] counter_bytes_rx_reg;
  reg        counter_bytes_rx_lsb_we;
  reg [31:0] counter_bytes_rx_lsb_reg;

  wire [31:0] counter_dispatched_msb;
  wire [31:0] counter_dispatched_lsb;
  reg         counter_dispatched_lsb_we;

  wire [31:0] counter_error_msb;
  wire [31:0] counter_error_lsb;
  reg         counter_error_lsb_we;

  wire [31:0] counter_good_msb;
  wire [31:0] counter_good_lsb;
  reg         counter_good_lsb_we;

  reg         counter_packets_discarded_nts_inc;
  reg         counter_packets_discarded_other_inc;
  reg         counter_packets_discarded_rst;
  wire [31:0] counter_packets_discarded_msb;
  wire [31:0] counter_packets_discarded_lsb;
  reg         counter_packets_discarded_lsb_we;

  reg         counter_packets_rx_rst;
  wire [31:0] counter_packets_rx_msb;
  wire [31:0] counter_packets_rx_lsb;
  reg         counter_packets_rx_lsb_we;

  reg        dispatcher_enabled_we;
  reg        dispatcher_enabled_new;
  reg        dispatcher_enabled_reg;

  reg        engine_ctrl_we;
  reg [31:0] engine_ctrl_new;
  reg [31:0] engine_ctrl_reg;
  reg        engine_status_we;
  reg [31:0] engine_status_new;
  reg [31:0] engine_status_reg;
  reg        engine_data_we;
  reg [31:0] engine_data_new;
  reg [31:0] engine_data_reg;

  reg [31:0] engines_ready_new;
  reg [31:0] engines_ready_reg;

  reg        ntp_time_lsb_we;
  reg [31:0] ntp_time_lsb_reg;

  reg [31:0] systick32_reg;

  //----------------------------------------------------------------
  // Engine API bus registers
  //----------------------------------------------------------------

  reg  [ENGINES-1:0] bus_cs_new;
  reg  [ENGINES-1:0] bus_cs_reg;
  reg                bus_we_new;
  reg                bus_we_reg;
  reg  [11:0]        bus_addr_new;
  reg  [11:0]        bus_addr_reg;
  wire [31:0]        bus_write_data;
  reg  [31:0]        bus_read_data_mux;
  reg                bus_read_data_mux_valid;

  //----------------------------------------------------------------
  // Output wiring
  //----------------------------------------------------------------

  assign bus_write_data  = engine_data_reg;

  assign error_state     = 1'b0; //TODO

  assign o_api_read_data = api_read_data;

  assign o_engine_cs         = bus_cs_reg;
  assign o_engine_we         = bus_we_reg;
  assign o_engine_address    = bus_addr_reg;
  assign o_engine_write_data = bus_write_data;


  //----------------------------------------------------------------
  // Dispatcher Mux
  //----------------------------------------------------------------

  wire mux_nts_busy;
  wire mux_nts_ready;
  /* verilator lint_off UNUSED */
  wire mux_mini_busy; //TODO
  wire mux_mini_ready; //TODO
  /* verilator lint_on UNUSED */

  nts_dispatcher_mux #(.ENGINES(ENGINES_NTS)) mux_nts (
    .i_clk    ( i_clk    ),
    .i_areset ( i_areset ),

    .o_busy  ( mux_nts_busy  ),
    .o_ready ( mux_nts_ready ),

    .i_discard   ( nts_discard_reg  ),

    .i_start     ( nts_rd_start_reg ),
    .i_valid     ( nts_rd_valid_reg ),
    .i_valid4bit ( nts_rd_lwdv_reg  ),
    .i_data      ( nts_rd_data_reg  ),

    .i_dispatch_busy          ( i_dispatch_busy          [   ENGINES_NTS-1:0] ),
    .i_dispatch_ready         ( i_dispatch_ready         [   ENGINES_NTS-1:0] ),
    .o_dispatch_data_valid    ( o_dispatch_data_valid    [ 4*ENGINES_NTS-1:0] ),
    .o_dispatch_fifo_empty    ( o_dispatch_fifo_empty    [   ENGINES_NTS-1:0] ),
    .o_dispatch_fifo_rd_start ( o_dispatch_fifo_rd_start [   ENGINES_NTS-1:0] ),
    .o_dispatch_fifo_rd_valid ( o_dispatch_fifo_rd_valid [   ENGINES_NTS-1:0] ),
    .o_dispatch_fifo_rd_data  ( o_dispatch_fifo_rd_data  [64*ENGINES_NTS-1:0] )
  );

  nts_dispatcher_mux #(.ENGINES(ENGINES_MINI)) mux_mini (
    .i_clk    ( i_clk    ),
    .i_areset ( i_areset ),

    .o_busy  ( mux_mini_busy  ),
    .o_ready ( mux_mini_ready ),

    .i_discard   ( mini_discard_reg  ),

    .i_start     ( mini_rd_start_reg ),
    .i_valid     ( mini_rd_valid_reg ),
    .i_valid4bit ( mini_rd_lwdv_reg  ),
    .i_data      ( mini_rd_data_reg  ),

    .i_dispatch_busy          ( i_dispatch_busy          [   ENGINES-1:   ENGINES_NTS] ),
    .i_dispatch_ready         ( i_dispatch_ready         [   ENGINES-1:   ENGINES_NTS] ),
    .o_dispatch_data_valid    ( o_dispatch_data_valid    [ 4*ENGINES-1: 4*ENGINES_NTS] ),
    .o_dispatch_fifo_empty    ( o_dispatch_fifo_empty    [   ENGINES-1:   ENGINES_NTS] ),
    .o_dispatch_fifo_rd_start ( o_dispatch_fifo_rd_start [   ENGINES-1:   ENGINES_NTS] ),
    .o_dispatch_fifo_rd_valid ( o_dispatch_fifo_rd_valid [   ENGINES-1:   ENGINES_NTS] ),
    .o_dispatch_fifo_rd_data  ( o_dispatch_fifo_rd_data  [64*ENGINES-1:64*ENGINES_NTS] )
  );

  //----------------------------------------------------------------
  // API
  //----------------------------------------------------------------

  always @*
  begin : api
    api_read_data = 0;

    api_dummy_we = 0;
    api_dummy_new = 0;

    counter_bad_lsb_we = 0;

    counter_bytes_rx_rst = 0;
    counter_bytes_rx_lsb_we = 0;

    counter_dispatched_lsb_we = 0;
    counter_error_lsb_we = 0;
    counter_good_lsb_we = 0;

    counter_packets_discarded_rst = 0;
    counter_packets_discarded_lsb_we = 0;

    counter_packets_rx_rst = 0;
    counter_packets_rx_lsb_we = 0;

    counter_sof_detect_lsb_we = 0;

    engine_ctrl_we = 0;
    engine_ctrl_new = 0;
    engine_status_we = 0;
    engine_status_new = 0;
    engine_data_we = 0;
    engine_data_new = 0;

    dispatcher_enabled_we = 0;
    dispatcher_enabled_new = 0;

    ntp_time_lsb_we = 0;

    if (engine_status_reg[0]) begin
      if (bus_read_data_mux_valid) begin
        engine_status_we = 1;
        engine_status_new = { engine_status_reg[31:1], 1'b0 };
        engine_data_we = 1;
        engine_data_new = bus_read_data_mux;
      end
    end

    if (i_api_cs) begin
      if (i_api_we) begin
        case (i_api_address)
          ADDR_DUMMY:
            begin
              api_dummy_we = 1;
              api_dummy_new = i_api_write_data;
            end
          ADDR_CTRL:
            begin
              dispatcher_enabled_we = 1;
              dispatcher_enabled_new = i_api_write_data[0];
            end
          ADDR_BYTES_RX_MSB: counter_bytes_rx_rst = 1;
          ADDR_NTS_REC_MSB: counter_packets_rx_rst = 1;
          ADDR_NTS_DISCARDED_MSB: counter_packets_discarded_rst = 1;
          ADDR_BUS_ID_CMD_ADDR:
            begin
              engine_ctrl_we = 1;
              engine_ctrl_new = i_api_write_data;
            end
          ADDR_BUS_STATUS:
            begin
              engine_status_we = 1;
              engine_status_new = i_api_write_data;
            end
          ADDR_BUS_DATA:
            begin
              engine_data_we = 1;
              engine_data_new = i_api_write_data;
            end
          default: ;
        endcase
      end else begin
        case (i_api_address)
          ADDR_NAME0: api_read_data = CORE_NAME[63:32];
          ADDR_NAME1: api_read_data = CORE_NAME[31:0];
          ADDR_VERSION: api_read_data = CORE_VERSION;
          ADDR_DUMMY: api_read_data = api_dummy_reg;
          ADDR_SYSTICK32: api_read_data = systick32_reg;
          ADDR_CTRL: api_read_data = { 31'h0, dispatcher_enabled_reg };
          ADDR_STATUS: api_read_data = (engines_ready_reg == 0) ? 32'h0 : 32'h1;
          //TODO ADDR_STATES_INSPECT: api_read_data = { 15'h0, current_mem_reg, 4'h0, mem_state_reg[0], 4'h0, mem_state_reg[1] };
          ADDR_NTPTIME_MSB:
            begin
              api_read_data = i_ntp_time[63:32];
              ntp_time_lsb_we = 1;
            end
          ADDR_NTPTIME_LSB: api_read_data = ntp_time_lsb_reg;
          ADDR_BYTES_RX_MSB:
            begin
              api_read_data = counter_bytes_rx_reg[63:32];
              counter_bytes_rx_lsb_we = 1;
            end
          ADDR_BYTES_RX_LSB:
            begin
              api_read_data = counter_bytes_rx_lsb_reg;
            end
          ADDR_NTS_REC_MSB:
            begin
              api_read_data = counter_packets_rx_msb;
              counter_packets_rx_lsb_we = 1;
            end
          ADDR_NTS_REC_LSB:
            begin
              api_read_data = counter_packets_rx_lsb;
            end
          ADDR_NTS_DISCARDED_MSB:
            begin
              api_read_data = counter_packets_discarded_msb;
              counter_packets_discarded_lsb_we = 1;
            end
          ADDR_NTS_DISCARDED_LSB:
            begin
              api_read_data = counter_packets_discarded_lsb;
            end
          ADDR_NTS_ENGINES_READY:
            begin
              api_read_data = engines_ready_reg;
            end
          ADDR_NTS_ENGINES_ALL:
             begin
               api_read_data = ENGINES;
             end
          ADDR_COUNTER_FRAMES_MSB:
            begin
              api_read_data = counter_sof_detect_msb;
              counter_sof_detect_lsb_we = 1;
            end
          ADDR_COUNTER_FRAMES_LSB:
            begin
              api_read_data = counter_sof_detect_lsb;
            end
          ADDR_COUNTER_GOOD_MSB:
            begin
              api_read_data = counter_good_msb;
              counter_good_lsb_we = 1;
            end
          ADDR_COUNTER_GOOD_LSB:
            begin
              api_read_data = counter_good_lsb;
            end
          ADDR_COUNTER_BAD_MSB:
            begin
              api_read_data = counter_bad_msb;
              counter_bad_lsb_we = 1;
            end
          ADDR_COUNTER_BAD_LSB:
            begin
              api_read_data = counter_bad_lsb;
            end
          ADDR_COUNTER_DISPATCHED_MSB:
            begin
              api_read_data = counter_dispatched_msb;
              counter_dispatched_lsb_we = 1;
            end
          ADDR_COUNTER_DISPATCHED_LSB:
            begin
              api_read_data = counter_dispatched_lsb;
            end
          ADDR_COUNTER_ERROR_MSB:
            begin
              api_read_data = counter_error_msb;
              counter_error_lsb_we = 1;
            end
          ADDR_COUNTER_ERROR_LSB:
            begin
              api_read_data = counter_error_lsb;
            end
          ADDR_BUS_ID_CMD_ADDR:
            begin
              api_read_data = engine_ctrl_reg;
            end
          ADDR_BUS_STATUS:
            begin
              api_read_data = engine_status_reg;
            end
          ADDR_BUS_DATA:
            begin
              api_read_data = engine_data_reg;
            end
          ADDR_LAST:
            begin
              api_read_data = 32'hf005ba11;
            end
          default: ;
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // Register Update
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin

      api_dummy_reg <= 0;

      bus_cs_reg   <= 0;
      bus_we_reg   <= 0;
      bus_addr_reg <= 0;

      counter_bytes_rx_reg <= 0;
      counter_bytes_rx_lsb_reg <= 0;

      dispatcher_enabled_reg <= 0;

      engine_ctrl_reg <= 0;
      engine_status_reg <= 0;
      engine_data_reg <= 0;

      engines_ready_reg <= 0;

      mini_discard_reg <= 0;
      mini_rd_data_reg <= 0;
      mini_rd_lwdv_reg <= 0;
      mini_rd_start_reg <= 0;
      mini_rd_valid_reg <= 0;
      mini_state_reg <= STATE_IDLE;

      nts_discard_reg <= 0;
      nts_rd_data_reg <= 0;
      nts_rd_lwdv_reg <= 0;
      nts_rd_start_reg <= 0;
      nts_rd_valid_reg <= 0;
      nts_state_reg <= STATE_IDLE;

      ntp_time_lsb_reg <= 0;

      systick32_reg <= 32'h01;

    end else begin

      if (api_dummy_we)
        api_dummy_reg <= api_dummy_new;

      bus_cs_reg   <= bus_cs_new;
      bus_we_reg   <= bus_we_new;
      bus_addr_reg <= bus_addr_new;

      if (counter_bytes_rx_we)
       counter_bytes_rx_reg <= counter_bytes_rx_new;

      if (counter_bytes_rx_lsb_we)
        counter_bytes_rx_lsb_reg <= counter_bytes_rx_reg[31:0];

      if (dispatcher_enabled_we)
        dispatcher_enabled_reg <= dispatcher_enabled_new;

      if (engine_ctrl_we)
        engine_ctrl_reg <= engine_ctrl_new;

      if (engine_data_we)
        engine_data_reg <= engine_data_new;

      if (engine_status_we)
        engine_status_reg <= engine_status_new;

      engines_ready_reg <= engines_ready_new;

      mini_discard_reg <= mini_discard_new;
      mini_rd_lwdv_reg <= mini_rd_lwdv_new;
      mini_rd_start_reg <= mini_rd_start_new;
      mini_rd_data_reg <= mini_rd_data_new;
      mini_rd_valid_reg <= mini_rd_valid_new;

      if (mini_state_we)
        mini_state_reg <= mini_state_new;

      nts_discard_reg <= nts_discard_new;
      nts_rd_lwdv_reg <= nts_rd_lwdv_new;
      nts_rd_start_reg <= nts_rd_start_new;
      nts_rd_data_reg <= nts_rd_data_new;
      nts_rd_valid_reg <= nts_rd_valid_new;

      if (nts_state_we)
        nts_state_reg <= nts_state_new;

      if (ntp_time_lsb_we)
        ntp_time_lsb_reg <= i_ntp_time[31:0];

      systick32_reg <= systick32_reg + 1;

    end
  end

  //----------------------------------------------------------------
  // Debug counters
  //----------------------------------------------------------------

  counter64 counter_bad (
     .i_areset     ( i_areset            ),
     .i_clk        ( i_clk               ),
     .i_inc        ( i_rx_bad_frame      ),
     .i_rst        ( 1'b0                ),
     .i_lsb_sample ( counter_bad_lsb_we  ),
     .o_msb        ( counter_bad_msb     ),
     .o_lsb        ( counter_bad_lsb     )
  );

  counter64 counter_dispatched (
     .i_areset     ( i_areset                   ),
     .i_clk        ( i_clk                      ),
     .i_inc        ( nts_rd_start_reg           ),
     .i_rst        ( 1'b0                       ),
     .i_lsb_sample ( counter_dispatched_lsb_we  ),
     .o_msb        ( counter_dispatched_msb     ),
     .o_lsb        ( counter_dispatched_lsb     )
  );

  counter64 counter_error (
     .i_areset     ( i_areset                   ),
     .i_clk        ( i_clk                      ),
     .i_inc        ( error_state                ),
     .i_rst        ( 1'b0                       ),
     .i_lsb_sample ( counter_error_lsb_we       ),
     .o_msb        ( counter_error_msb          ),
     .o_lsb        ( counter_error_lsb          )
  );

  counter64 counter_good (
     .i_areset     ( i_areset             ),
     .i_clk        ( i_clk                ),
     .i_inc        ( i_rx_good_frame      ),
     .i_rst        ( 1'b0                 ),
     .i_lsb_sample ( counter_good_lsb_we  ),
     .o_msb        ( counter_good_msb     ),
     .o_lsb        ( counter_good_lsb     )
  );

  counter64 counter_packets_discarded (
     .i_areset     ( i_areset                            ),
     .i_clk        ( i_clk                               ),
     .i_inc        ( counter_packets_discarded_nts_inc |
                     counter_packets_discarded_other_inc ),
     .i_rst        ( counter_packets_discarded_rst       ),
     .i_lsb_sample ( counter_packets_discarded_lsb_we    ),
     .o_msb        ( counter_packets_discarded_msb       ),
     .o_lsb        ( counter_packets_discarded_lsb       )
  );

  counter64 counter_packets_received (
     .i_areset     ( i_areset                  ),
     .i_clk        ( i_clk                     ),
     .i_inc        ( i_rx_good_frame           ),
     .i_rst        ( counter_packets_rx_rst    ),
     .i_lsb_sample ( counter_packets_rx_lsb_we ),
     .o_msb        ( counter_packets_rx_msb    ),
     .o_lsb        ( counter_packets_rx_lsb    )
  );

  counter64 counter_start_of_frame (
     .i_areset     ( i_areset                  ),
     .i_clk        ( i_clk                     ),
     .i_inc        ( d_start_of_frame          ),
     .i_rst        ( 1'b0                      ),
     .i_lsb_sample ( counter_sof_detect_lsb_we ),
     .o_msb        ( counter_sof_detect_msb    ),
     .o_lsb        ( counter_sof_detect_lsb    )
  );

  always @*
  begin : engines_ready_counter
    reg [31:0] counter;
    integer i;
    counter = 0;
    for (i = 0; i < ENGINES; i = i + 1)
       if (!i_dispatch_busy[i]) counter = counter + 1;
    engines_ready_new = counter;
  end

  //----------------------------------------------------------------
  // Enigne MUX handling
  //----------------------------------------------------------------

  always @*
  begin: engine_reg_parser_mux
    reg         enable_by_ctrl;
    reg         enable_by_cmd;
    reg  [11:0] id;
    reg  [ 7:0] cmd;
    reg  [11:0] addr;
    integer  i;

    bus_cs_new = 0;
    bus_we_new = 0;
    bus_addr_new = 0;

    { id, cmd, addr } = engine_ctrl_reg;

    enable_by_cmd = 0;

    enable_by_ctrl = engine_status_reg[0];

    if (enable_by_ctrl) begin

      bus_addr_new = addr;

      case (cmd)
        BUS_READ:
          begin
            enable_by_cmd = 1;
          end
        BUS_WRITE:
          begin
            bus_we_new = 1;
            enable_by_cmd = 1;
          end
        default: ;
      endcase

      if (enable_by_cmd) begin
        for (i = 0; i < ENGINES; i = i + 1) begin
          if (id == i[11:0]) begin
            if (i_engine_api_busy[i] == 1'b0) begin
              if (i_engine_read_data_valid[i] == 1'b0) begin
                bus_cs_new[i] = 1;
              end
            end
          end
        end
      end

    end //enable_by_ctrl
  end

  //------------------------------------------
  // Mux engines to bus_read_data_mux
  //------------------------------------------

  always @*
  begin : engine_api_mux
    reg [11:0] id;
    integer i;
    id = engine_ctrl_reg[31-:12];;
    bus_read_data_mux = 0;
    bus_read_data_mux_valid = 0;
    for (i = 0; i < ENGINES; i = i + 1) begin
      if (id == i[11:0]) begin
        if (i_engine_read_data_valid[i] == 1) begin
          bus_read_data_mux       = i_engine_read_data[i*32+:32];
          bus_read_data_mux_valid = 1;
        end
      end
    end
  end

  //------------------------------------------
  // Preprocessor
  //  - Determines if packet to be handled as NTS.
  //  - Converts oc_mac format to 64BE,4DV format.
  //------------------------------------------

  preprocessor preprocessor (
    .i_clk           ( i_clk           ),
    .i_areset        ( i_areset        ),
    .i_rx_data_valid ( i_rx_data_valid ),
    .i_rx_data       ( i_rx_data       ),
    .i_rx_bad_frame  ( i_rx_bad_frame  ),
    .i_rx_good_frame ( i_rx_good_frame ),

    .o_rx_data_be    ( d_data0         ),
    .o_rx_valid4bit  ( d_valid4bits    ),
    .o_packet_nts    ( d_is_nts        ),
    .o_packet_other  ( d_is_other      ),
    .o_packet_drop   ( d_is_drop       ),
    .o_ethernet_good ( d_good          ),
    .o_ethernet_bad  ( d_bad           ),

    .o_sof ( d_start_of_frame )
  );

  //------------------------------------------
  // RX processing (NTS)
  //------------------------------------------

  always @*
  begin : mac_rx_proc_nts

    counter_packets_discarded_nts_inc = 0;

    nts_discard_new = 0;

    nts_rd_start_new = 0;
    nts_rd_data_new = 0;
    nts_rd_valid_new = 0;
    nts_rd_lwdv_new = 0;

    nts_state_we = 0;
    nts_state_new = STATE_IDLE;

    case (nts_state_reg)
      STATE_IDLE:
        begin
          if (d_is_nts) begin
            if (dispatcher_enabled_reg == 1'b0) begin

            end else if (mux_nts_busy) begin
              counter_packets_discarded_nts_inc = 1;

            end else if (mux_nts_ready == 1'b0) begin
              counter_packets_discarded_nts_inc = 1;

            end else begin
              nts_state_we = 1;
              nts_state_new = STATE_FORWARDING;
              nts_rd_start_new = 1;
              nts_rd_data_new  = d_data0;
              nts_rd_valid_new = 1;
              nts_rd_lwdv_new = d_valid4bits;
            end
          end
        end
      STATE_FORWARDING:
        begin
          if (d_valid4bits != 0) begin
            nts_rd_data_new  = d_data0;
            nts_rd_valid_new = 1;
            nts_rd_lwdv_new = d_valid4bits;
          end
          if (d_good) begin
            nts_discard_new = 1;
            nts_state_we = 1;
            nts_state_new = STATE_IDLE;
          end
          if (d_bad) begin
            nts_discard_new = 1;
            nts_state_we = 1;
            nts_state_new = STATE_IDLE;
          end
        end
      default: //Default: Error handler
        begin
          nts_state_we = 1;
          nts_state_new = STATE_IDLE;
         end
    endcase
  end

  //------------------------------------------
  // RX processing (other protocols)
  //------------------------------------------

  always @*
  begin : mac_rx_proc_mini

    counter_packets_discarded_other_inc = 0;

    mini_discard_new = 0;

    mini_rd_start_new = 0;
    mini_rd_data_new = 0;
    mini_rd_valid_new = 0;
    mini_rd_lwdv_new = 0;

    mini_state_we = 0;
    mini_state_new = 0;

    case (mini_state_reg)
      STATE_IDLE:
        begin
          if (d_is_other) begin
            if (dispatcher_enabled_reg == 1'b0) begin

            end else if (mux_mini_busy) begin
              counter_packets_discarded_other_inc = 1;

            end else if (mux_mini_ready == 1'b0) begin
              counter_packets_discarded_other_inc = 1;

            end else begin
              mini_state_we = 1;
              mini_state_new = STATE_FORWARDING;
              mini_rd_start_new = 1;
              mini_rd_data_new  = d_data0;
              mini_rd_valid_new = 1;
              mini_rd_lwdv_new = d_valid4bits;
            end
          end
        end
      STATE_FORWARDING:
        begin
          if (d_valid4bits != 0) begin
            mini_rd_data_new  = d_data0;
            mini_rd_valid_new = 1;
            mini_rd_lwdv_new = d_valid4bits;
          end
          if (d_good) begin
            mini_discard_new = 1;
            mini_state_we = 1;
            mini_state_new = STATE_IDLE;
          end
          if (d_bad) begin
            mini_discard_new = 1;
            mini_state_we = 1;
            mini_state_new = STATE_IDLE;
          end
        end
      default: //Default: Error handler
        begin
          mini_state_we = 1;
          mini_state_new = STATE_IDLE;
         end
    endcase
  end

  //------------------------------------------
  // Byte counter
  //------------------------------------------

  always @*
  begin : mac_rx_byte_counter
    counter_bytes_rx_we = 0;
    counter_bytes_rx_new = 0;

    if (counter_bytes_rx_rst) begin
      counter_bytes_rx_we = 1;
      counter_bytes_rx_new = 0;
    end else if (d_valid4bits != 0) begin
      counter_bytes_rx_we = 1;
      counter_bytes_rx_new = counter_bytes_rx_reg + { 60'h0, d_valid4bits }; //TODO optimize
    end

  end

endmodule
