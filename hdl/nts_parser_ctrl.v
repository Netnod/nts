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

module nts_parser_ctrl #(
  parameter ADDR_WIDTH = 10
) (
  input  wire                    i_areset, // async reset
  input  wire                    i_clk,
  input  wire                    i_clear,
  input  wire                    i_process_initial,
  input  wire  [7:0]             i_last_word_data_valid,
  input  wire [63:0]             i_data,

  input  wire                    i_access_port_wait,
  output wire [ADDR_WIDTH+3-1:0] o_access_port_addr,
  output wire [2:0]              o_access_port_wordsize,
  output wire                    o_access_port_rd_en,
  input  wire                    i_access_port_rd_dv,
  input  wire [63:0]             i_access_port_rd_data
);

  localparam [3:0] OPCODE_GET_OFFSET_UDP_DATA = 4'b0000;
  localparam [3:0] OPCODE_GET_LENGTH_UDP      = 4'b0001;

  localparam STATE_IDLE                  = 4'h0;
  localparam STATE_COPY                  = 4'h1;
  localparam STATE_EXTRACT_FROM_IP       = 4'h2;
  localparam STATE_LENGTH_CHECKS         = 4'h3;
  localparam STATE_EXTRACT_EXT_FROM_RAM  = 4'h4;
  localparam STATE_ERROR_GENERAL         = 4'hf;


  reg [ADDR_WIDTH+3-1:0] access_port_addr;
  reg [2:0]              access_port_wordsize;
  reg                    access_port_rd_en;


  assign o_access_port_addr     = access_port_addr;
  assign o_access_port_wordsize = access_port_wordsize;
  assign o_access_port_rd_en    = access_port_rd_en;

  reg  [3:0]            state;
  reg  [ADDR_WIDTH-1:0] counter;
  wire                  detect_ipv4;
  wire                  detect_ipv4_bad;
  wire [31:0]           read_data;
  reg  [3:0]            read_opcode;

  nts_ip #(ADDR_WIDTH) ip_decoder (
    .i_areset(i_areset),
    .i_clk(i_clk),
    .i_clear(i_clear),
    .i_process(i_process_initial),
    .i_last_word_data_valid(i_last_word_data_valid),
    .i_data(i_data),
    .i_read_opcode(read_opcode),
    .o_detect_ipv4(detect_ipv4),
    .o_detect_ipv4_bad(detect_ipv4_bad),
    .o_read_data(read_data)
  );

  reg  [ADDR_WIDTH+3-1:0] ntp_addr;
  reg  [15:0]             udp_length;

  reg  [2:0]              ntp_extension_counter;
  reg                     ntp_extension_copied      [0:7];
  reg  [ADDR_WIDTH+3-1:0] ntp_extension_addr        [0:7];
  reg  [15:0]             ntp_extension_tag         [0:7];
  reg  [15:0]             ntp_extension_length      [0:7];

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin : ASYNC_RESET
      integer i;
      for (i=0; i <= 7; i++) begin
        ntp_extension_copied      [i] <= 'b0;
        ntp_extension_addr        [i] <= 'b0;
        ntp_extension_tag         [i] <= 'b0;
        ntp_extension_length      [i] <= 'b0;
      end
      access_port_rd_en               <= 'b0;
      access_port_wordsize            <= 'b0;
      access_port_addr                <= 'b0;
    end else if (i_clear) begin : SYNC_RESET_FROM_TOP_MODULE
      integer i;
      for (i=0; i <= 7; i++) begin
        ntp_extension_copied      [i] <= 'b0;
        ntp_extension_addr        [i] <= 'b0;
        ntp_extension_tag         [i] <= 'b0;
        ntp_extension_length      [i] <= 'b0;
      end
      access_port_rd_en               <= 'b0;
      access_port_wordsize            <= 'b0;
      access_port_addr                <= 'b0;
    end else begin
      access_port_rd_en        <= 'b0;
      if (state == STATE_EXTRACT_EXT_FROM_RAM && ntp_extension_copied[ntp_extension_counter] == 'b0) begin
        //$display("%s:%0d i_access_port_rd_dv=%0d i_access_port_wait=%0d", `__FILE__, `__LINE__, i_access_port_rd_dv, i_access_port_wait);
        if (i_access_port_rd_dv) begin
          ntp_extension_copied      [ntp_extension_counter] <= 'b1;
          ntp_extension_addr        [ntp_extension_counter] <= ntp_addr;
          ntp_extension_tag         [ntp_extension_counter] <= i_access_port_rd_data[31:16];
          ntp_extension_length      [ntp_extension_counter] <= i_access_port_rd_data[15:0];
          //$display("%s:%0d tag %0h, length %h", `__FILE__, `__LINE__, i_access_port_rd_data[31:16], i_access_port_rd_data[15:0]);
        end else if (i_access_port_wait == 'b0) begin
          //$display("%s:%0d ", `__FILE__, `__LINE__);
          access_port_rd_en                <= 'b1;
          access_port_wordsize             <= 2; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
          access_port_addr                 <= ntp_addr;
        end
      end
    end
  end

  function func_address_within_memory_bounds (input [ADDR_WIDTH+3-1:0] address, [ADDR_WIDTH+3-1:0] bytes);
    reg [ADDR_WIDTH+3-1:0] memory_bound;
    reg [ADDR_WIDTH+4-1:0] acc;
    begin
      memory_bound = { counter, 3'b000};
      acc = {1'b0, address} + {1'b0, bytes} - 1;
      if (acc[ADDR_WIDTH+4-1] == 'b1) func_address_within_memory_bounds  = 'b0;
      else if (acc[ADDR_WIDTH+3-1:0] >= memory_bound) func_address_within_memory_bounds  = 'b0;
      else func_address_within_memory_bounds  = 'b1;
    end
  endfunction

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin
      state                     <= STATE_IDLE;
      read_opcode               <= OPCODE_GET_OFFSET_UDP_DATA;
      counter                   <= 'b0;
      ntp_extension_counter     <= 'b0;

    end else if (i_clear) begin
      state                 <= STATE_IDLE;
    end else begin
      //$display("%s:%0d debug: state %0d i_process_initial %0d", `__FILE__, `__LINE__, state, i_process_initial);
      case (state)
        STATE_IDLE:
          begin
            read_opcode    <= OPCODE_GET_OFFSET_UDP_DATA;
            counter         <= 'b0;
            ntp_extension_counter <= 'b0;
            if (i_process_initial) begin
              state <= STATE_COPY;
            end
          end
        STATE_COPY:
          if (i_process_initial == 1'b0) begin
            state       <= STATE_EXTRACT_FROM_IP;
            read_opcode <= OPCODE_GET_OFFSET_UDP_DATA;
          end else begin
            counter     <= counter + 1;
          end
        STATE_EXTRACT_FROM_IP:
          case (read_opcode)
            OPCODE_GET_OFFSET_UDP_DATA:
              begin
               read_opcode                 <= OPCODE_GET_LENGTH_UDP;
               ntp_addr[ADDR_WIDTH+3-1:3]  <= read_data[ADDR_WIDTH+3-1:3] + 6;
               ntp_addr[2:0]               <= read_data[2:0];
              end
            OPCODE_GET_LENGTH_UDP:
              begin
                state                      <= STATE_LENGTH_CHECKS;
                udp_length                 <= read_data[15:0];
              end
            default:
              begin
                state <= STATE_ERROR_GENERAL;
                $display("%s:%0d warning: not implemented",`__FILE__,`__LINE__);
              end
          endcase
        STATE_LENGTH_CHECKS:
          begin
            if (udp_length < ( 8 /* UDP Header */ + 6*8 /* Minimum NTP Payload */ + 8 /* Smallest NTP extension */ ))
              state           <= STATE_ERROR_GENERAL;
            else if (udp_length > 65507 /* IPv4 maximum UDP packet size */)
              state           <= STATE_ERROR_GENERAL;
            else if (udp_length[1:0] != 0) /* NTP packets are 7*8 + M(4+4n), always 4 byte aligned */
              state           <= STATE_ERROR_GENERAL;
            else if (func_address_within_memory_bounds (ntp_addr, 4) == 'b0)
              state           <= STATE_ERROR_GENERAL;
            else
              state           <= STATE_EXTRACT_EXT_FROM_RAM;
          end
        STATE_EXTRACT_EXT_FROM_RAM:
           if (ntp_extension_copied[ntp_extension_counter] == 'b1) begin
             //TODO: implement support for multiple extensions
             $display("%s:%0d copied, ok? tag: %h len: %h",`__FILE__,`__LINE__, ntp_extension_tag[ntp_extension_counter], ntp_extension_length[ntp_extension_counter]);
             state <= STATE_IDLE;
           end
        STATE_ERROR_GENERAL:
          begin
            state  <= STATE_IDLE;
            $display("%s:%0d warning: error",`__FILE__,`__LINE__);
          end
        default:
          begin
            state <= STATE_ERROR_GENERAL;
            $display("%s:%0d warning: not implemented",`__FILE__,`__LINE__);
          end
      endcase
    end
  end
endmodule
