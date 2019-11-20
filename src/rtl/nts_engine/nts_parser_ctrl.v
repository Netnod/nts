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

module nts_parser_ctrl #(
  parameter ADDR_WIDTH = 8,
  parameter ACCESS_PORT_WIDTH = 64,
  parameter NTS_MAX_ALLOWED_PLACEHOLDERS = 7, // 5.7 The client SHOULD NOT include more than seven NTS Cookie Placeholder extension fields in a request.
  parameter [15:0] TAG_NTS_UNIQUE_IDENTIFIER  = 'h0104,
  parameter [15:0] TAG_NTS_COOKIE             = 'h0204,
  parameter [15:0] TAG_NTS_COOKIE_PLACEHOLDER = 'h0304,
  parameter [15:0] TAG_NTS_AUTHENTICATOR      = 'h0404,
  parameter [15:0] LEN_NTS_COOKIE             = 'h0068,
  parameter [15:0] LEN_NTS_MIN_UNIQUE_IDENT   = 'h0024, //5.3. The string MUST be at least 32 octets long.
  parameter [15:0] LEN_NTS_AUTHENTICATOR      = 'h0028, //TL 4h + KeyId 4h + SIV nonce 10h + SIV tag 10h
  parameter DEBUG_OUTPUT = 1
) (
  input  wire                         i_areset, // async reset
  input  wire                         i_clk,

  output wire                         o_busy,

  input  wire                         i_clear,
  input  wire                         i_process_initial,
  input  wire                   [7:0] i_last_word_data_valid,
  input  wire                  [63:0] i_data,

  input  wire                         i_tx_empty,
  input  wire                         i_tx_full,
  output wire                         o_tx_clear,
  output wire                         o_tx_w_en,
  output wire                  [63:0] o_tx_w_data,
  output wire                         o_tx_ipv4_done,
  output wire                         o_tx_ipv6_done,

  input  wire                         i_access_port_wait,
  output wire      [ADDR_WIDTH+3-1:0] o_access_port_addr,
  output wire                   [2:0] o_access_port_wordsize,
  output wire                         o_access_port_rd_en,
  input  wire                         i_access_port_rd_dv,
  input  wire [ACCESS_PORT_WIDTH-1:0] i_access_port_rd_data,

  output wire                   [3:0] o_keymem_key_word,
  output wire                         o_keymem_get_key_with_id,
  output wire                  [31:0] o_keymem_server_id,
  input  wire                         i_keymem_key_length,
  input  wire                         i_keymem_key_valid,
  input  wire                         i_keymem_ready,

  input  wire                         i_timestamp_busy,
  output wire                         o_timestamp_record_receive_timestamp,
  output wire                         o_timestamp_transmit, //parser signal packet transmit OK
  output wire                [63 : 0] o_timestamp_origin_timestamp,
  output wire                [ 2 : 0] o_timestamp_version_number,
  output wire                [ 7 : 0] o_timestamp_poll,

  input  wire                         i_crypto_busy,
  input  wire                         i_crypto_verify_tag_ok,
  output wire                         o_crypto_rx_op_copy_ad,
  output wire                         o_crypto_rx_op_copy_nonce,
  output wire                         o_crypto_rx_op_copy_pc,
  output wire                         o_crypto_rx_op_copy_tag,
  output wire      [ADDR_WIDTH+3-1:0] o_crypto_rx_addr,
  output wire                   [9:0] o_crypto_rx_bytes,
  output wire                         o_crypto_tx_op_copy_ad,
  output wire                         o_crypto_tx_op_store_nonce_tag,
  output wire                         o_crypto_tx_op_store_cookie,
  output wire      [ADDR_WIDTH+3-1:0] o_crypto_tx_addr,
  output wire                   [9:0] o_crypto_tx_bytes,
  output wire                         o_crypto_op_cookie_verify,
  output wire                         o_crypto_op_cookie_loadkeys,
  output wire                         o_crypto_op_cookie_rencrypt,
  output wire                         o_crypto_op_c2s_verify_auth,
  output wire                         o_crypto_op_s2c_generate_auth,

  output wire                         o_muxctrl_timestamp_ipv4,
  output wire                         o_muxctrl_timestamp_ipv6,

  output wire                         o_muxctrl_crypto, //Crypto is in charge of RX, TX

  output wire                         o_detect_unique_identifier,
  output wire                         o_detect_nts_cookie,
  output wire                         o_detect_nts_cookie_placeholder,
  output wire                         o_detect_nts_authenticator
);

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam STATE_IDLE                     = 4'h0;
  localparam STATE_COPY                     = 4'h1;
  localparam STATE_LENGTH_CHECKS            = 4'h3;
  localparam STATE_EXTRACT_EXT_FROM_RAM     = 4'h4;
  localparam STATE_EXTENSIONS_EXTRACTED     = 4'h5;
  localparam STATE_EXTRACT_COOKIE_FROM_RAM  = 4'h6;
  localparam STATE_VERIFY_KEY_FROM_COOKIE1  = 4'h7;
  localparam STATE_VERIFY_KEY_FROM_COOKIE2  = 4'h8;
  localparam STATE_RX_AUTH_COOKIE           = 4'h9;
  localparam STATE_RX_AUTH_PACKET           = 4'ha;
  localparam STATE_TIMESTAMP                = 4'hb;
  localparam STATE_TIMESTAMP_WAIT           = 4'hc;
  localparam STATE_ERROR_UNIMPLEMENTED      = 4'he;
  localparam STATE_ERROR_GENERAL            = 4'hf;

  localparam CRYPTO_FSM_IDLE              =  0;
  localparam CRYPTO_FSM_RX_AUTH_COOKIE    =  1; // issue load nonce
  localparam CRYPTO_FSM_RX_AUTH_COOKIE_W1 =  2; // wait for complete, issue load tag
  localparam CRYPTO_FSM_RX_AUTH_COOKIE_W2 =  3; // wait for complete, issue load ciphertext
  localparam CRYPTO_FSM_RX_AUTH_COOKIE_W3 =  4; // wait for complete, issue cookie verify
  localparam CRYPTO_FSM_RX_AUTH_COOKIE_W4 =  5; // wait for complete, signal result
  localparam CRYPTO_FSM_RX_AUTH_PACKET    =  6; // issue load keys
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W1 =  7; // wait for complete, issue load AD
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W2 =  8; // wait for complete, issue load nonce
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W3 =  9; // wait for complete, issue load tag
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W4 = 10; // wait for complete, issue load load ciphertext
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W5 = 11; // wait for complete, issue packet verify
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W6 = 12; // wait for complete, signal result
  localparam CRYPTO_FSM_DONE_FAILURE      = 14;
  localparam CRYPTO_FSM_DONE_SUCCESS      = 15;

  localparam BYTES_TAG_LEN           = 4;

  localparam BYTES_KEYID             = 4;

  localparam BYTES_COOKIE_OVERHEAD   = BYTES_TAG_LEN + BYTES_KEYID;
  localparam BYTES_COOKIE_NONCE      = 16;
  localparam BYTES_COOKIE_TAG        = 16;
  localparam BYTES_COOKIE_CIPHERTEXT = 64;

  localparam OFFSET_COOKIE_NONCE      = BYTES_COOKIE_OVERHEAD;
  localparam OFFSET_COOKIE_TAG        = BYTES_COOKIE_NONCE     + OFFSET_COOKIE_NONCE;
  localparam OFFSET_COOKIE_CIPHERTEXT = BYTES_COOKIE_TAG       + OFFSET_COOKIE_TAG;

  localparam BYTES_AUTH_NONCE_LEN_FIELD      = 2;
  localparam BYTES_AUTH_CIPHERTEXT_LEN_FIELD = 2;
  localparam BYTES_AUTH_OVERHEAD             = BYTES_TAG_LEN + BYTES_AUTH_NONCE_LEN_FIELD + BYTES_AUTH_CIPHERTEXT_LEN_FIELD; //8 = 4*2

  localparam BYTES_AUTH_NONCE = 16; //TODO hardcoded, not OK in the future.
  localparam BYTES_AUTH_TAG   = 16;

  localparam OFFSET_AUTH_NONCE = BYTES_AUTH_OVERHEAD;
  localparam OFFSET_AUTH_TAG   = BYTES_AUTH_TAG + OFFSET_AUTH_NONCE;

  localparam NTP_EXTENSION_BITS          = 4;
  localparam NTP_EXTENSION_FIELDS        = (1<<NTP_EXTENSION_BITS);

  localparam [15:0] E_TYPE_IPV4 =  16'h08_00;
  localparam [15:0] E_TYPE_IPV6 =  16'h86_DD;

  localparam [3:0] IP_V4        =  4'h4;
  localparam [3:0] IP_V6        =  4'h6;

  //localparam ADDR_IPV4_START_NTP = 6 * 8 + 2;
  //localparam ADDR_IPV6_START_NTP = 8 * 8 + 6;
  localparam ADDR_IPV4_START_NTP = 5 * 8 + 2;
  localparam ADDR_IPV6_START_NTP = 7 * 8 + 6;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg                         access_port_addr_we;
  reg      [ADDR_WIDTH+3-1:0] access_port_addr_new;
  reg      [ADDR_WIDTH+3-1:0] access_port_addr_reg;
  reg                         access_port_rd_en_we;
  reg                         access_port_rd_en_new;
  reg                         access_port_rd_en_reg;
  reg                         access_port_wordsize_we;
  reg                   [2:0] access_port_wordsize_new;
  reg                   [2:0] access_port_wordsize_reg;

  reg                         cookie_server_id_we;
  reg                  [31:0] cookie_server_id_new;
  reg                  [31:0] cookie_server_id_reg;

  reg                         crypto_fsm_we;
  reg                   [3:0] crypto_fsm_new;
  reg                   [3:0] crypto_fsm_reg;

  reg                         state_we;
  reg                   [3:0] state_new;
  reg                   [3:0] state_reg;

  reg                         word_counter_we;
  reg        [ADDR_WIDTH-1:0] word_counter_new;
  reg        [ADDR_WIDTH-1:0] word_counter_reg;

  reg                         last_bytes_we;
  reg                   [3:0] last_bytes_new;
  reg                   [3:0] last_bytes_reg;

  reg                          memory_bound_we;
  reg       [ADDR_WIDTH+3-1:0] memory_bound_new;
  reg       [ADDR_WIDTH+3-1:0] memory_bound_reg;

  reg                          memory_address_we;
  reg       [ADDR_WIDTH+3-1:0] memory_address_new;
  reg       [ADDR_WIDTH+3-1:0] memory_address_reg;
  reg       [ADDR_WIDTH+3-1:0] memory_address_next_reg;
  reg                          memory_address_failure_reg;
  reg                          memory_address_lastbyte_read_reg;

  //reg                   [63:0] previous_i_data_reg; //We receive i_data one cycle before process signal
  reg                          ipdecode_ethernet_protocol_we;
  reg                   [15:0] ipdecode_ethernet_protocol_new;
  reg                   [15:0] ipdecode_ethernet_protocol_reg;
  reg                          ipdecode_ip_version_we;
  reg                    [3:0] ipdecode_ip_version_new;
  reg                    [3:0] ipdecode_ip_version_reg;
  reg                          ipdecode_ip4_ihl_we;
  reg                    [3:0] ipdecode_ip4_ihl_new;
  reg                    [3:0] ipdecode_ip4_ihl_reg;

  reg                          ipdecode_udp_length_we;
  reg                   [15:0] ipdecode_udp_length_new;
  reg                   [15:0] ipdecode_udp_length_reg;

  reg                          keymem_key_word_we;
  reg                    [3:0] keymem_key_word_new;
  reg                    [3:0] keymem_key_word_reg;
  reg                          keymem_get_key_with_id_we;
  reg                          keymem_get_key_with_id_new;
  reg                          keymem_get_key_with_id_reg;
  reg                          keymem_server_id_we;
  reg                   [31:0] keymem_server_id_new;
  reg                   [31:0] keymem_server_id_reg;

  reg                          timestamp_record_receive_timestamp_we;
  reg                          timestamp_record_receive_timestamp_new;
  reg                          timestamp_record_receive_timestamp_reg;
  reg                          timestamp_origin_timestamp_we;
  reg                 [63 : 0] timestamp_origin_timestamp_new;
  reg                 [63 : 0] timestamp_origin_timestamp_reg;
  reg                          timestamp_version_number_we;
  reg                 [ 2 : 0] timestamp_version_number_new;
  reg                 [ 2 : 0] timestamp_version_number_reg;
//reg                          timestamp_poll_we;
//reg                 [ 7 : 0] timestamp_poll_new;
//reg                 [ 7 : 0] timestamp_poll_reg;


  reg                          ntp_extension_counter_we;
  reg [NTP_EXTENSION_BITS-1:0] ntp_extension_counter_new;
  reg [NTP_EXTENSION_BITS-1:0] ntp_extension_counter_reg;

  reg                          ntp_extension_reset;
  reg                          ntp_extension_we;
  reg                          ntp_extension_copied_new;
  reg                          ntp_extension_copied_reg  [0:NTP_EXTENSION_FIELDS-1];
  reg       [ADDR_WIDTH+3-1:0] ntp_extension_addr_new;
  reg       [ADDR_WIDTH+3-1:0] ntp_extension_addr_reg    [0:NTP_EXTENSION_FIELDS-1];
  reg                   [15:0] ntp_extension_tag_new;
  reg                   [15:0] ntp_extension_tag_reg     [0:NTP_EXTENSION_FIELDS-1];
  reg                   [15:0] ntp_extension_length_new;
  reg                   [15:0] ntp_extension_length_reg  [0:NTP_EXTENSION_FIELDS-1];

  reg       [ADDR_WIDTH+3-1:0] nts_authenticator_start_addr_new;
  reg       [ADDR_WIDTH+3-1:0] nts_authenticator_start_addr_reg;
  reg                          nts_basic_sanity_check_packet_ok_new;
  reg                          nts_basic_sanity_check_packet_ok_reg;
  reg [NTP_EXTENSION_BITS-1:0] nts_valid_placeholders_new;
  /* verilator lint_off UNUSED */
  reg [NTP_EXTENSION_BITS-1:0] nts_valid_placeholders_reg; //TODO implement
  /* verilator lint_on UNUSED */
  reg       [ADDR_WIDTH+3-1:0] nts_cookie_start_addr_new;
  reg       [ADDR_WIDTH+3-1:0] nts_cookie_start_addr_reg;

  reg                          detect_unique_identifier_reg;
  reg                          detect_nts_cookie_reg;
  reg                          detect_nts_cookie_placeholder_reg;
  reg                          detect_nts_authenticator_reg;

  reg [NTP_EXTENSION_BITS-1:0] detect_nts_cookie_index_reg;

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  reg crypto_op_cookie_verify;
  reg crypto_op_cookie_loadkeys;
  reg crypto_op_c2s_verify_auth;

  reg                    crypto_rx_op_copy_ad;
  reg                    crypto_rx_op_copy_nonce;
  reg                    crypto_rx_op_copy_pc;
  reg                    crypto_rx_op_copy_tag;
  reg [ADDR_WIDTH+3-1:0] crypto_rx_addr;
  reg              [9:0] crypto_rx_bytes;

  wire detect_ipv4;
  wire detect_ipv4_bad;
  wire detect_ipv6;

  wire [ADDR_WIDTH+3-1:0] ipdecode_offset_ntp_ext;

  reg  muxctrl_crypto;


  //----------------------------------------------------------------
  // Connectivity for ports etc.
  //----------------------------------------------------------------

  assign detect_ipv4     = (ipdecode_ethernet_protocol_reg == E_TYPE_IPV4) && (ipdecode_ip_version_reg == IP_V4);
  assign detect_ipv4_bad = detect_ipv4 && ipdecode_ip4_ihl_reg != 5;

  assign detect_ipv6     = (ipdecode_ethernet_protocol_reg == E_TYPE_IPV6) && (ipdecode_ip_version_reg == IP_V6);

  assign ipdecode_offset_ntp_ext[ADDR_WIDTH+3-1:3] = (detect_ipv4 && ipdecode_ip4_ihl_reg == 5) ? (5+6) : (detect_ipv6) ? (7+6) : 0;
  assign ipdecode_offset_ntp_ext[2:0]              = (detect_ipv4 && ipdecode_ip4_ihl_reg == 5) ? 2 : (detect_ipv6) ? 6 : 0;

  assign o_busy                 = (i_tx_empty == 'b0) || (state_reg != STATE_IDLE);
  //assign o_busy                 = state_reg != STATE_IDLE;

  assign o_access_port_addr     = access_port_addr_reg;
  assign o_access_port_rd_en    = access_port_rd_en_reg;
  assign o_access_port_wordsize = access_port_wordsize_reg;

  assign o_keymem_key_word        = keymem_key_word_reg;
  assign o_keymem_get_key_with_id = keymem_get_key_with_id_reg;
  assign o_keymem_server_id       = keymem_server_id_reg;

  assign o_tx_clear     = state_reg == STATE_ERROR_GENERAL;
  assign o_tx_ipv4_done = detect_ipv4 && state_reg == STATE_ERROR_UNIMPLEMENTED; //TODO implement termination logic
  assign o_tx_ipv6_done = detect_ipv6 && state_reg == STATE_ERROR_UNIMPLEMENTED; //TODO implement termination logic
  assign o_tx_w_en      = i_process_initial;   //TODO implement proper write logic
  assign o_tx_w_data    = i_data;          //TODO implement proper write logic

  assign o_timestamp_record_receive_timestamp = timestamp_record_receive_timestamp_reg;
  assign o_timestamp_transmit                 = (state_reg == STATE_TIMESTAMP);
  assign o_timestamp_origin_timestamp         = timestamp_origin_timestamp_reg;
  assign o_timestamp_version_number           = timestamp_version_number_reg;
  assign o_timestamp_poll                     = 0; //TODO timestamp_poll_reg;

  assign o_crypto_rx_op_copy_ad    = crypto_rx_op_copy_ad;
  assign o_crypto_rx_op_copy_nonce = crypto_rx_op_copy_nonce;
  assign o_crypto_rx_op_copy_pc    = crypto_rx_op_copy_pc;
  assign o_crypto_rx_op_copy_tag   = crypto_rx_op_copy_tag;

  assign o_crypto_rx_addr          = crypto_rx_addr;
  assign o_crypto_rx_bytes         = crypto_rx_bytes;

  assign o_crypto_tx_op_copy_ad = 0;         //TODO
  assign o_crypto_tx_op_store_nonce_tag = 0; //TODO
  assign o_crypto_tx_op_store_cookie = 0;    //TODO
  assign o_crypto_tx_addr = 0;               //TODO
  assign o_crypto_tx_bytes = 0;              //TODO

  assign o_crypto_op_cookie_verify     = crypto_op_cookie_verify;
  assign o_crypto_op_cookie_loadkeys   = crypto_op_cookie_loadkeys;

  assign o_crypto_op_cookie_rencrypt   = 0;  //TODO

  assign o_crypto_op_c2s_verify_auth   = crypto_op_c2s_verify_auth;

  assign o_crypto_op_s2c_generate_auth = 0;  //TODO

  assign o_muxctrl_timestamp_ipv4 = ((state_reg == STATE_TIMESTAMP) || (state_reg == STATE_TIMESTAMP_WAIT)) && (detect_ipv4) && (detect_ipv4_bad=='b0);
  assign o_muxctrl_timestamp_ipv6 = ((state_reg == STATE_TIMESTAMP) || (state_reg == STATE_TIMESTAMP_WAIT)) && (detect_ipv6);

  assign o_muxctrl_crypto = muxctrl_crypto;

  assign o_detect_unique_identifier      = detect_unique_identifier_reg;
  assign o_detect_nts_cookie             = detect_nts_cookie_reg;
  assign o_detect_nts_cookie_placeholder = detect_nts_cookie_placeholder_reg;
  assign o_detect_nts_authenticator      = detect_nts_authenticator_reg;

  //----------------------------------------------------------------
  // Functions and Tasks
  //----------------------------------------------------------------

  function func_address_within_memory_bounds (
    input [ADDR_WIDTH+3-1:0] address,
    input [ADDR_WIDTH+3-1:0] bytes
  );
    reg [ADDR_WIDTH+4-1:0] acc;
    begin
      acc = {1'b0, address} + {1'b0, bytes} - 1;

      if (acc[ADDR_WIDTH+4-1] == 'b1)
        func_address_within_memory_bounds  = 'b0;
      else if (acc[ADDR_WIDTH+3-1:0] >= memory_bound_reg)
        func_address_within_memory_bounds  = 'b0;
      else
        func_address_within_memory_bounds  = 'b1;
    end
  endfunction

  task task_incremment_address_for_nts_extension;
    input  [ADDR_WIDTH+3-1:0] address_in;
    input              [15:0] ntp_extension_length_value;
    output [ADDR_WIDTH+3-1:0] address_out;
    output                    failure;
    output                    lastbyteread;
    reg                [16:0] acc;
    begin
      lastbyteread                          = 'b0;
      failure                               = 'b1;
      address_out                           = address_in;
      if (ntp_extension_length_value[1:0] == 'b0) begin //All extension fields are zero-padded to a word (four octets) boundary.
        acc                                 = 0;
        acc[ADDR_WIDTH+3-1:0]               = address_in;
        acc                                 = acc + {1'b0, ntp_extension_length_value};
        //$display("%s:%0d address_in=%h (%0d) length=%d (%0d) acc=%h (%0d) memory_bound=%h (%d)",`__FILE__,`__LINE__, address_in, address_in, ntp_extension_length_value, ntp_extension_length_value, acc, acc, memory_bound, memory_bound);
        if (acc[16:ADDR_WIDTH+4-1] == 'b0) begin
          if (acc[ADDR_WIDTH+3-1:0] <= memory_bound_reg) begin
            failure                           = 'b0;
            address_out                       = acc[ADDR_WIDTH+3-1:0];
            if (acc[ADDR_WIDTH+3-1:0] == memory_bound_reg) begin
              lastbyteread                    = 'b1;
            end
          end
        end
      end
    end
  endtask

  //----------------------------------------------------------------
  // Register Update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active high reset.
  //----------------------------------------------------------------

  always @ (posedge i_clk, posedge i_areset)
  begin : reg_update
    if (i_areset == 1'b1) begin
      access_port_addr_reg       <= 'b0;
      access_port_rd_en_reg      <= 'b0;
      access_port_wordsize_reg   <= 'b0;
      cookie_server_id_reg       <= 'b0;
      crypto_fsm_reg             <= CRYPTO_FSM_IDLE;
      ipdecode_ip_version_reg    <= 'b0;
      ipdecode_ip4_ihl_reg       <= 'b0;
      ipdecode_udp_length_reg    <= 'b0;
      keymem_key_word_reg        <= 'b0;
      keymem_get_key_with_id_reg <= 'b0;
      keymem_server_id_reg       <= 'b0;
      last_bytes_reg             <= 'b0;
      memory_address_reg         <= 'b0;
      memory_bound_reg           <= 'b0;
      ntp_extension_counter_reg  <= 'b0;
      nts_authenticator_start_addr_reg <= 'b0;
      nts_basic_sanity_check_packet_ok_reg <= 'b0;
      nts_cookie_start_addr_reg  <= 'b0;
      nts_valid_placeholders_reg <= 'b0;
      //previous_i_data_reg        <= 'b0;
      state_reg                  <= 'b0;
      timestamp_record_receive_timestamp_reg <= 'b0;
      timestamp_origin_timestamp_reg         <= 'b0;
      timestamp_version_number_reg           <= 'b0;
    //timestamp_poll_reg                     <= 'b0;
      word_counter_reg           <= 'b0;
      begin : ntp_extension_reset_async
        integer i;
        for (i=0; i <= NTP_EXTENSION_FIELDS-1; i=i+1) begin
          ntp_extension_copied_reg [i] <= 'b0;
          ntp_extension_addr_reg   [i] <= 'b0;
          ntp_extension_tag_reg    [i] <= 'b0;
          ntp_extension_length_reg [i] <= 'b0;
        end
      end
    end else begin
      //previous_i_data_reg <= i_data;

      if (access_port_addr_we)
        access_port_addr_reg <= access_port_addr_new;

      if (access_port_rd_en_we)
        access_port_rd_en_reg <= access_port_rd_en_new;

      if (access_port_wordsize_we)
        access_port_wordsize_reg <= access_port_wordsize_new;

      if (crypto_fsm_we)
        crypto_fsm_reg <= crypto_fsm_new;

      if (cookie_server_id_we)
        cookie_server_id_reg <= cookie_server_id_new;

      if (ipdecode_ethernet_protocol_we)
        ipdecode_ethernet_protocol_reg <= ipdecode_ethernet_protocol_new;

      if (ipdecode_ip_version_we)
        ipdecode_ip_version_reg <= ipdecode_ip_version_new;

      if (ipdecode_ip4_ihl_we)
        ipdecode_ip4_ihl_reg <= ipdecode_ip4_ihl_new;

      if (ipdecode_udp_length_we)
        ipdecode_udp_length_reg <= ipdecode_udp_length_new;

      if (keymem_key_word_we)
        keymem_key_word_reg <= keymem_key_word_new;

      if (keymem_get_key_with_id_we)
        keymem_get_key_with_id_reg <= keymem_get_key_with_id_new;

      if (keymem_server_id_we)
        keymem_server_id_reg <= keymem_server_id_new;

      if (last_bytes_we)
        last_bytes_reg <= last_bytes_new;

      if (memory_address_we)
        memory_address_reg <= memory_address_new;

      if (memory_bound_we)
        memory_bound_reg <= memory_bound_new;

      if (ntp_extension_reset) begin : ntp_extension_reset_sync
        integer i;
        for (i=0; i <= NTP_EXTENSION_FIELDS-1; i=i+1) begin
          ntp_extension_copied_reg [i] <= 'b0;
        end
      end else if (ntp_extension_we)
        ntp_extension_copied_reg [ntp_extension_counter_reg] <= ntp_extension_copied_new;

      if (ntp_extension_we) begin
        $display("%s:%0d ntp_ext[%0d] = tag:%h,length:%h,addr:%h", `__FILE__, `__LINE__, ntp_extension_counter_reg, ntp_extension_tag_new, ntp_extension_length_new, ntp_extension_addr_new);
        ntp_extension_addr_reg   [ntp_extension_counter_reg] <= ntp_extension_addr_new;
        ntp_extension_tag_reg    [ntp_extension_counter_reg] <= ntp_extension_tag_new;
        ntp_extension_length_reg [ntp_extension_counter_reg] <= ntp_extension_length_new;
      end

      if (ntp_extension_counter_we)
        ntp_extension_counter_reg <= ntp_extension_counter_new;

      nts_authenticator_start_addr_reg <= nts_authenticator_start_addr_new;
      nts_basic_sanity_check_packet_ok_reg <= nts_basic_sanity_check_packet_ok_new;
      nts_cookie_start_addr_reg <= nts_cookie_start_addr_new;
      nts_valid_placeholders_reg <= nts_valid_placeholders_new;

      if (state_we)
        state_reg <= state_new;

      if (timestamp_record_receive_timestamp_we)
        timestamp_record_receive_timestamp_reg <= timestamp_record_receive_timestamp_new;

      if (timestamp_origin_timestamp_we)
        timestamp_origin_timestamp_reg <= timestamp_origin_timestamp_new;

      if (timestamp_version_number_we)
        timestamp_version_number_reg <= timestamp_version_number_new;

    //if (timestamp_poll_we)
    //  timestamp_poll_reg <= timestamp_poll_new;

      if (word_counter_we)
        word_counter_reg <= word_counter_new;
    end
  end

  //----------------------------------------------------------------
  // Memory bounds calculation
  // Counts exact number of bytes recieved by parser
  //----------------------------------------------------------------

  always @*
  begin : memory_bounds_calc
    reg [ADDR_WIDTH+3-1:0] bounds;
    memory_bound_we   = 'b0;
    bounds            = 0;
    bounds[3:0]       = last_bytes_reg;
    bounds            = bounds + { word_counter_reg, 3'b000};
    memory_bound_new  = bounds;
    if (memory_bound_reg != bounds)
      memory_bound_we = 'b1;
  end

  //----------------------------------------------------------------
  // Word counter
  // Counts number of words recieved by parser.
  // Memory bounds calculation depends on this counter.
  //----------------------------------------------------------------

  always @*
  begin : word_counter
    word_counter_we  = 'b0;
    word_counter_new = 'b0;
    case (state_reg)
      STATE_IDLE:
        if (i_process_initial)
          word_counter_we = 'b1;
      STATE_COPY:
        if (i_process_initial) begin
          word_counter_we  = 'b1;
          word_counter_new = word_counter_reg + 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Last word data valid byte counter
  // Counts number of bytes in last word recieved by parser.
  // Memory bounds calculation depends on this counter.
  //----------------------------------------------------------------

  always @*
  begin : convert_lwdv_to_byte_counter
    last_bytes_we = 'b0;

    case (i_last_word_data_valid)
      8'b00000001: last_bytes_new = 1;
      8'b00000011: last_bytes_new = 2;
      8'b00000111: last_bytes_new = 3;
      8'b00001111: last_bytes_new = 4;
      8'b00011111: last_bytes_new = 5;
      8'b00111111: last_bytes_new = 6;
      8'b01111111: last_bytes_new = 7;
      8'b11111111: last_bytes_new = 8;
      default: last_bytes_new = 'b0; //illegal value
    endcase

    case (state_reg)
      STATE_IDLE:
        if (i_process_initial)
          last_bytes_we = 'b1;
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // NTS Sanity Check Logic
  // Verifies that NTS extension exhibit basic sanity
  // https://tools.ietf.org/html/draft-ietf-ntp-using-nts-for-ntp-20
  //----------------------------------------------------------------

  always @*
  begin : nts_basic_sanity_check
    nts_authenticator_start_addr_new = 0;
    nts_basic_sanity_check_packet_ok_new = 0;
    nts_cookie_start_addr_new = 0;
    nts_valid_placeholders_new = 0;

    begin : nts_basic_sanity_check_locals
      reg [NTP_EXTENSION_BITS:0] i;
      reg [NTP_EXTENSION_BITS-1:0] j;
      reg [NTP_EXTENSION_BITS-1:0] unique_idenfifiers;
      reg [NTP_EXTENSION_BITS-1:0] cookies;
      reg [NTP_EXTENSION_BITS-1:0] cookie_placeholders;
      reg [NTP_EXTENSION_BITS-1:0] authenticators;
      reg evil_packet;

      evil_packet = 0;

      unique_idenfifiers = 0;
      cookies = 0;
      cookie_placeholders = 0;
      authenticators = 0;

      for (i = 0; i < NTP_EXTENSION_FIELDS; i = i + 1) begin
        j = i[NTP_EXTENSION_BITS-1:0];
        if (ntp_extension_copied_reg[j]) begin

          if (ntp_extension_tag_reg[j] == TAG_NTS_UNIQUE_IDENTIFIER) begin
            unique_idenfifiers = unique_idenfifiers + 1;
            //5.3. The string MUST be at least 32 octets long.
            if (ntp_extension_length_reg[j] < LEN_NTS_MIN_UNIQUE_IDENT) begin
              $display("%s:%0d Length: %0d, required: %0d", `__FILE__, `__LINE__, ntp_extension_length_reg[j], LEN_NTS_MIN_UNIQUE_IDENT);
              evil_packet = 1;
            end
          end

          if (ntp_extension_tag_reg[j] == TAG_NTS_COOKIE) begin
            cookies = cookies + 1;
            nts_cookie_start_addr_new = ntp_extension_addr_reg[j];
            if (ntp_extension_length_reg[j] != LEN_NTS_COOKIE ) begin
              $display("%s:%0d Length: %0d, required: %0d", `__FILE__, `__LINE__, ntp_extension_length_reg[j], LEN_NTS_COOKIE);
              evil_packet = 1;
            end
          end

          if (ntp_extension_tag_reg[j] == TAG_NTS_COOKIE_PLACEHOLDER) begin
            cookie_placeholders = cookie_placeholders + 1;
            //5.5. The body length of the NTS Cookie Placeholder extension field MUST be
            //     the same as the body length of the NTS Cookie extension field.
            // => Approximation: same length rules
            if (ntp_extension_length_reg[j] != LEN_NTS_COOKIE ) begin
              $display("%s:%0d Length: %0d, required: %0d", `__FILE__, `__LINE__, ntp_extension_length_reg[j], LEN_NTS_COOKIE);
              evil_packet = 1;
            end
            // NOTE:
            // "The client MAY include one or more NTS Cookie Placeholder extension
            // fields which MUST be authenticated and MAY be encrypted."
          end

          if (ntp_extension_tag_reg[j] == TAG_NTS_AUTHENTICATOR) begin
            authenticators = authenticators  + 1;
            nts_authenticator_start_addr_new = ntp_extension_addr_reg[j];
            if (ntp_extension_length_reg[j] != LEN_NTS_AUTHENTICATOR ) begin
              $display("%s:%0d Length: %0d, required: %0d", `__FILE__, `__LINE__, ntp_extension_length_reg[j], LEN_NTS_AUTHENTICATOR);
              evil_packet = 1;
            end
          end

        end
      end

      //$display("%s:%0d Evil %b", `__FILE__, `__LINE__, evil_packet);

      // 5.7 Protocol Details, Client

      // Exactly one Unique Identifier extension field which MUST be
      // authenticated, MUST NOT be encrypted, and whose contents MUST NOT
      // duplicate those of any previous request.

      if ( unique_idenfifiers != 1 )
        evil_packet = 1;

      //$display("%s:%0d Evil %b", `__FILE__, `__LINE__, evil_packet);

      // 5.7 Protocol Details, Client

      // Exactly one NTS Cookie extension field which MUST be authenticated
      // and MUST NOT be encrypted.  The cookie MUST be one which has been
      // previously provided to the client; either from the key exchange
      // server during the NTS-KE handshake or from the NTP server in
      // response to a previous NTS-protected NTP request.

      if ( authenticators != 1 )
        evil_packet = 1;

      //$display("%s:%0d Evil %b", `__FILE__, `__LINE__, evil_packet);

      // 5.7 Protocol Details, Client

      // Exactly one NTS Authenticator and Encrypted Extension Fields
      // extension field, generated using an AEAD Algorithm and C2S key
      // established through NTS-KE.

      if ( cookies != 1 )
        evil_packet = 1;

      //$display("%s:%0d Evil %b", `__FILE__, `__LINE__, evil_packet);

      // 5.7 Protocol Details, Client

      // The client MAY include one or more NTS Cookie Placeholder extension
      // fields which MUST be authenticated and MAY be encrypted.  The number
      // of NTS Cookie Placeholder extension fields that the client includes
      // SHOULD be such that if the client includes N placeholders and the
      // server sends back N+1 cookies, the number of unused cookies stored by
      // the client will come to eight.  The client SHOULD NOT include more
      // than seven NTS Cookie Placeholder extension fields in a request.
      // When both the client and server adhere to all cookie-management
      // guidance provided in this memo, the number of placeholder extension
      // fields will equal the number of dropped packets since the last
      // successful volley.

      if (cookie_placeholders > NTS_MAX_ALLOWED_PLACEHOLDERS)
        evil_packet = 1;

      //$display("%s:%0d Evil %b", `__FILE__, `__LINE__, evil_packet);

      //TODO: WARNING, encrypted cookie placeholders not supported (only encrypted cookies supported)


      // TODO!!! ADD RULE that authenticator must be last

      nts_basic_sanity_check_packet_ok_new = ( ~evil_packet );
      nts_valid_placeholders_new = cookie_placeholders;
    end
  end


  //----------------------------------------------------------------
  // NTP Extension field control
  // Writes to NTP Extension fields upon i_access_port receving
  // values from Rx Buffer.
  //----------------------------------------------------------------

  always @*
  begin : ntp_extension_field_control

    ntp_extension_we           = 'b0;
    ntp_extension_reset        = 'b0;
    ntp_extension_addr_new     = 'b0;
    ntp_extension_copied_new   = 'b0;
    ntp_extension_length_new   = 'b0;
    ntp_extension_tag_new      = 'b0;

    if (i_clear || state_reg == STATE_IDLE)
      ntp_extension_reset      = 'b1;

    if (state_reg == STATE_EXTRACT_EXT_FROM_RAM && ntp_extension_copied_reg[ntp_extension_counter_reg] == 'b0 && i_access_port_rd_dv) begin
      ntp_extension_we         = 'b1;
      ntp_extension_addr_new   = memory_address_reg;
      ntp_extension_copied_new = 'b1;
      ntp_extension_length_new = i_access_port_rd_data[15:0];
      ntp_extension_tag_new    = i_access_port_rd_data[31:16];
    end
  end

  always @*
  begin
    access_port_addr_we        = 'b0;
    access_port_addr_new       = 'b0;
    access_port_rd_en_we       = 'b0;
    access_port_rd_en_new      = 'b0;
    access_port_wordsize_we    = 'b0;
    access_port_wordsize_new   = 'b0;

    if (i_clear) begin : addr_port_sync_reset_from_top_module
      access_port_addr_we      = 'b1; //write zeros if top module requests reset
      access_port_rd_en_we     = 'b1;
      access_port_wordsize_we  = 'b1;

    end else begin
      if (access_port_rd_en_reg == 'b1)
        access_port_rd_en_we  = 'b1; //reset read signal if high

      if (state_reg == STATE_EXTRACT_EXT_FROM_RAM && ntp_extension_copied_reg[ntp_extension_counter_reg] == 'b0) begin
        //$display("%s:%0d i_access_port_rd_dv=%0d i_access_port_wait=%0d", `__FILE__, `__LINE__, i_access_port_rd_dv, i_access_port_wait);
        if (i_access_port_rd_dv) begin
          ;
        end else if (i_access_port_wait == 'b0) begin
          access_port_addr_we      = 'b1;
          access_port_addr_new     = memory_address_reg;
          access_port_rd_en_we     = 'b1;
          access_port_rd_en_new    = 'b1;
          access_port_wordsize_we  = 'b1; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
          access_port_wordsize_new = 2; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
        end
      end else if (state_reg == STATE_EXTENSIONS_EXTRACTED && detect_nts_cookie_reg && ntp_extension_length_reg[detect_nts_cookie_index_reg] >= 8)  begin
        ;
      end else if (state_reg == STATE_EXTRACT_COOKIE_FROM_RAM) begin
        //TODO add support for multiple cookies
        if (i_access_port_rd_dv) begin
          $display("%s:%0d i_access_port_rd_data=%h",`__FILE__, `__LINE__, i_access_port_rd_data);
          ;
        end else if (i_access_port_wait == 'b0) begin
          access_port_addr_we      = 'b1;
          access_port_addr_new     = ntp_extension_addr_reg[detect_nts_cookie_index_reg] + 4;
          access_port_rd_en_we     = 'b1;
          access_port_rd_en_new    = 'b1;
          access_port_wordsize_we  = 'b1; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
          access_port_wordsize_new = 2; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
        end
      end
    end
  end

  always @*
  begin
   $display("%s:%0d keymem_get_key_with_id_we = %h", `__FILE__, `__LINE__, keymem_get_key_with_id_we);
  end

  always @*
  begin
    keymem_key_word_we         = 'b0;
    keymem_key_word_new        = 'b0;

    keymem_get_key_with_id_we  = 'b1;
    keymem_get_key_with_id_new = 'b0;

    keymem_server_id_we        = 'b0;
    keymem_server_id_new       = 'b0;

    case (state_reg)
      STATE_EXTRACT_COOKIE_FROM_RAM:
        begin
          keymem_key_word_we         = 'b1;
          //keymem_get_key_with_id_we  = 'b1;
          keymem_server_id_we        = 'b1;
        end
      STATE_VERIFY_KEY_FROM_COOKIE1:
        //$display("%s:%0d STATE_VERIFY_KEY_FROM_COOKIE1 i_keymem_key_valid=%h i_keymem_ready=%h keymem_key_word_reg=%h", `__FILE__, `__LINE__, i_keymem_key_valid, i_keymem_ready, keymem_key_word_reg);
        if (i_keymem_ready == 'b1) begin
          keymem_key_word_we         = 'b1;
          keymem_key_word_new        = 'b0;
          //keymem_get_key_with_id_we  = 'b1;
          keymem_get_key_with_id_new = 'b1;
          keymem_server_id_we        = 'b1;
          keymem_server_id_new       = cookie_server_id_reg;
        end
        //$display("%s:%0d STATE_VERIFY_KEY_FROM_COOKIE1 keymem_server_id_we = %h keymem_server_id_new = %h coookie_server_id_reg = %h", `__FILE__, `__LINE__, keymem_server_id_we, keymem_server_id_new, cookie_server_id_reg);
      STATE_VERIFY_KEY_FROM_COOKIE2:
        begin
          //$display("%s:%0d STATE_VERIFY_KEY_FROM_COOKIE2 i_keymem_key_valid=%h i_keymem_ready=%h keymem_key_word_reg=%h keymem_server_id_reg=%h", `__FILE__, `__LINE__, i_keymem_key_valid, i_keymem_ready, keymem_key_word_reg, keymem_server_id_reg);
          keymem_get_key_with_id_we  = 'b1;
          keymem_get_key_with_id_new = 'b0;
          if (i_keymem_ready && keymem_get_key_with_id_reg == 'b0) begin
            if (i_keymem_key_valid == 'b0) begin
               ; // reset, zero all output
               $display("%s:%0d STATE_VERIFY_KEY_FROM_COOKIE2", `__FILE__, `__LINE__);
            end else if (keymem_key_word_reg == 'b1111) begin
              keymem_get_key_with_id_we  = 'b1;
              ; // reset, zero all output
              $display("%s:%0d STATE_VERIFY_KEY_FROM_COOKIE2", `__FILE__, `__LINE__);
            end else begin
              // Yay! We read a key word
              keymem_key_word_we         = 'b1;
              keymem_key_word_new        = keymem_key_word_reg + 1;
              keymem_get_key_with_id_we  = 'b1;
              keymem_get_key_with_id_new = 'b1;
              $display("%s:%0d STATE_VERIFY_KEY_FROM_COOKIE2 keymem_key_word_reg = %h keymem_key_word_new = %h", `__FILE__, `__LINE__, keymem_key_word_reg, keymem_key_word_new);
            end
          end
        end
      default: ;
    endcase
    //$display("%s:%0d keymem_key_word we=%h new=%h keymem_server_id we=%h new=%h", `__FILE__, `__LINE__, keymem_key_word_we, keymem_key_word_new, keymem_server_id_we, keymem_server_id_new);
  end

  always @*
  begin
    cookie_server_id_we  = 'b0;
    cookie_server_id_new = 'b0;
    if (state_reg == STATE_EXTRACT_COOKIE_FROM_RAM) begin
      if (i_access_port_rd_dv) begin
        cookie_server_id_we  = 'b1;
        cookie_server_id_new = i_access_port_rd_data[31:0];
        $display("%s:%0d cookie_server_id we=%h new=%h", `__FILE__, `__LINE__, cookie_server_id_we, i_access_port_rd_data[31:0]);
      end
    end
  end

  //----------------------------------------------------------------
  // Memory Address calculator
  // Updates memory address reg.
  //   Initilize to NTP Extension start calulcated by IP decode.
  //   Increments by NTP Extension length
  //   Until all bytes consumed.
  //----------------------------------------------------------------

  always @*
  begin : memory_address_calculator
    memory_address_we    = 'b0;
    memory_address_new   = 'b0;

    if (state_reg == STATE_LENGTH_CHECKS) begin
      memory_address_we  = 'b1;
      memory_address_new = ipdecode_offset_ntp_ext;
    end

    if (state_reg == STATE_EXTRACT_EXT_FROM_RAM) begin
      task_incremment_address_for_nts_extension(
           memory_address_reg, ntp_extension_length_reg[ntp_extension_counter_reg], /* IN */
           memory_address_next_reg, memory_address_failure_reg, memory_address_lastbyte_read_reg /*OUT*/);

      if (ntp_extension_copied_reg[ntp_extension_counter_reg] && memory_address_failure_reg == 'b0 && memory_address_lastbyte_read_reg == 'b0 && ntp_extension_counter_reg!=NTP_EXTENSION_FIELDS-1) begin
        memory_address_we  = 'b1;
        memory_address_new = memory_address_next_reg;
      end

    end else begin
      memory_address_we  = 'b1;
      memory_address_next_reg = 0;
      memory_address_failure_reg = 1;
      memory_address_lastbyte_read_reg = 1;
    end
  end

  //----------------------------------------------------------------
  // NTP Extension counter control
  // Increments 0, 1, ..., NTP_EXTENSION_FIELDS-1
  //   for each NTP Extension read
  //----------------------------------------------------------------

  always @*
  begin : ntp_extension_counter_control
    ntp_extension_counter_we  = 'b0;
    ntp_extension_counter_new = 'b0;
    case (state_reg)
      STATE_IDLE:
        if (i_process_initial) begin
          ntp_extension_counter_we  = 'b1;
          ntp_extension_counter_new = 'b0;
        end
      STATE_EXTRACT_EXT_FROM_RAM:
        if (ntp_extension_copied_reg[ntp_extension_counter_reg] && memory_address_failure_reg == 'b0 && memory_address_lastbyte_read_reg == 'b0 && ntp_extension_counter_reg!=NTP_EXTENSION_FIELDS-1) begin
          ntp_extension_counter_we  = 'b1;
          ntp_extension_counter_new = ntp_extension_counter_reg + 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Finite State Machine (Crypto)
  // Controlls communication with crypto engine
  //----------------------------------------------------------------

  always @*
  begin : CRYPTO_FSM
    crypto_fsm_we = 0;
    crypto_fsm_new = CRYPTO_FSM_IDLE;
    crypto_rx_op_copy_ad = 0;
    crypto_rx_op_copy_nonce = 0;
    crypto_rx_op_copy_pc = 0;
    crypto_rx_op_copy_tag = 0;
    crypto_rx_addr = 0;
    crypto_rx_bytes = 0;
    crypto_op_cookie_verify = 0;
    crypto_op_cookie_loadkeys = 0;
    crypto_op_c2s_verify_auth = 0;

    if (crypto_fsm_reg == CRYPTO_FSM_IDLE)
      muxctrl_crypto = 0;
    else
      muxctrl_crypto = 1;

    case (crypto_fsm_reg)
      CRYPTO_FSM_IDLE:
        case (state_reg)
          STATE_RX_AUTH_COOKIE:
            begin
              crypto_fsm_we  = 1;
              crypto_fsm_new = CRYPTO_FSM_RX_AUTH_COOKIE;
            end
          STATE_RX_AUTH_PACKET:
            begin
              crypto_fsm_we  = 1;
              crypto_fsm_new = CRYPTO_FSM_RX_AUTH_PACKET;
            end
          default: ;
        endcase
      CRYPTO_FSM_RX_AUTH_COOKIE:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_COOKIE_W1;
          crypto_rx_op_copy_nonce = 1;
          crypto_rx_addr = nts_cookie_start_addr_reg + OFFSET_COOKIE_NONCE;
          crypto_rx_bytes = BYTES_COOKIE_NONCE;
          //$display("%s:%0d new: %h, addr: %h bytes: %h",`__FILE__,`__LINE__, crypto_fsm_new, crypto_rx_addr, crypto_rx_bytes);

        end
      CRYPTO_FSM_RX_AUTH_COOKIE_W1:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_COOKIE_W2;
          crypto_rx_op_copy_tag = 1;
          crypto_rx_addr = nts_cookie_start_addr_reg + OFFSET_COOKIE_TAG;
          crypto_rx_bytes = BYTES_COOKIE_TAG;
        end
      CRYPTO_FSM_RX_AUTH_COOKIE_W2:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_COOKIE_W3;
          crypto_rx_op_copy_pc = 1;
          crypto_rx_addr = nts_cookie_start_addr_reg + OFFSET_COOKIE_CIPHERTEXT;
          crypto_rx_bytes = BYTES_COOKIE_CIPHERTEXT;
        end
      CRYPTO_FSM_RX_AUTH_COOKIE_W3:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_COOKIE_W4;
          crypto_op_cookie_verify = 1;
        end
      CRYPTO_FSM_RX_AUTH_COOKIE_W4:
        if (i_crypto_busy == 1'b0) begin
          if (i_crypto_verify_tag_ok) begin
            crypto_fsm_we = 1;
            crypto_fsm_new = CRYPTO_FSM_DONE_SUCCESS;
          end else begin
            crypto_fsm_we = 1;
            crypto_fsm_new = CRYPTO_FSM_DONE_FAILURE;
          end
        end
      CRYPTO_FSM_RX_AUTH_PACKET:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_PACKET_W1;
          crypto_op_cookie_loadkeys = 1; //Copy C2S, S2C
        end
      CRYPTO_FSM_RX_AUTH_PACKET_W1:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_PACKET_W2;
          crypto_rx_op_copy_ad = 1;
          if (detect_ipv4) begin
            crypto_rx_addr = ADDR_IPV4_START_NTP; //6*8 + 2 ?
            crypto_rx_bytes = nts_authenticator_start_addr_reg - ADDR_IPV4_START_NTP;
          end
          else if (detect_ipv6) begin
            crypto_rx_addr = ADDR_IPV6_START_NTP; //8*8 + 6 ?
            crypto_rx_bytes = nts_authenticator_start_addr_reg - ADDR_IPV6_START_NTP;
          end
        end
      CRYPTO_FSM_RX_AUTH_PACKET_W2:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_PACKET_W3;
          crypto_rx_op_copy_nonce = 1;
          crypto_rx_addr = nts_authenticator_start_addr_reg + OFFSET_AUTH_NONCE;
          crypto_rx_bytes = BYTES_AUTH_NONCE;
        end
      CRYPTO_FSM_RX_AUTH_PACKET_W3:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_PACKET_W4;
          crypto_rx_op_copy_tag = 1;
          crypto_rx_addr = nts_authenticator_start_addr_reg + OFFSET_AUTH_TAG;
          crypto_rx_bytes = BYTES_AUTH_TAG;
        end
      CRYPTO_FSM_RX_AUTH_PACKET_W4:
        //TODO add support for ciphertext in NTS Authenticator and Encrypted Extension
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_PACKET_W5;
          //crypto_rx_op_copy_pc = 1;
          //crypto_rx_addr = nts_authenticator_start_addr_reg + OFFSET_AUTH_PC;
          //crypto_rx_bytes = ...;
        end
      CRYPTO_FSM_RX_AUTH_PACKET_W5:
        //if (i_crypto_busy == 1'b0) begin //TODO wait for crypto to complete ciphertext loading
        begin
          crypto_fsm_we = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_PACKET_W6;
          crypto_op_c2s_verify_auth = 1;
        end
      CRYPTO_FSM_RX_AUTH_PACKET_W6:
        if (i_crypto_busy == 1'b0) begin
          if (i_crypto_verify_tag_ok) begin
            crypto_fsm_we = 1;
            crypto_fsm_new = CRYPTO_FSM_DONE_SUCCESS;
          end else begin
            crypto_fsm_we = 1;
            crypto_fsm_new = CRYPTO_FSM_DONE_FAILURE;
          end
        end
      CRYPTO_FSM_DONE_SUCCESS:
        begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_IDLE;
        end
      CRYPTO_FSM_DONE_FAILURE:
        begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_IDLE;
        end
       default:
         begin
           crypto_fsm_we = 1;
           crypto_fsm_new = CRYPTO_FSM_DONE_FAILURE;
         end
    endcase
  end

  //----------------------------------------------------------------
  // Finite State Machine
  // Overall functionallitty control
  //----------------------------------------------------------------

  always @*
  begin : FSM
    state_we   = 'b0;
    state_new  = STATE_IDLE;

    if (i_clear)
      state_we  = 'b1;

    else case (state_reg)
      STATE_IDLE:
        begin
          if (i_process_initial) begin
            state_we  = 'b1;
            state_new = STATE_COPY;
            case (i_last_word_data_valid)
              8'b00000001: ;
              8'b00000011: ;
              8'b00000111: ;
              8'b00001111: ;
              8'b00011111: ;
              8'b00111111: ;
              8'b01111111: ;
              8'b11111111: ;
              default: state_new = STATE_ERROR_GENERAL;
            endcase
          end
          if (i_tx_full) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
          end
        end
      STATE_COPY:
        if (i_process_initial == 1'b0) begin
          state_we  = 'b1;
          state_new = STATE_LENGTH_CHECKS;
        end
      STATE_LENGTH_CHECKS:
        begin
          state_we = 'b1;
          if (ipdecode_udp_length_reg < ( 8 /* UDP Header */ + 6*8 /* Minimum NTP Payload */ + 8 /* Smallest NTP extension */ ))
            state_new = STATE_ERROR_GENERAL;
          else if (ipdecode_udp_length_reg > 65507 /* IPv4 maximum UDP packet size */)
            state_new  = STATE_ERROR_GENERAL;
          else if (ipdecode_udp_length_reg[1:0] != 0) /* NTP packets are 7*8 + M(4+4n), always 4 byte aligned */
            state_new  = STATE_ERROR_GENERAL;
          else if (func_address_within_memory_bounds (ipdecode_offset_ntp_ext, 4) == 'b0)
            state_new  = STATE_ERROR_GENERAL;
          else
            state_new  = STATE_EXTRACT_EXT_FROM_RAM;
        end
      STATE_EXTRACT_EXT_FROM_RAM:
        if (ntp_extension_copied_reg[ntp_extension_counter_reg] == 'b1) begin
          if (memory_address_failure_reg == 'b1) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
            $display("%s:%0d memory_address_failure_reg %h",`__FILE__,`__LINE__, memory_address_failure_reg);
          end else if (memory_address_lastbyte_read_reg == 1'b1) begin
            state_we  = 'b1;
            state_new = STATE_EXTENSIONS_EXTRACTED;
          end else if (ntp_extension_counter_reg==NTP_EXTENSION_FIELDS-1) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
            $display("%s:%0d ",`__FILE__,`__LINE__);
          end
        end
      STATE_EXTENSIONS_EXTRACTED:
        if (nts_basic_sanity_check_packet_ok_reg) begin
          state_we  = 'b1;
          state_new = STATE_EXTRACT_COOKIE_FROM_RAM;
        end else begin
          state_we  = 'b1;
          state_new = STATE_ERROR_GENERAL;
          $display("%s:%0d packet rejected!",`__FILE__,`__LINE__);
        end
/*
        if (detect_nts_cookie_reg) begin
          if (ntp_extension_length_reg[detect_nts_cookie_index_reg] >= 8) begin
            state_we  = 'b1;
            state_new = STATE_EXTRACT_COOKIE_FROM_RAM;
          end else begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
          end
        end else begin
          state_we  = 'b1;
          state_new = STATE_ERROR_GENERAL;
        end
*/
      STATE_EXTRACT_COOKIE_FROM_RAM:
        if (i_access_port_rd_dv) begin
          state_we  = 'b1;
          state_new = STATE_VERIFY_KEY_FROM_COOKIE1;
        end
      STATE_VERIFY_KEY_FROM_COOKIE1:
        begin
          if (i_keymem_ready) begin
            state_we  = 'b1;
            state_new = STATE_VERIFY_KEY_FROM_COOKIE2;
          end else begin
            state_we  = 'b1;
            state_new = STATE_ERROR_UNIMPLEMENTED;
          end
        end
      STATE_VERIFY_KEY_FROM_COOKIE2:
        if (i_keymem_ready && keymem_get_key_with_id_reg == 'b0 ) begin
          if (i_keymem_key_valid == 'b0) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
            //$display("%s:%0d i_keymem_ready=%h keymem_get_key_with_id_reg=%h i_keymem_key_valid=%h...", `__FILE__, `__LINE__, i_keymem_ready, keymem_get_key_with_id_reg, i_keymem_key_valid);
          end else if (i_keymem_key_length) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL; //512 (256+256) bit keys are not supported
          end else if (keymem_key_word_reg == 'b1111) begin
            state_we  = 'b1;
            state_new = STATE_RX_AUTH_COOKIE;
          end
        end
      STATE_RX_AUTH_COOKIE:
        case (crypto_fsm_reg)
          CRYPTO_FSM_DONE_SUCCESS:
            begin
              state_we  = 'b1;
              state_new = STATE_RX_AUTH_PACKET;
            end
          CRYPTO_FSM_DONE_FAILURE:
            begin
              state_we  = 'b1;
              state_new = STATE_ERROR_GENERAL; //TODO Signal Kiss Of Death upon auth failures;
            end
          default: ;
        endcase
      STATE_RX_AUTH_PACKET:
        case (crypto_fsm_reg)
          CRYPTO_FSM_DONE_SUCCESS:
            begin
              state_we  = 'b1;
              state_new = STATE_TIMESTAMP;
            end
          CRYPTO_FSM_DONE_FAILURE:
            begin
              state_we  = 'b1;
              state_new = STATE_ERROR_GENERAL; //TODO Signal Kiss Of Death upon auth failures;
            end
          default: ;
        endcase
      STATE_TIMESTAMP:
        begin
          state_we  = 'b1;
          state_new = STATE_TIMESTAMP_WAIT;
        end
      STATE_TIMESTAMP_WAIT:
        if (i_timestamp_busy == 'b0) begin
          state_we  = 'b1;
          state_new = STATE_ERROR_UNIMPLEMENTED;
        end
      STATE_ERROR_GENERAL:
        begin
          state_we  = 'b1;
          state_new = STATE_IDLE;
        end
      default:
        begin
          state_we  = 'b1;
          state_new = STATE_IDLE;
        end
    endcase
  end

  //----------------------------------------------------------------
  // IP Decode
  //----------------------------------------------------------------

  always @*
  begin
    ipdecode_ethernet_protocol_we  = 'b0;
    ipdecode_ethernet_protocol_new = 'b0;
    ipdecode_ip_version_we         = 'b0;
    ipdecode_ip_version_new        = 'b0;
    ipdecode_ip4_ihl_we            = 'b0;
    ipdecode_ip4_ihl_new           = 'b0;
    ipdecode_udp_length_we         = 'b0;
    ipdecode_udp_length_new        = 'b0;

    if (i_clear) begin
      ipdecode_ethernet_protocol_we  = 'b1;
      ipdecode_ip_version_we         = 'b1;
      ipdecode_ip4_ihl_we            = 'b1;
      ipdecode_udp_length_we         = 'b1;

    end else if (i_process_initial) begin
//      $display("%s:%0d %h %h", `__FILE__, `__LINE__, i_data, previous_i_data_reg);
      if (word_counter_reg == 0) begin
        ipdecode_ethernet_protocol_we  = 'b1;
        ipdecode_ethernet_protocol_new = i_data[31:16];
        ipdecode_ip_version_we         = 'b1;
        ipdecode_ip_version_new        = i_data[15:12];
        ipdecode_ip4_ihl_we            = 'b1;
        ipdecode_ip4_ihl_new           = i_data[11:8];
//        $display("%s:%0d %h %h %h %h", `__FILE__, `__LINE__, ipdecode_ethernet_protocol_new, ipdecode_ip_version_new, ipdecode_ip4_ihl_new, previous_i_data_reg);

      end else if (detect_ipv4 && ipdecode_ip4_ihl_reg == 5) begin
        if (word_counter_reg == 3) begin
          ipdecode_udp_length_we   = 'b1;
          ipdecode_udp_length_new  = i_data[15:0];
        end
      end else if (detect_ipv6) begin
        if (word_counter_reg == 6) begin
          ipdecode_udp_length_we   = 'b1;
          ipdecode_udp_length_new  = i_data[47:32];
        end
      end
    end
  end

  //----------------------------------------------------------------
  // NTP Decode
  //----------------------------------------------------------------

  always @*
  begin
    timestamp_origin_timestamp_we   = 0;
    timestamp_origin_timestamp_new  = 0; /* RFC 5905 Figure 31: x.org         <--     r.xmt */
    timestamp_version_number_we     = 0;
    timestamp_version_number_new    = 0;

    if (i_clear) begin
      timestamp_origin_timestamp_we = 1;
      timestamp_version_number_we   = 1;

    end else if (i_process_initial) begin
      if (detect_ipv4 && detect_ipv4_bad == 'b0) begin
        if (word_counter_reg == 4) begin
          timestamp_version_number_we  = 1;
          timestamp_version_number_new = i_data[45:43];
          $display("%s:%0d timestamp_version_number_new=%h", `__FILE__, `__LINE__, timestamp_version_number_new);
        end else if (word_counter_reg == 9) begin
          timestamp_origin_timestamp_we  = 1;
          timestamp_origin_timestamp_new = { i_data[47:0], 16'h0 };
        end else if (word_counter_reg == 10) begin
          timestamp_origin_timestamp_we  = 1;
          timestamp_origin_timestamp_new = { timestamp_origin_timestamp_reg[63:16], i_data[63:48] };
          $display("%s:%0d timestamp_origin_timestamp_new=%h", `__FILE__, `__LINE__, timestamp_origin_timestamp_new);
        end
      end if (detect_ipv6) begin
        if (word_counter_reg == 6) begin
          timestamp_version_number_we  = 1;
          timestamp_version_number_new = i_data[13:11];
          $display("%s:%0d timestamp_version_number_new=%h", `__FILE__, `__LINE__, timestamp_version_number_new);
        end else if (word_counter_reg == 11) begin
          timestamp_origin_timestamp_we  = 1;
          timestamp_origin_timestamp_new = { i_data[15:0], 48'h0 };
        end else if (word_counter_reg == 12) begin
          timestamp_origin_timestamp_we  = 1;
          timestamp_origin_timestamp_new = { timestamp_origin_timestamp_reg[63:48], i_data[63:16] };
          $display("%s:%0d timestamp_origin_timestamp_new=%h", `__FILE__, `__LINE__, timestamp_origin_timestamp_new);
        end
      end
    end
  end

  //----------------------------------------------------------------
  // NTP Timestamp signals
  //----------------------------------------------------------------

  always @*
  begin
     timestamp_record_receive_timestamp_we  = 0;
     timestamp_record_receive_timestamp_new = 0;

     if (state_reg == STATE_IDLE && i_process_initial) begin
       // nts_engine (parser and rx_buffer) begins to receive packet from scheduler
       timestamp_record_receive_timestamp_we  = 1;
       timestamp_record_receive_timestamp_new = 1;
     end else if (timestamp_record_receive_timestamp_reg == 1) begin
       timestamp_record_receive_timestamp_we  = 1;
       timestamp_record_receive_timestamp_new = 0;
     end
  end

  //----------------------------------------------------------------
  // Output detection signals
  // Supports debugging/simulations and prevents reg optimizations
  //----------------------------------------------------------------

  always @*
  begin : output_detection_signals
    integer i;

    detect_nts_cookie_index_reg       = 'b0;

    detect_unique_identifier_reg      = 'b0;
    detect_nts_cookie_reg             = 'b0;
    detect_nts_cookie_placeholder_reg = 'b0;
    detect_nts_authenticator_reg      = 'b0;

    for (i = 0; i < NTP_EXTENSION_FIELDS; i = i + 1) begin
      if (ntp_extension_copied_reg[i]) begin

        if (ntp_extension_tag_reg[i]==TAG_NTS_UNIQUE_IDENTIFIER)
          detect_unique_identifier_reg      = 'b1;

        if (ntp_extension_tag_reg[i]==TAG_NTS_COOKIE) begin
          detect_nts_cookie_reg             = 'b1;
          detect_nts_cookie_index_reg       = i [NTP_EXTENSION_BITS-1:0];
        end

        if (ntp_extension_tag_reg[i]==TAG_NTS_COOKIE_PLACEHOLDER)
          detect_nts_cookie_placeholder_reg = 'b1;

        if (ntp_extension_tag_reg[i]==TAG_NTS_AUTHENTICATOR)
          detect_nts_authenticator_reg      = 'b1;
      end
    end
  end

  //----------------------------------------------------------------
  // Debug messages
  // Only emits messages that are useful for running local debug
  //----------------------------------------------------------------

  generate
    if (DEBUG_OUTPUT) begin
      always @(posedge i_clk)
        if (crypto_fsm_we == 1)
          $display("%s:%0d State: %h CRYPTO_FSM state %h => %h [%s]",`__FILE__,`__LINE__,
            state_reg,
            crypto_fsm_reg,
            crypto_fsm_new,
           (crypto_fsm_new==CRYPTO_FSM_DONE_SUCCESS) ? "Win!" : ((crypto_fsm_new==CRYPTO_FSM_DONE_FAILURE)?"Fail":"...."));
    end
  endgenerate
/*
  always @ (posedge i_clk, posedge i_areset)
  begin : debug_messages
    if (i_areset == 1'b1) begin
      ;
    end else begin
      case (state_reg)
        STATE_IDLE: ;
        STATE_COPY: ; //$display("%s:%0d STATE_COPY", `__FILE__, `__LINE__);
        STATE_LENGTH_CHECKS: ; //$display("%s:%0d STATE_LENGTH_CHECKS", `__FILE__, `__LINE__);
        STATE_EXTRACT_EXT_FROM_RAM: ; //$display("%s:%0d STATE_EXTRACT_EXT_FROM_RAM", `__FILE__, `__LINE__);
        STATE_EXTRACT_COOKIE_FROM_RAM: $display("%s:%0d STATE_EXTRACT_COOKIE_FROM_RAM", `__FILE__, `__LINE__);
        STATE_EXTENSIONS_EXTRACTED: $display("%s:%0d STATE_EXTENSIONS_EXTRACTED", `__FILE__, `__LINE__);
        STATE_VERIFY_KEY_FROM_COOKIE1: $display("%s:%0d STATE_VERIFY_KEY_FROM_COOKIE1", `__FILE__, `__LINE__);
        STATE_VERIFY_KEY_FROM_COOKIE2: $display("%s:%0d STATE_VERIFY_KEY_FROM_COOKIE2", `__FILE__, `__LINE__);
        STATE_TIMESTAMP: $display("%s:%0d TIMESTAMP", `__FILE__, `__LINE__);
        STATE_TIMESTAMP_WAIT: $display("%s:%0d TIMESTAMP_WAIT", `__FILE__, `__LINE__);
        STATE_ERROR_GENERAL: $display("%s:%0d warning: error", `__FILE__, `__LINE__);
        default: $display("%s:%0d warning: state %0d not implemented", `__FILE__, `__LINE__, state_reg);
      endcase
    end
  end
*/
endmodule
