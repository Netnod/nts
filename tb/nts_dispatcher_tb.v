module nts_dispatcher_front_tb;

  localparam ADDR_WIDTH=3;

  reg                   i_areset;
  reg                   i_clk;
  reg [7:0]             i_rx_data_valid;
  reg [63:0]            i_rx_data;
  reg                   i_rx_bad_frame;
  reg                   i_rx_good_frame;
  reg                   i_process_frame;
  wire                  o_dispatch_packet_available;
  wire [ADDR_WIDTH-1:0] o_dispatch_counter;
  wire [7:0]            o_dispatch_data_valid;
  reg  [ADDR_WIDTH-1:0] i_dispatch_raddr;
  wire [63:0]           o_dispatch_rdata;

  nts_dispatcher_front #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),
    .i_rx_data_valid(i_rx_data_valid),
    .i_rx_data(i_rx_data),
    .i_rx_bad_frame(i_rx_bad_frame),
    .i_rx_good_frame(i_rx_good_frame),
    .i_process_frame(i_process_frame),
    .o_dispatch_packet_available(o_dispatch_packet_available),
    .o_dispatch_counter(o_dispatch_counter),
    .o_dispatch_data_valid(o_dispatch_data_valid),
    .i_dispatch_raddr(i_dispatch_raddr),
    .o_dispatch_rdata(o_dispatch_rdata)
  );
  `define assert(condition) if(!condition) begin $display("ASSERT FAILED"); $finish(1); end
  initial begin
    $display("nts dispatcher test.");
    i_clk = 1;
    i_areset = 0;
    i_dispatch_raddr = 'b0;
    i_rx_data_valid = 'b0;
    i_rx_data = 'b0;
    i_rx_bad_frame = 'b0;
    i_rx_good_frame = 'b0;
    i_process_frame = 'b0;
    #10 i_areset = 1;
    #10 i_areset = 0;
    `assert(o_dispatch_packet_available == 'b0);
    `assert((o_dispatch_counter == 'b0));
    `assert((o_dispatch_data_valid == 'b0));
/*
    $display("%h", o_dispatch_packet_available);
    $display("%h", o_dispatch_counter);
    $display("%h", o_dispatch_data_valid);
    $display("%h", o_dispatch_rdata);
*/
    $finish;
  end
  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
