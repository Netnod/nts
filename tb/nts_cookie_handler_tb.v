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
module nts_cookie_handler_tb #( parameter verbose = 1);

  localparam [15:0] NTP_TAG_NTS_COOKIE = 16'h0204;

/*
  Key File:  6c47f0d3.key
  Key Value: 3fc91575cf885a02820a019e846fa2a68c9aa6543f4c1ebabea74ca0d16aeda8
  Cookie:    6c47f0d3cd65766f2c8fb4cc6b8d5b7aca60c5eca507af99a998d8395e045f75ffa2be8c3b025e7b46a4f2472777e251e4fc36b7ed1287f362cd54b1152488c5873a6fc70ec582beb3640aaae23038c694939e8d71c51d88f6a6def90efc99906cd3c2cb
  C2S:       9e36980572b3cf91a8fb2f29b105a1d95439ebabeb61403e1aba654e9ba56176
  S2C:       8f62b677d6c55010504abd646cf394cfc5990605f6032b0e8b7df00667cac34b
*/
  localparam  [31:0] NTS_TEST_REQUEST_MASTER_KEY_ID = 32'h6c47f0d3;
  localparam [511:0] NTS_TEST_REQUEST_MASTER_KEY = 512'h3fc91575cf885a02820a019e846fa2a68c9aa6543f4c1ebabea74ca0d16aeda8;
  localparam [831:0] NTS_TEST_COOKIE1 = 832'h020400686c47f0d3cd65766f2c8fb4cc6b8d5b7aca60c5eca507af99a998d8395e045f75ffa2be8c3b025e7b46a4f2472777e251e4fc36b7ed1287f362cd54b1152488c5873a6fc70ec582beb3640aaae23038c694939e8d71c51d88f6a6def90efc99906cd3c2cb;

  reg           i_clk;
  reg           i_areset;
  reg   [3 : 0] i_key_word;
  reg           i_key_valid;
  reg           i_key_length;
  reg  [31 : 0] i_key_id;
  reg  [31 : 0] i_key_data;
  reg           i_cookie_nonce;
  reg           i_cookie_s2c;
  reg           i_cookie_c2s;
  reg           i_cookie_tag;
  reg   [3 : 0] i_cookie_word;
  reg  [31 : 0] i_cookie_data;
  reg           i_op_unwrap;
  reg           i_op_gencookie;
  wire          o_busy;
  wire          o_unwrap_tag_ok;
  wire          o_unrwapped_s2c;
  wire          o_unwrapped_c2s;
  wire  [2 : 0] o_unwrapped_word;
  wire [31 : 0] o_unwrapped_data;
  wire          o_noncegen_get;
  reg  [63 : 0] i_noncegen_nonce;
  reg           i_noncegen_ready;
  wire          o_cookie_valid;
  wire  [3 : 0] o_cookie_word;
  wire [63 : 0] o_cookie_data;

  reg         reset_unwrap_rx;
  reg [255:0] c2s;
  reg [255:0] s2c;
  reg   [7:0] reced_s2c;
  reg   [7:0] reced_c2s;
  reg   [3:0] nonce_delay;
  reg         nonce_set;
  reg  [63:0] nonce_set_a;
  reg  [63:0] nonce_set_b;
  reg [831:0] rx_cookie;

  nts_cookie_handler dut (
    .i_clk(i_clk),
    .i_areset(i_areset),
    .i_key_word(i_key_word),
    .i_key_valid(i_key_valid),
    .i_key_length(i_key_length),
    .i_key_id(i_key_id),
    .i_key_data(i_key_data),
    .i_cookie_nonce(i_cookie_nonce),
    .i_cookie_s2c(i_cookie_s2c),
    .i_cookie_c2s(i_cookie_c2s),
    .i_cookie_tag(i_cookie_tag),
    .i_cookie_word(i_cookie_word),
    .i_cookie_data(i_cookie_data),
    .i_op_unwrap(i_op_unwrap),
    .i_op_gencookie(i_op_gencookie),
    .o_busy(o_busy),
    .o_unwrap_tag_ok(o_unwrap_tag_ok),
    .o_unrwapped_s2c(o_unrwapped_s2c),
    .o_unwrapped_c2s(o_unwrapped_c2s),
    .o_unwrapped_word(o_unwrapped_word),
    .o_unwrapped_data(o_unwrapped_data),
    .o_noncegen_get(o_noncegen_get),
    .i_noncegen_nonce(i_noncegen_nonce),
    .i_noncegen_ready(i_noncegen_ready),
    .o_cookie_valid(o_cookie_valid),
    .o_cookie_word(o_cookie_word),
    .o_cookie_data(o_cookie_data)
  );

  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready flag to be set in dut.
  //----------------------------------------------------------------
  task wait_ready;
    begin : wready
      integer i;
      i = 0;
      while (o_busy) begin
        i = i + 1;
        #10;
      end
      if (verbose>1) $display("%s:%0d wait_ready completed in %0d ticks", `__FILE__, `__LINE__, i);
    end
  endtask // wait_ready

  task write_key_zero;
    begin : write_key_zero_locals
      integer i;
      for (i = 0; i < 16; i++) begin
       i_key_word = i[3:0];
       i_key_valid = 1;
       i_key_length = 1;
       i_key_data = { i[7:0], i[7:0], i[7:0], i[7:0] };
       #10;
      end
      i_key_word = 0;
      i_key_valid = 0;
      i_key_length = 0;
      i_key_data = 0;
      #10;
    end
  endtask

  `define dump(prefix, x) $display("%s:%0d **** %s%s = %h", `__FILE__, `__LINE__, prefix, `"x`", x)

  task dump_aes_siv_inputs;
    begin
      `dump("aes_siv_core.", dut.reset_n);
      `dump("aes_siv_core.", dut.config_encdec_reg);
      `dump("aes_siv_core.", dut.core_key);
      `dump("aes_siv_core.", dut.config_mode_reg);
      `dump("aes_siv_core.", dut.start_reg);
      `dump("aes_siv_core.", dut.ad_start_reg);
      `dump("aes_siv_core.", dut.ad_length_reg);
      `dump("aes_siv_core.", dut.nonce_start_reg);
      `dump("aes_siv_core.", dut.nonce_length_reg);
      `dump("aes_siv_core.", dut.pc_start_reg);
      `dump("aes_siv_core.", dut.pc_length_reg);
      `dump("aes_siv_core.", dut.core_cs);
      `dump("aes_siv_core.", dut.core_we);
      `dump("aes_siv_core.", dut.core_ack);
      `dump("aes_siv_core.", dut.core_block_rd);
      `dump("aes_siv_core.", dut.core_block_wr);
      `dump("aes_siv_core.", dut.core_tag_in);
      `dump("aes_siv_core.", dut.core_tag_out);
      `dump("aes_siv_core.", dut.core_tag_ok);
      `dump("aes_siv_core.", dut.core_ready);
    end
  endtask

  task write_cookie_zero;
    begin : write_cookie
      integer i;
      integer j;
      i_cookie_data = 0;
      for (j = 0; j < 4; j = j + 1) begin
        i_cookie_nonce = 0;
        i_cookie_s2c = 0;
        i_cookie_c2s = 0;
        i_cookie_tag = 0;
        case (j)
          0: i_cookie_nonce = 1;
          1: i_cookie_s2c = 1;
          2: i_cookie_c2s = 1;
          3: i_cookie_tag = 1;
        endcase
        for (i = 0; i < 16; i = i + 1) begin
           i_cookie_data = { j[3:0],i[3:0], j[3:0],i[3:0],j[3:0], i[3:0],j[3:0], i[3:0] };
           i_cookie_word = i[3:0];
           #10;
        end
      end
      #10;
      i_cookie_data = 0;
      i_cookie_nonce = 0;
      i_cookie_s2c = 0;
      i_cookie_c2s = 0;
      i_cookie_tag = 0;
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

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  task write_key ( input [31:0] keyid, input [511:0] key, input keylen );
    begin : write_key
      reg [4:0] i;
      reg [3:0] j;
      i_key_id = keyid;
      for (i = 0; i < 16; i++) begin
        j = 15-i[3:0];
        i_key_word = j[3:0];
        i_key_valid = 1;
        i_key_length = keylen;
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

  task write_cookie ( input [831:0] ntp_extension_nts );
    begin : write_cookie
      reg            valid_cookie;
      reg     [31:0] cookie_ad_keyid;
      reg    [127:0] cookie_nonce;
      reg    [255:0] cookie_c_c2s;
      reg    [255:0] cookie_c_s2c;
      reg    [127:0] cookie_tag;
      reg [4:0] i;
      reg [3:0] j;
      split_chrony_cookie( ntp_extension_nts, valid_cookie, cookie_ad_keyid, cookie_nonce, cookie_tag, cookie_c_c2s, cookie_c_s2c );
      if (verbose>1) begin
        $display("%s:%0d write_cookie: cookie  %h", `__FILE__, `__LINE__, ntp_extension_nts );
        $display("%s:%0d write_cookie: AD:     %h", `__FILE__, `__LINE__, cookie_ad_keyid );
        $display("%s:%0d write_cookie: NONCE:  %h", `__FILE__, `__LINE__, cookie_nonce );
        $display("%s:%0d write_cookie: CIPHER: %h %h (c2s s2c)", `__FILE__, `__LINE__, cookie_c_c2s, cookie_c_s2c);
        $display("%s:%0d write_cookie: TAG:    %h", `__FILE__, `__LINE__, cookie_tag);
      end
      `assert(valid_cookie);
      i_cookie_data = 0;
      for (i = 0; i < 4; i = i + 1) begin
        j = 3 - i[3:0];
        { i_cookie_nonce, i_cookie_s2c, i_cookie_c2s, i_cookie_tag } = 4'b1000;
        i_cookie_data = cookie_nonce[i*32+:32];
        i_cookie_word = j[3:0];
        if (verbose>1)
          $display("%s:%0d nonce: %h (%h)", `__FILE__, `__LINE__, i_cookie_data, i_cookie_word );
        #10;
      end
      for (i = 0; i < 8; i = i + 1) begin
        j = 7 - i[3:0];
        { i_cookie_nonce, i_cookie_s2c, i_cookie_c2s, i_cookie_tag } = 4'b0100;
        i_cookie_data = cookie_c_s2c[i*32+:32];
        i_cookie_word = j[3:0];
        if (verbose>1)
          $display("%s:%0d s2c:   %h (%h)", `__FILE__, `__LINE__, i_cookie_data, i_cookie_word );
        #10;
      end
      for (i = 0; i < 8; i = i + 1) begin
        j = 7 - i[3:0];
        { i_cookie_nonce, i_cookie_s2c, i_cookie_c2s, i_cookie_tag } = 4'b0010;
        i_cookie_data = cookie_c_c2s[i*32+:32];
        i_cookie_word = j[3:0];
        if (verbose>1)
          $display("%s:%0d c2s:   %h (%h)", `__FILE__, `__LINE__, i_cookie_data, i_cookie_word );
        #10;
      end
      for (i = 0; i < 4; i = i + 1) begin
        j = 3 - i[3:0];
        { i_cookie_nonce, i_cookie_s2c, i_cookie_c2s, i_cookie_tag } = 4'b0001;
        i_cookie_data = cookie_tag[i*32+:32];
        i_cookie_word = j[3:0];
        if (verbose>1)
          $display("%s:%0d tag:   %h (%h)", `__FILE__, `__LINE__, i_cookie_data, i_cookie_word );
        #10;
      end
      #10;
      #10;
      i_cookie_data = 0;
      i_cookie_nonce = 0;
      i_cookie_s2c = 0;
      i_cookie_c2s = 0;
      i_cookie_tag = 0;
    end
  endtask

  task start_unwrap;
  begin
    #10;
    i_op_unwrap = 1;
    #10;
    `assert( o_busy );
    i_op_unwrap = 0;
    #10;
    if (verbose>1) dump_aes_siv_inputs();
  end
  endtask

  task start_cookiegen;
  begin
    i_op_gencookie = 1;
    #10;
    i_op_gencookie = 0;
    #10;
  end
  endtask

  task reset_rx;
  begin
    reset_unwrap_rx = 1;
    #10;
    reset_unwrap_rx = 0;
    #10;
  end
  endtask

  task unwrap_test (
    input [127:0] testname_str,
    input [511:0] masterkey_value,
    input  [31:0] masterkey_keyid,
    input         masterkey_length,
    input [831:0] cookie,
    input         expect_success,
    input [255:0] expect_c2s,
    input [255:0] expect_s2c
  );
  begin
    if (verbose>1) begin
      $display("%s:%0d Unwrap [%s] start...", `__FILE__, `__LINE__, testname_str);
    end
    reset_rx();
    write_key(masterkey_keyid, masterkey_value, masterkey_length);
    write_cookie(cookie);
    start_unwrap();
    wait_ready();
    if (expect_success) begin
      `assert( o_unwrap_tag_ok );
      if (verbose>1) begin
        $display("%s:%0d UNWRAPPED %b S2C = %h", `__FILE__, `__LINE__, reced_s2c, s2c);
        $display("%s:%0d UNWRAPPED %b C2S = %h", `__FILE__, `__LINE__, reced_c2s, c2s);
      end
      `assert( reced_s2c == 8'hff );
      `assert( reced_c2s == 8'hff );
      `assert( c2s == expect_c2s );
      `assert( s2c == expect_s2c );
    end else begin
      `assert( o_unwrap_tag_ok == 'b0 );
    end
    if (verbose>0) begin
      $display("%s:%0d Unwrap [%s] executed with expected result (%0d).", `__FILE__, `__LINE__, testname_str, o_unwrap_tag_ok);
    end
  end
  endtask

  task unwrap_test_and_wrap (
    input [256:0] testname_str,
    input [511:0] masterkey_value,
    input  [31:0] masterkey_keyid,
    input         masterkey_length,
    input [831:0] cookie,
    input [127:0] wrap_new_nonce,
    input         expect_success,
    input [255:0] expect_c2s,
    input [255:0] expect_s2c,
    input [831:0] expect_cookie
  );
  begin
    if (verbose>1) begin
      $display("%s:%0d Unwrap_and_wrap [%s] start...", `__FILE__, `__LINE__, testname_str);
    end
    i_areset = 1;
    nonce_set = 1;
    nonce_set_a = wrap_new_nonce[127:64];
    nonce_set_b = wrap_new_nonce[63:0];
    #10;
    i_areset = 0;
    reset_rx();
    write_key(masterkey_keyid, masterkey_value, masterkey_length);
    write_cookie(cookie);
    start_unwrap();
    wait_ready();
    if (expect_success) begin
      `assert( o_unwrap_tag_ok );
      if (verbose>1) begin
        $display("%s:%0d UNWRAPPED %b S2C = %h", `__FILE__, `__LINE__, reced_s2c, s2c);
        $display("%s:%0d UNWRAPPED %b C2S = %h", `__FILE__, `__LINE__, reced_c2s, c2s);
      end
      `assert( reced_s2c == 8'hff );
      `assert( reced_c2s == 8'hff );
      `assert( c2s == expect_c2s );
      `assert( s2c == expect_s2c );
    end else begin
      `assert( o_unwrap_tag_ok == 'b0 );
    end

    start_cookiegen();
    wait_ready();

    if (verbose>1) begin
      if (expect_cookie != rx_cookie) begin
        $display("%s:%0d Expected = %h", `__FILE__, `__LINE__, expect_cookie);
        $display("%s:%0d RxCookie = %h", `__FILE__, `__LINE__, rx_cookie);
      end
    end
    `assert(expect_cookie == rx_cookie);

    if (verbose>0) begin
      $display("%s:%0d Unwrap_and_wrap [%s] executed with expected result (%0d).", `__FILE__, `__LINE__, testname_str, o_unwrap_tag_ok);
    end
  end
  endtask

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk = 0;
    i_areset = 1;
    i_key_word = 0;
    i_key_valid = 0;
    i_key_length = 0;
    i_key_data = 0;
    i_cookie_nonce = 0;
    i_cookie_s2c = 0;
    i_cookie_c2s = 0;
    i_cookie_tag = 0;
    i_cookie_word = 0;
    i_cookie_data = 0;
    i_op_unwrap = 0;
    i_op_gencookie = 0;
    nonce_set = 0;
    nonce_set_a = 0;
    nonce_set_b = 0;
    reset_unwrap_rx = 0;
    #10;
    i_areset = 0;
    #10;
    `assert( o_busy == 'b0 );

    unwrap_test("Testcase Bad", NTS_TEST_REQUEST_MASTER_KEY, NTS_TEST_REQUEST_MASTER_KEY_ID, 0, {32'h02040068, 800'h0}, 0, 0, 0);

    unwrap_test("Testcase 1", NTS_TEST_REQUEST_MASTER_KEY, NTS_TEST_REQUEST_MASTER_KEY_ID, 0, NTS_TEST_COOKIE1, 1, 256'h9e36980572b3cf91a8fb2f29b105a1d95439ebabeb61403e1aba654e9ba56176, 256'h8f62b677d6c55010504abd646cf394cfc5990605f6032b0e8b7df00667cac34b );

    start_cookiegen();

    wait_ready();
    #200;

    unwrap_test_and_wrap(
      "c == WRAP(k, n, UNWRAP(k, n, c))",
      NTS_TEST_REQUEST_MASTER_KEY,
      NTS_TEST_REQUEST_MASTER_KEY_ID,
      0,
      NTS_TEST_COOKIE1,
      128'hcd65766f2c8fb4cc6b8d5b7aca60c5ec,
      1,
      256'h9e36980572b3cf91a8fb2f29b105a1d95439ebabeb61403e1aba654e9ba56176,
      256'h8f62b677d6c55010504abd646cf394cfc5990605f6032b0e8b7df00667cac34b,
      NTS_TEST_COOKIE1
     );

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      c2s <= 0;
      s2c <= 0;
      reced_s2c <= 0;
      reced_c2s <= 0;
      rx_cookie <= 0;
    end else begin
      if (reset_unwrap_rx) begin
        c2s <= 0;
        s2c <= 0;
        reced_s2c <= 0;
        reced_c2s <= 0;
        rx_cookie <= 0;
      end else begin
        if (o_unrwapped_s2c) begin
          s2c[o_unwrapped_word*32+:32] <= o_unwrapped_data;
          reced_s2c[o_unwrapped_word] <= 1;
          if (verbose>1) $display("%s:%0d UNWRAPPED S2C[%0d] = %h", `__FILE__, `__LINE__, o_unwrapped_word, o_unwrapped_data);
        end
        if (o_unwrapped_c2s) begin
          c2s[o_unwrapped_word*32+:32] <= o_unwrapped_data;
          reced_c2s[o_unwrapped_word] <= 1;
          if (verbose>1) $display("%s:%0d UNWRAPPED C2S[%0d] = %h", `__FILE__, `__LINE__, o_unwrapped_word, o_unwrapped_data);
        end
      end

      if (o_cookie_valid) begin : rx_cookie_count
        reg [3:0] rx_pos;
        rx_pos = 12 - o_cookie_word;
        if (verbose>1) $display("%s:%0d o_cookie_word=%h, o_cookie_data=%h", `__FILE__, `__LINE__, o_cookie_word, o_cookie_data);
        rx_cookie[rx_pos*64+:64] <= o_cookie_data;
      end

    end
  end

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

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
