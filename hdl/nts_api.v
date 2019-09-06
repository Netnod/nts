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

module nts_api #(
  parameter integer CPOL = 0,
  parameter integer CPHA = 0,
  parameter integer API_SLAVE_BITS = 1
) (
  input  wire                                i_areset, // async reset
  input  wire                                i_clk,
  input  wire                                i_spi_sclk,
  input  wire                                i_spi_mosi,
  output wire                                o_spi_miso,
  input  wire                                i_spi_ss,
  output wire      [(2**API_SLAVE_BITS)-1:0] o_api_cs,
  output wire                                o_api_we,
  output wire                        [7 : 0] o_api_address,
  output wire                       [31 : 0] o_api_write_data,
  input  wire [32*(2**API_SLAVE_BITS)-1 : 0] i_api_read_data
);

  localparam SPI_RX_COUNTER_REG_SIZE = 6;
  localparam SPI_RX_REG_SIZE = 1 /* start bit */
                          + API_SLAVE_BITS
                          + 1 /* we bit */
                          + 8 /* addr */
                          + 32 /* data */;
  localparam [SPI_RX_COUNTER_REG_SIZE-1:0] SPI_RX_REG_SIZE_XX = SPI_RX_REG_SIZE[SPI_RX_COUNTER_REG_SIZE-1:0];

  localparam SPI_TX_COUNTER_REG_SIZE = 6;
  localparam SPI_TX_REG_SIZE = 1 /* start bit */ + 32; /* data */
  localparam [SPI_TX_COUNTER_REG_SIZE-1:0] SPI_TX_REG_SIZE_XX = SPI_TX_REG_SIZE[SPI_TX_COUNTER_REG_SIZE-1:0];


  reg     [(2**API_SLAVE_BITS)-1:0] api_cs_new;
  reg     [(2**API_SLAVE_BITS)-1:0] api_cs_reg; //decoded_slave_bits_new expanded

  reg         [SPI_RX_REG_SIZE-1:0] spi_rx_new;
  reg         [SPI_RX_REG_SIZE-1:0] spi_rx_reg;
  reg [SPI_RX_COUNTER_REG_SIZE-1:0] spi_rx_counter_new;
  reg [SPI_RX_COUNTER_REG_SIZE-1:0] spi_rx_counter_reg;

  reg         [SPI_TX_REG_SIZE-1:0] spi_tx_new;
  reg         [SPI_TX_REG_SIZE-1:0] spi_tx_reg;
  reg         [SPI_TX_REG_SIZE-1:0] spi_tx_from_sys_reg;
  reg [SPI_TX_COUNTER_REG_SIZE-1:0] spi_tx_counter_new;
  reg [SPI_TX_COUNTER_REG_SIZE-1:0] spi_tx_counter_reg;

  reg         [SPI_RX_REG_SIZE-1:0] sys_rx_reg;
  reg [SPI_RX_COUNTER_REG_SIZE-1:0] sys_rx_counter_reg;

  reg                               sys_tx_we;
  reg         [SPI_TX_REG_SIZE-1:0] sys_tx_new;
  reg         [SPI_TX_REG_SIZE-1:0] sys_tx_reg;

  reg                               decoded_old_we;
  reg                               decoded_old_new;
  reg                               decoded_old_reg;

  reg                               decoded_all_we;
  reg                               decoded_start_new;
  reg                               decoded_start_reg;
  reg          [API_SLAVE_BITS-1:0] decoded_slave_bits_new;
  reg          [API_SLAVE_BITS-1:0] decoded_slave_bits_reg;
  reg                               decoded_we_new;
  reg                               decoded_we_reg;
  reg                       [7 : 0] decoded_addr_new;
  reg                       [7 : 0] decoded_addr_reg;
  reg                      [31 : 0] decoded_write_data_new;
  reg                      [31 : 0] decoded_write_data_reg;

  reg  spi_miso_new;
  reg  spi_miso_reg;

  wire spi_clock;

  assign spi_clock  = (CPOL==0) ? i_spi_sclk : ~i_spi_sclk;

  assign o_spi_miso = i_spi_ss ? 1'bZ : spi_miso_reg;

  assign o_api_cs         = api_cs_reg;
  assign o_api_we         = decoded_we_reg;
  assign o_api_address    = decoded_addr_reg;
  assign o_api_write_data = decoded_write_data_reg;

  generate
    if (CPHA == 0)
      always @(posedge spi_clock)
      begin : cpha_0_rx_middle
        if (i_areset == 'b1) begin
          spi_rx_counter_reg <= 'b0;
          spi_rx_reg         <= 'b0;

        end else begin
          spi_rx_counter_reg <= spi_rx_counter_new;
          spi_rx_reg         <= spi_rx_new;
       end
      end

    if (CPHA == 1)
      always @(negedge spi_clock)
      begin : cpha_1_rx_middle
        if (i_areset == 'b1) begin
          spi_rx_counter_reg <= 'b0;
          spi_rx_reg         <= 'b0;

       end else begin
         spi_rx_counter_reg  <= spi_rx_counter_new;
         spi_rx_reg          <= spi_rx_new;
         //$display("%s:%0d   %b (%h) (%0d)", `__FILE__, `__LINE__, spi_rx_new, spi_rx_new, spi_rx_counter_new) ;
       end
      end

    if (CPHA == 1)
      always @(posedge spi_clock)
      begin : cpha_1_tx_rising
        if (i_areset == 'b1) begin
          spi_miso_reg       <= 'b0;
          spi_tx_counter_reg <= 'b0;
          spi_tx_reg         <= 'b0;

       end else begin
         spi_miso_reg        <= spi_miso_new;
         spi_tx_counter_reg  <= spi_tx_counter_new;
         spi_tx_reg          <= spi_tx_new;
         //$display("%s:%0d tx: %b %b (%h) (%0d)", `__FILE__, `__LINE__, spi_miso_new, spi_tx_new, spi_tx_new, spi_tx_counter_new);
       end
      end
  endgenerate

  always @*
  begin
    spi_tx_new = 'b0;
    spi_tx_counter_new = 'b0;
    if (i_spi_ss == 0) begin
      if (spi_tx_counter_reg == 'b0) begin
        if (spi_rx_counter_reg == SPI_RX_REG_SIZE_XX) begin
          spi_tx_counter_new = SPI_TX_REG_SIZE_XX;
          spi_tx_new = spi_tx_from_sys_reg;
        end
      end else begin
        spi_tx_counter_new = spi_tx_counter_reg - 1;
        spi_tx_new = { spi_tx_reg[SPI_TX_REG_SIZE-2:0], 1'b0 };
        spi_miso_new = spi_tx_reg[SPI_TX_REG_SIZE-1];
      end
    end
  end

  always @(posedge i_clk)
  begin : rx_clock_domain_crossing
    if (i_areset == 'b1) begin
      sys_rx_reg         <= 'b0;
      sys_rx_counter_reg <= 'b0;
    end else begin
      sys_rx_reg         <= spi_rx_reg;
      sys_rx_counter_reg <= spi_rx_counter_reg;
    end
  end

  always @(posedge i_clk)
  begin : tx_clock_domain_crossing
    if (i_areset == 'b1) begin
      spi_tx_from_sys_reg <= 'b0;
    end else begin
      spi_tx_from_sys_reg <= sys_tx_reg;
    end
  end

  always @(posedge i_clk)
  begin : sys_reg_update
    if (i_areset == 'b1) begin
      sys_tx_reg             <= 'b0;
      decoded_old_reg        <= 'b0;
      decoded_start_reg      <= 'b0;
      decoded_we_reg         <= 'b0;
      decoded_addr_reg       <= 'b0;
      decoded_write_data_reg <= 'b0;
    end else begin
      if (decoded_old_we)
        decoded_old_reg        <= decoded_old_new;
      if (decoded_all_we) begin
        api_cs_reg             <= api_cs_new;
        decoded_start_reg      <= decoded_start_new;
        decoded_slave_bits_reg <= decoded_slave_bits_new;
        decoded_we_reg         <= decoded_we_new;
        decoded_addr_reg       <= decoded_addr_new;
        decoded_write_data_reg <= decoded_write_data_new;
      end
      if (sys_tx_we)
        sys_tx_reg             <= sys_tx_new;
    end
  end


  always @*
  begin
    spi_rx_counter_new = 'b0;
    spi_rx_new         = spi_rx_reg;

    if (i_spi_ss == 'b1) begin
      spi_rx_counter_new = 'b0;
      spi_rx_new         = 'b0;
    end else if (spi_rx_counter_reg < SPI_RX_REG_SIZE_XX) begin
      spi_rx_new       = { spi_rx_reg[SPI_RX_REG_SIZE-2:0], i_spi_mosi };
      spi_rx_counter_new = spi_rx_counter_reg + 1;
    end else begin
      spi_rx_new         = spi_rx_reg;
      spi_rx_counter_new = spi_rx_counter_reg;
    end
  end

/*
  always @(posedge spi_clock or negedge spi_clock)
  begin
    if (i_areset == 'b1) begin
      spi_miso_reg       <= 'b0;
      spi_tx_reg         <= 'b0;
      spi_tx_counter_reg <= 'b0;
    end else if (i_spi_ss == 'b1) begin
      spi_tx_counter_reg <= 'b0;

    end else if (i_spi_ss == 'b0) begin
      if ((CPHA == 0 && spi_clock == 'b0) || (CPHA == 1 && spi_clock == 'b1)) begin
        { spi_miso_reg, spi_tx_reg } <= { spi_tx_reg, 1'b0 };
        spi_tx_counter_reg <= (spi_tx_counter_reg == 0) ? 0 : (spi_tx_counter_reg-1);
      end
    end
  end
*/


  always @*
  begin
    decoded_old_we  = 'b0;
    decoded_old_new = 'b0;
    decoded_all_we  = 'b0;
    api_cs_new      = 'b0;
    {
      decoded_start_new,
      decoded_slave_bits_new,
      decoded_we_new,
      decoded_addr_new,
      decoded_write_data_new
    } = 'b0;
    if (sys_rx_counter_reg < SPI_RX_REG_SIZE_XX) begin
      //$display("%s:%0d spi_rx_reg %b %h", `__FILE__, `__LINE__, sys_rx_reg, sys_rx_reg);
      decoded_old_we = 'b1; //reset
      decoded_all_we = 'b1; // write zeros
    end else if (decoded_old_reg == 'b1) begin
      decoded_all_we = 'b1; // write zeros
    end else begin
      //$display("%s:%0d spi_rx_reg %b %h", `__FILE__, `__LINE__, sys_rx_reg, sys_rx_reg);
      {
        decoded_start_new,
        decoded_slave_bits_new,
        decoded_we_new,
        decoded_addr_new,
        decoded_write_data_new
      } = sys_rx_reg;
      if ( decoded_start_new ) begin : set_cs_pins
        integer i;
        for (i = 0; i < (2**API_SLAVE_BITS); i = i + 1) begin : forloop
          reg [API_SLAVE_BITS-1:0] b;
          b = i[API_SLAVE_BITS-1:0];
          if ( b == decoded_slave_bits_new ) begin
            api_cs_new[b] = 'b1;
          end
        end
        decoded_all_we = 'b1;
        decoded_old_we  = 'b1;
        decoded_old_new = 'b1;
        //$display("%s:%0d spi_rx_reg %b %h", `__FILE__, `__LINE__, sys_rx_reg, sys_rx_reg);
        //$display("%s:%0d decode: start=%h slave=%h we=%h addr=%h data=%h", `__FILE__, `__LINE__, decoded_start_new, decoded_slave_bits_new, decoded_we_new, decoded_addr_new, decoded_write_data_new);
        //$display("%s:%0d api_cs_new=%b (%h)", `__FILE__, `__LINE__, api_cs_new, api_cs_new);
      end else begin
        $display("%s:%0d Warning: RX decode problem %h %h %h %h %h", `__FILE__, `__LINE__, decoded_start_new, decoded_slave_bits_new, decoded_we_new, decoded_addr_new, decoded_write_data_new);
      end
    end
  end

  always @*
  begin
    sys_tx_we = 'b0;
    sys_tx_new = 'b0;
    if (api_cs_reg != 'b0) begin : locals
      reg [API_SLAVE_BITS-1:0] i;
      i = decoded_slave_bits_reg;
      sys_tx_we = 'b1;
      sys_tx_new = { 1'b1, i_api_read_data[32*i-:32] };
    end
  end
endmodule
