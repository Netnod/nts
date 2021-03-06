//======================================================================
//
// nts_engine.v
// ------------
// Top level module for the NTS engine.
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

module nts_engine #(
  parameter ADDR_WIDTH = 8,
  parameter SUPPORT_NTS      = 1,
  parameter SUPPORT_NTP_AUTH = 0,
  parameter SUPPORT_NTP      = 0,
  parameter SUPPORT_NET      = 0
) (
  input  wire                  i_areset, // async reset
  input  wire                  i_clk,
  output wire                  o_busy,

  input wire  [63:0]           i_ntp_time,

  output wire                  o_dispatch_rx_ready,
  input  wire [3:0]            i_dispatch_rx_data_last_valid,
  input  wire                  i_dispatch_rx_fifo_empty,
  /* verilator lint_off UNUSED */
  input  wire                  i_dispatch_rx_fifo_rd_start,
  /* verilator lint_on UNUSED */
  input  wire                  i_dispatch_rx_fifo_rd_valid,
  input  wire [63:0]           i_dispatch_rx_fifo_rd_data,

  output wire                  o_dispatch_tx_packet_available,
  input  wire                  i_dispatch_tx_packet_read,
  output wire                  o_dispatch_tx_fifo_empty,
  input  wire                  i_dispatch_tx_fifo_rd_start,
  output wire                  o_dispatch_tx_fifo_rd_valid,
  output wire [63:0]           o_dispatch_tx_fifo_rd_data,
  output wire  [3:0]           o_dispatch_tx_bytes_last_word,

  input  wire                  i_api_cs,
  input  wire                  i_api_we,
  input  wire [11:0]           i_api_address,
  input  wire [31:0]           i_api_write_data,
  output wire [31:0]           o_api_read_data,
  output wire                  o_api_read_data_valid,
  output wire                  o_api_busy
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
  localparam CORE_VERSION = 32'h30_2e_31_31;
  localparam CORE_SUPPORT = { 28'b0, SUPPORT_NET,
                                     SUPPORT_NTP,
                                     SUPPORT_NTP_AUTH,
                                     SUPPORT_NTS };

  localparam ADDR_NAME0         = 'h00;
  localparam ADDR_NAME1         = 'h01;
  localparam ADDR_VERSION       = 'h02;
  localparam ADDR_CTRL          = 'h08;
  localparam ADDR_STATUS        = 'h09;
  localparam ADDR_SUPPORT       = 'h0a;

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
  // Control registers and related wires
  //----------------------------------------------------------------

  reg       ctrl_we;
  reg [0:0] ctrl_new;
  reg [0:0] ctrl_reg;

  //----------------------------------------------------------------
  // TX mux wires
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

  reg                   [15:0] access_port_csum_initial;
  wire                  [15:0] access_port_csum_initial_parser;

  reg                    [2:0] access_port_wordsize;
  wire                   [2:0] access_port_wordsize_parser;

  reg                          access_port_rd_en;
  wire                         access_port_rd_en_parser;

  wire                         access_port_rd_dv;
  reg                          access_port_rd_dv_parser;

  wire [ACCESS_PORT_WIDTH-1:0] access_port_rd_data;
  reg                   [63:0] access_port_rd_data_parser;

  /* verilator lint_off UNUSED */
  wire                         api_cs_cookie;
  /* verilator lint_on UNUSED */
  wire                         api_cs_clock;
  wire                         api_cs_debug;
  wire                         api_cs_engine;
  /* verilator lint_off UNUSED */
  wire                         api_cs_keymem;
  /* verilator lint_on UNUSED */
  wire                         api_cs_parser;
  /* verilator lint_off UNUSED */
  wire                         api_cs_ntpauth_keymem;
  /* verilator lint_on UNUSED */

  reg                 [31 : 0] api_read_data_engine;
  wire                [31 : 0] api_read_data_cookie;
  reg                 [31 : 0] api_read_data_debug;
  wire                [31 : 0] api_read_data_clock;
  wire                [31 : 0] api_read_data_keymem;
  wire                [31 : 0] api_read_data_parser;
  wire                [31 : 0] api_read_data_ntpauth_keymem;

  wire                         api_we;
  wire                 [7 : 0] api_address;
  wire                [31 : 0] api_write_data;

  /* verilator lint_off UNUSED */
  wire                         keymem_internal_get_current_key;
  wire                         keymem_internal_get_key_with_id;
  wire                [31 : 0] keymem_internal_server_key_id;
  wire                 [2 : 0] keymem_internal_key_word;
  wire                         keymem_internal_key_valid;
  wire                [31 : 0] keymem_internal_key_id;
  wire                [31 : 0] keymem_internal_key_data;
  wire                         keymem_internal_ready;
  /* verilator lint_on UNUSED */

  /* verilator lint_off UNUSED */
  wire                         ntpauth_ntpkeymem_get_key_md5;
  wire                         ntpauth_ntpkeymem_get_key_sha1;
  wire                [31 : 0] ntpauth_ntpkeymem_keyid;

  wire                 [2 : 0] ntpkeymem_ntpauth_key_word;
  wire                         ntpkeymem_ntpauth_key_valid;
  wire                [31 : 0] ntpkeymem_ntpauth_key_data;
  wire                         ntpkeymem_ntpauth_ready;
  /* verilator lint_on UNUSED */

  wire                   [6:0] ntpauth_txbuf_address;
  wire                         ntpauth_txbuf_write_en;
  wire                  [63:0] ntpauth_txbuf_write_data;

  /* verilator lint_off UNUSED */
  wire                         parser_ntpauth_md5;
  wire                         parser_ntpauth_sha1;
  /* verilator lint_on UNUSED */
  wire                         ntpauth_parser_ready;
  wire                         ntpauth_parser_good;
  wire                         ntpauth_parser_bad_key;
  wire                         ntpauth_parser_bad_digest;
  /* verilator lint_off UNUSED */
  wire                         parser_ntpauth_transmit;
  /* verilator lint_on UNUSED */

  wire                         busy;
  wire                         parser_busy;

  wire                         parser_txbuf_clear;
  wire                         parser_txbuf_address_internal;
  wire      [ADDR_WIDTH+3-1:0] parser_txbuf_address;
  wire                         parser_txbuf_write_en;
  wire                  [63:0] parser_txbuf_write_data;
  wire                         parser_txbuf_sum_reset;
  wire                  [15:0] parser_txbuf_sum_reset_value;
  wire                         parser_txbuf_sum_en;
  wire      [ADDR_WIDTH+3-1:0] parser_txbuf_sum_bytes;
  wire                         parser_txbuf_update_length;
  wire                         parser_txbuf_transfer;

  wire                         txbuf_error;
  wire                         txbuf_busy;
  wire                         txbuf_parser_full;
  wire                         txbuf_parser_empty;
  wire                  [15:0] txbuf_parser_sum;
  wire                         txbuf_parser_sum_done;

  wire                         parser_timestamp_kiss_of_death;
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
  wire                         parser_muxctrl_ntpauth;
  wire                         parser_muxctrl_timestamp_ipv4;
  wire                         parser_muxctrl_timestamp_ipv6;

  /* verilator lint_off UNUSED */
  wire                         parser_statistics_nts_bad_auth;
  wire                         parser_statistics_nts_bad_cookie;
  wire                         parser_statistics_nts_bad_keyid;
  wire                         parser_statistics_nts_processed;
  /* verilator lint_on UNUSED */


  wire                    crypto_parser_busy;
  wire                    crypto_error;
  wire                    crypto_parser_verify_tag_ok;
  /* verilator lint_off UNUSED */
  wire                    parser_crypto_sample_key;
  wire                    parser_crypto_rx_op_copy_ad;
  wire                    parser_crypto_rx_op_copy_nonce;
  wire                    parser_crypto_rx_op_copy_pc;
  wire                    parser_crypto_rx_op_copy_tag;
  wire [ADDR_WIDTH+3-1:0] parser_crypto_rx_addr;
  wire [ADDR_WIDTH+3-1:0] parser_crypto_rx_bytes;
  wire                    parser_crypto_tx_op_copy_ad;
  wire                    parser_crypto_tx_op_store_nonce_tag;
  wire                    parser_crypto_tx_op_store_cookie;
  wire                    parser_crypto_store_tx_cookiebuf;
  wire [ADDR_WIDTH+3-1:0] parser_crypto_tx_addr;
  wire [ADDR_WIDTH+3-1:0] parser_crypto_tx_bytes;
  wire             [63:0] parser_crypto_cookieprefix;
  wire                    parser_crypto_op_cookie_verify;
  wire                    parser_crypto_op_cookie_loadkeys;
  wire                    parser_crypto_op_cookie_rencrypt;
  wire                    parser_crypto_op_cookiebuf_reset;
  wire                    parser_crypto_op_cookiebuf_append;
  wire                    parser_crypto_op_c2s_verify_auth;
  wire                    parser_crypto_op_s2c_generate_auth;
  reg                     rxbuf_crypto_wait;
  wire [ADDR_WIDTH+3-1:0] crypto_rxbuf_addr;
  wire [ADDR_WIDTH+3-1:0] crypto_rxbuf_burstsize;
  wire              [2:0] crypto_rxbuf_wordsize;
  wire                    crypto_rxbuf_rd_en;
  reg                     rxbuf_crypto_rd_dv;
  reg              [63:0] rxbuf_crypto_rd_data;
  /* verilator lint_on UNUSED */

  wire                    crypto_txbuf_read_en;
  /* verilator lint_off UNUSED */
  wire             [63:0] txbuf_crypto_read_data;
  wire                    txbuf_crypto_read_valid;
  /* verilator lint_on UNUSED */
  wire                    crypto_txbuf_write_en;
  wire             [63:0] crypto_txbuf_write_data;
  wire [ADDR_WIDTH+3-1:0] crypto_txbuf_address;

  /* verilator lint_off UNUSED */
  wire                    crypto_noncegen_get;
  wire             [63:0] noncegen_crypto_nonce;
  wire                    noncegen_crypto_nonce_valid;
  wire                    noncegen_crypto_ready;
  /* verilator lint_on UNUSED */

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign busy = (~ctrl_reg[0]) || parser_busy;

  assign o_busy                          = busy;

  //----------------------------------------------------------------
  // Statistics counters and Debug registers
  //----------------------------------------------------------------

  /* verilator lint_off UNUSED */
  wire [31:0] counter_nts_bad_auth_msb;
  wire [31:0] counter_nts_bad_auth_lsb;
  reg         counter_nts_bad_auth_lsb_we;

  wire [31:0] counter_nts_bad_cookie_msb;
  wire [31:0] counter_nts_bad_cookie_lsb;
  reg         counter_nts_bad_cookie_lsb_we;

  wire [31:0] counter_nts_bad_keyid_msb;
  wire [31:0] counter_nts_bad_keyid_lsb;
  reg        counter_nts_bad_keyid_lsb_we;

  wire [31:0] counter_nts_processed_msb;
  wire [31:0] counter_nts_processed_lsb;
  reg         counter_nts_processed_lsb_we;

  wire [31:0] counter_error_crypto_msb;
  wire [31:0] counter_error_crypto_lsb;
  reg         counter_error_crypto_lsb_we;

  wire  [31:0] counter_error_txbuf_msb;
  wire  [31:0] counter_error_txbuf_lsb;
  reg          counter_error_txbuf_lsb_we;
  /* verilator lint_on UNUSED */

  reg [31:0] systick32_reg;

  if (SUPPORT_NTS) begin
    counter64 counter_nts_bad_auth (
       .i_areset     ( i_areset                       ),
       .i_clk        ( i_clk                          ),
       .i_inc        ( parser_statistics_nts_bad_auth ),
       .i_rst        ( 1'b0                           ),
       .i_lsb_sample ( counter_nts_bad_auth_lsb_we    ),
       .o_msb        ( counter_nts_bad_auth_msb       ),
       .o_lsb        ( counter_nts_bad_auth_lsb       )
    );

    counter64 counter_nts_bad_cookie (
       .i_areset     ( i_areset                         ),
       .i_clk        ( i_clk                            ),
       .i_inc        ( parser_statistics_nts_bad_cookie ),
       .i_rst        ( 1'b0                             ),
       .i_lsb_sample ( counter_nts_bad_cookie_lsb_we    ),
       .o_msb        ( counter_nts_bad_cookie_msb       ),
       .o_lsb        ( counter_nts_bad_cookie_lsb       )
    );

    counter64 counter_nts_bad_keyid (
       .i_areset     ( i_areset                        ),
       .i_clk        ( i_clk                           ),
       .i_inc        ( parser_statistics_nts_bad_keyid ),
       .i_rst        ( 1'b0                            ),
       .i_lsb_sample ( counter_nts_bad_keyid_lsb_we    ),
       .o_msb        ( counter_nts_bad_keyid_msb       ),
       .o_lsb        ( counter_nts_bad_keyid_lsb       )
    );

    counter64 counter_nts_processed (
       .i_areset     ( i_areset                        ),
       .i_clk        ( i_clk                           ),
       .i_inc        ( parser_statistics_nts_processed ),
       .i_rst        ( 1'b0                            ),
       .i_lsb_sample ( counter_nts_processed_lsb_we    ),
       .o_msb        ( counter_nts_processed_msb       ),
       .o_lsb        ( counter_nts_processed_lsb       )
    );
  end else begin
    assign counter_nts_bad_auth_msb = 0;
    assign counter_nts_bad_auth_lsb = 0;
    assign counter_nts_bad_cookie_msb = 0;
    assign counter_nts_bad_cookie_lsb = 0;
    assign counter_nts_bad_keyid_msb = 0;
    assign counter_nts_bad_keyid_lsb = 0;
    assign counter_nts_processed_msb = 0;
    assign counter_nts_processed_lsb = 0;
  end

  counter64 counter_error_crypto (
     .i_areset     ( i_areset                    ),
     .i_clk        ( i_clk                       ),
     .i_inc        ( crypto_error                ),
     .i_rst        ( 1'b0                        ),
     .i_lsb_sample ( counter_error_crypto_lsb_we ),
     .o_msb        ( counter_error_crypto_msb    ),
     .o_lsb        ( counter_error_crypto_lsb    )
  );

  counter64 counter_error_txbuf (
     .i_areset     ( i_areset                   ),
     .i_clk        ( i_clk                      ),
     .i_inc        ( txbuf_error                ),
     .i_rst        ( 1'b0                       ),
     .i_lsb_sample ( counter_error_txbuf_lsb_we ),
     .o_msb        ( counter_error_txbuf_msb    ),
     .o_lsb        ( counter_error_txbuf_lsb    )
  );

  //----------------------------------------------------------------
  // Register update
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_up
    if (i_areset) begin

      ctrl_reg <= 0;

      systick32_reg <= 32'h0000_0001;

    end else begin
      if (ctrl_we)
        ctrl_reg <= ctrl_new;

      systick32_reg <= systick32_reg + 1;
    end
  end

  //----------------------------------------------------------------
  // NTS Engine API
  //----------------------------------------------------------------

  always @*
  begin
    api_read_data_engine = 0;
    ctrl_we = 0;
    ctrl_new = 0;
    if (api_cs_engine) begin
      if (api_we) begin
        case (api_address)
          ADDR_CTRL:
            begin
              ctrl_we  = 1;
              ctrl_new = api_write_data[0:0];
            end
          default: ;
        endcase
      end else begin
        case (api_address)
          ADDR_NAME0: api_read_data_engine = CORE_NAME0;
          ADDR_NAME1: api_read_data_engine = CORE_NAME1;
          ADDR_VERSION: api_read_data_engine = CORE_VERSION;
          ADDR_CTRL: api_read_data_engine = { 31'h0000_0000, ctrl_reg };
          ADDR_STATUS: api_read_data_engine = { 31'h0000_0000, (~parser_busy) }; //TODO: Bit31 RNG error. No such signal from noncegen to forward.
          ADDR_SUPPORT: api_read_data_engine = CORE_SUPPORT;
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
              api_read_data_debug = counter_nts_processed_msb;
              counter_nts_processed_lsb_we = 1;
            end
          ADDR_DEBUG_NTS_PROCESSED + 1:
            begin
              api_read_data_debug = counter_nts_processed_lsb;
            end
          ADDR_DEBUG_NTS_BAD_COOKIE:
            begin
              api_read_data_debug = counter_nts_bad_cookie_msb;
              counter_nts_bad_cookie_lsb_we = 1;
            end
          ADDR_DEBUG_NTS_BAD_COOKIE + 1:
            begin
              api_read_data_debug = counter_nts_bad_cookie_lsb;
            end
          ADDR_DEBUG_NTS_BAD_AUTH:
            begin
              api_read_data_debug = counter_nts_bad_auth_msb;
              counter_nts_bad_auth_lsb_we = 1;
            end
          ADDR_DEBUG_NTS_BAD_AUTH + 1:
            begin
              api_read_data_debug = counter_nts_bad_auth_lsb;
            end
          ADDR_DEBUG_NTS_BAD_KEYID:
            begin
              api_read_data_debug = counter_nts_bad_keyid_msb;
              counter_nts_bad_keyid_lsb_we = 1;
            end
          ADDR_DEBUG_NTS_BAD_KEYID + 1:
            begin
              api_read_data_debug = counter_nts_bad_keyid_lsb;
            end
          ADDR_DEBUG_NAME: api_read_data_debug = DEBUG_NAME;
          ADDR_DEBUG_SYSTICK32: api_read_data_debug = systick32_reg;
          ADDR_DEBUG_ERROR_CRYPTO:
            begin
              api_read_data_debug = counter_error_crypto_msb;
              counter_error_crypto_lsb_we = 1;
            end
          ADDR_DEBUG_ERROR_CRYPTO + 1:
            api_read_data_debug = counter_error_crypto_lsb;
          ADDR_DEBUG_ERROR_TXBUF:
            begin
               api_read_data_debug = counter_error_txbuf_msb;
               counter_error_txbuf_lsb_we = 1;
            end
          ADDR_DEBUG_ERROR_TXBUF + 1:
            api_read_data_debug = counter_error_txbuf_lsb;
          default: ;
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // API instantiation.
  //----------------------------------------------------------------

  nts_api api (
    .i_clk( i_clk ),
    .i_areset( i_areset ),
    .o_busy( o_api_busy ),

    .i_external_api_cs(i_api_cs),
    .i_external_api_we(i_api_we),
    .i_external_api_address(i_api_address),
    .i_external_api_write_data(i_api_write_data),
    .o_external_api_read_data(o_api_read_data),
    .o_external_api_read_data_valid(o_api_read_data_valid),

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
    .i_internal_parser_api_read_data(api_read_data_parser),

    .o_internal_ntpauth_keymem_api_cs(api_cs_ntpauth_keymem),
    .i_internal_ntpauth_keymem_api_read_data(api_read_data_ntpauth_keymem)
  );

  //----------------------------------------------------------------
  // Receive buffer instantiation.
  //----------------------------------------------------------------

  nts_rx_buffer #(
    .ADDR_WIDTH(ADDR_WIDTH)
  ) rx_buffer (
     .i_areset(i_areset),
     .i_clk(i_clk),

     .i_parser_busy(busy),

     .o_dispatch_ready(o_dispatch_rx_ready),
     .i_dispatch_fifo_empty(i_dispatch_rx_fifo_empty),
     .i_dispatch_fifo_rd_valid(i_dispatch_rx_fifo_rd_valid),
     .i_dispatch_fifo_rd_data(i_dispatch_rx_fifo_rd_data),

     .o_access_port_wait(access_port_wait),
     .i_access_port_addr(access_port_addr),
     .i_access_port_burstsize(access_port_burstsize),
     .i_access_port_csum_initial(access_port_csum_initial),
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
    access_port_csum_initial = 0;
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
          access_port_csum_initial = access_port_csum_initial_parser;
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
          access_port_burstsize[ADDR_WIDTH+3-1:0] = crypto_rxbuf_burstsize;
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
    reg [3:0] muxctrl;

    muxctrl = { parser_muxctrl_ntpauth, parser_muxctrl_crypto, parser_muxctrl_timestamp_ipv6, parser_muxctrl_timestamp_ipv4 };

    mux_tx_address_internal = 1;
    mux_tx_address_hi       = 0;
    mux_tx_address_lo       = 0;
    mux_tx_write_en         = 0;
    mux_tx_write_data       = 0;

    case (muxctrl)
      4'b0000:
        begin
          mux_tx_address_internal = parser_txbuf_address_internal;
          mux_tx_address_hi       = parser_txbuf_address[ADDR_WIDTH+3-1:3];
          mux_tx_address_lo       = parser_txbuf_address[2:0];
          mux_tx_write_en         = parser_txbuf_write_en;
          mux_tx_write_data       = parser_txbuf_write_data;
        end
      4'b0001: //IPv4 timestamp
        begin
          mux_tx_address_internal = 0;
          mux_tx_address_hi       = 0;
          mux_tx_address_hi[2:0]  = timestamp_tx_header_block;
          mux_tx_address_hi       = mux_tx_address_hi + 5;
          mux_tx_address_lo       = 2;
          mux_tx_write_en         = timestamp_tx_wr_en;
          mux_tx_write_data       = timestamp_tx_header_data;
        end
      4'b0010: //IPv6 timestamp
        begin
          mux_tx_address_internal = 0;
          mux_tx_address_hi       = 0;
          mux_tx_address_hi[2:0]  = timestamp_tx_header_block;
          mux_tx_address_hi       = mux_tx_address_hi + 7;
          mux_tx_address_lo       = 6;
          mux_tx_write_en         = timestamp_tx_wr_en;
          mux_tx_write_data       = timestamp_tx_header_data;
        end
      4'b0100:
        begin
          mux_tx_address_internal = 0;
          mux_tx_address_hi       = crypto_txbuf_address[ADDR_WIDTH+3-1:3];
          mux_tx_address_lo       = crypto_txbuf_address[2:0];
          mux_tx_write_en         = crypto_txbuf_write_en;
          mux_tx_write_data       = crypto_txbuf_write_data;
        end
      4'b1000:
        begin
          mux_tx_address_internal = 0;
          mux_tx_address_hi[3:0]  = ntpauth_txbuf_address[6:3];
          mux_tx_address_lo       = ntpauth_txbuf_address[2:0];
          mux_tx_write_en         = ntpauth_txbuf_write_en;
          mux_tx_write_data       = ntpauth_txbuf_write_data;
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
    .i_dispatch_tx_fifo_rd_start(i_dispatch_tx_fifo_rd_start),
    .o_dispatch_tx_fifo_rd_valid(o_dispatch_tx_fifo_rd_valid),
    .o_dispatch_tx_fifo_rd_data(o_dispatch_tx_fifo_rd_data),
    .o_dispatch_tx_bytes_last_word(o_dispatch_tx_bytes_last_word),

    .i_parser_clear(parser_txbuf_clear),

    .i_write_en(mux_tx_write_en),
    .i_write_data(mux_tx_write_data),

    .i_read_en(crypto_txbuf_read_en),
    .o_read_valid(txbuf_crypto_read_valid),
    .o_read_data(txbuf_crypto_read_data),

    .i_sum_reset(parser_txbuf_sum_reset),
    .i_sum_reset_value(parser_txbuf_sum_reset_value),
    .i_sum_en(parser_txbuf_sum_en),
    .i_sum_bytes(parser_txbuf_sum_bytes),
    .o_sum(txbuf_parser_sum),
    .o_sum_done(txbuf_parser_sum_done),

    .i_address_internal(mux_tx_address_internal),
    .i_address_hi(mux_tx_address_hi),
    .i_address_lo(mux_tx_address_lo),

    .i_parser_update_length(parser_txbuf_update_length),

    .i_parser_transfer(parser_txbuf_transfer),

    .o_parser_current_memory_full(txbuf_parser_full),
    .o_parser_current_empty(txbuf_parser_empty)
  );

  //----------------------------------------------------------------
  // Parser Ctrl instantiation.
  //----------------------------------------------------------------

  nts_parser_ctrl #(
    .ADDR_WIDTH       ( ADDR_WIDTH       ),
    .SUPPORT_NTS      ( SUPPORT_NTS      ),
    .SUPPORT_NTP_AUTH ( SUPPORT_NTP_AUTH ),
    .SUPPORT_NTP      ( SUPPORT_NTP      ),
    .SUPPORT_NET      ( SUPPORT_NET      )
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

   .i_tx_busy(txbuf_busy),
   .i_tx_empty(txbuf_parser_empty),
   .i_tx_full(txbuf_parser_full),
   .o_tx_clear(parser_txbuf_clear),
   .o_tx_addr_internal(parser_txbuf_address_internal),
   .o_tx_addr(parser_txbuf_address),
   .o_tx_w_en(parser_txbuf_write_en),
   .o_tx_w_data(parser_txbuf_write_data),
   .i_tx_sum(txbuf_parser_sum),
   .i_tx_sum_done(txbuf_parser_sum_done),
   .o_tx_sum_reset(parser_txbuf_sum_reset),
   .o_tx_sum_reset_value(parser_txbuf_sum_reset_value),
   .o_tx_sum_en(parser_txbuf_sum_en),
   .o_tx_sum_bytes(parser_txbuf_sum_bytes),
   .o_tx_update_length(parser_txbuf_update_length),
   .o_tx_transfer(parser_txbuf_transfer),

   .i_access_port_wait(access_port_wait_parser),
   .o_access_port_addr(access_port_addr_parser),
   .o_access_port_burstsize(access_port_burstsize_parser),
   .o_access_port_csum_initial(access_port_csum_initial_parser),
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
   .o_timestamp_kiss_of_death(parser_timestamp_kiss_of_death),
   .o_timestamp_record_receive_timestamp(parser_timestamp_record_rectime),
   .o_timestamp_transmit(parser_timestamp_transmit),
   .o_timestamp_origin_timestamp(parser_timestamp_client_orgtime),
   .o_timestamp_version_number(parser_timestamp_client_version),
   .o_timestamp_poll(parser_timestamp_client_poll),

   .i_crypto_busy(crypto_parser_busy),
   .i_crypto_verify_tag_ok(crypto_parser_verify_tag_ok),

   .o_crypto_cookieprefix(parser_crypto_cookieprefix),
   .o_crypto_sample_key(parser_crypto_sample_key),
   .o_crypto_rx_op_copy_ad(parser_crypto_rx_op_copy_ad),
   .o_crypto_rx_op_copy_nonce(parser_crypto_rx_op_copy_nonce),
   .o_crypto_rx_op_copy_pc(parser_crypto_rx_op_copy_pc),
   .o_crypto_rx_op_copy_tag(parser_crypto_rx_op_copy_tag),
   .o_crypto_rx_addr(parser_crypto_rx_addr),
   .o_crypto_rx_bytes(parser_crypto_rx_bytes),
   .o_crypto_tx_op_copy_ad(parser_crypto_tx_op_copy_ad),
   .o_crypto_tx_op_store_nonce_tag(parser_crypto_tx_op_store_nonce_tag),
   .o_crypto_tx_op_store_cookie(parser_crypto_tx_op_store_cookie),
   .o_crypto_tx_op_store_cookiebuf(parser_crypto_store_tx_cookiebuf),
   .o_crypto_tx_addr(parser_crypto_tx_addr),
   .o_crypto_tx_bytes(parser_crypto_tx_bytes),
   .o_crypto_op_cookie_verify(parser_crypto_op_cookie_verify),
   .o_crypto_op_cookie_loadkeys(parser_crypto_op_cookie_loadkeys),
   .o_crypto_op_cookie_rencrypt(parser_crypto_op_cookie_rencrypt),
   .o_crypto_op_cookiebuf_append(parser_crypto_op_cookiebuf_append),
   .o_crypto_op_cookiebuf_reset(parser_crypto_op_cookiebuf_reset),
   .o_crypto_op_c2s_verify_auth(parser_crypto_op_c2s_verify_auth),
   .o_crypto_op_s2c_generate_auth(parser_crypto_op_s2c_generate_auth),

   .o_ntpauth_md5        ( parser_ntpauth_md5        ),
   .o_ntpauth_sha1       ( parser_ntpauth_sha1       ),
   .o_ntpauth_transmit   ( parser_ntpauth_transmit   ),
   .i_ntpauth_ready      ( ntpauth_parser_ready      ),
   .i_ntpauth_good       ( ntpauth_parser_good       ),
   .i_ntpauth_bad_digest ( ntpauth_parser_bad_digest ),
   .i_ntpauth_bad_key    ( ntpauth_parser_bad_key    ),

   .o_muxctrl_crypto(parser_muxctrl_crypto),

   .o_muxctrl_ntpauth(parser_muxctrl_ntpauth),

   .o_muxctrl_timestamp_ipv4(parser_muxctrl_timestamp_ipv4),
   .o_muxctrl_timestamp_ipv6(parser_muxctrl_timestamp_ipv6),

   .o_statistics_nts_bad_auth(parser_statistics_nts_bad_auth),
   .o_statistics_nts_bad_cookie(parser_statistics_nts_bad_cookie),
   .o_statistics_nts_bad_keyid(parser_statistics_nts_bad_keyid),
   .o_statistics_nts_processed(parser_statistics_nts_processed)

  );

  //----------------------------------------------------------------
  // Server Key Memory instantiation.
  //----------------------------------------------------------------

  if (SUPPORT_NTS) begin
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
  end else begin
    assign api_read_data_keymem = 0;
    assign keymem_internal_key_valid = 0;
    assign keymem_internal_key_id = 0;
    assign keymem_internal_key_data = 0;
    assign keymem_internal_ready = 0;
  end

  //----------------------------------------------------------------
  // NTP AUTH (MD5, SHA1) 160bit Key Memory instantiation.
  //----------------------------------------------------------------

  if (SUPPORT_NTP_AUTH) begin
    ntp_auth_keymem ntpkeymem (
      .i_clk       ( i_clk    ),
      .i_areset    ( i_areset ),

      .i_cs        ( api_cs_ntpauth_keymem ),
      .i_we        ( api_we                ),
      .i_address   ( api_address           ),
      .i_write_data( api_write_data        ),
      .o_read_data ( api_read_data_ntpauth_keymem  ),

      .i_get_key_md5  ( ntpauth_ntpkeymem_get_key_md5  ),
      .i_get_key_sha1 ( ntpauth_ntpkeymem_get_key_sha1 ),
      .i_keyid        ( ntpauth_ntpkeymem_keyid        ),
      .o_key_word     ( ntpkeymem_ntpauth_key_word     ),
      .o_key_valid    ( ntpkeymem_ntpauth_key_valid    ),
      .o_key_data     ( ntpkeymem_ntpauth_key_data     ),
      .o_ready        ( ntpkeymem_ntpauth_ready        )
    );
  end else begin
    assign api_read_data_ntpauth_keymem = 0;
  end

  //----------------------------------------------------------------
  // NTP AUTH (MD5, SHA1) module.
  //----------------------------------------------------------------

  if (SUPPORT_NTP_AUTH) begin
    ntp_auth ntpauth (
      .i_areset ( i_areset ),
      .i_clk    ( i_clk    ),

      .i_auth_md5  ( parser_ntpauth_md5      ),
      .i_auth_sha1 ( parser_ntpauth_sha1     ),
      .i_tx        ( parser_ntpauth_transmit ),

      .o_ready      ( ntpauth_parser_ready      ),
      .o_good       ( ntpauth_parser_good       ),
      .o_bad_digest ( ntpauth_parser_bad_digest ),
      .o_bad_key    ( ntpauth_parser_bad_key    ),

      .i_rx_reset ( i_dispatch_rx_fifo_rd_start ),
      .i_rx_valid ( i_dispatch_rx_fifo_rd_valid ),
      .i_rx_data  ( i_dispatch_rx_fifo_rd_data  ),

      .i_timestamp_wr_en            ( timestamp_tx_wr_en        ),
      .i_timestamp_ntp_header_block ( timestamp_tx_header_block ),
      .i_timestamp_ntp_header_data  ( timestamp_tx_header_data  ),

      .o_keymem_get_key_md5  ( ntpauth_ntpkeymem_get_key_md5  ),
      .o_keymem_get_key_sha1 ( ntpauth_ntpkeymem_get_key_sha1 ),
      .o_keymem_keyid        ( ntpauth_ntpkeymem_keyid        ),
      .i_keymem_key_word     ( ntpkeymem_ntpauth_key_word     ),
      .i_keymem_key_valid    ( ntpkeymem_ntpauth_key_valid    ),
      .i_keymem_key_data     ( ntpkeymem_ntpauth_key_data     ),
      .i_keymem_ready        ( ntpkeymem_ntpauth_ready        ),

      .o_tx_wr_en ( ntpauth_txbuf_write_en   ),
      .o_tx_addr  ( ntpauth_txbuf_address    ),
      .o_tx_data  ( ntpauth_txbuf_write_data )
    );
  end else begin
    assign ntpauth_parser_bad_digest = 0;
    assign ntpauth_parser_bad_key = 0;
    assign ntpauth_parser_good = 0;
    assign ntpauth_parser_ready = 0;
    assign ntpauth_txbuf_write_en = 0;
    assign ntpauth_txbuf_address = 0;
    assign ntpauth_txbuf_write_data = 0;
  end

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
    .i_parser_kiss_of_death(parser_timestamp_kiss_of_death),
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

  if (SUPPORT_NTS) begin : nts_enabled
    wire [31:0] ZERO;
    assign ZERO = 0;

    nts_verify_secure #(.ADDR_WIDTH(ADDR_WIDTH)) crypto (
      .i_areset(i_areset),
      .i_clk(i_clk),

      .o_busy         ( crypto_parser_busy ),
      .o_error        ( crypto_error       ),

      .o_verify_tag_ok( crypto_parser_verify_tag_ok ),

      .i_key_word   ( keymem_internal_key_word ),
      .i_key_valid  ( parser_crypto_sample_key ),
      .i_key_data   ( keymem_internal_key_data ),

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
      .i_op_store_tx_cookiebuf ( parser_crypto_store_tx_cookiebuf    ), //Write cookie buffer. First issue i_op_generate_tag, then parser_crypto_tx_op_store_nonce_tag, then i_op_store_tx_cookiebuf
      .i_copy_tx_addr          ( parser_crypto_tx_addr               ), //Specify memory address in TX buf
      .i_copy_tx_bytes         ( parser_crypto_tx_bytes              ),

      .i_op_cookie_verify      ( parser_crypto_op_cookie_verify   ), //Decipher and authenticate (nonce)(tag)(ciphertext) user server key
      .i_op_cookie_loadkeys    ( parser_crypto_op_cookie_loadkeys ), //Copy S2C, C2S from RAM to Registers,
      .i_op_cookie_rencrypt    ( parser_crypto_op_cookie_rencrypt ), //Encrypt (nonce)(plaintext) into (nonce)(tag)(ciphertext)

      .i_op_verify_c2s   ( parser_crypto_op_c2s_verify_auth   ), //Authenticate an incomming packet using C2S key
      .i_op_generate_tag ( parser_crypto_op_s2c_generate_auth ), //Authenticate an outbound packet using S2C key

      .i_op_cookiebuf_reset(parser_crypto_op_cookiebuf_reset),
      .i_op_cookiebuf_appendcookie(parser_crypto_op_cookiebuf_append),
      .i_cookie_prefix(parser_crypto_cookieprefix),

      .i_rx_wait      ( rxbuf_crypto_wait      ),
      .o_rx_addr      ( crypto_rxbuf_addr      ),
      .o_rx_burstsize ( crypto_rxbuf_burstsize ),
      .o_rx_wordsize  ( crypto_rxbuf_wordsize  ),
      .o_rx_rd_en     ( crypto_rxbuf_rd_en     ),
      .i_rx_rd_dv     ( rxbuf_crypto_rd_dv     ),
      .i_rx_rd_data   ( rxbuf_crypto_rd_data   ),

      .i_tx_busy       ( txbuf_busy              ),
      .o_tx_read_en    ( crypto_txbuf_read_en    ),
      .i_tx_read_dv    ( txbuf_crypto_read_valid ),
      .i_tx_read_data  ( txbuf_crypto_read_data  ),
      .o_tx_write_en   ( crypto_txbuf_write_en   ),
      .o_tx_write_data ( crypto_txbuf_write_data ),
      .o_tx_address    ( crypto_txbuf_address    ),

      .o_noncegen_get         ( crypto_noncegen_get         ),
      .i_noncegen_nonce       ( noncegen_crypto_nonce       ),
      .i_noncegen_nonce_valid ( noncegen_crypto_nonce_valid ),
      .i_noncegen_ready       ( noncegen_crypto_ready       )

    );

  //----------------------------------------------------------------
  // NTS Nonce Generator. Pseudorandom number generator.
  //----------------------------------------------------------------

    nts_noncegen noncegen (
      .clk        ( i_clk    ),
      .areset     ( i_areset ),
      //API
      .cs         ( api_cs_cookie        ),
      .we         ( api_we               ),
      .address    ( api_address          ),
      .write_data ( api_write_data       ),
      .read_data  ( api_read_data_cookie ),
      //NonceGen
      .get_nonce   ( crypto_noncegen_get         ),
      .nonce       ( noncegen_crypto_nonce       ),
      .nonce_valid ( noncegen_crypto_nonce_valid ),
      .ready       ( noncegen_crypto_ready       )
    );
  end else begin
    assign api_read_data_cookie = 0;
    assign crypto_error = 0;
    assign crypto_parser_busy = 0;
    assign crypto_parser_verify_tag_ok = 0;
    assign crypto_rxbuf_addr = 0;
    assign crypto_txbuf_read_en = 0;
    assign crypto_rxbuf_burstsize = 0;
    assign crypto_rxbuf_wordsize = 0;
    assign crypto_rxbuf_rd_en = 0;
    assign crypto_txbuf_read_en = 0;
    assign crypto_txbuf_write_en = 0;
    assign crypto_txbuf_write_data = 0;
    assign crypto_txbuf_address = 0;
    assign crypto_noncegen_get = 0;
    assign noncegen_crypto_nonce = 0;
    assign noncegen_crypto_nonce_valid = 0;
    assign noncegen_crypto_ready = 0;
  end // (SUPPORT_NTS)

  //----------------------------------------------------------------

endmodule
