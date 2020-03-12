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

module nts_dispatcher_tb;

  localparam ADDR_WIDTH=7;

  localparam [1839:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_1=1840'h001c7300_00995254_00cdcd23_08004500_00d80001_00004011_bc3f4d48_e37ec23a_cad31267_101b00c4_3a272300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00002d88_68987dd0_23a60104_0024d406_12b0c40f_353d6afc_d5709668_cd4ebceb_cd8ab0aa_4fd63533_3e8491dc_9f0d0204_006830a8_dce151bd_4e5aa6e3_e577ab41_30e77bc7_cd5ab785_9283e20b_49d8f6bb_89a5b313_4cc92a3d_5eef1f45_3930d7af_f838eec7_99876905_a470e88b_1c57a85a_93fab799_a47c1b7c_8706604f_de780bf9_84394999_d7d59abc_5468cfec_5b261efe_d850618e_91c5;

  reg                   i_areset;
  reg                   i_clk;

  reg [7:0]             i_rx_data_valid;
  reg [63:0]            i_rx_data;
  reg                   i_rx_bad_frame;
  reg                   i_rx_good_frame;

  reg [63:0]            i_ntp_time;

  //ENGINGES=1. Possible improvement: multiple engines in testbench
  reg                   i_dispatch_busy;
  wire                  o_dispatch_packet_available;
  reg                   i_dispatch_packet_read_discard;
  wire [ADDR_WIDTH-1:0] o_dispatch_counter;
  wire [3:0]            o_dispatch_data_valid;
  wire                  o_dispatch_fifo_empty;
  reg                   i_dispatch_fifo_rd_start;
  wire                  o_dispatch_fifo_rd_valid;
  wire [63:0]           o_dispatch_fifo_rd_data;

  wire [31:0]           o_api_read_data;

  wire                  o_engine_cs;
  wire                  o_engine_we;
  wire [11:0]           o_engine_address;
  wire [31:0]           o_engine_write_data;

  //----------------------------------------------------------------
  // RX MAC helper regs
  //----------------------------------------------------------------

  reg                     rx_busy;
  integer                 rx_ptr;
  wire             [71:0] rx_current;
  reg [71:0] /* 8 + 64 */ packet [0:99];
  reg                     packet_available;
  integer                 packet_length;

  assign rx_current = packet[rx_ptr];

  //----------------------------------------------------------------
  // Consumer mem
  //----------------------------------------------------------------

  reg [63:0] consumer_packet [0:99];
  integer consumer_ptr;

  //----------------------------------------------------------------
  // Design Under Test
  //----------------------------------------------------------------

  nts_dispatcher #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .i_ntp_time( i_ntp_time ),

    .i_rx_data_valid ( i_rx_data_valid ),
    .i_rx_data       ( i_rx_data       ),
    .i_rx_bad_frame  ( i_rx_bad_frame  ),
    .i_rx_good_frame ( i_rx_good_frame ),

    .i_dispatch_busy               ( i_dispatch_busy                ),
    .o_dispatch_packet_available   ( o_dispatch_packet_available    ),
    .i_dispatch_packet_read_discard( i_dispatch_packet_read_discard ),
    .o_dispatch_data_valid         ( o_dispatch_data_valid          ),
    .o_dispatch_fifo_empty         ( o_dispatch_fifo_empty          ),
    .i_dispatch_fifo_rd_start      ( i_dispatch_fifo_rd_start       ),
    .o_dispatch_fifo_rd_valid      ( o_dispatch_fifo_rd_valid       ),
    .o_dispatch_fifo_rd_data       ( o_dispatch_fifo_rd_data        ),

    .i_api_cs                ( 1'b0                ),
    .i_api_we                ( 1'b0                ),
    .i_api_address           ( 12'h0               ),
    .i_api_write_data        ( 32'h0               ),
    .o_api_read_data         ( o_api_read_data     ),
    .i_engine_api_busy       ( 1'b0                ),
    .o_engine_cs             ( o_engine_cs         ),
    .o_engine_we             ( o_engine_we         ),
    .o_engine_address        ( o_engine_address    ),
    .o_engine_write_data     ( o_engine_write_data ),
    .i_engine_read_data      ( 32'h0               ),
    .i_engine_read_data_valid( 1'b1                )
  );

  //----------------------------------------------------------------
  // Useful Macro
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s %d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  //----------------------------------------------------------------
  // Send Packet tasks. Inits the RX model.
  //----------------------------------------------------------------

  task send_packet (
    input [65535:0] source,
    input    [31:0] length
  );
  integer i;
  integer packet_ptr;
  integer source_ptr;
  begin
    `assert( (0==(length%8)) ); // byte aligned required
    `assert( rx_busy == 1'b0 );
    for (i=0; i<100; i=i+1) begin
      packet[i] = { 8'h00, 64'habad_1dea_f00d_cafe };
    end
    packet_ptr = 1;
    source_ptr = (length % 64);
    case (source_ptr)
       56: packet[0] = { 8'b0111_1111,  8'b0, source[55:0] };
       48: packet[0] = { 8'b0011_1111, 16'b0, source[47:0] };
       40: packet[0] = { 8'b0001_1111, 24'b0, source[39:0] };
       32: packet[0] = { 8'b0000_1111, 32'b0, source[31:0] };
       24: packet[0] = { 8'b0000_0111, 40'b0, source[23:0] };
       16: packet[0] = { 8'b0000_0011, 48'b0, source[15:0] };
        8: packet[0] = { 8'b0000_0001, 56'b0, source[7:0] };
        0: packet_ptr = 0;
      default:
        `assert(0)
    endcase

    if (packet_ptr != 0)
      $display("%s:%0d %h %h", `__FILE__, `__LINE__, 0, packet[0]);

    for ( i = 0; i < length/64; i = i + 1) begin
       packet[packet_ptr] = { 8'b1111_1111, source[source_ptr+:64] };
       $display("%s:%0d %h %h", `__FILE__, `__LINE__, packet_ptr, packet[packet_ptr]);
       source_ptr = source_ptr + 64;
       packet_ptr = packet_ptr + 1;
    end
    packet_length = packet_ptr - 1;
    packet_available = 1;
    #20;
    `assert( rx_busy );
    packet_available = 0;
    while (rx_busy) #10;
  end
  endtask

  initial begin
    $display("Test start: %s %d", `__FILE__, `__LINE__);
    i_clk = 1;
    i_areset = 1;
    i_rx_data_valid = 'b0;
    i_rx_data = 'b0;
    i_rx_bad_frame = 'b0;
    i_rx_good_frame = 'b0;

    #20;
    i_areset = 0;
    #20;
/*
    #10 i_areset = 0;
    `assert((o_dispatch_packet_available == 'b0));
    `assert((o_dispatch_counter == 'b0));
    `assert((o_dispatch_data_valid == 'b0));
    `assert((o_dispatch_fifo_empty == 'b1));

    #10
    i_rx_data[63:32] = 'h01020304; i_rx_data[31:0] = 'h05060708;
    i_rx_data_valid = 'hff;
    `assert((o_dispatch_packet_available == 'b0));
    `assert((o_dispatch_counter == 'b0));

    #10
    i_rx_data[63:32] = 'h00000002; i_rx_data[31:0] = 'h20202020;
    i_rx_data_valid = 'hff;
    `assert(o_dispatch_packet_available == 'b0);

    #10
    i_rx_data[63:32] = 'h00000003; i_rx_data[31:0] = 'h30303030;
    i_rx_data_valid = 'hff;
    i_rx_good_frame = 'b1;
    `assert((o_dispatch_packet_available == 'b0));

    #10
    i_rx_data = 'b0;
    i_rx_data_valid = 'h00;
    i_rx_good_frame = 'b0;
    `assert((o_dispatch_packet_available == 'b0));

    #10
    `assert((o_dispatch_packet_available == 'b0));
    i_rx_data = 'b0;
    i_rx_data_valid = 'h00;
    i_rx_good_frame = 'b0;

    #10
    `assert((o_dispatch_packet_available == 'b1));
    `assert((o_dispatch_counter == 'h2));
    `assert((o_dispatch_data_valid == 'hff));
    `assert((o_dispatch_fifo_empty == 'b0));
    i_dispatch_fifo_rd_en = 'b1;

    #10
    `assert((o_dispatch_packet_available == 'b1));
    `assert((o_dispatch_counter == 'h2));
    `assert((o_dispatch_data_valid == 'hff));
    `assert((o_dispatch_fifo_empty == 'b0));
    `assert((o_dispatch_fifo_rd_data[63:32] == 'h01020304));
    `assert((o_dispatch_fifo_rd_data[31:0] == 'h05060708));
    i_dispatch_fifo_rd_en = 'b1;

    #10
    `assert((o_dispatch_packet_available == 'b1));
    `assert((o_dispatch_counter == 'h2));
    `assert((o_dispatch_data_valid == 'hff));
    `assert((o_dispatch_fifo_empty == 'b0));
    `assert((o_dispatch_fifo_rd_data[63:32] == 'h00000002));
    `assert((o_dispatch_fifo_rd_data[31:0] == 'h20202020));
    i_dispatch_fifo_rd_en = 'b1;

    #10
    `assert((o_dispatch_packet_available == 'b1));
    `assert((o_dispatch_counter == 'h2));
    `assert((o_dispatch_data_valid == 'hff));
    `assert((o_dispatch_fifo_empty == 'b1));
    `assert((o_dispatch_fifo_rd_data[63:32] == 'h00000003));
    `assert((o_dispatch_fifo_rd_data[31:0] == 'h30303030));
    i_dispatch_packet_read_discard = 'b1;
    i_dispatch_fifo_rd_en = 'b0;

    #10
    `assert((o_dispatch_packet_available == 'b0));
    i_dispatch_packet_read_discard = 'b0;
*/

    send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840);

    while (i_dispatch_packet_read_discard == 0) #10;

    begin : vars_
      integer i;
      reg [71:0] tmp_a;
      reg [63:0] tmp_b;
      for ( i = 0; i < 'h1d; i = i + 1 ) begin
        tmp_a = packet[i];
        tmp_b = consumer_packet[i];
        $display("%s:%0d %h packet=[%h] consumer_packet=[%h]", `__FILE__, `__LINE__, tmp_a[71:64], tmp_a[63:0], tmp_b);
      end
    end

    #2000;
    $display("Test stop: %s %d", `__FILE__, `__LINE__);
    $finish;
  end

  //----------------------------------------------------------------
  // Testbench model: MAC RX
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_rx_data_valid <= 0;
      i_rx_data <= 0;
      i_rx_bad_frame <= 0;
      i_rx_good_frame <= 0;
      rx_busy <= 0;
    end else begin
      { i_rx_data_valid, i_rx_data, i_rx_bad_frame, i_rx_good_frame } <= 0;

      if (rx_busy) begin
        $display("%s:%0d %h %h", `__FILE__, `__LINE__, rx_current[71:64], rx_current[63:0]);
        { i_rx_data_valid, i_rx_data } <= rx_current;
        if (rx_ptr == 0) begin
          rx_busy <= 0;
          i_rx_good_frame <= 1;
        end else begin
          rx_ptr <= rx_ptr - 1;
        end

      end else if (packet_available) begin
        $display("%s:%0d packet_available", `__FILE__, `__LINE__);
        rx_busy <= 1;
        rx_ptr <= packet_length;
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: Dispatcher consumer (e.g. NTS ENGINE)
  //----------------------------------------------------------------

  localparam CONSUMER_IDLE = 0;
  localparam CONSUMER_READ_FIFO = 1;
  localparam CONSUMER_CLEAR= 2;
  reg [1:0] consumer_reg;

  always @(posedge i_clk)
  begin
    i_dispatch_packet_read_discard = 'b0;
    //i_dispatch_fifo_rd_start = 'b0;
    case (consumer_reg)
      /*CONSUMER_READ_FIFO:
        if (o_dispatch_fifo_empty == 0)
          i_dispatch_fifo_rd_en = 1;*/
      CONSUMER_CLEAR:
        i_dispatch_packet_read_discard = 1;
      default: ;
    endcase
  end

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      consumer_reg <= CONSUMER_IDLE;
      consumer_ptr <= 0;
    end else begin
      //$display("%s:%0d consumer_reg: %h", `__FILE__, `__LINE__, consumer_reg);
      i_dispatch_fifo_rd_start <= 0;
      case (consumer_reg)
        CONSUMER_IDLE:
          if (o_dispatch_packet_available && o_dispatch_fifo_empty == 0) begin
            consumer_reg <= CONSUMER_READ_FIFO;
            consumer_ptr <= 0;
            i_dispatch_fifo_rd_start <= 1;
          end
        CONSUMER_READ_FIFO:
          if (o_dispatch_fifo_empty) begin
            consumer_reg <= CONSUMER_CLEAR;
          end else begin
            if (o_dispatch_fifo_rd_valid) begin
              $display("%s:%0d consumer_ptr: %h o_dispatch_fifo_rd_data: %h o_dispatch_data_valid: %h", `__FILE__, `__LINE__, consumer_ptr, o_dispatch_fifo_rd_data, o_dispatch_data_valid);
              consumer_ptr <= consumer_ptr + 1;
              consumer_packet[consumer_ptr] <= o_dispatch_fifo_rd_data;
            end
          end
         CONSUMER_CLEAR:
            consumer_reg <= CONSUMER_IDLE;
        default: ;
      endcase
    end
  end

  //----------------------------------------------------------------
  // Testbench model: NTP_Time
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_ntp_time <= 64'h1337_0000_0000_0000;;
    end else begin
      i_ntp_time <= i_ntp_time + 1;
    end
  end

  //----------------------------------------------------------------
  // Testbench model: System Clock
  //----------------------------------------------------------------

  always begin
    #5 i_clk = ~i_clk;
  end
endmodule
