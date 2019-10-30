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

module nts_verify_secure_tb #( parameter verbose = 2 );
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

  localparam RX_PORT_WIDTH = 64;
  localparam ADDR_WIDTH = 8;


  reg  i_areset; // async reset
  reg  i_clk;
  wire o_busy;

  reg          i_unrwapped_s2c;
  reg          i_unwrapped_c2s;
  reg  [2 : 0] i_unwrapped_word;
  reg [31 : 0] i_unwrapped_data;

  reg                    i_op_copy_rx_ad;
  reg                    i_op_copy_rx_nonce;
  reg                    i_op_copy_rx_tag;
  reg                    i_op_verify;

  reg  [ADDR_WIDTH+3-1:0] i_copy_rx_addr;
  reg               [9:0] i_copy_rx_bytes;

  reg                     i_rx_wait;
  wire [ADDR_WIDTH+3-1:0] o_rx_addr;
  wire              [2:0] o_rx_wordsize;
  wire                    o_rx_rd_en;
  reg                     i_rx_rd_dv;
  reg [RX_PORT_WIDTH-1:0] i_rx_rd_data;

  nts_verify_secure #(.RX_PORT_WIDTH(RX_PORT_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),
    .o_busy(o_busy),
    .i_unrwapped_s2c(i_unrwapped_s2c),
    .i_unwrapped_c2s(i_unwrapped_c2s),
    .i_unwrapped_word(i_unwrapped_word),
    .i_unwrapped_data(i_unwrapped_data),
    .i_op_copy_rx_ad(i_op_copy_rx_ad),
    .i_op_copy_rx_nonce(i_op_copy_rx_nonce),
    .i_op_copy_rx_tag(i_op_copy_rx_tag),
    .i_op_verify(i_op_verify),
    .i_copy_rx_addr(i_copy_rx_addr),
    .i_copy_rx_bytes(i_copy_rx_bytes),
    .i_rx_wait(i_rx_wait),
    .o_rx_addr(o_rx_addr),
    .o_rx_wordsize(o_rx_wordsize),
    .o_rx_rd_en(o_rx_rd_en),
    .i_rx_rd_dv(i_rx_rd_dv),
    .i_rx_rd_data(i_rx_rd_data)
  );

  `define dump(prefix, x) $display("%s:%0d **** %s%s = %h", `__FILE__, `__LINE__, prefix, `"x`", x)
  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  task write_c2s(
    input [255:0] c2s
  );
  begin : load_c2s
    integer i;
    reg [2:0] j;
    if (verbose>0) $display("%s:%0d write_c2s", `__FILE__, `__LINE__);
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

  reg [63:0] mem_tmp[0:255];
  reg [ADDR_WIDTH+3-1:0] mem_tmp_baseaddr;

  function [63:0] mem_func( input [ADDR_WIDTH+3-1:0] addr );
  begin : mem_func__
    reg [ADDR_WIDTH+3-1:0] a;
    a = addr[ADDR_WIDTH+3-1:3] - mem_tmp_baseaddr[ADDR_WIDTH+3-1:3];
    $display("%s:%0d mem_func(%h)=mem_tmp[%h]=%h", `__FILE__, `__LINE__, addr, a, mem_tmp[a]);
    mem_func = mem_tmp[a];
  end
  endfunction

  task init_memory_model ( input [ADDR_WIDTH+3-1:0] addr );
  begin : init_memory_model
    integer i;

    mem_tmp_baseaddr = addr;

    #10;
    for (i = 0; i < 256; i = i + 1)
      mem_tmp[i] = { 32'hffffffff, i };
  end
  endtask

  task write_ad(
    input              [9:0] bytes_count,
    input          [16383:0] ad
  );
  begin : write_ad
    integer i;
    integer j;
    `dump( "", ad );
    `dump( " 160 ? ", bytes_count );
    `dump( " 160 / 8 ? ", bytes_count[7:3] );
    `dump( " 160 % 8 ? ", bytes_count[2:0] );
    j = 0;
    for (i = bytes_count[7:3]; i > 0; i = i - 1) begin : offset_calc
      integer offset;
      offset = (64*i) + (8*bytes_count[2:0]) - 1;
      mem_tmp[j] = ad[offset-:64];
      `dump( "", i );
      `dump( "", offset );
      `dump( "", mem_tmp[j] );
      j = j + 1;
    end
    case (bytes_count[2:0])
      1: mem_tmp[j] = { ad[0+:8], 56'h0 };
      2: mem_tmp[j] = { ad[0+:16], 48'h0 };
      3: mem_tmp[j] = { ad[0+:24], 40'h0 };
      4: mem_tmp[j] = { ad[0+:32], 32'h0 };
      5: mem_tmp[j] = { ad[0+:40], 24'h0 };
      6: mem_tmp[j] = { ad[0+:48], 16'h0 };
      7: mem_tmp[j] = { ad[0+:56], 8'h0 };
    endcase
    `dump( "", mem_tmp[j] );

    while (o_busy) #10;
    i_op_copy_rx_ad = 1;
    i_copy_rx_addr = mem_tmp_baseaddr;
    i_copy_rx_bytes = bytes_count;
    #10;
    i_op_copy_rx_ad = 0;
    `assert(o_busy);
    while (o_busy) begin
      #10;
    end

  end
  endtask

  task write_nonce (
    input [127:0] nonce
  );
  begin
    mem_tmp[32] = nonce[127:64];
    mem_tmp[33] = nonce[63:0];
    while (o_busy) #10;
    i_op_copy_rx_nonce = 1;
    i_copy_rx_addr = mem_tmp_baseaddr + (32*8);
    i_copy_rx_bytes = 16;
    #10;
    i_op_copy_rx_nonce = 0;
    `assert(o_busy);
    while (o_busy) begin
      #10;
    end
  end
  endtask

  task write_tag (
    input [127:0] tag
  );
  begin
    mem_tmp[35] = tag[127:64];
    mem_tmp[36] = tag[63:0];
    while (o_busy) #10;
    i_op_copy_rx_tag = 1;
    i_copy_rx_addr = mem_tmp_baseaddr + (35*8);
    i_copy_rx_bytes = 16;
    #10;
    i_op_copy_rx_tag = 0;
    `assert(o_busy);
    while (o_busy) begin
      #10;
    end
  end
  endtask

  task verify_nonce_ad_tag;
  begin : verify__
    integer i;
    while (o_busy) #10;
    i_op_verify = 1;
    #10;
    i_op_verify = 0;
    `assert(o_busy);
    i = 0;
    while (o_busy) begin
      #10;
      i = i + 1;
    end
    if (verbose>1)
      $display("%s:%0d verify_nonce_ad_tag completed in %0d ticks.", `__FILE__, `__LINE__, i);
  end
  endtask

  task dump_ram_row ( input [7:0] row);
    $display("%s:%0d dump_ram, ram[0x%h]=0x%h", `__FILE__, `__LINE__, row, dut.mem.ram[row]);
  endtask

  task dump_ram( input [7:0] first, input [7:0] last);
  begin : dump_ram
    reg [7:0] i ;
    for (i = first; i <= last; i = i + 1)
      dump_ram_row(i);
  end
  endtask

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk = 0;
    i_areset = 1;
    i_unrwapped_s2c = 0;
    i_unwrapped_c2s = 0;
    i_unwrapped_word = 0;
    i_unwrapped_data = 0;
    i_op_copy_rx_ad = 0;
    i_op_copy_rx_nonce = 0;
    i_op_copy_rx_tag = 0;
    i_op_verify = 0;
    i_copy_rx_addr = 0;
    i_copy_rx_bytes = 0;

    #10;
    i_areset = 0;
    #10;
    write_c2s(TEST1_C2S);
    if (verbose>1) begin
      `dump("", dut.key_c2s_reg);
    end
    `assert( TEST1_C2S == dut.key_c2s_reg );

    init_memory_model( 11'h080 );

    write_ad( 188, { 14880'h0, TEST1_AD } );
    write_nonce( TEST1_NONCE );
    write_tag( TEST1_TAG );

    dump_ram(0,40);
    `dump("", dut.core_tag_reg[0] );
    `dump("", dut.core_tag_reg[1] );

    verify_nonce_ad_tag();

    `dump("aes-siv.", dut.core_config_encdec_reg);
    `dump("aes-siv.", dut.core_key);
    `dump("aes-siv.", dut.core_config_mode_reg);
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

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  always @*
  begin
    if (dut.core_ack_reg)
      $display("%s:%0d Read: %h", `__FILE__, `__LINE__, dut.core_block_rd);
  end

  integer delay_cnt;
  reg [63:0] delay_value;
  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_rx_wait <= 0;
      i_rx_rd_dv <= 0;
      i_rx_rd_data <= 0;
      delay_cnt <= 0;
      delay_value <= 0;
    end else begin
      i_rx_rd_dv <= 0;
      i_rx_rd_data <= 0;
      if (i_rx_wait) begin
        if (delay_cnt < 3) begin
          delay_cnt <= delay_cnt+1;
        end else begin
          i_rx_wait <= 0;
          i_rx_rd_dv <= 1;
          i_rx_rd_data <= delay_value;
        end
      end else if (o_rx_rd_en) begin
        i_rx_wait <= 1;
        delay_cnt <= 0;
        delay_value <= mem_func(o_rx_addr);
      end
    end
  end

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
