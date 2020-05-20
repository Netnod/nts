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

module nts_top_tb;
  localparam ADDR_WIDTH = 10;

  localparam DEBUG_CRYPTO_RX = 1;
  localparam DEBUG           = 3;
  localparam BENCHMARK       = 1;
  localparam ENGINES         = 1;

  localparam TEST_FUZZ_UI       = 0;
  localparam TEST_FUZZ_UI_START = 32;
  localparam TEST_FUZZ_UI_STOP  = 512;
  localparam TEST_FUZZ_UI_INC   = 4;

  localparam TEST_UI36 = 3;

  localparam TEST_NORMAL = 1;

  localparam [11:0] API_ADDR_ENGINE_BASE        = 12'h000;
  localparam [11:0] API_ADDR_ENGINE_NAME0       = API_ADDR_ENGINE_BASE;
  localparam [11:0] API_ADDR_ENGINE_NAME1       = API_ADDR_ENGINE_BASE + 1;
  localparam [11:0] API_ADDR_ENGINE_VERSION     = API_ADDR_ENGINE_BASE + 2;
  localparam [11:0] API_ADDR_ENGINE_CTRL        = API_ADDR_ENGINE_BASE + 8;

  localparam [11:0] API_ADDR_DEBUG_BASE           = 12'h180;
  localparam [11:0] API_ADDR_DEBUG_NTS_PROCESSED  = API_ADDR_DEBUG_BASE + 0;
  localparam [11:0] API_ADDR_DEBUG_NTS_BAD_COOKIE = API_ADDR_DEBUG_BASE + 2;
  localparam [11:0] API_ADDR_DEBUG_NTS_BAD_AUTH   = API_ADDR_DEBUG_BASE + 4;
  localparam [11:0] API_ADDR_DEBUG_NTS_BAD_KEYID  = API_ADDR_DEBUG_BASE + 6;
  localparam [11:0] API_ADDR_DEBUG_NAME           = API_ADDR_DEBUG_BASE + 8;
  localparam [11:0] API_ADDR_DEBUG_SYSTICK32      = API_ADDR_DEBUG_BASE + 9;
  localparam [11:0] API_ADDR_DEBUG_ERR_CRYPTO     = API_ADDR_DEBUG_BASE + 'h20;
  localparam [11:0] API_ADDR_DEBUG_ERR_TXBUF      = API_ADDR_DEBUG_BASE + 'h22;

  localparam [11:0] API_ADDR_CLOCK_BASE         = 12'h010;
  localparam [11:0] API_ADDR_CLOCK_NAME0        = API_ADDR_CLOCK_BASE + 0;
  localparam [11:0] API_ADDR_CLOCK_NAME1        = API_ADDR_CLOCK_BASE + 1;

  localparam [11:0] API_ADDR_KEYMEM_BASE        = 12'h080;
  localparam [11:0] API_ADDR_KEYMEM_NAME0       = API_ADDR_KEYMEM_BASE + 0;
  localparam [11:0] API_ADDR_KEYMEM_NAME1       = API_ADDR_KEYMEM_BASE + 1;
  localparam [11:0] API_ADDR_KEYMEM_ADDR_CTRL   = API_ADDR_KEYMEM_BASE + 12'h08;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_ID     = API_ADDR_KEYMEM_BASE + 12'h10;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_START  = API_ADDR_KEYMEM_BASE + 12'h40;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_END    = API_ADDR_KEYMEM_BASE + 12'h4f;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_ID     = API_ADDR_KEYMEM_BASE + 12'h12;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_START  = API_ADDR_KEYMEM_BASE + 12'h50;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_END    = API_ADDR_KEYMEM_BASE + 12'h5f;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_ID     = API_ADDR_KEYMEM_BASE + 12'h14;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_START  = API_ADDR_KEYMEM_BASE + 12'h60;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_END    = API_ADDR_KEYMEM_BASE + 12'h6f;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_ID     = API_ADDR_KEYMEM_BASE + 12'h16;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_START  = API_ADDR_KEYMEM_BASE + 12'h70;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_END    = API_ADDR_KEYMEM_BASE + 12'h7f;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_COUNTER_MSB  = API_ADDR_KEYMEM_BASE + 'h30;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_COUNTER_LSB  = API_ADDR_KEYMEM_BASE + 'h31;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_COUNTER_MSB  = API_ADDR_KEYMEM_BASE + 'h32;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_COUNTER_LSB  = API_ADDR_KEYMEM_BASE + 'h33;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_COUNTER_MSB  = API_ADDR_KEYMEM_BASE + 'h34;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_COUNTER_LSB  = API_ADDR_KEYMEM_BASE + 'h35;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_COUNTER_MSB  = API_ADDR_KEYMEM_BASE + 'h36;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_COUNTER_LSB  = API_ADDR_KEYMEM_BASE + 'h37;
  localparam [11:0] API_ADDR_KEYMEM_ERROR_COUNTER_MSB = API_ADDR_KEYMEM_BASE + 'h38;
  localparam [11:0] API_ADDR_KEYMEM_ERROR_COUNTER_LSB = API_ADDR_KEYMEM_BASE + 'h39;

  localparam [11:0] API_ADDR_NONCEGEN_BASE     = 12'h020;
  localparam [11:0] API_ADDR_NONCEGEN_CTRL     = API_ADDR_NONCEGEN_BASE + 'h08;
  localparam [11:0] API_ADDR_NONCEGEN_KEY0     = API_ADDR_NONCEGEN_BASE + 'h10;
  localparam [11:0] API_ADDR_NONCEGEN_KEY1     = API_ADDR_NONCEGEN_BASE + 'h11;
  localparam [11:0] API_ADDR_NONCEGEN_KEY2     = API_ADDR_NONCEGEN_BASE + 'h12;
  localparam [11:0] API_ADDR_NONCEGEN_KEY3     = API_ADDR_NONCEGEN_BASE + 'h13;
  localparam [11:0] API_ADDR_NONCEGEN_LABEL    = API_ADDR_NONCEGEN_BASE + 'h20;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT0 = API_ADDR_NONCEGEN_BASE + 'h40;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT1 = API_ADDR_NONCEGEN_BASE + 'h41;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT2 = API_ADDR_NONCEGEN_BASE + 'h42;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT3 = API_ADDR_NONCEGEN_BASE + 'h43;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT4 = API_ADDR_NONCEGEN_BASE + 'h44;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT5 = API_ADDR_NONCEGEN_BASE + 'h45;

  localparam [11:0] API_ADDR_PARSER_BASE         = 12'h200;
  localparam [11:0] API_ADDR_PARSER_NAME         = API_ADDR_PARSER_BASE +    0;
  localparam [11:0] API_ADDR_PARSER_VERSION      = API_ADDR_PARSER_BASE +    2;
  localparam [11:0] API_ADDR_PARSER_DUMMY        = API_ADDR_PARSER_BASE +    3;
  localparam [11:0] API_ADDR_PARSER_CTRL         = API_ADDR_PARSER_BASE +    4;
  localparam [11:0] API_ADDR_PARSER_STATE        = API_ADDR_PARSER_BASE + 'h10;
  localparam [11:0] API_ADDR_PARSER_STATE_CRYPTO = API_ADDR_PARSER_BASE + 'h12;
  localparam [11:0] API_ADDR_PARSER_ERROR_STATE  = API_ADDR_PARSER_BASE + 'h13;
  localparam [11:0] API_ADDR_PARSER_ERROR_COUNT  = API_ADDR_PARSER_BASE + 'h14;
  localparam [11:0] API_ADDR_PARSER_ERROR_CAUSE  = API_ADDR_PARSER_BASE + 'h15;
  localparam [11:0] API_ADDR_PARSER_ERROR_SIZE   = API_ADDR_PARSER_BASE + 'h16;
  localparam [11:0] API_ADDR_PARSER_MAC_CTRL     = API_ADDR_PARSER_BASE + 'h30;
  localparam [11:0] API_ADDR_PARSER_IPV4_CTRL    = API_ADDR_PARSER_BASE + 'h31;
  localparam [11:0] API_ADDR_PARSER_IPV6_CTRL    = API_ADDR_PARSER_BASE + 'h32;
  localparam [11:0] API_ADDR_PARSER_MAC_0        = API_ADDR_PARSER_BASE + 'h40;
  localparam [11:0] API_ADDR_PARSER_MAC_1        = API_ADDR_PARSER_BASE + 'h42;
  localparam [11:0] API_ADDR_PARSER_MAC_2        = API_ADDR_PARSER_BASE + 'h44;
  localparam [11:0] API_ADDR_PARSER_MAC_3        = API_ADDR_PARSER_BASE + 'h46;
  localparam [11:0] API_ADDR_PARSER_IPV4_0       = API_ADDR_PARSER_BASE + 'h50;
  localparam [11:0] API_ADDR_PARSER_IPV4_1       = API_ADDR_PARSER_BASE + 'h51;
  localparam [11:0] API_ADDR_PARSER_IPV4_2       = API_ADDR_PARSER_BASE + 'h52;
  localparam [11:0] API_ADDR_PARSER_IPV4_3       = API_ADDR_PARSER_BASE + 'h53;
  localparam [11:0] API_ADDR_PARSER_IPV4_4       = API_ADDR_PARSER_BASE + 'h54;
  localparam [11:0] API_ADDR_PARSER_IPV4_5       = API_ADDR_PARSER_BASE + 'h55;
  localparam [11:0] API_ADDR_PARSER_IPV4_6       = API_ADDR_PARSER_BASE + 'h56;
  localparam [11:0] API_ADDR_PARSER_IPV4_7       = API_ADDR_PARSER_BASE + 'h57;
  localparam [11:0] API_ADDR_PARSER_IPV6_0       = API_ADDR_PARSER_BASE + 'h60;
  localparam [11:0] API_ADDR_PARSER_IPV6_1       = API_ADDR_PARSER_BASE + 'h64;
  localparam [11:0] API_ADDR_PARSER_IPV6_2       = API_ADDR_PARSER_BASE + 'h68;
  localparam [11:0] API_ADDR_PARSER_IPV6_3       = API_ADDR_PARSER_BASE + 'h6C;
  localparam [11:0] API_ADDR_PARSER_IPV6_4       = API_ADDR_PARSER_BASE + 'h70;
  localparam [11:0] API_ADDR_PARSER_IPV6_5       = API_ADDR_PARSER_BASE + 'h74;
  localparam [11:0] API_ADDR_PARSER_IPV6_6       = API_ADDR_PARSER_BASE + 'h78;
  localparam [11:0] API_ADDR_PARSER_IPV6_7       = API_ADDR_PARSER_BASE + 'h7C;

  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_BASE          = 12'h300;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_NAME0         = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h00;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_NAME1         = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h01;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_VERSION       = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h02;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_SLOTS         = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h03;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_ACTIVE_SLOT   = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h10;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_LOAD          = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h11;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_BUSY          = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h12;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_MD5_SHA1      = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h13;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_KEYID         = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h20;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_COUNTER_MSB   = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h21;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_COUNTER_LSB   = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h22;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_KEY0          = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h23;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_KEY1          = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h24;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_KEY2          = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h25;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_KEY3          = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h26;
  localparam [11:0] API_ADDR_NTPAUTH_KEYMEM_KEY4          = API_ADDR_NTPAUTH_KEYMEM_BASE + 'h27;

  localparam [11:0] API_DISPATCHER_ADDR_NAME               = 'h000;
  localparam [11:0] API_DISPATCHER_ADDR_VERSION            = 'h002;
  localparam [11:0] API_DISPATCHER_ADDR_DUMMY              = 'h003;
  localparam [11:0] API_DISPATCHER_ADDR_SYSTICK32          = 'h004;
  localparam [11:0] API_DISPATCHER_ADDR_NTPTIME            = 'h006;
  localparam [11:0] API_DISPATCHER_ADDR_CTRL               = 'h008;
  localparam [11:0] API_DISPATCHER_ADDR_STATUS             = 'h009;
  localparam [11:0] API_DISPATCHER_ADDR_BYTES_RX           = 'h00a;
  localparam [11:0] API_DISPATCHER_ADDR_NTS_REC            = 'h00c;
  localparam [11:0] API_DISPATCHER_ADDR_NTS_DISCARDED      = 'h00e;
  localparam [11:0] API_DISPATCHER_AADR_NTS_ENGINES_READY  = 'h010;
  localparam [11:0] API_DISPATCHER_ADDR_NTS_ENGINES_ALL    = 'h011;
  localparam [11:0] API_DISPATCHER_ADDR_COUNTER_FRAMES     = 'h020;
  localparam [11:0] API_DISPATCHER_ADDR_COUNTER_GOOD       = 'h022;
  localparam [11:0] API_DISPATCHER_ADDR_COUNTER_BAD        = 'h024;
  localparam [11:0] API_DISPATCHER_ADDR_COUNTER_DISPATCHED = 'h026;
  localparam [11:0] API_DISPATCHER_ADDR_COUNTER_ERROR      = 'h028;
  localparam [11:0] API_DISPATCHER_ADDR_BUS_ID_CMD_ADDR    = 80;
  localparam [11:0] API_DISPATCHER_ADDR_BUS_STATUS         = 81;
  localparam [11:0] API_DISPATCHER_ADDR_BUS_DATA           = 82;

  localparam [11:0] API_EXTRACTOR_ADDR_NAME    = 'h400;
  localparam [11:0] API_EXTRACTOR_ADDR_VERSION = 'h402;
  localparam [11:0] API_EXTRACTOR_ADDR_BYTES   = 'h40A;
  localparam [11:0] API_EXTRACTOR_ADDR_PACKETS = 'h40C;

  localparam [7:0] BUS_READ  = 8'h55;
  localparam [7:0] BUS_WRITE = 8'hAA;

  localparam PACKET_MAX_WORDS = 200;

  localparam   [31:0] NTS_TEST_REQUEST_MASTER_KEY_ID_1=32'h30a8dce1;
  localparam  [255:0] NTS_TEST_REQUEST_MASTER_KEY_1=256'h6d1e7f51_f64876ba_68d4669e_649ad613_402bf7bb_5cf275a9_83a28dab_5e416314;
  localparam  [255:0] NTS_TEST_REQUEST_C2S_KEY_1=256'hf6467017_5420ab7e_2952fc90_fff2649e_e9ae6707_05d32341_94e72f48_6618a5b5;
  localparam  [255:0] NTS_TEST_REQUEST_S2C_KEY_1=256'hfa8ac687_49e3d765_618b2e63_496a5b6f_20baf052_148863bb_49555ac0_88fc5c44;
  localparam [1839:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_1=1840'h001c7300_00995254_00cdcd23_08004500_00d80001_00004011_bc3f4d48_e37ec23a_cad31267_101b00c4_3a272300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00002d88_68987dd0_23a60104_0024d406_12b0c40f_353d6afc_d5709668_cd4ebceb_cd8ab0aa_4fd63533_3e8491dc_9f0d0204_006830a8_dce151bd_4e5aa6e3_e577ab41_30e77bc7_cd5ab785_9283e20b_49d8f6bb_89a5b313_4cc92a3d_5eef1f45_3930d7af_f838eec7_99876905_a470e88b_1c57a85a_93fab799_a47c1b7c_8706604f_de780bf9_84394999_d7d59abc_5468cfec_5b261efe_d850618e_91c5;
  localparam [1999:0] NTS_TEST_REQUEST_WITH_KEY_IPV6_1=2000'h001c7300_00995254_00cdcd23_86dd6000_000000c4_11402a01_03f00001_00085063_d01c72c6_ab922a01_03f70002_00520000_00000000_00111267_101b00c4_5ccc2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00002d88_68987dd0_23a60104_0024d406_12b0c40f_353d6afc_d5709668_cd4ebceb_cd8ab0aa_4fd63533_3e8491dc_9f0d0204_006830a8_dce151bd_4e5aa6e3_e577ab41_30e77bc7_cd5ab785_9283e20b_49d8f6bb_89a5b313_4cc92a3d_5eef1f45_3930d7af_f838eec7_99876905_a470e88b_1c57a85a_93fab799_a47c1b7c_8706604f_de780bf9_84394999_d7d59abc_5468cfec_5b261efe_d850618e_91c5;

  localparam   [31:0] NTS_TEST_REQUEST_MASTER_KEY_ID_2=32'h13fe78e9;
  localparam  [255:0] NTS_TEST_REQUEST_MASTER_KEY_2=256'hfeb10c69_9c6435be_5a9ee521_e40e420c_f665d8f7_a969302a_63b9385d_353ae43e;
  localparam  [255:0] NTS_TEST_REQUEST_C2S_KEY_2=256'h8b61a5d5_b5d13237_2272b0e7_59938580_1cbbdfd6_d2f59fe4_8c11551d_8c724265;
  localparam  [255:0] NTS_TEST_REQUEST_S2C_KEY_2=256'h55b99245_5a4c8089_e6a1281a_f8a2842d_443ea9ac_34646e84_dca14456_6f7b908c;
  localparam [2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;
  localparam [2319:0] NTS_TEST_REQUEST_WITH_KEY_IPV6_2=2320'h001c7300_00995254_00cdcd23_86dd6000_000000ec_11402a01_03f00001_00085063_d01c72c6_ab922a01_03f70002_00520000_00000000_00111267_101b00ec_af002300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;

  localparam [2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_KEYID=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813f__f__78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;
  localparam [2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_COOKIE=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e9dead_beefdead_beef7d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;
  localparam [2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_AUTH=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c7dead_beef;


  localparam[31:0] NTS_TEST_REQUEST_MASTER_KEY_ID_3=32'h13fe78e9;
  localparam[255:0] NTS_TEST_REQUEST_MASTER_KEY_3=256'hfeb10c69_9c6435be_5a9ee521_e40e420c_f665d8f7_a969302a_63b9385d_353ae43e;
  localparam[255:0] NTS_TEST_REQUEST_C2S_KEY_3=256'h5531bb00_c863789a_bed4545c_e250f971_ac09940f_35df0fab_6e52b78f_3a9867fb;
  localparam[255:0] NTS_TEST_REQUEST_S2C_KEY_3=256'h394b3b04_4c2f0e38_56694d62_f7c1e2da_1e0c9572_76823fcf_fb7b293f_866c9737;
  localparam[7983:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_3=7984'h001c7300_0099d8cb_8a36ac3c_08004500_03d80001_00004011_854850d8_13e6c23a_cad31267_101b03c4_d2c62300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000d9fb_2822c2ac_dc4d0104_00247020_0faf5670_ce6c5866_662046c1_6e7180bb_31982d22_ac4e2fc3_625eeaf4_fbc10204_006813fe_78e96cb5_760841e1_a3a834d7_7e7e9db4_cd17406d_633f5019_71ef9e6d_2dd03493_db1bc622_0955ec27_ac035d10_239c9643_aad3ac00_c614f950_11cb251e_50e7dadf_4dd7444e_9f9e001c_72072bdc_2ffc3a10_1611ef05_a693766e_b1a12b9c_72f8d879_4e500304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000404_00280010_0010893e_de70d1ec_935d08fa_7330354b_45c67497_2b33600c_7b5eb079_e66100f4_b9aa;
  localparam[8143:0] NTS_TEST_REQUEST_WITH_KEY_IPV6_3=8144'h001c7300_00990000_00000000_86dd6000_000003c4_11400000_00000000_00000000_00000000_00002a01_03f70002_00520000_00000000_00111267_101b03c4_96362300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000d9fb_2822c2ac_dc4d0104_00247020_0faf5670_ce6c5866_662046c1_6e7180bb_31982d22_ac4e2fc3_625eeaf4_fbc10204_006813fe_78e96cb5_760841e1_a3a834d7_7e7e9db4_cd17406d_633f5019_71ef9e6d_2dd03493_db1bc622_0955ec27_ac035d10_239c9643_aad3ac00_c614f950_11cb251e_50e7dadf_4dd7444e_9f9e001c_72072bdc_2ffc3a10_1611ef05_a693766e_b1a12b9c_72f8d879_4e500304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000404_00280010_0010893e_de70d1ec_935d08fa_7330354b_45c67497_2b33600c_7b5eb079_e66100f4_b9aa;


  localparam   [31:0] NTS_TEST_REQUEST_UI36_MASTER_KEY_ID=32'hc94655d1;
  localparam  [255:0] NTS_TEST_REQUEST_UI36_MASTER_KEY=256'h712ba5fa_d41833af_f9c46f79_189c339f_6155227c_96f557ef_d641f111_f7235096;
  localparam  [255:0] NTS_TEST_REQUEST_UI36_C2S_KEY=256'h6b106573_655c2345_072f1643_80ef65a1_0d1419df_b5d02049_1ae65b23_1cba45e0;
  localparam  [255:0] NTS_TEST_REQUEST_UI36_S2C_KEY=256'h28278f92_0a93410f_5f576fb6_c4fa7cdf_2a98399a_5f1440bc_db6e0c46_483deb92;
  localparam [2191:0] NTS_TEST_REQUEST_UI36_WITH_KEY_IPV4=2192'h001c7300_00995254_00cdcd23_08004500_01040001_00004011_bc134d48_e37ec23a_cad31267_101b00f0_e55b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000eb_f7dd50ad_03b20104_00287207_182ab676_cebf1961_d3e3091a_3c8ced0a_a8d676c8_132488a1_2042b163_ab147449_29da0204_0068c946_55d14245_7b552a95_f7ae6ead_d24ec51a_18304a6c_a2fd2e2e_924f4c8d_3ff95725_2faf9aa4_0149998a_797acde5_7e7cf20a_7b28bcd0_360c52e6_b60d7948_b1d8cf02_b254aff5_640fc6b6_20b4b1d9_5644b40d_38bc6a6d_acc2c49e_f708d298_20295948_60cf0404_00280010_00108e46_4e8aa224_908ca7ad_7b7ad4aa_f704cf47_c856b2ed_d5d76df5_921d9ce7_9f78;
  localparam [2351:0] NTS_TEST_REQUEST_UI36_WITH_KEY_IPV6=2352'h001c7300_00995254_00cdcd23_86dd6000_000000f0_11402a01_03f00001_00085063_d01c72c6_ab922a01_03f70002_00520000_00000000_00111267_101b00f0_08012300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000eb_f7dd50ad_03b20104_00287207_182ab676_cebf1961_d3e3091a_3c8ced0a_a8d676c8_132488a1_2042b163_ab147449_29da0204_0068c946_55d14245_7b552a95_f7ae6ead_d24ec51a_18304a6c_a2fd2e2e_924f4c8d_3ff95725_2faf9aa4_0149998a_797acde5_7e7cf20a_7b28bcd0_360c52e6_b60d7948_b1d8cf02_b254aff5_640fc6b6_20b4b1d9_5644b40d_38bc6a6d_acc2c49e_f708d298_20295948_60cf0404_00280010_00108e46_4e8aa224_908ca7ad_7b7ad4aa_f704cf47_c856b2ed_d5d76df5_921d9ce7_9f78;

  localparam [127:0] IPV6_ADDR_FD75_02 = 128'hfd_75_50_2f_e2_21_dd_cf_00_00_00_00_00_00_00_02;
  localparam [127:0] IPV6_ADDR_FD75_10 = 128'hfd_75_50_2f_e2_21_dd_cf_00_00_00_00_00_00_00_10;

  localparam [687:0] PACKET_NEIGHBOR_SOLICITATION = {
       128'h33_33_ff_00_00_02_98_03_9b_3c_1c_66_86_dd_60_00, // 33ÿ......<.f.Ý`.
       128'h00_00_00_20_3a_ff_fd_75_50_2f_e2_21_dd_cf_00_00, // ... :ÿýuP/â!ÝÏ..
       128'h00_00_00_00_00_01_ff_02_00_00_00_00_00_00_00_00, // ......ÿ.........
       128'h00_01_ff_00_00_02_87_00_0e_c6_00_00_00_00_fd_75, // ..ÿ......Æ....ýu
       128'h50_2f_e2_21_dd_cf_00_00_00_00_00_00_00_02_01_01, // P/â!ÝÏ..........
        48'h98_03_9b_3c_1c_66 };                             //  ...<.f

  //12:29:39.724886 IP6 fd75:502f:e221:ddcf::1 > fd75:502f:e221:ddcf::10: ICMP6, echo request, seq 3, length 64
  localparam [943:0] PACKET_PING6 = {
     128'hfffe_fdfc_fbfa_9803_9b3c_1c66_86dd_6009,
     128'hf7e6_0040_3a40_fd75_502f_e221_ddcf_0000,
     128'h0000_0000_0001_fd75_502f_e221_ddcf_0000,
     128'h0000_0000_0010_8000_37b7_68a2_0003_23a9,
     128'h745e_0000_0000_620f_0b00_0000_0000_1011,
     128'h1213_1415_1617_1819_1a1b_1c1d_1e1f_2021,
     128'h2223_2425_2627_2829_2a2b_2c2d_2e2f_3031,
      48'h3233_3435_3637
  };

  localparam [783:0] PACKET_PING4 = {
     128'h52_5a_2c_18_2e_80_98_03_9b_3c_1c_66_08_00_45_00, // RZ,......<.f..E.
     128'h00_54_34_45_40_00_40_01_34_fe_c0_a8_28_01_c0_a8, // .T4E@.@.4þÀ¨(.À¨
     128'h28_14_08_00_31_d7_12_e7_00_01_7c_07_82_5e_00_00, // (...1×.ç..|..^..
     128'h00_00_f6_07_00_00_00_00_00_00_10_11_12_13_14_15, // ..ö.............
     128'h16_17_18_19_1a_1b_1c_1d_1e_1f_20_21_22_23_24_25, // .......... !"#$%
     128'h26_27_28_29_2a_2b_2c_2d_2e_2f_30_31_32_33_34_35, // &'()*+,-./012345
      16'h36_37 };                                         //  67

  localparam [591:0] PACKET_IP4_UDP_TRACEROUTE = {
       128'h52_5a_2c_18_2e_80_98_03_9b_3c_1c_66_08_00_45_00, // RZ,......<.f..E.
       128'h00_3c_b2_a5_00_00_01_11_35_a6_c0_a8_28_01_c0_a8, // .<²¥....5¦À¨(.À¨
       128'h28_14_d8_2f_82_9a_00_28_d1_9f_40_41_42_43_44_45, // (.Ø/...(Ñ.@ABCDE
       128'h46_47_48_49_4a_4b_4c_4d_4e_4f_50_51_52_53_54_55, // FGHIJKLMNOPQRSTU
        80'h56_57_58_59_5a_5b_5c_5d_5e_5f };                 // VWXYZ[\]^_

  //IP6 fd75:502f:e221:ddcf::1.45876 > fd75:502f:e221:ddcf::2.33434: UDP, length 32
  localparam [751:0] PACKET_IP6_UDP_TRACEROUTE = {
	128'h525a_2c18_2e80_9803_9b3c_1c66_86dd_6003,
	128'h0cc0_0028_1101_fd75_502f_e221_ddcf_0000,
	128'h0000_0000_0001_fd75_502f_e221_ddcf_0000,
	128'h0000_0000_0002_b334_829a_0028_1b6a_4041,
	128'h4243_4445_4647_4849_4a4b_4c4d_4e4f_5051,
	112'h5253_5455_5657_5859_5a5b_5c5d_5e5f
  };

  localparam [719:0] PACKET_IPV4_VANILLA_NTP = {
     128'h52_5a_2c_18_2e_80_98_03_9b_3c_1c_66_08_00_45_00,
     128'h00_4c_30_6a_40_00_40_11_38_d1_c0_a8_28_01_c0_a8,
     128'h28_14_e8_aa_00_7b_00_38_d1_af_e3_00_03_fa_00_01,
     128'h00_00_00_01_00_00_00_00_00_00_00_00_00_00_00_00,
     128'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00,
      80'h00_00_e2_1c_b6_45_c2_f8_ba_73
  };

  localparam [879:0] PACKET_IPV6_VANILLA_NTP = {
       128'h52_5a_2c_18_2e_80_98_03_9b_3c_1c_66_86_dd_60_0c, //  RZ,......<.f.Ý`.
       128'hae_6c_00_38_11_40_fd_75_50_2f_e2_21_dd_cf_00_00, //  ®l.8.@ýuP/â!ÝÏ..
       128'h00_00_00_00_00_01_fd_75_50_2f_e2_21_dd_cf_00_00, //  ......ýuP/â!ÝÏ..
       128'h00_00_00_00_00_02_9c_f8_00_7b_00_38_1b_7a_e3_00, //  .......ø.{.8.zã.
       128'h03_fa_00_01_00_00_00_01_00_00_00_00_00_00_00_00, //  .ú..............
       128'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00, //  ................
       112'h00_00_00_00_00_00_e2_1c_b7_0f_39_b1_7d_e3        //  ......â.·.9±}ã
  };


  localparam  [31:0] TESTKEYMD5_1_KEYID = 32'hc01df00d;
  localparam [159:0] TESTKEYMD5_1_KEY   = { 32'hf00d_4444,
                                            32'hf00d_3333,
                                            32'hf00d_2222,
                                            32'hf00d_1111,
                                            32'hf00d_0000 };
  localparam [127:0] MD5_VANILLA_NTP_MD5TESTKEY1 = 128'h24cbed6d24f8bae9af1142b860288314;


  localparam  [31:0] TESTKEYSHA_1_KEYID = 12;
  localparam [159:0] TESTKEYSHA_1_KEY = 160'h6dea311109529e436c2b4fccae9bc753c16d1b48;
  localparam [911:0] PACKET_NTP_AUTH_TESTKEYSHA_1 =  {
      128'h00_1c_42_a6_21_1a_00_1c_42_71_99_e6_08_00_45_00, //   ..B¦!...Bq.æ..E.
      128'h00_64_8d_27_40_00_40_11_97_29_0a_00_01_1d_0a_00, //   .d.'@.@..)......
      128'h01_1c_00_7b_00_7b_00_50_16_9a_e3_00_03_fa_00_01, //   ...{.{.P..ã..ú..
      128'h00_00_00_01_00_00_00_00_00_00_00_00_00_00_00_00, //   ................
      128'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00, //   ................
      128'h00_00_d9_c1_24_9c_49_81_79_2f_00_00_00_0c_6b_94, //   ..ÙÁ$.I.y/....k.
      128'h4d_ce_3f_05_51_0d_20_6f_61_5f_36_e9_00_fa_53_25, //   MÎ?.Q. oa_6é.úS%
       16'h94_c8                                            // .È
  };

  localparam API_ADDR_WIDTH  = 12;
  localparam API_RW_WIDTH    = 32;
  localparam MAC_DATA_WIDTH  = 64;

  localparam [15:0] E_TYPE_ARP  =  16'h08_06;

  localparam [15:0] ARP_HRD_ETHERNET = 16'h00_01;
  localparam [15:0] ARP_PRO_IPV4     = 16'h08_00;
  localparam [15:0] ARP_OP_REQUEST   = 16'h00_01;
  localparam [15:0] ARP_OP_REPLY     = 16'h00_02;
  localparam  [7:0] ARP_HLN_ETHERNET = 8'h6;
  localparam  [7:0] ARP_PLN_IPV4     = 8'h4;

  //----------------------------------------------------------------
  // DUT Inputs, Outputs
  //----------------------------------------------------------------

  reg i_areset; // async reset
  reg i_clk;

  reg                [7:0] i_mac_rx_data_valid;
  reg [MAC_DATA_WIDTH-1:0] i_mac_rx_data;
  reg                      i_mac_rx_bad_frame;
  reg                      i_mac_rx_good_frame;

  wire                      o_mac_tx_start;
  reg                       i_mac_tx_ack;
  wire                [7:0] o_mac_tx_data_valid;
  wire [MAC_DATA_WIDTH-1:0] o_mac_tx_data;

  reg         i_api_dispatcher_cs;
  reg         i_api_dispatcher_we;
  reg  [11:0] i_api_dispatcher_address;
  reg  [31:0] i_api_dispatcher_write_data;
  wire [31:0] o_api_dispatcher_read_data;

  reg  [63:0] i_ntp_time;

  //----------------------------------------------------------------
  // RX MAC helper regs
  //----------------------------------------------------------------

  reg                     rx_busy;
  integer                 rx_ptr;
  wire             [71:0] rx_current;
  reg [71:0] /* 8 + 64 */ packet [0:PACKET_MAX_WORDS-1];
  reg                     packet_available;
  integer                 packet_length;
  reg                     packet_marked_bad;

  assign rx_current = packet[rx_ptr];

  //----------------------------------------------------------------
  // Task for simplifying updating API signals
  //----------------------------------------------------------------

  task api_set;
    input         i_cs;
    input         i_we;
    input  [11:0] i_addr;
    input  [31:0] i_data;
    output        o_cs;
    output        o_we;
    output [11:0] o_addr;
    output [31:0] o_data;
  begin
    o_cs   = i_cs;
    o_we   = i_we;
    o_addr = i_addr;
    o_data = i_data;
  end
  endtask

  task dispatcher_read32( output [31:0] out, input [11:0] addr );
  begin : dispatcher_read32_
    reg [31:0] result;
    result = 0;
    api_set(1, 0, addr, 0, i_api_dispatcher_cs, i_api_dispatcher_we, i_api_dispatcher_address, i_api_dispatcher_write_data);
    #10;
    result = o_api_dispatcher_read_data;
    api_set(0, 0, 0, 0, i_api_dispatcher_cs, i_api_dispatcher_we, i_api_dispatcher_address, i_api_dispatcher_write_data);
    out = result;
  end
  endtask

  task dispatcher_read64( output [63:0] out, input [11:0] addr );
  begin : dispatcher_read64_
    reg [63:0] result;
    result = 0;
    dispatcher_read32( result[63:32], addr );
    dispatcher_read32( result[31:0], addr+1 );
    out = result;
  end
  endtask

  task dispatcher_write32( input [31:0] data, input [11:0] addr);
  begin
    api_set(1, 1, addr, data, i_api_dispatcher_cs, i_api_dispatcher_we, i_api_dispatcher_address, i_api_dispatcher_write_data);
    #10;
    api_set(0, 0, 0, 0, i_api_dispatcher_cs, i_api_dispatcher_we, i_api_dispatcher_address, i_api_dispatcher_write_data);
  end
  endtask

  task api_read32( output [31:0] out, input [11:0] engine, input [11:0] addr );
  begin : api_read32_
    reg [31:0] id_cmd_addr;
    reg [31:0] result;
    reg [31:0] status;
    result = 0;

    id_cmd_addr = { engine, BUS_READ, addr };
    dispatcher_write32( id_cmd_addr, API_DISPATCHER_ADDR_BUS_ID_CMD_ADDR );
    dispatcher_write32( 32'h0000_0001, API_DISPATCHER_ADDR_BUS_STATUS );

    dispatcher_read32( status, API_DISPATCHER_ADDR_BUS_STATUS );
    while (status != 0)
      dispatcher_read32( status, API_DISPATCHER_ADDR_BUS_STATUS );

    dispatcher_read32( result, API_DISPATCHER_ADDR_BUS_DATA );

    out = result;
  end
  endtask

  task api_write32( input [31:0] data, input [11:0] engine, input [11:0] addr );
  begin : api_write_32_
    reg [31:0] id_cmd_addr;
    reg [31:0] status;

    id_cmd_addr = { engine, BUS_WRITE, addr };
    dispatcher_write32( id_cmd_addr, API_DISPATCHER_ADDR_BUS_ID_CMD_ADDR );
    dispatcher_write32( data, API_DISPATCHER_ADDR_BUS_DATA );
    dispatcher_write32( 32'h0000_0001, API_DISPATCHER_ADDR_BUS_STATUS );

    dispatcher_read32( status, API_DISPATCHER_ADDR_BUS_STATUS );
    while (status != 0)
      dispatcher_read32( status, API_DISPATCHER_ADDR_BUS_STATUS );

  end
  endtask

  task api_read64( output [63:0] out, input [11:0] engine, input [11:0] addr );
  begin : api_read64_
    reg [63:0] result;
    result = 0;
    api_read32( result[63:32], engine, addr );
    api_read32( result[31:0], engine, addr+1 );
    out = result;
  end
  endtask

  task api_write64( input [63:0] data, input [11:0] engine, input [11:0] addr );
  begin
    api_write32( data[63:32], engine, addr );
    api_write32( data[31:0], engine, addr + 1 );
  end
  endtask

  //----------------------------------------------------------------
  // Install NTS key
  //----------------------------------------------------------------

  task install_key_256bit(
    input  [11:0] engine,
    input  [31:0] keyid,
    input [255:0] key,
    input   [1:0] key_index );
  begin : install_key_256bit
    reg [11:0] addr_key;
    reg [11:0] addr_keyid;
    reg [31:0] tmp;
    reg [3:0] i;
    reg [2:0] index;
    case (key_index)
      0:
        begin
          addr_key = API_ADDR_KEYMEM_KEY0_START;
          addr_keyid = API_ADDR_KEYMEM_KEY0_ID;
        end
      1:
        begin
          addr_key = API_ADDR_KEYMEM_KEY1_START;
          addr_keyid = API_ADDR_KEYMEM_KEY1_ID;
        end
      2:
        begin
          addr_key = API_ADDR_KEYMEM_KEY2_START;
          addr_keyid = API_ADDR_KEYMEM_KEY2_ID;
        end
      3:
        begin
          addr_key = API_ADDR_KEYMEM_KEY3_START;
          addr_keyid = API_ADDR_KEYMEM_KEY3_ID;
        end
      default: ;
    endcase

    api_read32(tmp, engine, API_ADDR_KEYMEM_ADDR_CTRL);

    tmp = tmp & ~ (1<<key_index);

    api_write32( tmp,   engine, API_ADDR_KEYMEM_ADDR_CTRL );
    api_write32( keyid, engine, addr_keyid );

    for (i = 0; i < 8; i = i + 1) begin
      index = i[2:0];
      api_write32( key[32*index+:32], engine, addr_key + {8'b00, index} ); //256bit LSB
    end
    for (i = 0; i < 8; i = i + 1) begin
      index = i[2:0];
      api_write32( 0, engine, addr_key + {8'b01, index} ); //256bit MSB, all zeros
    end

    tmp = tmp | (1<<key_index);
    api_write32( tmp, engine, API_ADDR_KEYMEM_ADDR_CTRL );
  end
  endtask

  //----------------------------------------------------------------
  // Set current NTS key (used to generate new cookies)
  //----------------------------------------------------------------

  task set_current_key( input [11:0] engine, input [1:0] current_key );
  begin : set_current_key_
    reg [31:0] tmp;
    api_read32(tmp, engine, API_ADDR_KEYMEM_ADDR_CTRL);
    tmp = { tmp[31:18], current_key, tmp[15:0] };
    api_write32(tmp, engine, API_ADDR_KEYMEM_ADDR_CTRL);
  end
  endtask

  task init_noncegen ( input [11:0] engine );
  begin
    api_write32( 32'h5eb6_3bbb, engine, API_ADDR_NONCEGEN_KEY0);
    api_write32( 32'he01e_eed0, engine, API_ADDR_NONCEGEN_KEY1);
    api_write32( 32'h93cb_22bb, engine, API_ADDR_NONCEGEN_KEY2);
    api_write32( 32'h8f5a_cdc3, engine, API_ADDR_NONCEGEN_KEY3);
    api_write32( 32'h6adf_b183, engine, API_ADDR_NONCEGEN_CONTEXT0);
    api_write32( 32'ha4a2_c94a, engine, API_ADDR_NONCEGEN_CONTEXT1);
    api_write32( 32'h2f92_dab5, engine, API_ADDR_NONCEGEN_CONTEXT2);
    api_write32( 32'hade7_62a4, engine, API_ADDR_NONCEGEN_CONTEXT3);
    api_write32( 32'h7889_a5a1, engine, API_ADDR_NONCEGEN_CONTEXT4);
    api_write32( 32'hdead_beef, engine, API_ADDR_NONCEGEN_CONTEXT5);
    api_write32( {20'h000_0, engine}, engine, API_ADDR_NONCEGEN_LABEL);
    api_write32( 32'h0000_0001, engine, API_ADDR_NONCEGEN_CTRL);
  end
  endtask

  task enable_engine ( input [11:0] engine );
  begin
    api_write32( 32'h0000_0001, engine, API_ADDR_ENGINE_CTRL);
  end
  endtask

  task enable_dispatcher;
  begin
    dispatcher_write32( 32'h0000_0001, API_DISPATCHER_ADDR_CTRL);
  end
  endtask

  task set_parser_ctrl_bit( input [11:0] engine, input [4:0] bitnumber, input bitvalue );
  begin : parser_ctrl_bits
    reg [31:0] tmp;
    api_read32( tmp, engine, API_ADDR_PARSER_CTRL );
    tmp[bitnumber] = bitvalue;
    api_write32( tmp, engine, API_ADDR_PARSER_CTRL );
  end
  endtask

  // A lot of testcases are from Linux pcaps with bad checksums. (sigh)
  // Testbench not so useful when checksums checked...
  task parser_disable_checksum_checks ( input [11:0] engine );
  begin
    set_parser_ctrl_bit( engine, 5'h0, 1'b0 );
  end
  endtask

  task parser_enable_ntp ( input [11:0] engine );
  begin
    set_parser_ctrl_bit( engine, 5'h2, 1'b1 ); //NTP
    set_parser_ctrl_bit( engine, 5'h3, 1'b1 ); //NTP AUTH MD5
    set_parser_ctrl_bit( engine, 5'h4, 1'b1 ); //NTP AUTH SHA1
  end
  endtask

  task init_address_resolution( input [11:0] engine );
  begin : address_resoltion
    integer i;
    api_write64( {16'h00_00, 48'hFF_FE_FD_FC_FB_FA}, engine, API_ADDR_PARSER_MAC_0 );
    api_write64( {16'h00_00, 48'hEF_EE_ED_EC_EB_EA}, engine, API_ADDR_PARSER_MAC_1 );
    api_write64( {16'h00_00, 48'hDF_DE_DD_DC_DB_DA}, engine, API_ADDR_PARSER_MAC_2 );
  //api_write64( {16'h00_00, 48'hCF_CE_CD_CC_CB_CA}, engine, API_ADDR_PARSER_MAC_3 );
    api_write64( {16'h00_00, 48'h52_5a_2c_18_2e_80}, engine, API_ADDR_PARSER_MAC_3 ); //TraceRoute testcase
    api_write32( 32'h80_A1_A2_A3, engine, API_ADDR_PARSER_IPV4_0 );
    api_write32( 32'h90_A1_A2_A3, engine, API_ADDR_PARSER_IPV4_1 );
    api_write32( 32'hA0_A1_A2_A3, engine, API_ADDR_PARSER_IPV4_2 );
    api_write32( 32'hB0_A1_A2_A3, engine, API_ADDR_PARSER_IPV4_3 );
    api_write32( 32'hC0_A1_A2_A3, engine, API_ADDR_PARSER_IPV4_4 );
    api_write32( 32'hD0_A1_A2_A3, engine, API_ADDR_PARSER_IPV4_5 );
    api_write32( 32'hE0_A1_A2_A3, engine, API_ADDR_PARSER_IPV4_6 );
  //api_write32( 32'hF0_A1_A2_A3, engine, API_ADDR_PARSER_IPV4_7 );
    api_write32( 32'hc0_a8_28_14, engine, API_ADDR_PARSER_IPV4_7 );

    for (i = 0; i < 4; i = i + 1) begin
      api_write32( IPV6_ADDR_FD75_02[127-i*32-:32], engine, API_ADDR_PARSER_IPV6_0 + i[11:0]);
      api_write32( IPV6_ADDR_FD75_10[127-i*32-:32], engine, API_ADDR_PARSER_IPV6_1 + i[11:0]);
    end
    api_write32( 32'h0f, engine, API_ADDR_PARSER_MAC_CTRL );
    api_write32( 32'hff, engine, API_ADDR_PARSER_IPV4_CTRL );
    api_write32( 32'h03, engine, API_ADDR_PARSER_IPV6_CTRL );
  end
  endtask

  task init_ntp_auth( input [11:0] engine );
  begin : init_ntpauth
    reg [31:0] slots;
    $display("%s:%0d Init NTP AUTH engine: %0d", `__FILE__, `__LINE__, engine);
    api_read32(slots, engine, API_ADDR_NTPAUTH_KEYMEM_SLOTS);
    $display("%s:%0d  * Slots: %0d", `__FILE__, `__LINE__, slots);

    api_write32(0, engine, API_ADDR_NTPAUTH_KEYMEM_ACTIVE_SLOT);
    api_write32(0, engine, API_ADDR_NTPAUTH_KEYMEM_MD5_SHA1);
    api_write32(TESTKEYMD5_1_KEYID, engine, API_ADDR_NTPAUTH_KEYMEM_KEYID );
    api_write32(TESTKEYMD5_1_KEY[159:128], engine, API_ADDR_NTPAUTH_KEYMEM_KEY4 );
    api_write32(TESTKEYMD5_1_KEY[127:96],  engine, API_ADDR_NTPAUTH_KEYMEM_KEY3 );
    api_write32(TESTKEYMD5_1_KEY[95:64],   engine, API_ADDR_NTPAUTH_KEYMEM_KEY2 );
    api_write32(TESTKEYMD5_1_KEY[63:32],   engine, API_ADDR_NTPAUTH_KEYMEM_KEY1 );
    api_write32(TESTKEYMD5_1_KEY[31:0],    engine, API_ADDR_NTPAUTH_KEYMEM_KEY0 );

    api_write32(1, engine, API_ADDR_NTPAUTH_KEYMEM_MD5_SHA1);
    api_write32(1, engine, API_ADDR_NTPAUTH_KEYMEM_ACTIVE_SLOT);
    api_write32(0, engine, API_ADDR_NTPAUTH_KEYMEM_MD5_SHA1);
    api_write32(TESTKEYSHA_1_KEYID, engine, API_ADDR_NTPAUTH_KEYMEM_KEYID );
    api_write32(TESTKEYSHA_1_KEY[159:128], engine, API_ADDR_NTPAUTH_KEYMEM_KEY4 );
    api_write32(TESTKEYSHA_1_KEY[127:96],  engine, API_ADDR_NTPAUTH_KEYMEM_KEY3 );
    api_write32(TESTKEYSHA_1_KEY[95:64],   engine, API_ADDR_NTPAUTH_KEYMEM_KEY2 );
    api_write32(TESTKEYSHA_1_KEY[63:32],   engine, API_ADDR_NTPAUTH_KEYMEM_KEY1 );
    api_write32(TESTKEYSHA_1_KEY[31:0],    engine, API_ADDR_NTPAUTH_KEYMEM_KEY0 );
    api_write32(2, engine, API_ADDR_NTPAUTH_KEYMEM_MD5_SHA1);
  end
  endtask

  //----------------------------------------------------------------
  // Test bench macros
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  //----------------------------------------------------------------
  // Test bench tasks
  //----------------------------------------------------------------

  function [63:0] mac_reverse( input [63:0] d );
  begin
    mac_reverse[56+:8] = d[0+:8]  ;
    mac_reverse[48+:8] = d[8+:8]  ;
    mac_reverse[40+:8] = d[16+:8] ;
    mac_reverse[32+:8] = d[24+:8] ;
    mac_reverse[24+:8] = d[32+:8] ;
    mac_reverse[16+:8] = d[40+:8] ;
    mac_reverse[8+:8]  = d[48+:8] ;
    mac_reverse[0+:8]  = d[56+:8] ;
  end
  endfunction

  task send_packet (
    input [65535:0] source,
    input    [31:0] length,
    input           bad_packet
  );
  integer i;
  integer packet_ptr;
  integer source_ptr;
  begin
    `assert( (0==(length%8)) ); // byte aligned required
    `assert( rx_busy == 1'b0 );
    packet_marked_bad = bad_packet;
    for (i=0; i<PACKET_MAX_WORDS; i = i + 1) begin
      packet[i] = { 8'h00, 64'habad_1dea_f00d_cafe };
    end
    packet_ptr = 1;
    source_ptr = (length % 64);
    case (source_ptr)
       56: packet[0] = { 8'b0111_1111, mac_reverse( { source[55:0],  8'h0 } ) };
       48: packet[0] = { 8'b0011_1111, mac_reverse( { source[47:0], 16'h0 } ) };
       40: packet[0] = { 8'b0001_1111, mac_reverse( { source[39:0], 24'h0 } ) };
       32: packet[0] = { 8'b0000_1111, mac_reverse( { source[31:0], 32'h0 } ) };
       24: packet[0] = { 8'b0000_0111, mac_reverse( { source[23:0], 40'h0 } ) };
       16: packet[0] = { 8'b0000_0011, mac_reverse( { source[15:0], 48'h0 } ) };
        8: packet[0] = { 8'b0000_0001, mac_reverse( { source[7:0],  56'h0 } ) };
        0: packet_ptr = 0;
      default:
        `assert(0)
    endcase

    if (packet_ptr != 0)
      if (DEBUG > 2) $display("%s:%0d %h %h", `__FILE__, `__LINE__, 0, packet[0]);

    for ( i = 0; i < length/64; i = i + 1) begin
       packet[packet_ptr] = { 8'b1111_1111, mac_reverse( source[source_ptr+:64] )};
       if (DEBUG > 2)
         $display("%s:%0d %h %h", `__FILE__, `__LINE__, packet_ptr, packet[packet_ptr]);
       source_ptr = source_ptr + 64;
       packet_ptr = packet_ptr + 1;
    end
    packet_length = packet_ptr - 1;
    packet_available = 1;
    #20;
    `assert( rx_busy );
    packet_available = 0;
    while (rx_busy) #10;
    #20;
  end
  endtask

  task send_ipv4_ntpauth_md5 (input [719:0] ntp, input [31:0] keyid, input [127:0] md5);
  begin : send_ipv4_ntpauth_md5_
    reg [879:0] ntpauth;
    ntpauth = { ntp, keyid, md5 };
    $display("%s:%0d ntpauth: %h", `__FILE__, `__LINE__, ntpauth);
    ntpauth[879-(14+2)*8-:16]    = ntpauth[879-(14+2)*8-:16] + 4 + 16; //Total Length
    $display("%s:%0d ntpauth: %h", `__FILE__, `__LINE__, ntpauth);
    ntpauth[879-(14+20+4)*8-:16] = ntpauth[879-(14+20+4)*8-:16] + 4 + 16; //UDP Length
    $display("%s:%0d ntpauth: %h", `__FILE__, `__LINE__, ntpauth);
    send_packet( { 64656'b0, ntpauth }, 880, 0 );
  end
  endtask

  //----------------------------------------------------------------
  // Design Under Test (DUT)
  //----------------------------------------------------------------

  nts_top #( .ENGINES(ENGINES), .ADDR_WIDTH(ADDR_WIDTH) ) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .i_mac_rx_data_valid(i_mac_rx_data_valid),
    .i_mac_rx_data(i_mac_rx_data),
    .i_mac_rx_bad_frame(i_mac_rx_bad_frame),
    .i_mac_rx_good_frame(i_mac_rx_good_frame),

    .o_mac_tx_start(o_mac_tx_start),
    .i_mac_tx_ack(i_mac_tx_ack),
    .o_mac_tx_data(o_mac_tx_data),
    .o_mac_tx_data_valid(o_mac_tx_data_valid),


    .i_ntp_time(i_ntp_time),

    .i_api_dispatcher_cs(i_api_dispatcher_cs),
    .i_api_dispatcher_we(i_api_dispatcher_we),
    .i_api_dispatcher_address(i_api_dispatcher_address),
    .i_api_dispatcher_write_data(i_api_dispatcher_write_data),
    .o_api_dispatcher_read_data(o_api_dispatcher_read_data)
  );


  //----------------------------------------------------------------
  // Test bench code
  //----------------------------------------------------------------

  task parser_monitor;
  begin : parser_monitor_
    reg [11:0] engine;
    reg [31:0] parser_error_state;
    reg [31:0] parser_error_cause;
    reg [31:0] parser_error_count;
    reg [31:0] parser_error_size;
    for (engine = 0; engine < ENGINES; engine = engine + 1) begin
      api_read32(parser_error_state, engine, API_ADDR_PARSER_ERROR_STATE);
      api_read32(parser_error_count, engine, API_ADDR_PARSER_ERROR_COUNT);
      api_read32(parser_error_cause, engine, API_ADDR_PARSER_ERROR_CAUSE);
      api_read32(parser_error_size, engine, API_ADDR_PARSER_ERROR_SIZE);
      if (parser_error_cause != 0) begin
        $display("%s:%0d: *** ERROR! Engine: %0d Cause: %s (%h), State: %h, Size: %h, Count: %h", `__FILE__, `__LINE__, engine, parser_error_cause, parser_error_cause, parser_error_state, parser_error_size, parser_error_count);
      end
    end
  end
  endtask

  task test_ui36;
  begin : test_ui36_
    integer i;
    reg [11:0] engine;
    for (engine = 0; engine < ENGINES; engine = engine + 1) begin
      $display("%s:%0d: *** Intstall UI36 packet master key into slot 3", `__FILE__, `__LINE__);
      install_key_256bit( engine, NTS_TEST_REQUEST_UI36_MASTER_KEY_ID, NTS_TEST_REQUEST_UI36_MASTER_KEY, 3 );
    end
    for (i = 0; i < TEST_UI36; i = i + 1) begin
      for (engine = 0; engine < ENGINES; engine = engine + 1) begin
        $display("%s:%0d: *** Transmit UI36 packets", `__FILE__, `__LINE__);
        send_packet({63344'b0, NTS_TEST_REQUEST_UI36_WITH_KEY_IPV4}, 2192, 0);
        send_packet({63184'b0, NTS_TEST_REQUEST_UI36_WITH_KEY_IPV6}, 2352, 0);
        parser_monitor();
      end
      #10000;
    end
  end
  endtask

  localparam [6975:0] FUZZ_UI_FOOT = 6976'h0204_006813fe_78e96cb5_760841e1_a3a834d7_7e7e9db4_cd17406d_633f5019_71ef9e6d_2dd03493_db1bc622_0955ec27_ac035d10_239c9643_aad3ac00_c614f950_11cb251e_50e7dadf_4dd7444e_9f9e001c_72072bdc_2ffc3a10_1611ef05_a693766e_b1a12b9c_72f8d879_4e500304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000304_00680000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000404_00280010_0010893e_de70d1ec_935d08fa_7330354b_45c67497_2b33600c_7b5eb079_e66100f4_b9aa;
  localparam [879:0] FUZZ_UI_HEAD = 880'h001c7300_00990000_00000000_86dd6000_000003c4_11400000_00000000_00000000_00000000_00002a01_03f70002_00520000_00000000_00111267_101b03c4_96362300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000d9fb_2822c2ac_dc4d;

  task fuzz_ui;
  begin : fuzz_ui_
    integer i;
    integer j;
    reg [15:0] udp_length;
    reg [15:0] tlv_length;
    reg [65535:0] pkt;
    reg [11:0] engine;

    // Test with good UI of arbitrary lengths

    for (i = TEST_FUZZ_UI_START; i <= TEST_FUZZ_UI_STOP; i = i + TEST_FUZZ_UI_INC) begin
      udp_length = 8 + 48 + i[15:0] + 4 + 872;
      tlv_length = i[15:0] + 16'h0004;
      $display("%s:%0d: *** Fuzz!!! %0d udp_length: %h", `__FILE__, `__LINE__, i, udp_length);
      pkt = 65536'h0;
      pkt[0+:6976] = FUZZ_UI_FOOT;
      for (j = 0; j < i; j = j + 1) begin
        pkt[6976+j*8+:8] = j[7:0];
        $display("%s:%0d: *** Fuzz pkt[%0d+:8] = %h", `__FILE__, `__LINE__, 6152+j*8, j[7:0]);
      end
      pkt[6976+i*8+:32] = { 16'h0104, tlv_length };
      pkt[6976+i*8+32+:880] = FUZZ_UI_HEAD;
      pkt[6976+i*8+32+880-5*64+:16] = udp_length;
      pkt[6976+i*8+32+880-10*64-16+:16] = udp_length;
      send_packet(pkt, 6976 + i*8 + 32 + 880, 0);
      #20000;
      parser_monitor();
    end

    // Test with bad UI with weird lengths

    for (i = 0; i < 7; i = i + 1) begin
      for (engine = 0; engine < ENGINES; engine = engine + 1) begin
        udp_length = 8 + 48 + 4 + 872;
        case (i)
          0: tlv_length = 0; // 0 : next UI is itself?
          1: tlv_length = 4; // 4 : TLV length is tag+length, empty value
          2: tlv_length = 16; // 16: Minimum Length is 16+4, illegal.
          3: tlv_length = 21; // Length is not even 4 octets.
          4: tlv_length = 22; // Length is not even 4 octets.
          5: tlv_length = 23; // Length is not even 4 octets.
          6: tlv_length = 16'hfffc; // -4: will overflow arithmetics for sure.
          default: tlv_length = 0;
        endcase
        $display("%s:%0d: *** Fuzz!!! udp_length: %h Weird tlv_length: %h", `__FILE__, `__LINE__, udp_length, tlv_length);
        pkt = 65536'h0;
        pkt[0+:6976] = FUZZ_UI_FOOT;
        pkt[6976+:32] = { 16'h0104, tlv_length };
        pkt[6976+32+:880] = FUZZ_UI_HEAD;
        pkt[6976+32+880-5*64+:16] = udp_length;
        pkt[6976+32+880-10*64-16+:16] = udp_length;
        send_packet(pkt, 6976 +  32 + 880, 0);
        #20000;
        parser_monitor();
      end
    end
  end
  endtask

  task arp_request (input [47:0] ethernet_src, input [31:0] ip_src, input [31:0] ip_dst );
  begin : arp_request_
    //0000   ff ff ff ff ff ff 98 03 9b 3c 1c 66 08 06 00 01   ÿÿÿÿÿÿ...<.f....
    //0010   08 00 06 04 00 01 98 03 9b 3c 1c 66 c0 a8 28 01   .........<.fÀ¨(.
    //0020   00 00 00 00 00 00 c0 a8 28 02                     ......À¨(.
    reg [42*8-1:0] packet;
    reg [47:0] ethernet_dst;
    reg [47:0] arp_dst;
    arp_dst      = 48'h00_00_00_00_00_00;
    ethernet_dst = 48'hff_ff_ff_ff_ff_ff;
    packet       = { ethernet_dst, ethernet_src, E_TYPE_ARP,
                     ARP_HRD_ETHERNET, ARP_PRO_IPV4,
                     ARP_HLN_ETHERNET, ARP_PLN_IPV4, ARP_OP_REQUEST,
                     ethernet_src, ip_src,
                     arp_dst, ip_dst
                    };
    send_packet({65200'h0, packet}, 336, 0);
  end
  endtask

  localparam  [31:0] TRACE_MASTER_KEY_ID = 32'hf001_fefe;
  localparam [255:0] TRACE_MASTER_KEY = { 128'hf001_AAA0_f001_AAA1_f001_AAA2_f001_AAA3,
                                          128'hf001_BBB0_f001_BBB1_f001_BBB2_f001_BBB3 };
  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk    = 0;
    i_areset = 1;
    i_api_dispatcher_cs = 0;
    i_api_dispatcher_we = 0;
    i_api_dispatcher_address = 0;
    i_api_dispatcher_write_data = 0;

    #10;
    i_areset = 0;
    #10;

    begin : sanity_check
      reg [63:0] dispatcher_name;
      reg [31:0] dispatcher_engines_all;
      dispatcher_read64(dispatcher_name, API_DISPATCHER_ADDR_NAME);
      `assert( dispatcher_name == 64'h4e_54_53_2d_44_49_53_50);

      dispatcher_read32(dispatcher_engines_all, API_DISPATCHER_ADDR_NTS_ENGINES_ALL);
      `assert( ENGINES == dispatcher_engines_all );
    end

    begin : loop
      integer i;
      reg [11:0] engine;
      for (i = 0; i < 100; i = i + 1) begin
        for (engine = 0; engine < ENGINES; engine = engine + 1) begin
          case (i)
            2: init_address_resolution( engine );
            3: parser_enable_ntp( engine );
            4: init_ntp_auth( engine );
            5: install_key_256bit( engine, NTS_TEST_REQUEST_MASTER_KEY_ID_1, NTS_TEST_REQUEST_MASTER_KEY_1, 0 );
            6: install_key_256bit( engine, NTS_TEST_REQUEST_MASTER_KEY_ID_2, NTS_TEST_REQUEST_MASTER_KEY_2, 1 );
            7: install_key_256bit( engine, TRACE_MASTER_KEY_ID, TRACE_MASTER_KEY, 2 );
            8: init_noncegen(engine);
            9: set_current_key(engine, 2);
            10: enable_engine(engine);
            11: if (engine == 0) enable_dispatcher();
            17: parser_disable_checksum_checks( engine );
            default: ;
          endcase
        end
        if (TEST_NORMAL) begin
          send_packet({64848'h0, PACKET_NEIGHBOR_SOLICITATION}, 688, 0);
          arp_request(48'hF0_F1_F2_F3_F4_F5, 32'hE0_E1_E2_E3, 32'hD0_D1_D2_D3);
          arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'h80_A1_A2_A3);
          arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'h90_A1_A2_A3);
          arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'hA0_A1_A2_A3);
          arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'hB0_A1_A2_A3);
          arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'hC0_A1_A2_A3);
          arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'hD0_A1_A2_A3);
          arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'hE0_A1_A2_A3);
          arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'hF0_A1_A2_A3);
        //send_packet({64592'b0, PACKET_PING6}, 944, 0);
          send_packet({64944'b0, PACKET_IP4_UDP_TRACEROUTE}, 592, 0);
          send_packet({64784'b0, PACKET_IP6_UDP_TRACEROUTE}, 752, 0);
          send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_KEYID}, 2160, 0);
          send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_KEYID}, 2160, 0);
          send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_COOKIE}, 2160, 0);
          send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_AUTH}, 2160, 0);
          send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, 1);
          send_packet({57552'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_3}, 7984, 0); //same key _2 packets, but 7 placeholders
          send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
          send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, 0);
          send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
          send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
          send_packet({63344'b0, NTS_TEST_REQUEST_UI36_WITH_KEY_IPV4}, 2192, 0);
          send_packet({63184'b0, NTS_TEST_REQUEST_UI36_WITH_KEY_IPV6}, 2352, 0);
          send_packet({64816'b0, PACKET_IPV4_VANILLA_NTP}, 720, 0);
          send_packet({64656'b0, PACKET_IPV6_VANILLA_NTP}, 880, 0);
          send_ipv4_ntpauth_md5( PACKET_IPV4_VANILLA_NTP, TESTKEYMD5_1_KEYID, MD5_VANILLA_NTP_MD5TESTKEY1 );
          send_packet( { 64624'b0, PACKET_NTP_AUTH_TESTKEYSHA_1 }, 912, 0 );
        end
      end
    end
    if (TEST_NORMAL) begin
      //while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
      //send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, 0);
      while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
      #20000;

      $display("%s:%0d: NTS_TEST_REQUEST_WITH_KEY_IPV4_3", `__FILE__, `__LINE__);
      send_packet({57552'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_3}, 7984, 0); //same key _2 packets, but 7 placeholders
      while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
      #20000;

      $display("%s:%0d: NTS_TEST_REQUEST_WITH_KEY_IPV4_3", `__FILE__, `__LINE__);
      send_packet({57552'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_3}, 7984, 0); //same key _2 packets, but 7 placeholders
      while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
      #20000;

      $display("%s:%0d: NTS_TEST_REQUEST_WITH_KEY_IPV6_3", `__FILE__, `__LINE__);
      send_packet({57392'b0, NTS_TEST_REQUEST_WITH_KEY_IPV6_3}, 8144, 0);
      while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
      #20000;
    end
    if (TEST_FUZZ_UI) begin
      fuzz_ui();
      #900000;
    end
    if (TEST_UI36 > 0) begin
      test_ui36();
    end
    if (TEST_NORMAL) begin
      $display("%s:%0d: ARP", `__FILE__, `__LINE__);
      send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_KEYID}, 2160, 0);
      #20000;
      $display("%s:%0d: ARP", `__FILE__, `__LINE__);
      arp_request(48'hF0_F1_F2_F3_F4_F5, 32'hE0_E1_E2_E3, 32'hD0_D1_D2_D3);
      #20000;
      $display("%s:%0d: ARP", `__FILE__, `__LINE__);
      arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'h80_A1_A2_A3);
      #20000;
      $display("%s:%0d: ARP", `__FILE__, `__LINE__);
      arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'h90_A1_A2_A3);
      #20000;
      $display("%s:%0d: ARP", `__FILE__, `__LINE__);
      arp_request(48'h85_84_83_82_81_80, 32'h44_43_42_41, 32'hA0_A1_A2_A3);
      #20000;
      $display("%s:%0d: ICMPv6 Neigbour Solicitation", `__FILE__, `__LINE__);
      send_packet({64848'h0, PACKET_NEIGHBOR_SOLICITATION}, 688, 0);
      #20000;
      $display("%s:%0d: ICMPv6 Trace Route", `__FILE__, `__LINE__);
      send_packet({64784'b0, PACKET_IP6_UDP_TRACEROUTE}, 752, 0);
      #20000;
      $display("%s:%0d: ICMPv4 Trace Route", `__FILE__, `__LINE__);
      send_packet({64944'b0, PACKET_IP4_UDP_TRACEROUTE}, 592, 0);
      #20000;
      $display("%s:%0d: ICMPv4 Trace Route", `__FILE__, `__LINE__);
      send_packet({64944'b0, PACKET_IP4_UDP_TRACEROUTE}, 592, 0);
      #20000;
      $display("%s:%0d: ICMPv4 Trace Route", `__FILE__, `__LINE__);
      send_packet({64944'b0, PACKET_IP4_UDP_TRACEROUTE}, 592, 0);
      #20000;
      $display("%s:%0d: IPv4 Vanilla NTP", `__FILE__, `__LINE__);
      send_packet({64816'b0, PACKET_IPV4_VANILLA_NTP}, 720, 0);
      #20000;
      $display("%s:%0d: IPv6 Vanilla NTP", `__FILE__, `__LINE__);
      send_packet({64656'b0, PACKET_IPV6_VANILLA_NTP}, 880, 0);
      #20000;
      $display("%s:%0d: IPv4 NTP AUTH MD5", `__FILE__, `__LINE__);
      send_ipv4_ntpauth_md5( PACKET_IPV4_VANILLA_NTP, TESTKEYMD5_1_KEYID, MD5_VANILLA_NTP_MD5TESTKEY1 );
      #20000;
      $display("%s:%0d: IPv4 NTP AUTH SHA1", `__FILE__, `__LINE__);
      send_packet( { 64624'b0, PACKET_NTP_AUTH_TESTKEYSHA_1 }, 912, 0 );
      #20000;
      begin : ping
        integer i;
        for (i = 0; i < 3; i = i + 1) begin
          $display("%s:%0d: ICMPv6 Ping6", `__FILE__, `__LINE__);
          send_packet({64592'h0, PACKET_PING6}, 944, 0);
          #2000;
          $display("%s:%0d: ICMPv4 Ping4", `__FILE__, `__LINE__);
          send_packet({64752'h0, PACKET_PING4}, 784, 0);
          #2000;
        end
      end
      #2000;
    end

    //----------------------------------------------------------------
    // Human readable Debug
    //----------------------------------------------------------------

    #100 ;
    begin : fin_locals_
      reg [11:0] engine;
      reg [63:0] engine_name;
      reg [31:0] engine_version;
      reg [63:0] clock_name;
      reg [31:0] debug_name;
      reg [63:0] keymem_name;
      reg [31:0] debug_systick32;
      reg [63:0] engine_stats_nts_bad_auth;
      reg [63:0] engine_stats_nts_bad_cookie;
      reg [63:0] engine_stats_nts_bad_keyid;
      reg [63:0] engine_stats_nts_processed;
      reg [63:0] crypto_err;
      reg [63:0] txbuf_err;
      reg [63:0] keymem_key0_ctr;
      reg [63:0] keymem_key1_ctr;
      reg [63:0] keymem_key2_ctr;
      reg [63:0] keymem_key3_ctr;
      reg [63:0] keymem_error_ctr;
      reg [63:0] dispatcher_name;
      reg [31:0] dispatcher_version;
      reg [31:0] dispatcher_systick32;
      reg [63:0] dispatcher_ntp_time;
      reg [31:0] dispatcher_ctrl;
      reg [31:0] dispatcher_status;
      reg [63:0] dispatcher_counter_bytes_rx;
      reg [63:0] dispatcher_counter_frames;
      reg [63:0] dispatcher_counter_good;
      reg [63:0] dispatcher_counter_bad;
      reg [63:0] dispatcher_counter_dispatched;
      reg [63:0] dispatcher_counter_packets_discarded;
      reg [63:0] dispatcher_counter_packets_recieved;
      reg [63:0] dispatcher_counter_error;
      reg [63:0] extractor_name;
      reg [31:0] extractor_version;
      reg [63:0] extractor_bytes;
      reg [63:0] extractor_packets;
      reg [63:0] parser_name;
      reg [31:0] parser_version;
      reg [31:0] parser_state;
      reg [31:0] parser_state_crypto;
      reg [31:0] parser_error_state;
      reg [31:0] parser_error_cause;
      reg [31:0] parser_error_count;
      reg [31:0] parser_error_size;
      reg [11:0] addr;
      reg [31:0] value;

      for (engine = 0; engine < ENGINES; engine = engine + 1) begin
        for (addr = 0; addr < 12'hFFF; addr = addr + 1) begin
          api_read32(value, engine, addr);
          if (value != 0)
            $display("%s:%0d: *** Engine:%0d[%h] = %h", `__FILE__, `__LINE__, engine, addr, value);
        end
      end

      for (addr = 0; addr < 12'hFFF; addr = addr + 1) begin
        dispatcher_read32(value, addr);
        if (value != 0)
          $display("%s:%0d: *** Dispatcher[%h] = %h", `__FILE__, `__LINE__, addr, value);
      end

      dispatcher_read64(dispatcher_name, API_DISPATCHER_ADDR_NAME);
      dispatcher_read32(dispatcher_version, API_DISPATCHER_ADDR_VERSION);
      dispatcher_read32(dispatcher_systick32, API_DISPATCHER_ADDR_SYSTICK32);
      dispatcher_read64(dispatcher_ntp_time, API_DISPATCHER_ADDR_NTPTIME);
      dispatcher_read32(dispatcher_ctrl, API_DISPATCHER_ADDR_CTRL);
      dispatcher_read32(dispatcher_status, API_DISPATCHER_ADDR_STATUS);
      dispatcher_read64(dispatcher_counter_bytes_rx, API_DISPATCHER_ADDR_BYTES_RX);
      dispatcher_read64(dispatcher_counter_frames, API_DISPATCHER_ADDR_COUNTER_FRAMES);
      dispatcher_read64(dispatcher_counter_good, API_DISPATCHER_ADDR_COUNTER_GOOD);
      dispatcher_read64(dispatcher_counter_bad, API_DISPATCHER_ADDR_COUNTER_BAD);
      dispatcher_read64(dispatcher_counter_dispatched, API_DISPATCHER_ADDR_COUNTER_DISPATCHED);
      dispatcher_read64(dispatcher_counter_error, API_DISPATCHER_ADDR_COUNTER_ERROR);
      dispatcher_read64(dispatcher_counter_packets_recieved, API_DISPATCHER_ADDR_NTS_REC);
      dispatcher_read64(dispatcher_counter_packets_discarded, API_DISPATCHER_ADDR_NTS_DISCARDED);
      dispatcher_read64(extractor_name, API_EXTRACTOR_ADDR_NAME);
      dispatcher_read32(extractor_version, API_EXTRACTOR_ADDR_VERSION);
      dispatcher_read64(extractor_bytes, API_EXTRACTOR_ADDR_BYTES);
      dispatcher_read64(extractor_packets, API_EXTRACTOR_ADDR_PACKETS);
      $display("%s:%0d: *** Dispatcher CORE: %s %s", `__FILE__, `__LINE__, dispatcher_name, dispatcher_version);
      $display("%s:%0d: *** Dispatcher, ntp_time:            %016x", `__FILE__, `__LINE__, dispatcher_ntp_time);
      $display("%s:%0d: *** Dispatcher, systick32:           %0d", `__FILE__, `__LINE__, dispatcher_systick32);
      $display("%s:%0d: *** Dispatcher, ctrl:                %0d", `__FILE__, `__LINE__, dispatcher_ctrl);
      $display("%s:%0d: *** Dispatcher, status:              %0d", `__FILE__, `__LINE__, dispatcher_status);
      $display("%s:%0d: *** Dispatcher, received (bytes):    %0d", `__FILE__, `__LINE__, dispatcher_counter_bytes_rx);
      $display("%s:%0d: *** Dispatcher, received (packets):  %0d", `__FILE__, `__LINE__, dispatcher_counter_packets_recieved);
      $display("%s:%0d: *** Dispatcher, discarded (packets): %0d", `__FILE__, `__LINE__, dispatcher_counter_packets_discarded);
      $display("%s:%0d: *** Dispatcher, frame start counter: %0d", `__FILE__, `__LINE__, dispatcher_counter_frames);
      $display("%s:%0d: *** Dispatcher, good frame counter:  %0d", `__FILE__, `__LINE__, dispatcher_counter_good);
      $display("%s:%0d: *** Dispatcher, bad frame counter:   %0d", `__FILE__, `__LINE__, dispatcher_counter_bad);
      $display("%s:%0d: *** Dispatcher, dispatched counter:  %0d", `__FILE__, `__LINE__, dispatcher_counter_dispatched);
      $display("%s:%0d: *** Dispatcher, error counter:       %0d", `__FILE__, `__LINE__, dispatcher_counter_error);
      $display("%s:%0d: *** Extractor CORE: %s %s", `__FILE__, `__LINE__, extractor_name, extractor_version);
      $display("%s:%0d: *** Extractor, bytes transmitted:    %0d", `__FILE__, `__LINE__, extractor_bytes);
      $display("%s:%0d: *** Extractor, packets transmitted:  %0d", `__FILE__, `__LINE__, extractor_packets);


      for (engine = 0; engine < ENGINES; engine = engine + 1) begin
        api_read64(engine_name, engine, API_ADDR_ENGINE_NAME0);
        api_read32(engine_version, engine, API_ADDR_ENGINE_VERSION);
        api_read64(clock_name, engine, API_ADDR_CLOCK_NAME0);
        api_read32(debug_name, engine, API_ADDR_DEBUG_NAME);
        api_read64(keymem_name, engine, API_ADDR_KEYMEM_NAME0);

        api_read32(debug_systick32, engine, API_ADDR_DEBUG_SYSTICK32);
        api_read64(engine_stats_nts_bad_auth, engine, API_ADDR_DEBUG_NTS_BAD_AUTH);
        api_read64(engine_stats_nts_bad_cookie, engine, API_ADDR_DEBUG_NTS_BAD_COOKIE);
        api_read64(engine_stats_nts_bad_keyid, engine, API_ADDR_DEBUG_NTS_BAD_KEYID);
        api_read64(engine_stats_nts_processed, engine, API_ADDR_DEBUG_NTS_PROCESSED);
        api_read64(crypto_err, engine, API_ADDR_DEBUG_ERR_CRYPTO);
        api_read64(txbuf_err, engine, API_ADDR_DEBUG_ERR_TXBUF);

        api_read64(keymem_key0_ctr, engine, API_ADDR_KEYMEM_KEY0_COUNTER_MSB);
        api_read64(keymem_key1_ctr, engine, API_ADDR_KEYMEM_KEY1_COUNTER_MSB);
        api_read64(keymem_key2_ctr, engine, API_ADDR_KEYMEM_KEY2_COUNTER_MSB);
        api_read64(keymem_key3_ctr, engine, API_ADDR_KEYMEM_KEY3_COUNTER_MSB);
        api_read64(keymem_error_ctr, engine, API_ADDR_KEYMEM_ERROR_COUNTER_MSB);

        api_read64(parser_name, engine, API_ADDR_PARSER_NAME);
        api_read32(parser_version, engine, API_ADDR_PARSER_VERSION);
        api_read32(parser_state, engine, API_ADDR_PARSER_STATE);
        api_read32(parser_state_crypto, engine, API_ADDR_PARSER_STATE_CRYPTO);
        api_read32(parser_error_state, engine, API_ADDR_PARSER_ERROR_STATE);
        api_read32(parser_error_count, engine, API_ADDR_PARSER_ERROR_COUNT);
        api_read32(parser_error_cause, engine, API_ADDR_PARSER_ERROR_CAUSE);
        api_read32(parser_error_size, engine, API_ADDR_PARSER_ERROR_SIZE);

        $display("%s:%0d: *** Engine %0d (%h)", `__FILE__, `__LINE__, engine, engine);
        $display("%s:%0d: ***   CORE: %s %s", `__FILE__, `__LINE__, engine_name, engine_version);
        $display("%s:%0d: ***   CORE: %s", `__FILE__, `__LINE__, clock_name);
        $display("%s:%0d: ***   CORE: %s", `__FILE__, `__LINE__, debug_name);
        $display("%s:%0d: ***     - DEBUG, NTS bad auth:   %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_auth);
        $display("%s:%0d: ***     - DEBUG, NTS bad cookie: %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_cookie);
        $display("%s:%0d: ***     - DEBUG, NTS bad key id: %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_keyid);
        $display("%s:%0d: ***     - DEBUG, NTS processed:  %0d", `__FILE__, `__LINE__, engine_stats_nts_processed);
        $display("%s:%0d: ***     - DEBUG, Errors Crypto:  %0d", `__FILE__, `__LINE__, crypto_err);
        $display("%s:%0d: ***     - DEBUG, Errors TxBuf:   %0d", `__FILE__, `__LINE__, txbuf_err);
        $display("%s:%0d: ***     - DEBUG, systick32:      %0d", `__FILE__, `__LINE__, debug_systick32);

        $display("%s:%0d: ***   CORE: %s", `__FILE__, `__LINE__, keymem_name);
        $display("%s:%0d: ***     - KeyMem, Key0 Counter:  %0d (dec)", `__FILE__, `__LINE__, keymem_key0_ctr);
        $display("%s:%0d: ***     - KeyMem, Key1 Counter:  %0d (dec)", `__FILE__, `__LINE__, keymem_key1_ctr);
        $display("%s:%0d: ***     - KeyMem, Key2 Counter:  %0d (dec)", `__FILE__, `__LINE__, keymem_key2_ctr);
        $display("%s:%0d: ***     - KeyMem, Key3 Counter:  %0d (dec)", `__FILE__, `__LINE__, keymem_key3_ctr);
        $display("%s:%0d: ***     - KeyMem, Error Counter: %0d (dec)", `__FILE__, `__LINE__, keymem_error_ctr);

        $display("%s:%0d: ***   CORE: %s %s", `__FILE__, `__LINE__, parser_name, parser_version);
        $display("%s:%0d: ***     - PARSER, state:        %h", `__FILE__, `__LINE__, parser_state);
        $display("%s:%0d: ***     - PARSER, state_crypto: %h", `__FILE__, `__LINE__, parser_state_crypto);
        $display("%s:%0d: ***     - PARSER, error_state:  %h", `__FILE__, `__LINE__, parser_error_state);
        $display("%s:%0d: ***     - PARSER, error count:  %0d (dec)", `__FILE__, `__LINE__, parser_error_count);
        $display("%s:%0d: ***     - PARSER, error cause:  %h", `__FILE__, `__LINE__, parser_error_cause);
        $display("%s:%0d: ***     - PARSER, error size:   %0d (dec)", `__FILE__, `__LINE__, parser_error_size);
      end
    end

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  //----------------------------------------------------------------
  // Testbench model: MAC RX
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_mac_rx_data_valid <= 0;
      i_mac_rx_data <= 0;
      i_mac_rx_bad_frame <= 0;
      i_mac_rx_good_frame <= 0;
      rx_busy <= 0;
    end else begin
      { i_mac_rx_data_valid, i_mac_rx_data, i_mac_rx_bad_frame, i_mac_rx_good_frame } <= 0;

      if (rx_busy) begin
        $display("%s:%0d RX: %h %h", `__FILE__, `__LINE__, rx_current[71:64], rx_current[63:0]);
        { i_mac_rx_data_valid, i_mac_rx_data } <= rx_current;
        if (rx_ptr == 0) begin
          rx_busy <= 0;
          if (packet_marked_bad)
            i_mac_rx_bad_frame <= 1;
          else
            i_mac_rx_good_frame <= 1;
        end else begin
          rx_ptr <= rx_ptr - 1;
        end

      end else if (packet_available) begin
        $display("%s:%0d packet_available", `__FILE__, `__LINE__);
        rx_busy <= 1;
        rx_ptr <= packet_length;
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: MAC TX
  //----------------------------------------------------------------

  localparam TX_IDLE       = 0;
  localparam TX_IPG        = 1;
  localparam TX_AWAIT_DATA = 2;
  localparam TX_RECEIVING  = 3;
  integer tx_state;
  reg [9:0] tx_ipg;
  reg [9:0] tx_seed;

  function [9:0] tx_generate_ipg (input [9:0] seed);
  begin
    case (seed % 5)
      default: tx_generate_ipg = 0;
      1: tx_generate_ipg = seed % 7;
      2: tx_generate_ipg = seed % 11;
      3: tx_generate_ipg = seed % 13;
      4: tx_generate_ipg = seed % 17;
    endcase
  end
  endfunction

  reg                      tx_rec_new;
  /* verilator lint_off UNUSED */
  integer                  tx_rec_bytes;
  /* verilator lint_on UNUSED */
  reg     [ADDR_WIDTH-1:0] tx_rec_addr;
  reg               [63:0] tx_rec_data [0:(1<<ADDR_WIDTH)-1];

  function [63:0] swap(input [63:0] in);
  begin
     swap[8*0+:8] = in[8*7+:8];
     swap[8*1+:8] = in[8*6+:8];
     swap[8*2+:8] = in[8*5+:8];
     swap[8*3+:8] = in[8*4+:8];
     swap[8*4+:8] = in[8*3+:8];
     swap[8*5+:8] = in[8*2+:8];
     swap[8*6+:8] = in[8*1+:8];
     swap[8*7+:8] = in[8*0+:8];
  end
  endfunction

  function [7:0] tx_read_byte(input integer i);
  begin : tx_read_byte_
    reg  [2:0] index;
    reg [63:0] tmp;

    tmp = swap( tx_rec_data[ i[ADDR_WIDTH+3-1:3] ] );
    //$display("%s:%0d * TX * tmp=%h", `__FILE__, `__LINE__, tmp);
    if (i >= tx_rec_bytes) begin
      tx_read_byte = 8'h00;
      //$display("%s:%0d * TX * tx_read_byte error, tx_rec_bytes: (%0d) i: (%0d)", `__FILE__, `__LINE__, tx_rec_bytes, i);
    end else begin
      index = i[2:0];
      case (index)
        0: tx_read_byte = tmp[63-:8];
        1: tx_read_byte = tmp[55-:8];
        2: tx_read_byte = tmp[47-:8];
        3: tx_read_byte = tmp[39-:8];
        4: tx_read_byte = tmp[31-:8];
        5: tx_read_byte = tmp[23-:8];
        6: tx_read_byte = tmp[15-:8];
        7: tx_read_byte = tmp[7-:8];
        default:
          begin
            tx_read_byte = 0;
            //$display("%s:%0d * TX * tx_read_byte error, index: (%0d) i: (%0d)", `__FILE__, `__LINE__, index, i);
          end
      endcase
    end
    //$display("%s:%0d * TX * tx_read_byte(%0d)=%h", `__FILE__, `__LINE__, i, tx_read_byte);
  end
  endfunction

  function [15:0] tx_read_word16(input integer i);
  begin
    tx_read_word16[15:8] = tx_read_byte( i );
    tx_read_word16[7:0] = tx_read_byte( i + 1 );
  end
  endfunction

  function [31:0] tx_read_word32(input integer i);
  begin
    tx_read_word32[31-:8] = tx_read_byte( i );
    tx_read_word32[23-:8] = tx_read_byte( i + 1 );
    tx_read_word32[15-:8] = tx_read_byte( i + 2 );
    tx_read_word32[7-:8]  = tx_read_byte( i + 3 );
  end
  endfunction

  function [63:0] tx_read_word64(input integer i);
  begin
    tx_read_word64[63-:8] = tx_read_byte( i );
    tx_read_word64[55-:8] = tx_read_byte( i + 1 );
    tx_read_word64[47-:8] = tx_read_byte( i + 2 );
    tx_read_word64[39-:8] = tx_read_byte( i + 3 );
    tx_read_word64[31-:8] = tx_read_byte( i + 4 );
    tx_read_word64[23-:8] = tx_read_byte( i + 5 );
    tx_read_word64[15-:8] = tx_read_byte( i + 6 );
    tx_read_word64[7-:8]  = tx_read_byte( i + 7 );
  end
  endfunction

  function [127:0] tx_read_word128(input integer i);
  begin
    tx_read_word128[127:64] = tx_read_word64(i);
    tx_read_word128[63:0]   = tx_read_word64(i + 8);
  end
  endfunction

  function [159:0] tx_read_word160(input integer i);
  begin
    tx_read_word160[159:96] = tx_read_word64(i);
    tx_read_word160[95:32]  = tx_read_word64(i + 8);
    tx_read_word160[31:0]   = tx_read_word32(i + 16);
  end
  endfunction

  function [15:0] internet_checksum(input  [15:0] init,
                                    input integer start,
                                    input integer length);
  begin : internet_checksum_
    integer    index;
    integer    remain;
    reg        carry;
    reg [15:0] sum;
    carry = 0;
    index = start;
    remain = length;
    sum = init;
    while (remain > 0) begin : internet_checksum__
      reg [15:0] word;
      if (remain > 1) begin
        word = tx_read_word16(index);
        index = index + 2;
        remain = remain - 2;
      end else begin
        word = { tx_read_byte(index), 8'h00 };
        index = index + 1;
        remain = remain - 1;
      end
      $display("%s:%0d * TX * csum = %h + %h", `__FILE__, `__LINE__, sum, word);

      { carry, sum } = { 1'b0, sum } + { 1'b0, word };
      if (carry) begin
        sum = sum + 1;
        $display("%s:%0d * TX * csum = %h (carry corrected)", `__FILE__, `__LINE__, sum);
      end
    end
    internet_checksum = sum;
  end
  endfunction

  task check_udp_checksum;
  begin : check_udp_checksum_
    reg  [7:0] ip;
    reg [15:0] csum;
    reg [15:0] ethernet_protocol;
    reg [15:0] payload_length;
    reg  [7:0] next;
    reg        garbage;
    integer    csum_offset;
    integer    csum_bytes;

    garbage = 0;
    ethernet_protocol = tx_read_word16( 12 );
    //$display("%s:%0d * TX * Ethernet Protocol %h", `__FILE__, `__LINE__, ethernet_protocol);
    case (ethernet_protocol)
      16'h86DD:
        begin
          payload_length = tx_read_word16(14 + 4);
          next = tx_read_byte(14 + 4 + 2);
          csum_offset = 14 + 8;
          csum_bytes = { 16'h0000, payload_length } + 32;
          ip="6";
        end
      16'h0800:
        begin
          payload_length = tx_read_word16(14 + 2);
          if (payload_length > 20) begin
            payload_length = payload_length - 20;
          end else begin
            garbage = 1;
          end
          next = tx_read_byte(14 + 9);
          csum_offset = 14 + 12;
          csum_bytes = { 16'h0000, payload_length } + 8;
          ip="4";
        end
      default: garbage = 1;
    endcase

    if (!garbage) begin
      if (next == 17) begin
        csum = 16'd0017 + payload_length;
        csum = internet_checksum(csum,
                                 csum_offset,
                                 csum_bytes
                                 );
        $display("%s:%0d * TX * UDP CHECK: %h (%s), IPv%s", `__FILE__, `__LINE__, csum, (csum==16'hffff)?"PASS":"FAIL", ip);
      end
    end
  end
  endtask

  task check_icmp;
  begin : check_icmp_
    reg  [7:0] ip;
    reg [15:0] csum;
    reg [15:0] ethernet_protocol;
    reg [15:0] payload_length;
    reg  [7:0] next;
    reg  [7:0] icmp_type;
    reg        icmp_unreachable;
    reg [15:0] icmp_unreachable_udp_src;
    reg [15:0] icmp_unreachable_udp_dst;
    reg [15:0] icmp_unreachable_udp_length;
    reg        garbage;
    integer    csum_offset;
    integer    csum_bytes;

    garbage = 0;
    icmp_unreachable = 0;
    ethernet_protocol = tx_read_word16( 12 );
    case (ethernet_protocol)
      16'h86DD:
        begin
          payload_length = tx_read_word16(14 + 4);
          next = tx_read_byte(14 + 4 + 2);
          icmp_type = tx_read_byte(14 + 40);
          icmp_unreachable_udp_src    = tx_read_word16(14 + 40 + 8 + 40);
          icmp_unreachable_udp_dst    = tx_read_word16(14 + 40 + 8 + 40 + 2);
          icmp_unreachable_udp_length = tx_read_word16(14 + 40 + 8 + 40 + 2 + 2);
          csum = { 8'h00, next } + payload_length;
          csum_offset = 14 + 8;
          csum_bytes = { 16'h0000, payload_length } + 32;
          ip="6";
          if (next != 58) garbage = 1;
          if (icmp_type == 1) icmp_unreachable = 1;
        end
      16'h0800:
        begin
          payload_length = tx_read_word16(14 + 2);
          if (payload_length > 20) begin
            payload_length = payload_length - 20;
          end else begin
            garbage = 1;
          end
          next = tx_read_byte(14 + 9);
          icmp_type = tx_read_byte(14 + 20);
          icmp_unreachable_udp_src    = tx_read_word16(14 + 20 + 8 + 20);
          icmp_unreachable_udp_dst    = tx_read_word16(14 + 20 + 8 + 20 + 2);
          icmp_unreachable_udp_length = tx_read_word16(14 + 20 + 8 + 20 + 2 + 2);
          csum = 0;
          csum_offset = 14 + 20;
          csum_bytes = { 16'h0000, payload_length };
          ip="4";
          if (next != 1) garbage = 1;
          if (icmp_type == 3) icmp_unreachable = 1;
        end
      default: garbage = 1;
    endcase

    if (!garbage) begin
      csum = internet_checksum(csum, csum_offset, csum_bytes);
      $display("%s:%0d * TX * ICMPv%s CHECK: %h (%s)", `__FILE__, `__LINE__, ip, csum, (csum==16'hffff)?"PASS":"FAIL");
      $display("%s:%0d * TX * ICMPv%s Type: %h (%0d)", `__FILE__, `__LINE__, ip, icmp_type, icmp_type);
      if (icmp_unreachable) begin
        $display("%s:%0d * TX * ICMPv%s Destination Unreachable (SrcPort %0d, DstPort %0d, Length %0d)", `__FILE__, `__LINE__, ip, icmp_unreachable_udp_src, icmp_unreachable_udp_dst, icmp_unreachable_udp_length);
      end
    end
  end
  endtask

  task check_ipv4;
  begin : check_ipv4_
    reg [15:0] csum;
    reg [15:0] ethernet_protocol;
    reg  [7:0] ip_ihl;
    reg [15:0] total_length;
    integer expected_length;
    ethernet_protocol = tx_read_word16( 12 );
    ip_ihl = tx_read_byte( 14 );
    total_length = tx_read_word16(14 + 2);
    if (ethernet_protocol == 16'h0800) begin
      `assert(ip_ihl == 8'h45);
      `assert(total_length > 20);
      expected_length = tx_rec_bytes - 14;
      $display("%s:%0d * TX * IPv4 total length %s: %0d (expected: %0d), tx_rec_bytes: %0d)", `__FILE__, `__LINE__,
         ( ( {16'h0000, total_length} ) == expected_length) ?"GOOD":"BAD!",
         total_length, expected_length, tx_rec_bytes);
      //`assert( ( {16'h0000, total_length} ) == expected_length);
      csum = internet_checksum( 16'h0000, 14, 20);
      $display("%s:%0d * TX * IPv4 CHECK: %h (%s)", `__FILE__, `__LINE__, csum, (csum==16'hffff)?"PASS":"FAIL");
    end
  end
  endtask

  task check_nts;
  begin : check_nts_
    reg        garbage;
    reg [15:0] ethernet_protocol;
    reg [15:0] srcport;
    reg [15:0] payload_length;
    reg  [7:0] next;
    integer    ntp_offset;
    integer    extension_offset;
    integer    i;
    reg  [15:0] ext_tag;
    reg  [15:0] ext_length;
    reg   [1:0] ntp_li;
    reg   [2:0] ntp_vn;
    reg   [2:0] ntp_mode;
    reg   [7:0] ntp_stratum;
    reg   [7:0] ntp_poll;
    reg   [7:0] ntp_precision;
    reg  [31:0] ntp_root_delay;
    reg  [31:0] ntp_root_dispersion;
    reg  [31:0] ntp_reference_id;
    reg  [63:0] ntp_ref_time;
    reg  [63:0] ntp_origin_time;
    reg  [63:0] ntp_receive_time;
    reg  [63:0] ntp_transmit_time;
    reg  [31:0] ntpauth_keyid;
    reg [127:0] ntpauth_md5;
    reg [159:0] ntpauth_sha1;
    garbage = 0;

    ethernet_protocol = tx_read_word16( 12 );
    case (ethernet_protocol)
      16'h86DD:
        begin
          payload_length = tx_read_word16(14 + 4);
          next = tx_read_byte(14 + 4 + 2);
          srcport = tx_read_word16( 14 + 40 );
          ntp_offset = 14 + 40 + 8;
        end
      16'h0800:
        begin
          payload_length = tx_read_word16(14 + 2);
          if (payload_length > 20) begin
            payload_length = payload_length - 20;
          end else begin
            garbage = 1;
          end
          next = tx_read_byte(14 + 9);
          srcport = tx_read_word16( 14 + 20 );
          ntp_offset = 14 + 20 + 8;
        end
      default: garbage = 1;
    endcase

    if (!garbage) begin
      $display("%s:%0d * TX * next: %0d", `__FILE__, `__LINE__, next);
      if (next == 17) begin
        $display("%s:%0d * TX * UDP SRC port: %0d", `__FILE__, `__LINE__, srcport);
        if (srcport == 123 || srcport == 4123) begin
          //Great, it is NTP!
        end else begin
          garbage = 1;
        end
      end else garbage = 1;
    end

    if (!garbage) begin
      { ntp_li, ntp_vn, ntp_mode, ntp_stratum, ntp_poll, ntp_precision } = tx_read_word32( ntp_offset );
      ntp_root_delay = tx_read_word32( ntp_offset + 4 );
      ntp_root_dispersion = tx_read_word32( ntp_offset + 8) ;
      ntp_reference_id = tx_read_word32( ntp_offset + 12 );
      ntp_ref_time = tx_read_word64( ntp_offset + 16 );
      ntp_origin_time = tx_read_word64( ntp_offset + 24 );
      ntp_receive_time = tx_read_word64( ntp_offset + 32 );
      ntp_transmit_time = tx_read_word64( ntp_offset + 40 );
      ntpauth_keyid = tx_read_word32( ntp_offset + 48 );
      ntpauth_md5 = tx_read_word128( ntp_offset + 52 );
      ntpauth_sha1 = tx_read_word160( ntp_offset + 52 );
      $display("%s:%0d * TX * NTP LI: %h, VN: %h, mode: %h, stratum: %h, poll: %h, precision: %h", `__FILE__, `__LINE__, ntp_li, ntp_vn, ntp_mode, ntp_stratum, ntp_poll, ntp_precision );
      $display("%s:%0d * TX * NTP Root Delay: %h", `__FILE__, `__LINE__, ntp_root_delay);
      $display("%s:%0d * TX * NTP Root Dispersion: %h", `__FILE__, `__LINE__, ntp_root_dispersion);
      $display("%s:%0d * TX * NTP Reference Id: %h (%s)", `__FILE__, `__LINE__, ntp_reference_id, ntp_reference_id);
      $display("%s:%0d * TX * NTP Reference Time: %h", `__FILE__, `__LINE__, ntp_ref_time);
      $display("%s:%0d * TX * NTP Origin Time: %h", `__FILE__, `__LINE__, ntp_origin_time);
      $display("%s:%0d * TX * NTP Receive Time: %h", `__FILE__, `__LINE__, ntp_receive_time);
      $display("%s:%0d * TX * NTP Transmit Time: %h", `__FILE__, `__LINE__, ntp_transmit_time);
    end

    if (!garbage) begin
      if (payload_length < 8+6*8) begin
        $display("%s:%0d * TX * NTP Payload Length: (%0d) (%0d) - ERROR SHORT", `__FILE__, `__LINE__, payload_length, payload_length-8);
         garbage = 1;
      end else if (payload_length == 8+6*8) begin
        $display("%s:%0d * TX * NTP Payload Length: (%0d) (%0d) - NTP only, no auth", `__FILE__, `__LINE__, payload_length, payload_length-8);
        garbage = 1;
      end else if (payload_length == 8+6*8 + 4 ) begin
        $display("%s:%0d * TX * NTP Payload Length: (%0d) (%0d) - NTP Crypto-NAK KeyID: %h", `__FILE__, `__LINE__, payload_length, payload_length-8, ntpauth_keyid);
        if (ntpauth_keyid != 0) 
          $display("%s:%0d * TX * NTP Illegal Crypto-NAK KeyID: %h (expected 0)", `__FILE__, `__LINE__, ntpauth_keyid);
        garbage = 1;
      end else if (payload_length == 8+6*8 + 4 + 16) begin
        $display("%s:%0d * TX * NTP Payload Length: (%0d) (%0d) - NTP MD5 KeyID: %h md5: %h", `__FILE__, `__LINE__, payload_length, payload_length-8, ntpauth_keyid, ntpauth_md5);
       garbage = 1;
      end else if (payload_length == 8+6*8 + 4 + 20) begin
        $display("%s:%0d * TX * NTP Payload Length: (%0d) (%0d) - NTP SHA1 KeyID: %h sha1: %h", `__FILE__, `__LINE__, payload_length, payload_length-8, ntpauth_keyid, ntpauth_sha1);
       garbage = 1;
      end else if (payload_length > 8+6*8+32+10) begin
        $display("%s:%0d * TX * NTP Payload Length: (%0d) (%0d) - Probably NTS", `__FILE__, `__LINE__, payload_length, payload_length-8);
      end else begin
        $display("%s:%0d * TX * NTP Payload Length: (%0d) (%0d) - **confused**", `__FILE__, `__LINE__, payload_length, payload_length-8);
      end
    end

    if (!garbage) begin : ext_proc
      reg [15:0] skip_bytes;
      skip_bytes = 0;

      extension_offset = ntp_offset + 6*8;
      i = extension_offset;
      while (i < tx_rec_bytes) begin
        if (skip_bytes > 0) begin
          skip_bytes = skip_bytes-1;
          i = i + 1;
        end else begin
          ext_tag = tx_read_word16( i );
          ext_length = tx_read_word16( i + 2 );
          $display("%s:%0d * TX * NTP Extension: Tag: %h Length: %h", `__FILE__, `__LINE__, ext_tag, ext_length);
          if (ext_tag == 16'h0104 && ext_length < 4+32) begin
            $display("%s:%0d * TX * NTP Extension: NTS Warning short UniqIdEF!!", `__FILE__, `__LINE__);
          end
          `assert(ext_length % 4 == 0);
          if (ext_tag == 16'h0404 && ext_length < 4+2+2+4+32) begin
            $display("%s:%0d * TX * NTP Extension: NTS Warning short Enc&AuthEF!!", `__FILE__, `__LINE__);
          end
          `assert(ext_length % 4 == 0);
          `assert(ext_length > 16);
          if (ext_tag == 16'h0404) begin : EncAuthEF
            reg  [15:0] nonce_length;
            reg  [15:0] ciphertext_length;
            reg [127:0] tmp;
            reg  [15:0] c;
            nonce_length = tx_read_word16( i + 4 );
            ciphertext_length = tx_read_word16( i + 6 );
            $display("%s:%0d * TX * NTP Extension: NTS Enc&AuthEF NL = %0d, CL = %0d", `__FILE__, `__LINE__, nonce_length, ciphertext_length);
            if (nonce_length == 16) begin
              tmp = tx_read_word128( i + 8 );
              $display("%s:%0d * TX * NTP Extension: NTS Enc&AuthEF nonce = %h", `__FILE__, `__LINE__, tmp);
              for (c = 0; c < ciphertext_length/16; c = c + 1) begin
                tmp = tx_read_word128( i + 24 + c * 16 );
                $display("%s:%0d * TX * NTP Extension: NTS Enc&AuthEF c[%0d] = %h", `__FILE__, `__LINE__, c, tmp);
              end
              if ( (tx_read_word128( i +  8 ) === 128'habfef8bad8ec78ee85f983b2028f76bb ) &&
                   (tx_read_word128( i + 24 ) === 128'h65132c80e7eb739de1c29d9656458f0f ) &&
                   (tx_read_word128( i + 40 ) === 128'h2ba26a299aa88d2795ecad0f441cd0b3 )
                 )
              begin
                $display("%s:%0d * TX * NTP Extension: NTS Enc&AuthEF -- looks like a well know good packet", `__FILE__, `__LINE__);
              end
            end else begin
              $display("%s:%0d * TX * NTP Extension: NTS Enc&AuthEF wrong nonce length (%0d)!", `__FILE__, `__LINE__, nonce_length);
            end
          end
          skip_bytes = ext_length;
        end
      end
    end
  end
  endtask

  always @(posedge i_clk or posedge i_areset)
  begin : tx_checks
    if (i_areset) begin
    end else if (tx_rec_new) begin
      $display("%s:%0d * TX * tx_rec_bytes: %h (%0d)", `__FILE__, `__LINE__, tx_rec_bytes, tx_rec_bytes);
      check_icmp();
      check_ipv4();
      check_udp_checksum();
      check_nts();
    end
  end

  always @(posedge i_clk or posedge i_areset)
  begin : tx_model
    reg [9:0] tmp_ipg;
    if (i_areset) begin
      i_mac_tx_ack <= 0;
      tx_ipg <= 0;
      tx_rec_new <= 0;
      tx_rec_bytes <= 0;
      tx_rec_addr <= 0;
      tx_seed <= 0;
      tx_state <= TX_IDLE;
    end else begin
      i_mac_tx_ack <= 0;
      tx_rec_new <= 0;
      case (tx_state)
        TX_IDLE:
          begin
            if (o_mac_tx_data_valid != 8'h00) $display("%s:%0d TX TX_IDLE illegal data: %h - %h", `__FILE__, `__LINE__, o_mac_tx_data_valid, o_mac_tx_data);
            if (o_mac_tx_start) begin
              tmp_ipg = tx_generate_ipg(tx_seed);
              $display("%s:%0d TX MAC will wait %0d cycles before issing ACK. Seed was: %0d", `__FILE__, `__LINE__, tmp_ipg, tx_seed);
              tx_ipg <= tmp_ipg;
              tx_seed <= tx_seed + 1;
              tx_state <= TX_IPG;
            end
          end
        TX_IPG:
          begin
            if (o_mac_tx_data_valid != 8'h00) $display("%s:%0d TX TX_IPG illegal data: %h - %h", `__FILE__, `__LINE__, o_mac_tx_data_valid, o_mac_tx_data);
            if (tx_ipg == 0) begin
              $display("%s:%0d TX MAC issues transmit send ack", `__FILE__, `__LINE__);
              `assert(o_mac_tx_data_valid == 8'hff);
              i_mac_tx_ack <= 1;
              tx_rec_addr <= 0;
              tx_rec_bytes <= 0;
              tx_state <= TX_RECEIVING;
            end else begin
              tx_ipg <= tx_ipg - 1;
            end
          end
        TX_RECEIVING:
          begin
            if (o_mac_tx_data_valid != 8'hff) begin
              tx_state <= TX_IDLE;
              tx_rec_new <= 1;
            end
            if (o_mac_tx_data_valid != 8'h00) begin
              $display("%s:%0d TX Transmit to MAC, DV: %h Data: %h", `__FILE__, `__LINE__, o_mac_tx_data_valid, o_mac_tx_data);
              tx_rec_data[tx_rec_addr] <= o_mac_tx_data;
              tx_rec_addr <= tx_rec_addr + 1;
            end
            case (o_mac_tx_data_valid)
              8'b0000_0001: tx_rec_bytes <= tx_rec_bytes + 1;
              8'b0000_0011: tx_rec_bytes <= tx_rec_bytes + 2;
              8'b0000_0111: tx_rec_bytes <= tx_rec_bytes + 3;
              8'b0000_1111: tx_rec_bytes <= tx_rec_bytes + 4;
              8'b0001_1111: tx_rec_bytes <= tx_rec_bytes + 5;
              8'b0011_1111: tx_rec_bytes <= tx_rec_bytes + 6;
              8'b0111_1111: tx_rec_bytes <= tx_rec_bytes + 7;
              8'b1111_1111: tx_rec_bytes <= tx_rec_bytes + 8;
              default: ;
            endcase
          end
      endcase

    end
 end

  //----------------------------------------------------------------
  // Testbench model: NTP clock
  //----------------------------------------------------------------

  always  @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_ntp_time = 64'h0000_0001_0000_0000;
    end else begin
      i_ntp_time = i_ntp_time + 1;
    end
  end

  //----------------------------------------------------------------
  // Testbench model: System Clock
  //----------------------------------------------------------------

  always begin
    #5 i_clk = ~i_clk;
  end

  //----------------------------------------------------------------
  // Debu traces - occationally timestamp output
  //----------------------------------------------------------------

  if (DEBUG>0) begin : clock_stamp
    reg [63:0] clock;
    always  @(posedge i_clk or posedge i_areset)
    if (i_areset) begin
      clock <= 0;
    end else begin
      clock <= clock + 1;
      if ((clock & 64'hffff) == 64'h0)
        $display("%s:%0d DEBUG CLOCK: %0d (%h) ticks", `__FILE__, `__LINE__, clock, clock);
    end
  end

  //----------------------------------------------------------------
  // Debug traces
  //----------------------------------------------------------------

  `define inspect( x ) $display("%s:%0d: INSPECT: %s = %h", `__FILE__, `__LINE__, `"x`", x)
  `define always_inspect( x ) always @* `inspect( x )

  if (DEBUG_CRYPTO_RX) begin
    `always_inspect( dut.genblk1[0].engine.crypto.i_rx_wait );
    `always_inspect( dut.genblk1[0].engine.crypto.o_rx_addr );
    `always_inspect( dut.genblk1[0].engine.crypto.o_rx_burstsize);
    `always_inspect( dut.genblk1[0].engine.crypto.o_rx_wordsize);
    `always_inspect( dut.genblk1[0].engine.crypto.o_rx_rd_en);
    `always_inspect( dut.genblk1[0].engine.crypto.i_rx_rd_dv);
    `always_inspect( dut.genblk1[0].engine.crypto.i_rx_rd_data);
    `always_inspect( dut.genblk1[0].engine.crypto.core_tag_out);
  end


  if (DEBUG>0) begin
    always @*
     $display("%s:%0d dut.genblk1[0].engine.parser.protocol_detect_ip4echo_reg: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.parser.protocol_detect_ip4echo_reg);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.parser.cookies_count_reg: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.parser.cookies_count_reg);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.parser_muxctrl_ntpauth: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.parser_muxctrl_ntpauth);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.parser_ntpauth_md5: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.parser_ntpauth_md5);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.parser_ntpauth_sha1: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.parser_ntpauth_sha1);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.parser_ntpauth_transmit: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.parser_ntpauth_transmit);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.ntpauth_txbuf_address: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.ntpauth_txbuf_address);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.ntpauth_txbuf_write_en: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.ntpauth_txbuf_write_en);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.ntpauth_txbuf_write_data: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.ntpauth_txbuf_write_data);
    always @*
     $display("%s:%0d dut.genblk1[0].engine.parser.protocol_detect_ntpauth_md5_reg: %h", `__FILE__, `__LINE__, dut.genblk1[0].engine.parser.protocol_detect_ntpauth_md5_reg);
    always @*
      $display("%s:%0d dut.dispatcher.engines_ready_reg: %h", `__FILE__, `__LINE__,  dut.dispatcher.engines_ready_reg);
    always @*
      $display("%s:%0d dut.dispatcher.mem_state[0]: %h", `__FILE__, `__LINE__, dut.dispatcher.mem_state_reg[0]);
    always @*
      $display("%s:%0d dut.dispatcher.mem_state[1]: %h", `__FILE__, `__LINE__, dut.dispatcher.mem_state_reg[1]);
    always @*
      $display("%s:%0d dut.dispatcher.current_mem: %h", `__FILE__, `__LINE__, dut.dispatcher.current_mem_reg);
    always @*
      $display("%s:%0d dut.dispatcher.mac_rx_corrected=%h",  `__FILE__, `__LINE__, dut.dispatcher.mac_rx_corrected);
    always @*
      $display("%s:%0d dut.engine_extractor_packet_available: %h", `__FILE__, `__LINE__, dut.engine_extractor_packet_available);
    always @*
      $display("%s:%0d dut.engine_extractor_fifo_empty: %h", `__FILE__, `__LINE__, dut.engine_extractor_fifo_empty);
    always @(posedge i_clk)
      begin
        if (dut.extractor.ram_engine_write)
           $display("%s:%0d extractor.RAM[%h]=%h", `__FILE__, `__LINE__, dut.extractor.ram_engine_addr, dut.extractor.ram_engine_wdata);
        if (dut.extractor.buffer_engine_selected_we)
            $display("%s:%0d extractor, next write buffer: %h", `__FILE__, `__LINE__, dut.extractor.buffer_engine_selected_new);
      end
    always @(posedge i_clk)
      begin
        if (dut.extractor.buffer_mac_selected_we)
          $display("%s:%0d extactor mac select buffer: %h", `__FILE__, `__LINE__, dut.extractor.buffer_mac_selected_reg);
      end
  end

  if (DEBUG>2) begin
    always @*
     begin : tx_mux
       reg                    internal;
       reg                    en;
       reg [ADDR_WIDTH+3-1:0] addr;
       reg             [63:0] data;
       internal = dut.genblk1[0].engine.mux_tx_address_internal;
       en       = dut.genblk1[0].engine.mux_tx_write_en;
       addr     = { dut.genblk1[0].engine.mux_tx_address_hi,
                    dut.genblk1[0].engine.mux_tx_address_lo };
       data     = dut.genblk1[0].engine.mux_tx_write_data;
       if (en)
         $display("%s:%0d TX-MUX [%h,%h] = %h", `__FILE__, `__LINE__, internal, addr, data);
    end
  end


  //----------------------------------------------------------------
  // Benchmarking registers
  //----------------------------------------------------------------

  if (BENCHMARK) begin : benchmark

    reg [63:0] tick_counter;
    reg [63:0] old_tick_counter_packet;

    reg [63:0] old_tick_counter;
    reg [63:0] old_tick_counter_crypto;
    reg [63:0] old_tick_counter_icmp;
    reg [63:0] old_tick_counter_ntp;
    reg [63:0] old_tick_counter_nts;
    reg [63:0] old_tick_counter_siv;
    reg [63:0] old_tick_counter_verify_secure;
    reg  [4:0] old_parser_state;
    reg  [4:0] old_parser_state_crypto;
    reg  [5:0] old_parser_state_icmp;
    reg  [4:0] old_parser_state_ntp;
    reg  [5:0] old_parser_state_nts;
    reg  [4:0] old_parser_state_siv;
    reg  [4:0] old_parser_state_verify_secure;

    always @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        tick_counter <= 1;
      end else begin
        tick_counter <= tick_counter + 1;
      end
    end

    always @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        old_tick_counter_packet <= 1;
        old_tick_counter <= 1;
        old_parser_state <= 0;
      end else begin
        if (old_parser_state == 0)
          old_tick_counter_packet <= tick_counter;

        if (old_parser_state != dut.genblk1[0].engine.parser.state_reg) begin
          old_tick_counter <= tick_counter;
          old_parser_state <= dut.genblk1[0].engine.parser.state_reg;

          if (old_parser_state != 0)
            $display("%s:%0d BENCHMARK: dut.genblk1[0].engine.parser.state_reg(%h)->(%h): %0d ticks", `__FILE__, `__LINE__,
               old_parser_state, dut.genblk1[0].engine.parser.state_reg, tick_counter - old_tick_counter);
          if (dut.genblk1[0].engine.parser.state_reg == 0)
            $display("%s:%0d BENCHMARK: Packet took %0d ticks to process", `__FILE__, `__LINE__, tick_counter - old_tick_counter_packet);
        end
      end
    end

    always @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        old_tick_counter_crypto <= 1;
        old_parser_state_crypto <= 0;
      end else begin

        if (old_parser_state_crypto != dut.genblk1[0].engine.parser.crypto_fsm_reg) begin
          old_tick_counter_crypto <= tick_counter;
          old_parser_state_crypto <= dut.genblk1[0].engine.parser.crypto_fsm_reg;
          $display("%s:%0d BENCHMARK: dut.genblk1[0].engine.parser.crypto_fsm_reg %h -> %h (hex): %0d ticks", `__FILE__, `__LINE__,
            old_parser_state_crypto, dut.genblk1[0].engine.parser.crypto_fsm_reg, tick_counter - old_tick_counter_crypto);
        end
      end
    end

    always @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        old_tick_counter_icmp <= 1;
        old_parser_state_icmp <= 0;
      end else begin

        if (old_parser_state_icmp != dut.genblk1[0].engine.parser.icmp_state_reg) begin
          old_tick_counter_icmp <= tick_counter;
          old_parser_state_icmp <= dut.genblk1[0].engine.parser.icmp_state_reg;
          $display("%s:%0d BENCHMARK: dut.genblk1[0].engine.parser.icmp_state_reg %h -> %h (hex): %0d ticks", `__FILE__, `__LINE__,
            old_parser_state_icmp, dut.genblk1[0].engine.parser.icmp_state_reg, tick_counter - old_tick_counter_icmp);
        end
      end
    end

    always @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        old_tick_counter_ntp <= 1;
        old_parser_state_ntp <= 0;
      end else begin
        if (old_parser_state_ntp != dut.genblk1[0].engine.parser.basic_ntp_state_reg) begin
          old_tick_counter_ntp <= tick_counter;
          old_parser_state_ntp <= dut.genblk1[0].engine.parser.basic_ntp_state_reg;
          $display("%s:%0d BENCHMARK: dut.genblk1[0].engine.parser.basic_ntp_state_reg %h -> %h (hex): %0d ticks", `__FILE__, `__LINE__,
            old_parser_state_ntp, dut.genblk1[0].engine.parser.basic_ntp_state_reg, tick_counter - old_tick_counter_ntp);
        end
      end
    end

    always @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        old_tick_counter_nts <= 1;
        old_parser_state_nts <= 0;
      end else begin
        if (old_parser_state_nts != dut.genblk1[0].engine.parser.nts_state_reg) begin
          old_tick_counter_nts <= tick_counter;
          old_parser_state_nts <= dut.genblk1[0].engine.parser.nts_state_reg;
          $display("%s:%0d BENCHMARK: dut.genblk1[0].engine.parser.nts_state_reg %h -> %h (hex): %0d ticks", `__FILE__, `__LINE__,
            old_parser_state_nts, dut.genblk1[0].engine.parser.nts_state_reg, tick_counter - old_tick_counter_nts);
        end
      end
    end

    always @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        old_tick_counter_siv <= 1;
        old_parser_state_siv <= 0;
      end else begin
        if (old_parser_state_siv != dut.genblk1[0].engine.crypto.core.core_ctrl_reg) begin
          old_tick_counter_siv <= tick_counter;
          old_parser_state_siv <= dut.genblk1[0].engine.crypto.core.core_ctrl_reg;
          $display("%s:%0d BENCHMARK: dut.genblk1[0].engine.crypto.core.core_ctrl_reg %h -> %h (hex): %0d ticks", `__FILE__, `__LINE__,
            old_parser_state_siv, dut.genblk1[0].engine.crypto.core.core_ctrl_reg, tick_counter - old_tick_counter_siv);
        end
      end
    end

    always @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        old_tick_counter_verify_secure <= 1;
        old_parser_state_verify_secure <= 0;
      end else begin
        if (old_parser_state_verify_secure != dut.genblk1[0].engine.crypto.state_reg) begin
          old_tick_counter_verify_secure <= tick_counter;
          old_parser_state_verify_secure <= dut.genblk1[0].engine.crypto.state_reg;
          $display("%s:%0d BENCHMARK: dut.genblk1[0].engine.crypto.state_reg %h -> %h (hex): %0d ticks", `__FILE__, `__LINE__,
            old_parser_state_verify_secure, dut.genblk1[0].engine.crypto.state_reg, tick_counter - old_tick_counter_verify_secure);
        end
      end
    end

  end

endmodule
