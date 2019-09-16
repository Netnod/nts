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

module nts_tx_buffer #(
  parameter ADDR_WIDTH = 10
) (
  input  wire        i_areset, // async reset
  input  wire        i_clk,

  output wire        o_dispatch_tx_packet_available,
  input  wire        i_dispatch_tx_packet_read,
  output wire        o_dispatch_tx_fifo_empty,
  input  wire        i_dispatch_tx_fifo_rd_en,
  output wire [63:0] o_dispatch_tx_fifo_rd_data,
  output wire  [3:0] o_dispatch_tx_bytes_last_word,

  input  wire        i_parser_clear,
  input  wire        i_parser_w_en,
  input  wire [63:0] i_parser_w_data,

  input  wire        i_parser_ipv4_done,
  input  wire        i_parser_ipv6_done,

  output wire        o_parser_current_memory_full,
  output wire        o_parser_current_empty
);

  //----------------------------------------------------------------
  // Local parameters
  //----------------------------------------------------------------

  localparam STATE_EMPTY                = 0;
  localparam STATE_HAS_DATA             = 1;
  //localparam STATE_IP4_LENGTH           = 2;
  //localparam STATE_IP4_CHECKSUM         = 3;
  //localparam STATE_IP4_UDP_CHECKSUM     = 4;
  //localparam STATE_IP6_LENGTH           = 5;
  //localparam STATE_IP6_CHECKSUM         = 6;
  //localparam STATE_IP6_UDP_CHECKSUM     = 7;
  localparam STATE_FIFO_OUT             = 8;
  localparam STATE_ERROR_GENERAL        = 'h6;
  localparam STATE_ERROR_BUFFER_OVERRUN = 'hf;

  localparam [ADDR_WIDTH-1:0] ADDRESS_FULL        = ~ 'b0;
  localparam [ADDR_WIDTH-1:0] ADDRESS_ALMOST_FULL = (~ 'b0) - 1;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg                  current_mem_we;
  reg                  current_mem_new;
  reg                  current_mem_reg;

  reg                  mem_state_we    [1:0];
  reg            [3:0] mem_state_new   [1:0];
  reg            [3:0] mem_state_reg   [1:0];

  reg                  ram_wr_en_we    [0:1];
  reg                  ram_wr_en_new   [0:1];
  reg                  ram_wr_en_reg   [0:1];

  reg                  ram_wr_data_we  [0:1];
  reg           [63:0] ram_wr_data_new [0:1];
  reg           [63:0] ram_wr_data_reg [0:1];

  reg                  ram_addr_we     [0:1];
  reg [ADDR_WIDTH-1:0] ram_addr_new    [0:1];
  reg [ADDR_WIDTH-1:0] ram_addr_reg    [0:1];

  reg                  word_count_we   [0:1];
  reg [ADDR_WIDTH-1:0] word_count_new  [0:1];
  reg [ADDR_WIDTH-1:0] word_count_reg  [0:1];

  //----------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------

  wire           [63:0] ram_rd_data [1:0];

  wire                  parser;
  wire                  fifo;
  wire [ADDR_WIDTH-1:0] fifo_word_count_p1;

  //----------------------------------------------------------------
  // Wire and output assignments
  //----------------------------------------------------------------

  assign parser                          = current_mem_reg;
  assign fifo                            = ~ current_mem_reg;
  assign fifo_word_count_p1              = word_count_reg[ fifo ] + 1; //TODO handle overflow
  assign o_dispatch_tx_packet_available  = mem_state_reg[ fifo ] == STATE_FIFO_OUT;
  assign o_dispatch_tx_fifo_empty        = ram_addr_reg[ fifo ] == fifo_word_count_p1;
  assign o_dispatch_tx_fifo_rd_data      = ram_rd_data[ fifo ];
  assign o_dispatch_tx_bytes_last_word   = 0; //TODO implement
  assign o_parser_current_empty          = mem_state_reg[ parser ] == STATE_EMPTY;
  assign o_parser_current_memory_full    = (mem_state_reg[ parser ] == STATE_HAS_DATA && ram_addr_reg[ parser ] == ADDRESS_FULL) ||
                                           (mem_state_reg[ parser ] == STATE_HAS_DATA && ram_addr_reg[ parser ] == ADDRESS_ALMOST_FULL && i_parser_w_en) ||
                                           (mem_state_reg[ parser ] > STATE_HAS_DATA); //TODO verify

  //----------------------------------------------------------------
  // Memory holding the Tx buffer
  //----------------------------------------------------------------

  bram #(ADDR_WIDTH,64) mem0 (
     .i_clk(i_clk),
     .i_addr(ram_addr_reg[0]),
     .i_write(ram_wr_en_reg[0]),
     .i_data(ram_wr_data_reg[0]),
     .o_data(ram_rd_data[0])
  );

  bram #(ADDR_WIDTH,64) mem1 (
     .i_clk(i_clk),
     .i_addr(ram_addr_reg[1]),
     .i_write(ram_wr_en_reg[1]),
     .i_data(ram_wr_data_reg[1]),
     .o_data(ram_rd_data[1])
  );

  //----------------------------------------------------------------
  // BRAM Synchronous register updates
  //----------------------------------------------------------------

  always @ (posedge i_clk)
  begin : bram_reg_update
    integer i;
    for (i = 0; i < 2; i = i + 1) begin
      if (i_areset == 1'b1) begin // synchronous reset
        ram_addr_reg[i]    <= 'b0;
        ram_wr_data_reg[i] <= 'b0;
        ram_wr_en_reg[i]   <= 'b0;
      end else begin
        if (ram_addr_we[i])
          ram_addr_reg[i] <= ram_addr_new[i];

        if (ram_wr_data_we[i])
          ram_wr_data_reg[i] <= ram_wr_data_new[i];

        if (ram_wr_en_we[i])
          ram_wr_en_reg[i] <= ram_wr_en_new[i];
      end
    end
  end

  //----------------------------------------------------------------
  // Asynchronous register updates
  //----------------------------------------------------------------

  always @ (posedge i_clk, posedge i_areset)
  begin : reg_update
    integer i;
    if (i_areset == 1'b1) begin
      current_mem_reg   <= 'b0;
      for (i = 0; i < 2; i = i + 1) begin
        mem_state_reg[i] <= 'b0;
        word_count_reg[i] <= 'b0;
      end
    end else begin
      if (current_mem_we)
        current_mem_reg <= current_mem_new;
      for (i = 0; i < 2; i = i + 1) begin
        if (mem_state_we[i])
          mem_state_reg[i] <= mem_state_new[i];
        if (word_count_we[i])
          word_count_reg[i] <= word_count_new[i];
      end
    end
  end

  always @*
  begin
    current_mem_we = 0;
    current_mem_new = 0;

    begin : defaults
      integer i;
      for (i = 0; i < 2; i = i + 1) begin
        mem_state_we[i] = 0;
        mem_state_new[i] = STATE_EMPTY;

        ram_addr_we[i] = 0;
        ram_addr_new[i] = 0;

        ram_wr_data_we[i]  = 0;
        ram_wr_data_new[i] = 0;

        ram_wr_en_we[i]  = 1;
        ram_wr_en_new[i] = 0;

        word_count_we[i]  = 0;
        word_count_new[i] = 0;
      end
    end

    if (i_parser_clear) begin
      mem_state_we  [parser] = 1;
      mem_state_new [parser] = STATE_EMPTY;
      ram_wr_data_we[parser] = 1;
      ram_wr_en_we  [parser] = 1;
      word_count_we [parser] = 1;
    end else begin
      case ( mem_state_reg[parser] )
        STATE_EMPTY:
          if (i_parser_w_en) begin
            mem_state_we[parser] = 1;
            mem_state_new[parser] = STATE_HAS_DATA;

            ram_addr_we[parser] = 1;

            ram_wr_data_we[parser]  = 1;
            ram_wr_data_new[parser] = i_parser_w_data;

            ram_wr_en_we[parser]  = 1;
            ram_wr_en_new[parser] = 1;

            word_count_we[parser] = 1;
          end
        STATE_HAS_DATA:
          begin
            if (i_parser_w_en) begin
              ram_addr_we[parser] = 1;
              ram_addr_new[parser] = ram_addr_reg[parser] + 1;

              ram_wr_data_we[parser] = 1;
              ram_wr_data_new[parser] = i_parser_w_data;

              ram_wr_en_we[parser]  = 1;
              ram_wr_en_new[parser] = 1;

              word_count_we[parser] = 1;
              word_count_new[parser] = word_count_reg[parser] + 1;
            end else begin
              ram_wr_en_we[parser]  = 1;
              ram_wr_en_new[parser] = 0;
            end
            if (i_parser_ipv4_done || i_parser_ipv6_done) begin
              mem_state_we[parser] = 1;
              mem_state_new[parser] = STATE_FIFO_OUT;
            end
          end
        STATE_FIFO_OUT:
          if (mem_state_reg[fifo] == STATE_EMPTY) begin
            current_mem_we  = 1;
            current_mem_new = ~ current_mem_reg;
            ram_addr_we[parser] = 1;
            ram_addr_new[parser] = 0;
          end
        default ;
      endcase
    end

    // --- FIFO
    case ( mem_state_reg[fifo] )
      STATE_EMPTY: ;
      STATE_FIFO_OUT:
        begin
          //TODO handle overflow
          //if (ram_addr_reg[fifo] == word_count_reg[fifo]) begin
          //  ;
          //end else
          if (i_dispatch_tx_fifo_rd_en) begin
            ram_addr_we  [fifo] = 1;
            ram_addr_new [fifo] = ram_addr_reg[fifo] + 1;
          end
          if (i_dispatch_tx_packet_read) begin
            mem_state_we [fifo] = 1;
            mem_state_new[fifo] = STATE_EMPTY;
            ram_addr_we  [fifo] = 1;
            ram_addr_new [fifo] = 0;
          end
        end
      STATE_ERROR_GENERAL:
        begin
          mem_state_we [fifo] = 1;
          mem_state_new[fifo] = STATE_EMPTY;
          ram_addr_we  [fifo] = 1;
          ram_addr_new [fifo] = 0;
        end
      default:
        begin
          mem_state_we [fifo] = 1;
          mem_state_new[fifo] = STATE_ERROR_GENERAL;
        end
    endcase
  end

endmodule
