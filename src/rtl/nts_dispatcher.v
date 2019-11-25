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

module nts_dispatcher #(
  parameter ADDR_WIDTH = 8,
  parameter ENGINES = 1,
  parameter DEBUG = 1
) (
  input  wire        i_areset, // async reset
  input  wire        i_clk,

  // MAC
  input  wire [7:0]  i_rx_data_valid,
  input  wire [63:0] i_rx_data,
  input  wire        i_rx_bad_frame,
  input  wire        i_rx_good_frame,

  output wire                  o_dispatch_packet_available,
  input  wire                  i_dispatch_packet_read_discard,
  output wire [ADDR_WIDTH-1:0] o_dispatch_counter,
  output wire [7:0]            o_dispatch_data_valid,
  output wire                  o_dispatch_fifo_empty,
  input  wire                  i_dispatch_fifo_rd_start,
  output wire                  o_dispatch_fifo_rd_valid,
  output wire [63:0]           o_dispatch_fifo_rd_data,

  input  wire                  i_api_cs,
  input  wire                  i_api_we,
  input  wire [11:0]           i_api_address,
  input  wire [31:0]           i_api_write_data,
  output wire [31:0]           o_api_read_data,

  output wire [ENGINES-1:0]    o_engine_cs,
  output wire                  o_engine_we,
  output wire [11:0]           o_engine_address,
  output wire [31:0]           o_engine_write_data,
  input  wire [ENGINES*32-1:0] i_engine_read_data
);

  //----------------------------------------------------------------
  // API constants
  //----------------------------------------------------------------

  localparam ADDR_NAME0             = 0;
  localparam ADDR_NAME1             = 1;
  localparam ADDR_VERSION           = 2;
  localparam ADDR_DUMMY             = 3;
  localparam ADDR_CTRL              = 8;  //TODO implement
  localparam ADDR_STATUS            = 9;  //TODO implement
  localparam ADDR_BYTES_RX_MSB      = 10;
  localparam ADDR_BYTES_RX_LSB      = 11;
  localparam ADDR_NTS_REC_MSB       = 12; //TODO implement
  localparam ADDR_NTS_REC_LSB       = 13; //TODO implement
  localparam ADDR_NTS_DISCARDED_MSB = 14; //TODO implement
  localparam ADDR_NTS_DISCARDED_LSB = 15; //TODO implement
  localparam ADDR_NTS_ENGINES_READY = 16; //TODO implement

  localparam ADDR_COUNTER_FRAMES_MSB     = 'h20;
  localparam ADDR_COUNTER_FRAMES_LSB     = 'h21;
  localparam ADDR_COUNTER_GOOD_MSB       = 'h22;
  localparam ADDR_COUNTER_GOOD_LSB       = 'h23;
  localparam ADDR_COUNTER_BAD_MSB        = 'h24;
  localparam ADDR_COUNTER_BAD_LSB        = 'h25;
  localparam ADDR_COUNTER_DISPATCHED_MSB = 'h26;
  localparam ADDR_COUNTER_DISPATCHED_LSB = 'h27;
  localparam ADDR_COUNTER_ERROR_MSB      = 'h28;
  localparam ADDR_COUNTER_ERROR_LSB      = 'h29;

  localparam ADDR_BUS_ID_CMD_ADDR = 80;
  localparam ADDR_BUS_STATUS      = 81;
  localparam ADDR_BUS_DATA        = 82;

  localparam BUS_READ  = 8'h55;
  localparam BUS_WRITE = 8'hAA;

  localparam CORE_NAME    = 64'h4e_54_53_2d_44_49_53_50; //NTS-DISP
  localparam CORE_VERSION = 32'h30_2e_30_31; //0.01

  //----------------------------------------------------------------
  // State constants
  //----------------------------------------------------------------

  localparam STATE_EMPTY           = 0;
  localparam STATE_HAS_DATA        = 1;
  localparam STATE_PACKET_RECEIVED = 2;
  localparam STATE_FIFO_OUT_INIT_0 = 3;
  localparam STATE_FIFO_OUT_INIT_1 = 4;
  localparam STATE_FIFO_OUT_INIT_2 = 5;
  localparam STATE_FIFO_OUT        = 6;
  localparam STATE_FIFO_OUT_FIN_0  = 7;
  localparam STATE_FIFO_OUT_FIN_1  = 8;
  localparam STATE_ERROR_GENERAL   = 9;

  //----------------------------------------------------------------
  // Internal registers and wires
  //----------------------------------------------------------------

  reg  [31:0]     api_read_data;

  reg               current_mem;       //Current: MAC RX receiver. ~Current: Dispatcher FIFO out
  reg                fifo_empty;
  reg  [3:0]          mem_state [1:0];

  reg                     write [1:0]; //RAM W.E.
  reg  [63:0]            w_data [1:0]; //RAM W.D.
  wire [63:0]            r_data [1:0]; //RAM R.D
  reg  [ADDR_WIDTH-1:0]  r_addr;       //RAM R.A
  reg  [ADDR_WIDTH-1:0]  w_addr [1:0]; //RAM W.A
  reg  [ADDR_WIDTH-1:0] counter [1:0];
  reg  [7:0]         data_valid [1:0];

  reg [63:0] fifo_rd_data;  //out
  reg        fifo_rd_valid; //out

  reg [7:0] previous_rx_data_valid;
  reg       detect_start_of_frame;

  wire      error_state;

  reg [63:0] mac_rx_corrected;


  //----------------------------------------------------------------
  // API Debug, counter etc registers
  //----------------------------------------------------------------

  reg        api_dummy_we;
  reg [31:0] api_dummy_new;
  reg [31:0] api_dummy_reg;

  reg        counter_sof_detect_we;
  reg [63:0] counter_sof_detect_new;
  reg [63:0] counter_sof_detect_reg;
  reg        counter_sof_detect_lsb_we;
  reg [31:0] counter_sof_detect_lsb_reg;

  reg        counter_bad_we;
  reg [63:0] counter_bad_new;
  reg [63:0] counter_bad_reg;
  reg        counter_bad_lsb_we;
  reg [31:0] counter_bad_lsb_reg;

  reg        counter_bytes_rx_we;
  reg [63:0] counter_bytes_rx_new;
  reg [63:0] counter_bytes_rx_reg;
  reg        counter_bytes_rx_lsb_we;
  reg [31:0] counter_bytes_rx_lsb_reg;

  reg        counter_dispatched_we;
  reg [63:0] counter_dispatched_new;
  reg [63:0] counter_dispatched_reg;
  reg        counter_dispatched_lsb_we;
  reg [31:0] counter_dispatched_lsb_reg;

  reg        counter_error_we;
  reg [63:0] counter_error_new;
  reg [63:0] counter_error_reg;
  reg        counter_error_lsb_we;
  reg [31:0] counter_error_lsb_reg;

  reg        counter_good_we;
  reg [63:0] counter_good_new;
  reg [63:0] counter_good_reg;
  reg        counter_good_lsb_we;
  reg [31:0] counter_good_lsb_reg;

  reg        engine_ctrl_we;
  reg [31:0] engine_ctrl_new;
  reg [31:0] engine_ctrl_reg;
  reg        engine_status_we;
  reg [31:0] engine_status_new;
  reg [31:0] engine_status_reg;
  reg        engine_data_we;
  reg [31:0] engine_data_new;
  reg [31:0] engine_data_reg;

  reg  [ENGINES-1:0] bus_cs_new;
  reg  [ENGINES-1:0] bus_cs_reg;
  reg                bus_we_new;
  reg                bus_we_reg;
  reg  [11:0]        bus_addr_new;
  reg  [11:0]        bus_addr_reg;
  wire [31:0]        bus_write_data;
  reg  [31:0]        bus_read_data_mux;

  //----------------------------------------------------------------
  // Output wiring
  //----------------------------------------------------------------

  assign bus_write_data  = engine_data_reg;

  assign error_state     = (mem_state[0] == STATE_ERROR_GENERAL) || (mem_state[1] == STATE_ERROR_GENERAL);

  assign o_api_read_data = api_read_data;

  assign o_dispatch_packet_available  = mem_state[ ~ current_mem ] == STATE_FIFO_OUT_INIT_0;
  assign o_dispatch_counter           = counter[ ~ current_mem ];
  assign o_dispatch_data_valid        = data_valid[ ~ current_mem ];
  assign o_dispatch_fifo_empty        = fifo_empty;
  assign o_dispatch_fifo_rd_valid     = fifo_rd_valid;
  assign o_dispatch_fifo_rd_data      = fifo_rd_data;

  assign o_engine_cs         = bus_cs_reg;
  assign o_engine_we         = bus_we_reg;
  assign o_engine_address    = bus_addr_reg;
  assign o_engine_write_data = bus_write_data;

  //----------------------------------------------------------------
  // RAM cores
  //----------------------------------------------------------------

  bram #(ADDR_WIDTH,64) mem0 (
     .i_clk(i_clk),
     .i_addr(write[0] ? w_addr[0] : r_addr),
     .i_write(write[0]),
     .i_data(w_data[0]),
     .o_data(r_data[0])
  );

  bram #(ADDR_WIDTH,64) mem1 (
     .i_clk(i_clk),
     .i_addr(write[1] ? w_addr[1] : r_addr),
     .i_write(write[1]),
     .i_data(w_data[1]),
     .o_data(r_data[1])
  );

  //----------------------------------------------------------------
  // API
  //----------------------------------------------------------------

  always @*
  begin : api
    api_read_data = 0;

    api_dummy_we = 0;
    api_dummy_new = 0;

    counter_bad_lsb_we = 0;
    counter_bytes_rx_lsb_we = 0;
    counter_dispatched_lsb_we = 0;
    counter_error_lsb_we = 0;
    counter_good_lsb_we = 0;
    counter_sof_detect_lsb_we = 0;

    engine_ctrl_we = 0;
    engine_ctrl_new = 0;
    engine_status_we = 0;
    engine_status_new = 0;
    engine_data_we = 0;
    engine_data_new = 0;

    if (engine_status_reg[0]) begin
      if (bus_cs_reg != 0) begin
        //Reset status after 1 cycle.
        engine_status_we = 1;
        engine_status_new = { engine_status_reg[31:1], 1'b0 };
        if (bus_we_reg == 1'b0) begin
          engine_data_we = 1;
          engine_data_new = bus_read_data_mux;
        end
      end
    end

    if (i_api_cs) begin
      if (i_api_we) begin
        case (i_api_address)
          ADDR_DUMMY:
            begin
              api_dummy_we = 1;
              api_dummy_new = i_api_write_data;
            end
          ADDR_BUS_ID_CMD_ADDR:
            begin
              engine_ctrl_we = 1;
              engine_ctrl_new = i_api_write_data;
            end
          ADDR_BUS_STATUS:
            begin
              engine_status_we = 1;
              engine_status_new = i_api_write_data;
            end
          ADDR_BUS_DATA:
            begin
              engine_data_we = 1;
              engine_data_new = i_api_write_data;
            end
          default: ;
        endcase
      end else begin
        case (i_api_address)
          ADDR_NAME0: api_read_data = CORE_NAME[63:32];
          ADDR_NAME1: api_read_data = CORE_NAME[31:0];
          ADDR_VERSION: api_read_data = CORE_VERSION;
          ADDR_DUMMY: api_read_data = api_dummy_reg;
          ADDR_BYTES_RX_MSB:
            begin
              api_read_data = counter_bytes_rx_reg[63:32];
              counter_bytes_rx_lsb_we = 1;
            end
          ADDR_BYTES_RX_LSB:
            begin
              api_read_data = counter_bytes_rx_lsb_reg;
            end
          ADDR_COUNTER_FRAMES_MSB:
            begin
              api_read_data = counter_sof_detect_reg[63:32];
              counter_sof_detect_lsb_we = 1;
            end
          ADDR_COUNTER_FRAMES_LSB:
            begin
              api_read_data = counter_sof_detect_lsb_reg;
            end
          ADDR_COUNTER_GOOD_MSB:
            begin
              api_read_data = counter_good_reg[63:32];
              counter_good_lsb_we = 1;
            end
          ADDR_COUNTER_GOOD_LSB:
            begin
              api_read_data = counter_good_lsb_reg;
            end
          ADDR_COUNTER_BAD_MSB:
            begin
              api_read_data = counter_bad_reg[63:32];
              counter_bad_lsb_we = 1;
            end
          ADDR_COUNTER_BAD_LSB:
            begin
              api_read_data = counter_bad_lsb_reg;
            end
          ADDR_COUNTER_DISPATCHED_MSB:
            begin
              api_read_data = counter_dispatched_reg[63:32];
              counter_dispatched_lsb_we = 1;
            end
          ADDR_COUNTER_DISPATCHED_LSB:
            begin
              api_read_data = counter_dispatched_lsb_reg;
            end
          ADDR_COUNTER_ERROR_MSB:
            begin
              api_read_data = counter_error_reg[63:32];
              counter_error_lsb_we = 1;
            end
          ADDR_COUNTER_ERROR_LSB:
            begin
              api_read_data = counter_error_lsb_reg;
            end
          ADDR_BUS_ID_CMD_ADDR:
            begin
              api_read_data = engine_ctrl_reg;
            end
          ADDR_BUS_STATUS:
            begin
              api_read_data = engine_status_reg;
            end
          ADDR_BUS_DATA:
            begin
              api_read_data = engine_data_reg;
            end
          default: ;
        endcase
      end
    end
  end

  //----------------------------------------------------------------
  // Register Update
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin

      api_dummy_reg <= 0;

      counter_bad_reg <= 0;
      counter_bad_lsb_reg <= 0;
      counter_bytes_rx_reg <= 0;
      counter_bytes_rx_lsb_reg <= 0;
      counter_dispatched_reg <= 0;
      counter_dispatched_lsb_reg <= 0;
      counter_error_reg <= 0;
      counter_error_lsb_reg <= 0;
      counter_good_reg <= 0;
      counter_good_lsb_reg <= 0;
      counter_sof_detect_reg <= 0;
      counter_sof_detect_lsb_reg <= 0;
      engine_ctrl_reg <= 0;
      engine_status_reg <= 0;
      engine_data_reg <= 0;

    end else begin

      if (api_dummy_we)
        api_dummy_reg <= api_dummy_new;

      if (counter_bad_we)
       counter_bad_reg <= counter_bad_new;

      if (counter_bad_lsb_we)
        counter_bad_lsb_reg <= counter_bad_reg[31:0];

      if (counter_bytes_rx_we)
       counter_bytes_rx_reg <= counter_bytes_rx_new;

      if (counter_bytes_rx_lsb_we)
        counter_bytes_rx_lsb_reg <= counter_bytes_rx_reg[31:0];

      if (counter_dispatched_we)
       counter_dispatched_reg <= counter_dispatched_new;

      if (counter_dispatched_lsb_we)
        counter_dispatched_lsb_reg <= counter_dispatched_reg[31:0];

      if (counter_error_we)
       counter_error_reg <= counter_error_new;

      if (counter_error_lsb_we)
        counter_error_lsb_reg <= counter_error_reg[31:0];

      if (counter_good_we)
       counter_good_reg <= counter_good_new;

      if (counter_good_lsb_we)
        counter_good_lsb_reg <= counter_good_reg[31:0];

      if (counter_sof_detect_we)
       counter_sof_detect_reg <= counter_sof_detect_new;

      if (counter_sof_detect_lsb_we)
        counter_sof_detect_lsb_reg <= counter_sof_detect_reg[31:0];

      if (engine_ctrl_we)
        engine_ctrl_reg <= engine_ctrl_new;

      if (engine_data_we)
        engine_data_reg <= engine_data_new;

      if (engine_status_we)
        engine_status_reg <= engine_status_new;

    end
  end

  //----------------------------------------------------------------
  // Debug counters
  //----------------------------------------------------------------

  always @*
  begin : debug_regs

    counter_bad_we = 0;
    counter_bad_new = 0;

    counter_dispatched_we = 0;
    counter_dispatched_new = 0;

    counter_error_we = 0;
    counter_error_new = 0;

    counter_good_we = 0;
    counter_good_new = 0;

    counter_sof_detect_we = 0;
    counter_sof_detect_new = 0;

    if (i_rx_bad_frame) begin
      counter_bad_we = 1;
      counter_bad_new = counter_bad_reg + 1;
    end

    if (i_dispatch_fifo_rd_start) begin
      counter_dispatched_we = 1;
      counter_dispatched_new = counter_dispatched_reg + 1;
    end

    if (error_state) begin
      counter_error_we = 1;
      counter_error_new = counter_error_reg + 1;
    end

    if (i_rx_good_frame) begin
      counter_good_we = 1;
      counter_good_new = counter_good_reg + 1;
    end

    if (detect_start_of_frame) begin
      counter_sof_detect_we = 1;
      counter_sof_detect_new = counter_sof_detect_reg + 1;
    end
  end

  //----------------------------------------------------------------
  // MAC RX Data/DataValid pre-processor
  //
  //  - Fix byte order of last word to fit rest of message.
  //    (reduces complexity in rest of design)
  //
  //  - Increments byte counters
  //
  //----------------------------------------------------------------

  always @*
  begin : mac_rx_data_processor
    reg [3:0] bytes;
    bytes = 0;
    counter_bytes_rx_we = 0;
    counter_bytes_rx_new = 0;
    mac_rx_corrected = 0;

    case (i_rx_data_valid)
      8'b1111_1111:
        begin
          bytes = 8;
          mac_rx_corrected = { i_rx_data };
        end
      8'b0111_1111:
        begin
          bytes = 7;
          mac_rx_corrected = { i_rx_data[55:0],  8'h00 };
        end
      8'b0011_1111:
        begin
          bytes = 6;
          mac_rx_corrected = { i_rx_data[47:0], 16'h0000 };
        end
      8'b0001_1111:
         begin
           bytes = 5;
           mac_rx_corrected = { i_rx_data[39:0], 24'h000000 };
         end
      8'b0000_1111:
         begin
           bytes = 4;
           mac_rx_corrected = { i_rx_data[31:0], 32'h00000000 };
         end
      8'b0000_0111:
         begin
           bytes = 3;
            mac_rx_corrected = { i_rx_data[23:0], 40'h0000000000 };
          end
      8'b0000_0011:
         begin
           bytes = 2;
           mac_rx_corrected = { i_rx_data[15:0], 48'h000000000000 };
         end
      8'b0000_0001:
        begin
          bytes = 1;
          mac_rx_corrected = { i_rx_data[7:0],  56'h00000000000000 };
        end
      8'b0000_0000:
        begin
          bytes = 0;
          mac_rx_corrected = 64'h0;
        end
      default:
        begin
          mac_rx_corrected = i_rx_data;
          if (DEBUG)
            $display("%s:%0d Unexpected i_rx_data_valid: %b",  `__FILE__, `__LINE__, i_rx_data_valid );
        end
    endcase
    if (bytes != 0) begin
      counter_bytes_rx_we = 1;
      counter_bytes_rx_new = counter_bytes_rx_reg + { 60'h0, bytes };
    end
  end

  //----------------------------------------------------------------
  // Start of Frame Detector (previous MAC RX DV sampler)
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  if (i_areset) begin
    previous_rx_data_valid <= 8'hFF; // Must not be zero as 00FF used to detect start of frame
  end else begin
    previous_rx_data_valid <= i_rx_data_valid;
  end

  //----------------------------------------------------------------
  // Start of Frame Detector
  //----------------------------------------------------------------

  always @*
  begin : sof_detector
    reg [15:0] rx_valid;
    rx_valid = {previous_rx_data_valid, i_rx_data_valid};
    detect_start_of_frame = 0;
    if ( 16'h00FF == rx_valid) begin
      detect_start_of_frame = 1;
    end
  end

  //----------------------------------------------------------------
  // Enigne MUX handling
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  if (i_areset) begin
    bus_cs_reg   <= 0;
    bus_we_reg   <= 0;
    //bus_addr_reg <= 0;
  end else begin
    bus_cs_reg   <= bus_cs_new;
    bus_we_reg   <= bus_we_new;
    bus_addr_reg <= bus_addr_new;
  end

  always @*
  begin: engine_reg_parser_mux
    reg         enable_by_ctrl;
    reg         enable_by_cmd;
    reg  [11:0] id;
    reg  [ 7:0] cmd;
    reg  [11:0] addr;
    integer  i;

    bus_read_data_mux = 0;
    bus_cs_new = 0;
    bus_we_new = 0;
    bus_addr_new = 0;

    { id, cmd, addr } = engine_ctrl_reg;

    enable_by_cmd = 0;

    enable_by_ctrl = engine_status_reg[0];

    if (enable_by_ctrl) begin

      bus_addr_new = addr;

      case (cmd)
        BUS_READ:
          begin
            enable_by_cmd = 1;
          end
        BUS_WRITE:
          begin
            bus_we_new = 1;
            enable_by_cmd = 1;
          end
        default:
          begin
            if (DEBUG)
              $display("%s:%0d Unexpected cmd: %h (engine_ctrl_reg: %h)",  `__FILE__, `__LINE__, cmd, engine_ctrl_reg );
          end
      endcase

      if (enable_by_cmd) begin
        for (i = 0; i < ENGINES; i = i + 1) begin
          if (id == i[11:0]) begin
            bus_cs_new[i] = 1;
          end
        end
      end

    end //enable_by_ctrl
  end

  always @*
  begin : engine_api_mux
    integer i;
    bus_read_data_mux = 0;
    for (i = 0; i < ENGINES; i = i + 1) begin
      if (bus_cs_reg[i] == 1)
         bus_read_data_mux = i_engine_read_data[i*32+:32];
    end
  end

  //----------------------------------------------------------------
  // Main process
  //----------------------------------------------------------------

  always @ (posedge i_clk or posedge i_areset)
  begin : main_proc
    if (i_areset == 1'b1) begin
      current_mem   <= 'b0;
      fifo_empty    <= 'b1;
      fifo_rd_data  <= 'b0;
      r_addr        <= 'b0;
      mem_state[0]  <= STATE_EMPTY;
      mem_state[1]  <= STATE_EMPTY;
      write[0]      <= 1'b0;
      write[1]      <= 1'b0;
      w_data[0]     <= 64'b0;
      w_data[1]     <= 64'b0;
      w_addr[0]     <= 'b0;
      w_addr[1]     <= 'b0;
      counter[0]    <= 'b0;
      counter[1]    <= 'b0;
      data_valid[0] <= 'b0;
      data_valid[1] <= 'b0;
    end else begin
      write[0]    <= 1'b0;
      write[1]    <= 1'b0;
      w_data[0]   <= 64'b0;
      w_data[1]   <= 64'b0;

      //------------------------------------------
      // Previous (ENGINE RX FIFO) frame handling
      //------------------------------------------

      if (i_dispatch_packet_read_discard) begin
        $display("%s:%0d i_dispatch_packet_read_discard", `__FILE__, `__LINE__);
        mem_state[ ~ current_mem] <= STATE_EMPTY;
        fifo_empty <= 'b1;
      end else begin
        case (mem_state[ ~ current_mem])
          STATE_FIFO_OUT_INIT_0:
            begin
              if (i_dispatch_fifo_rd_start) begin
                mem_state[ ~ current_mem] <= STATE_FIFO_OUT_INIT_1;
              end
              r_addr <= 0;
              fifo_empty  <= 'b0;
            end
          STATE_FIFO_OUT_INIT_1:
            begin
              mem_state[ ~ current_mem] <= STATE_FIFO_OUT;
              r_addr <= 1;
              fifo_rd_data <= 0;
            end
          STATE_FIFO_OUT:
            begin
              fifo_rd_data <= r_data[ ~ current_mem ];
              fifo_rd_valid <= 1;
              if (r_addr == counter[ ~ current_mem]) begin
                mem_state[ ~ current_mem] <= STATE_FIFO_OUT_FIN_0;
              end else begin
                r_addr <= r_addr + 1;
              end
            end
          STATE_FIFO_OUT_FIN_0:
            begin
              fifo_rd_data <= r_data[ ~ current_mem ];
              fifo_rd_valid <= 1;
              mem_state[ ~ current_mem] <= STATE_FIFO_OUT_FIN_1;
              $display("%s:%0d Emit: %h ", `__FILE__, `__LINE__, r_data[ ~ current_mem ]);
            end
          STATE_FIFO_OUT_FIN_1:
            begin
              //Remain here until i_dispatch_packet_read_discard (above) takes us out
              fifo_rd_valid <= 0;
              fifo_empty <= 'b1;
            end
          default: ;
        endcase
      end

      //------------------------------------------
      // Current (MAC RX) frame handling
      //------------------------------------------

      if (i_rx_bad_frame) begin
         mem_state[current_mem]  <= STATE_EMPTY;
         w_addr[current_mem]     <= 'b0;
         counter[current_mem]    <= 'b0;
         data_valid[current_mem] <= 'b0;
       end else begin
         //$display("%s:%0d Current mem: %h Current state: %h RxDV: %h", `__FILE__, `__LINE__, current_mem, mem_state[current_mem], i_rx_good_frame);
         case (mem_state[current_mem])
           STATE_EMPTY:
             if (detect_start_of_frame) begin
               mem_state[current_mem] <= STATE_HAS_DATA;
             end
           STATE_HAS_DATA:
             begin
               if (i_rx_good_frame) begin
                 $display("%s:%0d data_valid: %h (%b)", `__FILE__, `__LINE__, i_rx_data_valid, i_rx_data_valid);
                 data_valid[current_mem] <= i_rx_data_valid;
                 mem_state[current_mem] <= STATE_PACKET_RECEIVED;
               end
             end
           STATE_PACKET_RECEIVED:
             if (mem_state[ ~ current_mem] == STATE_EMPTY) begin
               mem_state[current_mem] <= STATE_FIFO_OUT_INIT_0;
               current_mem <= ~ current_mem;
             end
           default:
             mem_state[current_mem] <= STATE_EMPTY;
          endcase

          if (i_rx_data_valid != 'b0) begin

            case (mem_state[current_mem])
              STATE_EMPTY:
                begin
                  write[current_mem]   <= 1'b1;
                  w_addr[current_mem]  <= 'b0;
                  w_data[current_mem]  <= mac_rx_corrected; // i_rx_data but last word shifted logically correct
                  counter[current_mem] <= 'b0;
                end
              STATE_HAS_DATA:
                if (counter[current_mem] != ~ 'b0) begin
                  write[current_mem]   <= 1'b1;
                  w_addr[current_mem]  <= counter[current_mem] + 1;
                  w_data[current_mem]  <= mac_rx_corrected; // i_rx_data but last word shifted logically correct
                  counter[current_mem] <= counter[current_mem] + 1;
                end // not buffer overrun
              default: ;
            endcase

          end //rx_data_valid
        end // not bad frame
    end //posedge i_clk
  end //always begin

  if (DEBUG>0) begin
    always @*
      $display("%s:%0d mem_state[0]: %h", `__FILE__, `__LINE__, mem_state[0]);
    always @*
      $display("%s:%0d mem_state[1]: %h", `__FILE__, `__LINE__, mem_state[1]);
    always @*
      $display("%s:%0d current_mem: %h", `__FILE__, `__LINE__, current_mem);
  end
endmodule