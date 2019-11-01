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

  localparam RX_PORT_WIDTH = 64;
  localparam ADDR_WIDTH = 8;

  //----------------------------------------------------------------
  // Inputs and outputs
  //----------------------------------------------------------------

  reg  i_areset; // async reset
  reg  i_clk;
  wire o_busy;
  wire o_verify_tag_ok;

  reg          i_unrwapped_s2c;
  reg          i_unwrapped_c2s;
  reg  [2 : 0] i_unwrapped_word;
  reg [31 : 0] i_unwrapped_data;

  reg                    i_op_copy_rx_ad;
  reg                    i_op_copy_rx_nonce;
  reg                    i_op_copy_rx_tag;
  reg                    i_op_verify;
  reg                    i_op_copy_tx_ad;
  reg                    i_op_generate_tag;

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
  wire [ADDR_WIDTH+3-1:0] o_tx_address;

  wire          o_noncegen_get;
  reg  [63 : 0] i_noncegen_nonce;
  reg           i_noncegen_ready;

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
    .i_unrwapped_s2c(i_unrwapped_s2c),
    .i_unwrapped_c2s(i_unwrapped_c2s),
    .i_unwrapped_word(i_unwrapped_word),
    .i_unwrapped_data(i_unwrapped_data),
    .i_op_copy_rx_ad(i_op_copy_rx_ad),
    .i_op_copy_rx_nonce(i_op_copy_rx_nonce),
    .i_op_copy_rx_tag(i_op_copy_rx_tag),
    .i_op_verify(i_op_verify),
    .i_op_copy_tx_ad(i_op_copy_tx_ad),
    .i_op_generate_tag(i_op_generate_tag),
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
    a = { 3'b000, addr[ADDR_WIDTH+3-1:3] - mem_tmp_baseaddr[ADDR_WIDTH+3-1:3] };
    if (verbose>2)
      $display("%s:%0d mem_func(%h)=mem_tmp[%h]=%h", `__FILE__, `__LINE__, addr, a, mem_tmp[a[7:0]]);
    mem_func = mem_tmp[a[7:0]];
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
    if (verbose>2) begin
      `dump( "", ad );
      `dump( " ", bytes_count );
      `dump( " ", bytes_count[7:3] );
      `dump( " ", bytes_count[2:0] );
    end
    j = 0;
    for (i = { 27'h0, bytes_count[7:3] }; i > 0; i = i - 1) begin : offset_calc
      integer offset;
      offset = (64*i) + (8*bytes_count[2:0]) - 1;
      mem_tmp[j] = ad[offset-:64];
      if (verbose>2) begin
        `dump( "", i );
        `dump( "", offset );
        `dump( "", mem_tmp[j] );
      end
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
    if (verbose>2)
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
    if (verbose>1)
      $display("%s:%0d test_verify [ %s ] start.", `__FILE__, `__LINE__, description);

    write_c2s(c2s);
    write_ad( ad_bytes_count, ad );
    write_nonce( nonce );
    write_tag( tag );

    verify_nonce_ad_tag();

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

  //----------------------------------------------------------------
  // Testbench start
  //----------------------------------------------------------------

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
    i_op_copy_tx_ad = 0;
    i_op_generate_tag = 0;
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
    init_memory_model( 11'h080 );

    test_verify("case 1", 1, TEST1_C2S, 188, { 14880'h0, TEST1_AD }, TEST1_NONCE, TEST1_TAG);

    if (verbose>1) begin
      dump_ram(0,40);
      `dump("", dut.key_c2s_reg);
      `dump("", dut.core_tag_reg[0] );
      `dump("", dut.core_tag_reg[1] );
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
    end

    init_memory_model( 11'h080 );
    //write_ad( 200, 'h0 );
    if (verbose>1)
      dump_ram(0,40);

    i_op_copy_tx_ad = 1;
    i_copy_tx_addr = mem_tmp_baseaddr;
    i_copy_tx_bytes = 188;
    #10;
    i_op_copy_tx_ad = 0;
    `assert(o_busy);
    while(o_busy) #10;
    if (verbose>1)
      dump_ram(0,40);

    i_op_generate_tag = 1;
    #10;
    i_op_generate_tag = 0;
    `assert(o_busy);
    while(o_busy) #10;
    if (verbose>1)
      dump_ram(0,40);

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
        tmp = mem_func(o_rx_addr);
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
        tmp = mem_func(o_tx_address);
        i_tx_read_data <= tmp;
        if (verbose>1) $display("%s:%0d TX-buff[%h]=%h", `__FILE__, `__LINE__, o_tx_address, tmp);
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
