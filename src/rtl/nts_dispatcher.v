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

module nts_dispatcher #(
  parameter ADDR_WIDTH = 8,
  parameter DEBUG = 1
) (
  input  wire        i_areset, // async reset
  input  wire        i_clk,

  // MAC
  input  wire [7:0]  i_rx_data_valid,
  input  wire [63:0] i_rx_data,
  input  wire        i_rx_bad_frame,
  input  wire        i_rx_good_frame,

  output wire                  o_dispatch_packet_available,
  input  wire                  i_dispatch_packet_read_discard,
  output wire [ADDR_WIDTH-1:0] o_dispatch_counter,
  output wire [7:0]            o_dispatch_data_valid,
  output wire                  o_dispatch_fifo_empty,
  input  wire                  i_dispatch_fifo_rd_start,
  output wire                  o_dispatch_fifo_rd_valid,
  output wire [63:0]           o_dispatch_fifo_rd_data,

  input  wire                  i_api_cs,
  input  wire                  i_api_we,
  input  wire [11:0]           i_api_address,
  input  wire [31:0]           i_api_write_data,
  output wire [31:0]           o_api_read_data
);

  //----------------------------------------------------------------
  // API constants
  //----------------------------------------------------------------

  localparam ADDR_NAME0   = 0;
  localparam ADDR_NAME1   = 1;
  localparam ADDR_VERSION = 2;
  localparam ADDR_DUMMY   = 3;
  localparam ADDR_COUNTER_FRAMES_MSB = 'h10;
  localparam ADDR_COUNTER_FRAMES_LSB = 'h11;

  localparam CORE_NAME    = 64'h4e_54_53_5f_44_53_50_54; //NTS_DSPT
  localparam CORE_VERSION = 32'h30_2e_30_31; //0.01

  //----------------------------------------------------------------
  // State constants
  //----------------------------------------------------------------

  localparam STATE_EMPTY           = 0;
  localparam STATE_HAS_DATA        = 1;
  localparam STATE_PACKET_RECEIVED = 2;
  localparam STATE_FIFO_OUT_INIT_0 = 3;
  localparam STATE_FIFO_OUT_INIT_1 = 4;
  localparam STATE_FIFO_OUT_INIT_2 = 5;
  localparam STATE_FIFO_OUT        = 6;
  localparam STATE_FIFO_OUT_FIN_0  = 7;
  localparam STATE_FIFO_OUT_FIN_1  = 8;
  localparam STATE_ERROR_GENERAL   = 9;

  //----------------------------------------------------------------
  // Internal registers and wires
  //----------------------------------------------------------------

  reg  [31:0]     api_read_data;

  reg               current_mem;       //Current: MAC RX receiver. ~Current: Dispatcher FIFO out
  reg                fifo_empty;
  reg  [3:0]          mem_state [1:0];

  reg                     write [1:0]; //RAM W.E.
  reg  [63:0]            w_data [1:0]; //RAM W.D.
  wire [63:0]            r_data [1:0]; //RAM R.D
  reg  [ADDR_WIDTH-1:0]  r_addr;       //RAM R.A
  reg  [ADDR_WIDTH-1:0]  w_addr [1:0]; //RAM W.A
  reg  [ADDR_WIDTH-1:0] counter [1:0];
  reg  [7:0]         data_valid [1:0];

  reg [63:0] fifo_rd_data;  //out
  reg        fifo_rd_valid; //out

  reg [7:0] previous_rx_data_valid;
  reg       detect_start_of_frame;

  //----------------------------------------------------------------
  // API Debug, counter etc registers
  //----------------------------------------------------------------

  reg        api_dummy_we;
  reg [31:0] api_dummy_new;
  reg [31:0] api_dummy_reg;
  reg        counter_sof_detect_we;
  reg [63:0] counter_sof_detect_new;
  reg [63:0] counter_sof_detect_reg;
  reg        counter_sof_detect_lsb_we;
  reg [31:0] counter_sof_detect_lsb_reg;

  //----------------------------------------------------------------
  // Output wiring
  //----------------------------------------------------------------

  assign o_api_read_data              = api_read_data;
  assign o_dispatch_packet_available  = mem_state[ ~ current_mem ] == STATE_FIFO_OUT_INIT_0; //STATE_FIFO_OUT;
  assign o_dispatch_counter           = counter[ ~ current_mem ];
  assign o_dispatch_data_valid        = data_valid[ ~ current_mem ];
  assign o_dispatch_fifo_empty        = fifo_empty;
  assign o_dispatch_fifo_rd_valid     = fifo_rd_valid;
  assign o_dispatch_fifo_rd_data      = fifo_rd_data; //r_data[ ~ current_mem ];

  //----------------------------------------------------------------
  // RAM cores
  //----------------------------------------------------------------

  bram #(ADDR_WIDTH,64) mem0 (
     .i_clk(i_clk),
     .i_addr(write[0] ? w_addr[0] : r_addr),
     .i_write(write[0]),
     .i_data(w_data[0]),
     .o_data(r_data[0])
  );

  bram #(ADDR_WIDTH,64) mem1 (
     .i_clk(i_clk),
     .i_addr(write[1] ? w_addr[1] : r_addr),
     .i_write(write[1]),
     .i_data(w_data[1]),
     .o_data(r_data[1])
  );

  //----------------------------------------------------------------
  // API
  //----------------------------------------------------------------

  always @*
  begin : api
    api_read_data = 0;

    api_dummy_we = 0;
    api_dummy_new = 0;
    counter_sof_detect_lsb_we = 0;

    if (i_api_cs) begin
      if (i_api_we) begin
        case (i_api_address)
          ADDR_DUMMY:
            begin
              api_dummy_we = 1;
              api_dummy_new = i_api_write_data;
            end
          default: ;
        endcase
      end else begin
        case (i_api_address)
          ADDR_NAME0: api_read_data = CORE_NAME[63:32];
          ADDR_NAME1: api_read_data = CORE_NAME[31:0];
          ADDR_VERSION: api_read_data = CORE_VERSION;
          ADDR_DUMMY: api_read_data = api_dummy_reg;
          ADDR_COUNTER_FRAMES_MSB:
            begin
              api_read_data = counter_sof_detect_reg[63:32];
              counter_sof_detect_lsb_we = 1;
            end
          ADDR_COUNTER_FRAMES_LSB:
            begin
              api_read_data = counter_sof_detect_lsb_reg;
            end
          default: ;
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // Register Update
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      api_dummy_reg <= 0;
      counter_sof_detect_reg <= 0;
      counter_sof_detect_lsb_reg <= 0;
    end else begin

      if (api_dummy_we)
        api_dummy_reg <= api_dummy_new;

      if (counter_sof_detect_we)
       counter_sof_detect_reg <= counter_sof_detect_new;

      if (counter_sof_detect_lsb_we)
        counter_sof_detect_lsb_reg <= counter_sof_detect_reg[31:0];

    end
  end

  //----------------------------------------------------------------
  // Debug counters
  //----------------------------------------------------------------

  always @*
  begin : debug_regs
    counter_sof_detect_we = 0;
    counter_sof_detect_new = 0;

    if (detect_start_of_frame) begin
      counter_sof_detect_we = 1;
      counter_sof_detect_new = counter_sof_detect_reg + 1;
    end
  end

  //----------------------------------------------------------------
  // Start of Frame Detector (previous MAC RX DV sampler)
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  if (i_areset) begin
    previous_rx_data_valid <= 8'hFF; // Must not be zero as 00FF used to detect start of frame
  end else begin
    previous_rx_data_valid <= i_rx_data_valid;
  end

  //----------------------------------------------------------------
  // Start of Frame Detector
  //----------------------------------------------------------------

  always @*
  begin : sof_detector
    reg [15:0] rx_valid;
    rx_valid = {previous_rx_data_valid, i_rx_data_valid};
    detect_start_of_frame = 0;
    if ( 16'h00FF == rx_valid) begin
      detect_start_of_frame = 1;
    end
  end

  //----------------------------------------------------------------
  // Main process
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin : main_proc
    if (i_areset == 1'b1) begin
      current_mem   <= 'b0;
      fifo_empty    <= 'b1;
      fifo_rd_data  <= 'b0;
      r_addr        <= 'b0;
      mem_state[0]  <= STATE_EMPTY;
      mem_state[1]  <= STATE_EMPTY;
      write[0]      <= 1'b0;
      write[1]      <= 1'b0;
      w_data[0]     <= 64'b0;
      w_data[1]     <= 64'b0;
      w_addr[0]     <= 'b0;
      w_addr[1]     <= 'b0;
      counter[0]    <= 'b0;
      counter[1]    <= 'b0;
      data_valid[0] <= 'b0;
      data_valid[1] <= 'b0;
    end else begin
      write[0]    <= 1'b0;
      write[1]    <= 1'b0;
      w_data[0]   <= 64'b0;
      w_data[1]   <= 64'b0;

      //------------------------------------------
      // Previous (ENGINE RX FIFO) frame handling
      //------------------------------------------

      if (i_dispatch_packet_read_discard) begin
        $display("%s:%0d i_dispatch_packet_read_discard", `__FILE__, `__LINE__);
        mem_state[ ~ current_mem] <= STATE_EMPTY;
        fifo_empty <= 'b1;
      end else begin
        case (mem_state[ ~ current_mem])
          STATE_FIFO_OUT_INIT_0:
            begin
              if (i_dispatch_fifo_rd_start) begin
                mem_state[ ~ current_mem] <= STATE_FIFO_OUT_INIT_1;
              end
              r_addr <= 0;
              fifo_empty  <= 'b0;
            end
          STATE_FIFO_OUT_INIT_1:
            begin
              mem_state[ ~ current_mem] <= STATE_FIFO_OUT;
              r_addr <= 1;
              fifo_rd_data <= 0;
            end
          STATE_FIFO_OUT:
            begin
              fifo_rd_data <= r_data[ ~ current_mem ];
              fifo_rd_valid <= 1;
              if (r_addr == counter[ ~ current_mem]) begin
                mem_state[ ~ current_mem] <= STATE_FIFO_OUT_FIN_0;
              end else begin
                r_addr <= r_addr + 1;
              end
            end
          STATE_FIFO_OUT_FIN_0:
            begin
              fifo_rd_data <= r_data[ ~ current_mem ];
              fifo_rd_valid <= 1;
              mem_state[ ~ current_mem] <= STATE_FIFO_OUT_FIN_1;
              $display("%s:%0d Emit: %h ", `__FILE__, `__LINE__, r_data[ ~ current_mem ]);
            end
          STATE_FIFO_OUT_FIN_1:
            begin
              //Remain here until i_dispatch_packet_read_discard (above) takes us out
              fifo_rd_valid <= 0;
              fifo_empty <= 'b1;
            end
          default: ;
        endcase
      end

      //------------------------------------------
      // Current (MAC RX) frame handling
      //------------------------------------------

      if (i_rx_bad_frame) begin
         mem_state[current_mem]  <= STATE_EMPTY;
         w_addr[current_mem]     <= 'b0;
         counter[current_mem]    <= 'b0;
         data_valid[current_mem] <= 'b0;
       end else begin
         //$display("%s:%0d Current mem: %h Current state: %h RxDV: %h", `__FILE__, `__LINE__, current_mem, mem_state[current_mem], i_rx_good_frame);
         case (mem_state[current_mem])
           STATE_EMPTY:
             if (detect_start_of_frame) begin
               mem_state[current_mem] <= STATE_HAS_DATA;
             end
           STATE_HAS_DATA:
             begin
               if (i_rx_good_frame) begin
                 $display("%s:%0d data_valid: %h (%b)", `__FILE__, `__LINE__, i_rx_data_valid, i_rx_data_valid);
                 data_valid[current_mem] <= i_rx_data_valid;
                 mem_state[current_mem] <= STATE_PACKET_RECEIVED;
               end
             end
           STATE_PACKET_RECEIVED:
             if (mem_state[ ~ current_mem] == STATE_EMPTY) begin
               mem_state[current_mem] <= STATE_FIFO_OUT_INIT_0;
               current_mem <= ~ current_mem;
             end
           default:
             mem_state[current_mem] <= STATE_EMPTY;
          endcase

          if (i_rx_data_valid != 'b0) begin

            case (mem_state[current_mem])
              STATE_EMPTY:
                begin
                  write[current_mem]   <= 1'b1;
                  w_addr[current_mem]  <= 'b0;
                  w_data[current_mem]  <= i_rx_data;
                  counter[current_mem] <= 'b0;
                end
              STATE_HAS_DATA:
                if (counter[current_mem] != ~ 'b0) begin
                  write[current_mem]   <= 1'b1;
                  w_addr[current_mem]  <= counter[current_mem] + 1;
                  w_data[current_mem]  <= i_rx_data;
                  counter[current_mem] <= counter[current_mem] + 1;
                end // not buffer overrun
              default: ;
            endcase

          end //rx_data_valid
        end // not bad frame
    end //posedge i_clk
  end //always begin

  if (DEBUG>0) begin
    always @*
      $display("%s:%0d mem_state[0]: %h", `__FILE__, `__LINE__, mem_state[0]);
    always @*
      $display("%s:%0d mem_state[1]: %h", `__FILE__, `__LINE__, mem_state[1]);
    always @*
      $display("%s:%0d current_mem: %h", `__FILE__, `__LINE__, current_mem);
  end
endmodule
