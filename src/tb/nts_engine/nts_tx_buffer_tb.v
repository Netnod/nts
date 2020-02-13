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

module nts_tx_buffer_tb #( parameter integer verbose_output = 'h5);

  //----------------------------------------------------------------
  // Test bench constants
  //----------------------------------------------------------------

  localparam ADDR_WIDTH = 12;

  localparam integer ETHIPV4_NTS_TESTPACKETS_BITS=5488;
  localparam integer ETHIPV6_NTS_TESTPACKETS_BITS=5648;

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_request1 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0c4ab40004011, 64'h759f7f0000017f00, 64'h0001ccc0101e028c, 64'h00a0230000200000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000eb3f7b35711a, 64'h50d601040024f7d4, 64'h2b2df5367ab1e4ba, 64'h70b9f848cec24727, 64'hb8da97007037b202, 64'h81f1dd7db8730204, 64'h00682b30980579b0, 64'h9bd394da6aa4b0cd, 64'h4989c356c64cb031, 64'h64c0c23fa1d61579, 64'hc7dbb78496bc1f95, 64'h27189fd0b4f5ada4, 64'h4ecf5052dcc33bab, 64'h2a90ca4c5011f2e6, 64'he64b9d6dc9dc7b5e, 64'h43011d5e3846cf4e, 64'h94ca4843e6b473eb, 64'h8adb80fc5c8366bd, 64'hfe8b69b8b5bb0304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000404, 64'h002800100010adf1, 64'h62d91c6b9894501d, 64'h4b102ce39fbc2537, 64'hd84ea25db8498682, 48'h10558dfe3707 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_request2 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0131540004011, 64'h27367f0000017f00, 64'h0001ebf2101e028c, 64'h00a0230000200000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h000009d5cdfe2669, 64'hecde010400243655, 64'h6f163ebfae3276b5, 64'haff192a6028098fe, 64'hb8983255de2cdfda, 64'ha57de4d567640204, 64'h00682b3076b5e7b6, 64'h048efa30d87888d2, 64'h709614c3cda4c841, 64'h48ce1d9ecfaf395d, 64'h7625d735009621a7, 64'h8c7a5430ca40b636, 64'haaf6fcfe8815437f, 64'hb00761607149e425, 64'h6b10b925ab96e59b, 64'hef9eccf720386318, 64'h96e02a0ba2479796, 64'hbedc0bcb1673017f, 64'hd76d0d9b05c40304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000404, 64'h0028001000109c20, 64'ha5628e63642e446f, 64'hb15ae6459ee56f39, 64'ha9cdc5d14a8506b9, 48'h1d90d7056363 };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_request1 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001c528, 64'h101e028c029f2300, 64'h0020000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h000000000000d28a, 64'h27e711a7c03d0104, 64'h002481c0511c3e5e, 64'heb916a896c27b3b6, 64'hb48178eb79d3611a, 64'hb4b009c034bb89dc, 64'h1311020400682b30, 64'h934e47ee4ef90bcd, 64'h2db5548f21b0ca97, 64'hec8115349f734c47, 64'h9256e70e1e7e9e9a, 64'h241dcf30448b2ec2, 64'h33d1393f5f256526, 64'hd61d5e790aeeeae3, 64'h73ca8cc2354afa5d, 64'h2a0f2e4b3eada37f, 64'hb2351a6e3c27fa6d, 64'he917584462e3e6e7, 64'hf6912b95cfcc63ee, 64'h9eae030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000040400280010, 64'h0010bcde5b727894, 64'hd1474b7ebb548ade, 64'hb20ce193a04aef41, 64'h91a4c7866b201516, 16'h6eaf };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_request2 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001a481, 64'h101e028c029f2300, 64'h0020000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000009006, 64'h7ae76b0e7c8f0104, 64'h002442c6f064b709, 64'h5020fe86a9a3ee40, 64'h24873e09427a8bda, 64'h42913ac7a4210292, 64'h5605020400682b30, 64'hd49a5da26e878c97, 64'h95a0e8d0be12c940, 64'h8d3335fe04d25f97, 64'h615b4b9955786ce6, 64'h8c20a76268775cc5, 64'h64444dfa8b32b61b, 64'h6902f7bc1345b6e1, 64'h55d30a580e7db691, 64'he627d22e0b0a768b, 64'h3ae3c420e8fe60bb, 64'hcd44679ddb4c66ca, 64'h192adbb6440f0f28, 64'h6ebd030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000040400280010, 64'h001077615f9af204, 64'h4b9b0bdc77ea2105, 64'h1d0b8d0db8249882, 64'h3565bbd1515ff270, 16'h1883 };

  localparam [2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;

  //----------------------------------------------------------------
  // Test bench variables, wires
  //----------------------------------------------------------------

  reg         i_areset; // async reset
  reg         i_clk;

  wire        o_error;
  wire        o_busy;

  wire        o_dispatch_tx_packet_available;
  reg         i_dispatch_tx_packet_read;
  wire        o_dispatch_tx_fifo_empty;
  reg         i_dispatch_tx_fifo_rd_en;
  wire [63:0] o_dispatch_tx_fifo_rd_data;
  wire  [3:0] o_dispatch_tx_bytes_last_word;

  reg         i_parser_clear;
  reg         i_parser_update_length; //TODO tests on this?

  reg         i_read_en; //TODO read tests?
  wire [63:0] o_read_data;

  reg                     i_sum_reset;
  reg              [15:0] i_sum_reset_value;
  reg                     i_sum_en;
  reg  [ADDR_WIDTH+3-1:0] i_sum_bytes;
  wire             [15:0] o_sum;
  wire                    o_sum_done;

  reg         i_write_en;
  reg [63:0]  i_write_data;

  reg                  i_address_internal;
  reg [ADDR_WIDTH-1:0] i_address_hi;
  reg            [2:0] i_address_lo;


  reg         i_parser_ipv4_done;
  reg         i_parser_ipv6_done;

  wire        o_parser_current_memory_full;
  wire        o_parser_current_empty;

  reg           rx_start;
  reg     [1:0] rx_state;
  reg    [12:0] rx_count;
  reg  [6299:0] rx_buf;
 //reg    [63:0] tx_buf [0:99];

  //----------------------------------------------------------------
  // Test bench macros
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  //----------------------------------------------------------------
  // Test bench tasks
  //----------------------------------------------------------------

  task wait_busy;
  while(o_busy) #10;
  endtask

  task write_packet (
    input [65535:0] source,
    input    [31:0] length
  );
    integer i;
    integer packet_ptr;
    integer source_ptr;
    reg [63:0] packet [0:99];
    begin
      wait_busy();
      if (verbose_output > 0) $display("%s:%0d Send packet!", `__FILE__, `__LINE__);
      `assert( (0==(length%8)) ); // byte aligned required
      for (i=0; i<100; i=i+1) begin
        packet[i] = 64'habad_1dea_f00d_cafe;
      end
      //for (i=0; i<100; i=i+1) begin
      //  tx_buf[i] = 64'hXXXX_XXXX_XXXX_XXXX;
      //end
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
      i_address_internal = 1;
      for (i=0; i<length/64; i=i+1) begin
         packet[packet_ptr] = source[source_ptr+:64];
         if (verbose_output > 2) $display("%s:%0d length=%0d packet_ptr=%0d packet=%h", `__FILE__, `__LINE__, length, packet_ptr, packet[packet_ptr]);
         source_ptr = source_ptr + 64;
         packet_ptr = packet_ptr + 1;
      end

      #10 ;
/*
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
*/
      //`assert(i_process_initial == 'b0);
      //i_clear = 'b1;
      #10;
      //i_clear = 'b0;


      begin : waky_waky
        integer i;
        i = 0;
        while (o_parser_current_empty == 'b0) begin
          #10 ;
          i = i + 1;
          `assert(i < 10000);
        end
      end


      source_ptr = 0;
      #10
      for (packet_ptr=packet_ptr-1; packet_ptr>=0; packet_ptr=packet_ptr-1) begin
        if (verbose_output >= 3) $display("%s:%0d packet_ptr[%0d]=%h", `__FILE__, `__LINE__, packet_ptr, packet[packet_ptr]);
        i_write_en         = 1;
        i_write_data[63:0] = packet[packet_ptr];
        //tx_buf[source_ptr] = packet[packet_ptr];
        source_ptr = source_ptr + 1;
        #10 ;
        //i_process_initial = 'b1; //1 cycle delayed
      end
      i_write_en = 0;
      #10 ;
      //i_process_initial = 'b0; //1 cycle delayed
    end
  endtask

  task transmit_packet( input ipv6 );
    begin
      wait_busy();
      if (ipv6) begin
        i_parser_ipv6_done = 1;
        #10 ;
        i_parser_ipv6_done = 0;
        #10 ;
      end else begin
        i_parser_ipv4_done = 1;
        #10 ;
        i_parser_ipv4_done = 0;
        #10 ;
      end
    end
  endtask

  task send_packet (
    input [65535:0] source,
    input    [31:0] length,
    input           ipv6
  );
    begin
      wait_busy();
      write_packet ( source, length );
      transmit_packet ( ipv6 );
    end
  endtask

  task receive_packet;
  begin : recieve_packets_locals
    integer i;
    reg [63:0] rx_block;
    $display("%s:%0d receive_packet begin", `__FILE__, `__LINE__);
    `assert((rx_state == 0) || (rx_state == 3));
    rx_start = 1;
    #10 ;
    `assert(rx_state == 1);
    rx_start = 0;
    #10 ;
    i = 0;
    while (rx_state != 3) begin
      `assert(i < 10000);
      #10 i = i + 1;
    end
    if (verbose_output >= 2) begin
      $display("%s:%0d rx_count=%h", `__FILE__, `__LINE__, rx_count);
      for ( i = {19'h0, rx_count } - 1; i>=0 ; i = i - 1)
      begin
        rx_block = rx_buf[i*64+:64];
        $display("%s:%0d rx_buf[%2d*64+:64]=%h", `__FILE__, `__LINE__, i, rx_block);
      end
      $display("%s:%0d rx_buf=%h", `__FILE__, `__LINE__, rx_buf);
    end
    $display("%s:%0d receive_packet end", `__FILE__, `__LINE__);
  end
  endtask

  task write( input [ADDR_WIDTH+3-1:0] addr, input [63:0] data );
  begin
    $display("%s:%0d write(%h, %h)", `__FILE__, `__LINE__, addr, data);
    i_address_internal = 0;
    { i_address_hi, i_address_lo } = addr;
    i_write_en = 1;
    i_write_data = data;
    #10;
    i_address_hi = 0;
    i_address_lo = 0;
    i_write_en   = 0;
    i_write_data = 0;
    wait_busy();
  end
  endtask

  task init_tx( input [ADDR_WIDTH+3-1:0] addr, input [63:0] pattern, input integer blocks);
  integer i;
  reg [ADDR_WIDTH+3-1:0] a;
  begin
    a = addr;
    for (i = 0; i < blocks; i = i + 1) begin
      write(a, pattern);
      a = a + 8;
    end
  end
  endtask


  task read( input [ADDR_WIDTH+3-1:0] addr, output [63:0] data );
  begin
    i_address_internal = 0;
    { i_address_hi, i_address_lo } = addr;
    i_read_en = 1;
    #10;
    i_address_hi = 0;
    i_address_lo = 0;
    i_read_en   = 0;
    data = o_read_data;
  end
  endtask

  task read_and_hexdump( input [ADDR_WIDTH+3-1:0] addr, input integer blocks );
  integer i;
  reg [ADDR_WIDTH+3-1:0] a;
  reg [63:0] data;
  begin
    a = addr;
    for (i = 0; i < blocks; i = i + 1) begin
      read(a, data);
      $display("%s:%0d hexdump[%h]: %h", `__FILE__, `__LINE__, a, data);
      a = a + 8;
    end
  end
  endtask

  task checksum( input [ADDR_WIDTH+3-1:0] addr, input [ADDR_WIDTH+3-1:0] bytes );
  begin
    checksum_reset(0);
    checksum_without_reset(addr, bytes);
  end
  endtask

  task checksum_reset(input [15:0] reset_value);
  begin
    i_sum_reset = 1;
    i_sum_reset_value = reset_value;
    #10;
    i_sum_reset = 0;
    i_sum_reset_value = 0;
  end
  endtask

  task checksum_without_reset( input [ADDR_WIDTH+3-1:0] addr, input [ADDR_WIDTH+3-1:0] bytes );
  begin
    $display("%s:%0d checksum_without_reset(%h,%h)", `__FILE__, `__LINE__, addr, bytes);
    i_address_internal = 0;
    { i_address_hi, i_address_lo } = addr;
    i_sum_en = 1;
    i_sum_bytes = bytes;
    #20;
    i_address_hi = 0;
    i_address_lo = 0;
    i_sum_en     = 0;
    i_sum_bytes  = 0;
    while (o_sum_done === 1'b0) #10;
    `assert(o_sum_done === 1'b1);
  end
  endtask

  //----------------------------------------------------------------
  // Test bench Design Under Test (DUT) instantiation
  //----------------------------------------------------------------

  nts_tx_buffer #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset), // async reset
    .i_clk(i_clk),

    .o_busy(o_busy),
    .o_error(o_error),

    .o_dispatch_tx_packet_available(o_dispatch_tx_packet_available),
    .i_dispatch_tx_packet_read(i_dispatch_tx_packet_read),
    .o_dispatch_tx_fifo_empty(o_dispatch_tx_fifo_empty),
    .i_dispatch_tx_fifo_rd_en(i_dispatch_tx_fifo_rd_en),
    .o_dispatch_tx_fifo_rd_data(o_dispatch_tx_fifo_rd_data),
    .o_dispatch_tx_bytes_last_word(o_dispatch_tx_bytes_last_word),

    .i_parser_clear(i_parser_clear),
    .i_parser_update_length(i_parser_update_length),
    .i_read_en(i_read_en),
    .o_read_data(o_read_data),
    .i_sum_reset(i_sum_reset),
    .i_sum_reset_value(i_sum_reset_value),
    .i_sum_en(i_sum_en),
    .i_sum_bytes(i_sum_bytes),
    .o_sum(o_sum),
    .o_sum_done(o_sum_done),
    .i_write_en(i_write_en),
    .i_write_data(i_write_data),

    .i_address_internal(i_address_internal),
    .i_address_hi(i_address_hi),
    .i_address_lo(i_address_lo),

    .i_parser_ipv4_done(i_parser_ipv4_done),
    .i_parser_ipv6_done(i_parser_ipv6_done),

    .o_parser_current_memory_full(o_parser_current_memory_full),
    .o_parser_current_empty(o_parser_current_empty)
  );

  //----------------------------------------------------------------
  // Test bench code
  //----------------------------------------------------------------

  //Validates IPv4 checksum calculation for with different offsets to check stability of implementations.
  task ipv4_header_checksum_different_offsets;
  begin
    init_tx(0, 64'hF0F0_F0F0_F0F0_F0F0, 6);
    read_and_hexdump(0, 5);
    //Example IP header (with 0 checksum)
    write(7+0*8, 64'h4500_0073_0000_4000);
    write(7+1*8, 64'h4011_0000_c0a8_0001);
    write(7+2*8, 64'hc0a8_00c7_0035_e97c);
    write(7+3*8, 64'h005f_279f_1e4b_8180);
    read_and_hexdump(7, 4);
    checksum(7, 20);
    `assert(o_sum == 'h479E);

    init_tx(0, 64'hE0E0_E0E0_E0E0_E0E0, 6);
    read_and_hexdump(0, 5);
    write(2+0*8, 64'h4500_0073_0000_4000);
    write(2+1*8, 64'h4011_0000_c0a8_0001);
    write(2+2*8, 64'hc0a8_00c7_0035_e97c);
    write(2+3*8, 64'h005f_279f_1e4b_8180);
    read_and_hexdump(2, 4);
    checksum(2, 20);
    `assert(o_sum == 'h479E);

    init_tx(0, 64'hD0D0_D0D0_D0D0_D0D0, 6);
    read_and_hexdump(0, 5);
    write(1+0*8, 64'h4500_0073_0000_4000);
    write(1+1*8, 64'h4011_0000_c0a8_0001);
    write(1+2*8, 64'hc0a8_00c7_0035_e97c);
    write(1+3*8, 64'h005f_279f_1e4b_8180);
    read_and_hexdump(1, 4);
    checksum(1, 20);
    `assert(o_sum == 'h479E);

    init_tx(0, 64'hC0C0_C0C0_C0C0_C0C0, 6);
    read_and_hexdump(0, 5);
    write(0+0*8, 64'h4500_0073_0000_4000);
    write(0+1*8, 64'h4011_0000_c0a8_0001);
    write(0+2*8, 64'hc0a8_00c7_0035_e97c);
    write(0+3*8, 64'h005f_279f_1e4b_8180);
    read_and_hexdump(0, 4);
    checksum(0, 20);
    `assert(o_sum == 'h479E);
  end
  endtask

  //Validates a IPv4 header with valid checksum. Also tries different lengths to check that code is stable.
  task ipv4_header_checksum_ffff;
  begin
    //Example IP header (with valid checksum)
    init_tx(0, 64'hC0C0_C0C0_C0C0_C0C0, 6);
    read_and_hexdump(0, 5);
    write(3+0*8, 64'h4500_0073_0000_4000);
    write(3+1*8, 64'h4011_b861_c0a8_0001);
    write(3+2*8, 64'hc0a8_00c7_0035_e97c);
    write(3+3*8, 64'h005f_279f_1e4b_8180);

    //Validate with correct length should yield ffff (0) because checksum OK.
    checksum(3, 20);
    `assert(o_sum === 'hffff); //FFFF = checksum OK (inverts to zero);

    checksum(3, 0); //sanity check: do not hang on empty checksum operations.
    `assert(o_sum === 'h0000); //sanity check: empty checks should return zero

    checksum(3, 1);
    `assert(o_sum == 'h4500);

    checksum(3, 2);
    `assert(o_sum == 'h4500);

    checksum(3, 3);
    `assert(o_sum == 'h4500);

    checksum(3, 4);
    `assert(o_sum == 'h4573);

    checksum(3, 5);
    `assert(o_sum == 'h4573);

    checksum(3, 6);
    `assert(o_sum == 'h4573);

    checksum(3, 7);
    `assert(o_sum == 'h8573);

    checksum(3, 8);
    `assert(o_sum == 'h8573);

    checksum(3, 9);
    `assert(o_sum == 'hc573);

    checksum(3, 10);
    `assert(o_sum == 'hc584);

    checksum(3, 11);
    `assert(o_sum == 'h7d85);

    checksum(3, 12);
    `assert(o_sum == 'h7de6);

    checksum(3, 13);
    `assert(o_sum == 'h3de7);

    checksum(3, 14);
    `assert(o_sum == 'h3e8f);

    checksum(3, 15);
    `assert(o_sum == 'h3e8f);

    checksum(3, 16);
    `assert(o_sum == 'h3e90);

    checksum(3, 17);
    `assert(o_sum == 'hfe90);

    checksum(3, 18);
    `assert(o_sum == 'hff38);

    checksum(3, 19);
    `assert(o_sum == 'hff38);

    checksum(3, 20);
    `assert(o_sum == 'hffff);

    checksum(3, 21);
    `assert(o_sum == 'hffff);

    checksum(3, 22);
    `assert(o_sum == 'h0035);

    checksum(3, 23);
    `assert(o_sum == 'he935);

    checksum(3, 24);
    `assert(o_sum == 'he9b1);

    checksum(3, 25);
    `assert(o_sum == 'he9b1);

    checksum(3, 26);
    `assert(o_sum == 'hea10);

    checksum(3, 27);
    `assert(o_sum == 'h1111);

    checksum(3, 28);
    `assert(o_sum == 'h11b0);

    checksum(3, 29);
    `assert(o_sum == 'h2fb0);

    checksum(3, 30);
    `assert(o_sum == 'h2ffb);

    checksum(3, 31);
    `assert(o_sum == 'hb0fb);

    checksum(3, 32);
    `assert(o_sum == 'hb17b);
  end
  endtask

  task test_udp_checksum;
  begin
    write(14+0*8, 64'h4500_004a_6581_4000);
    write(14+1*8, 64'h4011_6eca_c0a8_0065);
    write(14+2*8, 64'h44a8_60a2_8206_0035);
    write(14+3*8, 64'h0036_0000_79d0_0100);
    write(14+4*8, 64'h0001_0000_0000_0000);
    write(14+5*8, 64'h0331_3135_0331_3031);
    write(14+6*8, 64'h0331_3938_0331_3332);
    write(14+7*8, 64'h0769_6e2d_6164_6472);
    write(14+8*8, 64'h0461_7270_6100_000C);
    write(14+9*8, 64'h0001_F0F0_F0F0_F0F0); // 0001 followed by garbage
    checksum_reset('h11);
    checksum_without_reset(14+12, 4+4); //14 = eth overhead, 12 = ipv4 ports offset. 4+4 = ipv4 addresses
    checksum_without_reset(14+20+2+2, 2); //14 = eth overhead, 20 = ipv4 overhead
    checksum_without_reset(14+20, 'h0036); //34: udp data offset
    `assert(o_sum == 'h51C3);
    write(14+0*8, 64'h4500_004a_6581_4000);
    write(14+1*8, 64'h4011_6eca_c0a8_0065);
    write(14+2*8, 64'h44a8_60a2_8206_0035);
    write(14+3*8, 64'h0036_AE3C_79d0_0100); //AE3C = NOT 51C3
    write(14+4*8, 64'h0001_0000_0000_0000);
    write(14+5*8, 64'h0331_3135_0331_3031);
    write(14+6*8, 64'h0331_3938_0331_3332);
    write(14+7*8, 64'h0769_6e2d_6164_6472);
    write(14+8*8, 64'h0461_7270_6100_000C);
    write(14+9*8, 64'h0001_F0F0_F0F0_F0F0); // 0001 followed by garbage
    checksum_reset('h11);
    checksum_without_reset(14+12, 4+4); //14 = eth overhead, 12 = ipv4 ports offset. 4+4 = ipv4 addresses
    checksum_without_reset(14+20+2+2, 2); //14 = eth overhead, 20 = ipv4 overhead
    checksum_without_reset(14+20, 'h0036); //34: udp data offset
    `assert(o_sum == 'hffff);
  end
  endtask

  task write128( input [ADDR_WIDTH+3-1:0] addr, input [127:0] data);
  begin
    write(addr, data[127:64]);
    write(addr+8, data[63:0]);
  end
  endtask

  task test_udp_checksum_nts;
  begin : test_udp
    reg [15:0] csum;
    // a real NTS packet, from a tcpdump hexdump.
    write128(  'h0000, 128'hd8cb8a36ac3c000000000bb208004500); // ...6.<........E.
    write128(  'h0010, 128'h03d884df40003c11c469c23acad350d8); // ....@.<..i.:..P.
    write128(  'h0020, 128'h13e6101bc3bb03c4bab8240200e70000); // ..........$.....
    write128(  'h0030, 128'h000100000003c23aca14e1d017b0fc6c); // .......:.......l
    write128(  'h0040, 128'h62eed534eec50f124076e1d017b2c4f0); // b..4....@v......
    write128(  'h0050, 128'h1176e1d017b2c4ff4296010400244c0a); // .v......B....$L.
    write128(  'h0060, 128'h480f8eb6b35c0ab34d80079eacd63b0a); // H....\..M.....;.
    write128(  'h0070, 128'h5d5eedad8f7f80ade885725e47490404); // ]^........r^GI..
    write128(  'h0080, 128'h036800100350fbf5474b92f40c831c2b); // .h...P..GK.....+
    write128(  'h0090, 128'hb74475a5c559f9e2fa626df5d35e055d); // .Du..Y...bm..^.]
    write128(  'h00a0, 128'h389447e61aa6a59a595f1d242d2b3346); // 8.G.....Y_.$-+3F
    write128(  'h00b0, 128'h6cb38a14195c242ade1e140b04a09ec5); // l....\$*........
    write128(  'h00c0, 128'hd41a1380c2ca2a8be6a8905e271e5796); // ......*....^'.W.
    write128(  'h00d0, 128'hdc40bdc735b3c839ec787c95b69b9311); // .@..5..9.x|.....
    write128(  'h00e0, 128'ha9c04c59d701504cc3834c7fe18acc60); // ..LY..PL..L....`
    write128(  'h00f0, 128'hd2ec2c6d5a6d4baa861c087e47db49b7); // ..,mZmK....~G.I.
    write128(  'h0100, 128'hf23f77e67be538a6851452be8cf646b8); // .?w.{.8...R...F.
    write128(  'h0110, 128'hd1f10c4c9329c11b9f1cd48eec0f8f39); // ...L.).........9
    write128(  'h0120, 128'hc2aca7c2ab53b431cfb06fb43943b7a7); // .....S.1..o.9C..
    write128(  'h0130, 128'hda448427c20b8fdbde0dc783895156dc); // .D.'.........QV.
    write128(  'h0140, 128'h5bd056cfd41ed1b748eba5b563ff4a2c); // [.V.....H...c.J,
    write128(  'h0150, 128'h0542e9e2ae802688f452f2f3420358df); // .B....&..R..B.X.
    write128(  'h0160, 128'hb6b5eae1d69b74a1997ff2cc4247ff1b); // ......t.....BG..
    write128(  'h0170, 128'h898912d5e8b6e26ad56e90d62dc871fa); // .......j.n..-.q.
    write128(  'h0180, 128'hc24ae1839ca04a5bbb767c8144aac49a); // .J....J[.v|.D...
    write128(  'h0190, 128'h717328465ee64e65566fe4dc54917898); // qs(F^.NeVo..T.x.
    write128(  'h01a0, 128'hbea220307cdaee3eafdab922ca424990); // ...0|..>...".BI.
    write128(  'h01b0, 128'h772edb678827ee89098b34678e563b0a); // w..g.'....4g.V;.
    write128(  'h01c0, 128'had5e174fc7316de681f52e009515f376); // .^.O.1m........v
    write128(  'h01d0, 128'h611dd99b49bc687424a8ea2d5f2bd06b); // a...I.ht$..-_+.k
    write128(  'h01e0, 128'h557d7bed55354799c767278cc1c65767); // U}{.U5G..g'...Wg
    write128(  'h01f0, 128'h30f6868f841539ff2cea3c16bf781c73); // 0.....9.,.<..x.s
    write128(  'h0200, 128'he224497a6bc67f9782a6369137ed378c); // .$Izk.....6.7.7.
    write128(  'h0210, 128'h9fd15354a55499d39e346d8e911220d0); // ..ST.T...4m.....
    write128(  'h0220, 128'h76f21cd70e662dd8502e5efc70a797b5); // v....f-.P.^.p...
    write128(  'h0230, 128'ha4f5e209a377863470b518e46ad9fcb4); // .....w.4p...j...
    write128(  'h0240, 128'hc521ea5ac401ccbbfc8dcbbcf242b0d4); // .!.Z.........B..
    write128(  'h0250, 128'hd68e1a946622f748cd17e1ac1ba46306); // ....f".H......c.
    write128(  'h0260, 128'hadf7c078b854899092bf13953f9a22c9); // ...x.T......?.".
    write128(  'h0270, 128'h4001bfd63f984690978e1be982232f4c); // @...?.F......#/L
    write128(  'h0280, 128'h176cd524974068984a755881206bca1a); // .l.$.@h.JuX..k..
    write128(  'h0290, 128'hba59c20b87ea197058e399892217450f); // .Y.....pX...".E.
    write128(  'h02a0, 128'hb84d8af8299e6ebeb9756d7fe680643d); // .M..).n..um...d=
    write128(  'h02b0, 128'ha8ffce59b0b35449680730c8af567dc9); // ...Y..TIh.0..V}.
    write128(  'h02c0, 128'h2edec8c1c83a44adc752a2e976f5abc5); // .....:D..R..v...
    write128(  'h02d0, 128'h2229a05bc2d6de494e236aabf4f17796); // ").[...IN#j...w.
    write128(  'h02e0, 128'h97b1404c99ec52cb4e9d44af7f6a7131); // ..@L..R.N.D..jq1
    write128(  'h02f0, 128'haab16b01509a4fa73981c2f19a8dba75); // ..k.P.O.9......u
    write128(  'h0300, 128'h2da5f099872a3a5ae26d2c344f86e81c); // -....*:Z.m,4O...
    write128(  'h0310, 128'hf02a6e79447814f1cbbc9fabcedfd986); // .*nyDx..........
    write128(  'h0320, 128'h657cde04f1596e5d170dda86e9329890); // e|...Yn].....2..
    write128(  'h0330, 128'h99cf45cb1dd063248ab1301615720730); // ..E...c$..0..r.0
    write128(  'h0340, 128'h197760de4646fee98f41d55cf3d5f422); // .w`.FF...A.\..."
    write128(  'h0350, 128'h3d50721655c9b3cbdc01f34b789d9d7e); // =Pr.U......Kx..~
    write128(  'h0360, 128'hfb85f21bcee97818624d4553c04527e2); // ......x.bMES.E'.
    write128(  'h0370, 128'h37d4695d8057aa3d6143932b0ba69934); // 7.i].W.=aC.+...4
    write128(  'h0380, 128'h9a70c427b5ca9632e437dbfee490e174); // .p.'...2.7.....t
    write128(  'h0390, 128'h563898ccf1c8c4b2158964c335adea16); // V8........d.5...
    write128(  'h03a0, 128'hbb8fa6522d69e62b95c4f53be9036364); // ...R-i.+...;..cd
    write128(  'h03b0, 128'hbf6f7ed1c680493f64301ff4a74237ef); // .o~...I?d0...B7.
    write128(  'h03c0, 128'h6f58321f6f8c839e8c087e1d9a956ae0); // oX2.o.....~...j.
    write128(  'h03d0, 128'hd4641be799959ecf3b4b3382e90e97bd); // .d......;K3.....
    write128(  'h03e0, 128'h6d2b4e3bd23c00000000000000000000); //  m+N;.<
    $display("%s:%0d UDP.1 Validate UDP check OK for an inbound packet.", `__FILE__, `__LINE__);
    checksum_reset('h11);
    checksum_without_reset(14+12, 4+4); //14 = eth overhead, 12 = ipv4 ports offset. 4+4 = ipv4 addresses
    checksum_without_reset(14+20+2+2, 2); //14 = eth overhead, 20 = ipv4 overhead
    checksum_without_reset(14+20, 'h03c4); //34: udp data offset
    `assert(o_sum == 'hffff);

    write128(  'h0000,   128'h98_03_9b_3c_1c_66_52_5a_2c_18_2e_b1_08_00_45_00 ); //  ...<.fRZ,..±..E.
    write128(  'h0010,   128'h01_00_00_00_40_00_ff_11_a9_85_c0_a8_28_15_c0_a8 ); //  ....@.ÿ.©.À¨(.À¨
  //write128(  'h0020,   128'h28_01_00_7b_c4_05_00_ec_7a_28_24_01_00_00_00_00 ); //  (..{Ä..ìz($..... (bug: 7a28 incorrect, 7a27 correct)
    write128(  'h0020,   128'h28_01_00_7b_c4_05_00_ec_00_00_24_01_00_00_00_00 ); //  (..{Ä..ìz($.....
    write128(  'h0030,   128'h00_00_00_00_00_00_00_00_00_00_e1_e7_ec_73_00_00 ); //  ..........áçìs..
    write128(  'h0040,   128'h00_00_e6_a8_9d_3f_e5_38_27_50_e1_e7_ec_74_42_49 ); //  ..æ¨.?å8'PáçìtBI
    write128(  'h0050,   128'h25_9a_e1_e7_ec_74_42_4a_15_fd_01_04_00_24_5f_7a ); //  %.áçìtBJ.ý...$_z
    write128(  'h0060,   128'h1b_9d_ee_e9_07_4f_1e_5f_87_85_f4_4d_e1_6b_72_02 ); //  ..îé.O._..ôMákr.
    write128(  'h0070,   128'hf6_5d_c6_a2_f1_b6_d1_65_4a_db_58_bc_8c_c6_04_04 ); //  ö]Æ¢ñ¶ÑeJÛX¼.Æ..
    write128(  'h0080,   128'h00_90_00_10_00_78_80_6e_6b_f4_e6_96_3b_18_8c_c9 ); //  .....x.nkôæ.;..É
    write128(  'h0090,   128'hd4_f0_fd_8c_0e_67_b1_17_a8_47_f3_3a_58_23_85_d5 ); //  Ôðý..g±.¨Gó:X#.Õ
    write128(  'h00a0,   128'h6f_94_4e_1b_64_f3_4b_fc_cf_fb_84_1b_7d_e4_9e_b1 ); //  o.N.dóKüÏû..}ä.±
    write128(  'h00b0,   128'he6_03_1a_8e_74_e7_20_f6_56_84_b5_46_56_6b_20_1f ); //  æ...tç öV.µFVk .
    write128(  'h00c0,   128'hcf_7d_9c_6b_db_bb_0f_85_65_91_61_e0_58_16_81_0f ); //  Ï}.kÛ»..e.aàX...
    write128(  'h00d0,   128'hdc_a4_1d_1c_32_c4_3b_e0_78_02_b9_8f_c1_cc_5f_69 ); //  Ü¤..2Ä;àx.¹.ÁÌ_i
    write128(  'h00e0,   128'h80_47_f9_ac_a7_6a_6b_2c_0b_3b_17_5f_08_ef_41_b9 ); //  .Gù¬§jk,.;._.ïA¹
    write128(  'h00f0,   128'h08_0c_08_d9_bb_a8_77_86_63_f1_f2_4e_34_71_92_23 ); //  ...Ù»¨w.cñòN4q.#
    write128(  'h0100,   128'h54_e8_00_0d_41_85_07_18_5c_61_bc_ae_95_f3_00_00 ); //  Tè..A...\a¼®.ó
    $display("%s:%0d UDP.2 Validate UDP check OK for an outbound packet known to trigger a off-by-one bug previously.", `__FILE__, `__LINE__);
    checksum_reset('h11);
    checksum_without_reset(14+12, 4+4); //14 = eth overhead, 12 = ipv4 ports offset. 4+4 = ipv4 addresses
    checksum_without_reset(14+20+2+2, 2); //14 = eth overhead, 20 = ipv4 overhead
    checksum_without_reset(14+20, 'h0ec); //34: udp data offset
    csum = ~ o_sum;
    $display("%s:%0d UDP.2 Checksum calculated: %h (expected: 7a27).", `__FILE__, `__LINE__, csum);
    `assert(csum == 'h7a27);

    write128(  'h0000, 128'h98039b3c1c66525a2c182e8086dd6000 ); //  ...<.fRZ,....Ý`.
    write128(  'h0010, 128'h000003c411fffd75502fe221ddcf0000 ); //  ...Ä.ÿýuP/â!ÝÏ..
    write128(  'h0020, 128'h000000000002fd75502fe221ddcf0000 ); //  ......ýuP/â!ÝÏ..
  //write128(  'h0030, 128'h000000000001007ba7dd03c4e0f92401 ); //  .......{§Ý.Äàù$.
    write128(  'h0030, 128'h000000000001007ba7dd03c400002401 ); //  .......{§Ý.Äàù$.
    write128(  'h0040, 128'h0000000000000000000000000000e1ee ); //  ..............áî
    write128(  'h0050, 128'h5ac80000000010206e8a39910a0ee1ee ); //  ZÈ..... n.9...áî
    write128(  'h0060, 128'h5ac9729e26b3e1ee5ac972a066a10104 ); //  ZÉr.&³áîZÉr f¡..
    write128(  'h0070, 128'h00248725eea95d8914987921d54ad12b ); //  .$.%î©]...y!ÕJÑ+
    write128(  'h0080, 128'h6a94948588794809508f2a8f6d4d2236 ); //  j....yH.P.*.mM"6
    write128(  'h0090, 128'he25b0404036800100350697056939d22 ); //  â[...h...PipV.."
    write128(  'h00a0, 128'h78578c22cb2f1792e8b8856f7e3f6e9c ); //  xW."Ë/..è¸.o~?n.
    write128(  'h00b0, 128'h3bd3140daf2193a1361a13eee6beff76 ); //  ;Ó..¯!.¡6..îæ¾ÿv
    write128(  'h00c0, 128'h96974125f2a0a7124336014513d43901 ); //  ..A%ò §.C6.E.Ô9.
    write128(  'h00d0, 128'hf332a38428996d047f891412468f95cd ); //  ó2£.(.m.....F..Í
    write128(  'h00e0, 128'h156cd26fb348705803047a49445514fd ); //  .lÒo³HpX..zIDU.ý
    write128(  'h00f0, 128'hd9faa6099033a85be535d1fd3b9df1e4 ); //  Ùú¦..3¨[å5Ñý;.ñä
    write128(  'h0100, 128'h7092da4662b2de7538ea156dfc974f48 ); //  p.ÚFb²Þu8ê.mü.OH
    write128(  'h0110, 128'ha62f4cfe11fb8909ea2cdd986d06b382 ); //  ¦/Lþ.û..ê,Ý.m.³.
    write128(  'h0120, 128'h72d0905b01059f0021f22a70026a7e12 ); //  rÐ.[....!ò*p.j~.
    write128(  'h0130, 128'h5069c287210b17d37fdfb7cc0941b659 ); //  PiÂ.!..Ó.ß·Ì.A¶Y
    write128(  'h0140, 128'hbc204de11b21f7814232fee0959e505f ); //  ¼ Má.!÷.B2þà..P_
    write128(  'h0150, 128'h513c292b054dbbb569632bfd8df67443 ); //  Q<)+.M»µic+ý.ötC
    write128(  'h0160, 128'hca0ba2e419fadec0c4c10b1338a4250a ); //  Ê.¢ä.úÞÀÄÁ..8¤%.
    write128(  'h0170, 128'h1b34189011265d00826fd60b9cb38694 ); //  .4...&]..oÖ..³..
    write128(  'h0180, 128'h2a8edfa5d55ed8a8afeca54699d462d1 ); //  *.ß¥Õ^Ø¨¯ì¥F.ÔbÑ
    write128(  'h0190, 128'h54db6cd214d6052d1fca65b8bd249e7e ); //  TÛlÒ.Ö.-.Êe¸½$.~
    write128(  'h01a0, 128'h9e159685bd08d92aa2ba9d7b7ece0654 ); //  ....½.Ù*¢º.{~Î.T
    write128(  'h01b0, 128'he154c5614a418017b81f7e690660a122 ); //  áTÅaJA..¸.~i.`¡"
    write128(  'h01c0, 128'hb1dca3f391f44b80b45e96d8e880fea7 ); //  ±Ü£ó.ôK.´^.Øè.þ§
    write128(  'h01d0, 128'h30fa3e9cae4eff1a731102ab1875089f ); //  0ú>.®Nÿ.s..«.u..
    write128(  'h01e0, 128'h0d9e857e495272003ebd9c6f7d333959 ); //  ...~IRr.>½.o}39Y
    write128(  'h01f0, 128'h0cfdee5b6233e4fcf87674b801242d68 ); //  .ýî[b3äüøvt¸.$-h
    write128(  'h0200, 128'h39248cfd90520bc85aff9a0164d66980 ); //  9$.ý.R.ÈZÿ..dÖi.
    write128(  'h0210, 128'h4a8866aad9e2578a46b0f87e0ab393cc ); //  J.fªÙâW.F°ø~.³.Ì
    write128(  'h0220, 128'hae6be86d63eb18160c02dc65faf9479a ); //  ®kèmcë....ÜeúùG.
    write128(  'h0230, 128'h0da02cf9d0e9dbaf5c19005c7d961574 ); //  . ,ùÐéÛ¯\..\}..t
    write128(  'h0240, 128'h9de9bc2a494b16170703ba39c682abfb ); //  .é¼*IK....º9Æ.«û
    write128(  'h0250, 128'h46bebf845ebfb5f236674986fa21561a ); //  F¾¿.^¿µò6gI.ú!V.
    write128(  'h0260, 128'h3bde3bbb93df2a652974cf4ff4c16f60 ); //  ;Þ;».ß*e)tÏOôÁo`
    write128(  'h0270, 128'h18cfa79f8bf39a3c38f4118546b04334 ); //  .Ï§..ó.<8ô..F°C4
    write128(  'h0280, 128'h6cae53d785bf3cf65106d83eead4356f ); //  l®S×.¿<öQ.Ø>êÔ5o
    write128(  'h0290, 128'he847ae72f5c9e595b3da2099233907e7 ); //  èG®rõÉå.³Ú .#9.ç
    write128(  'h02a0, 128'h1f34644e716a876d849e73d60a2b96c8 ); //  .4dNqj.m..sÖ.+.È
    write128(  'h02b0, 128'hfdeaa4ddf9be0172d68db1bbd23d0e23 ); //  ýê¤Ýù¾.rÖ.±»Ò=.#
    write128(  'h02c0, 128'hd2787e08408599c987bc05e08612a5f6 ); //  Òx~.@..É.¼.à..¥ö
    write128(  'h02d0, 128'hc20b39ae32731e314490d17d8e1fdb83 ); //  Â.9®2s.1D.Ñ}..Û.
    write128(  'h02e0, 128'h5d5aa9d99e2a88bc61bc6112f87e4a0c ); //  ]Z©Ù.*.¼a¼a.ø~J.
    write128(  'h02f0, 128'h280acd15065ecbf3b6d3412045aca8b2 ); //  (.Í..^Ëó¶ÓA E¬¨²
    write128(  'h0300, 128'hb463a05051bcd498ff5a5a8c0f264eac ); //  ´c PQ¼Ô.ÿZZ..&N¬
    write128(  'h0310, 128'h857e922d0852d35ac082d3103ba4ddc4 ); //  .~.-.RÓZÀ.Ó.;¤ÝÄ
    write128(  'h0320, 128'h0e7b579b59081a4cfac20812a5c87647 ); //  .{W.Y..LúÂ..¥ÈvG
    write128(  'h0330, 128'h557ed81ffdd7c7945a4a98632a82ebe9 ); //  U~Ø.ý×Ç.ZJ.c*.ëé
    write128(  'h0340, 128'h9f07b5db7243b0a6d7790e79b4427cb2 ); //  ..µÛrC°¦×y.y´B|²
    write128(  'h0350, 128'h5402c423b1a07cd8c93a7e5fad67230c ); //  T.Ä#± |ØÉ:~_.g#.
    write128(  'h0360, 128'h5f093c081dc4af068dde6bd47ff99ad2 ); //  _.<..Ä¯..ÞkÔ.ù.Ò
    write128(  'h0370, 128'h8741061e276b5be367413f176fad8538 ); //  .A..'k[ãgA?.o..8
    write128(  'h0380, 128'h9b19aa4b2241ec10471afd26d9ccf20f ); //  ..ªK"Aì.G.ý&ÙÌò.
    write128(  'h0390, 128'h8c9c861b18505e79ea177fc54bfe2a23 ); //  .....P^yê..ÅKþ*#
    write128(  'h03a0, 128'h12f60bd266ac1a2d958a8722fb6e2f2c ); //  .ö.Òf¬.-..."ûn/,
    write128(  'h03b0, 128'h4d36edac67c1127cfadddca614df5692 ); //  M6í¬gÁ.|úÝÜ¦.ßV.
    write128(  'h03c0, 128'h696975c6070f832a5b5ecb7ce2f93146 ); //  iiuÆ...*[^Ë|âù1F
    write128(  'h03d0, 128'h3b4e0c8fbe3f92bee84ce2d3e414bbdf ); //  ;N..¾?.¾èLâÓä.»ß
    write128(  'h03e0, 128'hd21331dd35c11daba3fbac83417bdc97 ); //  Ò.1Ý5Á.«£û¬.A{Ü.
    write128(  'h03f0, 128'hbf93041e79872dcfc23f000000000000 ); //  ¿...y.-ÏÂ?

    $display("%s:%0d UDP.3 Validate UDP check OK for an outbound IPV6 packet.", `__FILE__, `__LINE__);
    checksum_reset('h11);
    checksum_without_reset(14+8, 32); //14 = eth overhead, 8 = ipv6 ports offset.
    checksum_without_reset(14+40+2+2, 2); //14 = eth overhead
    checksum_without_reset(14+40, 'h03c4); //34: udp data offset
    csum = ~ o_sum;
    $display("%s:%0d UDP.3 Checksum calculated: %h (expected: 0d20).", `__FILE__, `__LINE__, csum);
    `assert(csum == 'h0d20);


  end
  endtask

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);

    rx_start = 0;
    i_areset = 1;
    i_clk    = 0;

    //i_dispatch_tx_packet_read = 0;
    //i_dispatch_tx_fifo_rd_en  = 0;

    i_parser_clear  = 0;
    i_parser_update_length = 0;
    i_read_en    = 0;
    i_sum_reset  = 0;
    i_sum_en     = 0;
    i_sum_bytes  = 0;
    i_write_en   = 0;
    i_write_data = 0;
    i_address_internal = 1;
    i_address_hi       = 0;
    i_address_lo       = 0;

    i_parser_ipv4_done = 0;
    i_parser_ipv6_done = 0;

    #20 ;
    i_areset = 0;
    #10 ;

    //----------------------------------------------------------------
    // IPv4 Requests
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv4 requests", `__FILE__, `__LINE__);
    #20
    send_packet({60048'b0, nts_packet_ipv4_request1}, ETHIPV4_NTS_TESTPACKETS_BITS, 0);

    send_packet({60048'b0, nts_packet_ipv4_request2}, ETHIPV4_NTS_TESTPACKETS_BITS, 0);

    receive_packet();
    receive_packet();

    //----------------------------------------------------------------
    // IPv6 Request
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv6 requests", `__FILE__, `__LINE__);

    send_packet({59888'b0, nts_packet_ipv6_request1}, ETHIPV6_NTS_TESTPACKETS_BITS, 1);

    send_packet({59888'b0, nts_packet_ipv6_request2}, ETHIPV6_NTS_TESTPACKETS_BITS, 1);

    receive_packet();
    receive_packet();

    //----------------------------------------------------------------
    // Test write port
    //----------------------------------------------------------------

    $display("%s:%0d Test write port", `__FILE__, `__LINE__);

    write_packet({65344'b0, 64'hA1A2_A3A4_A5A6_A7A8, 64'hB1B2_B3B4_B5B6_B7B8, 64'hC1C2_C3C4_C5C6_C7C8 }, 3*64);
    i_address_internal = 0;
    i_address_hi       = 0;
    i_address_lo       = 4;
    i_write_en         = 1;
    i_write_data       = 64'hD1D2_D3D4_D5D6_D7D8;
    #10;
    i_address_hi       = 1;
    i_write_data       = 64'hE1E2_E3E4_E5E6_E7E8;
    #10;
    i_write_en         = 0;
    #10;
    transmit_packet(0);
    #10;
    receive_packet();

    i_write_en = 0;

    ipv4_header_checksum_different_offsets();
    ipv4_header_checksum_ffff();
    test_udp_checksum();
    test_udp_checksum_nts();

    #2000;
    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  always @(posedge i_clk, posedge i_areset)
  begin : simple_rx
    if (i_areset) begin
      i_dispatch_tx_packet_read = 0;
      i_dispatch_tx_fifo_rd_en = 0;
      rx_state = 0;
      rx_buf[6299:64] = 6236'b0;
      rx_buf[63:0] = 64'hXXXX_XXXX_XXXX_XXXX;
    end else begin
      if (rx_state != 0) begin
        //$display("%s:%0d rx_start=%h rx_state=%h o_dispatch_tx_fifo_empty=%h o_dispatch_tx_fifo_rd_data=%h", `__FILE__, `__LINE__, rx_start, rx_state, o_dispatch_tx_fifo_empty, o_dispatch_tx_fifo_rd_data);
      end
      i_dispatch_tx_packet_read = 0;
      i_dispatch_tx_fifo_rd_en = 0;
      case (rx_state)
        0:
          begin
            rx_buf[6299:64] = 6236'b0;
            rx_buf[63:0] = 64'hXXXX_0001_XXXX_XXXX;
            rx_count = 0;
            if (rx_start)
              rx_state = 1;
          end
        1: if (o_dispatch_tx_packet_available && o_dispatch_tx_fifo_empty=='b0) begin
             i_dispatch_tx_fifo_rd_en = 1;
             rx_state = 2;
           end
        2:
          begin
            if (o_dispatch_tx_fifo_empty) begin
              rx_state                  = 3;
              i_dispatch_tx_packet_read = 1;
            end else begin
              i_dispatch_tx_fifo_rd_en  = 1;
              rx_buf[6299:64] = rx_buf[6235:0];
              rx_buf[63:0]    = o_dispatch_tx_fifo_rd_data;
              rx_count        = rx_count + 1;
            end
          end
        3:
          if (rx_start) begin
            rx_state        = 1;
            rx_buf[6299:64] = 6236'b0;
            rx_buf[63:0]    = 64'hXXXX_0003_XXXX_XXXX;
            rx_count        = 0;
          end
      endcase
    end
  end

  always begin
    #5 i_clk = ~i_clk;
  end

  always @*
    $display("%s:%0d Warning: o_error: %h", `__FILE__, `__LINE__, o_error);
  always @*
    $display("%s:%0d o_parser_current_memory_full: %h", `__FILE__, `__LINE__, o_parser_current_memory_full);
  always @*
    $display("%s:%0d o_dispatch_tx_bytes_last_word: %h", `__FILE__, `__LINE__, o_dispatch_tx_bytes_last_word);
  //always @*
  //  $display("%s:%0d o_read_data: %h", `__FILE__, `__LINE__, o_read_data);
  always @*
    $display("%s:%0d o_sum: %h", `__FILE__, `__LINE__, o_sum);
  always @*
    $display("%s:%0d ram_addr_hi_reg[0] %h", `__FILE__, `__LINE__, dut.ram_addr_hi_reg[ 0 ] );
  always @*
    $display("%s:%0d ram_addr_hi_reg[1] %h", `__FILE__, `__LINE__, dut.ram_addr_hi_reg[ 1 ] );
  always @(posedge i_clk)
    if (dut.sum_cycle_reg)
      $display("%s:%0d data: %h", `__FILE__, `__LINE__, dut.ram_rd_data[ dut.parser ] );
//always @*
//  $display("%s:%0d sum_addr_we: %h sum_addr_new: %h", `__FILE__, `__LINE__, dut.sum_addr_we, dut.sum_addr_new);
//always @*
//  $display("%s:%0d sum_counter_we: %h sum_counter_new: %h", `__FILE__, `__LINE__, dut.sum_counter_we, dut.sum_counter_new);
//always @*
//  $display("%s:%0d sum_counter_reg: %h", `__FILE__, `__LINE__, dut.sum_counter_reg);
endmodule
