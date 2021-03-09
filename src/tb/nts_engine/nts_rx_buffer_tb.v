//======================================================================
//
// nts_rx_buffer_tb.v
// ------------------
// Testbench for the NTS RX buffer.
//
// Author: Peter Magnusson
//
//
//
// Copyright 2019 Netnod Internet Exchange i Sverige AB
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
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
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
//======================================================================

module nts_rx_buffer_tb;
  parameter ADDR_WIDTH = 8;
  parameter VERBOSE = 1 ;
  parameter TEST_BUFF_WORDS = 40;

  reg                     i_areset;
  reg                     i_clk;
  reg                     i_parser_busy;
  /* verilator lint_off UNUSED */
  wire                    dispatch_ready;
  /* verilator lint_on UNUSED */
  reg                     dispatch_fifo_empty;
  reg                     dispatch_fifo_rd_valid;
  reg  [63:0]             dispatch_fifo_rd_data;

  wire                    access_port_wait;
  reg  [ADDR_WIDTH+3-1:0] access_port_addr;
  reg  [15:0]             access_port_csum_initial;
  reg  [2:0]              access_port_wordsize;
  reg  [15:0]             access_port_burstsize;
  reg                     access_port_rd_en;
  wire                    access_port_rd_dv;
  wire  [63:0]            access_port_rd_data;

  reg [64*TEST_BUFF_WORDS-1:0] rd_buf;

  reg [15:0] csum;

  nts_rx_buffer #(.ADDR_WIDTH(ADDR_WIDTH), .SUPPORT_8BIT(1), .SUPPORT_16BIT(1) ) dut (
     .i_areset(i_areset),
     .i_clk(i_clk),
     .i_parser_busy(i_parser_busy),
     .o_dispatch_ready(dispatch_ready),
     .i_dispatch_fifo_empty(dispatch_fifo_empty),
     .i_dispatch_fifo_rd_valid(dispatch_fifo_rd_valid),
     .i_dispatch_fifo_rd_data(dispatch_fifo_rd_data),
     .o_access_port_wait(access_port_wait),
     .i_access_port_addr(access_port_addr),
     .i_access_port_csum_initial(access_port_csum_initial),
     .i_access_port_wordsize(access_port_wordsize),
     .i_access_port_burstsize(access_port_burstsize),
     .i_access_port_rd_en(access_port_rd_en),
     .o_access_port_rd_dv(access_port_rd_dv),
     .o_access_port_rd_data(access_port_rd_data)
  );

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  task read ( input [10:0] addr, input [2:0] ws );
    begin
      #10
      `assert(access_port_wait == 'b0);
      access_port_addr = addr;
      access_port_rd_en = 1;
      access_port_wordsize = ws;
      #10;
      `assert(access_port_wait);
      access_port_rd_en = 0;
      #10 ;
      while(access_port_wait) begin
        `assert(access_port_rd_dv == 'b0);
        #10 ;
      end
      `assert(access_port_rd_dv == 'b1);
      if (VERBOSE>1)
        case(ws)
          0: $display("%s:%0d read: %h", `__FILE__, `__LINE__, access_port_rd_data[0+:8]);
          1: $display("%s:%0d read: %h", `__FILE__, `__LINE__, access_port_rd_data[0+:16]);
          2: $display("%s:%0d read: %h", `__FILE__, `__LINE__, access_port_rd_data[0+:32]);
          3: $display("%s:%0d read: %h", `__FILE__, `__LINE__, access_port_rd_data[0+:64]);
          default: ;
        endcase
    end
  endtask

  task read_burst (input [10:0] addr, input [15:0] bytes, output [64*TEST_BUFF_WORDS-1:0] test_buff);
  begin : read_burst
    integer i;
    if (VERBOSE>1) $display("%s:%0d read_burst(%h, %h, ...)", `__FILE__, `__LINE__, addr, bytes);
    test_buff = 0;
    #10 `assert(access_port_wait == 'b0);
    access_port_addr = addr;
    access_port_rd_en = 1;
    access_port_wordsize = 4; //burst
    access_port_burstsize = bytes;

    #10;
    if (bytes == 0) begin
      `assert(access_port_wait==0);
      access_port_rd_en = 0;
    end else begin
      `assert(access_port_wait);
      access_port_rd_en = 0;
      i = 0;
      while(access_port_wait) begin
        if (access_port_rd_dv) begin
          `assert(i < TEST_BUFF_WORDS);
          test_buff = { test_buff[64*TEST_BUFF_WORDS-65:0], access_port_rd_data };
          if (VERBOSE>1) $display("%s:%0d read[%0d] = %h.", `__FILE__, `__LINE__, i, access_port_rd_data);
          i = i + 1;
        end
        #10 ;
      end
    end
  end
  endtask

  task read_csum_with_init (input [10:0] addr, input [15:0] bytes, input [15:0] csum_initial, output [15:0] csum);
  begin : read_csum_with_init
    integer i;
    if (VERBOSE>1) $display("%s:%0d read_csum(%h, %h, ...)", `__FILE__, `__LINE__, addr, bytes);
    csum = 0;
    #10 `assert(access_port_wait == 'b0);
    access_port_addr = addr;
    access_port_csum_initial = csum_initial;
    access_port_rd_en = 1;
    access_port_wordsize = 5; //csum
    access_port_burstsize = bytes;

    #10;
    if (bytes == 0) begin
      `assert(access_port_wait==0);
      access_port_rd_en = 0;
    end else begin
      `assert(access_port_wait);
      access_port_rd_en = 0;
      i = 0;
      while(access_port_wait) begin
        if (access_port_rd_dv) begin
          `assert(i == 0);
          `assert(access_port_rd_data[63:16] == 0);
          csum = access_port_rd_data[15:0];
          if (VERBOSE>1) $display("%s:%0d read[%0d] = %h.", `__FILE__, `__LINE__, i, access_port_rd_data);
          i = i + 1;
        end
        #10 ;
      end
    end
    access_port_addr = 0;
    access_port_csum_initial = 0;
    access_port_rd_en = 0;
    access_port_wordsize = 0;
    access_port_burstsize = 0;
  end
  endtask

  task read_csum (input [10:0] addr, input [15:0] bytes, output [15:0] csum);
  begin
    read_csum_with_init(addr, bytes, 16'h0000, csum);
  end
  endtask

  localparam [431:0] PACKET_TCP = {
    128'hff_fe_fd_fc_fb_fa_98_03_9b_3c_1c_66_08_00_45_00, // ÿþýüûú...<.f..E.
    128'h00_28_c9_cf_00_00_40_06_df_90_c0_a8_28_01_c0_a8, // .(ÉÏ..@.ß.À¨(.À¨
    128'h28_1e_00_03_00_04_7b_2a_9e_cf_00_00_00_00_50_02, // (.....{*.Ï....P.
     48'h05_c8_be_a9_00_00                                // .È¾©..
  };

  task test_csum_packet_tcp;
  begin : test_csum_packet_tcp_
    reg [15:0] csum;
     if (VERBOSE>0) $display("%s:%0d csum access port tests with a real TCP packet.", `__FILE__, `__LINE__);
        #100
    #10;
    i_areset = 1;
    #20;
    i_areset = 0;
    dispatch_fifo_empty = 'b0;
    dispatch_fifo_rd_valid = 0;
    dispatch_fifo_rd_data = 'b00;
    i_parser_busy = 0;
    #20;
    #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, PACKET_TCP[431-:64] };
    #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, PACKET_TCP[367-:64] };
    #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, PACKET_TCP[303-:64] };
    #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, PACKET_TCP[239-:64] };
    #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, PACKET_TCP[175-:64] };
    #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, PACKET_TCP[111-:64] };
    #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, PACKET_TCP[47-:48], 16'h0 };
    #10;
    dispatch_fifo_empty = 'b1;
    dispatch_fifo_rd_valid = 0;
    dispatch_fifo_rd_data = 0;
    #10;
    read_csum( 14, 20, csum );
    `assert ( csum === 16'hffff );
  end
  endtask

  initial
      begin
        $display("Test start: %s:%0d.", `__FILE__, `__LINE__);
        i_clk = 1;
        #5 ;
        i_areset = 1;
        i_parser_busy = 1;
        access_port_addr = 'b0;
        access_port_csum_initial = 16'h0;
        access_port_wordsize = 'b0;
        access_port_burstsize = 16'h0;
        access_port_rd_en = 'b0;
        dispatch_fifo_empty = 'b0;
        dispatch_fifo_rd_valid = 0;
        dispatch_fifo_rd_data = 'b00;
        #5 ;

        #10 i_areset = 0;

        #10 dispatch_fifo_empty = 'b0;
        i_parser_busy = 0;
        #10;
        if (VERBOSE>0) $display("%s:%0d Populate test values.", `__FILE__, `__LINE__);
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, 64'hdeadbeef00000000 };
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, 64'habad1deac0fef00d };
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, 64'h0123456789abcdef };
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, 64'hffffffffffffffff };
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b1, 64'heeeeeeeeeeeeeeee };
        #10 { dispatch_fifo_rd_valid, dispatch_fifo_rd_data } = { 1'b0, 64'h0 };

        #10 dispatch_fifo_empty = 'b1;
        #10 dispatch_fifo_empty = 'b0;

        if (VERBOSE>0) $display("%s:%0d 64 bit access port tests.", `__FILE__, `__LINE__);
        #100
        //$display("%s:%0d dut.memctrl_reg=%h", `__FILE__, `__LINE__, dut.memctrl_reg);
        read('b00_000, 3);
        `assert(access_port_rd_data == 64'hdeadbeef00000000);
        read('b00_000, 3);
        `assert(access_port_rd_data == 64'hdeadbeef00000000);
        read('b01_000, 3);
        `assert(access_port_rd_data == 64'habad1deac0fef00d);
        read('b01_000, 3);
        `assert(access_port_rd_data == 64'habad1deac0fef00d);
        read('b10_000, 3);
        `assert(access_port_rd_data == 64'h0123456789abcdef);
        read('b10_000, 3);
        `assert(access_port_rd_data == 64'h0123456789abcdef);
        read('b00_001, 3);
        `assert(access_port_rd_data == 64'hadbeef00000000ab);
        read('b01_010, 3);
        `assert(access_port_rd_data == 64'h1deac0fef00d0123);
        read('b01_011, 3);
        `assert(access_port_rd_data == 64'heac0fef00d012345);
        read('b01_100, 3);
        `assert(access_port_rd_data == 64'hc0fef00d01234567);
        read('b01_101, 3);
        `assert(access_port_rd_data == 64'hfef00d0123456789);
        read('b01_110, 3);
        `assert(access_port_rd_data == 64'hf00d0123456789ab);
        read('b01_111, 3);
        `assert(access_port_rd_data == 64'h0d0123456789abcd);

        if (VERBOSE>0) $display("%s:%0d 8 bit access port tests.", `__FILE__, `__LINE__);
        #100
        read('b00_000, 0);
        `assert(access_port_rd_data == 64'hde);
        read('b00_001, 0);
        `assert(access_port_rd_data == 64'had);
        read('b01_010, 0);
        `assert(access_port_rd_data == 64'h1d);
        read('b01_011, 0);
        `assert(access_port_rd_data == 64'hea);
        read('b01_110, 0);
        `assert(access_port_rd_data == 64'hf0);
        read('b10_111, 0);
        `assert(access_port_rd_data == 64'hef);


        if (VERBOSE>0) $display("%s:%0d 16 bit access port tests.", `__FILE__, `__LINE__);
        #100
        read('b01_000, 1);
        `assert(access_port_rd_data == 64'habad);
        read('b00_001, 1);
        `assert(access_port_rd_data == 64'hadbe);
        read('b01_010, 1);
        `assert(access_port_rd_data == 64'h1dea);
        read('b01_011, 1);
        `assert(access_port_rd_data == 64'heac0);
        read('b01_110, 1);
        `assert(access_port_rd_data == 64'hf00d);
        read('b01_111, 1);
        `assert(access_port_rd_data == 64'h0d01);

        if (VERBOSE>0) $display("%s:%0d 32 bit access port tests.", `__FILE__, `__LINE__);
        #100
        read('b01_000, 2);
        `assert(access_port_rd_data == 64'habad1dea);
        read('b00_001, 2);
        `assert(access_port_rd_data == 64'hadbeef00);
        read('b01_010, 2);
        `assert(access_port_rd_data == 64'h1deac0fe);
        read('b01_011, 2);
        `assert(access_port_rd_data == 64'heac0fef0);
        read('b01_100, 2);
        `assert(access_port_rd_data == 64'hc0fef00d);
        read('b01_101, 2);
        `assert(access_port_rd_data == 64'hfef00d01);
        read('b01_110, 2);
        `assert(access_port_rd_data == 64'hf00d0123);
        read('b01_111, 2);
        `assert(access_port_rd_data == 64'h0d012345);

        if (VERBOSE>0) $display("%s:%0d burst access port tests.", `__FILE__, `__LINE__);
        #100

        read_burst(0, 0, rd_buf);
        `assert(rd_buf == 0);

        read_burst(0, 8, rd_buf);
        `assert(rd_buf[0+:64] == 64'hdeadbeef00000000 );

        //should work twice :)
        read_burst(0, 8, rd_buf);
        `assert(rd_buf[0+:64] == 64'hdeadbeef00000000 );

        read_burst(0, 1, rd_buf);
        `assert(rd_buf[63-:8] == 8'hde );

        read_burst(1, 1, rd_buf);
        `assert(rd_buf[63-:8] == 8'had );

        read_burst(2, 8, rd_buf);
        `assert(rd_buf[63-:64] ==  64'hbeef00000000abad);

        read_burst(2, 7, rd_buf);
        `assert(rd_buf[63-:64] ==  64'hbeef00000000ab00);

        read_burst(0, 16, rd_buf);
        `assert(rd_buf[0+:128] == 128'hdeadbeef00000000abad1deac0fef00d );

        read_burst(1, 15, rd_buf);
        `assert(rd_buf[0+:128] == 128'hadbeef00000000abad1deac0fef00d_00 );

        read_burst(7, 16, rd_buf);
        `assert(rd_buf[0+:128] == 128'h00abad1deac0fef00d0123456789abcd );

        read_burst(8, 16, rd_buf);
        `assert(rd_buf[0+:128] == 128'habad1deac0fef00d0123456789abcdef );

        read_burst(0, 24, rd_buf);
        `assert(rd_buf[0+:196] == 196'hdeadbeef00000000abad1deac0fef00d0123456789abcdef );

        read_burst(0, 23, rd_buf);
        `assert(rd_buf[0+:196] == 196'hdeadbeef00000000abad1deac0fef00d0123456789abcd_00 );

        read_burst(1, 23, rd_buf);
        `assert(rd_buf[0+:196] == 196'hadbeef00000000abad1deac0fef00d0123456789abcdef_00 );

        read_burst(2, 23, rd_buf);
        `assert(rd_buf[0+:196] == 196'hbeef00000000abad1deac0fef00d0123456789abcdef_ff_00 );

        read_burst(3, 23, rd_buf);
        `assert(rd_buf[0+:196] == 196'hef00000000abad1deac0fef00d0123456789abcdef_ffff_00 );

        read_burst(4, 23, rd_buf);
        `assert(rd_buf[0+:196] == 196'h00000000abad1deac0fef00d0123456789abcdef_ffffff_00 );

        read_burst(4, 22, rd_buf);
        `assert(rd_buf[0+:196] == 196'h00000000abad1deac0fef00d0123456789abcdef_ffff_0000 );

        read_burst(4, 21, rd_buf);
        `assert(rd_buf[0+:196] == 196'h00000000abad1deac0fef00d0123456789abcdef_ff_000000 );

        read_burst(5, 21, rd_buf);
        `assert(rd_buf[0+:196] == 196'h000000abad1deac0fef00d0123456789abcdef_ffff_000000 );

        read_burst(6, 20, rd_buf);
        `assert(rd_buf[0+:196] == 196'h0000abad1deac0fef00d0123456789abcdef_ffff_00000000 );

        read_burst(6, 19, rd_buf);
        `assert(rd_buf[0+:196] == 196'h0000abad1deac0fef00d0123456789abcdef_ff_0000000000 );

        read_burst(7, 18, rd_buf);
        `assert(rd_buf[0+:196] == 196'h00abad1deac0fef00d0123456789abcdef_ff_000000000000 );

        read_burst(7, 17, rd_buf);
        `assert(rd_buf[0+:196] == 196'h00abad1deac0fef00d0123456789abcdef_00000000000000 );

        if (VERBOSE>0) $display("%s:%0d csum access port tests.", `__FILE__, `__LINE__);
        #100

        read_csum(0, 0, csum);
        `assert(csum == 0);

        read_csum(0, 1, csum);
        `assert(csum == 16'hde00);

        read_csum(0, 2, csum);
        `assert(csum == 16'hdead);

        read_csum(0, 3, csum);
        `assert(csum == 16'h9CAE); // 19CAD = dead + be00

        read_csum(0, 4, csum);
        `assert(csum == 16'h9D9D); // 19D9C = dead + beef

        read_csum(0, 8, csum);
        `assert(csum == 16'h9D9D); // 19D9C = dead + beef + 0000 + 0000

        read_csum(0, 9, csum);
        `assert(csum == 16'h489e); // 2489C = dead + beef + 0000 + 0000 + ab00

        read_csum(0, 10, csum);
        `assert(csum == 16'h494b); // 24949 = dead + beef + 0000 + 0000 + abad

        read_csum(0, 11, csum);
        `assert(csum == 16'h664b); // 26649 = dead + beef + 0000 + 0000 + abad + 1d00

        read_csum(0, 12, csum);
        `assert(csum == 16'h6735); // 26733 = dead + beef + 0000 + 0000 + abad + 1dea

        read_csum(0, 13, csum);
        `assert(csum == 16'h2736); // 32733 = dead + beef + 0000 + 0000 + abad + 1dea + c000

        read_csum(0, 14, csum);
        `assert(csum == 16'h2834); // 32831 = dead + beef + 0000 + 0000 + abad + 1dea + c0fe

        read_csum(0, 15, csum);
        `assert(csum == 16'h1835); // 41831 = dead + beef + 0000 + 0000 + abad + 1dea + c0fe + f000

        read_csum(0, 16, csum);
        `assert(csum == 16'h1842); // 4183E = dead + beef + 0000 + 0000 + abad + 1dea + c0fe + f00d

        read_csum(0, 24, csum);
        `assert(csum == 16'hB667); // 5B662 = dead + beef + abad + 1dea + c0fe + f00d + 0123 + 4567 + 89ab + cdef

        read_csum(14, 20, csum);
        `assert(csum == 16'h7D22); // 77D1B = f00d + 0123 + 4567 + 89ab + cdef + ffff + ffff + ffff + ffff + eeee


        read_csum_with_init(0, 4, 16'h0000, csum);
        `assert(csum == 16'h9D9D); // 19D9C = 0000 + dead + beef

        read_csum_with_init(0, 4, 16'h0001, csum);
        `assert(csum == 16'h9D9E); // 19D9D = 0001 + dead + beef

        read_csum_with_init(0, 4, 16'h6261, csum);
        `assert(csum == 16'hfffe); // 6261 = fffe - 9D9D

        read_csum_with_init(0, 4, 16'h6262, csum);
        `assert(csum == 16'hffff); // 6262 = ffff - 9D9D

        read_csum_with_init(0, 4, 16'h6263, csum);
        `assert(csum == 16'h0001); //overflows comes back in csum algorithm

        test_csum_packet_tcp();

        $display("Test stop: %s:%0d.", `__FILE__, `__LINE__);
        #40 $finish;
      end

  if (VERBOSE>2) begin

    always @(posedge i_clk)
      begin
        if (dut.csum_reset) begin
          $display("%s:%0d csum_reset!",  `__FILE__, `__LINE__);
        end
        if (dut.p0_done_new)
          $display("%s:%0d p0_done!",  `__FILE__, `__LINE__);
        if (dut.csum_block_valid_reg) begin
          $display("%s:%0d checksum block: %h!",  `__FILE__, `__LINE__, dut.csum_block_reg);
        end
      end

    always @*
      $display("%s:%0d dispatch_fifo_empty: %b",  `__FILE__, `__LINE__, dispatch_fifo_empty);

    always @*
      $display("%s:%0d dut.memctrl_reg=%h", `__FILE__, `__LINE__, dut.memctrl_reg);

    always @*
      $display("%s:%0d dut.burst_size_we=%h new=%h", `__FILE__, `__LINE__, dut.burst_size_we, dut.burst_size_new);

    always @*
      $display("%s:%0d dut.burst_mem_reg=%h", `__FILE__, `__LINE__, dut.burst_mem_reg);

    always @*
      $display("%s:%0d dut.burst_size_reg=%h", `__FILE__, `__LINE__, dut.burst_size_reg);

    always @*
      $display("%s:%0d dut.ram_addr_we=%h new=%h", `__FILE__, `__LINE__, dut.ram_addr_we, dut.ram_addr_new);

    wire [63:0] mem_0;
    wire [63:0] mem_1;
    wire [63:0] mem_2;
    wire [63:0] mem_3;
    assign mem_0 = dut.mem.mem[0];
    assign mem_1 = dut.mem.mem[1];
    assign mem_2 = dut.mem.mem[2];
    assign mem_3 = dut.mem.mem[3];

    always @*
      $display("%s:%0d dut.mem.mem[0]=%h", `__FILE__, `__LINE__, mem_0);
    always @*
      $display("%s:%0d dut.mem.mem[1]=%h", `__FILE__, `__LINE__, mem_1);
    always @*
      $display("%s:%0d dut.mem.mem[2]=%h", `__FILE__, `__LINE__, mem_2);
    always @*
      $display("%s:%0d dut.mem.mem[3]=%h", `__FILE__, `__LINE__, mem_3);
  end

  always begin
    #5 i_clk = ~i_clk;
  end

endmodule
