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
module nts_cookie_handler_tb #( parameter verbose = 2);

  localparam [15:0] NTP_TAG_NTS_COOKIE = 16'h0204;
/*
  //localparam [31:0] NTS_TEST_REQUEST_MASTER_KEY_ID=32'ha9f8;
  localparam [31:0] NTS_TEST_REQUEST_MASTER_KEY_ID=32'ha9f8318d;
  localparam [511:0] NTS_TEST_REQUEST_MASTER_KEY=512'h393221357cd4273f71d501eab96d5707e773a2116894775b7ba42602e70bdc6a;
  localparam [831:0] NTS_TEST_COOKIE1 = 832'h02040068a9f8318d0e430e06df91524bdadecdb55fcb348e21add23aefe21d739ca4456bd46dade6f3897c9918f1a59a1521c856ed7ae750e392b892e7343e9399453c23c465555422432c83af13108306443e795b84f7ba2e4ab116bd813d5830b85581431f4f08;
*/

/*6c47f0d3.key
3fc91575cf885a02820a019e846fa2a68c9aa6543f4c1ebabea74ca0d16aeda8
Cookie: 6c47f0d3cd65766f2c8fb4cc6b8d5b7aca60c5eca507af99a998d8395e045f75ffa2be8c3b025e7b46a4f2472777e251e4fc36b7ed1287f362cd54b1152488c5873a6fc70ec582beb3640aaae23038c694939e8d71c51d88f6a6def90efc99906cd3c2cb
C2S: 9e36980572b3cf91a8fb2f29b105a1d95439ebabeb61403e1aba654e9ba56176
S2C: 8f62b677d6c55010504abd646cf394cfc5990605f6032b0e8b7df00667cac34b*/
  localparam  [31:0] NTS_TEST_REQUEST_MASTER_KEY_ID = 32'h6c47f0d3;
  localparam [511:0] NTS_TEST_REQUEST_MASTER_KEY = 511'h3fc91575cf885a02820a019e846fa2a68c9aa6543f4c1ebabea74ca0d16aeda8;
  localparam [831:0] NTS_TEST_COOKIE1 = 832'h020400686c47f0d3cd65766f2c8fb4cc6b8d5b7aca60c5eca507af99a998d8395e045f75ffa2be8c3b025e7b46a4f2472777e251e4fc36b7ed1287f362cd54b1152488c5873a6fc70ec582beb3640aaae23038c694939e8d71c51d88f6a6def90efc99906cd3c2cb;

  reg           i_clk;
  reg           i_areset;
  reg   [3 : 0] i_key_word;
  reg           i_key_valid;
  reg           i_key_length;
  reg  [31 : 0] i_key_data;
  reg  [31 : 0] i_key_id;
  reg           i_cookie_nonce;
  reg           i_cookie_s2c;
  reg           i_cookie_c2s;
  reg           i_cookie_tag;
  reg   [3 : 0] i_cookie_word;
  reg  [31 : 0] i_cookie_data;
  reg           i_op_unwrap;
  wire          o_busy;
  wire          o_unwrap_tag_ok;
  wire          o_unrwapped_s2c;
  wire          o_unwrapped_c2s;
  wire  [3 : 0] o_unwrapped_word;
  wire [31 : 0] o_unwrapped_data;


  nts_cookie_handler dut (
    .i_clk(i_clk),
    .i_areset(i_areset),
    .i_key_word(i_key_word),
    .i_key_valid(i_key_valid),
    .i_key_length(i_key_length),
    .i_key_data(i_key_data),
    .i_key_id(i_key_id),
    .i_cookie_nonce(i_cookie_nonce),
    .i_cookie_s2c(i_cookie_s2c),
    .i_cookie_c2s(i_cookie_c2s),
    .i_cookie_tag(i_cookie_tag),
    .i_cookie_word(i_cookie_word),
    .i_cookie_data(i_cookie_data),
    .i_op_unwrap(i_op_unwrap),
    .o_busy(o_busy),
    .o_unwrap_tag_ok(o_unwrap_tag_ok),
    .o_unrwapped_s2c(o_unrwapped_s2c),
    .o_unwrapped_c2s(o_unwrapped_c2s),
    .o_unwrapped_word(o_unwrapped_word),
    .o_unwrapped_data(o_unwrapped_data)
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
      if (verbose>0) $display("%s:%0d wait_ready completed in %0d ticks", `__FILE__, `__LINE__, i);
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
       i_key_id = 0;
       #10;
      end
      i_key_word = 0;
      i_key_valid = 0;
      i_key_length = 0;
      i_key_data = 0;
      i_key_id = 0;
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
      integer i;
      integer j;
      /*if (keylen) begin*/
        for (i = 0; i < 16; i++) begin
          j = 15-i;
          i_key_word = j[3:0];
          i_key_valid = 1;
          i_key_length = keylen;
          i_key_data = key[i*32+:32];
          i_key_id = keyid;
          if (verbose>1)
            $display("%s:%0d key: %h (%h) keyid: %h", `__FILE__, `__LINE__, i_key_data, i_key_word, keyid );
          #10;
        end
      /*end else begin
        for (i = 0; i < 4; i++) begin
          j = 7 - i;
          i_key_word = j[3:0];
          i_key_valid = 1;
          i_key_length = 0;
          i_key_data = key[i*32+:32];
          i_key_id = keyid;
          if (verbose>1)
            $display("%s:%0d key: %h (%h) keyid: %h", `__FILE__, `__LINE__, i_key_data, i_key_word, keyid );
          #10;
        end
        for (i = 0; i < 4; i++) begin
          j = 15 - i;
          i_key_word = j[3:0];
          i_key_valid = 1;
          i_key_length = 0;
          i_key_data = key[i*32+:32];
          i_key_id = keyid;
          if (verbose>1)
            $display("%s:%0d key: %h (%h) keyid: %h", `__FILE__, `__LINE__, i_key_data, i_key_word, keyid );
          #10;
        end
        for (i = 0; i < 4; i++) begin
          j = 11 - i;
          i_key_word = j[3:0];
          i_key_valid = 1;
          i_key_length = 0;
          i_key_data = 0;
          i_key_id = keyid;
          if (verbose>1)
            $display("%s:%0d key: %h (%h) keyid: %h", `__FILE__, `__LINE__, i_key_data, i_key_word, keyid );
          #10;
        end
        for (i = 0; i < 4; i++) begin
          j = 3 - i;
          i_key_word = j[3:0];
          i_key_valid = 1;
          i_key_length = 0;
          i_key_data = 0;
          i_key_id = keyid;
          if (verbose>1)
            $display("%s:%0d key: %h (%h) keyid: %h", `__FILE__, `__LINE__, i_key_data, i_key_word, keyid );
          #10;
        end
      end*/
      i_key_word = 0;
      i_key_valid = 0;
      i_key_length = 0;
      i_key_data = 0;
      i_key_id = 0;
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
      integer i;
      integer j;
      split_chrony_cookie( ntp_extension_nts, valid_cookie, cookie_ad_keyid, cookie_nonce, cookie_tag, cookie_c_c2s, cookie_c_s2c );
      if (verbose>0) begin
        $display("%s:%0d write_cookie: cookie  %h", `__FILE__, `__LINE__, ntp_extension_nts );
        $display("%s:%0d write_cookie: AD:     %h", `__FILE__, `__LINE__, cookie_ad_keyid );
        $display("%s:%0d write_cookie: NONCE:  %h", `__FILE__, `__LINE__, cookie_nonce );
        $display("%s:%0d write_cookie: CIPHER: %h %h (c2s s2c)", `__FILE__, `__LINE__, cookie_c_c2s, cookie_c_s2c);
        $display("%s:%0d write_cookie: TAG:    %h", `__FILE__, `__LINE__, cookie_tag);
      end
      `assert(valid_cookie);
      i_cookie_data = 0;
      for (i = 0; i < 4; i = i + 1) begin
        j = 3 - i;
        { i_cookie_nonce, i_cookie_s2c, i_cookie_c2s, i_cookie_tag } = 4'b1000;
        i_cookie_data = cookie_nonce[i*32+:32];
        i_cookie_word = j[3:0];
        if (verbose>1)
          $display("%s:%0d nonce: %h (%h)", `__FILE__, `__LINE__, i_cookie_data, i_cookie_word );
        #10;
      end
      for (i = 0; i < 8; i = i + 1) begin
        j = 7 - i;
        { i_cookie_nonce, i_cookie_s2c, i_cookie_c2s, i_cookie_tag } = 4'b0100;
        i_cookie_data = cookie_c_s2c[i*32+:32];
        i_cookie_word = j[3:0];
        if (verbose>1)
          $display("%s:%0d s2c:   %h (%h)", `__FILE__, `__LINE__, i_cookie_data, i_cookie_word );
        #10;
      end
      for (i = 0; i < 8; i = i + 1) begin
        j = 7 - i;
        { i_cookie_nonce, i_cookie_s2c, i_cookie_c2s, i_cookie_tag } = 4'b0010;
        i_cookie_data = cookie_c_c2s[i*32+:32];
        i_cookie_word = j[3:0];
        if (verbose>1)
          $display("%s:%0d c2s:   %h (%h)", `__FILE__, `__LINE__, i_cookie_data, i_cookie_word );
        #10;
      end
      for (i = 0; i < 4; i = i + 1) begin
        j = 3 - i;
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


  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk = 0;
    i_areset = 1;
    i_key_word = 0;
    i_key_valid = 0;
    i_key_length = 0;
    i_key_data = 0;
    i_key_id = 0;
    i_cookie_nonce = 0;
    i_cookie_s2c = 0;
    i_cookie_c2s = 0;
    i_cookie_tag = 0;
    i_cookie_word = 0;
    i_cookie_data = 0;
    i_op_unwrap = 0;
    #10;
    i_areset = 0;
    #10;
    `assert( o_busy == 'b0 );
/*
    write_key_zero();
    write_cookie_zero();
    `assert( o_busy == 'b0 );
    #10;
    i_op_unwrap = 1;
    #10;
    `assert( o_busy );
    i_op_unwrap = 0;
    #10;
    `assert( o_busy );
    dump_aes_siv_inputs();
    wait_ready();
    end*/
    `dump("", NTS_TEST_REQUEST_MASTER_KEY);
    write_key(NTS_TEST_REQUEST_MASTER_KEY_ID, NTS_TEST_REQUEST_MASTER_KEY, 0);
    write_cookie(NTS_TEST_COOKIE1);
    #10;
    i_op_unwrap = 1;
    #10;
    `assert( o_busy );
    i_op_unwrap = 0;
    #10;
    dump_aes_siv_inputs();
    wait_ready();
    dump_aes_siv_inputs();

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
