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

module nts_ip #(
  parameter ADDR_WIDTH = 10,
  parameter IP_OPCODE_WIDTH = 4
) (
  input  wire                       i_areset, // async reset
  input  wire                       i_clk,
  input  wire                       i_clear,
  input  wire                       i_process,
  input  wire                 [7:0] i_last_word_data_valid,
  input  wire                [63:0] i_data,
  input  wire [IP_OPCODE_WIDTH-1:0] i_read_opcode,
  output wire                       o_detect_ipv4,
  output wire                       o_detect_ipv4_bad,
  output wire                [31:0] o_read_data
);

  localparam [IP_OPCODE_WIDTH-1:0] OPCODE_GET_OFFSET_UDP_DATA = 'b0;
  localparam [IP_OPCODE_WIDTH-1:0] OPCODE_GET_LENGTH_UDP      = 'b1;

  reg             [31:0] previous_i_data; //We receive i_data one cycle before process signal
                                          //We currently only use 32 bit LSB, so remove MSB for
                                          //now just to make synthesis warnings go away
  reg   [ADDR_WIDTH-1:0] addr;
  reg             [15:0] ethernet_protocol;
  reg              [3:0] ip_version;
  reg              [3:0] ip4_ihl;
  reg             [15:0] udp_length;
  reg [ADDR_WIDTH+3-1:0] offset_udp_data;
  reg             [31:0] read_data;
  wire                   detect_ipv4;
  wire                   detect_ipv4_bad;

  localparam  [15:0] E_TYPE_IPV4     =  16'h08_00;
  localparam   [3:0] IP_V4           =  4'h4;

  assign detect_ipv4     = (ethernet_protocol == E_TYPE_IPV4) && (ip_version == IP_V4);
  assign detect_ipv4_bad = detect_ipv4 && ip4_ihl != 5;

  assign o_detect_ipv4     = detect_ipv4;
  assign o_detect_ipv4_bad = detect_ipv4_bad;
  assign o_read_data       = read_data;

  always @*
  begin
    read_data = 32'b0;
    case (i_read_opcode)
      OPCODE_GET_OFFSET_UDP_DATA: read_data[ADDR_WIDTH+3-1:0] = offset_udp_data;
      OPCODE_GET_LENGTH_UDP:      read_data[15:0]             = udp_length;
    default: ;
    endcase
  end

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin
      addr              <= 'b0;
      ethernet_protocol <= 'b0;
      ip_version        <= 'b0;
      ip4_ihl           <= 'b0;
      udp_length        <= 'b0;
      offset_udp_data   <= 'b0;
      previous_i_data   <= 'b0;
    end else begin
      previous_i_data   <= i_data[31:0];
      if (i_clear) begin
         addr              <= 'b0;
         ethernet_protocol <= 'b0;
         ip_version        <= 'b0;
         ip4_ihl           <= 'b0;
         udp_length        <= 'b0;
         offset_udp_data   <= 'b0;
      end else if (i_process) begin
        addr               <= addr+1;
        //0: 2c768aadf786902b [63:16] e_dst [15:0] e_src
        //1: 3431273408004500 [63:32] e_src [31:16] eth_proto [15:12] ip_version
        //2: 004c000040004011
        //3: 1573c0a80101a0b1

        if (addr == 1) begin
          ethernet_protocol <= previous_i_data[31:16];
          ip_version        <= previous_i_data[15:12];
          ip4_ihl           <= previous_i_data[11:8];
        end else if (detect_ipv4 && ip4_ihl == 5) begin
          offset_udp_data[ADDR_WIDTH+3-1:3] <= 5;
          offset_udp_data[2:0]              <= 2;

/*
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |Version|  IHL  |Type of Service|          Total Length         |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |         Identification        |Flags|      Fragment Offset    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |  Time to Live |    Protocol   |         Header Checksum       |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                       Source Address                          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                    Destination Address                        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                    Options                    |    Padding    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
*/
          if (addr == 2) begin
            //$display("%s:%0d ip_total_length    %0d", `__FILE__, `__LINE__, i_data[63:48]);
            //$display("%s:%0d ip_id              %0h", `__FILE__, `__LINE__, i_data[47:32]);
            //$display("%s:%0d ip_flags           %0h", `__FILE__, `__LINE__, i_data[31:29]);
            //$display("%s:%0d ip_fragment_offset %0d", `__FILE__, `__LINE__, i_data[28:16]);
            //$display("%s:%0d ip_ttl             %0d", `__FILE__, `__LINE__, i_data[15:8]);
            //$display("%s:%0d ip_protocol        %0d", `__FILE__, `__LINE__, i_data[7:0]);
          end else if (addr == 3) begin
            //$display("%s:%0d ip_checksum        %0h", `__FILE__, `__LINE__, i_data[63:48]);
            //$display("%s:%0d ip_source          %0h", `__FILE__, `__LINE__, i_data[47:16]);
            //$display("%s:%0d ip_dst (part1)     %0h", `__FILE__, `__LINE__, i_data[15:0]);
          end else if (addr == 4) begin
            //ihl=5 => 160 bits. 160/64
	    //16 bits of IPv4 header in addr=1
            //64 bits of IPv4 header in addr=2
            //64 bits of IPv4 header in addr=3
            //16 bits of IPv4 header remaining
/*
                 0      7 8     15 16    23 24    31
                 +--------+--------+--------+--------+
                 |     Source      |   Destination   |
                 |      Port       |      Port       |
                 +--------+--------+--------+--------+
                 |                 |                 |
                 |     Length      |    Checksum     |
                 +--------+--------+--------+--------+
                 |
                 |          data octets ...
                 +---------------- ...

*/
            //$display("%s:%0d ip_dst (part2)     %0h", `__FILE__, `__LINE__, i_data[63:48]);
            //$display("%s:%0d udp_src            %0h", `__FILE__, `__LINE__, i_data[47:32]);
            //$display("%s:%0d udp_dst            %0h", `__FILE__, `__LINE__, i_data[31:16]);
            udp_length   <= previous_i_data[15:0];
            //$display("%s:%0d udp_length         %0d", `__FILE__, `__LINE__, i_data[15:0]);
          end else if (addr == 5) begin
            //$display("%s:%0d udp_checksum       %h", `__FILE__, `__LINE__, i_data[63:48]);
            //$display("%s:%0d ntp first row      %h", `__FILE__, `__LINE__, i_data[47:16]);
            //$display("%s:%0d ntp root delay msb %h", `__FILE__, `__LINE__, i_data[15:0]);
/*
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |LI | VN  |Mode |    Stratum     |     Poll      |  Precision   |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                         Root Delay                            |
*/

          end else if (addr == 6) begin
            //$display("%s:%0d ntp root delay lsb %h", `__FILE__, `__LINE__, i_data[63:48]);
            //$display("%s:%0d ntp root disper.   %h", `__FILE__, `__LINE__, i_data[47:16]);
            //$display("%s:%0d ntp reference msb  %h", `__FILE__, `__LINE__, i_data[15:0]);
/*
      |                         Root Delay                            |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                         Root Dispersion                       |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                          Reference ID                         |
*/
          end else if (addr == 7) begin
            //$display("%s:%0d ntp reference lsb  %h", `__FILE__, `__LINE__, i_data[63:48]);
            //$display("%s:%0d ntp reftimstmp msb %h", `__FILE__, `__LINE__, i_data[47:0]);
/*
      |                          Reference ID                         |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                                                               |
      +                     Reference Timestamp (64)                  +
      |                                                               |
*/

          end else if (addr == 8) begin
            //$display("%s:%0d ntp reftimstmp lsb %h", `__FILE__, `__LINE__, i_data[63:48]);
            //$display("%s:%0d ntp origimstmp msb %h", `__FILE__, `__LINE__, i_data[47:0]);
/*
      |                                                               |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                                                               |
      +                      Origin Timestamp (64)                    +
*/
          end else if (addr == 9) begin
            //$display("%s:%0d ntp origimstmp lsb  %h", `__FILE__, `__LINE__, i_data[63:48]);
/*
      +                      Receive Timestamp (64)                   +
*/
          end else if (addr == 10) begin
            //$display("%s:%0d ntp rec.mstmp lsb  %h", `__FILE__, `__LINE__, i_data[63:48]);

          end else if (addr == 11) begin
            //$display("%s:%0d ntp trans.mstmp lsb  %h", `__FILE__, `__LINE__, i_data[63:48]);
            //$display("%s:%0d debug: %h", `__FILE__, `__LINE__, i_data[47:32]);
            //$display("%s:%0d debug: %h", `__FILE__, `__LINE__, i_data[31:16]);
          end
        end
      end
    end
  end
endmodule
