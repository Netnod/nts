//
// Copyright (c) 2019-2020, The Swedish Post and Telecom Authority (PTS)
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

module nts_api_tb;
  parameter verbose = 0;
  localparam PORTS = 6;


  reg         i_clk;
  reg         i_areset;
  wire        o_busy;

  reg         i_external_api_cs;
  reg         i_external_api_we;
  reg  [11:0] i_external_api_address;
  reg  [31:0] i_external_api_write_data;
  wire [31:0] o_external_api_read_data;
  wire        o_external_api_read_data_valid;

  wire        o_internal_api_we;
  wire  [7:0] o_internal_api_address;
  wire [31:0] o_internal_api_write_data;

  wire        o_internal_engine_api_cs;
  wire [31:0] i_internal_engine_api_read_data;

  wire        o_internal_clock_api_cs;
  wire [31:0] i_internal_clock_api_read_data;

  wire        o_internal_cookie_api_cs;
  wire [31:0] i_internal_cookie_api_read_data;

  wire        o_internal_keymem_api_cs;
  wire [31:0] i_internal_keymem_api_read_data;

  wire        o_internal_debug_api_cs;
  wire [31:0] i_internal_debug_api_read_data;

  wire        o_internal_parser_api_cs;
  reg  [31:0] i_internal_parser_api_read_data;

  wire [PORTS-1:0]  cs;

  reg [31:0] parser_mem [2**8-1 : 0];

  //----------------------------------------------------------------
  // Design Under Test: API
  //----------------------------------------------------------------

  nts_api dut (
    .i_clk(i_clk),
    .i_areset(i_areset),
    .o_busy(o_busy),

    .i_external_api_cs(i_external_api_cs),
    .i_external_api_we(i_external_api_we),
    .i_external_api_address(i_external_api_address),
    .i_external_api_write_data(i_external_api_write_data),
    .o_external_api_read_data(o_external_api_read_data),
    .o_external_api_read_data_valid(o_external_api_read_data_valid),

    .o_internal_api_we(o_internal_api_we),
    .o_internal_api_address(o_internal_api_address),
    .o_internal_api_write_data(o_internal_api_write_data),

    .o_internal_engine_api_cs(o_internal_engine_api_cs),
    .i_internal_engine_api_read_data(i_internal_engine_api_read_data),

    .o_internal_clock_api_cs(o_internal_clock_api_cs),
    .i_internal_clock_api_read_data(i_internal_clock_api_read_data),

    .o_internal_cookie_api_cs(o_internal_cookie_api_cs),
    .i_internal_cookie_api_read_data(i_internal_cookie_api_read_data),

    .o_internal_keymem_api_cs(o_internal_keymem_api_cs),
    .i_internal_keymem_api_read_data(i_internal_keymem_api_read_data),

    .o_internal_debug_api_cs(o_internal_debug_api_cs),
    .i_internal_debug_api_read_data(i_internal_debug_api_read_data),

    .o_internal_parser_api_cs(o_internal_parser_api_cs),
    .i_internal_parser_api_read_data(i_internal_parser_api_read_data)
  );

  //----------------------------------------------------------------
  // Assert. Only truths can be asserted, lies will be terminated.
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  //----------------------------------------------------------------
  // Testbench Main
  //----------------------------------------------------------------

  initial begin
    $display("Test start %s:%0d ", `__FILE__, `__LINE__);
    i_clk = 0;
    i_areset = 0;
    set(0, 0, 0, 0, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);

    #10 i_areset = 1;
    #10 i_areset = 0;

    api(1, 0, 0, 0);
    `assert( o_external_api_read_data_valid === 1'b1 );
    `assert( o_external_api_read_data == 32'h0A00_0000);
    #10 `assert( o_external_api_read_data_valid === 1'b0 );

    api(1, 0, 12'h180, 0);
    `assert( o_external_api_read_data_valid === 1'b1 );
    `assert( o_external_api_read_data == 32'h0E00_0000);
    #10 `assert( o_external_api_read_data_valid === 1'b0 );

    api(1, 0, 12'h010, 0);
    `assert( o_external_api_read_data_valid === 1'b1 );
    `assert( o_external_api_read_data == 32'h0B00_0000);
    #10 `assert( o_external_api_read_data_valid === 1'b0 );

    api(1, 0, 5, 0);
    `assert( o_external_api_read_data_valid === 1'b1 );
    `assert( o_external_api_read_data == 32'h0A00_0005);
    #10 `assert( o_external_api_read_data_valid === 1'b0 );

    api(1, 0, 'h010, 'hF);
    `assert( o_external_api_read_data_valid === 1'b1 );
    `assert( o_external_api_read_data == 32'h0B00_0000);

    api(1, 1, 'h023, 'h9);
    `assert( o_external_api_read_data_valid === 1'b1 ); //RV on W, hmm...
    `assert( o_external_api_read_data == 32'h0 );

    api(1, 1, 'h082, 'hE);
    `assert( o_external_api_read_data_valid === 1'b1 );
    `assert( o_external_api_read_data == 32'h0 ); //RV on W
    #10 `assert( o_external_api_read_data_valid === 1'b0 );

    begin : p_w
      integer i;
      reg [31:0] magic;
      reg [11:0] addr;
      for (i = 0; i < 256; i = i + 1) begin
        addr = 12'h200 + { 4'h0, i[7:0] };
        magic = 2147483647 + 17 * i; //Whatever. Just a cool magic number.
        api(1, 1, addr, magic);
        if (verbose > 2) $display("%s:%0d write [%h] = %h", `__FILE__, `__LINE__, addr, magic);
      end
      for (i = 0; i < 256; i = i + 1) begin
        addr = 12'h200 + { 4'h0, i[7:0] };
        magic = 2147483647 + 17 * i; //Whatever. Just a cool magic number.
        api(1, 0, addr, 0);
        `assert( o_external_api_read_data_valid === 1'b1 );
        if (verbose > 2) $display("%s:%0d read [%h] = %h (%h expected)", `__FILE__, `__LINE__, addr, o_external_api_read_data, magic);
        `assert( o_external_api_read_data === magic );
        #10 `assert( o_external_api_read_data_valid === 1'b0 );
      end
    end

    $display("Test end %s:%0d ", `__FILE__, `__LINE__);
    $finish;
  end

  //----------------------------------------------------------------
  // Testbench model: Read dummies for Engine, Clock, Cookie, etc.
  //----------------------------------------------------------------

  assign      i_internal_engine_api_read_data = { 8'h0A, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };
  assign      i_internal_clock_api_read_data  = { 8'h0B, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };
  assign      i_internal_cookie_api_read_data = { 8'h0C, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };
  assign      i_internal_keymem_api_read_data = { 8'h0D, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };
  assign      i_internal_debug_api_read_data  = { 8'h0E, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };

  assign      cs = { o_internal_engine_api_cs, o_internal_clock_api_cs, o_internal_cookie_api_cs, o_internal_keymem_api_cs, o_internal_debug_api_cs, o_internal_parser_api_cs };

  //----------------------------------------------------------------
  // Testbench model: Parser register write
  //----------------------------------------------------------------

  always @(posedge i_clk)
  begin : parser_mem_wr_impl_
    reg  [7:0] addr;
    reg        en;
    reg        we;
    reg [31:0] wd;
    addr = o_internal_api_address;
    en = o_internal_parser_api_cs;
    we = o_internal_api_we;
    wd = o_internal_api_write_data;

    if (en) begin
      if (we) begin
        if (verbose > 2) $display("%s:%0d write [%h] = %h", `__FILE__, `__LINE__, addr, wd);
        parser_mem[addr] = wd;
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: Parser register 0 cycle latency read
  //----------------------------------------------------------------

  always @*
  begin : parser_mem_rd_impl_
    reg  [7:0] addr;
    reg        en;
    reg [31:0] rd;
    reg        we;
    addr = o_internal_api_address;
    en = o_internal_parser_api_cs;
    rd = 0;
    we = o_internal_api_we;
    if (en) begin
      if (~we) begin
        rd = parser_mem[addr];
        if (verbose > 2) $display("%s:%0d read [%h] = %h", `__FILE__, `__LINE__, addr, rd);
      end
    end
    i_internal_parser_api_read_data = rd;
  end

  //----------------------------------------------------------------
  // Testbench Task: API setter
  //----------------------------------------------------------------

  task set;
    input         i_cs;
    input         i_we;
    input  [11:0] i_addr;
    input  [31:0] i_data;
    output        o_cs;
    output        o_we;
    output [11:0] o_addr;
    output  [31:0] o_data;
  begin
    o_cs   = i_cs;
    o_we   = i_we;
    o_addr = i_addr;
    o_data = i_data;
    if (verbose > 1)
      $display("%s:%0d cs=%h we=%h addr=%h data=%h", `__FILE__, `__LINE__, i_cs, i_we, i_addr, i_data);
  end
  endtask

  //----------------------------------------------------------------
  // Testbench Task: Wait While API is Busy
  //----------------------------------------------------------------

  task wait_busy;
  begin
    while (o_busy) begin
      #10;
      if (verbose > 1) $display("%s:%0d busy", `__FILE__, `__LINE__);
    end
  end
  endtask

  //----------------------------------------------------------------
  // API with busy wait
  //----------------------------------------------------------------

  task api;
    input         i_cs;
    input         i_we;
    input  [11:0] i_addr;
    input  [31:0] i_data;
  begin
    set(i_cs, i_we, i_addr, i_data, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #10 ;
    set(0, 0, 0, 0, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    wait_busy();
  end
  endtask

  //----------------------------------------------------------------
  // Testbench model: System Clock
  //----------------------------------------------------------------

  always begin
    #5 i_clk = ~i_clk;
  end

  //----------------------------------------------------------------
  // Verbose output
  //----------------------------------------------------------------

  if (verbose > 1) begin
    always @*
      $display("%s:%0d o_internal_api_write_data = %h", `__FILE__, `__LINE__, o_internal_api_write_data);
    always @*
      $display("%s:%0d cs = %h", `__FILE__, `__LINE__, cs);
    always @*
      $display("%s:%0d o_busy = %h", `__FILE__, `__LINE__, o_busy);
    always @*
      $display("%s:%0d o_external_api_read_data = %h", `__FILE__, `__LINE__, o_external_api_read_data);
  end

  //----------------------------------------------------------------
  // Cable Select Sanity Checker
  // Assert ERROR if multiple CS are fired by API, should never
  // happend.
  //----------------------------------------------------------------

  always @*
  begin : cs_sanrity_checker
    integer i;
    integer exes;
    integer ones;
    exes = 0;
    ones = 0;
    for (i = 0; i < PORTS; i = i + 1) begin
      if ( cs[i] === 1'bx ) exes = exes + 1;
      if ( cs[i] === 1'b1 ) ones = ones + 1;
    end
    //$display("%s:%0d %0d %0d", `__FILE__, `__LINE__, exes, ones);
    if (exes > 0) begin
      `assert( exes == PORTS );
    end
    if (ones > 0) begin
      `assert( ones == 1 );
      `assert( exes == 0 );
    end
  end

endmodule
