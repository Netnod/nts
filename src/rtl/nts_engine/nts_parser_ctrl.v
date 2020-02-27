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
  parameter NTS_MAX_ALLOWED_PLACEHOLDERS = 7, // 5.7 The client SHOULD NOT include more than seven NTS Cookie Placeholder extension fields in a request.
  parameter [15:0] TAG_NTS_UNIQUE_IDENTIFIER  = 'h0104,
  parameter [15:0] TAG_NTS_COOKIE             = 'h0204,
  parameter [15:0] TAG_NTS_COOKIE_PLACEHOLDER = 'h0304,
  parameter [15:0] TAG_NTS_AUTHENTICATOR      = 'h0404,
  parameter [15:0] LEN_NTS_COOKIE             = 'h0068,
  parameter [15:0] LEN_NTS_MIN_UNIQUE_IDENT   = 'h0024, //5.3. The string MUST be at least 32 octets long.
  parameter [15:0] LEN_NTS_AUTHENTICATOR      = 'h0028, //TL 4h + KeyId 4h + SIV nonce 10h + SIV tag 10h
  parameter DEBUG_BUFFER = 1
) (
  input  wire                         i_areset, // async reset
  input  wire                         i_clk,

  output wire                         o_busy,

  input  wire                         i_api_cs,
  input  wire                         i_api_we,
  input  wire                   [7:0] i_api_address,
  input  wire                  [31:0] i_api_write_data,
  output wire                  [31:0] o_api_read_data,

  input  wire                         i_clear,
  input  wire                         i_process_initial,
  input  wire                   [3:0] i_last_word_data_valid,
  input  wire                  [63:0] i_data,

  input  wire                         i_tx_busy,
  input  wire                         i_tx_empty,
  input  wire                         i_tx_full,
  output wire                         o_tx_clear,
  output wire                         o_tx_addr_internal,
  output wire      [ADDR_WIDTH+3-1:0] o_tx_addr,
  output wire                         o_tx_w_en,
  output wire                  [63:0] o_tx_w_data,
  input  wire                  [15:0] i_tx_sum,
  input  wire                         i_tx_sum_done,
  output wire                         o_tx_sum_reset,
  output wire                  [15:0] o_tx_sum_reset_value,
  output wire                         o_tx_sum_en,
  output wire      [ADDR_WIDTH+3-1:0] o_tx_sum_bytes,
  output wire                         o_tx_update_length,
  output wire                         o_tx_ipv4_done,
  output wire                         o_tx_ipv6_done,

  input  wire                         i_access_port_wait,
  output wire      [ADDR_WIDTH+3-1:0] o_access_port_addr,
  output wire                  [15:0] o_access_port_burstsize,
  output wire                   [2:0] o_access_port_wordsize,
  output wire                         o_access_port_rd_en,
  input  wire                         i_access_port_rd_dv,
  input  wire                  [63:0] i_access_port_rd_data,

  output wire                   [2:0] o_keymem_key_word,
  output wire                         o_keymem_get_current_key,
  output wire                         o_keymem_get_key_with_id,
  output wire                  [31:0] o_keymem_server_id,
  input  wire                         i_keymem_key_valid,
  input  wire                  [31:0] i_keymem_key_id,
  input  wire                         i_keymem_ready,

  input  wire                         i_timestamp_busy,
  output wire                         o_timestamp_record_receive_timestamp,
  output wire                         o_timestamp_transmit, //parser signal packet transmit OK
  output wire                [63 : 0] o_timestamp_origin_timestamp,
  output wire                [ 2 : 0] o_timestamp_version_number,
  output wire                [ 7 : 0] o_timestamp_poll,
  output wire                         o_timestamp_kiss_of_death,

  input  wire                         i_crypto_busy,
  input  wire                         i_crypto_verify_tag_ok,

  output wire                         o_crypto_sample_key,
  output wire                  [63:0] o_crypto_cookieprefix,
  output wire                         o_crypto_rx_op_copy_ad,
  output wire                         o_crypto_rx_op_copy_nonce,
  output wire                         o_crypto_rx_op_copy_pc,
  output wire                         o_crypto_rx_op_copy_tag,
  output wire      [ADDR_WIDTH+3-1:0] o_crypto_rx_addr,
  output wire      [ADDR_WIDTH+3-1:0] o_crypto_rx_bytes,
  output wire                         o_crypto_tx_op_copy_ad,
  output wire                         o_crypto_tx_op_store_nonce_tag,
  output wire                         o_crypto_tx_op_store_cookie,
  output wire                         o_crypto_tx_op_store_cookiebuf,
  output wire      [ADDR_WIDTH+3-1:0] o_crypto_tx_addr,
  output wire      [ADDR_WIDTH+3-1:0] o_crypto_tx_bytes,
  output wire                         o_crypto_op_cookie_verify,
  output wire                         o_crypto_op_cookie_loadkeys,
  output wire                         o_crypto_op_cookie_rencrypt,
  output wire                         o_crypto_op_cookiebuf_append,
  output wire                         o_crypto_op_cookiebuf_reset,
  output wire                         o_crypto_op_c2s_verify_auth,
  output wire                         o_crypto_op_s2c_generate_auth,

  output wire                         o_muxctrl_timestamp_ipv4,
  output wire                         o_muxctrl_timestamp_ipv6,

  output wire                         o_muxctrl_crypto, //Crypto is in charge of RX, TX

  output wire                         o_detect_unique_identifier,
  output wire                         o_detect_nts_cookie,
  output wire                         o_detect_nts_cookie_placeholder,
  output wire                         o_detect_nts_authenticator,

  output wire                         o_statistics_nts_processed,
  output wire                         o_statistics_nts_bad_cookie,
  output wire                         o_statistics_nts_bad_auth,
  output wire                         o_statistics_nts_bad_keyid
);

  //----------------------------------------------------------------
  // API. Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam CORE_NAME    = 64'h70_61_72_73_65_72_20_20; //"parser  "
  localparam CORE_VERSION = 32'h30_2e_30_31;

  localparam ADDR_NAME0        =    0;
  localparam ADDR_NAME1        =    1;
  localparam ADDR_VERSION      =    2;
  localparam ADDR_DUMMY        =    3;
  localparam ADDR_STATE        = 'h10;
  localparam ADDR_STATE_CRYPTO = 'h12;
  localparam ADDR_ERROR_STATE  = 'h13;
  localparam ADDR_ERROR_COUNT  = 'h14;
  localparam ADDR_ERROR_CAUSE  = 'h15;
  localparam ADDR_ERROR_SIZE   = 'h16;

  //----------------------------------------------------------------
  // Error causes observable over API
  //----------------------------------------------------------------

  localparam ERROR_CAUSE_BAD_RXW          = 32'h42_52_58_57; //BRXW
  localparam ERROR_CAUSE_COOKIE1_GEN_FAIL = 32'h43_6f_47_31; //CoG1
  localparam ERROR_CAUSE_COOKIE1_TX_FAIL  = 32'h43_6f_54_31; //CoT1
  localparam ERROR_CAUSE_CRYPTO_BUSY      = 32'h43_42_73_79; //CBsy
  localparam ERROR_CAUSE_IPV_CONFUSED     = 32'h49_50_56_3f; //IPV?
  localparam ERROR_CAUSE_KEY_COOKIE_FAIL  = 32'h4b_43_6f_6b; //KCok
  localparam ERROR_CAUSE_KEY_CURRENT_FAIL = 32'h4b_43_75_72; //KCur
  localparam ERROR_CAUSE_KEYMEM_BUSY      = 32'h4b_42_73_79; //KBsy
  localparam ERROR_CAUSE_NTP_OUT_OF_MEM   = 32'h4d_45_52_30; //MER0
  localparam ERROR_CAUSE_PKT_SHORT        = 32'h4c_50_4b_30; //LPK0
  localparam ERROR_CAUSE_PKT_LONG         = 32'h4c_50_4b_31; //LPK1
  localparam ERROR_CAUSE_PKT_UDP_ALIGN    = 32'h4c_50_4b_32; //LPK2
  localparam ERROR_CAUSE_TX_FULL          = 32'h54_46_55_4c; //TFUL

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam BITS_STATE = 6;

  localparam [BITS_STATE-1:0] STATE_IDLE                     = 6'h00;
  localparam [BITS_STATE-1:0] STATE_COPY                     = 6'h01; //RX handling states
  localparam [BITS_STATE-1:0] STATE_LENGTH_CHECKS            = 6'h02;
  localparam [BITS_STATE-1:0] STATE_EXTRACT_EXT_FROM_RAM     = 6'h03;
  localparam [BITS_STATE-1:0] STATE_EXTENSIONS_EXTRACTED     = 6'h04;
  localparam [BITS_STATE-1:0] STATE_EXTRACT_COOKIE_FROM_RAM  = 6'h05;
  localparam [BITS_STATE-1:0] STATE_VERIFY_KEY_FROM_COOKIE1  = 6'h06;
  localparam [BITS_STATE-1:0] STATE_VERIFY_KEY_FROM_COOKIE2  = 6'h07;
  localparam [BITS_STATE-1:0] STATE_RX_AUTH_COOKIE           = 6'h08;
  localparam [BITS_STATE-1:0] STATE_RX_AUTH_PACKET           = 6'h09;

  localparam [BITS_STATE-1:0] STATE_WRITE_HEADER_IPV4_IPV6   = 6'h0a; //TX handling states
  localparam [BITS_STATE-1:0] STATE_TIMESTAMP                = 6'h0c;
  localparam [BITS_STATE-1:0] STATE_TIMESTAMP_WAIT           = 6'h0d;
  localparam [BITS_STATE-1:0] STATE_UNIQUE_IDENTIFIER_COPY_0 = 6'h0e;
  localparam [BITS_STATE-1:0] STATE_UNIQUE_IDENTIFIER_COPY_1 = 6'h0f;
  localparam [BITS_STATE-1:0] STATE_RETRIVE_CURRENT_KEY_0    = 6'h10;
  localparam [BITS_STATE-1:0] STATE_RETRIVE_CURRENT_KEY_1    = 6'h11;
  localparam [BITS_STATE-1:0] STATE_RESET_EXTRA_COOKIES      = 6'h15;
  localparam [BITS_STATE-1:0] STATE_ADDITIONAL_COOKIES_CTRL  = 6'h16;
  localparam [BITS_STATE-1:0] STATE_GENERATE_EXTRA_COOKIE    = 6'h17;
  localparam [BITS_STATE-1:0] STATE_RECORD_EXTRA_COOKIE      = 6'h18;
  localparam [BITS_STATE-1:0] STATE_COPY_PACKET_TO_CRYPTO_AD = 6'h19;
  localparam [BITS_STATE-1:0] STATE_TX_AUTH_PACKET           = 6'h1a;
  localparam [BITS_STATE-1:0] STATE_TX_EMIT_TL_NL_CL         = 6'h1b;
  localparam [BITS_STATE-1:0] STATE_TX_EMIT_NONCE_CIPHERTEXT = 6'h1c;
  localparam [BITS_STATE-1:0] STATE_TX_UPDATE_LENGTH         = 6'h1d;
  localparam [BITS_STATE-1:0] STATE_TX_WRITE_UDP_LENGTH      = 6'h1e;
  localparam [BITS_STATE-1:0] STATE_UDP_CHECKSUM_RESET       = 6'h1f;
  localparam [BITS_STATE-1:0] STATE_UDP_CHECKSUM_PS_SRCADDR  = 6'h20;
  localparam [BITS_STATE-1:0] STATE_UDP_CHECKSUM_PS_UDPLLEN  = 6'h21;
  localparam [BITS_STATE-1:0] STATE_UDP_CHECKSUM_DATAGRAM    = 6'h22;
  localparam [BITS_STATE-1:0] STATE_UDP_CHECKSUM_WAIT        = 6'h23;
  localparam [BITS_STATE-1:0] STATE_WRITE_NEW_UDP_CSUM       = 6'h24;
  localparam [BITS_STATE-1:0] STATE_WRITE_NEW_UDP_CSUM_DELAY = 6'h25;
  localparam [BITS_STATE-1:0] STATE_WRITE_NEW_IP_HEADER_0    = 6'h26;
  localparam [BITS_STATE-1:0] STATE_WRITE_NEW_IP_HEADER_1    = 6'h27;
  localparam [BITS_STATE-1:0] STATE_WRITE_NEW_IP_HEADR_DELAY = 6'h28;
  localparam [BITS_STATE-1:0] STATE_TRANSFER_PACKET          = 6'h29;

  localparam [BITS_STATE-1:0] STATE_ERROR_UNIMPLEMENTED      = 6'h2e;
  localparam [BITS_STATE-1:0] STATE_ERROR_GENERAL            = 6'h2f;

  localparam CRYPTO_FSM_IDLE                 = 'h00;
  localparam CRYPTO_FSM_WAIT_THEN_SUCCESS    = 'h01; // wait for complete. Always indicate success.
  localparam CRYPTO_FSM_RX_AUTH_COOKIE       = 'h02; // issue load nonce
  localparam CRYPTO_FSM_RX_AUTH_COOKIE_W1    = 'h03; // wait for complete, issue load tag
  localparam CRYPTO_FSM_RX_AUTH_COOKIE_W2    = 'h04; // wait for complete, issue load ciphertext
  localparam CRYPTO_FSM_RX_AUTH_COOKIE_W3    = 'h05; // wait for complete, issue cookie verify
  localparam CRYPTO_FSM_RX_AUTH_COOKIE_W4    = 'h06; // wait for complete, signal result
  localparam CRYPTO_FSM_RX_AUTH_PACKET       = 'h07; // issue load keys
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W1    = 'h08; // wait for complete, issue load AD
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W2    = 'h09; // wait for complete, issue load nonce
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W3    = 'h0a; // wait for complete, issue load tag
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W4    = 'h0b; // wait for complete, issue load load ciphertext
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W5    = 'h0c; // wait for complete, issue packet verify
  localparam CRYPTO_FSM_RX_AUTH_PACKET_W6    = 'h0d; // wait for complete, signal result
  localparam CRYPTO_FSM_GEN_COOKIE           = 'h0e; // issue cookie renecrypt
  localparam CRYPTO_FSM_EMIT_FIRST_COOKIE    = 'h0f; // issue tx emit cookie
  localparam CRYPTO_FSM_COOKIEBUF_RESET      = 'h10; // issue cookiebuf reset
  localparam CRYPTO_FSM_COOKIEBUF_APPEND     = 'h11; // issue cookiebuf append
  localparam CRYPTO_FSM_COPY_TX_TO_AD        = 'h12; // issue copy
  localparam CRYPTO_FSM_TX_AUTH_PACKET       = 'h13; // issue authenticate & encrypt encrypted payload
  localparam CRYPTO_FSM_STORE_TAG_NONCE      = 'h14;
  localparam CRYPTO_FSM_STORE_COOKIEBUF      = 'h15;
  localparam CRYPTO_FSM_DONE_FAILURE         = 'h1e;
  localparam CRYPTO_FSM_DONE_SUCCESS         = 'h1f;


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

  localparam  [7:0] IPV4_TOS     = 0;
  localparam  [2:0] IPV4_FLAGS   = 3'b010; // Reserved=0, must be zero. DF=1 (don't fragment). MF=0 (Last Fragment)
  localparam [12:0] IPV4_FRAGMENT_OFFSET = 0;
  localparam  [7:0] IPV4_TTL     = 8'hff;
  localparam  [7:0] IP_UDP_PROTO = 8'h11; //17

  localparam  [7:0] IPV6_TC       =  8'h0;
  localparam [19:0] IPV6_FL       = 20'h0;
  localparam  [7:0] IPV6_HOPLIMIT = IPV4_TTL;

  localparam ADDR_IPV4_START_NTP = 5 * 8 + 2;
  localparam ADDR_IPV6_START_NTP = 7 * 8 + 6;

  localparam HEADER_LENGTH_ETHERNET = 6+6+2;
  localparam HEADER_LENGTH_IPV4     = 5*4; //IHL=5, word size 4 bytes.
  localparam HEADER_LENGTH_IPV6     = 40;

  localparam OFFSET_ETH_IPV4_SRCADDR    = HEADER_LENGTH_ETHERNET + 12;
  localparam OFFSET_ETH_IPV6_SRCADDR    = HEADER_LENGTH_ETHERNET + 8;
  localparam OFFSET_ETH_IPV4_UDP        = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV4;
  localparam OFFSET_ETH_IPV6_UDP        = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV6;
  localparam OFFSET_ETH_IPV4_UDP_LENGTH = OFFSET_ETH_IPV4_UDP + 4;
  localparam OFFSET_ETH_IPV6_UDP_LENGTH = OFFSET_ETH_IPV6_UDP + 4;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg                         api_dummy_we;
  reg                  [31:0] api_dummy_new;
  reg                  [31:0] api_dummy_reg;

  reg                         access_port_addr_we;
  reg      [ADDR_WIDTH+3-1:0] access_port_addr_new;
  reg      [ADDR_WIDTH+3-1:0] access_port_addr_reg;
  reg                         access_port_burstsize_we;
  reg                  [15:0] access_port_burstsize_new;
  reg                  [15:0] access_port_burstsize_reg;
  reg                         access_port_rd_en_we;
  reg                         access_port_rd_en_new;
  reg                         access_port_rd_en_reg;
  reg                         access_port_wordsize_we;
  reg                   [2:0] access_port_wordsize_new;
  reg                   [2:0] access_port_wordsize_reg;

  reg                         cookie_server_id_we;
  reg                  [31:0] cookie_server_id_new;
  reg                  [31:0] cookie_server_id_reg;

  reg                         cookies_count_we;
  reg                   [3:0] cookies_count_new;
  reg                   [3:0] cookies_count_reg;


  reg                         error_state_we;
  reg        [BITS_STATE-1:0] error_state_new;
  reg        [BITS_STATE-1:0] error_state_reg;

  reg                         error_cause_we;
  reg                  [31:0] error_cause_new;
  reg                  [31:0] error_cause_reg;

  reg                         error_count_we;
  reg                  [31:0] error_count_new;
  reg                  [31:0] error_count_reg;

  reg                         error_size_we;
  reg      [ADDR_WIDTH+3-1:0] error_size_new;
  reg      [ADDR_WIDTH+3-1:0] error_size_reg;

  reg                         copy_bytes_we;
  reg                  [15:0] copy_bytes_new;
  reg                  [15:0] copy_bytes_reg;

//reg                         copy_rx_addr_we;
//reg      [ADDR_WIDTH+3-1:0] copy_rx_addr_new;
//reg      [ADDR_WIDTH+3-1:0] copy_rx_addr_reg;

  reg                         copy_tx_addr_we;
  reg      [ADDR_WIDTH+3-1:0] copy_tx_addr_new;
  reg      [ADDR_WIDTH+3-1:0] copy_tx_addr_reg;

  reg                         crypto_fsm_we;
  reg                   [4:0] crypto_fsm_new;
  reg                   [4:0] crypto_fsm_reg;

  reg                         state_we;
  reg        [BITS_STATE-1:0] state_new;
  reg        [BITS_STATE-1:0] state_reg;
  reg        [BITS_STATE-1:0] state_previous_reg;

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

  reg                          ipdecode_ethernet_mac_dst_we;
  reg                   [47:0] ipdecode_ethernet_mac_dst_new;
  reg                   [47:0] ipdecode_ethernet_mac_dst_reg;
  reg                          ipdecode_ethernet_mac_src_we;
  reg                   [47:0] ipdecode_ethernet_mac_src_new;
  reg                   [47:0] ipdecode_ethernet_mac_src_reg;
  reg                          ipdecode_ethernet_protocol_we;
  reg                   [15:0] ipdecode_ethernet_protocol_new;
  reg                   [15:0] ipdecode_ethernet_protocol_reg;

  reg                          ipdecode_ip_version_we;
  reg                    [3:0] ipdecode_ip_version_new;
  reg                    [3:0] ipdecode_ip_version_reg;

  reg                          ipdecode_ip4_ihl_we;
  reg                    [3:0] ipdecode_ip4_ihl_new;
  reg                    [3:0] ipdecode_ip4_ihl_reg;
  reg                          ipdecode_ip4_ip_dst_we;
  reg                   [31:0] ipdecode_ip4_ip_dst_new;
  reg                   [31:0] ipdecode_ip4_ip_dst_reg;
  reg                          ipdecode_ip4_ip_src_we;
  reg                   [31:0] ipdecode_ip4_ip_src_new;
  reg                   [31:0] ipdecode_ip4_ip_src_reg;

  reg                          ipdecode_ip6_ip_dst_we;
  reg                  [127:0] ipdecode_ip6_ip_dst_new;
  reg                  [127:0] ipdecode_ip6_ip_dst_reg;
  reg                          ipdecode_ip6_ip_src_we;
  reg                  [127:0] ipdecode_ip6_ip_src_new;
  reg                  [127:0] ipdecode_ip6_ip_src_reg;

  reg                          ipdecode_udp_length_we;
  reg                   [15:0] ipdecode_udp_length_new;
  reg                   [15:0] ipdecode_udp_length_reg;
  reg                          ipdecode_udp_port_dst_we;
  reg                   [15:0] ipdecode_udp_port_dst_new;
  reg                   [15:0] ipdecode_udp_port_dst_reg;
  reg                          ipdecode_udp_port_src_we;
  reg                   [15:0] ipdecode_udp_port_src_new;
  reg                   [15:0] ipdecode_udp_port_src_reg;

  reg                          keymem_get_current_key_new;
  reg                          keymem_get_current_key_reg;
  reg                          keymem_get_key_with_id_new;
  reg                          keymem_get_key_with_id_reg;

  reg                          keymem_key_id_we;
  reg                   [31:0] keymem_key_id_new;
  reg                   [31:0] keymem_key_id_reg;

  reg                          keymem_key_word_we;
  reg                    [2:0] keymem_key_word_new;
  reg                    [2:0] keymem_key_word_reg;
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
  reg                          nts_kiss_of_death_we;
  reg                          nts_kiss_of_death_new;
  reg                          nts_kiss_of_death_reg;
  reg       [ADDR_WIDTH+3-1:0] nts_unique_identifier_addr_new;
  reg       [ADDR_WIDTH+3-1:0] nts_unique_identifier_addr_reg;
  reg                   [15:0] nts_unique_identifier_length_new;
  reg                   [15:0] nts_unique_identifier_length_reg;
  reg                    [2:0] nts_valid_placeholders_new;
  reg                    [2:0] nts_valid_placeholders_reg;
  reg       [ADDR_WIDTH+3-1:0] nts_cookie_start_addr_new;
  reg       [ADDR_WIDTH+3-1:0] nts_cookie_start_addr_reg;

  reg                          detect_unique_identifier_reg;
  reg                          detect_nts_cookie_reg;
  reg                          detect_nts_cookie_placeholder_reg;
  reg                          detect_nts_authenticator_reg;

  reg [NTP_EXTENSION_BITS-1:0] detect_nts_cookie_index_reg;

  reg statistics_nts_processed_new;
  reg statistics_nts_processed_reg;
  reg statistics_nts_bad_cookie_new;
  reg statistics_nts_bad_cookie_reg;
  reg statistics_nts_bad_auth_new;
  reg statistics_nts_bad_auth_reg;
  reg statistics_nts_bad_keyid_new;
  reg statistics_nts_bad_keyid_reg;

  reg [15:0] tx_authenticator_length_new;
  reg [15:0] tx_authenticator_length_reg;

  reg [15:0] tx_ciphertext_length_new;
  reg [15:0] tx_ciphertext_length_reg;

  reg        tx_header_ipv4_index_we;
  reg  [2:0] tx_header_ipv4_index_new;
  reg  [2:0] tx_header_ipv4_index_reg;

  reg [15:0] tx_ipv4_csum_new;
  reg [15:0] tx_ipv4_csum_reg;

  reg        tx_ipv4_totlen_we;
  reg [15:0] tx_ipv4_totlen_new;
  reg [15:0] tx_ipv4_totlen_reg;

  reg        tx_header_ipv6_index_we;
  reg  [3:0] tx_header_ipv6_index_new;
  reg  [3:0] tx_header_ipv6_index_reg;

  reg        tx_udp_length_we;
  reg [15:0] tx_udp_length_new;
  reg [15:0] tx_udp_length_reg;

  reg        tx_udp_checksum_we;
  reg [15:0] tx_udp_checksum_new;
  reg [15:0] tx_udp_checksum_reg;

  //----------------------------------------------------------------
  // Debug buffer
  //----------------------------------------------------------------

  localparam DEBUG_BUFFER_WORDS = 64;

  reg  [63:0] debug_buffer [0:DEBUG_BUFFER_WORDS-1];
  wire  [5:0] debug_buffer_read_addr;
  wire [63:0] debug_buffer_read_data;
  reg   [5:0] debug_buffer_write_addr;
  reg  [63:0] debug_buffer_write_data;
  reg         debug_buffer_write_enable;

  assign debug_buffer_read_addr = i_api_address[6:1];
  assign debug_buffer_read_data = (DEBUG_BUFFER>0) ? debug_buffer[debug_buffer_read_addr] : 0;

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  reg [31:0] api_read_data;

  wire [3:0] cookies_to_emit;

  reg copy_done; //wire

  reg                    crypto_sample_key;
  reg             [63:0] crypto_cookieprefix;
  reg                    crypto_op_cookie_loadkeys;
  reg                    crypto_op_cookie_rencrypt;
  reg                    crypto_op_cookie_verify;
  reg                    crypto_op_cookiebuf_append;
  reg                    crypto_op_cookiebuf_reset;
  reg                    crypto_op_c2s_verify_auth;
  reg                    crypto_op_s2c_generate_auth;
  reg [ADDR_WIDTH+3-1:0] crypto_rx_addr;
  reg [ADDR_WIDTH+3-1:0] crypto_rx_bytes;
  reg                    crypto_rx_op_copy_ad;
  reg                    crypto_rx_op_copy_nonce;
  reg                    crypto_rx_op_copy_pc;
  reg                    crypto_rx_op_copy_tag;
  reg [ADDR_WIDTH+3-1:0] crypto_tx_addr;
  reg [ADDR_WIDTH+3-1:0] crypto_tx_bytes;
  reg                    crypto_tx_op_copy_ad;
  reg                    crypto_tx_op_store_cookie;
  reg                    crypto_tx_op_store_cookiebuf;
  reg                    crypto_tx_op_store_nonce_tag;

  wire detect_ipv4;
  wire detect_ipv4_bad;
  wire detect_ipv6;

  wire [ADDR_WIDTH+3-1:0] ipdecode_offset_ntp_ext;

  reg  muxctrl_crypto;

  wire     [15:0] tx_ethernet_type;
  wire    [111:0] tx_header_ethernet;
  wire [16*5-1:0] tx_header_ipv4_nocsum0;
  wire [16*4-1:0] tx_header_ipv4_nocsum1;
  wire [32*5-1:0] tx_header_ipv4;
  wire [40*8-1:0] tx_header_ipv6;
  wire     [15:0] tx_header_ipv6_payload_length;
  wire    [335:0] tx_header_ethernet_ipv4_udp;
  wire    [495:0] tx_header_ethernet_ipv6_udp;
  wire     [63:0] tx_header_udp;

  reg                    tx_address_internal;
  reg [ADDR_WIDTH+3-1:0] tx_address;
  reg                    tx_update_length;
  reg                    tx_write_en;
  reg             [63:0] tx_write_data;
  reg                    tx_sum_reset;
  reg             [15:0] tx_sum_reset_value;
  reg                    tx_sum_en;
  reg [ADDR_WIDTH+3-1:0] tx_sum_bytes;

  //----------------------------------------------------------------
  // Connectivity for ports etc.
  //----------------------------------------------------------------

  assign cookies_to_emit = 1 + { 1'b0, nts_valid_placeholders_reg };

  assign detect_ipv4     = (ipdecode_ethernet_protocol_reg == E_TYPE_IPV4) && (ipdecode_ip_version_reg == IP_V4);
  assign detect_ipv4_bad = detect_ipv4 && ipdecode_ip4_ihl_reg != 5;

  assign detect_ipv6     = (ipdecode_ethernet_protocol_reg == E_TYPE_IPV6) && (ipdecode_ip_version_reg == IP_V6);

  assign ipdecode_offset_ntp_ext[ADDR_WIDTH+3-1:3] = (detect_ipv4 && ipdecode_ip4_ihl_reg == 5) ? (5+6) : (detect_ipv6) ? (7+6) : 0;
  assign ipdecode_offset_ntp_ext[2:0]              = (detect_ipv4 && ipdecode_ip4_ihl_reg == 5) ? 2 : (detect_ipv6) ? 6 : 0;

  assign o_busy                 = (i_tx_empty == 'b0) || (state_reg != STATE_IDLE);

  assign o_access_port_addr      = access_port_addr_reg;
  assign o_access_port_burstsize = access_port_burstsize_reg;
  assign o_access_port_rd_en     = access_port_rd_en_reg;
  assign o_access_port_wordsize  = access_port_wordsize_reg;

  assign o_api_read_data = api_read_data;

  assign o_keymem_get_current_key = keymem_get_current_key_reg;
  assign o_keymem_key_word        = keymem_key_word_reg;
  assign o_keymem_get_key_with_id = keymem_get_key_with_id_reg;
  assign o_keymem_server_id       = keymem_server_id_reg;

  assign o_tx_clear     = state_reg == STATE_ERROR_GENERAL;
  assign o_tx_ipv4_done = detect_ipv4 && state_reg == STATE_TRANSFER_PACKET;
  assign o_tx_ipv6_done = detect_ipv6 && state_reg == STATE_TRANSFER_PACKET;
  assign o_tx_addr_internal = tx_address_internal;
  assign o_tx_addr          = tx_address;
  assign o_tx_update_length = tx_update_length;
  assign o_tx_w_en          = tx_write_en;
  assign o_tx_w_data        = tx_write_data;

  assign o_tx_sum_reset       = tx_sum_reset;
  assign o_tx_sum_reset_value = tx_sum_reset_value;
  assign o_tx_sum_en          = tx_sum_en;
  assign o_tx_sum_bytes       = tx_sum_bytes;

  assign o_timestamp_kiss_of_death            = nts_kiss_of_death_reg;
  assign o_timestamp_record_receive_timestamp = timestamp_record_receive_timestamp_reg;
  assign o_timestamp_transmit                 = (state_reg == STATE_TIMESTAMP);
  assign o_timestamp_origin_timestamp         = timestamp_origin_timestamp_reg;
  assign o_timestamp_version_number           = timestamp_version_number_reg;
  assign o_timestamp_poll                     = 0; //TODO timestamp_poll_reg;

  assign o_crypto_sample_key       = crypto_sample_key;

  assign o_crypto_rx_addr          = crypto_rx_addr;
  assign o_crypto_rx_bytes         = crypto_rx_bytes;

  assign o_crypto_rx_op_copy_ad    = crypto_rx_op_copy_ad;
  assign o_crypto_rx_op_copy_nonce = crypto_rx_op_copy_nonce;
  assign o_crypto_rx_op_copy_pc    = crypto_rx_op_copy_pc;
  assign o_crypto_rx_op_copy_tag   = crypto_rx_op_copy_tag;

  assign o_crypto_tx_addr               = crypto_tx_addr;
  assign o_crypto_tx_bytes              = crypto_tx_bytes;

  assign o_crypto_tx_op_copy_ad         = crypto_tx_op_copy_ad;
  assign o_crypto_tx_op_store_cookie    = crypto_tx_op_store_cookie;
  assign o_crypto_tx_op_store_cookiebuf = crypto_tx_op_store_cookiebuf;
  assign o_crypto_tx_op_store_nonce_tag = crypto_tx_op_store_nonce_tag;

  assign o_crypto_cookieprefix = crypto_cookieprefix;

  assign o_crypto_op_cookie_loadkeys   = crypto_op_cookie_loadkeys;
  assign o_crypto_op_cookie_rencrypt   = crypto_op_cookie_rencrypt;
  assign o_crypto_op_cookie_verify     = crypto_op_cookie_verify;
  assign o_crypto_op_cookiebuf_append  = crypto_op_cookiebuf_append;
  assign o_crypto_op_cookiebuf_reset   = crypto_op_cookiebuf_reset;
  assign o_crypto_op_c2s_verify_auth   = crypto_op_c2s_verify_auth;
  assign o_crypto_op_s2c_generate_auth = crypto_op_s2c_generate_auth;

  assign o_muxctrl_timestamp_ipv4 = ((state_reg == STATE_TIMESTAMP) || (state_reg == STATE_TIMESTAMP_WAIT)) && (detect_ipv4) && (detect_ipv4_bad=='b0);
  assign o_muxctrl_timestamp_ipv6 = ((state_reg == STATE_TIMESTAMP) || (state_reg == STATE_TIMESTAMP_WAIT)) && (detect_ipv6);

  assign o_muxctrl_crypto = muxctrl_crypto;

  assign o_detect_unique_identifier      = detect_unique_identifier_reg;
  assign o_detect_nts_cookie             = detect_nts_cookie_reg;
  assign o_detect_nts_cookie_placeholder = detect_nts_cookie_placeholder_reg;
  assign o_detect_nts_authenticator      = detect_nts_authenticator_reg;

  assign o_statistics_nts_processed  = statistics_nts_processed_reg;
  assign o_statistics_nts_bad_cookie = statistics_nts_bad_cookie_reg;
  assign o_statistics_nts_bad_auth   = statistics_nts_bad_auth_reg;
  assign o_statistics_nts_bad_keyid  = statistics_nts_bad_keyid_reg;



  assign tx_ethernet_type = detect_ipv4 ? E_TYPE_IPV4 : (detect_ipv6 ? E_TYPE_IPV6 : 16'hFFFF);
  assign tx_header_ethernet = {
                                ipdecode_ethernet_mac_src_reg,
                                ipdecode_ethernet_mac_dst_reg,
                                tx_ethernet_type
                              };

  assign tx_header_ipv4_nocsum0 = {
           IP_V4, 4'h5, IPV4_TOS, tx_ipv4_totlen_reg,  //|Version|  IHL  |Type of Service|          Total Length         |
           16'h0000, IPV4_FLAGS, IPV4_FRAGMENT_OFFSET, //|         Identification        |Flags|      Fragment Offset    |
           IPV4_TTL, IP_UDP_PROTO };                   //|  Time to Live |    Protocol   |         Header Checksum       |
  assign tx_header_ipv4_nocsum1 = {
           ipdecode_ip4_ip_dst_reg,                    //|                       Source Address                          |
           ipdecode_ip4_ip_src_reg };                  //|                    Destination Address                        |
  assign tx_header_ipv4 = { tx_header_ipv4_nocsum0, tx_ipv4_csum_reg, tx_header_ipv4_nocsum1 };

  assign tx_header_ipv6_payload_length = tx_udp_length_reg;
  assign tx_header_ipv6 = { IP_V6, IPV6_TC, IPV6_FL, tx_header_ipv6_payload_length, IP_UDP_PROTO, IPV6_HOPLIMIT, ipdecode_ip6_ip_dst_reg, ipdecode_ip6_ip_src_reg };

  assign tx_header_udp = { ipdecode_udp_port_dst_reg, ipdecode_udp_port_src_reg, tx_udp_length_reg, tx_udp_checksum_reg };
  assign tx_header_ethernet_ipv4_udp = { tx_header_ethernet, tx_header_ipv4, tx_header_udp };
  assign tx_header_ethernet_ipv6_udp = { tx_header_ethernet, tx_header_ipv6, tx_header_udp };

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
  // API
  //----------------------------------------------------------------

  always @*
  begin
    api_dummy_we = 0;
    api_dummy_new = 0;
    api_read_data = 0;
    if (i_api_cs) begin
      if (i_api_we) begin
        case (i_api_address)
          ADDR_DUMMY:
            begin
              api_dummy_we = 1;
              api_dummy_new = i_api_write_data;
            end
          default: ;
        endcase
      end else begin
        if (i_api_address < 128) begin
          case (i_api_address)
            ADDR_NAME0: api_read_data = CORE_NAME[63:32];
            ADDR_NAME1: api_read_data = CORE_NAME[31:0];
            ADDR_VERSION: api_read_data = CORE_VERSION;
            ADDR_STATE: api_read_data[BITS_STATE-1:0] = state_reg; //MSB=0 from init
            ADDR_STATE_CRYPTO: api_read_data = { 27'h0, crypto_fsm_reg };
            ADDR_ERROR_STATE: api_read_data[BITS_STATE-1:0] = error_state_reg; //MSB=0 from init
            ADDR_ERROR_COUNT: api_read_data = error_count_reg;
            ADDR_ERROR_CAUSE: api_read_data = error_cause_reg;
            ADDR_ERROR_SIZE: api_read_data[ADDR_WIDTH+3-1:0] = error_size_reg; //MSB=0 from init
            ADDR_DUMMY: api_read_data = api_dummy_reg;
            default: ;
          endcase
        end else begin
          api_read_data = (i_api_address[0]) ? debug_buffer_read_data[31:0] : debug_buffer_read_data[63:32];
        end
      end
    end
  end

  //----------------------------------------------------------------
  // API debug helpers
  //----------------------------------------------------------------

  always @*
  begin : api_error_signals
    reg [ADDR_WIDTH+3-1:0] bounds;
    bounds            = 0;
    bounds[3:0]       = last_bytes_reg;
    bounds            = bounds + { word_counter_reg, 3'b000};

    error_count_we = 0;
    error_count_new = 0;
    error_size_we = 0;
    error_size_new = 0;
    error_state_we = 0;
    error_state_new = 0;
    if (state_reg == STATE_ERROR_GENERAL) begin
      error_count_we = 1;
      error_count_new = error_count_reg + 1;
      error_size_we = 1;
      error_size_new = bounds;
      error_state_we = 1;
      error_state_new = state_previous_reg;
    end
  end

  //----------------------------------------------------------------
  // API debug buffer
  //----------------------------------------------------------------

  always @*
  begin : api_debug_write
    reg [ADDR_WIDTH-1:0] tmp;
    debug_buffer_write_enable = 0;
    debug_buffer_write_addr = 0;
    debug_buffer_write_data = 0;
    if (DEBUG_BUFFER) begin
      debug_buffer_write_data = i_data;
      case (state_reg)
        STATE_IDLE:
          if (i_process_initial) begin
            debug_buffer_write_addr = 0;
            debug_buffer_write_enable = 1;
          end
        STATE_COPY:
          if (i_process_initial) begin
            if (word_counter_reg < (DEBUG_BUFFER_WORDS-1)) begin
              tmp = word_counter_reg + 1;
              if (tmp[ADDR_WIDTH-1:6] == 0) begin
                debug_buffer_write_addr = tmp[5:0];
                debug_buffer_write_enable = 1;
              end
            end
          end
        default: ;
      endcase
    end //if DEBUG_BUFFER
  end

  if (DEBUG_BUFFER)
    always @ (posedge i_clk, posedge i_areset)
    begin : debug_update
      integer i;
      if (i_areset) begin
        for (i = 0; i < DEBUG_BUFFER_WORDS; i = i + 1) begin
          debug_buffer[i] <= 0;
        end
      end else begin
        if (debug_buffer_write_enable) begin
          debug_buffer[debug_buffer_write_addr] <= debug_buffer_write_data;
        end
      end
    end

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
      access_port_burstsize_reg  <= 'b0;
      access_port_rd_en_reg      <= 'b0;
      access_port_wordsize_reg   <= 'b0;

      api_dummy_reg              <= 32'h64_75_4d_79; //"duMy"

      cookie_server_id_reg       <= 'b0;
      cookies_count_reg          <= 0;

      copy_bytes_reg             <= 'b0;
      copy_tx_addr_reg           <= 0;

      crypto_fsm_reg             <= CRYPTO_FSM_IDLE;

      error_cause_reg            <= 'b0;
      error_count_reg            <= 'b0;
      error_size_reg             <= 'b0;
      error_state_reg            <= 'b0;

      ipdecode_ethernet_mac_dst_reg  <= 0;
      ipdecode_ethernet_mac_src_reg  <= 0;
      ipdecode_ethernet_protocol_reg <= 0;
      ipdecode_ip_version_reg    <= 'b0;
      ipdecode_ip4_ihl_reg       <= 'b0;
      ipdecode_ip4_ip_dst_reg    <= 'b0;
      ipdecode_ip4_ip_src_reg    <= 'b0;

      ipdecode_ip6_ip_dst_reg    <= 'b0;
      ipdecode_ip6_ip_src_reg    <= 'b0;

      ipdecode_udp_length_reg    <= 'b0;
      ipdecode_udp_port_dst_reg  <= 'b0;
      ipdecode_udp_port_src_reg  <= 'b0;

      keymem_get_current_key_reg <= 'b0;
      keymem_get_key_with_id_reg <= 'b0;
      keymem_key_id_reg          <= 'b0;
      keymem_key_word_reg        <= 'b0;
      keymem_server_id_reg       <= 'b0;

      last_bytes_reg             <= 'b0;

      memory_address_reg         <= 'b0;
      memory_bound_reg           <= 'b0;

      ntp_extension_counter_reg            <= 'b0;
      nts_authenticator_start_addr_reg     <= 'b0;
      nts_basic_sanity_check_packet_ok_reg <= 'b0;
      nts_cookie_start_addr_reg            <= 'b0;
      nts_kiss_of_death_reg                <= 'b0;
      nts_unique_identifier_addr_reg       <= 'b0;
      nts_unique_identifier_length_reg     <= 'b0;
      nts_valid_placeholders_reg           <= 'b0;

      state_reg                     <= 'b0;
      state_previous_reg            <= 'b0;

      statistics_nts_processed_reg  <= 0;
      statistics_nts_bad_cookie_reg <= 0;
      statistics_nts_bad_auth_reg   <= 0;
      statistics_nts_bad_keyid_reg  <= 0;

      timestamp_record_receive_timestamp_reg <= 'b0;
      timestamp_origin_timestamp_reg         <= 'b0;
      timestamp_version_number_reg           <= 'b0;

    //timestamp_poll_reg                     <= 'b0;

      tx_authenticator_length_reg <= 0;
      tx_ciphertext_length_reg <= 0;
      tx_header_ipv4_index_reg <= 0;
      tx_header_ipv4_index_reg <= 0;
      tx_ipv4_csum_reg <= 0;
      tx_ipv4_totlen_reg <= 0;
      tx_udp_checksum_reg <= 0; //TODO implement
      tx_udp_length_reg <= 0;

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

      if (access_port_addr_we)
        access_port_addr_reg <= access_port_addr_new;

      if (access_port_burstsize_we)
        access_port_burstsize_reg <= access_port_burstsize_new;

      if (access_port_rd_en_we)
        access_port_rd_en_reg <= access_port_rd_en_new;

      if (access_port_wordsize_we)
        access_port_wordsize_reg <= access_port_wordsize_new;

      if (api_dummy_we)
        api_dummy_reg <= api_dummy_new;

      if (cookie_server_id_we)
        cookie_server_id_reg <= cookie_server_id_new;

      if (cookies_count_we)
        cookies_count_reg <= cookies_count_new;

      if (copy_bytes_we)
        copy_bytes_reg <= copy_bytes_new;

      if (copy_tx_addr_we)
        copy_tx_addr_reg <= copy_tx_addr_new;

      if (crypto_fsm_we)
        crypto_fsm_reg <= crypto_fsm_new;

      if (error_cause_we)
        error_cause_reg <= error_cause_new;

      if (error_count_we)
        error_count_reg <= error_count_new;

      if (error_size_we)
        error_size_reg <= error_size_new;

      if (error_state_we)
        error_state_reg <= error_state_new;

      if (ipdecode_ethernet_mac_dst_we)
        ipdecode_ethernet_mac_dst_reg <= ipdecode_ethernet_mac_dst_new;

      if (ipdecode_ethernet_mac_src_we)
        ipdecode_ethernet_mac_src_reg <= ipdecode_ethernet_mac_src_new;

      if (ipdecode_ethernet_protocol_we)
        ipdecode_ethernet_protocol_reg <= ipdecode_ethernet_protocol_new;

      if (ipdecode_ip_version_we)
        ipdecode_ip_version_reg <= ipdecode_ip_version_new;

      if (ipdecode_ip4_ihl_we)
        ipdecode_ip4_ihl_reg <= ipdecode_ip4_ihl_new;

      if (ipdecode_ip4_ip_dst_we)
        ipdecode_ip4_ip_dst_reg <= ipdecode_ip4_ip_dst_new;

      if (ipdecode_ip4_ip_src_we)
        ipdecode_ip4_ip_src_reg <= ipdecode_ip4_ip_src_new;

      if (ipdecode_ip6_ip_dst_we)
        ipdecode_ip6_ip_dst_reg <= ipdecode_ip6_ip_dst_new;

      if (ipdecode_ip6_ip_src_we)
        ipdecode_ip6_ip_src_reg <= ipdecode_ip6_ip_src_new;

      if (ipdecode_udp_length_we)
        ipdecode_udp_length_reg <= ipdecode_udp_length_new;

      if (ipdecode_udp_port_dst_we)
        ipdecode_udp_port_dst_reg <= ipdecode_udp_port_dst_new;

      if (ipdecode_udp_port_src_we)
        ipdecode_udp_port_src_reg <= ipdecode_udp_port_src_new;

      keymem_get_current_key_reg <= keymem_get_current_key_new;

      keymem_get_key_with_id_reg <= keymem_get_key_with_id_new;

      if (keymem_key_id_we)
         keymem_key_id_reg <= keymem_key_id_new;

      if (keymem_key_word_we)
        keymem_key_word_reg <= keymem_key_word_new;

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
        ntp_extension_addr_reg   [ntp_extension_counter_reg] <= ntp_extension_addr_new;
        ntp_extension_tag_reg    [ntp_extension_counter_reg] <= ntp_extension_tag_new;
        ntp_extension_length_reg [ntp_extension_counter_reg] <= ntp_extension_length_new;
      end

      if (ntp_extension_counter_we)
        ntp_extension_counter_reg <= ntp_extension_counter_new;

      nts_authenticator_start_addr_reg     <= nts_authenticator_start_addr_new;
      nts_basic_sanity_check_packet_ok_reg <= nts_basic_sanity_check_packet_ok_new;
      nts_cookie_start_addr_reg            <= nts_cookie_start_addr_new;

      if (nts_kiss_of_death_we)
        nts_kiss_of_death_reg <= nts_kiss_of_death_new;

      nts_unique_identifier_addr_reg       <= nts_unique_identifier_addr_new;
      nts_unique_identifier_length_reg     <= nts_unique_identifier_length_new;
      nts_valid_placeholders_reg           <= nts_valid_placeholders_new;

      if (state_we) begin
        state_reg <= state_new;
        state_previous_reg <= state_reg;
      end

      statistics_nts_processed_reg  <= statistics_nts_processed_new;
      statistics_nts_bad_cookie_reg <= statistics_nts_bad_cookie_new;
      statistics_nts_bad_auth_reg   <= statistics_nts_bad_auth_new;
      statistics_nts_bad_keyid_reg  <= statistics_nts_bad_keyid_new;

      if (timestamp_record_receive_timestamp_we)
        timestamp_record_receive_timestamp_reg <= timestamp_record_receive_timestamp_new;

      if (timestamp_origin_timestamp_we)
        timestamp_origin_timestamp_reg <= timestamp_origin_timestamp_new;

      if (timestamp_version_number_we)
        timestamp_version_number_reg <= timestamp_version_number_new;

    //if (timestamp_poll_we)
    //  timestamp_poll_reg <= timestamp_poll_new;

      tx_authenticator_length_reg <= tx_authenticator_length_new;
      tx_ciphertext_length_reg <= tx_ciphertext_length_new;

      if (tx_header_ipv4_index_we)
        tx_header_ipv4_index_reg <= tx_header_ipv4_index_new;

      if (tx_header_ipv6_index_we)
        tx_header_ipv6_index_reg <= tx_header_ipv6_index_new;

      tx_ipv4_csum_reg <= tx_ipv4_csum_new;

      if (tx_ipv4_totlen_we)
        tx_ipv4_totlen_reg <= tx_ipv4_totlen_new;

      if (tx_udp_checksum_we)
        tx_udp_checksum_reg <= tx_udp_checksum_new;

      if (tx_udp_length_we)
        tx_udp_length_reg <= tx_udp_length_new;

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
    last_bytes_new = 0;

    case (state_reg)
      STATE_IDLE:
        if (i_process_initial) begin
          last_bytes_we = 'b1;
          last_bytes_new = i_last_word_data_valid;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // NTS Kiss-o'-Death
  // If the server is unable to validate the cookie or authenticate
  // the request, it SHOULD respond with a Kiss-o'-Death (KoD)
  // packet (see RFC 5905, Section 7.4 [RFC5905]) with kiss code
  // "NTSN", meaning "NTS negative-acknowledgment (NAK)".  It MUST
  // NOT include any NTS Cookie or NTS Authenticator and Encrypted
  // Extension Fields extension fields.
  // https://tools.ietf.org/html/draft-ietf-ntp-using-nts-for-ntp-21
  //----------------------------------------------------------------

  always @*
  begin : nts_kiss_of_death
    nts_kiss_of_death_we = 0;
    nts_kiss_of_death_new = 0;
    case (state_reg)
      STATE_IDLE:
        begin
          nts_kiss_of_death_we = 1;
          nts_kiss_of_death_new = 0;
        end
      STATE_VERIFY_KEY_FROM_COOKIE2:
        if (i_keymem_ready && keymem_get_key_with_id_reg == 'b0 ) begin
          if (i_keymem_key_valid == 'b0) begin
            nts_kiss_of_death_we = 1;
            nts_kiss_of_death_new = 1;
          end
        end
      STATE_RX_AUTH_COOKIE:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_FAILURE) begin
          nts_kiss_of_death_we = 1;
          nts_kiss_of_death_new = 1;
        end
      STATE_RX_AUTH_PACKET:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_FAILURE) begin
          nts_kiss_of_death_we = 1;
          nts_kiss_of_death_new = 1;
        end
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
    nts_unique_identifier_addr_new = 0;
    nts_unique_identifier_length_new = 0;
    nts_valid_placeholders_new = 0;

    begin : nts_basic_sanity_check_locals
      reg   [NTP_EXTENSION_BITS:0] i;
      reg [NTP_EXTENSION_BITS-1:0] j;

      reg [NTP_EXTENSION_BITS-1:0] authenticators;
      reg [NTP_EXTENSION_BITS-1:0] cookies;
      reg [NTP_EXTENSION_BITS-1:0] unique_idenfifiers;

      reg [2:0] cookie_placeholders;

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
            nts_unique_identifier_addr_new = ntp_extension_addr_reg[j];
            nts_unique_identifier_length_new = ntp_extension_length_reg[j];
            //5.3. The string MUST be at least 32 octets long.
            if (ntp_extension_length_reg[j] < LEN_NTS_MIN_UNIQUE_IDENT) begin
              evil_packet = 1;
            end
          end

          if (ntp_extension_tag_reg[j] == TAG_NTS_COOKIE) begin
            cookies = cookies + 1;
            nts_cookie_start_addr_new = ntp_extension_addr_reg[j];
            if (ntp_extension_length_reg[j] != LEN_NTS_COOKIE ) begin
              evil_packet = 1;
            end
          end

          if (ntp_extension_tag_reg[j] == TAG_NTS_COOKIE_PLACEHOLDER) begin
            if (cookie_placeholders < 7) begin
              cookie_placeholders = cookie_placeholders + 1;
            end else begin
              evil_packet = 1; //5.7 The client SHOULD NOT include more than seven
                               //    NTS Cookie Placeholder extension fields in a request.
            end
            //5.5. The body length of the NTS Cookie Placeholder extension field MUST be
            //     the same as the body length of the NTS Cookie extension field.
            // => Approximation: same length rules
            if (ntp_extension_length_reg[j] != LEN_NTS_COOKIE ) begin
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
              evil_packet = 1;
            end
          end

        end
      end

      // 5.7 Protocol Details, Client

      // Exactly one Unique Identifier extension field which MUST be
      // authenticated, MUST NOT be encrypted, and whose contents MUST NOT
      // duplicate those of any previous request.

      if ( unique_idenfifiers != 1 )
        evil_packet = 1;

      // 5.7 Protocol Details, Client

      // Exactly one NTS Cookie extension field which MUST be authenticated
      // and MUST NOT be encrypted.  The cookie MUST be one which has been
      // previously provided to the client; either from the key exchange
      // server during the NTS-KE handshake or from the NTP server in
      // response to a previous NTS-protected NTP request.

      if ( authenticators != 1 )
        evil_packet = 1;

      // 5.7 Protocol Details, Client

      // Exactly one NTS Authenticator and Encrypted Extension Fields
      // extension field, generated using an AEAD Algorithm and C2S key
      // established through NTS-KE.

      if ( cookies != 1 )
        evil_packet = 1;

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

  //----------------------------------------------------------------
  // RX buffer Access Port control
  //----------------------------------------------------------------

  always @*
  begin
    access_port_addr_we        = 'b0;
    access_port_addr_new       = 'b0;
    access_port_burstsize_we   = 'b0;
    access_port_burstsize_new  = 'b0;
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

      case (state_reg)
        STATE_EXTRACT_EXT_FROM_RAM:
          if (ntp_extension_copied_reg[ntp_extension_counter_reg] == 'b0) begin
             //$display("%s:%0d i_access_port_rd_dv=%0d i_access_port_wait=%0d", `__FILE__, `__LINE__, i_access_port_rd_dv, i_access_port_wait);
            if (i_access_port_rd_dv)
              ;
            else if (i_access_port_wait)
              ;
            else begin
              access_port_addr_we      = 'b1;
              access_port_addr_new     = memory_address_reg;
              access_port_rd_en_we     = 'b1;
              access_port_rd_en_new    = 'b1;
              access_port_wordsize_we  = 'b1;
              access_port_wordsize_new = 2; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
            end
          end
        STATE_EXTRACT_COOKIE_FROM_RAM:
          if (i_access_port_rd_dv)
            //$display("%s:%0d i_access_port_rd_data=%h",`__FILE__, `__LINE__, i_access_port_rd_data);
            ;
          else if (i_access_port_wait)
            ;
          else begin
            access_port_addr_we      = 'b1;
            access_port_addr_new     = ntp_extension_addr_reg[detect_nts_cookie_index_reg] + 4;
            access_port_rd_en_we     = 'b1;
            access_port_rd_en_new    = 'b1;
            access_port_wordsize_we  = 'b1;
            access_port_wordsize_new = 2; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
          end
        STATE_UNIQUE_IDENTIFIER_COPY_0:
          begin
            access_port_addr_we       = 'b1;
            access_port_addr_new      = nts_unique_identifier_addr_reg;
            access_port_burstsize_we  = 'b1;
            access_port_burstsize_new = nts_unique_identifier_length_reg;
            access_port_rd_en_we      = 'b1;
            access_port_rd_en_new     = 'b1;
            access_port_wordsize_we   = 'b1;
            access_port_wordsize_new  = 4; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit, 4: burst
          end

        STATE_UNIQUE_IDENTIFIER_COPY_1:
          begin
            access_port_rd_en_we      = 'b1;
            access_port_rd_en_new     = 'b0;
          end
        default: ;
      endcase
    end
  end

  //----------------------------------------------------------------
  // RX -> TX copy process
  //----------------------------------------------------------------

  always @*
  begin : copy_proc
    reg [ADDR_WIDTH+3-1:0] tmp_bytes;

    copy_done = 0;

    copy_bytes_we = 0;
    copy_bytes_new = 0;


    copy_tx_addr_we = 0;
    copy_tx_addr_new = 0;

    tmp_bytes = copy_bytes_reg[ADDR_WIDTH+3-1:0];

    case (state_reg)
      STATE_TIMESTAMP_WAIT:
        begin
          //Kiss-o'-Death requires copy_tx_addr_reg set earlier, ahead of jump
          //from STATE_TIMESTAMP_WAIT to TX_UPDATE_LENGTH
          copy_tx_addr_we   = 1;
          copy_tx_addr_new  = ipdecode_offset_ntp_ext;
        end
      STATE_UNIQUE_IDENTIFIER_COPY_0:
        begin
          copy_bytes_we     = 1;
          copy_bytes_new    = nts_unique_identifier_length_reg;
          copy_tx_addr_we   = 1;
          copy_tx_addr_new  = ipdecode_offset_ntp_ext;
        end
      STATE_UNIQUE_IDENTIFIER_COPY_1:
        begin
          if (i_access_port_rd_dv) begin
            if (copy_bytes_reg < 8) begin
              copy_bytes_we    = 1;
              copy_bytes_new   = 0;
              copy_done        = 1;
              copy_tx_addr_we  = 1;
              copy_tx_addr_new = copy_tx_addr_reg + tmp_bytes;
            end else begin
              copy_bytes_we    = 1;
              copy_bytes_new   = copy_bytes_reg - 8;
              copy_tx_addr_we  = 1;
              copy_tx_addr_new = copy_tx_addr_reg + 8;
            end
          end
        end
      STATE_TX_EMIT_TL_NL_CL:
        begin
          copy_tx_addr_we  = 1;
          copy_tx_addr_new = copy_tx_addr_reg + BYTES_AUTH_OVERHEAD;
        end
      STATE_TX_EMIT_NONCE_CIPHERTEXT:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_SUCCESS) begin : emit_nonce_ct_tmp
          reg [ADDR_WIDTH+3-1:0] ciphertext_length;
          ciphertext_length = tx_ciphertext_length_reg[ADDR_WIDTH+3-1:0];

          copy_tx_addr_we  = 1;
          copy_tx_addr_new = copy_tx_addr_reg + BYTES_AUTH_NONCE + ciphertext_length;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Keymem control
  //   1. Sets outputs controlling nts_keymem operation.
  //   2. Records keymem_id to be used in new cookie generation.
  //----------------------------------------------------------------

  always @*
  begin : keymem_control
    crypto_sample_key          = 'b0;
    keymem_get_current_key_new = 'b0;
    keymem_get_key_with_id_new = 'b0;

    keymem_key_id_we           = 'b0;
    keymem_key_id_new          = 'b0;

    keymem_key_word_we         = 'b0;
    keymem_key_word_new        = 'b0;

    keymem_server_id_we        = 'b0;
    keymem_server_id_new       = 'b0;

    case (state_reg)
      STATE_EXTRACT_COOKIE_FROM_RAM:
        begin
          keymem_key_word_we         = 'b1;
          keymem_server_id_we        = 'b1;
        end
      STATE_VERIFY_KEY_FROM_COOKIE1:
        if (i_keymem_ready == 'b1) begin
          keymem_get_key_with_id_new = 'b1;
          keymem_key_word_we         = 'b1;
          keymem_key_word_new        = 'b0;
          keymem_server_id_we        = 'b1;
          keymem_server_id_new       = cookie_server_id_reg;
        end
      STATE_VERIFY_KEY_FROM_COOKIE2:
        if (i_keymem_ready && keymem_get_key_with_id_reg == 'b0) begin
          if (i_keymem_key_valid == 'b0) begin
            ; // reset, zero all output
          end else if (keymem_key_word_reg == 'b111) begin
            crypto_sample_key = 1;
            ; // reset, zero all output
          end else begin
            // Yay! We read a key word
            crypto_sample_key = 1;
            keymem_get_key_with_id_new = 'b1;
            keymem_key_word_we         = 'b1;
            keymem_key_word_new        = keymem_key_word_reg + 1;
          end
        end
      STATE_RETRIVE_CURRENT_KEY_0:
        begin
          keymem_get_current_key_new = 'b1;
          keymem_key_word_we         = 'b1;
          keymem_key_word_new        = 'b0;
        end
      STATE_RETRIVE_CURRENT_KEY_1:
        if (i_keymem_ready && keymem_get_current_key_reg == 'b0) begin
          if (i_keymem_key_valid == 'b0) begin
             ; // reset, zero all output
          end else if (keymem_key_word_reg == 'b111) begin
            crypto_sample_key = 1;
            ; // reset, zero all output
          end else begin
            // Yay! We read a key word
            //TODO error if key_id changes during read
            crypto_sample_key = 1;
            keymem_get_current_key_new = 'b1;
            keymem_key_id_we           = 'b1;
            keymem_key_id_new          = i_keymem_key_id;
            keymem_key_word_we         = 'b1;
            keymem_key_word_new        = keymem_key_word_reg + 1;
          end
        end
      default: ;
    endcase
  end

  always @*
  begin
    cookie_server_id_we  = 'b0;
    cookie_server_id_new = 'b0;
    if (state_reg == STATE_EXTRACT_COOKIE_FROM_RAM) begin
      if (i_access_port_rd_dv) begin
        cookie_server_id_we  = 'b1;
        cookie_server_id_new = i_access_port_rd_data[31:0];
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
  // TX IPv4 csum calculation
  //----------------------------------------------------------------

  function [16:0] calc_csum16 ( input [15:0] a, input [15:0] b );
    calc_csum16 = { 1'b0, a } + { 1'b0, b };
  endfunction

  function [15:0] ipv4_csum ( input [16*9-1:0] header );

    integer     i;

    reg  [8:0] carry;
    reg  [7:0] msb; // Largest possible msb is 8 as in 9*0xFFFF=0x8FFF7
    reg [15:0] sum0 [0:4];
    reg [15:0] sum1 [0:1];
    reg [15:0] sum2;
    reg [15:0] sum3;
    reg [15:0] sum4;
    reg [15:0] notsum4;

  begin
    for (i = 0; i < 4; i = i+1) begin
      { carry[i], sum0[i] } = calc_csum16( header[i*32+:16], header[i*32+16+:16] );
    end
    for (i = 0; i < 2; i = i+1) begin
      { carry[4+i], sum1[i] } = calc_csum16( sum0[2*i], sum0[2*i+1] );
    end
    { carry[6], sum2 } = calc_csum16( sum1[0], sum1[1] );
    { carry[7], sum3 } = calc_csum16( sum2, header[143-:16] );

    msb = 0;
    for (i = 0; i < 8; i = i + 1) begin
      msb = msb + { 7'h0, carry[i] };
    end

    sum4 = sum3 + { 8'h0, msb }; //Cannot overflow! 0x8FFF7 = 0x8 + 0xFFF7 = 0xFFFF
    notsum4 = ~sum4;
    ipv4_csum = notsum4;
  end
  endfunction

  always @*
  begin : ipv4_calc_proc
    reg [16*9-1:0] words;
    words = { tx_header_ipv4_nocsum0, tx_header_ipv4_nocsum1 };
    tx_ipv4_csum_new = ipv4_csum( words );
  end

  //----------------------------------------------------------------
  // TX write control
  //----------------------------------------------------------------

  task tx_control_update_udp_header;
  begin
    if (detect_ipv4) begin
      tx_address    = OFFSET_ETH_IPV4_UDP;
    end else if (detect_ipv6) begin
      tx_address    = OFFSET_ETH_IPV6_UDP;
    end
    tx_write_en   = 1;
    tx_write_data = tx_header_udp;
  end
  endtask

  always @*
  begin : tx_control

    reg [15:0] nonce_length;
    nonce_length = BYTES_AUTH_NONCE; //typecast from length undefined to 16bit

    tx_authenticator_length_new = BYTES_AUTH_OVERHEAD /*TL, NL, CL */ + BYTES_AUTH_NONCE + tx_ciphertext_length_reg;
    tx_address_internal = 0;
    tx_address = 0;
    tx_ciphertext_length_new = BYTES_AUTH_TAG + LEN_NTS_COOKIE * cookies_to_emit;
    tx_header_ipv4_index_we = 0;
    tx_header_ipv4_index_new = 0;
    tx_header_ipv6_index_we = 0;
    tx_header_ipv6_index_new = 0;
    tx_sum_reset = 0;
    tx_sum_reset_value = 0;
    tx_sum_en = 0;
    tx_sum_bytes = 0;
    tx_update_length = 0;
    tx_write_en = 0;
    tx_write_data = 0;
    case (state_reg)
      STATE_COPY:
        if (i_process_initial && !i_tx_full) begin
          if (detect_ipv4) begin
            tx_header_ipv4_index_we = 1;
            tx_header_ipv4_index_new = 5;
          end if (detect_ipv6) begin
            tx_header_ipv6_index_we = 1;
            tx_header_ipv6_index_new = 7;
          end
        end
      STATE_WRITE_HEADER_IPV4_IPV6:
        if (detect_ipv4) begin : emit_ipv4_headers
          reg [6*64-1:0] header;
          tx_address_internal = 1;
          tx_header_ipv4_index_we = 1;
          tx_header_ipv4_index_new = tx_header_ipv4_index_reg - 1;
          header = { tx_header_ethernet_ipv4_udp, 48'h0 };
          tx_write_en = 1;
          tx_write_data = header[ tx_header_ipv4_index_reg*64+:64 ];
        end
        else if (detect_ipv6) begin : emit_ipv6_headers
          reg [8*64-1:0] header;
          tx_address_internal = 1;
          tx_header_ipv6_index_we = 1;
          tx_header_ipv6_index_new = tx_header_ipv6_index_reg - 1;
          header = { tx_header_ethernet_ipv6_udp, 16'h0 };
          tx_write_en = 1;
          tx_write_data = header[ tx_header_ipv6_index_reg*64+:64 ];
        end
      STATE_UNIQUE_IDENTIFIER_COPY_1:
        begin
          tx_address    = copy_tx_addr_reg;
          tx_write_en   = i_access_port_rd_dv;
          tx_write_data = i_access_port_rd_data;
        end
      STATE_TX_EMIT_TL_NL_CL:
        begin
          tx_address    = copy_tx_addr_reg;
          tx_write_en   = 1;
          tx_write_data = { TAG_NTS_AUTHENTICATOR, tx_authenticator_length_reg, nonce_length, tx_ciphertext_length_reg };
        end
      STATE_TX_UPDATE_LENGTH:
        begin
          tx_address       = copy_tx_addr_reg;
          tx_update_length = 1;
        end
      STATE_TX_WRITE_UDP_LENGTH: tx_control_update_udp_header();
      STATE_UDP_CHECKSUM_RESET:
        begin
          tx_sum_reset = 1;
          tx_sum_reset_value = 16'h0011; //Static pseudo header. 00: Zero pre-padding. 0x11/17: UDP protocol.
        end
      STATE_UDP_CHECKSUM_PS_SRCADDR:
        begin
          tx_sum_en = 1;
          if (detect_ipv4) begin
            tx_address = OFFSET_ETH_IPV4_SRCADDR;
            tx_sum_bytes = 8; //4 byte src + 4 bytes dst
          end else if (detect_ipv6) begin
            tx_address = OFFSET_ETH_IPV6_SRCADDR;
            tx_sum_bytes = 32; //16 byte src + 16 bytes dst
          end
        end
      STATE_UDP_CHECKSUM_PS_UDPLLEN:
        if (i_tx_sum_done) begin
          tx_sum_en = 1;
          if (detect_ipv4) begin
            tx_address = OFFSET_ETH_IPV4_UDP_LENGTH;
            tx_sum_bytes = 2;
          end else if (detect_ipv6) begin
            tx_address = OFFSET_ETH_IPV6_UDP_LENGTH;
            tx_sum_bytes = 2;
          end
        end
      STATE_UDP_CHECKSUM_DATAGRAM:
        if (i_tx_sum_done) begin
          tx_sum_en = 1;
          tx_sum_bytes = tx_udp_length_reg[ADDR_WIDTH+3-1:0]; //TODO: breaks if address space > 16 bits
          if (detect_ipv4) begin
            tx_address = OFFSET_ETH_IPV4_UDP;
          end else if (detect_ipv6) begin
            tx_address = OFFSET_ETH_IPV6_UDP;
          end
        end
      STATE_WRITE_NEW_UDP_CSUM:
        begin
          tx_control_update_udp_header();
          //tx_write_data = 64'hF0F0_F0F0_F0F0;
          //$display("%s:%0d UDP_CSUM: TX[%h (%0d)] = [%h]", `__FILE__, `__LINE__, tx_address, tx_address, tx_write_data);
        end
      STATE_WRITE_NEW_IP_HEADER_0:
        if (detect_ipv4) begin
          tx_address = HEADER_LENGTH_ETHERNET;
          tx_write_en = 1;
          tx_write_data = tx_header_ipv4[159-:64];
          //tx_write_data = 64'hdead_f00d_dead_f00d;
          //$display("%s:%0d IP_HEADER_0: TX[%h (%0d)] = [%h]", `__FILE__, `__LINE__, tx_address,tx_address, tx_write_data);
        end else if (detect_ipv6) begin
          tx_address = HEADER_LENGTH_ETHERNET;
          tx_write_en = 1;
          tx_write_data = tx_header_ipv6[40*8-1-:64];
          // |Version| Traffic Class |           Flow Label                  |
          // |         Payload Length        |  Next Header  |   Hop Limit   |
        end
      STATE_WRITE_NEW_IP_HEADER_1:
        if (detect_ipv4) begin
          tx_address = HEADER_LENGTH_ETHERNET + 8;
          tx_write_en = 1;
          tx_write_data = tx_header_ipv4[95-:64];
          //tx_write_data = 64'h1337_1337_1337_1337;
          //$display("%s:%0d IP_HEADER_0: TX[%h (%0d)] = [%h]", `__FILE__, `__LINE__, tx_address, tx_address, tx_write_data);
        end
      default: ;
    endcase
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

    crypto_cookieprefix = 0;

    crypto_op_cookie_loadkeys = 0;
    crypto_op_cookie_rencrypt = 0;
    crypto_op_cookie_verify = 0;
    crypto_op_cookiebuf_append = 0;
    crypto_op_cookiebuf_reset = 0;
    crypto_op_c2s_verify_auth = 0;
    crypto_op_s2c_generate_auth = 0;

    crypto_rx_addr = 0;
    crypto_rx_bytes = 0;
    crypto_rx_op_copy_ad = 0;
    crypto_rx_op_copy_nonce = 0;
    crypto_rx_op_copy_pc = 0;
    crypto_rx_op_copy_tag = 0;

    crypto_tx_addr = 0;
    crypto_tx_bytes = 0;
    crypto_tx_op_copy_ad = 0;
    crypto_tx_op_store_cookie = 0;
    crypto_tx_op_store_cookiebuf = 0;
    crypto_tx_op_store_nonce_tag = 0;

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
          STATE_RESET_EXTRA_COOKIES:
            begin
              crypto_fsm_we  = 1;
              crypto_fsm_new = CRYPTO_FSM_COOKIEBUF_RESET;
            end
          STATE_GENERATE_EXTRA_COOKIE:
            begin
              crypto_fsm_we  = 1;
              crypto_fsm_new = CRYPTO_FSM_GEN_COOKIE;
            end
          STATE_RECORD_EXTRA_COOKIE:
            begin
              crypto_fsm_we  = 1;
              crypto_fsm_new = CRYPTO_FSM_COOKIEBUF_APPEND;
            end
          STATE_COPY_PACKET_TO_CRYPTO_AD:
            begin
              crypto_fsm_we  = 1;
              crypto_fsm_new = CRYPTO_FSM_COPY_TX_TO_AD;
            end
          STATE_TX_AUTH_PACKET:
            begin
              crypto_fsm_we  = 1;
              crypto_fsm_new = CRYPTO_FSM_TX_AUTH_PACKET;
            end
          STATE_TX_EMIT_TL_NL_CL: ; // No-operation. Performed by other parser logic.
          STATE_TX_EMIT_NONCE_CIPHERTEXT:
            begin
              crypto_fsm_we  = 1;
              crypto_fsm_new = CRYPTO_FSM_STORE_TAG_NONCE;
            end
          default: ;
        endcase
      CRYPTO_FSM_WAIT_THEN_SUCCESS:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_DONE_SUCCESS;
        end
      CRYPTO_FSM_RX_AUTH_COOKIE:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_RX_AUTH_COOKIE_W1;
          crypto_rx_op_copy_nonce = 1;
          crypto_rx_addr = nts_cookie_start_addr_reg + OFFSET_COOKIE_NONCE;
          crypto_rx_bytes = BYTES_COOKIE_NONCE;
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
      CRYPTO_FSM_GEN_COOKIE:
        if (i_crypto_busy == 1'b0) begin
          crypto_op_cookie_rencrypt = 1;
          crypto_fsm_we = 1;
          crypto_fsm_new = CRYPTO_FSM_WAIT_THEN_SUCCESS;
        end
      CRYPTO_FSM_EMIT_FIRST_COOKIE:
        if (i_crypto_busy == 1'b0) begin
          crypto_tx_addr = copy_tx_addr_reg;
          crypto_tx_bytes = 'h68; //TODO declare constant?
          crypto_tx_op_store_cookie = 1;
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_WAIT_THEN_SUCCESS;
        end
      CRYPTO_FSM_COOKIEBUF_RESET:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_WAIT_THEN_SUCCESS;
          crypto_op_cookiebuf_reset = 1;
        end
      CRYPTO_FSM_COOKIEBUF_APPEND:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_WAIT_THEN_SUCCESS;
          crypto_cookieprefix = { TAG_NTS_COOKIE, LEN_NTS_COOKIE, keymem_key_id_reg };
          crypto_op_cookiebuf_append = 1;
        end
      CRYPTO_FSM_COPY_TX_TO_AD:
        if (i_crypto_busy == 1'b0) begin : crypto_fsm_copy_tx_to_ad
          reg [ADDR_WIDTH+3-1:0] ntp_start;
          ntp_start = (detect_ipv4) ? ADDR_IPV4_START_NTP : ADDR_IPV6_START_NTP;

          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_WAIT_THEN_SUCCESS;
          crypto_tx_op_copy_ad = 1;
          crypto_tx_addr = ntp_start;
          //crypto_tx_addr = 0;
          crypto_tx_bytes = copy_tx_addr_reg - ntp_start;
        end
      CRYPTO_FSM_TX_AUTH_PACKET:
        begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_WAIT_THEN_SUCCESS;
          crypto_op_s2c_generate_auth = 1;
        end
      CRYPTO_FSM_STORE_TAG_NONCE:
        begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_STORE_COOKIEBUF;
          crypto_tx_op_store_nonce_tag = 1;
          crypto_tx_addr = copy_tx_addr_reg;
          crypto_tx_bytes = BYTES_AUTH_NONCE + tx_ciphertext_length_reg[ADDR_WIDTH+3-1:0];
          //$display("%s:%0d **** TX addr: %h tx_bytes: %h", `__FILE__, `__LINE__, crypto_tx_addr, crypto_tx_bytes);
        end
      CRYPTO_FSM_STORE_COOKIEBUF:
        if (i_crypto_busy == 1'b0) begin
          crypto_fsm_we  = 1;
          crypto_fsm_new = CRYPTO_FSM_WAIT_THEN_SUCCESS;
          crypto_tx_op_store_cookiebuf = 1;
          crypto_tx_addr = copy_tx_addr_reg + BYTES_AUTH_NONCE + BYTES_AUTH_TAG;;
          crypto_tx_bytes = tx_ciphertext_length_reg[ADDR_WIDTH+3-1:0]; //unsused by crypto for now, but clearer if stated
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
  // Finite State Machine - Set Error Task
  // Goes to STATE_ERROR_GENERAL while setting an error cause
  //----------------------------------------------------------------

  task set_error_state( input [31:0] cause );
  begin
    state_we = 1;
    state_new = STATE_ERROR_GENERAL;
    error_cause_we = 1;
    error_cause_new = cause;
  end
  endtask

  //----------------------------------------------------------------
  // Finite State Machine
  // Overall functionallitty control
  //----------------------------------------------------------------

  always @*
  begin : FSM
    state_we   = 'b0;
    state_new  = STATE_IDLE;

    error_cause_we = 0;
    error_cause_new = 0;

    if (i_clear)
      state_we  = 'b1;

    else case (state_reg)
      STATE_IDLE:
        begin
          if (i_process_initial) begin
            state_we  = 'b1;
            state_new = STATE_COPY;
          end
          if (i_tx_full)
            set_error_state( ERROR_CAUSE_TX_FULL );
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
            set_error_state( ERROR_CAUSE_PKT_SHORT );
          else if (ipdecode_udp_length_reg > 65507 /* IPv4 maximum UDP packet size */)
            set_error_state( ERROR_CAUSE_PKT_LONG );
          else if (ipdecode_udp_length_reg[1:0] != 0) /* NTP packets are 7*8 + M(4+4n), always 4 byte aligned */
            set_error_state( ERROR_CAUSE_PKT_UDP_ALIGN );
          else if (func_address_within_memory_bounds (ipdecode_offset_ntp_ext, 4) == 'b0)
            set_error_state( ERROR_CAUSE_NTP_OUT_OF_MEM );
          else
            state_new  = STATE_EXTRACT_EXT_FROM_RAM;
        end
      STATE_EXTRACT_EXT_FROM_RAM:
        if (ntp_extension_copied_reg[ntp_extension_counter_reg] == 'b1) begin
          if (memory_address_failure_reg == 'b1) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
          end else if (memory_address_lastbyte_read_reg == 1'b1) begin
            state_we  = 'b1;
            state_new = STATE_EXTENSIONS_EXTRACTED;
          end else if (ntp_extension_counter_reg==NTP_EXTENSION_FIELDS-1) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
          end
        end
      STATE_EXTENSIONS_EXTRACTED:
        if (nts_basic_sanity_check_packet_ok_reg) begin
          state_we  = 'b1;
          state_new = STATE_EXTRACT_COOKIE_FROM_RAM;
        end else begin
          state_we  = 'b1;
          state_new = STATE_ERROR_GENERAL;
        end
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
            set_error_state( ERROR_CAUSE_KEYMEM_BUSY );
          end
        end
      STATE_VERIFY_KEY_FROM_COOKIE2:
        if (i_keymem_ready && keymem_get_key_with_id_reg == 'b0 ) begin
          if (i_keymem_key_valid == 'b0) begin
          //set_error_state( ERROR_CAUSE_KEY_COOKIE_FAIL );
            state_we  = 'b1;
            state_new = STATE_WRITE_HEADER_IPV4_IPV6; //Kiss-o'-Death
          end else if (keymem_key_word_reg == 'b111) begin
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
              state_new = STATE_WRITE_HEADER_IPV4_IPV6; //Kiss-o'-Death
            end
          default: ;
        endcase
      STATE_RX_AUTH_PACKET:
        case (crypto_fsm_reg)
          CRYPTO_FSM_DONE_SUCCESS:
            begin
              state_we  = 'b1;
              state_new = STATE_WRITE_HEADER_IPV4_IPV6;

            end
          CRYPTO_FSM_DONE_FAILURE:
            begin
              state_we  = 'b1;
              state_new = STATE_WRITE_HEADER_IPV4_IPV6; //Kiss-o'-Death
            end
          default: ;
        endcase
      STATE_WRITE_HEADER_IPV4_IPV6:
        if (detect_ipv4) begin
          if (tx_header_ipv4_index_reg == 0) begin
            state_we  = 'b1;
            state_new = STATE_TIMESTAMP;
          end
        end else if (detect_ipv6) begin
          if (tx_header_ipv6_index_reg == 0) begin
            state_we  = 'b1;
            state_new = STATE_TIMESTAMP;
          end
        end else begin
          set_error_state( ERROR_CAUSE_IPV_CONFUSED );
        end
      STATE_TIMESTAMP:
        begin
          state_we  = 'b1;
          state_new = STATE_TIMESTAMP_WAIT;
        end
      STATE_TIMESTAMP_WAIT:
        if (i_timestamp_busy == 'b0) begin
          if (nts_kiss_of_death_reg) begin
            state_we  = 'b1;
            state_new = STATE_TX_UPDATE_LENGTH; //Kiss-o'-Death
          end else begin
            state_we  = 'b1;
            state_new = STATE_UNIQUE_IDENTIFIER_COPY_0;
          end
        end
      STATE_UNIQUE_IDENTIFIER_COPY_0:
        begin
          state_we  = 'b1;
          state_new = STATE_UNIQUE_IDENTIFIER_COPY_1;
        end
      STATE_UNIQUE_IDENTIFIER_COPY_1:
        if (copy_done) begin
          state_we  = 'b1;
          state_new = STATE_RETRIVE_CURRENT_KEY_0;
        end
      STATE_RETRIVE_CURRENT_KEY_0:
        begin
          state_we  = 'b1;
          state_new = STATE_RETRIVE_CURRENT_KEY_1;
        end
      STATE_RETRIVE_CURRENT_KEY_1:
        if (i_keymem_ready && keymem_get_current_key_reg == 'b0 ) begin
          if (i_keymem_key_valid == 'b0) begin
            set_error_state ( ERROR_CAUSE_KEY_CURRENT_FAIL );
          end else if (keymem_key_word_reg == 'b111) begin
            state_we  = 'b1;
            state_new = STATE_RESET_EXTRA_COOKIES;
          end
        end
      STATE_RESET_EXTRA_COOKIES:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_SUCCESS) begin
          state_we  = 'b1;
          state_new = STATE_ADDITIONAL_COOKIES_CTRL;
        end
      STATE_ADDITIONAL_COOKIES_CTRL:
        if (cookies_count_reg < cookies_to_emit) begin // for(i=0; i < nts_valid_placeholders+1; i++) {
                                                       //   generateCookie();
                                                       //   storeCookie();
                                                       // }
          state_we  = 'b1;
          state_new = STATE_GENERATE_EXTRA_COOKIE;
        end else begin
          state_we  = 'b1;
          state_new = STATE_COPY_PACKET_TO_CRYPTO_AD;
        end
      STATE_GENERATE_EXTRA_COOKIE:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_SUCCESS) begin
          state_we  = 'b1;
          state_new = STATE_RECORD_EXTRA_COOKIE;
        end
      STATE_RECORD_EXTRA_COOKIE:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_SUCCESS) begin
          state_we  = 'b1;
          state_new = STATE_ADDITIONAL_COOKIES_CTRL; //jump back, while(
        end
      STATE_COPY_PACKET_TO_CRYPTO_AD:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_SUCCESS) begin
          state_we  = 'b1;
          state_new = STATE_TX_AUTH_PACKET;
        end
      STATE_TX_AUTH_PACKET:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_SUCCESS) begin
          state_we  = 'b1;
          state_new = STATE_TX_EMIT_TL_NL_CL;
        end
      STATE_TX_EMIT_TL_NL_CL:
        begin
          state_we  = 'b1;
          state_new = STATE_TX_EMIT_NONCE_CIPHERTEXT;
        end
      STATE_TX_EMIT_NONCE_CIPHERTEXT:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_SUCCESS) begin
          state_we  = 'b1;
          state_new = STATE_TX_UPDATE_LENGTH;
        end
      STATE_TX_UPDATE_LENGTH:
        begin
          state_we  = 'b1;
          state_new = STATE_TX_WRITE_UDP_LENGTH;
        end
      STATE_TX_WRITE_UDP_LENGTH:
        begin
          state_we  = 'b1;
          state_new = STATE_UDP_CHECKSUM_RESET;
        end
      STATE_UDP_CHECKSUM_RESET:
        begin
          state_we  = 'b1;
          state_new = STATE_UDP_CHECKSUM_PS_SRCADDR;
        end
      STATE_UDP_CHECKSUM_PS_SRCADDR:
        begin
          state_we  = 'b1;
          state_new = STATE_UDP_CHECKSUM_PS_UDPLLEN;
        end
      STATE_UDP_CHECKSUM_PS_UDPLLEN:
        if (i_tx_sum_done) begin
          state_we  = 'b1;
          state_new = STATE_UDP_CHECKSUM_DATAGRAM;
        end
      STATE_UDP_CHECKSUM_DATAGRAM:
        if (i_tx_sum_done) begin
          state_we  = 'b1;
          state_new = STATE_UDP_CHECKSUM_WAIT;
        end
      STATE_UDP_CHECKSUM_WAIT:
        if (i_tx_sum_done) begin
          state_we  = 'b1;
          state_new = STATE_WRITE_NEW_UDP_CSUM;
        end
      STATE_WRITE_NEW_UDP_CSUM:
        begin
          state_we  = 'b1;
          state_new = STATE_WRITE_NEW_UDP_CSUM_DELAY;
        end
      STATE_WRITE_NEW_UDP_CSUM_DELAY:
        //TXBUF memory controller require wait cycles delay
        // between different unaligned burst writes.
        if (i_tx_busy == 'b0) begin
          state_we  = 'b1;
          state_new = STATE_WRITE_NEW_IP_HEADER_0;
        end
      STATE_WRITE_NEW_IP_HEADER_0:
        begin
          state_we  = 'b1;
          state_new = STATE_WRITE_NEW_IP_HEADER_1;
        end
      STATE_WRITE_NEW_IP_HEADER_1:
        begin
          state_we  = 'b1;
          state_new = STATE_WRITE_NEW_IP_HEADR_DELAY;
        end
      STATE_WRITE_NEW_IP_HEADR_DELAY:
        //TXBUF memory controller require wait cycles delay
        //between different unaligned burst writes.
        if (i_tx_busy == 'b0) begin
          state_we  = 'b1;
          state_new = STATE_TRANSFER_PACKET;
        end
      STATE_TRANSFER_PACKET:
        begin
          state_we  = 'b1;
          state_new = STATE_IDLE;
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
  // Additional Cookie Generation
  //----------------------------------------------------------------

  always @*
  begin
    cookies_count_we = 0;
    cookies_count_new = 0;

    case (state_reg)
      STATE_RESET_EXTRA_COOKIES:
        begin
          cookies_count_we = 1;
          cookies_count_new = 0;
        end
      STATE_ADDITIONAL_COOKIES_CTRL:
        if (cookies_count_reg < cookies_to_emit) begin
          cookies_count_we = 1;
          cookies_count_new = cookies_count_reg + 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // IP Decode
  //----------------------------------------------------------------

  always @*
  begin
    ipdecode_ethernet_mac_dst_we   = 'b0;
    ipdecode_ethernet_mac_dst_new  = 'b0;
    ipdecode_ethernet_mac_src_we   = 'b0;
    ipdecode_ethernet_mac_src_new  = 'b0;
    ipdecode_ethernet_protocol_we  = 'b0;
    ipdecode_ethernet_protocol_new = 'b0;

    ipdecode_ip_version_we         = 'b0;
    ipdecode_ip_version_new        = 'b0;

    ipdecode_ip4_ihl_we            = 'b0;
    ipdecode_ip4_ihl_new           = 'b0;
    ipdecode_ip4_ip_dst_we         = 'b0;
    ipdecode_ip4_ip_dst_new        = 'b0;
    ipdecode_ip4_ip_src_we         = 'b0;
    ipdecode_ip4_ip_src_new        = 'b0;

    ipdecode_ip6_ip_dst_we         = 'b0;
    ipdecode_ip6_ip_dst_new        = 'b0;
    ipdecode_ip6_ip_src_we         = 'b0;
    ipdecode_ip6_ip_src_new        = 'b0;

    ipdecode_udp_length_we         = 'b0;
    ipdecode_udp_length_new        = 'b0;
    ipdecode_udp_port_dst_we       = 'b0;
    ipdecode_udp_port_dst_new      = 'b0;
    ipdecode_udp_port_src_we       = 'b0;
    ipdecode_udp_port_src_new      = 'b0;

    if (i_clear) begin
      ipdecode_ethernet_protocol_we  = 'b1;
      ipdecode_ip_version_we         = 'b1;
      ipdecode_ip4_ihl_we            = 'b1;
      ipdecode_udp_length_we         = 'b1;

    end else if (i_process_initial) begin
      if (state_reg == STATE_IDLE) begin
        ipdecode_ethernet_mac_dst_we   = 'b1;
        ipdecode_ethernet_mac_dst_new  = i_data[63:16];
        ipdecode_ethernet_mac_src_we   = 'b1;
        ipdecode_ethernet_mac_src_new  = { i_data[15:0], 32'h0 };

      end else if (word_counter_reg == 0) begin
        ipdecode_ethernet_mac_src_we   = 'b1;
        ipdecode_ethernet_mac_src_new  = { ipdecode_ethernet_mac_src_reg[47:32], i_data[63:32] };
        ipdecode_ethernet_protocol_we  = 'b1;
        ipdecode_ethernet_protocol_new = i_data[31:16];
        ipdecode_ip_version_we         = 'b1;
        ipdecode_ip_version_new        = i_data[15:12];
        ipdecode_ip4_ihl_we            = 'b1;
        ipdecode_ip4_ihl_new           = i_data[11:8];

      end else if (detect_ipv4 && ipdecode_ip4_ihl_reg == 5) begin
        case (word_counter_reg)
          2: begin
               ipdecode_ip4_ip_src_we  = 'b1;
               ipdecode_ip4_ip_src_new = i_data[47:16];
               ipdecode_ip4_ip_dst_we  = 'b1;
               ipdecode_ip4_ip_dst_new = { i_data[15:0], 16'h0000 };
             end
          3: begin
               ipdecode_ip4_ip_dst_we    = 'b1;
               ipdecode_ip4_ip_dst_new   = { ipdecode_ip4_ip_dst_reg[31:16], i_data[63:48] };
               ipdecode_udp_port_src_we  = 'b1;
               ipdecode_udp_port_src_new = i_data[47:32];
               ipdecode_udp_port_dst_we  = 'b1;
               ipdecode_udp_port_dst_new = i_data[31:16];
               ipdecode_udp_length_we    = 'b1;
               ipdecode_udp_length_new   = i_data[15:0];
             end
          default: ;
        endcase
      end else if (detect_ipv6) begin
        case (word_counter_reg)
          1: begin
               ipdecode_ip6_ip_src_we  = 'b1;
               ipdecode_ip6_ip_src_new = { i_data[15:0], 112'h0 };
             end
          2: begin
               ipdecode_ip6_ip_src_we  = 'b1;
               ipdecode_ip6_ip_src_new = { ipdecode_ip6_ip_src_reg[127:112], i_data, 48'h0 };
             end
          3: begin
               ipdecode_ip6_ip_dst_we  = 'b1;
               ipdecode_ip6_ip_dst_new = { i_data[15:0], 112'h0 };
               ipdecode_ip6_ip_src_we  = 'b1;
               ipdecode_ip6_ip_src_new = { ipdecode_ip6_ip_src_reg[127:48], i_data[63:16] };
             end
          4: begin
               ipdecode_ip6_ip_dst_we  = 'b1;
               ipdecode_ip6_ip_dst_new = { ipdecode_ip6_ip_dst_reg[127:112], i_data, 48'h0000 };
             end
          5: begin
               ipdecode_ip6_ip_dst_we  = 'b1;
               ipdecode_ip6_ip_dst_new = { ipdecode_ip6_ip_dst_reg[127:48], i_data[63:16] };
               ipdecode_udp_port_src_we  = 'b1;
               ipdecode_udp_port_src_new = i_data[15:0];
             end
          6: begin
               ipdecode_udp_port_dst_we  = 'b1;
               ipdecode_udp_port_dst_new = i_data[63:48];
               ipdecode_udp_length_we    = 'b1;
               ipdecode_udp_length_new   = i_data[47:32];
             end
          default: ;
        endcase
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
        end else if (word_counter_reg == 9) begin
          timestamp_origin_timestamp_we  = 1;
          timestamp_origin_timestamp_new = { i_data[47:0], 16'h0 };
        end else if (word_counter_reg == 10) begin
          timestamp_origin_timestamp_we  = 1;
          timestamp_origin_timestamp_new = { timestamp_origin_timestamp_reg[63:16], i_data[63:48] };
        end
      end if (detect_ipv6) begin
        if (word_counter_reg == 6) begin
          timestamp_version_number_we  = 1;
          timestamp_version_number_new = i_data[13:11];
        end else if (word_counter_reg == 11) begin
          timestamp_origin_timestamp_we  = 1;
          timestamp_origin_timestamp_new = { i_data[15:0], 48'h0 };
        end else if (word_counter_reg == 12) begin
          timestamp_origin_timestamp_we  = 1;
          timestamp_origin_timestamp_new = { timestamp_origin_timestamp_reg[63:48], i_data[63:16] };
        end
      end
    end
  end

  //----------------------------------------------------------------
  // TX IP, UDP control
  //----------------------------------------------------------------

  always @*
  begin : tx_ip_udp
    tx_ipv4_totlen_we = 0;
    tx_ipv4_totlen_new = 0;
    tx_udp_length_we = 0;
    tx_udp_length_new = 0;
    tx_udp_checksum_we = 0;
    tx_udp_checksum_new = 0;

    case (state_reg)
      STATE_IDLE:
        begin
          tx_ipv4_totlen_we = 1;  //zeroize
          tx_udp_length_we  = 1;  //zeroize
          tx_udp_checksum_we = 1; //zeroise
        end
      STATE_TX_UPDATE_LENGTH:
        begin
          tx_udp_length_we = 1;
          tx_udp_length_new [15:ADDR_WIDTH+3] = 0;
          tx_udp_length_new[ADDR_WIDTH+3-1:0] = copy_tx_addr_reg;
          if (detect_ipv4) begin
            tx_ipv4_totlen_we = 1;
            tx_ipv4_totlen_new [15:ADDR_WIDTH+3] = 0;
            tx_ipv4_totlen_new[ADDR_WIDTH+3-1:0] = copy_tx_addr_reg;
            tx_ipv4_totlen_new = tx_ipv4_totlen_new - HEADER_LENGTH_ETHERNET;
            tx_udp_length_new  = tx_udp_length_new - HEADER_LENGTH_ETHERNET - HEADER_LENGTH_IPV4;
          end else if (detect_ipv6) begin
            tx_udp_length_new = tx_udp_length_new - HEADER_LENGTH_ETHERNET - HEADER_LENGTH_IPV6;
          end
        end
      STATE_UDP_CHECKSUM_WAIT:
        if (i_tx_sum_done) begin
          tx_udp_checksum_we = 1;
          tx_udp_checksum_new = ~ i_tx_sum;
        end
      default: ;
    endcase
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
  // Statistics signals
  //----------------------------------------------------------------

  always @*
  begin : statistics
    statistics_nts_bad_auth_new   = 0;
    statistics_nts_bad_cookie_new = 0;
    statistics_nts_bad_keyid_new  = 0;
    statistics_nts_processed_new  = 0;

    case (state_reg)
      STATE_VERIFY_KEY_FROM_COOKIE2:
        if (i_keymem_ready && keymem_get_key_with_id_reg == 'b0 ) begin
          if (i_keymem_key_valid == 'b0) begin
            statistics_nts_bad_keyid_new = 1;
          end
        end
      STATE_RX_AUTH_COOKIE:
        if (crypto_fsm_reg == CRYPTO_FSM_DONE_FAILURE)
          statistics_nts_bad_cookie_new = 1;
      STATE_RX_AUTH_PACKET:
        begin
           if (crypto_fsm_reg == CRYPTO_FSM_DONE_SUCCESS)
             statistics_nts_processed_new = 1;
           if (crypto_fsm_reg == CRYPTO_FSM_DONE_FAILURE)
             statistics_nts_bad_auth_new = 1;
        end
      default: ;
    endcase
  end

endmodule
