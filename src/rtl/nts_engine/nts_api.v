//======================================================================
//
// nts_api.v
// ---------
// API for NTS engine.
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

module nts_api #(
  parameter [11:0] ADDR_ENGINE_BASE = 12'h000,
  parameter [11:0] ADDR_ENGINE_STOP = 12'h00F,
  parameter [11:0] ADDR_CLOCK_BASE  = 12'h010,
  parameter [11:0] ADDR_CLOCK_STOP  = 12'h01F,
  parameter [11:0] ADDR_COOKIE_BASE = 12'h020,
  parameter [11:0] ADDR_COOKIE_STOP = 12'h03F,
  parameter [11:0] ADDR_KEYMEM_BASE = 12'h080,
  parameter [11:0] ADDR_KEYMEM_STOP = 12'h17F,
  parameter [11:0] ADDR_DEBUG_BASE  = 12'h180,
  parameter [11:0] ADDR_DEBUG_STOP  = 12'h1F0,
  parameter [11:0] ADDR_PARSER_BASE = 12'h200,
  parameter [11:0] ADDR_PARSER_STOP = 12'h2FF,
  parameter [11:0] ADDR_NTPAUTH_KEYMEM_BASE = 12'h300,
  parameter [11:0] ADDR_NTPAUTH_KEYMEM_STOP = 12'h3FF
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
  input  wire [31:0] i_internal_parser_api_read_data,

  output wire        o_internal_ntpauth_keymem_api_cs,
  input  wire [31:0] i_internal_ntpauth_keymem_api_read_data
);

  //----------------------------------------------------------------
  // Busy reg, indicating the pipeline is working. Do not disturb.
  //----------------------------------------------------------------

  reg        busy_we;
  reg        busy_new;
  reg        busy_reg;

  //----------------------------------------------------------------
  // Pipeline stage 0. Capture external API.
  //----------------------------------------------------------------

  reg        p0_api_cs_reg;
  reg        p0_api_we_reg;
  reg [11:0] p0_api_address_reg;
  reg [31:0] p0_api_write_data_reg;

  //----------------------------------------------------------------
  // Pipeline stage 1. Address Decoded (demux)
  //----------------------------------------------------------------

  reg        p1_api_cs_reg;
  reg        p1_api_we_reg;
  reg  [7:0] p1_api_address_reg;
  reg [31:0] p1_api_write_data_reg;
  reg        p1_cs_engine_reg;
  reg        p1_cs_clock_reg;
  reg        p1_cs_cookie_reg;
  reg        p1_cs_keymem_reg;
  reg        p1_cs_debug_reg;
  reg        p1_cs_parser_reg;
  reg        p1_cs_ntpauth_keymem_reg;

  //----------------------------------------------------------------
  // Pipeline stage 2. Capture API endpoint read_data.
  //----------------------------------------------------------------

  reg        p2_api_cs_reg;
  reg        p2_api_we_reg;
  reg        p2_cs_engine_reg;
  reg        p2_cs_clock_reg;
  reg        p2_cs_cookie_reg;
  reg        p2_cs_keymem_reg;
  reg        p2_cs_debug_reg;
  reg        p2_cs_parser_reg;
  reg        p2_cs_ntpauth_keymem_reg;
  reg [31:0] p2_data_engine_reg;
  reg [31:0] p2_data_clock_reg;
  reg [31:0] p2_data_cookie_reg;
  reg [31:0] p2_data_keymem_reg;
  reg [31:0] p2_data_debug_reg;
  reg [31:0] p2_data_parser_reg;
  reg [31:0] p2_data_ntpauth_keymem_reg;

  //Pipleline stage 2 helper wires. Comintatorial logic, does not synthesis to wire registers.
  reg [7:0] addr_calculated;
  reg       select_engine;
  reg       select_clock;
  reg       select_cookie;
  reg       select_keymem;
  reg       select_debug;
  reg       select_parser;
  reg       select_ntpauth_keymem;

  //----------------------------------------------------------------
  // Pipeline stage 3. Mux p2_data_*_reg into p3_api_read_data_reg
  //----------------------------------------------------------------

  reg [31:0] p3_api_read_data_new;
  reg [31:0] p3_api_read_data_reg;
  reg        p3_api_read_data_valid_reg;

  //----------------------------------------------------------------
  // Output wire assignment
  //----------------------------------------------------------------

  assign o_internal_api_we         = p1_api_we_reg;
  assign o_internal_api_address    = p1_api_address_reg;
  assign o_internal_api_write_data = p1_api_write_data_reg;

  assign o_internal_engine_api_cs  = p1_cs_engine_reg;
  assign o_internal_clock_api_cs   = p1_cs_clock_reg;
  assign o_internal_cookie_api_cs  = p1_cs_cookie_reg;
  assign o_internal_keymem_api_cs  = p1_cs_keymem_reg;
  assign o_internal_debug_api_cs   = p1_cs_debug_reg;
  assign o_internal_parser_api_cs  = p1_cs_parser_reg;
  assign o_internal_ntpauth_keymem_api_cs  = p1_cs_ntpauth_keymem_reg;

  assign o_busy = busy_reg;

  assign o_external_api_read_data       = p3_api_read_data_reg;
  assign o_external_api_read_data_valid = p3_api_read_data_valid_reg;

  //----------------------------------------------------------------
  // Busy reg
  //----------------------------------------------------------------

  always @*
  begin
    busy_we = 0;
    busy_new = 0;
    if (i_external_api_cs) begin
      busy_we = 1;
      busy_new = 1;
    end
    if (p2_api_cs_reg) begin
      busy_we = 1;
      busy_new = 0;
    end
  end

  //----------------------------------------------------------------
  // Reg update. Updates the pipeline
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
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
      p1_cs_engine_reg      <= 0;
      p1_cs_clock_reg       <= 0;
      p1_cs_cookie_reg      <= 0;
      p1_cs_keymem_reg      <= 0;
      p1_cs_debug_reg       <= 0;
      p1_cs_parser_reg      <= 0;
      p1_cs_ntpauth_keymem_reg      <= 0;

      p2_api_cs_reg      <= 0;
      p2_api_we_reg      <= 0;
      p2_cs_engine_reg   <= 0;
      p2_cs_clock_reg    <= 0;
      p2_cs_cookie_reg   <= 0;
      p2_cs_keymem_reg   <= 0;
      p2_cs_debug_reg    <= 0;
      p2_cs_parser_reg   <= 0;
      p2_cs_ntpauth_keymem_reg   <= 0;
      p2_data_engine_reg <= 0;
      p2_data_clock_reg  <= 0;
      p2_data_cookie_reg <= 0;
      p2_data_keymem_reg <= 0;
      p2_data_debug_reg  <= 0;
      p2_data_parser_reg <= 0;
      p2_data_ntpauth_keymem_reg <= 0;

      p3_api_read_data_reg       <= 0;
      p3_api_read_data_valid_reg <= 0;
    end else begin
      if (busy_we)
        busy_reg <= busy_new;

      // Pipeline stage 0: capture input

      p0_api_cs_reg         <= i_external_api_cs;
      p0_api_we_reg         <= i_external_api_we;
      p0_api_address_reg    <= i_external_api_address;
      p0_api_write_data_reg <= i_external_api_write_data;

      // Pipeline stage 1: decode input

      p1_api_cs_reg         <= p0_api_cs_reg;
      p1_api_we_reg         <= p0_api_we_reg;
      p1_api_address_reg    <= addr_calculated;
      p1_api_write_data_reg <= p0_api_write_data_reg;
      p1_cs_engine_reg      <= p0_api_cs_reg && select_engine;
      p1_cs_clock_reg       <= p0_api_cs_reg && select_clock;
      p1_cs_cookie_reg      <= p0_api_cs_reg && select_cookie;
      p1_cs_keymem_reg      <= p0_api_cs_reg && select_keymem;
      p1_cs_debug_reg       <= p0_api_cs_reg && select_debug;
      p1_cs_parser_reg      <= p0_api_cs_reg && select_parser;
      p1_cs_ntpauth_keymem_reg      <= p0_api_cs_reg && select_ntpauth_keymem;

      // Pipeline stage 2: capture API endpoints read_data

      p2_api_cs_reg      <= p1_api_cs_reg;
      p2_api_we_reg      <= p1_api_we_reg;
      p2_cs_engine_reg   <= p1_cs_engine_reg;
      p2_cs_clock_reg    <= p1_cs_clock_reg;
      p2_cs_cookie_reg   <= p1_cs_cookie_reg;
      p2_cs_keymem_reg   <= p1_cs_keymem_reg;
      p2_cs_debug_reg    <= p1_cs_debug_reg;
      p2_cs_parser_reg   <= p1_cs_parser_reg;
      p2_cs_ntpauth_keymem_reg   <= p1_cs_ntpauth_keymem_reg;
      p2_data_engine_reg <= i_internal_engine_api_read_data;
      p2_data_clock_reg  <= i_internal_clock_api_read_data;
      p2_data_cookie_reg <= i_internal_cookie_api_read_data;
      p2_data_keymem_reg <= i_internal_keymem_api_read_data;
      p2_data_debug_reg  <= i_internal_debug_api_read_data;
      p2_data_parser_reg <= i_internal_parser_api_read_data;
      p2_data_ntpauth_keymem_reg <= i_internal_ntpauth_keymem_api_read_data;

      // Pipeline stage 3: output results

      p3_api_read_data_reg       <= p3_api_read_data_new;
      p3_api_read_data_valid_reg <= p2_api_cs_reg;
    end
  end

  //----------------------------------------------------------------
  // Address Decode.
  //  * Reads pipeline stage 0
  //  * Decodes into pipeline 1
  //----------------------------------------------------------------

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
    select_ntpauth_keymem = 0;

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
    end else if ((addr >= ADDR_NTPAUTH_KEYMEM_BASE) && (addr <= ADDR_NTPAUTH_KEYMEM_STOP)) begin
      select_ntpauth_keymem = 1;
      addr_offset = ADDR_NTPAUTH_KEYMEM_BASE;
    end

    addr_tmp = addr - addr_offset;
    if (addr_tmp[11:8] != 0)
      addr_calculated = 0; //Unexpected error
    else
      addr_calculated = addr_tmp[7:0];
  end

  //----------------------------------------------------------------
  // Pipeline Stage 3 output mux
  //  * Reads pipeline stage 2
  //  * Muxes into pipeline 3
  //----------------------------------------------------------------

  always @*
  begin : pipeline3_mux
    reg [6:0] mux_ctrl;
    p3_api_read_data_new = 0;
    mux_ctrl = { p2_cs_engine_reg,
                 p2_cs_clock_reg,
                 p2_cs_cookie_reg,
                 p2_cs_keymem_reg,
                 p2_cs_debug_reg,
                 p2_cs_parser_reg,
                 p2_cs_ntpauth_keymem_reg };
    if (p2_api_cs_reg && p2_api_we_reg == 'b0) begin
      case (mux_ctrl)
        7'b100_0000: p3_api_read_data_new = p2_data_engine_reg;
        7'b010_0000: p3_api_read_data_new = p2_data_clock_reg;
        7'b001_0000: p3_api_read_data_new = p2_data_cookie_reg;
        7'b000_1000: p3_api_read_data_new = p2_data_keymem_reg;
        7'b000_0100: p3_api_read_data_new = p2_data_debug_reg;
        7'b000_0010: p3_api_read_data_new = p2_data_parser_reg;
        7'b000_0001: p3_api_read_data_new = p2_data_ntpauth_keymem_reg;
        default: ;
      endcase
    end
  end

endmodule
