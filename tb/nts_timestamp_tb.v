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
module nts_timestamp_tb #( parameter verbose = 1 );

  //----------------------------------------------------------------
  // Constants
  //----------------------------------------------------------------
  localparam API_ADDR_NAME0   = 8'h00;
  localparam API_ADDR_NAME1   = 8'h01;
  localparam API_CORE_NAME0   = 32'h74696d65; //"time"
  localparam API_CORE_NAME1   = 32'h73746d70; //"stmp"

  localparam [7:0] API_ADDR_NTP_CONFIG     = 8'h10;
  localparam [7:0] API_ADDR_NTP_ROOT_DELAY = 8'h11;
  localparam [7:0] API_ADDR_NTP_ROOT_DISP  = 8'h12;
  localparam [7:0] API_ADDR_NTP_REF_ID     = 8'h13;
  localparam [7:0] API_ADDR_NTP_TX_OFS     = 8'h14;

  //----------------------------------------------------------------
  // Regs and Wires.
  //----------------------------------------------------------------
  reg i_areset;
  reg i_clk;

  reg  [63:0] i_ntp_time;

  reg          i_parser_clear;
  reg          i_parser_record_receive_timestamp;
  reg          i_parser_transmit;
  reg [63 : 0] i_parser_origin_timestamp;
  reg  [2 : 0] i_parser_version_number;
  reg  [7 : 0] i_parser_poll;

  reg           i_tx_read;
  wire          o_tx_empty;
  wire [ 2 : 0] o_tx_ntp_header_block;
  wire [63 : 0] o_tx_ntp_header_data;

  reg         i_api_cs;
  reg         i_api_we;
  reg   [7:0] i_api_address;
  reg  [31:0] i_api_write_data;
  wire [31:0] o_api_read_data;

  reg [63 : 0] expect_origin_timestamp;
  reg [63 : 0] expect_receive_timestamp;
  reg [63 : 0] expect_transmit_timestamp;

  reg [63 : 0] client_time;

  integer i; //loop counter

  //----------------------------------------------------------------
  // Design Under Test - Core instantiation
  //----------------------------------------------------------------
  nts_timestamp dut (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .i_ntp_time(i_ntp_time),

    .i_parser_clear(i_parser_clear),
    .i_parser_record_receive_timestamp(i_parser_record_receive_timestamp),
    .i_parser_transmit(i_parser_transmit),
    .i_parser_origin_timestamp(i_parser_origin_timestamp),
    .i_parser_version_number(i_parser_version_number),
    .i_parser_poll(i_parser_poll),

    .i_tx_read(i_tx_read),
    .o_tx_empty(o_tx_empty),
    .o_tx_ntp_header_block(o_tx_ntp_header_block),
    .o_tx_ntp_header_data(o_tx_ntp_header_data),

    .i_api_cs(i_api_cs),
    .i_api_we(i_api_we),
    .i_api_address(i_api_address),
    .i_api_write_data(i_api_write_data),
    .o_api_read_data(o_api_read_data)
  );

  //----------------------------------------------------------------
  // Api_set - helper task for setting all the API regs in one line
  //----------------------------------------------------------------
  task api_set;
    input         i_cs;
    input         i_we;
    input   [7:0] i_addr;
    input  [31:0] i_data;
    output        o_cs;
    output        o_we;
    output  [7:0] o_addr;
    output [31:0] o_data;
  begin
    o_cs   = i_cs;
    o_we   = i_we;
    o_addr = i_addr;
    o_data = i_data;
    if (verbose >= 2)
      $display("%s:%0d cs=%h we=%h addr=%h data=%h", `__FILE__, `__LINE__, i_cs, i_we, i_addr, i_data);
  end
  endtask

  //----------------------------------------------------------------
  // Macros
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end
  `define api_write(addr, value) \
    begin \
      api_set(1, 1, addr, value,  i_api_cs, i_api_we, i_api_address, i_api_write_data); \
      #10; \
      api_set(0, 0, 0, 0, i_api_cs, i_api_we, i_api_address, i_api_write_data); \
    end
  `define api_read_assert(addr, value) \
    begin \
      api_set(1, 0, addr, 0,  i_api_cs, i_api_we, i_api_address, i_api_write_data); \
      #10; \
      `assert(value == o_api_read_data) \
      api_set(0, 0, 0, 0, i_api_cs, i_api_we, i_api_address, i_api_write_data); \
    end

  initial begin
    $display("Test start %s:%0d ", `__FILE__, `__LINE__);
    i_areset = 1;
    i_clk    = 0;

    i_parser_clear = 0;
    i_parser_record_receive_timestamp = 0;
    i_parser_transmit = 0;
    i_parser_origin_timestamp = 0;
    i_parser_version_number = 0;
    i_parser_poll = 0;

    i_tx_read = 0;

    api_set(0, 0, 0, 0, i_api_cs, i_api_we, i_api_address, i_api_write_data);

    #10;
    i_areset = 0;

    #10;
    `assert(o_api_read_data == 0);

    `api_read_assert(API_ADDR_NAME0, API_CORE_NAME0);
    `api_read_assert(API_ADDR_NAME1, API_CORE_NAME1);

    `api_write(API_ADDR_NTP_CONFIG,     32'hdeadbeef);
    `api_write(API_ADDR_NTP_ROOT_DELAY, 32'h1007de1a);
    `api_write(API_ADDR_NTP_ROOT_DISP,  32'h1007d155);
    `api_write(API_ADDR_NTP_REF_ID,     32'habad1dea);
    `api_write(API_ADDR_NTP_TX_OFS,     32'hc01df00d);

    `api_read_assert(API_ADDR_NTP_CONFIG,     32'hdeadbeef);
    `api_read_assert(API_ADDR_NTP_ROOT_DELAY, 32'h1007de1a);
    `api_read_assert(API_ADDR_NTP_ROOT_DISP,  32'h1007d155);
    `api_read_assert(API_ADDR_NTP_REF_ID,     32'habad1dea);
    `api_read_assert(API_ADDR_NTP_TX_OFS,     32'hc01df00d);

    `api_write(API_ADDR_NTP_CONFIG,     32'h0);
    `api_write(API_ADDR_NTP_TX_OFS,     32'h0);

    #10;

    for (i = 0; i < 10; i = i + 1) begin
      if (verbose > 0)
        $display("%s:%0d Timestamp #%0d", `__FILE__, `__LINE__, i);

      `assert(o_tx_empty);
      i_parser_record_receive_timestamp = 1;

      #10;
      `assert(o_tx_empty);
      i_parser_record_receive_timestamp = 1; //timestamp expected in TX
      expect_receive_timestamp = i_ntp_time;

      #10;
      `assert(o_tx_empty);
      i_parser_record_receive_timestamp = 0;

      #10;
      `assert(o_tx_empty);
      i_parser_transmit = 1;
      i_parser_origin_timestamp = client_time;
      expect_origin_timestamp = client_time;
      expect_transmit_timestamp = i_ntp_time;

      #10;
      i_parser_transmit = 0;
      i_parser_origin_timestamp = 0;
      i_parser_version_number = 0;
      i_parser_poll = 0;


      while( o_tx_empty ) #10;

      while ( o_tx_empty == 'b0 ) begin
        if (verbose > 1)
          $display("%s:%0d TX(%h): %h", `__FILE__, `__LINE__, o_tx_ntp_header_block, o_tx_ntp_header_data);
        case (o_tx_ntp_header_block)
          0: `assert( 64'h040100001007de1a == o_tx_ntp_header_data ) //NTP version 4, root delay.
          1: `assert( 64'h1007d155abad1dea == o_tx_ntp_header_data ) //Root dispersion, REF ID
          2: `assert( 64'hffffeeed00000000 == o_tx_ntp_header_data ) //Reference timestamp; current time - 1 i.e. ffffeeee-1,0.
          3: `assert( expect_origin_timestamp == o_tx_ntp_header_data )
          4: `assert( expect_receive_timestamp == o_tx_ntp_header_data )
          5: `assert( expect_transmit_timestamp == o_tx_ntp_header_data )
        endcase
        i_tx_read = 1;
        #10;
      end
      `assert(o_tx_empty);
      i_tx_read = 0;
      #10;
      `assert(o_tx_empty);
    end

    $display("Test end %s:%0d ", `__FILE__, `__LINE__);
    $finish;
  end

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_ntp_time <= 64'hFFFF_EEEE_1234_5678;
      client_time <= 64'hffff_dddd_0000_0000;

    end else begin
      i_ntp_time <= i_ntp_time + 1;
      client_time <= client_time + 1;

    end
  end

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
