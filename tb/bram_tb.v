module bram_testbench;
  parameter AW = 8;
  parameter DW = 64;

  reg clk;
  reg [AW-1:0] address;
  reg write_enable;    
  reg [DW-1:0] data_in;
  wire [DW-1:0] data_out;

  bram #(.ADDR_WIDTH(8),.DATA_WIDTH(64)) ram_test (
    .i_clk(clk), 
    .i_addr(address), 
    .i_write(write_enable), 
    .i_data(data_in),
    .o_data(data_out));

    initial
      begin
        $display("bram test.");
        clk = 1;

        #10 write_enable = 1;
        address = 0;
        data_in = 64'hdeadbeef00000000;  
        #10 address = 1;
        data_in = 64'habad1deac0fef00d;

        #10 write_enable = 0;
        #10 $display("0x%08h", data_out);
        #10 address = 0;
        #10 $display("0x%08h", data_out);
        #10 address = 1;
        #10 $display("0x%08h", data_out);
        #40 $finish;
      end

  always begin
    #5 clk = ~clk;
  end

endmodule
