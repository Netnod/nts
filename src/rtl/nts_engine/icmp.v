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
module icmp #(
  parameter ADDR_WIDTH = 10
) (
  input  i_clk,
  input  i_areset,

  input  [47:0] i_ethernet_dst,
  input  [47:0] i_ethernet_src,
  input  [47:0] i_ethernet_ns6src,

  input  [31:0] i_ip4_dst,
  input  [31:0] i_ip4_src,

  input [127:0] i_ip6_ns_target_address,
  input [127:0] i_ip6_dst,
  input [127:0] i_ip6_src,
  input   [7:0] i_ip6_priority,
  input   [3:0] i_ip6_flowlabel_msb,
  input  [15:0] i_ip6_payload_length,

  input [15:0] i_icmp_echo_id,
  input [15:0] i_icmp_echo_seq,
  input [15:0] i_icmp_echo_d0,

  input  i_process,

  input  i_pd_ip4_echo,
  input  i_pd_ip4_trace,

  input  i_pd_ip6_ns,
  input  i_pd_ip6_echo,
  input  i_pd_ip6_trace,

  input  i_match_addr_ethernet,
  input  i_match_addr_ip4,
  input  i_match_addr_ip6,
  input  i_match_addr_ip6_ns,

  input  i_copy_done,

  input                     i_tx_busy,
  input              [15:0] i_tx_sum,
  input                     i_tx_sum_done,
  output                    o_tx_sum_en,
  output [ADDR_WIDTH+3-1:0] o_tx_sum_bytes,
  output                    o_tx_sum_reset,
  output             [15:0] o_tx_sum_reset_value,

  input  [ADDR_WIDTH+3-1:0] i_memory_bound,

  output                    o_ap_rd,
  output [ADDR_WIDTH+3-1:0] o_ap_addr,
  output [ADDR_WIDTH+3-1:0] o_ap_burst,

  output [ADDR_WIDTH+3-1:0] o_tx_addr,
  output                    o_tx_write_en,
  output             [63:0] o_tx_write_data,

  output o_tx_from_rx,

  output o_icmp_idle,

  output                    o_responder_en,
  output             [63:0] o_responder_data,
  output                    o_responder_update_length,
  output                    o_responder_length_we,
  output [ADDR_WIDTH+3-1:0] o_responder_length_new,

  output o_packet_drop,
  output o_packet_transmit
);

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam BITS_ICMP_STATE = 6;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_IDLE             = 6'h00;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_ND_INIT       = 6'h01;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_ND_RESPOND    = 6'h02;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_ECHO_INIT     = 6'h03;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_ECHO_RESPOND  = 6'h04;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_ECHO_COPY     = 6'h05;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_ECHO_COPY_D   = 6'h06;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_ECHO_COPY_D2  = 6'h07;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_TRACE_INIT    = 6'h08;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_TRACE_RESPOND = 6'h09;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_TRACE_COPY    = 6'h0a;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_TRACE_COPY_D  = 6'h0b;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_UPDATE_LENGTH = 6'h10;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_CSUM_RESET    = 6'h11;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_CSUM_CALC     = 6'h12;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_CSUM_WAIT     = 6'h13;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_CSUM_UPDATE   = 6'h14;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V6_CSUM_UPDATE_D = 6'h15;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_ECHO_INIT     = 6'h20;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_ECHO_RESPOND  = 6'h21;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_ECHO_COPY     = 6'h22;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_ECHO_COPY_D   = 6'h23;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_ECHO_COPY_D2  = 6'h24;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_TRACE_INIT    = 6'h25;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_TRACE_RESPOND = 6'h26;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_TRACE_COPY    = 6'h27;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_TRACE_COPY_D  = 6'h28;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_UPDATE_LENGTH = 6'h30;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_CSUM_RESET    = 6'h31;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_CSUM_CALC     = 6'h32;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_CSUM_WAIT     = 6'h33;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_CSUM_UPDATE   = 6'h34;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_V4_CSUM_UPDATE_D = 6'h35;

  localparam [BITS_ICMP_STATE-1:0] ICMP_S_DROP_PACKET      = 6'h3e;
  localparam [BITS_ICMP_STATE-1:0] ICMP_S_TRANSMIT_PACKET  = 6'h3f;

  localparam HEADER_LENGTH_ETHERNET = 6+6+2;
  localparam HEADER_LENGTH_IPV4     = 5*4; //IHL=5, word size 4 bytes.
  localparam HEADER_LENGTH_IPV6     = 40;
  localparam OFFSET_ETH_IPV4_DATA       = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV4;
  localparam OFFSET_ICMP_V4_ECHO_COPY = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV4 + 4; //Type,Code,Csum
  localparam OFFSET_ICMP_V6_ECHO_COPY = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV6 + 4; //Type,Code,Csum
  localparam [15:0] E_TYPE_IPV4 =  16'h08_00;
  localparam [15:0] E_TYPE_IPV6 =  16'h86_DD;
  localparam ICMP_V4_UNREACHABLE_INITIAL_BYTES = 8; //Type,Code,Csum,Unused
  localparam ICMP_V6_UNREACHABLE_INITIAL_BYTES = 8; //Type,Code,Csum,Unused
  localparam       ICMPV4_BYTES_TRACEROUTE = 20 + 8; //RFC 792; Internet Header + 64 bits of Original Data Datagram
  localparam        IPV6_MTU_MIN  = 1280;

  localparam [3:0] IP_V4        =  4'h4;
  localparam [3:0] IP_V6        =  4'h6;

  localparam  [7:0] IPV4_TOS     = 0;
  localparam  [2:0] IPV4_FLAGS   = 3'b010; // Reserved=0, must be zero. DF=1 (don't fragment). MF=0 (Last Fragment)
  localparam  [7:0] IPV4_TTL     = 8'hff;
  localparam [12:0] IPV4_FRAGMENT_OFFSET = 0;

  localparam  [7:0] IPV6_TC       =  8'h0;
  localparam [19:0] IPV6_FL       = 20'h0;
  localparam  [7:0] IPV6_HOPLIMIT = IPV4_TTL;

  localparam  [7:0] IP_PROTO_ICMPV4 = 8'h01;
  localparam  [7:0] IP_PROTO_ICMPV6 = 8'h3a; //58

  localparam [7:0] ICMP_TYPE_V4_ECHO_REPLY             =   0;
  localparam [7:0] ICMP_TYPE_V4_DEST_UNREACHABLE       =   3;
  localparam [7:0] ICMP_TYPE_V4_ECHO_REQUEST           =   8;
  localparam [7:0] ICMP_TYPE_V6_DEST_UNREACHABLE       =   1;
  localparam [7:0] ICMP_TYPE_V6_ECHO_REQUEST           = 128;
  localparam [7:0] ICMP_TYPE_V6_ECHO_REPLY             = 129;
  localparam [7:0] ICMP_TYPE_V6_NEIGHBOR_SOLICITATION  = 135;
  localparam [7:0] ICMP_TYPE_V6_NEIGHBOR_ADVERTISEMENT = 136;

  localparam [7:0] ICMP_CODE_V4_UNREACHABLE_PORT = 3;
  localparam [7:0] ICMP_CODE_V6_UNREACHABLE_PORT = 4;

  localparam OFFSET_ETH_IPV6_ICMPV6_CSUM = 'h38;
  localparam OFFSET_ETH_IPV6_SRCADDR    = HEADER_LENGTH_ETHERNET + 8;
  localparam OFFSET_ETH_IPV4_ICMPV4_CSUM = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV4 + 2; //Type,Code


  reg                        icmp_state_we;
  reg  [BITS_ICMP_STATE-1:0] icmp_state_new;
  reg  [BITS_ICMP_STATE-1:0] icmp_state_reg;

  reg [ADDR_WIDTH+3-1:0] ap_addr;
  reg [ADDR_WIDTH+3-1:0] ap_burst;
  reg                    ap_rd;

  reg tx_from_rx;

  reg [ADDR_WIDTH+3-1:0] tx_address;
  reg [ADDR_WIDTH+3-1:0] tx_sum_bytes;
  reg tx_sum_en;
  reg tx_sum_reset;
  reg [15:0] tx_sum_reset_value;
  reg tx_write_en;
  reg [63:0] tx_write_data;

  reg response_done_new;
  reg response_done_reg;

  reg                          response_en_new;
  reg                  [63:0]  response_data_new;
  reg                          responder_update_length;
  reg                          response_packet_total_length_we;
  reg       [ADDR_WIDTH+3-1:0] response_packet_total_length_new;
//reg       [ADDR_WIDTH+3-1:0] response_packet_total_length_reg;

  reg                    tx_icmpv4_ip_total_length_we;
  reg [ADDR_WIDTH+3-1:0] tx_icmpv4_ip_total_length_new;
  reg [ADDR_WIDTH+3-1:0] tx_icmpv4_ip_total_length_reg;
  reg             [15:0] tx_icmpv4_ip_checksum_new;
  reg             [15:0] tx_icmpv4_ip_checksum_reg;

  reg                    tx_icmp_payload_length_we;
  reg [ADDR_WIDTH+3-1:0] tx_icmp_payload_length_new;
  reg [ADDR_WIDTH+3-1:0] tx_icmp_payload_length_reg;
  reg                    tx_icmp_csum_bytes_we;
  reg [ADDR_WIDTH+3-1:0] tx_icmp_csum_bytes_new;
  reg [ADDR_WIDTH+3-1:0] tx_icmp_csum_bytes_reg;
  reg                    tx_icmp_tmpblock_we;
  reg             [63:0] tx_icmp_tmpblock_new;
  reg             [63:0] tx_icmp_tmpblock_reg;


  wire    [111:0] tx_header_ethernet_ipv4;
  wire    [111:0] tx_header_ethernet_ipv6;

  reg        tx_header_icmpv6_echo_index_we;
  reg  [3:0] tx_header_icmpv6_echo_index_new;
  reg  [3:0] tx_header_icmpv6_echo_index_reg;

  reg        tx_header_icmpv4_trace_index_we;
  reg  [3:0] tx_header_icmpv4_trace_index_new;
  reg  [3:0] tx_header_icmpv4_trace_index_reg;

  reg        tx_header_icmpv6ns_index_we;
  reg  [3:0] tx_header_icmpv6ns_index_new;
  reg  [3:0] tx_header_icmpv6ns_index_reg;

  reg        tx_header_icmpv6_trace_index_we;
  reg  [3:0] tx_header_icmpv6_trace_index_new;
  reg  [3:0] tx_header_icmpv6_trace_index_reg;

  reg        tx_header_icmpv4_echo_index_we;
  reg  [3:0] tx_header_icmpv4_echo_index_new;
  reg  [3:0] tx_header_icmpv4_echo_index_reg;


  wire [14*8-1:0] tx_header_ethernet_na;
  wire [40*8-1:0] tx_header_ipv6_na;
  wire [32*8-1:0] tx_header_icmp_na;
  wire [86*8-1:0] tx_header_ethernet_ipv6_icmp_na;

  wire [ 4*8-1:0] tx_header_icmp_echo;
  wire [40*8-1:0] tx_header_ipv6_echo;
  wire [58*8-1:0] tx_header_ethernet_ipv6_icmp_echo;

  wire [10*8-1:0] tx_header_icmp_trace;
  wire [40*8-1:0] tx_header_ipv6_trace;
  wire [64*8-1:0] tx_header_ethernet_ipv6_icmp_trace;

  wire [20*8-1:0] tx_header_ipv4_baseicmp;

  wire [ 4*8-1:0] tx_header_icmp4_echo;
  wire [38*8-1:0] tx_header_ethernet_ipv4_icmp_echo;

  wire [ 8*8-1:0] tx_header_icmp4_trace;
  wire [42*8-1:0] tx_header_ethernet_ipv4_icmp_trace;

  wire [15:0] tx_icmp_payload_length16bit;
  wire [15:0] tx_icmpv4_ip_total_length16bit;

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

  assign tx_header_ethernet_ipv4 = {
                                     i_ethernet_src,
                                     i_ethernet_dst,
                                     E_TYPE_IPV4
                                   };

  assign tx_header_ethernet_ipv6 = {
                                     i_ethernet_src,
                                     i_ethernet_dst,
                                     E_TYPE_IPV6
                                   };

  //----------------------------------------------------------------
  // ICMPv6 Neighbor Advertisement (rfc4861)
  //----------------------------------------------------------------

  assign tx_header_ethernet_na = {i_ethernet_src, i_ethernet_ns6src, E_TYPE_IPV6 };
  assign tx_header_ipv6_na = { IP_V6, IPV6_TC, IPV6_FL,
                                      16'h20, //Payload length is 32
                                      IP_PROTO_ICMPV6,
                                      8'hff, //Hop Limit is 255 (rfc4861)
                                      i_ip6_ns_target_address, i_ip6_src
                                    };
  assign tx_header_icmp_na = { ICMP_TYPE_V6_NEIGHBOR_ADVERTISEMENT,
                               8'h0, //code
                               16'h0000, //Zero checksum
                               32'h60_00_00_00, //Solicited, Override
                               i_ip6_ns_target_address,
                               8'h2, //OPTION: Target Link-Layer Address
                               8'h1, //rfc4861; 1 => 8 octets option length
                               i_ethernet_ns6src
                             };
  assign tx_header_ethernet_ipv6_icmp_na = { tx_header_ethernet_na, tx_header_ipv6_na, tx_header_icmp_na };

  //----------------------------------------------------------------
  // ICMPv6 Trace Route
  //----------------------------------------------------------------

  assign tx_icmp_payload_length16bit[15:ADDR_WIDTH+3] = 0;
  assign tx_icmp_payload_length16bit[ADDR_WIDTH+3-1:0] = tx_icmp_payload_length_reg;

  assign tx_header_ipv6_trace = { IP_V6, IPV6_TC, IPV6_FL,
                                   tx_icmp_payload_length16bit,
                                   IP_PROTO_ICMPV6,
                                   IPV6_HOPLIMIT,
                                   i_ip6_dst, i_ip6_src
                                 };
  assign tx_header_icmp_trace = { ICMP_TYPE_V6_DEST_UNREACHABLE, ICMP_CODE_V6_UNREACHABLE_PORT, 48'h0000_0000_0000,
                                   IP_V6, i_ip6_priority, i_ip6_flowlabel_msb
                                 };
  assign tx_header_ethernet_ipv6_icmp_trace = { tx_header_ethernet_ipv6, tx_header_ipv6_trace, tx_header_icmp_trace };

  //----------------------------------------------------------------
  // ICMPv4
  //----------------------------------------------------------------

  assign tx_icmpv4_ip_total_length16bit[15:ADDR_WIDTH+3] = 0;
  assign tx_icmpv4_ip_total_length16bit[ADDR_WIDTH+3-1:0] = tx_icmpv4_ip_total_length_reg;
  assign tx_header_ipv4_baseicmp = {
              IP_V4, 4'h5, IPV4_TOS, tx_icmpv4_ip_total_length16bit,
              16'h0000, IPV4_FLAGS, IPV4_FRAGMENT_OFFSET,
              IPV4_TTL, IP_PROTO_ICMPV4, tx_icmpv4_ip_checksum_reg,
              i_ip4_dst, i_ip4_src
            };

  //----------------------------------------------------------------
  // ICMPv4 Echo Reply
  //----------------------------------------------------------------

  assign tx_header_icmp4_echo = { ICMP_TYPE_V4_ECHO_REPLY, 8'h0 /* code */, 16'h0000 };
  assign tx_header_ethernet_ipv4_icmp_echo = { tx_header_ethernet_ipv4,
                                        tx_header_ipv4_baseicmp,
                                        tx_header_icmp4_echo };


  //----------------------------------------------------------------
  // ICMPv4 Trace Route
  //----------------------------------------------------------------

  assign tx_header_icmp4_trace = { ICMP_TYPE_V4_DEST_UNREACHABLE,
                                   ICMP_CODE_V4_UNREACHABLE_PORT,
                                   16'h0000, //checksum
                                   32'h0000_0000 //unused
                                  };
  assign tx_header_ethernet_ipv4_icmp_trace = { tx_header_ethernet_ipv4,
                                               tx_header_ipv4_baseicmp,
                                               tx_header_icmp4_trace };

  //----------------------------------------------------------------
  // ICMPv6 Echo Reply
  //----------------------------------------------------------------

  assign tx_header_ipv6_echo = { IP_V6, IPV6_TC, IPV6_FL,
                                 i_ip6_payload_length,
                                 IP_PROTO_ICMPV6,
                                 IPV6_HOPLIMIT,
                                 i_ip6_dst, i_ip6_src
                               };
  assign tx_header_icmp_echo = { ICMP_TYPE_V6_ECHO_REPLY, 8'h0 /* code */, 16'h0000 };
  assign tx_header_ethernet_ipv6_icmp_echo = { tx_header_ethernet_ipv6, tx_header_ipv6_echo, tx_header_icmp_echo };


  assign o_tx_from_rx = tx_from_rx;
  assign o_ap_addr    = ap_addr;
  assign o_ap_burst   = ap_burst;
  assign o_ap_rd      = ap_rd;
  assign o_tx_addr    = tx_address;
  assign o_tx_write_en = tx_write_en;
  assign o_tx_write_data = tx_write_data;
  assign o_tx_sum_en = tx_sum_en;
  assign o_tx_sum_bytes = tx_sum_bytes;
  assign o_tx_sum_reset = tx_sum_reset;
  assign o_tx_sum_reset_value = tx_sum_reset_value;

  assign o_responder_en = response_en_new;
  assign o_responder_data = response_data_new;
  assign o_responder_update_length = responder_update_length;
  assign o_responder_length_we = response_packet_total_length_we;
  assign o_responder_length_new = response_packet_total_length_new;

  assign o_icmp_idle       = icmp_state_reg == ICMP_S_IDLE;
  assign o_packet_drop     = icmp_state_reg == ICMP_S_DROP_PACKET;
  assign o_packet_transmit = icmp_state_reg == ICMP_S_TRANSMIT_PACKET;

  always @*
  begin : ipv4_calc_proc2
    reg [16*9-1:0] words;
    words = { tx_header_ipv4_baseicmp[20*8-1:10*8], tx_header_ipv4_baseicmp[8*8-1:0] };
     tx_icmpv4_ip_checksum_new = ipv4_csum( words );
  end

  always @*
  begin : tx_response
    response_en_new = 0;
    response_data_new = 0;
    response_done_new = 0;
    response_packet_total_length_we  = 0;
    response_packet_total_length_new = 0;

    tx_icmp_csum_bytes_we = 0;
    tx_icmp_csum_bytes_new = 0;
    tx_icmp_payload_length_we = 0;
    tx_icmp_payload_length_new = 0;
    tx_icmp_tmpblock_we = 0;
    tx_icmp_tmpblock_new = 0;
    tx_icmpv4_ip_total_length_we = 0;
    tx_icmpv4_ip_total_length_new = 0;

    tx_header_icmpv4_echo_index_we = 0;
    tx_header_icmpv4_echo_index_new = 0;
    tx_header_icmpv4_trace_index_we = 0;
    tx_header_icmpv4_trace_index_new = 0;
    tx_header_icmpv6_echo_index_we = 0;
    tx_header_icmpv6_echo_index_new = 0;
    tx_header_icmpv6ns_index_we = 0;
    tx_header_icmpv6ns_index_new = 0;
    tx_header_icmpv6_trace_index_we = 0;
    tx_header_icmpv6_trace_index_new = 0;

    if (i_process == 1'b0) begin
      tx_header_icmpv4_echo_index_we = 1;
      tx_header_icmpv4_echo_index_new = 4;
      tx_header_icmpv4_trace_index_we = 1;
      tx_header_icmpv4_trace_index_new = 5;
      tx_header_icmpv6_echo_index_we = 1;
      tx_header_icmpv6_echo_index_new = 7;
      tx_header_icmpv6ns_index_we = 1;
      tx_header_icmpv6ns_index_new = 10;
      tx_header_icmpv6_trace_index_we = 1;
      tx_header_icmpv6_trace_index_new = 7;
    end else begin
      case (icmp_state_reg)
        // ----- IPV6 Neighbor Discovery / Advertisement ----
        ICMP_S_V6_ND_INIT:
          begin
            response_packet_total_length_we    = 1;
            response_packet_total_length_new   = 86; //14 byte ethernet, 40 byte IPv6, 32 byte ICMPv6
            tx_icmp_payload_length_we  = 1;
            tx_icmp_payload_length_new = 32;
            tx_icmp_csum_bytes_we      = 1;
            tx_icmp_csum_bytes_new     = 16 + 16 //2 ipv6 addresses
                                       + tx_icmp_payload_length_new;
            tx_icmp_tmpblock_we = 1;
            tx_icmp_tmpblock_new = tx_header_ethernet_ipv6_icmp_na[
                                      (86-OFFSET_ETH_IPV6_ICMPV6_CSUM)*8-1-:64
                                   ];
          end
        ICMP_S_V6_ND_RESPOND:
          begin : emit_icmp_na
            reg [11*64-1:0] header;
            header = { tx_header_ethernet_ipv6_icmp_na, 16'h0000 };
            if (response_done_reg == 1'b0) begin
              tx_header_icmpv6ns_index_we = 1;
              tx_header_icmpv6ns_index_new = tx_header_icmpv6ns_index_reg - 1;
              response_en_new = 1;
              response_data_new = header[ tx_header_icmpv6ns_index_reg*64+:64 ];
              response_done_new = tx_header_icmpv6ns_index_reg == 0;
            end
          end
        // ----- IPV6 Ping (Echo Reply) ----
        ICMP_S_V6_ECHO_INIT:
          begin
            response_packet_total_length_we    = 1;
            response_packet_total_length_new   = i_memory_bound;
            tx_icmp_payload_length_we  = 1;
            tx_icmp_payload_length_new = i_memory_bound - ( HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV6 );
            tx_icmp_csum_bytes_we      = 1;
            tx_icmp_csum_bytes_new     = i_memory_bound - OFFSET_ETH_IPV6_SRCADDR;
            tx_icmp_tmpblock_we        = 1;
            tx_icmp_tmpblock_new       = { 16'h0000, i_icmp_echo_id, i_icmp_echo_seq, i_icmp_echo_d0};
          end
        ICMP_S_V6_ECHO_RESPOND:
          begin : emit_echo_response_v6
            reg [8*64-1:0] header;
            header = { tx_header_ethernet_ipv6_icmp_echo, 48'h0000_0000_0000 };
            if (response_done_reg == 1'b0) begin
              tx_header_icmpv6_echo_index_we = 1;
              tx_header_icmpv6_echo_index_new = tx_header_icmpv6_echo_index_reg - 1;
              response_en_new = 1;
              response_data_new = header[ tx_header_icmpv6_echo_index_reg*64+:64 ];
              response_done_new = tx_header_icmpv6_echo_index_reg == 0;
            end
          end
        // ----- IPV6 Trace Route (Port Unreachable) ----
        ICMP_S_V6_TRACE_INIT:
          begin
            if (i_ip6_payload_length > IPV6_MTU_MIN - HEADER_LENGTH_IPV6 - ICMP_V6_UNREACHABLE_INITIAL_BYTES) begin
              response_packet_total_length_we    = 1;
              response_packet_total_length_new   = IPV6_MTU_MIN + HEADER_LENGTH_ETHERNET;
              tx_icmp_payload_length_we  = 1;
              tx_icmp_payload_length_new = IPV6_MTU_MIN - HEADER_LENGTH_IPV6;
              tx_icmp_csum_bytes_we      = 1;
              tx_icmp_csum_bytes_new     = IPV6_MTU_MIN - 8 /* IPv6 not in csum */;
            end else begin
              response_packet_total_length_we    = 1;
              response_packet_total_length_new   = HEADER_LENGTH_IPV6 + ICMP_V6_UNREACHABLE_INITIAL_BYTES + i_memory_bound;
              tx_icmp_payload_length_we  = 1;
              tx_icmp_payload_length_new = HEADER_LENGTH_IPV6 + ICMP_V6_UNREACHABLE_INITIAL_BYTES + i_ip6_payload_length[ADDR_WIDTH+3-1:0];
              tx_icmp_csum_bytes_we      = 1;
              tx_icmp_csum_bytes_new     = response_packet_total_length_new - HEADER_LENGTH_ETHERNET - 8 /* IPv6 not in csum */;
            end
            tx_icmp_tmpblock_we = 1;
            tx_icmp_tmpblock_new = tx_header_ethernet_ipv6_icmp_trace[
                                      (64-OFFSET_ETH_IPV6_ICMPV6_CSUM)*8-1-:64
                                   ];
          end
        ICMP_S_V6_TRACE_RESPOND:
          begin : emit_trace_response
            reg [8*64-1:0] header;
            header = { tx_header_ethernet_ipv6_icmp_trace };
            if (response_done_reg == 1'b0) begin
              tx_header_icmpv6_trace_index_we = 1;
              tx_header_icmpv6_trace_index_new = tx_header_icmpv6_trace_index_reg - 1;
              response_en_new = 1;
              response_data_new = header[ tx_header_icmpv6_trace_index_reg*64+:64 ];
              response_done_new = tx_header_icmpv6_trace_index_reg == 0;
            end
          end
        // ----- IPV6 Update Checksum in temp block ----
        ICMP_S_V6_CSUM_WAIT:
          if (i_tx_sum_done) begin
            tx_icmp_tmpblock_we = 1;
            tx_icmp_tmpblock_new = { (~i_tx_sum), tx_icmp_tmpblock_reg[47:0] };
          end
        // ----- IPV4 Ping (Echo Reply) ----
        ICMP_S_V4_ECHO_INIT:
          begin
            response_packet_total_length_we       = 1;
            response_packet_total_length_new      = i_memory_bound;
            tx_icmpv4_ip_total_length_we  = 1;
            tx_icmpv4_ip_total_length_new = i_memory_bound - HEADER_LENGTH_ETHERNET;
            tx_icmp_csum_bytes_we         = 1;
            tx_icmp_csum_bytes_new        = i_memory_bound - OFFSET_ETH_IPV4_DATA;
            tx_icmp_tmpblock_we           = 1;
            tx_icmp_tmpblock_new          = tx_header_ethernet_ipv4_icmp_echo[63:0];
          end
        ICMP_S_V4_ECHO_RESPOND:
          begin : emit_echo_response_v4
            reg [5*64-1:0] header;
            header = { tx_header_ethernet_ipv4_icmp_echo, 16'h0000 };
            if (response_done_reg == 1'b0) begin
              tx_header_icmpv4_echo_index_we = 1;
              tx_header_icmpv4_echo_index_new = tx_header_icmpv4_echo_index_reg - 1;
              response_en_new = 1;
              response_data_new =  header[ tx_header_icmpv4_echo_index_reg*64+:64 ];
              response_done_new =  tx_header_icmpv4_echo_index_reg == 0;
            end
          end
        ICMP_S_V4_TRACE_INIT:
          begin
            response_packet_total_length_we       = 1;
            response_packet_total_length_new      = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV4 + ICMP_V4_UNREACHABLE_INITIAL_BYTES + ICMPV4_BYTES_TRACEROUTE;
            tx_icmpv4_ip_total_length_we  = 1;
            tx_icmpv4_ip_total_length_new = HEADER_LENGTH_IPV4 + ICMP_V4_UNREACHABLE_INITIAL_BYTES + ICMPV4_BYTES_TRACEROUTE;
            tx_icmp_csum_bytes_we         = 1;
            tx_icmp_csum_bytes_new        = ICMP_V4_UNREACHABLE_INITIAL_BYTES + ICMPV4_BYTES_TRACEROUTE;
            tx_icmp_tmpblock_we           = 1;
            tx_icmp_tmpblock_new          = tx_header_ethernet_ipv4_icmp_trace[95:32];
          end
        ICMP_S_V4_TRACE_RESPOND:
          begin : emit_trace_response_v4
            reg [6*64-1:0] header;
            header = { tx_header_ethernet_ipv4_icmp_trace, 48'h0000_0000_0000 };
            if (response_done_reg == 1'b0) begin
              tx_header_icmpv4_trace_index_we = 1;
              tx_header_icmpv4_trace_index_new = tx_header_icmpv4_trace_index_reg - 1;
              response_en_new = 1;
              response_data_new = header[ tx_header_icmpv4_trace_index_reg*64+:64 ];
              response_done_new = tx_header_icmpv4_trace_index_reg == 0;
            end
          end
        ICMP_S_V4_CSUM_WAIT:
          if (i_tx_sum_done) begin
            tx_icmp_tmpblock_we  = 1;
            tx_icmp_tmpblock_new = { tx_icmp_tmpblock_reg[63:16], (~i_tx_sum) };
          end
        default: ;
      endcase
    end
  end

  always @*
  begin
    ap_addr = 0;
    ap_burst = 0;
    ap_rd = 0;
    responder_update_length = 0;
    tx_address = 0;
    tx_write_en = 0;
    tx_write_data = 0;
    tx_from_rx = 0;
    tx_sum_en = 0;
    tx_sum_bytes = 0;
    tx_sum_reset = 0;
    tx_sum_reset_value = 0;
    if (i_process) begin
      case (icmp_state_reg)
        ICMP_S_V6_ECHO_COPY:
          begin
            ap_addr = OFFSET_ICMP_V6_ECHO_COPY;
            ap_burst = i_memory_bound - OFFSET_ICMP_V6_ECHO_COPY;
            ap_rd = 1;
            tx_address = OFFSET_ICMP_V6_ECHO_COPY;
            tx_from_rx = 1;
          end
        ICMP_S_V6_TRACE_COPY:
          begin
            ap_addr = 14; //Start of IP packet
            ap_burst = tx_icmp_payload_length_reg - ICMP_V6_UNREACHABLE_INITIAL_BYTES;
            ap_rd = 'b1;
            tx_address = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV6 + ICMP_V6_UNREACHABLE_INITIAL_BYTES;
            tx_from_rx = 1;
          end
        ICMP_S_V6_UPDATE_LENGTH:
          begin
            responder_update_length = 1;
          end
        ICMP_S_V6_CSUM_RESET:
          begin : icmpv6_csum_reset
            reg [15:0] len;
            len = 0;
            len[ADDR_WIDTH+3-1:0] = tx_icmp_payload_length_reg;
            tx_sum_reset = 1;
            tx_sum_reset_value = {8'h00, IP_PROTO_ICMPV6 } + len;
          //$display("%s:%0d: csum_reset: %h len %h (%0d)", `__FILE__, `__LINE__, tx_sum_reset_value, len, len);
          end
        ICMP_S_V6_CSUM_CALC:
          begin
            tx_address = OFFSET_ETH_IPV6_SRCADDR;
            tx_sum_en = 1;
            tx_sum_bytes = tx_icmp_csum_bytes_reg;
          //$display("%s:%0d: csum bytes %h (%0d)", `__FILE__, `__LINE__, tx_sum_bytes, tx_sum_bytes);
          end
        ICMP_S_V6_CSUM_UPDATE:
          begin
            tx_address = OFFSET_ETH_IPV6_ICMPV6_CSUM;
            tx_write_en = 1;
            tx_write_data = tx_icmp_tmpblock_reg;
          end
        ICMP_S_V4_ECHO_COPY:
          begin
            ap_addr  = OFFSET_ICMP_V4_ECHO_COPY;
            ap_burst = i_memory_bound - OFFSET_ICMP_V4_ECHO_COPY;
            ap_rd = 'b1;
            tx_address = OFFSET_ICMP_V4_ECHO_COPY;
            tx_from_rx = 1;
          end
        ICMP_S_V4_TRACE_COPY:
          begin
           ap_addr = 14; //Start of IP packet
           ap_burst = ICMPV4_BYTES_TRACEROUTE;
           ap_rd = 'b1;
           tx_address = HEADER_LENGTH_ETHERNET + HEADER_LENGTH_IPV4 + ICMP_V4_UNREACHABLE_INITIAL_BYTES;
           tx_from_rx = 1;
          end
        ICMP_S_V4_UPDATE_LENGTH:
          begin
            responder_update_length = 1;
          end
        ICMP_S_V4_CSUM_RESET:
          begin
            tx_sum_reset = 1;
            tx_sum_reset_value = 0;
          end
        ICMP_S_V4_CSUM_CALC:
          begin
            tx_address = OFFSET_ETH_IPV4_DATA;
            tx_sum_en = 1;
            tx_sum_bytes = tx_icmp_csum_bytes_reg;
          //$display("%s:%0d: csum bytes %h (%0d)", `__FILE__, `__LINE__, tx_sum_bytes, tx_sum_bytes);
           end
        ICMP_S_V4_CSUM_UPDATE:
          begin
          //$display("%s:%0d: tx_icmp_tmpblock_reg: %h", `__FILE__, `__LINE__, tx_icmp_tmpblock_reg);
            tx_address = OFFSET_ETH_IPV4_ICMPV4_CSUM - 6;
            tx_write_en = 1;
            tx_write_data = tx_icmp_tmpblock_reg;
            //$display("%s:%0d: TX[ %0d (dec) ] = %h", `__FILE__, `__LINE__, tx_address, tx_write_data);
          end
        default: ;
      endcase
    end
  end


  //----------------------------------------------------------------
  // Finite State Machine - ICMP
  // Overall functionallity control
  //----------------------------------------------------------------

  always @*
  begin : fsm_icmp_
    icmp_state_we  = 'b0;
    icmp_state_new = ICMP_S_IDLE;

    case (icmp_state_reg)
      ICMP_S_IDLE:
        if (i_process) begin
          if (i_pd_ip6_ns) begin
            icmp_state_we  = 'b1;
            icmp_state_new = ICMP_S_V6_ND_INIT;
          end else if (i_pd_ip6_echo) begin
            icmp_state_we  = 'b1;
            icmp_state_new = ICMP_S_V6_ECHO_INIT;
          end else if (i_pd_ip6_trace) begin
            icmp_state_we  = 'b1;
            icmp_state_new = ICMP_S_V6_TRACE_INIT;
          end else if (i_pd_ip4_echo) begin
            icmp_state_we  = 'b1;
            icmp_state_new = ICMP_S_V4_ECHO_INIT;
          end else if (i_pd_ip4_trace) begin
            icmp_state_we  = 'b1;
            icmp_state_new = ICMP_S_V4_TRACE_INIT;
          end else begin
            icmp_state_we  = 'b1;
            icmp_state_new = ICMP_S_DROP_PACKET;
          end
        end
      ICMP_S_V6_ND_INIT:
        if (i_match_addr_ip6_ns) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_ND_RESPOND;
        end else begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_DROP_PACKET;
        end
      ICMP_S_V6_ND_RESPOND:
        if (response_done_reg) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_UPDATE_LENGTH;
        end
      ICMP_S_V6_ECHO_INIT:
        if (i_match_addr_ethernet && i_match_addr_ip6) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_ECHO_RESPOND;
        end else begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_DROP_PACKET;
        end
      ICMP_S_V6_ECHO_RESPOND:
        if (response_done_reg) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_ECHO_COPY;
        end
      ICMP_S_V6_ECHO_COPY:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_ECHO_COPY_D;
        end
      ICMP_S_V6_ECHO_COPY_D:
        if (i_copy_done) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_ECHO_COPY_D2;
        end
      ICMP_S_V6_ECHO_COPY_D2:
        //TXBUF memory controller require wait cycles delay
        //between different unaligned burst writes.
        if (i_tx_busy == 'b0) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_UPDATE_LENGTH;
        end
      ICMP_S_V6_TRACE_INIT:
        if (i_match_addr_ethernet && i_match_addr_ip6) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_TRACE_RESPOND;
        end else begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_DROP_PACKET;
        end
      ICMP_S_V6_TRACE_RESPOND:
        if (response_done_reg) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_TRACE_COPY;
        end
      ICMP_S_V6_TRACE_COPY:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_TRACE_COPY_D;
        end
      ICMP_S_V6_TRACE_COPY_D:
        if (i_copy_done) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_UPDATE_LENGTH;
        end
      ICMP_S_V6_UPDATE_LENGTH:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_CSUM_RESET;
        end
      ICMP_S_V6_CSUM_RESET:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_CSUM_CALC;
        end
      ICMP_S_V6_CSUM_CALC:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_CSUM_WAIT;
        end
      ICMP_S_V6_CSUM_WAIT:
        if (i_tx_sum_done) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_CSUM_UPDATE;
        end
      ICMP_S_V6_CSUM_UPDATE:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V6_CSUM_UPDATE_D;
        end
      ICMP_S_V6_CSUM_UPDATE_D:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_TRANSMIT_PACKET;
        end
      ICMP_S_V4_ECHO_INIT:
        if (i_match_addr_ethernet && i_match_addr_ip4) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_ECHO_RESPOND;
        end else begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_DROP_PACKET;
        end
      ICMP_S_V4_ECHO_RESPOND:
        if (response_done_reg) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_ECHO_COPY;
        end
      ICMP_S_V4_ECHO_COPY:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_ECHO_COPY_D;
        end
      ICMP_S_V4_ECHO_COPY_D:
        if (i_copy_done) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_ECHO_COPY_D2;
        end
      ICMP_S_V4_ECHO_COPY_D2:
        //TXBUF memory controller require wait cycles delay
        //between different unaligned burst writes.
        if (i_tx_busy == 'b0) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_UPDATE_LENGTH;
        end
      ICMP_S_V4_TRACE_INIT:
        if (i_match_addr_ethernet && i_match_addr_ip4) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_TRACE_RESPOND;
        end else begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_DROP_PACKET;
        end
      ICMP_S_V4_TRACE_RESPOND:
        if (response_done_reg) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_TRACE_COPY;
        end
      ICMP_S_V4_TRACE_COPY:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_TRACE_COPY_D;
        end
      ICMP_S_V4_TRACE_COPY_D:
        if (i_copy_done) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_UPDATE_LENGTH;
        end
      ICMP_S_V4_UPDATE_LENGTH:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_CSUM_RESET;
        end
      ICMP_S_V4_CSUM_RESET:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_CSUM_CALC;
        end
      ICMP_S_V4_CSUM_CALC:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_CSUM_WAIT;
        end
      ICMP_S_V4_CSUM_WAIT:
        if (i_tx_sum_done) begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_CSUM_UPDATE;
        end
      ICMP_S_V4_CSUM_UPDATE:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_V4_CSUM_UPDATE_D;
        end
      ICMP_S_V4_CSUM_UPDATE_D:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_TRANSMIT_PACKET;
        end
      ICMP_S_TRANSMIT_PACKET:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_IDLE;
        end
      ICMP_S_DROP_PACKET:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_IDLE;
        end
      default:
        begin
          icmp_state_we  = 'b1;
          icmp_state_new = ICMP_S_DROP_PACKET;
        end
    endcase
  end

  always @(posedge i_clk or posedge i_areset)
  begin : reg_up
    if (i_areset) begin
      icmp_state_reg  <= 0;
      response_done_reg <= 0;
      tx_header_icmpv4_echo_index_reg <= 0;
      tx_header_icmpv4_trace_index_reg <= 0;

      tx_header_icmpv6_echo_index_reg <= 0;
      tx_header_icmpv6ns_index_reg <= 0;
      tx_header_icmpv6_trace_index_reg <= 0;

      tx_icmp_payload_length_reg <= 0;
      tx_icmp_csum_bytes_reg     <= 0;
      tx_icmp_tmpblock_reg       <= 0;

      tx_icmpv4_ip_checksum_reg <= 0;
      tx_icmpv4_ip_total_length_reg <= 0;

    end else begin
      if (icmp_state_we)
        icmp_state_reg <= icmp_state_new;

      response_done_reg <= response_done_new;

      if (tx_icmp_csum_bytes_we)
        tx_icmp_csum_bytes_reg <= tx_icmp_csum_bytes_new;

      if (tx_icmp_payload_length_we)
        tx_icmp_payload_length_reg <= tx_icmp_payload_length_new;

      if (tx_header_icmpv4_echo_index_we)
        tx_header_icmpv4_echo_index_reg <= tx_header_icmpv4_echo_index_new;

      if (tx_header_icmpv4_trace_index_we)
        tx_header_icmpv4_trace_index_reg <= tx_header_icmpv4_trace_index_new;

      if (tx_header_icmpv6_echo_index_we)
        tx_header_icmpv6_echo_index_reg <= tx_header_icmpv6_echo_index_new;

      if (tx_header_icmpv6ns_index_we)
        tx_header_icmpv6ns_index_reg <= tx_header_icmpv6ns_index_new;

      if (tx_header_icmpv6_trace_index_we)
        tx_header_icmpv6_trace_index_reg <= tx_header_icmpv6_trace_index_new;

      if (tx_icmp_tmpblock_we)
        tx_icmp_tmpblock_reg <= tx_icmp_tmpblock_new;;

      if (tx_icmpv4_ip_total_length_we)
        tx_icmpv4_ip_total_length_reg <= tx_icmpv4_ip_total_length_new;

      tx_icmpv4_ip_checksum_reg <= tx_icmpv4_ip_checksum_new;

    end
  end

endmodule
