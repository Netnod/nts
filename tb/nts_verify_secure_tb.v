//
// Copyright (c) 2019, The Swedish Post and Telecom Authority (PTS)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//

//
// Author: Peter Magnusson, Assured AB
//

module nts_verify_secure_tb #(
  parameter verbose = 1 // 0: Silent. 1. Informative messages. 2. Traces. 3. Extreme traces.
);
  localparam [255:0] TEST1_C2S = { 128'h2be26209_fdc335d0_13aeb45a_ecd91f1a,
                                   128'ha4e1055b_8f7fdae8_c592b87d_09200b74 };

  localparam [127:0] TEST1_NONCE = 128'h7208a18a_82f9a600_130d32d0_5c9d74dd;

  localparam [1503:0] TEST1_AD = { 128'h23000020_00000000_00000000_00000000,
                                   128'h00000000_00000000_00000000_00000000,
                                   128'h00000000_00000000_40478317_6d76ee40,
                                   128'h01040024_62733aee_2f65b707_8698f4f1,
                                   128'hb42cf4f8_bb7149ed_d0b8a6d2_426a823c,
                                   128'ha6563ff5_02040068_ea0e3f0d_06043007,
                                   128'h46b5d7c0_9f9e2a29_a785c2b9_b6d49397,
                                   128'h1faefc47_977295e2_127b7dfd_dcfa59ed,
                                   128'h82e24e32_94789bb2_0d7dddf8_a5c7d998,
                                   128'h2ce752f0_775ab86e_985a57f2_d34cac37,
                                   128'hd6621199_d600a4fd_af6de2b8_a70bfdd6,
                                    96'h1b072c09_10d5e57a_1956a84c};

  localparam [127:0] TEST1_TAG = 128'h464470e5_98f324b7_31647dde_6191623e;

  localparam  [15:0] NTP_TAG_NTS_COOKIE = 16'h0204;
  localparam  [31:0] NTS_TEST_REQUEST_MASTER_KEY_ID = 32'h6c47f0d3;
  localparam [255:0] NTS_TEST_REQUEST_MASTER_KEY = 256'h3fc91575cf885a02820a019e846fa2a68c9aa6543f4c1ebabea74ca0d16aeda8;
  localparam [831:0] NTS_TEST_COOKIE1 = 832'h020400686c47f0d3cd65766f2c8fb4cc6b8d5b7aca60c5eca507af99a998d8395e045f75ffa2be8c3b025e7b46a4f2472777e251e4fc36b7ed1287f362cd54b1152488c5873a6fc70ec582beb3640aaae23038c694939e8d71c51d88f6a6def90efc99906cd3c2cb;
  localparam [255:0] NTS_TEST_COOKIE1_C2S = 256'h9e36980572b3cf91a8fb2f29b105a1d95439ebabeb61403e1aba654e9ba56176;
  localparam [255:0] NTS_TEST_COOKIE1_S2C = 256'h8f62b677d6c55010504abd646cf394cfc5990605f6032b0e8b7df00667cac34b;

  localparam RX_PORT_WIDTH = 64;
  localparam ADDR_WIDTH = 8;

  //----------------------------------------------------------------
  // Inputs and outputs
  //----------------------------------------------------------------

  reg                    i_areset; // async reset
  reg                    i_clk;

  wire                   o_busy;
  wire                   o_verify_tag_ok;

  reg            [3 : 0] i_key_word;
  reg                    i_key_valid;
  reg                    i_key_length;
  reg           [31 : 0] i_key_data;

  reg                    i_unwrapped_s2c;
  reg                    i_unwrapped_c2s;
  reg            [2 : 0] i_unwrapped_word;
  reg           [31 : 0] i_unwrapped_data;

  reg                    i_op_copy_rx_ad;
  reg                    i_op_copy_rx_nonce;
  reg                    i_op_copy_rx_tag;
  reg                    i_op_copy_rx_pc;
  reg                    i_op_verify_c2s;
  reg                    i_op_cookie_verify;
  reg                    i_op_copy_tx_ad;
  reg                    i_op_generate_tag;
  reg                    i_op_store_tx_nonce_tag;
  reg                    i_op_store_tx_cookie;
  reg                    i_op_cookie_loadkeys;
  reg                    i_op_cookie_rencrypt;

  reg  [ADDR_WIDTH+3-1:0] i_copy_rx_addr;
  reg               [9:0] i_copy_rx_bytes;

  reg  [ADDR_WIDTH+3-1:0] i_copy_tx_addr;
  reg               [9:0] i_copy_tx_bytes;

  reg                     i_rx_wait;
  wire [ADDR_WIDTH+3-1:0] o_rx_addr;
  wire              [2:0] o_rx_wordsize;
  wire                    o_rx_rd_en;
  reg                     i_rx_rd_dv;
  reg [RX_PORT_WIDTH-1:0] i_rx_rd_data;

  wire                    o_tx_read_en;
  reg              [63:0] i_tx_read_data;
  wire                    o_tx_write_en;
  wire             [63:0] o_tx_write_data;
  wire [ADDR_WIDTH+3-1:0] o_tx_address;

  wire                    o_noncegen_get;
  reg            [63 : 0] i_noncegen_nonce;
  reg                     i_noncegen_ready;

  //----------------------------------------------------------------
  // Helpful debug variables
  //----------------------------------------------------------------

  reg         nonce_set;
  reg  [63:0] nonce_set_a;
  reg  [63:0] nonce_set_b;

  //----------------------------------------------------------------
  // Design Under Test (DUT)
  //----------------------------------------------------------------

  nts_verify_secure #(.RX_PORT_WIDTH(RX_PORT_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),
    .o_busy(o_busy),
    .o_verify_tag_ok(o_verify_tag_ok),

    .i_key_word(i_key_word),
    .i_key_valid(i_key_valid),
    .i_key_length(i_key_length),
    .i_key_data(i_key_data),

    .i_unrwapped_s2c(i_unwrapped_s2c),
    .i_unwrapped_c2s(i_unwrapped_c2s),
    .i_unwrapped_word(i_unwrapped_word),
    .i_unwrapped_data(i_unwrapped_data),

    .i_op_copy_rx_ad(i_op_copy_rx_ad),
    .i_op_copy_rx_nonce(i_op_copy_rx_nonce),
    .i_op_copy_rx_tag(i_op_copy_rx_tag),
    .i_op_copy_rx_pc(i_op_copy_rx_pc),
    .i_op_verify_c2s(i_op_verify_c2s),
    .i_op_cookie_verify(i_op_cookie_verify),
    .i_op_copy_tx_ad(i_op_copy_tx_ad),
    .i_op_generate_tag(i_op_generate_tag),
    .i_op_store_tx_nonce_tag(i_op_store_tx_nonce_tag),
    .i_op_store_tx_cookie(i_op_store_tx_cookie),
    .i_op_cookie_loadkeys(i_op_cookie_loadkeys),
    .i_op_cookie_rencrypt(i_op_cookie_rencrypt),

    .i_copy_rx_addr(i_copy_rx_addr),
    .i_copy_rx_bytes(i_copy_rx_bytes),
    .i_copy_tx_addr(i_copy_tx_addr),
    .i_copy_tx_bytes(i_copy_tx_bytes),

    .i_rx_wait(i_rx_wait),
    .o_rx_addr(o_rx_addr),
    .o_rx_wordsize(o_rx_wordsize),
    .o_rx_rd_en(o_rx_rd_en),
    .i_rx_rd_dv(i_rx_rd_dv),
    .i_rx_rd_data(i_rx_rd_data),

    .o_tx_read_en(o_tx_read_en),
    .i_tx_read_data(i_tx_read_data),
    .o_tx_write_en(o_tx_write_en),
    .o_tx_write_data(o_tx_write_data),
    .o_tx_address(o_tx_address),

    .o_noncegen_get(o_noncegen_get),
    .i_noncegen_nonce(i_noncegen_nonce),
    .i_noncegen_ready(i_noncegen_ready)
  );

  //----------------------------------------------------------------
  // Macros
  //----------------------------------------------------------------

  `define dump(prefix, x) $display("%s:%0d **** %s%s = %h", `__FILE__, `__LINE__, prefix, `"x`", x)
  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  //----------------------------------------------------------------
  // Tasks
  //----------------------------------------------------------------

  task write_key ( input [31:0] keyid, input [255:0] key );
    begin : write_key
      reg [3:0] i;
      for (i = 0; i < 8; i = i + 1) begin
        i_key_word = i[3:0];
        i_key_valid = 1;
        i_key_length = 0; //256(128+128). 512bit(256+256) not yet supported.
        i_key_data = key[i*32+:32];
        if (verbose>1)
          $display("%s:%0d key: %h (%h) keyid: %h", `__FILE__, `__LINE__, i_key_data, i_key_word, keyid );
        #10;
      end
      i_key_word = 0;
      i_key_valid = 0;
      i_key_length = 0;
      i_key_data = 0;
      #10;
    end
  endtask

  task write_c2s(
    input [255:0] c2s
  );
  begin : load_c2s
    integer i;
    reg [2:0] j;
    if (verbose>1) $display("%s:%0d write_c2s", `__FILE__, `__LINE__);
    for ( i = 0; i < 8; i = i + 1) begin
      j = i[2:0];
      i_unwrapped_c2s = 1;
      i_unwrapped_word = j;
      i_unwrapped_data = c2s[j*32+:32];
      #10;
    end
    i_unwrapped_c2s = 0;
    i_unwrapped_word = 0;
    i_unwrapped_data = 0;
    #10;
  end
  endtask

  task write_s2c(
    input [255:0] s2c
  );
  begin : load_s2c
    integer i;
    reg [2:0] j;
    if (verbose>1) $display("%s:%0d write_s2c", `__FILE__, `__LINE__);
    for ( i = 0; i < 8; i = i + 1) begin
      j = i[2:0];
      i_unwrapped_s2c = 1;
      i_unwrapped_word = j;
      i_unwrapped_data = s2c[j*32+:32];
      #10;
    end
    i_unwrapped_s2c = 0;
    i_unwrapped_word = 0;
    i_unwrapped_data = 0;
    #10;
  end
  endtask

  reg [63:0] mem_rx[0:255];
  reg [63:0] mem_tx[0:255];
  reg [ADDR_WIDTH+3-1:0] mem_rx_baseaddr;
  reg [ADDR_WIDTH+3-1:0] mem_tx_baseaddr;

  function [63:0] mem_rx_func( input [ADDR_WIDTH+3-1:0] addr );
  begin : mem_rx_func__
    reg [ADDR_WIDTH+3-1:0] a;
    a = { 3'b000, addr[ADDR_WIDTH+3-1:3] - mem_rx_baseaddr[ADDR_WIDTH+3-1:3] };
    if (verbose>2)
      $display("%s:%0d mem_rx_func(%h)=mem_rx[%h]=%h", `__FILE__, `__LINE__, addr, a, mem_rx[a[7:0]]);
    mem_rx_func = mem_rx[a[7:0]];
  end
  endfunction

  function [63:0] mem_tx_func( input [ADDR_WIDTH+3-1:0] addr );
  begin : mem_tx_func__
    reg [ADDR_WIDTH+3-1:0] a;
    a = { 3'b000, addr[ADDR_WIDTH+3-1:3] - mem_tx_baseaddr[ADDR_WIDTH+3-1:3] };
    if (verbose>2)
      $display("%s:%0d mem_tx_func(%h)=mem_tx[%h]=%h", `__FILE__, `__LINE__, addr, a, mem_tx[a[7:0]]);
    mem_tx_func = mem_tx[a[7:0]];
  end
  endfunction

  task mem_tx_update_delayed( input [ADDR_WIDTH+3-1:0] addr, input [63:0] val );
  begin : mem_tx_upc__
    reg [ADDR_WIDTH+3-1:0] a;
    a = { 3'b000, addr[ADDR_WIDTH+3-1:3] - mem_tx_baseaddr[ADDR_WIDTH+3-1:3] };
    if (verbose>2)
      $display("%s:%0d mem_tx_update( addr=%h, val=%h) updates mem_tx[%h]", `__FILE__, `__LINE__, addr, val, a);
    mem_tx[a[7:0]] <= val;
  end
  endtask

  task init_memory_model_rx ( input [ADDR_WIDTH+3-1:0] addr );
  begin : init_memory_model
    integer i;

    mem_rx_baseaddr = addr;

    #10;
    for (i = 0; i < 256; i = i + 1)
      mem_rx[i] = { 32'hffffffff, i };
  end
  endtask

  task init_memory_model_tx ( input [ADDR_WIDTH+3-1:0] addr );
  begin : init_memory_model
    integer i;

    mem_tx_baseaddr = addr;

    #10;
    for (i = 0; i < 256; i = i + 1)
      mem_tx[i] = { 32'heeeeeeee, i };
  end
  endtask

  task wait_busy;
  begin : wait_busy
    integer i;
    i = 0;
    while (o_busy) begin
      #10;
      i = i + 1;
    end
    if (verbose>1)
      $display("%s:%0d wait_busy completed in %0d ticks.", `__FILE__, `__LINE__, i);
  end
  endtask

  task write_rx_ad(
    input              [9:0] bytes_count,
    input          [16383:0] ad
  );
  begin : write_rx_ad
    integer i;
    integer j;
    if (verbose>2) begin
      `dump( "", ad );
      `dump( "", bytes_count );
      `dump( "", bytes_count[7:3] );
      `dump( "", bytes_count[2:0] );
    end
    j = 0;
    for (i = { 27'h0, bytes_count[7:3] }; i > 0; i = i - 1) begin : offset_calc
      integer offset;
      offset = (64*i) + (8*bytes_count[2:0]) - 1;
      mem_rx[j] = ad[offset-:64];
      if (verbose>2) begin
        `dump( "", i );
        `dump( "", offset );
        `dump( "", mem_rx[j] );
      end
      j = j + 1;
    end
    case (bytes_count[2:0])
      1: mem_rx[j] = { ad[0+:8], 56'h0 };
      2: mem_rx[j] = { ad[0+:16], 48'h0 };
      3: mem_rx[j] = { ad[0+:24], 40'h0 };
      4: mem_rx[j] = { ad[0+:32], 32'h0 };
      5: mem_rx[j] = { ad[0+:40], 24'h0 };
      6: mem_rx[j] = { ad[0+:48], 16'h0 };
      7: mem_rx[j] = { ad[0+:56], 8'h0 };
    endcase
    if (verbose>2)
      `dump( "", mem_rx[j] );

    wait_busy();
    i_op_copy_rx_ad = 1;
    i_copy_rx_addr = mem_rx_baseaddr;
    i_copy_rx_bytes = bytes_count;
    #10;
    i_op_copy_rx_ad = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task write_tx_ad(
    input     [9:0] bytes_count,
    input [16383:0] ad
  );
  begin : write_tx_ad
    integer i;
    integer j;
    if (verbose>2) begin
      `dump( "", ad );
      `dump( "", bytes_count );
      `dump( "", bytes_count[7:3] );
      `dump( "", bytes_count[2:0] );
    end
    j = 0;
    for (i = { 27'h0, bytes_count[7:3] }; i > 0; i = i - 1) begin : tx_offset_calc
      integer offset;
      offset = (64*i) + (8*bytes_count[2:0]) - 1;
      mem_tx[j] = ad[offset-:64];
      if (verbose>2) begin
        `dump( "", i );
        `dump( "", offset );
        `dump( "", mem_rx[j] );
      end
      j = j + 1;
    end
    case (bytes_count[2:0])
      1: mem_tx[j] = { ad[0+:8], 56'h0 };
      2: mem_tx[j] = { ad[0+:16], 48'h0 };
      3: mem_tx[j] = { ad[0+:24], 40'h0 };
      4: mem_tx[j] = { ad[0+:32], 32'h0 };
      5: mem_tx[j] = { ad[0+:40], 24'h0 };
      6: mem_tx[j] = { ad[0+:48], 16'h0 };
      7: mem_tx[j] = { ad[0+:56], 8'h0 };
    endcase
    if (verbose>2)
      `dump( "", mem_tx[j] );

    wait_busy();
    i_op_copy_tx_ad = 1;
    i_copy_tx_addr = mem_tx_baseaddr;
    i_copy_tx_bytes = bytes_count;
    #10;
    i_op_copy_tx_ad = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask


  task write_rx_nonce (
    input [127:0] nonce
  );
  begin
    mem_rx[32] = nonce[127:64];
    mem_rx[33] = nonce[63:0];
    wait_busy();
    i_op_copy_rx_nonce = 1;
    i_copy_rx_addr = mem_rx_baseaddr + (32*8);
    i_copy_rx_bytes = 16;
    #10;
    i_op_copy_rx_nonce = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task write_rx_tag (
    input [127:0] tag
  );
  begin
    mem_rx[35] = tag[127:64];
    mem_rx[36] = tag[63:0];
    wait_busy();
    i_op_copy_rx_tag = 1;
    i_copy_rx_addr = mem_rx_baseaddr + (35*8);
    i_copy_rx_bytes = 16;
    #10;
    i_op_copy_rx_tag = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task write_rx_pc (
    input [511:0] pc
  );
  begin
    mem_rx[37] = pc[448+:64];
    mem_rx[38] = pc[384+:64];
    mem_rx[39] = pc[320+:64];
    mem_rx[40] = pc[256+:64];
    mem_rx[41] = pc[192+:64];
    mem_rx[42] = pc[128+:64];
    mem_rx[43] = pc[64+:64];
    mem_rx[44] = pc[0+:64];
    wait_busy();
    i_op_copy_rx_pc = 1;
    i_copy_rx_addr = mem_rx_baseaddr + (37*8);
    i_copy_rx_bytes = 64; /*512bits; 256(128+128) * 2 */
    #10;
    i_op_copy_rx_pc = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task verify_c2s;
  begin
    wait_busy();
    i_op_verify_c2s = 1;
    #10;
    i_op_verify_c2s = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task verify_cookie;
  begin
    wait_busy();
    i_op_cookie_verify = 1;
    #10;
    i_op_cookie_verify = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task cookie_loadkeys;
  begin
    wait_busy();
    i_op_cookie_loadkeys = 1;
    #10;
    i_op_cookie_loadkeys = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task cookie_rencrypt;
  begin
    wait_busy();
    i_op_cookie_rencrypt = 1;
    #10;
    i_op_cookie_rencrypt = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task generate_tag;
  begin
    wait_busy();
    i_op_generate_tag = 1;
    #10;
    i_op_generate_tag = 0;
    `assert(o_busy);
    wait_busy();
  end
  endtask

  task dump_ram_row ( input [7:0] row);
    $display("%s:%0d dump_ram - dut.mem.ram[0x%h]=0x%h", `__FILE__, `__LINE__, row, dut.mem.ram[row]);
  endtask

  task dump_ram( input [7:0] first, input [7:0] last);
  begin : dump_ram
    reg [7:0] i ;
    for (i = first; i <= last; i = i + 1)
      dump_ram_row(i);
  end
  endtask

  task dump_siv;
  begin
      `dump("aes-siv.", dut.core_config_encdec_reg);
      `dump("aes-siv.", dut.core_key);
      `dump("aes-siv.", dut.core_config_mode);
      `dump("aes-siv.", dut.core_start_reg);
      `dump("aes-siv.", dut.core_ad_start);
      `dump("aes-siv.", dut.core_ad_length_reg);
      `dump("aes-siv.", dut.core_nonce_start);
      `dump("aes-siv.", dut.core_nonce_length);
      `dump("aes-siv.", dut.core_pc_start);
      `dump("aes-siv.", dut.core_pc_length);
      `dump("aes-siv.", dut.core_cs);
      `dump("aes-siv.", dut.core_we);
      `dump("aes-siv.", dut.core_ack_reg);
      `dump("aes-siv.", dut.core_addr);
      `dump("aes-siv.", dut.core_block_rd);
      `dump("aes-siv.", dut.core_block_wr);
      `dump("aes-siv.", dut.core_tag_in);
      `dump("aes-siv.", dut.core_tag_out);
      `dump("aes-siv.", dut.core_tag_ok);
      `dump("aes-siv.", dut.core_ready);
      `dump("aes-siv.", dut.core_tag_out);
  end
  endtask

  task test_verify (
     input    [63:0] description,
     input           expect_success,
     input   [255:0] c2s,
     input     [9:0] ad_bytes_count,
     input [16383:0] ad,
     input   [127:0] nonce,
     input   [127:0] tag
  );
  begin : test_verify
    if (verbose>1) begin : test_verify_debug
      $display("%s:%0d test_verify [ %s ] start.", `__FILE__, `__LINE__, description);
      $display("%s:%0d C2S:   %h", `__FILE__, `__LINE__, c2s);
      $display("%s:%0d AD:    %h", `__FILE__, `__LINE__, ad);
      $display("%s:%0d Nonce: %h", `__FILE__, `__LINE__, nonce);
      $display("%s:%0d Tag:   %h", `__FILE__, `__LINE__, tag);
    end

    write_c2s(c2s);
    write_rx_ad( ad_bytes_count, ad );
    write_rx_nonce( nonce );
    write_rx_tag( tag );

    verify_c2s();

    if (expect_success) begin
      `assert(o_verify_tag_ok);
    end else begin
      `assert(o_verify_tag_ok == 'b0);
    end

    if (verbose>1) begin
      `dump("", o_verify_tag_ok);
    end
    if (verbose>0)
      $display("%s:%0d test_verify [ %s ] completed with expected result (%b).", `__FILE__, `__LINE__, description, expect_success);
  end
  endtask

  task test_generate_tag (
     input    [63:0] description,
     input   [255:0] s2c,
     input     [9:0] ad_bytes_count,
     input [16383:0] ad,
     input   [127:0] nonce,
     input   [127:0] tag
  );
  begin
    if (verbose>1) begin
      $display("%s:%0d test_generate_tag [ %s ] start.", `__FILE__, `__LINE__, description);
      $display("%s:%0d S2C:   %h", `__FILE__, `__LINE__, s2c);
      $display("%s:%0d AD:    %h", `__FILE__, `__LINE__, ad);
      $display("%s:%0d Nonce: %h", `__FILE__, `__LINE__, nonce);
      $display("%s:%0d Tag:   %h", `__FILE__, `__LINE__, tag);
    end

    i_areset = 1; /* needed for nonce generation */
    nonce_set = 1;
    nonce_set_a = nonce[127:64];
    nonce_set_b = nonce[63:0];
    #10;
    i_areset = 0;

    write_s2c(s2c);
    write_tx_ad( ad_bytes_count, ad );

    generate_tag();

    `assert( dut.core_tag_out == tag );

    if (verbose>0)
      $display("%s:%0d test_generate_tag [ %s ] completed. Good tag! Expected: %h... Calculated: %h...", `__FILE__, `__LINE__, description, tag[127-:32], dut.core_tag_out[127-:32]);
  end
  endtask

  task split_chrony_cookie (
    input  [831:0] ntp_extension_nts,
    output         valid,
    output  [31:0] cookie_ad_keyid,
    output [127:0] cookie_nonce,
    output [127:0] cookie_tag,
    output [255:0] cookie_ciphertext_c2s,
    output [255:0] cookie_ciphertext_s2c
  );
    begin : split_cookie_locals
      reg [15:0] tag;
      reg [15:0] len;
      valid = 0;
      { tag, len, cookie_ad_keyid, cookie_nonce, cookie_tag, cookie_ciphertext_c2s, cookie_ciphertext_s2c } = ntp_extension_nts;
      if (tag == NTP_TAG_NTS_COOKIE) begin
         if (len == 16'h0068) begin //832 bits
           valid = 1;
         end
      end
    end
  endtask

  task unwrap_test (
    input [127:0] testname_str,
    input [255:0] masterkey_value,
    input  [31:0] masterkey_keyid,
    //input         masterkey_length,
    input [831:0] cookie,
    input         expect_success,
    input [255:0] expect_c2s,
    input [255:0] expect_s2c
  );
  begin
    if (verbose>1) begin
      $display("%s:%0d Unwrap [%s] start...", `__FILE__, `__LINE__, testname_str);
    end
    //reset_rx();
    write_key(masterkey_keyid, masterkey_value/*, masterkey_length*/);

    begin : unwrap_cookie
      reg         valid_cookie;
      reg  [31:0] cookie_keyid;
      reg [127:0] cookie_nonce;
      reg [127:0] cookie_tag;
      reg [511:0] cookie_ciphertext;
      split_chrony_cookie(
           cookie,
           valid_cookie,
           cookie_keyid,
           cookie_nonce,
           cookie_tag,
           cookie_ciphertext[511:256],
           cookie_ciphertext[255:0] );
      write_rx_nonce(cookie_nonce);
      write_rx_pc(cookie_ciphertext);
      write_rx_tag(cookie_tag);
      if (verbose>1) begin
        $display("%s:%0d unwrap_cookie: cookie: %h", `__FILE__, `__LINE__, cookie );
        $display("%s:%0d unwrap_cookie: keyid:  %h", `__FILE__, `__LINE__, cookie_keyid );
        $display("%s:%0d unwrap_cookie: NONCE:  %h", `__FILE__, `__LINE__, cookie_nonce );
        $display("%s:%0d unwrap_cookie: CIPHER: %h", `__FILE__, `__LINE__, cookie_ciphertext );
        $display("%s:%0d unwrap_cookie: TAG:    %h", `__FILE__, `__LINE__, cookie_tag );
      end
      `assert(valid_cookie);
      verify_cookie();
    end

    if (expect_success) begin
      `assert( o_verify_tag_ok );
      cookie_loadkeys();
      if (verbose>1) begin
        $display("%s:%0d Unwrapped S2C = %h", `__FILE__, `__LINE__, dut.key_s2c_reg);
        $display("%s:%0d Unwrapped C2S = %h", `__FILE__, `__LINE__, dut.key_c2s_reg);
      end
      `assert( dut.key_c2s_reg == expect_c2s );
      `assert( dut.key_s2c_reg == expect_s2c );
    end else begin
      `assert( o_verify_tag_ok == 'b0 );
    end

    if (verbose>0) begin
      $display("%s:%0d Unwrap [%s] executed with result: %d.", `__FILE__, `__LINE__, testname_str, o_verify_tag_ok);
    end
  end
  endtask

  task unwrap_recursive_inner (
    input  [127:0] testname_str,
    input  integer recursions,
    input  [255:0] masterkey_value,
    input   [31:0] masterkey_keyid,
    input  [831:0] cookie,
    input  [255:0] expect_c2s,
    input  [255:0] expect_s2c,
    output [831:0] cookie_out
  );
  begin
    write_key(masterkey_keyid, masterkey_value/*, masterkey_length*/);
    begin : unwrap_recursive_cookie
      reg         valid_cookie;
      reg  [31:0] cookie_keyid;
      reg [127:0] cookie_nonce;
      reg [127:0] cookie_tag;
      reg [511:0] cookie_ciphertext;
      split_chrony_cookie(
           cookie,
           valid_cookie,
           cookie_keyid,
           cookie_nonce,
           cookie_tag,
           cookie_ciphertext[511:256],
           cookie_ciphertext[255:0] );
      write_rx_nonce(cookie_nonce);
      write_rx_pc(cookie_ciphertext);
      write_rx_tag(cookie_tag);
      if (verbose>1) begin
        $display("%s:%0d unwrap_cookie: cookie: %h", `__FILE__, `__LINE__, cookie );
        $display("%s:%0d unwrap_cookie: keyid:  %h", `__FILE__, `__LINE__, cookie_keyid );
        $display("%s:%0d unwrap_cookie: NONCE:  %h", `__FILE__, `__LINE__, cookie_nonce );
        $display("%s:%0d unwrap_cookie: CIPHER: %h", `__FILE__, `__LINE__, cookie_ciphertext );
        $display("%s:%0d unwrap_cookie: TAG:    %h", `__FILE__, `__LINE__, cookie_tag );
      end
      `assert(valid_cookie);
      verify_cookie();
    end
    `assert( o_verify_tag_ok );
    cookie_loadkeys();
    if (verbose>1) begin
      $display("%s:%0d Unwrapped S2C = %h", `__FILE__, `__LINE__, dut.key_s2c_reg);
      $display("%s:%0d Unwrapped C2S = %h", `__FILE__, `__LINE__, dut.key_c2s_reg);
    end
    `assert( dut.key_c2s_reg == expect_c2s );
    `assert( dut.key_s2c_reg == expect_s2c );

    if (verbose>0) begin
      $display("%s:%0d Unwrap_reursive [%s][%0d] executed with result: %d. Cookie: %h...", `__FILE__, `__LINE__, testname_str, recursions,o_verify_tag_ok, cookie);
    end
    cookie_rencrypt();

    cookie_out =
         {
           NTP_TAG_NTS_COOKIE, 16'h0068,
           masterkey_keyid,
           dut.mem.ram[0], dut.mem.ram[1],
           dut.core_tag_out,
           dut.mem.ram[2], dut.mem.ram[3], dut.mem.ram[4], dut.mem.ram[5],
           dut.mem.ram[6], dut.mem.ram[7], dut.mem.ram[8], dut.mem.ram[9]
         };
    $display("%s:%0d Cookie: %h...", `__FILE__, `__LINE__, cookie_out);

    i_op_store_tx_cookie = 1;
    i_copy_tx_addr = mem_tx_baseaddr;
    i_copy_tx_bytes = 'h60;
    #10;
    i_op_store_tx_cookie = 0;
    `assert( o_busy );
    while ( o_busy ) #10;

    cookie_out =
         {
           NTP_TAG_NTS_COOKIE, 16'h0068,
           masterkey_keyid,
           mem_tx[0], mem_tx[1], mem_tx[2], mem_tx[3], mem_tx[4], mem_tx[5],
           mem_tx[6], mem_tx[7], mem_tx[8], mem_tx[9], mem_tx[10], mem_tx[11]
         };
    $display("%s:%0d Cookie: %h...", `__FILE__, `__LINE__, cookie_out);
  end
  endtask

  task unwrap_recursive (
    input [127:0] testname_str,
    input integer recursions,
    input [255:0] masterkey_value,
    input  [31:0] masterkey_keyid,
    input [831:0] cookie,
    input [255:0] expect_c2s,
    input [255:0] expect_s2c
  );
  begin : unwrap_recursive
    reg [831:0] cookie_in;
    reg [831:0] cookie_out;
    integer i;
    if (verbose>1) begin
      $display("%s:%0d Unwrap_recurisve [%s] start...", `__FILE__, `__LINE__, testname_str);
    end

    nonce_set = 0;
    i_areset = 1;
    #10;
    i_areset = 0;

    cookie_in = cookie;
    for ( i = 0; i < recursions; i = i + 1 ) begin
      unwrap_recursive_inner (
        testname_str,
        i,
        masterkey_value,
        masterkey_keyid,
        cookie_in,
        expect_c2s,
        expect_s2c,
        cookie_out );
      cookie_in = cookie_out;
    end
  end
  endtask

  //----------------------------------------------------------------
  // Testbench start
  //----------------------------------------------------------------

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk = 0;
    i_areset = 1;
    i_unwrapped_s2c = 0;
    i_unwrapped_c2s = 0;
    i_unwrapped_word = 0;
    i_unwrapped_data = 0;
    i_op_copy_rx_ad = 0;
    i_op_copy_rx_nonce = 0;
    i_op_copy_rx_tag = 0;
    i_op_copy_rx_pc = 0;
    i_op_verify_c2s = 0;
    i_op_cookie_verify = 0;
    i_op_copy_tx_ad = 0;
    i_op_generate_tag = 0;
    i_op_store_tx_nonce_tag = 0;
    i_op_store_tx_cookie = 0;
    i_op_cookie_loadkeys = 0;
    i_copy_rx_addr = 0;
    i_copy_rx_bytes = 0;
    i_copy_tx_addr = 0;
    i_copy_tx_bytes = 0;
    i_tx_read_data = 0;

    nonce_set = 0;
    nonce_set_a = 0;
    nonce_set_b = 0;

    #10;
    i_areset = 0;
    #10;
    init_memory_model_rx( 11'h080 );
    init_memory_model_tx( 11'h040 );

    test_verify("case 1", 1, TEST1_C2S, 188, { 14880'h0, TEST1_AD }, TEST1_NONCE, TEST1_TAG);

    if (verbose>1) begin
      $display("%s:%0d ---------------------------------- Debug after Verify ----------------------------------", `__FILE__, `__LINE__);
      dump_ram(0,40);
      `dump("", dut.key_current_reg);
      `dump("", dut.key_c2s_reg);
      `dump("", dut.key_s2c_reg);
      `dump("", dut.core_tag_reg[0] );
      `dump("", dut.core_tag_reg[1] );
      dump_siv();
    end

    init_memory_model_rx( 11'h080 );
    init_memory_model_tx( 11'h040 );
    //write_ad( 200, 'h0 );
    if (verbose>1)
      dump_ram(0,40);

    i_op_copy_tx_ad = 1;
    i_copy_tx_addr = mem_tx_baseaddr;
    i_copy_tx_bytes = 188;
    #10;
    i_op_copy_tx_ad = 0;
    `assert(o_busy);
    wait_busy();

    if (verbose>1) begin
      $display("%s:%0d ---------------------------------- Debug before Generate Tag ----------------------------------", `__FILE__, `__LINE__);
      dump_ram(0,40);
      dump_siv();
   end

    generate_tag();
    if (verbose>1) begin
      $display("%s:%0d ---------------------------------- Debug after Generate Tag ----------------------------------", `__FILE__, `__LINE__);
      dump_ram(0,40);
      dump_siv();
    end

    test_generate_tag("case 1", TEST1_C2S, 188, { 14880'h0, TEST1_AD }, TEST1_NONCE, TEST1_TAG); //Gen tag

    i_op_store_tx_nonce_tag = 1;
    #10;
    i_op_store_tx_nonce_tag = 0;
    wait_busy();

    unwrap_test(
      "case 2",
      NTS_TEST_REQUEST_MASTER_KEY,
      NTS_TEST_REQUEST_MASTER_KEY_ID,
      NTS_TEST_COOKIE1,
      1'b1,
      NTS_TEST_COOKIE1_C2S,
      NTS_TEST_COOKIE1_S2C
    );
    if (verbose > 1) begin
      `dump("", dut.key_master_reg);
      `dump("", dut.key_c2s_reg);
      `dump("", dut.key_s2c_reg);
      `dump("", o_verify_tag_ok);
      `dump("", dut.core_tag_ok);
      dump_ram(0,70);
    end
    unwrap_recursive(
      "case 2r",
      10,
      NTS_TEST_REQUEST_MASTER_KEY,
      NTS_TEST_REQUEST_MASTER_KEY_ID,
      NTS_TEST_COOKIE1,
      NTS_TEST_COOKIE1_C2S,
      NTS_TEST_COOKIE1_S2C
    );

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

/*
  always @*
  begin
    if (verbose>2)
      if (dut.core_ack_reg)
        $display("%s:%0d Read: %h", `__FILE__, `__LINE__, dut.core_block_rd);
  end
*/

  //----------------------------------------------------------------
  // Testbench model: RX-Buff
  //----------------------------------------------------------------

  integer delay_rx_cnt;
  reg [63:0] delay_rx_value;

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_rx_wait <= 0;
      i_rx_rd_dv <= 0;
      i_rx_rd_data <= 0;
      delay_rx_cnt <= 0;
      delay_rx_value <= 0;
    end else begin
      i_rx_rd_dv <= 0;
      i_rx_rd_data <= 0;
      if (i_rx_wait) begin
        if (delay_rx_cnt < 3) begin
          delay_rx_cnt <= delay_rx_cnt+1;
        end else begin
          i_rx_wait <= 0;
          i_rx_rd_dv <= 1;
          i_rx_rd_data <= delay_rx_value;
        end
      end else if (o_rx_rd_en) begin : rx_buff
        reg [63:0] tmp;
        `assert(o_rx_wordsize == 3); //64bit
        tmp = mem_rx_func(o_rx_addr);
        i_rx_wait <= 1;
        delay_rx_cnt <= 0;
        delay_rx_value <= tmp;
        if (verbose>1) $display("%s:%0d RX-buff[%h]=%h", `__FILE__, `__LINE__, o_rx_addr, tmp);
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: TX-Buff
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_tx_read_data <= 0;
    end else begin
      i_tx_read_data <= 0;
      if (o_tx_read_en) begin : tx_buff
        reg [63:0] tmp;
        tmp = mem_tx_func(o_tx_address);
        i_tx_read_data <= tmp;
        if (verbose>1) $display("%s:%0d TX-buff[%h]=%h (read)", `__FILE__, `__LINE__, o_tx_address, tmp);
      end
      if (o_tx_write_en) begin
        mem_tx_update_delayed(o_tx_address, o_tx_write_data);
        if (verbose>1) $display("%s:%0d TX-buff[%h]=%h (write)", `__FILE__, `__LINE__, o_tx_address, o_tx_write_data);
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: Nonce Generator
  //----------------------------------------------------------------

  reg   [3:0] nonce_delay;

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_noncegen_nonce <= 64'h0;
      i_noncegen_ready <= 0;
      nonce_delay <= 0;
    end else begin
      i_noncegen_ready <= 0;
      if (nonce_delay == 4'hF) begin
        nonce_delay <= 0;
        if (nonce_set) begin
          i_noncegen_nonce <= (i_noncegen_nonce == nonce_set_a) ? nonce_set_b : nonce_set_a;
        end else begin
          i_noncegen_nonce <= i_noncegen_nonce + 1;
        end
        i_noncegen_ready <= 1;
      end else if (nonce_delay > 0) begin
        nonce_delay <= nonce_delay + 1;
      end else if (o_noncegen_get) begin
        nonce_delay <= 1;
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench System Clock Generator
  //----------------------------------------------------------------

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule