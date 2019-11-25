module nts_top #(
  parameter ENGINES         = 1, //Beware: only ENGINES=1 supported for now
  parameter DEBUG           = 1,
  parameter ADDR_WIDTH      = 7,
  parameter API_ADDR_WIDTH  = 12,
  parameter API_RW_WIDTH    = 32,
  parameter MAC_DATA_WIDTH  = 64
) (
  input  wire i_areset, // async reset
  input  wire i_clk,

  input  wire                [7:0] i_mac_rx_data_valid,
  input  wire [MAC_DATA_WIDTH-1:0] i_mac_rx_data,
  input  wire                      i_mac_rx_bad_frame,
  input  wire                      i_mac_rx_good_frame,

  //Engine API interface. TODO: replace with SPI interface to reduce width when many concurrent lines
  input  wire                  [ENGINES - 1:0] i_api_cs,
  input  wire                  [ENGINES - 1:0] i_api_we,
  input  wire [API_ADDR_WIDTH * ENGINES - 1:0] i_api_address,
  input  wire [API_RW_WIDTH   * ENGINES - 1:0] i_api_write_data,
  output wire [API_RW_WIDTH   * ENGINES - 1:0] o_api_read_data,

  //Dispatcher API interface. TODO: replace with SPI interface.
  input  wire                        i_api_dispatcher_cs,
  input  wire                        i_api_dispatcher_we,
  input  wire [API_ADDR_WIDTH - 1:0] i_api_dispatcher_address,
  input  wire   [API_RW_WIDTH - 1:0] i_api_dispatcher_write_data,
  output wire   [API_RW_WIDTH - 1:0] o_api_dispatcher_read_data
);
  localparam LAST_DATA_VALID_WIDTH = 8;

  reg [63:0] ntp_time_DUMMY;

  wire                  [ENGINES - 1:0] api_cs;
  wire                  [ENGINES - 1:0] api_we;
  wire [API_ADDR_WIDTH * ENGINES - 1:0] api_address;
  wire   [API_RW_WIDTH * ENGINES - 1:0] api_write_data;
  wire   [API_RW_WIDTH * ENGINES - 1:0] api_read_data;

  wire [ENGINES-1:0] engine_busy;
  wire [ENGINES-1:0] engine_dispatch_rx_packet_read_discard;
  wire [ENGINES-1:0] engine_dispatch_rx_fifo_rd_start;
  wire [ENGINES-1:0] engine_debug_detect_nts_cookie;
  wire [ENGINES-1:0] engine_debug_detect_nts_cookie_placeholder;
  wire [ENGINES-1:0] engine_debug_detect_unique_identifier;
  wire [ENGINES-1:0] engine_debug_detect_nts_authenticator;

  wire [LAST_DATA_VALID_WIDTH * ENGINES - 1 : 0] dispatch_engine_rx_data_last_valid;
  wire                         [ENGINES - 1 : 0] dispatch_engine_rx_fifo_empty;
  wire                         [ENGINES - 1 : 0] dispatch_engine_rx_packet_available;
  wire                         [ENGINES - 1 : 0] dispatch_engine_rx_fifo_rd_valid;
  wire        [MAC_DATA_WIDTH * ENGINES - 1 : 0] dispatch_engine_rx_fifo_rd_data;

  wire                                     [6:0] o_dispatch_counter; //TODO remove

  wire                          o_dispatch_tx_packet_available_DUMMY;
  reg                           i_dispatch_tx_packet_read_DUMMY;
  wire                          o_dispatch_tx_fifo_empty_DUMMY;
  reg                           i_dispatch_tx_fifo_rd_en_DUMMY;
  wire [MAC_DATA_WIDTH - 1 : 0] o_dispatch_tx_fifo_rd_data_DUMMY;
  wire                    [3:0] o_dispatch_tx_bytes_last_word_DUMMY;

  wire                          engine_noncegen_get_DUMMY;
  reg                           noncegen_engine_ready_DUMMY;
  reg                    [63:0] noncegen_engine_data_DUMMY;

  assign api_cs = i_api_cs;
  assign api_we = i_api_we;
  assign api_address = i_api_address;
  assign api_write_data = i_api_write_data;

  assign o_api_read_data = api_read_data;

  //----------------------------------------------------------------
  // Dispatcher
  //----------------------------------------------------------------

  nts_dispatcher #(.ADDR_WIDTH(ADDR_WIDTH)) dispatcher (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .i_rx_data_valid(i_mac_rx_data_valid),
    .i_rx_data(i_mac_rx_data),
    .i_rx_bad_frame(i_mac_rx_bad_frame),
    .i_rx_good_frame(i_mac_rx_good_frame),

    .o_dispatch_packet_available(dispatch_engine_rx_packet_available[0]),
    .i_dispatch_packet_read_discard(engine_dispatch_rx_packet_read_discard[0]),
    .o_dispatch_counter(o_dispatch_counter),
    .o_dispatch_data_valid(dispatch_engine_rx_data_last_valid[LAST_DATA_VALID_WIDTH*0+:LAST_DATA_VALID_WIDTH]),
    .o_dispatch_fifo_empty(dispatch_engine_rx_fifo_empty[0]),
    .i_dispatch_fifo_rd_start(engine_dispatch_rx_fifo_rd_start[0]),
    .o_dispatch_fifo_rd_valid(dispatch_engine_rx_fifo_rd_valid[0]),
    .o_dispatch_fifo_rd_data(dispatch_engine_rx_fifo_rd_data[MAC_DATA_WIDTH*0+:MAC_DATA_WIDTH]),

    .i_api_cs(i_api_dispatcher_cs),
    .i_api_we(i_api_dispatcher_we),
    .i_api_address(i_api_dispatcher_address),
    .i_api_write_data(i_api_dispatcher_write_data),
    .o_api_read_data(o_api_dispatcher_read_data)
  );

  if (DEBUG) begin
    always @*
      $display("%s:%0d  o_dispatch_counter=%h (ignored)",  `__FILE__, `__LINE__, o_dispatch_counter);
  end

  //----------------------------------------------------------------
  // NTS Engine(s)
  //----------------------------------------------------------------

/*
  genvar engine_index;
  generate
    for (engine_index = 0; engine_index < ENGINES; engine_index = engine_index + 1) begin
*/
    localparam engine_index = 0;

      nts_engine #(.ADDR_WIDTH(ADDR_WIDTH)) engine (
        .i_areset(i_areset),
        .i_clk(i_clk),

        .i_ntp_time(ntp_time_DUMMY),

        .o_busy(engine_busy[engine_index]),

        .i_dispatch_rx_packet_available(dispatch_engine_rx_packet_available[engine_index]),
        .o_dispatch_rx_packet_read_discard(engine_dispatch_rx_packet_read_discard[engine_index]),
        .i_dispatch_rx_data_last_valid(dispatch_engine_rx_data_last_valid[LAST_DATA_VALID_WIDTH*engine_index+:LAST_DATA_VALID_WIDTH]),
        .i_dispatch_rx_fifo_empty(dispatch_engine_rx_fifo_empty[engine_index]),
        .o_dispatch_rx_fifo_rd_start(engine_dispatch_rx_fifo_rd_start[engine_index]),
        .i_dispatch_rx_fifo_rd_valid(dispatch_engine_rx_fifo_rd_valid[engine_index]),
        .i_dispatch_rx_fifo_rd_data(dispatch_engine_rx_fifo_rd_data[MAC_DATA_WIDTH*engine_index+:MAC_DATA_WIDTH]),

        .o_dispatch_tx_packet_available(o_dispatch_tx_packet_available_DUMMY),
        .i_dispatch_tx_packet_read(i_dispatch_tx_packet_read_DUMMY),
        .o_dispatch_tx_fifo_empty(o_dispatch_tx_fifo_empty_DUMMY),
        .i_dispatch_tx_fifo_rd_en(i_dispatch_tx_fifo_rd_en_DUMMY),
        .o_dispatch_tx_fifo_rd_data(o_dispatch_tx_fifo_rd_data_DUMMY),
        .o_dispatch_tx_bytes_last_word(o_dispatch_tx_bytes_last_word_DUMMY),

        .i_api_cs(api_cs[engine_index]),
        .i_api_we(api_we[engine_index]),
        .i_api_address(api_address[API_ADDR_WIDTH*engine_index+:API_ADDR_WIDTH]),
        .i_api_write_data(api_write_data[API_RW_WIDTH*engine_index+:API_RW_WIDTH]),
        .o_api_read_data(api_read_data[API_RW_WIDTH*engine_index+:API_RW_WIDTH]),

        .o_noncegen_get(engine_noncegen_get_DUMMY),
        .i_noncegen_data(noncegen_engine_data_DUMMY),
        .i_noncegen_ready(noncegen_engine_ready_DUMMY),

        .o_detect_unique_identifier(engine_debug_detect_unique_identifier[engine_index]),
        .o_detect_nts_cookie(engine_debug_detect_nts_cookie[engine_index]),
        .o_detect_nts_cookie_placeholder(engine_debug_detect_nts_cookie_placeholder[engine_index]),
        .o_detect_nts_authenticator(engine_debug_detect_nts_authenticator[engine_index])
      );

      if (DEBUG) begin
        always @*
          if (engine_busy[engine_index]==1'b0) begin
            $display("%s:%0d detect UI:%b C:%b CP:%b A:%b",  `__FILE__, `__LINE__,
              engine_debug_detect_unique_identifier[engine_index],
              engine_debug_detect_nts_cookie[engine_index],
              engine_debug_detect_nts_cookie_placeholder[engine_index],
              engine_debug_detect_nts_authenticator[engine_index]);
          end
        always @*
          $display("%s:%0d engine.crypto.key_master_reg: %h", `__FILE__, `__LINE__, engine.crypto.key_master_reg);
        always @*
          $display("%s:%0d engine.crypto.key_current_reg: %h", `__FILE__, `__LINE__, engine.crypto.key_current_reg);
        always @*
          $display("%s:%0d engine.crypto.key_c2s_reg: %h", `__FILE__, `__LINE__, engine.crypto.key_c2s_reg);
        always @*
          $display("%s:%0d engine.crypto.key_s2c_reg: %h", `__FILE__, `__LINE__, engine.crypto.key_s2c_reg);
        always @*
          $display("%s:%0d engine.parser.state_reg: %h", `__FILE__, `__LINE__, engine.parser.state_reg);
        always @*
          $display("%s:%0d engine.parser.i_last_word_data_valid: %b", `__FILE__, `__LINE__, engine.parser.i_last_word_data_valid);
        always @*
          $display("%s:%0d engine.parser.word_counter_reg: %h", `__FILE__, `__LINE__, engine.parser.word_counter_reg);
        always @*
          $display("%s:%0d engine.parser.ipdecode_udp_length_reg: %h (%0d)", `__FILE__, `__LINE__, engine.parser.ipdecode_udp_length_reg, engine.parser.ipdecode_udp_length_reg);
        always @*
          $display("%s:%0d engine.parser.detect_ipv4: %b detect_ipv6: %b", `__FILE__, `__LINE__, engine.parser.detect_ipv4, engine.parser.detect_ipv6);
        always @*
          $display("%s:%0d i_dispatch_rx_fifo_rd_data: %h", `__FILE__, `__LINE__, engine.i_dispatch_rx_fifo_rd_data);
        always @*
           $display("%s:%0d engine.i_dispatch_rx_fifo_rd_valid: %h",  `__FILE__, `__LINE__, engine.i_dispatch_rx_fifo_rd_valid);
      end
/*
    end
  endgenerate
*/
  //----------------------------------------------------------------
  // Dummy: TX
  //----------------------------------------------------------------

  reg tx_receiving;

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_dispatch_tx_packet_read_DUMMY <= 'b0;
      i_dispatch_tx_fifo_rd_en_DUMMY  <= 'b0;
      tx_receiving              <= 'b0;

    end else begin
      i_dispatch_tx_packet_read_DUMMY <= 'b0;
      i_dispatch_tx_fifo_rd_en_DUMMY  <= 'b0;
      if (tx_receiving) begin
        if (o_dispatch_tx_fifo_empty_DUMMY) begin
          i_dispatch_tx_packet_read_DUMMY <= 'b1;
          tx_receiving <= 'b0;
        end else begin
          i_dispatch_tx_fifo_rd_en_DUMMY  <= 'b1;
        end
      end else if (o_dispatch_tx_packet_available_DUMMY) begin
        tx_receiving <= 'b1;
      end
    end
  end

  if (DEBUG) begin
    always @*
      if (i_dispatch_tx_packet_read_DUMMY)
       $display("%s:%0d o_dispatch_tx_bytes_last_word_DUMMY=%b (ignored)",  `__FILE__, `__LINE__, o_dispatch_tx_bytes_last_word_DUMMY);
    always @*
      $display("%s:%0d  o_dispatch_tx_fifo_rd_data_DUMMY=%h (ignored)",  `__FILE__, `__LINE__, o_dispatch_tx_fifo_rd_data_DUMMY);
  end

  //----------------------------------------------------------------
  // Dummy: NTP clock
  //----------------------------------------------------------------

  always  @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      ntp_time_DUMMY = 64'h0000_0001_0000_0000;
    end else begin
      ntp_time_DUMMY = ntp_time_DUMMY + 1;
    end
  end

  //----------------------------------------------------------------
  // Dummy: Nonce Generator
  //----------------------------------------------------------------

  reg   [3:0] nonce_delay;

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      noncegen_engine_data_DUMMY <= 64'h0;
      noncegen_engine_ready_DUMMY <= 0;
      nonce_delay <= 0;
    end else begin
      noncegen_engine_ready_DUMMY <= 0;
      if (nonce_delay == 4'hF) begin
        nonce_delay <= 0;
        noncegen_engine_ready_DUMMY <= 1;
        noncegen_engine_data_DUMMY <= noncegen_engine_data_DUMMY + 1;
      end else if (nonce_delay > 0) begin
        nonce_delay <= nonce_delay + 1;
      end else if (engine_noncegen_get_DUMMY) begin
        nonce_delay <= 1;
      end
    end
  end

endmodule
