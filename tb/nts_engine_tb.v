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

module nts_engine_tb #( parameter integer verbose_output = 'h0);
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

  task send_packet ( input [65535:0] source, [31:0] length );
    integer i;
    integer packet_ptr;
    integer source_ptr;
    reg [63:0] packet [0:99];
    begin
      if (verbose_output > 0) $display("%s:%0d Send packet!", `__FILE__, `__LINE__);
      `assert( (0==(length%8)) ); // byte aligned required
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
      if (verbose_output > 2) $display("%s:%0d length=%0d packet_ptr=%0d packet=%h", `__FILE__, `__LINE__, length, 0, packet[0]);
      for (i=0; i<length/64; i=i+1) begin
         packet[packet_ptr] = source[source_ptr+:64];
         if (verbose_output > 2) $display("%s:%0d length=%0d packet_ptr=%0d packet=%h", `__FILE__, `__LINE__, length, packet_ptr, packet[packet_ptr]);
         source_ptr = source_ptr + 64;
         packet_ptr = packet_ptr + 1;
      end

      #10
      i_dispatch_packet_available = 0;
      i_dispatch_data_valid       = 'b0;
      i_dispatch_fifo_empty       = 'b1;
      i_dispatch_fifo_rd_data     = 'b0;
      `assert( o_busy == 'b0 );
      `assert( o_dispatch_packet_read_discard == 'b0 );
      `assert( o_dispatch_fifo_rd_en == 'b0 );


      #10
      i_dispatch_packet_available = 'b1;

      case ((length/8) % 8)
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
            $display("length:%0d", length);
            `assert(0);
          end
      endcase

      `assert( o_busy == 'b0 );
      `assert( o_dispatch_packet_read_discard == 'b0 );
      `assert( o_dispatch_fifo_rd_en == 'b0 );

      #10
      for (packet_ptr=packet_ptr-1; packet_ptr>=0; packet_ptr=packet_ptr-1) begin
        i_dispatch_fifo_empty = 'b0;
        i_dispatch_fifo_rd_data[63:0] = packet[packet_ptr];
        if (verbose_output > 2) $display("%s:%0d i_dispatch_fifo_rd_data = %h", `__FILE__, `__LINE__, packet[packet_ptr]);
        if (o_dispatch_fifo_rd_en == 'b0) begin
          while ( o_dispatch_fifo_rd_en == 'b0 ) begin
            if (verbose_output > 1) $display("%s:%0d waiting for dut to wake up...", `__FILE__, `__LINE__);
            #10 ;
          end
        end else #10 ;
      end
      i_dispatch_fifo_empty = 'b1;
      #10
      `assert( o_dispatch_packet_read_discard == 'b0 );
      `assert( o_dispatch_fifo_rd_en == 'b0 );
      #10
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

    end
  endtask

  task send_ntp4_req;
    begin
      send_packet({64816'b0, packet_eth_ipv4_udp_ntp}, $bits(packet_eth_ipv4_udp_ntp));
    end
  endtask

  reg [5487:0] nts_packet1 = { 64'hfe5400a6ab8d5254, 64'h00ab4ff908004500, 64'h02a0558c40004011, 64'h6d46c0a87a28c0a8, 64'h7a01007bb562028c, 64'h7818240400e60000, 64'h0c8a000000391f0e, 64'h83bce10908460b93, 64'h9a21e3f82e7eb74a, 64'h9f6ae10909b47081, 64'h1a35e10909b47088, 64'h333a01040024c186, 64'h0fbe6268f9374950, 64'h5a7ba4b50307df91, 64'hfe02f08b1146a062, 64'he1f87880fa540404, 64'h0230001002183e83, 64'h0616b8fead9a5d2c, 64'h0c2d3ca182a5e96c, 64'h62a5effa54f553f7, 64'h23886ce066068f91, 64'hcae6b73290b62ab2, 64'hd81a8ff06de30cef, 64'h9b4ba0efb47f600a, 64'h922647bd7f7f8838, 64'h07f4ca4d61fc285a, 64'h868ab7f071187a2f, 64'h3fcc4fd13dbc2e18, 64'hcb8986453f357c3c, 64'h9270aa21e668dbd3, 64'h3f8232200e753c11, 64'he63895c5b61f3c1f, 64'h123906d7442f94bc, 64'h6ea991a2d73a6766, 64'hb16e160ecc30c3a4, 64'hdda45c2af6a165dd, 64'h76bd40e6bb51491d, 64'h63ff0f78e115200f, 64'h1042baba7c4965fe, 64'h204d685c550718ad, 64'hf4dc2ce9679a75ae, 64'haf5cd5ab286bf95d, 64'h56b3d798b92b1fd5, 64'h90285ed5a82df100, 64'hc67036e9f819ac28, 64'h3e10d57331de9a4e, 64'hda1103b0657077b8, 64'hb619f4433a9871b8, 64'hbdd63960eecf3902, 64'h81d3dac87677c215, 64'h4e354268c905e17e, 64'he897eddc99653708, 64'h88935b411a8da4ef, 64'hefb7d075b83c01f8, 64'h6e2a14d53ad01df9, 64'hab831ca751ea9f55, 64'h3706bbe026f35044, 64'h9761095a14e3a33d, 64'h9c717e6c53c66154, 64'h219dca89eb17c9aa, 64'he32331cc2a1c0fca, 64'h66462a379bcb0717, 64'hf9c3640829342a1e, 64'hf5340b79a1c9291d, 64'h60d92f3fe60f98a7, 64'ha23da91a3774c6a5, 64'h172565f547391daa, 64'he45a49e46e04f7e5, 64'h53d30660cb79a9b1, 64'ha86fef58230a5e37, 64'h6e290ac55f516a3d, 64'h4d5dbbb16a2e14c4, 64'h70b339292bc7b972, 64'h0d982132a71d57d4, 64'ha8c313fbdbe1f02a, 64'hf2d9454eb0048865, 64'h8c91ff388287f7df, 64'h809e8ca6aea664e5, 64'h39d4ae129bcb1bfa, 64'h6a150b4f44875be3, 64'h149f94258cc0eaad, 64'h1da92a64c3bb4faf, 64'h06302113076e3443, 64'h9f326416d51040a2, 64'h33ff5138d8c1a283, 48'hc719450556f7 };


  reg [5487:0] nts_packet2 = { 64'hfe5400a6ab8d5254, 64'h00ab4ff908004500, 64'h02a0a9c840004011, 64'h190ac0a87a28c0a8, 64'h7a01007ba24e028c, 64'h7818240400e60000, 64'h0c8a000000401f0e, 64'h83bce10908460b93, 64'h9a21356fa54c089a, 64'h143ce1090a11f0a1, 64'h4fd8e1090a11f0ab, 64'hbeb801040024dde4, 64'hdbeb1963d1a5fcf2, 64'h9256daba4a9917e0, 64'hbaa8e51a7401366b, 64'h75e18512dead0404, 64'h02300010021834c8, 64'h39711a027c8a68b7, 64'hdc3cfd9df233bbfd, 64'h21d4c4b8b8340de3, 64'h02bcd638ead234e9, 64'h81e43ebfaacded9d, 64'he30356ba353de5dd, 64'h10f9b4b59ff9da3e, 64'h4a9cd7a4a341322c, 64'h6dd38fca610ee799, 64'hd372b44767ce4147, 64'hf635786e76bbb9ae, 64'hd475299ba5c894db, 64'h21319392776ed78a, 64'h8121a4eb1c4ca6cc, 64'h74112c820478e8cc, 64'h97538d22e02d5eaf, 64'h23ea33b0d0f0e6c7, 64'h5b2b718f82bb07a4, 64'h763da21c6ed93e07, 64'h10b05c53dc1f372c, 64'h123af5a06884d6e0, 64'hf0a433d6c0876556, 64'hcf7294d7846cd34d, 64'h1136546f81f972c2, 64'h8a29ca55df766bb0, 64'h80fca38aa2128abe, 64'h7b59964c88fe75ae, 64'ha12f927220086540, 64'h6d4a70b5baa07e18, 64'h5014199b499eb9b0, 64'h305b3f85bf9eed00, 64'h4891c494b2732b3f, 64'hcbb67f867962c5cc, 64'h29ea1624d44e6a3a, 64'h474358d27860c73c, 64'he45a13bb8d3cefc3, 64'h8d1403187efbd782, 64'h231613181ee48c90, 64'h29eda2d7779fd7bd, 64'hac2bdd262fe9c73f, 64'h5d0530b859048dc8, 64'hd71d6d56623e7b05, 64'h84e4b3b134055460, 64'h0e4caa795ded6ef2, 64'h1d8c36eb495cefc0, 64'h7d2e4696dfa5d8f2, 64'h50ad96aa82126f5d, 64'hc18fb9fa36d7d001, 64'he1a6ec4fc5859b30, 64'hda8b425ae761b4aa, 64'h791096a8bf33a3f3, 64'h37ded08d578e4bfb, 64'h846a6546381e3bda, 64'hb5c181f3b6e7cf2c, 64'hbbfbc97427b81dee, 64'ha6c0f6f4aed1b803, 64'h4eda786f1a410233, 64'hbd8a688add4bf752, 64'h1a7b4881bf6d334f, 64'h42e0e0915de39919, 64'h494c551fc6bb8071, 64'h1bfc48a9de20a17e, 64'he5941ff57639b6f3, 64'h79de52181507dbdd, 64'ha82682aee21d98a0, 64'ha079bc635a8bd1aa, 64'h5a731d2479bbe12c, 64'hf9040b8872fdf4ad, 48'hf996410bcfd8 };

  reg [5487:0] nts_packet3 = { 64'hfe5400a6ab8d5254, 64'h00ab4ff908004500, 64'h02a0ae0b40004011, 64'h14c7c0a87a28c0a8, 64'h7a01007b98a5028c, 64'h7818240400e60000, 64'h0c8a000000411f0e, 64'h83bce10908460b93, 64'h9a21eb71fb26d69a, 64'h6444e1090a1cdfae, 64'h5739e1090a1cdfb9, 64'hf04601040024c477, 64'h9861c58286f503cb, 64'hd910354b85038e4a, 64'h3bb7826b00aabfc1, 64'h5bf45b2b43400404, 64'h023000100218867a, 64'h39b5645c96a8b43d, 64'hd6b8a7985a13b5b5, 64'h61ee989d5fbd4052, 64'h4ef919ef8b0d5392, 64'ha0b54f40fd7f15db, 64'hb63de0cc4ec04958, 64'h039712565f037384, 64'h3a0b7f8b26a9779f, 64'h62dab2c8abceeea0, 64'h3858aaf4c4dbe8cc, 64'ha058f6c7998a9bf2, 64'hb7139d619bef9457, 64'h6f12373deb195937, 64'hf79ca4df668bb8b0, 64'hce5c3f20a7620d82, 64'h03bc6459a8321bdc, 64'h793d5c1dc7c74abe, 64'h0ead5f9fc5326eab, 64'h1df3b5a04c537aee, 64'he94a30a465cab94e, 64'h0dae2812a446cb35, 64'h67eeb9a9ae4ffed9, 64'hf8e2f4823c3eb5c6, 64'h685197cbf4163176, 64'hc01e1ed7213f978b, 64'h1a6de7f45712714d, 64'h5aae104d684242fb, 64'hcb00f95538c6f4c3, 64'hed4ea8293b64c443, 64'hdb454132ea307c24, 64'hde979a78b5bba1b5, 64'hacec4ecdf2e41ea6, 64'h62ce47d8a62a301d, 64'hd4f4fdfbc2d74b46, 64'ha0e47f5217d070c3, 64'h2317b4ccb10c3d21, 64'h900ecdd81764aaab, 64'ha83e6d736c4df61f, 64'h03f77d5f3752f7ed, 64'hdf69daeb623fcb3a, 64'hd1b340e7f0b8e67e, 64'h2aac50f424ad6ac2, 64'h4b67300fd2384493, 64'hc96d9c0bea0b4445, 64'h8778a6aab9c73223, 64'h3c71e27fdbb4da56, 64'h23dec7d475b5e440, 64'h2074556071a48692, 64'h10b459bda7feb809, 64'h7d50bbf070363c1d, 64'hda5029b8558700b6, 64'hb57101215eae3677, 64'ha81d2f450dbb1178, 64'h78a4010b8fd0143c, 64'h98baabb41ed3a11d, 64'h2cfa0e4a8f79ca7a, 64'h36c0b283be945262, 64'h91dbce3c06414f1b, 64'hd2111a5e952683a2, 64'hb99359f0bae1ab27, 64'h40b8c65e5b0e1e80, 64'had50dc4215a6fbe8, 64'hbef43ca4114d3362, 64'h35bc7fd46cc1ee29, 64'h50a732dc8d4e3448, 64'hdb0ab8edd1ac1fa6, 64'ha5b7e0b3fa9bfc43, 64'hc52dfb342716d1a4, 48'he4e1590e0225 };

 reg [5487:0] nts_packet4 = { 64'hfe5400a6ab8d5254, 64'h00ab4ff908004500, 64'h02a0af1140004011, 64'h13c1c0a87a28c0a8, 64'h7a01007bb673028c, 64'h7818240400e60000, 64'h0c8a000000411f0e, 64'h83bce10908460b93, 64'h9a210caa0df97388, 64'h0014e1090a23473e, 64'h79d6e1090a234745, 64'hd670010400247876, 64'h7a8dcc0bed79d3f9, 64'h15e7a1687462bdf2, 64'h4551a72b8811f4f0, 64'hfff60a3f5f3a0404, 64'h0230001002184c98, 64'h841d4c4d6650413e, 64'h7e6ef3c02a95158c, 64'h0ca6c0697eeda65d, 64'hc43b2010d501be10, 64'hb7885861057daa1f, 64'h9846198e2c11859e, 64'h866b46cddd1b8d0b, 64'hf9bc6f8f73a90738, 64'h945544c7a2d2669a, 64'h57358ab0087dde93, 64'hc5c847fb0e79541e, 64'hc4478eb0d5debe06, 64'h8ac4658057b92a8d, 64'h72b6261555250a80, 64'hd105e7c74ecfdc35, 64'h5c7293b31b2b2870, 64'h36fd2d996d596c38, 64'h18ee16f05c99f2a2, 64'h0e45407c0f3c41d9, 64'hb66df99fbe66d55a, 64'h1ae2e29e65e07049, 64'hfa815c28caf9386f, 64'h60b027da6144de90, 64'h776ffe871328cf73, 64'h736686d6174e9b93, 64'h6a55a02306669324, 64'hac32815ac873ac09, 64'h2e5660dfec376fab, 64'h6022f75c9522a73a, 64'h1d09b2851f1a299a, 64'hcf1277f1cfd0a08c, 64'h8156dd8371978808, 64'hb10f8b9d61e84293, 64'h5e91439e49b9996e, 64'h35e6afeb90f4864b, 64'h7928370f80e027e6, 64'h4f571594f9135bed, 64'hdeb870fd1917db87, 64'hb1bf664e3e0a4709, 64'h92c6332942b3f11f, 64'h63ea4c2078090c78, 64'hc38cef99aa1f05ff, 64'h097b6b9375c5e115, 64'hd4f19ae5aebf69ff, 64'h47f6c3c356d17698, 64'hf576bc08f2240b7b, 64'h2a33357fb904c22b, 64'hf9782c961c3b5687, 64'h7f644b7e17c1ebbe, 64'h8905b533dc0ecd1a, 64'h2bd8d511c9ea52cc, 64'hb12738a0975c340c, 64'h32eab2f2244d05cf, 64'h18befe2b80a28c9d, 64'h2af727b6bda67acb, 64'h7ecc5e52fe073433, 64'h1292419d903e7415, 64'h9f978ecda5d867f3, 64'h17cf1c90d0202c69, 64'h9504bc5443cd2760, 64'h833578e8b5d1f9eb, 64'h29b53819409917e5, 64'h6a6477a032be781f, 64'hed5c4624b074b7e9, 64'h85c4ddb63f4c78e4, 64'h32f033202e284282, 64'ha121e52d7ab1a8ee, 64'hf832119af7c40023, 48'hbd782703fba3 };

  task send_nts_packet1;
    begin
      send_packet({60048'b0, nts_packet1}, $bits(nts_packet1));
    end
  endtask

  task send_nts_packet2;
    begin
      send_packet({60048'b0, nts_packet2}, $bits(nts_packet2));
    end
  endtask

  task send_nts_packet3;
    begin
      send_packet({60048'b0, nts_packet3}, $bits(nts_packet3));
    end
  endtask
  task send_nts_packet4;
    begin
      send_packet({60048'b0, nts_packet4}, $bits(nts_packet4));
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
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
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

    #100000
    send_nts_packet1;

    #100
    send_nts_packet2;

    #20
    send_nts_packet3;

    #20
    send_nts_packet4;

    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end
  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
