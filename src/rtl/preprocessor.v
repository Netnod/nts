//======================================================================
//
// preprocessor.v
// --------------
// Packet preprocessor.
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

module preprocessor (
  input  wire        i_clk,
  input  wire        i_areset,

  input  wire  [7:0] i_rx_data_valid,
  input  wire [63:0] i_rx_data,
  input  wire        i_rx_bad_frame,
  input  wire        i_rx_good_frame,

  output wire [63:0] o_rx_data_be,
  output wire  [3:0] o_rx_valid4bit,
  output wire        o_packet_nts,
  output wire        o_packet_other,
  output wire        o_packet_drop,
  output wire        o_ethernet_good,
  output wire        o_ethernet_bad,
  output wire        o_sof
);

  //----------------------------------------------------------------
  // Local parameters (constants)
  //----------------------------------------------------------------

  localparam [15:0] E_TYPE_IPV4 =  16'h08_00;
  localparam [15:0] E_TYPE_IPV6 =  16'h86_DD;

  localparam  [2:0] NTP_MODE3_CLIENT = 3'h3;

  localparam  [7:0] IP_PROTO_UDP    = 8'h11; //17

  localparam UDP_LENGTH_NTP_VANILLA = 8      // UDP Header
                                    + 6 * 8; // NTP Payload


  //----------------------------------------------------------------
  // Registers
  //----------------------------------------------------------------

  reg [70:0] input0_reg;
  reg [70:0] input1_reg;
  reg [70:0] input2_reg;
  reg [70:0] input3_reg;
  reg [70:0] input4_reg;
  reg [70:0] input5_reg;
  reg [70:0] input6_reg;
  reg [70:0] input7_reg;

  reg [63:0] out_rx_data_be_reg;
  reg  [3:0] out_rx_valid4bit_reg;
  reg        out_packet_nts_reg;
  reg        out_packet_other_reg;
  reg        out_packet_drop_reg;
  reg        out_ethernet_good_reg;
  reg        out_ethernet_bad_reg;
  reg        out_sof_reg;

  //----------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------

  wire        d_sof;
  wire        d_bad;
  wire        d_good;
  wire  [3:0] d_valid4bits;
  wire [63:0] d_data0;

  wire [15:0] d_ether_proto;
  wire  [3:0] d_ip_version;

  wire  [3:0] d_ip4_ihl;
  wire [15:0] d_ip4_total_length;
  wire        d_ip4_flags_mf;
  wire [12:0] d_ip4_fragment_offs;
  wire  [7:0] d_ip4_protocol;
  wire [15:0] d_ip4_udp_port_dst;
  wire  [2:0] d_ip4_ntp_mode;

  wire [15:0] d_ip6_payload_length;
  wire  [7:0] d_ip6_next;
  wire [15:0] d_ip6_udp_port_dst;
  wire  [2:0] d_ip6_ntp_mode;

  reg decode_is_nts4;
  reg decode_is_nts6;

  wire decode_is_nts;
  wire decode_is_other;

  reg decode_bad_packet4;
  reg decode_bad_packet6;

  reg  detect_start_of_frame;

  reg [63:0] mac_rx_corrected;

  reg [7:0] previous_rx_data_valid;

  reg [3:0] rx_data_valid_4bit;

  //----------------------------------------------------------------
  // Wire assignments
  //----------------------------------------------------------------

  assign { d_sof, d_bad, d_good, d_valid4bits, d_data0 } = input0_reg;

  assign d_ether_proto        = input1_reg[31:16];

  assign d_ip_version         = input1_reg[15:12];

  assign d_ip4_ihl            = input1_reg[11:8];
  assign d_ip4_total_length   = input2_reg[63:48];
//assign d_ip4_identification = input2_reg[47:32];
//assign d_ip4_flags_reserved = input2_reg[31];
//assign d_ip4_flags_df       = input2_reg|30];
  assign d_ip4_flags_mf       = input2_reg[29];
  assign d_ip4_fragment_offs  = input2_reg[28:16];
//assign d_ip4_ttl            = input2_reg[15:8];
  assign d_ip4_protocol       = input2_reg[7:0];
  assign d_ip4_udp_port_dst   = input4_reg[31:16];
//assign d_ip4_udp_len        = input4_reg[15:0];
//assign d_ip4_udp_csum       = input5_reg[63:48];
//assign d_ip4_ntp_leap       = input5_reg[47:46];
//assign d_ip4_ntp_version    = input5_reg[45:43];
  assign d_ip4_ntp_mode       = input5_reg[42:40];

  assign d_ip6_payload_length = input2_reg[47:32];
  assign d_ip6_next           = input2_reg[31:24];
  assign d_ip6_udp_port_dst   = input7_reg[63:48];
//assign d_ip6_udp_len        = input7_reg[47:32];
//assign d_ip6_udp_csum       = input7_reg[31:16];
//assign d_ip6_ntp_leap       = input7_reg[15:14];
//assign d_ip6_ntp_version    = input7_reg[13:11];
  assign d_ip6_ntp_mode       = input7_reg[10:8];

  assign decode_is_nts   = d_sof & ( decode_is_nts6 | decode_is_nts4 );
  assign decode_is_other = d_sof & ( !decode_is_nts6 & !decode_is_nts4 );

  assign o_rx_data_be    = out_rx_data_be_reg;
  assign o_rx_valid4bit  = out_rx_valid4bit_reg;
  assign o_packet_nts    = out_packet_nts_reg;
  assign o_packet_other  = out_packet_other_reg;
  assign o_packet_drop   = out_packet_drop_reg;
  assign o_ethernet_good = out_ethernet_good_reg;
  assign o_ethernet_bad  = out_ethernet_bad_reg;
  assign o_sof           = out_sof_reg;

  //----------------------------------------------------------------
  // MAC RX Data/DataValid pre-processor
  //
  //  - Fix byte order of last word to fit rest of message.
  //    (reduces complexity in rest of design)
  //
  //  - Increments byte counters
  //
  //----------------------------------------------------------------

  function [63:0] mac_byte_reverse( input [63:0] rxd, input [7:0] rxv );
  begin : reverse
    reg [63:0] out;
    out[56+:8] = rxv[0] ? rxd[0+:8]  : 8'h00;
    out[48+:8] = rxv[1] ? rxd[8+:8]  : 8'h00;
    out[40+:8] = rxv[2] ? rxd[16+:8] : 8'h00;
    out[32+:8] = rxv[3] ? rxd[24+:8] : 8'h00;
    out[24+:8] = rxv[4] ? rxd[32+:8] : 8'h00;
    out[16+:8] = rxv[5] ? rxd[40+:8] : 8'h00;
    out[8+:8]  = rxv[6] ? rxd[48+:8] : 8'h00;
    out[0+:8]  = rxv[7] ? rxd[56+:8] : 8'h00;
    mac_byte_reverse = out;
  end
  endfunction

  //----------------------------------------------------------------
  // mac_rx_data_processor - give us Big Endian and 4bit data valid
  //----------------------------------------------------------------

  always @*
  begin : mac_rx_data_processor
    reg [3:0] bytes;
    bytes = 0;

    mac_rx_corrected = mac_byte_reverse( i_rx_data, i_rx_data_valid );

    case (i_rx_data_valid)
      8'b1111_1111: bytes = 8;
      8'b0111_1111: bytes = 7;
      8'b0011_1111: bytes = 6;
      8'b0001_1111: bytes = 5;
      8'b0000_1111: bytes = 4;
      8'b0000_0111: bytes = 3;
      8'b0000_0011: bytes = 2;
      8'b0000_0001: bytes = 1;
      8'b0000_0000: bytes = 0;
      default: ;
    endcase

    rx_data_valid_4bit = bytes;
  end

  //----------------------------------------------------------------
  // Start of Frame Detector
  //----------------------------------------------------------------

  always @*
  begin : sof_detector
    reg [15:0] rx_valid;
    rx_valid = {previous_rx_data_valid, i_rx_data_valid};
    detect_start_of_frame = 0;
    if ( 16'h00FF == rx_valid) begin
      detect_start_of_frame = 1;
    end
  end

  //----------------------------------------------------------------
  // IPV4 Decoder
  //----------------------------------------------------------------

  always @*
  begin : decoder_is_ipv4
    reg port_is_nts;
    reg length_is_nts;

    decode_is_nts4 = 0;
    decode_bad_packet4 = 0;

    case (d_ip4_udp_port_dst)
      123: port_is_nts = 1;
      4123: port_is_nts = 1;
      default: port_is_nts = 0;
    endcase

    case (d_ip4_total_length)
      20 + UDP_LENGTH_NTP_VANILLA: length_is_nts = 1; //NTS engines processing NTP
      20 + UDP_LENGTH_NTP_VANILLA + 4 + 16: length_is_nts = 0;
      20 + UDP_LENGTH_NTP_VANILLA + 4 + 20: length_is_nts = 0;
      default: length_is_nts = 1;
    endcase

    if (d_ether_proto == E_TYPE_IPV4) begin
      if (d_ip_version == 4) begin
        if (d_ip4_ihl == 5) begin
          if (d_ip4_flags_mf == 1'b0) begin
            if (d_ip4_fragment_offs == 13'h0) begin
              if (d_ip4_protocol == IP_PROTO_UDP) begin
                if (port_is_nts) begin
                  if (d_ip4_ntp_mode != NTP_MODE3_CLIENT) begin
                    decode_bad_packet4 = 1;
                  end else if (length_is_nts) begin
                    decode_is_nts4 = 1;
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  //----------------------------------------------------------------
  // IPV6 Decoder
  //----------------------------------------------------------------

  always @*
  begin : decoder_is_ipv6
    reg port_is_nts;
    reg length_is_nts;

    decode_is_nts6 = 0;
    decode_bad_packet6 = 0;

    case (d_ip6_udp_port_dst)
      123: port_is_nts = 1;
      4123: port_is_nts = 1;
      default: port_is_nts = 0;
    endcase

    case (d_ip6_payload_length)
      UDP_LENGTH_NTP_VANILLA: length_is_nts = 1; //NTS engines processing NTP
      UDP_LENGTH_NTP_VANILLA + 4 + 16: length_is_nts = 0;
      UDP_LENGTH_NTP_VANILLA + 4 + 20: length_is_nts = 0;
      default: length_is_nts = 1;
    endcase

    if (d_ether_proto == E_TYPE_IPV6) begin
      if (d_ip_version == 6) begin
        if (d_ip6_next == IP_PROTO_UDP) begin
          if (port_is_nts) begin
            if (d_ip6_ntp_mode != NTP_MODE3_CLIENT) begin
              decode_bad_packet6 = 1;
            end else if (length_is_nts) begin
              decode_is_nts6 = 1;
            end
          end
        end
      end
    end
  end


  //----------------------------------------------------------------
  // Register Update
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin

      input0_reg <= 0;
      input1_reg <= 0;
      input2_reg <= 0;
      input3_reg <= 0;
      input4_reg <= 0;
      input5_reg <= 0;
      input6_reg <= 0;
      input7_reg <= 0;

      out_rx_data_be_reg    <= 0;
      out_rx_valid4bit_reg  <= 0;
      out_packet_nts_reg    <= 0;
      out_packet_other_reg  <= 0;
      out_packet_drop_reg   <= 0;
      out_ethernet_good_reg <= 0;
      out_ethernet_bad_reg  <= 0;
      out_sof_reg           <= 0;

      previous_rx_data_valid <= 8'hFF; // Must not be zero as 00FF used to detect start of frame
    end else begin

      input0_reg <= input1_reg;
      input1_reg <= input2_reg;
      input2_reg <= input3_reg;
      input3_reg <= input4_reg;
      input4_reg <= input5_reg;
      input5_reg <= input6_reg;
      input6_reg <= input7_reg;
      input7_reg <= { detect_start_of_frame, i_rx_bad_frame, i_rx_good_frame, rx_data_valid_4bit, mac_rx_corrected };

      out_rx_data_be_reg    <= d_data0;
      out_rx_valid4bit_reg  <= d_valid4bits;
      out_packet_nts_reg    <= decode_is_nts;
      out_packet_other_reg  <= decode_is_other;
      out_packet_drop_reg   <= decode_bad_packet4 | decode_bad_packet6;
      out_ethernet_good_reg <= d_good;
      out_ethernet_bad_reg  <= d_bad;
      out_sof_reg           <= d_sof;

      //----------------------------------------------------------------
      // Start of Frame Detector (previous MAC RX DV sampler)
      //----------------------------------------------------------------
      previous_rx_data_valid <= i_rx_data_valid;
    end
  end

endmodule
