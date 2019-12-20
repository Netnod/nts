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
  input  wire [7:0]            i_dispatch_rx_data_last_valid,
  input  wire                  i_dispatch_rx_fifo_empty,
  output wire                  o_dispatch_rx_fifo_rd_start,
  input  wire                  i_dispatch_rx_fifo_rd_valid,
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

  output wire                  o_noncegen_get,   //TODO incorporate internally later
  input  wire [63:0]           i_noncegen_data,  //TODO incorporate internally later
  input  wire                  i_noncegen_ready, //TODO incorporate internally later

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

  localparam CORE_NAME0   = 32'h4e_54_53_5f; // "NTS_"
  localparam CORE_NAME1   = 32'h45_4e_47_4e; // "ENGN"
  localparam CORE_VERSION = 32'h30_2e_30_31; // "0.02". 0.02: Basic TX development. 0.01: Basic RX development

  localparam ADDR_NAME0         = 'h00;
  localparam ADDR_NAME1         = 'h01;
  localparam ADDR_VERSION       = 'h02;
  localparam ADDR_CTRL          = 'h08; //TODO implement
  localparam ADDR_STATUS        = 'h09;

  localparam DEBUG_NAME = 32'h44_42_55_47; // "DBUG"

  localparam ADDR_DEBUG_NTS_PROCESSED  = 0;
  localparam ADDR_DEBUG_NTS_BAD_COOKIE = 2;
  localparam ADDR_DEBUG_NTS_BAD_AUTH   = 4;
  localparam ADDR_DEBUG_NTS_BAD_KEYID  = 6;
  localparam ADDR_DEBUG_NAME           = 8;
  localparam ADDR_DEBUG_SYSTICK32      = 9;
  localparam ADDR_DEBUG_ERROR_CRYPTO   = 'h20;
  localparam ADDR_DEBUG_ERROR_TXBUF    = 'h22;


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
  reg                          access_port_wait_parser;

  reg       [ADDR_WIDTH+3-1:0] access_port_addr;
  wire      [ADDR_WIDTH+3-1:0] access_port_addr_parser;

  reg                   [15:0] access_port_burstsize;
  wire                  [15:0] access_port_burstsize_parser;

  reg                    [2:0] access_port_wordsize;
  wire                   [2:0] access_port_wordsize_parser;

  reg                          access_port_rd_en;
  wire                         access_port_rd_en_parser;

  wire                         access_port_rd_dv;
  reg                          access_port_rd_dv_parser;

  wire [ACCESS_PORT_WIDTH-1:0] access_port_rd_data;
  reg                   [63:0] access_port_rd_data_parser;

  wire                         detect_unique_identifier;
  wire                         detect_nts_cookie;
  wire                         detect_nts_cookie_placeholder;
  wire                         detect_nts_authenticator;

  /* verilator lint_off UNUSED */
  wire                         api_cs_cookie; //TODO implement
  /* verilator lint_on UNUSED */
  wire                         api_cs_clock;
  wire                         api_cs_debug;
  wire                         api_cs_engine;
  wire                         api_cs_keymem;
  wire                         api_cs_parser;

  reg                 [31 : 0] api_read_data_engine;
  wire                [31 : 0] api_read_data_cookie;
  reg                 [31 : 0] api_read_data_debug;

  wire                [31 : 0] api_read_data_clock;
  wire                [31 : 0] api_read_data_keymem;
  wire                [31 : 0] api_read_data_parser;

  wire                         api_we;
  wire                 [7 : 0] api_address;
  wire                [31 : 0] api_write_data;

  wire                         keymem_internal_get_current_key;
  wire                         keymem_internal_get_key_with_id;
  wire                [31 : 0] keymem_internal_server_key_id;
  wire                 [2 : 0] keymem_internal_key_word;
  wire                         keymem_internal_key_valid;
  /* verilator lint_off UNUSED */
  wire                [31 : 0] keymem_internal_key_id; //TODO implement
  /* verilator lint_on UNUSED */
  wire                [31 : 0] keymem_internal_key_data;
  wire                         keymem_internal_ready;

  wire                         parser_busy;

  wire                         parser_txbuf_clear;
  wire                         parser_txbuf_address_internal;
  wire      [ADDR_WIDTH+3-1:0] parser_txbuf_address;
  wire                         parser_txbuf_write_en;
  wire                  [63:0] parser_txbuf_write_data;
  wire                         parser_txbuf_update_length;
  wire                         parser_txbuf_ipv4_done;
  wire                         parser_txbuf_ipv6_done;

  wire                         txbuf_error;
  wire                         txbuf_busy;
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

  wire                         parser_muxctrl_crypto;
  wire                         parser_muxctrl_timestamp_ipv4;
  wire                         parser_muxctrl_timestamp_ipv6;

  wire                         parser_statistics_nts_bad_auth;
  wire                         parser_statistics_nts_bad_cookie;
  wire                         parser_statistics_nts_bad_keyid;
  wire                         parser_statistics_nts_processed;


  wire                    crypto_parser_busy;
  wire                    crypto_error;
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
  reg                     rxbuf_crypto_wait;
  wire [ADDR_WIDTH+3-1:0] crypto_rxbuf_addr;
  wire              [2:0] crypto_rxbuf_wordsize;
  wire                    crypto_rxbuf_rd_en;
  reg                     rxbuf_crypto_rd_dv;
  reg              [63:0] rxbuf_crypto_rd_data;

  /* verilator lint_off UNUSED */
  wire                    crypto_txbuf_read_en;    //TODO implement
  wire             [63:0] txbuf_crypto_read_data;  //TODO implement
  wire                    crypto_txbuf_write_en;   //TODO implement
  wire             [63:0] crypto_txbuf_write_data; //TODO implement
  wire [ADDR_WIDTH+3-1:0] crypto_txbuf_address;    //TODO implement
  /* verilator lint_on UNUSED */

  wire                    crypto_noncegen_get;
  wire             [63:0] noncegen_crypto_nonce;
  wire                    noncegen_crypto_ready;

  wire             [31:0] ZERO;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign api_read_data_cookie = 0; //TODO implement

  assign o_busy                          = parser_busy;

  assign o_detect_unique_identifier      = detect_unique_identifier;
  assign o_detect_nts_cookie             = detect_nts_cookie;
  assign o_detect_nts_cookie_placeholder = detect_nts_cookie_placeholder;
  assign o_detect_nts_authenticator      = detect_nts_authenticator;

  assign o_noncegen_get        = crypto_noncegen_get; //TODO incorporate internally later
  assign noncegen_crypto_nonce = i_noncegen_data;     //TODO incorporate internally later
  assign noncegen_crypto_ready = i_noncegen_ready;    //TODO incorporate internally later

  assign txbuf_crypto_read_data = 0; //TODO implement

  assign ZERO = 0;

  //----------------------------------------------------------------
  // Debug registers
  //----------------------------------------------------------------
  reg        counter_nts_bad_auth_we;
  reg [63:0] counter_nts_bad_auth_new;
  reg [63:0] counter_nts_bad_auth_reg;
  reg        counter_nts_bad_auth_lsb_we;
  reg [31:0] counter_nts_bad_auth_lsb_reg;

  reg        counter_nts_bad_cookie_we;
  reg [63:0] counter_nts_bad_cookie_new;
  reg [63:0] counter_nts_bad_cookie_reg;
  reg        counter_nts_bad_cookie_lsb_we;
  reg [31:0] counter_nts_bad_cookie_lsb_reg;

  reg        counter_nts_bad_keyid_we;
  reg [63:0] counter_nts_bad_keyid_new;
  reg [63:0] counter_nts_bad_keyid_reg;
  reg        counter_nts_bad_keyid_lsb_we;
  reg [31:0] counter_nts_bad_keyid_lsb_reg;

  reg        counter_nts_processed_we;
  reg [63:0] counter_nts_processed_new;
  reg [63:0] counter_nts_processed_reg;
  reg        counter_nts_processed_lsb_we;
  reg [31:0] counter_nts_processed_lsb_reg;

  reg        counter_error_crypto_we;
  reg [63:0] counter_error_crypto_new;
  reg [63:0] counter_error_crypto_reg;
  reg        counter_error_crypto_lsb_we;
  reg [31:0] counter_error_crypto_lsb_reg;

  reg        counter_error_txbuf_we;
  reg [63:0] counter_error_txbuf_new;
  reg [63:0] counter_error_txbuf_reg;
  reg        counter_error_txbuf_lsb_we;
  reg [31:0] counter_error_txbuf_lsb_reg;

  reg [31:0] systick32_reg;

  always @*
  begin : reg_setter
    counter_nts_bad_auth_we    = 0;
    counter_nts_bad_auth_new   = 0;
    counter_nts_bad_cookie_we  = 0;
    counter_nts_bad_cookie_new = 0;
    counter_nts_bad_keyid_we   = 0;
    counter_nts_bad_keyid_new  = 0;
    counter_nts_processed_we   = 0;
    counter_nts_processed_new  = 0;

    counter_error_crypto_we  = 0;
    counter_error_crypto_new = 0;
    counter_error_txbuf_we   = 0;
    counter_error_txbuf_new  = 0;

    if (parser_statistics_nts_bad_auth) begin
      counter_nts_bad_auth_we = 1;
      counter_nts_bad_auth_new = counter_nts_bad_auth_reg + 1;
    end

    if (parser_statistics_nts_bad_cookie) begin
      counter_nts_bad_cookie_we = 1;
      counter_nts_bad_cookie_new = counter_nts_bad_cookie_reg + 1;
    end

    if (parser_statistics_nts_bad_keyid) begin
      counter_nts_bad_keyid_we = 1;
      counter_nts_bad_keyid_new = counter_nts_bad_keyid_reg + 1;
    end

    if (parser_statistics_nts_processed) begin
      counter_nts_processed_we = 1;
      counter_nts_processed_new = counter_nts_processed_reg + 1;
    end

    if (crypto_error) begin
      counter_error_crypto_we = 1;
      counter_error_crypto_new = counter_error_crypto_reg + 1;
    end

    if (txbuf_error) begin
      counter_error_txbuf_we = 1;
      counter_error_txbuf_new = counter_error_txbuf_reg + 1;
    end
  end

  //----------------------------------------------------------------
  // Register update
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_up
    if (i_areset) begin

      counter_nts_bad_auth_reg <= 0;
      counter_nts_bad_auth_lsb_reg <= 0;

      counter_nts_bad_cookie_reg <= 0;
      counter_nts_bad_cookie_lsb_reg <= 0;

      counter_nts_bad_keyid_reg <= 0;
      counter_nts_bad_keyid_lsb_reg <= 0;

      counter_nts_processed_reg <= 0;
      counter_nts_processed_lsb_reg <= 0;

      counter_error_crypto_reg <= 0;
      counter_error_crypto_lsb_reg <= 0;

      counter_error_txbuf_reg <= 0;
      counter_error_txbuf_lsb_reg <= 0;

      systick32_reg <= 32'h0000_0001;

    end else begin
      if (counter_nts_bad_auth_we)
        counter_nts_bad_auth_reg <= counter_nts_bad_auth_new;

      if (counter_nts_bad_auth_lsb_we)
        counter_nts_bad_auth_lsb_reg <= counter_nts_bad_auth_reg[31:0];

      if (counter_nts_bad_cookie_we)
        counter_nts_bad_cookie_reg <= counter_nts_bad_cookie_new;

      if (counter_nts_bad_cookie_lsb_we)
        counter_nts_bad_cookie_lsb_reg <= counter_nts_bad_cookie_reg[31:0];

      if (counter_nts_bad_keyid_we)
        counter_nts_bad_keyid_reg <= counter_nts_bad_keyid_new;

      if (counter_nts_bad_keyid_lsb_we)
        counter_nts_bad_keyid_lsb_reg <= counter_nts_bad_keyid_reg[31:0];

      if (counter_nts_processed_we)
        counter_nts_processed_reg <= counter_nts_processed_new;

      if (counter_nts_processed_lsb_we)
        counter_nts_processed_lsb_reg <= counter_nts_processed_reg[31:0];

      if (counter_error_crypto_we)
        counter_error_crypto_reg <= counter_error_crypto_new;

      if (counter_error_crypto_lsb_we)
        counter_error_crypto_lsb_reg <= counter_error_crypto_reg[31:0];

      if (counter_error_txbuf_we)
        counter_error_txbuf_reg <= counter_error_txbuf_new;

      if (counter_error_txbuf_lsb_we)
        counter_error_txbuf_lsb_reg <= counter_error_txbuf_reg[31:0];

      systick32_reg <= systick32_reg + 1;
    end
  end

  //----------------------------------------------------------------
  // NTS Engine API
  //----------------------------------------------------------------

  always @*
  begin
    api_read_data_engine = 0;
    if (api_cs_engine) begin
      if (api_we) begin
        ;
      end else begin
        case (api_address)
          ADDR_NAME0: api_read_data_engine = CORE_NAME0;
          ADDR_NAME1: api_read_data_engine = CORE_NAME1;
          ADDR_VERSION: api_read_data_engine = CORE_VERSION;
          ADDR_CTRL: api_read_data_engine = 32'h0000_0001;
          default: ;
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // NTS Debug API
  //----------------------------------------------------------------

  always @*
  begin
    api_read_data_debug = 0;
    counter_nts_bad_auth_lsb_we = 0;
    counter_nts_bad_cookie_lsb_we = 0;
    counter_nts_bad_keyid_lsb_we = 0;
    counter_nts_processed_lsb_we = 0;
    counter_error_crypto_lsb_we = 0;
    counter_error_txbuf_lsb_we = 0;

    if (api_cs_debug) begin
      if (api_we) begin
        ;
      end else begin
        case (api_address)
          ADDR_DEBUG_NTS_PROCESSED:
            begin
              api_read_data_debug = counter_nts_processed_reg[63:32];
              counter_nts_processed_lsb_we = 1;
            end
          ADDR_DEBUG_NTS_PROCESSED + 1:
            begin
              api_read_data_debug = counter_nts_processed_lsb_reg;
            end
          ADDR_DEBUG_NTS_BAD_COOKIE:
            begin
              api_read_data_debug = counter_nts_bad_cookie_reg[63:32];
              counter_nts_bad_cookie_lsb_we = 1;
            end
          ADDR_DEBUG_NTS_BAD_COOKIE + 1:
            begin
              api_read_data_debug = counter_nts_bad_cookie_lsb_reg;
            end
          ADDR_DEBUG_NTS_BAD_AUTH:
            begin
              api_read_data_debug = counter_nts_bad_auth_reg[63:32];
              counter_nts_bad_auth_lsb_we = 1;
            end
          ADDR_DEBUG_NTS_BAD_AUTH + 1:
            begin
              api_read_data_debug = counter_nts_bad_auth_lsb_reg;
            end
          ADDR_DEBUG_NTS_BAD_KEYID:
            begin
              api_read_data_debug = counter_nts_bad_keyid_reg[63:32];
              counter_nts_bad_keyid_lsb_we = 1;
            end
          ADDR_DEBUG_NTS_BAD_KEYID + 1:
            begin
              api_read_data_debug = counter_nts_bad_keyid_lsb_reg;
            end
          ADDR_DEBUG_NAME: api_read_data_debug = DEBUG_NAME;
          ADDR_DEBUG_SYSTICK32: api_read_data_debug = systick32_reg;
          ADDR_DEBUG_ERROR_CRYPTO:
            begin
              api_read_data_debug = counter_error_crypto_reg[63:32];
              counter_error_crypto_lsb_we = 1;
            end
          ADDR_DEBUG_ERROR_CRYPTO + 1:
            api_read_data_debug = counter_error_crypto_lsb_reg;
          ADDR_DEBUG_ERROR_TXBUF:
            begin
               api_read_data_debug = counter_error_txbuf_reg[63:32];
               counter_error_txbuf_lsb_we = 1;
            end
          ADDR_DEBUG_ERROR_TXBUF + 1:
            api_read_data_debug = counter_error_txbuf_lsb_reg;
          default: ;
        endcase
      end
    end
  end

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
    .i_internal_debug_api_read_data(api_read_data_debug),

    .o_internal_parser_api_cs(api_cs_parser),
    .i_internal_parser_api_read_data(api_read_data_parser)
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

     .i_parser_busy(parser_busy),

     .i_dispatch_packet_available(i_dispatch_rx_packet_available),
     .o_dispatch_packet_read(o_dispatch_rx_packet_read_discard),
     .i_dispatch_fifo_empty(i_dispatch_rx_fifo_empty),
     .o_dispatch_fifo_rd_start(o_dispatch_rx_fifo_rd_start),
     .i_dispatch_fifo_rd_valid(i_dispatch_rx_fifo_rd_valid),
     .i_dispatch_fifo_rd_data(i_dispatch_rx_fifo_rd_data),

     .o_access_port_wait(access_port_wait),
     .i_access_port_addr(access_port_addr),
     .i_access_port_burstsize(access_port_burstsize),
     .i_access_port_wordsize(access_port_wordsize),
     .i_access_port_rd_en(access_port_rd_en),
     .o_access_port_rd_dv(access_port_rd_dv),
     .o_access_port_rd_data(access_port_rd_data)
  );

  //----------------------------------------------------------------
  // RX Mux instantiation.
  //----------------------------------------------------------------

  always @*
  begin : rx_mux_vars
    reg [0:0] muxctrl;
    muxctrl = { parser_muxctrl_crypto };

    access_port_addr = 0;
    access_port_burstsize = 0;
    access_port_wordsize = 0;
    access_port_rd_en = 0;

    access_port_wait_parser = 1;
    access_port_rd_dv_parser = 0;
    access_port_rd_data_parser = 0;

    rxbuf_crypto_wait = 1;
    rxbuf_crypto_rd_dv = 0;
    rxbuf_crypto_rd_data = 0;

    case (muxctrl)
      1'b0:
        begin
          access_port_addr = access_port_addr_parser;
          access_port_burstsize = access_port_burstsize_parser;
          access_port_wordsize = access_port_wordsize_parser;
          access_port_rd_en = access_port_rd_en_parser;

          access_port_wait_parser = access_port_wait;
          access_port_rd_dv_parser = access_port_rd_dv;
          access_port_rd_data_parser = access_port_rd_data;
        end
      1'b1:
        begin
          access_port_addr = crypto_rxbuf_addr;
          access_port_wordsize = crypto_rxbuf_wordsize;
          access_port_rd_en = crypto_rxbuf_rd_en;

          rxbuf_crypto_wait = access_port_wait;
          rxbuf_crypto_rd_dv = access_port_rd_dv;
          rxbuf_crypto_rd_data = access_port_rd_data;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Transmit Mux instantiation.
  //----------------------------------------------------------------

  always @*
  begin : tx_mux_vars
    reg [2:0] muxctrl;

    muxctrl = { parser_muxctrl_crypto, parser_muxctrl_timestamp_ipv6, parser_muxctrl_timestamp_ipv4 };

    mux_tx_address_internal = 1;
    mux_tx_address_hi       = 0;
    mux_tx_address_lo       = 0;
    mux_tx_write_en         = 0;
    mux_tx_write_data       = 0;

    case (muxctrl)
      3'b000:
        begin
          mux_tx_address_internal = parser_txbuf_address_internal;
          mux_tx_address_hi       = parser_txbuf_address[ADDR_WIDTH+3-1:3];
          mux_tx_address_lo       = parser_txbuf_address[2:0];
          mux_tx_write_en         = parser_txbuf_write_en;
          mux_tx_write_data       = parser_txbuf_write_data;
        end
      3'b001: //IPv4 timestamp
        begin
          mux_tx_address_internal = 0;
          mux_tx_address_hi       = 0;
          mux_tx_address_hi[2:0]  = timestamp_tx_header_block;
          mux_tx_address_hi       = mux_tx_address_hi + 5;
          mux_tx_address_lo       = 2;
          mux_tx_write_en         = timestamp_tx_wr_en;
          mux_tx_write_data       = timestamp_tx_header_data;
        end
      3'b010: //IPv6 timestamp
        begin
          mux_tx_address_internal = 0;
          mux_tx_address_hi       = 0;
          mux_tx_address_hi[2:0]  = timestamp_tx_header_block;
          mux_tx_address_hi       = mux_tx_address_hi + 7;
          mux_tx_address_lo       = 6;
          mux_tx_write_en         = timestamp_tx_wr_en;
          mux_tx_write_data       = timestamp_tx_header_data;
        end
      3'b100:
        begin
          mux_tx_address_internal = 0;
          mux_tx_address_hi       = crypto_txbuf_address[ADDR_WIDTH+3-1:3];
          mux_tx_address_lo       = crypto_txbuf_address[2:0];
          mux_tx_write_en         = crypto_txbuf_write_en;
          mux_tx_write_data       = crypto_txbuf_write_data;
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

    .o_busy(txbuf_busy),
    .o_error(txbuf_error),

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

    .i_parser_update_length(parser_txbuf_update_length),

    .i_parser_ipv4_done(parser_txbuf_ipv4_done),
    .i_parser_ipv6_done(parser_txbuf_ipv6_done),

    .o_parser_current_memory_full(txbuf_parser_full),
    .o_parser_current_empty(txbuf_parser_empty)
  );

  //----------------------------------------------------------------
  // Parser Ctrl instantiation.
  //----------------------------------------------------------------

  nts_parser_ctrl #(
    .ADDR_WIDTH(ADDR_WIDTH)
  ) parser (
   .i_areset(i_areset),
   .i_clk(i_clk),

   .o_busy(parser_busy),

   .i_clear(1'b0), //currently no soft reset implemented

   .i_api_cs(api_cs_parser),
   .i_api_we(api_we),
   .i_api_address(api_address),
   .i_api_write_data(api_write_data),
   .o_api_read_data(api_read_data_parser),

   .i_process_initial(i_dispatch_rx_fifo_rd_valid),
   .i_last_word_data_valid(i_dispatch_rx_data_last_valid),
   .i_data(i_dispatch_rx_fifo_rd_data),

   .i_tx_empty(txbuf_parser_empty),
   .i_tx_full(txbuf_parser_full),
   .o_tx_clear(parser_txbuf_clear),
   .o_tx_addr_internal(parser_txbuf_address_internal),
   .o_tx_addr(parser_txbuf_address),
   .o_tx_w_en(parser_txbuf_write_en),
   .o_tx_w_data(parser_txbuf_write_data),
   .o_tx_update_length(parser_txbuf_update_length),
   .o_tx_ipv4_done(parser_txbuf_ipv4_done),
   .o_tx_ipv6_done(parser_txbuf_ipv6_done),

   .i_access_port_wait(access_port_wait_parser),
   .o_access_port_addr(access_port_addr_parser),
   .o_access_port_burstsize(access_port_burstsize_parser),
   .o_access_port_wordsize(access_port_wordsize_parser),
   .o_access_port_rd_en(access_port_rd_en_parser),
   .i_access_port_rd_dv(access_port_rd_dv_parser),
   .i_access_port_rd_data(access_port_rd_data_parser),

   .i_keymem_key_id(keymem_internal_key_id),
   .i_keymem_key_valid(keymem_internal_key_valid),
   .i_keymem_ready(keymem_internal_ready),
   .o_keymem_get_current_key(keymem_internal_get_current_key),
   .o_keymem_get_key_with_id(keymem_internal_get_key_with_id),
   .o_keymem_key_word(keymem_internal_key_word),
   .o_keymem_server_id(keymem_internal_server_key_id),

   .i_timestamp_busy(timestamp_parser_busy),
   .o_timestamp_record_receive_timestamp(parser_timestamp_record_rectime),
   .o_timestamp_transmit(parser_timestamp_transmit),
   .o_timestamp_origin_timestamp(parser_timestamp_client_orgtime),
   .o_timestamp_version_number(parser_timestamp_client_version),
   .o_timestamp_poll(parser_timestamp_client_poll),

   .i_crypto_busy(crypto_parser_busy),
   .i_crypto_verify_tag_ok(crypto_parser_verify_tag_ok),
   .o_crypto_rx_op_copy_ad(parser_crypto_rx_op_copy_ad),
   .o_crypto_rx_op_copy_nonce(parser_crypto_rx_op_copy_nonce),
   .o_crypto_rx_op_copy_pc(parser_crypto_rx_op_copy_pc),
   .o_crypto_rx_op_copy_tag(parser_crypto_rx_op_copy_tag),
   .o_crypto_rx_addr(parser_crypto_rx_addr),
   .o_crypto_rx_bytes(parser_crypto_rx_bytes),
   .o_crypto_tx_op_copy_ad(parser_crypto_tx_op_copy_ad),
   .o_crypto_tx_op_store_nonce_tag(parser_crypto_tx_op_store_nonce_tag),
   .o_crypto_tx_op_store_cookie(parser_crypto_tx_op_store_cookie),
   .o_crypto_tx_addr(parser_crypto_tx_addr),
   .o_crypto_tx_bytes(parser_crypto_tx_bytes),
   .o_crypto_op_cookie_verify(parser_crypto_op_cookie_verify),
   .o_crypto_op_cookie_loadkeys(parser_crypto_op_cookie_loadkeys),
   .o_crypto_op_cookie_rencrypt(parser_crypto_op_cookie_rencrypt),
   .o_crypto_op_c2s_verify_auth(parser_crypto_op_c2s_verify_auth),
   .o_crypto_op_s2c_generate_auth(parser_crypto_op_s2c_generate_auth),

   .o_muxctrl_crypto(parser_muxctrl_crypto),

   .o_muxctrl_timestamp_ipv4(parser_muxctrl_timestamp_ipv4),
   .o_muxctrl_timestamp_ipv6(parser_muxctrl_timestamp_ipv6),

   .o_statistics_nts_bad_auth(parser_statistics_nts_bad_auth),
   .o_statistics_nts_bad_cookie(parser_statistics_nts_bad_cookie),
   .o_statistics_nts_bad_keyid(parser_statistics_nts_bad_keyid),
   .o_statistics_nts_processed(parser_statistics_nts_processed),

   .o_detect_unique_identifier(detect_unique_identifier),
   .o_detect_nts_cookie(detect_nts_cookie),
   .o_detect_nts_cookie_placeholder(detect_nts_cookie_placeholder),
   .o_detect_nts_authenticator(detect_nts_authenticator)
  );

  //----------------------------------------------------------------
  // Server Key Memory instantiation.
  //----------------------------------------------------------------

  nts_keymem keymem (
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

  nts_verify_secure #(.ADDR_WIDTH(ADDR_WIDTH)) crypto (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .o_busy         ( crypto_parser_busy ),
    .o_error        ( crypto_error       ),

    .o_verify_tag_ok( crypto_parser_verify_tag_ok ),

    .i_key_word   ( keymem_internal_key_word   ),
    .i_key_valid  ( keymem_internal_key_valid  ),
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

    .i_op_cookiebuf_reset(0), //TODO implement support
    .i_op_cookiebuf_appendcookie(0), //TODO implement support
    .i_cookie_prefix(0), //TODO implement support

    .i_rx_wait     ( rxbuf_crypto_wait     ),
    .o_rx_addr     ( crypto_rxbuf_addr     ),
    .o_rx_wordsize ( crypto_rxbuf_wordsize ),
    .o_rx_rd_en    ( crypto_rxbuf_rd_en    ),
    .i_rx_rd_dv    ( rxbuf_crypto_rd_dv    ),
    .i_rx_rd_data  ( rxbuf_crypto_rd_data  ),

    .i_tx_busy       ( txbuf_busy              ),
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
