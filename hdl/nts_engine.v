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
  parameter ADDR_WIDTH = 8
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

  localparam ACCESS_PORT_WIDTH       = 64;

  localparam STATE_RESET             = 4'h0;
  localparam STATE_EMPTY             = 4'h1;
  localparam STATE_COPY              = 4'h2;
  localparam STATE_ERROR_BAD_PACKET  = 4'hc;
  localparam STATE_ERROR_OVERFLOW    = 4'hd;
  localparam STATE_ERROR_GENERAL     = 4'he;
  localparam STATE_TO_BE_IMPLEMENTED = 4'hf;

  //----------------------------------------------------------------
  // Regs for Muxes
  //----------------------------------------------------------------

  reg                  mux_tx_write_en;
  reg           [63:0] mux_tx_write_data;
  reg                  mux_tx_address_internal;
  reg [ADDR_WIDTH-1:0] mux_tx_address_hi;
  reg            [2:0] mux_tx_address_lo;

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

  wire                         timestamp_parser_busy;
  wire                         timestamp_tx_wr_en;
  wire                [ 2 : 0] timestamp_tx_header_block;
  wire                [63 : 0] timestamp_tx_header_data;

  wire                         parser_muxctrl_timestamp_ipv4;
  wire                         parser_muxctrl_timestamp_ipv6;


  wire                    crypto_parser_busy;
  wire                    crypto_parser_verify_tag_ok;
  wire                    parser_crypto_rx_op_copy_ad;
  wire                    parser_crypto_rx_op_copy_nonce;
  wire                    parser_crypto_rx_op_copy_pc;
  wire                    parser_crypto_rx_op_copy_tag;
  wire [ADDR_WIDTH+3-1:0] parser_crypto_rx_addr;
  wire              [9:0] parser_crypto_rx_bytes;
  wire                    parser_crypto_tx_op_copy_ad;
  wire                    parser_crypto_tx_op_store_nonce_tag;
  wire                    parser_crypto_tx_op_store_cookie;
  wire [ADDR_WIDTH+3-1:0] parser_crypto_tx_addr;
  wire              [9:0] parser_crypto_tx_bytes;
  wire                    parser_crypto_op_cookie_verify;
  wire                    parser_crypto_op_cookie_loadkeys;
  wire                    parser_crypto_op_cookie_rencrypt;
  wire                    parser_crypto_op_c2s_verify_auth;
  wire                    parser_crypto_op_s2c_generate_auth;
  wire                    rxbuf_crypto_wait;
  wire [ADDR_WIDTH+3-1:0] crypto_rxbuf_addr;
  wire              [2:0] crypto_rxbuf_wordsize;
  wire                    crypto_rxbuf_rd_en;
  wire                    crypto_rxbuf_rd_dv;
  wire             [63:0] crypto_rxbuf_rd_data;
  wire                    crypto_txbuf_read_en;
  wire             [63:0] txbuf_crypto_read_data;
  wire                    crypto_txbuf_write_en;
  wire             [63:0] crypto_txbuf_write_data;
  wire [ADDR_WIDTH+3-1:0] crypto_txbuf_address;
  wire                    crypto_noncegen_get;
  wire             [63:0] noncegen_crypto_nonce;
  wire                    noncegen_crypto_ready;

  wire             [31:0] ZERO;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign keymem_internal_get_current_key = 'b0;

  assign api_read_data_engine = 0; //TODO implement
  assign api_read_data_cookie = 0; //TODO implement
  assign api_read_data_debug  = 0; //TODO implement

  assign o_busy                          = parser_busy;

  assign o_detect_unique_identifier      = detect_unique_identifier;
  assign o_detect_nts_cookie             = detect_nts_cookie;
  assign o_detect_nts_cookie_placeholder = detect_nts_cookie_placeholder;
  assign o_detect_nts_authenticator      = detect_nts_authenticator;

  assign ZERO                            = 0;

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
  // Transmit Mux instantiation.
  //----------------------------------------------------------------

  always @*
  begin : tx_mux_vars
    reg [1:0] muxctrl;

    muxctrl = { parser_muxctrl_timestamp_ipv6, parser_muxctrl_timestamp_ipv4 };

    mux_tx_address_internal = 1;
    mux_tx_address_hi       = 0;
    mux_tx_address_lo       = 0;
    mux_tx_write_en         = parser_txbuf_write_en;
    mux_tx_write_data       = parser_txbuf_write_data;

    case (muxctrl)
      2'b01: //IPv4 timestamp
       begin
         mux_tx_address_internal = 0;
         mux_tx_address_hi       = 0;
         mux_tx_address_hi[2:0]  = timestamp_tx_header_block;
         mux_tx_address_hi       = mux_tx_address_hi + 5;
         mux_tx_address_lo       = 2;
         mux_tx_write_en         = timestamp_tx_wr_en;
         mux_tx_write_data       = timestamp_tx_header_data;
       end
      2'b10: //IPv6 timestamp
       begin
         mux_tx_address_internal = 0;
         mux_tx_address_hi       = 0;
         mux_tx_address_hi[2:0]  = timestamp_tx_header_block;
         mux_tx_address_hi       = mux_tx_address_hi + 7;
         mux_tx_address_lo       = 6;
         mux_tx_write_en         = timestamp_tx_wr_en;
         mux_tx_write_data       = timestamp_tx_header_data;
       end
      default: ;
    endcase;

  end


  //----------------------------------------------------------------
  // Transmit Buffer instantiation.
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

    .i_write_en(mux_tx_write_en),
    .i_write_data(mux_tx_write_data),

    .i_address_internal(mux_tx_address_internal),
    .i_address_hi(mux_tx_address_hi),
    .i_address_lo(mux_tx_address_lo),

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

   .i_timestamp_busy(timestamp_parser_busy),
   .o_timestamp_record_receive_timestamp(parser_timestamp_record_rectime),
   .o_timestamp_transmit(parser_timestamp_transmit),
   .o_timestamp_origin_timestamp(parser_timestamp_client_orgtime),
   .o_timestamp_version_number(parser_timestamp_client_version),
   .o_timestamp_poll(parser_timestamp_client_poll),

   .o_muxctrl_timestamp_ipv4(parser_muxctrl_timestamp_ipv4),
   .o_muxctrl_timestamp_ipv6(parser_muxctrl_timestamp_ipv6),

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

    .o_busy(timestamp_parser_busy),

    // Parsed information
    .i_parser_clear(parser_txbuf_clear), //parser request ignore current packet
    .i_parser_record_receive_timestamp(parser_timestamp_record_rectime),
    .i_parser_transmit(parser_timestamp_transmit), //parser signal packet transmit OK
    .i_parser_origin_timestamp(parser_timestamp_client_orgtime),
    .i_parser_version_number(parser_timestamp_client_version),
    .i_parser_poll(parser_timestamp_client_poll),

    .o_tx_wr_en(timestamp_tx_wr_en),
    .o_tx_ntp_header_block(timestamp_tx_header_block),
    .o_tx_ntp_header_data(timestamp_tx_header_data),

    // API access
    .i_api_cs(api_cs_clock),
    .i_api_we(api_we),
    .i_api_address(api_address),
    .i_api_write_data(api_write_data),
    .o_api_read_data(api_read_data_clock)
  );

  //----------------------------------------------------------------
  // NTS Verify Secure instantiation.
  //----------------------------------------------------------------

  nts_verify_secure crypto (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .o_busy         ( crypto_parser_busy ),

    .o_verify_tag_ok( crypto_parser_verify_tag_ok ),

    .i_key_word   ( keymem_internal_key_word   ),
    .i_key_valid  ( keymem_internal_key_valid  ),
    .i_key_length ( keymem_internal_key_length ),
    .i_key_data   ( keymem_internal_key_data   ),

    .i_unrwapped_s2c  ( ZERO[ 0:0] ),
    .i_unwrapped_c2s  ( ZERO[ 0:0] ),
    .i_unwrapped_word ( ZERO[ 2:0] ),
    .i_unwrapped_data ( ZERO[31:0] ),

    .i_op_copy_rx_ad    ( parser_crypto_rx_op_copy_ad    ),
    .i_op_copy_rx_nonce ( parser_crypto_rx_op_copy_nonce ),
    .i_op_copy_rx_pc    ( parser_crypto_rx_op_copy_pc    ),
    .i_op_copy_rx_tag   ( parser_crypto_rx_op_copy_tag   ),
    .i_copy_rx_addr     ( parser_crypto_rx_addr          ), //Specify memory address in RX buf
    .i_copy_rx_bytes    ( parser_crypto_rx_bytes         ),

    .i_op_copy_tx_ad         ( parser_crypto_tx_op_copy_ad         ), //Read packet stored in TX buff for transfer
    .i_op_store_tx_nonce_tag ( parser_crypto_tx_op_store_nonce_tag ), //Write raw packet auth: (nonce)(tag)
    .i_op_store_tx_cookie    ( parser_crypto_tx_op_store_cookie    ), //Write raw cookie: (nonce)(tag)(ciphertext)
    .i_copy_tx_addr          ( parser_crypto_tx_addr               ), //Specify memory address in TX buf
    .i_copy_tx_bytes         ( parser_crypto_tx_bytes              ),

    .i_op_cookie_verify      ( parser_crypto_op_cookie_verify   ), //Decipher and authenticate (nonce)(tag)(ciphertext) user server key
    .i_op_cookie_loadkeys    ( parser_crypto_op_cookie_loadkeys ), //Copy S2C, C2S from RAM to Registers,
    .i_op_cookie_rencrypt    ( parser_crypto_op_cookie_rencrypt ), //Encrypt (nonce)(plaintext) into (nonce)(tag)(ciphertext)

    .i_op_verify_c2s   ( parser_crypto_op_c2s_verify_auth   ), //Authenticate an incomming packet using C2S key
    .i_op_generate_tag ( parser_crypto_op_s2c_generate_auth ), //Authenticate an outbound packet using S2C key

    .i_rx_wait     ( rxbuf_crypto_wait     ),
    .o_rx_addr     ( crypto_rxbuf_addr     ),
    .o_rx_wordsize ( crypto_rxbuf_wordsize ),
    .o_rx_rd_en    ( crypto_rxbuf_rd_en    ),
    .i_rx_rd_dv    ( crypto_rxbuf_rd_dv    ),
    .i_rx_rd_data  ( crypto_rxbuf_rd_data  ),

    .o_tx_read_en    ( crypto_txbuf_read_en    ),
    .i_tx_read_data  ( txbuf_crypto_read_data  ),
    .o_tx_write_en   ( crypto_txbuf_write_en   ),
    .o_tx_write_data ( crypto_txbuf_write_data ),
    .o_tx_address    ( crypto_txbuf_address    ),

    .o_noncegen_get   ( crypto_noncegen_get   ),
    .i_noncegen_nonce ( noncegen_crypto_nonce ),
    .i_noncegen_ready ( noncegen_crypto_ready )

  );

  //----------------------------------------------------------------

endmodule
