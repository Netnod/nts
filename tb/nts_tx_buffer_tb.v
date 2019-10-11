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

  reg         i_areset; // async reset
  reg         i_clk;

  wire        o_dispatch_tx_packet_available;
  reg         i_dispatch_tx_packet_read;
  wire        o_dispatch_tx_fifo_empty;
  reg         i_dispatch_tx_fifo_rd_en;
  wire [63:0] o_dispatch_tx_fifo_rd_data;
  wire  [3:0] o_dispatch_tx_bytes_last_word;

  reg         i_parser_clear;
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
  reg    [63:0] tx_buf [0:99];

  //----------------------------------------------------------------
  // Test bench macros
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  //----------------------------------------------------------------
  // Test bench tasks
  //----------------------------------------------------------------

  task write_packet (
    input [65535:0] source,
    input    [31:0] length
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
        tx_buf[i] = 64'hXXXX_XXXX_XXXX_XXXX;
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
        tx_buf[source_ptr] = packet[packet_ptr];
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

  //----------------------------------------------------------------
  // Test bench Design Under Test (DUT) instantiation
  //----------------------------------------------------------------

  nts_tx_buffer #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset), // async reset
    .i_clk(i_clk),

    .o_dispatch_tx_packet_available(o_dispatch_tx_packet_available),
    .i_dispatch_tx_packet_read(i_dispatch_tx_packet_read),
    .o_dispatch_tx_fifo_empty(o_dispatch_tx_fifo_empty),
    .i_dispatch_tx_fifo_rd_en(i_dispatch_tx_fifo_rd_en),
    .o_dispatch_tx_fifo_rd_data(o_dispatch_tx_fifo_rd_data),
    .o_dispatch_tx_bytes_last_word(o_dispatch_tx_bytes_last_word),

    .i_parser_clear(i_parser_clear),

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

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);

    rx_start = 0;
    i_areset = 1;
    i_clk    = 0;

    //i_dispatch_tx_packet_read = 0;
    //i_dispatch_tx_fifo_rd_en  = 0;

    i_parser_clear  = 0;
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

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  always @(posedge i_clk, posedge i_areset)
  begin : simple_rx
    integer i;
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

endmodule
