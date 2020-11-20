//======================================================================
//
// nts_extractor.v
// ---------------
// NTS packet extractor (from engines).
//
// Author: Peter Magnusson
//
//
// Copyright (c) 2019, Netnod Internet Exchange i Sverige AB (Netnod).
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
//======================================================================

module nts_extractor #(
  parameter API_ADDR_WIDTH = 12,
  parameter API_ADDR_BASE  = 'h400,
  parameter ENGINES        = 4
) (
  input  wire i_areset, // async reset
  input  wire i_clk,

  input  wire                        i_api_cs,
  input  wire                        i_api_we,
  input  wire [API_ADDR_WIDTH - 1:0] i_api_address,
  input  wire                 [31:0] i_api_write_data,
  output wire                 [31:0] o_api_read_data,

  input  wire      [ENGINES - 1 : 0] i_engine_packet_available,
  output wire      [ENGINES - 1 : 0] o_engine_packet_read,
  input  wire      [ENGINES - 1 : 0] i_engine_fifo_empty,
  output wire      [ENGINES - 1 : 0] o_engine_fifo_rd_start,
  input  wire      [ENGINES - 1 : 0] i_engine_fifo_rd_valid,
  input  wire [64 * ENGINES - 1 : 0] i_engine_fifo_rd_data,
  input  wire  [4 * ENGINES - 1 : 0] i_engine_bytes_last_word,

  output wire        o_mac_tx_start,
  input  wire        i_mac_tx_ack,
  output wire  [7:0] o_mac_tx_data_valid,
  output wire [63:0] o_mac_tx_data
);
  //----------------------------------------------------------------
  // Local parameters, constants, definitions etc
  //----------------------------------------------------------------

  localparam ENGINES_DIV4 = ENGINES>>2;
  localparam ENGINES_REM  = ENGINES - 3 * ENGINES_DIV4;

  localparam ADDR_WIDTH	= 8;
  localparam ADDR_NAME0             = API_ADDR_BASE + 0;
  localparam ADDR_NAME1             = API_ADDR_BASE + 1;
  localparam ADDR_VERSION           = API_ADDR_BASE + 2;
  localparam ADDR_DUMMY             = API_ADDR_BASE + 3;
  localparam ADDR_BYTES             = API_ADDR_BASE + 'ha;
  localparam ADDR_PACKETS           = API_ADDR_BASE + 'hc;
  localparam ADDR_MUX_STATE         = API_ADDR_BASE + 'h20;
  localparam ADDR_MUX_INDEX         = API_ADDR_BASE + 'h21;
  localparam ADDR_DEBUG_TX          = API_ADDR_BASE + 'h30;
  localparam ADDR_ERROR_STARTS      = API_ADDR_BASE + 'h40;
  localparam ADDR_ERROR_DISCARDS    = API_ADDR_BASE + 'h41;

  localparam CORE_NAME    = 64'h4e_54_53_2d_45_58_54_52; //NTS-EXTR
  localparam CORE_VERSION = 32'h30_2e_30_36;

  //----------------------------------------------------------------
  // Asynchrononous registers
  //----------------------------------------------------------------

  //reg        counter_bytes_rst;
  //reg        counter_bytes_we;
  //reg [63:0] counter_bytes_new;
  //reg [63:0] counter_bytes_reg;
  //reg        counter_bytes_lsb_we;
  //reg [31:0] counter_bytes_lsb_reg;

  //reg        counter_packets_rst;
  //reg        counter_packets_we;
  //reg [63:0] counter_packets_new;
  //reg [63:0] counter_packets_reg;
  //reg        counter_packets_lsb_we;
  //reg [31:0] counter_packets_lsb_reg;

  //reg [31:0] debug_tx_new;
  //reg [31:0] debug_tx_reg;

  reg        dummy_we;
  reg [31:0] dummy_new;
  reg [31:0] dummy_reg;

  //----------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------

  reg [31:0] api_read_data;

  wire                  mux0b_ready;
  wire                  mux0b_start;
  wire                  mux0b_stop;
  wire [ADDR_WIDTH-1:0] mux0b_wr_addr;
  wire                  mux0b_wr_en;
  wire           [63:0] mux0b_wr_data;
  wire [ADDR_WIDTH-1:0] mux0b_length;
  wire            [3:0] mux0b_lwdv;

  wire                  mux1b_ready;
  wire                  mux1b_start;
  wire                  mux1b_stop;
  wire [ADDR_WIDTH-1:0] mux1b_wr_addr;
  wire                  mux1b_wr_en;
  wire           [63:0] mux1b_wr_data;
  wire [ADDR_WIDTH-1:0] mux1b_length;
  wire            [3:0] mux1b_lwdv;

  wire                  mux2b_ready;
  wire                  mux2b_start;
  wire                  mux2b_stop;
  wire [ADDR_WIDTH-1:0] mux2b_wr_addr;
  wire                  mux2b_wr_en;
  wire           [63:0] mux2b_wr_data;
  wire [ADDR_WIDTH-1:0] mux2b_length;
  wire            [3:0] mux2b_lwdv;

  wire                  mux3b_ready;
  wire                  mux3b_start;
  wire                  mux3b_stop;
  wire [ADDR_WIDTH-1:0] mux3b_wr_addr;
  wire                  mux3b_wr_en;
  wire           [63:0] mux3b_wr_data;
  wire [ADDR_WIDTH-1:0] mux3b_length;
  wire            [3:0] mux3b_lwdv;


  wire    [ENGINES_DIV4-1:0] mux0e_pkt_available;
  wire    [ENGINES_DIV4-1:0] mux0e_pkt_read;
  wire    [ENGINES_DIV4-1:0] mux0e_fifo_empty;
  wire    [ENGINES_DIV4-1:0] mux0e_fifo_rd_start;
  wire    [ENGINES_DIV4-1:0] mux0e_fifo_rd_valid;
  wire [64*ENGINES_DIV4-1:0] mux0e_fifo_rd_data;
  wire  [4*ENGINES_DIV4-1:0] mux0e_dvlw;

  wire    [ENGINES_DIV4-1:0] mux1e_pkt_available;
  wire    [ENGINES_DIV4-1:0] mux1e_pkt_read;
  wire    [ENGINES_DIV4-1:0] mux1e_fifo_empty;
  wire    [ENGINES_DIV4-1:0] mux1e_fifo_rd_start;
  wire    [ENGINES_DIV4-1:0] mux1e_fifo_rd_valid;
  wire [64*ENGINES_DIV4-1:0] mux1e_fifo_rd_data;
  wire  [4*ENGINES_DIV4-1:0] mux1e_dvlw;

  wire    [ENGINES_DIV4-1:0] mux2e_pkt_available;
  wire    [ENGINES_DIV4-1:0] mux2e_pkt_read;
  wire    [ENGINES_DIV4-1:0] mux2e_fifo_empty;
  wire    [ENGINES_DIV4-1:0] mux2e_fifo_rd_start;
  wire    [ENGINES_DIV4-1:0] mux2e_fifo_rd_valid;
  wire [64*ENGINES_DIV4-1:0] mux2e_fifo_rd_data;
  wire  [4*ENGINES_DIV4-1:0] mux2e_dvlw;

  wire    [ENGINES_REM -1:0] mux3e_pkt_available;
  wire    [ENGINES_REM -1:0] mux3e_pkt_read;
  wire    [ENGINES_REM -1:0] mux3e_fifo_empty;
  wire    [ENGINES_REM -1:0] mux3e_fifo_rd_start;
  wire    [ENGINES_REM -1:0] mux3e_fifo_rd_valid;
  wire [64*ENGINES_REM -1:0] mux3e_fifo_rd_data;
  wire  [4*ENGINES_REM -1:0] mux3e_dvlw;

  //----------------------------------------------------------------
  // Wire assignments
  //----------------------------------------------------------------

  assign o_api_read_data = api_read_data;

  assign { mux3e_pkt_available,
           mux2e_pkt_available,
           mux1e_pkt_available,
           mux0e_pkt_available } = i_engine_packet_available;

  assign { mux3e_fifo_empty,
           mux2e_fifo_empty,
           mux1e_fifo_empty,
           mux0e_fifo_empty } = i_engine_fifo_empty;

  assign { mux3e_fifo_rd_valid,
           mux2e_fifo_rd_valid,
           mux1e_fifo_rd_valid,
           mux0e_fifo_rd_valid } = i_engine_fifo_rd_valid;

  assign { mux3e_fifo_rd_data,
           mux2e_fifo_rd_data,
           mux1e_fifo_rd_data,
           mux0e_fifo_rd_data } = i_engine_fifo_rd_data;

  assign { mux3e_dvlw,
           mux2e_dvlw,
           mux1e_dvlw,
           mux0e_dvlw } = i_engine_bytes_last_word;

  assign o_engine_packet_read = { mux3e_pkt_read,
                                  mux2e_pkt_read,
                                  mux1e_pkt_read,
                                  mux0e_pkt_read  };


   assign o_engine_fifo_rd_start = { mux3e_fifo_rd_start,
                                     mux2e_fifo_rd_start,
                                     mux1e_fifo_rd_start,
                                     mux0e_fifo_rd_start };

  //----------------------------------------------------------------
  // TX handler. Holds TXMEMs and emits to MAC.
  //----------------------------------------------------------------

  nts_extractor_tx #( .ADDR_WIDTH( ADDR_WIDTH ) ) tx (
    .i_areset ( i_areset ),
    .i_clk    ( i_clk    ),

    .buffer0_ready   ( mux0b_ready   ),
    .buffer0_start   ( mux0b_start   ),
    .buffer0_stop    ( mux0b_stop    ),
    .buffer0_wr_addr ( mux0b_wr_addr ),
    .buffer0_wr_en   ( mux0b_wr_en   ),
    .buffer0_wr_data ( mux0b_wr_data ),
    .buffer0_length  ( mux0b_length  ),
    .buffer0_lwdv    ( mux0b_lwdv    ),

    .buffer1_ready   ( mux1b_ready   ),
    .buffer1_start   ( mux1b_start   ),
    .buffer1_stop    ( mux1b_stop    ),
    .buffer1_wr_addr ( mux1b_wr_addr ),
    .buffer1_wr_en   ( mux1b_wr_en   ),
    .buffer1_wr_data ( mux1b_wr_data ),
    .buffer1_length  ( mux1b_length  ),
    .buffer1_lwdv    ( mux1b_lwdv    ),

    .buffer2_ready   ( mux2b_ready   ),
    .buffer2_start   ( mux2b_start   ),
    .buffer2_stop    ( mux2b_stop    ),
    .buffer2_wr_addr ( mux2b_wr_addr ),
    .buffer2_wr_en   ( mux2b_wr_en   ),
    .buffer2_wr_data ( mux2b_wr_data ),
    .buffer2_length  ( mux2b_length  ),
    .buffer2_lwdv    ( mux2b_lwdv    ),

    .buffer3_ready   ( mux3b_ready   ),
    .buffer3_start   ( mux3b_start   ),
    .buffer3_stop    ( mux3b_stop    ),
    .buffer3_wr_addr ( mux3b_wr_addr ),
    .buffer3_wr_en   ( mux3b_wr_en   ),
    .buffer3_wr_data ( mux3b_wr_data ),
    .buffer3_length  ( mux3b_length  ),
    .buffer3_lwdv    ( mux3b_lwdv    ),


    .o_mac_tx_start      ( o_mac_tx_start      ),
    .i_mac_tx_ack        ( i_mac_tx_ack        ),
    .o_mac_tx_data_valid ( o_mac_tx_data_valid ),
    .o_mac_tx_data       ( o_mac_tx_data       )
  );

  nts_extractor_mux #(
    .ADDR_WIDTH( ADDR_WIDTH   ),
    .ENGINES   ( ENGINES_DIV4 )
  ) mux0 (
    .i_areset                 ( i_areset            ),
    .i_clk                    ( i_clk               ),
    .i_engine_packet_available( mux0e_pkt_available ),
    .o_engine_packet_read     ( mux0e_pkt_read      ),
    .i_engine_fifo_empty      ( mux0e_fifo_empty    ),
    .o_engine_fifo_rd_start   ( mux0e_fifo_rd_start ),
    .i_engine_fifo_rd_valid   ( mux0e_fifo_rd_valid ),
    .i_engine_fifo_rd_data    ( mux0e_fifo_rd_data  ),
    .i_engine_bytes_last_word ( mux0e_dvlw          ),
    .o_buffer_ready           ( mux0b_ready         ),
    .i_buffer_start           ( mux0b_start         ),
    .i_buffer_stop            ( mux0b_stop          ),
    .o_buffer_length          ( mux0b_length        ),
    .o_buffer_lwdv            ( mux0b_lwdv          ),
    .o_buffer_wr_addr         ( mux0b_wr_addr       ),
    .o_buffer_wr_en           ( mux0b_wr_en         ),
    .o_buffer_wr_data         ( mux0b_wr_data       )
  );

  nts_extractor_mux #(
    .ADDR_WIDTH( ADDR_WIDTH   ),
    .ENGINES   ( ENGINES_DIV4 )
  ) mux1 (
    .i_areset                 ( i_areset            ),
    .i_clk                    ( i_clk               ),
    .i_engine_packet_available( mux1e_pkt_available ),
    .o_engine_packet_read     ( mux1e_pkt_read      ),
    .i_engine_fifo_empty      ( mux1e_fifo_empty    ),
    .o_engine_fifo_rd_start   ( mux1e_fifo_rd_start ),
    .i_engine_fifo_rd_valid   ( mux1e_fifo_rd_valid ),
    .i_engine_fifo_rd_data    ( mux1e_fifo_rd_data  ),
    .i_engine_bytes_last_word ( mux1e_dvlw          ),
    .o_buffer_ready           ( mux1b_ready         ),
    .i_buffer_start           ( mux1b_start         ),
    .i_buffer_stop            ( mux1b_stop          ),
    .o_buffer_length          ( mux1b_length        ),
    .o_buffer_lwdv            ( mux1b_lwdv          ),
    .o_buffer_wr_addr         ( mux1b_wr_addr       ),
    .o_buffer_wr_en           ( mux1b_wr_en         ),
    .o_buffer_wr_data         ( mux1b_wr_data       )
  );

  nts_extractor_mux #(
    .ADDR_WIDTH( ADDR_WIDTH   ),
    .ENGINES   ( ENGINES_DIV4 )
  ) mux2 (
    .i_areset                 ( i_areset            ),
    .i_clk                    ( i_clk               ),
    .i_engine_packet_available( mux2e_pkt_available ),
    .o_engine_packet_read     ( mux2e_pkt_read      ),
    .i_engine_fifo_empty      ( mux2e_fifo_empty    ),
    .o_engine_fifo_rd_start   ( mux2e_fifo_rd_start ),
    .i_engine_fifo_rd_valid   ( mux2e_fifo_rd_valid ),
    .i_engine_fifo_rd_data    ( mux2e_fifo_rd_data  ),
    .i_engine_bytes_last_word ( mux2e_dvlw          ),
    .o_buffer_ready           ( mux2b_ready         ),
    .i_buffer_start           ( mux2b_start         ),
    .i_buffer_stop            ( mux2b_stop          ),
    .o_buffer_length          ( mux2b_length        ),
    .o_buffer_lwdv            ( mux2b_lwdv          ),
    .o_buffer_wr_addr         ( mux2b_wr_addr       ),
    .o_buffer_wr_en           ( mux2b_wr_en         ),
    .o_buffer_wr_data         ( mux2b_wr_data       )
  );

  nts_extractor_mux #(
    .ADDR_WIDTH( ADDR_WIDTH  ),
    .ENGINES   ( ENGINES_REM )
  ) mux3 (
    .i_areset                 ( i_areset            ),
    .i_clk                    ( i_clk               ),
    .i_engine_packet_available( mux3e_pkt_available ),
    .o_engine_packet_read     ( mux3e_pkt_read      ),
    .i_engine_fifo_empty      ( mux3e_fifo_empty    ),
    .o_engine_fifo_rd_start   ( mux3e_fifo_rd_start ),
    .i_engine_fifo_rd_valid   ( mux3e_fifo_rd_valid ),
    .i_engine_fifo_rd_data    ( mux3e_fifo_rd_data  ),
    .i_engine_bytes_last_word ( mux3e_dvlw          ),
    .o_buffer_ready           ( mux3b_ready         ),
    .i_buffer_start           ( mux3b_start         ),
    .i_buffer_stop            ( mux3b_stop          ),
    .o_buffer_length          ( mux3b_length        ),
    .o_buffer_lwdv            ( mux3b_lwdv          ),
    .o_buffer_wr_addr         ( mux3b_wr_addr       ),
    .o_buffer_wr_en           ( mux3b_wr_en         ),
    .o_buffer_wr_data         ( mux3b_wr_data       )
  );



  //----------------------------------------------------------------
  // A small debug register.
  //----------------------------------------------------------------

  //always @*
  //  begin
  //    debug_tx_new = { 7'b1000_000, o_mac_tx_start, 8'h00, o_mac_tx_data_valid, 5'b0, tx.tx_state };
  //  end

  //----------------------------------------------------------------
  // API
  //----------------------------------------------------------------

  always @*
  begin : api
    api_read_data = 0;
    //counter_bytes_rst = 0;
    //counter_bytes_lsb_we = 0;
    //counter_packets_rst = 0;
    //counter_packets_lsb_we = 0;
    dummy_we = 0;
    dummy_new = 0;

    if (i_api_cs) begin
      if (i_api_we) begin
        case (i_api_address)
          ADDR_DUMMY:
            begin
              dummy_we  = 1;
              dummy_new = i_api_write_data;
            end
          //ADDR_BYTES: counter_bytes_rst = 1;
          //ADDR_PACKETS: counter_packets_rst = 1;
          default: ;
        endcase
      end else begin
        case (i_api_address)
          ADDR_NAME0: api_read_data = CORE_NAME[63:32];
          ADDR_NAME1: api_read_data = CORE_NAME[31:0];
          ADDR_VERSION: api_read_data = CORE_VERSION;
          ADDR_DUMMY: api_read_data = dummy_reg;
          //ADDR_BYTES:
          //  begin
          //    counter_bytes_lsb_we = 1;
          //    api_read_data = counter_bytes_reg[63:32];
          //  end
          //ADDR_BYTES + 1: api_read_data = counter_bytes_lsb_reg;
          //ADDR_PACKETS:
          //  begin
          //    counter_packets_lsb_we = 1;
          //    api_read_data = counter_packets_reg[63:32];
          //  end
          //ADDR_PACKETS + 1: api_read_data = counter_packets_lsb_reg;
          //ADDR_MUX_STATE: api_read_data[0] = mux_in_ctrl_reg;
          //ADDR_MUX_INDEX: api_read_data = mux_in_index_reg;
          //ADDR_DEBUG_TX: api_read_data = debug_tx_reg;
          //ADDR_ERROR_STARTS: api_read_data = error_illegal_start_reg;
          //ADDR_ERROR_DISCARDS: api_read_data = error_illegal_discard_reg;
          default: ;
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // API counters
  //----------------------------------------------------------------

/*
  always @*
  begin : api_counters
    counter_bytes_we = 0;
    counter_bytes_new = 0;
    counter_packets_we = 0;
    counter_packets_new = 0;

    if (counter_bytes_rst) begin
      counter_bytes_we = 1;
      counter_bytes_new = 0;
    end else begin
      counter_bytes_we = 1;
      case (o_mac_tx_data_valid)
        default: counter_bytes_we = 0;
        8'b0000_0001: counter_bytes_new = counter_bytes_reg + 1;
        8'b0000_0011: counter_bytes_new = counter_bytes_reg + 2;
        8'b0000_0111: counter_bytes_new = counter_bytes_reg + 3;
        8'b0000_1111: counter_bytes_new = counter_bytes_reg + 4;
        8'b0001_1111: counter_bytes_new = counter_bytes_reg + 5;
        8'b0011_1111: counter_bytes_new = counter_bytes_reg + 6;
        8'b0111_1111: counter_bytes_new = counter_bytes_reg + 7;
        8'b1111_1111: counter_bytes_new = counter_bytes_reg + 8;
      endcase
    end

    if (counter_packets_rst) begin
      counter_packets_we = 1;
      counter_packets_new = 0;
    end else if (o_mac_tx_start) begin
      counter_packets_we = 1;
      counter_packets_new = counter_packets_reg + 1;
    end

  end
*/

  //----------------------------------------------------------------
  // Register Update (asynchronous reset)
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      //counter_bytes_reg <= 0;
      //counter_bytes_lsb_reg <= 0;
      //counter_packets_reg <= 0;
      //counter_packets_lsb_reg <= 0;
      //debug_tx_reg <= 0;
      dummy_reg <= 0;
      //error_illegal_discard_reg <= 0;
      //error_illegal_start_reg <= 0;
      //note: mac moved to its own clocked process to get timing, behaivor etc very similar to pp_tx
    end else begin
      //if (counter_bytes_we)
      //  counter_bytes_reg <= counter_bytes_new;

      //if (counter_bytes_lsb_we)
      //  counter_bytes_lsb_reg <= counter_bytes_reg[31:0];

      //if (counter_packets_we)
      //  counter_packets_reg <= counter_packets_new;

      //if (counter_packets_lsb_we)
      //  counter_packets_lsb_reg <= counter_packets_reg[31:0];

      //debug_tx_reg <= debug_tx_new;

      if (dummy_we)
        dummy_reg <= dummy_new;

      //if (error_illegal_discard_inc)
      //  error_illegal_discard_reg <= error_illegal_discard_reg + 1;

      //if (error_illegal_start_inc)
      //  error_illegal_start_reg <= error_illegal_start_reg + 1;

      //mac moved to its own clocked process to get timing, behaivor etc very similar to pp_tx
    end
  end


endmodule
