//
// Copyright (c) 2019-2020, The Swedish Post and Telecom Authority (PTS)
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
  parameter verbose = 2 // 0: Silent. 1. Informative messages. 2. Traces. 3. Extreme traces.
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
  wire                   o_error;
  wire                   o_verify_tag_ok;

  reg            [2 : 0] i_key_word;
  reg                    i_key_valid;
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
  reg                    i_op_store_tx_cookiebuf;
  reg                    i_op_cookie_loadkeys;
  reg                    i_op_cookie_rencrypt;
  reg                    i_op_cookiebuf_appendcookie;
  reg                    i_op_cookiebuf_reset;

  reg              [63:0] i_cookie_prefix;

  reg  [ADDR_WIDTH+3-1:0] i_copy_rx_addr;
  reg  [ADDR_WIDTH+3-1:0] i_copy_rx_bytes;

  reg  [ADDR_WIDTH+3-1:0] i_copy_tx_addr;
  reg  [ADDR_WIDTH+3-1:0] i_copy_tx_bytes;


  reg                     i_rx_wait;
  wire [ADDR_WIDTH+3-1:0] o_rx_addr;
  wire              [2:0] o_rx_wordsize;
  wire [ADDR_WIDTH+3-1:0] o_rx_burstsize;
  wire                    o_rx_rd_en;
  reg                     i_rx_rd_dv;
  reg [RX_PORT_WIDTH-1:0] i_rx_rd_data;

  reg                     i_tx_busy;
  wire                    o_tx_read_en;
  reg                     i_tx_read_dv;
  reg              [63:0] i_tx_read_data;
  wire                    o_tx_write_en;
  wire             [63:0] o_tx_write_data;
  wire [ADDR_WIDTH+3-1:0] o_tx_address;

  wire                    o_noncegen_get;
  reg            [63 : 0] i_noncegen_nonce;
  reg                     i_noncegen_ready;
  reg                     i_noncegen_nonce_valid;

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
    .o_error(o_error),
    .o_verify_tag_ok(o_verify_tag_ok),

    .i_key_word(i_key_word),
    .i_key_valid(i_key_valid),
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
    .i_op_store_tx_cookiebuf(i_op_store_tx_cookiebuf),
    .i_op_cookie_loadkeys(i_op_cookie_loadkeys),
    .i_op_cookie_rencrypt(i_op_cookie_rencrypt),
    .i_op_cookiebuf_reset(i_op_cookiebuf_reset),
    .i_op_cookiebuf_appendcookie(i_op_cookiebuf_appendcookie),

    .i_cookie_prefix(i_cookie_prefix),

    .i_copy_rx_addr(i_copy_rx_addr),
    .i_copy_rx_bytes(i_copy_rx_bytes),
    .i_copy_tx_addr(i_copy_tx_addr),
    .i_copy_tx_bytes(i_copy_tx_bytes),

    .i_rx_wait(i_rx_wait),
    .o_rx_addr(o_rx_addr),
    .o_rx_wordsize(o_rx_wordsize),
    .o_rx_burstsize(o_rx_burstsize),
    .o_rx_rd_en(o_rx_rd_en),
    .i_rx_rd_dv(i_rx_rd_dv),
    .i_rx_rd_data(i_rx_rd_data),

    .i_tx_busy(i_tx_busy),
    .o_tx_read_en(o_tx_read_en),
    .i_tx_read_dv(i_tx_read_dv),
    .i_tx_read_data(i_tx_read_data),
    .o_tx_write_en(o_tx_write_en),
    .o_tx_write_data(o_tx_write_data),
    .o_tx_address(o_tx_address),

    .o_noncegen_get(o_noncegen_get),
    .i_noncegen_nonce(i_noncegen_nonce),
    .i_noncegen_nonce_valid(i_noncegen_nonce_valid),
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
        i_key_word = i[2:0];
        i_key_valid = 1;
        i_key_data = key[i*32+:32];
        if (verbose>1)
          $display("%s:%0d key: %h (%h) keyid: %h", `__FILE__, `__LINE__, i_key_data, i_key_word, keyid );
        #10;
      end
      i_key_word = 0;
      i_key_valid = 0;
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

  task wait_busy ( input integer line );
  begin : wait_busy
    integer i;
    i = 0;
    while (o_busy) begin
      #10;
      i = i + 1;
    end
    if (verbose>1)
      $display("%s:%0d:%0d wait_busy completed in %0d ticks.", `__FILE__, `__LINE__, line, i);
  end
  endtask

  task write_rx_ad(
    input [ADDR_WIDTH+3-1:0] bytes_count,
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

    wait_busy( `__LINE__ );
    i_op_copy_rx_ad = 1;
    i_copy_rx_addr = mem_rx_baseaddr;
    i_copy_rx_bytes = bytes_count;
    #10;
    i_op_copy_rx_ad = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task write_tx_ad(
    input [ADDR_WIDTH+3-1:0] bytes_count,
    input          [16383:0] ad
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

    wait_busy( `__LINE__ );
    i_op_copy_tx_ad = 1;
    i_copy_tx_addr = mem_tx_baseaddr;
    i_copy_tx_bytes = bytes_count;
    #10;
    i_op_copy_tx_ad = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask


  task write_rx_nonce (
    input [127:0] nonce
  );
  begin
    mem_rx[32] = nonce[127:64];
    mem_rx[33] = nonce[63:0];
    wait_busy( `__LINE__ );
    i_op_copy_rx_nonce = 1;
    i_copy_rx_addr = mem_rx_baseaddr + (32*8);
    i_copy_rx_bytes = 16;
    #10;
    i_op_copy_rx_nonce = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task write_rx_tag (
    input [127:0] tag
  );
  begin
    mem_rx[35] = tag[127:64];
    mem_rx[36] = tag[63:0];
    wait_busy( `__LINE__ );
    i_op_copy_rx_tag = 1;
    i_copy_rx_addr = mem_rx_baseaddr + (35*8);
    i_copy_rx_bytes = 16;
    #10;
    i_op_copy_rx_tag = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
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
    wait_busy( `__LINE__ );
    i_op_copy_rx_pc = 1;
    i_copy_rx_addr = mem_rx_baseaddr + (37*8);
    i_copy_rx_bytes = 64; /*512bits; 256(128+128) * 2 */
    #10;
    i_op_copy_rx_pc = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task verify_c2s;
  begin
    wait_busy( `__LINE__ );
    i_op_verify_c2s = 1;
    #10;
    i_op_verify_c2s = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task verify_cookie;
  begin
    wait_busy( `__LINE__ );
    i_op_cookie_verify = 1;
    #10;
    i_op_cookie_verify = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task cookie_loadkeys;
  begin
    wait_busy( `__LINE__ );
    i_op_cookie_loadkeys = 1;
    #10;
    i_op_cookie_loadkeys = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task cookie_rencrypt;
  begin
    wait_busy( `__LINE__ );
    i_op_cookie_rencrypt = 1;
    #10;
    i_op_cookie_rencrypt = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task generate_tag;
  begin
    wait_busy( `__LINE__ );
    i_op_generate_tag = 1;
    #10;
    i_op_generate_tag = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task store_nonce_tag (
    output [255:0] nonce_tag
  );
  begin : store_nonce_tag
    reg [63:0] a;
    reg [63:0] b;
    reg [63:0] c;
    reg [63:0] d;
    wait_busy( `__LINE__ );
    i_op_store_tx_nonce_tag = 1;
    i_copy_tx_addr = 64; // some address, whatever
    i_copy_tx_bytes = 32; //nonce=16, tag=16
    #10;
    i_op_store_tx_nonce_tag = 0;
    i_copy_tx_addr = 0;
    i_copy_tx_bytes = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
    a = mem_tx_func(64);
    b = mem_tx_func(64+1*8);
    c = mem_tx_func(64+2*8);
    d = mem_tx_func(64+3*8);
    //$display("%s:%0d %h %h %h %h", `__FILE__, `__LINE__, a, b, c, d );
    nonce_tag = { a, b, c, d };
  end
  endtask

  task store_cookiebuffer;
  begin
    wait_busy( `__LINE__ );
    i_op_store_tx_cookiebuf = 1;
    i_copy_tx_addr = 64+4*8; // some address, whatever. offsetted 0 from last task store_nonce_tag write.
    i_copy_tx_bytes = 0; //unused
    #10;
    i_op_store_tx_cookiebuf = 0;
    i_copy_tx_addr = 0;
    i_copy_tx_bytes = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task cookiebuf_reset;
  begin
    wait_busy( `__LINE__ );
    i_op_cookiebuf_reset = 1;
    #10;
    i_op_cookiebuf_reset = 0;
    `assert(o_busy == 'b0); //TODO change behaivor to be more similar to other ops?
    //wait_busy( `__LINE__ );
  end
  endtask

  task cookiebuf_record_cookie( input [63:0] cookie_prefix );
  begin
    wait_busy( `__LINE__ );
    i_cookie_prefix = cookie_prefix;
    i_op_cookiebuf_appendcookie = 1;
    #10;
    i_op_cookiebuf_appendcookie = 0;
    i_cookie_prefix = 0;
    `assert(o_busy);
    wait_busy( `__LINE__ );
  end
  endtask

  task dump_ram_row ( input [9:0] row);
    $display("%s:%0d dump_ram - dut.mem.ram[0x%h]=0x%h", `__FILE__, `__LINE__, row, dut.mem.ram[row]);
  endtask

  task dump_ram( input [9:0] first, input [9:0] last);
  begin : dump_ram
    reg [9:0] i ;
    $display("%s:%0d dump_ram( %h...%h )", `__FILE__, `__LINE__, first, last );
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
     input             [63:0] description,
     input                    expect_success,
     input            [255:0] c2s,
     input [ADDR_WIDTH+3-1:0] ad_bytes_count,
     input          [16383:0] ad,
     input            [127:0] nonce,
     input            [127:0] tag
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
     input             [63:0] description,
     input            [255:0] s2c,
     input [ADDR_WIDTH+3-1:0] ad_bytes_count,
     input          [16383:0] ad,
     input            [127:0] nonce,
     input            [127:0] tag
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

    cookiebuf_reset();
    write_s2c(s2c);
    write_tx_ad( ad_bytes_count, ad );

    generate_tag();

    `assert( dut.core_tag_out == tag );

    begin : test_generate_tag_locals
      reg [255:0] nonce_tag;
      reg [255:0] expected_nonce_tag;
      integer i;
      store_nonce_tag( nonce_tag );

      expected_nonce_tag = { nonce, tag };
      if (verbose > 2)
        for (i = 255; i > 0; i = i - 64)
          $display("%s:%0d test_generate_tag [ %s ] NT[%0d-:64] Expected: %h... Calculated: %h...", `__FILE__, `__LINE__, description, i, expected_nonce_tag[i-:64], nonce_tag[i-:64]);
      `assert( nonce_tag == expected_nonce_tag );
    end

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
    input [831:0] cookie,
    input         expect_success,
    input [255:0] expect_c2s,
    input [255:0] expect_s2c
  );
  begin
    if (verbose>1) begin
      $display("%s:%0d Unwrap [%s] start...", `__FILE__, `__LINE__, testname_str);
    end
    write_key(masterkey_keyid, masterkey_value);

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
    write_key(masterkey_keyid, masterkey_value);
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

    if (verbose>1) begin
      $display("%s:%0d Unwrap_reursive [%s][%0d] executed with result: %d. Cookie: %h...", `__FILE__, `__LINE__, testname_str, recursions,o_verify_tag_ok, cookie);
    end
    cookie_rencrypt();

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
    if (verbose>1) $display("%s:%0d Cookie: %h...", `__FILE__, `__LINE__, cookie_out);
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

  function [63:0] inspect_dut_ram( input [9:0] i );
    inspect_dut_ram = dut.mem.ram[i];
  endfunction

  task cookie_buffer_test (
    input [127:0] testname_str,
    input integer cookies_to_generate,
    input [255:0] masterkey_value,
    input  [31:0] masterkey_keyid,
    input [831:0] cookie
  );
  begin : cookie_buffer_test
    integer i;
    reg         valid_cookie;
    reg  [31:0] cookie_keyid;
    reg [127:0] cookie_nonce;
    reg [127:0] cookie_tag;
    reg [511:0] cookie_ciphertext;
    reg   [9:0] tmp;
    reg  [63:0] expected64;
    reg  [63:0] actual64;
    if (verbose>0) begin
      $display("%s:%0d cookie_buffer [%s] start...", `__FILE__, `__LINE__, testname_str);
    end

    nonce_set = 0;
    i_areset = 1;
    #10;
    i_areset = 0;
    #100;

    write_key(masterkey_keyid, masterkey_value);

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
      $display("%s:%0d cookie_buffer: cookie: %h", `__FILE__, `__LINE__, cookie );
      $display("%s:%0d cookie_buffer: keyid:  %h", `__FILE__, `__LINE__, cookie_keyid );
      $display("%s:%0d cookie_buffer: NONCE:  %h", `__FILE__, `__LINE__, cookie_nonce );
      $display("%s:%0d cookie_buffer: CIPHER: %h", `__FILE__, `__LINE__, cookie_ciphertext );
      $display("%s:%0d cookie_buffer: TAG:    %h", `__FILE__, `__LINE__, cookie_tag );
    end

    `assert(valid_cookie);

    verify_cookie();
    cookiebuf_reset();
    for (i = 0; i < cookies_to_generate; i = i + 1) begin
      if (verbose>1)
         $display("%s:%0d cookie_buffer: rencrypt cookie", `__FILE__, `__LINE__);

      cookie_rencrypt();

      if (verbose>1)
         $display("%s:%0d cookie_buffer: rencrypt cookie", `__FILE__, `__LINE__);

      cookiebuf_record_cookie( { NTP_TAG_NTS_COOKIE, 16'h0068, cookie_keyid } );

    end
    tmp = cookies_to_generate[9:0];
    tmp = tmp * ('h68/8);
    tmp = tmp + 768 - 1;

    if (verbose>1) begin
      $display("%s:%0d cookie_buffer: RAM before cookie encryption", `__FILE__, `__LINE__);
      dump_ram(768, tmp);
    end
    expected64 = { 32'h02040068, masterkey_keyid };
    actual64 = inspect_dut_ram(768);
    //$display("%s:%0d XXX %h", `__FILE__, `__LINE__, inspect_dut_ram(768));
    `assert( expected64 === actual64 );

    generate_tag();
    if (verbose>1) begin
      $display("%s:%0d cookie_buffer: RAM after cookie encryption", `__FILE__, `__LINE__);
      dump_ram(768, tmp);
    end
    expected64 = { 32'h02040068, masterkey_keyid }; //we should NOT get the expected value. Reverse logic.
    actual64 = inspect_dut_ram(768);
    //$display("%s:%0d YYY %h %h", `__FILE__, `__LINE__, { 32'h02040068, masterkey_keyid }, inspect_dut_ram(768));
    `assert( expected64 !== actual64 );

    store_cookiebuffer();
  end
  endtask

  task test_copy_ad;
  begin : test_copy_ad
    reg  [63:0] ad1;
    reg [127:0] ad2;
    reg  [63:0] tmp1;
    reg  [63:0] tmp2;
    ad1 =  64'hf0f1_f2f3_f4f5_f6f7;
    ad2 = 128'he0e1_e2e3_e4e5_e6e7_d0d1_d2d3_d4d5_d6d7;

    write_tx_ad( 8, { 16320'h0, ad1 } );
    tmp1 = inspect_dut_ram(512);
    //$display("%s:%0d tmp1: %h expected: %h", `__FILE__, `__LINE__, tmp1, ad1);
    `assert( tmp1 === ad1 );

    write_tx_ad( 16, { 16256'h0, ad2 } );
    tmp1 = inspect_dut_ram(512);
    tmp2 = inspect_dut_ram(513);
    //$display("%s:%0d tmp1,2: %h %h expected: %h", `__FILE__, `__LINE__, tmp1, tmp2, ad2);
    `assert( tmp1 === ad2[127:64] );
    `assert( tmp2 === ad2[63:0] );

    write_tx_ad( 8, { 16320'h0, ad1 } );
    tmp1 = inspect_dut_ram(512);
    tmp2 = inspect_dut_ram(513);
    `assert( tmp1 === ad1 );
    `assert( tmp2 === ad2[63:0] );

    write_tx_ad( 16, { 16256'h0, ad2 } );
    tmp1 = inspect_dut_ram(512);
    tmp2 = inspect_dut_ram(513);
    `assert( tmp1 === ad2[127:64] );
    `assert( tmp2 === ad2[63:0] );
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
    i_op_store_tx_cookiebuf = 0;
    i_op_cookie_loadkeys = 0;
    i_op_cookiebuf_appendcookie = 0;
    i_op_cookiebuf_reset = 0;

    i_copy_rx_addr = 0;
    i_copy_rx_bytes = 0;
    i_copy_tx_addr = 0;
    i_copy_tx_bytes = 0;
    i_tx_busy = 0;
    i_tx_read_data = 0;

    nonce_set = 0;
    nonce_set_a = 0;
    nonce_set_b = 0;

    #10;
    i_areset = 0;
    #10;
    init_memory_model_rx( 11'h080 );
    init_memory_model_tx( 11'h040 );

    #20;

    test_copy_ad();

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
    wait_busy( `__LINE__ );

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
    wait_busy( `__LINE__ );

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

    cookie_buffer_test("crypt7", 7, NTS_TEST_REQUEST_MASTER_KEY, NTS_TEST_REQUEST_MASTER_KEY_ID, NTS_TEST_COOKIE1);

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  //----------------------------------------------------------------
  // Testbench model: RX-Buff
  //----------------------------------------------------------------

  integer                delay_rx_cnt;
  reg [ADDR_WIDTH+3-1:0] delay_rx_current;
  reg [ADDR_WIDTH+3-1:0] delay_rx_burst;


  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_rx_wait <= 0;
      i_rx_rd_dv <= 0;
      i_rx_rd_data <= 0;
      delay_rx_cnt <= 0;
      delay_rx_current <= 0;
      delay_rx_burst <= 0;

    end else begin
      i_rx_rd_dv <= 0;
      i_rx_rd_data <= 0;
      if (i_rx_wait) begin
        if (delay_rx_cnt < 3) begin
          delay_rx_cnt <= delay_rx_cnt + 1;
        end else begin
          if (delay_rx_burst > 0) begin : rx_out
            reg [63:0] tmp;
            tmp = mem_rx_func( delay_rx_current );
            if (verbose>1) $display("%s:%0d RX-buff[%h]=%h (burstsize: %0d)", `__FILE__, `__LINE__, o_rx_addr, tmp, delay_rx_burst);
            i_rx_rd_dv <= 1;
            i_rx_rd_data <= tmp;
          end
          if (delay_rx_burst <= 8) begin
            i_rx_wait <= 0;
          end else begin
            delay_rx_current <= delay_rx_current + 8;
            delay_rx_burst <= delay_rx_burst - 8;
          end
        end
      end else if (o_rx_rd_en) begin
        case (o_rx_wordsize)
          3: begin
               delay_rx_current <= o_rx_addr;
               delay_rx_burst <= 8;
             end
          4: begin
               delay_rx_current <= o_rx_addr;
               delay_rx_burst <= o_rx_burstsize;
             end
          default: `assert( 0 == 1 )
        endcase
        i_rx_wait <= 1;
        delay_rx_cnt <= 0;
      end
    end
  end

  always @(posedge i_clk or posedge i_areset)
    if (i_areset)
      ;
    else begin
      if (o_error)
        $display("%s:%0d =====> ERROR!!! <====",  `__FILE__, `__LINE__);
      `assert( o_error == 'b0 );
     end

  //----------------------------------------------------------------
  // Testbench model: TX-Buff
  //----------------------------------------------------------------

  // TX RTL is allowed to wait before responding to read,
  // but must support sequensial burst reads.
  // This little delay pipeline simulates how TX RTL might
  // behave.
  reg        tx_delay0_dv;
  reg [63:0] tx_delay0_data;
  reg        tx_delay1_dv;
  reg [63:0] tx_delay1_data;
  reg        tx_delay2_dv;
  reg [63:0] tx_delay2_data;

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_tx_read_dv <= 0;
      i_tx_read_data <= 0;
      tx_delay0_dv <= 0;
      tx_delay0_data <= 0;
      tx_delay1_dv <= 0;
      tx_delay1_data <= 0;
      tx_delay2_dv <= 0;
      tx_delay2_data <= 0;
    end else begin
      i_tx_read_dv <= tx_delay2_dv;
      i_tx_read_data <= tx_delay2_data;
      tx_delay0_dv <= 0;
      tx_delay0_data <= 0;
      tx_delay1_dv <= tx_delay0_dv;
      tx_delay1_data <= tx_delay0_data;
      tx_delay2_dv <= tx_delay1_dv;
      tx_delay2_data <= tx_delay1_data;

      if (o_tx_read_en) begin : tx_buff
        reg [63:0] tmp;
        tmp = mem_tx_func(o_tx_address);
        tx_delay0_dv <= 1;
        tx_delay0_data <= tmp;
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
      i_noncegen_nonce_valid <= 0;
      nonce_delay <= 0;
    end else begin
      i_noncegen_ready <= 0;
      i_noncegen_nonce_valid <= 0;
      if (nonce_delay == 4'hF) begin
        nonce_delay <= 0;
        if (nonce_set) begin
          i_noncegen_nonce <= (i_noncegen_nonce == nonce_set_a) ? nonce_set_b : nonce_set_a;
        end else begin
          i_noncegen_nonce <= i_noncegen_nonce + 1;
        end
        i_noncegen_ready <= 1;
        i_noncegen_nonce_valid <= 1;
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

  //----------------------------------------------------------------
  // Useful debug output
  //----------------------------------------------------------------

  if (verbose>1) begin
    always @(posedge i_clk or posedge i_areset)
      if (dut.core_start_reg) dump_siv();
  end

endmodule
