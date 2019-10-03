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

module memory_ctrl #(
  parameter ADDR_WIDTH = 8
) (
  input                   i_clk,
  input                   i_areset,

  input                   i_read_64,
  input                   i_write_64,
  input            [63:0] i_write_data,

  input  [ADDR_WIDTH-1:0] i_addr_hi,
  input             [2:0] i_addr_lo,

  output                  o_error,
  output                  o_busy,
  output           [63:0] o_data
);
  localparam DATA_WIDTH = 64;
  localparam BITS_STATE = 3;

  localparam STATE_IDLE                      = 0;
  localparam STATE_UNALIGNED_WRITE64_PRELOAD = 1;
  localparam STATE_UNALIGNED_WRITE64         = 2;
  localparam STATE_UNALIGNED_WRITE64_LAST    = 3;
  localparam STATE_ERROR                     = 7;

  reg                   read64_we;
  reg                   read64_new;
  reg                   read64_reg;

  reg                   addr_a_we;
  reg  [ADDR_WIDTH-1:0] addr_a_new;
  reg  [ADDR_WIDTH-1:0] addr_a_reg;
  reg                   addr_b_we;
  reg  [ADDR_WIDTH-1:0] addr_b_new;
  reg  [ADDR_WIDTH-1:0] addr_b_reg;

  reg                   lo_we;
  reg             [2:0] lo_new;
  reg             [2:0] lo_reg;

  reg                   tmp_write;
  reg            [63:0] tmp_write_data;

  reg            [63:0] tmp_read_data;

  reg                   state_we;
  reg  [BITS_STATE-1:0] state_new;
  reg  [BITS_STATE-1:0] state_reg;

  reg            [63:0] write_1delay_reg;
  reg            [55:0] write_2delay_reg;

  wire [ADDR_WIDTH-1:0] addr_hi_p1;
  wire [ADDR_WIDTH-1:0] addr_a;
  wire [ADDR_WIDTH-1:0] addr_b;
  wire           [63:0] data_a;
  wire           [63:0] data_b;
  wire                  global_enable;
  wire                  write;

  wire                  write_op_aligned;
  wire                  write_op_unaligned;


  assign write_op_aligned   = i_write_64 && (i_addr_lo == 3'b000);
  assign write_op_unaligned = i_write_64 && (i_addr_lo != 3'b000);

  assign addr_hi_p1    = i_addr_hi + 1;

  assign addr_a        = (state_reg == STATE_IDLE) ? i_addr_hi                 : addr_a_reg;
  assign addr_b        = (state_reg == STATE_IDLE) ? addr_hi_p1                : addr_b_reg;
  assign global_enable = (state_reg == STATE_IDLE) ? (i_write_64 || i_read_64) : 1;
  assign write         = tmp_write; //(state_reg == STATE_IDLE) ? write_op_aligned          : (state_reg == STATE_UNALIGNED_WRITE64 ? 1 : 0);

  assign o_busy  = state_reg != STATE_IDLE;
  assign o_error = state_reg == STATE_ERROR;
  assign o_data  = tmp_read_data;

  bram_dpge #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(64) ) ram (
     .i_clk(i_clk),
     .i_en(global_enable),
     .i_we_a(write),
     .i_addr_a(addr_a),
     .i_addr_b(addr_b),
     .i_data(tmp_write_data),
     .o_data_a(data_a),
     .o_data_b(data_b)
  );

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      addr_a_reg       <= 0;
      addr_b_reg       <= 0;
      lo_reg           <= 0;
      state_reg        <= STATE_IDLE;
      write_1delay_reg <= 0;
      write_2delay_reg <= 0;

    end else if (i_clk) begin
      if (addr_a_we) addr_a_reg <= addr_a_new;
      if (addr_b_we) addr_b_reg <= addr_b_new;
      if (lo_we) lo_reg <= lo_new;
      if (read64_we) read64_reg <= read64_new;
      if (state_we) state_reg <= state_new;

      write_1delay_reg <= i_write_data;
      write_2delay_reg <= write_1delay_reg[55:0];

      //if (state_we) $display("%s:%0d FSM state change, old: %h new: %h" , `__FILE__, `__LINE__, state_reg, state_new);
    end
  end

  always @*
  begin : read_logic
    tmp_read_data = 0;
    if (read64_reg) begin
      case (lo_reg)
        0: tmp_read_data = { data_a[63:0] };
        1: tmp_read_data = { data_a[55:0], data_b[63:56] };
        2: tmp_read_data = { data_a[47:0], data_b[63:48] };
        3: tmp_read_data = { data_a[39:0], data_b[63:40] };
        4: tmp_read_data = { data_a[31:0], data_b[63:32] };
        5: tmp_read_data = { data_a[23:0], data_b[63:24] };
        6: tmp_read_data = { data_a[15:0], data_b[63:16] };
        7: tmp_read_data = { data_a[ 7:0], data_b[63:8] };
        default: ;
      endcase
    end
  end

  always @*
  begin : write_logic

    tmp_write      = 0;
    tmp_write_data = 0;

    if (state_reg == STATE_IDLE && i_addr_lo == 'b0 && i_write_64) begin
      tmp_write      = 1;
      tmp_write_data = i_write_data;

    end else if (state_reg == STATE_UNALIGNED_WRITE64_PRELOAD) begin : left_preloaded
      tmp_write      = 1;
      //$display("%s:%0d data_a = %h, data_b = %h, write_1delay_reg =%h" , `__FILE__, `__LINE__, data_a, data_b, write_1delay_reg);
      case (lo_reg)
        1: tmp_write_data = { data_a[63:56], write_1delay_reg[63: 8] };
        2: tmp_write_data = { data_a[63:48], write_1delay_reg[63:16] };
        3: tmp_write_data = { data_a[63:40], write_1delay_reg[63:24] };
        4: tmp_write_data = { data_a[63:32], write_1delay_reg[63:32] };
        5: tmp_write_data = { data_a[63:24], write_1delay_reg[63:40] };
        6: tmp_write_data = { data_a[63:16], write_1delay_reg[63:48] };
        7: tmp_write_data = { data_a[63: 8], write_1delay_reg[63:56] };
        default: ;
       endcase
       //$display("%s:%0d WRITE %0d.%0d = %h", `__FILE__, `__LINE__, addr_a, lo_reg, tmp_write_data);
    end else if (state_reg == STATE_UNALIGNED_WRITE64) begin : left_preloaded2
      tmp_write      = 1;
      //$display("%s:%0d data_a = %h, data_b = %h, write_1delay_reg = %h write_2delay_reg = %h" , `__FILE__, `__LINE__, data_a, data_b, write_1delay_reg, write_2delay_reg);
      case (lo_reg)
        1: tmp_write_data = { write_2delay_reg[ 7:0], write_1delay_reg[63: 8] };
        2: tmp_write_data = { write_2delay_reg[15:0], write_1delay_reg[63:16] };
        3: tmp_write_data = { write_2delay_reg[23:0], write_1delay_reg[63:24] };
        4: tmp_write_data = { write_2delay_reg[31:0], write_1delay_reg[63:32] };
        5: tmp_write_data = { write_2delay_reg[39:0], write_1delay_reg[63:40] };
        6: tmp_write_data = { write_2delay_reg[47:0], write_1delay_reg[63:48] };
        7: tmp_write_data = { write_2delay_reg[55:0], write_1delay_reg[63:56] };
        default: ;
       endcase
       //$display("%s:%0d WRITE %0d.%0d = %h", `__FILE__, `__LINE__, addr_a, lo_reg, tmp_write_data);
    end else if (state_reg == STATE_UNALIGNED_WRITE64_LAST) begin : right_preloaded
      tmp_write      = 1;
      //$display("%s:%0d data_a = %h, data_b = %h, write_1delay_reg = %h write_2delay_reg = %h" , `__FILE__, `__LINE__, data_a, data_b, write_1delay_reg, write_2delay_reg);
      case (lo_reg)
        1: tmp_write_data = { write_2delay_reg[ 7:0], data_b[55:0] };
        2: tmp_write_data = { write_2delay_reg[15:0], data_b[47:0] };
        3: tmp_write_data = { write_2delay_reg[23:0], data_b[39:0] };
        4: tmp_write_data = { write_2delay_reg[31:0], data_b[31:0] };
        5: tmp_write_data = { write_2delay_reg[39:0], data_b[23:0] };
        6: tmp_write_data = { write_2delay_reg[47:0], data_b[15:0] };
        7: tmp_write_data = { write_2delay_reg[55:0], data_b[ 7:0] };
        default: ;
       endcase
       //$display("%s:%0d WRITE %0d.%0d = %h", `__FILE__, `__LINE__, addr_a, lo_reg, tmp_write_data);
    end
  end

  always @*
  begin : FSM
    addr_a_we  = 0;
    addr_a_new = 0;
    addr_b_we  = 0;
    addr_b_new = 0;
    lo_we      = 0;
    lo_new     = 0;
    state_we   = 0;
    state_new  = STATE_IDLE;
    read64_we  = 0;
    read64_new = 0;

    case (state_reg)
      STATE_IDLE:
        begin
          read64_we  = 1;
          lo_we      = 1;
          lo_new     = i_addr_lo;

          //$display("%s:%0d i_addr_lo = %b write_op_unaligned = %b i_read_64 = %b", `__FILE__, `__LINE__, i_addr_lo, write_op_unaligned, i_read_64);

          if (i_read_64) begin
            read64_new = 1;
          end
          else if (write_op_unaligned) begin
            state_we    = 1;
            state_new   = STATE_UNALIGNED_WRITE64_PRELOAD;
            addr_a_we   = 1;
            addr_a_new  = i_addr_hi;
            addr_b_we   = 1;
            addr_b_new  = addr_hi_p1;
          end
        end
      STATE_UNALIGNED_WRITE64_PRELOAD:
        begin
          if (i_write_64) begin
            //delayed write
            if (i_addr_hi != addr_b_reg) begin
              state_we = 1;
              state_new = STATE_ERROR;
            end else begin
              state_we    = 1;
              state_new   = STATE_UNALIGNED_WRITE64;
              addr_a_we   = 1;
              addr_a_new  = i_addr_hi; //write addr next op
              addr_b_we   = 1;
              addr_b_new  = addr_hi_p1; //read addr next op
            end
          end else begin
            //stop delayed write
            state_we  = 1;
            state_new = STATE_IDLE;
          end
        end
      STATE_UNALIGNED_WRITE64:
        begin
          if (i_write_64) begin
            //delayed write
            if (i_addr_hi != addr_b_reg) begin
              state_we = 1;
              state_new = STATE_ERROR;
            end else begin
              addr_a_we   = 1;
              addr_a_new  = i_addr_hi; //write addr next op
              addr_b_we   = 1;
              addr_b_new  = addr_hi_p1; //read addr next op
            end
          end else begin
            //stop delayed write
            addr_a_we   = 1;
            addr_a_new  = addr_b_reg; //write addr next op
            state_we  = 1;
            state_new = STATE_UNALIGNED_WRITE64_LAST;
          end
        end
      STATE_UNALIGNED_WRITE64_LAST:
        begin
          state_we  = 1;
          state_new = STATE_IDLE;
          if (i_write_64) begin
            state_we = 1;
            state_new = STATE_ERROR;
          end
        end
      default:
        begin
          state_we  = 1;
          state_new = STATE_IDLE;
          //$display("%s:%0d error, state: state_reg: %h", `__FILE__, `__LINE__, state_reg);
        end
    endcase
  end
endmodule
