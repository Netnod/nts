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

module nts_extractor #(
  parameter API_ADDR_WIDTH = 12,
  parameter API_ADDR_BASE  = 'h400
) (
  input  wire        i_areset, // async reset
  input  wire        i_clk,

  input  wire                        i_api_cs,
  input  wire                        i_api_we,
  input  wire [API_ADDR_WIDTH - 1:0] i_api_address,
  /* verilator lint_off UNUSED */
  input  wire                 [31:0] i_api_write_data,
  /* verilator lint_on UNUSED */
  output wire                 [31:0] o_api_read_data,

  input  wire        i_engine_packet_available,
  output wire        o_engine_packet_read,
  input  wire        i_engine_fifo_empty,
  output wire        o_engine_fifo_rd_en,
  input  wire [63:0] i_engine_fifo_rd_data,
  input  wire  [3:0] i_engine_bytes_last_word,

  output wire        o_mac_tx_start,
  input  wire        i_mac_tx_ack,
  output wire  [7:0] o_mac_tx_data_valid,
  output wire [63:0] o_mac_tx_data
);
  //----------------------------------------------------------------
  // Local parameters, constants, definitions etc
  //----------------------------------------------------------------

  localparam BRAM_WIDTH = 16;
  localparam ADDR_WIDTH = 8;

  localparam BUFFER_SELECT_ADDRESS_WIDTH = BRAM_WIDTH - ADDR_WIDTH;
  localparam BUFFERS = 1<<BUFFER_SELECT_ADDRESS_WIDTH;
  localparam [BUFFER_SELECT_ADDRESS_WIDTH-1:0] BUFFER_FIRST = 0;
  localparam [BUFFER_SELECT_ADDRESS_WIDTH-1:0] BUFFER_LAST = ~ BUFFER_FIRST;

  localparam [0:0] STATE_RESET  = 1'b0;
  localparam [0:0] STATE_NORMAL = 1'b1;

  localparam [1:0] BUFFER_STATE_UNUSED  = 2'b00;
  localparam [1:0] BUFFER_STATE_WRITING = 2'b01;
  localparam [1:0] BUFFER_STATE_LOADED  = 2'b10;
  localparam [1:0] BUFFER_STATE_READING = 2'b11;

  localparam TX_IDLE       = 3'd0;
  localparam TX_AWAIT_ACK  = 3'd1;
  localparam TX_WRITE      = 3'd2;
  localparam TX_WRITE_LAST = 3'd3;

  localparam ADDR_NAME0             = API_ADDR_BASE + 0;
  localparam ADDR_NAME1             = API_ADDR_BASE + 1;
  localparam ADDR_VERSION           = API_ADDR_BASE + 2;
  localparam ADDR_BYTES             = API_ADDR_BASE + 10;
  localparam ADDR_PACKETS           = API_ADDR_BASE + 12;

  localparam CORE_NAME    = 64'h4e_54_53_2d_45_58_54_52; //NTS-EXTR
  localparam CORE_VERSION = 32'h30_2e_30_31; //0.01

  //----------------------------------------------------------------
  // Asynchrononous registers
  //----------------------------------------------------------------

  reg        counter_bytes_we;
  reg [63:0] counter_bytes_new;
  reg [63:0] counter_bytes_reg;
  reg        counter_bytes_lsb_we;
  reg [31:0] counter_bytes_lsb_reg;

  reg        counter_packets_we;
  reg [63:0] counter_packets_new;
  reg [63:0] counter_packets_reg;
  reg        counter_packets_lsb_we;
  reg [31:0] counter_packets_lsb_reg;

  reg [ADDR_WIDTH-1:0] buffer_addr_reg  [0:BUFFERS-1];
  reg            [3:0] buffer_lwdv_reg  [0:BUFFERS-1];
  reg            [1:0] buffer_state_reg [0:BUFFERS-1];

  reg                   buffer_engine_addr_we;
  reg  [ADDR_WIDTH-1:0] buffer_engine_addr_new;

  reg       buffer_engine_lwdv_we;
  reg [3:0] buffer_engine_lwdv_new;

  reg                                   buffer_engine_selected_we;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_engine_selected_new;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_engine_selected_reg;

  reg                                   buffer_reset_we;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_reset_new;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_reset_reg;

  reg        buffer_engine_state_we;
  reg  [1:0] buffer_engine_state_new;
  reg                                   buffer_mac_selected_we;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_mac_selected_new;
  reg [BUFFER_SELECT_ADDRESS_WIDTH-1:0] buffer_mac_selected_reg;

  wire [ADDR_WIDTH-1:0] buffer_mac_addr;

  reg        buffer_mac_state_we;
  reg  [1:0] buffer_mac_state_new;

  reg engine_packet_read_new;
  reg engine_packet_read_reg;
  reg engine_fifo_rd_en_new;
  reg engine_fifo_rd_en_reg;

  reg  [7:0] mac_data_valid_new;
  reg  [7:0] mac_data_valid_reg;
  reg [63:0] mac_data_new;
  reg [63:0] mac_data_reg;
  reg        mac_start_new;
  reg        mac_start_reg;

  reg                  read_addr_we;
  reg [ADDR_WIDTH-1:0] read_addr_new;
  reg [ADDR_WIDTH-1:0] read_addr_reg;

  reg       state_we;
  reg [0:0] state_new;
  reg [0:0] state_reg;

  reg       tx_state_we;
  reg [2:0] tx_state_new;
  reg [2:0] tx_state_reg;

  //----------------------------------------------------------------
  // Synchrononous registers
  //----------------------------------------------------------------

  //Reset wires
  reg sync_reset_metastable;
  reg sync_reset;

  // Registers between engine input read and ram writes to relax timing requirements
  reg [BRAM_WIDTH-1:0] write_addr_new;
  reg [BRAM_WIDTH-1:0] write_addr_reg;
  reg                  write_wren_new;
  reg                  write_wren_reg;
  reg           [63:0] write_wdata_new;
  reg           [63:0] write_wdata_reg;

  //----------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------

  reg            [31:0] api_read_data;

  wire [ADDR_WIDTH-1:0] buffer_engine_addr;
  wire            [1:0] buffer_engine_state;
  wire            [1:0] buffer_mac_state;

  reg [BRAM_WIDTH-1:0] ram_engine_addr;
  /* verilator lint_off UNUSED */
  wire          [63:0] ram_engine_rdata;
  /* verilator lint_on UNUSED */
  reg                  ram_engine_write;
  reg           [63:0] ram_engine_wdata;
  reg [BRAM_WIDTH-1:0] ram_mac_addr;
  reg                  ram_mac_read;
  wire          [63:0] ram_mac_rdata;

  reg tx_start;
  reg tx_stop;

  //----------------------------------------------------------------
  // Wire assignments
  //----------------------------------------------------------------

  assign buffer_engine_addr = buffer_addr_reg[buffer_engine_selected_reg];
  assign buffer_engine_state = buffer_state_reg[buffer_engine_selected_reg];

  assign buffer_mac_addr = buffer_addr_reg[buffer_mac_selected_reg];
  assign buffer_mac_state = buffer_state_reg[buffer_mac_selected_reg];

  assign o_api_read_data = api_read_data;

  assign o_mac_tx_data = mac_data_reg;
  assign o_mac_tx_data_valid = mac_data_valid_reg;
  assign o_mac_tx_start = mac_start_reg;

  assign o_engine_packet_read = engine_packet_read_reg;
  assign o_engine_fifo_rd_en  = engine_fifo_rd_en_reg;

  //----------------------------------------------------------------
  // API
  //----------------------------------------------------------------

  always @*
  begin : api
    api_read_data = 0;
    counter_bytes_lsb_we = 0;

    if (i_api_cs) begin
      if (i_api_we) begin
        ;
      end else begin
        case (i_api_address)
          ADDR_NAME0: api_read_data = CORE_NAME[63:32];
          ADDR_NAME1: api_read_data = CORE_NAME[31:0];
          ADDR_VERSION: api_read_data = CORE_VERSION;
          ADDR_BYTES:
            begin
              counter_bytes_lsb_we = 1;
              api_read_data = counter_bytes_reg[63:32];
            end
          ADDR_BYTES + 1: api_read_data = counter_bytes_lsb_reg;
          ADDR_PACKETS:
            begin
              counter_packets_lsb_we = 1;
              api_read_data = counter_packets_reg[63:32];
            end
          ADDR_PACKETS + 1: api_read_data = counter_packets_lsb_reg;
          default: ;
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // API counters
  //----------------------------------------------------------------

  always @*
  begin : api_counters
    counter_bytes_we = 1;
    counter_bytes_new = 0;
    counter_packets_we = 0;
    counter_packets_new = 0;
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
    if (mac_start_reg) begin
      counter_packets_we = 1;
      counter_packets_new = counter_packets_reg + 1;
    end
  end

  //----------------------------------------------------------------
  // Buffer RAM
  //----------------------------------------------------------------

  bram_dp2w #( .ADDR_WIDTH( BRAM_WIDTH ), .DATA_WIDTH(64) ) bufferMEM (
    .i_clk(i_clk),
    .i_en_a(ram_engine_write),
    .i_en_b(ram_mac_read),
    .i_we_a(ram_engine_write),
    .i_we_b(1'b0),
    .i_addr_a(ram_engine_addr),
    .i_addr_b(ram_mac_addr),
    .i_data_a(ram_engine_wdata),
    .i_data_b(64'b0),
    .o_data_a(ram_engine_rdata),
    .o_data_b(ram_mac_rdata)
  );

  //----------------------------------------------------------------
  // Engine_reader process
  // Copies data from engine to internal buffers
  //----------------------------------------------------------------

  always @*
  begin : engine_reader
    buffer_engine_addr_we = 0;
    buffer_engine_addr_new = 0;
    buffer_engine_lwdv_we = 0;
    buffer_engine_lwdv_new = 0;
    buffer_engine_selected_we = 0;
    buffer_engine_selected_new = 0;
    buffer_engine_state_we = 0;
    buffer_engine_state_new = 0;
    engine_packet_read_new = 0;
    engine_fifo_rd_en_new = 0;
    write_wdata_new = 0;
    write_wren_new = 0;
    write_addr_new = 0;
    if (state_reg == STATE_NORMAL) begin
      case (buffer_engine_state)
        BUFFER_STATE_UNUSED:
          if (i_engine_packet_available && i_engine_fifo_empty==1'b0) begin
            buffer_engine_lwdv_we = 1;
            buffer_engine_lwdv_new = i_engine_bytes_last_word;
            buffer_engine_state_we = 1;
            buffer_engine_state_new = BUFFER_STATE_WRITING;
            engine_fifo_rd_en_new = 1;
          end
        BUFFER_STATE_WRITING:
          if (i_engine_fifo_empty) begin
            engine_packet_read_new = 1;
            buffer_engine_state_we = 1;
            buffer_engine_state_new = BUFFER_STATE_LOADED;
            buffer_engine_selected_we = 1;
            buffer_engine_selected_new = buffer_engine_selected_reg + 1;
          end else begin
            buffer_engine_addr_we = 1;
            buffer_engine_addr_new = buffer_engine_addr + 1;
            write_addr_new[BRAM_WIDTH-1:ADDR_WIDTH] = buffer_engine_selected_reg;
            write_addr_new[ADDR_WIDTH-1:0] = buffer_engine_addr;
            write_wdata_new = i_engine_fifo_rd_data;
            write_wren_new = 1;
            engine_fifo_rd_en_new = 1;
          end
        BUFFER_STATE_LOADED: ;
        BUFFER_STATE_READING: ;
      endcase
    end
  end

  //----------------------------------------------------------------
  // RAM write process
  //----------------------------------------------------------------

  always @*
  begin : ram_write
    ram_engine_write = write_wren_reg;
    ram_engine_addr = write_addr_reg;
    ram_engine_wdata = write_wdata_reg;
  end

  //----------------------------------------------------------------
  // MAC Media Access Controller
  //----------------------------------------------------------------

  always @*
  begin
    ram_mac_addr       = 0;
    ram_mac_read       = 0;
    mac_start_new      = 0;
    mac_data_new       = 0;
    mac_data_valid_new = 0;
    read_addr_we       = 0;
    read_addr_new      = 0;
    tx_state_we        = 0;
    tx_state_new       = 0;
    tx_stop            = 0;

    if (state_reg == STATE_NORMAL) begin
      ram_mac_addr[BRAM_WIDTH-1:ADDR_WIDTH] = buffer_mac_selected_reg;
      ram_mac_addr[ADDR_WIDTH-1:0] = read_addr_reg;
      ram_mac_read = 1;

      case (tx_state_reg)
        TX_IDLE:
          if (tx_start) begin
            mac_start_new = 1;
            read_addr_we = 1;
            read_addr_new = 0;
            tx_state_we = 1;
            tx_state_new = TX_AWAIT_ACK;
          end
        TX_AWAIT_ACK:
          begin
            if (i_mac_tx_ack) begin
              read_addr_we = 1;
              read_addr_new = 1;
              tx_state_we = 1;
              tx_state_new = TX_WRITE;
            end
          end
        TX_WRITE:
          begin
            mac_data_new = ram_mac_rdata;
            mac_data_valid_new = 8'hff;
            read_addr_we = 1;
            read_addr_new = read_addr_reg + 1;
            if (read_addr_new >= buffer_mac_addr) begin
               //$display("%s:%0d read_addr_reg: %h buffer_mac_addr: %h", `__FILE__, `__LINE__, read_addr_reg, buffer_mac_addr);
               tx_state_we = 1;
               tx_state_new = TX_WRITE_LAST;
            end
          end
        TX_WRITE_LAST:
          begin : tx_write_last
            reg [71:0] tmp;
            case (buffer_lwdv_reg[buffer_mac_selected_reg])
              default: tmp = { 8'b0000_0000, 64'h0 };
              1: tmp = { 8'b0000_0001, 56'h0, ram_mac_rdata[63-:8] };
              2: tmp = { 8'b0000_0011, 48'h0, ram_mac_rdata[63-:16] };
              3: tmp = { 8'b0000_0111, 40'h0, ram_mac_rdata[63-:24] };
              4: tmp = { 8'b0000_1111, 32'h0, ram_mac_rdata[63-:32] };
              5: tmp = { 8'b0001_1111, 24'h0, ram_mac_rdata[63-:40] };
              6: tmp = { 8'b0011_1111, 16'h0, ram_mac_rdata[63-:48] };
              7: tmp = { 8'b0111_1111,  8'h0, ram_mac_rdata[63-:56] };
              8: tmp = { 8'b1111_1111,        ram_mac_rdata[63-:64] };
            endcase
            { mac_data_valid_new, mac_data_new } = tmp;
            tx_state_we = 1;
            tx_state_new = TX_IDLE;
            tx_stop = 1;
          end
        default: ;
      endcase;
    end
  end

  //----------------------------------------------------------------
  // MAC buffer selector
  //----------------------------------------------------------------

  always @*
  begin
    buffer_mac_selected_we = 0;
    buffer_mac_selected_new = 0;
    buffer_mac_state_we = 0;
    buffer_mac_state_new = 0;
    tx_start = 0;
    if (state_reg == STATE_NORMAL) begin
      case (buffer_mac_state)
        BUFFER_STATE_UNUSED: ;
        BUFFER_STATE_WRITING: ;
        BUFFER_STATE_LOADED:
          if (tx_state_reg == TX_IDLE) begin
            buffer_mac_state_we = 1;
            buffer_mac_state_new = BUFFER_STATE_READING;
            tx_start = 1;
          end
        BUFFER_STATE_READING:
          if (tx_stop) begin
            buffer_mac_selected_we = 1;
            buffer_mac_selected_new = buffer_mac_selected_reg + 1;
            buffer_mac_state_we = 1;
            buffer_mac_state_new = BUFFER_STATE_UNUSED;
          end
        default: ;
      endcase
    end
  end


  //----------------------------------------------------------------
  // Array register reset upon bootup
  //----------------------------------------------------------------

  always @*
  begin
    buffer_reset_we = 0;
    buffer_reset_new = 0;
    state_we = 0;
    state_new = 0;
    case (state_reg)
      STATE_RESET:
        begin
          //$display("%s:%0d reset: %h", `__FILE__, `__LINE__, buffer_reset_reg);
          if (buffer_reset_reg == BUFFER_LAST) begin
            state_we = 1;
            state_new = STATE_NORMAL;
          end else begin
            buffer_reset_we = 1;
            buffer_reset_new = buffer_reset_reg + 1;
          end
        end
      STATE_NORMAL: ;
    endcase
  end

  //----------------------------------------------------------------
  // Synchronous reset conversion
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      sync_reset_metastable <= 1;
      sync_reset <= 1;
    end else begin
      sync_reset_metastable <= 0;
      sync_reset <= sync_reset_metastable;
    end
  end

  //----------------------------------------------------------------
  // BRAM Register Update (synchronous reset)
  //----------------------------------------------------------------

  always @(posedge i_clk)
  begin : bram_reg_update
    if (sync_reset) begin
      write_addr_reg  <= 0;
      write_wdata_reg <= 0;
      write_wren_reg  <= 0;
    end else begin
      write_addr_reg  <= write_addr_new;
      write_wdata_reg <= write_wdata_new;
      write_wren_reg  <= write_wren_new;
    end
  end

  //----------------------------------------------------------------
  // Register Update (asynchronous reset)
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      buffer_engine_selected_reg <= 0;
      buffer_mac_selected_reg <= 0;
      buffer_reset_reg <= 0;
      counter_bytes_reg <= 0;
      counter_bytes_lsb_reg <= 0;
      counter_packets_reg <= 0;
      counter_packets_lsb_reg <= 0;
      engine_fifo_rd_en_reg <= 0;
      engine_packet_read_reg <= 0;
      mac_start_reg <= 0;
      mac_data_reg <= 0;
      mac_data_valid_reg <= 0;
      read_addr_reg <= 0;
      state_reg <= STATE_RESET;
      tx_state_reg <= TX_IDLE;
    end else begin
      if (counter_bytes_we)
        counter_bytes_reg <= counter_bytes_new;

      if (counter_bytes_lsb_we)
        counter_bytes_lsb_reg <= counter_bytes_reg[31:0];

      if (counter_packets_we)
        counter_packets_reg <= counter_packets_new;

      if (counter_packets_lsb_we)
        counter_packets_lsb_reg <= counter_packets_reg[31:0];

      if (buffer_engine_addr_we)
        buffer_addr_reg[buffer_engine_selected_reg] <= buffer_engine_addr_new;

      if (buffer_engine_selected_we)
        buffer_engine_selected_reg <= buffer_engine_selected_new;

      if (buffer_engine_lwdv_we)
        buffer_lwdv_reg[buffer_engine_selected_reg] <= buffer_engine_lwdv_new;

      if (buffer_engine_state_we)
        buffer_state_reg[buffer_engine_selected_reg] <= buffer_engine_state_new;

      if (buffer_mac_selected_we)
        buffer_mac_selected_reg <= buffer_mac_selected_new;

      if (buffer_mac_state_we)
        buffer_state_reg[buffer_mac_selected_reg] <= buffer_mac_state_new;

      if (buffer_reset_we)
        buffer_reset_reg <= buffer_reset_new;

      engine_fifo_rd_en_reg <= engine_fifo_rd_en_new;
      engine_packet_read_reg <= engine_packet_read_new;

      mac_start_reg <= mac_start_new;
      mac_data_reg <= mac_data_new;
      mac_data_valid_reg <= mac_data_valid_new;

      if (read_addr_we)
        read_addr_reg <= read_addr_new;

      if (state_we)
        state_reg <= state_new;

      if (state_reg == STATE_RESET) begin
        buffer_addr_reg[buffer_reset_reg] <= 0;
        buffer_lwdv_reg[buffer_reset_reg] <= 0;
        buffer_state_reg[buffer_reset_reg] <= BUFFER_STATE_UNUSED;
      end

      if (tx_state_we)
        tx_state_reg <= tx_state_new;
    end
  end

endmodule
