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
  parameter SUPPORT_8BIT = 0,
  parameter SUPPORT_16BIT = 0,
  parameter SUPPORT_32BIT = 1,
  parameter SUPPORT_64BIT = 1
) (
  input  wire                    i_areset, // async reset
  input  wire                    i_clk,

  input  wire                    i_parser_busy,

  input  wire                    i_dispatch_packet_available,
  output wire                    o_dispatch_packet_read,
  input  wire                    i_dispatch_fifo_empty,
  output wire                    o_dispatch_fifo_rd_start,
  input  wire                    i_dispatch_fifo_rd_valid,
  input  wire             [63:0] i_dispatch_fifo_rd_data,

  output wire                    o_access_port_wait,
  input  wire [ADDR_WIDTH+3-1:0] i_access_port_addr,
  input  wire              [2:0] i_access_port_wordsize,
  input  wire             [15:0] i_access_port_burstsize,
  input  wire                    i_access_port_rd_en,
  output wire                    o_access_port_rd_dv,
  output wire             [63:0] o_access_port_rd_data
);

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam ACCESS_PORT_WIDTH = 64;

  localparam MEMORY_CTRL_IDLE            = 4'h0;

  localparam MEMORY_CTRL_FIFO_WRITE      = 4'h1;

  localparam MEMORY_CTRL_READ_SIMPLE_DLY = 4'h2;
  localparam MEMORY_CTRL_READ_SIMPLE     = 4'h3;
  localparam MEMORY_CTRL_READ_1ST_DLY    = 4'h4;
  localparam MEMORY_CTRL_READ_1ST        = 4'h5;
  localparam MEMORY_CTRL_READ_2ND        = 4'h6;

  localparam MEMORY_CTRL_BURST_DLY       = 4'h7;
  localparam MEMORY_CTRL_BURST_1ST       = 4'h8;
  localparam MEMORY_CTRL_BURST           = 4'h9;

  localparam MEMORY_CTRL_CSUM_DLY        = 4'ha;
  localparam MEMORY_CTRL_CSUM_1ST        = 4'hb;
  localparam MEMORY_CTRL_CSUM            = 4'hc;
  localparam MEMORY_CTRL_CSUM_FINALIZE   = 4'hd;

  localparam MEMORY_CTRL_ERROR           = 4'hf;

  localparam [2:0] MODE_8BIT  = 0;
  localparam [2:0] MODE_16BIT = 1;
  localparam [2:0] MODE_32BIT = 2;
  localparam [2:0] MODE_64BIT = 3;
  localparam [2:0] MODE_BURST = 4;
  localparam [2:0] MODE_CSUM  = 5;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  //---- internal states
  reg                     memctrl_we;
  reg  [3:0]              memctrl_new;
  reg  [3:0]              memctrl_reg;

  //--- internal registers for handling input FIFO

  reg                     dispatch_fifo_rd_start_new;
  reg                     dispatch_fifo_rd_start_reg;
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
  reg                         burst_mem_we;
  reg                  [55:0] burst_mem_new;
  reg                  [55:0] burst_mem_reg;
  reg                         burst_size_we;
  reg                  [15:0] burst_size_new;
  reg                  [15:0] burst_size_reg;


  reg        csum_read_done;
  reg        csum_calculate_done;
  reg        csum_reset;
  reg [15:0] csum_value;

  reg [63:0] csum_block_new;
  reg [63:0] csum_block_reg;
  reg        csum_block_valid_new;
  reg        csum_block_valid_reg;
  reg        csum_mem_we;
  reg [55:0] csum_mem_new;
  reg [55:0] csum_mem_reg;
  reg        csum_size_we;
  reg [15:0] csum_size_new;
  reg [15:0] csum_size_reg;

  reg p0_done_new;
  reg p0_done_reg;

  reg        p1_done_new;
  reg        p1_done_reg;
  reg        p1_carry_a_new;
  reg        p1_carry_a_reg;
  reg        p1_carry_b_new;
  reg        p1_carry_b_reg;
  reg [15:0] p1_sum_a_new;
  reg [15:0] p1_sum_a_reg;
  reg [15:0] p1_sum_b_new;
  reg [15:0] p1_sum_b_reg;

  reg p1_valid_new;
  reg p1_valid_reg;

  reg        p2_carry_a_new;
  reg        p2_carry_a_reg;
  reg        p2_carry_b_new;
  reg        p2_carry_b_reg;
  reg        p2_carry_c_new;
  reg        p2_carry_c_reg;
  reg        p2_done_new;
  reg        p2_done_reg;
  reg [15:0] p2_sum_c_new;
  reg [15:0] p2_sum_c_reg;
  reg        p2_valid_new;
  reg        p2_valid_reg;

  reg        p3_done_new;
  reg        p3_done_reg;
  reg [15:0] p3_csum_new;
  reg [15:0] p3_csum_reg;

  // ---- internal registers for handling synchronous reset of BRAM
  reg sync_reset_metastable;
  reg sync_reset;

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

  reg         burst_done;
  reg         fifo_start;
  reg         fifo_done;
  wire [63:0] ram_rd_data;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign o_access_port_wait       = access_wait_reg;
  assign o_access_port_rd_dv      = access_dv_reg;
  assign o_access_port_rd_data    = access_out_reg;
  assign o_dispatch_packet_read   = dispatch_packet_read_reg;
  assign o_dispatch_fifo_rd_start = dispatch_fifo_rd_start_reg;

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
  // Register Update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active high reset.
  //----------------------------------------------------------------

  always @ (posedge i_clk, posedge i_areset)
  begin : reg_update
    if (i_areset == 1'b1) begin
      access_addr_lo_reg  <= 'b0;
      access_dv_reg       <= 'b0;
      access_out_reg      <= 'b0;
      access_wait_reg     <= 'b0;
      access_ws8bit_reg   <= 'b0;
      access_ws16bit_reg  <= 'b0;
      access_ws32bit_reg  <= 'b0;
      access_ws64bit_reg  <= 'b0;

      burst_mem_reg  <= 'b0;
      burst_size_reg <= 'b0;

      csum_block_reg       <= 'b0;
      csum_block_valid_reg <= 'b0;
      csum_mem_reg         <= 'b0;
      csum_size_reg        <= 'b0;

      fifo_addr_reg              <= 'b0;
      dispatch_fifo_rd_start_reg <= 'b0;
      dispatch_packet_read_reg   <= 'b0;
      memctrl_reg                <= 'b0;

      p0_done_reg    <= 'b0;

      p1_carry_a_reg <= 'b0;
      p1_carry_b_reg <= 'b0;
      p1_done_reg    <= 'b0;
      p1_sum_a_reg   <= 'b0;
      p1_sum_b_reg   <= 'b0;
      p1_valid_reg   <= 'b0;

      p2_carry_a_reg <= 'b0;
      p2_carry_b_reg <= 'b0;
      p2_carry_c_reg <= 'b0;
      p2_done_reg    <= 'b0;
      p2_sum_c_reg   <= 'b0;
      p2_valid_reg   <= 'b0;

      p3_csum_reg    <= 'b0;
      p3_done_reg    <= 'b0;

    end else begin
      if (access_addr_lo_we)
        access_addr_lo_reg <= access_addr_lo_new;

      if (access_out_we)
        access_out_reg  <= access_out_new;

      if (access_dv_we)
        access_dv_reg  <= access_dv_new;

      if (access_wait_we)
        access_wait_reg <= access_wait_new;

      if (access_ws_we) begin
        access_ws8bit_reg  <= access_ws8bit_new;
        access_ws16bit_reg <= access_ws16bit_new;
        access_ws32bit_reg <= access_ws32bit_new;
        access_ws64bit_reg <= access_ws64bit_new;
      end

      if (burst_mem_we)
        burst_mem_reg <= burst_mem_new;

      if (burst_size_we)
        burst_size_reg <= burst_size_new;

      csum_block_reg <= csum_block_new;
      csum_block_valid_reg <= csum_block_valid_new;

      if (csum_mem_we)
        csum_mem_reg <= csum_mem_new;

      if (csum_size_we)
        csum_size_reg <= csum_size_new;

      if (fifo_addr_we)
        fifo_addr_reg <= fifo_addr_new;

      dispatch_fifo_rd_start_reg <= dispatch_fifo_rd_start_new;

      if (dispatch_packet_read_we)
        dispatch_packet_read_reg <= dispatch_packet_read_new;

      if (memctrl_we) begin
        memctrl_reg <= memctrl_new;
      end

      p0_done_reg    <= p0_done_new;

      p1_done_reg    <= p1_done_new;
      p1_carry_a_reg <= p1_carry_a_new;
      p1_carry_b_reg <= p1_carry_b_new;
      p1_sum_a_reg   <= p1_sum_a_new;
      p1_sum_b_reg   <= p1_sum_b_new;
      p1_valid_reg   <= p1_valid_new;

      p2_done_reg    <= p2_done_new;
      p2_carry_a_reg <= p2_carry_a_new;
      p2_carry_b_reg <= p2_carry_b_new;
      p2_carry_c_reg <= p2_carry_c_new;
      p2_sum_c_reg   <= p2_sum_c_new;
      p2_valid_reg   <= p2_valid_new;

      p3_csum_reg  <= p3_csum_new;
      p3_done_reg  <= p3_done_new;
    end
  end

  //----------------------------------------------------------------
  // Synchronous reset conversion
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      sync_reset_metastable <= 1;
      sync_reset <= 1;
    end else begin
      sync_reset_metastable <= 0;
      sync_reset <= sync_reset_metastable;
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
    if (sync_reset) begin
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
  // FIFO start wire
  // Helper reg. Used by FSM and others.
  //----------------------------------------------------------------

  always @*
  begin : fifo_reg_start_proc
    fifo_start = 0;
    case (memctrl_reg)
      MEMORY_CTRL_IDLE:
        if (i_parser_busy == 0)
          if (i_dispatch_packet_available && i_dispatch_fifo_empty == 0)
            fifo_start = 1;
      default: ;
    endcase
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
        if (fifo_start) begin
          memctrl_we              = 'b1;
          memctrl_new             = MEMORY_CTRL_FIFO_WRITE;

        end else if (i_access_port_rd_en) begin
          case (i_access_port_wordsize)
            MODE_8BIT:
              begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_SIMPLE_DLY;
              end
            MODE_16BIT:
              if (i_access_port_addr[2:0] != 7) begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_SIMPLE_DLY;
              end else begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_1ST_DLY;
              end
            MODE_32BIT:
              if (i_access_port_addr[2:0] < 5) begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_SIMPLE_DLY;
              end else begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_1ST_DLY;
              end
            MODE_64BIT:
              if (i_access_port_addr[2:0] == 'b0) begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_SIMPLE_DLY;
              end else begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_READ_1ST_DLY;
              end
            MODE_BURST:
              if (i_access_port_burstsize > 0) begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_BURST_DLY;
              end
            MODE_CSUM:
              if (i_access_port_burstsize > 0) begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_CSUM_DLY;
              end
            default:
              begin
                memctrl_we       = 'b1;
                memctrl_new      = MEMORY_CTRL_ERROR;
              end
          endcase
          //$display("%s:%0d memctrl_we: %h memctrl_new: %h", `__FILE__, `__LINE__, memctrl_we, memctrl_new);
        end
      MEMORY_CTRL_FIFO_WRITE:
        if (fifo_done) begin
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
      MEMORY_CTRL_BURST_DLY:
        begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_BURST_1ST;
        end
      MEMORY_CTRL_BURST_1ST:
        if (burst_done) begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_IDLE;
        end else begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_BURST;
        end
      MEMORY_CTRL_BURST:
        if (burst_done) begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_IDLE;
        end
      MEMORY_CTRL_CSUM_DLY:
        begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_CSUM_1ST;
        end
      MEMORY_CTRL_CSUM_1ST:
        if (csum_read_done) begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_CSUM_FINALIZE;
        end else begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_CSUM;
        end
      MEMORY_CTRL_CSUM:
        if (csum_read_done) begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_CSUM_FINALIZE;
        end
      MEMORY_CTRL_CSUM_FINALIZE:
        if (csum_calculate_done) begin
          memctrl_we            = 'b1;
          memctrl_new           = MEMORY_CTRL_IDLE;
        end
      MEMORY_CTRL_ERROR:
        begin
          //$display("%s:%0d WARNING: Memory controller error state detected!", `__FILE__, `__LINE__);
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
    reg sequential_access;

    sequential_access = 0;

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

          if (fifo_start) begin
            ;
          end else if (i_access_port_rd_en) begin
            ram_addr_we             = 'b1;
            ram_addr_new            = i_access_port_addr[ADDR_WIDTH+3-1:3];
          end
        end
      MEMORY_CTRL_FIFO_WRITE:
        if (i_dispatch_fifo_rd_valid) begin
          ram_addr_we             = 'b1;
          ram_addr_new            = fifo_addr_reg;
          ram_wr_en_we            = 'b1;
          ram_wr_en_new           = 'b1;
          ram_wr_data_we          = 'b1;
          ram_wr_data_new         = i_dispatch_fifo_rd_data;
        end
      MEMORY_CTRL_READ_1ST_DLY: sequential_access = 1;
      MEMORY_CTRL_BURST_DLY:    sequential_access = 1;
      MEMORY_CTRL_BURST_1ST:    sequential_access = 1;
      MEMORY_CTRL_BURST:        sequential_access = 1;
      MEMORY_CTRL_CSUM_DLY:     sequential_access = 1;
      MEMORY_CTRL_CSUM_1ST:     sequential_access = 1;
      MEMORY_CTRL_CSUM:         sequential_access = 1;
      default: ;
    endcase

    if (sequential_access) begin
      ram_addr_we  = 'b1;
      ram_addr_new = ram_addr_reg + 1;
    end
  end

  //----------------------------------------------------------------
  // FIFO control
  //----------------------------------------------------------------

  always @*
  begin : fifo_control
    fifo_addr_we                  = 'b0;
    fifo_addr_new                 = 'b0;

    fifo_done                     = 'b0;

    dispatch_packet_read_we       = 'b1;
    dispatch_packet_read_new      = 'b0;

    dispatch_fifo_rd_start_new = 0;

    case (memctrl_reg)
      MEMORY_CTRL_IDLE:
        begin
          //dispatch_fifo_rd_en_we  = 'b1; // write zero to rd_en
          if (fifo_start) begin
            dispatch_fifo_rd_start_new = 'b1;
            fifo_addr_we               = 'b1; // write zero to fifo_addr_reg
          end
        end
      MEMORY_CTRL_FIFO_WRITE:
        if (i_dispatch_fifo_rd_valid) begin
          fifo_addr_we            = 'b1;
          fifo_addr_new           = fifo_addr_reg + 1;
        end else if (i_dispatch_fifo_empty) begin
          dispatch_packet_read_we  = 'b1;
          dispatch_packet_read_new = 'b1;
          fifo_done                = 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Access port
  // Allows unaligned reads
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

    burst_done = 0;
    burst_size_we = 0;
    burst_size_new = 0;
    burst_mem_we = 0;
    burst_mem_new = 0;

    case (memctrl_reg)
      MEMORY_CTRL_IDLE:
        begin
          access_dv_we    = 'b1;
          access_dv_new   = 'b0;
          access_wait_we  = 'b1;
          access_wait_new = 'b0;


          if (fifo_start) begin
            ;
          end else if (i_access_port_rd_en) begin

            access_addr_lo_we   = 'b1;
            access_addr_lo_new  = i_access_port_addr[2:0];
            burst_size_we       = 1;
            burst_size_new      = i_access_port_burstsize;

            case (i_access_port_wordsize)
              MODE_8BIT:
                 if (SUPPORT_8BIT) begin
                   access_wait_new    = 'b1;
                   access_ws_we       = 'b1;
                   access_ws8bit_new  = 'b1;
                 end
              MODE_16BIT:
                if (SUPPORT_16BIT) begin
                   access_wait_new    = 'b1;
                   access_ws_we       = 'b1;
                   access_ws16bit_new = 'b1;
                 end
              MODE_32BIT:
                 if (SUPPORT_32BIT) begin
                   access_wait_new    = 'b1;
                   access_ws_we       = 'b1;
                   access_ws32bit_new = 'b1;
                 end
              MODE_64BIT:
                 if (SUPPORT_64BIT) begin
                   access_wait_new    = 'b1;
                   access_ws_we       = 'b1;
                   access_ws64bit_new = 'b1;
                 end
              MODE_BURST:
                 if (i_access_port_burstsize != 0) begin
                   access_wait_new    = 'b1;
                   access_ws_we       = 'b1;
                 end
              MODE_CSUM:
                 if (i_access_port_burstsize != 0) begin
                   access_wait_new    = 'b1;
                   access_ws_we       = 'b1;
                 end
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
                0: access_out_new[ 7:0 ] = ram_rd_data[ 56+:8 ];
                1: access_out_new[ 7:0 ] = ram_rd_data[ 48+:8 ];
                2: access_out_new[ 7:0 ] = ram_rd_data[ 40+:8 ];
                3: access_out_new[ 7:0 ] = ram_rd_data[ 32+:8 ];
                4: access_out_new[ 7:0 ] = ram_rd_data[ 24+:8 ];
                5: access_out_new[ 7:0 ] = ram_rd_data[ 16+:8 ];
                6: access_out_new[ 7:0 ] = ram_rd_data[ 8+:8 ];
                7: access_out_new[ 7:0 ] = ram_rd_data[ 0+:8 ];
                default: ;
              endcase
          else if (access_ws16bit_reg)
              case (access_addr_lo_reg)
                0: access_out_new[ 15:0 ] = ram_rd_data[ 48+:16 ];
                1: access_out_new[ 15:0 ] = ram_rd_data[ 40+:16 ];
                2: access_out_new[ 15:0 ] = ram_rd_data[ 32+:16 ];
                3: access_out_new[ 15:0 ] = ram_rd_data[ 24+:16 ];
                4: access_out_new[ 15:0 ] = ram_rd_data[ 16+:16 ];
                5: access_out_new[ 15:0 ] = ram_rd_data[ 8+:16 ];
                6: access_out_new[ 15:0 ] = ram_rd_data[ 0+:16 ];
                default: ;
              endcase
          else if (access_ws32bit_reg)
            case (access_addr_lo_reg)
              0: access_out_new[ 31:0 ] = ram_rd_data[ 32+:32 ];
              1: access_out_new[ 31:0 ] = ram_rd_data[ 24+:32 ];
              2: access_out_new[ 31:0 ] = ram_rd_data[ 16+:32 ];
              3: access_out_new[ 31:0 ] = ram_rd_data[ 8+:32 ];
              4: access_out_new[ 31:0 ] = ram_rd_data[ 0+:32 ];
              default: ;
            endcase
          else if (access_ws64bit_reg)
            case (access_addr_lo_reg)
              0: access_out_new[ 63:0 ] = ram_rd_data[ 0+:64 ];
              default: ;
            endcase
        end
      MEMORY_CTRL_READ_1ST:
        begin
          access_out_we           = 'b1;
          access_out_new          = 0;
          if (access_ws16bit_reg)
            case (access_addr_lo_reg)
              7: access_out_new[ 15:8 ] = ram_rd_data[ 0+:8 ];
              default: ;
            endcase
          else if (access_ws32bit_reg)
            case (access_addr_lo_reg)
              5: access_out_new[  8+:24 ] = ram_rd_data[ 0+:24 ];
              6: access_out_new[ 16+:16 ] = ram_rd_data[ 0+:16 ];
              7: access_out_new[ 24+:8  ] = ram_rd_data[ 0+:8  ];
              default: ;
            endcase
          else if (access_ws64bit_reg)
            case (access_addr_lo_reg)
              1: access_out_new[  8+:56 ] = ram_rd_data[ 0+:56 ];
              2: access_out_new[ 16+:48 ] = ram_rd_data[ 0+:48 ];
              3: access_out_new[ 24+:40 ] = ram_rd_data[ 0+:40 ];
              4: access_out_new[ 32+:32 ] = ram_rd_data[ 0+:32 ];
              5: access_out_new[ 40+:24 ] = ram_rd_data[ 0+:24 ];
              6: access_out_new[ 48+:16 ] = ram_rd_data[ 0+:16 ];
              7: access_out_new[ 56+:8  ] = ram_rd_data[ 0+:8  ];
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
              7: access_out_new[ 0+:8 ] = ram_rd_data[ 56+:8 ];
              default: ;
            endcase
          else if (access_ws32bit_reg)
            case (access_addr_lo_reg)
              5: access_out_new[ 0+:8  ] = ram_rd_data[ 56+:8  ];
              6: access_out_new[ 0+:16 ] = ram_rd_data[ 48+:16 ];
              7: access_out_new[ 0+:24 ] = ram_rd_data[ 40+:24 ];
              default: ;
            endcase
          else if (access_ws64bit_reg)
            case (access_addr_lo_reg)
              1: access_out_new[ 0+:8  ] = ram_rd_data[ 56+: 8 ];
              2: access_out_new[ 0+:16 ] = ram_rd_data[ 48+:16 ];
              3: access_out_new[ 0+:24 ] = ram_rd_data[ 40+:24 ];
              4: access_out_new[ 0+:32 ] = ram_rd_data[ 32+:32 ];
              5: access_out_new[ 0+:40 ] = ram_rd_data[ 24+:40 ];
              6: access_out_new[ 0+:48 ] = ram_rd_data[ 16+:48 ];
              7: access_out_new[ 0+:56 ] = ram_rd_data[  8+:56 ];
              default: ;
            endcase
        end
      MEMORY_CTRL_BURST_DLY: ;
      MEMORY_CTRL_BURST_1ST:
        begin
          access_out_we  = 'b1;
          access_out_new = 0;
          burst_mem_we   = 1;
          burst_mem_new   = ram_rd_data[55:0];
          case (access_addr_lo_reg)
            0: begin
                 access_out_new[63-:64] = ram_rd_data;
                 access_dv_we = 1;
                 access_dv_new = 1;
                 if (burst_size_reg <= 8) begin
                   burst_done = 1;
                 end else begin
                   //special case: can emit in BURST_DELAY_1ST, but not done. Sigh.
                   burst_size_we = 1;
                   burst_size_new = burst_size_reg - 8;
                 end
               end
            1: begin
                 if (burst_size_reg <= 7) begin
                   access_dv_we    = 1;
                   access_dv_new   = 1;
                   access_out_new  = { ram_rd_data[0+:56], 8'b0 };
                   burst_done      = 1;
                 end
               end
            2: begin
                 if (burst_size_reg <= 6) begin
                   access_dv_we    = 1;
                   access_dv_new   = 1;
                   access_out_new  = { ram_rd_data[0+:48], 16'b0 };
                   burst_done      = 1;
                 end
               end
            3: begin
                 if (burst_size_reg <= 5) begin
                   access_dv_we    = 1;
                   access_dv_new   = 1;
                   access_out_new  = { ram_rd_data[0+:40], 24'b0 };
                   burst_done      = 1;
                 end
               end
            4: begin
                 if (burst_size_reg <= 4) begin
                   access_dv_we    = 1;
                   access_dv_new   = 1;
                   access_out_new  = { ram_rd_data[0+:32], 32'b0 };
                   burst_done      = 1;
                 end
               end
            5: begin
                 if (burst_size_reg <= 3) begin
                   access_dv_we    = 1;
                   access_dv_new   = 1;
                   access_out_new  = { ram_rd_data[0+:24], 40'b0 };
                   burst_done      = 1;
                 end
               end
            6: begin
                 if (burst_size_reg <= 2) begin
                   access_dv_we    = 1;
                   access_dv_new   = 1;
                   access_out_new  = { ram_rd_data[0+:16], 48'b0 };
                   burst_done      = 1;
                 end
               end
            7: begin
                 if (burst_size_reg <= 1) begin
                   access_dv_we    = 1;
                   access_dv_new   = 1;
                   access_out_new  = { ram_rd_data[0+:8], 56'b0 };
                   burst_done      = 1;
                 end
               end
            default: ;
         endcase
        end
      MEMORY_CTRL_BURST:
        begin : burst_locals
          access_dv_we   = 1;
          access_dv_new  = 1;
          access_out_we  = 'b1;
          access_out_new = 0;
          burst_mem_we   = 1;
          burst_mem_new  = ram_rd_data[55:0];
          case (access_addr_lo_reg)
            0: access_out_new = ram_rd_data;
            1: access_out_new = { burst_mem_reg[55:0], ram_rd_data[63-:8] };
            2: access_out_new = { burst_mem_reg[47:0], ram_rd_data[63-:16] };
            3: access_out_new = { burst_mem_reg[39:0], ram_rd_data[63-:24] };
            4: access_out_new = { burst_mem_reg[31:0], ram_rd_data[63-:32] };
            5: access_out_new = { burst_mem_reg[23:0], ram_rd_data[63-:40] };
            6: access_out_new = { burst_mem_reg[15:0], ram_rd_data[63-:48] };
            7: access_out_new = { burst_mem_reg[7:0],  ram_rd_data[63-:56] };
          endcase

          if (burst_size_reg <= 8) begin
            burst_done = 1;
            case (burst_size_reg[2:0])
              1: access_out_new = access_out_new & 64'hFF00_0000_0000_0000;
              2: access_out_new = access_out_new & 64'hFFFF_0000_0000_0000;
              3: access_out_new = access_out_new & 64'hFFFF_FF00_0000_0000;
              4: access_out_new = access_out_new & 64'hFFFF_FFFF_0000_0000;
              5: access_out_new = access_out_new & 64'hFFFF_FFFF_FF00_0000;
              6: access_out_new = access_out_new & 64'hFFFF_FFFF_FFFF_0000;
              7: access_out_new = access_out_new & 64'hFFFF_FFFF_FFFF_FF00;
              default: ;
            endcase
          end else begin
            burst_size_we = 1;
            burst_size_new = burst_size_reg - 8;
          end
        end
      MEMORY_CTRL_CSUM_FINALIZE:
        if (csum_calculate_done) begin
          access_dv_we   = 1;
          access_dv_new  = 1;
          access_out_we  = 1;
          access_out_new = { 48'b0, csum_value };
        end
      default ;
    endcase
  end

  //----------------------------------------------------------------
  // Checksum reader
  // Converts RAM reads to aligned 64 bit blocks, great for checksum
  //----------------------------------------------------------------

  always @*
  begin : checksum_reader
    csum_block_new       = 0;
    csum_block_valid_new = 0;

    csum_mem_we    = 1;
    csum_mem_new   = ram_rd_data[55:0];

    csum_read_done = 0;
    csum_reset = 0;

    csum_size_we = 0;
    csum_size_new = 0;

    case (memctrl_reg)
      MEMORY_CTRL_IDLE:
        begin
          if (i_access_port_rd_en) begin
            csum_size_we  = 1;
            csum_size_new = i_access_port_burstsize;
          end
        end
      MEMORY_CTRL_CSUM_DLY:
        begin
          csum_reset = 1;
        end
      MEMORY_CTRL_CSUM_1ST:
        begin
          csum_mem_we   = 1;
          csum_mem_new   = ram_rd_data[55:0];

          case (access_addr_lo_reg)
            0: begin
                 csum_block_new[63-:64] = ram_rd_data;
                 csum_block_valid_new = 1;

                 if (csum_size_reg <= 8) begin
                   csum_block_valid_new = 1;
                   csum_read_done = 1;
                 end else begin
                   csum_size_we = 1;
                   csum_size_new = csum_size_reg - 8;
                 end
               end
            1:
              if (csum_size_reg <= 7) begin
                csum_block_valid_new = 1;
                csum_block_new = { ram_rd_data[0+:56], 8'b0 };
                csum_read_done = 1;
              end
            2:
              if (csum_size_reg <= 6) begin
                csum_block_valid_new = 1;
                csum_block_new = { ram_rd_data[0+:48], 16'b0 };
                csum_read_done = 1;
              end
            3:
              if (csum_size_reg <= 5) begin
                csum_block_valid_new = 1;
                csum_block_new  = { ram_rd_data[0+:40], 24'b0 };
                csum_read_done      = 1;
               end
            4:
              if (csum_size_reg <= 4) begin
                csum_block_valid_new = 1;
                csum_block_new  = { ram_rd_data[0+:32], 32'b0 };
                csum_read_done  = 1;
               end
            5:
              if (csum_size_reg <= 3) begin
                csum_block_valid_new = 1;
                csum_block_new  = { ram_rd_data[0+:24], 40'b0 };
                csum_read_done  = 1;
               end
            6:
              if (csum_size_reg <= 2) begin
                csum_block_valid_new = 1;
                csum_block_new  = { ram_rd_data[0+:16], 48'b0 };
                csum_read_done  = 1;
              end
            7:
              if (csum_size_reg <= 1) begin
                csum_block_valid_new = 1;
                csum_block_new  = { ram_rd_data[0+:8], 56'b0 };
                csum_read_done  = 1;
              end
            default: ;
          endcase
          if (csum_block_valid_new) begin
            case (csum_size_reg)
              1: csum_block_new = csum_block_new & 64'hFF00_0000_0000_0000;
              2: csum_block_new = csum_block_new & 64'hFFFF_0000_0000_0000;
              3: csum_block_new = csum_block_new & 64'hFFFF_FF00_0000_0000;
              4: csum_block_new = csum_block_new & 64'hFFFF_FFFF_0000_0000;
              5: csum_block_new = csum_block_new & 64'hFFFF_FFFF_FF00_0000;
              6: csum_block_new = csum_block_new & 64'hFFFF_FFFF_FFFF_0000;
              7: csum_block_new = csum_block_new & 64'hFFFF_FFFF_FFFF_FF00;
              default: ;
            endcase
          end
        end
      MEMORY_CTRL_CSUM:
        begin
          csum_block_valid_new = 1;
          csum_mem_we   = 1;
          csum_mem_new  = ram_rd_data[55:0];
          case (access_addr_lo_reg)
            0: csum_block_new = ram_rd_data;
            1: csum_block_new = { csum_mem_reg[55:0], ram_rd_data[63-:8] };
            2: csum_block_new = { csum_mem_reg[47:0], ram_rd_data[63-:16] };
            3: csum_block_new = { csum_mem_reg[39:0], ram_rd_data[63-:24] };
            4: csum_block_new = { csum_mem_reg[31:0], ram_rd_data[63-:32] };
            5: csum_block_new = { csum_mem_reg[23:0], ram_rd_data[63-:40] };
            6: csum_block_new = { csum_mem_reg[15:0], ram_rd_data[63-:48] };
            7: csum_block_new = { csum_mem_reg[7:0],  ram_rd_data[63-:56] };
          endcase

          if (csum_size_reg <= 8) begin
            csum_read_done = 1;
            case (csum_size_reg)
              1: csum_block_new = csum_block_new & 64'hFF00_0000_0000_0000;
              2: csum_block_new = csum_block_new & 64'hFFFF_0000_0000_0000;
              3: csum_block_new = csum_block_new & 64'hFFFF_FF00_0000_0000;
              4: csum_block_new = csum_block_new & 64'hFFFF_FFFF_0000_0000;
              5: csum_block_new = csum_block_new & 64'hFFFF_FFFF_FF00_0000;
              6: csum_block_new = csum_block_new & 64'hFFFF_FFFF_FFFF_0000;
              7: csum_block_new = csum_block_new & 64'hFFFF_FFFF_FFFF_FF00;
              default: ;
            endcase
          end else begin
            csum_size_we = 1;
            csum_size_new = csum_size_reg - 8;
          end
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Checksum pipelined arithmetics
  //
  //   p0: capture checksum_read_done
  //
  //   p1: ( c_a, sum_a ) = checksum_block_a1 + checksum_block_a2
  //       ( c_b, sum_b ) = checksum_block_b1 + checksum_block_b2
  //
  //   p2: ( c_c, sum_c ) = sum_a + sum_b
  //
  //   p3: ( c_d, sum_d ) = sum_c + c_a + c_b + c_c
  //       sum = sum_d + c_d
  //
  //----------------------------------------------------------------

  always @*
  begin
    csum_calculate_done = 0;
    csum_value = 0;

    p0_done_new = 0;
    p1_done_new = 0;
    p1_valid_new = 0;

    { p1_carry_a_new, p1_sum_a_new } = 17'b0;
    { p1_carry_b_new, p1_sum_b_new } = 17'b0;

    p2_done_new = 0;
    p2_valid_new = 0;
    p2_carry_a_new = 0;
    p2_carry_b_new = 0;
    { p2_carry_c_new, p2_sum_c_new } = 17'b0;

    p3_done_new = 0;
    p3_csum_new = 0;

    if (csum_reset == 1'b0) begin
      csum_calculate_done = p3_done_reg;
      csum_value = p3_csum_reg;

      // Pipeline stage 0: capture done signal (one cycle early)

      p0_done_new = csum_read_done;

      // Pipeline stage 1: Sum four 16bit regs into two 16 bit regs, and remember carry

      p1_done_new = p0_done_reg;
      if (csum_block_valid_reg) begin
        p1_valid_new = 1;
        { p1_carry_a_new, p1_sum_a_new } = { 1'b0, csum_block_reg[63:48] } + { 1'b0, csum_block_reg[47:32] };
        { p1_carry_b_new, p1_sum_b_new } = { 1'b0, csum_block_reg[31:16] } + { 1'b0, csum_block_reg[15:0] };

      end else begin
        p1_valid_new = 0;
        { p1_carry_a_new, p1_sum_a_new } = 17'b0;
        { p1_carry_b_new, p1_sum_b_new } = 17'b0;
      end

      // Pipeline stage 2: Sum two 16bit regs into one 16 bit regs, and remember carry

      p2_done_new = p1_done_reg;
      if (p1_valid_reg) begin
        p2_valid_new = 1;
        p2_carry_a_new = p1_carry_a_reg;
        p2_carry_b_new = p1_carry_b_reg;
        { p2_carry_c_new, p2_sum_c_new } = { 1'b0, p1_sum_a_reg } + {1'b0, p1_sum_b_reg };
      end else begin
        p2_valid_new = 0;
        p2_carry_a_new = 0;
        p2_carry_b_new = 0;
        { p2_carry_c_new, p2_sum_c_new } = 17'b0;
      end

      // Pipeline stage 3: Add one 16bit reg to 16bit sum reg, and also handle all of the carries.

      p3_done_new = p2_done_reg;
      if (p2_valid_reg) begin : calc_tmp
        reg  [2:0] msb1;
        reg  [2:0] msb2;
        reg [15:0] sum1;
        reg [15:0] sum2;
        reg carry;
        msb1 = { 2'b00, p2_carry_a_reg } + { 2'b00, p2_carry_b_reg } + { 2'b00, p2_carry_c_reg };
        msb2 = { 2'b00, p2_carry_a_reg } + { 2'b00, p2_carry_b_reg } + { 2'b00, p2_carry_c_reg } + 3'b001;
        { carry, sum1 } = p3_csum_reg + p2_sum_c_reg + { 13'b0, msb1 };
        sum2 = p3_csum_reg + p2_sum_c_reg + { 13'b0, msb2 };
        if (carry) p3_csum_new = sum2;
        else       p3_csum_new = sum1;
      end else begin
        p3_csum_new = p3_csum_reg;
      end
    end
  end

endmodule
