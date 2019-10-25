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
  parameter ADDR_WIDTH = 8,
  parameter ACCESS_PORT_WIDTH = 64
) (
  input  wire                         i_areset, // async reset
  input  wire                         i_clk,
  input  wire                         i_clear,

  input  wire                         i_parser_busy,

  input  wire                         i_dispatch_packet_available,
  output wire                         o_dispatch_packet_read,
  input  wire                         i_dispatch_fifo_empty,
  output wire                         o_dispatch_fifo_rd_en,
  input  wire                  [63:0] i_dispatch_fifo_rd_data,

  output wire                         o_access_port_wait,
  input  wire      [ADDR_WIDTH+3-1:0] i_access_port_addr,
  input  wire                   [2:0] i_access_port_wordsize,
  input  wire                         i_access_port_rd_en,
  output wire                         o_access_port_rd_dv,
  output wire [ACCESS_PORT_WIDTH-1:0] o_access_port_rd_data
);

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam MEMORY_CTRL_IDLE            = 4'h0;
  localparam MEMORY_CTRL_FIFO_WRITE      = 4'h1;
  localparam MEMORY_CTRL_READ_SIMPLE_DLY = 4'h2;
  localparam MEMORY_CTRL_READ_SIMPLE     = 4'h3;
  localparam MEMORY_CTRL_READ_1ST_DLY    = 4'h4;
  localparam MEMORY_CTRL_READ_1ST        = 4'h5;
  localparam MEMORY_CTRL_READ_2ND        = 4'h6;
  localparam MEMORY_CTRL_ERROR           = 4'hf;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  //---- internal states
  reg                     memctrl_we;
  reg  [3:0]              memctrl_new;
  reg  [3:0]              memctrl_reg;

  //--- internal registers for handling input FIFO
  reg                     dispatch_fifo_rd_en_we;
  reg                     dispatch_fifo_rd_en_new;
  reg                     dispatch_fifo_rd_en_reg;

  reg                     dispatch_packet_read_we;
  reg                     dispatch_packet_read_new;
  reg                     dispatch_packet_read_reg;

  reg                     fifo_addr_we;
  reg  [ADDR_WIDTH-1:0]   fifo_addr_new;
  reg  [ADDR_WIDTH-1:0]   fifo_addr_reg;

  //---- internal registers for handling access port
  reg                         access_addr_lo_we;
  reg                   [2:0] access_addr_lo_new;
  reg                   [2:0] access_addr_lo_reg;
  reg                         access_dv_we;
  reg                         access_dv_new;
  reg                         access_dv_reg;
  reg                         access_out_we;
  reg [ACCESS_PORT_WIDTH-1:0] access_out_new;
  reg [ACCESS_PORT_WIDTH-1:0] access_out_reg;
  reg                         access_wait_we;
  reg                         access_wait_new;
  reg                         access_wait_reg;
  reg                         access_ws_we;
  reg                         access_ws8bit_new;
  reg                         access_ws8bit_reg;
  reg                         access_ws16bit_new;
  reg                         access_ws16bit_reg;
  reg                         access_ws32bit_new;
  reg                         access_ws32bit_reg;
  reg                         access_ws64bit_new;
  reg                         access_ws64bit_reg;

  // ---- internal registers, wires for handling memory access
  reg                     ram_wr_en_we;
  reg                     ram_wr_en_new;
  reg                     ram_wr_en_reg;

  reg                     ram_wr_data_we;
  reg  [63:0]             ram_wr_data_new;
  reg  [63:0]             ram_wr_data_reg;

  reg                     ram_addr_we;
  reg  [ADDR_WIDTH-1:0]   ram_addr_new;
  reg  [ADDR_WIDTH-1:0]   ram_addr_reg;

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  wire [63:0]             ram_rd_data;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign o_access_port_wait     = access_wait_reg;
  assign o_access_port_rd_dv    = access_dv_reg;
  assign o_access_port_rd_data  = access_out_reg;
  assign o_dispatch_packet_read = dispatch_packet_read_reg;
  assign o_dispatch_fifo_rd_en  = dispatch_fifo_rd_en_reg;

  //----------------------------------------------------------------
  // Memory holding the Receive buffer
  //----------------------------------------------------------------

  bram #(ADDR_WIDTH,64) mem (
     .i_clk(i_clk),
     .i_addr(ram_addr_reg),
     .i_write(ram_wr_en_reg),
     .i_data(ram_wr_data_reg),
     .o_data(ram_rd_data)
  );

  //----------------------------------------------------------------
  // Task copy_from_ram_to_accessout
  // Copies bits from RAM (ram_rd_data) to access_out_new
  // Avoids accessing beyond ACCESS_PORT_WIDTH bits, i.e. this task
  // avoids lint and optimization warnings upon 64bit mode present
  // when design is restricted to 32bit or 16 bit support.
  //----------------------------------------------------------------
  task copy_from_ram_to_accessout;
    inout [ACCESS_PORT_WIDTH-1:0] dst;
    input                 integer dst_start;
    input                  [63:0] src;
    input                 integer src_start;
    input                 integer bits;
    begin : copy_from_ram_to_accessout_locals
      integer i;
      //$display("%s:%0d copy_from_ram_to_accessout_locals(dst, %0d, src, %0d, %0d)", `__FILE__, `__LINE__, dst_start, src_start, bits);
      for (i = 0; i < bits; i=i+1) begin : copy_from_ram_to_accessout_loop_locals
        integer ram_offset;
        integer access_out_offset;
        ram_offset = src_start + i;
        access_out_offset = dst_start + i;
        if (access_out_offset < ACCESS_PORT_WIDTH) begin
          dst[access_out_offset] = src[ram_offset];
        end
      end
    end
  endtask


  //----------------------------------------------------------------
  // Register Update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active high reset.
  //----------------------------------------------------------------

  always @ (posedge i_clk, posedge i_areset)
  begin : reg_update
    if (i_areset == 1'b1) begin
      access_addr_lo_reg       <= 'b0;
      access_dv_reg            <= 'b0;
      access_out_reg           <= 'b0;
      access_wait_reg          <= 'b0;
      access_ws8bit_reg        <= 'b0;
      access_ws16bit_reg       <= 'b0;
      access_ws32bit_reg       <= 'b0;
      access_ws64bit_reg       <= 'b0;
      fifo_addr_reg            <= 'b0;
      dispatch_fifo_rd_en_reg  <= 'b0;
      dispatch_packet_read_reg <= 'b0;
      memctrl_reg              <= 'b0;
    end else begin
      if (access_out_we)
        access_out_reg         <= access_out_new;

      if (access_dv_we)
        access_dv_reg          <= access_dv_new;

      if (access_wait_we)
        access_wait_reg        <= access_wait_new;

      if (access_ws_we) begin
        access_ws8bit_reg      <= access_ws8bit_new;
        access_ws16bit_reg     <= access_ws16bit_new;
        access_ws32bit_reg     <= access_ws32bit_new;
        access_ws64bit_reg     <= access_ws64bit_new;
      end

      if (access_addr_lo_we)
        access_addr_lo_reg     <= access_addr_lo_new;

     if (fifo_addr_we)
       fifo_addr_reg           <= fifo_addr_new;

     if (dispatch_fifo_rd_en_we)
       dispatch_fifo_rd_en_reg <= dispatch_fifo_rd_en_new;

     if (dispatch_packet_read_we)
       dispatch_packet_read_reg <= dispatch_packet_read_new;

     if (memctrl_we)
       memctrl_reg             <= memctrl_new;
    end
  end

  //----------------------------------------------------------------
  // RAM Register Update
  // Update functionality for BRAM in the core.
  // All registers are positive edge triggered.
  // Reset is synchronious active high to conform to BRAM rules.
  //----------------------------------------------------------------

  always @ (posedge i_clk)
  begin : ram_reg_update
    if (i_areset == 1'b1 /* used synchroniously here */) begin
     ram_addr_reg       <= 'b0;
     ram_wr_en_reg      <= 'b0;
     ram_wr_data_reg    <= 'b0;
    end else begin
      if (ram_addr_we)
        ram_addr_reg    <= ram_addr_new;

      if (ram_wr_en_we)
        ram_wr_en_reg   <= ram_wr_en_new;

      if (ram_wr_data_we)
        ram_wr_data_reg <= ram_wr_data_new;
    end
  end

  //----------------------------------------------------------------
  // Finite State Machine
  // Overall functionallity control
  //----------------------------------------------------------------

  always @*
  begin : FSM
    memctrl_we              = 'b0;
    memctrl_new             = MEMORY_CTRL_IDLE;

    case (memctrl_reg)
      MEMORY_CTRL_IDLE:
        if (i_dispatch_packet_available && i_dispatch_fifo_empty == 0 && i_parser_busy == 0) begin
          memctrl_we              = 'b1;
          memctrl_new             = MEMORY_CTRL_FIFO_WRITE;

        end else if (i_access_port_rd_en) begin
          case (i_access_port_wordsize)
            0: begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_SIMPLE_DLY;
              end
            1: if (i_access_port_addr[2:0] != 7) begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_SIMPLE_DLY;
              end else begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_1ST_DLY;
              end
            2: if (i_access_port_addr[2:0] < 5) begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_SIMPLE_DLY;
              end else begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_1ST_DLY;
              end
            3: if (i_access_port_addr[2:0] == 'b0) begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_SIMPLE_DLY;
              end else begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_1ST_DLY;
              end
            default:
              begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_ERROR;
              end
          endcase
        end
      MEMORY_CTRL_FIFO_WRITE:
        if (i_dispatch_fifo_empty == 'b0) begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_FIFO_WRITE;
        end else begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_IDLE;
        end
      MEMORY_CTRL_READ_SIMPLE_DLY:
        begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_READ_SIMPLE;
        end
      MEMORY_CTRL_READ_SIMPLE:
        begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_IDLE;
          if (access_ws16bit_reg && access_addr_lo_reg >= 7)
            memctrl_new  = MEMORY_CTRL_ERROR;
          else if (access_ws32bit_reg && access_addr_lo_reg >= 5)
            memctrl_new  = MEMORY_CTRL_ERROR;
          else if (access_ws64bit_reg && access_addr_lo_reg >= 1)
            memctrl_new  = MEMORY_CTRL_ERROR;
        end
      MEMORY_CTRL_READ_1ST_DLY:
        begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_READ_1ST;
        end
      MEMORY_CTRL_READ_1ST:
        begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_READ_2ND;

          if (access_ws8bit_reg)
            memctrl_new         = MEMORY_CTRL_ERROR;

          else if (access_ws16bit_reg && access_addr_lo_reg < 7)
            memctrl_new         = MEMORY_CTRL_ERROR;

          else if (access_ws32bit_reg && access_addr_lo_reg < 5)
            memctrl_new         = MEMORY_CTRL_ERROR;

          else if (access_ws64bit_reg && access_addr_lo_reg == 0)
            memctrl_new         = MEMORY_CTRL_ERROR;

        end
      MEMORY_CTRL_READ_2ND:
        begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_IDLE;

          if (access_ws8bit_reg)
            memctrl_new         = MEMORY_CTRL_ERROR;

          else if (access_ws16bit_reg && access_addr_lo_reg < 7)
            memctrl_new         = MEMORY_CTRL_ERROR;

          else if (access_ws32bit_reg && access_addr_lo_reg < 5)
            memctrl_new         = MEMORY_CTRL_ERROR;

          else if (access_ws64bit_reg && access_addr_lo_reg == 0)
            memctrl_new         = MEMORY_CTRL_ERROR;

        end
      MEMORY_CTRL_ERROR:
        begin
          $display("%s:%0d WARNING: Memory controller error state detected!", `__FILE__, `__LINE__);
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_IDLE;
        end
      default:
        begin
          //$display("%s:%0d Unimplemented memory state: %0d", `__FILE__, `__LINE__, memctrl_reg);
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_ERROR;
        end
    endcase
  end

  //----------------------------------------------------------------
  // RAM Control
  //----------------------------------------------------------------

  always @*
  begin : ram_control
    ram_addr_we                     = 'b0;
    ram_wr_en_we                    = 'b0;
    ram_wr_data_we                  = 'b0;

    ram_addr_new                    = 'b0;
    ram_wr_en_new                   = 'b0;
    ram_wr_data_new                 = 'b0;

    case (memctrl_reg)
      MEMORY_CTRL_IDLE:
        begin
          ram_addr_we               = 'b1; //write zero addr
          ram_wr_en_we              = 'b1; //write zero wr (i.e. read)

          if (i_dispatch_packet_available && i_dispatch_fifo_empty == 0) begin
            ;
          end else if (i_access_port_rd_en) begin
            ram_addr_we             = 'b1;
            ram_addr_new            = i_access_port_addr[ADDR_WIDTH+3-1:3];
          end
        end
      MEMORY_CTRL_FIFO_WRITE:
        if (i_dispatch_fifo_empty == 'b0) begin
          ram_addr_we             = 'b1;
          ram_addr_new            = fifo_addr_reg;
          ram_wr_en_we            = 'b1;
          ram_wr_en_new           = 'b1;
          ram_wr_data_we          = 'b1;
          ram_wr_data_new         = i_dispatch_fifo_rd_data;
        end
      MEMORY_CTRL_READ_1ST_DLY:
        begin
          ram_addr_we  = 'b1;
          ram_addr_new = ram_addr_reg + 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // FIFO control
  //----------------------------------------------------------------

  always @*
  begin : fifo_control
    fifo_addr_we                  = 'b0;
    dispatch_fifo_rd_en_we        = 'b0;
    dispatch_packet_read_we       = 'b1;

    fifo_addr_new                 = 'b0;
    dispatch_fifo_rd_en_new       = 'b0;
    dispatch_packet_read_new      = 'b0;

    case (memctrl_reg)
      MEMORY_CTRL_IDLE:
        begin
          dispatch_fifo_rd_en_we  = 'b1; // write zero to rd_en
          if (i_dispatch_packet_available && i_dispatch_fifo_empty == 0) begin
            fifo_addr_we          = 'b1; // write zero to fifo_addr_reg
          end
        end
      MEMORY_CTRL_FIFO_WRITE:
        if (i_dispatch_fifo_empty == 'b0) begin
          dispatch_fifo_rd_en_we  = (dispatch_fifo_rd_en_reg == 'b0);
          dispatch_fifo_rd_en_new = 'b1;
          fifo_addr_we            = 'b1;
          fifo_addr_new           = fifo_addr_reg + 1;
        end else begin
          dispatch_fifo_rd_en_we  = 'b1;
          dispatch_fifo_rd_en_new = 'b0;
          dispatch_packet_read_we  = 'b1;
          dispatch_packet_read_new = 'b1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Access port
  // Allows naligned reads
  //----------------------------------------------------------------

  always @*
  begin : acess_port_control
    access_addr_lo_we             = 'b0;
    access_addr_lo_new            = 'b0;
    access_dv_we                  = 'b0;
    access_dv_new                 = 'b0;
    access_out_we                 = 'b0;
    access_out_new                = 'b0;
    access_wait_we                = 'b0;
    access_wait_new               = 'b0;
    access_ws_we                  = 'b0;
    access_ws8bit_new             = 'b0;
    access_ws16bit_new            = 'b0;
    access_ws32bit_new            = 'b0;
    access_ws64bit_new            = 'b0;
    case (memctrl_reg)
      MEMORY_CTRL_IDLE:
        begin
          access_dv_we            = 'b1;
          access_wait_we          = 'b1;

          access_dv_new           = 'b0;

          if (i_dispatch_packet_available && i_dispatch_fifo_empty == 0) begin
            ;
          end else if (i_access_port_rd_en) begin
            access_ws_we          = 'b1;
            access_addr_lo_we     = 'b1;

            access_wait_new       = 'b1;
            access_addr_lo_new    = i_access_port_addr[2:0];
            case (i_access_port_wordsize)
              0: access_ws8bit_new  = 'b1;
              1: access_ws16bit_new = 'b1;
              2: access_ws32bit_new = 'b1;
              3: access_ws64bit_new = 'b1;
              default: ;
            endcase
          end
        end
      MEMORY_CTRL_READ_SIMPLE:
        begin
          access_dv_we            = 'b1;
          access_dv_new           = 'b1;
          access_out_we           = 'b1;
          access_out_new          = 'b0;
          access_wait_we          = 'b1;
          access_wait_new         = 'b0;
          if (access_ws8bit_reg)
              case (access_addr_lo_reg)
                0: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 56, 8);
                1: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 48, 8);
                2: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 40, 8);
                3: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 32, 8);
                4: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 24, 8);
                5: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 16, 8);
                6: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 8, 8);
                7: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 0, 8);
                default: ;
              endcase
          else if (access_ws16bit_reg)
              case (access_addr_lo_reg)
                0: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 48, 16);
                1: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 40, 16);
                2: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 32, 16);
                3: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 24, 16);
                4: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 16, 16);
                5: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 8, 16);
                6: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 0, 16);
                default: ;
              endcase
          else if (access_ws32bit_reg)
            case (access_addr_lo_reg)
              0: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 32, 32);
              1: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 24, 32);
              2: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 16, 32);
              3: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 8, 32);
              4: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 0, 32);
              default: ;
            endcase
          else if (access_ws64bit_reg)
            case (access_addr_lo_reg)
              0: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 0, 64);
              default: ;
            endcase
        end
      MEMORY_CTRL_READ_1ST:
        begin
          access_out_we           = 'b1;
          access_out_new          = 0;
          if (access_ws16bit_reg)
            case (access_addr_lo_reg)
              7: copy_from_ram_to_accessout(access_out_new, 8, ram_rd_data, 0, 8);
              default: ;
            endcase
          else if (access_ws32bit_reg)
            case (access_addr_lo_reg)
              5: copy_from_ram_to_accessout(access_out_new, 8, ram_rd_data, 0, 24);
              6: copy_from_ram_to_accessout(access_out_new, 16, ram_rd_data, 0, 16);
              7: copy_from_ram_to_accessout(access_out_new, 24, ram_rd_data, 0, 8);
              default: ;
            endcase
          else if (access_ws64bit_reg)
            case (access_addr_lo_reg)
              1: copy_from_ram_to_accessout(access_out_new, 8, ram_rd_data, 0, 56);
              2: copy_from_ram_to_accessout(access_out_new, 16, ram_rd_data, 0, 48);
              3: copy_from_ram_to_accessout(access_out_new, 24, ram_rd_data, 0, 40);
              4: copy_from_ram_to_accessout(access_out_new, 32, ram_rd_data, 0, 32);
              5: copy_from_ram_to_accessout(access_out_new, 40, ram_rd_data, 0, 24);
              6: copy_from_ram_to_accessout(access_out_new, 48, ram_rd_data, 0, 16);
              7: copy_from_ram_to_accessout(access_out_new, 56, ram_rd_data, 0, 8);
              default: ;
            endcase
        end
      MEMORY_CTRL_READ_2ND:
        begin
          access_dv_we            = 'b1;
          access_dv_new           = 'b1;
          access_out_we           = 'b1;
          access_out_new          = access_out_reg;
          access_wait_we          = 'b1;
          access_wait_new         = 'b0;
          if ( access_ws16bit_reg)
            case (access_addr_lo_reg)
              7: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 56, 8);
              default: ;
            endcase
          else if (access_ws32bit_reg)
            case (access_addr_lo_reg)
              5: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 56, 8);
              6: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 48, 16);
              7: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 40, 24);
              default: ;
            endcase
          else if (access_ws64bit_reg)
            case (access_addr_lo_reg)
              1: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 56, 8);
              2: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 48, 16);
              3: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 40, 24);
              4: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 32, 32);
              5: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 24, 40);
              6: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 16, 48);
              7: copy_from_ram_to_accessout(access_out_new, 0, ram_rd_data, 8, 56);
              default: ;
            endcase
        end
      default ;
    endcase
  end
endmodule
