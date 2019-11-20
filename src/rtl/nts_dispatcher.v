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
  parameter ADDR_WIDTH = 8
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
  output wire [63:0]           o_dispatch_fifo_rd_data
);

  localparam STATE_EMPTY         = 0;
  localparam STATE_HAS_DATA      = 1;
  //localparam STATE_PROCESS       = 2;
  //localparam STATE_GOOD          = 3;
  localparam STATE_GOOD_PROCESS  = 2;
  localparam STATE_FIFO_OUT_INIT_0 = 3;
  localparam STATE_FIFO_OUT_INIT_1 = 4;
  localparam STATE_FIFO_OUT_INIT_2 = 5;
  localparam STATE_FIFO_OUT      = 6;
  localparam STATE_FIFO_OUT_FIN_0  = 7;
  localparam STATE_FIFO_OUT_FIN_1  = 8;
  localparam STATE_ERROR_GENERAL = 9;
  //localparam STATE_ERROR_BUFFER_OVERRUN = 7;

  reg           drop_next_frame;
  reg               current_mem;
  reg                fifo_empty;
  reg  [3:0]          mem_state [1:0];
  reg                     write [1:0];
  reg  [63:0]            w_data [1:0];
  wire [63:0]            r_data [1:0];
  reg  [ADDR_WIDTH-1:0]  r_addr;
  reg  [ADDR_WIDTH-1:0]  w_addr [1:0];
  reg  [ADDR_WIDTH-1:0] counter [1:0];
  reg  [7:0]         data_valid [1:0];

  reg [63:0] fifo_rd_data;
  reg        fifo_rd_valid;

  assign o_dispatch_packet_available  = mem_state[ ~ current_mem ] == STATE_FIFO_OUT_INIT_0; //STATE_FIFO_OUT;
  assign o_dispatch_counter           = counter[ ~ current_mem ];
  assign o_dispatch_data_valid        = data_valid[ ~ current_mem ];
  assign o_dispatch_fifo_empty        = fifo_empty;
  assign o_dispatch_fifo_rd_valid     = fifo_rd_valid;
  assign o_dispatch_fifo_rd_data      = fifo_rd_data; //r_data[ ~ current_mem ];

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

  //reg [63:0] fifo_next_reg;
  //reg [63:0] fifo_next2_reg;

  //always @*
  //  fifo_rd_data = i_dispatch_fifo_rd_en ? fifo_next2_reg : fifo_next_reg;

  always @ (posedge i_clk, posedge i_areset)
  begin
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
/*
          STATE_FIFO_OUT_INIT_2:
            begin
              mem_state[ ~ current_mem] <= STATE_FIFO_OUT;
              r_addr <= 2;
              fifo_next2_reg <= r_data[ ~ current_mem ];
            end
*/
          STATE_FIFO_OUT:
            begin
              fifo_rd_data <= r_data[ ~ current_mem ];
              fifo_rd_valid <= 1;
              //if (i_dispatch_fifo_rd_en) begin
                //$display("%s:%0d i_dispatch_fifo_rd_en. Emit: %h ", `__FILE__, `__LINE__, fifo_next_reg);
                //fifo_rd_data <= fifo_next_reg;
                //fifo_next_reg <= fifo_next2_reg;
                //fifo_next2_reg <= r_data[ ~ current_mem ];
                if (r_addr == counter[ ~ current_mem]) begin
                  //fifo_empty <= 'b1;
                  mem_state[ ~ current_mem] <= STATE_FIFO_OUT_FIN_0;
                end else begin
                  r_addr <= r_addr + 1;
                end
              //end
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
             if (i_rx_data_valid == 'hff) begin
               mem_state[current_mem] <= STATE_HAS_DATA;
             end else if (i_rx_data_valid != 0) begin
               //receiving last frame, unexpectedly
               mem_state[current_mem] <= STATE_ERROR_GENERAL;
             end else if (i_rx_good_frame) begin
               //receiving last frame, unexpectedly
               mem_state[current_mem] <= STATE_ERROR_GENERAL;
             end
           STATE_HAS_DATA:
             begin
               if (i_rx_good_frame) begin
                 $display("%s:%0d data_valid: %h (%b)", `__FILE__, `__LINE__, i_rx_data_valid, i_rx_data_valid);
                 data_valid[current_mem] <= i_rx_data_valid;
                 mem_state[current_mem] <= STATE_GOOD_PROCESS; /* *** */
               end
             end
           STATE_GOOD_PROCESS:
             if (mem_state[ ~ current_mem] == STATE_EMPTY) begin
               mem_state[current_mem] <= STATE_FIFO_OUT_INIT_0;
               current_mem <= ~ current_mem;
             end
           default:
             mem_state[current_mem] <= STATE_EMPTY;
          endcase
          if (i_rx_data_valid != 'b0) begin
            w_data[current_mem] <= i_rx_data;
            if (mem_state[current_mem] == STATE_EMPTY) begin
              if (drop_next_frame) begin
                 if (i_rx_good_frame) begin
                   drop_next_frame <= 1'b0;
                 end
              end else begin // accept frame
                write[current_mem]     <= 1'b1;
                w_addr[current_mem]    <= 'b0;
                counter[current_mem]   <= 'b0;
              end
            end else if (mem_state[current_mem] == STATE_HAS_DATA /* || mem_state[current_mem] == STATE_PROCESS */) begin
              if (counter[current_mem] != ~ 'b0) begin
                write[current_mem]     <= 1'b1;
                w_addr[current_mem]    <= counter[current_mem] + 1;
                counter[current_mem]   <= counter[current_mem] + 1;
              end // not buffer overrun
            end else if (/*mem_state[current_mem] == STATE_GOOD ||*/ mem_state[current_mem] == STATE_GOOD_PROCESS) begin
               drop_next_frame  <= 1'b1;
            end
          end //rx_data_valid
        end // not bad frame
    end //posedge i_clk
  end //always begin
endmodule
