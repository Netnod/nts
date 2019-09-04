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

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

  localparam ACCESS_PORT_WIDTH       = 32;

  localparam STATE_RESET             = 4'h0;
  localparam STATE_EMPTY             = 4'h1;
  localparam STATE_COPY              = 4'h2;
  localparam STATE_ERROR_BAD_PACKET  = 4'hc;
  localparam STATE_ERROR_OVERFLOW    = 4'hd;
  localparam STATE_ERROR_GENERAL     = 4'he;
  localparam STATE_TO_BE_IMPLEMENTED = 4'hf;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg       state_we;
  reg [3:0] state_new;
  reg [3:0] state_reg;

  reg       busy_we;
  reg       busy_new;
  reg       busy_reg;

  reg       dispatch_packet_discard_we;
  reg       dispatch_packet_discard_new;
  reg       dispatch_packet_discard_reg;

  reg       delay_counter_we; //temporary debug register for simularing work in unimplemented states
  reg [7:0] delay_counter_new; //temporary debug register for simularing work in unimplemented states
  reg [7:0] delay_counter_reg; //temporary debug register for simularing work in unimplemented states

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  wire                         dispatch_fifo_rd_en;
  wire                         access_port_wait;
  wire      [ADDR_WIDTH+3-1:0] access_port_addr;
  wire                   [2:0] access_port_wordsize;
  wire                         access_port_rd_en;
  wire                         access_port_rd_dv;
  wire [ACCESS_PORT_WIDTH-1:0] access_port_rd_data;
  wire                         debug_delay_continue;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign o_dispatch_packet_read_discard = dispatch_packet_discard_reg;
  assign o_dispatch_fifo_rd_en          = dispatch_fifo_rd_en;
  assign o_busy                         = busy_reg;

  assign debug_delay_continue           = state_reg == STATE_TO_BE_IMPLEMENTED && (delay_counter_reg < 100);

  //----------------------------------------------------------------
  // Receive buffer instantiation.
  //----------------------------------------------------------------

  nts_rx_buffer #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .ACCESS_PORT_WIDTH(ACCESS_PORT_WIDTH)
  ) buffer (
     .i_areset(i_areset),
     .i_clk(i_clk),

     .i_clear(state_reg == STATE_RESET),

     .i_dispatch_packet_available(i_dispatch_packet_available),
     .i_dispatch_fifo_empty(i_dispatch_fifo_empty),
     .o_dispatch_fifo_rd_en(dispatch_fifo_rd_en),
     .i_dispatch_fifo_rd_data(i_dispatch_fifo_rd_data),

     .o_access_port_wait(access_port_wait),
     .i_access_port_addr(access_port_addr),
     .i_access_port_wordsize(access_port_wordsize),
     .i_access_port_rd_en(access_port_rd_en),
     .o_access_port_rd_dv(access_port_rd_dv),
     .o_access_port_rd_data(access_port_rd_data)
  );

  //----------------------------------------------------------------
  // Parser Ctrl instantiation.
  //----------------------------------------------------------------

  nts_parser_ctrl #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .ACCESS_PORT_WIDTH(ACCESS_PORT_WIDTH)
  ) parser (
   .i_areset(i_areset),
   .i_clk(i_clk),

   .i_clear(state_reg == STATE_RESET),

   .i_process_initial(dispatch_fifo_rd_en),
   .i_last_word_data_valid(i_dispatch_data_valid),
   .i_data(i_dispatch_fifo_rd_data),

   .i_access_port_wait(access_port_wait),
   .o_access_port_addr(access_port_addr),
   .o_access_port_wordsize(access_port_wordsize),
   .o_access_port_rd_en(access_port_rd_en),
   .i_access_port_rd_dv(access_port_rd_dv),
   .i_access_port_rd_data(access_port_rd_data)
  );

  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active high reset.
  //----------------------------------------------------------------

  always @ (posedge i_clk, posedge i_areset)
  begin : reg_update
    if (i_areset == 1'b1) begin
      state_reg                   <= STATE_RESET;
      delay_counter_reg           <= 'b0; //this is just for a debug delay in not implemented state :)
      busy_reg                    <= 'b0;
      dispatch_packet_discard_reg <= 'b0;
    end else begin
      if (state_we)
        state_reg <= state_new;

      if (delay_counter_we)
        delay_counter_reg <= delay_counter_new;

      if (busy_we)
        busy_reg <= busy_new;

      if (dispatch_packet_discard_we)
        dispatch_packet_discard_reg <= dispatch_packet_discard_new;
    end
  end

  //----------------------------------------------------------------
  // State and output
  // Small internal FSM and related output signals.
  //----------------------------------------------------------------
  always @*
  begin : state_and_output
    dispatch_packet_discard_we    = 'b0;
    dispatch_packet_discard_new   = 'b0;
    state_we                      = 'b0;
    state_new                     = 'b0;
    busy_we                       = 'b0;
    busy_new                      = 'b0;
    case (state_reg)
      STATE_RESET:
        begin
          dispatch_packet_discard_we  = 'b1;
          dispatch_packet_discard_new = 'b0;
          state_we                    = 'b1;
          state_new                   = STATE_EMPTY;
          busy_we                     = 'b1;
          busy_new                    = 'b0;
        end
      STATE_EMPTY:
        begin
          if (i_dispatch_packet_available && i_dispatch_fifo_empty == 'b0) begin
            state_we                = 'b1;
            state_new               = STATE_COPY;
            busy_we                 = 'b1;
            busy_new                = 'b1;
          end
        end
      STATE_COPY:
        if (i_dispatch_fifo_empty) begin
          state_we                = 'b1;
          state_new               = STATE_TO_BE_IMPLEMENTED;
          //TODO rx_buffer to signal overflow
        end
      STATE_TO_BE_IMPLEMENTED:
        begin
          if (debug_delay_continue == 'b0) begin
            dispatch_packet_discard_we  = 'b1;
            dispatch_packet_discard_new = 'b1;
            busy_we                     = 'b1;
            busy_new                    = 'b0;
            state_we                    = 'b1;
            state_new                   = STATE_RESET;
          end
        end
      default:
        begin
          busy_we   = 'b1;
          busy_new  = 'b0;
          state_we  = 'b1;
          state_new = STATE_RESET;
        end
    endcase
  end

  //----------------------------------------------------------------
  // Debug Delay
  // A small delay to simulate system processing.
  // Will be removed when more of the processing is implemented.
  //----------------------------------------------------------------
  always @*
  begin : debug_delay
    delay_counter_we              = 'b0;
    delay_counter_new             = 'b0;
    case (state_reg)
      STATE_RESET:
        begin
          delay_counter_we        = 'b1;
          delay_counter_new       = 'b0;
        end
      STATE_TO_BE_IMPLEMENTED:
        begin
          if (debug_delay_continue) begin

            delay_counter_we     = 'b1;
            delay_counter_new    = delay_counter_reg + 1;

            if (delay_counter_reg == 0) begin
              $display("%s:%0d TODO!!! NOT IMPLEMENTED. state = %0d", `__FILE__, `__LINE__, state_reg);
            end
          end
        end
      default: ;
    endcase
  end
endmodule
