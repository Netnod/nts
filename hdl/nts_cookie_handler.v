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
  parameter    [15:0] COOKIE_TAG       = 16'h0204,
  parameter    [15:0] COOKIE_LEN       = 16'h0068,
  parameter integer KEY_LENGTH         = 512,
  parameter integer KEY_ADDR_32BITS    = 4,
  parameter integer WRP_LENGTH         = 256,
  parameter integer WRP_ADDR_32BITS    = 3,
  parameter integer COOKIE_LENGTH      = 832,
  parameter integer COOKIE_ADDR_64BITS = 4
) (
  input  wire                         i_clk,
  input  wire                         i_areset,

  input  wire [KEY_ADDR_32BITS-1 : 0] i_key_word,
  input  wire                         i_key_valid,
  input  wire                         i_key_length,
  input  wire                [31 : 0] i_key_id,
  input  wire                [31 : 0] i_key_data,

  input  wire                         i_cookie_nonce,
  input  wire                         i_cookie_s2c,
  input  wire                         i_cookie_c2s,
  input  wire                         i_cookie_tag,
  input  wire [KEY_ADDR_32BITS-1 : 0] i_cookie_word,
  input  wire                [31 : 0] i_cookie_data,

  input  wire                         i_op_unwrap,
  input  wire                         i_op_gencookie,

  output wire                         o_busy,

  output wire                         o_unwrap_tag_ok,
  output wire                         o_unrwapped_s2c,
  output wire                         o_unwrapped_c2s,
  output wire [WRP_ADDR_32BITS-1 : 0] o_unwrapped_word,
  output wire                [31 : 0] o_unwrapped_data,

  output wire                         o_noncegen_get,
  input  wire                [63 : 0] i_noncegen_nonce,
  input  wire                         i_noncegen_ready,

  output wire                          o_cookie_valid,
  output wire                   [63:0] o_cookie_data,
  output wire [COOKIE_ADDR_64BITS-1:0] o_cookie_word

);

  //----------------------------------------------------------------
  // Local constants / parameters.
  //----------------------------------------------------------------

  localparam LOCAL_MEMORY_BUS_WIDTH = 4;

  localparam MODE_DECRYPT = 0;
  localparam MODE_ENCRYPT = 1;

  localparam AEAD_AES_SIV_CMAC_256 = 1'h0;
  localparam AEAD_AES_SIV_CMAC_512 = 1'h1;

  localparam STATE_IDLE                    = 0;
  localparam STATE_UNWRAP_MEMSTORE_AD      = 1;
  localparam STATE_UNWRAP_MEMSTORE_NONCE   = 2;
  localparam STATE_UNWRAP_MEMSTORE_S2C_1   = 3;
  localparam STATE_UNWRAP_MEMSTORE_S2C_2   = 4;
  localparam STATE_UNWRAP_MEMSTORE_C2S_1   = 5;
  localparam STATE_UNWRAP_MEMSTORE_C2S_2   = 6;
  localparam STATE_UNWRAP_PROCESSING_START = 7;
  localparam STATE_UNWRAP_PROCESSING_WAIT1 = 8;
  localparam STATE_UNWRAP_PROCESSING_WAIT2 = 9;
  localparam STATE_UNWRAP_OK               = 10;
  localparam STATE_UNWRAP_MEMLOAD_S2C_1    = 11;
  localparam STATE_UNWRAP_MEMLOAD_S2C_2    = 12;
  localparam STATE_UNWRAP_MEMLOAD_C2S_1    = 13;
  localparam STATE_UNWRAP_MEMLOAD_C2S_2    = 14;
  localparam STATE_UNWRAP_TRANSMIT         = 15;
  localparam STATE_WRAP_MEMSTORE_NONCE     = 16;
  localparam STATE_WRAP_MEMSTORE_S2C_1     = 17;
  localparam STATE_WRAP_MEMSTORE_S2C_2     = 18;
  localparam STATE_WRAP_MEMSTORE_C2S_1     = 19;
  localparam STATE_WRAP_MEMSTORE_C2S_2     = 20;
  localparam STATE_WRAP_PROCESSING_START   = 21;
  localparam STATE_WRAP_PROCESSING_WAIT1   = 22;
  localparam STATE_WRAP_PROCESSING_WAIT2   = 23;
  localparam STATE_WRAP_OK                 = 24;
  localparam STATE_WRAP_MEMLOAD_CT_0       = 25;
  localparam STATE_WRAP_MEMLOAD_CT_1       = 26;
  localparam STATE_WRAP_MEMLOAD_CT_2       = 27;
  localparam STATE_WRAP_MEMLOAD_CT_3       = 28;
  localparam STATE_ERROR                   = 31;

  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_COOKIE_AD    = 0;
  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_COOKIE_NONCE = 1;
  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_COOKIE_C2S   = 1 + 1;
  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_COOKIE_S2C   = 1 + 1 + 2;
  localparam [LOCAL_MEMORY_BUS_WIDTH-1:0] MEMORY_CIPHERTEXT   = MEMORY_COOKIE_C2S;

  //----------------------------------------------------------------
  // FSM etc Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg            state_we;
  reg   [ 4 : 0] state_new;
  reg   [ 4 : 0] state_debug_old_reg;
  reg   [ 4 : 0] state_reg;

  reg    [3 : 0] cookie_addr;
  reg   [31 : 0] cookie_new;
  reg            cookie_s2c_we;
  reg   [31 : 0] cookie_s2c_reg [0 : 15];
  reg            cookie_c2s_we;
  reg   [31 : 0] cookie_c2s_reg [0 : 15];
  reg            cookie_nonce_we;
  reg   [31 : 0] cookie_nonce_reg [3 : 0];

  reg   [31 : 0] key_id_reg;
  reg   [31 : 0] key_id_new;
  reg            key_id_we;

  reg            key_length_reg;
  reg            key_length_new;
  reg            key_length_we;

  reg            unwrap_tag_ok_reg;
  reg            unwrap_tag_ok_new;
  reg            unwrap_tag_ok_we;

  reg    [127:0] unwrapped_new;
  reg            unwrapped_s2c_we  [ 0 : 1 ];
  reg    [127:0] unwrapped_s2c_reg [ 0 : 1 ];
  reg            unwrapped_c2s_we  [ 0 : 1 ];
  reg    [127:0] unwrapped_c2s_reg [ 0 : 1 ];

  reg            unwrap_transmit_counter_we;
  reg      [3:0] unwrap_transmit_counter_new;
  reg      [3:0] unwrap_transmit_counter_reg;

  reg            nonce_generate_we;
  reg            nonce_generate_new;
  reg            nonce_generate_reg;

  reg     [63:0] nonce_new;
  reg            nonce_invalidate;
  reg            nonce_a_we;
  reg     [63:0] nonce_a_reg;
  reg            nonce_a_valid_reg;
  reg            nonce_b_we;
  reg     [63:0] nonce_b_reg;
  reg            nonce_b_valid_reg;

  reg            nonce_old_we;
  reg    [127:0] nonce_old_new;
  reg    [127:0] nonce_old_reg;

  reg            ct_we;
  reg      [1:0] ct_wr_addr;
  reg    [127:0] ct_new;
  reg    [511:0] ct_reg; //Ciphertext (cookie except tag)

  reg            ct_out_we;
  reg      [3:0] ct_out_new; //Ciphertext/cookie counter 0..12
  reg      [3:0] ct_out_reg; //Ciphertext/cookie counter 0..12
  reg            ct_out_active_new; //Ciphertext/cookie output on/off
  reg            ct_out_active_reg; //Ciphertext/cookie output on/off

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

  reg            u_c2s;
  reg            u_s2c;
  reg      [2:0] u_word;
  reg     [31:0] u_data;

  reg                          wrapped_cookie_valid;
  reg                   [63:0] wrapped_cookie_data;
  reg [COOKIE_ADDR_64BITS-1:0] wrapped_cookie_word;

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

  assign o_busy = (state_reg != STATE_IDLE) || ct_out_active_reg;

  assign o_unwrap_tag_ok = unwrap_tag_ok_reg;

  assign o_unrwapped_s2c = u_s2c;
  assign o_unwrapped_c2s = u_c2s;
  assign o_unwrapped_word = u_word;
  assign o_unwrapped_data = u_data;

  assign o_noncegen_get = nonce_generate_reg;

  assign o_cookie_valid = wrapped_cookie_valid;
  assign o_cookie_data  = wrapped_cookie_data;
  assign o_cookie_word  = wrapped_cookie_word;

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

  always @*
  begin : unwrap_output
    u_s2c = 0;
    u_c2s = 0;
    u_word = 0;
    u_data = 0;
    if (state_reg == STATE_UNWRAP_TRANSMIT) begin : unwrap_output_locals
      reg [127:0] output_reg;
      reg   [1:0] output_index;
      output_reg = 0;
      u_word = unwrap_transmit_counter_reg[2:0];
      output_index = unwrap_transmit_counter_reg[1:0];
      case (unwrap_transmit_counter_reg[3:2])
        0:
          begin
            u_s2c = 1;
            output_reg = unwrapped_s2c_reg[1];
          end
        1:
          begin
            u_s2c = 1;
            output_reg = unwrapped_s2c_reg[0];
          end
        2:
          begin
            u_c2s = 1;
            output_reg = unwrapped_c2s_reg[1];
          end
        3:
          begin
            u_c2s = 1;
            output_reg = unwrapped_c2s_reg[0];
          end
        default: ;
      endcase
      u_data = output_reg[output_index*32+:32];
      //$display("%s:%0d %b %b [%0d] = %h", `__FILE__, `__LINE__, u_c2s, u_s2c, u_word, u_data);
    end
  end

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    integer i;
    if (i_areset) begin
      ct_reg <= 0;
      ct_out_reg <= 0;
      ct_out_active_reg <= 0;
      key_id_reg <= 0;
      key_length_reg <= 0;
      state_reg <= 0;
      state_debug_old_reg <= 0;
      nonce_a_reg <= 0;
      nonce_a_valid_reg <= 0;
      nonce_b_reg <= 0;
      nonce_b_valid_reg <= 0;
      nonce_generate_reg <= 0;
      nonce_old_reg <= 0;
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

      for (i = 0; i < 2; i = i + 1) begin
        unwrapped_s2c_reg[i] <= 0;
        unwrapped_c2s_reg[i] <= 0;
      end

      unwrap_transmit_counter_reg <= 0;
    end else begin
      // ------------- FSM -------------
      if (state_we) begin
        state_reg <= state_new;
        state_debug_old_reg <= state_reg;
      end

      // ------------- General Regs -------------
      if (ct_we) begin
        ct_reg[ct_wr_addr*128+:128] <= ct_new;
      end
      if (ct_out_we) begin
        ct_out_reg <= ct_out_new;
        ct_out_active_reg <= ct_out_active_new;
      end

      if (key_id_we)
        key_id_reg <= key_id_new;

      if (key_length_we)
        key_length_reg <= key_length_new;

      if (cookie_nonce_we)
        cookie_nonce_reg[cookie_addr[1:0]] <= cookie_new;

      if (cookie_s2c_we)
        cookie_s2c_reg[cookie_addr] <= cookie_new;

      if (cookie_c2s_we)
        cookie_c2s_reg[cookie_addr] <= cookie_new;

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

      if (nonce_old_we)
        nonce_old_reg <= nonce_old_new;

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

      if (unwrapped_c2s_we[0])
        unwrapped_c2s_reg[0] <= unwrapped_new;

      if (unwrapped_c2s_we[1])
        unwrapped_c2s_reg[1] <= unwrapped_new;

      if (unwrapped_s2c_we[0])
        unwrapped_s2c_reg[0] <= unwrapped_new;

      if (unwrapped_s2c_we[1])
        unwrapped_s2c_reg[1] <= unwrapped_new;

      if (unwrap_transmit_counter_we)
        unwrap_transmit_counter_reg <= unwrap_transmit_counter_new;
    end
  end

  always @*
  begin : memory_load_unwrapped
    unwrapped_c2s_we[0] = 0;
    unwrapped_c2s_we[1] = 0;
    unwrapped_s2c_we[0] = 0;
    unwrapped_s2c_we[1] = 0;
    unwrapped_new = mem_block_rd;
    case (state_reg)
      STATE_UNWRAP_MEMLOAD_S2C_1: unwrapped_s2c_we[0] = 1;
      STATE_UNWRAP_MEMLOAD_S2C_2: unwrapped_s2c_we[1] = 1;
      STATE_UNWRAP_MEMLOAD_C2S_1: unwrapped_c2s_we[0] = 1;
      STATE_UNWRAP_MEMLOAD_C2S_2: unwrapped_c2s_we[1] = 1;
      default: unwrapped_new = 0;
    endcase
/*
    if (unwrapped_new != 0) begin
      $display("%s:%0d Memory load: %h %h %h %h %h", `__FILE__, `__LINE__, unwrapped_c2s_we[0], unwrapped_c2s_we[1], unwrapped_s2c_we[0], unwrapped_s2c_we[1], unwrapped_new );
    end
*/
  end

  always @*
  begin : noncegen_copy
    //Internal
    nonce_a_we = 0;
    nonce_b_we = 0;
    nonce_new = 0;
    nonce_invalidate = 0;
    nonce_old_we  = 0;
    nonce_old_new = 0;
    //External (noncegen)
    nonce_generate_we = 0;
    nonce_generate_new = 0;

    if (state_reg == STATE_WRAP_MEMSTORE_NONCE) begin
      nonce_a_we = 1;
      nonce_b_we = 1;
      nonce_invalidate = 1;
      nonce_old_we  = 1;
      nonce_old_new = { nonce_a_reg, nonce_b_reg };
    end
    else if (nonce_generate_reg) begin
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

  always @*
  begin : simple_input_to_regs_processing
    cookie_addr = 0;
    cookie_new = 0;
    cookie_nonce_we = 0;
    cookie_s2c_we = 0;
    cookie_c2s_we = 0;
    key_we = 0;
    key_new = 0;
    key_addr = 0;
    key_id_we = 0;
    key_id_new = 0;
    key_length_we = 0;
    key_length_new = 0;
    unwrap_tag_ok_we = 0;
    unwrap_tag_ok_new = 0;
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
          if (i_op_unwrap || i_op_gencookie) begin
            config_we = 1;
            config_encdec_new = i_op_unwrap ? MODE_DECRYPT : MODE_ENCRYPT;
            config_mode_new = key_length_reg ? AEAD_AES_SIV_CMAC_512 : AEAD_AES_SIV_CMAC_256;

            ad_start_we = 1;
            ad_start_new[LOCAL_MEMORY_BUS_WIDTH-1:0] = MEMORY_COOKIE_AD; /* UNUSED (Chrony format) */
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

            unwrap_tag_ok_we = 1;
            unwrap_tag_ok_new = 0;
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
      STATE_WRAP_PROCESSING_START:
        begin
          start_new = 1;
        end
      STATE_ERROR:
        begin
        end
      default: ;
    endcase
  end

  always @*
  begin : cookie_out_ctrl
    wrapped_cookie_valid = 0;
    wrapped_cookie_data  = 0;
    wrapped_cookie_word  = 0;
    ct_out_we = 0;
    ct_out_new = 0;
    ct_out_active_new = 0;
    if (state_reg == STATE_WRAP_OK) begin
      ct_out_we = 1;
      ct_out_new = 0;
      ct_out_active_new = 1;
    end else if (ct_out_active_reg) begin
      ct_out_we = 1;
      ct_out_new = ct_out_reg + 1;
      ct_out_active_new = 1;
      wrapped_cookie_valid = 1;
      wrapped_cookie_word = ct_out_reg;
      case (ct_out_reg)
        4'h0: wrapped_cookie_data = { COOKIE_TAG, COOKIE_LEN, key_id_reg };
        4'h1: wrapped_cookie_data = nonce_old_reg[127:64];
        4'h2: wrapped_cookie_data = nonce_old_reg[63:0];
        4'h3: wrapped_cookie_data = core_tag_out[127:64];
        4'h4: wrapped_cookie_data = core_tag_out[63:0];
        4'h5: wrapped_cookie_data = ct_reg[1*64+:64];
        4'h6: wrapped_cookie_data = ct_reg[0*64+:64];
        4'h7: wrapped_cookie_data = ct_reg[3*64+:64];
        4'h8: wrapped_cookie_data = ct_reg[2*64+:64];
        4'h9: wrapped_cookie_data = ct_reg[5*64+:64];
        4'hA: wrapped_cookie_data = ct_reg[4*64+:64];
        4'hB: wrapped_cookie_data = ct_reg[7*64+:64];
        4'hC: wrapped_cookie_data = ct_reg[6*64+:64];
        default: ;
      endcase
      if (ct_out_reg >= 4'hC) begin
        ct_out_we = 1;
        ct_out_new = 0;
        ct_out_active_new = 0;
      end
      //$display("%s:%0d CT_OUT[%h]=%h", `__FILE__, `__LINE__, wrapped_cookie_word, wrapped_cookie_data);
    end
  end

  always @*
  begin : copy_ciphertext_from_ram_to_reg
    ct_we = 1;
    ct_wr_addr = 0;
    ct_new = mem_block_rd;
    case (state_reg)
      STATE_WRAP_MEMLOAD_CT_0: ct_wr_addr = 0;
      STATE_WRAP_MEMLOAD_CT_1: ct_wr_addr = 1;
      STATE_WRAP_MEMLOAD_CT_2: ct_wr_addr = 2;
      STATE_WRAP_MEMLOAD_CT_3: ct_wr_addr = 3;
      default:
        begin
          ct_we = 0;
          ct_new = 0;
        end
    endcase
    //if (ct_we)
    // $display("%s:%0d CT[%h]=%h", `__FILE__, `__LINE__, ct_wr_addr, ct_new);
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
    unwrap_transmit_counter_we = 0;
    unwrap_transmit_counter_new = 0;

    case (state_reg)
      STATE_IDLE:
        begin
          if (i_op_unwrap) begin
            state_we = 1;
            state_new = STATE_UNWRAP_MEMSTORE_AD;
          end
          if (i_op_gencookie) begin
            state_we = 1;
            if (nonce_a_valid_reg && nonce_b_valid_reg) begin
              state_new = STATE_WRAP_MEMSTORE_NONCE;
            end else begin
              state_new = STATE_ERROR;
            end
          end
        end
      STATE_UNWRAP_MEMSTORE_AD:
        begin
          mem_cs = 1;
          mem_we = 1;
          mem_addr = MEMORY_COOKIE_AD;
          mem_block_wr = 128'h0; /* UNUSED. AD=None in Chrony format */
          //$display("%s:%0d STATE_UNWRAP_MEMSTORE_AD: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
          state_we = 1;
          state_new = STATE_UNWRAP_MEMSTORE_NONCE;
        end
      STATE_UNWRAP_MEMSTORE_NONCE:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_NONCE;
            mem_block_wr = { cookie_nonce_reg[0], cookie_nonce_reg[1], cookie_nonce_reg[2], cookie_nonce_reg[3] };
            //$display("%s:%0d STATE_UNWRAP_MEMSTORE_NONCE: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_MEMSTORE_C2S_1;
          end
        end
      STATE_UNWRAP_MEMSTORE_C2S_1:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_C2S;
            mem_block_wr = { cookie_c2s_reg[0], cookie_c2s_reg[1], cookie_c2s_reg[2], cookie_c2s_reg[3] };
            //$display("%s:%0d STATE_UNWRAP_MEMSTORE_C2S_1: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_MEMSTORE_C2S_2;
          end
        end
      STATE_UNWRAP_MEMSTORE_C2S_2:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_C2S+1;
            mem_block_wr = { cookie_c2s_reg[4], cookie_c2s_reg[5], cookie_c2s_reg[6], cookie_c2s_reg[7] };
            //$display("%s:%0d STATE_UNWRAP_MEMSTORE_C2S_2: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_MEMSTORE_S2C_1;
          end
        end
      STATE_UNWRAP_MEMSTORE_S2C_1:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_S2C;
            mem_block_wr = { cookie_s2c_reg[0], cookie_s2c_reg[1], cookie_s2c_reg[2], cookie_s2c_reg[3] };
            //$display("%s:%0d STATE_UNWRAP_MEMSTORE_S2C_1: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
            state_we = 1;
            state_new = STATE_UNWRAP_MEMSTORE_S2C_2;
          end
        end
      STATE_UNWRAP_MEMSTORE_S2C_2:
        begin
          if (mem_ack) begin
            mem_cs = 1;
            mem_we = 1;
            mem_addr = MEMORY_COOKIE_S2C+1;
            mem_block_wr = { cookie_s2c_reg[4], cookie_s2c_reg[5], cookie_s2c_reg[6], cookie_s2c_reg[7] };
            //$display("%s:%0d STATE_UNWRAP_MEMSTORE_S2C_2: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
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
            state_new = STATE_ERROR;
          end
        end else begin
          core_ack = mem_ack;
          core_block_rd = mem_block_rd;
          mem_cs = core_cs;
          mem_we = core_we;
          mem_addr = core_addr[LOCAL_MEMORY_BUS_WIDTH-1:0];
          mem_block_wr = core_block_wr;
          if (core_cs) begin
            if (core_addr[15:LOCAL_MEMORY_BUS_WIDTH] != 0) begin
              //Illegal memory access
             //$display("%s:%0d Illegal memory access: %h_%h", `__FILE__, `__LINE__, core_addr[15:LOCAL_MEMORY_BUS_WIDTH], core_addr[LOCAL_MEMORY_BUS_WIDTH-1:0]);
              state_we = 1;
              state_new = STATE_ERROR;
            end
          end
        end
      STATE_UNWRAP_OK:
        begin
          mem_cs = 1;
          mem_we = 0;
          mem_addr = MEMORY_COOKIE_S2C;
          state_we = 1;
          state_new = STATE_UNWRAP_MEMLOAD_S2C_1;
        end
      STATE_UNWRAP_MEMLOAD_S2C_1:
        begin
          mem_cs = 1;
          mem_we = 0;
          mem_addr = MEMORY_COOKIE_S2C + 1;
          state_we = 1;
          state_new = STATE_UNWRAP_MEMLOAD_S2C_2;
        end
      STATE_UNWRAP_MEMLOAD_S2C_2:
        begin
          mem_cs = 1;
          mem_we = 0;
          mem_addr = MEMORY_COOKIE_C2S;
          state_we = 1;
          state_new = STATE_UNWRAP_MEMLOAD_C2S_1;
        end
      STATE_UNWRAP_MEMLOAD_C2S_1:
        begin
          mem_cs = 1;
          mem_we = 0;
          mem_addr = MEMORY_COOKIE_C2S + 1;
          state_we = 1;
          state_new = STATE_UNWRAP_MEMLOAD_C2S_2;
        end
      STATE_UNWRAP_MEMLOAD_C2S_2:
        begin
          state_we = 1;
          state_new = STATE_UNWRAP_TRANSMIT;
          unwrap_transmit_counter_we = 1;
          unwrap_transmit_counter_new = 0;
        end
      STATE_UNWRAP_TRANSMIT:
        begin
          if (unwrap_transmit_counter_reg == 15) begin
            state_we = 1;
            state_new = STATE_IDLE;
          end else begin
             unwrap_transmit_counter_we = 1;
             unwrap_transmit_counter_new = unwrap_transmit_counter_reg + 1;
          end
        end
      STATE_WRAP_MEMSTORE_NONCE:
        begin
          mem_cs = 1;
          mem_we = 1;
          mem_addr = MEMORY_COOKIE_NONCE;
          mem_block_wr = { nonce_a_reg, nonce_b_reg };
          //$display("%s:%0d STATE_UNWRAP_MEMSTORE_NONCE: write mem[%0d]=%h", `__FILE__, `__LINE__, mem_addr, mem_block_wr);
          state_we = 1;
          state_new = STATE_WRAP_MEMSTORE_S2C_1;
        end
      STATE_WRAP_MEMSTORE_S2C_1:
        begin
          mem_cs = 1;
          mem_we = 1;
          mem_addr = MEMORY_COOKIE_S2C;
          mem_block_wr = unwrapped_s2c_reg[0];
          state_we = 1;
          state_new = STATE_WRAP_MEMSTORE_S2C_2;
        end
      STATE_WRAP_MEMSTORE_S2C_2:
        begin
          mem_cs = 1;
          mem_we = 1;
          mem_addr = MEMORY_COOKIE_S2C + 1;
          mem_block_wr = unwrapped_s2c_reg[1];
          state_we = 1;
          state_new = STATE_WRAP_MEMSTORE_C2S_1;
        end
      STATE_WRAP_MEMSTORE_C2S_1:
        begin
          mem_cs = 1;
          mem_we = 1;
          mem_addr = MEMORY_COOKIE_C2S;
          mem_block_wr = unwrapped_c2s_reg[0];
          state_we = 1;
          state_new = STATE_WRAP_MEMSTORE_C2S_2;
        end
      STATE_WRAP_MEMSTORE_C2S_2:
        begin
          mem_cs = 1;
          mem_we = 1;
          mem_addr = MEMORY_COOKIE_C2S + 1;
          mem_block_wr = unwrapped_c2s_reg[1];
          state_we = 1;
          state_new = STATE_WRAP_PROCESSING_START;
        end
      STATE_WRAP_PROCESSING_START:
        begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          state_we = 1;
          state_new = STATE_WRAP_PROCESSING_WAIT1;
        end
      STATE_WRAP_PROCESSING_WAIT1:
        begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          state_we = 1;
          state_new = STATE_WRAP_PROCESSING_WAIT2;
        end
      STATE_WRAP_PROCESSING_WAIT2:
        if (core_ready) begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          state_we = 1;
          state_new = STATE_WRAP_OK;
        end else begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          core_ack = mem_ack;
          core_block_rd = mem_block_rd;
          mem_cs = core_cs;
          mem_we = core_we;
          mem_addr = core_addr[LOCAL_MEMORY_BUS_WIDTH-1:0];
          mem_block_wr = core_block_wr;
          if (core_cs) begin
            if (core_addr[15:LOCAL_MEMORY_BUS_WIDTH] != 0) begin
              //Illegal memory access
             //$display("%s:%0d Illegal memory access: %h_%h", `__FILE__, `__LINE__, core_addr[15:LOCAL_MEMORY_BUS_WIDTH], core_addr[LOCAL_MEMORY_BUS_WIDTH-1:0]);
              state_we = 1;
              state_new = STATE_ERROR;
            end
          end
        end
      STATE_WRAP_OK:
        begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          mem_cs = 1;
          mem_we = 0;
          mem_addr = MEMORY_CIPHERTEXT + 0;
          state_we = 1;
          state_new = STATE_WRAP_MEMLOAD_CT_0;
        end
      STATE_WRAP_MEMLOAD_CT_0:
        begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          mem_cs = 1;
          mem_we = 0;
          mem_addr = MEMORY_CIPHERTEXT + 1;
          state_we = 1;
          state_new = STATE_WRAP_MEMLOAD_CT_1;
        end
      STATE_WRAP_MEMLOAD_CT_1:
        begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          mem_cs = 1;
          mem_we = 0;
          mem_addr = MEMORY_CIPHERTEXT + 2;
          state_we = 1;
          state_new = STATE_WRAP_MEMLOAD_CT_2;
        end
      STATE_WRAP_MEMLOAD_CT_2:
        begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          mem_cs = 1;
          mem_we = 0;
          mem_addr = MEMORY_CIPHERTEXT + 3;
          state_we = 1;
          state_new = STATE_WRAP_MEMLOAD_CT_3;
        end
      STATE_WRAP_MEMLOAD_CT_3:
        begin
          //$display("%s:%0d state_reg=%h", `__FILE__, `__LINE__, state_reg);
          state_we = 1;
          state_new = STATE_IDLE;
        end
      default:
        begin
          state_we = 1;
          state_new = STATE_IDLE;
          $display("%s:%0d Error state %0d not implemented. Previous state was: %0d", `__FILE__, `__LINE__, state_reg, state_debug_old_reg);
        end
    endcase
  end

endmodule