//
// Copyright (c) 2019-2020, The Swedish Post and Telecom Authority (PTS)
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
  parameter ADDR_WIDTH = 8
) (
  input  wire        i_areset, // async reset
  input  wire        i_clk,

  output wire        o_busy,
  output wire        o_error,

  output wire        o_dispatch_tx_packet_available,
  input  wire        i_dispatch_tx_packet_read,
  output wire        o_dispatch_tx_fifo_empty,
  input  wire        i_dispatch_tx_fifo_rd_start,
  output wire        o_dispatch_tx_fifo_rd_valid,
  output wire [63:0] o_dispatch_tx_fifo_rd_data,
  output wire  [3:0] o_dispatch_tx_bytes_last_word,

  input  wire        i_parser_clear,

  input  wire        i_write_en,
  input  wire [63:0] i_write_data,

  input  wire        i_read_en,
  output wire [63:0] o_read_data,

  input  wire                    i_sum_reset,
  input  wire             [15:0] i_sum_reset_value,
  input  wire                    i_sum_en,
  input  wire [ADDR_WIDTH+3-1:0] i_sum_bytes,
  output wire             [15:0] o_sum,
  output wire                    o_sum_done,

  input  wire                  i_address_internal,
  input  wire [ADDR_WIDTH-1:0] i_address_hi,
  input  wire            [2:0] i_address_lo,

  input wire         i_parser_update_length,

  input  wire        i_parser_transfer,

  output wire        o_parser_current_memory_full,
  output wire        o_parser_current_empty
);

  //----------------------------------------------------------------
  // Local parameters
  //----------------------------------------------------------------

  localparam STATE_EMPTY                = 0;
  localparam STATE_CHECKSUM             = 1;
  localparam STATE_HAS_DATA             = 2;
  localparam STATE_FIFO_OUT             = 3;
  localparam STATE_FIFO_OUT_TRANSMIT    = 4;
  localparam STATE_ERROR_GENERAL        = 5;
  localparam STATE_ERROR_BUFFER_OVERRUN = 6;

  //localparam STATE_IP4_LENGTH           = 2;
  //localparam STATE_IP4_CHECKSUM         = 3;
  //localparam STATE_IP4_UDP_CHECKSUM     = 4;
  //localparam STATE_IP6_LENGTH           = 5;
  //localparam STATE_IP6_CHECKSUM         = 6;
  //localparam STATE_IP6_UDP_CHECKSUM     = 7;

  localparam [ADDR_WIDTH-1:0] ADDRESS_FULL        = ~ 'b0;
  localparam [ADDR_WIDTH-1:0] ADDRESS_ALMOST_FULL = (~ 'b0) - 1;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  wire                 bad_input_new;
  reg                  bad_input_reg;

  reg                  bytes_last_word_we  [0:1];
  reg            [3:0] bytes_last_word_new [0:1];
  reg            [3:0] bytes_last_word_reg [0:1];

  reg                  current_mem_we;
  reg                  current_mem_new;
  reg                  current_mem_reg;

  reg                  fifo_rd_valid_new;
  reg                  fifo_rd_valid_reg;

  reg                  mem_state_we    [0:1];
  reg            [2:0] mem_state_new   [0:1];
  reg            [2:0] mem_state_reg   [0:1];

  reg                  ram_rd          [0:1];
  reg                  ram_wr          [0:1];

  reg           [63:0] ram_wr_data     [0:1];

  reg [ADDR_WIDTH-1:0] ram_addr_hi     [0:1];
  reg                  ram_addr_hi_we  [0:1];
  reg [ADDR_WIDTH-1:0] ram_addr_hi_new [0:1];
  reg [ADDR_WIDTH-1:0] ram_addr_hi_reg [0:1];

  reg            [2:0] ram_addr_lo     [0:1];

  reg                  read_cycle_new;
  reg                  read_cycle_reg;
  reg           [63:0] read_data;

  reg                    sum_addr_we;
  reg [ADDR_WIDTH+3-1:0] sum_addr_new;
  reg [ADDR_WIDTH+3-1:0] sum_addr_reg;

  reg        sum_we;
  reg [15:0] sum_new;
  reg [15:0] sum_reg;

  //Pipeline delayed carry adders
  reg [15:0] sum_delayed_new;
  reg [15:0] sum_delayed_reg;
  reg  [2:0] carry_delayed_new;
  reg  [2:0] carry_delayed_reg;

  reg                    sum_counter_we;
  reg [ADDR_WIDTH+3-1:0] sum_counter_new;
  reg [ADDR_WIDTH+3-1:0] sum_counter_reg;

  reg sum_cycle_new;
  reg sum_cycle_reg;

  reg sum_done_delayed_new;
  reg sum_done_delayed_reg;
  reg sum_done_new;
  reg sum_done_reg;

  reg sum_pipelinestage1_execute_new;
  reg sum_pipelinestage1_execute_reg;

  reg                  sync_reset_metastable;
  reg                  sync_reset;

  reg                  word_count_we   [0:1];
  reg [ADDR_WIDTH-1:0] word_count_new  [0:1];
  reg [ADDR_WIDTH-1:0] word_count_reg  [0:1];

  //----------------------------------------------------------------
  // Output buffer regs for tx/extractor connection.
  //----------------------------------------------------------------

  reg        tx_packet_available_reg;
  reg        tx_fifo_empty_reg;
  reg        tx_fifo_rd_valid_reg;
  reg [63:0] tx_fifo_rd_data_reg;
  reg  [3:0] tx_bytes_last_word_reg;

  //----------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------

  wire           [63:0] ram_rd_data [1:0];
  wire                  ram_error   [1:0];
  wire                  ram_busy    [1:0];

  wire                  parser;
  wire                  fifo;
  wire [ADDR_WIDTH-1:0] fifo_word_count_p1;

  //----------------------------------------------------------------
  // Wire and output assignments
  //----------------------------------------------------------------

  assign parser                          = current_mem_reg;
  assign fifo                            = ~ current_mem_reg;
  assign fifo_word_count_p1              = word_count_reg[ fifo ] + 1; //TODO handle overflow

  assign o_busy = ram_busy[ parser ];

  assign o_error = (mem_state_reg[0] == STATE_ERROR_GENERAL) ||
                   (mem_state_reg[1] == STATE_ERROR_GENERAL) ||
                   ram_error[0] ||
                   ram_error[1] ||
                   bad_input_reg;

  assign bad_input_new = (mem_state_reg[parser] == STATE_EMPTY) && //TODO raise error if multiple command signals risen
                         (i_read_en || i_sum_en || i_parser_update_length || i_parser_transfer);


  assign o_dispatch_tx_packet_available  = tx_packet_available_reg;
  assign o_dispatch_tx_fifo_empty        = tx_fifo_empty_reg;
  assign o_dispatch_tx_fifo_rd_valid     = tx_fifo_rd_valid_reg;
  assign o_dispatch_tx_fifo_rd_data      = tx_fifo_rd_data_reg;
  assign o_dispatch_tx_bytes_last_word   = tx_bytes_last_word_reg;

  assign o_parser_current_empty          = mem_state_reg[ parser ] == STATE_EMPTY;
  assign o_parser_current_memory_full    = (mem_state_reg[ parser ] == STATE_HAS_DATA && ram_addr_hi_reg[ parser ] == ADDRESS_FULL) ||
                                           (mem_state_reg[ parser ] == STATE_HAS_DATA && ram_addr_hi_reg[ parser ] == ADDRESS_ALMOST_FULL && i_write_en) ||
                                           (mem_state_reg[ parser ] > STATE_HAS_DATA); //TODO verify
  assign o_read_data = read_data;
  assign o_sum = sum_reg;
  assign o_sum_done = sum_done_reg;

  //----------------------------------------------------------------
  // Output reg buffers
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  if (i_areset) begin
    tx_packet_available_reg <= 0;
    tx_fifo_empty_reg       <= 0;
    tx_fifo_rd_valid_reg    <= 0;
    tx_fifo_rd_data_reg     <= 0;
    tx_bytes_last_word_reg  <= 0;
  end else begin
    tx_packet_available_reg <= (mem_state_reg[ fifo ] == STATE_FIFO_OUT);

    tx_fifo_empty_reg <= 0;
    if (ram_addr_hi_reg[ fifo ] == fifo_word_count_p1) begin
      case (mem_state_reg[ fifo ])
        STATE_FIFO_OUT:          tx_fifo_empty_reg <= 1;
        STATE_FIFO_OUT_TRANSMIT: tx_fifo_empty_reg <= 1;
        default: ;
      endcase
    end

    tx_fifo_rd_valid_reg   <= fifo_rd_valid_reg;
    tx_fifo_rd_data_reg    <= ram_rd_data[ fifo ];
    tx_bytes_last_word_reg <= bytes_last_word_reg[ fifo ];
  end

  //----------------------------------------------------------------
  // Memory holding the Tx buffer
  //----------------------------------------------------------------

  memory_ctrl #(.ADDR_WIDTH(ADDR_WIDTH)) mem0 (
    .i_clk(i_clk),
    .i_areset(i_areset),

    .i_read_64(ram_rd[0]),
    .i_write_64(ram_wr[0]),
    .i_write_data(ram_wr_data[0]),

    .i_addr_hi(ram_addr_hi[0]),
    .i_addr_lo(ram_addr_lo[0]),

    .o_data(ram_rd_data[0]),
    .o_error(ram_error[0]),
    .o_busy(ram_busy[0])
  );

  memory_ctrl #(.ADDR_WIDTH(ADDR_WIDTH)) mem1 (
    .i_clk(i_clk),
    .i_areset(i_areset),

    .i_read_64(ram_rd[1]),
    .i_write_64(ram_wr[1]),
    .i_write_data(ram_wr_data[1]),

    .i_addr_hi(ram_addr_hi[1]),
    .i_addr_lo(ram_addr_lo[1]),

    .o_data(ram_rd_data[1]),
    .o_error(ram_error[1]),
    .o_busy(ram_busy[1])
  );

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
  // BRAM Synchronous register updates
  //----------------------------------------------------------------

  always @ (posedge i_clk)
  begin : bram_reg_update
    integer i;
    for (i = 0; i < 2; i = i + 1) begin
      if (sync_reset) begin
        ram_addr_hi_reg[i] <= 'b0;
      end else begin
        if (ram_addr_hi_we[i])
          ram_addr_hi_reg[i] <= ram_addr_hi_new[i];
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
      //Pipeline stage 0
      bad_input_reg   <= 0;
      current_mem_reg <= 0;
      read_cycle_reg  <= 0;
      sum_reg         <= 0;
      sum_addr_reg    <= 0;
      sum_counter_reg <= 0;
      sum_cycle_reg   <= 0;

      for (i = 0; i < 2; i = i + 1) begin
        bytes_last_word_reg[i] <= 0;
        mem_state_reg[i] <= STATE_EMPTY;
        word_count_reg[i] <= 'b0;
      end

      //Pipleline stage 1
      carry_delayed_reg    <= 0;
      sum_delayed_reg      <= 0;
      sum_done_reg         <= 0;
      sum_done_delayed_reg <= 0;
      sum_pipelinestage1_execute_reg <= 0;

      fifo_rd_valid_reg   <= 0;

    end else begin
      //Pipeline stage 0
      bad_input_reg <= bad_input_new;
      if (current_mem_we)
        current_mem_reg <= current_mem_new;
      read_cycle_reg <= read_cycle_new;
      if (sum_we)
        sum_reg <= sum_new;
      if (sum_addr_we)
        sum_addr_reg <= sum_addr_new;
      if (sum_counter_we)
        sum_counter_reg <= sum_counter_new;
      sum_cycle_reg <= sum_cycle_new;
      sum_done_reg <= sum_done_new;

      for (i = 0; i < 2; i = i + 1) begin
        if (bytes_last_word_we[i])
          bytes_last_word_reg[i] <= bytes_last_word_new[i];
        if (mem_state_we[i])
          mem_state_reg[i] <= mem_state_new[i];
        if (word_count_we[i])
          word_count_reg[i] <= word_count_new[i];
      end

      //Pipleline stage 1
      carry_delayed_reg <= carry_delayed_new;
      sum_delayed_reg <= sum_delayed_new;
      sum_done_delayed_reg <= sum_done_delayed_new;
      sum_pipelinestage1_execute_reg <= sum_pipelinestage1_execute_new;

      //Misc.
      fifo_rd_valid_reg <= fifo_rd_valid_new;
    end
  end

  //----------------------------------------------------------------
  // Parser/Crypto read port.
  //----------------------------------------------------------------

  always @*
  begin
    read_data = 64'hdeadbeefbaadf00d;
    if (read_cycle_reg)
      read_data = ram_rd_data[parser];
  end

  //----------------------------------------------------------------
  // Internet checksum code
  //----------------------------------------------------------------

  task internet_sum_pipelinestage0(
    input  [15:0] data0,
    input  [15:0] data1,
    input  [15:0] data2,
    input  [15:0] data3,
    output [15:0] s_out,
    output  [2:0] c_out
  );
  begin : internet_sum_locals0
    reg [15:0] sum_b [0:1];
    reg [15:0] sum_c;
    reg [2:0] carry;
    { carry[0], sum_b[0] } = { 1'b0, data0 } + { 1'b0, data1 };
    { carry[1], sum_b[1] } = { 1'b0, data2 } + { 1'b0, data3 };
    { carry[2], sum_c } = { 1'b0, sum_b[0] } + { 1'b0, sum_b[1] };

    s_out = sum_c;
    c_out = carry;
  end
  endtask

  task internet_sum_pipelinestage1(
     input  [15:0] s_in0,
     input  [15:0] s_in1,
     input   [2:0] c_in,
     output [15:0] s_out
  );
  begin : internet_sum_locals1
    reg  [3:0] carry;
    reg  [2:0] msb;
    reg  [2:0] msb_p1;
    reg [15:0] sum_d;
    reg [15:0] sum_e;
    reg        sum_e_carry;
    reg [15:0] sum_e_p1;

    carry[2:0] = c_in;

    { carry[3], sum_d } = { 1'b0, s_in0 } + { 1'b0, s_in1 }; //add data sums to original sum

    msb =
      { 2'b00, carry[0] } +
      { 2'b00, carry[1] } +
      { 2'b00, carry[2] } +
      { 2'b00, carry[3] };

    msb_p1 =
      { 2'b00, carry[0] } +
      { 2'b00, carry[1] } +
      { 2'b00, carry[2] } +
      { 2'b00, carry[3] } + 3'b001 ;

    { sum_e_carry, sum_e } = { 1'b0, sum_d } + { 14'h0, msb };
    sum_e_p1 = sum_d + { 13'h0, msb_p1 };

    s_out = sum_e_carry ? sum_e_p1 : sum_e;
  end
  endtask

  task internet_sum(
    input  [15:0] s_in,
    input  [15:0] data0,
    input  [15:0] data1,
    input  [15:0] data2,
    input  [15:0] data3,
    output [15:0] s_out
  );
  begin : internet_sum_combined
    reg [15:0] s_tmp;
    reg  [2:0] c_tmp;
    internet_sum_pipelinestage0( data0, data1, data2, data3, s_tmp, c_tmp );
    internet_sum_pipelinestage1( s_in, s_tmp, c_tmp, s_out );
  end
  endtask

  always @*
  begin
    sum_we = 0;
    sum_new = 0;
    sum_done_new = sum_done_delayed_reg;
    if (sum_pipelinestage1_execute_reg) begin
      sum_we = 1;
      internet_sum_pipelinestage1( sum_reg, sum_delayed_reg, carry_delayed_reg, sum_new );
    end
    if (i_sum_en) begin
      if (i_sum_bytes == 0)
        sum_done_new = 1;
    end
    if (i_sum_reset) begin
      sum_we = 1;
      sum_new = i_sum_reset_value;
    end
  end

  always @*
  begin : sum_process
    reg  [7:0] sum_ctrl;
    sum_pipelinestage1_execute_new = 0;
    sum_delayed_new = 0;
    carry_delayed_new = 0;
    sum_addr_we = 0;
    sum_addr_new = 0;
    sum_counter_we = 0;
    sum_counter_new = 0;
    sum_ctrl = 0;
    sum_cycle_new = 0;
    sum_done_delayed_new = 0;

    if (sum_cycle_reg) begin : sum_ctrl_locals
      reg [63:0] data;
      reg [15:0] d0;
      reg [15:0] d1;
      reg [15:0] d2;
      reg [15:0] d3;
      sum_pipelinestage1_execute_new = 1;

      case (sum_counter_reg)
        0: sum_ctrl = 8'b0000_0000;
        1: sum_ctrl = 8'b1000_0000;
        2: sum_ctrl = 8'b1100_0000;
        3: sum_ctrl = 8'b1110_0000;
        4: sum_ctrl = 8'b1111_0000;
        5: sum_ctrl = 8'b1111_1000;
        6: sum_ctrl = 8'b1111_1100;
        7: sum_ctrl = 8'b1111_1110;
        default: sum_ctrl = 8'b1111_1111;
      endcase

      if (sum_counter_reg <= 8) sum_done_delayed_new = 1;

      data = ram_rd_data[parser];
      d0 = { sum_ctrl[7] ? data[63-:8] : 8'h00, sum_ctrl[6] ? data[55-:8] : 8'h00 };
      d1 = { sum_ctrl[5] ? data[47-:8] : 8'h00, sum_ctrl[4] ? data[39-:8] : 8'h00 };
      d2 = { sum_ctrl[3] ? data[31-:8] : 8'h00, sum_ctrl[2] ? data[23-:8] : 8'h00 };
      d3 = { sum_ctrl[1] ? data[15-:8] : 8'h00, sum_ctrl[0] ? data[7-:8] : 8'h00 };
      //$display("%s:%0d %h - %h %h - %h %h %h %h", `__FILE__, `__LINE__, sum_counter_reg, sum_ctrl, data, d0, d1, d2, d3 );
      internet_sum_pipelinestage0( d0, d1, d2, d3, sum_delayed_new, carry_delayed_new );
    end

    case ( mem_state_reg[parser] )
      STATE_HAS_DATA:
        begin
          if (i_sum_en) begin
            sum_addr_we = 1;
            sum_addr_new = { i_address_hi, i_address_lo };
            sum_counter_we = 1;
            sum_counter_new = i_sum_bytes;
          end
        end
      STATE_CHECKSUM:
        begin
          sum_addr_we = 1;
          sum_addr_new = sum_addr_reg + 8;
          sum_cycle_new = 1;
          if (sum_cycle_reg) begin
            if (sum_counter_reg > 8) begin
              sum_counter_we = 1;
              sum_counter_new = sum_counter_reg - 8;
            end else begin
              sum_counter_we = 1;
              sum_counter_new = 0;
            end
          end
        end
      default: ;
    endcase
  end


  //----------------------------------------------------------------
  // Parser/FIFO main proc
  //----------------------------------------------------------------

  always @*
  begin
    current_mem_we = 0;
    current_mem_new = 0;
    fifo_rd_valid_new = 0;
    read_cycle_new = 0;

    begin : defaults
      integer i;
      for (i = 0; i < 2; i = i + 1) begin
        bytes_last_word_we[i] = 0;
        bytes_last_word_new[i] = 0;

        mem_state_we[i] = 0;
        mem_state_new[i] = STATE_EMPTY;

        ram_addr_hi[i] = 0;
        ram_addr_hi_we[i] = 0;
        ram_addr_hi_new[i] = 0;

        ram_addr_lo[i] = 0;

        ram_rd[i]  = 0;

        ram_wr[i]  = 0;

        ram_wr_data[i]  = 0;

        word_count_we[i]  = 0;
        word_count_new[i] = 0;
      end
    end

    if (i_parser_clear) begin
      mem_state_we  [parser] = 1;
      mem_state_new [parser] = STATE_EMPTY;
      word_count_we [parser] = 1;
    end else begin
      ram_addr_hi_we[parser]  = 1;
      ram_addr_hi_new[parser] = 0;
      case ( mem_state_reg[parser] )
        STATE_EMPTY:
          begin
            if (i_write_en) begin
              mem_state_we[parser] = 1;
              mem_state_new[parser] = STATE_HAS_DATA;

              if (i_address_internal) begin
                ram_addr_lo[parser] = 0;
                ram_addr_hi[parser] = 0;
                ram_addr_hi_we[parser]  = 1;
                ram_addr_hi_new[parser] = 1;

                word_count_we[parser] = 1;
                word_count_new[parser] = 1;
              end else begin
                ram_addr_lo[parser]     = i_address_lo;
                ram_addr_hi[parser]     = i_address_hi;
                //TODO: Not intended path, not well tested
              end

              ram_wr_data[parser] = i_write_data;

              ram_wr[parser]  = 1;

              //$display("%s:%0d WRITE: %h:%h = %h. wr=%h rd=%h", `__FILE__, `__LINE__, ram_addr_hi[parser], ram_addr_lo[parser], i_write_data, ram_wr[parser], ram_rd[parser] );
            end

          end
        STATE_HAS_DATA:
          begin
            if (i_sum_en && i_sum_bytes != 0) begin
              mem_state_we[parser]  = 1;
              mem_state_new[parser] = STATE_CHECKSUM;
            end
            if (i_read_en) begin
              ram_addr_lo[parser] = i_address_lo;
              ram_addr_hi[parser] = i_address_hi;
              ram_rd[parser] = 1;
              read_cycle_new = 1;
            end
            if (i_write_en) begin

              ram_wr_data[parser] = i_write_data;

              ram_wr[parser] = 1;

              if (i_address_internal) begin
                ram_addr_lo[parser]     = 0;
                ram_addr_hi[parser]     = ram_addr_hi_reg[parser];
                ram_addr_hi_we[parser]  = 1;
                ram_addr_hi_new[parser] = ram_addr_hi_reg[parser] + 1;

                word_count_we[parser] = 1;
                word_count_new[parser] = word_count_reg[parser] + 1;
              end else begin
                ram_addr_lo[parser]     = i_address_lo;
                ram_addr_hi[parser]     = i_address_hi;
              end
              //$display("%s:%0d WRITE: %h:%h = %h. wr=%h rd=%h", `__FILE__, `__LINE__, ram_addr_hi[parser], ram_addr_lo[parser], i_write_data, ram_wr[parser], ram_rd[parser] );
            end
            if (i_parser_update_length) begin
              if (i_address_lo == 0) begin
                if (i_address_hi == 0) begin
                  word_count_we[parser] = 1;
                  word_count_new[parser] = 0;
                  bytes_last_word_we[parser] = 1;
                  bytes_last_word_new[parser] = 0;
                end else begin
                  word_count_we[parser] = 1;
                  word_count_new[parser] = i_address_hi - 1;
                  bytes_last_word_we[parser] = 1;
                  bytes_last_word_new[parser] = 8;
                end
              end else begin
                word_count_we[parser] = 1;
                word_count_new[parser] = i_address_hi;
                bytes_last_word_we[parser] = 1;
                bytes_last_word_new[parser] = { 1'b0, i_address_lo };
              end
            end
            if (i_parser_transfer) begin
              mem_state_we[parser] = 1;
              mem_state_new[parser] = STATE_FIFO_OUT;
            end
          end
        STATE_CHECKSUM:
          begin
            { ram_addr_hi[parser], ram_addr_lo[parser] } = sum_addr_reg;
            ram_rd[parser] = 1;
            if (sum_counter_we && sum_counter_new <= 8) begin
              mem_state_we[parser] = 1;
              mem_state_new[parser] = STATE_HAS_DATA;
            end
            if (sum_counter_reg <= 8) begin
              mem_state_we[parser] = 1;
              mem_state_new[parser] = STATE_HAS_DATA;
            end
          end
        STATE_FIFO_OUT:
          if (mem_state_reg[fifo] == STATE_EMPTY) begin
            current_mem_we  = 1;
            current_mem_new = ~ current_mem_reg;
            ram_rd[parser] = 1;
            ram_addr_hi_we[parser] = 1;
            ram_addr_hi_new[parser] = 0;
          end
        default ;
      endcase
    end

    // --- FIFO
    case ( mem_state_reg[fifo] )
      STATE_EMPTY: ;
      STATE_FIFO_OUT:
        begin
          ram_rd[fifo]      = 1;
          ram_addr_hi[fifo] = ram_addr_hi_reg[fifo];
          if (i_dispatch_tx_fifo_rd_start) begin
            mem_state_we [fifo] = 1;
            mem_state_new[fifo] = STATE_FIFO_OUT_TRANSMIT;
          end
          if (i_dispatch_tx_packet_read) begin
            mem_state_we [fifo] = 1;
            mem_state_new[fifo] = STATE_EMPTY;
            ram_addr_hi_we[fifo] = 1;
            ram_addr_hi_new[fifo] = 0;
          end
        end
      STATE_FIFO_OUT_TRANSMIT:
        begin
          ram_rd[fifo]      = 1;
          ram_addr_hi[fifo] = ram_addr_hi_reg[fifo];

          if (ram_addr_hi_reg[fifo] < fifo_word_count_p1) begin
            fifo_rd_valid_new      = 1;
            ram_addr_hi_we  [fifo] = 1;
            ram_addr_hi_new [fifo] = ram_addr_hi_reg[fifo] + 1;
          end
          if (i_dispatch_tx_packet_read) begin
            mem_state_we [fifo] = 1;
            mem_state_new[fifo] = STATE_EMPTY;
            ram_addr_hi_we[fifo] = 1;
            ram_addr_hi_new[fifo] = 0;
          end
        end
      STATE_ERROR_GENERAL:
        begin
          mem_state_we [fifo] = 1;
          mem_state_new[fifo] = STATE_EMPTY;
          ram_addr_hi_we [fifo] = 1;
          ram_addr_hi_new[fifo] = 0;
        end
      default:
        begin
          mem_state_we [fifo] = 1;
          mem_state_new[fifo] = STATE_ERROR_GENERAL;
        end
    endcase
  end

endmodule
