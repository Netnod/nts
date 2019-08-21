//
// Copyright (c) 2016-2019, The Swedish Post and Telecom Authority (PTS)
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

module nts_engine_tb;
  localparam  [47:0] MY_ETH_ADDR     =  48'h2c_76_8a_ad_f7_86;
  localparam  [31:0] MY_IPV4_ADDR    =  32'hA0_B1_C2_D3;
//  localparam [127:0] MY_IPV6_ADDR    = 128'hfe80_0000_0000_0000_2e76_8aff_fead_f786;
//  localparam  [47:0] MAC_BDCST_ADDR  =  48'hFF_FF_FF_FF_FF_FF;
  localparam  [47:0] CLNT_ETH_ADDR   =  48'h90_2b_34_31_27_34;
  localparam  [31:0] CLNT_IPV4_ADDR  =  32'hC0_A8_01_01;
//  localparam [127:0] CLNT_IPV6_ADDR  = 128'hfe80_0000_0000_0000_922b_34ff_fe31_2734;
//  localparam  [15:0] E_TYPE_ARP      =  16'h08_06;
  localparam  [15:0] E_TYPE_IPV4     =  16'h08_00;
//  localparam  [15:0] E_TYPE_IPV6     =  16'h86_DD;
//  localparam  [15:0] H_TYPE_ETH      =  16'h00_01;
//  localparam  [15:0] P_TYPE_IPV4     =  16'h08_00;
//  localparam  [15:0] ARP_OPER_REQ    =  16'h00_01;
 // localparam  [15:0] ARP_OPER_RESP   =  16'h00_02;
  localparam   [7:0] H_TYPE_ETH_LEN  =   8'h06;
//  localparam   [7:0] P_TYPE_IPV4_LEN =   8'h04;
  localparam  [15:0] NTP_IP_PKT_LEN  =  16'd76;  // NTP packet total length
  localparam  [15:0] ICMP_PROTV4     =  16'd1;   // ICMP Protocol for IPv4
  localparam  [15:0] UDP_PROT        =  16'd17;  // UDP Protocol
  localparam  [15:0] NTP_PORT        =  16'd123; // NTP destination port
  localparam  [15:0] CLNT_PORT       =  16'habc; // NTP source
  localparam  [15:0] NTP_UDP_PKT_LEN =  16'd56;  // NTP UDP packet length


  reg  [47:0] e_dst_mac;
  reg  [47:0] e_src_mac;
  reg  [15:0] e_type;

  reg  [3:0] ip_ver;

  reg  [3:0] ip4_ihl;
  reg  [5:0] ip4_dscp;
  reg  [1:0] ip4_ecn;
  reg [15:0] ip4_tot_len;
  reg [15:0] ip4_ident;
  reg  [2:0] ip4_flags;
  reg [12:0] ip4_frag_offs;
  reg  [7:0] ip4_ttl;
  reg  [7:0] ip4_protocol;
  reg [15:0] ip4_head_csum;
  reg [31:0] ip4_src_addr;
  reg [31:0] ip4_dst_addr;

  reg [15:0] udp_src_port;
  reg [15:0] udp_dst_port;
  reg [15:0] udp_len;
  reg [15:0] udp_csum;

  reg  [1:0] ntp_li;
  reg  [2:0] ntp_vn;
  reg  [2:0] ntp_mode;
  reg  [7:0] ntp_stratum;
  reg  [7:0] ntp_poll;
  reg  [7:0] ntp_precision;
  reg [31:0] ntp_root_delay;
  reg [31:0] ntp_root_disp;
  reg [31:0] ntp_ref_id;
  reg [63:0] ntp_ref_ts;
  reg [63:0] ntp_org_ts;
  reg [63:0] ntp_rx_ts;
  reg [63:0] ntp_tx_ts;

  wire [111:0] eth_header;
  wire [159:0] ipv4_header;
  wire  [63:0] udp_header;
  wire [383:0] ntp_payload;
  wire [719:0] packet_eth_ipv4_udp_ntp;

  assign eth_header              = { e_dst_mac, e_src_mac, e_type };
  assign ipv4_header             = { ip_ver, ip4_ihl, ip4_dscp, ip4_ecn, ip4_tot_len, ip4_ident, ip4_flags, ip4_frag_offs, ip4_ttl, ip4_protocol, ip4_head_csum, ip4_src_addr, ip4_dst_addr};
  assign udp_header              = { udp_src_port, udp_dst_port, udp_len, udp_csum };
  assign ntp_payload             = { ntp_li, ntp_vn, ntp_mode, ntp_stratum, ntp_poll, ntp_precision, ntp_root_delay, ntp_root_disp, ntp_ref_id, ntp_ref_ts, ntp_org_ts, ntp_rx_ts, ntp_tx_ts };
  assign packet_eth_ipv4_udp_ntp = { eth_header, ipv4_header, udp_header, ntp_payload };

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  // Calculate checksum of IPV4 header
  function [15:0] calc_ipv4h_csum;
    input x; //don't care
    reg	 [31:0]              tmp_sum;
    integer i;
    begin
      //bit [20*8/2-1:0] [15:0] head_words;
      tmp_sum = 32'b0;
//      head_words = ipv4_head;
      for (i=0; i<$bits(ipv4_header)/16; i=i+1) begin
        tmp_sum += { 16'b0, ipv4_header[i*16+:16] };
      end
      //for (i=0; i<20/2; i=i+1) begin
      //  tmp_sum = tmp_sum + { 16'b0, head_words[i] };
      //end
//    tmp_sum = tmp_sum[31:16] + tmp_sum[15:0];
      tmp_sum = { 16'b0, (tmp_sum[31:16] + tmp_sum[15:0]) };
      calc_ipv4h_csum = ~tmp_sum[15:0];
    end
  endfunction //

  //------------------------------------------------------------------------------------------

  // Calculate checksum of IPV4 UDP NTP packet
  function [15:0] calc_udp_ntp4_csum;
//    input packet;
    input x; //dont care
    reg [31:0]              tmp_sum;
    integer i;
    begin
//      tmp_sum = 16'b0;
//      tmp_sum += packet.ip_head.src_addr[31:16] + packet.ip_head.src_addr[15:0];
//      tmp_sum += packet.ip_head.dst_addr[31:16] + packet.ip_head.dst_addr[15:0];
//      tmp_sum += packet.ip_head.protocol;
//      tmp_sum += packet.udp_head.udp_len;
//      tmp_sum += packet.udp_head.src_port;
//      tmp_sum += packet.udp_head.dst_port;
//      tmp_sum += packet.udp_head.udp_len;
//      tmp_sum += packet.udp_head.udp_csum;
      // add ntp payload as data
      tmp_sum = 32'b0;
      tmp_sum += {28'b0, ip_ver};
      tmp_sum += {16'b0, ip4_src_addr[31:16]};
      tmp_sum += {16'b0, ip4_src_addr[15:0]};
      tmp_sum += {16'b0, ip4_dst_addr[31:16]};
      tmp_sum += {16'b0, ip4_dst_addr[15:0]};
      tmp_sum += {24'b0, ip4_protocol};
      tmp_sum += {16'b0, udp_len};
      tmp_sum += {16'b0, udp_src_port};
      tmp_sum += {16'b0, udp_dst_port};
      tmp_sum += {16'b0, udp_len};
      tmp_sum += {16'b0, udp_csum};
      // add ntp payload as data
      for (i=0; i<$bits(ntp_payload)/16; i=i+1) begin
//        tmp_sum += packet.payload[i*16+:16];
        tmp_sum += {16'b0, ntp_payload[i*16+:16]};
      end
//      for (i=0; i<32/16; i=i+1) begin
//        tmp_sum += packet.key_id[i*16+:16];
//        tmp_sum += {16'b0, packet.key_id[i*16+:16]};
//      end
//      for (i=0; i<160/16; i=i+1) begin
//        tmp_sum += packet.digest[i*16+:16];
//        tmp_sum += {16'b0, packet.digest[i*16+:16]};
//      end
      while (tmp_sum[31:16] > 0) begin
        tmp_sum = {16'b0, tmp_sum[31:16]} + {16'b0, tmp_sum[15:0]};
      end
//      if (tmp_sum != 16'hffff) begin
      if (tmp_sum != 32'h0000ffff) begin
        // Avoid generating 00 as csum since it could skip detection
        calc_udp_ntp4_csum = ~tmp_sum[15:0];
      end
    end
  endfunction // calc_udp_ntp4_csum

  //------------------------------------------------------------------------------------------

  task create_ntp4_req;
    //output ntp4_pkt_t packet;
    //input  sign = 0;
    //input  sha1 = 0;
    //input  key  = 0;
    begin
      e_dst_mac      = MY_ETH_ADDR;
      e_src_mac      = CLNT_ETH_ADDR;
      e_type         = E_TYPE_IPV4;
      ip_ver         = 4'd4;                            // IPV4
      ip4_ihl        = 4'd5;                            // 20 bytes
      ip4_dscp       = 6'd0;
      ip4_ecn        = 2'd0;
//      packet.ip_head.tot_len    = sign == 1'b0 ? NTP_IP_PKT_LEN : sha1 == 1'b0 ? NTP_IP_PKT_LEN + 20 : NTP_IP_PKT_LEN + 24;
      ip4_tot_len    = NTP_IP_PKT_LEN;
      ip4_ident      = 0;
      ip4_flags      = 3'b010;                          // Dont fragment
      ip4_frag_offs  = 13'd0;
      ip4_ttl        = 8'd64;
//      packet.ip_head.protocol   = UDP_PROT;
      ip4_protocol   = UDP_PROT[7:0];
      ip4_head_csum  = 16'd0;                           // tmp value for calculation
      ip4_src_addr   = CLNT_IPV4_ADDR;
      ip4_dst_addr   = MY_IPV4_ADDR;
      ip4_head_csum  = calc_ipv4h_csum(0); // update checksum
      udp_src_port  = CLNT_PORT;
      udp_dst_port  = NTP_PORT;
//      packet.udp_head.udp_len   = sign == 1'b0 ? NTP_UDP_PKT_LEN : sha1 == 1'b0 ? NTP_UDP_PKT_LEN + 20 : NTP_UDP_PKT_LEN + 24;
      udp_len   = NTP_UDP_PKT_LEN;
      udp_csum  = 16'b0;
      ntp_li         =  2'b0;
      ntp_vn         =  3'd4;
      ntp_mode       =  3'd3;
      ntp_stratum    =  8'd0;
      ntp_poll       =  8'd10;
      ntp_precision  =  8'd0;
//    packet.payload.root_delay = 32'haaaaaaaa;
      ntp_root_delay = $random;
      ntp_root_disp  = 32'hbbbbbbbb;
      ntp_ref_id     = 32'd0;
      ntp_ref_ts     = 64'd0;
      ntp_org_ts     = 64'd0;
      ntp_rx_ts      = 64'd0;
      ntp_tx_ts      = 64'h0123456789abcdef;
      //packet.key_id             = sign == 1'b0 ?  32'b0 : sha1 == 1'b0 ? MD5_KEY_ID[key] : SHA1_KEY_ID[key];
      //packet.digest             = sign == 1'b0 ? 160'b0 : sha1 == 1'b0 ? md5_func(MD5_KEY[key], packet.payload) << 32 : sha1_func(SHA1_KEY[key], packet.payload);
      //packet.key_id             = 32'b0;
      //packet.digest             = 160'b0;
      udp_csum = calc_udp_ntp4_csum(0);
    end
  endtask //create_ntp4_req


  //task_set_port(i_dispatch_fifo_rd_data, packet_eth_ipv4_udp_ntp, offset_hi, 0);a
/*
  task task_set_port;
     output destination_port;
     input  source_data;
     input  integer offset_hi;
     input  integer offset_lo;
     begin
       destination_port = 'b0;
       destination_port = source_data[offset_hi:offset_lo];
     end
   endtask;
*/

  task send_packet ( input [65535:0] source, [31:0] length );
    integer i;
    integer packet_ptr;
    integer source_ptr;
    reg [63:0] packet [0:99];
    begin
      for (i=0; i<100; i=i+1) begin
        packet[i] = 64'habad_1dea_f00d_cafe;
      end
      packet_ptr = 1;
      source_ptr = (length % 64);
      case (source_ptr)
         56: packet[0] = { 8'b0, source[55:0] };
         48: packet[0] = { 16'b0, source[47:0] };
         32: packet[0] = { 32'b0, source[31:0] };
         24: packet[0] = { 40'b0, source[23:0] };
         16: packet[0] = { 48'b0, source[15:0] };
          8: packet[0] = { 56'b0, source[7:0] };
          0: packet_ptr = 0;
        default:
          `assert(0)
      endcase
      $display("%s:%0d length=%0d packet=%h", `__FILE__, `__LINE__, length, packet[0]);
      for (i=0; i<length/64; i=i+1) begin
         packet[packet_ptr] = source[source_ptr+:64];
         $display("%s:%0d length=%0d packet=%h", `__FILE__, `__LINE__, length, packet[packet_ptr]);
         source_ptr = source_ptr + 64;
         packet_ptr = packet_ptr + 1;
      end
/*
      #10
      i_dispatch_packet_available = 0;
      i_dispatch_data_valid       = 'b0;
      i_dispatch_fifo_empty       = 'b1;
      i_dispatch_fifo_rd_data     = 'b0;
      `assert( o_busy == 'b0 );
      `assert( o_dispatch_packet_read_discard == 'b0 );
      `assert( o_dispatch_fifo_rd_en == 'b0 );


      #10
      length  = $bits(packet_eth_ipv4_udp_ntp);
      `assert( (0==(length%8)) ); // byte aligned required
      i_dispatch_packet_available = 'b1;

      case (modlen)
        0: i_dispatch_data_valid  = 8'b11111111; //all bytes valid
        1: i_dispatch_data_valid  = 8'b00000001; //last byte valid
        2: i_dispatch_data_valid  = 8'b00000011;
        3: i_dispatch_data_valid  = 8'b00000111;
        4: i_dispatch_data_valid  = 8'b00001111;
        5: i_dispatch_data_valid  = 8'b00011111;
        6: i_dispatch_data_valid  = 8'b00111111;
        7: i_dispatch_data_valid  = 8'b01111111;
        default:
          begin
            $display("length:%0d modlen:%0d", length, modlen);
            `assert(0);
          end
      endcase

      `assert( o_busy == 'b0 );
      `assert( o_dispatch_packet_read_discard == 'b0 );
      `assert( o_dispatch_fifo_rd_en == 'b0 );

      //#10
      //i_dispatch_fifo_empty = 'b0;
      //i_dispatch_fifo_rd_data = packet_eth_ipv4_udp_ntp[length-:64];
      //  $display("%08h%08h", i_dispatch_fifo_rd_data[63:32], i_dispatch_fifo_rd_data[31:0]);

      `assert( o_busy == 'b0 );
      `assert( o_dispatch_packet_read_discard == 'b0 );
      `assert( o_dispatch_fifo_rd_en == 'b0 );

      $display("%s:%0d length=%0d", `__FILE__, `__LINE__, length);
      $display("%s:%0d %h", `__FILE__, `__LINE__, packet_eth_ipv4_udp_ntp[719:656]);;
      for (i=length; i>=0; i=i-64) begin
        $display("%s:%0d i=%d", `__FILE__, `__LINE__, i);
        #10
        //i_dispatch_fifo_rd_data[63:0] = 'b0;
        //offset_hi = bits - 1;
        if (i>64) begin
          //offset_lo = offset_hi - 63;
          i_dispatch_fifo_empty = 'b0;
          i_dispatch_fifo_rd_data[63:0] = packet_eth_ipv4_udp_ntp[i-:64];
          //task_set_port(i_dispatch_fifo_rd_data, packet_eth_ipv4_udp_ntp, offset_hi, offset_lo);
          $display("%s:%0d %08h%08h", `__FILE__, `__LINE__, i_dispatch_fifo_rd_data[63:32], i_dispatch_fifo_rd_data[31:0]);
        end else begin
          i_dispatch_fifo_empty = 'b1;
          case (i)
            64: i_dispatch_fifo_rd_data[63:0] = packet_eth_ipv4_udp_ntp[63:0];
            56: i_dispatch_fifo_rd_data[55:0] = packet_eth_ipv4_udp_ntp[55:0];
            48: i_dispatch_fifo_rd_data[47:0] = packet_eth_ipv4_udp_ntp[47:0];
            32: i_dispatch_fifo_rd_data[31:0] = packet_eth_ipv4_udp_ntp[31:0];
            24: i_dispatch_fifo_rd_data[23:0] = packet_eth_ipv4_udp_ntp[23:0];
            16: i_dispatch_fifo_rd_data[15:0] = packet_eth_ipv4_udp_ntp[15:0];
             8: i_dispatch_fifo_rd_data[7:0] = packet_eth_ipv4_udp_ntp[7:0];
            default:
              `assert(0)
          endcase
          $display("%s:%0d %08h%08h", `__FILE__, `__LINE__, i_dispatch_fifo_rd_data[63:32], i_dispatch_fifo_rd_data[31:0]);
          //i_dispatch_fifo_rd_data[offset_hi:0] = packet_eth_ipv4_udp_ntp[offset_hi:0];
          //task_set_port(i_dispatch_fifo_rd_data, packet_eth_ipv4_udp_ntp, offset_hi, 0);
        end
        if ( o_dispatch_fifo_rd_en == 'b0 ) begin
          $display("%s:%0d waiting for dut to wake up...", `__FILE__, `__LINE__);
          #10 ;
        end
        //`assert( o_busy == 'b1 );
        `assert( o_dispatch_packet_read_discard == 'b0 );
        `assert( o_dispatch_fifo_rd_en == 'b1 );
      end;
      #10 ;
      `assert( o_dispatch_fifo_rd_en == 'b0 );
      for ( i=0; i<100000 || o_dispatch_packet_read_discard == 'b1; i=i+1 ) begin
        #10 ;
      end
      `assert( o_dispatch_packet_read_discard == 'b0 );
      `assert( o_dispatch_fifo_rd_en == 'b0 );
      for (i=0; i<100000 || o_busy == 'b1; i=i+1) begin
        #10 ;
      end
      `assert( o_busy == 'b0 );
      `assert( o_dispatch_packet_read_discard == 'b0 );
      `assert( o_dispatch_fifo_rd_en == 'b0 );

*/
    end
  endtask

  task send_ntp4_req;
    begin
      send_packet({64816'b0, packet_eth_ipv4_udp_ntp}, $bits(packet_eth_ipv4_udp_ntp));
    end
  endtask

  reg                  i_areset;
  reg                  i_clk;
  wire                 o_busy;
  reg                  i_dispatch_packet_available;
  wire                 o_dispatch_packet_read_discard;
  reg [7:0]            i_dispatch_data_valid;
  reg                  i_dispatch_fifo_empty;
  wire                 o_dispatch_fifo_rd_en;
  reg [63:0]           i_dispatch_fifo_rd_data;

  nts_engine dut (
    .i_areset(i_areset),
    .i_clk(i_clk),
    .o_busy(o_busy),
    .i_dispatch_packet_available(i_dispatch_packet_available),
    .o_dispatch_packet_read_discard(o_dispatch_packet_read_discard),
    .i_dispatch_data_valid(i_dispatch_data_valid),
    .i_dispatch_fifo_empty(i_dispatch_fifo_empty),
    .o_dispatch_fifo_rd_en(o_dispatch_fifo_rd_en),
    .i_dispatch_fifo_rd_data(i_dispatch_fifo_rd_data)
  );

  initial begin
    $display("Test start: %s %d", `__FILE__, `__LINE__);
    i_clk                       = 0;
    i_areset                    = 1;
    i_dispatch_packet_available = 0;
    i_dispatch_data_valid       = 'b0;
    i_dispatch_fifo_empty       = 'b1;
    i_dispatch_fifo_rd_data     = 'b0;

    #10
    i_areset = 0;
    `assert( o_busy == 'b0 );
    `assert( o_dispatch_packet_read_discard == 'b0 );
    `assert( o_dispatch_fifo_rd_en == 'b0 );

    create_ntp4_req;
    send_ntp4_req;

    $display("Test stop: %s %d", `__FILE__, `__LINE__);
    $finish;
  end
  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
