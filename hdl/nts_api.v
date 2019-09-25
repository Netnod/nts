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
  parameter [11:0] ADDR_DEBUG_STOP  = 12'h1FF
) (
  input  wire        i_external_api_cs,
  input  wire        i_external_api_we,
  input  wire [11:0] i_external_api_address,
  input  wire [31:0] i_external_api_write_data,
  output wire [31:0] o_external_api_read_data,

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
  input  wire [31:0] i_internal_debug_api_read_data
);

  wire        select_engine;
  wire        select_clock;
  wire        select_cookie;
  wire        select_keymem;
  wire        select_debug;
  wire [11:0] addr_offset;
  wire [11:0] addr_calculated;


  assign select_engine             = /*(i_external_api_address >= ADDR_ENGINE_BASE) && */ (i_external_api_address <= ADDR_ENGINE_STOP);
  assign select_clock              = (i_external_api_address >= ADDR_CLOCK_BASE)  && (i_external_api_address <= ADDR_CLOCK_STOP);
  assign select_cookie             = (i_external_api_address >= ADDR_COOKIE_BASE) && (i_external_api_address <= ADDR_COOKIE_STOP);
  assign select_keymem             = (i_external_api_address >= ADDR_KEYMEM_BASE) && (i_external_api_address <= ADDR_KEYMEM_STOP);
  assign select_debug              = (i_external_api_address >= ADDR_DEBUG_BASE)  && (i_external_api_address <= ADDR_DEBUG_STOP);

  assign addr_offset               = select_engine ? ADDR_ENGINE_BASE : (
                                     select_clock  ? ADDR_CLOCK_BASE : (
                                     select_cookie ? ADDR_COOKIE_BASE : (
                                     select_keymem ? ADDR_KEYMEM_BASE  : (
                                     select_debug  ? ADDR_DEBUG_BASE : 0 ))));

  assign addr_calculated           = i_external_api_address - addr_offset;

  assign o_internal_api_we         = i_external_api_we;
  assign o_internal_api_address    = addr_calculated[7:0];
  assign o_internal_api_write_data = i_external_api_write_data;

  assign o_internal_engine_api_cs  = i_external_api_cs && select_engine;
  assign o_internal_clock_api_cs   = i_external_api_cs && select_clock;
  assign o_internal_cookie_api_cs  = i_external_api_cs && select_cookie;
  assign o_internal_keymem_api_cs  = i_external_api_cs && select_keymem;
  assign o_internal_debug_api_cs   = i_external_api_cs && select_debug;

  assign o_external_api_read_data  = i_external_api_cs ? (
                                       select_engine ? i_internal_engine_api_read_data : (
                                       select_clock  ? i_internal_clock_api_read_data : (
                                       select_cookie ? i_internal_cookie_api_read_data : (
                                       select_keymem ? i_internal_keymem_api_read_data  : (
                                       select_debug  ? i_internal_debug_api_read_data :
                                       0 ))))
                                     ) : 0;


endmodule
