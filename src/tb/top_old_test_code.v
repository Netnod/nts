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


module old_test_code

  if (DEBUG>0) begin
    always @(posedge i_clk)
      if (dut.extractor_engine_fifo_rd_start || dut.engine_extractor_fifo_rd_valid)
        begin
          $display("%s:%0d extractor_engine_fifo_rd_start: %h, engine_extractor_fifo_rd_valid: %h, engine_extractor_fifo_rd_data: %h",`__FILE__,`__LINE__, dut.extractor_engine_fifo_rd_start, dut.engine_extractor_fifo_rd_valid, dut.engine_extractor_fifo_rd_data);
        end
    always @(posedge i_clk)
      if (dut.engine.parser.ntp_extension_we)
        $display("%s:%0d ntp_ext[%0d] = tag:%h,length:%h,addr:%h",
          `__FILE__,
          `__LINE__,
          dut.engine.parser.ntp_extension_counter_reg,
          dut.engine.parser.ntp_extension_tag_new,
          dut.engine.parser.ntp_extension_length_new,
          dut.engine.parser.ntp_extension_addr_new
        );
      always @(posedge i_clk)
        if (dut.engine.parser.crypto_fsm_we == 1)
          $display("%s:%0d State: %h CRYPTO_FSM state %h => %h [%s]",`__FILE__,`__LINE__,
            dut.engine.parser.state_reg,
            dut.engine.parser.crypto_fsm_reg,
            dut.engine.parser.crypto_fsm_new,
           (dut.engine.parser.crypto_fsm_new==dut.engine.parser.CRYPTO_FSM_DONE_SUCCESS) ? "Win!" : ((dut.engine.parser.crypto_fsm_new==dut.engine.parser.CRYPTO_FSM_DONE_FAILURE)?"Fail":"...."));
      always @*
        begin : tmp___
          integer engine_index;
          for (engine_index = 0; engine_index < ENGINES; engine_index = engine_index + 1)
            if (dut.engine_busy[dut.engine_index]==1'b0)
              $display("%s:%0d detect UI:%b C:%b CP:%b A:%b",  `__FILE__, `__LINE__,
                dut.engine_debug_detect_unique_identifier[engine_index],
                dut.engine_debug_detect_nts_cookie[engine_index],
                dut.engine_debug_detect_nts_cookie_placeholder[engine_index],
                dut.engine_debug_detect_nts_authenticator[engine_index]);
        end
      always @*
        $display("%s:%0d dut.engine.crypto.key_master_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.key_master_reg);
      always @*
        $display("%s:%0d dut.engine.crypto.key_current_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.key_current_reg);
      always @*
        $display("%s:%0d dut.engine.crypto.key_c2s_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.key_c2s_reg);
      always @*
        $display("%s:%0d dut.engine.crypto.key_s2c_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.key_s2c_reg);
      always @(posedge i_clk)
        begin
          if (dut.engine.crypto.i_key_valid)
            $display("%s:%0d dut.engine.crypto.i_key_valid word[%h]=%h", `__FILE__, `__LINE__, dut.engine.crypto.i_key_word, dut.engine.crypto.i_key_data );
          if (dut.engine.crypto.nonce_a_we)
            $display("%s:%0d dut.engine.crypto.nonce_a_we=1: %h", `__FILE__, `__LINE__, dut.engine.crypto.nonce_new);
          if (dut.engine.crypto.nonce_b_we)
            $display("%s:%0d dut.engine.crypto.nonce_b_we=1: %h", `__FILE__, `__LINE__, dut.engine.crypto.nonce_new);
          if (dut.engine.crypto.ramnc_en && dut.engine.crypto.ramnc_we)
            $display("%s:%0d dut.engine.crypto.ramnc_wdata: %h_%h", `__FILE__, `__LINE__, dut.engine.crypto.ramnc_wdata[127:64], dut.engine.crypto.ramnc_wdata[63:0]);
        end
      always @*
        $display("%s:%0d dut.engine.crypto.i_noncegen ready:%h valid: %h nonce:%h", `__FILE__, `__LINE__, dut.engine.crypto.i_noncegen_ready, dut.engine.crypto.i_noncegen_nonce_valid, dut.engine.crypto.i_noncegen_nonce);
      always @*
        $display("%s:%0d dut.engine.parser.state_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.state_reg);
      always @*
        $display("%s:%0d dut.engine.parser.i_last_word_data_valid: %b", `__FILE__, `__LINE__, dut.engine.parser.i_last_word_data_valid);
      always @*
        $display("%s:%0d dut.engine.parser.word_counter_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.word_counter_reg);
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_ip6_ip_dst_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.ipdecode_ip6_ip_dst_reg);
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_ip6_ip_src_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.ipdecode_ip6_ip_src_reg);
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_udp_port_dst_reg: %h (%0d)", `__FILE__, `__LINE__, dut.engine.parser.ipdecode_udp_port_dst_reg, dut.engine.parser.ipdecode_udp_port_dst_reg);
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_udp_port_src_reg: %h (%0d)", `__FILE__, `__LINE__, dut.engine.parser.ipdecode_udp_port_src_reg, dut.engine.parser.ipdecode_udp_port_src_reg);
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_udp_length_reg: %h (%0d)", `__FILE__, `__LINE__, dut.engine.parser.ipdecode_udp_length_reg, dut.engine.parser.ipdecode_udp_length_reg);
      always @*
        $display("%s:%0d dut.engine.parser.detect_ipv4: %b detect_ipv6: %b", `__FILE__, `__LINE__, dut.engine.parser.detect_ipv4, dut.engine.parser.detect_ipv6);
      always @(posedge i_clk or posedge i_areset)
        begin : tx_mux_inspect_locals_
          reg [ADDR_WIDTH+3-1:0] addr;
          addr = { dut.engine.mux_tx_address_hi, dut.engine.mux_tx_address_lo };
          if (i_areset == 0)
            if (dut.engine.mux_tx_write_en)
              $display("%s:%0d dut.engine.mux_tx %h %h (%h %h) = %h",  `__FILE__, `__LINE__, dut.engine.mux_tx_address_internal, addr, dut.engine.mux_tx_address_hi, dut.engine.mux_tx_address_lo, dut.engine.mux_tx_write_data);
        end
      always @*
        $display("%s:%0d dut.engine.i_dispatch_rx_fifo_rd_data: %h", `__FILE__, `__LINE__, dut.engine.i_dispatch_rx_fifo_rd_data);
      always @*
        $display("%s:%0d dut.engine.i_dispatch_rx_fifo_rd_valid: %h",  `__FILE__, `__LINE__, dut.engine.i_dispatch_rx_fifo_rd_valid);
      always @*
        $display("%s:%0d dut.dispatcher.mem_state[0]: %h", `__FILE__, `__LINE__, dut.dispatcher.mem_state_reg[0]);
      always @*
        $display("%s:%0d dut.dispatcher.mem_state[1]: %h", `__FILE__, `__LINE__, dut.dispatcher.mem_state_reg[1]);
      always @*
        $display("%s:%0d dut.dispatcher.current_mem: %h", `__FILE__, `__LINE__, dut.dispatcher.current_mem_reg);
/*
      always @*
        $display("%s:%0d dut.o_dispatch_tx_bytes_last_word_DUMMY=%b (ignored)",  `__FILE__, `__LINE__, dut.o_dispatch_tx_bytes_last_word_DUMMY);
      always @*
        $display("%s:%0d dut.o_dispatch_tx_fifo_rd_data_DUMMY=%h (ignored)",  `__FILE__, `__LINE__, dut.o_dispatch_tx_fifo_rd_data_DUMMY);
      always @*
        $display("%s:%0d dut.tx_d=%h (ignored)",  `__FILE__, `__LINE__, dut.tx_d); //TODO doesn't work well now. Fix later.
*/
      always @*
        $display("%s:%0d dut.dispatcher.mac_rx_corrected=%h",  `__FILE__, `__LINE__, dut.dispatcher.mac_rx_corrected);
      always @(posedge i_clk or posedge i_areset)
        if (i_areset == 0)
          if (dut.engine.rx_buffer.memctrl_we)
            if (dut.engine.rx_buffer.memctrl_new == dut.engine.rx_buffer.MEMORY_CTRL_ERROR) begin
              $display("%s:%0d WARNING: Memory controller error state detected!", `__FILE__, `__LINE__);
              $display("%s:%0d          memctrl_reg: %h", `__FILE__, `__LINE__, dut.engine.rx_buffer.memctrl_reg);
              $display("%s:%0d          access_ws{8,16,32,64}bit_reg: %b", `__FILE__, `__LINE__, {dut.engine.rx_buffer.access_ws8bit_reg, dut.engine.rx_buffer.access_ws16bit_reg, dut.engine.rx_buffer.access_ws32bit_reg, dut.engine.rx_buffer.access_ws64bit_reg});
              $display("%s:%0d          access_addr_lo_reg: %h", `__FILE__, `__LINE__, dut.engine.rx_buffer.access_addr_lo_reg);
              $display("%s:%0d          i_parser_busy: %h", `__FILE__, `__LINE__, dut.engine.rx_buffer.i_parser_busy);
          end
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_ethernet_mac_dst_reg: %h",  `__FILE__, `__LINE__, dut.engine.parser.ipdecode_ethernet_mac_dst_reg);
      always @*
        $display("%s:%0d dut.engine.parser.ipdecode_ethernet_mac_src_reg: %h",  `__FILE__, `__LINE__, dut.engine.parser.ipdecode_ethernet_mac_src_reg);
      always @*
        $display("%s:%0d dut.engine.parser.tx_header_ethernet_ipv4_udp: %h",  `__FILE__, `__LINE__, dut.engine.parser.tx_header_ethernet_ipv4_udp);
      always @*
        if (dut.engine.access_port_rd_dv_parser)
          $display("%s:%0d dut.engine.access_port(parser)[%h:%h]=%h", `__FILE__, `__LINE__, dut.engine.access_port_addr_parser, dut.engine.access_port_wordsize_parser, dut.engine.access_port_rd_data_parser);
      always @*
        if (dut.engine.parser_txbuf_address_internal==0)
          if (dut.engine.parser_txbuf_write_en)
            $display("%s:%0d dut.engine.parser_txbuf[%h]=%h", `__FILE__, `__LINE__, dut.engine.parser_txbuf_address, dut.engine.parser_txbuf_write_data);
      always @*
        $display("%s:%0d dut.engine.parser.cookies_count_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.cookies_count_reg);
      always @*
        $display("%s:%0d dut.engine.parser.nts_valid_placeholders_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.nts_valid_placeholders_reg);
      always @*
        $display("%s:%0d dut.engine.crypto.state_reg: %h", `__FILE__, `__LINE__, dut.engine.crypto.state_reg);
      always @*
        $display("%s:%0d dut.engine.parser.tx_udp_length_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.tx_udp_length_reg);
      always @*
        $display("%s:%0d dut.engine.parser.tx_ipv4_totlen_reg: %h", `__FILE__, `__LINE__, dut.engine.parser.tx_ipv4_totlen_reg);
      always @(posedge i_clk)
        begin
          if (dut.engine.parser_txbuf_sum_en)
            $display("%s:%0d dut.engine.sum_en, addr: %h (%0d), bytes: %h (%0d)", `__FILE__, `__LINE__, dut.engine.parser_txbuf_address, dut.engine.parser_txbuf_address, dut.engine.parser_txbuf_sum_bytes, dut.engine.parser_txbuf_sum_bytes);
          if (dut.engine.txbuf_parser_sum_done)
            $display("%s:%0d dut.engine.sum_done, sum: %h", `__FILE__, `__LINE__, dut.engine.txbuf_parser_sum);
      end
    always @*
      $display("%s:%0d dut.engine_extractor_packet_available: %h", `__FILE__, `__LINE__, dut.engine_extractor_packet_available);
    always @*
      $display("%s:%0d dut.engine_extractor_fifo_empty: %h", `__FILE__, `__LINE__, dut.engine_extractor_fifo_empty);
    always @(posedge i_clk)
      begin
        if (dut.extractor.ram_engine_write)
           $display("%s:%0d extractor.RAM[%h]=%h", `__FILE__, `__LINE__, dut.extractor.ram_engine_addr, dut.extractor.ram_engine_wdata);
        if (dut.extractor.buffer_engine_selected_we)
            $display("%s:%0d extractor, next write buffer: %h", `__FILE__, `__LINE__, dut.extractor.buffer_engine_selected_new);
      end
    always @(posedge i_clk)
      begin
        if (dut.engine.tx_buffer.current_mem_we)
          $display("%s:%0d txbuf word count: %h", `__FILE__, `__LINE__, dut.engine.tx_buffer.word_count_reg[dut.engine.tx_buffer.current_mem_reg]);
        if (dut.engine.tx_buffer.i_parser_update_length)
          $display("%s:%0d txbuf update word count: %h %h", `__FILE__, `__LINE__, dut.engine.tx_buffer.i_address_hi, dut.engine.tx_buffer.i_address_lo);
      end
    always @(posedge i_clk)
      begin
        if (dut.extractor.buffer_mac_selected_we)
          $display("%s:%0d extactor mac select buffer: %h", `__FILE__, `__LINE__, dut.extractor.buffer_mac_selected_reg);
      end
  end

 end

endmodule
