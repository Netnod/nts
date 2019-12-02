module nts_top_tb;
  localparam [11:0] API_ADDR_ENGINE_BASE        = 12'h000;
  localparam [11:0] API_ADDR_ENGINE_NAME0       = API_ADDR_ENGINE_BASE;
  localparam [11:0] API_ADDR_ENGINE_NAME1       = API_ADDR_ENGINE_BASE + 1;
  localparam [11:0] API_ADDR_ENGINE_VERSION     = API_ADDR_ENGINE_BASE + 2;

  localparam [11:0] API_ADDR_DEBUG_BASE           = 12'h180;
  localparam [11:0] API_ADDR_DEBUG_NTS_PROCESSED  = API_ADDR_DEBUG_BASE + 0;
  localparam [11:0] API_ADDR_DEBUG_NTS_BAD_COOKIE = API_ADDR_DEBUG_BASE + 2;
  localparam [11:0] API_ADDR_DEBUG_NTS_BAD_AUTH   = API_ADDR_DEBUG_BASE + 4;
  localparam [11:0] API_ADDR_DEBUG_NTS_BAD_KEYID  = API_ADDR_DEBUG_BASE + 6;
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

  localparam [7:0] BUS_READ  = 8'h55;
  localparam [7:0] BUS_WRITE = 8'hAA;

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

  localparam [2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_COOKIE=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e9dead_beefdead_beef7d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;
  localparam [2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_AUTH=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c7dead_beef;

  localparam DEBUG           = 1;
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
  reg [71:0] /* 8 + 64 */ packet [0:99];
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
    for (i=0; i<100; i=i+1) begin
      packet[i] = { 8'h00, 64'habad_1dea_f00d_cafe };
    end
    packet_ptr = 1;
    source_ptr = (length % 64);
    case (source_ptr)
       56: packet[0] = { 8'b0111_1111,  8'b0, source[55:0] };
       48: packet[0] = { 8'b0011_1111, 16'b0, source[47:0] };
       40: packet[0] = { 8'b0001_1111, 24'b0, source[39:0] };
       32: packet[0] = { 8'b0000_1111, 32'b0, source[31:0] };
       24: packet[0] = { 8'b0000_0111, 40'b0, source[23:0] };
       16: packet[0] = { 8'b0000_0011, 48'b0, source[15:0] };
        8: packet[0] = { 8'b0000_0001, 56'b0, source[7:0] };
        0: packet_ptr = 0;
      default:
        `assert(0)
    endcase

    if (packet_ptr != 0)
      if (DEBUG > 2) $display("%s:%0d %h %h", `__FILE__, `__LINE__, 0, packet[0]);

    for ( i = 0; i < length/64; i = i + 1) begin
       packet[packet_ptr] = { 8'b1111_1111, source[source_ptr+:64] };
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

  nts_top #( .ENGINES(ENGINES) ) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .i_mac_rx_data_valid(i_mac_rx_data_valid),
    .i_mac_rx_data(i_mac_rx_data),
    .i_mac_rx_bad_frame(i_mac_rx_bad_frame),
    .i_mac_rx_good_frame(i_mac_rx_good_frame),

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

    install_key_256bit( NTS_TEST_REQUEST_MASTER_KEY_ID_1, NTS_TEST_REQUEST_MASTER_KEY_1, 0 );
    install_key_256bit( NTS_TEST_REQUEST_MASTER_KEY_ID_2, NTS_TEST_REQUEST_MASTER_KEY_2, 1 );

    begin : loop
      integer i;
      for (i = 0; i < 15; i = i + 1) begin
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_COOKIE}, 2160, 0);
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2_BAD_AUTH}, 2160, 0);
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, 1);
        while (dut.dispatcher.mem_state_reg[dut.dispatcher.current_mem_reg] != 0) #10;
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
        send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, 0);
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
        send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, 0);
      end
    end
    #90000;

    //----------------------------------------------------------------
    // Human readable Debug
    //----------------------------------------------------------------

    #100 ;
    begin : fin_locals_
      reg [63:0] engine_name;
      reg [31:0] engine_version;
      reg [63:0] clock_name;
      reg [63:0] keymem_name;
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
      reg [11:0] addr;
      reg [31:0] value;
      api_read64(engine_name, API_ADDR_ENGINE_NAME0);
      api_read32(engine_version, API_ADDR_ENGINE_VERSION);
      api_read64(clock_name, API_ADDR_CLOCK_NAME0);
      api_read64(keymem_name, API_ADDR_KEYMEM_NAME0);
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
      $display("%s:%0d: *** CORE: %s %s", `__FILE__, `__LINE__, dispatcher_name, dispatcher_version);
      $display("%s:%0d: *** CORE: %s %s", `__FILE__, `__LINE__, engine_name, engine_version);
      $display("%s:%0d: *** CORE: %s", `__FILE__, `__LINE__, clock_name);
      $display("%s:%0d: *** CORE: %s", `__FILE__, `__LINE__, keymem_name);
      $display("%s:%0d: *** STATISTICS, NTS bad auth:   %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_auth);
      $display("%s:%0d: *** STATISTICS, NTS bad cookie: %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_cookie);
      $display("%s:%0d: *** STATISTICS, NTS bad key id: %0d", `__FILE__, `__LINE__, engine_stats_nts_bad_keyid);
      $display("%s:%0d: *** STATISTICS, NTS processed:  %0d", `__FILE__, `__LINE__, engine_stats_nts_processed);
      $display("%s:%0d: *** DEBUG, Errors Crypto: %0d", `__FILE__, `__LINE__, crypto_err);
      $display("%s:%0d: *** DEBUG, Errors TxBuf: %0d", `__FILE__, `__LINE__, txbuf_err);
      $display("%s:%0d: *** Dispatcher, ntp_time:            %016x", `__FILE__, `__LINE__, dispatcher_ntp_time);
      $display("%s:%0d: *** Dispatcher, systick32:           %0d", `__FILE__, `__LINE__, dispatcher_systick32);
      $display("%s:%0d: *** Dispatcher, bytes received:      %0d", `__FILE__, `__LINE__, dispatcher_counter_bytes_rx);
      $display("%s:%0d: *** Dispatcher, frame start counter: %0d", `__FILE__, `__LINE__, dispatcher_counter_frames);
      $display("%s:%0d: *** Dispatcher, good frame counter:  %0d", `__FILE__, `__LINE__, dispatcher_counter_good);
      $display("%s:%0d: *** Dispatcher, bad frame counter:   %0d", `__FILE__, `__LINE__, dispatcher_counter_bad);
      $display("%s:%0d: *** Dispatcher, dispatched counter:  %0d", `__FILE__, `__LINE__, dispatcher_counter_dispatched);
      $display("%s:%0d: *** Dispatcher, error counter:       %0d", `__FILE__, `__LINE__, dispatcher_counter_error);
      for (addr = 0; addr < 12'hFFF; addr = addr + 1) begin
        dispatcher_read32(value, addr);
        if (value != 0)
          $display("%s:%0d: *** Dispatcher[%h] = %h", `__FILE__, `__LINE__, addr, value);
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

endmodule
