//
// Copyright (c) 2016-2019, The Swedish Post and Telecom Authority (PTS)
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

  localparam ACCESS_PORT_WIDTH = 32;
  localparam ADDR_WIDTH = 7;

  localparam integer ETHIPV4_NTS_TESTPACKETS_BITS=5488;
  localparam integer ETHIPV6_NTS_TESTPACKETS_BITS=5648;

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_request1 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0c4ab40004011, 64'h759f7f0000017f00, 64'h0001ccc0101e028c, 64'h00a0230000200000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000eb3f7b35711a, 64'h50d601040024f7d4, 64'h2b2df5367ab1e4ba, 64'h70b9f848cec24727, 64'hb8da97007037b202, 64'h81f1dd7db8730204, 64'h00682b30980579b0, 64'h9bd394da6aa4b0cd, 64'h4989c356c64cb031, 64'h64c0c23fa1d61579, 64'hc7dbb78496bc1f95, 64'h27189fd0b4f5ada4, 64'h4ecf5052dcc33bab, 64'h2a90ca4c5011f2e6, 64'he64b9d6dc9dc7b5e, 64'h43011d5e3846cf4e, 64'h94ca4843e6b473eb, 64'h8adb80fc5c8366bd, 64'hfe8b69b8b5bb0304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000404, 64'h002800100010adf1, 64'h62d91c6b9894501d, 64'h4b102ce39fbc2537, 64'hd84ea25db8498682, 48'h10558dfe3707 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_request2 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0131540004011, 64'h27367f0000017f00, 64'h0001ebf2101e028c, 64'h00a0230000200000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h000009d5cdfe2669, 64'hecde010400243655, 64'h6f163ebfae3276b5, 64'haff192a6028098fe, 64'hb8983255de2cdfda, 64'ha57de4d567640204, 64'h00682b3076b5e7b6, 64'h048efa30d87888d2, 64'h709614c3cda4c841, 64'h48ce1d9ecfaf395d, 64'h7625d735009621a7, 64'h8c7a5430ca40b636, 64'haaf6fcfe8815437f, 64'hb00761607149e425, 64'h6b10b925ab96e59b, 64'hef9eccf720386318, 64'h96e02a0ba2479796, 64'hbedc0bcb1673017f, 64'hd76d0d9b05c40304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000404, 64'h0028001000109c20, 64'ha5628e63642e446f, 64'hb15ae6459ee56f39, 64'ha9cdc5d14a8506b9, 48'h1d90d7056363 };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_request1 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001c528, 64'h101e028c029f2300, 64'h0020000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h000000000000d28a, 64'h27e711a7c03d0104, 64'h002481c0511c3e5e, 64'heb916a896c27b3b6, 64'hb48178eb79d3611a, 64'hb4b009c034bb89dc, 64'h1311020400682b30, 64'h934e47ee4ef90bcd, 64'h2db5548f21b0ca97, 64'hec8115349f734c47, 64'h9256e70e1e7e9e9a, 64'h241dcf30448b2ec2, 64'h33d1393f5f256526, 64'hd61d5e790aeeeae3, 64'h73ca8cc2354afa5d, 64'h2a0f2e4b3eada37f, 64'hb2351a6e3c27fa6d, 64'he917584462e3e6e7, 64'hf6912b95cfcc63ee, 64'h9eae030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000040400280010, 64'h0010bcde5b727894, 64'hd1474b7ebb548ade, 64'hb20ce193a04aef41, 64'h91a4c7866b201516, 16'h6eaf };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_request2 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001a481, 64'h101e028c029f2300, 64'h0020000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000009006, 64'h7ae76b0e7c8f0104, 64'h002442c6f064b709, 64'h5020fe86a9a3ee40, 64'h24873e09427a8bda, 64'h42913ac7a4210292, 64'h5605020400682b30, 64'hd49a5da26e878c97, 64'h95a0e8d0be12c940, 64'h8d3335fe04d25f97, 64'h615b4b9955786ce6, 64'h8c20a76268775cc5, 64'h64444dfa8b32b61b, 64'h6902f7bc1345b6e1, 64'h55d30a580e7db691, 64'he627d22e0b0a768b, 64'h3ae3c420e8fe60bb, 64'hcd44679ddb4c66ca, 64'h192adbb6440f0f28, 64'h6ebd030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000040400280010, 64'h001077615f9af204, 64'h4b9b0bdc77ea2105, 64'h1d0b8d0db8249882, 64'h3565bbd1515ff270, 16'h1883 };


  //----------------------------------------------------------------
  // Test bench variables, wires
  //----------------------------------------------------------------

  reg                          i_areset; // async reset
  reg                          i_clk;

  wire                         o_busy;

  reg                          i_clear;
  reg                          i_process_initial;
  reg                    [7:0] i_last_word_data_valid;
  reg                   [63:0] i_data;

  reg                          i_tx_empty;
  reg                          i_tx_full;
  wire                         o_tx_clear;
  wire                         o_tx_w_en;
  wire                  [63:0] o_tx_w_data;
  wire                         o_tx_ipv4_done;
  wire                         o_tx_ipv6_done;

  reg                          i_access_port_wait;
  wire      [ADDR_WIDTH+3-1:0] o_access_port_addr;
  wire                   [2:0] o_access_port_wordsize;
  wire                         o_access_port_rd_en;
  reg                          i_access_port_rd_dv;
  reg  [ACCESS_PORT_WIDTH-1:0] i_access_port_rd_data;

  wire                         o_timestamp_record_receive_timestamp;
  wire                         o_timestamp_transmit; //parser signal packet transmit OK
  wire                [63 : 0] o_timestamp_origin_timestamp;
  wire                [ 2 : 0] o_timestamp_version_number;
  wire                [ 7 : 0] o_timestamp_poll;

  wire                  [3:0] o_keymem_key_word;
  wire                        o_keymem_get_key_with_id;
  wire                 [31:0] o_keymem_server_id;
  reg                         i_keymem_key_length;
  reg                         i_keymem_key_valid;
  reg                         i_keymem_ready;

  wire                        o_detect_unique_identifier;
  wire                        o_detect_nts_cookie;
  wire                        o_detect_nts_cookie_placeholder;
  wire                        o_detect_nts_authenticator;
  
  reg                 [3 : 0] detect_bits;

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
    output    [3:0] detect_bits
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
        0: i_last_word_data_valid  = 8'b11111111; //all bytes valid
        1: i_last_word_data_valid  = 8'b00000001; //last byte valid
        2: i_last_word_data_valid  = 8'b00000011;
        3: i_last_word_data_valid  = 8'b00000111;
        4: i_last_word_data_valid  = 8'b00001111;
        5: i_last_word_data_valid  = 8'b00011111;
        6: i_last_word_data_valid  = 8'b00111111;
        7: i_last_word_data_valid  = 8'b01111111;
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
        detect_bits = { o_detect_unique_identifier, o_detect_nts_cookie, o_detect_nts_cookie_placeholder, o_detect_nts_authenticator};
        if (verbose_output >= 4) $display("%s:%0d detect_bits=%b (%h)", `__FILE__, `__LINE__, detect_bits, detect_bits);
        #10;
      end

    end
  endtask

  //----------------------------------------------------------------
  // Test bench Design Under Test (DUT) instantiation
  //----------------------------------------------------------------

  nts_parser_ctrl #(.ACCESS_PORT_WIDTH(ACCESS_PORT_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset), // async reset
    .i_clk(i_clk),

    .o_busy(o_busy),

    .i_clear(i_clear),
    .i_process_initial(i_process_initial),
    .i_last_word_data_valid(i_last_word_data_valid),
    .i_data(i_data),

    .i_tx_empty(i_tx_empty),
    .i_tx_full(i_tx_full),
    .o_tx_clear(o_tx_clear),
    .o_tx_w_en(o_tx_w_en),
    .o_tx_w_data(o_tx_w_data),
    .o_tx_ipv4_done(o_tx_ipv4_done),
    .o_tx_ipv6_done(o_tx_ipv6_done),

    .i_access_port_wait(i_access_port_wait),
    .o_access_port_addr(o_access_port_addr),
    .o_access_port_wordsize(o_access_port_wordsize),
    .o_access_port_rd_en(o_access_port_rd_en),
    .i_access_port_rd_dv(i_access_port_rd_dv),
    .i_access_port_rd_data(i_access_port_rd_data),

    .o_keymem_key_word(o_keymem_key_word),
    .o_keymem_get_key_with_id(o_keymem_get_key_with_id),
    .o_keymem_server_id(o_keymem_server_id),
    .i_keymem_key_length(i_keymem_key_length),
    .i_keymem_key_valid(i_keymem_key_valid),
    .i_keymem_ready(i_keymem_ready),

    .o_timestamp_record_receive_timestamp(o_timestamp_record_receive_timestamp),
    .o_timestamp_transmit(o_timestamp_transmit), //parser signal packet transmit OK
    .o_timestamp_origin_timestamp(o_timestamp_origin_timestamp),
    .o_timestamp_version_number(o_timestamp_version_number),
    .o_timestamp_poll(o_timestamp_poll),

    .o_detect_unique_identifier(o_detect_unique_identifier),
    .o_detect_nts_cookie(o_detect_nts_cookie),
    .o_detect_nts_cookie_placeholder(o_detect_nts_cookie_placeholder),
    .o_detect_nts_authenticator(o_detect_nts_authenticator)
  );
  
  //----------------------------------------------------------------
  // Test bench code
  //----------------------------------------------------------------

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

    #10
    i_areset = 0;

    //----------------------------------------------------------------
    // IPv4 Requests
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv4 requests", `__FILE__, `__LINE__);
    #20
    send_packet({60048'b0, nts_packet_ipv4_request1}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    $display("%s:%0d detect_bits=%b", `__FILE__, `__LINE__, detect_bits);
    `assert(detect_bits == 'b1111);

    send_packet({60048'b0, nts_packet_ipv4_request2}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    //----------------------------------------------------------------
    // IPv6 Request
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv6 requests", `__FILE__, `__LINE__);

    send_packet({59888'b0, nts_packet_ipv6_request1}, ETHIPV6_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    send_packet({59888'b0, nts_packet_ipv6_request2}, ETHIPV6_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  always @(posedge i_clk, posedge i_areset)
  begin
    if (i_areset) begin
      keymem_state <= 0;
      i_keymem_ready <= 1;
      i_keymem_key_valid <= 0;
      i_keymem_key_length <= 0;
    end else if (keymem_state) begin
      keymem_state <= 0;
      i_keymem_ready <= 1;
      i_keymem_key_valid <= 1;
      i_keymem_key_length <= 1;
    end else if (o_keymem_get_key_with_id) begin
      keymem_state <= 1;
      i_keymem_ready <= 0;
      i_keymem_key_valid <= 0;
      i_keymem_key_length <= 0;
    end
  end

  always @(posedge i_clk)
  begin
    if (verbose_output >= 4) $display("%s:%0d o_access_port_rd_en=%h", `__FILE__, `__LINE__, o_access_port_rd_en);
    if (i_areset) begin
      ;
    end else if (o_access_port_rd_en) begin : vars
      reg [ADDR_WIDTH-1:0] addr_hi;
      reg            [2:0] addr_lo;
      reg           [87:0] tmp;
      reg           [63:0] tmp_hi;
      reg           [63:0] tmp_lo;
      `assert(o_access_port_wordsize == 2);
      addr_hi = o_access_port_addr[ADDR_WIDTH+3-1:3];
      addr_lo = o_access_port_addr[2:0];
      tmp_hi = rx_buf[addr_hi];
      tmp_lo = rx_buf[addr_hi+1];
      tmp = { tmp_hi, tmp_lo[63:40] };
      case (addr_lo)
        0: i_access_port_rd_data = tmp[87:56];
        1: i_access_port_rd_data = tmp[79:48];
        2: i_access_port_rd_data = tmp[71:40];
        3: i_access_port_rd_data = tmp[63:32];
        4: i_access_port_rd_data = tmp[55:24];
        5: i_access_port_rd_data = tmp[47:16];
        6: i_access_port_rd_data = tmp[39:8];
        7: i_access_port_rd_data = tmp[31:0];
        default: begin `assert(0); end
      endcase
      i_access_port_rd_dv = 1;
      if (verbose_output >= 4) $display("%s:%0d i_access_port_rd_data=%h", `__FILE__, `__LINE__, i_access_port_rd_data);
    end else begin
      i_access_port_rd_data = 32'hXXXX_XXXX;
      i_access_port_rd_dv = 0;
    end
  end

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
