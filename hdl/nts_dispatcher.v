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
  output wire [ADDR_WIDTH-1:0] o_dispatch_counter,
  output wire [7:0]            o_dispatch_data_valid,
  input  wire [ADDR_WIDTH-1:0] i_dispatch_raddr,
  output wire [63:0]           o_dispatch_rdata
);

  localparam STATE_EMPTY         = 0;
  localparam STATE_HAS_DATA      = 1;
  localparam STATE_PROCESS       = 2;
  localparam STATE_GOOD          = 3;
  localparam STATE_GOOD_PROCESS  = 4;
  localparam STATE_ERROR_BUFFER_OVERRUN = 7;

  reg           drop_next_frame;
  reg               current_mem;
  reg  [2:0]          mem_state [1:0];
  reg                     write [1:0];
  reg  [63:0]            w_data [1:0];
  wire [63:0]            r_data [1:0];
  reg  [ADDR_WIDTH-1:0]  w_addr [1:0];
  reg  [ADDR_WIDTH-1:0] counter [1:0];
  reg  [7:0]         data_valid [1:0];


  assign o_dispatch_packet_available  = mem_state[ ~ current_mem ] == STATE_GOOD_PROCESS;
  assign o_dispatch_counter           = counter[ ~ current_mem ];
  assign o_dispatch_data_valid        = data_valid[ ~ current_mem ];
  assign o_dispatch_rdata             = r_data[ ~ current_mem ];

  bram #(ADDR_WIDTH,64) mem0 (
     .i_clk(i_clk),
     .i_addr(write[0] ? w_addr[0] : i_dispatch_raddr),
     .i_write(write[0]),
     .i_data(w_data[0]),
     .o_data(r_data[0])
  );
  bram #(ADDR_WIDTH,64) mem1 (
     .i_clk(i_clk),
     .i_addr(write[1] ? w_addr[1] : i_dispatch_raddr),
     .i_write(write[1]),
     .i_data(w_data[1]),
     .o_data(r_data[1])
  );

  always @ (posedge i_clk, posedge i_areset)
  begin
    if (i_areset == 1'b1) begin
      current_mem   <= 'b0;
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
      if (i_rx_bad_frame) begin
         mem_state[current_mem]  <= STATE_EMPTY;
         w_addr[current_mem]     <= 'b0;
         counter[current_mem]    <= 'b0;
         data_valid[current_mem] <= 'b0;
       end else begin
         case (mem_state[current_mem])
           STATE_EMPTY:
             //TBD
              ;
           STATE_HAS_DATA:
             if (i_rx_good_frame) begin
               data_valid[current_mem] <= i_rx_data_valid;
             end else if (i_rx_good_frame && i_process_frame) begin
               mem_state[current_mem] <= STATE_GOOD_PROCESS;
             end else if (i_rx_good_frame) begin
               mem_state[current_mem] <= STATE_GOOD;
             end else if (i_process_frame) begin
               mem_state[current_mem] <= STATE_GOOD_PROCESS;
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


