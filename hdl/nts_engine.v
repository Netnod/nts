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

module nts_engine #(
  parameter ADDR_WIDTH = 10
) (
  input  wire                  i_areset, // async reset
  input  wire                  i_clk,
  output wire                  o_busy,

  input wire  [63:0]           i_ntp_time,

  input  wire                  i_dispatch_rx_packet_available,
  output wire                  o_dispatch_rx_packet_read_discard,
  input  wire [7:0]            i_dispatch_rx_data_valid,
  input  wire                  i_dispatch_rx_fifo_empty,
  output wire                  o_dispatch_rx_fifo_rd_en,
  input  wire [63:0]           i_dispatch_rx_fifo_rd_data,

  output wire                  o_dispatch_tx_packet_available,
  input  wire                  i_dispatch_tx_packet_read,
  output wire                  o_dispatch_tx_fifo_empty,
  input  wire                  i_dispatch_tx_fifo_rd_en,
  output wire [63:0]           o_dispatch_tx_fifo_rd_data,
  output wire  [3:0]           o_dispatch_tx_bytes_last_word,

  input  wire                  i_api_cs,
  input  wire                  i_api_we,
  input  wire [11:0]           i_api_address,
  input  wire [31:0]           i_api_write_data,
  output wire [31:0]           o_api_read_data,

  output wire                  o_detect_unique_identifier,
  output wire                  o_detect_nts_cookie,
  output wire                  o_detect_nts_cookie_placeholder,
  output wire                  o_detect_nts_authenticator
);

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam ACCESS_PORT_WIDTH       = 32;

  localparam STATE_RESET             = 4'h0;
  localparam STATE_EMPTY             = 4'h1;
  localparam STATE_COPY              = 4'h2;
  localparam STATE_ERROR_BAD_PACKET  = 4'hc;
  localparam STATE_ERROR_OVERFLOW    = 4'hd;
  localparam STATE_ERROR_GENERAL     = 4'he;
  localparam STATE_TO_BE_IMPLEMENTED = 4'hf;

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  wire                         access_port_wait;
  wire      [ADDR_WIDTH+3-1:0] access_port_addr;
  wire                   [2:0] access_port_wordsize;
  wire                         access_port_rd_en;
  wire                         access_port_rd_dv;
  wire [ACCESS_PORT_WIDTH-1:0] access_port_rd_data;

  wire                         detect_unique_identifier;
  wire                         detect_nts_cookie;
  wire                         detect_nts_cookie_placeholder;
  wire                         detect_nts_authenticator;

  wire                         api_cs_engine;
  wire                         api_cs_clock;
  wire                         api_cs_cookie;
  wire                         api_cs_keymem;
  wire                         api_cs_debug;

  wire                [31 : 0] api_read_data_engine;
  wire                [31 : 0] api_read_data_clock;
  wire                [31 : 0] api_read_data_cookie;
  wire                [31 : 0] api_read_data_keymem;
  wire                [31 : 0] api_read_data_debug;

  wire                         api_we;
  wire                 [7 : 0] api_address;
  wire                [31 : 0] api_write_data;

  wire                         keymem_internal_get_current_key;
  wire                         keymem_internal_get_key_with_id;
  wire                [31 : 0] keymem_internal_server_key_id;
  wire                 [3 : 0] keymem_internal_key_word;
  wire                         keymem_internal_key_valid;
  wire                         keymem_internal_key_length;
  wire                [31 : 0] keymem_internal_key_id;
  wire                [31 : 0] keymem_internal_key_data;
  wire                         keymem_internal_ready;

  wire                         parser_busy;

  wire                         parser_txbuf_clear;
  wire                         parser_txbuf_write_en;
  wire                  [63:0] parser_txbuf_write_data;
  wire                         parser_txbuf_ipv4_done;
  wire                         parser_txbuf_ipv6_done;

  wire                         txbuf_parser_full;
  wire                         txbuf_parser_empty;

  wire                         parser_timestamp_record_rectime;
  wire                         parser_timestamp_transmit;
  wire                [63 : 0] parser_timestamp_client_orgtime;
  wire                [ 2 : 0] parser_timestamp_client_version;
  wire                [ 7 : 0] parser_timestamp_client_poll;

  wire                         tx_timestamp_read;
  wire                         timestamp_tx_empty;
  wire                [ 2 : 0] timestamp_tx_header_block;
  wire                [63 : 0] timestamp_tx_header_data;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign keymem_internal_get_current_key = 'b0;

  assign api_read_data_engine = 0; //TODO implement
  assign api_read_data_cookie = 0; //TODO implement
  assign api_read_data_debug  = 0; //TODO implement

  assign parser_timestamp_record_rectime = 0; //TODO implement
  assign parser_timestamp_transmit       = 0; //TODO implement
  assign parser_timestamp_client_orgtime = 0; //TODO implement
  assign parser_timestamp_client_version = 0; //TODO implement
  assign parser_timestamp_client_poll    = 0; //TODO implement

  assign tx_timestamp_read               = 0; //TODO implement

  assign o_busy                          = parser_busy;

  assign o_detect_unique_identifier      = detect_unique_identifier;
  assign o_detect_nts_cookie             = detect_nts_cookie;
  assign o_detect_nts_cookie_placeholder = detect_nts_cookie_placeholder;
  assign o_detect_nts_authenticator      = detect_nts_authenticator;

  //----------------------------------------------------------------
  // API instantiation.
  //----------------------------------------------------------------

  nts_api api (
    .i_external_api_cs(i_api_cs),
    .i_external_api_we(i_api_we),
    .i_external_api_address(i_api_address),
    .i_external_api_write_data(i_api_write_data),
    .o_external_api_read_data(o_api_read_data),

    .o_internal_api_we(api_we),
    .o_internal_api_address(api_address),
    .o_internal_api_write_data(api_write_data),

    .o_internal_engine_api_cs(api_cs_engine),
    .i_internal_engine_api_read_data(api_read_data_engine),

    .o_internal_clock_api_cs(api_cs_clock),
    .i_internal_clock_api_read_data(api_read_data_clock),

    .o_internal_cookie_api_cs(api_cs_cookie),
    .i_internal_cookie_api_read_data(api_read_data_cookie),

    .o_internal_keymem_api_cs(api_cs_keymem),
    .i_internal_keymem_api_read_data(api_read_data_keymem),

    .o_internal_debug_api_cs(api_cs_debug),
    .i_internal_debug_api_read_data(api_read_data_debug)
  );

  //----------------------------------------------------------------
  // Receive buffer instantiation.
  //----------------------------------------------------------------

  nts_rx_buffer #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .ACCESS_PORT_WIDTH(ACCESS_PORT_WIDTH)
  ) rx_buffer (
     .i_areset(i_areset),
     .i_clk(i_clk),

     .i_clear(parser_txbuf_clear), //Reset RX if TX reset issued.

     .i_parser_busy(parser_busy),

     .i_dispatch_packet_available(i_dispatch_rx_packet_available),
     .o_dispatch_packet_read(o_dispatch_rx_packet_read_discard),
     .i_dispatch_fifo_empty(i_dispatch_rx_fifo_empty),
     .o_dispatch_fifo_rd_en(o_dispatch_rx_fifo_rd_en),
     .i_dispatch_fifo_rd_data(i_dispatch_rx_fifo_rd_data),

     .o_access_port_wait(access_port_wait),
     .i_access_port_addr(access_port_addr),
     .i_access_port_wordsize(access_port_wordsize),
     .i_access_port_rd_en(access_port_rd_en),
     .o_access_port_rd_dv(access_port_rd_dv),
     .o_access_port_rd_data(access_port_rd_data)
  );

  //----------------------------------------------------------------
  // Transmit Vuffer instantiation.
  //----------------------------------------------------------------

  nts_tx_buffer #(
    .ADDR_WIDTH(ADDR_WIDTH)
  ) tx_buffer (
    .i_areset(i_areset), // async reset
    .i_clk(i_clk),

    .o_dispatch_tx_packet_available(o_dispatch_tx_packet_available),
    .i_dispatch_tx_packet_read(i_dispatch_tx_packet_read),
    .o_dispatch_tx_fifo_empty(o_dispatch_tx_fifo_empty),
    .i_dispatch_tx_fifo_rd_en(i_dispatch_tx_fifo_rd_en),
    .o_dispatch_tx_fifo_rd_data(o_dispatch_tx_fifo_rd_data),
    .o_dispatch_tx_bytes_last_word(o_dispatch_tx_bytes_last_word),

    .i_parser_clear(parser_txbuf_clear),
    .i_parser_w_en(parser_txbuf_write_en),
    .i_parser_w_data(parser_txbuf_write_data),

    .i_parser_ipv4_done(parser_txbuf_ipv4_done),
    .i_parser_ipv6_done(parser_txbuf_ipv6_done),

    .o_parser_current_memory_full(txbuf_parser_full),
    .o_parser_current_empty(txbuf_parser_empty)
  );

  //----------------------------------------------------------------
  // Parser Ctrl instantiation.
  //----------------------------------------------------------------

  nts_parser_ctrl #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .ACCESS_PORT_WIDTH(ACCESS_PORT_WIDTH)
  ) parser (
   .i_areset(i_areset),
   .i_clk(i_clk),

   .o_busy(parser_busy),

   .i_clear(1'b0), //currently no soft reset implemented

   .i_process_initial(o_dispatch_rx_fifo_rd_en),
   .i_last_word_data_valid(i_dispatch_rx_data_valid),
   .i_data(i_dispatch_rx_fifo_rd_data),

   .i_tx_empty(txbuf_parser_empty),
   .i_tx_full(txbuf_parser_full),
   .o_tx_clear(parser_txbuf_clear),
   .o_tx_w_en(parser_txbuf_write_en),
   .o_tx_w_data(parser_txbuf_write_data),
   .o_tx_ipv4_done(parser_txbuf_ipv4_done),
   .o_tx_ipv6_done(parser_txbuf_ipv6_done),

   .i_access_port_wait(access_port_wait),
   .o_access_port_addr(access_port_addr),
   .o_access_port_wordsize(access_port_wordsize),
   .o_access_port_rd_en(access_port_rd_en),
   .i_access_port_rd_dv(access_port_rd_dv),
   .i_access_port_rd_data(access_port_rd_data),

   .o_keymem_key_word(keymem_internal_key_word),
   .o_keymem_get_key_with_id(keymem_internal_get_key_with_id),
   .o_keymem_server_id(keymem_internal_server_key_id),
   .i_keymem_key_length(keymem_internal_key_length),
   .i_keymem_key_valid(keymem_internal_key_valid),
   .i_keymem_ready(keymem_internal_ready),

   .o_detect_unique_identifier(detect_unique_identifier),
   .o_detect_nts_cookie(detect_nts_cookie),
   .o_detect_nts_cookie_placeholder(detect_nts_cookie_placeholder),
   .o_detect_nts_authenticator(detect_nts_authenticator)
  );

  //----------------------------------------------------------------
  // Server Key Memory instantiation.
  //----------------------------------------------------------------

  keymem keymem (
    .clk(i_clk),
    .areset(i_areset),
    // API access
    .cs(api_cs_keymem),
    .we(api_we),
    .address(api_address),
    .write_data(api_write_data),
    .read_data(api_read_data_keymem),
    // Client access
    .get_current_key(keymem_internal_get_current_key),
    .get_key_with_id(keymem_internal_get_key_with_id),
    .server_key_id(keymem_internal_server_key_id),
    .key_word(keymem_internal_key_word),
    .key_valid(keymem_internal_key_valid),
    .key_length(keymem_internal_key_length),
    .key_id(keymem_internal_key_id),
    .key_data(keymem_internal_key_data),
    .ready(keymem_internal_ready)
  );

  //----------------------------------------------------------------
  // NTP Timestamp instantiation.
  //----------------------------------------------------------------

  nts_timestamp timestamp (
    .i_areset(i_areset), // async reset
    .i_clk(i_clk),

    .i_ntp_time(i_ntp_time),

    // Parsed information
    .i_parser_clear(parser_txbuf_clear), //parser request ignore current packet
    .i_parser_record_receive_timestamp(parser_timestamp_record_rectime),
    .i_parser_transmit(parser_timestamp_transmit), //parser signal packet transmit OK
    .i_parser_origin_timestamp(parser_timestamp_client_orgtime),
    .i_parser_version_number(parser_timestamp_client_version),
    .i_parser_poll(parser_timestamp_client_poll),

    .i_tx_read(tx_timestamp_read),
    .o_tx_empty(timestamp_tx_empty),
    .o_tx_ntp_header_block(timestamp_tx_header_block),
    .o_tx_ntp_header_data(timestamp_tx_header_data),

    // API access
    .i_api_cs(api_cs_clock),
    .i_api_we(api_we),
    .i_api_address(api_address),
    .i_api_write_data(api_write_data),
    .o_api_read_data(api_read_data_clock)
  );

endmodule
