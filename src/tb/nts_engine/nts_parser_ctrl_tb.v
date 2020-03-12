//
// Copyright (c) 2016-2020, The Swedish Post and Telecom Authority (PTS)
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

module nts_parser_ctrl_tb #( parameter integer verbose_output = 'h0);

  //----------------------------------------------------------------
  // Test bench constants
  //----------------------------------------------------------------

  localparam ACCESS_PORT_WIDTH = 64;
  localparam ADDR_WIDTH = 7;

  localparam integer ETHIPV4_NTS_TESTPACKETS_BITS=5488;
  localparam integer ETHIPV6_NTS_TESTPACKETS_BITS=5648;

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_request1 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0c4ab40004011, 64'h759f7f0000017f00, 64'h0001ccc0101e028c, 64'h00a0230000200000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000eb3f7b35711a, 64'h50d601040024f7d4, 64'h2b2df5367ab1e4ba, 64'h70b9f848cec24727, 64'hb8da97007037b202, 64'h81f1dd7db8730204, 64'h00682b30980579b0, 64'h9bd394da6aa4b0cd, 64'h4989c356c64cb031, 64'h64c0c23fa1d61579, 64'hc7dbb78496bc1f95, 64'h27189fd0b4f5ada4, 64'h4ecf5052dcc33bab, 64'h2a90ca4c5011f2e6, 64'he64b9d6dc9dc7b5e, 64'h43011d5e3846cf4e, 64'h94ca4843e6b473eb, 64'h8adb80fc5c8366bd, 64'hfe8b69b8b5bb0304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000404, 64'h002800100010adf1, 64'h62d91c6b9894501d, 64'h4b102ce39fbc2537, 64'hd84ea25db8498682, 48'h10558dfe3707 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_request2 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0131540004011, 64'h27367f0000017f00, 64'h0001ebf2101e028c, 64'h00a0230000200000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h000009d5cdfe2669, 64'hecde010400243655, 64'h6f163ebfae3276b5, 64'haff192a6028098fe, 64'hb8983255de2cdfda, 64'ha57de4d567640204, 64'h00682b3076b5e7b6, 64'h048efa30d87888d2, 64'h709614c3cda4c841, 64'h48ce1d9ecfaf395d, 64'h7625d735009621a7, 64'h8c7a5430ca40b636, 64'haaf6fcfe8815437f, 64'hb00761607149e425, 64'h6b10b925ab96e59b, 64'hef9eccf720386318, 64'h96e02a0ba2479796, 64'hbedc0bcb1673017f, 64'hd76d0d9b05c40304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000404, 64'h0028001000109c20, 64'ha5628e63642e446f, 64'hb15ae6459ee56f39, 64'ha9cdc5d14a8506b9, 48'h1d90d7056363 };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_request1 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001c528, 64'h101e028c029f2300, 64'h0020000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h000000000000d28a, 64'h27e711a7c03d0104, 64'h002481c0511c3e5e, 64'heb916a896c27b3b6, 64'hb48178eb79d3611a, 64'hb4b009c034bb89dc, 64'h1311020400682b30, 64'h934e47ee4ef90bcd, 64'h2db5548f21b0ca97, 64'hec8115349f734c47, 64'h9256e70e1e7e9e9a, 64'h241dcf30448b2ec2, 64'h33d1393f5f256526, 64'hd61d5e790aeeeae3, 64'h73ca8cc2354afa5d, 64'h2a0f2e4b3eada37f, 64'hb2351a6e3c27fa6d, 64'he917584462e3e6e7, 64'hf6912b95cfcc63ee, 64'h9eae030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000040400280010, 64'h0010bcde5b727894, 64'hd1474b7ebb548ade, 64'hb20ce193a04aef41, 64'h91a4c7866b201516, 16'h6eaf };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_request2 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001a481, 64'h101e028c029f2300, 64'h0020000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000009006, 64'h7ae76b0e7c8f0104, 64'h002442c6f064b709, 64'h5020fe86a9a3ee40, 64'h24873e09427a8bda, 64'h42913ac7a4210292, 64'h5605020400682b30, 64'hd49a5da26e878c97, 64'h95a0e8d0be12c940, 64'h8d3335fe04d25f97, 64'h615b4b9955786ce6, 64'h8c20a76268775cc5, 64'h64444dfa8b32b61b, 64'h6902f7bc1345b6e1, 64'h55d30a580e7db691, 64'he627d22e0b0a768b, 64'h3ae3c420e8fe60bb, 64'hcd44679ddb4c66ca, 64'h192adbb6440f0f28, 64'h6ebd030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000040400280010, 64'h001077615f9af204, 64'h4b9b0bdc77ea2105, 64'h1d0b8d0db8249882, 64'h3565bbd1515ff270, 16'h1883 };


  localparam[31:0] NTS_TEST_REQUEST_MASTER_KEY_ID_1=32'h30a8dce1;
  localparam[255:0] NTS_TEST_REQUEST_MASTER_KEY_1=256'h6d1e7f51_f64876ba_68d4669e_649ad613_402bf7bb_5cf275a9_83a28dab_5e416314;
  localparam[255:0] NTS_TEST_REQUEST_C2S_KEY_1=256'hf6467017_5420ab7e_2952fc90_fff2649e_e9ae6707_05d32341_94e72f48_6618a5b5;
  localparam[255:0] NTS_TEST_REQUEST_S2C_KEY_1=256'hfa8ac687_49e3d765_618b2e63_496a5b6f_20baf052_148863bb_49555ac0_88fc5c44;
  localparam[1839:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_1=1840'h001c7300_00995254_00cdcd23_08004500_00d80001_00004011_bc3f4d48_e37ec23a_cad31267_101b00c4_3a272300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00002d88_68987dd0_23a60104_0024d406_12b0c40f_353d6afc_d5709668_cd4ebceb_cd8ab0aa_4fd63533_3e8491dc_9f0d0204_006830a8_dce151bd_4e5aa6e3_e577ab41_30e77bc7_cd5ab785_9283e20b_49d8f6bb_89a5b313_4cc92a3d_5eef1f45_3930d7af_f838eec7_99876905_a470e88b_1c57a85a_93fab799_a47c1b7c_8706604f_de780bf9_84394999_d7d59abc_5468cfec_5b261efe_d850618e_91c5;
  localparam[1999:0] NTS_TEST_REQUEST_WITH_KEY_IPV6_1=2000'h001c7300_00995254_00cdcd23_86dd6000_000000c4_11402a01_03f00001_00085063_d01c72c6_ab922a01_03f70002_00520000_00000000_00111267_101b00c4_5ccc2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00002d88_68987dd0_23a60104_0024d406_12b0c40f_353d6afc_d5709668_cd4ebceb_cd8ab0aa_4fd63533_3e8491dc_9f0d0204_006830a8_dce151bd_4e5aa6e3_e577ab41_30e77bc7_cd5ab785_9283e20b_49d8f6bb_89a5b313_4cc92a3d_5eef1f45_3930d7af_f838eec7_99876905_a470e88b_1c57a85a_93fab799_a47c1b7c_8706604f_de780bf9_84394999_d7d59abc_5468cfec_5b261efe_d850618e_91c5;

  localparam[31:0] NTS_TEST_REQUEST_MASTER_KEY_ID_2=32'h13fe78e9;
  localparam[255:0] NTS_TEST_REQUEST_MASTER_KEY_2=256'hfeb10c69_9c6435be_5a9ee521_e40e420c_f665d8f7_a969302a_63b9385d_353ae43e;
  localparam[255:0] NTS_TEST_REQUEST_C2S_KEY_2=256'h8b61a5d5_b5d13237_2272b0e7_59938580_1cbbdfd6_d2f59fe4_8c11551d_8c724265;
  localparam[255:0] NTS_TEST_REQUEST_S2C_KEY_2=256'h55b99245_5a4c8089_e6a1281a_f8a2842d_443ea9ac_34646e84_dca14456_6f7b908c;
  localparam[2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;
  localparam[2319:0] NTS_TEST_REQUEST_WITH_KEY_IPV6_2=2320'h001c7300_00995254_00cdcd23_86dd6000_000000ec_11402a01_03f00001_00085063_d01c72c6_ab922a01_03f70002_00520000_00000000_00111267_101b00ec_af002300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;

  //----------------------------------------------------------------
  // Test bench variables, wires
  //----------------------------------------------------------------

  reg                          i_areset; // async reset
  reg                          i_clk;

  wire                         o_busy;

  reg                          i_clear;
  reg                          i_process_initial;
  reg                    [3:0] i_last_word_data_valid;
  reg                   [63:0] i_data;
  /* verilator lint_off UNUSED */
  wire                  [31:0] o_api_read_data;
  /* verilator lint_on UNUSED */

  reg                          i_tx_empty;
  reg                          i_tx_full;
  wire                         o_tx_clear;
  wire                         o_tx_w_en;
  wire                  [63:0] o_tx_w_data;
  wire                         o_tx_ipv4_done;
  wire                         o_tx_ipv6_done;

  /* verilator lint_off UNUSED */
  wire                   [9:0] o_tx_addr;
  wire                         o_tx_addr_internal;
  wire                         o_tx_sum_reset;
  wire                  [15:0] o_tx_sum_reset_value;
  wire                         o_tx_sum_en;
  wire                   [9:0] o_tx_sum_bytes;
  wire                         o_tx_update_length;
  /* verilator lint_on UNUSED */

  reg                          i_access_port_wait;
  wire      [ADDR_WIDTH+3-1:0] o_access_port_addr;
  /* verilator lint_off UNUSED */
  wire                  [15:0] o_access_port_burstsize;
  /* verilator lint_on UNUSED */
  wire                   [2:0] o_access_port_wordsize;
  wire                         o_access_port_rd_en;
  reg                          i_access_port_rd_dv;
  reg  [ACCESS_PORT_WIDTH-1:0] i_access_port_rd_data;

  reg                          i_timestamp_busy;
  /* verilator lint_off UNUSED */
  wire                         o_timestamp_kiss_of_death;
  /* verilator lint_on UNUSED */
  wire                         o_timestamp_record_receive_timestamp;
  wire                         o_timestamp_transmit; //parser signal packet transmit OK
  wire                [63 : 0] o_timestamp_origin_timestamp;
  wire                [ 2 : 0] o_timestamp_version_number;
  wire                [ 7 : 0] o_timestamp_poll;

  /* verilator lint_off UNUSED */
  wire                        o_keymem_get_current_key;
  /* verilator lint_on UNUSED */
  wire                  [2:0] o_keymem_key_word;
  wire                        o_keymem_get_key_with_id;
  wire                 [31:0] o_keymem_server_id;
  reg                         i_keymem_key_valid;
  reg                         i_keymem_ready;

  wire                        i_crypto_busy;
  reg                         i_crypto_verify_tag_ok;
  wire                        o_crypto_rx_op_copy_ad;
  wire                        o_crypto_rx_op_copy_nonce;
  wire                        o_crypto_rx_op_copy_pc;
  wire                        o_crypto_rx_op_copy_tag;
  wire     [ADDR_WIDTH+3-1:0] o_crypto_rx_addr;
  wire                  [9:0] o_crypto_rx_bytes;
  wire                        o_crypto_tx_op_copy_ad;
  wire                        o_crypto_tx_op_store_nonce_tag;
  wire                        o_crypto_tx_op_store_cookie;
  /* verilator lint_off UNUSED */
  wire                        o_crypto_sample_key;
  wire                        o_crypto_tx_op_store_cookiebuf;
  wire                        o_crypto_op_cookiebuf_append;
  wire                 [63:0] o_crypto_cookieprefix;
  wire                        o_crypto_op_cookiebuf_reset;
  /* verilator lint_on UNUSED */
  wire     [ADDR_WIDTH+3-1:0] o_crypto_tx_addr;
  wire                  [9:0] o_crypto_tx_bytes;
  wire                        o_crypto_op_cookie_verify;
  wire                        o_crypto_op_cookie_loadkeys;
  wire                        o_crypto_op_cookie_rencrypt;
  wire                        o_crypto_op_c2s_verify_auth;
  wire                        o_crypto_op_s2c_generate_auth;

  wire                        o_muxctrl_timestamp_ipv4;
  wire                        o_muxctrl_timestamp_ipv6;

  wire                        o_muxctrl_crypto; //Crypto is in charge of RX, TX

  /* verilator lint_off UNUSED */
  wire                        o_statistics_nts_processed;
  wire                        o_statistics_nts_bad_cookie;
  wire                        o_statistics_nts_bad_auth;
  wire                        o_statistics_nts_bad_keyid;
  /* verilator lint_on UNUSED */

  wire                        o_detect_unique_identifier;
  wire                        o_detect_nts_cookie;
  wire                        o_detect_nts_cookie_placeholder;
  wire                        o_detect_nts_authenticator;

//reg                 [3 : 0] detect_bits;

  reg                         keymem_state;

  reg                  [63:0] rx_buf [0:99];

  //----------------------------------------------------------------
  // Test bench macros
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  //----------------------------------------------------------------
  // Test bench tasks
  //----------------------------------------------------------------

  task send_packet (
    input [65535:0] source,
    input    [31:0] length,
    output    [3:0] detect_bits__
  );
    integer i;
    integer packet_ptr;
    integer source_ptr;
    reg [63:0] packet [0:99];
    begin
      if (verbose_output > 0) $display("%s:%0d Send packet!", `__FILE__, `__LINE__);
      `assert( (0==(length%8)) ); // byte aligned required
      for (i=0; i<100; i=i+1) begin
        packet[i] = 64'habad_1dea_f00d_cafe;
      end
      for (i=0; i<100; i=i+1) begin
        rx_buf[i] = 64'hXXXX_XXXX_XXXX_XXXX;
      end
      packet_ptr = 1;
      source_ptr = (length % 64);
      case (source_ptr)
         56: packet[0] = { 8'b0, source[55:0] };
         48: packet[0] = { 16'b0, source[47:0] };
         32: packet[0] = { 32'b0, source[31:0] };
         24: packet[0] = { 40'b0, source[23:0] };
         16: packet[0] = { 48'b0, source[15:0] };
          8: packet[0] = { 56'b0, source[7:0] };
          0: packet_ptr = 0;
        default:
          `assert(0)
      endcase
      if (verbose_output > 2) $display("%s:%0d length=%0d packet_ptr=%0d packet=%h", `__FILE__, `__LINE__, length, 0, packet[0]);
      for (i=0; i<length/64; i=i+1) begin
         packet[packet_ptr] = source[source_ptr+:64];
         if (verbose_output > 2) $display("%s:%0d length=%0d packet_ptr=%0d packet=%h", `__FILE__, `__LINE__, length, packet_ptr, packet[packet_ptr]);
         source_ptr = source_ptr + 64;
         packet_ptr = packet_ptr + 1;
      end

      #10
      case ((length/8) % 8)
        0: i_last_word_data_valid  = 8; //all bytes valid
        1: i_last_word_data_valid  = 1;
        2: i_last_word_data_valid  = 2;
        3: i_last_word_data_valid  = 3;
        4: i_last_word_data_valid  = 4;
        5: i_last_word_data_valid  = 5;
        6: i_last_word_data_valid  = 6;
        7: i_last_word_data_valid  = 7;
        default:
          begin
            $display("length:%0d", length);
            `assert(0);
          end
      endcase
      `assert(i_process_initial == 'b0);
      i_clear = 'b1;
      #10;
      i_clear = 'b0;

      #10;
      i_tx_empty = 0;
      #50;
      `assert(o_busy);
      i_tx_empty = 1;

      while(o_busy)
      begin
        #10;
      end

      source_ptr = 0;
      #10
      for (packet_ptr=packet_ptr-1; packet_ptr>=0; packet_ptr=packet_ptr-1) begin
        if (verbose_output >= 3) $display("%s:%0d packet_ptr[%0d]=%h", `__FILE__, `__LINE__, packet_ptr, packet[packet_ptr]);
        i_data[63:0] = packet[packet_ptr];
        rx_buf[source_ptr] = packet[packet_ptr];
        source_ptr = source_ptr + 1;
        #10 ;
        i_process_initial = 'b1; //1 cycle delayed
      end
      #10
      i_process_initial = 'b0; //1 cycle delayed

      `assert(o_busy);
      while(o_busy)
      begin
        detect_bits__ = { o_detect_unique_identifier, o_detect_nts_cookie, o_detect_nts_cookie_placeholder, o_detect_nts_authenticator};
        if (verbose_output >= 4) $display("%s:%0d detect_bits=%b (%h)", `__FILE__, `__LINE__, detect_bits__, detect_bits__);
        #10;
      end

    end
  endtask

  //----------------------------------------------------------------
  // Test bench Design Under Test (DUT) instantiation
  //----------------------------------------------------------------

  nts_parser_ctrl #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset), // async reset
    .i_clk(i_clk),

    .o_busy(o_busy),

    .i_clear(i_clear),
    .i_process_initial(i_process_initial),
    .i_last_word_data_valid(i_last_word_data_valid),
    .i_data(i_data),

    .i_api_address(8'h0),
    .i_api_cs(1'b0),
    .i_api_we(1'b0),
    .i_api_write_data(32'h0),
    .o_api_read_data(o_api_read_data),

    .i_tx_busy(1'h0),
    .o_tx_addr_internal(o_tx_addr_internal),
    .i_tx_empty(i_tx_empty),
    .i_tx_full(i_tx_full),
    .o_tx_clear(o_tx_clear),
    .o_tx_w_en(o_tx_w_en),
    .o_tx_w_data(o_tx_w_data),
    .o_tx_ipv4_done(o_tx_ipv4_done),
    .o_tx_ipv6_done(o_tx_ipv6_done),
    .o_tx_addr(o_tx_addr),
    .i_tx_sum(16'h0),
    .i_tx_sum_done(1'h0),
    .o_tx_sum_reset(o_tx_sum_reset),
    .o_tx_sum_reset_value(o_tx_sum_reset_value),
    .o_tx_sum_en(o_tx_sum_en),
    .o_tx_sum_bytes(o_tx_sum_bytes),
    .o_tx_update_length(o_tx_update_length),

    .i_access_port_wait(i_access_port_wait),
    .o_access_port_addr(o_access_port_addr),
    .o_access_port_burstsize(o_access_port_burstsize),
    .o_access_port_wordsize(o_access_port_wordsize),
    .o_access_port_rd_en(o_access_port_rd_en),
    .i_access_port_rd_dv(i_access_port_rd_dv),
    .i_access_port_rd_data(i_access_port_rd_data),

    .o_keymem_get_current_key(o_keymem_get_current_key),
    .i_keymem_key_id(0),
    .o_keymem_key_word(o_keymem_key_word),
    .o_keymem_get_key_with_id(o_keymem_get_key_with_id),
    .o_keymem_server_id(o_keymem_server_id),
    .i_keymem_key_valid(i_keymem_key_valid),
    .i_keymem_ready(i_keymem_ready),

    .i_timestamp_busy(i_timestamp_busy),
    .o_timestamp_kiss_of_death(o_timestamp_kiss_of_death),
    .o_timestamp_record_receive_timestamp(o_timestamp_record_receive_timestamp),
    .o_timestamp_transmit(o_timestamp_transmit), //parser signal packet transmit OK
    .o_timestamp_origin_timestamp(o_timestamp_origin_timestamp),
    .o_timestamp_version_number(o_timestamp_version_number),
    .o_timestamp_poll(o_timestamp_poll),

    .i_crypto_busy(i_crypto_busy),
    .o_crypto_sample_key(o_crypto_sample_key),
    .i_crypto_verify_tag_ok(i_crypto_verify_tag_ok),
    .o_crypto_rx_op_copy_ad(o_crypto_rx_op_copy_ad),
    .o_crypto_rx_op_copy_nonce(o_crypto_rx_op_copy_nonce),
    .o_crypto_rx_op_copy_pc(o_crypto_rx_op_copy_pc),
    .o_crypto_rx_op_copy_tag(o_crypto_rx_op_copy_tag),
    .o_crypto_rx_addr(o_crypto_rx_addr),
    .o_crypto_rx_bytes(o_crypto_rx_bytes),
    .o_crypto_tx_op_copy_ad(o_crypto_tx_op_copy_ad),
    .o_crypto_tx_op_store_nonce_tag(o_crypto_tx_op_store_nonce_tag),
    .o_crypto_tx_op_store_cookie(o_crypto_tx_op_store_cookie),
    .o_crypto_tx_addr(o_crypto_tx_addr),
    .o_crypto_tx_bytes(o_crypto_tx_bytes),
    .o_crypto_op_cookie_verify(o_crypto_op_cookie_verify),
    .o_crypto_op_cookie_loadkeys(o_crypto_op_cookie_loadkeys),
    .o_crypto_op_cookie_rencrypt(o_crypto_op_cookie_rencrypt),
    .o_crypto_op_c2s_verify_auth(o_crypto_op_c2s_verify_auth),
    .o_crypto_op_s2c_generate_auth(o_crypto_op_s2c_generate_auth),

    .o_muxctrl_timestamp_ipv4(o_muxctrl_timestamp_ipv4),
    .o_muxctrl_timestamp_ipv6(o_muxctrl_timestamp_ipv6),

    .o_muxctrl_crypto(o_muxctrl_crypto),

    .o_crypto_cookieprefix(o_crypto_cookieprefix),
    .o_crypto_tx_op_store_cookiebuf(o_crypto_tx_op_store_cookiebuf),
    .o_crypto_op_cookiebuf_append(o_crypto_op_cookiebuf_append),
    .o_crypto_op_cookiebuf_reset(o_crypto_op_cookiebuf_reset),
    .o_statistics_nts_processed(o_statistics_nts_processed),
    .o_statistics_nts_bad_cookie(o_statistics_nts_bad_cookie),
    .o_statistics_nts_bad_auth(o_statistics_nts_bad_auth),
    .o_statistics_nts_bad_keyid(o_statistics_nts_bad_keyid),

    .o_detect_unique_identifier(o_detect_unique_identifier),
    .o_detect_nts_cookie(o_detect_nts_cookie),
    .o_detect_nts_cookie_placeholder(o_detect_nts_cookie_placeholder),
    .o_detect_nts_authenticator(o_detect_nts_authenticator)
  );

  //----------------------------------------------------------------
  // Test bench code
  //----------------------------------------------------------------

  task test_ipv4_checksum;
  begin : test_ipv4_checksum
    /* verilator lint_off UNUSED */
    reg      [15:0] actual;
    reg      [15:0] expected;
    reg [5*4*8-1:0] header;
    header = 160'h45_00_03_d8_00_00_40_00_ff_11_00_00_c0_a8_28_15_c0_a8_28_01;
    actual = dut.ipv4_csum( { header[159-:10*8], header[0+:64] } );
    expected = 'ha6ad;
    $display("%s:%0d test_ipv4_checksum expected: %h actual: %h", `__FILE__, `__LINE__, expected, actual);
    `assert( actual == expected );
    /* verilator lint_on UNUSED */
  end
  endtask

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk                       = 0;
    i_areset                    = 1;

    i_clear                     = 0;
    i_process_initial           = 0;
    i_last_word_data_valid      = 0;
    i_data                      = 0;

    i_tx_empty                  = 1;
    i_tx_full                   = 0;

    i_access_port_wait          = 0;
    i_access_port_rd_dv         = 0;
    i_access_port_rd_data       = 0;

    i_timestamp_busy            = 0;

    #10
    i_areset = 0;

    $display("%s:%0d Warning: a lot of tests here are commented out due to not being updated/maintained", `__FILE__, `__LINE__);
/*
    //----------------------------------------------------------------
    // IPv4 Requests
    //----------------------------------------------------------------

    #20
    $display("%s:%0d Send NTS IPv4 requests", `__FILE__, `__LINE__);

    #20
    $display("%s:%0d PARSE: nts_packet_ipv4_request1", `__FILE__, `__LINE__);
    send_packet({60048'b0, nts_packet_ipv4_request1}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    $display("%s:%0d PARSE: nts_packet_ipv4_request2", `__FILE__, `__LINE__);
    send_packet({60048'b0, nts_packet_ipv4_request2}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    $display("%s:%0d PARSE: NTS_TEST_REQUEST_WITH_KEY_IPV4_1", `__FILE__, `__LINE__);
    send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, detect_bits);
    `assert(detect_bits == 'b1100);

    $display("%s:%0d PARSE: NTS_TEST_REQUEST_WITH_KEY_IPV4_2", `__FILE__, `__LINE__);
    send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, detect_bits);
    `assert(detect_bits == 'b1101);

    //$display("%s:%0d detect_bits=%b", `__FILE__, `__LINE__, detect_bits);

    //----------------------------------------------------------------
    // IPv6 Request
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv6 requests", `__FILE__, `__LINE__);

    $display("%s:%0d PARSE: nts_packet_ipv6_request1", `__FILE__, `__LINE__);
    send_packet({59888'b0, nts_packet_ipv6_request1}, ETHIPV6_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    $display("%s:%0d PARSE: nts_packet_ipv6_request2", `__FILE__, `__LINE__);
    send_packet({59888'b0, nts_packet_ipv6_request2}, ETHIPV6_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    $display("%s:%0d PARSE: NTS_TEST_REQUEST_WITH_KEY_IPV6_1", `__FILE__, `__LINE__);
    send_packet({63536'b0, NTS_TEST_REQUEST_WITH_KEY_IPV6_1}, 2000, detect_bits);
    `assert(detect_bits == 'b1100);

    $display("%s:%0d PARSE: NTS_TEST_REQUEST_WITH_KEY_IPV6_2", `__FILE__, `__LINE__);
    send_packet({63216'b0, NTS_TEST_REQUEST_WITH_KEY_IPV6_2}, 2320, detect_bits);
    `assert(detect_bits == 'b1101);
*/
    test_ipv4_checksum();
    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  //----------------------------------------------------------------
  // Testbench model: KeyMem
  //----------------------------------------------------------------

  always @(posedge i_clk, posedge i_areset)
  begin
    if (i_areset) begin
      keymem_state <= 0;
      i_keymem_ready <= 1;
      i_keymem_key_valid <= 0;
    end else begin
      i_keymem_key_valid <= 0;
      i_keymem_ready <= 1;
      if (keymem_state) begin
        keymem_state <= 0;
        i_keymem_ready <= 1;
        i_keymem_key_valid <= 1;
      end else if (o_keymem_get_key_with_id) begin
        keymem_state <= 1;
        i_keymem_ready <= 0;
        $display("%s:%0d KEYMEM[%h.%h]", `__FILE__, `__LINE__, o_keymem_server_id, o_keymem_key_word);
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: RX-Buff
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin
    if (verbose_output >= 4) $display("%s:%0d o_access_port_rd_en=%h", `__FILE__, `__LINE__, o_access_port_rd_en);
    if (i_areset) begin
      ;
    end else if (o_access_port_rd_en) begin : vars
      reg [ADDR_WIDTH-1:0] addr_hi;
      reg            [2:0] addr_lo;
      reg           [87:0] tmp;
      `assert(o_access_port_wordsize == 2);
      addr_hi = o_access_port_addr[ADDR_WIDTH+3-1:3];
      addr_lo = o_access_port_addr[2:0];
      tmp = { rx_buf[addr_hi], rx_buf[addr_hi+1][63:40] };
      case (addr_lo)
        0: i_access_port_rd_data = { 32'h0, tmp[87:56] };
        1: i_access_port_rd_data = { 32'h0, tmp[79:48] };
        2: i_access_port_rd_data = { 32'h0, tmp[71:40] };
        3: i_access_port_rd_data = { 32'h0, tmp[63:32] };
        4: i_access_port_rd_data = { 32'h0, tmp[55:24] };
        5: i_access_port_rd_data = { 32'h0, tmp[47:16] };
        6: i_access_port_rd_data = { 32'h0, tmp[39:8] };
        7: i_access_port_rd_data = { 32'h0, tmp[31:0] };
        default: begin `assert(0); end
      endcase
      i_access_port_rd_dv = 1;
      if (verbose_output >= 4) $display("%s:%0d i_access_port_rd_data=%h", `__FILE__, `__LINE__, i_access_port_rd_data);
    end else begin
      i_access_port_rd_data = 64'hXXX_XXXX_XXXX_XXXX;
      i_access_port_rd_dv = 0;
    end
  end

  //----------------------------------------------------------------
  // Testbench model: TX-Buff
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      ;
    end else begin
      if (o_tx_clear) begin
        $display("%s:%0d TX_CLEAR", `__FILE__, `__LINE__);
      end else if (o_tx_w_en) begin
        $display("%s:%0d TX_WRITE: %h", `__FILE__, `__LINE__, o_tx_w_data);
      end else if (o_tx_ipv4_done) begin
        $display("%s:%0d TX_TRANSMIT IPv4", `__FILE__, `__LINE__);
      end else if (o_tx_ipv6_done) begin
        $display("%s:%0d TX_TRANSMIT IPv6", `__FILE__, `__LINE__);
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: Timestamp
  //----------------------------------------------------------------

  always @*
  begin
    if (o_timestamp_transmit) begin
      $display("%s:%0d TIMESTAMP.Transmit. Origin: %h Version: %h Poll: %h", `__FILE__, `__LINE__, o_timestamp_origin_timestamp, o_timestamp_version_number, o_timestamp_poll);
      i_timestamp_busy = 1;
      #100;
      i_timestamp_busy = 0;
    end
  end

  always @*
  begin
    if (o_timestamp_record_receive_timestamp)
      $display("%s:%0d TIMESTAMP.Record_Recieve_TimeStamp", `__FILE__, `__LINE__);
  end


  always @*
  begin
    //if (verbose_output >= 1) $display("%s:%0d o_muxctrl_timestamp_ipv4=%h o_muxctrl_timestamp_ipv6=%h", `__FILE__, `__LINE__, o_muxctrl_timestamp_ipv4, o_muxctrl_timestamp_ipv6);
    $display("%s:%0d MUX: ipv4=%h ipv6=%h", `__FILE__, `__LINE__, o_muxctrl_timestamp_ipv4, o_muxctrl_timestamp_ipv6);
  end


  //----------------------------------------------------------------
  // Testbench model: Crypto Engine for verifying NTS auth
  //----------------------------------------------------------------

  localparam CRYPTO_STATE_IDLE = 0;
  localparam CRYPTO_STATE_DELAY = 1;

  localparam [10:0] CRYPTO_MAGIC_CONSTANT_SMALL_DELAY = 42;
  localparam [10:0] CRYPTO_MAGIC_CONSTANT_LONG_DELAY = 500;

  reg  [1:0] crypto_state;
  reg [10:0] crypto_delay;
  reg        crypto_verify_tag_ok_set;
  reg        crypto_verify_tag_ok_value;

  assign i_crypto_busy = crypto_state != CRYPTO_STATE_IDLE;

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_crypto_verify_tag_ok <= 0;
      crypto_state <= CRYPTO_STATE_DELAY;
      crypto_delay <= CRYPTO_MAGIC_CONSTANT_SMALL_DELAY;
      crypto_verify_tag_ok_set <= 0;
      crypto_verify_tag_ok_value <= 0;
    end else begin
      case (crypto_state)
        CRYPTO_STATE_IDLE:
          begin
            crypto_verify_tag_ok_set <= 0;
            crypto_verify_tag_ok_value <= 0;
            if (o_crypto_rx_op_copy_ad || o_crypto_rx_op_copy_nonce || o_crypto_rx_op_copy_pc || o_crypto_rx_op_copy_tag) begin
              $display("%s:%0d CRYPTO RX OP %b Addr: %h Bytes: %h", `__FILE__, `__LINE__,
                { o_crypto_rx_op_copy_ad, o_crypto_rx_op_copy_nonce, o_crypto_rx_op_copy_pc, o_crypto_rx_op_copy_tag },
                o_crypto_rx_addr, o_crypto_rx_bytes);
              `assert ( o_muxctrl_crypto );
              `assert ( o_crypto_rx_bytes != 0 );
              crypto_delay <= CRYPTO_MAGIC_CONSTANT_SMALL_DELAY + { 1'b0, o_crypto_rx_bytes };
              crypto_state <= CRYPTO_STATE_DELAY;
            end else if (o_crypto_tx_op_copy_ad || o_crypto_tx_op_store_nonce_tag || o_crypto_tx_op_store_cookie) begin
              $display("%s:%0d CRYPTO TX OP %b Addr: %h Bytes: %h", `__FILE__, `__LINE__,
                { o_crypto_tx_op_copy_ad, o_crypto_tx_op_store_nonce_tag, o_crypto_tx_op_store_cookie },
                o_crypto_tx_addr, o_crypto_tx_bytes );
              `assert ( o_muxctrl_crypto );
              `assert ( o_crypto_tx_bytes != 0 );
              crypto_delay <= CRYPTO_MAGIC_CONSTANT_SMALL_DELAY + { 1'b0, o_crypto_tx_bytes };
              crypto_state <= CRYPTO_STATE_DELAY;
            end else if ( o_crypto_op_cookie_verify ) begin
              i_crypto_verify_tag_ok <= 0;
              crypto_delay <= CRYPTO_MAGIC_CONSTANT_LONG_DELAY;
              crypto_state <= CRYPTO_STATE_DELAY;
              crypto_verify_tag_ok_set <= 1;
              crypto_verify_tag_ok_value <= 1;
            end else if ( o_crypto_op_cookie_loadkeys ) begin
              crypto_delay <= CRYPTO_MAGIC_CONSTANT_LONG_DELAY;
              crypto_state <= CRYPTO_STATE_DELAY;
            end else if ( o_crypto_op_cookie_rencrypt ) begin
              crypto_delay <= CRYPTO_MAGIC_CONSTANT_LONG_DELAY;
              crypto_state <= CRYPTO_STATE_DELAY;
            end else if ( o_crypto_op_c2s_verify_auth ) begin
              crypto_verify_tag_ok_set <= 1;
              crypto_verify_tag_ok_value <= 1;
              crypto_delay <= CRYPTO_MAGIC_CONSTANT_LONG_DELAY;
              crypto_state <= CRYPTO_STATE_DELAY;
            end else if ( o_crypto_op_s2c_generate_auth ) begin
              crypto_delay <= CRYPTO_MAGIC_CONSTANT_LONG_DELAY;
              crypto_state <= CRYPTO_STATE_DELAY;
            end
          end
         CRYPTO_STATE_DELAY:
           if (crypto_delay == 0) begin
             if (crypto_verify_tag_ok_set) begin
               i_crypto_verify_tag_ok <= crypto_verify_tag_ok_value;
             end
             crypto_state <= CRYPTO_STATE_IDLE;
           end else begin
             crypto_delay <= crypto_delay - 1;
           end
      endcase
    end
  end

  always @*
  begin
    if (dut.nts_valid_placeholders_reg > 0)
      $display( "%s:%0d placeholders: %h.", `__FILE__, `__LINE__, dut.nts_valid_placeholders_reg );
  end

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
