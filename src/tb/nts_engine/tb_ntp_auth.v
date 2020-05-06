//
// Copyright (c) 2020, The Swedish Post and Telecom Authority (PTS)
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
module tb_ntp_auth;

  //----------------------------------------------------------------
  // Constants: System clock model
  //----------------------------------------------------------------

  localparam HALF_CLOCK_PERIOD = 5;
  localparam CLOCK_PERIOD = 2 * HALF_CLOCK_PERIOD;

  //----------------------------------------------------------------
  // Constants: Test configuration
  //----------------------------------------------------------------

  localparam DEBUG        = 0;
  localparam DEBUG_FSM    = 0;
  localparam DEBUG_MD5    = 0;
  localparam DEBUG_KEYMEM = 0;
  localparam DEBUG_RX     = 0;
  localparam DEBUG_RX_IP4 = 0;
  localparam DEBUG_RX_IP6 = 0;
  localparam DEBUG_TX     = 0;

  //----------------------------------------------------------------
  // Constants: Test values
  //----------------------------------------------------------------

  localparam  [31:0] TESTKEYMD5_1_KEYID = 32'hc01df00d;
  localparam [159:0] TESTKEYMD5_1_KEY   = { 32'hf00d_4444,
                                            32'hf00d_3333,
                                            32'hf00d_2222,
                                            32'hf00d_1111,
                                            32'hf00d_0000 };

  localparam [719:0] PACKET_IPV4_VANILLA_NTP = {
     128'h52_5a_2c_18_2e_80_98_03_9b_3c_1c_66_08_00_45_00,
     128'h00_4c_30_6a_40_00_40_11_38_d1_c0_a8_28_01_c0_a8,
     128'h28_14_e8_aa_00_7b_00_38_d1_af_e3_00_03_fa_00_01,
     128'h00_00_00_01_00_00_00_00_00_00_00_00_00_00_00_00,
     128'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00,
      80'h00_00_e2_1c_b6_45_c2_f8_ba_73
  };

  localparam [127:0] DUMMY_MD5_HELLO_WORLD = 128'h5eb63bbbe01eeed093cb22bb8f5acdc3 ;

  localparam [879:0] PACKET_NTP_AUTH_MD5TESTKEY1_BAD_DIGEST =
    { PACKET_IPV4_VANILLA_NTP, TESTKEYMD5_1_KEYID, DUMMY_MD5_HELLO_WORLD };

  localparam [127:0] MD5_VANILLA_NTP_MD5TESTKEY1 = 128'h24cbed6d24f8bae9af1142b860288314;
  localparam [879:0] PACKET_NTP_AUTH_MD5TESTKEY1_GOOD_DIGEST =
    { PACKET_IPV4_VANILLA_NTP, TESTKEYMD5_1_KEYID, MD5_VANILLA_NTP_MD5TESTKEY1 };

  localparam [879:0] PACKET_NTP_AUTH_WRONG_KEYID =
    { PACKET_IPV4_VANILLA_NTP, 32'h01234567, MD5_VANILLA_NTP_MD5TESTKEY1 };


  localparam [879:0] PACKET_IPV6_VANILLA_NTP = {
       128'h52_5a_2c_18_2e_80_98_03_9b_3c_1c_66_86_dd_60_0c, //  RZ,......<.f.Ý`.
       128'hae_6c_00_38_11_40_fd_75_50_2f_e2_21_dd_cf_00_00, //  ®l.8.@ýuP/â!ÝÏ..
       128'h00_00_00_00_00_01_fd_75_50_2f_e2_21_dd_cf_00_00, //  ......ýuP/â!ÝÏ..
       128'h00_00_00_00_00_02_9c_f8_00_7b_00_38_1b_7a_e3_00, //  .......ø.{.8.zã.
       128'h03_fa_00_01_00_00_00_01_00_00_00_00_00_00_00_00, //  .ú..............
       128'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00, //  ................
       112'h00_00_00_00_00_00_e2_1c_b7_0f_39_b1_7d_e3        //  ......â.·.9±}ã
  };

  // MD5( f00d4444f00d3333f00d2222f00d1111f00d0000
  //      e30003fa00010000000100000000000000000000
  //      0000000000000000000000000000000000000000
  //      e21cb70f39b17de3 )
  // = 6daa174d23dd64649080c459206b3ace
  localparam [127:0] MD5_VANILLA_IPV6_NTP_MD5TESTKEY1 = 128'h6daa174d23dd64649080c459206b3ace;

  localparam [1039:0] PACKET_IPV6_NTP_AUTH_MD5TESTKEY1_GOOD_DIGEST =
    { PACKET_IPV6_VANILLA_NTP, TESTKEYMD5_1_KEYID, MD5_VANILLA_IPV6_NTP_MD5TESTKEY1 };


  localparam  [31:0] TESTKEYMD5_2_KEYID = 32'h1;
  localparam [159:0] TESTKEYMD5_2_KEY = 160'h7e_64_41_58_74_29_30_65_4d_7a_61_7b_67_74_65_74_4d_60_5c_35; //~dAXt)0eMza{gtetM`\5
  localparam [879:0] PACKET_NTP_AUTH_MD5TESTKEY2 = {
      128'h00_1c_42_a6_21_1a_00_1c_42_71_99_e6_08_00_45_00, //  ..B¦!...Bq.æ..E.
      128'h00_60_ed_45_40_00_40_11_37_0f_0a_00_01_1d_0a_00, //  .`íE@.@.7.......
      128'h01_1c_00_7b_00_7b_00_4c_16_96_e3_00_03_fa_00_01, //  ...{.{.L..ã..ú..
      128'h00_00_00_01_00_00_00_00_00_00_00_00_00_00_00_00, //  ................
      128'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00, //  ................
      128'h00_00_d9_c1_40_f2_43_f2_a5_f6_00_00_00_01_87_5f, //  ..ÙÁ@òCò¥ö....._
      112'h94_63_f6_35_d2_4d_42_c0_07_15_a4_2e_0f_93        //  .cö5ÒMBÀ..¤...
  };

  //----------------------------------------------------------------
  // Test registers
  //----------------------------------------------------------------

  integer test_counter_fail;
  integer test_counter_success;
  reg     test_output_on_success;
  reg [31:0] test_ticks;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. Clock, reset.
  //----------------------------------------------------------------

  reg i_areset;
  reg i_clk;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. Parser control I/O.
  //----------------------------------------------------------------

  reg  i_auth_md5;
  wire o_auth_md5_ready;
  wire o_auth_md5_good;
  reg  i_auth_md5_tx;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. Received data, BE order.
  //----------------------------------------------------------------

  reg        i_rx_reset;
  reg        i_rx_valid;
  reg [63:0] i_rx_data;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. TX timestamp traffic
  //----------------------------------------------------------------

  reg          i_timestamp_wr_en;
  reg  [2 : 0] i_timestamp_ntp_header_block;
  reg [63 : 0] i_timestamp_ntp_header_data;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. Key Memory for NTP Auth.
  //----------------------------------------------------------------

  wire          o_keymem_get_key_md5;
  wire          o_keymem_get_key_sha1;
  wire [31 : 0] o_keymem_keyid;
  reg   [2 : 0] i_keymem_key_word;
  reg           i_keymem_key_valid;
  reg  [31 : 0] i_keymem_key_data;
  reg           i_keymem_ready;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. Transmit
  //----------------------------------------------------------------

  wire          o_tx_wr_en;
  wire  [6 : 0] o_tx_addr;
  wire [63 : 0] o_tx_data;

  //----------------------------------------------------------------
  // DUT, Design Under Test.
  //----------------------------------------------------------------

  ntp_auth dut (
    .i_areset         ( i_areset         ),
    .i_clk            ( i_clk            ),

    .i_auth_md5       ( i_auth_md5       ),
    .o_auth_md5_ready ( o_auth_md5_ready ),
    .o_auth_md5_good  ( o_auth_md5_good  ),
    .i_auth_md5_tx    ( i_auth_md5_tx    ),

    .i_rx_reset       ( i_rx_reset       ),
    .i_rx_valid       ( i_rx_valid       ),
    .i_rx_data        ( i_rx_data        ),

    .i_timestamp_wr_en            ( i_timestamp_wr_en            ),
    .i_timestamp_ntp_header_block ( i_timestamp_ntp_header_block ),
    .i_timestamp_ntp_header_data  ( i_timestamp_ntp_header_data  ),

    .o_keymem_get_key_md5  ( o_keymem_get_key_md5  ),
    .o_keymem_get_key_sha1 ( o_keymem_get_key_sha1 ),
    .o_keymem_keyid        ( o_keymem_keyid        ),
    .i_keymem_key_word     ( i_keymem_key_word     ),
    .i_keymem_key_valid    ( i_keymem_key_valid    ),
    .i_keymem_key_data     ( i_keymem_key_data     ),
    .i_keymem_ready        ( i_keymem_ready        ),

    .o_tx_wr_en ( o_tx_wr_en ),
    .o_tx_addr  ( o_tx_addr  ),
    .o_tx_data  ( o_tx_data  )
  );

  //----------------------------------------------------------------
  // Testbench model: TX
  //----------------------------------------------------------------

  reg test_clear_tx;
  reg [3*64-1:0] testbench_tx_ipv4 ;
  reg [3*64-1:0] testbench_tx_ipv6 ;
  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      testbench_tx_ipv4 <= { 64'hf1, 64'hf2, 64'hf3 };
      testbench_tx_ipv6 <= { 64'hf1, 64'hf2, 64'hf3 };
    end else begin
      if (test_clear_tx) begin
        testbench_tx_ipv4 <= { 64'he1, 64'he2, 64'he3 };
        testbench_tx_ipv6 <= { 64'he1, 64'he2, 64'he3 };
      end else if (o_tx_wr_en) begin
        case (o_tx_addr)
          7'h5a: testbench_tx_ipv4[2*64+:64] <= o_tx_data;
          7'h62: testbench_tx_ipv4[1*64+:64] <= o_tx_data;
          7'h6a: testbench_tx_ipv4[0*64+:64] <= o_tx_data;
          7'h6e: testbench_tx_ipv6[2*64+:64] <= o_tx_data;
          7'h76: testbench_tx_ipv6[1*64+:64] <= o_tx_data;
          7'h7e: testbench_tx_ipv6[0*64+:64] <= o_tx_data;
          default: $display("%s:%0d Unexpected! TX_WRITE[%h]=%h", `__FILE__, `__LINE__, o_tx_addr, o_tx_data);
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // Test Macros
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  `define test(testname, condition) \
    begin \
      if (!(condition)) \
        begin \
          test_counter_fail = test_counter_fail + 1; \
          $display("%s:%0d %s test failed: %s", `__FILE__, `__LINE__, testname, `"condition`"); \
        end \
      else \
        begin \
          test_counter_success = test_counter_success + 1; \
          if (test_output_on_success) $display("%s:%0d %s test success", `__FILE__, `__LINE__, testname); \
        end \
    end

  //----------------------------------------------------------------
  // Test Tasks
  //----------------------------------------------------------------

  task send_packet( input [2047:0] source, input [31:0] length );
  begin : send_packet_
    integer i;
    integer packet_ptr;
    integer source_ptr;
    reg [63:0] packet [0:31];

    `assert( (0==(length%8)) ); // byte aligned required
    for (i=0; i<16; i = i + 1) begin
      packet[i] = 64'habad_1dea_f00d_cafe;
    end
    packet_ptr = 1;
    source_ptr = (length % 64);
    case (source_ptr)
       56: packet[0] = { source[55:0],  8'h0 };
       48: packet[0] = { source[47:0], 16'h0 };
       40: packet[0] = { source[39:0], 24'h0 };
       32: packet[0] = { source[31:0], 32'h0 };
       24: packet[0] = { source[23:0], 40'h0 };
       16: packet[0] = { source[15:0], 48'h0 };
        8: packet[0] = { source[7:0],  56'h0 };
        0: packet_ptr = 0;
      default:
        `assert(0)
    endcase

    if (packet_ptr != 0)
      if (DEBUG > 2) $display("%s:%0d %h %h", `__FILE__, `__LINE__, 0, packet[0]);

    for ( i = 0; i < length/64; i = i + 1) begin
       packet[packet_ptr] = source[source_ptr+:64];
       if (DEBUG > 2)
         $display("%s:%0d %h %h", `__FILE__, `__LINE__, packet_ptr, packet[packet_ptr]);
       source_ptr = source_ptr + 64;
       packet_ptr = packet_ptr + 1;
    end

    i_rx_reset = 1;
    #( CLOCK_PERIOD );
    i_rx_reset = 0;
    #( CLOCK_PERIOD );
    for (i = packet_ptr - 1; i >= 0; i = i - 1) begin
      i_rx_valid = 1;
      i_rx_data = packet[i];
       if (DEBUG > 1)
         $display("%s:%0d send_packet transmit: %h", `__FILE__, `__LINE__, i_rx_data);
      #( CLOCK_PERIOD );
    end
    i_rx_valid = 0;
    #( CLOCK_PERIOD );
  end
  endtask

  task send_ip4_md5( input [879:0] packet );
  begin
    send_packet( { 1168'h0, packet }, 880 );
  end
  endtask

  task send_ip6_md5( input [1039:0] packet );
  begin
    send_packet( { 1008'h0, packet }, 1040 );
  end
  endtask

  task md5_busy_wait;
  begin
    while ( o_auth_md5_ready == 1'b0 ) #( CLOCK_PERIOD );
  end
  endtask

  task test_bad_md5_digest;
  begin : test_bad_md5_digest_
    reg [3*64-1:0] expect4;
    reg [3*64-1:0] expect6;

    expect4 = { 64'h0 /* CRYPTO-NAK */, 64'he2, 64'he3 };
    expect6 = { 64'he1, 64'he2, 64'he3 };

    $display("%s:%0d TEST: test_bad_md5_digest", `__FILE__, `__LINE__);

    test_clear_tx = 1;
    #( CLOCK_PERIOD );
    test_clear_tx = 0;

    send_ip4_md5(PACKET_NTP_AUTH_MD5TESTKEY1_BAD_DIGEST);

    md5_busy_wait();
    i_auth_md5 = 1;
    #( CLOCK_PERIOD );
    i_auth_md5 = 0;
    md5_busy_wait();
    `test( "test_bad_md5_digest", o_auth_md5_good === 1'b0 );

    i_auth_md5_tx = 1;
    #( CLOCK_PERIOD );
    i_auth_md5_tx = 0;
    md5_busy_wait();

    `test( "test_bad_md5_digest", expect4 === testbench_tx_ipv4 );
    `test( "test_bad_md5_digest", expect6 === testbench_tx_ipv6 );

  end
  endtask
    //`test( "test_bad_md5_digest", dut.ntp_rx_reg === PACKET_IPV4_VANILLA_NTP[383:0] );
    //`test( "test_bad_md5_digest", dut.keyid_reg === TESTKEYMD5_1_KEYID );
    //`test( "test_bad_md5_digest", dut.ntp_digest_reg === { DUMMY_MD5_HELLO_WORLD, 32'h0 } );


  task timestamp ( input [7:0] start_byte );
  begin : timestamp_
    reg [7:0] b;
    reg [63:0] data;
    integer i;
    integer j;
    b = start_byte;
    for ( i = 0; i < 6; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        data[(7-j)*8+:8] = b;
        b = b + 1;
      end
      i_timestamp_wr_en = 1;
      i_timestamp_ntp_header_block = i[2:0];
      i_timestamp_ntp_header_data = data;
      #( CLOCK_PERIOD );
    end
    i_timestamp_wr_en = 0;
    i_timestamp_ntp_header_block = 0;
    i_timestamp_ntp_header_data = 0;
    #( CLOCK_PERIOD );
  end
  endtask

  task test_good_md5_digest;
  begin : test_good_md5_digest_
    reg [3*64-1:0] expect4;
    reg [3*64-1:0] expect6;

    // MD5( f00d4444f00d3333f00d2222f00d1111f00d0000
    //      a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3
    //      b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7
    //      c8c9cacbcccdcecf ) =
    // 492bcd392808eea14c1e2d8f10f571a7

    expect4 = { TESTKEYMD5_1_KEYID, 128'h492bcd392808eea14c1e2d8f10f571a7, 32'h0 };
    expect6 = { 64'he1, 64'he2, 64'he3 };

    $display("%s:%0d TEST: test_good_md5_digest", `__FILE__, `__LINE__);

    test_clear_tx = 1;
    #( CLOCK_PERIOD );
    test_clear_tx = 0;

    send_ip4_md5( PACKET_NTP_AUTH_MD5TESTKEY1_GOOD_DIGEST );

    md5_busy_wait();
    i_auth_md5 = 1;
    #( CLOCK_PERIOD );
    i_auth_md5 = 0;
    md5_busy_wait();
    `test( "test_good_md5_digest", o_auth_md5_good === 1'b1 );

    timestamp( 8'ha0 );

    i_auth_md5_tx = 1;
    #( CLOCK_PERIOD );
    i_auth_md5_tx = 0;
    md5_busy_wait();

    `test( "test_good_md5_digest", expect4 === testbench_tx_ipv4 );
    `test( "test_good_md5_digest", expect6 === testbench_tx_ipv6 );
  end
  endtask
    //`test( "test_good_md5_digest", dut.ntp_rx_reg === PACKET_IPV4_VANILLA_NTP[383:0] );
    //`test( "test_good_md5_digest", dut.keyid_reg === TESTKEYMD5_1_KEYID );
    //`test( "test_good_md5_digest", dut.ntp_digest_reg === { MD5_VANILLA_NTP_MD5TESTKEY1, 32'h0 } );
    //`test( "test_???t", dut.ntp_digest_reg === { DUMMY_MD5_HELLO_WORLD, 32'h0 } );
    //`test( "test_???t", 0 );

  task test_wrong_keyid;
  begin : test_wrong_keyid_
    reg [3*64-1:0] expect4;
    reg [3*64-1:0] expect6;

    expect4 = { 64'h0 /* CRYPTO-NAK */, 64'he2, 64'he3 };
    expect6 = { 64'he1, 64'he2, 64'he3 };

    $display("%s:%0d TEST: test_wrong_keyid", `__FILE__, `__LINE__);

    test_clear_tx = 1;
    #( CLOCK_PERIOD );
    test_clear_tx = 0;

    send_ip4_md5( PACKET_NTP_AUTH_WRONG_KEYID );

    md5_busy_wait();
    i_auth_md5 = 1;
    #( CLOCK_PERIOD );
    i_auth_md5 = 0;
    md5_busy_wait();
    `test( "test_wrong_keyid", o_auth_md5_good === 1'b0 );

    i_auth_md5_tx = 1;
    #( CLOCK_PERIOD );
    i_auth_md5_tx = 0;
    md5_busy_wait();

    `test( "test_wrong_keyid", expect4 === testbench_tx_ipv4 );
    `test( "test_wrong_keyid", expect6 === testbench_tx_ipv6 );
  end
  endtask

  task test_ipv6_good_md5_digest;
  begin : test_good_md5_digest_
    reg [3*64-1:0] expect4;
    reg [3*64-1:0] expect6;

    // MD5( f00d4444f00d3333f00d2222f00d1111f00d0000
    //      a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3
    //      b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7
    //      c8c9cacbcccdcecf ) =
    // 492bcd392808eea14c1e2d8f10f571a7

    expect4 = { 64'he1, 64'he2, 64'he3 };
    expect6 = { TESTKEYMD5_1_KEYID, 128'h492bcd392808eea14c1e2d8f10f571a7, 32'h0 };

    $display("%s:%0d TEST: test_ipv6_good_md5_digest", `__FILE__, `__LINE__);

    test_clear_tx = 1;
    #( CLOCK_PERIOD );
    test_clear_tx = 0;

    send_ip6_md5( PACKET_IPV6_NTP_AUTH_MD5TESTKEY1_GOOD_DIGEST );

    md5_busy_wait();
    i_auth_md5 = 1;
    #( CLOCK_PERIOD );
    i_auth_md5 = 0;
    md5_busy_wait();
    `test( "test_ipv6_good_md5_digest", o_auth_md5_good === 1'b1 );

    timestamp( 8'ha0 );

    i_auth_md5_tx = 1;
    #( CLOCK_PERIOD );
    i_auth_md5_tx = 0;
    md5_busy_wait();

    `test( "test_ipv6_good_md5_digest", expect4 === testbench_tx_ipv4 );
    `test( "test_ipv6_good_md5_digest", expect6 === testbench_tx_ipv6 );
  end
  endtask

  task test_ipv4_good_md5_digest2;
  begin : test_good_md5_digest2_
    reg [3*64-1:0] expect4;
    reg [3*64-1:0] expect6;

    //MD5( 7e644158742930654d7a617b677465744d605c35
    //     a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3
    //     b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7
    //     c8c9cacbcccdcecf ) =
    // 55a80ef71927f51c8914cfcd880267e4

    expect4 = { TESTKEYMD5_2_KEYID, 128'h55a80ef71927f51c8914cfcd880267e4, 32'h0 };
    expect6 = { 64'he1, 64'he2, 64'he3 };

    $display("%s:%0d TEST: test_ipv4_good_md5_digest2", `__FILE__, `__LINE__);

    test_clear_tx = 1;
    #( CLOCK_PERIOD );
    test_clear_tx = 0;

    send_ip4_md5( PACKET_NTP_AUTH_MD5TESTKEY2 );

    md5_busy_wait();
    i_auth_md5 = 1;
    #( CLOCK_PERIOD );
    i_auth_md5 = 0;
    md5_busy_wait();
    `test( "test_ipv4_good_md5_digest", o_auth_md5_good === 1'b1 );

    timestamp( 8'ha0 );

    i_auth_md5_tx = 1;
    #( CLOCK_PERIOD );
    i_auth_md5_tx = 0;
    md5_busy_wait();

    `test( "test_ipv4_good_md5_digest", expect4 === testbench_tx_ipv4 );
    `test( "test_ipv4_good_md5_digest", expect6 === testbench_tx_ipv6 );
  end
  endtask

  //----------------------------------------------------------------
  // test_main {
  //   init
  //   run_tests
  //   print_summary
  //   exit
  // }
  //----------------------------------------------------------------

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);

    test_output_on_success = 0;

    i_areset = 1;
    i_clk = 0;
    i_auth_md5 = 0;
    i_rx_reset = 0;
    i_rx_valid = 0;
    i_rx_data = 0;
    i_timestamp_wr_en = 0;
    i_timestamp_ntp_header_block = 0;
    i_timestamp_ntp_header_data = 0;
    test_counter_fail = 0;
    test_counter_success = 0;
    test_clear_tx = 0;

    #(2 * CLOCK_PERIOD);
    i_areset = 0;
    #(2 * CLOCK_PERIOD);

    test_bad_md5_digest();
    test_good_md5_digest();
    test_wrong_keyid();
    test_ipv6_good_md5_digest();
    test_ipv4_good_md5_digest2();

    $display("Test stop: %s:%0d SUCCESS: %0d FAILURES: %0d", `__FILE__, `__LINE__, test_counter_success, test_counter_fail);
    $finish;
  end

  //----------------------------------------------------------------
  // Testbench model: Keymem
  //----------------------------------------------------------------

  reg [159:0] key;
  reg         keyfound;
  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      key <= 0;
      keyfound <= 0;
      i_keymem_key_word <= 0;
      i_keymem_key_valid <= 0;
      i_keymem_key_data <= 0;
      i_keymem_ready <= 1;
    end else begin
      i_keymem_key_valid <= 0;
      i_keymem_key_word <= 0;
      i_keymem_key_data <= 0;
      if (i_keymem_ready) begin
        key <= 0;
        keyfound <= 0;

        if (o_keymem_get_key_md5) begin
          i_keymem_ready <= 0;
          case (o_keymem_keyid)
            TESTKEYMD5_1_KEYID: { keyfound, key } <= { 1'b1, TESTKEYMD5_1_KEY };
            TESTKEYMD5_2_KEYID: { keyfound, key } <= { 1'b1, TESTKEYMD5_2_KEY };
            default: if (DEBUG_KEYMEM) $display("%s:%0d Unknown MD5 key: %h", `__FILE__, `__LINE__, o_keymem_keyid);
          endcase
        end

        if (o_keymem_get_key_sha1) $display("%s:%0d SHA1 requested, not yet implemented!?!?", `__FILE__, `__LINE__); //TODO implement

      end else begin
        if (keyfound) begin
          if (i_keymem_key_valid) begin
            i_keymem_key_valid <= 1;
            i_keymem_key_word <= i_keymem_key_word + 1;
            case (i_keymem_key_word)
              0: i_keymem_key_data <= key[ 1*32+:32] ;
              1: i_keymem_key_data <= key[ 2*32+:32] ;
              2: i_keymem_key_data <= key[ 3*32+:32] ;
              3: begin
                  i_keymem_key_data <= key[ 4*32+:32] ;
                  i_keymem_ready <= 1;
                 end
            endcase
          end else begin
            i_keymem_key_valid <= 1;
            i_keymem_key_word <= 0;
            i_keymem_key_data <= key[0*32+:32] ;
          end
        end else begin
          i_keymem_ready <= 1;
        end
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: System Clock
  //----------------------------------------------------------------

  always begin
    #(HALF_CLOCK_PERIOD) i_clk = ~i_clk;
  end

  //----------------------------------------------------------------
  // Testbench model: tick counter
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  if (i_areset)
    test_ticks <= 0;
  else
    test_ticks <= test_ticks + 1;

  `define inspect( x ) $display("%s:%0d: INSPECT: %s = %h", `__FILE__, `__LINE__, `"x`", x)

  if (DEBUG_FSM) begin
    always @*
      `inspect( dut.fsm_key_reg );

    always @*
      `inspect( dut.fsm_md5_reg );

    always @*
      `inspect( dut.fsm_txout_reg );
  end


  if (DEBUG_RX) begin
    always @*
      `inspect( dut.rx_counter_reg );

    always @*
      `inspect( dut.ntp_rx_reg );

    always @*
      `inspect( dut.ntp_digest_reg );

  end

  if (DEBUG_RX_IP4) begin
    always @*
      `inspect( dut.rx_ipv4_reg );

    always @*
      `inspect( dut.rx_ipv4_current_reg );

    always @*
      `inspect( dut.rx_ipv4_current_reg );
  end

  if (DEBUG_RX_IP6) begin
    always @*
      `inspect( dut.rx_ipv6_reg );

    always @*
      `inspect( dut.rx_ipv6_current_reg );

    always @*
      `inspect( dut.rx_ipv6_current_reg );
  end

  if (DEBUG_TX) begin
    always @*
      `inspect( dut.ntp_tx_reg );
  end


  if (DEBUG_KEYMEM) begin
    always @*
      `inspect (dut.o_keymem_keyid );

    always @*
      `inspect (dut.i_keymem_key_word );

    always @*
      `inspect (dut.i_keymem_key_valid );

    always @*
      `inspect (dut.i_keymem_ready );

  end

  if (DEBUG_MD5) begin
    always @*
      `inspect( dut.i_auth_md5 );

    always @*
      `inspect( dut.i_auth_md5_tx );

    always @*
      `inspect( dut.o_auth_md5_good );

    always @*
      `inspect( dut.o_auth_md5_ready );

    always @*
      `inspect( dut.md5_init );

    always @*
      `inspect( dut.md5_next );

    always @*
      `inspect( dut.md5_block_reg );
    always @*
      `inspect( dut.md5_digest );
  end

endmodule
