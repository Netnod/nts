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

module nts_verify_secure #(
  parameter RX_PORT_WIDTH = 64,
  parameter ADDR_WIDTH = 8
)
(
  input  wire                         i_areset, // async reset
  input  wire                         i_clk,

  output wire                         o_busy,

  input  wire                         i_unrwapped_s2c,
  input  wire                         i_unwrapped_c2s,
  input  wire                 [2 : 0] i_unwrapped_word,
  input  wire                [31 : 0] i_unwrapped_data,

  input  wire                         i_op_copy_rx_ad,
  input  wire                         i_op_copy_rx_nonce,
  input  wire                         i_op_copy_rx_tag,
  input  wire                         i_op_verify,

  input  wire      [ADDR_WIDTH+3-1:0] i_copy_rx_addr,
  input  wire                   [9:0] i_copy_rx_bytes,

  input  wire                         i_rx_wait,
  output wire      [ADDR_WIDTH+3-1:0] o_rx_addr,
  output wire                   [2:0] o_rx_wordsize,
  output wire                         o_rx_rd_en,
  input  wire                         i_rx_rd_dv,
  input  wire     [RX_PORT_WIDTH-1:0] i_rx_rd_data
);

  localparam BITS_STATE = 3;
  localparam [BITS_STATE-1:0] STATE_IDLE               = 0;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_INIT_AD    = 1;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_INIT_NONCE = 2;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_INIT_TAG   = 3;
  localparam [BITS_STATE-1:0] STATE_COPY_RX            = 4;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_TAG        = 5;
  localparam [BITS_STATE-1:0] STATE_SIV_VERIFY_WAIT_0  = 6;
  localparam [BITS_STATE-1:0] STATE_SIV_VERIFY_WAIT_1  = 7;

  /* MEM8 addresses must be lsb=0 */
  localparam [7:0] MEM8_ADDR_AD    = 8;
  localparam [7:0] MEM8_ADDR_PC    = 0;
  localparam [7:0] MEM8_ADDR_NONCE = 4;

  localparam MODE_DECRYPT = 0;
  localparam MODE_ENCRYPT = 1;

  localparam AEAD_AES_SIV_CMAC_256 = 1'h0;
  localparam AEAD_AES_SIV_CMAC_512 = 1'h1;

  reg                  state_we;
  reg [BITS_STATE-1:0] state_new;
  reg [BITS_STATE-1:0] state_reg;

  reg            key_c2s_we;
  reg      [2:0] key_c2s_addr;
  reg     [31:0] key_c2s_new;
  reg    [255:0] key_c2s_reg;

  reg            key_s2c_we;
  reg      [2:0] key_s2c_addr;
  reg     [31:0] key_s2c_new;
  reg    [255:0] key_s2c_reg;

  reg            core_tag_we   [0:1];
  reg     [63:0] core_tag_new;
  reg     [63:0] core_tag_reg  [0:1];

  reg       ramrx_addr_we;
  reg [7:0] ramrx_addr_new;
  reg [7:0] ramrx_addr_reg;

  reg                    rx_addr_last_we;
  reg [ADDR_WIDTH+3-1:0] rx_addr_last_new;
  reg [ADDR_WIDTH+3-1:0] rx_addr_last_reg;

  reg                    rx_addr_next_we;
  reg [ADDR_WIDTH+3-1:0] rx_addr_next_new;
  reg [ADDR_WIDTH+3-1:0] rx_addr_next_reg;

  reg rx_tag_we;
  reg rx_tag_new;
  reg rx_tag_reg;

  reg          core_ack_reg; //core_ack_new == core_cs

  reg          core_start_reg;
  reg          core_start_new;

  reg          core_config_encdec_reg;
  reg          core_config_encdec_new;
  reg          core_config_mode_reg;
  reg          core_config_mode_new;
  reg          core_config_we;

  reg [19 : 0] core_ad_length_reg;
  reg [19 : 0] core_ad_length_new;
  reg          core_ad_length_we;


  // --------------------------------------------
  // Wires
  // --------------------------------------------

  wire [511 : 0] core_key;
  wire  [15 : 0] core_ad_start;
  wire  [15 : 0] core_pc_start;
  wire  [15 : 0] core_nonce_start;

  wire  [19 : 0] core_nonce_length;
  wire  [19 : 0] core_pc_length;

  wire           core_cs;
  wire           core_we;
  wire  [15 : 0] core_addr;
  wire [127 : 0] core_block_rd;
  wire [127 : 0] core_block_wr;
  wire [127 : 0] core_tag_in;
  wire [127 : 0] core_tag_out;
  wire           core_tag_ok;
  wire           core_ready;


  reg [ADDR_WIDTH+3-1:0] rx_addr;
  reg                    rx_rd_en;

  reg          ramrx_en;
  reg          ramrx_we;
  reg   [63:0] ramrx_wdata;

  reg          ram_a_en;
  reg          ram_a_we;
  reg    [7:0] ram_a_addr;
  reg   [63:0] ram_a_wdata;

  reg          ram_b_en;
  reg          ram_b_we;
  reg    [7:0] ram_b_addr;
  reg   [63:0] ram_b_wdata;

  wire  [63:0] ram_a_rdata;
  wire  [63:0] ram_b_rdata;

  wire         reset_n;

  // --------------------------------------------
  // Wire and output assignments
  // --------------------------------------------

  assign core_key = { key_c2s_reg[255:128], 128'h0, key_c2s_reg[127:0], 128'h0 }; // TODO update when adding s2c support

  assign core_ad_start = { 9'h0, MEM8_ADDR_AD[7:1] };

  assign core_block_rd = { ram_a_rdata, ram_b_rdata };

  assign core_nonce_start = { 9'h0, MEM8_ADDR_NONCE[7:1] };
  assign core_nonce_length = 16;

  assign core_pc_start = { 9'h0, MEM8_ADDR_PC[7:1] };
  assign core_pc_length = 0;

  assign core_tag_in = { core_tag_reg[0], core_tag_reg[1] };

  assign o_busy = state_reg != STATE_IDLE;

  assign o_rx_addr = rx_addr;
  assign o_rx_rd_en = rx_rd_en;
  assign o_rx_wordsize = 3; // 3: 64bit, 2: 32bit, 1: 16bit, 0: 8bit


  assign reset_n = ~ i_areset;


  bram_dp2w #( .ADDR_WIDTH(8), .DATA_WIDTH(64) ) mem (
    .i_clk(i_clk),
    .i_en_a(ram_a_en),
    .i_en_b(ram_b_en),
    .i_we_a(ram_a_we),
    .i_we_b(ram_b_we),
    .i_addr_a(ram_a_addr),
    .i_addr_b(ram_b_addr),
    .i_data_a(ram_a_wdata),
    .i_data_b(ram_b_wdata),
    .o_data_a(ram_a_rdata),
    .o_data_b(ram_b_rdata)
  );

  aes_siv_core core(
    .clk(i_clk),
    .reset_n(reset_n),
    .encdec(core_config_encdec_reg),
    .key(core_key),
    .mode(core_config_mode_reg),
    .start(core_start_reg),
    .ad_start(core_ad_start),
    .ad_length(core_ad_length_reg),
    .nonce_start(core_nonce_start),
    .nonce_length(core_nonce_length),
    .pc_start(core_pc_start),
    .pc_length(core_pc_length),
    .cs(core_cs),
    .we(core_we),
    .ack(core_ack_reg),
    .addr(core_addr),
    .block_rd(core_block_rd),
    .block_wr(core_block_wr),
    .tag_in(core_tag_in),
    .tag_out(core_tag_out),
    .tag_ok(core_tag_ok),
    .ready(core_ready)
  );

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      core_ack_reg <= 0;
      core_ad_length_reg <= 0;
      core_config_encdec_reg <= 0;
      core_config_mode_reg <= 0;
      core_start_reg <= 0;
      core_tag_reg[0] <= 0;
      core_tag_reg[1] <= 0;
      key_c2s_reg <= 0;
      key_s2c_reg <= 0;
      state_reg <= 0;
      ramrx_addr_reg <= 0;
      rx_addr_next_reg <= 0;
      rx_tag_reg <= 0;
    end else begin
      core_ack_reg <= core_cs; // Memory always responds next cycle

      if (core_ad_length_we)
        core_ad_length_reg <= core_ad_length_new;

      if (core_config_we) begin
        core_config_encdec_reg <= core_config_encdec_new;
        core_config_mode_reg <= core_config_mode_new;
      end

      core_start_reg <= core_start_new;

      if (core_tag_we[0])
        core_tag_reg[0] <= core_tag_new;

      if (core_tag_we[1])
        core_tag_reg[1] <= core_tag_new;

      if (key_c2s_we)
        key_c2s_reg[key_c2s_addr*32+:32] <= key_c2s_new;

      if (key_s2c_we)
        key_s2c_reg[key_s2c_addr*32+:32] <= key_s2c_new;

      if (state_we)
        state_reg <= state_new;

      if (ramrx_addr_we)
        ramrx_addr_reg <= ramrx_addr_new;

      if (rx_addr_last_we)
        rx_addr_last_reg <= rx_addr_last_new;

      if (rx_addr_next_we)
        rx_addr_next_reg <= rx_addr_next_new;

      if (rx_tag_we)
        rx_tag_reg <= rx_tag_new;
    end
  end

  always @*
  begin : ram_mux
    ram_a_en = 0;
    ram_a_we = 0;
    ram_a_addr = 0;
    ram_a_wdata = 0;

    ram_b_en = 0;
    ram_b_we = 0;
    ram_b_addr = 0;
    ram_b_wdata = 0;
    case (state_reg)
      STATE_COPY_RX:
        begin
          ram_a_en = ramrx_en;
          ram_a_we = ramrx_we;
          ram_a_addr = ramrx_addr_reg;
          ram_a_wdata = ramrx_wdata;
        end
      default:
        begin
          ram_a_en = core_cs;
          ram_a_we = core_we;
          ram_a_addr = { core_addr[6:0], 1'b0 };
          ram_a_wdata = core_block_wr[127:64];
          ram_b_en = core_cs;
          ram_b_we = core_we;
          ram_b_addr = { core_addr[6:0], 1'b1 };
          ram_b_wdata = core_block_wr[63:0];
        end
    endcase
  end

  always @*
  begin : unwrapped_handler
    key_c2s_we = 0;
    key_c2s_addr = 0;
    key_c2s_new = 0;

    key_s2c_we = 0;
    key_s2c_addr = 0;
    key_s2c_new = 0;

    if (i_unrwapped_s2c) begin
      key_s2c_we = 1;
      key_s2c_addr = i_unwrapped_word;
      key_s2c_new = i_unwrapped_data;
    end
    if (i_unwrapped_c2s) begin
      key_c2s_we = 1;
      key_c2s_addr = i_unwrapped_word;
      key_c2s_new = i_unwrapped_data;
    end
  end

  always @*
  begin : rx_handler
    core_tag_we[0] = 0;
    core_tag_we[1] = 0;
    core_tag_new = 0;
    ramrx_en = 0;
    ramrx_we = 0;
    ramrx_addr_we = 0;
    ramrx_addr_new = 0;
    ramrx_wdata = 0;
    rx_addr = 0;
    rx_rd_en = 0;
    rx_addr_last_we = 0;
    rx_addr_last_new = 0;
    rx_addr_next_we = 0;
    rx_addr_next_new = 0;
    rx_tag_we = 0;
    rx_tag_new = 0;
    case (state_reg)
      STATE_IDLE:
        if (i_op_copy_rx_ad || i_op_copy_rx_nonce || i_op_copy_rx_tag) begin
          rx_addr_last_we = 1;
          rx_addr_last_new = i_copy_rx_addr + i_copy_rx_bytes;
          rx_addr_next_we = 1;
          rx_addr_next_new = i_copy_rx_addr;
        end
      STATE_COPY_RX_INIT_AD:
        if (i_rx_wait == 'b0) begin
          ramrx_addr_we = 1;
          ramrx_addr_new = MEM8_ADDR_AD;
          rx_addr = rx_addr_next_reg;
          rx_rd_en = 1;
          rx_addr_next_we = 1;
          rx_addr_next_new = rx_addr_next_reg + 8;
          $display("%s:%0d RX READ ADDR: %h", `__FILE__, `__LINE__, rx_addr);
        end
      STATE_COPY_RX_INIT_NONCE:
        if (i_rx_wait == 'b0) begin
          ramrx_addr_we = 1;
          ramrx_addr_new = MEM8_ADDR_NONCE;
          rx_addr = rx_addr_next_reg;
          rx_rd_en = 1;
          rx_addr_next_we = 1;
          rx_addr_next_new = rx_addr_next_reg + 8;
          $display("%s:%0d RX READ ADDR: %h ramrx_addr_new=%h", `__FILE__, `__LINE__, rx_addr, ramrx_addr_new);
        end
      STATE_COPY_RX_INIT_TAG:
        if (i_rx_wait == 'b0) begin
          rx_tag_we = 1;
          rx_tag_new = 0;
          rx_addr = rx_addr_next_reg;
          rx_rd_en = 1;
          rx_addr_next_we = 1;
          rx_addr_next_new = rx_addr_next_reg + 8;
        end
      STATE_COPY_RX:
        begin
          if (i_rx_wait == 'b0) begin
            if (i_rx_rd_dv) begin
              ramrx_en = 1;
              ramrx_we = 1;
              ramrx_addr_we = 1;
              ramrx_addr_new = ramrx_addr_reg + 1;
              ramrx_wdata = i_rx_rd_data;
              rx_addr = rx_addr_next_reg;
              rx_rd_en = 1;
              rx_addr_next_we = 1;
              rx_addr_next_new = rx_addr_next_reg + 8;
              $display("%s:%0d RX READ ADDR: %h", `__FILE__, `__LINE__, rx_addr);
            end
          end
        end

      STATE_COPY_RX_TAG:
        begin
          if (i_rx_wait == 'b0) begin
            if (i_rx_rd_dv) begin
              $display("%s:%0d RX: %h", `__FILE__, `__LINE__, i_rx_rd_data);
              core_tag_we[rx_tag_reg] = 1;
              core_tag_new = i_rx_rd_data;

              rx_tag_we = 1;
              rx_tag_new = rx_tag_reg + 1;
              rx_addr = rx_addr_next_reg;
              rx_rd_en = 1;
              rx_addr_next_we = 1;
              rx_addr_next_new = rx_addr_next_reg + 8;
              $display("%s:%0d RX READ ADDR: %h", `__FILE__, `__LINE__, rx_addr);
            end
          end
        end
      default: ;
    endcase
  end

  always @*
  begin : aes_siv_core_ctrl
    core_ad_length_we = 0;
    core_ad_length_new = 0;
    core_config_we = 0;
    core_config_encdec_new = AEAD_AES_SIV_CMAC_256;
    core_config_mode_new = MODE_DECRYPT;
    core_start_new = 0;

    case (state_reg)
      STATE_IDLE:
        begin
          if (i_op_copy_rx_ad) begin
            core_ad_length_we = 1;
            core_ad_length_new = { 10'b0, i_copy_rx_bytes };
          end
          if (i_op_verify) begin
            core_config_we = 1;
            core_config_encdec_new = AEAD_AES_SIV_CMAC_256;
            core_config_mode_new = MODE_DECRYPT;
            core_start_new = 1;
          end
        end
      default: ;
    endcase
  end

  always @*
  begin : fsm
    state_we = 0;
    state_new = 0;

    case (state_reg)
      STATE_IDLE:
        if (i_op_copy_rx_ad) begin
          state_we = 1;
          state_new = STATE_COPY_RX_INIT_AD;
        end else if (i_op_copy_rx_nonce) begin
          state_we = 1;
          state_new = STATE_COPY_RX_INIT_NONCE;
        end else if (i_op_copy_rx_tag) begin
          state_we = 1;
          state_new = STATE_COPY_RX_INIT_TAG;
        end else if (i_op_verify) begin
          state_we = 1;
          state_new = STATE_SIV_VERIFY_WAIT_0;
        end
      STATE_COPY_RX_INIT_AD:
        if (i_rx_wait == 'b0) begin
          state_we = 1;
          state_new = STATE_COPY_RX;
        end
      STATE_COPY_RX_INIT_NONCE:
        if (i_rx_wait == 'b0) begin
          state_we = 1;
          state_new = STATE_COPY_RX;
        end
      STATE_COPY_RX_INIT_TAG:
        if (i_rx_wait == 'b0) begin
          state_we = 1;
          state_new = STATE_COPY_RX_TAG;
        end
      STATE_COPY_RX:
        if (rx_rd_en && rx_addr >= rx_addr_last_reg) begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_COPY_RX_TAG:
        if (rx_rd_en && rx_addr >= rx_addr_last_reg) begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_SIV_VERIFY_WAIT_0:
        begin
          state_we = 1;
          state_new = STATE_SIV_VERIFY_WAIT_1;
        end
      STATE_SIV_VERIFY_WAIT_1:
        if (core_ready) begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      default: ;
    endcase
  end

endmodule
