//
// Copyright (c) 2019, The Swedish Post and Telecom Authority (PTS)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//

//
// Author: Peter Magnusson, Assured AB
//

module nts_cookie_handler #(
  parameter integer KEY_LENGTH      = 512,
  parameter integer KEY_ADDR_32BITS = 4
) (
  input  wire                         i_clk,
  input  wire                         i_areset,
  input  wire [KEY_ADDR_32BITS-1 : 0] i_key_word,
  input  wire                         i_key_valid,
  input  wire                         i_key_length,
  input  wire                [31 : 0] i_key_data,
  input wire                 [31 : 0] i_key_id,
  input  wire                         i_cookie_nonce,
  input  wire                         i_cookie_s2c,
  input  wire                         i_cookie_c2s,
  input  wire                         i_cookie_tag,
  input  wire [KEY_ADDR_32BITS-1 : 0] i_cookie_word,
  input  wire                [31 : 0] i_cookie_data,
  input  wire                         i_op_unwrap,
  output wire                         o_busy,
  output wire                         o_unwrap_tag_ok,
  output wire                         o_unrwapped_s2c,
  output wire                         o_unwrapped_c2s,
  output wire [KEY_ADDR_32BITS-1 : 0] o_unwrapped_word,
  output wire                [31 : 0] o_unwrapped_data
);

  //----------------------------------------------------------------
  // Local constants / parameters.
  //----------------------------------------------------------------

  localparam LOCAL_MEMORY_BUS_WIDTH = 4;

  localparam MODE_DECRYPT = 0;

  localparam AEAD_AES_SIV_CMAC_256 = 1'h0;
  localparam AEAD_AES_SIV_CMAC_512 = 1'h1;

  localparam STATE_IDLE                    = 0;
  localparam STATE_UNWRAP_LOAD_AD          = 1;
  localparam STATE_UNWRAP_LOAD_NONCE       = 2;
  localparam STATE_UNWRAP_LOAD_S2C_1       = 3;
  localparam STATE_UNWRAP_LOAD_S2C_2       = 4;
  localparam STATE_UNWRAP_LOAD_C2S_1       = 5;
  localparam STATE_UNWRAP_LOAD_C2S_2       = 6;
  localparam STATE_UNWRAP_PROCESSING_START = 7;
  localparam STATE_UNWRAP_PROCESSING_WAIT1 = 8;
  localparam STATE_UNWRAP_PROCESSING_WAIT2 = 9;
  localparam STATE_UNWRAP_OK               = 10;

  localparam STATE_ERROR                   = 15;

  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_COOKIE_AD    = 0;
  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_COOKIE_NONCE = 1;
  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_COOKIE_C2S   = 1 + 1;
  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_COOKIE_S2C   = 1 + 1 + 2;
  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_CIPHERTEXT   = MEMORY_COOKIE_C2S;

  //----------------------------------------------------------------
  // FSM etc Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg            state_we;
  reg   [ 3 : 0] state_new;
  reg   [ 3 : 0] state_reg;

  reg            key_id_we;
  reg   [31 : 0] key_id_new;
  reg   [31 : 0] key_id_reg;

  reg    [3 : 0] cookie_addr;
  reg   [31 : 0] cookie_new;
  reg            cookie_s2c_we;
  reg   [31 : 0] cookie_s2c_reg [0 : 15];
  reg            cookie_c2s_we;
  reg   [31 : 0] cookie_c2s_reg [0 : 15];
  reg            cookie_nonce_we;
  reg   [31 : 0] cookie_nonce_reg [3 : 0];

  reg            key_length_reg;
  reg            key_length_new;
  reg            key_length_we;

  reg            unwrap_tag_ok_reg;
  reg            unwrap_tag_ok_new;
  reg            unwrap_tag_ok_we;

  //----------------------------------------------------------------
  // AES-SIV Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg          start_reg;
  reg          start_new;

  reg          config_encdec_reg;
  reg          config_encdec_new;
  reg          config_mode_reg;
  reg          config_mode_new;
  reg          config_we;


  reg [31 : 0] key_reg [0 : 15];
  reg  [3 : 0] key_addr;
  reg [31 : 0] key_new;
  reg          key_we;

  reg [15 : 0] ad_start_reg;
  reg [15 : 0] ad_start_new;
  reg          ad_start_we;

  reg [19 : 0] ad_length_reg;
  reg [19 : 0] ad_length_new;
  reg          ad_length_we;

  reg [15 : 0] nonce_start_reg;
  reg [15 : 0] nonce_start_new;
  reg          nonce_start_we;

  reg [19 : 0] nonce_length_reg;
  reg [19 : 0] nonce_length_new;
  reg          nonce_length_we;

  reg [15 : 0] pc_start_reg;
  reg [15 : 0] pc_start_new;
  reg          pc_start_we;

  reg [19 : 0] pc_length_reg;
  reg [19 : 0] pc_length_new;
  reg          pc_length_we;

  reg [31 : 0] tag_in_reg [0 : 3];
  reg  [1 : 0] tag_in_addr;
  reg [31 : 0] tag_in_new;
  reg          tag_in_we;

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  reg                                 mem_cs;
  reg                                 mem_we;
  wire                                mem_ack;
  reg  [LOCAL_MEMORY_BUS_WIDTH-1 : 0] mem_addr;
  reg                       [127 : 0] mem_block_wr;
  wire                      [127 : 0] mem_block_rd;

  wire [511 : 0] core_key;
  wire           core_cs;
  wire           core_we;
  reg            core_ack;
  wire  [15 : 0] core_addr;
  reg  [127 : 0] core_block_rd;
  wire [127 : 0] core_block_wr;
  wire [127 : 0] core_tag_in;
  wire [127 : 0] core_tag_out;
  wire           core_tag_ok;
  wire           core_ready;

  wire           reset_n;

  //----------------------------------------------------------------
  // Assignments
  //----------------------------------------------------------------

  assign core_key = key_length_reg ?
                    {key_reg[00], key_reg[01], key_reg[02], key_reg[03],
                     key_reg[04], key_reg[05], key_reg[06], key_reg[07],
                     key_reg[08], key_reg[09], key_reg[10], key_reg[11],
                     key_reg[12], key_reg[13], key_reg[14], key_reg[15]} :

                    {key_reg[08], key_reg[09], key_reg[10], key_reg[11],
                     128'h0,
                     key_reg[12], key_reg[13], key_reg[14], key_reg[15],
                     128'h0};

  assign core_tag_in = {tag_in_reg[0], tag_in_reg[1],
                        tag_in_reg[2], tag_in_reg[3]};

  assign o_busy = state_reg != STATE_IDLE;
  assign o_unwrap_tag_ok = unwrap_tag_ok_reg;

  assign o_unrwapped_s2c = 0; //TODO
  assign o_unwrapped_c2s = 0; //TODO
  assign o_unwrapped_word = 0; //TODO
  assign o_unwrapped_data = 0; //TODO
  assign reset_n = ~ i_areset;

  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  aes_siv_core core(
                    .clk(i_clk),
                    .reset_n(reset_n),
                    .encdec(config_encdec_reg),
                    .key(core_key),
                    .mode(config_mode_reg),
                    .start(start_reg),
                    .ad_start(ad_start_reg),
                    .ad_length(ad_length_reg),
                    .nonce_start(nonce_start_reg),
                    .nonce_length(nonce_length_reg),
                    .pc_start(pc_start_reg),
                    .pc_length(pc_length_reg),
                    .cs(core_cs),
                    .we(core_we),
                    .ack(core_ack),
                    .addr(core_addr),
                    .block_rd(core_block_rd),
                    .block_wr(core_block_wr),
                    .tag_in(core_tag_in),
                    .tag_out(core_tag_out),
                    .tag_ok(core_tag_ok),
                    .ready(core_ready)
                   );

  bram_with_ack memm (
                  .clk(i_clk),
                  .areset(i_areset),
                  .cs(mem_cs),
                  .we(mem_we),
                  .ack(mem_ack),
                  .addr(mem_addr),
                  .block_wr(mem_block_wr),
                  .block_rd(mem_block_rd)
                 );

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    integer i;
    if (i_areset) begin
      key_id_reg <= 0;
      key_length_reg <= 0;
      state_reg <= 0;
      unwrap_tag_ok_reg <= 0;

      for (i = 0 ; i < 16 ; i = i + 1) begin
        key_reg[i] <= 32'h0;
        cookie_s2c_reg[i] <= 32'h0;
        cookie_c2s_reg[i] <= 32'h0;
      end

      for (i = 0 ; i < 4 ; i = i + 1) begin
        tag_in_reg[i] <= 32'h0;
        cookie_nonce_reg[i] <= 32'h0;
      end

    end else begin
      // ------------- FSM -------------
      if (state_we) state_reg <= state_new;

      // ------------- General Regs -------------
      if (key_id_we) key_id_reg <= key_id_new;
      if (key_length_we) key_length_reg <= key_length_new;

      if (cookie_nonce_we)
        cookie_nonce_reg[cookie_addr[1:0]] <= cookie_new;

      if (cookie_s2c_we)
        cookie_s2c_reg[cookie_addr] <= cookie_new;

      if (cookie_c2s_we)
        cookie_c2s_reg[cookie_addr] <= cookie_new;

      if (unwrap_tag_ok_we)
        unwrap_tag_ok_reg <= unwrap_tag_ok_new;

      // ------------ AES-SIV Regs -------------
      start_reg  <= start_new;

      if (config_we) begin
        config_encdec_reg <= config_encdec_new;
        config_mode_reg   <= config_mode_new;
      end

      if (ad_start_we)
        ad_start_reg <= ad_start_new;

      if (ad_length_we)
        ad_length_reg <= ad_length_new;

      if (nonce_start_we)
        nonce_start_reg <= nonce_start_new;

      if (nonce_length_we)
        nonce_length_reg <= nonce_length_new;

      if (pc_start_we)
        pc_start_reg <= pc_start_new;

      if (pc_length_we)
        pc_length_reg <= pc_length_new;

      if (tag_in_we)
        tag_in_reg[tag_in_addr] <= tag_in_new;

      if (key_we)
        key_reg[key_addr] <= key_new;
    end
  end

  always @*
  begin : simple_input_to_regs_processing
    cookie_addr = 0;
    cookie_new = 0;
    cookie_nonce_we = 0;
    cookie_s2c_we = 0;
    cookie_c2s_we = 0;
    key_we = 0;
    key_addr = 0;
    key_id_we = 0;
    key_id_new = 0;
    key_length_we = 0;
    key_length_new = 0;
    //-------- AES-SIV regs ---------
    config_we = 0;
    config_encdec_new = 1;
    config_mode_new = 0;
    start_new = 0;
    ad_start_we = 0;
    ad_start_new = 0;
    ad_length_we = 0;
    ad_length_new = 0;
    nonce_start_we = 0;
    nonce_start_new = 0;
    nonce_length_we = 0;
    nonce_length_new = 0;
    pc_start_we = 0;
    pc_start_new = 0;
    pc_length_we = 0;
    pc_length_new = 0;
    tag_in_we = 0;
    tag_in_addr = 0;
    tag_in_new = 0;
    case (state_reg)
      STATE_IDLE:
        begin
          if (i_key_valid) begin
            key_we = 1;
            key_new = i_key_data;
            key_addr = i_key_word;
            key_id_we = 1;
            key_id_new = i_key_id;
            key_length_we = 1;
            key_length_new = i_key_length;
          end
          if (i_cookie_nonce) begin
            cookie_nonce_we = 1;
            cookie_addr = i_cookie_word;
            cookie_new = i_cookie_data;
          end
          if (i_cookie_s2c) begin
            cookie_s2c_we = 1;
            cookie_addr = i_cookie_word;
            cookie_new = i_cookie_data;
          end
          if (i_cookie_c2s) begin
            cookie_c2s_we = 1;
            cookie_addr = i_cookie_word;
            cookie_new = i_cookie_data;
          end
          if (i_cookie_tag) begin
            tag_in_we = 1;
            tag_in_addr = i_cookie_word[1:0];
            tag_in_new = i_cookie_data;
          end
          if (i_op_unwrap) begin
            config_we = 1;
            config_encdec_new = MODE_DECRYPT;
            config_mode_new = key_length_reg ? AEAD_AES_SIV_CMAC_512 : AEAD_AES_SIV_CMAC_256;

            ad_start_we = 1;
            ad_start_new[LOCAL_MEMORY_BUS_WIDTH-1:0] = MEMORY_COOKIE_AD;
            ad_length_we = 1;
            ad_length_new = 0;

            nonce_start_we = 1;
            nonce_start_new[LOCAL_MEMORY_BUS_WIDTH-1:0] = MEMORY_COOKIE_NONCE;
            nonce_length_we = 1;
            nonce_length_new = 16;

            pc_start_we = 1;
            pc_start_new[LOCAL_MEMORY_BUS_WIDTH-1:0] = MEMORY_COOKIE_C2S;
            pc_length_we = 1;
            pc_length_new = 64;
          end
        end
      STATE_UNWRAP_PROCESSING_START:
        begin
          start_new = 1;
        end
      STATE_UNWRAP_PROCESSING_WAIT2:
        if (core_ready) begin
          unwrap_tag_ok_we = 1;
          unwrap_tag_ok_new = core_tag_ok;
        end
      default: ;
    endcase
  end

  always @*
  begin : fsm_and_mem_ctrl
    mem_cs = 0;
    mem_we = 0;
    mem_addr = 0;
    mem_block_wr = 0;
    core_ack = 0;
    core_block_rd = 0;
    state_we = 0;
    state_new = 0;

    case (state_reg)
      STATE_IDLE:
        begin
          if (i_op_unwrap) begin
            state_we = 1;
            state_new = STATE_UNWRAP_LOAD_AD;
          end
        end
      STATE_UNWRAP_LOAD_AD:
        begin
          mem_cs = 1;
          mem_we = 1;
          mem_addr = MEMORY_COOKIE_AD;
          mem_block_wr = { key_id_reg, 96'b0 };
          $display("%s:%0d STATE_UNWRAP_LOAD_AD: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
          state_we = 1;
          state_new = STATE_UNWRAP_LOAD_NONCE;
        end
      STATE_UNWRAP_LOAD_NONCE:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_NONCE;
            mem_block_wr = { cookie_nonce_reg[0], cookie_nonce_reg[1], cookie_nonce_reg[2], cookie_nonce_reg[3] };
            $display("%s:%0d STATE_UNWRAP_LOAD_NONCE: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_LOAD_C2S_1;
          end
        end
      STATE_UNWRAP_LOAD_C2S_1:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_C2S;
            mem_block_wr = { cookie_c2s_reg[0], cookie_c2s_reg[1], cookie_c2s_reg[2], cookie_c2s_reg[3] };
            $display("%s:%0d STATE_UNWRAP_LOAD_C2S_1: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_LOAD_C2S_2;
          end
        end
      STATE_UNWRAP_LOAD_C2S_2:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_C2S+1;
            mem_block_wr = { cookie_c2s_reg[4], cookie_c2s_reg[5], cookie_c2s_reg[6], cookie_c2s_reg[7] };
            $display("%s:%0d STATE_UNWRAP_LOAD_C2S_2: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_LOAD_S2C_1;
          end
        end
      STATE_UNWRAP_LOAD_S2C_1:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_S2C;
            mem_block_wr = { cookie_s2c_reg[0], cookie_s2c_reg[1], cookie_s2c_reg[2], cookie_s2c_reg[3] };
            $display("%s:%0d STATE_UNWRAP_LOAD_S2C_1: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_LOAD_S2C_2;
          end
        end
      STATE_UNWRAP_LOAD_S2C_2:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_S2C+1;
            mem_block_wr = { cookie_s2c_reg[4], cookie_s2c_reg[5], cookie_s2c_reg[6], cookie_s2c_reg[7] };
            $display("%s:%0d STATE_UNWRAP_LOAD_S2C_2: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_PROCESSING_START;
          end
        end
      STATE_UNWRAP_PROCESSING_START:
        begin
          state_we = 1;
          state_new = STATE_UNWRAP_PROCESSING_WAIT1;
        end
      STATE_UNWRAP_PROCESSING_WAIT1:
        begin
          state_we = 1;
          state_new = STATE_UNWRAP_PROCESSING_WAIT2;
        end
      STATE_UNWRAP_PROCESSING_WAIT2:
        if (core_ready) begin
          if (core_tag_ok) begin
            state_we = 1;
            state_new = STATE_UNWRAP_OK;
          end else begin
            state_we = 1;
            state_new = STATE_ERROR; //TODO implement a success handler... :)
          end
        end else begin
          core_ack = mem_ack;
          core_block_rd = mem_block_rd;
          mem_cs = core_cs;
          mem_we = core_we;
          mem_addr = core_addr[LOCAL_MEMORY_BUS_WIDTH-1:0];
          mem_block_wr = core_block_wr;
        end
      default:
        begin
          state_we = 1;
          state_new = STATE_IDLE;
          $display("%s:%0d Error state %0d not implemented", `__FILE__, `__LINE__, state_reg);
        end
    endcase
  end

endmodule
