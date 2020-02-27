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

module nts_api #(
  parameter [11:0] ADDR_ENGINE_BASE = 12'h000,
  parameter [11:0] ADDR_ENGINE_STOP = 12'h009,
  parameter [11:0] ADDR_CLOCK_BASE  = 12'h010,
  parameter [11:0] ADDR_CLOCK_STOP  = 12'h01F,
  parameter [11:0] ADDR_COOKIE_BASE = 12'h020,
  parameter [11:0] ADDR_COOKIE_STOP = 12'h03F,
  parameter [11:0] ADDR_KEYMEM_BASE = 12'h080,
  parameter [11:0] ADDR_KEYMEM_STOP = 12'h17F,
  parameter [11:0] ADDR_DEBUG_BASE  = 12'h180,
  parameter [11:0] ADDR_DEBUG_STOP  = 12'h1F0,
  parameter [11:0] ADDR_PARSER_BASE = 12'h200,
  parameter [11:0] ADDR_PARSER_STOP = 12'h2FF
) (

  input  wire        i_clk,
  input  wire        i_areset,
  output wire        o_busy,

  input  wire        i_external_api_cs,
  input  wire        i_external_api_we,
  input  wire [11:0] i_external_api_address,
  input  wire [31:0] i_external_api_write_data,
  output wire [31:0] o_external_api_read_data,
  output wire        o_external_api_read_data_valid,

  output wire        o_internal_api_we,
  output wire  [7:0] o_internal_api_address,
  output wire [31:0] o_internal_api_write_data,

  output wire        o_internal_engine_api_cs,
  input  wire [31:0] i_internal_engine_api_read_data,

  output wire        o_internal_clock_api_cs,
  input  wire [31:0] i_internal_clock_api_read_data,

  output wire        o_internal_cookie_api_cs,
  input  wire [31:0] i_internal_cookie_api_read_data,

  output wire        o_internal_keymem_api_cs,
  input  wire [31:0] i_internal_keymem_api_read_data,

  output wire        o_internal_debug_api_cs,
  input  wire [31:0] i_internal_debug_api_read_data,

  output wire        o_internal_parser_api_cs,
  input  wire [31:0] i_internal_parser_api_read_data
);

  reg        busy_we;
  reg        busy_new;
  reg        busy_reg;

  reg        p0_api_cs_reg;
  reg        p0_api_we_reg;
  reg [11:0] p0_api_address_reg;
  reg [31:0] p0_api_write_data_reg;

  reg        p1_api_cs_reg;
  reg        p1_api_we_reg;
  reg  [7:0] p1_api_address_reg;
  reg [31:0] p1_api_write_data_reg;
  reg        p1_select_engine_reg;
  reg        p1_select_clock_reg;
  reg        p1_select_cookie_reg;
  reg        p1_select_keymem_reg;
  reg        p1_select_debug_reg;
  reg        p1_select_parser_reg;

  reg  [7:0] addr_calculated;
  reg        select_engine;
  reg        select_clock;
  reg        select_cookie;
  reg        select_keymem;
  reg        select_debug;
  reg        select_parser;

  reg [31:0] p2_api_read_data_new;
  reg [31:0] p2_api_read_data_reg;
  reg        p2_api_read_data_valid_reg;

  assign o_internal_api_we         = p1_api_we_reg;
  assign o_internal_api_address    = p1_api_address_reg;
  assign o_internal_api_write_data = p1_api_write_data_reg;

  assign o_internal_engine_api_cs  = p1_api_cs_reg && p1_select_engine_reg;
  assign o_internal_clock_api_cs   = p1_api_cs_reg && p1_select_clock_reg;
  assign o_internal_cookie_api_cs  = p1_api_cs_reg && p1_select_cookie_reg;
  assign o_internal_keymem_api_cs  = p1_api_cs_reg && p1_select_keymem_reg;
  assign o_internal_debug_api_cs   = p1_api_cs_reg && p1_select_debug_reg;
  assign o_internal_parser_api_cs  = p1_api_cs_reg && p1_select_parser_reg;

  assign o_busy = busy_reg;

  assign o_external_api_read_data       = p2_api_read_data_reg;
  assign o_external_api_read_data_valid = p2_api_read_data_valid_reg;

  always @*
  begin
    busy_we = 0;
    busy_new = 0;
    if (i_external_api_cs) begin
      busy_we = 1;
      busy_new = 1;
    end
    if (p1_api_cs_reg) begin
      busy_we = 1;
      busy_new = 0;
    end
  end

  always @(posedge i_clk or posedge i_areset)
  begin : pipeline_stage0;
    if (i_areset) begin
      busy_reg <= 0;

      p0_api_cs_reg         <= 0;
      p0_api_we_reg         <= 0;
      p0_api_address_reg    <= 0;
      p0_api_write_data_reg <= 0;

      p1_api_cs_reg         <= 0;
      p1_api_we_reg         <= 0;
      p1_api_address_reg    <= 0;
      p1_api_write_data_reg <= 0;
      p1_select_engine_reg  <= 0;
      p1_select_clock_reg   <= 0;
      p1_select_cookie_reg  <= 0;
      p1_select_keymem_reg  <= 0;
      p1_select_debug_reg   <= 0;
      p1_select_parser_reg  <= 0;

      p2_api_read_data_reg       <= 0;
      p2_api_read_data_valid_reg <= 0;
    end else begin
      if (busy_we)
        busy_reg <= busy_new;

      p0_api_cs_reg         <= i_external_api_cs;
      p0_api_we_reg         <= i_external_api_we;
      p0_api_address_reg    <= i_external_api_address;
      p0_api_write_data_reg <= i_external_api_write_data;

      p1_api_cs_reg         <= p0_api_cs_reg;
      p1_api_we_reg         <= p0_api_we_reg;
      p1_api_address_reg    <= addr_calculated;
      p1_api_write_data_reg <= p0_api_write_data_reg;
      p1_select_engine_reg  <= select_engine;
      p1_select_clock_reg   <= select_clock;
      p1_select_cookie_reg  <= select_cookie;
      p1_select_keymem_reg  <= select_keymem;
      p1_select_debug_reg   <= select_debug;
      p1_select_parser_reg  <= select_parser;

      p2_api_read_data_reg       <= p2_api_read_data_new;
      p2_api_read_data_valid_reg <= p1_api_cs_reg;
    end
  end

  always @*
  begin : address_decode
    reg [11:0] addr;
    reg [11:0] addr_offset;
    reg [11:0] addr_tmp;

    addr = p0_api_address_reg;
    addr_offset = 0;

    select_engine = 0;
    select_clock = 0;
    select_cookie = 0;
    select_keymem = 0;
    select_debug = 0;
    select_parser = 0;

    if (addr <= ADDR_ENGINE_STOP) begin
      select_engine = 1;
      addr_offset = ADDR_ENGINE_BASE;
    end else if ((addr >= ADDR_CLOCK_BASE) && (addr <= ADDR_CLOCK_STOP)) begin
      select_clock = 1;
      addr_offset = ADDR_CLOCK_BASE;
    end else if ((addr >= ADDR_COOKIE_BASE) && (addr <= ADDR_COOKIE_STOP)) begin
      select_cookie = 1;
      addr_offset = ADDR_COOKIE_BASE;
    end else if ((addr >= ADDR_KEYMEM_BASE) && (addr <= ADDR_KEYMEM_STOP)) begin
      select_keymem = 1;
      addr_offset = ADDR_KEYMEM_BASE;
    end else if ((addr >= ADDR_DEBUG_BASE) && (addr <= ADDR_DEBUG_STOP)) begin
      select_debug = 1;
      addr_offset = ADDR_DEBUG_BASE;
    end else if ((addr >= ADDR_PARSER_BASE) && (addr <= ADDR_PARSER_STOP)) begin
      select_parser = 1;
      addr_offset = ADDR_PARSER_BASE;
    end

    addr_tmp = addr - addr_offset;
    if (addr_tmp[11:8] != 0)
      addr_calculated = 0; //Unexpected error
    else
      addr_calculated = addr_tmp[7:0];
  end

  always @*
  begin : pipeline2_demux
    reg [5:0] demux_ctrl;
    p2_api_read_data_new = 0;
    demux_ctrl = { p1_select_engine_reg,
                   p1_select_clock_reg,
                   p1_select_cookie_reg,
                   p1_select_keymem_reg,
                   p1_select_debug_reg,
                   p1_select_parser_reg };
    if (p1_api_cs_reg && p1_api_we_reg == 'b0) begin
      case (demux_ctrl)
        6'b100_000: p2_api_read_data_new = i_internal_engine_api_read_data;
        6'b010_000: p2_api_read_data_new = i_internal_clock_api_read_data;
        6'b001_000: p2_api_read_data_new = i_internal_cookie_api_read_data;
        6'b000_100: p2_api_read_data_new = i_internal_keymem_api_read_data;
        6'b000_010: p2_api_read_data_new = i_internal_debug_api_read_data;
        6'b000_001: p2_api_read_data_new = i_internal_parser_api_read_data;
        default: ;
      endcase
    end
  end

endmodule
