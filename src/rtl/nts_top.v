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

module nts_top #(
  parameter ENGINES_NTS     = 2,
  parameter ENGINES_MINI    = 2,
  parameter ADDR_WIDTH      = 8,
  parameter API_ADDR_WIDTH  = 12,
  parameter API_RW_WIDTH    = 32,
  parameter MAC_DATA_WIDTH  = 64
) (
  input  wire i_areset, // async reset
  input  wire i_clk,

  input  wire                [7:0] i_mac_rx_data_valid,
  input  wire [MAC_DATA_WIDTH-1:0] i_mac_rx_data,
  input  wire                      i_mac_rx_bad_frame,
  input  wire                      i_mac_rx_good_frame,

  output wire                      o_mac_tx_start,
  input  wire                      i_mac_tx_ack,
  output wire                [7:0] o_mac_tx_data_valid,
  output wire [MAC_DATA_WIDTH-1:0] o_mac_tx_data,

  input  wire               [63:0] i_ntp_time,

  //Dispatcher API interface.
  input  wire                        i_api_dispatcher_cs,
  input  wire                        i_api_dispatcher_we,
  input  wire [API_ADDR_WIDTH - 1:0] i_api_dispatcher_address,
  input  wire   [API_RW_WIDTH - 1:0] i_api_dispatcher_write_data,
  output wire   [API_RW_WIDTH - 1:0] o_api_dispatcher_read_data
);

  localparam ENGINES = ENGINES_NTS + ENGINES_MINI;
  localparam LAST_DATA_VALID_WIDTH = 4;

  reg               [63:0] ntp_time_reg;
  reg                [7:0] rx_data_valid_reg;
  reg [MAC_DATA_WIDTH-1:0] rx_data_reg;
  reg                      rx_bad_frame_reg;
  reg                      rx_good_frame_reg;

  wire                  [ENGINES - 1:0] api_busy;
  wire                  [ENGINES - 1:0] api_cs;
  wire                                  api_we;
  wire           [API_ADDR_WIDTH - 1:0] api_address;
  wire             [API_RW_WIDTH - 1:0] api_write_data;
  wire   [API_RW_WIDTH * ENGINES - 1:0] api_read_data;
  wire                  [ENGINES - 1:0] api_read_data_valid;

  wire [ENGINES-1:0] engine_busy;
  wire [ENGINES-1:0] engine_dispatch_rx_ready;

  wire [LAST_DATA_VALID_WIDTH * ENGINES - 1 : 0] dispatch_engine_rx_data_last_valid;
  wire                         [ENGINES - 1 : 0] dispatch_engine_rx_fifo_empty;
  wire                         [ENGINES - 1 : 0] dispatch_engine_rx_fifo_rd_valid;
  wire        [MAC_DATA_WIDTH * ENGINES - 1 : 0] dispatch_engine_rx_fifo_rd_data;
  wire                         [ENGINES - 1 : 0] dispatch_engine_rx_fifo_rd_start;

  wire                         [ENGINES - 1 : 0] engine_extractor_packet_available;
  wire                         [ENGINES - 1 : 0] engine_extractor_fifo_empty;
  wire                         [ENGINES - 1 : 0] engine_extractor_fifo_rd_valid;
  wire        [MAC_DATA_WIDTH * ENGINES - 1 : 0] engine_extractor_fifo_rd_data;
  wire [LAST_DATA_VALID_WIDTH * ENGINES - 1 : 0] engine_extractor_bytes_last_word;

  wire                         [ENGINES - 1 : 0] extractor_engine_packet_read;
  wire                         [ENGINES - 1 : 0] extractor_engine_fifo_rd_start;

  wire   [API_RW_WIDTH - 1:0] api_extractor_read_data;
  wire   [API_RW_WIDTH - 1:0] api_dispatcher_read_data;

  assign o_api_dispatcher_read_data = api_dispatcher_read_data | api_extractor_read_data;

  //----------------------------------------------------------------
  // Buffer inputs
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  if (i_areset) begin
    ntp_time_reg      <= 0;
    rx_data_valid_reg <= 0;
    rx_data_reg       <= 0;
    rx_bad_frame_reg  <= 0;
    rx_good_frame_reg <= 0;
  end else begin
    ntp_time_reg      <= i_ntp_time;
    rx_data_valid_reg <= i_mac_rx_data_valid;
    rx_data_reg       <= i_mac_rx_data;
    rx_bad_frame_reg  <= i_mac_rx_bad_frame;
    rx_good_frame_reg <= i_mac_rx_good_frame;
  end

  //----------------------------------------------------------------
  // Dispatcher
  //----------------------------------------------------------------

  nts_dispatcher #(
     .ENGINES(ENGINES),
     .ENGINES_NTS(ENGINES_NTS),
     .ENGINES_MINI(ENGINES_MINI),
     .ADDR_WIDTH(ADDR_WIDTH)
  ) dispatcher (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .i_ntp_time(ntp_time_reg),

    .i_rx_data_valid(rx_data_valid_reg),
    .i_rx_data(rx_data_reg),
    .i_rx_bad_frame(rx_bad_frame_reg),
    .i_rx_good_frame(rx_good_frame_reg),

    .i_dispatch_busy               ( engine_busy                            ),
    .i_dispatch_ready              ( engine_dispatch_rx_ready               ),
    .o_dispatch_data_valid         ( dispatch_engine_rx_data_last_valid     ),
    .o_dispatch_fifo_empty         ( dispatch_engine_rx_fifo_empty          ),
    .o_dispatch_fifo_rd_start      ( dispatch_engine_rx_fifo_rd_start       ),
    .o_dispatch_fifo_rd_valid      ( dispatch_engine_rx_fifo_rd_valid       ),
    .o_dispatch_fifo_rd_data       ( dispatch_engine_rx_fifo_rd_data        ),

    .i_api_cs(i_api_dispatcher_cs),
    .i_api_we(i_api_dispatcher_we),
    .i_api_address(i_api_dispatcher_address),
    .i_api_write_data(i_api_dispatcher_write_data),
    .o_api_read_data(api_dispatcher_read_data),

    .i_engine_api_busy(api_busy),
    .o_engine_cs(api_cs),
    .o_engine_we(api_we),
    .o_engine_address(api_address),
    .o_engine_write_data(api_write_data),
    .i_engine_read_data(api_read_data),
    .i_engine_read_data_valid(api_read_data_valid)
  );


  //----------------------------------------------------------------
  // Extractor
  //----------------------------------------------------------------

  nts_extractor #( .ENGINES(ENGINES) ) extractor (
    .i_areset(i_areset),
    .i_clk(i_clk),
    .i_api_cs(i_api_dispatcher_cs),
    .i_api_we(i_api_dispatcher_we),
    .i_api_address(i_api_dispatcher_address),
    .i_api_write_data(i_api_dispatcher_write_data),
    .o_api_read_data(api_extractor_read_data),
    .o_mac_tx_start(o_mac_tx_start),
    .i_mac_tx_ack(i_mac_tx_ack),
    .o_mac_tx_data_valid(o_mac_tx_data_valid),
    .o_mac_tx_data(o_mac_tx_data),

    .i_engine_packet_available( engine_extractor_packet_available ),
    .o_engine_packet_read     ( extractor_engine_packet_read      ),
    .i_engine_fifo_empty      ( engine_extractor_fifo_empty       ),
    .o_engine_fifo_rd_start   ( extractor_engine_fifo_rd_start    ),
    .i_engine_fifo_rd_valid   ( engine_extractor_fifo_rd_valid    ),
    .i_engine_fifo_rd_data    ( engine_extractor_fifo_rd_data     ),
    .i_engine_bytes_last_word ( engine_extractor_bytes_last_word  )
  );

  //----------------------------------------------------------------
  // NTS Engine(s)
  //----------------------------------------------------------------

  localparam [ENGINES-1:0] SUPPORT_NTS      = {{ENGINES_MINI{1'b0}},{ENGINES_NTS{1'b1}}};
  localparam [ENGINES-1:0] SUPPORT_NTP_AUTH = {{ENGINES_MINI{1'b1}},{ENGINES_NTS{1'b0}}};
  localparam [ENGINES-1:0] SUPPORT_NTP      = {{ENGINES_MINI{1'b0}},{ENGINES_NTS{1'b1}}};
  localparam [ENGINES-1:0] SUPPORT_NET      = {{ENGINES_MINI{1'b1}},{ENGINES_NTS{1'b0}}};
  genvar engine_index;
  generate
    for (engine_index = 0; engine_index < ENGINES; engine_index = engine_index + 1) begin : genblk1
      nts_engine #(
        .ADDR_WIDTH      ( ADDR_WIDTH),
        .SUPPORT_NTS     ( SUPPORT_NTS[engine_index]      ),
        .SUPPORT_NTP_AUTH( SUPPORT_NTP_AUTH[engine_index] ),
        .SUPPORT_NTP     ( SUPPORT_NTP[engine_index]      ),
        .SUPPORT_NET     ( SUPPORT_NET[engine_index]      )
      ) engine (
        .i_areset(i_areset),
        .i_clk(i_clk),

        .i_ntp_time(ntp_time_reg),

        .o_busy(engine_busy[engine_index]),

        .o_dispatch_rx_ready(engine_dispatch_rx_ready[engine_index]),
        .i_dispatch_rx_data_last_valid(dispatch_engine_rx_data_last_valid[LAST_DATA_VALID_WIDTH*engine_index+:LAST_DATA_VALID_WIDTH]),
        .i_dispatch_rx_fifo_empty(dispatch_engine_rx_fifo_empty[engine_index]),
        .i_dispatch_rx_fifo_rd_start(dispatch_engine_rx_fifo_rd_start[engine_index]),
        .i_dispatch_rx_fifo_rd_valid(dispatch_engine_rx_fifo_rd_valid[engine_index]),
        .i_dispatch_rx_fifo_rd_data(dispatch_engine_rx_fifo_rd_data[MAC_DATA_WIDTH*engine_index+:MAC_DATA_WIDTH]),

        .o_dispatch_tx_packet_available(engine_extractor_packet_available[engine_index]),
        .i_dispatch_tx_packet_read(extractor_engine_packet_read[engine_index]),
        .o_dispatch_tx_fifo_empty(engine_extractor_fifo_empty[engine_index]),
        .i_dispatch_tx_fifo_rd_start(extractor_engine_fifo_rd_start[engine_index]),
        .o_dispatch_tx_fifo_rd_valid(engine_extractor_fifo_rd_valid[engine_index]),
        .o_dispatch_tx_fifo_rd_data(engine_extractor_fifo_rd_data[MAC_DATA_WIDTH*engine_index+:MAC_DATA_WIDTH]),
        .o_dispatch_tx_bytes_last_word(engine_extractor_bytes_last_word[LAST_DATA_VALID_WIDTH*engine_index+:LAST_DATA_VALID_WIDTH]),

        .o_api_busy(api_busy[engine_index]),
        .i_api_cs(api_cs[engine_index]),
        .i_api_we(api_we),
        .i_api_address(api_address),
        .i_api_write_data(api_write_data),
        .o_api_read_data(api_read_data[API_RW_WIDTH*engine_index+:API_RW_WIDTH]),
        .o_api_read_data_valid(api_read_data_valid[engine_index])
      );
    end
  endgenerate

endmodule
