//
// Copyright (c) 2020, The Swedish Post and Telecom Authority (PTS)
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

module ntp_auth (
  input  wire         i_areset, // async reset
  input  wire         i_clk,

  input wire          i_auth_md5,
  output wire         o_auth_md5_ready,
  output wire         o_auth_md5_good,
  input wire          i_auth_md5_tx,

  input wire          i_rx_reset,
  input wire          i_rx_valid,
  input wire   [63:0] i_rx_data,

  input wire          i_timestamp_wr_en,
  input wire [ 2 : 0] i_timestamp_ntp_header_block,
  input wire [63 : 0] i_timestamp_ntp_header_data,

  output wire          o_keymem_get_key_md5,
  output wire          o_keymem_get_key_sha1,
  output wire [31 : 0] o_keymem_keyid,
  input wire   [2 : 0] i_keymem_key_word,
  input wire           i_keymem_key_valid,
  input wire  [31 : 0] i_keymem_key_data,
  input wire           i_keymem_ready,

  output wire          o_tx_wr_en,
  output wire  [6 : 0] o_tx_addr,
  output wire [63 : 0] o_tx_data
);

  localparam FSM_MD5_BITS = 4;

  localparam [FSM_MD5_BITS-1:0] FSM_MD5_IDLE          = 0;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_KEYWAIT       = 1;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_RXAUTH_INIT   = 2;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_RXAUTH_BLOCK0 = 3;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_RXAUTH_WAIT0  = 4;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_RXAUTH_BLOCK1 = 5;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_RXAUTH_WAIT1  = 6;

  localparam [FSM_MD5_BITS-1:0] FSM_MD5_TXAUTH_INIT   = 7;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_TXAUTH_BLOCK0 = 8;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_TXAUTH_WAIT0  = 9;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_TXAUTH_BLOCK1 = 10;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_TXAUTH_WAIT1  = 11;
  localparam [FSM_MD5_BITS-1:0] FSM_MD5_TXAUTH_OUT    = 12;

  localparam [FSM_MD5_BITS-1:0] FSM_MD5_ERROR         = 15;

  localparam FSM_KEY_BITS = 4;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_IDLE    = 0;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_MD5     = 1;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_SHA1    = 2;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_WAIT0   = 3;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_WAIT1   = 4;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_WAIT2   = 5;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_WAIT3   = 6;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_WAIT4   = 7;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_SUCCESS = 8;
  localparam [FSM_KEY_BITS-1:0] FSM_KEY_ERROR   = 15;

  localparam FSM_TXOUT_BITS = 3;
  localparam [FSM_TXOUT_BITS-1:0] FSM_TXOUT_IDLE        = 0;
  localparam [FSM_TXOUT_BITS-1:0] FSM_TXOUT_MD5_0       = 1;
  localparam [FSM_TXOUT_BITS-1:0] FSM_TXOUT_MD5_1       = 2;
  localparam [FSM_TXOUT_BITS-1:0] FSM_TXOUT_MD5_2       = 3;
  localparam [FSM_TXOUT_BITS-1:0] FSM_TXOUT_CRYPTO_NAK  = 4;
  localparam [FSM_TXOUT_BITS-1:0] FSM_TXOUT_FINAL       = 5;

  localparam [15:0] E_TYPE_IPV4 = 16'h08_00;
  localparam [15:0] E_TYPE_IPV6 = 16'h86_DD;

  localparam  [63:0] MD5_MESSAGE_BITLENGTH = 6*64 + 160;
  localparam   [7:0] MD5_PAD_BYTE0 = 8'h80;
  localparam [415:0] MD5_PAD = { MD5_PAD_BYTE0, 408'h0 };

  //----------------------------------------------------------------
  // Output Registers
  //----------------------------------------------------------------

  reg good_md5_we;
  reg good_md5_new;
  reg good_md5_reg;

  reg        keyid_we;
  reg [31:0] keyid_new;
  reg [31:0] keyid_reg;

  reg ready_md5_we;
  reg ready_md5_new;
  reg ready_md5_reg;

  reg          tx_we;
  reg          tx_wr_new;
  reg          tx_wr_reg;
  reg  [6 : 0] tx_addr_new;
  reg  [6 : 0] tx_addr_reg;
  reg [63 : 0] tx_data_new;
  reg [63 : 0] tx_data_reg;

  //----------------------------------------------------------------
  // Output Wires
  //----------------------------------------------------------------

  reg keymem_get_md5;

  //----------------------------------------------------------------
  // Output
  //----------------------------------------------------------------

  assign o_auth_md5_ready = ready_md5_reg;
  assign o_auth_md5_good = good_md5_reg;

  assign o_keymem_get_key_md5 = keymem_get_md5;
  assign o_keymem_get_key_sha1 = 0;
  assign o_keymem_keyid = keyid_reg;

  assign o_tx_addr = tx_addr_reg;
  assign o_tx_data = tx_data_reg;
  assign o_tx_wr_en = tx_wr_reg;

  //----------------------------------------------------------------
  // Input Registers (only here to relax timing / routing)
  //----------------------------------------------------------------

  reg           timestamp_wr_en_reg;
  reg  [ 2 : 0] timestamp_ntp_header_block_reg;
  reg  [63 : 0] timestamp_ntp_header_data_reg;

  //----------------------------------------------------------------
  // Registers
  //----------------------------------------------------------------

  reg                    fsm_key_we;
  reg [FSM_MD5_BITS-1:0] fsm_key_new;
  reg [FSM_MD5_BITS-1:0] fsm_key_reg;

  reg                    fsm_md5_we;
  reg [FSM_MD5_BITS-1:0] fsm_md5_new;
  reg [FSM_MD5_BITS-1:0] fsm_md5_reg;

  reg                      fsm_txout_we;
  reg [FSM_TXOUT_BITS-1:0] fsm_txout_new;
  reg [FSM_TXOUT_BITS-1:0] fsm_txout_reg;

  reg         key_we;
  reg  [31:0] key_new;
  reg   [2:0] key_addr;
  reg [159:0] key_reg;

  reg key_good_we;
  reg key_good_new;
  reg key_good_reg;


  reg         ntp_digest_we;
  reg [159:0] ntp_digest_new;
  /* verilator lint_off UNUSED */
  reg [159:0] ntp_digest_reg; //bits [31:0] will not be used in MD5
  /* verilator lint_on UNUSED */

  reg        ntp_counter_we;
  reg [15:0] ntp_counter_new;
  reg [15:0] ntp_counter_reg;

  reg            ntp_rx_we;
  reg      [2:0] ntp_rx_addr;
  reg     [63:0] ntp_rx_new;
  reg [6*64-1:0] ntp_rx_reg;

  reg            ntp_tx_we;
  reg      [2:0] ntp_tx_addr;
  reg     [63:0] ntp_tx_new;
  reg [6*64-1:0] ntp_tx_reg;

  reg        rx_counter_we;
  reg [15:0] rx_counter_new;
  reg [15:0] rx_counter_reg;

  reg rx_ipv4_we;
  reg rx_ipv4_new;
  reg rx_ipv4_reg;

  reg        rx_ipv4_current_valid_new;
  reg        rx_ipv4_current_valid_reg;
  reg [63:0] rx_ipv4_current_new;
  reg [63:0] rx_ipv4_current_reg;

  reg        rx_ipv4_previous_valid_new;
  reg        rx_ipv4_previous_valid_reg;
  reg [47:0] rx_ipv4_previous_new;
  reg [47:0] rx_ipv4_previous_reg;


  reg rx_ipv6_we;
  reg rx_ipv6_new;
  reg rx_ipv6_reg;

  reg        rx_ipv6_current_valid_new;
  reg        rx_ipv6_current_valid_reg;
  reg [63:0] rx_ipv6_current_new;
  reg [63:0] rx_ipv6_current_reg;

  reg        rx_ipv6_previous_valid_new;
  reg        rx_ipv6_previous_valid_reg;
  reg [15:0] rx_ipv6_previous_new;
  reg [15:0] rx_ipv6_previous_reg;

  //----------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------

  reg          txout_done;

  reg          md5_init;
  reg          md5_next;
  wire         md5_ready;
  wire [127:0] md5_digest;

  reg         md5_block_we;
  reg [511:0] md5_block_new;
  reg [511:0] md5_block_reg;

  //----------------------------------------------------------------
  // MD5 core
  //----------------------------------------------------------------

  md5_core md5(
    .clk    (  i_clk    ),
    .reset_n( ~i_areset ),

    .init( md5_init ),
    .next( md5_next ),

    .block  ( md5_block_reg ),
    .digest ( md5_digest    ),
    .ready  ( md5_ready     )
  );



  function [31:0] md5_encode( input [31:0] data );
  begin
    md5_encode[7:0]   = data[31:24];
    md5_encode[15:8]  = data[23:16];
    md5_encode[23:16] = data[15:8];
    md5_encode[31:24] = data[7:0];
  end
  endfunction

  function [447:0] md5_encode_448( input [447:0] data );
  begin
    md5_encode_448[0*32+:32]  = md5_encode( data[0*32+:32] );
    md5_encode_448[1*32+:32]  = md5_encode( data[1*32+:32] );
    md5_encode_448[2*32+:32]  = md5_encode( data[2*32+:32] );
    md5_encode_448[3*32+:32]  = md5_encode( data[3*32+:32] );
    md5_encode_448[4*32+:32]  = md5_encode( data[4*32+:32] );
    md5_encode_448[5*32+:32]  = md5_encode( data[5*32+:32] );
    md5_encode_448[6*32+:32]  = md5_encode( data[6*32+:32] );
    md5_encode_448[7*32+:32]  = md5_encode( data[7*32+:32] );
    md5_encode_448[8*32+:32]  = md5_encode( data[8*32+:32] );
    md5_encode_448[9*32+:32]  = md5_encode( data[9*32+:32] );
    md5_encode_448[10*32+:32] = md5_encode( data[10*32+:32] );
    md5_encode_448[11*32+:32] = md5_encode( data[11*32+:32] );
    md5_encode_448[12*32+:32] = md5_encode( data[12*32+:32] );
    md5_encode_448[13*32+:32] = md5_encode( data[13*32+:32] );
  end
  endfunction

  function [511:0] md5_encode_512( input [511:0] data );
  begin
    md5_encode_512[0*32+:32]  = md5_encode( data[0*32+:32] );
    md5_encode_512[1*32+:32]  = md5_encode( data[1*32+:32] );
    md5_encode_512[2*32+:32]  = md5_encode( data[2*32+:32] );
    md5_encode_512[3*32+:32]  = md5_encode( data[3*32+:32] );
    md5_encode_512[4*32+:32]  = md5_encode( data[4*32+:32] );
    md5_encode_512[5*32+:32]  = md5_encode( data[5*32+:32] );
    md5_encode_512[6*32+:32]  = md5_encode( data[6*32+:32] );
    md5_encode_512[7*32+:32]  = md5_encode( data[7*32+:32] );
    md5_encode_512[8*32+:32]  = md5_encode( data[8*32+:32] );
    md5_encode_512[9*32+:32]  = md5_encode( data[9*32+:32] );
    md5_encode_512[10*32+:32] = md5_encode( data[10*32+:32] );
    md5_encode_512[11*32+:32] = md5_encode( data[11*32+:32] );
    md5_encode_512[12*32+:32] = md5_encode( data[12*32+:32] );
    md5_encode_512[13*32+:32] = md5_encode( data[13*32+:32] );
    md5_encode_512[14*32+:32] = md5_encode( data[14*32+:32] );
    md5_encode_512[15*32+:32] = md5_encode( data[15*32+:32] );
  end
  endfunction

  //----------------------------------------------------------------
  // MD5 FSM
  //----------------------------------------------------------------

  always @*
  begin
    fsm_md5_we = 0;
    fsm_md5_new = FSM_MD5_IDLE;
    good_md5_we = 0;
    good_md5_new = 0;
    md5_block_we = 0;
    md5_block_new = 0;
    md5_init = 0;
    md5_next = 0;
    ready_md5_we = 0;
    ready_md5_new = 0;
    case (fsm_md5_reg)
      FSM_MD5_IDLE:
        if (i_auth_md5) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_KEYWAIT;
          good_md5_we = 1;
          good_md5_new = 0;
          ready_md5_we = 1;
          ready_md5_new = 0;
        end else if (i_auth_md5_tx) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_TXAUTH_INIT;
          ready_md5_we = 1;
          ready_md5_new = 0;
        end
      FSM_MD5_KEYWAIT:
        case (fsm_key_reg)
          FSM_KEY_ERROR:
            begin
              fsm_md5_we = 1;
              fsm_md5_new = FSM_MD5_ERROR;
            end
          FSM_KEY_SUCCESS:
            begin
              fsm_md5_we = 1;
              fsm_md5_new = FSM_MD5_RXAUTH_INIT;
            end
          default: ;
        endcase
      FSM_MD5_RXAUTH_INIT:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_RXAUTH_BLOCK0;
          md5_block_we = 1;
          md5_block_new = md5_encode_512( { key_reg, ntp_rx_reg[6*64-1:32] } );
          md5_init = 1;
        end
      FSM_MD5_RXAUTH_BLOCK0:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_RXAUTH_WAIT0;
          md5_next = 1;
        end
      FSM_MD5_RXAUTH_WAIT0:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_RXAUTH_BLOCK1;
          md5_block_we = 1;
          md5_block_new[511:64] = md5_encode_448( { ntp_rx_reg[31:0], MD5_PAD } );
          md5_block_new[63:0] = { MD5_MESSAGE_BITLENGTH[31:0], MD5_MESSAGE_BITLENGTH[63:32] };
        end
      FSM_MD5_RXAUTH_BLOCK1:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_RXAUTH_WAIT1;
          md5_next = 1;
        end
      FSM_MD5_RXAUTH_WAIT1:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_IDLE;
          if (md5_digest == ntp_digest_reg[159-:128]) begin
            good_md5_we = 1;
            good_md5_new = 1;
          end else begin
            good_md5_we = 1;
            good_md5_new = 0;
          end
          ready_md5_we = 1;
          ready_md5_new = 1;
        end
      FSM_MD5_TXAUTH_INIT:
        if (key_good_reg == 1'b0) begin
           //Crypto-NACK
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_TXAUTH_OUT;
        end else if (good_md5_reg == 1'b0) begin
           //Crypto-NACK
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_TXAUTH_OUT;
        end else begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_TXAUTH_BLOCK0;
          md5_block_we = 1;
          md5_block_new = md5_encode_512( { key_reg, ntp_tx_reg[6*64-1:32] } );
          md5_init = 1;
        end
      FSM_MD5_TXAUTH_BLOCK0:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_TXAUTH_WAIT0;
          md5_next = 1;
        end
      FSM_MD5_TXAUTH_WAIT0:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_TXAUTH_BLOCK1;
          md5_block_we = 1;
          md5_block_new[511:64] = md5_encode_448( { ntp_tx_reg[31:0], MD5_PAD } );
          md5_block_new[63:0] = { MD5_MESSAGE_BITLENGTH[31:0], MD5_MESSAGE_BITLENGTH[63:32] };
        end
      FSM_MD5_TXAUTH_BLOCK1:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_TXAUTH_WAIT1;
          md5_next = 1;
        end
      FSM_MD5_TXAUTH_WAIT1:
        if (md5_ready) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_TXAUTH_OUT;
        end
      FSM_MD5_TXAUTH_OUT:
        if (txout_done) begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_IDLE;
          ready_md5_we = 1;
          ready_md5_new = 1;
        end
      default:
        begin
          fsm_md5_we = 1;
          fsm_md5_new = FSM_MD5_IDLE;
          good_md5_we = 1;
          good_md5_new = 0;
          ready_md5_we = 1;
          ready_md5_new = 1;
        end
    endcase
  end

  //----------------------------------------------------------------
  // Key FSM
  //----------------------------------------------------------------

  always @*
  begin : fsm_key_

    fsm_key_we = 0;
    fsm_key_new = 0;
    keymem_get_md5 = 0;

    case (fsm_key_reg)
      FSM_KEY_IDLE:
        if (fsm_md5_reg == FSM_MD5_KEYWAIT) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_MD5;
        end
      FSM_KEY_MD5:
        if (i_keymem_ready) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_WAIT0;
          keymem_get_md5 = 1;
        end
      FSM_KEY_WAIT0:
        if (i_keymem_key_valid) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_WAIT1;
        end else if (i_keymem_ready) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_ERROR;
        end
      FSM_KEY_WAIT1:
        if (i_keymem_key_valid) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_WAIT2;
        end else if (i_keymem_ready) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_ERROR;
        end
      FSM_KEY_WAIT2:
        if (i_keymem_key_valid) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_WAIT3;
        end else if (i_keymem_ready) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_ERROR;
        end
      FSM_KEY_WAIT3:
        if (i_keymem_key_valid) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_WAIT4;
        end else if (i_keymem_ready) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_ERROR;
        end
      FSM_KEY_WAIT4:
        if (i_keymem_key_valid) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_SUCCESS;
        end else if (i_keymem_ready) begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_ERROR;
        end
      FSM_KEY_SUCCESS:
        begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_IDLE;
        end
      FSM_KEY_ERROR:
        begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_IDLE;
        end
      default:
        begin
          fsm_key_we = 1;
          fsm_key_new = FSM_KEY_ERROR;
         end
    endcase
  end

  //----------------------------------------------------------------
  // Key Capture. Records keys sent from Key Mem
  //----------------------------------------------------------------

  always @*
  begin : key_capture
    reg capture;
    capture = 0;

    key_we = 0;
    key_addr = 0;
    key_new = 0;

    key_good_we = 0;
    key_good_new = 0;

    case (fsm_key_reg)
      FSM_KEY_MD5:
        begin
          key_good_we = 1;
          key_good_new = 0;
        end
      FSM_KEY_WAIT0: capture = 1;
      FSM_KEY_WAIT1: capture = 1;
      FSM_KEY_WAIT2: capture = 1;
      FSM_KEY_WAIT3: capture = 1;
      FSM_KEY_WAIT4: capture = 1;
      FSM_KEY_SUCCESS:
        begin
          key_good_we = 1;
          key_good_new = 1;
        end
      FSM_KEY_ERROR:
        begin
          key_good_we = 1;
          key_good_new = 0;
        end
      default: ;
    endcase

    if (capture) begin
      if (i_keymem_key_valid) begin
        key_we = 1;
        key_addr = i_keymem_key_word;
        key_new = i_keymem_key_data;
      end
    end
  end

  //----------------------------------------------------------------
  // Register Update
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      fsm_key_reg <= FSM_KEY_IDLE;
      fsm_md5_reg <= FSM_MD5_IDLE;
      fsm_txout_reg <= FSM_TXOUT_IDLE;
      good_md5_reg <= 0;
      key_reg <= 0;
      key_good_reg <= 0;
      keyid_reg <= 0;
      md5_block_reg <= 0;
      ntp_counter_reg <= 0;
      ntp_digest_reg <= 0;
      ntp_rx_reg <= 0;
      ntp_tx_reg <= 0;
      ready_md5_reg <= 1;
      rx_counter_reg <= 0;
      rx_ipv4_reg <= 0;
      rx_ipv4_current_reg <= 0;
      rx_ipv4_current_valid_reg <= 0;
      rx_ipv4_previous_reg <= 0;
      rx_ipv4_previous_valid_reg <= 0;
      rx_ipv6_reg <= 0;
      rx_ipv6_current_reg <= 0;
      rx_ipv6_current_valid_reg <= 0;
      rx_ipv6_previous_reg <= 0;
      rx_ipv6_previous_valid_reg <= 0;
      timestamp_wr_en_reg <= 0;
      timestamp_ntp_header_block_reg <= 0;
      timestamp_ntp_header_data_reg <= 0;
      tx_addr_reg <= 0;
      tx_data_reg <= 0;
      tx_wr_reg <= 0;
    end else begin
      if (fsm_key_we)
        fsm_key_reg <= fsm_key_new;

      if (fsm_md5_we)
        fsm_md5_reg <= fsm_md5_new;

      if (fsm_txout_we)
        fsm_txout_reg <= fsm_txout_new;

      if (good_md5_we)
        good_md5_reg <= good_md5_new;

      if (key_we)
        key_reg[ key_addr*32+:32 ] <= key_new;

      if (key_good_we)
        key_good_reg <= key_good_new;

      if (keyid_we)
        keyid_reg <= keyid_new;

      if (md5_block_we)
        md5_block_reg  <= md5_block_new;

      if (ntp_counter_we)
        ntp_counter_reg <= ntp_counter_new;

      if (ntp_digest_we)
        ntp_digest_reg <= ntp_digest_new;

      if (ntp_rx_we)
        ntp_rx_reg[ ntp_rx_addr*64+:64 ] <= ntp_rx_new;

      if (ntp_tx_we)
        ntp_tx_reg[ ntp_tx_addr*64+:64 ] <= ntp_tx_new;

      if (ready_md5_we)
        ready_md5_reg <= ready_md5_new;

      if (rx_counter_we)
        rx_counter_reg <= rx_counter_new;

      rx_ipv4_current_reg <= rx_ipv4_current_new;
      rx_ipv4_current_valid_reg <= rx_ipv4_current_valid_new;

      rx_ipv4_previous_reg <= rx_ipv4_previous_new;
      rx_ipv4_previous_valid_reg <= rx_ipv4_previous_valid_new;

      rx_ipv6_current_reg <= rx_ipv6_current_new;
      rx_ipv6_current_valid_reg <= rx_ipv6_current_valid_new;

      rx_ipv6_previous_reg <= rx_ipv6_previous_new;
      rx_ipv6_previous_valid_reg <= rx_ipv6_previous_valid_new;

      if (rx_ipv4_we)
        rx_ipv4_reg <= rx_ipv4_new;

      if (rx_ipv6_we)
        rx_ipv6_reg <= rx_ipv6_new;

      timestamp_wr_en_reg <= i_timestamp_wr_en;
      timestamp_ntp_header_block_reg <= i_timestamp_ntp_header_block;
      timestamp_ntp_header_data_reg <= i_timestamp_ntp_header_data;

      if (tx_we) begin
        tx_addr_reg <= tx_addr_new;
        tx_data_reg <= tx_data_new;
        tx_wr_reg <= tx_wr_new;
      end
    end
  end

  //----------------------------------------------------------------
  // RX word counter
  //----------------------------------------------------------------

  always @*
  begin
    rx_counter_we = 0;
    rx_counter_new = 0;
    if (i_rx_reset) begin
      rx_counter_we = 1;
      rx_counter_new = 0;
    end else if (i_rx_valid) begin
      if (rx_counter_reg != 16'hffff) begin
        rx_counter_we = 1;
        rx_counter_new = rx_counter_reg + 1;
      end
    end
  end


  always @*
  begin
    rx_ipv4_we  = 0;
    rx_ipv4_new = 0;

    rx_ipv6_we  = 0;
    rx_ipv6_new = 0;

    if (i_rx_reset) begin
      rx_ipv4_we  = 1;
      rx_ipv4_new = 0;
      rx_ipv6_we  = 1;
      rx_ipv6_new = 0;

    end else if (i_rx_valid) begin
      case (rx_counter_reg)
        1: case (i_rx_data[31:16])
             E_TYPE_IPV4: begin rx_ipv4_we = 1; rx_ipv4_new = 1; end
             E_TYPE_IPV6: begin rx_ipv6_we = 1; rx_ipv6_new = 1; end
             default: ;
           endcase
        default: ;
      endcase
    end
  end

  always @*
  begin
    ntp_counter_we = 0;
    ntp_counter_new = 0;

    rx_ipv4_previous_valid_new = 0;
    rx_ipv4_previous_new = i_rx_data[47:0];
    rx_ipv4_current_valid_new = 0;
    rx_ipv4_current_new = 0;

    rx_ipv6_previous_valid_new = 0;
    rx_ipv6_previous_new = i_rx_data[15:0];
    rx_ipv6_current_valid_new = 0;
    rx_ipv6_current_new = 0;


    if (rx_ipv4_reg) begin

      if (rx_counter_reg >= 5) begin
        if (i_rx_valid) begin
          rx_ipv4_previous_valid_new = 1;
          rx_ipv4_current_new = { rx_ipv4_previous_reg, i_rx_data[63:48] };
        end else begin
          rx_ipv4_current_new = { rx_ipv4_previous_reg, 16'h0 };
        end

        rx_ipv4_current_valid_new = rx_ipv4_previous_valid_reg;

        if (rx_ipv4_current_valid_reg) begin
          if (ntp_counter_reg != 16'hffff) begin
            ntp_counter_we = 1;
            ntp_counter_new = ntp_counter_reg + 1;
          end
        end
      end
    end

    if (rx_ipv6_reg) begin
      if (rx_counter_reg >= 7) begin
        if (i_rx_valid) begin
          rx_ipv6_previous_valid_new = 1;
          rx_ipv6_current_new = { rx_ipv6_previous_reg, i_rx_data[63:16] };
        end else begin
          rx_ipv6_current_new = { rx_ipv6_previous_reg, 48'h0 };
        end

        rx_ipv6_current_valid_new = rx_ipv6_previous_valid_reg;

        if (rx_ipv6_current_valid_reg) begin
          if (ntp_counter_reg != 16'hffff) begin
            ntp_counter_we = 1;
            ntp_counter_new = ntp_counter_reg + 1;
          end
        end
      end
    end

    if (i_rx_reset) begin
      rx_ipv4_previous_new = 0;
      rx_ipv4_current_new = 0;
      rx_ipv6_previous_new = 0;
      rx_ipv4_current_new = 0;
      ntp_counter_we = 1;
      ntp_counter_new = 0;
    end
  end

  //----------------------------------------------------------------
  // RX NTP
  //----------------------------------------------------------------

  always @*
  begin : rx
    reg process;
    reg [63:0] process_data;

    process = 0;
    process_data = 0;

    keyid_we = 0;
    keyid_new = 0;

    ntp_digest_we = 0;
    ntp_digest_new = 0;

    ntp_rx_we = 0;
    ntp_rx_addr = 0;
    ntp_rx_new = 0;

    if (rx_ipv4_reg) begin
      if (rx_ipv4_current_valid_reg) begin
        process = 1;
        process_data = rx_ipv4_current_reg;
      end
    end

    if (rx_ipv6_reg) begin
      if (rx_ipv6_current_valid_reg) begin
        process = 1;
        process_data = rx_ipv6_current_reg;
      end
    end

    if (process) begin
      case (ntp_counter_reg)
        'h0: begin ntp_rx_we = 1; ntp_rx_addr = 5; ntp_rx_new = process_data; end
        'h1: begin ntp_rx_we = 1; ntp_rx_addr = 4; ntp_rx_new = process_data; end
        'h2: begin ntp_rx_we = 1; ntp_rx_addr = 3; ntp_rx_new = process_data; end
        'h3: begin ntp_rx_we = 1; ntp_rx_addr = 2; ntp_rx_new = process_data; end
        'h4: begin ntp_rx_we = 1; ntp_rx_addr = 1; ntp_rx_new = process_data; end
        'h5: begin ntp_rx_we = 1; ntp_rx_addr = 0; ntp_rx_new = process_data; end
        'h6: begin
               keyid_we = 1;
               keyid_new = process_data[63:32];
               ntp_digest_we = 1;
               ntp_digest_new = { process_data[31:0], 128'h0 };
              end
        'h7: begin
               ntp_digest_we = 1;
               ntp_digest_new = { ntp_digest_reg[159:128], process_data, 64'h0 };
             end
        'h8: begin
               ntp_digest_we = 1;
               ntp_digest_new = { ntp_digest_reg[159:64], process_data };
             end
        default: ;
      endcase
    end
  end

  //----------------------------------------------------------------
  // TX NTP
  //----------------------------------------------------------------

  always @*
  begin : tx
    ntp_tx_we = 0;
    ntp_tx_addr = 0;
    ntp_tx_new = 0;
    if (timestamp_wr_en_reg) begin
      ntp_tx_we = 1;
      ntp_tx_addr = 5 - timestamp_ntp_header_block_reg;
      ntp_tx_new = timestamp_ntp_header_data_reg;
    end
  end

  //----------------------------------------------------------------
  // TX out
  //----------------------------------------------------------------

  always @*
  begin : txout
    reg         bad_state;
    reg [6 : 0] base_addr;

    if (rx_ipv4_reg) begin
      bad_state = 0;
      base_addr = 7'h5a; //14 + 20 + 8 + 48
    end else if (rx_ipv6_reg) begin
      bad_state = 0;
      base_addr = 7'h6e; //14 + 40 + 8 + 48
    end else begin
      bad_state = 1;
      base_addr = 0;
    end

    txout_done = 0;

    fsm_txout_we = 0;
    fsm_txout_new = 0;

    tx_we = 0;
    tx_addr_new = 0;
    tx_data_new = 0;
    tx_wr_new = 0;

    case (fsm_txout_reg)
      FSM_TXOUT_IDLE:
        if (fsm_md5_reg == FSM_MD5_TXAUTH_OUT) begin
          if (bad_state) begin
            fsm_txout_we = 1;
            fsm_txout_new = FSM_TXOUT_FINAL;
          end else if (good_md5_reg) begin
            fsm_txout_we = 1;
            fsm_txout_new = FSM_TXOUT_MD5_0;
          end else begin
            fsm_txout_we = 1;
            fsm_txout_new = FSM_TXOUT_CRYPTO_NAK;
          end
        end
      FSM_TXOUT_MD5_0:
        begin
          tx_we = 1;
          tx_addr_new = base_addr;
          tx_data_new = { keyid_reg, md5_digest[127:96] };
          tx_wr_new = 1;
          fsm_txout_we = 1;
          fsm_txout_new = FSM_TXOUT_MD5_1;
        end
      FSM_TXOUT_MD5_1:
        begin
          tx_we = 1;
          tx_addr_new = base_addr + 8;
          tx_data_new = md5_digest[95:32];
          tx_wr_new = 1;
          fsm_txout_we = 1;
          fsm_txout_new = FSM_TXOUT_MD5_2;
        end
      FSM_TXOUT_MD5_2:
        begin
          tx_we = 1;
          tx_addr_new = base_addr + 16;
          tx_data_new = { md5_digest[31:0], 32'h0 };
          tx_wr_new = 1;
          fsm_txout_we = 1;
          fsm_txout_new = FSM_TXOUT_FINAL;
        end
      FSM_TXOUT_CRYPTO_NAK:
        begin
          tx_we = 1;
          tx_addr_new = base_addr;
          tx_data_new = 0;
          tx_wr_new = 1;
          fsm_txout_we = 1;
          fsm_txout_new = FSM_TXOUT_FINAL;
        end
      FSM_TXOUT_FINAL:
        begin
          tx_we = 1;
          tx_addr_new = 0;
          tx_data_new = 0;
          tx_wr_new = 0;
          txout_done = 1;
          fsm_txout_we = 1;
          fsm_txout_new = FSM_TXOUT_IDLE;
        end
      default:
        begin
          txout_done = 1;
          fsm_txout_we = 1;
          fsm_txout_new = FSM_TXOUT_IDLE;
        end
    endcase
  end


endmodule
