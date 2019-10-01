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

module nts_timestamp (
  input wire  i_areset, // async reset
  input wire  i_clk,

  input wire  [ 63 : 0 ] i_ntp_time,

  // Parsed information
  input wire           i_parser_clear, //parser request ignore current packet
  input wire           i_parser_record_receive_timestamp,
  input wire           i_parser_transmit, //parser signal packet transmit OK
  input wire  [63 : 0] i_parser_origin_timestamp,
  input wire  [ 2 : 0] i_parser_version_number,
  input wire  [ 7 : 0] i_parser_poll,

  input  wire          i_tx_read,
  output wire          o_tx_empty,
  output wire [ 2 : 0] o_tx_ntp_header_block,
  output wire [63 : 0] o_tx_ntp_header_data,

  // API access
  input wire           i_api_cs,
  input wire           i_api_we,
  input wire   [7 : 0] i_api_address,
  input wire  [31 : 0] i_api_write_data,
  output wire [31 : 0] o_api_read_data
);
  //----------------------------------------------------------------
  // API related local constants
  //----------------------------------------------------------------
  localparam ADDR_NAME0   = 8'h00;
  localparam ADDR_NAME1   = 8'h01;
  localparam ADDR_VERSION = 8'h02;

  localparam ADDR_NTP_CONFIG        = 8'h10;
  localparam ADDR_NTP_ROOT_DELAY    = 8'h11;
  localparam ADDR_NTP_ROOT_DISP     = 8'h12;
  localparam ADDR_NTP_REF_ID        = 8'h13;
  localparam ADDR_NTP_TX_OFS        = 8'h14;

  localparam CORE_NAME0   = 32'h74696d65; //"time"
  localparam CORE_NAME1   = 32'h73746d70; //"stmp"
  localparam CORE_VERSION = 32'h302e3030; //"0.00"

  //----------------------------------------------------------------
  // NTP related locaal constants
  //----------------------------------------------------------------
  localparam       NTP_HEADER_BITS      = 384;
  localparam       NTP_HEADER_BLOCKS    = NTP_HEADER_BITS/64; //6
  localparam [2:0] NTP_HEADER_BLOCKS_M1 = NTP_HEADER_BLOCKS[2:0] - 1;

  //----------------------------------------------------------------
  // States
  //----------------------------------------------------------------

  localparam STATE_BITS = 1;

  localparam [STATE_BITS-1 : 0] STATE_IDLE      = 0;
  localparam [STATE_BITS-1 : 0] STATE_TX_FIFO   = 1;

  //----------------------------------------------------------------
  // reg
  //----------------------------------------------------------------
  reg        ntp_config_we;      // LI | VN | Mode | Stratum | Poll | Precision
  reg [31:0] ntp_config_new;     // LI | VN | Mode | Stratum | Poll | Precision
  reg [31:0] ntp_config_reg;     // LI | VN | Mode | Stratum | Poll | Precision
  reg        ntp_root_delay_we;  // Root Delay
  reg [31:0] ntp_root_delay_new; // Root Delay
  reg [31:0] ntp_root_delay_reg; // Root Delay

  reg        ntp_root_disp_we;   // Root Dispersion
  reg [31:0] ntp_root_disp_new;  // Root Dispersion
  reg [31:0] ntp_root_disp_reg;  // Root Dispersion

  reg        ntp_ref_id_we;      // Reference ID
  reg [31:0] ntp_ref_id_new;     // Reference ID
  reg [31:0] ntp_ref_id_reg;     // Reference ID

  reg        ntp_tx_ofs_we;      // TX offset
  reg [31:0] ntp_tx_ofs_new;     // TX offset
  reg [31:0] ntp_tx_ofs_reg;     // TX offset


  reg        p_client_poll_we;
  reg  [7:0] p_client_poll_new;
  reg  [7:0] p_client_poll_reg;

  reg        p_origin_timestamp_we;
  reg [63:0] p_origin_timestamp_new;
  reg [63:0] p_origin_timestamp_reg;

  reg        p_reference_timestamp_seconds_we;
  reg [31:0] p_reference_timestamp_seconds_new;
  reg [31:0] p_reference_timestamp_seconds_reg;

  reg        p_receive_timestamp_we;
  reg [63:0] p_receive_timestamp_new;
  reg [63:0] p_receive_timestamp_reg;

  reg        p_transmit_timestamp_we;
  reg [63:0] p_transmit_timestamp_new;
  reg [63:0] p_transmit_timestamp_reg;

  reg        p_version_number_we;
  reg  [2:0] p_version_number_new;
  reg  [2:0] p_version_number_reg;

  reg  [STATE_BITS-1:0] state_we;
  reg  [STATE_BITS-1:0] state_new;
  reg  [STATE_BITS-1:0] state_reg;

  reg        tx_counter_we;
  reg  [2:0] tx_counter_new; //0..5
  reg  [2:0] tx_counter_reg; //0..5

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  reg  [31:0] api_tmp_read_data;

  reg         tmp_ntp_empty;
  reg  [63:0] tmp_ntp_data;

  wire [63:0] ntp_ref_ts;

  wire [ 1:0] p_LI;
  wire [ 2:0] p_VN;
  wire [ 2:0] p_MODE;
  wire [ 7:0] p_STRATUM;
  wire [ 7:0] p_POLL;
  wire [ 7:0] p_PRECISION;

  wire [NTP_HEADER_BITS-1 : 0] packet;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign o_api_read_data = api_tmp_read_data;

  assign ntp_ref_ts[63:32] = p_reference_timestamp_seconds_reg;
  assign ntp_ref_ts[31: 0] = 32'b0; // Fraction

  assign p_LI        = ntp_config_reg[31:30];
  assign p_VN        = ntp_config_reg[29:27] != 3'b0 ? ntp_config_reg[29:27] : p_version_number_reg;
  assign p_MODE      = ntp_config_reg[26:24] != 3'b0 ? ntp_config_reg[26:24] : 3'd4 /* NTPv4 */;
  assign p_STRATUM   = ntp_config_reg[23:16] != 8'b0 ? ntp_config_reg[23:16] : 8'd1;
  assign p_POLL      = ntp_config_reg[15:8]  != 8'b0 ? ntp_config_reg[15:8]  : p_client_poll_reg;
  assign p_PRECISION = ntp_config_reg[7:0];

/*
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |LI | VN  |Mode |    Stratum     |     Poll      |  Precision   |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                         Root Delay                            |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                         Root Dispersion                       |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                          Reference ID                         |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                                                               |
 +                     Reference Timestamp (64)                  +
 |                                                               |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                                                               |
 +                      Origin Timestamp (64)                    +
 |                                                               |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                                                               |
 +                      Receive Timestamp (64)                   +
 |                                                               |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                                                               |
 +                      Transmit Timestamp (64)                  +
 |                                                               |
*/
  assign packet = { p_LI, p_VN, p_MODE, p_STRATUM, p_POLL, p_PRECISION,
                    ntp_root_delay_reg,
                    ntp_root_disp_reg,
                    ntp_ref_id_reg,
                    ntp_ref_ts,
                    p_origin_timestamp_reg,
                    p_receive_timestamp_reg,
                    p_transmit_timestamp_reg
                  };

  assign o_tx_ntp_header_data  = tmp_ntp_data;
  assign o_tx_ntp_header_block = tx_counter_reg;

  assign o_tx_empty            = tmp_ntp_empty;

  always @*
  begin : tx_mux
    tmp_ntp_data = 0;
    case (tx_counter_reg)
      0: tmp_ntp_data = packet[NTP_HEADER_BITS -   1 : NTP_HEADER_BITS -  64 ];
      1: tmp_ntp_data = packet[NTP_HEADER_BITS -  65 : NTP_HEADER_BITS - 128 ];
      2: tmp_ntp_data = packet[NTP_HEADER_BITS - 129 : NTP_HEADER_BITS - 192 ];
      3: tmp_ntp_data = packet[NTP_HEADER_BITS - 193 : NTP_HEADER_BITS - 256 ];
      4: tmp_ntp_data = packet[NTP_HEADER_BITS - 257 : NTP_HEADER_BITS - 320 ];
      5: tmp_ntp_data = packet[NTP_HEADER_BITS - 321 : NTP_HEADER_BITS - 384 ];
      default: ;
    endcase
  end

  always @*
  begin
    tmp_ntp_empty = 1;
    if (state_reg == STATE_TX_FIFO) begin
      tmp_ntp_empty = 0;
    end
  end


  //----------------------------------------------------------------
  // Register update
  //----------------------------------------------------------------
  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      ntp_config_reg        <= 'b0;
      ntp_root_delay_reg    <= 'b0;
      ntp_root_disp_reg     <= 'b0;
      ntp_ref_id_reg        <= 'b0;
      ntp_tx_ofs_reg        <= 'b0;

      p_client_poll_reg       <= 'b0;
      p_origin_timestamp_reg  <= 'b0;
      p_receive_timestamp_reg <= 'b0;
      p_version_number_reg    <= 'b0;

      p_reference_timestamp_seconds_reg <= 'b0;

      state_reg <= 'b0;

      tx_counter_reg <= 'b0;

    end else begin
      if (ntp_config_we)
        ntp_config_reg <= ntp_config_new;

      if (ntp_root_delay_we)
        ntp_root_delay_reg <= ntp_root_delay_new;

      if (ntp_root_disp_we)
        ntp_root_disp_reg <= ntp_root_disp_new;

      if (ntp_ref_id_we)
        ntp_ref_id_reg  <= ntp_ref_id_new;

      if (ntp_tx_ofs_we)
        ntp_tx_ofs_reg <= ntp_tx_ofs_new;

      if (p_client_poll_we)
        p_client_poll_reg <= p_client_poll_new;

      if (p_origin_timestamp_we)
        p_origin_timestamp_reg <= p_origin_timestamp_new;

      if (p_reference_timestamp_seconds_we)
        p_reference_timestamp_seconds_reg <= p_reference_timestamp_seconds_new;

      if (p_receive_timestamp_we)
        p_receive_timestamp_reg <= p_receive_timestamp_new;

      if (p_transmit_timestamp_we)
        p_transmit_timestamp_reg <= p_transmit_timestamp_new;

      if (p_version_number_we)
        p_version_number_reg <= p_version_number_new;

      if (state_we)
        state_reg <= state_new;

      if (tx_counter_we)
        tx_counter_reg <= tx_counter_new;

    end
  end

  //----------------------------------------------------------------
  // timpestamps
  //----------------------------------------------------------------

  always @*
  begin : rx_timing
    p_origin_timestamp_we   = 'b0;
    p_receive_timestamp_we  = 'b0;
    p_transmit_timestamp_we = 'b0;
    p_reference_timestamp_seconds_we = 'b0;

    p_origin_timestamp_new   = i_parser_origin_timestamp;
    p_receive_timestamp_new  = i_ntp_time;
    p_transmit_timestamp_new = i_ntp_time + { 32'b0, ntp_tx_ofs_reg }; //TODO NTP design has various constants added here as well
    p_reference_timestamp_seconds_new = i_ntp_time[63:32] - 1; // Create a reference timestamp assuming it was set one the previous PPS.

    // TODO: Future improvement; singal reftime from ntp_clock_top.

    if (state_reg == STATE_IDLE) begin
      if (i_parser_record_receive_timestamp)
        p_receive_timestamp_we = 'b1;

      if (i_parser_transmit) begin
        p_origin_timestamp_we   = 'b1;
        p_transmit_timestamp_we = 'b1;
        p_reference_timestamp_seconds_we = 'b1;
      end
    end

  end

  //----------------------------------------------------------------
  // Parser regs
  //----------------------------------------------------------------

  always @*
  begin : parser
    p_version_number_we = 'b0;
    p_client_poll_we    = 'b0;

    p_version_number_new = i_parser_version_number;
    p_client_poll_new    = i_parser_poll;

    if (state_reg == STATE_IDLE && i_parser_transmit) begin
      p_version_number_we = 'b1;
      p_client_poll_we    = 'b1;
    end
  end

  //----------------------------------------------------------------
  // State
  //----------------------------------------------------------------

  always @*
  begin : state_process
    state_we  = 'b0;
    state_new = STATE_IDLE;
    if (i_parser_clear) begin
      state_we = 'b1;
    end else begin
      case (state_reg)
        STATE_IDLE:
           if (i_parser_transmit) begin
            state_we  = 'b1;
            state_new = STATE_TX_FIFO;
          end
        STATE_TX_FIFO:
          begin
            if (tx_counter_reg == NTP_HEADER_BLOCKS_M1 && i_tx_read) begin
              state_we  = 'b1;
              state_new = STATE_IDLE;
            end
          end
        default:
          begin
            state_we  = 'b1;
            state_new = STATE_IDLE;
          end
      endcase
    end
  end

  always @*
  begin : tx_fifo_counter_process
    tx_counter_we  = 'b0;
    tx_counter_new = 'b0;
    if (state_reg == STATE_TX_FIFO) begin
      if (i_tx_read) begin
        tx_counter_we  = 'b1;
        if (tx_counter_reg == NTP_HEADER_BLOCKS_M1) begin
          tx_counter_new = 'b0;
        end else begin
          tx_counter_new = tx_counter_reg + 1;
        end
      end
    end else begin
      tx_counter_we  = 'b1; //reset counter in other states
    end
  end

  //----------------------------------------------------------------
  // api
  //----------------------------------------------------------------
  always @*
  begin : api
    api_tmp_read_data  = 32'h0;

    ntp_config_we      = 'b0;
    ntp_root_delay_we  = 'b0;
    ntp_root_disp_we   = 'b0;
    ntp_ref_id_we      = 'b0;
    ntp_tx_ofs_we      = 'b0;

    ntp_config_new     = i_api_write_data;
    ntp_root_delay_new = i_api_write_data;
    ntp_root_disp_new  = i_api_write_data;
    ntp_ref_id_new     = i_api_write_data;
    ntp_tx_ofs_new     = i_api_write_data;

    if (i_api_cs) begin
      if (i_api_we) begin
        case (i_api_address)
          ADDR_NTP_CONFIG:     ntp_config_we      = 'b1;
          ADDR_NTP_ROOT_DELAY: ntp_root_delay_we  = 'b1;
          ADDR_NTP_ROOT_DISP:  ntp_root_disp_we   = 'b1;
          ADDR_NTP_REF_ID:     ntp_ref_id_we      = 'b1;
          ADDR_NTP_TX_OFS:     ntp_tx_ofs_we      = 'b1;

          default: ;
        endcase
      end else begin // read
        case (i_api_address)
          ADDR_NAME0:   api_tmp_read_data = CORE_NAME0;
          ADDR_NAME1:   api_tmp_read_data = CORE_NAME1;
          ADDR_VERSION: api_tmp_read_data = CORE_VERSION;

          ADDR_NTP_CONFIG:     api_tmp_read_data = ntp_config_reg;
          ADDR_NTP_ROOT_DELAY: api_tmp_read_data = ntp_root_delay_reg;
          ADDR_NTP_ROOT_DISP:  api_tmp_read_data = ntp_root_disp_reg;
          ADDR_NTP_REF_ID:     api_tmp_read_data = ntp_ref_id_reg;
          ADDR_NTP_TX_OFS:     api_tmp_read_data = ntp_tx_ofs_reg;

          default: ;
        endcase
      end // end read
    end // end cs
  end
endmodule
