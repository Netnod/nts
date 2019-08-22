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
  parameter ADDR_WIDTH = 10
) (
  input  wire                  i_areset, // async reset
  input  wire                  i_clk,
  input  wire                  i_clear,
  input  wire                  i_process,
  input  wire [7:0]            i_last_word_data_valid,
  input  wire [63:0]           i_data,
  output wire                  o_detect_ipv4,
  output wire                  o_detect_ipv4_bad
);

  reg [ADDR_WIDTH-1:0] addr;
  reg           [15:0] ethernet_protocol;
  reg            [3:0] ip_version;
  reg            [3:0] ip4_ihl;
  reg           [15:0] udp_length;
  wire                 detect_ipv4;
  wire                 detect_ipv4_bad;

  localparam  [15:0] E_TYPE_IPV4     =  16'h08_00;
  localparam   [3:0] IP_V4           =  4'h04;

  assign detect_ipv4     = (ethernet_protocol == E_TYPE_IPV4) && (ip_version == IP_V4);
  assign detect_ipv4_bad = detect_ipv4 && ip4_ihl != 5;

  assign o_detect_ipv4     = detect_ipv4;
  assign o_detect_ipv4_bad = detect_ipv4_bad;

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin
      addr              <= 'b0;
      ethernet_protocol <= 'b0;
      ip_version        <= 'b0;
      udp_length        <= 'b0;
    end else begin
      if (i_clear) begin
         addr              <= 'b0;
         ethernet_protocol <= 'b0;
         ip_version        <= 'b0;
         udp_length        <= 'b0;
      end else if (i_process) begin
        addr               <= 'b0;
        //0: 2c768aadf786902b [63:16] e_dst [15:0] e_src
        //1: 3431273408004500 [63:32] e_src [31:16] eth_proto [15:12] ip_version
        //2: 004c000040004011
        //3: 1573c0a80101a0b1
        if (addr == 1) begin
          ethernet_protocol <= i_data[31:16];
          ip_version        <= i_data[15:12];
          ip4_ihl           <= i_data[11:8];
        end else if (detect_ipv4 && ip4_ihl == 5) begin
          if (addr == 3) begin
            //ihl=5 => 160 bits. 160/64
	    //16 bits of IPv4 header in addr=1
            //84 bits of IPv4 header in addr=2
            //60 bits of IPv4 header remaining, 24 bits of UDP
            //UDP source port [23:8]
            //UDP dst port [7:0]
            ;
          end else if (addr == 4) begin
            udp_length <= i_data[15:0];
          end
        end
      end
    end
  end
endmodule
