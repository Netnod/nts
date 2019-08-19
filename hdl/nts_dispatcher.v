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

module nts_dispatcher_front #(
  parameter ADDR_WIDTH = 10
) (
  input  wire        i_areset, // async reset
  input  wire        i_clk,
  // MAC
  input  wire [7:0]  i_rx_data_valid,
  input  wire [63:0] i_rx_data,
  input  wire        i_rx_bad_frame,
  input  wire        i_rx_good_frame,
  // PreProcessor decision
  input wire         i_process_frame,
  // NTP Config
  // -- TBD --
  // interface to nts_dispatcher_backend
  output wire                  o_dispatch_packet_available,
  input  wire                  i_dispatch_packet_read_discard,
  output wire [ADDR_WIDTH-1:0] o_dispatch_counter,
  output wire [7:0]            o_dispatch_data_valid,
  output wire                  o_dispatch_fifo_empty,
  input  wire                  i_dispatch_fifo_rd_en,
  output wire [63:0]           o_dispatch_fifo_rd_data
);

  localparam STATE_EMPTY         = 0;
  localparam STATE_HAS_DATA      = 1;
  localparam STATE_PROCESS       = 2;
  localparam STATE_GOOD          = 3;
  localparam STATE_GOOD_PROCESS  = 4;
  localparam STATE_FIFO_OUT      = 5;
  localparam STATE_ERROR_GENERAL = 6;
  localparam STATE_ERROR_BUFFER_OVERRUN = 7;

  reg           drop_next_frame;
  reg               current_mem;
  reg                fifo_empty;
  reg  [2:0]          mem_state [1:0];
  reg                     write [1:0];
  reg  [63:0]            w_data [1:0];
  wire [63:0]            r_data [1:0];
  reg  [ADDR_WIDTH-1:0]  r_addr;
  reg  [ADDR_WIDTH-1:0]  w_addr [1:0];
  reg  [ADDR_WIDTH-1:0] counter [1:0];
  reg  [7:0]         data_valid [1:0];


  assign o_dispatch_packet_available  = mem_state[ ~ current_mem ] == STATE_FIFO_OUT;
  assign o_dispatch_counter           = counter[ ~ current_mem ];
  assign o_dispatch_data_valid        = data_valid[ ~ current_mem ];
  assign o_dispatch_fifo_empty        = fifo_empty;
  assign o_dispatch_fifo_rd_data      = r_data[ ~ current_mem ];

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

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin
      current_mem   <= 'b0;
      fifo_empty    <= 'b1;
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
      if (i_dispatch_packet_read_discard) begin
        mem_state[ ~ current_mem] <= STATE_EMPTY;
        fifo_empty <= 'b1;
      end
      if (i_dispatch_fifo_rd_en) begin
        if (r_addr == counter[~current_mem]) begin
          fifo_empty <= 'b1;
        end else begin
          r_addr <= r_addr + 1;
        end
      end
      if (i_rx_bad_frame) begin
         mem_state[current_mem]  <= STATE_EMPTY;
         w_addr[current_mem]     <= 'b0;
         counter[current_mem]    <= 'b0;
         data_valid[current_mem] <= 'b0;
       end else begin
         //$display("Current mem: %h", current_mem);
         //$display("Current state: %h", mem_state[current_mem]);
         //$display("i_rx_good_frame: %h", i_rx_good_frame);
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
                 data_valid[current_mem] <= i_rx_data_valid;
               end
               if (i_rx_good_frame && i_process_frame) begin
                 mem_state[current_mem] <= STATE_GOOD_PROCESS;
               end else if (i_rx_good_frame) begin
                 mem_state[current_mem] <= STATE_GOOD;
               end else if (i_process_frame) begin
                 mem_state[current_mem] <= STATE_PROCESS;
               end
             end
           STATE_PROCESS:
             begin
               if (i_rx_good_frame) begin
                 mem_state[current_mem] <= STATE_GOOD_PROCESS;
               end
               if (counter[current_mem] == ~ 'b0 && i_rx_data_valid != 'b0) begin
                 mem_state[current_mem] <= STATE_ERROR_BUFFER_OVERRUN;
               end
             end
           STATE_GOOD:
             if (i_process_frame) begin
               mem_state[current_mem] <= STATE_GOOD_PROCESS;
             end
           STATE_GOOD_PROCESS:
             if (mem_state[ ~ current_mem] == STATE_EMPTY) begin
               mem_state[current_mem] <= STATE_FIFO_OUT;
               current_mem <= ~ current_mem;
               fifo_empty  <= 'b0;
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
            end else if (mem_state[current_mem] == STATE_HAS_DATA || mem_state[current_mem] == STATE_PROCESS) begin
              if (counter[current_mem] != ~ 'b0) begin
                write[current_mem]     <= 1'b1;
                w_addr[current_mem]    <= counter[current_mem] + 1;
                counter[current_mem]   <= counter[current_mem] + 1;
              end // not buffer overrun
            end else if (mem_state[current_mem] == STATE_GOOD || mem_state[current_mem] == STATE_GOOD_PROCESS) begin
               drop_next_frame  <= 1'b1;
            end
          end //rx_data_valid
        end // not bad frame
    end //posedge i_clk
  end //always begin
endmodule
