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
  input  wire [63:0]           i_dispatch_fifo_rd_data,

  output wire                  o_dispatch_tx_packet_available,
  input  wire                  i_dispatch_tx_packet_read,
  output wire                  o_dispatch_tx_fifo_empty,
  input  wire                  i_dispatch_tx_fifo_rd_en,
  output wire [63:0]           o_dispatch_tx_fifo_rd_data,
  output wire  [3:0]           o_dispatch_tx_bytes_last_word,

  input  wire                  i_api_cs,
  input  wire                  i_api_we,
  input  wire [11:0]           i_api_address,
  input  wire [31:0]           i_api_write_data,
  output wire [31:0]           o_api_read_data,

  output wire                  o_detect_unique_identifier,
  output wire                  o_detect_nts_cookie,
  output wire                  o_detect_nts_cookie_placeholder,
  output wire                  o_detect_nts_authenticator
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
  reg [6:0] delay_counter_new; //temporary debug register for simularing work in unimplemented states
  reg [6:0] delay_counter_reg; //temporary debug register for simularing work in unimplemented states

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

  wire                         detect_unique_identifier;
  wire                         detect_nts_cookie;
  wire                         detect_nts_cookie_placeholder;
  wire                         detect_nts_authenticator;

  wire                         api_cs_engine;
  wire                         api_cs_clock;
  wire                         api_cs_cookie;
  wire                         api_cs_keymem;
  wire                         api_cs_debug;

  wire                [31 : 0] api_read_data_engine;
  wire                [31 : 0] api_read_data_clock;
  wire                [31 : 0] api_read_data_cookie;
  wire                [31 : 0] api_read_data_keymem;
  wire                [31 : 0] api_read_data_debug;

  wire                         api_we;
  wire                 [7 : 0] api_address;
  wire                [31 : 0] api_write_data;

  wire                         keymem_internal_get_current_key;
  wire                         keymem_internal_get_key_with_id;
  wire                [31 : 0] keymem_internal_server_key_id;
  wire                 [3 : 0] keymem_internal_key_word;
  wire                         keymem_internal_key_valid;
  wire                         keymem_internal_key_length;
  wire                [31 : 0] keymem_internal_key_id;
  wire                [31 : 0] keymem_internal_key_data;
  wire                         keymem_internal_ready;

  wire                         parser_txbuf_clear;
  wire                         parser_txbuf_write_en;
  wire                  [63:0] parser_txbuf_write_data;
  wire                         parser_txbuf_ipv4_done;
  wire                         parser_txbuf_ipv6_done;
  wire                         txbuf_parser_full;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign debug_delay_continue            = state_reg == STATE_TO_BE_IMPLEMENTED && (delay_counter_reg < 100);

  assign keymem_internal_get_current_key = 'b0;

  assign parser_txbuf_clear       = 'b0; //TODO implement
  assign parser_txbuf_write_en    = 'b0; //TODO implement
  assign parser_txbuf_write_data  = 'b0; //TODO implement
  assign parser_txbuf_ipv4_done   = 'b0; //TODO implement
  assign parser_txbuf_ipv6_done   = 'b0; //TODO implement

  assign o_dispatch_packet_read_discard  = dispatch_packet_discard_reg;
  assign o_dispatch_fifo_rd_en           = dispatch_fifo_rd_en;
  assign o_busy                          = busy_reg;

  //assign o_keymem_api_read_data          = keymem_api_read_data;

  assign o_detect_unique_identifier      = detect_unique_identifier;
  assign o_detect_nts_cookie             = detect_nts_cookie;
  assign o_detect_nts_cookie_placeholder = detect_nts_cookie_placeholder;
  assign o_detect_nts_authenticator      = detect_nts_authenticator;

  //----------------------------------------------------------------
  // API instantiation.
  //----------------------------------------------------------------

  nts_api dut (
    .i_external_api_cs(i_api_cs),
    .i_external_api_we(i_api_we),
    .i_external_api_address(i_api_address),
    .i_external_api_write_data(i_api_write_data),
    .o_external_api_read_data(o_api_read_data),

    .o_internal_api_we(api_we),
    .o_internal_api_address(api_address),
    .o_internal_api_write_data(api_write_data),

    .o_internal_engine_api_cs(api_cs_engine),
    .i_internal_engine_api_read_data(api_read_data_engine),

    .o_internal_clock_api_cs(api_cs_clock),
    .i_internal_clock_api_read_data(api_read_data_clock),

    .o_internal_cookie_api_cs(api_cs_cookie),
    .i_internal_cookie_api_read_data(api_read_data_cookie),

    .o_internal_keymem_api_cs(api_cs_keymem),
    .i_internal_keymem_api_read_data(api_read_data_keymem),

    .o_internal_debug_api_cs(api_cs_debug),
    .i_internal_debug_api_read_data(api_read_data_debug)
  );

  //----------------------------------------------------------------
  // Receive buffer instantiation.
  //----------------------------------------------------------------

  nts_rx_buffer #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .ACCESS_PORT_WIDTH(ACCESS_PORT_WIDTH)
  ) rx_buffer (
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
  // Transmit Vuffer instantiation.
  //----------------------------------------------------------------

  nts_tx_buffer #(
    .ADDR_WIDTH(ADDR_WIDTH)
  ) tx_buffer (
    .i_areset(i_areset), // async reset
    .i_clk(i_clk),

    .o_dispatch_tx_packet_available(o_dispatch_tx_packet_available),
    .i_dispatch_tx_packet_read(i_dispatch_tx_packet_read),
    .o_dispatch_tx_fifo_empty(o_dispatch_tx_fifo_empty),
    .i_dispatch_tx_fifo_rd_en(i_dispatch_tx_fifo_rd_en),
    .o_dispatch_tx_fifo_rd_data(o_dispatch_tx_fifo_rd_data),
    .o_dispatch_tx_bytes_last_word(o_dispatch_tx_bytes_last_word),

    .i_parser_clear(parser_txbuf_clear),
    .i_parser_w_en(parser_txbuf_write_en),
    .i_parser_w_data(parser_txbuf_write_data),

    .i_parser_ipv4_done(parser_txbuf_ipv4_done),
    .i_parser_ipv6_done(parser_txbuf_ipv6_done),

    .o_parser_current_memory_full(txbuf_parser_full),
    .o_parser_current_empty(txbuf_parser_full)
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
   .i_access_port_rd_data(access_port_rd_data),

   .o_keymem_key_word(keymem_internal_key_word),
   .o_keymem_get_key_with_id(keymem_internal_get_key_with_id),
   .o_keymem_server_id(keymem_internal_server_key_id),
   .i_keymem_key_length(keymem_internal_key_length),
   .i_keymem_key_valid(keymem_internal_key_valid),
   .i_keymem_ready(keymem_internal_ready),

   .o_detect_unique_identifier(detect_unique_identifier),
   .o_detect_nts_cookie(detect_nts_cookie),
   .o_detect_nts_cookie_placeholder(detect_nts_cookie_placeholder),
   .o_detect_nts_authenticator(detect_nts_authenticator)
  );

  keymem keymem (
    .clk(i_clk),
    .areset(i_areset),
    // API access
    .cs(api_cs_keymem),
    .we(api_we),
    .address(api_address),
    .write_data(api_write_data),
    .read_data(api_read_data_keymem),
    // Client access
    .get_current_key(keymem_internal_get_current_key),
    .get_key_with_id(keymem_internal_get_key_with_id),
    .server_key_id(keymem_internal_server_key_id),
    .key_word(keymem_internal_key_word),
    .key_valid(keymem_internal_key_valid),
    .key_length(keymem_internal_key_length),
    .key_id(keymem_internal_key_id),
    .key_data(keymem_internal_key_data),
    .ready(keymem_internal_ready)
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
