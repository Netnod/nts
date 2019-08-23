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

module nts_engine #(
  parameter ADDR_WIDTH = 10
) (
  input  wire                  i_areset, // async reset
  input  wire                  i_clk,
  output wire                  o_busy,
  input  wire                  i_dispatch_packet_available,
  output wire                  o_dispatch_packet_read_discard,
  input  wire [7:0]            i_dispatch_data_valid,
  input  wire                  i_dispatch_fifo_empty,
  output wire                  o_dispatch_fifo_rd_en,
  input  wire [63:0]           i_dispatch_fifo_rd_data
);

  reg [3:0]  state;

  localparam STATE_EMPTY             = 4'h0;
  localparam STATE_COPY              = 4'h1;
  localparam STATE_ERROR_BAD_PACKET  = 4'hc;
  localparam STATE_ERROR_OVERFLOW    = 4'hd;
  localparam STATE_ERROR_GENERAL     = 4'he;
  localparam STATE_TO_BE_IMPLEMENTED = 4'hf;

  reg [ADDR_WIDTH-1:0] addr;
  reg [ADDR_WIDTH-1:0] counter;
  reg [7:0]            data_valid; //bit field, ff = 8bytes valid, 7f=7bytes, 3f=6bytes, ...
  reg                  busy;
  reg                  dispatch_packet_discard;
  reg                  dispatch_fifo_rd_en;
  wire [63:0]          r_data;

  bram #(ADDR_WIDTH,64) nts_rx_buffer (
     .i_clk(i_clk),
     .i_addr(addr),
     .i_write(dispatch_fifo_rd_en),
     .i_data(i_dispatch_fifo_rd_data),
     .o_data(r_data)
  );

  wire        detect_ipv4;
  wire        detect_ipv4_bad;
  reg   [3:0] ip_read_opcode;
  wire [31:0] ip_read_data;

  nts_ip #(ADDR_WIDTH) ip_decoder (
   .i_areset(i_areset),
   .i_clk(i_clk),
   .i_clear(state == STATE_EMPTY),
   .i_process(state == STATE_COPY && dispatch_fifo_rd_en),
   .i_last_word_data_valid(i_dispatch_data_valid),
   .i_data(i_dispatch_fifo_rd_data),
   .i_read_opcode(ip_read_opcode),
   .o_detect_ipv4(detect_ipv4),
   .o_detect_ipv4_bad(detect_ipv4_bad),
   .o_read_data(ip_read_data)
  );

  assign o_busy = busy;
  assign o_dispatch_packet_read_discard = dispatch_packet_discard;
  assign o_dispatch_fifo_rd_en = dispatch_fifo_rd_en;

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin
      state                   <= STATE_EMPTY;
      busy                    <= 'b0;
      addr                    <= 'b0;
      counter                 <= 'b0;
      dispatch_packet_discard <= 'b0;
      dispatch_fifo_rd_en     <= 'b0;
    end else begin
      dispatch_packet_discard <= 'b0;
      dispatch_fifo_rd_en     <= 'b0;
      //$display("%s:%0d state=%h busy=%h addr=%h counter=%h discard=%h rd_en=%h", `__FILE__, `__LINE__, state, busy, addr, counter, dispatch_packet_discard, dispatch_fifo_rd_en);
      case (state)
        STATE_EMPTY:
          begin
            addr  <= 'b0;
            if (i_dispatch_packet_available && i_dispatch_fifo_empty == 'b0) begin
              state               <= STATE_COPY;
              busy                <= 'b1;
              dispatch_fifo_rd_en <= 'b1;
            end else begin
              busy                <= 'b0;
            end
          end
        STATE_COPY:
          if (i_dispatch_fifo_empty) begin
            state               <= STATE_TO_BE_IMPLEMENTED;
            counter             <= addr;
            //$display("%s:%0d detect_ipv4: %h detect_ipv4_bad: %h", `__FILE__, `__LINE__, detect_ipv4, detect_ipv4_bad);
            //$display("%s:%0d Ethernet protocol: %h ", `__FILE__, `__LINE__, ethernet_protocol);
            //$display("%s:%0d ip_version: ", `__FILE__, `__LINE__, ip_version);
          end else if (addr == ~ 'b0) begin //not empty, but internal memory full
            state               <= STATE_ERROR_OVERFLOW;
          end else begin
            dispatch_fifo_rd_en <= 'b1;
            addr                 <= addr+1;
          end
        default:
          begin
            $display("%s:%0d TODO!!! NOT IMPLEMENTED.", `__FILE__, `__LINE__);
            busy  <= 'b0;
            state <= STATE_EMPTY;
          end
      endcase
    end
  end
endmodule
