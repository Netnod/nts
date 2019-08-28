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

module nts_rx_buffer #(
  parameter ADDR_WIDTH = 10
) (
  input  wire                    i_areset, // async reset
  input  wire                    i_clk,
  input  wire                    i_clear,
  input  wire                    i_dispatch_packet_available,
  input  wire                    i_dispatch_fifo_empty,
  output wire                    o_dispatch_fifo_rd_en,
  input  wire [63:0]             i_dispatch_fifo_rd_data,
  output wire                    o_access_port_wait,
  input  wire [ADDR_WIDTH+3-1:0] i_access_port_addr,
  input  wire [2:0]              i_access_port_wordsize,
  input  wire                    i_access_port_rd_en,
  output wire                    o_access_port_rd_dv,
  output wire [63:0]             o_access_port_rd_data
);

  localparam MEMORY_CTRL_IDLE            = 4'h0;
  localparam MEMORY_CTRL_FIFO_WRITE      = 4'h1;
  localparam MEMORY_CTRL_READ_SIMPLE_DLY = 4'h2;
  localparam MEMORY_CTRL_READ_SIMPLE     = 4'h3;
  localparam MEMORY_CTRL_READ_1ST_DLY    = 4'h4;
  localparam MEMORY_CTRL_READ_1ST        = 4'h5;
  localparam MEMORY_CTRL_READ_2ND        = 4'h6;
  localparam MEMORY_CTRL_ERROR           = 4'hf;

  //---- internal states
  reg  [3:0]              memctrl;

  //--- internal registers for handling input FIFO
  reg                     dispatch_fifo_rd_en;
  reg  [ADDR_WIDTH-1:0]   fifo_addr;

  //---- internal registers for handling access port
  reg  [2:0]              access_ws;
  reg  [63:0]             access_out;
  reg                     access_wait;
  reg                     access_dv;
  reg  [2:0]              access_addr_lo;

  // ---- internal registers, wires for handling memory access
  wire [63:0]             ram_rd_data;
  reg                     ram_wr_en;
  reg  [63:0]             ram_wr_data;
  reg  [ADDR_WIDTH-1:0]   ram_addr;

  assign o_access_port_wait    = access_wait;
  assign o_access_port_rd_dv   = access_dv;
  assign o_access_port_rd_data = access_out;
  assign o_dispatch_fifo_rd_en = dispatch_fifo_rd_en;

  bram #(ADDR_WIDTH,64) mem (
     .i_clk(i_clk),
     .i_addr(ram_addr),
     .i_write(ram_wr_en),
     .i_data(ram_wr_data),
     .o_data(ram_rd_data)
  );

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin
      memctrl                         <= MEMORY_CTRL_IDLE;
      fifo_addr                       <= 'b0;
      dispatch_fifo_rd_en             <= 'b0;
      access_ws                       <= 'b0;
      access_addr_lo                  <= 'b0;
      access_out                      <= 'b0;
      access_dv                       <= 'b0;
      access_wait                     <= 'b0;
      ram_addr                        <= 'b0;
      ram_wr_en                       <= 'b0;
      ram_wr_data                     <= 'b0;
    end else begin
      dispatch_fifo_rd_en             <= 'b0;
      ram_addr                        <= 'b0;
      ram_wr_en                       <= 'b0;
      ram_wr_data                     <= 'b0;
      access_dv                       <= 'b0;
      case (memctrl)
        MEMORY_CTRL_IDLE:
          begin
            access_ws                 <= 'b0;
            access_out                <= 'b0;
            access_wait               <= 'b0;
            ram_addr                  <= 'b0;
            ram_wr_en                 <= 'b0;
            ram_wr_data               <= 'b0;
            if (i_dispatch_packet_available && i_dispatch_fifo_empty == 0) begin
              fifo_addr               <= 'b0;
              memctrl                 <= MEMORY_CTRL_FIFO_WRITE;
            end else if (i_access_port_rd_en) begin
              access_ws        <= i_access_port_wordsize;
              access_addr_lo   <= i_access_port_addr[2:0];
              ram_addr         <= i_access_port_addr[ADDR_WIDTH+3-1:3];
              access_wait <= 'b1;
              case (i_access_port_wordsize)
                0: memctrl <= MEMORY_CTRL_READ_SIMPLE_DLY;
                1: if (i_access_port_addr[2:0] != 7) memctrl  <= MEMORY_CTRL_READ_SIMPLE_DLY; else memctrl <= MEMORY_CTRL_READ_1ST_DLY;
                2: if (i_access_port_addr[2:0] < 5) memctrl <= MEMORY_CTRL_READ_SIMPLE_DLY; else memctrl <= MEMORY_CTRL_READ_1ST_DLY;
                3: if (i_access_port_addr[2:0] == 'b0) memctrl <= MEMORY_CTRL_READ_SIMPLE_DLY; else memctrl <= MEMORY_CTRL_READ_1ST_DLY;
                default: memctrl <= MEMORY_CTRL_ERROR;
              endcase
            end
          end
        MEMORY_CTRL_FIFO_WRITE:
          if (i_dispatch_fifo_empty == 'b0) begin
            dispatch_fifo_rd_en     <= 'b1;
            fifo_addr               <= fifo_addr + 1;
            ram_addr                <= fifo_addr;
            ram_wr_en               <= 'b1;
            ram_wr_data             <= i_dispatch_fifo_rd_data;
            memctrl                 <= MEMORY_CTRL_FIFO_WRITE;
          end else
            memctrl                 <= MEMORY_CTRL_IDLE;
        MEMORY_CTRL_READ_SIMPLE_DLY:
            memctrl                 <= MEMORY_CTRL_READ_SIMPLE;
        MEMORY_CTRL_READ_SIMPLE:
          begin
            memctrl            <= MEMORY_CTRL_IDLE;
            access_wait        <= 'b0;
            access_dv          <= 'b1;
            case (access_ws)
              0:
                case (access_addr_lo)
                  0: access_out <= { 56'b0, ram_rd_data[63:56] };
                  1: access_out <= { 56'b0, ram_rd_data[55:48] };
                  2: access_out <= { 56'b0, ram_rd_data[47:40] };
                  3: access_out <= { 56'b0, ram_rd_data[39:32] };
                  4: access_out <= { 56'b0, ram_rd_data[31:24] };
                  5: access_out <= { 56'b0, ram_rd_data[23:16] };
                  6: access_out <= { 56'b0, ram_rd_data[15:8] };
                  7: access_out <= { 56'b0, ram_rd_data[7:0] };
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              1:
                case (access_addr_lo)
                  0: access_out <= { 48'b0, ram_rd_data[63:48] };
                  1: access_out <= { 48'b0, ram_rd_data[55:40] };
                  2: access_out <= { 48'b0, ram_rd_data[47:32] };
                  3: access_out <= { 48'b0, ram_rd_data[39:24] };
                  4: access_out <= { 48'b0, ram_rd_data[31:16] };
                  5: access_out <= { 48'b0, ram_rd_data[23:8] };
                  6: access_out <= { 48'b0, ram_rd_data[15:0] };
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              2:
                case (access_addr_lo)
                  0: access_out <= { 32'b0, ram_rd_data[63:32] };
                  1: access_out <= { 32'b0, ram_rd_data[55:24] };
                  2: access_out <= { 32'b0, ram_rd_data[47:16] };
                  3: access_out <= { 32'b0, ram_rd_data[39:8] };
                  4: access_out <= { 32'b0, ram_rd_data[31:0] };
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              3:
                case (access_addr_lo)
                  0: access_out <= ram_rd_data[63:0] ;
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              default: memctrl <= MEMORY_CTRL_ERROR;
            endcase
           end
        MEMORY_CTRL_READ_1ST_DLY:
          begin
            ram_addr <= ram_addr + 1;
            memctrl  <= MEMORY_CTRL_READ_1ST;
          end
        MEMORY_CTRL_READ_1ST:
          begin
            memctrl                       <= MEMORY_CTRL_READ_2ND;
            case (access_ws)
              1:
                case (access_addr_lo)
                  7: access_out <= { 48'b0, ram_rd_data[7:0], 8'b0 };
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              2:
                case (access_addr_lo)
                  5: access_out <= { 32'b0, ram_rd_data[23:0], 8'b0 };
                  6: access_out <= { 32'b0, ram_rd_data[15:0], 16'b0 };
                  7: access_out <= { 32'b0, ram_rd_data[7:0], 24'b0 };
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              3:
                case (access_addr_lo)
                  1: access_out <= { ram_rd_data[55:0], 8'b0 };
                  2: access_out <= { ram_rd_data[47:0], 16'b0 };
                  3: access_out <= { ram_rd_data[39:0], 24'b0 };
                  4: access_out <= { ram_rd_data[31:0], 32'b0 };
                  5: access_out <= { ram_rd_data[23:0], 40'b0 };
                  6: access_out <= { ram_rd_data[15:0], 48'b0 };
                  7: access_out <= { ram_rd_data[7:0], 56'b0 };
                endcase
              default: memctrl <= MEMORY_CTRL_ERROR;
            endcase

          end
        MEMORY_CTRL_READ_2ND:
          begin
            memctrl            <= MEMORY_CTRL_IDLE;
            access_wait        <= 'b0;
            access_dv          <= 'b1;
            case (access_ws)
              1:
                case (access_addr_lo)
                  7: access_out <= { 48'b0, access_out[15:8], ram_rd_data[63:56]};
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              2:
                case (access_addr_lo)
                  5: access_out <= { 32'b0, access_out[31:8], ram_rd_data[63:56] };
                  6: access_out <= { 32'b0, access_out[31:16], ram_rd_data[63:48] };
                  7: access_out <= { 32'b0, access_out[31:24], ram_rd_data[63:40] };
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              3:
                case (access_addr_lo)
                  1: access_out <= { access_out[63:8], ram_rd_data[63:56] };
                  2: access_out <= { access_out[63:16], ram_rd_data[63:48] };
                  3: access_out <= { access_out[63:24], ram_rd_data[63:40] };
                  4: access_out <= { access_out[63:32], ram_rd_data[63:32] };
                  5: access_out <= { access_out[63:40], ram_rd_data[63:24] };
                  6: access_out <= { access_out[63:48], ram_rd_data[63:16] };
                  7: access_out <= { access_out[63:56], ram_rd_data[63:8] };
                  default: memctrl <= MEMORY_CTRL_ERROR;
                endcase
              default: memctrl <= MEMORY_CTRL_ERROR;
            endcase
          end
        MEMORY_CTRL_ERROR:
          begin
            $display("%s:%0d WARNING: Memory controller error state detected!", `__FILE__, `__LINE__);
            memctrl <= MEMORY_CTRL_IDLE;
          end
        default:
          begin
            $display("%s:%0d Unimplemented memory state: %0d", `__FILE__, `__LINE__, memctrl);
            memctrl <= MEMORY_CTRL_IDLE;
          end
      endcase
    end
  end
endmodule
