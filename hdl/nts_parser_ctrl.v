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
  input  wire                  i_areset, // async reset
  input  wire                  i_clk,
  input  wire                  i_clear,
  input  wire                  i_process_initial,
  input  wire  [7:0]           i_last_word_data_valid,
  input  wire [63:0]           i_data
);

  localparam [3:0] OPCODE_GET_NTP_OFFSET = 4'b0000;

  localparam STATE_IDLE                 = 4'h0;
  localparam STATE_COPY                 = 4'h1;
  localparam STATE_EXTRACT_FROM_IP      = 4'h2;
  localparam STATE_EXTRACT_EXT_FROM_RAM = 4'h3;
  localparam STATE_ERROR_GENERAL        = 4'hf;

  localparam MEMORY_CTRL_IDLE           = 4'h0;
  localparam MEMORY_CTRL_READ_SIMPLE    = 4'h1;
  localparam MEMORY_CTRL_READ_1ST       = 4'h2;
  localparam MEMORY_CTRL_READ_2ND       = 4'h3;

  reg  [3:0]            state;
  reg  [3:0]            memctrl;
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

  reg  [ADDR_WIDTH-1:0] ntp_word;
  reg  [3:0]            ntp_word_offset;

  reg  [2:0]            ntp_extension_counter;
  reg                   ntp_extension_copied      [0:7];
  reg  [ADDR_WIDTH-1:0] ntp_extension_first_word  [0:7];
  reg  [3:0]            ntp_extension_word_offset [0:7];
  reg  [15:0]           ntp_extension_tag         [0:7];
  reg  [15:0]           ntp_extension_length      [0:7];

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin : ASYNC_RESET
      integer i;
      memctrl                         <= 'b0;
      for (i=0; i <= 7; i++) begin
        ntp_extension_copied      [i] <= 'b0;
        ntp_extension_first_word  [i] <= 'b0;
        ntp_extension_word_offset [i] <= 'b0;
        ntp_extension_tag         [i] <= 'b0;
        ntp_extension_length      [i] <= 'b0;
      end
    end else if (i_clear) begin : SYNC_RESET_FROM_TOP_MODULE
      integer i;
      memctrl                         <= 'b0;
      for (i=0; i <= 7; i++) begin
        ntp_extension_copied      [i] <= 'b0;
        ntp_extension_first_word  [i] <= 'b0;
        ntp_extension_word_offset [i] <= 'b0;
        ntp_extension_tag         [i] <= 'b0;
        ntp_extension_length      [i] <= 'b0;
      end
    end else begin
      case (memctrl)
        MEMORY_CTRL_IDLE:
          if (state == STATE_EXTRACT_EXT_FROM_RAM)
            if (ntp_extension_copied[ntp_extension_counter] == 'b0) begin
              if (ntp_word_offset < 4) begin
              end else begin
              end
          end
        MEMORY_CTRL_READ_SIMPLE:
          begin
            $display("%s:%0d todo implement!!!", `__FILE__, `__LINE__);
            memctrl <= MEMORY_CTRL_IDLE;
            ntp_extension_copied[ntp_extension_counter] <= 'b1;
          end
        MEMORY_CTRL_READ_1ST:
          begin
            $display("%s:%0d todo implement!!!", `__FILE__, `__LINE__);
            memctrl <= MEMORY_CTRL_READ_2ND;
          end
        MEMORY_CTRL_READ_2ND:
          begin
            $display("%s:%0d todo implement!!!", `__FILE__, `__LINE__);
            memctrl <= MEMORY_CTRL_IDLE;
            ntp_extension_copied[ntp_extension_counter] <= 'b1;
          end
        default:
          begin
            $display("%s:%0d todo implement!!!", `__FILE__, `__LINE__);
            memctrl <= MEMORY_CTRL_IDLE;
            ntp_extension_copied[ntp_extension_counter] <= 'b1;
          end
      endcase 
    end
  end


  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin
      state                     <= STATE_IDLE;
      read_opcode               <= OPCODE_GET_NTP_OFFSET;
      counter                   <= 'b0;
      ntp_word                  <= 'b0;
      ntp_word_offset           <= 'b0;
      ntp_extension_counter     <= 'b0;

    end else if (i_clear) begin
      state                 <= STATE_IDLE;
    end else
      case (state)
        STATE_IDLE:
          begin
            read_opcode    <= OPCODE_GET_NTP_OFFSET;
            counter         <= 'b0;
            ntp_word        <= 'b0;
            ntp_word_offset <= 'b0;

            if (i_process_initial) begin
              state <= STATE_COPY;
            end
          end
        STATE_COPY:
          if (i_process_initial == 1'b0) begin
            state       <= STATE_EXTRACT_FROM_IP;
            read_opcode <= OPCODE_GET_NTP_OFFSET;
          end else begin
            counter     <= counter + 1;
          end
        STATE_EXTRACT_FROM_IP:
          case (read_opcode)
            OPCODE_GET_NTP_OFFSET:
              begin
               ntp_word        <= read_data[ADDR_WIDTH+4-1:4];
               ntp_word_offset <= read_data[3:0];
              end
            default:
              begin
                state <= STATE_ERROR_GENERAL;
                $display("%s:%0d warning: not implemented",`__FILE__,`__LINE__);
              end
          endcase
      STATE_ERROR_GENERAL:
        begin
          state  <= STATE_IDLE;
          $display("%s:%0d warning: error",`__FILE__,`__LINE__);
        end
      default:
        state <= STATE_ERROR_GENERAL;
      endcase
  end
endmodule
