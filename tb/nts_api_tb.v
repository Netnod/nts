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

module nts_api_tb;
  parameter verbose = 1;

  reg         i_external_api_cs;
  reg         i_external_api_we;
  reg  [11:0] i_external_api_address;
  reg  [31:0] i_external_api_write_data;
  wire [31:0] o_external_api_read_data;

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

  wire [4:0]  cs;

  assign      i_internal_engine_api_read_data = { 8'h0A, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };
  assign      i_internal_clock_api_read_data  = { 8'h0B, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };
  assign      i_internal_cookie_api_read_data = { 8'h0C, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };
  assign      i_internal_keymem_api_read_data = { 8'h0D, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };
  assign      i_internal_debug_api_read_data  = { 8'h0E, 7'h0, o_internal_api_we, i_external_api_write_data[7:0], o_internal_api_address };

  assign      cs = { o_internal_engine_api_cs, o_internal_clock_api_cs, o_internal_cookie_api_cs, o_internal_keymem_api_cs, o_internal_debug_api_cs };

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  nts_api dut (
    .i_external_api_cs(i_external_api_cs),
    .i_external_api_we(i_external_api_we),
    .i_external_api_address(i_external_api_address),
    .i_external_api_write_data(i_external_api_write_data),
    .o_external_api_read_data(o_external_api_read_data),

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
    .i_internal_debug_api_read_data(i_internal_debug_api_read_data)
  );

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
    if (verbose > 0)
      $display("%s:%0d cs=%h we=%h addr=%h data=%h", `__FILE__, `__LINE__, i_cs, i_we, i_addr, i_data);
  end
  endtask

  initial begin
    $display("Test start %s:%0d ", `__FILE__, `__LINE__);

    set(0,0,0,0, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #1 `assert( cs == 5'b00000 );

    set(1,0,0,0, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #1 `assert( cs == 5'b10000 ); `assert( o_external_api_read_data == 32'h0A00_0000);

    set(1,0,0,1, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #1 `assert( cs == 5'b10000 ); `assert( o_external_api_read_data == 32'h0A00_0100);

    set(1,0,5,1, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #1 `assert( cs == 5'b10000 ); `assert( o_external_api_read_data == 32'h0A00_0105);

    set(1,0,'h010, 'hF, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #1 `assert( cs == 5'b01000 ); `assert( o_external_api_read_data == 32'h0B00_0F00);

    set(1,1,'h023, 'h9, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #1 `assert( cs == 5'b00100 ); `assert( o_external_api_read_data == 32'h0C01_0903);

    set(1,1,'h082, 'hE, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #1 `assert( cs == 5'b00010 ); `assert( o_external_api_read_data == 32'h0D01_0E02);

    set(1,1,'h0aF, 'hD, i_external_api_cs, i_external_api_we, i_external_api_address, i_external_api_write_data);
    #1 `assert( cs == 5'b00001 ); `assert( o_external_api_read_data == 32'h0E01_0D0F);

    $display("Test end %s:%0d ", `__FILE__, `__LINE__);
    $finish;
  end

  always @*
    $display("%s:%0d o_internal_api_write_data = %h", `__FILE__, `__LINE__, o_internal_api_write_data);

endmodule
