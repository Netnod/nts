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

module nts_parser_ctrl #(
  parameter ADDR_WIDTH = 10,
  parameter ACCESS_PORT_WIDTH = 64
) (
  input  wire                    i_areset, // async reset
  input  wire                    i_clk,
  input  wire                    i_clear,
  input  wire                    i_process_initial,
  input  wire              [7:0] i_last_word_data_valid,
  input  wire             [63:0] i_data,

  input  wire                         i_access_port_wait,
  output wire      [ADDR_WIDTH+3-1:0] o_access_port_addr,
  output wire                   [2:0] o_access_port_wordsize,
  output wire                         o_access_port_rd_en,
  input  wire                         i_access_port_rd_dv,
  input  wire [ACCESS_PORT_WIDTH-1:0] i_access_port_rd_data,

  output wire o_detect_unique_identifier,
  output wire o_detect_nts_cookie,
  output wire o_detect_nts_cookie_placeholder,
  output wire o_detect_nts_authenticator
);

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------

//  localparam IP_OPCODE_WIDTH = 1;

//  localparam [IP_OPCODE_WIDTH-1:0] OPCODE_GET_OFFSET_UDP_DATA = 'b0;
//  localparam [IP_OPCODE_WIDTH-1:0] OPCODE_GET_LENGTH_UDP      = 'b1;
//  localparam [IP_OPCODE_WIDTH-1:0] OPCODE_FIRST               = OPCODE_GET_OFFSET_UDP_DATA;
//  localparam [IP_OPCODE_WIDTH-1:0] OPCODE_LAST                = OPCODE_GET_LENGTH_UDP;

  localparam [15:0] TAG_UNIQUE_IDENTIFIER      = 'h0104;
  localparam [15:0] TAG_NTS_COOKIE             = 'h0204;
  localparam [15:0] TAG_NTS_COOKIE_PLACEHOLDER = 'h0304;
  localparam [15:0] TAG_NTS_AUTHENTICATOR      = 'h0404;

  localparam STATE_IDLE                  = 4'h0;
  localparam STATE_COPY                  = 4'h1;
//  localparam STATE_EXTRACT_FROM_IP       = 4'h2;
  localparam STATE_LENGTH_CHECKS         = 4'h3;
  localparam STATE_EXTRACT_EXT_FROM_RAM  = 4'h4;
  localparam STATE_EXTENSIONS_EXTRACTED  = 4'h5;
  localparam STATE_ERROR_GENERAL         = 4'hf;

  localparam NTP_EXTENSION_BITS          = 4;
  localparam NTP_EXTENSION_FIELDS        = (1<<NTP_EXTENSION_BITS);

  localparam [15:0] E_TYPE_IPV4 =  16'h08_00;
  localparam [15:0] E_TYPE_IPV6 =  16'h86_DD;

  localparam [3:0] IP_V4        =  4'h4;
  localparam [3:0] IP_V6        =  4'h6;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg                         access_port_addr_we;
  reg      [ADDR_WIDTH+3-1:0] access_port_addr_new;
  reg      [ADDR_WIDTH+3-1:0] access_port_addr_reg;
  reg                         access_port_rd_en_we;
  reg                         access_port_rd_en_new;
  reg                         access_port_rd_en_reg;
  reg                         access_port_wordsize_we;
  reg                   [2:0] access_port_wordsize_new;
  reg                   [2:0] access_port_wordsize_reg;

  reg                         state_we;
  reg                   [3:0] state_new;
  reg                   [3:0] state_reg;

  reg                         word_counter_we;
  reg        [ADDR_WIDTH-1:0] word_counter_new;
  reg        [ADDR_WIDTH-1:0] word_counter_reg;

  reg                         last_bytes_we;
  reg                   [3:0] last_bytes_new;
  reg                   [3:0] last_bytes_reg;

//  reg                         read_opcode_we;
//  reg   [IP_OPCODE_WIDTH-1:0] read_opcode_new;
//  reg   [IP_OPCODE_WIDTH-1:0] read_opcode_reg;


  reg                          memory_bound_we;
  reg       [ADDR_WIDTH+3-1:0] memory_bound_new;
  reg       [ADDR_WIDTH+3-1:0] memory_bound_reg;

  reg                          memory_address_we;
  reg       [ADDR_WIDTH+3-1:0] memory_address_new;
  reg       [ADDR_WIDTH+3-1:0] memory_address_reg;
  reg       [ADDR_WIDTH+3-1:0] memory_address_next_reg;
  reg                          memory_address_failure_reg;
  reg                          memory_address_lastbyte_read_reg;

  reg                   [47:0] previous_i_data_reg; //We receive i_data one cycle before process signal
  reg                          ipdecode_ethernet_protocol_we;
  reg                   [15:0] ipdecode_ethernet_protocol_new;
  reg                   [15:0] ipdecode_ethernet_protocol_reg;
  reg                          ipdecode_ip_version_we;
  reg                    [3:0] ipdecode_ip_version_new;
  reg                    [3:0] ipdecode_ip_version_reg;
  reg                          ipdecode_ip4_ihl_we;
  reg                    [3:0] ipdecode_ip4_ihl_new;
  reg                    [3:0] ipdecode_ip4_ihl_reg;

  reg                          ipdecode_offset_ntp_ext_we;
  reg       [ADDR_WIDTH+3-1:0] ipdecode_offset_ntp_ext_new;
  reg       [ADDR_WIDTH+3-1:0] ipdecode_offset_ntp_ext_reg;
  reg                          ipdecode_udp_length_we;
  reg                   [15:0] ipdecode_udp_length_new;
  reg                   [15:0] ipdecode_udp_length_reg;

  reg                          ntp_extension_counter_we;
  reg [NTP_EXTENSION_BITS-1:0] ntp_extension_counter_new;
  reg [NTP_EXTENSION_BITS-1:0] ntp_extension_counter_reg;

  reg                          ntp_extension_reset;
  reg                          ntp_extension_we;
  reg                          ntp_extension_copied_new;
  reg                          ntp_extension_copied_reg  [0:NTP_EXTENSION_FIELDS-1];
  reg       [ADDR_WIDTH+3-1:0] ntp_extension_addr_new;
  reg       [ADDR_WIDTH+3-1:0] ntp_extension_addr_reg    [0:NTP_EXTENSION_FIELDS-1];
  reg                   [15:0] ntp_extension_tag_new;
  reg                   [15:0] ntp_extension_tag_reg     [0:NTP_EXTENSION_FIELDS-1];
  reg                   [15:0] ntp_extension_length_new;
  reg                   [15:0] ntp_extension_length_reg  [0:NTP_EXTENSION_FIELDS-1];

  reg                          detect_unique_identifier_reg;
  reg                          detect_nts_cookie_reg;
  reg                          detect_nts_cookie_placeholder_reg;
  reg                          detect_nts_authenticator_reg;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  wire        detect_ipv4;
  wire        detect_ipv4_bad;
//  wire [31:0] ipdecode_read_data_wire;
  wire        detect_ipv6;

  //----------------------------------------------------------------
  // Connectivity for ports etc.
  //----------------------------------------------------------------

  assign detect_ipv4     = (ipdecode_ethernet_protocol_reg == E_TYPE_IPV4) && (ipdecode_ip_version_reg == IP_V4);
  assign detect_ipv4_bad = detect_ipv4 && ipdecode_ip4_ihl_reg != 5;

  assign detect_ipv6     = (ipdecode_ethernet_protocol_reg == E_TYPE_IPV6) && (ipdecode_ip_version_reg == IP_V6);

  assign o_access_port_addr     = access_port_addr_reg;
  assign o_access_port_rd_en    = access_port_rd_en_reg;
  assign o_access_port_wordsize = access_port_wordsize_reg;

  assign o_detect_unique_identifier      = detect_unique_identifier_reg;
  assign o_detect_nts_cookie             = detect_nts_cookie_reg;
  assign o_detect_nts_cookie_placeholder = detect_nts_cookie_placeholder_reg;
  assign o_detect_nts_authenticator      = detect_nts_authenticator_reg;

  //----------------------------------------------------------------
  // Functions and Tasks
  //----------------------------------------------------------------

  function func_address_within_memory_bounds (
    input [ADDR_WIDTH+3-1:0] address,
    input [ADDR_WIDTH+3-1:0] bytes
  );
    reg [ADDR_WIDTH+4-1:0] acc;
    begin
      acc = {1'b0, address} + {1'b0, bytes} - 1;

      if (acc[ADDR_WIDTH+4-1] == 'b1)
        func_address_within_memory_bounds  = 'b0;
      else if (acc[ADDR_WIDTH+3-1:0] >= memory_bound_reg)
        func_address_within_memory_bounds  = 'b0;
      else
        func_address_within_memory_bounds  = 'b1;
    end
  endfunction

  task task_incremment_address_for_nts_extension;
    input  [ADDR_WIDTH+3-1:0] address_in;
    input              [15:0] ntp_extension_length_value;
    output [ADDR_WIDTH+3-1:0] address_out;
    output                    failure;
    output                    lastbyteread;
    reg                [16:0] acc;
    begin
      lastbyteread                          = 'b0;
      failure                               = 'b1;
      address_out                           = address_in;
      if (ntp_extension_length_value[1:0] == 'b0) begin //All extension fields are zero-padded to a word (four octets) boundary.
        acc                                 = 0;
        acc[ADDR_WIDTH+3-1:0]               = address_in;
        acc                                 = acc + {1'b0, ntp_extension_length_value};
        //$display("%s:%0d address_in=%h (%0d) length=%d (%0d) acc=%h (%0d) memory_bound=%h (%d)",`__FILE__,`__LINE__, address_in, address_in, ntp_extension_length_value, ntp_extension_length_value, acc, acc, memory_bound, memory_bound);
        if (acc[16:ADDR_WIDTH+4-1] == 'b0) begin
          if (acc[ADDR_WIDTH+3-1:0] <= memory_bound_reg) begin
            failure                           = 'b0;
            address_out                       = acc[ADDR_WIDTH+3-1:0];
            if (acc[ADDR_WIDTH+3-1:0] == memory_bound_reg) begin
              lastbyteread                    = 'b1;
            end
          end
        end
      end
    end
  endtask

  //----------------------------------------------------------------
  // Register Update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active high reset.
  //----------------------------------------------------------------

  always @ (posedge i_clk, posedge i_areset)
  begin : reg_update
    if (i_areset == 1'b1) begin
      access_port_addr_reg      <= 'b0;
      access_port_rd_en_reg     <= 'b0;
      access_port_wordsize_reg  <= 'b0;
      ipdecode_offset_ntp_ext_reg     <= 'b0;
      ipdecode_udp_length_reg   <= 'b0;
      last_bytes_reg            <= 'b0;
      memory_address_reg        <= 'b0;
      memory_bound_reg          <= 'b0;
      ntp_extension_counter_reg <= 'b0;
      previous_i_data_reg       <= 'b0;
//      read_opcode_reg           <= OPCODE_FIRST;
      state_reg                 <= 'b0;
      word_counter_reg          <= 'b0;
      begin : ntp_extension_reset_async
        integer i;
        for (i=0; i <= NTP_EXTENSION_FIELDS-1; i=i+1) begin
          ntp_extension_copied_reg [i] <= 'b0;
          ntp_extension_addr_reg   [i] <= 'b0;
          ntp_extension_tag_reg    [i] <= 'b0;
          ntp_extension_length_reg [i] <= 'b0;
        end
      end
    end else begin
      previous_i_data_reg  <= i_data[47:0];

      if (access_port_addr_we)
        access_port_addr_reg <= access_port_addr_new;

      if (access_port_rd_en_we)
        access_port_rd_en_reg <= access_port_rd_en_new;

      if (access_port_wordsize_we)
        access_port_wordsize_reg <= access_port_wordsize_new;

      if (ipdecode_ethernet_protocol_we)
        ipdecode_ethernet_protocol_reg <= ipdecode_ethernet_protocol_new;

      if (ipdecode_ip_version_we)
        ipdecode_ip_version_reg <= ipdecode_ip_version_new;

      if (ipdecode_ip4_ihl_we)
        ipdecode_ip4_ihl_reg <= ipdecode_ip4_ihl_new;

      if (ipdecode_offset_ntp_ext_we)
        ipdecode_offset_ntp_ext_reg <= ipdecode_offset_ntp_ext_new;

      if (ipdecode_udp_length_we)
        ipdecode_udp_length_reg <= ipdecode_udp_length_new;

      if (last_bytes_we)
        last_bytes_reg <= last_bytes_new;

      if (memory_address_we)
        memory_address_reg <= memory_address_new;

      if (memory_bound_we)
        memory_bound_reg <= memory_bound_new;

      if (ntp_extension_reset) begin : ntp_extension_reset_sync
        integer i;
        for (i=0; i <= NTP_EXTENSION_FIELDS-1; i=i+1) begin
          ntp_extension_copied_reg [i] <= 'b0;
        end
      end else if (ntp_extension_we)
        ntp_extension_copied_reg [ntp_extension_counter_reg] <= ntp_extension_copied_new;

      if (ntp_extension_we) begin
        $display("%s:%0d ntp_ext[%0d] = tag:%h,length:%h,addr:%h", `__FILE__, `__LINE__, ntp_extension_counter_reg, ntp_extension_tag_new, ntp_extension_length_new, ntp_extension_addr_new);
        ntp_extension_addr_reg   [ntp_extension_counter_reg] <= ntp_extension_addr_new;
        ntp_extension_tag_reg    [ntp_extension_counter_reg] <= ntp_extension_tag_new;
        ntp_extension_length_reg [ntp_extension_counter_reg] <= ntp_extension_length_new;
      end

      if (ntp_extension_counter_we)
        ntp_extension_counter_reg <= ntp_extension_counter_new;

      if (state_we)
        state_reg <= state_new;

      if (word_counter_we)
        word_counter_reg <= word_counter_new;
    end
  end

  //----------------------------------------------------------------
  // Memory bounds calculation
  // Counts exact number of bytes recieved by parser
  //----------------------------------------------------------------

  always @*
  begin : memory_bounds_calc
    reg [ADDR_WIDTH+3-1:0] bounds;
    memory_bound_we   = 'b0;
    bounds            = 0;
    bounds[3:0]       = last_bytes_reg;
    bounds            = bounds + { word_counter_reg, 3'b000};
    memory_bound_new  = bounds;
    if (memory_bound_reg != bounds)
      memory_bound_we = 'b1;
  end

  //----------------------------------------------------------------
  // Word counter
  // Counts number of words recieved by parser.
  // Memory bounds calculation depends on this counter.
  //----------------------------------------------------------------

  always @*
  begin : word_counter
    word_counter_we  = 'b0;
    word_counter_new = 'b0;
    case (state_reg)
      STATE_IDLE:
        if (i_process_initial)
          word_counter_we = 'b1;
      STATE_COPY:
        if (i_process_initial) begin
          word_counter_we  = 'b1;
          word_counter_new = word_counter_reg + 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Last word data valid byte counter
  // Counts number of bytes in last word recieved by parser.
  // Memory bounds calculation depends on this counter.
  //----------------------------------------------------------------

  always @*
  begin : convert_lwdv_to_byte_counter
    last_bytes_we = 'b0;

    case (i_last_word_data_valid)
      8'b00000001: last_bytes_new = 1;
      8'b00000011: last_bytes_new = 2;
      8'b00000111: last_bytes_new = 3;
      8'b00001111: last_bytes_new = 4;
      8'b00011111: last_bytes_new = 5;
      8'b00111111: last_bytes_new = 6;
      8'b01111111: last_bytes_new = 7;
      8'b11111111: last_bytes_new = 8;
      default: last_bytes_new = 'b0; //illegal value
    endcase

    case (state_reg)
      STATE_IDLE:
        if (i_process_initial)
          last_bytes_we = 'b1;
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // NTP Extension field control
  // Writes to NTP Extension fields upon i_access_port receving
  // values from Rx Buffer.
  //----------------------------------------------------------------

  always @*
  begin : ntp_extension_field_control

    ntp_extension_we           = 'b0;
    ntp_extension_reset        = 'b0;
    ntp_extension_addr_new     = 'b0;
    ntp_extension_copied_new   = 'b0;
    ntp_extension_length_new   = 'b0;
    ntp_extension_tag_new      = 'b0;

    if (i_clear)
      ntp_extension_reset      = 'b1;

    if (state_reg == STATE_EXTRACT_EXT_FROM_RAM && ntp_extension_copied_reg[ntp_extension_counter_reg] == 'b0 && i_access_port_rd_dv) begin
      ntp_extension_we         = 'b1;
      ntp_extension_addr_new   = memory_address_reg;
      ntp_extension_copied_new = 'b1;
      ntp_extension_length_new = i_access_port_rd_data[15:0];
      ntp_extension_tag_new    = i_access_port_rd_data[31:16];
    end
  end

  always @*
  begin
    access_port_rd_en_we       = 'b0;
    access_port_rd_en_new      = 'b0;
    access_port_wordsize_we    = 'b0;
    access_port_wordsize_new   = 'b0;
    access_port_addr_we        = 'b0;
    access_port_addr_new       = 'b0;

    if (i_clear) begin : SYNC_RESET_FROM_TOP_MODULE
      access_port_addr_we      = 'b1; //write zeros
      access_port_rd_en_we     = 'b1;
      access_port_wordsize_we  = 'b1;

    end else begin
      if (access_port_rd_en_reg == 'b1)
        access_port_rd_en_we  = 'b1; //reset read signal if high

      if (state_reg == STATE_EXTRACT_EXT_FROM_RAM && ntp_extension_copied_reg[ntp_extension_counter_reg] == 'b0) begin
        //$display("%s:%0d i_access_port_rd_dv=%0d i_access_port_wait=%0d", `__FILE__, `__LINE__, i_access_port_rd_dv, i_access_port_wait);
        if (i_access_port_rd_dv) begin
          ;
        end else if (i_access_port_wait == 'b0) begin
          access_port_addr_we      = 'b1;
          access_port_addr_new     = memory_address_reg;
          access_port_rd_en_we     = 'b1;
          access_port_rd_en_new    = 'b1;
          access_port_wordsize_we  = 'b1; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
          access_port_wordsize_new = 2; //0: 8bit, 1: 16bit, 2: 32bit, 3: 64bit
        end
      end
    end
  end

  //----------------------------------------------------------------
  // Memory Address calculator
  // Updates memory address reg.
  //   Initilize to NTP Extension start calulcated by IP decode.
  //   Increments by NTP Extension length
  //   Until all bytes consumed.
  //----------------------------------------------------------------

  always @*
  begin : memory_address_calculator
    memory_address_we    = 'b0;
    memory_address_new   = 'b0;

    if (state_reg == STATE_LENGTH_CHECKS) begin
      memory_address_we  = 'b1;
      memory_address_new = ipdecode_offset_ntp_ext_reg;
    end

    if (state_reg == STATE_EXTRACT_EXT_FROM_RAM) begin
      task_incremment_address_for_nts_extension(
           memory_address_reg, ntp_extension_length_reg[ntp_extension_counter_reg], /* IN */
           memory_address_next_reg, memory_address_failure_reg, memory_address_lastbyte_read_reg /*OUT*/);

      if (ntp_extension_copied_reg[ntp_extension_counter_reg] && memory_address_failure_reg == 'b0 && memory_address_lastbyte_read_reg == 'b0 && ntp_extension_counter_reg!=NTP_EXTENSION_FIELDS-1) begin
        memory_address_we  = 'b1;
        memory_address_new = memory_address_next_reg;
      end

    end else begin
      memory_address_we  = 'b1;
      memory_address_next_reg = 0;
      memory_address_failure_reg = 1;
      memory_address_lastbyte_read_reg = 1;
    end
  end

  //----------------------------------------------------------------
  // NTP Extension counter control
  // Increments 0, 1, ..., NTP_EXTENSION_FIELDS-1
  //   for each NTP Extension read
  //----------------------------------------------------------------

  always @*
  begin : ntp_extension_counter_control
    ntp_extension_counter_we  = 'b0;
    ntp_extension_counter_new = 'b0;
    case (state_reg)
      STATE_IDLE:
        if (i_process_initial) begin
          ntp_extension_counter_we  = 'b1;
          ntp_extension_counter_new = 'b0;
        end
      STATE_EXTRACT_EXT_FROM_RAM:
        if (ntp_extension_copied_reg[ntp_extension_counter_reg] && memory_address_failure_reg == 'b0 && memory_address_lastbyte_read_reg == 'b0 && ntp_extension_counter_reg!=NTP_EXTENSION_FIELDS-1) begin
          ntp_extension_counter_we  = 'b1;
          ntp_extension_counter_new = ntp_extension_counter_reg + 1;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Finite State Machine
  // Overall functionallitty control
  //----------------------------------------------------------------

  always @*
  begin : FSM
    state_we   = 'b0;
    state_new  = STATE_IDLE;

    if (i_clear)
      state_we  = 'b1;

    else case (state_reg)
      STATE_IDLE:
          if (i_process_initial) begin
            state_we  = 'b1;
            state_new = STATE_COPY;
            case (i_last_word_data_valid)
              8'b00000001: ;
              8'b00000011: ;
              8'b00000111: ;
              8'b00001111: ;
              8'b00011111: ;
              8'b00111111: ;
              8'b01111111: ;
              8'b11111111: ;
              default: state_new = STATE_ERROR_GENERAL;
            endcase
          end
       STATE_COPY:
         if (i_process_initial == 1'b0) begin
          state_we  = 'b1;
          state_new = STATE_LENGTH_CHECKS;
        end
      STATE_LENGTH_CHECKS:
        begin
          state_we = 'b1;
          if (ipdecode_udp_length_reg < ( 8 /* UDP Header */ + 6*8 /* Minimum NTP Payload */ + 8 /* Smallest NTP extension */ ))
            state_new = STATE_ERROR_GENERAL;
          else if (ipdecode_udp_length_reg > 65507 /* IPv4 maximum UDP packet size */)
            state_new  = STATE_ERROR_GENERAL;
          else if (ipdecode_udp_length_reg[1:0] != 0) /* NTP packets are 7*8 + M(4+4n), always 4 byte aligned */
            state_new  = STATE_ERROR_GENERAL;
          else if (func_address_within_memory_bounds (ipdecode_offset_ntp_ext_reg, 4) == 'b0)
            state_new  = STATE_ERROR_GENERAL;
          else
            state_new  = STATE_EXTRACT_EXT_FROM_RAM;
        end
      STATE_EXTRACT_EXT_FROM_RAM:
        if (ntp_extension_copied_reg[ntp_extension_counter_reg] == 'b1) begin
          if (memory_address_failure_reg == 'b1) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
            $display("%s:%0d memory_address_failure_reg %h",`__FILE__,`__LINE__, memory_address_failure_reg);
          end else if (memory_address_lastbyte_read_reg == 1'b1) begin
            state_we  = 'b1;
            state_new = STATE_EXTENSIONS_EXTRACTED;
          end if (ntp_extension_counter_reg==NTP_EXTENSION_FIELDS-1) begin
            state_we  = 'b1;
            state_new = STATE_ERROR_GENERAL;
            $display("%s:%0d ",`__FILE__,`__LINE__);
          end
        end
      STATE_ERROR_GENERAL:
        begin
          state_we  = 'b1;
          state_new = STATE_IDLE;
        end
      default:
        begin
          state_we  = 'b1;
          state_new = STATE_IDLE;
        end
    endcase
  end

  //----------------------------------------------------------------
  // IP Decode
  //----------------------------------------------------------------

  always @*
  begin
    ipdecode_ethernet_protocol_we  = 'b0;
    ipdecode_ethernet_protocol_new = 'b0;
    ipdecode_ip_version_we         = 'b0;
    ipdecode_ip_version_new        = 'b0;
    ipdecode_ip4_ihl_we            = 'b0;
    ipdecode_ip4_ihl_new           = 'b0;
    ipdecode_offset_ntp_ext_we     = 'b0;
    ipdecode_offset_ntp_ext_new    = 'b0;
    ipdecode_udp_length_we         = 'b0;
    ipdecode_udp_length_new        = 'b0;

    if (i_clear) begin
      ipdecode_ethernet_protocol_we  = 'b1;
      ipdecode_ip_version_we         = 'b1;
      ipdecode_ip4_ihl_we            = 'b1;
      ipdecode_offset_ntp_ext_we     = 'b1;
      ipdecode_udp_length_we         = 'b1;

    end else if (i_process_initial) begin

      if (word_counter_reg == 0) begin
        ipdecode_ethernet_protocol_we  = 'b1;
        ipdecode_ethernet_protocol_new = previous_i_data_reg[31:16];
        ipdecode_ip_version_we         = 'b1;
        ipdecode_ip_version_new        = previous_i_data_reg[15:12];
        ipdecode_ip4_ihl_we            = 'b1;
        ipdecode_ip4_ihl_new           = previous_i_data_reg[11:8];

      end else if (detect_ipv4 && ipdecode_ip4_ihl_reg == 5) begin
        ipdecode_offset_ntp_ext_we                    = 'b1;
        ipdecode_offset_ntp_ext_new[ADDR_WIDTH+3-1:3] = 5+6;
        ipdecode_offset_ntp_ext_new[2:0]              = 2;

        if (word_counter_reg == 3) begin
          ipdecode_udp_length_we   = 'b1;
          ipdecode_udp_length_new  = previous_i_data_reg[15:0];
        end
      end else if (detect_ipv6) begin
        ipdecode_offset_ntp_ext_we                    = 'b1;
        ipdecode_offset_ntp_ext_new[ADDR_WIDTH+3-1:3] = 7+6;
        ipdecode_offset_ntp_ext_new[2:0]              = 6;
        if (word_counter_reg == 6) begin
          ipdecode_udp_length_we   = 'b1;
          ipdecode_udp_length_new  = previous_i_data_reg[47:32];
        end
      end
    end
  end

  //----------------------------------------------------------------
  // Output detection signals
  // Supports debugging/simulations and prevents reg optimizations
  //----------------------------------------------------------------

  always @*
  begin : output_detection_signals
    integer i;
    detect_unique_identifier_reg      = 'b0;
    detect_nts_cookie_reg             = 'b0;
    detect_nts_cookie_placeholder_reg = 'b0;
    detect_nts_authenticator_reg      = 'b0;
    for (i = 0; i < NTP_EXTENSION_FIELDS; i = i + 1) begin
      if (ntp_extension_copied_reg[i]) begin

        if (ntp_extension_tag_reg[i]==TAG_UNIQUE_IDENTIFIER)
          detect_unique_identifier_reg       = 'b1;

        if (ntp_extension_tag_reg[i]==TAG_NTS_COOKIE)
           detect_nts_cookie_reg             = 'b1;

        if (ntp_extension_tag_reg[i]==TAG_NTS_COOKIE_PLACEHOLDER)
           detect_nts_cookie_placeholder_reg = 'b1;

        if (ntp_extension_tag_reg[i]==TAG_NTS_AUTHENTICATOR)
           detect_nts_authenticator_reg      = 'b1;
      end
    end
  end

  //----------------------------------------------------------------
  // Debug messages
  // Only emits messages that are useful for running local debug
  //----------------------------------------------------------------

  always @ (posedge i_clk, posedge i_areset)
  begin : debug_messages
    if (i_areset == 1'b1) begin
      ;
    end else begin
      case (state_reg)
        STATE_IDLE: ;
        STATE_COPY: ;
        STATE_LENGTH_CHECKS: ;
        STATE_EXTRACT_EXT_FROM_RAM: ;
        STATE_ERROR_GENERAL: $display("%s:%0d warning: error",`__FILE__,`__LINE__);
        default: $display("%s:%0d warning: state %0d not implemented",`__FILE__,`__LINE__, state_reg);
      endcase
    end
  end
endmodule
