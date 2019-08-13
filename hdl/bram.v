module bram #(
    //Parameters
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8
  ) (
    input wire i_clk,
    input wire [ADDR_WIDTH-1:0] i_addr, 
    input wire i_write,
    input wire [DATA_WIDTH-1:0] i_data,
    output reg [DATA_WIDTH-1:0] o_data 
  );

  //Parameterized constant
  localparam DEPTH = 2**ADDR_WIDTH;

  //BRAM array
  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1]; 

  always @ (posedge i_clk)
  begin
    if (i_write) begin
      mem[i_addr] <= i_data;
    end
    else begin
      o_data <= mem[i_addr];
    end     
  end
endmodule
