//======================================================================
//
// nts_extractor_tx.v
// ------------------
// TX control for the NTS packet extractor.
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

module nts_extractor_tx #(
  parameter ADDR_WIDTH = 8
) (
  input  wire i_areset, // async reset
  input  wire i_clk,

  input  wire                  buffer0_ready,
  output wire                  buffer0_start,
  output wire                  buffer0_stop,
  input  wire [ADDR_WIDTH-1:0] buffer0_wr_addr,
  input  wire                  buffer0_wr_en,
  input  wire           [63:0] buffer0_wr_data,
  input  wire [ADDR_WIDTH-1:0] buffer0_length,
  input  wire            [3:0] buffer0_lwdv,

  input  wire                  buffer1_ready,
  output wire                  buffer1_start,
  output wire                  buffer1_stop,
  input  wire [ADDR_WIDTH-1:0] buffer1_wr_addr,
  input  wire                  buffer1_wr_en,
  input  wire           [63:0] buffer1_wr_data,
  input  wire [ADDR_WIDTH-1:0] buffer1_length,
  input  wire            [3:0] buffer1_lwdv,

  input  wire                  buffer2_ready,
  output wire                  buffer2_start,
  output wire                  buffer2_stop,
  input  wire [ADDR_WIDTH-1:0] buffer2_wr_addr,
  input  wire                  buffer2_wr_en,
  input  wire           [63:0] buffer2_wr_data,
  input  wire [ADDR_WIDTH-1:0] buffer2_length,
  input  wire            [3:0] buffer2_lwdv,

  input  wire                  buffer3_ready,
  output wire                  buffer3_start,
  output wire                  buffer3_stop,
  input  wire [ADDR_WIDTH-1:0] buffer3_wr_addr,
  input  wire                  buffer3_wr_en,
  input  wire           [63:0] buffer3_wr_data,
  input  wire [ADDR_WIDTH-1:0] buffer3_length,
  input  wire            [3:0] buffer3_lwdv,

  output wire        o_mac_tx_start,
  input  wire        i_mac_tx_ack,
  output wire  [7:0] o_mac_tx_data_valid,
  output wire [63:0] o_mac_tx_data
);
  //----------------------------------------------------------------
  // Local parameters, constants, definitions etc
  //----------------------------------------------------------------

  localparam BUFFERS  = 4;
  localparam BSELADDR = 2;

  localparam TX_IDLE      = 3'd0;
  localparam TX_AWAIT_ACK = 3'd1;
  localparam TX_WRITE     = 3'd2;

  //----------------------------------------------------------------
  // Wires that array-mirrors the input wires
  //----------------------------------------------------------------

  wire [ADDR_WIDTH-1 : 0] b_length [0:BUFFERS-1];
  wire    [BUFFERS-1 : 0] b_ready;
  wire            [3 : 0] b_lwdv [0:BUFFERS-1];


  assign b_ready[0] = buffer0_ready;
  assign b_ready[1] = buffer1_ready;
  assign b_ready[2] = buffer2_ready;
  assign b_ready[3] = buffer3_ready;

  assign b_length[0] = buffer0_length;
  assign b_length[1] = buffer1_length;
  assign b_length[2] = buffer2_length;
  assign b_length[3] = buffer3_length;

  assign b_lwdv[0] = buffer0_lwdv;
  assign b_lwdv[1] = buffer1_lwdv;
  assign b_lwdv[2] = buffer2_lwdv;
  assign b_lwdv[3] = buffer3_lwdv;

  //----------------------------------------------------------------
  // Registers
  //----------------------------------------------------------------

  reg                buffer_mac_selected_we;
  reg [BSELADDR-1:0] buffer_mac_selected_new;
  reg [BSELADDR-1:0] buffer_mac_selected_reg;

  reg         [7:0] mac_data_valid [0:BUFFERS-1];
  reg        [63:0] mac_data       [0:BUFFERS-1];
  reg [BUFFERS-1:0] mac_start;


  reg [BSELADDR-1:0] tx_buffer;
  reg                tx_start;
  reg  [BUFFERS-1:0] tx_stop;


  reg    [BUFFERS-1:0] b_start;
  reg    [BUFFERS-1:0] b_stop;
  reg   [BSELADDR-1:0] tx_start_buffer;
  reg [ADDR_WIDTH-1:0] tx_start_last;
  reg            [3:0] tx_start_lwdv;

  //----------------------------------------------------------------
  // Output wires
  //----------------------------------------------------------------


  assign { buffer3_start, buffer2_start, buffer1_start, buffer0_start } = b_start;
  assign { buffer3_stop, buffer2_stop, buffer1_stop, buffer0_stop } = b_stop;

  assign o_mac_tx_data = mac_data[tx_buffer];
  assign o_mac_tx_data_valid = mac_data_valid[tx_buffer];
  assign o_mac_tx_start = mac_start[tx_buffer];

  //----------------------------------------------------------------
  // Register Update (asynchronous reset)
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      buffer_mac_selected_reg <= 0;
    end else begin
      if (buffer_mac_selected_we)
        buffer_mac_selected_reg <= buffer_mac_selected_new;
    end
  end

  //----------------------------------------------------------------
  // MAC Media Access Controller - functions
  //----------------------------------------------------------------

  function [63:0] mac_byte_txreverse( input [63:0] txd, input [7:0] txv );
  begin : txreverse
    reg [63:0] out;
    out[0+:8]  = txv[0] ? txd[56+:8] : 8'h00;
    out[8+:8]  = txv[1] ? txd[48+:8] : 8'h00;
    out[16+:8] = txv[2] ? txd[40+:8] : 8'h00;
    out[24+:8] = txv[3] ? txd[32+:8] : 8'h00;
    out[32+:8] = txv[4] ? txd[24+:8] : 8'h00;
    out[40+:8] = txv[5] ? txd[16+:8] : 8'h00;
    out[48+:8] = txv[6] ? txd[8+:8]  : 8'h00;
    out[56+:8] = txv[7] ? txd[0+:8]  : 8'h00;
    mac_byte_txreverse = out;
  end
  endfunction

  function [7:0] mac_last_word_data_valid_expander( input [3:0] lwdv );
  begin : lwdv_expander
    reg [7:0] x;
    case (lwdv)
      default: x = 8'b0000_0000;
      1: x = 8'b0000_0001;
      2: x = 8'b0000_0011;
      3: x = 8'b0000_0111;
      4: x = 8'b0000_1111;
      5: x = 8'b0001_1111;
      6: x = 8'b0011_1111;
      7: x = 8'b0111_1111;
      8: x = 8'b1111_1111;
    endcase
    mac_last_word_data_valid_expander = x;
  end
  endfunction

  //----------------------------------------------------------------
  // MAC Media Access Controller
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
    if (i_areset == 1'b1) begin
      tx_buffer <= 0;
    end else begin
      if (tx_start)
        tx_buffer <= tx_start_buffer;
    end

  reg [2:0] tx_state [0:BUFFERS-1];

  generate
    genvar i;
    for (i = 0; i < BUFFERS; i = i + 1) begin : tx_instances
      reg [ADDR_WIDTH-1:0] tx_count;
      reg [ADDR_WIDTH-1:0] tx_last;
      reg            [7:0] tx_lwdv;
      reg           [63:0] txmem [ 0 : (1<<ADDR_WIDTH)-1 ];
      reg [ADDR_WIDTH-1:0] txmem_addr;
      reg           [63:0] txmem_wdata;
      reg                  txmem_wren;

      always @(posedge i_clk)
      begin
        case(i)
          0:
            begin
              txmem_addr  <= buffer0_wr_addr;
              txmem_wren  <= buffer0_wr_en;
              txmem_wdata <= buffer0_wr_data;
            end
          1:
            begin
              txmem_addr  <= buffer1_wr_addr;
              txmem_wren  <= buffer1_wr_en;
              txmem_wdata <= buffer1_wr_data;
            end
          2:
            begin
              txmem_addr  <= buffer2_wr_addr;
              txmem_wren  <= buffer2_wr_en;
              txmem_wdata <= buffer2_wr_data;
            end
          3:
            begin
              txmem_addr  <= buffer3_wr_addr;
              txmem_wren  <= buffer3_wr_en;
              txmem_wdata <= buffer3_wr_data;
            end
         endcase
      end

      always @(posedge i_clk)
      begin
        if (txmem_wren) begin
          txmem[txmem_addr] <= txmem_wdata;
        end
      end

      always @(posedge i_clk or posedge i_areset)
      begin

        if (i_areset == 1'b1) begin
          mac_data_valid[i] <= 8'h0;
          mac_data[i] <= 64'h0;
          mac_start[i] <= 1'h0;
          tx_count <= 0;
          tx_last <= 0;
          tx_lwdv <= 0;
          tx_state[i] <= 0;
          tx_stop[i] <= 0;
        end else begin
          tx_stop[i] <= 0;
          mac_data_valid[i] <= 0;
          mac_start[i] <= 0;
          case (tx_state[i])
            TX_IDLE:
              if (tx_start && tx_start_buffer == i[BSELADDR-1:0]) begin

                mac_start[i] <= 1;
                mac_data[i] <= mac_byte_txreverse( txmem[0], 8'hff );
                mac_data_valid[i] <= 8'hff;

                tx_last <= tx_start_last;
                tx_lwdv <= mac_last_word_data_valid_expander( tx_start_lwdv );
                tx_count <= 2;
                tx_state[i] <= TX_AWAIT_ACK;
              end
            TX_AWAIT_ACK:
              if (i_mac_tx_ack) begin
                mac_data[i] <= mac_byte_txreverse( txmem[1], 8'hff );
                mac_data_valid[i] <= 8'hff;
                tx_state[i] <= TX_WRITE;
              end else begin
                mac_data[i] <= mac_data[i];
                mac_data_valid[i] <= mac_data_valid[i];
              end
            TX_WRITE:
              begin
                tx_count <= tx_count + 1;
                if (tx_count >= tx_last) begin
                  mac_data[i] <= mac_byte_txreverse( txmem[tx_count], tx_lwdv );
                  mac_data_valid[i] <= tx_lwdv;

                  tx_state[i] <= TX_IDLE;
                  tx_stop[i] <= 1;
                end else begin
                  mac_data[i] <= mac_byte_txreverse( txmem[tx_count], 8'hff );
                  mac_data_valid[i] <= 8'hff;
                end
              end
            default:
              begin
                mac_start[i]      <= 1'b0;
                mac_data[i]       <= 64'h0;
                mac_data_valid[i] <= 8'h0;
                tx_count          <= 0;
                tx_last           <= 0;
                tx_lwdv           <= 0;
                tx_state[i]       <= TX_IDLE;
                tx_stop[i]        <= 0;
             end
         endcase
        end //not async reset
      end
    end
  endgenerate

  //----------------------------------------------------------------
  // MAC buffer selector
  //----------------------------------------------------------------

  always @*
  begin : mac_buff_select
    reg next;
    reg ready;

    next = 0;
    ready = b_ready[buffer_mac_selected_reg];

    b_start = {BUFFERS{1'b0}};
    b_stop = {BUFFERS{1'b0}};

    buffer_mac_selected_we = 0;
    buffer_mac_selected_new = 0;

    tx_start        = 0;
    tx_start_buffer = 0;
    tx_start_last   = 0;
    tx_start_lwdv   = 0;

    if (tx_stop[buffer_mac_selected_reg]) begin
      b_stop[buffer_mac_selected_reg] = 1'b1;
      next = 1;
    end else begin
      case (tx_state[buffer_mac_selected_reg])
        TX_IDLE:
          if (ready) begin
            b_start[buffer_mac_selected_reg] = 1'b1;
            tx_start = 1;
            tx_start_buffer = buffer_mac_selected_reg;
            tx_start_lwdv = b_lwdv[buffer_mac_selected_reg];
            tx_start_last = b_length[buffer_mac_selected_reg] - 1;
          end else begin
            next = 1;
          end
        default: ;
      endcase
    end
    if (next) begin
      buffer_mac_selected_we = 1;
      buffer_mac_selected_new = buffer_mac_selected_reg + 1;
    end
  end

endmodule
