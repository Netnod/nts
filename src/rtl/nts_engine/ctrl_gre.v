//======================================================================
//
// ctrl_gre.v
// ----------
// Control for the default packets GRE wrapping functionality.
//
// Author: Peter Magnusson
//
//
// Copyright (c) 2019, Netnod Internet Exchange i Sverige AB (Netnod).
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
//======================================================================

module ctrl_gre #(
  parameter ADDR_WIDTH = 10
) (
  input i_clk,
  input i_areset,

  input i_detect_ipv4,
  input i_detect_ipv6,
  input i_addr_match_ipv4,
  input i_addr_match_ipv6,

  input        i_api_dst_mac_msb_we,
  input        i_api_dst_mac_lsb_we,
  input        i_api_dst_ipv4_we,
  input        i_api_src_mac_msb_we,
  input        i_api_src_mac_lsb_we,
  input        i_api_src_ipv4_we,
  input [31:0] i_api_wdata,

  input                     i_process,

  input  [ADDR_WIDTH+3-1:0] i_memory_bound,
  input                     i_copy_done,

  output                    o_rx_rd,
  output [ADDR_WIDTH+3-1:0] o_rx_addr,
  output [ADDR_WIDTH+3-1:0] o_rx_burst,

  output [ADDR_WIDTH+3-1:0] o_tx_addr,
  output                    o_tx_from_rx,

  output                    o_responder_en,
  output             [63:0] o_responder_data,
  output                    o_responder_update_length,
  output                    o_responder_length_we,
  output [ADDR_WIDTH+3-1:0] o_responder_length_new,

  output o_packet_transmit,
  output o_packet_drop
);

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam BITS_STATE = 3;
  localparam [BITS_STATE-1:0] STATE_IDLE          = 3'h0;
  localparam [BITS_STATE-1:0] STATE_INIT          = 3'h1;
  localparam [BITS_STATE-1:0] STATE_RESPOND       = 3'h2;
  localparam [BITS_STATE-1:0] STATE_COPY          = 3'h3;
  localparam [BITS_STATE-1:0] STATE_COPY_D        = 3'h4;
  localparam [BITS_STATE-1:0] STATE_UPDATE_LENGTH = 3'h5;
  localparam [BITS_STATE-1:0] STATE_DROP          = 3'h6;
  localparam [BITS_STATE-1:0] STATE_TRANSMIT      = 3'h7;

  localparam [15:0] E_TYPE_IPV4 =  16'h08_00;
  localparam [15:0] E_TYPE_IPV6 =  16'h86_DD;

  localparam [3:0] IP_V4        =  4'h4;
  localparam  [7:0] IPV4_TOS     = 0;
  localparam  [2:0] IPV4_FLAGS   = 3'b010; // Reserved=0, must be zero. DF=1 (don't fragment). MF=0 (Last Fragment)
  localparam  [7:0] IPV4_TTL     = 8'h0f;
  localparam [12:0] IPV4_FRAGMENT_OFFSET = 0;

  localparam  [7:0] IP_PROTO_GRE = 47;

  localparam [ 0:0] GRE_CHECKSUM_PRESENT_FALSE = 0;
  localparam [11:0] GRE_RESERVED0_ALL_ZERO = 0;
  localparam  [2:0] GRE_VERSION_0 = 0;

  localparam HEADER_LENGTH_ETHERNET = 6+6+2;
  localparam HEADER_LENGTH_IPV4     = 5*4; //IHL=5, word size 4 bytes.
  localparam HEADER_LENGTH_GRE      = 4;

  localparam OFFSET_GRE_PAYLOAD     = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV4 + HEADER_LENGTH_GRE;


  //----------------------------------------------------------------
  // Registers
  //----------------------------------------------------------------

  reg                  state_we;
  reg [BITS_STATE-1:0] state_new;
  reg [BITS_STATE-1:0] state_reg;

  reg    [31:0] mac_dst_lsb_reg;
  reg    [15:0] mac_dst_msb_reg;
  wire   [47:0] mac_dst;
  assign        mac_dst = { mac_dst_msb_reg, mac_dst_lsb_reg };

  reg    [31:0] mac_src_lsb_reg;
  reg    [15:0] mac_src_msb_reg;
  wire   [47:0] mac_src;
  assign        mac_src = { mac_src_msb_reg, mac_src_lsb_reg };

  reg [31:0] ip_dst_reg;
  reg [31:0] ip_src_reg;

  reg        gre_protocol_we;
  reg [15:0] gre_protocol_new;
  reg [15:0] gre_protocol_reg;

  reg respond_done_we;
  reg respond_done_new;
  reg respond_done_reg;

  reg [15:0] tx_ipv4_totlen_new;
  reg [15:0] tx_ipv4_totlen_reg;

  reg [15:0] tx_ipv4_csum_new;
  reg [15:0] tx_ipv4_csum_reg;

  reg                          response_en_new;
  reg                   [63:0] response_data_new;
  reg                          response_length_we;
  reg       [ADDR_WIDTH+3-1:0] response_packet_total_length_new;
  reg       [ADDR_WIDTH+3-1:0] response_packet_total_length_reg;

  reg                          responder_update_length;
  reg                    respond_ctr_we;
  reg [ADDR_WIDTH+3-1:0] respond_ctr_new;
  reg [ADDR_WIDTH+3-1:0] respond_ctr_reg;

  wire    [111:0] tx_header_ethernet;
  wire [16*5-1:0] tx_header_ipv4_nocsum0;
  wire [16*4-1:0] tx_header_ipv4_nocsum1;
  wire [32*5-1:0] tx_header_ipv4;
  wire     [31:0] tx_header_gre;
  wire [38*8-1:0] tx_header_eth_ipv4_gre;
  wire    [319:0] tx_header_eth_ipv4_gre_padded;

  reg                    rx_rd;
  reg [ADDR_WIDTH+3-1:0] rx_addr;
  reg [ADDR_WIDTH+3-1:0] rx_burst;

  reg [ADDR_WIDTH+3-1:0] tx_addr;
  reg                    tx_from_rx;

  reg [ADDR_WIDTH+3-1:0] bytes_to_copy_new;
  reg [ADDR_WIDTH+3-1:0] bytes_to_copy_reg;

  //----------------------------------------------------------------
  // Responder (TX delayed) outputs
  //----------------------------------------------------------------

  assign o_responder_en = response_en_new;
  assign o_responder_data = response_data_new;
  assign o_responder_length_we = response_length_we;
  assign o_responder_length_new = response_packet_total_length_reg;
  assign o_responder_update_length = responder_update_length;

  //----------------------------------------------------------------
  // RX access port outs
  //----------------------------------------------------------------

  assign o_rx_rd = rx_rd;
  assign o_rx_addr = rx_addr;
  assign o_rx_burst = rx_burst;

  //----------------------------------------------------------------
  // TX outs
  //----------------------------------------------------------------

  assign o_tx_addr = tx_addr;
  assign o_tx_from_rx = tx_from_rx;

  //----------------------------------------------------------------
  // State outs
  //----------------------------------------------------------------

  assign o_packet_transmit = state_reg == STATE_TRANSMIT;
  assign o_packet_drop     = state_reg == STATE_DROP;

  //----------------------------------------------------------------
  // Functions
  //----------------------------------------------------------------

  function [16:0] calc_csum16 ( input [15:0] a, input [15:0] b );
    calc_csum16 = { 1'b0, a } + { 1'b0, b };
  endfunction

  function [15:0] ipv4_csum ( input [16*9-1:0] header );

    integer     i;

    reg  [8:0] carry;
    reg  [7:0] msb; // Largest possible msb is 8 as in 9*0xFFFF=0x8FFF7
    reg [15:0] sum0 [0:4];
    reg [15:0] sum1 [0:1];
    reg [15:0] sum2;
    reg [15:0] sum3;
    reg [15:0] sum4;
    reg [15:0] notsum4;

  begin
    for (i = 0; i < 4; i = i+1) begin
      { carry[i], sum0[i] } = calc_csum16( header[i*32+:16], header[i*32+16+:16] );
    end
    for (i = 0; i < 2; i = i+1) begin
      { carry[4+i], sum1[i] } = calc_csum16( sum0[2*i], sum0[2*i+1] );
    end
    { carry[6], sum2 } = calc_csum16( sum1[0], sum1[1] );
    { carry[7], sum3 } = calc_csum16( sum2, header[143-:16] );

    msb = 0;
    for (i = 0; i < 8; i = i + 1) begin
      msb = msb + { 7'h0, carry[i] };
    end

    sum4 = sum3 + { 8'h0, msb }; //Cannot overflow! 0x8FFF7 = 0x8 + 0xFFF7 = 0xFFFF
    notsum4 = ~sum4;
    ipv4_csum = notsum4;
  end
  endfunction

  //----------------------------------------------------------------
  // IPV4 header checksum calculation
  //----------------------------------------------------------------

  always @*
  begin : ipv4_calc_proc
    reg [16*9-1:0] words;
    words = { tx_header_ipv4_nocsum0, tx_header_ipv4_nocsum1 };
    tx_ipv4_csum_new = ipv4_csum( words );
  end

  //----------------------------------------------------------------
  // IPV4 total length caluclation
  //----------------------------------------------------------------

  always @*
  begin
    tx_ipv4_totlen_new = 0;
    tx_ipv4_totlen_new[ADDR_WIDTH+3-1:0] = i_memory_bound;
    tx_ipv4_totlen_new = tx_ipv4_totlen_new
                       + HEADER_LENGTH_IPV4
                       + HEADER_LENGTH_GRE
                       - HEADER_LENGTH_ETHERNET;
  end

  always @*
  begin
    response_packet_total_length_new = 0;
    if (i_process) begin
      response_packet_total_length_new = i_memory_bound
                                       + HEADER_LENGTH_IPV4
                                       + HEADER_LENGTH_GRE;
    end
  end


  //----------------------------------------------------------------
  // GRE protocol type
  //----------------------------------------------------------------

  always @*
  begin
    gre_protocol_we = 0;
    gre_protocol_new = 0;
    if (i_process) begin
      if (i_detect_ipv4) begin
        gre_protocol_we = 1;
        gre_protocol_new = E_TYPE_IPV4;
      end else if (i_detect_ipv6) begin
        gre_protocol_we = 1;
        gre_protocol_new = E_TYPE_IPV6;
      end else begin
        gre_protocol_we = 1;
        gre_protocol_new = 0;
      end
    end
  end


  //----------------------------------------------------------------
  // GRE payload data length (bytes to copy)
  //----------------------------------------------------------------

  always @*
  begin
    bytes_to_copy_new = i_memory_bound - HEADER_LENGTH_ETHERNET;
  end


  assign tx_header_ethernet = {
                                mac_dst,
                                mac_src,
                                E_TYPE_IPV4
                              };

  assign tx_header_ipv4_nocsum0 = {
           IP_V4, 4'h5, IPV4_TOS, tx_ipv4_totlen_reg,  //|Version|  IHL  |Type of Service|          Total Length         |
           16'h0000, IPV4_FLAGS, IPV4_FRAGMENT_OFFSET, //|         Identification        |Flags|      Fragment Offset    |
           IPV4_TTL, IP_PROTO_GRE };                   //|  Time to Live |    Protocol   |         Header Checksum       |
  assign tx_header_ipv4_nocsum1 = {
           ip_src_reg,                                 //|                       Source Address                          |
           ip_dst_reg };                               //|                    Destination Address                        |

  assign tx_header_ipv4 = { tx_header_ipv4_nocsum0, tx_ipv4_csum_reg, tx_header_ipv4_nocsum1 };
  assign tx_header_gre = {
                           GRE_CHECKSUM_PRESENT_FALSE,
                           GRE_RESERVED0_ALL_ZERO,
                           GRE_VERSION_0,
                           gre_protocol_reg
                         };

  assign tx_header_eth_ipv4_gre = { tx_header_ethernet, tx_header_ipv4, tx_header_gre };

  assign tx_header_eth_ipv4_gre_padded = { tx_header_eth_ipv4_gre, 16'h0 };

  //----------------------------------------------------------------
  // GRE header responder.
  //----------------------------------------------------------------

  always @*
  begin
    rx_addr = 0;
    rx_burst = 0;
    rx_rd = 0;
    tx_addr = 0;
    tx_from_rx = 0;
    response_en_new = 0;
    response_data_new = 0;
    respond_done_we = 0;
    respond_done_new = 0;
    response_length_we = 0;
    responder_update_length = 0;

    respond_ctr_we = 0;
    respond_ctr_new = 0;

    case (state_reg)
      STATE_INIT:
       begin
         response_length_we = 1;
         respond_ctr_we = 1;
         respond_ctr_new = 4;
         respond_done_we = 1;
         respond_done_new = 0;
       end
      STATE_RESPOND:
        if (respond_done_reg == 1'b0) begin
          respond_ctr_we = 1;
          respond_ctr_new = respond_ctr_reg - 1;
          response_en_new = 1;
          response_data_new = tx_header_eth_ipv4_gre_padded[respond_ctr_reg*64+:64];
          respond_done_we = 1;
          respond_done_new = respond_ctr_reg == 0;
        end
      STATE_COPY:
        begin
          rx_addr = HEADER_LENGTH_ETHERNET;
          rx_burst = bytes_to_copy_reg;
          rx_rd = 1;
          tx_addr = OFFSET_GRE_PAYLOAD;
          tx_from_rx = 1;
        end
      STATE_UPDATE_LENGTH:
        begin
          responder_update_length = 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Finite State Machine
  //----------------------------------------------------------------

  always @*
  begin : fsm
    state_we = 0;
    state_new = 0;
    case (state_reg)
      STATE_IDLE:
        if (i_process) begin
          if (i_detect_ipv4 && i_addr_match_ipv4) begin
            state_we = 1;
            state_new = STATE_INIT;
          end else if (i_detect_ipv6 && i_addr_match_ipv6) begin
            state_we = 1;
            state_new = STATE_INIT;
          end else begin
            state_we = 1;
            state_new = STATE_DROP;
          end
        end
      STATE_INIT:
        begin
          state_we = 1;
          state_new = STATE_RESPOND;
        end
      STATE_RESPOND:
        if (respond_done_reg) begin
          state_we = 1;
          state_new = STATE_COPY;
        end
      STATE_COPY:
        begin
          state_we = 1;
          state_new = STATE_COPY_D;
        end
      STATE_COPY_D:
        if (i_copy_done) begin
          state_we = 1;
          state_new = STATE_UPDATE_LENGTH;
        end
      STATE_UPDATE_LENGTH:
        begin
          state_we = 1;
          state_new = STATE_TRANSMIT;
        end
      STATE_DROP:
        begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_TRANSMIT:
        begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      default:
        begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
    endcase
  end

  //----------------------------------------------------------------
  // Finite State Machine
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_up
    if (i_areset) begin

      bytes_to_copy_reg <= 0;

      mac_dst_lsb_reg  <= 0;
      mac_dst_msb_reg  <= 0;

      mac_src_lsb_reg  <= 0;
      mac_src_msb_reg  <= 0;

      ip_dst_reg <= 0;
      ip_src_reg <= 0;

      gre_protocol_reg <= 0;

      response_packet_total_length_reg <= 0;

      respond_ctr_reg <= 0;
      respond_done_reg <= 0;

      state_reg <= STATE_IDLE;

      tx_ipv4_csum_reg <= 0;
      tx_ipv4_totlen_reg <= 0;
    end else begin

      bytes_to_copy_reg <= bytes_to_copy_new;

      if (i_api_dst_mac_lsb_we)
        mac_dst_lsb_reg <= i_api_wdata;

      if (i_api_dst_mac_msb_we)
        mac_dst_msb_reg <= i_api_wdata[15:0];

      if (i_api_dst_ipv4_we)
        ip_dst_reg <= i_api_wdata;

      if (i_api_src_mac_lsb_we)
        mac_src_lsb_reg <= i_api_wdata;

      if (i_api_src_mac_msb_we)
        mac_src_msb_reg <= i_api_wdata[15:0];

      if (i_api_src_ipv4_we)
        ip_src_reg <= i_api_wdata;

      if (gre_protocol_we)
        gre_protocol_reg <= gre_protocol_new;


      response_packet_total_length_reg <= response_packet_total_length_new;

      if (respond_ctr_we)
        respond_ctr_reg <= respond_ctr_new;

      if (respond_done_we)
        respond_done_reg <= respond_done_new;

      if (state_we)
        state_reg <= state_new;

      tx_ipv4_csum_reg <= tx_ipv4_csum_new;
      tx_ipv4_totlen_reg <= tx_ipv4_totlen_new;
    end
  end

endmodule
