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
  output wire                         o_error,

  output wire                         o_verify_tag_ok,

  input wire                  [2 : 0] i_key_word,
  input wire                          i_key_valid,
  input wire                 [31 : 0] i_key_data,

  input  wire                         i_unrwapped_s2c,
  input  wire                         i_unwrapped_c2s,
  input  wire                 [2 : 0] i_unwrapped_word,
  input  wire                [31 : 0] i_unwrapped_data,

  input  wire                         i_op_copy_rx_ad,
  input  wire                         i_op_copy_rx_nonce,
  input  wire                         i_op_copy_rx_pc,
  input  wire                         i_op_copy_rx_tag,
  input  wire      [ADDR_WIDTH+3-1:0] i_copy_rx_addr,
  input  wire      [ADDR_WIDTH+3-1:0] i_copy_rx_bytes,

  input  wire                         i_op_copy_tx_ad,
  input  wire                         i_op_store_tx_nonce_tag,
  input  wire                         i_op_store_tx_cookie,
  input  wire                         i_op_store_tx_cookiebuf,
  input  wire      [ADDR_WIDTH+3-1:0] i_copy_tx_addr,
  input  wire      [ADDR_WIDTH+3-1:0] i_copy_tx_bytes,

  input  wire                         i_op_cookie_verify,
  input  wire                         i_op_cookie_loadkeys,
  input  wire                         i_op_cookie_rencrypt,

  input  wire                         i_op_cookiebuf_reset,
  input  wire                         i_op_cookiebuf_appendcookie,

  input  wire                         i_op_verify_c2s,
  input  wire                         i_op_generate_tag,

  input  wire                         i_rx_wait,
  output wire      [ADDR_WIDTH+3-1:0] o_rx_addr,
  output wire                   [2:0] o_rx_wordsize,
  output wire                         o_rx_rd_en,
  input  wire                         i_rx_rd_dv,
  input  wire     [RX_PORT_WIDTH-1:0] i_rx_rd_data,

  input  wire                         i_tx_busy,
  output wire                         o_tx_read_en,
  input  wire                  [63:0] i_tx_read_data,
  output wire                         o_tx_write_en,
  output wire                  [63:0] o_tx_write_data,
  output wire      [ADDR_WIDTH+3-1:0] o_tx_address,

  input wire                   [63:0] i_cookie_prefix,

  output wire                         o_noncegen_get,
  input  wire                [63 : 0] i_noncegen_nonce,
  input  wire                         i_noncegen_ready

);

  //----------------------------------------------------------------
  // Local parameters
  //----------------------------------------------------------------

  localparam BITS_STATE = 5;
  localparam [BITS_STATE-1:0] STATE_IDLE                 =  0;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_INIT_PC      =  1;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_INIT_NONCE   =  2;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_INIT_AD      =  3;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_INIT_TAG     =  4;
  localparam [BITS_STATE-1:0] STATE_COPY_RX              =  5;
  localparam [BITS_STATE-1:0] STATE_COPY_RX_TAG          =  6;
  localparam [BITS_STATE-1:0] STATE_SIV_VERIFY_WAIT_0    =  7;
  localparam [BITS_STATE-1:0] STATE_SIV_VERIFY_WAIT_1    =  8;
  localparam [BITS_STATE-1:0] STATE_COPY_TX_INIT_AD      =  9;
  localparam [BITS_STATE-1:0] STATE_COPY_TX              = 10;
  localparam [BITS_STATE-1:0] STATE_AUTH_MEMSTORE_NONCE  = 11;
  localparam [BITS_STATE-1:0] STATE_SIV_AUTH_WAIT_0      = 12;
  localparam [BITS_STATE-1:0] STATE_SIV_AUTH_WAIT_1      = 13;
  localparam [BITS_STATE-1:0] STATE_STORE_TX_AUTH_INIT   = 14;
  localparam [BITS_STATE-1:0] STATE_STORE_TX_AUTH        = 15;
  localparam [BITS_STATE-1:0] STATE_STORE_TX_COOKIE_INIT = 16;
  localparam [BITS_STATE-1:0] STATE_STORE_TX_COOKIE      = 17;
  localparam [BITS_STATE-1:0] STATE_LOAD_KEYS_FROM_MEM   = 18;
  localparam [BITS_STATE-1:0] STATE_STORE_COOKIEBUF      = 19;
  localparam [BITS_STATE-1:0] STATE_STORE_TX_CB_INIT     = 20;
  localparam [BITS_STATE-1:0] STATE_STORE_TX_CB          = 21;
  localparam [BITS_STATE-1:0] STATE_ERROR                = 31;

  localparam BRAM_WIDTH = 10;
  localparam [15:BRAM_WIDTH-1] CORE_ADDR_MSB_ZERO=0;
  localparam [19:BRAM_WIDTH+3] CORE_LENGTH_MSB_ZERO=0; // {MSB, length64, LSB}, LSB=3'b000

  /* MEM8 addresses must be lsb=0 */
  localparam [BRAM_WIDTH-1:0] MEM8_ADDR_NONCE   =   0;
  localparam [BRAM_WIDTH-1:0] MEM8_ADDR_PC      = 256;
  localparam [BRAM_WIDTH-1:0] MEM8_ADDR_AD      = 512;
  localparam [BRAM_WIDTH-1:0] MEM8_ADDR_COOKIES = 768;

  localparam MODE_DECRYPT = 0;
  localparam MODE_ENCRYPT = 1;

  localparam [1:0] MUX_CIPHERTEXT_NONE         = 2'b00;
  localparam [1:0] MUX_CIPHERTEXT_PC512        = 2'b01;
  localparam [1:0] MUX_CIPHERTEXT_PC_COOKIEBUF = 2'b10;

  localparam [5:0] MUX_RAM_CORE   = 6'b000001;
  localparam [5:0] MUX_RAM_RX     = 6'b000010;
  localparam [5:0] MUX_RAM_TX     = 6'b000100;
  localparam [5:0] MUX_RAM_NONCE  = 6'b001000;
  localparam [5:0] MUX_RAM_LOAD   = 6'b010000;
  localparam [5:0] MUX_RAM_COOKIE = 6'b100000;

  localparam AEAD_AES_SIV_CMAC_256 = 1'h0;

  //----------------------------------------------------------------
  // Registers - Finite State Machine
  //----------------------------------------------------------------

  reg                  state_we;
  reg [BITS_STATE-1:0] state_new;
  reg [BITS_STATE-1:0] state_reg;

  //----------------------------------------------------------------
  // Registers - AES-SIV core and key
  //----------------------------------------------------------------

  reg          key_current_we;
  reg  [255:0] key_current_new;
  reg  [255:0] key_current_reg;

  reg          key_master_we;
  reg    [2:0] key_master_addr;
  reg   [31:0] key_master_new;
  reg  [255:0] key_master_reg;

  reg          key_c2s_we;
  reg    [2:0] key_c2s_addr;
  reg   [31:0] key_c2s_new;
  reg  [255:0] key_c2s_reg;

  reg          key_s2c_we;
  reg    [2:0] key_s2c_addr;
  reg   [31:0] key_s2c_new;
  reg  [255:0] key_s2c_reg;

  reg          load_c2s_we;
  reg          load_s2c_we;
  reg    [0:0] load_addr;
  reg  [127:0] load_new;            //128bit interface for reloading key_c2s, key_s2c

  reg          core_tag_we   [0:1];
  reg   [63:0] core_tag_new;
  reg   [63:0] core_tag_reg  [0:1];

  reg          core_ack_reg; //core_ack_new == core_cs

  reg          core_start_reg;
  reg          core_start_new;

  reg          core_config_encdec_reg;
  reg          core_config_encdec_new;
  reg          core_config_we;

  reg [19 : 0] core_ad_length_reg;
  reg [19 : 0] core_ad_length_new;
  reg          core_ad_length_we;

  reg    [1:0] core_pc_mux_reg;
  reg    [1:0] core_pc_mux_new;
  reg    [0:0] core_pc_mux_we;

  //----------------------------------------------------------------
  // Registers - RX buffer access related
  //----------------------------------------------------------------

  reg                    ramrx_addr_we;
  reg   [BRAM_WIDTH-1:0] ramrx_addr_new;
  reg   [BRAM_WIDTH-1:0] ramrx_addr_reg; //Memory address in internal mem.

  reg                    rx_addr_last_we;
  reg [ADDR_WIDTH+3-1:0] rx_addr_last_new;
  reg [ADDR_WIDTH+3-1:0] rx_addr_last_reg; //Memory address in RX buffer.

  reg                    rx_addr_next_we;
  reg [ADDR_WIDTH+3-1:0] rx_addr_next_new;
  reg [ADDR_WIDTH+3-1:0] rx_addr_next_reg; //Memory address in RX buffer.

  reg                    rx_tag_we;
  reg                    rx_tag_new;
  reg                    rx_tag_reg; //0: reading tag msb from RX, 0 reading tag lsb from RX.

  //----------------------------------------------------------------
  // Registers - TX buffer access related
  //----------------------------------------------------------------

  reg                    ramtx_addr_we;
  reg   [BRAM_WIDTH-1:0] ramtx_addr_new;
  reg   [BRAM_WIDTH-1:0] ramtx_addr_reg; //Memory address in internal mem.

  reg                    tx_addr_last_we;
  reg [ADDR_WIDTH+3-1:0] tx_addr_last_new;
  reg [ADDR_WIDTH+3-1:0] tx_addr_last_reg; //Memory address in RX buffer.

  reg                    tx_addr_next_we;
  reg [ADDR_WIDTH+3-1:0] tx_addr_next_new;
  reg [ADDR_WIDTH+3-1:0] tx_addr_next_reg; //Memory address in RX buffer.

  reg                    tx_ctr_we;
  reg   [BRAM_WIDTH-1:0] tx_ctr_new;
  reg   [BRAM_WIDTH-1:0] tx_ctr_reg;

  //----------------------------------------------------------------
  // Registers - Self references. Load C2S, S2C from RAM
  //----------------------------------------------------------------

  reg                    ramld_addr_we;
  reg   [BRAM_WIDTH-1:0] ramld_addr_new;
  reg   [BRAM_WIDTH-1:0] ramld_addr_reg; //Memory address in internal mem.

  //----------------------------------------------------------------
  // Registers - Cookie buffer related
  //----------------------------------------------------------------

  reg       cookie_ctr_we;
  reg [3:0] cookie_ctr_new;
  reg [3:0] cookie_ctr_reg;

  reg        cookie_prefix_we;
  reg [63:0] cookie_prefix_new;
  reg [63:0] cookie_prefix_reg;

  reg                  ramcookie_addr_load_we;
  reg [BRAM_WIDTH-1:0] ramcookie_addr_load_new;
  reg [BRAM_WIDTH-1:0] ramcookie_addr_load_reg;

  reg                  ramcookie_addr_write_we;
  reg [BRAM_WIDTH-1:0] ramcookie_addr_write_new;
  reg [BRAM_WIDTH-1:0] ramcookie_addr_write_reg;

  reg                  cookiebuffer_length_we;
  reg [BRAM_WIDTH-1:0] cookiebuffer_length_new;
  reg [BRAM_WIDTH-1:0] cookiebuffer_length_reg;

  //----------------------------------------------------------------
  // Registers - Misc.
  //----------------------------------------------------------------

  reg verify_tag_ok_we;
  reg verify_tag_ok_new;
  reg verify_tag_ok_reg;

  //----------------------------------------------------------------
  // Wires - AES-SIV
  //----------------------------------------------------------------

  wire [511 : 0] core_key;

  wire           core_config_mode;

  wire  [15 : 0] core_ad_start;
  reg   [15 : 0] core_pc_start;
  wire  [15 : 0] core_nonce_start;

  wire  [19 : 0] core_nonce_length;
  reg   [19 : 0] core_pc_length;

  wire           core_cs;       // Core RAM wires (mux input)
  wire           core_we;       // Core RAM wires (mux input)
  wire  [15 : 0] core_addr;     // Core RAM wires (mux input)
  wire [127 : 0] core_block_rd;
  wire [127 : 0] core_block_wr; // Core RAM wires (mux input)

  wire [127 : 0] core_tag_in;
  wire [127 : 0] core_tag_out;
  wire           core_tag_ok;
  wire           core_ready;

  //----------------------------------------------------------------
  // Wires - Cookie buffer related
  //----------------------------------------------------------------

  reg        ramcookie_ld;
  reg        ramcookie_wr;
  reg [63:0] ramcookie_wdata;

  //----------------------------------------------------------------
  // Wires - RX-Buff related
  //----------------------------------------------------------------

  reg [ADDR_WIDTH+3-1:0] rx_addr;  //Address out
  reg                    rx_rd_en; //Read enable out

  reg [ADDR_WIDTH+3-1:0] rx_addr_reg;  //Address out
  reg                    rx_rd_en_reg; //Read enable out

  //----------------------------------------------------------------
  // Wires - TX-Buff related
  //----------------------------------------------------------------

  reg [ADDR_WIDTH+3-1:0] tx_addr;  //Address out
  reg                    tx_rd_en; //Read enable out
  reg                    tx_wr_en; //Write enable out
  reg           [63 : 0] tx_wr_data; //Write data out

  //----------------------------------------------------------------
  // Wires - RAM related
  //----------------------------------------------------------------

  reg          ramld_en;    // Load unwrapped key from RAM wire (mux input)

  reg          ramrx_en;    // RX access logic RAM wires (mux input)
  reg          ramrx_we;    // RX access logic RAM wires (mux input)
  reg   [63:0] ramrx_wdata; // RX access logic RAM wires (mux input)

  reg          ramtx_en;    // TX access logic RAM wires (mux input)
  reg          ramtx_we;    // TX access logic RAM wires (mux input)
  reg   [63:0] ramtx_wdata; // TX access logic RAM wires (mux input)

  reg          ramnc_en;    // Nonce copy RAM wires (mux input)
  reg          ramnc_we;    // Nonce copy RAM wires (mux input)
  reg  [127:0] ramnc_wdata; // Nonce copy RAM wires (mux input)

  reg                    ram_a_en;    // Memory port A
  reg                    ram_a_we;
  reg   [BRAM_WIDTH-1:0] ram_a_addr;
  reg             [63:0] ram_a_wdata;
  wire            [63:0] ram_a_rdata;

  reg                    ram_b_en;    // Memory port B
  reg                    ram_b_we;
  reg   [BRAM_WIDTH-1:0] ram_b_addr;
  reg             [63:0] ram_b_wdata;
  wire            [63:0] ram_b_rdata;

  //----------------------------------------------------------------
  // Wires - Nonce generation
  //----------------------------------------------------------------

  reg         nonce_generate_we;  // Hey Mr RNG,
  reg         nonce_generate_new; // please give me some 64
  reg         nonce_generate_reg; // bits of randomness.

  reg  [63:0] nonce_new;          // New nonce

  reg         nonce_invalidate;   // Invalidate nonce regs

  reg         nonce_a_we;          // First 64bit nonce
  reg  [63:0] nonce_a_reg;
  reg         nonce_a_valid_reg;

  reg         nonce_b_we;          // Second 64bit nonce
  reg  [63:0] nonce_b_reg;
  reg         nonce_b_valid_reg;

  //----------------------------------------------------------------
  // Wires - Misc.
  //----------------------------------------------------------------

  wire         reset_n;

  //----------------------------------------------------------------
  // Wire and output assignments
  //----------------------------------------------------------------

  assign core_key = { key_current_reg[255:128], 128'h0, key_current_reg[127:0], 128'h0 }; // TODO update when adding s2c support


  assign core_ad_start = { CORE_ADDR_MSB_ZERO, MEM8_ADDR_AD[BRAM_WIDTH-1:1] };

  assign core_block_rd = { ram_a_rdata, ram_b_rdata };

  assign core_config_mode = AEAD_AES_SIV_CMAC_256;

  assign core_nonce_start = { CORE_ADDR_MSB_ZERO, MEM8_ADDR_NONCE[BRAM_WIDTH-1:1] };
  assign core_nonce_length = 16;

  assign core_tag_in = { core_tag_reg[0], core_tag_reg[1] };

  assign o_busy = (state_reg != STATE_IDLE) || (nonce_a_valid_reg==1'b0) || (nonce_b_valid_reg==1'b0);

  assign o_error = (state_reg == STATE_ERROR) || (core_addr[15:BRAM_WIDTH-1] != 0);

  assign o_noncegen_get = nonce_generate_reg;

  assign o_rx_addr = rx_addr_reg;
  assign o_rx_rd_en = rx_rd_en_reg;
  assign o_rx_wordsize = 3; // 3: 64bit, 2: 32bit, 1: 16bit, 0: 8bit

  assign o_tx_read_en = tx_rd_en;
  assign o_tx_write_en = tx_wr_en;
  assign o_tx_write_data = tx_wr_data;
  assign o_tx_address = tx_addr;

  assign o_verify_tag_ok = verify_tag_ok_reg;

  assign reset_n = ~ i_areset;

  //----------------------------------------------------------------
  // RAM 64bit with Dual Read/Write ports.
  // Used as 64bit Write when talking to RX buffer.
  // Used as 128bit Read/Write when talking to AES-SIV core.
  //----------------------------------------------------------------

  bram_dp2w #( .ADDR_WIDTH( BRAM_WIDTH ), .DATA_WIDTH(64) ) mem (
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

  //----------------------------------------------------------------
  // AES-SIV Core control mux
  //----------------------------------------------------------------

  always @*
  begin : ciphertext_ctrl_mux
    core_pc_start = 0;
    core_pc_length = 0;
    case (core_pc_mux_reg)
      MUX_CIPHERTEXT_NONE: //No Ciphertext
        begin
          core_pc_start = { CORE_ADDR_MSB_ZERO, MEM8_ADDR_PC[BRAM_WIDTH-1:1] }; //unused.
          core_pc_length = 0;
        end
      MUX_CIPHERTEXT_PC512: //64 bytes of ciphertext. 512 = 2x256 C2S, S2C, 128+128bits keys */
        begin
          core_pc_start = { CORE_ADDR_MSB_ZERO, MEM8_ADDR_PC[BRAM_WIDTH-1:1] };
          core_pc_length = 64;
        end
      MUX_CIPHERTEXT_PC_COOKIEBUF:
        begin
          core_pc_start = { CORE_ADDR_MSB_ZERO, MEM8_ADDR_COOKIES[BRAM_WIDTH-1:1] };
          core_pc_length = { CORE_LENGTH_MSB_ZERO, cookiebuffer_length_reg, 3'b000 };
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // AES-SIV Core
  //----------------------------------------------------------------

  aes_siv_core core(
    .clk(i_clk),
    .reset_n(reset_n),
    .encdec(core_config_encdec_reg),
    .key(core_key),
    .mode(core_config_mode),
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


  //----------------------------------------------------------------
  // Register update
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      cookie_ctr_reg <= 0;
      cookie_prefix_reg <= 0;
      cookiebuffer_length_reg <= 0;
      core_ack_reg <= 0;
      core_ad_length_reg <= 0;
      core_config_encdec_reg <= 0;
      core_pc_mux_reg <= MUX_CIPHERTEXT_NONE;
      core_start_reg <= 0;
      core_tag_reg[0] <= 0;
      core_tag_reg[1] <= 0;
      key_current_reg <= 0;
      key_master_reg <= 0;
      key_c2s_reg <= 0;
      key_s2c_reg <= 0;
      nonce_a_reg <= 0;
      nonce_a_valid_reg <= 0;
      nonce_b_reg <= 0;
      nonce_b_valid_reg <= 0;
      nonce_generate_reg <= 0;
      ramld_addr_reg <= 0;
      ramrx_addr_reg <= 0;
      ramtx_addr_reg <= 0;
      ramcookie_addr_load_reg <= MEM8_ADDR_NONCE;
      ramcookie_addr_write_reg <= MEM8_ADDR_COOKIES;
      rx_addr_reg <= 0;
      rx_rd_en_reg <= 0;
      rx_addr_last_reg <= 0;
      rx_addr_next_reg <= 0;
      rx_tag_reg <= 0;
      state_reg <= 0;
      tx_addr_last_reg <= 0;
      tx_addr_next_reg <= 0;
      tx_ctr_reg <= 0;
      verify_tag_ok_reg <= 0;
    end else begin
      if (cookie_ctr_we)
        cookie_ctr_reg <= cookie_ctr_new;

      if (cookie_prefix_we)
        cookie_prefix_reg <= cookie_prefix_new;

      if (cookiebuffer_length_we)
        cookiebuffer_length_reg <= cookiebuffer_length_new;

      core_ack_reg <= core_cs; // Memory always responds next cycle

      if (core_ad_length_we)
        core_ad_length_reg <= core_ad_length_new;

      if (core_config_we) begin
        core_config_encdec_reg <= core_config_encdec_new;
      end

      core_start_reg <= core_start_new;

      if (core_pc_mux_we)
       core_pc_mux_reg <= core_pc_mux_new;

      if (core_tag_we[0])
        core_tag_reg[0] <= core_tag_new;

      if (core_tag_we[1])
        core_tag_reg[1] <= core_tag_new;

      if (key_current_we)
        key_current_reg <= key_current_new;

      if (key_master_we)
        key_master_reg[key_master_addr*32+:32] <= key_master_new;

      if (key_c2s_we)
        key_c2s_reg[key_c2s_addr*32+:32] <= key_c2s_new;
      else if (load_c2s_we)
        key_c2s_reg[load_addr*128+:128] <= load_new;

      if (key_s2c_we)
        key_s2c_reg[key_s2c_addr*32+:32] <= key_s2c_new;
      else if (load_s2c_we)
        key_s2c_reg[load_addr*128+:128] <= load_new;

      if (nonce_a_we) begin
        nonce_a_reg <= nonce_new;
        nonce_a_valid_reg <= ~ nonce_invalidate;
      end

      if (nonce_b_we) begin
        nonce_b_reg <= nonce_new;
        nonce_b_valid_reg <= ~ nonce_invalidate;
      end

      if (nonce_generate_we)
        nonce_generate_reg <= nonce_generate_new;

      if (ramcookie_addr_load_we)
        ramcookie_addr_load_reg <= ramcookie_addr_load_new;

      if (ramcookie_addr_write_we)
        ramcookie_addr_write_reg <= ramcookie_addr_write_new;

      if (ramld_addr_we)
        ramld_addr_reg <= ramld_addr_new;

      if (ramrx_addr_we)
        ramrx_addr_reg <= ramrx_addr_new;

      if (ramtx_addr_we)
        ramtx_addr_reg <= ramtx_addr_new;

      if (rx_addr_last_we)
        rx_addr_last_reg <= rx_addr_last_new;

      if (rx_addr_next_we)
        rx_addr_next_reg <= rx_addr_next_new;

      if (rx_tag_we)
        rx_tag_reg <= rx_tag_new;

      rx_addr_reg <= rx_addr;
      rx_rd_en_reg <= rx_rd_en;

      if (state_we)
        state_reg <= state_new;

      if (tx_addr_last_we)
        tx_addr_last_reg <= tx_addr_last_new;

      if (tx_addr_next_we)
        tx_addr_next_reg <= tx_addr_next_new;

      if (tx_ctr_we)
        tx_ctr_reg <= tx_ctr_new;

      if (verify_tag_ok_we)
        verify_tag_ok_reg <= verify_tag_ok_new;
    end
  end

  //----------------------------------------------------------------
  // Status output regs
  //----------------------------------------------------------------

  always @*
  begin
    verify_tag_ok_we = 0;
    verify_tag_ok_new = 0;
    case (state_reg)
      STATE_IDLE:
        if (i_op_verify_c2s || i_op_cookie_verify) begin
          verify_tag_ok_we = 1;
          verify_tag_ok_new = 0;
        end
      STATE_SIV_VERIFY_WAIT_1:
        if (core_ready) begin
          verify_tag_ok_we = 1;
          verify_tag_ok_new = core_tag_ok;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // RAM MUX
  // Select Control: State_reg (finite state machine)
  // Input: RAM-RX (RX buffer handling logic). 64bit.
  // Input: AES-SIV Core. 128bit.
  //----------------------------------------------------------------

  always @*
  begin : ram_mux
    reg [5:0] mux;

    mux = MUX_RAM_CORE;

    ram_a_en = 0;
    ram_a_we = 0;
    ram_a_addr = 0;
    ram_a_wdata = 0;

    ram_b_en = 0;
    ram_b_we = 0;
    ram_b_addr = 0;
    ram_b_wdata = 0;

    case (state_reg)
      STATE_COPY_RX:             mux = MUX_RAM_RX;
      STATE_AUTH_MEMSTORE_NONCE: mux = MUX_RAM_NONCE;
      STATE_COPY_TX:             mux = MUX_RAM_TX;
      STATE_STORE_TX_AUTH_INIT:  mux = MUX_RAM_TX;
      STATE_STORE_TX_AUTH:       mux = MUX_RAM_TX;
      STATE_STORE_TX_COOKIE:     mux = MUX_RAM_TX;
      STATE_STORE_TX_CB_INIT:    mux = MUX_RAM_TX;
      STATE_STORE_TX_CB:         mux = MUX_RAM_TX;
      STATE_LOAD_KEYS_FROM_MEM:  mux = MUX_RAM_LOAD;
      STATE_STORE_COOKIEBUF:     mux = MUX_RAM_COOKIE;
      default: ;
    endcase

    case (mux)
      default: //MUX_RAM_CORE
        begin
          ram_a_en = core_cs;
          ram_a_we = core_we;
          ram_a_addr = { core_addr[BRAM_WIDTH-2:0], 1'b0 }; //1'b0: 64bit MSB
          ram_a_wdata = core_block_wr[127:64];
          ram_b_en = core_cs;
          ram_b_we = core_we;
          ram_b_addr = { core_addr[BRAM_WIDTH-2:0], 1'b1 }; //1'b1: 64bit LSB
          ram_b_wdata = core_block_wr[63:0];
        end
      MUX_RAM_NONCE:
        begin
          ram_a_en = ramnc_en;
          ram_a_we = ramnc_we;
          ram_a_addr = MEM8_ADDR_NONCE;
          ram_a_wdata = ramnc_wdata[127:64];
          ram_b_en = ramnc_en;
          ram_b_we = ramnc_we;
          ram_b_addr = MEM8_ADDR_NONCE + 1;
          ram_b_wdata = ramnc_wdata[63:0];
        end
      MUX_RAM_RX:
        begin
          ram_a_en = ramrx_en;
          ram_a_we = ramrx_we;
          ram_a_addr = ramrx_addr_reg;
          ram_a_wdata = ramrx_wdata;
        end
      MUX_RAM_TX:
        begin
          ram_a_en = ramtx_en;
          ram_a_we = ramtx_we;
          ram_a_addr = ramtx_addr_reg;
          ram_a_wdata = ramtx_wdata;
        end
      MUX_RAM_LOAD:
        begin
          ram_a_en = ramld_en;
          ram_a_we = 0;
          ram_a_addr = ramld_addr_reg;
          ram_a_wdata = 0;
          ram_b_en = ramld_en;
          ram_b_we = 0;
          ram_b_addr = ramld_addr_reg + 1;
          ram_b_wdata = 0;
        end
      MUX_RAM_COOKIE:
        begin
          ram_a_en = ramcookie_ld;
          ram_a_we = 0;
          ram_a_addr = ramcookie_addr_load_reg;
          ram_b_en = ramcookie_wr;
          ram_b_we = 1;
          ram_b_addr = ramcookie_addr_write_reg;
          ram_b_wdata = ramcookie_wdata;
        end
    endcase
  end

  //----------------------------------------------------------------
  // Master key handler
  // Receives server keys from keymem (server keys)
  //----------------------------------------------------------------

  always @*
  begin : master_key_receiver
    key_master_we = 0;
    key_master_addr = 0;
    key_master_new = 0;
    if (state_reg == STATE_IDLE) begin
      if (i_key_valid) begin
        key_master_we = 1;
        key_master_new = i_key_data;
        key_master_addr = i_key_word[2:0];
      end
    end
  end

  //----------------------------------------------------------------
  // Load C2S, S2C keys from RAM
  //----------------------------------------------------------------

  always @*
  begin : load_keys_from_ram
    load_addr = 0;
    load_new = { ram_a_rdata, ram_b_rdata };
    load_c2s_we = 0;
    load_s2c_we = 0;
    ramld_en = 0;
    ramld_addr_we = 0;
    ramld_addr_new = 0;
    case (state_reg)
      STATE_IDLE:
        if (i_op_cookie_loadkeys) begin
          ramld_addr_we = 1;
          ramld_addr_new = MEM8_ADDR_PC;
        end
      STATE_LOAD_KEYS_FROM_MEM:
        begin
          ramld_addr_we = 1;
          ramld_addr_new = ramld_addr_reg + 2;
          case (ramld_addr_reg)
            MEM8_ADDR_PC + 0:
              begin
                ramld_en = 1;
              end
            MEM8_ADDR_PC + 2:
              begin
                load_addr = 1; // msb
                load_c2s_we = 1;
                ramld_en = 1;
              end
            MEM8_ADDR_PC + 4:
              begin
                load_addr = 0; // lsb
                load_c2s_we = 1;
                ramld_en = 1;
              end
            MEM8_ADDR_PC + 6:
              begin
                load_addr = 1; // msb
                load_s2c_we = 1;
                ramld_en = 1;
              end
            MEM8_ADDR_PC + 8:
              begin
                load_addr = 0; // lsb
                load_s2c_we = 1;
              end
            default: ;
          endcase
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Unwrapped handler
  // Receives keys from Cookie Handler unwrapping of cookies.
  //----------------------------------------------------------------

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

  //----------------------------------------------------------------
  // RX Handler
  // Communicates with RX buffer.
  // Sets RAMRX access for storing AD, nonce to local memory.
  // Sets CORE_TAG for storing TAG to register.
  //----------------------------------------------------------------

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
        if (i_op_copy_rx_pc || i_op_copy_rx_ad || i_op_copy_rx_nonce || i_op_copy_rx_tag) begin
          rx_addr_last_we = 1;
          rx_addr_last_new = i_copy_rx_addr + i_copy_rx_bytes;
          rx_addr_next_we = 1;
          rx_addr_next_new = i_copy_rx_addr;
        end
      STATE_COPY_RX_INIT_PC:
        if (i_rx_wait == 'b0) begin
          ramrx_addr_we = 1;
          ramrx_addr_new = MEM8_ADDR_PC;
          rx_addr = rx_addr_next_reg;
          rx_rd_en = 1;
          rx_addr_next_we = 1;
          rx_addr_next_new = rx_addr_next_reg + 8;
        end
      STATE_COPY_RX_INIT_AD:
        if (i_rx_wait == 'b0) begin
          ramrx_addr_we = 1;
          ramrx_addr_new = MEM8_ADDR_AD;
          rx_addr = rx_addr_next_reg;
          rx_rd_en = 1;
          rx_addr_next_we = 1;
          rx_addr_next_new = rx_addr_next_reg + 8;
        end
      STATE_COPY_RX_INIT_NONCE:
        if (i_rx_wait == 'b0) begin
          ramrx_addr_we = 1;
          ramrx_addr_new = MEM8_ADDR_NONCE;
          rx_addr = rx_addr_next_reg;
          rx_rd_en = 1;
          rx_addr_next_we = 1;
          rx_addr_next_new = rx_addr_next_reg + 8;
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
            end
          end
        end
      STATE_COPY_RX_TAG:
        begin
          if (i_rx_wait == 'b0) begin
            if (i_rx_rd_dv) begin
              core_tag_we[rx_tag_reg] = 1;
              core_tag_new = i_rx_rd_data;
              rx_tag_we = 1;
              rx_tag_new = rx_tag_reg + 1;
              rx_addr = rx_addr_next_reg;
              rx_rd_en = 1;
              rx_addr_next_we = 1;
              rx_addr_next_new = rx_addr_next_reg + 8;
            end
          end
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // TX Handler Helper tasks
  // Tasks for:
  //  * Communicateing with TX buffer.
  //  * Sets RAMTX access
  // Without these it is a bit too much repetitivive code in TX
  // handler.
  //----------------------------------------------------------------

  task tx_load_ram_and_emit (
    input        ramload,
    input [63:0] data_out
  );
  begin
    ramtx_en = ramload;
    ramtx_we = 0;
    tx_wr_en = 1;
    tx_wr_data = data_out;
  end
  endtask

  //----------------------------------------------------------------
  // TX Handler
  // Communicates with TX buffer.
  // Sets RAMTX access for storing AD, nonce to local memory.
  //----------------------------------------------------------------

  always @*
  begin : tx_handler
    ramtx_en = 0;
    ramtx_we = 0;
    ramtx_addr_we = 0;
    ramtx_addr_new = 0;
    ramtx_wdata = 0;
    tx_ctr_we = 0;
    tx_ctr_new = 0;
    tx_wr_en = 0;
    tx_wr_data = 0;
    tx_rd_en = 0;
    tx_addr = 0;
    tx_addr_last_we = 0;
    tx_addr_last_new = 0;
    tx_addr_next_we = 0;
    tx_addr_next_new = 0;
    case (state_reg)
      STATE_IDLE:
        if (i_op_copy_tx_ad) begin
          tx_addr_last_we = 1;
          tx_addr_last_new = i_copy_tx_addr + i_copy_tx_bytes;
          tx_addr_next_we = 1;
          tx_addr_next_new = i_copy_tx_addr;
          //$display("%s:%0d ****** tx_addr_last_new: %h i_copy_tx_addr: %h i_copy_tx_bytes: %h", `__FILE__, `__LINE__, tx_addr_last_new, i_copy_tx_addr, i_copy_tx_bytes);
        end
        else if (i_op_store_tx_nonce_tag) begin
          tx_addr_last_we = 1;
          tx_addr_last_new = i_copy_tx_addr + 'h20; //Nonce,Tag
          tx_addr_next_we = 1;
          tx_addr_next_new = i_copy_tx_addr;
          ramtx_addr_we = 1;
          ramtx_addr_new = MEM8_ADDR_NONCE;
        end
        else if (i_op_store_tx_cookie) begin
          tx_addr_last_we = 1;
          tx_addr_last_new = i_copy_tx_addr + 'h60; //Nonce,Tag,C2S,S2C
          tx_addr_next_we = 1;
          tx_addr_next_new = i_copy_tx_addr;
          tx_ctr_we = 1;
          tx_ctr_new = 0;
          ramtx_addr_we = 1;
          ramtx_addr_new = MEM8_ADDR_NONCE;
        end
        else if (i_op_store_tx_cookiebuf) begin
          tx_addr_next_we = 1;
          tx_addr_next_new = i_copy_tx_addr;
          tx_ctr_we = 1;
          tx_ctr_new = 0;
          ramtx_addr_we = 1;
          ramtx_addr_new = MEM8_ADDR_COOKIES;
        end
      STATE_COPY_TX_INIT_AD:
        begin
          ramtx_addr_we = 1;
          ramtx_addr_new = MEM8_ADDR_AD;
          tx_rd_en = 1;
          tx_addr = tx_addr_next_reg;
          tx_addr_next_we = 1;
          tx_addr_next_new = tx_addr_next_reg + 8;
        end
      STATE_COPY_TX:
        begin
          ramtx_en = 1;
          ramtx_we = 1;
          ramtx_addr_we = 1;
          ramtx_addr_new = ramtx_addr_reg + 1;
          ramtx_wdata = i_tx_read_data;
          tx_rd_en = 1;
          tx_addr = tx_addr_next_reg;
          tx_addr_next_we = 1;
          tx_addr_next_new = tx_addr_next_reg + 8;
          //$display("%s:%0d ****** tx_addr: %h tx_addr_last_reg: %h i_tx_read_data: %h", `__FILE__, `__LINE__, tx_addr, tx_addr_last_reg, i_tx_read_data);
        end
      STATE_STORE_TX_AUTH_INIT:
        begin
          ramtx_en = 1; //Load MEM8_ADDR_NONCE
          ramtx_we = 0;
          ramtx_addr_we = 1;
          ramtx_addr_new = ramtx_addr_reg + 1; //Next address: MEM8_ADDR_NONCE + 1
          tx_ctr_we = 1;
          tx_ctr_new = 0;
        end
      STATE_STORE_TX_AUTH:
        begin
          ramtx_addr_we = 1;
          ramtx_addr_new = ramtx_addr_reg + 1;
          tx_ctr_we = 1;
          tx_ctr_new = tx_ctr_reg + 1;
          tx_addr = tx_addr_next_reg;
          tx_addr_next_we = 1;
          tx_addr_next_new = tx_addr_next_reg + 8;
          case (ramtx_addr_reg)
            1:
              begin
                ramtx_en = 1; //Load MEM8_ADDR_NONCE + 1
                ramtx_we = 0;
                tx_wr_en = 1;
                tx_wr_data = ram_a_rdata; //Nonce MSB from previous cycle
              end
            2:
              begin
                tx_wr_en = 1;
                tx_wr_data = ram_a_rdata; //Nonce LSB from previous cycle
              end
            3:
              begin
                tx_wr_en = 1;
                tx_wr_data = core_tag_out[127:64];
              end
            4:
              begin
                tx_wr_en = 1;
                tx_wr_data = core_tag_out[63:0];
              end
            default: ;
          endcase
        end
      STATE_STORE_TX_COOKIE:
        begin
          ramtx_addr_we = 1;
          ramtx_addr_new = ramtx_addr_reg + 1; //MEM8_ADDR_NONCE, +1, ... then MEM8_ADDR_PC, +1, +2, ...
          tx_addr = tx_addr_next_reg;
          tx_addr_next_we = 1;
          tx_addr_next_new = tx_addr_next_reg + 8;
          tx_ctr_we = 1;
          tx_ctr_new = tx_ctr_reg + 1;
          case (tx_ctr_reg)
            'h0: //Load only
              begin
                tx_addr_next_we = 0; // Do not update tx_addr on first out
                ramtx_en = 1;
                ramtx_we = 0;
              end
            'h1: tx_load_ram_and_emit(1, ram_a_rdata); //Nonce MSB from previous cycle
            'h2: tx_load_ram_and_emit(0, ram_a_rdata); //Nonce LSB from previous cycle
            'h3: //Tag0
              begin
                ramtx_addr_we = 1;
                ramtx_addr_new = MEM8_ADDR_PC;
                tx_load_ram_and_emit(0, core_tag_out[127:64]);
              end
            'h4: tx_load_ram_and_emit(1, core_tag_out[63:0]); //Load from MEM8_ADDR_PC
            'h5: tx_load_ram_and_emit(1, ram_a_rdata); //C0 (C2S 0)
            'h6: tx_load_ram_and_emit(1, ram_a_rdata); //C1 (C2S 1)
            'h7: tx_load_ram_and_emit(1, ram_a_rdata); //C2 (C2S 2)
            'h8: tx_load_ram_and_emit(1, ram_a_rdata); //C3 (C2S 3)
            'h9: tx_load_ram_and_emit(1, ram_a_rdata); //C4 (S2C 0)
            'ha: tx_load_ram_and_emit(1, ram_a_rdata); //C5 (S2C 1)
            'hb: tx_load_ram_and_emit(1, ram_a_rdata); //C6 (S2C 2)
            'hc: tx_load_ram_and_emit(0, ram_a_rdata); //C7 (S2C 3)
            default: ;
          endcase;
        end
      STATE_STORE_TX_CB_INIT:
        begin
          ramtx_en = 1;
          ramtx_we = 0;
          ramtx_addr_we = 1;
          ramtx_addr_new = ramtx_addr_reg + 1;
          tx_ctr_we = 1;
          tx_ctr_new = tx_ctr_reg + 1; //TODO workaround to fix off by one issue in TX emit
        end
      STATE_STORE_TX_CB:
        begin
          ramtx_addr_we = 1;
          ramtx_addr_new = ramtx_addr_reg + 1;
          tx_addr = tx_addr_next_reg;
          tx_addr_next_we = 1;
          tx_addr_next_new = tx_addr_next_reg + 8;
          tx_ctr_we = 1;
          tx_ctr_new = tx_ctr_reg + 1;
          tx_load_ram_and_emit(1, ram_a_rdata);
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // AES-SIV core control
  // Sets AES-SIV registers
  //----------------------------------------------------------------

  always @*
  begin : aes_siv_core_ctrl
    core_pc_mux_we = 0;
    core_pc_mux_new = MUX_CIPHERTEXT_NONE;
    core_ad_length_we = 0;
    core_ad_length_new = 0;
    core_config_we = 0;
    core_config_encdec_new = MODE_DECRYPT;
    core_start_new = 0;
    key_current_we = 0;
    key_current_new = 0;

    case (state_reg)
      STATE_IDLE:
        begin
          if (i_op_copy_rx_ad) begin
            core_ad_length_we = 1;
            core_ad_length_new[19:ADDR_WIDTH+3] = 0;
            core_ad_length_new[ADDR_WIDTH+3-1:0] = i_copy_rx_bytes;
          end
          if (i_op_copy_tx_ad) begin
            core_ad_length_we = 1;
            core_ad_length_new[19:ADDR_WIDTH+3] = 0;
            core_ad_length_new[ADDR_WIDTH+3-1:0] = i_copy_tx_bytes;
          end
          if (i_op_verify_c2s) begin
            core_config_we = 1;
            core_config_encdec_new = MODE_DECRYPT;
            core_pc_mux_we = 1;
            core_pc_mux_new = MUX_CIPHERTEXT_NONE;
            core_start_new = 1;
            key_current_we = 1;
            key_current_new = key_c2s_reg;
          end
          if (i_op_generate_tag) begin
            core_config_we = 1;
            core_config_encdec_new = MODE_ENCRYPT;
            core_pc_mux_we = 1;
            core_pc_mux_new = MUX_CIPHERTEXT_PC_COOKIEBUF;
            core_start_new = 0; //Occurs later, in STATE_AUTH_MEMSTORE_NONCE
            key_current_we = 1;
            key_current_new = key_s2c_reg;
          end
          if (i_op_cookie_verify) begin
            core_ad_length_we = 1;
            core_ad_length_new = 0; // Chrony format, No AD
            core_config_we = 1;
            core_config_encdec_new = MODE_DECRYPT;
            core_pc_mux_we = 1;
            core_pc_mux_new = MUX_CIPHERTEXT_PC512;
            core_start_new = 1;
            key_current_we = 1;
            key_current_new = key_master_reg;
          end
          if (i_op_cookie_rencrypt) begin
            core_ad_length_we = 1;
            core_ad_length_new = 0; // Chrony format, No AD
            core_config_we = 1;
            core_config_encdec_new = MODE_ENCRYPT;
            core_pc_mux_we = 1;
            core_pc_mux_new = MUX_CIPHERTEXT_PC512;
            core_start_new = 0; //Occurs later, in STATE_AUTH_MEMSTORE_NONCE
            key_current_we = 1;
            key_current_new = key_master_reg;
          end
        end
      STATE_AUTH_MEMSTORE_NONCE:
        begin
          core_start_new = 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Nonce retrival process
  //----------------------------------------------------------------

  always @*
  begin : noncegen_copy
    //Internal
    nonce_a_we = 0;
    nonce_b_we = 0;
    nonce_new = 0;
    nonce_invalidate = 0;
    ramnc_en = 0;
    ramnc_we = 0;
    ramnc_wdata = 0;
    //External (noncegen)
    nonce_generate_we = 0;
    nonce_generate_new = 0;

    if (state_reg == STATE_AUTH_MEMSTORE_NONCE) begin
      nonce_a_we = 1;
      nonce_b_we = 1;
      nonce_invalidate = 1;
      ramnc_en = 1;
      ramnc_we = 1;
      ramnc_wdata = { nonce_a_reg, nonce_b_reg };
    end
    else
    if (nonce_generate_reg) begin
      if (i_noncegen_ready) begin
        nonce_generate_we = 1;
        nonce_generate_new = 0;
        if (nonce_a_valid_reg == 'b0) begin
          nonce_new = i_noncegen_nonce;
          nonce_a_we = 1;
          //$display("%s:%0d nonce_a = %h", `__FILE__, `__LINE__, nonce_new);
        end
        else if (nonce_b_valid_reg == 'b0) begin
          nonce_new = i_noncegen_nonce;
          nonce_b_we = 1;
          //$display("%s:%0d nonce_b = %h", `__FILE__, `__LINE__, nonce_new);
        end
      end
    end
    else if (nonce_a_valid_reg == 'b0 || nonce_b_valid_reg == 'b0) begin
      //$display("%s:%0d Request new nonce", `__FILE__, `__LINE__);
      nonce_generate_we = 1;
      nonce_generate_new = 1;
    end
  end

  //----------------------------------------------------------------
  // Cookie buffer length helper;
  //----------------------------------------------------------------

  always @*
  begin
    cookiebuffer_length_we = 0;
    cookiebuffer_length_new = 0;

    if (ramcookie_addr_write_we) begin
      cookiebuffer_length_we = 1;
      if (ramcookie_addr_write_new > MEM8_ADDR_COOKIES)
        cookiebuffer_length_new = ramcookie_addr_write_new - MEM8_ADDR_COOKIES;
    end
  end

  //----------------------------------------------------------------
  // Cookie Buffer Handler Helper tasks
  //----------------------------------------------------------------

  task cookie_load_ram_and_store (
    input        ramload,
    input [63:0] data_out
  );
  begin
    ramcookie_ld = ramload;
    ramcookie_wr = 1;
    ramcookie_wdata = data_out;
  end
  endtask

  //----------------------------------------------------------------
  // Cookie Buffer control
  //----------------------------------------------------------------

  always @*
  begin : cookie_buf

    cookie_prefix_we = 0;
    cookie_prefix_new = 0;

    cookie_ctr_we = 0;
    cookie_ctr_new = 0;

    ramcookie_addr_load_we = 0;
    ramcookie_addr_load_new = 0;
    ramcookie_addr_write_we = 0;
    ramcookie_addr_write_new = 0;
    ramcookie_ld = 0;
    ramcookie_wr = 0;
    ramcookie_wdata = 0;

    case (state_reg)
      STATE_IDLE:
        if (i_op_cookiebuf_reset) begin
          ramcookie_addr_write_we = 1;
          ramcookie_addr_write_new = MEM8_ADDR_COOKIES;
        end
        else if (i_op_cookiebuf_appendcookie) begin
          cookie_ctr_we = 1;
          cookie_ctr_new = 0;
          cookie_prefix_we = 1;
          cookie_prefix_new = i_cookie_prefix;
          ramcookie_addr_load_we = 1;
          ramcookie_addr_load_new = MEM8_ADDR_NONCE;
        end
      STATE_STORE_COOKIEBUF:
        begin
          cookie_ctr_we = 1;
          cookie_ctr_new = cookie_ctr_reg + 1;
          ramcookie_addr_load_we = 1;
          ramcookie_addr_load_new = ramcookie_addr_load_reg + 1;
          ramcookie_addr_write_we = 1;
          ramcookie_addr_write_new = ramcookie_addr_write_reg + 1;

          case (cookie_ctr_reg)
            'h0: //Load only
              begin
                cookie_load_ram_and_store(1, cookie_prefix_reg);
              end
            'h1: cookie_load_ram_and_store(1, ram_a_rdata); //Nonce MSB from previous cycle
            'h2: cookie_load_ram_and_store(0, ram_a_rdata); //Nonce LSB from previous cycle
            'h3: //Tag0
              begin
                ramcookie_addr_load_we = 1;
                ramcookie_addr_load_new = MEM8_ADDR_PC;
                cookie_load_ram_and_store(0, core_tag_out[127:64]);
              end
            'h4: cookie_load_ram_and_store(1, core_tag_out[63:0]); //Load from MEM8_ADDR_PC
            'h5: cookie_load_ram_and_store(1, ram_a_rdata); //C0 (C2S 0)
            'h6: cookie_load_ram_and_store(1, ram_a_rdata); //C1 (C2S 1)
            'h7: cookie_load_ram_and_store(1, ram_a_rdata); //C2 (C2S 2)
            'h8: cookie_load_ram_and_store(1, ram_a_rdata); //C3 (C2S 3)
            'h9: cookie_load_ram_and_store(1, ram_a_rdata); //C4 (S2C 0)
            'ha: cookie_load_ram_and_store(1, ram_a_rdata); //C5 (S2C 1)
            'hb: cookie_load_ram_and_store(1, ram_a_rdata); //C6 (S2C 2)
            'hc: cookie_load_ram_and_store(0, ram_a_rdata); //C7 (S2C 3)
            default:
              begin
                ramcookie_addr_load_we = 0;
                ramcookie_addr_write_we = 0;
              end
          endcase;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Finite State Machine
  //----------------------------------------------------------------

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
        end else if (i_op_copy_rx_pc) begin
          state_we = 1;
          state_new = STATE_COPY_RX_INIT_PC;
        end else if (i_op_copy_rx_tag) begin
          state_we = 1;
          state_new = STATE_COPY_RX_INIT_TAG;
        end else if (i_op_verify_c2s) begin
          state_we = 1;
          state_new = STATE_SIV_VERIFY_WAIT_0;
        end else if (i_op_cookie_verify) begin
          state_we = 1;
          state_new = STATE_SIV_VERIFY_WAIT_0;
        end else if (i_op_cookie_loadkeys) begin
          state_we = 1;
          state_new = STATE_LOAD_KEYS_FROM_MEM;
        end else if (i_op_cookie_rencrypt) begin
          if (nonce_a_valid_reg && nonce_b_valid_reg) begin
            state_we = 1;
            state_new = STATE_AUTH_MEMSTORE_NONCE;
          end else begin
            state_we = 1;
            state_new = STATE_ERROR;
          end
        end else if (i_op_copy_tx_ad) begin
          state_we = 1;
          state_new = STATE_COPY_TX_INIT_AD;
        end else if (i_op_generate_tag) begin
          if (nonce_a_valid_reg && nonce_b_valid_reg) begin
            state_we = 1;
            state_new = STATE_AUTH_MEMSTORE_NONCE;
          end else begin
            state_we = 1;
            state_new = STATE_ERROR;
          end
        end else if (i_op_store_tx_nonce_tag) begin
          state_we = 1;
          state_new = STATE_STORE_TX_AUTH_INIT;
        end else if (i_op_store_tx_cookie) begin
          state_we = 1;
          state_new = STATE_STORE_TX_COOKIE_INIT;
        end else if (i_op_store_tx_cookiebuf) begin
          state_we = 1;
          state_new = STATE_STORE_TX_CB_INIT;
        end else if (i_op_cookiebuf_appendcookie) begin
          state_we = 1;
          state_new = STATE_STORE_COOKIEBUF;
        end
      STATE_COPY_RX_INIT_PC:
        if (i_rx_wait == 'b0) begin
          state_we = 1;
          state_new = STATE_COPY_RX;
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
      STATE_COPY_TX_INIT_AD:
        begin
          state_we = 1;
          state_new = STATE_COPY_TX;
        end
      STATE_COPY_TX:
        if (tx_addr >= tx_addr_last_reg) begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_AUTH_MEMSTORE_NONCE:
        begin
          state_we = 1;
          state_new = STATE_SIV_AUTH_WAIT_0;
        end
      STATE_SIV_AUTH_WAIT_0:
         begin
          state_we = 1;
          state_new = STATE_SIV_AUTH_WAIT_1;
        end
      STATE_SIV_AUTH_WAIT_1:
        if (core_ready) begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_STORE_TX_AUTH_INIT:
        begin
          state_we = 1;
          state_new = STATE_STORE_TX_AUTH;
        end
      STATE_STORE_TX_AUTH:
        if (tx_ctr_reg >= 4) begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_STORE_TX_COOKIE_INIT:
        if (i_tx_busy == 'b0) begin
          state_we = 1;
          state_new = STATE_STORE_TX_COOKIE;
        end
      STATE_STORE_TX_COOKIE:
        if (tx_ctr_reg >= 12) begin //TODO replace with a named constant (128+128+256+256) / 64  ...
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_STORE_TX_CB_INIT:
        if (cookiebuffer_length_reg == 0) begin
          state_we = 1;
          state_new = STATE_IDLE;
        end else if (i_tx_busy == 'b0) begin
          state_we = 1;
          state_new = STATE_STORE_TX_CB;
        end
      STATE_STORE_TX_CB:
        if (tx_ctr_reg >= cookiebuffer_length_reg) begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_LOAD_KEYS_FROM_MEM:
        if (ramld_addr_reg >= MEM8_ADDR_PC + 8) begin //TODO replace with named constant.
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_STORE_COOKIEBUF:
        if (cookie_ctr_reg >= 12) begin //TODO replace with a named constant (128+128+256+256) / 64  ...
          state_we = 1;
          state_new = STATE_IDLE;
        end
      STATE_ERROR:
        begin
          state_we = 1;
          state_new = STATE_IDLE;
        end
      default:
        begin
          state_we = 1;
          state_new = STATE_ERROR;
        end
    endcase
  end

/*
  generate
    if (DEBUG_OUTPUT) begin
      always @(posedge i_clk) begin
        if (ram_a_en && ram_b_en && ram_a_we && ram_b_we) begin
          $display("%s:%0d RAM port AB addr[%h,%h] wdata: %h%h", `__FILE__, `__LINE__, ram_a_addr, ram_b_addr, ram_a_wdata, ram_b_wdata);
        end else if (ram_a_en && ram_b_en && ram_a_we==0 && ram_b_we==0) begin
          $display("%s:%0d RAM port AB addr[%h,%h] (read)", `__FILE__, `__LINE__, ram_a_addr, ram_b_addr);
        end else begin
          if (ram_a_en) $display("%s:%0d RAM port A, en: %h we: %h addr: %h wdata: %h", `__FILE__, `__LINE__, ram_a_en, ram_a_we, ram_a_addr, ram_a_wdata);
          if (ram_b_en) $display("%s:%0d RAM port B, en: %h we: %h addr: %h wdata: %h", `__FILE__, `__LINE__, ram_b_en, ram_b_we, ram_b_addr, ram_b_wdata);
        end
        if (state_reg == STATE_ERROR) $display("%s:%0d state==ERROR!", `__FILE__, `__LINE__);
      end
    end
  endgenerate
*/
endmodule
