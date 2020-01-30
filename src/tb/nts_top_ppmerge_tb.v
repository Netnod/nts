module nts_top_ppmerge_tb;
  localparam ADDR_WIDTH = 10;

  localparam [11:0] API_ADDR_ENGINE_BASE        = 12'h000;
  localparam [11:0] API_ADDR_ENGINE_NAME0       = API_ADDR_ENGINE_BASE;
  localparam [11:0] API_ADDR_ENGINE_NAME1       = API_ADDR_ENGINE_BASE + 1;
  localparam [11:0] API_ADDR_ENGINE_VERSION     = API_ADDR_ENGINE_BASE + 2;

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
  localparam [11:0] API_ADDR_KEYMEM_KEY0_LENGTH = API_ADDR_KEYMEM_BASE + 12'h11;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_START  = API_ADDR_KEYMEM_BASE + 12'h40;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_END    = API_ADDR_KEYMEM_BASE + 12'h4f;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_ID     = API_ADDR_KEYMEM_BASE + 12'h12;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_LENGTH = API_ADDR_KEYMEM_BASE + 12'h13;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_START  = API_ADDR_KEYMEM_BASE + 12'h50;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_END    = API_ADDR_KEYMEM_BASE + 12'h5f;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_ID     = API_ADDR_KEYMEM_BASE + 12'h14;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_LENGTH = API_ADDR_KEYMEM_BASE + 12'h15;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_START  = API_ADDR_KEYMEM_BASE + 12'h60;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_END    = API_ADDR_KEYMEM_BASE + 12'h6f;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_ID     = API_ADDR_KEYMEM_BASE + 12'h16;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_LENGTH = API_ADDR_KEYMEM_BASE + 12'h17;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_START  = API_ADDR_KEYMEM_BASE + 12'h70;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_END    = API_ADDR_KEYMEM_BASE + 12'h7f;

  localparam [11:0] API_DISPATCHER_ADDR_NAME               = 'h000;
  localparam [11:0] API_DISPATCHER_ADDR_VERSION            = 'h002;
  localparam [11:0] API_DISPATCHER_ADDR_DUMMY              = 'h003;
  localparam [11:0] API_DISPATCHER_ADDR_SYSTICK32          = 'h004;
  localparam [11:0] API_DISPATCHER_ADDR_NTPTIME            = 'h006;
  localparam [11:0] API_DISPATCHER_ADDR_BYTES_RX           = 'h00a;
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

  localparam DEBUG           = 1;
  localparam BENCHMARK       = 1;
  localparam ENGINES         = 1; //Beware: only ENGINES=1 supported for now
  localparam API_ADDR_WIDTH  = 12;
  localparam API_RW_WIDTH    = 32;
  localparam MAC_DATA_WIDTH  = 64;

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
  wire                      i_mac_tx_ack;
  wire                [7:0] o_mac_tx_data_valid;
  wire [MAC_DATA_WIDTH-1:0] o_mac_tx_data;

  reg         i_api_dispatcher_cs;
  reg         i_api_dispatcher_we;
  reg  [11:0] i_api_dispatcher_address;
  reg  [31:0] i_api_dispatcher_write_data;
  wire [31:0] o_api_dispatcher_read_data;

  reg  [63:0] i_ntp_time;

  wire          tb_mac_start;
  reg           tb_mac_ack;
  wire  [7 : 0] tb_mac_data_valid;
  wire [63 : 0] tb_mac_data;
 
  //----------------------------------------------------------------
  // pp model regs
  //----------------------------------------------------------------

  reg   [31:0] pp_tickcounter;
  reg          pp_start;
  reg [7 : 0]  pp_bytes;

  reg [7 : 0]  pp_tx_count;
  reg [2 : 0]  pp_tx_state;
  reg [63 : 0] pp_tx_data;
  reg [7 : 0]  pp_tx_data_valid;
  reg          pp_tx_start;
  wire         pp_tx_ack;


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

  //TODO make this support > 1 engine in the future
  task api_read32( output [31:0] out, input [11:0] addr );
  begin : api_read32_
    reg [31:0] id_cmd_addr;
    reg [31:0] result;
    reg [31:0] status;
    result = 0;

    id_cmd_addr = { 12'h0, BUS_READ, addr };
    dispatcher_write32( id_cmd_addr, API_DISPATCHER_ADDR_BUS_ID_CMD_ADDR );
    dispatcher_write32( 32'h0000_0001, API_DISPATCHER_ADDR_BUS_STATUS );

    dispatcher_read32( status, API_DISPATCHER_ADDR_BUS_STATUS );
    while (status != 0)
      dispatcher_read32( status, API_DISPATCHER_ADDR_BUS_STATUS );

    dispatcher_read32( result, API_DISPATCHER_ADDR_BUS_DATA );

    out = result;
  end
  endtask

  //TODO make this support > 1 engine in the future
  task api_write32( input [31:0] data, input [11:0] addr );
  begin : api_write_32_
    reg [31:0] id_cmd_addr;
    reg [31:0] status;

    id_cmd_addr = { 12'h0, BUS_WRITE, addr };
    dispatcher_write32( id_cmd_addr, API_DISPATCHER_ADDR_BUS_ID_CMD_ADDR );
    dispatcher_write32( data, API_DISPATCHER_ADDR_BUS_DATA );
    dispatcher_write32( 32'h0000_0001, API_DISPATCHER_ADDR_BUS_STATUS );

    dispatcher_read32( status, API_DISPATCHER_ADDR_BUS_STATUS );
    while (status != 0)
      dispatcher_read32( status, API_DISPATCHER_ADDR_BUS_STATUS );

  end
  endtask

  //TODO make this support > 1 engine in the future
  task api_read64( output [63:0] out, input [11:0] addr );
  begin : api_read64_
    reg [63:0] result;
    result = 0;
    api_read32( result[63:32], addr );
    api_read32( result[31:0], addr+1 );
    out = result;
  end
  endtask

  //----------------------------------------------------------------
  // Install key
  //----------------------------------------------------------------

  task install_key_256bit(
    input  [31:0] keyid,
    input [255:0] key,
    input   [1:0] key_index );
  begin : install_key_256bit
    reg [11:0] addr_key;
    reg [11:0] addr_keyid;
    reg [11:0] addr_length;
    reg [31:0] tmp;
    reg [3:0] i;
    reg [2:0] index;
    case (key_index)
      0:
        begin
          addr_key = API_ADDR_KEYMEM_KEY0_START;
          addr_keyid = API_ADDR_KEYMEM_KEY0_ID;
          addr_length = API_ADDR_KEYMEM_KEY0_LENGTH;
        end
      1:
        begin
          addr_key = API_ADDR_KEYMEM_KEY1_START;
          addr_keyid = API_ADDR_KEYMEM_KEY1_ID;
          addr_length = API_ADDR_KEYMEM_KEY1_LENGTH;
        end
      2:
        begin
          addr_key = API_ADDR_KEYMEM_KEY2_START;
          addr_keyid = API_ADDR_KEYMEM_KEY2_ID;
          addr_length = API_ADDR_KEYMEM_KEY2_LENGTH;
        end
      3:
        begin
          addr_key = API_ADDR_KEYMEM_KEY3_START;
          addr_keyid = API_ADDR_KEYMEM_KEY3_ID;
          addr_length = API_ADDR_KEYMEM_KEY3_LENGTH;
        end
      default: ;
    endcase

    api_read32(tmp, API_ADDR_KEYMEM_ADDR_CTRL);

    tmp = tmp & ~ (1<<key_index);

    api_write32( tmp,   API_ADDR_KEYMEM_ADDR_CTRL );
    api_write32( keyid, addr_keyid );
    api_write32( 0,     addr_length );

    for (i = 0; i < 8; i = i + 1) begin
      index = i[2:0];
      api_write32( key[32*index+:32], addr_key + {8'b00, index} ); //256bit LSB
    end
    for (i = 0; i < 8; i = i + 1) begin
      index = i[2:0];
      api_write32( 0, addr_key + {8'b01, index} ); //256bit MSB, all zeros
    end

    tmp = tmp | (1<<key_index);
    api_write32( tmp, API_ADDR_KEYMEM_ADDR_CTRL );
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

  pp_merge merge(
    .clk            ( i_clk    ),
    .areset         ( i_areset ),

    .pp_start       ( pp_tx_start      ),
    .pp_ack         ( pp_tx_ack        ),
    .pp_data_valid  ( pp_tx_data_valid ),
    .pp_data        ( pp_tx_data       ),

    .nts_start      ( o_mac_tx_start      ),
    .nts_ack        ( i_mac_tx_ack        ),
    .nts_data_valid ( o_mac_tx_data_valid ),
    .nts_data       ( o_mac_tx_data       ),

    .mac_start      ( tb_mac_start      ),
    .mac_ack        ( tb_mac_ack        ),
    .mac_data_valid ( tb_mac_data_valid ),
    .mac_data       ( tb_mac_data       )
  );


  //----------------------------------------------------------------
  // Test bench code
  //----------------------------------------------------------------

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk    = 0;
    i_areset = 1;
    i_api_dispatcher_cs = 0;
    i_api_dispatcher_we = 0;
    i_api_dispatcher_address = 0;


    #10;
    i_areset = 0;
    #10;

    install_key_256bit( NTS_TEST_REQUEST_MASTER_KEY_ID_1, NTS_TEST_REQUEST_MASTER_KEY_1, 0 );
    install_key_256bit( NTS_TEST_REQUEST_MASTER_KEY_ID_2, NTS_TEST_REQUEST_MASTER_KEY_2, 1 );

    begin : loop
      integer i;
      for (i = 0; i < 100; i = i + 1) begin
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_KEYID}, 2160, 0);
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_KEYID}, 2160, 0);
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_COOKIE}, 2160, 0);
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_AUTH}, 2160, 0);
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, 1);
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({57552'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_3}, 7984, 0); //same key _2 packets, but 7 placeholders
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
        send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, 0);
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
      end
    end
    //while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
    //send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, 0);
    while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
    #200;
    send_packet({57552'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_3}, 7984, 0); //same key _2 packets, but 7 placeholders
    #900000;

    //----------------------------------------------------------------
    // Human readable Debug
    //----------------------------------------------------------------

    #100 ;
    begin : fin_locals_
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
      reg [63:0] dispatcher_name;
      reg [31:0] dispatcher_version;
      reg [31:0] dispatcher_systick32;
      reg [63:0] dispatcher_ntp_time;
      reg [63:0] dispatcher_counter_bytes_rx;
      reg [63:0] dispatcher_counter_frames;
      reg [63:0] dispatcher_counter_good;
      reg [63:0] dispatcher_counter_bad;
      reg [63:0] dispatcher_counter_dispatched;
      reg [63:0] dispatcher_counter_error;
      reg [63:0] extractor_name;
      reg [31:0] extractor_version;
      reg [63:0] extractor_bytes;
      reg [63:0] extractor_packets;
      reg [11:0] addr;
      reg [31:0] value;

      for (addr = 0; addr < 12'hFFF; addr = addr + 1) begin
        dispatcher_read32(value, addr);
        if (value != 0)
          $display("%s:%0d: *** Dispatcher[%h] = %h", `__FILE__, `__LINE__, addr, value);
      end
      for (addr = 0; addr < 12'hFFF; addr = addr + 1) begin
        api_read32(value, addr);
        if (value != 0)
          $display("%s:%0d: *** Engine[%h] = %h", `__FILE__, `__LINE__, addr, value);
      end

      api_read64(engine_name, API_ADDR_ENGINE_NAME0);
      api_read32(engine_version, API_ADDR_ENGINE_VERSION);
      api_read64(clock_name, API_ADDR_CLOCK_NAME0);
      api_read32(debug_name, API_ADDR_DEBUG_NAME);
      api_read64(keymem_name, API_ADDR_KEYMEM_NAME0);
      api_read32(debug_systick32, API_ADDR_DEBUG_SYSTICK32);
      api_read64(engine_stats_nts_bad_auth, API_ADDR_DEBUG_NTS_BAD_AUTH);
      api_read64(engine_stats_nts_bad_cookie, API_ADDR_DEBUG_NTS_BAD_COOKIE);
      api_read64(engine_stats_nts_bad_keyid, API_ADDR_DEBUG_NTS_BAD_KEYID);
      api_read64(engine_stats_nts_processed, API_ADDR_DEBUG_NTS_PROCESSED);
      api_read64(crypto_err, API_ADDR_DEBUG_ERR_CRYPTO);
      api_read64(txbuf_err, API_ADDR_DEBUG_ERR_TXBUF);
      dispatcher_read64(dispatcher_name, API_DISPATCHER_ADDR_NAME);
      dispatcher_read32(dispatcher_version, API_DISPATCHER_ADDR_VERSION);
      dispatcher_read32(dispatcher_systick32, API_DISPATCHER_ADDR_SYSTICK32);
      dispatcher_read64(dispatcher_ntp_time, API_DISPATCHER_ADDR_NTPTIME);
      dispatcher_read64(dispatcher_counter_bytes_rx, API_DISPATCHER_ADDR_BYTES_RX);
      dispatcher_read64(dispatcher_counter_frames, API_DISPATCHER_ADDR_COUNTER_FRAMES);
      dispatcher_read64(dispatcher_counter_good, API_DISPATCHER_ADDR_COUNTER_GOOD);
      dispatcher_read64(dispatcher_counter_bad, API_DISPATCHER_ADDR_COUNTER_BAD);
      dispatcher_read64(dispatcher_counter_dispatched, API_DISPATCHER_ADDR_COUNTER_DISPATCHED);
      dispatcher_read64(dispatcher_counter_error, API_DISPATCHER_ADDR_COUNTER_ERROR);
      dispatcher_read64(extractor_name, API_EXTRACTOR_ADDR_NAME);
      dispatcher_read32(extractor_version, API_EXTRACTOR_ADDR_VERSION);
      dispatcher_read64(extractor_bytes, API_EXTRACTOR_ADDR_BYTES);
      dispatcher_read64(extractor_packets, API_EXTRACTOR_ADDR_PACKETS);
      $display("%s:%0d: *** CORE: %s %s", `__FILE__, `__LINE__, dispatcher_name, dispatcher_version);
      $display("%s:%0d: *** CORE: %s %s", `__FILE__, `__LINE__, extractor_name, extractor_version);
      $display("%s:%0d: *** CORE: %s %s", `__FILE__, `__LINE__, engine_name, engine_version);
      $display("%s:%0d: *** CORE: %s", `__FILE__, `__LINE__, clock_name);
      $display("%s:%0d: *** CORE: %s", `__FILE__, `__LINE__, debug_name);
      $display("%s:%0d: *** CORE: %s", `__FILE__, `__LINE__, keymem_name);
      $display("%s:%0d: *** DEBUG, systick32:      %0d", `__FILE__, `__LINE__, debug_systick32);
      $display("%s:%0d: *** DEBUG, NTS bad auth:   %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_auth);
      $display("%s:%0d: *** DEBUG, NTS bad cookie: %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_cookie);
      $display("%s:%0d: *** DEBUG, NTS bad key id: %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_keyid);
      $display("%s:%0d: *** DEBUG, NTS processed:  %0d", `__FILE__, `__LINE__, engine_stats_nts_processed);
      $display("%s:%0d: *** DEBUG, Errors Crypto:  %0d", `__FILE__, `__LINE__, crypto_err);
      $display("%s:%0d: *** DEBUG, Errors TxBuf:   %0d", `__FILE__, `__LINE__, txbuf_err);
      $display("%s:%0d: *** Dispatcher, ntp_time:            %016x", `__FILE__, `__LINE__, dispatcher_ntp_time);
      $display("%s:%0d: *** Dispatcher, systick32:           %0d", `__FILE__, `__LINE__, dispatcher_systick32);
      $display("%s:%0d: *** Dispatcher, bytes received:      %0d", `__FILE__, `__LINE__, dispatcher_counter_bytes_rx);
      $display("%s:%0d: *** Dispatcher, frame start counter: %0d", `__FILE__, `__LINE__, dispatcher_counter_frames);
      $display("%s:%0d: *** Dispatcher, good frame counter:  %0d", `__FILE__, `__LINE__, dispatcher_counter_good);
      $display("%s:%0d: *** Dispatcher, bad frame counter:   %0d", `__FILE__, `__LINE__, dispatcher_counter_bad);
      $display("%s:%0d: *** Dispatcher, dispatched counter:  %0d", `__FILE__, `__LINE__, dispatcher_counter_dispatched);
      $display("%s:%0d: *** Dispatcher, error counter:       %0d", `__FILE__, `__LINE__, dispatcher_counter_error);
      $display("%s:%0d: *** Extractor, bytes transmitted:    %0d", `__FILE__, `__LINE__, extractor_bytes);
      $display("%s:%0d: *** Extractor, packets transmitted:  %0d", `__FILE__, `__LINE__, extractor_packets);
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
        $display("%s:%0d %h %h", `__FILE__, `__LINE__, rx_current[71:64], rx_current[63:0]);
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

  always @(posedge i_clk or posedge i_areset)
  begin : tx_model
    reg [9:0] tmp_ipg;
    if (i_areset) begin
      tb_mac_ack <= 0;
      tx_ipg <= 0;
      tx_seed <= 0;
      tx_state <= TX_IDLE;
    end else begin
      tb_mac_ack <= 0;
      case (tx_state)
        TX_IDLE:
          begin
            if (tb_mac_data_valid != 8'h00) $display("%s:%0d TX TX_IDLE illegal data: %h - %h", `__FILE__, `__LINE__, tb_mac_data_valid, tb_mac_data);
            if (tb_mac_start) begin
              tmp_ipg = tx_generate_ipg(tx_seed);
              $display("%s:%0d TX MAC will wait %0d cycles before issing ACK. Seed was: %0d", `__FILE__, `__LINE__, tmp_ipg, tx_seed);
              tx_ipg <= tmp_ipg;
              tx_seed <= tx_seed + 1;
              tx_state <= TX_IPG;
            end
          end
        TX_IPG:
          begin
            if (tb_mac_data_valid != 8'h00) $display("%s:%0d TX TX_IPG illegal data: %h - %h", `__FILE__, `__LINE__, tb_mac_data_valid, tb_mac_data);
            if (tx_ipg == 0) begin
              $display("%s:%0d TX MAC issues transmit send ack", `__FILE__, `__LINE__);
              tb_mac_ack <= 1;
              tx_state <= TX_AWAIT_DATA;
            end else begin
              tx_ipg <= tx_ipg - 1;
            end
          end
        TX_AWAIT_DATA:
          case (tb_mac_data_valid)
            8'h00: ;
            8'hff: tx_state <= TX_RECEIVING;
            default: $display("%s:%0d TX TX_AWAIT_DATA illegal data: %h - %h", `__FILE__, `__LINE__, tb_mac_data_valid, tb_mac_data);
          endcase
        TX_RECEIVING: if (tb_mac_data_valid != 8'hff) tx_state <= TX_IDLE;
      endcase
      if (tb_mac_data_valid != 8'h00)
        $display("%s:%0d TX Transmit to MAC, DV: %h Data: %h", `__FILE__, `__LINE__, tb_mac_data_valid, tb_mac_data);
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
  // Testbench model: pp_tx
  //----------------------------------------------------------------

  localparam TX_S_IDLE = 3'h0;
  localparam TX_S_WACK = 3'h1;
  localparam TX_S_WR   = 3'h2;
  localparam TX_S_LAST = 3'h3;
  always @(posedge i_clk or posedge i_areset)
    begin : pp_tx_process
      if (i_areset == 1'b1)
        begin
          pp_tx_state      <= TX_S_IDLE;
          pp_tx_data       <= 64'b0;
          pp_tx_data_valid <=  8'b0;
          pp_tx_count      <=  0;
        end
      else
        begin
          pp_tx_data       <= 64'h0;
          pp_tx_data_valid <= 8'b0;
          pp_tx_start      <= 1'b0;

          case (pp_tx_state)
            TX_S_IDLE :
              begin
                if (pp_start == 1'b1)
                  begin
                    pp_tx_start <= 1'b1;
                    pp_tx_state <= TX_S_WACK;
                    $display("%s:%0d pp_tx: Starting new transfer.", `__FILE__, `__LINE__);
                  end
              end

            TX_S_WACK :
              begin
                pp_tx_data       <= 64'hdeaddead_dead0001;
                pp_tx_data_valid <= 8'hff;
                pp_tx_count      <= 1;

                if (pp_tx_ack == 1'b1)
                  begin
                    pp_tx_data       <= 64'hdeaddead_dead0002;
                    pp_tx_data_valid <= 8'hff;
                    pp_tx_count      <= 2;
                    pp_tx_state      <= TX_S_WR;
                  end
              end

            TX_S_WR :
              begin
                $display("%s:%0d pp_tx: Transferrring data to mac.",  `__FILE__, `__LINE__);
                pp_tx_data       <= 64'hdeaddead_dead0003;
                pp_tx_data_valid <= 8'hff;
                pp_tx_count      <= pp_tx_count + 1;

                if (pp_tx_count >= pp_bytes/8 -1)
                  begin
                    pp_tx_state <= TX_S_LAST;
                  end
              end

            TX_S_LAST :
              begin
                $display("%s:%0d pp_tx: Transferrring final data to mac.", `__FILE__, `__LINE__);
                pp_tx_data       <= 64'hdeaddead_dead0004;
                pp_tx_data_valid <= 8'hff >> (8 - (pp_bytes % 8));
                pp_tx_count      <= 0;
                pp_tx_state      <= TX_S_IDLE;
              end

            default :
              begin
                pp_tx_data        <= 64'h0;
                pp_tx_data_valid  <= 8'h00;
                pp_tx_count       <= 0;
                pp_tx_state       <= TX_S_IDLE;
              end
          endcase // case (pp_tx_state)
        end // else: !if(tb_areset == 1'b1)
     end

  always @(posedge i_clk or posedge i_areset)
  if (i_areset == 1'b1) begin
    pp_tickcounter <= 0;
    pp_start <= 0;
    pp_bytes <= 0;
  end else begin
    pp_start <= 0;
    pp_tickcounter <= pp_tickcounter + 1;
    if ((pp_tickcounter % 1373) == 0) begin
      pp_start <= 1;
      pp_bytes <= pp_tickcounter[7:0];
    end
  end

  if (DEBUG>0) begin
    always @(posedge i_clk)
      if (dut.engine.parser.ntp_extension_we)
        $display("%s:%0d ntp_ext[%0d] = tag:%h,length:%h,addr:%h",
          `__FILE__,
          `__LINE__,
          dut.engine.parser.ntp_extension_counter_reg,
          dut.engine.parser.ntp_extension_tag_new,
          dut.engine.parser.ntp_extension_length_new,
          dut.engine.parser.ntp_extension_addr_new
        );
      always @(posedge i_clk)
        if (dut.engine.parser.crypto_fsm_we == 1)
          $display("%s:%0d State: %h CRYPTO_FSM state %h => %h [%s]",`__FILE__,`__LINE__,
            dut.engine.parser.state_reg,
            dut.engine.parser.crypto_fsm_reg,
            dut.engine.parser.crypto_fsm_new,
           (dut.engine.parser.crypto_fsm_new==dut.engine.parser.CRYPTO_FSM_DONE_SUCCESS) ? "Win!" : ((dut.engine.parser.crypto_fsm_new==dut.engine.parser.CRYPTO_FSM_DONE_FAILURE)?"Fail":"...."));
      always @*
        begin : tmp___
          integer engine_index;
          for (engine_index = 0; engine_index < ENGINES; engine_index = engine_index + 1)
            if (dut.engine_busy[dut.engine_index]==1'b0)
              $display("%s:%0d detect UI:%b C:%b CP:%b A:%b",  `__FILE__, `__LINE__,
                dut.engine_debug_detect_unique_identifier[engine_index],
                dut.engine_debug_detect_nts_cookie[engine_index],
                dut.engine_debug_detect_nts_cookie_placeholder[engine_index],
                dut.engine_debug_detect_nts_authenticator[engine_index]);
        end
      always @*
        $display("%s:%0d dut.engine.crypto.key_master_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.key_master_reg);
      always @*
        $display("%s:%0d dut.engine.crypto.key_current_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.key_current_reg);
      always @*
        $display("%s:%0d dut.engine.crypto.key_c2s_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.key_c2s_reg);
      always @*
        $display("%s:%0d dut.engine.crypto.key_s2c_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.key_s2c_reg);
      always @*
        $display("%s:%0d dut.engine.parser.state_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.state_reg);
      always @*
        $display("%s:%0d dut.engine.parser.i_last_word_data_valid: %b", `__FILE__, `__LINE__, dut.engine.parser.i_last_word_data_valid);
      always @*
        $display("%s:%0d dut.engine.parser.word_counter_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.word_counter_reg);
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_udp_length_reg: %h (%0d)", `__FILE__, `__LINE__, dut.engine.parser.ipdecode_udp_length_reg, dut.engine.parser.ipdecode_udp_length_reg);
      always @*
        $display("%s:%0d dut.engine.parser.detect_ipv4: %b detect_ipv6: %b", `__FILE__, `__LINE__, dut.engine.parser.detect_ipv4, dut.engine.parser.detect_ipv6);
      always @(posedge i_clk or posedge i_areset)
        begin : tx_mux_inspect_locals_
          reg [ADDR_WIDTH+3-1:0] addr;
          addr = { dut.engine.mux_tx_address_hi, dut.engine.mux_tx_address_lo };
          if (i_areset == 0)
            if (dut.engine.mux_tx_write_en)
              $display("%s:%0d dut.engine.mux_tx %h %h (%h %h) = %h",  `__FILE__, `__LINE__, dut.engine.mux_tx_address_internal, addr, dut.engine.mux_tx_address_hi, dut.engine.mux_tx_address_lo, dut.engine.mux_tx_write_data);
        end
      always @*
        $display("%s:%0d dut.engine.i_dispatch_rx_fifo_rd_data: %h", `__FILE__, `__LINE__, dut.engine.i_dispatch_rx_fifo_rd_data);
      always @*
        $display("%s:%0d dut.engine.i_dispatch_rx_fifo_rd_valid: %h",  `__FILE__, `__LINE__, dut.engine.i_dispatch_rx_fifo_rd_valid);
      always @*
        $display("%s:%0d dut.dispatcher.mem_state[0]: %h", `__FILE__, `__LINE__, dut.dispatcher.mem_state_reg[0]);
      always @*
        $display("%s:%0d dut.dispatcher.mem_state[1]: %h", `__FILE__, `__LINE__, dut.dispatcher.mem_state_reg[1]);
      always @*
        $display("%s:%0d dut.dispatcher.current_mem: %h", `__FILE__, `__LINE__, dut.dispatcher.current_mem_reg);
/*
      always @*
        $display("%s:%0d dut.o_dispatch_tx_bytes_last_word_DUMMY=%b (ignored)",  `__FILE__, `__LINE__, dut.o_dispatch_tx_bytes_last_word_DUMMY);
      always @*
        $display("%s:%0d dut.o_dispatch_tx_fifo_rd_data_DUMMY=%h (ignored)",  `__FILE__, `__LINE__, dut.o_dispatch_tx_fifo_rd_data_DUMMY);
      always @*
        $display("%s:%0d dut.tx_d=%h (ignored)",  `__FILE__, `__LINE__, dut.tx_d); //TODO doesn't work well now. Fix later.
*/
      always @*
        $display("%s:%0d dut.dispatcher.mac_rx_corrected=%h",  `__FILE__, `__LINE__, dut.dispatcher.mac_rx_corrected);
      always @(posedge i_clk or posedge i_areset)
        if (i_areset == 0)
          if (dut.engine.rx_buffer.memctrl_we)
            if (dut.engine.rx_buffer.memctrl_new == dut.engine.rx_buffer.MEMORY_CTRL_ERROR) begin
              $display("%s:%0d WARNING: Memory controller error state detected!", `__FILE__, `__LINE__);
              $display("%s:%0d          memctrl_reg: %h", `__FILE__, `__LINE__, dut.engine.rx_buffer.memctrl_reg);
              $display("%s:%0d          access_ws{8,16,32,64}bit_reg: %b", `__FILE__, `__LINE__, {dut.engine.rx_buffer.access_ws8bit_reg, dut.engine.rx_buffer.access_ws16bit_reg, dut.engine.rx_buffer.access_ws32bit_reg, dut.engine.rx_buffer.access_ws64bit_reg});
              $display("%s:%0d          access_addr_lo_reg: %h", `__FILE__, `__LINE__, dut.engine.rx_buffer.access_addr_lo_reg);
              $display("%s:%0d          i_parser_busy: %h", `__FILE__, `__LINE__, dut.engine.rx_buffer.i_parser_busy);
          end
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_ethernet_mac_dst_reg: %h",  `__FILE__, `__LINE__, dut.engine.parser.ipdecode_ethernet_mac_dst_reg);
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_ethernet_mac_src_reg: %h",  `__FILE__, `__LINE__, dut.engine.parser.ipdecode_ethernet_mac_src_reg);
      always @*
        $display("%s:%0d dut.engine.parser.tx_header_ethernet_ipv4_udp: %h",  `__FILE__, `__LINE__, dut.engine.parser.tx_header_ethernet_ipv4_udp);
      always @*
        if (dut.engine.access_port_rd_dv_parser)
          $display("%s:%0d dut.engine.access_port(parser)[%h:%h]=%h", `__FILE__, `__LINE__, dut.engine.access_port_addr_parser, dut.engine.access_port_wordsize_parser, dut.engine.access_port_rd_data_parser);
      always @*
        if (dut.engine.parser_txbuf_address_internal==0)
          if (dut.engine.parser_txbuf_write_en)
            $display("%s:%0d dut.engine.parser_txbuf[%h]=%h", `__FILE__, `__LINE__, dut.engine.parser_txbuf_address, dut.engine.parser_txbuf_write_data);
      always @*
        $display("%s:%0d dut.engine.parser.cookies_count_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.cookies_count_reg);
      always @*
        $display("%s:%0d dut.engine.parser.nts_valid_placeholders_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.nts_valid_placeholders_reg);
      always @*
        $display("%s:%0d dut.engine.crypto.state_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.state_reg);
      always @*
        $display("%s:%0d dut.engine.parser.tx_udp_length_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.tx_udp_length_reg);
      always @*
        $display("%s:%0d dut.engine.parser.tx_ipv4_totlen_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.tx_ipv4_totlen_reg);
      always @(posedge i_clk)
        begin
          if (dut.engine.parser_txbuf_sum_en)
            $display("%s:%0d dut.engine.sum_en, bytes: %h (%0d)", `__FILE__, `__LINE__, dut.engine.parser_txbuf_sum_bytes, dut.engine.txbuf_parser_sum_done);
          if (dut.engine.txbuf_parser_sum_done)
            $display("%s:%0d dut.engine.sum_done, sum: %h", `__FILE__, `__LINE__, dut.engine.txbuf_parser_sum);
      end
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
        if (dut.engine.tx_buffer.current_mem_we)
          $display("%s:%0d txbuf word count: %h", `__FILE__, `__LINE__, dut.engine.tx_buffer.word_count_reg[dut.engine.tx_buffer.current_mem_reg]);
        if (dut.engine.tx_buffer.i_parser_update_length)
          $display("%s:%0d txbuf update word count: %h %h", `__FILE__, `__LINE__, dut.engine.tx_buffer.i_address_hi, dut.engine.tx_buffer.i_address_lo);
      end
    always @(posedge i_clk)
      begin
        if (dut.extractor.buffer_mac_selected_we)
          $display("%s:%0d extactor mac select buffer: %h", `__FILE__, `__LINE__, dut.extractor.buffer_mac_selected_reg);
      end

    always @*
      $display("%s:%0d merge.mux_ctrl: %h", `__FILE__, `__LINE__, merge.mux_ctrl);
    always @*
      $display("%s:%0d merge.mux_ctrl_reg: %h", `__FILE__, `__LINE__, merge.mux_ctrl_reg);
    always @*
      $display("%s:%0d merge.pp_merge_ctrl_reg: %h", `__FILE__, `__LINE__, merge.pp_merge_ctrl_reg);
    always @*
      $display("%s:%0d tb_mac_ack: %h nts_ack: %h pp_ack: ", `__FILE__, `__LINE__, tb_mac_ack, i_mac_tx_ack, pp_tx_ack);
  end

  //----------------------------------------------------------------
  // Benchmarking registers
  //----------------------------------------------------------------

  if (BENCHMARK) begin : benchmark
    reg [63:0] tick_counter;
    reg [63:0] old_tick_counter;
    reg [63:0] old_tick_counter_crypto;
    reg [63:0] old_tick_counter_packet;
    reg  [5:0] old_parser_state;
    reg  [4:0] old_parser_state_crypto;

    always  @(posedge i_clk or posedge i_areset)
    begin
      if (i_areset) begin
        tick_counter <= 1;
        old_tick_counter <= 1;
        old_tick_counter_crypto <= 1;
        old_tick_counter_packet <= 1;
        old_parser_state <= 0;
        old_parser_state_crypto <= 0;
      end else begin
        tick_counter <= tick_counter + 1;

        if (old_parser_state == 0)
          old_tick_counter_packet <= tick_counter;

        if (old_parser_state != dut.engine.parser.state_reg) begin
          old_tick_counter <= tick_counter;
          old_parser_state <= dut.engine.parser.state_reg;
          if (old_parser_state != 0)
            $display("%s:%0d dut.engine.parser.state_reg(%0d)->(%0d): %0d ticks", `__FILE__, `__LINE__, old_parser_state, dut.engine.parser.state_reg, tick_counter - old_tick_counter);
          if (dut.engine.parser.state_reg == 0)
            $display("%s:%0d Packet took %0d ticks to process", `__FILE__, `__LINE__, tick_counter - old_tick_counter_packet);
        end
        if (old_parser_state_crypto != dut.engine.parser.crypto_fsm_reg) begin
          old_tick_counter_crypto <= tick_counter;
          old_parser_state_crypto <= dut.engine.parser.crypto_fsm_reg;
          $display("%s:%0d dut.engine.parser.crypto_fsm_reg(%0d)->(%0d): %0d ticks", `__FILE__, `__LINE__, old_parser_state_crypto, dut.engine.parser.crypto_fsm_reg, tick_counter - old_tick_counter_crypto);
        end

      end
    end
 end

endmodule