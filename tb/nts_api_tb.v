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

module nts_api_tb;

  localparam API_SLAVE_BITS = 2;
  localparam integer SPI_REG_SIZE = 1 /* start bit */
                                 + API_SLAVE_BITS
                                 + 1 /* we bit */
                                 + 8 /* addr */
                                 + 32 /* data */;

  reg                                 i_areset;
  reg                                 i_clk;
  reg                                 i_spi_sclk;
  reg                                 i_spi_mosi;
  reg                                 i_spi_ss;

  reg  [32*(2**API_SLAVE_BITS)-1 : 0] i_api_read_data;

  reg                                 spi_close_reg;
  reg                                 spi_busy;
  reg              [SPI_REG_SIZE-1:0] tx_buf;
  integer                             tx_counter;
  reg                          [32:0] rx;
  integer                             rx_counter;

  wire      [(2**API_SLAVE_BITS)-1:0] o_api_cs;
  wire                                o_api_we;
  wire                        [7 : 0] o_api_address;
  wire                       [31 : 0] o_api_write_data;
  wire                                o_spi_miso;

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  task spi_transmit_cmd;
    input [API_SLAVE_BITS-1:0] slave;
    input                      we;
    input                [7:0] addr;
    input               [31:0] write_data;
    output  [SPI_REG_SIZE-1:0] tx;
    output             integer tx_bits;
  begin : spi_cmd_transmit_locals
    $display("%s:%0d spi_transmit(%h,%h,%h,%h,...,...)", `__FILE__, `__LINE__, slave, we, addr, write_data);
    `assert(tx_counter == 'b0);
    while (spi_busy) #10 ;
    tx      = { 1'b1, slave, we, addr, write_data };
    tx_bits = SPI_REG_SIZE;
  end
  endtask

  task spi_transmit_wait;
  begin
    $display("%s:%0d spi_wait() begin", `__FILE__, `__LINE__);
    while (tx_counter != 'b0) #10 ;
    $display("%s:%0d spi_wait() end", `__FILE__, `__LINE__);
  end
  endtask

  task spi_close;
  output spi_close_reg;
  begin
    $display("%s:%0d spi_close()", `__FILE__, `__LINE__);
    spi_close_reg = 1'b1;
  end
  endtask

  nts_api #(.CPHA(1), .CPOL(0), .API_SLAVE_BITS(API_SLAVE_BITS)) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),
    .i_spi_sclk(i_spi_sclk),
    .i_spi_mosi(i_spi_mosi),
    .o_spi_miso(o_spi_miso),
    .i_spi_ss(i_spi_ss),
    .o_api_cs(o_api_cs),
    .o_api_we(o_api_we),
    .o_api_address(o_api_address),
    .o_api_write_data(o_api_write_data),
    .i_api_read_data(i_api_read_data)
  );

  initial begin
    $display("Test start %s:%0d ", `__FILE__, `__LINE__);
    i_areset      = 1;
    i_clk         = 0;
    i_spi_sclk    = 0;
    i_spi_mosi    = 0;
    i_spi_ss      = 1;
    i_api_read_data = 128'hdeadbeef_baadf00d_1cee7eaa_12345678;
    rx            = 0;
    rx_counter    = 0;
    tx_counter    = 0;
    spi_close_reg = 0;
    spi_busy      = 0;

    #10 i_areset = 0;

    spi_transmit_cmd( 'h0, 'h0, 'h00, 'h0000_0000, tx_buf, tx_counter);
    spi_transmit_wait();
    spi_close(spi_close_reg);

    spi_transmit_cmd( 'h1, 'h1, 'hff, 'h1234_1234, tx_buf, tx_counter);
    spi_transmit_wait();
    spi_close(spi_close_reg);

    spi_transmit_cmd( 'h0, 'h0, 'h00, 'h2222_2222, tx_buf, tx_counter);
    spi_transmit_wait();
    spi_close(spi_close_reg);

    spi_transmit_cmd( 'h2, 'h1, 'h33, 'h3333_333F, tx_buf, tx_counter);
    spi_transmit_wait();
    spi_close(spi_close_reg);

    #10000;

    spi_transmit_cmd( 'h3, 'h1, 'hff, 'h1234_1234, tx_buf, tx_counter);
    spi_transmit_wait();
    spi_close(spi_close_reg);

    #10000;
    $display("Test end %s:%0d ", `__FILE__, `__LINE__);
    $finish;
  end

  always @(posedge i_spi_sclk)
  begin
    i_spi_mosi = 1'bZ;
    if (tx_counter != 'b0) begin
      spi_busy = 'b1;
      //$display("%s:%0d %b (%h) (%0d)", `__FILE__, `__LINE__, tx_buf, tx_buf, tx_counter);
      i_spi_ss                 = 0;
      tx_counter               = tx_counter-1;
      rx                       = 0;
      rx_counter               = 36;
      { i_spi_mosi, tx_buf }   = { tx_buf, 1'b0 };
    end else if (rx_counter != 0) begin
      ;

    end else if (spi_close_reg) begin
      spi_busy                 = 'b0;
      i_spi_ss                 = 1;
      spi_close_reg            = 0;
    end
  end

  always @(negedge i_spi_sclk)
  begin
    if (i_spi_ss) begin
      ; //spi is idle
    end else if (tx_counter != 0) begin
      ;
    end else if (rx_counter != 0) begin
      rx_counter = rx_counter - 1;
      rx = {rx[31:0], o_spi_miso };
      $display("%s:%0d rx: %b (%h) (%0d)", `__FILE__, `__LINE__, rx, rx, rx_counter);
    end
  end

  always begin
    #5 i_clk = ~i_clk;
  end

  always begin
    #101 i_spi_sclk = ~i_spi_sclk;
  end

  always @(posedge i_clk)
  begin
    if (i_areset == 'b1) ;
    else if (o_api_cs != 'b0)
      $display("%s:%0d ===========> (%b,%h,%h,%h,...,...) <==========", `__FILE__, `__LINE__, o_api_cs, o_api_we, o_api_address, o_api_write_data);
  end
endmodule
