module nts_top #(
  parameter ENGINES         = 1, //Beware: only ENGINES=1 supported for now
  parameter ADDR_WIDTH      = 8,
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

  input  wire               [63:0] i_ntp_time,

  //Dispatcher API interface. TODO: replace with SPI interface.
  input  wire                        i_api_dispatcher_cs,
  input  wire                        i_api_dispatcher_we,
  input  wire [API_ADDR_WIDTH - 1:0] i_api_dispatcher_address,
  input  wire   [API_RW_WIDTH - 1:0] i_api_dispatcher_write_data,
  output wire   [API_RW_WIDTH - 1:0] o_api_dispatcher_read_data
);
  localparam LAST_DATA_VALID_WIDTH = 8;

  reg               [63:0] ntp_time_reg;
  reg                [7:0] rx_data_valid_reg;
  reg [MAC_DATA_WIDTH-1:0] rx_data_reg;
  reg                      rx_bad_frame_reg;
  reg                      rx_good_frame_reg;

  wire                  [ENGINES - 1:0] api_cs;
  wire                                  api_we;
  wire           [API_ADDR_WIDTH - 1:0] api_address;
  wire             [API_RW_WIDTH - 1:0] api_write_data;
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

  wire                          o_dispatch_tx_packet_available_DUMMY;
  reg                           i_dispatch_tx_packet_read_DUMMY;
  wire                          o_dispatch_tx_fifo_empty_DUMMY;
  reg                           i_dispatch_tx_fifo_rd_en_DUMMY;
  wire [MAC_DATA_WIDTH - 1 : 0] o_dispatch_tx_fifo_rd_data_DUMMY;
  wire                    [3:0] o_dispatch_tx_bytes_last_word_DUMMY;

  wire                          engine_noncegen_get_DUMMY;
  reg                           noncegen_engine_ready_DUMMY;
  reg                    [63:0] noncegen_engine_data_DUMMY;

  //----------------------------------------------------------------
  // Buffer inputs
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  if (i_areset) begin
    ntp_time_reg      <= 0;
    rx_data_valid_reg <= 0;
    rx_data_reg       <= 0;
    rx_bad_frame_reg  <= 0;
    rx_good_frame_reg <= 0;
  end else begin
    ntp_time_reg      <= i_ntp_time;
    rx_data_valid_reg <= i_mac_rx_data_valid;
    rx_data_reg       <= i_mac_rx_data;
    rx_bad_frame_reg  <= i_mac_rx_bad_frame;
    rx_good_frame_reg <= i_mac_rx_good_frame;
  end

  //----------------------------------------------------------------
  // Dispatcher
  //----------------------------------------------------------------

  nts_dispatcher #(.ADDR_WIDTH(ADDR_WIDTH)) dispatcher (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .i_ntp_time(ntp_time_reg),

    .i_rx_data_valid(rx_data_valid_reg),
    .i_rx_data(rx_data_reg),
    .i_rx_bad_frame(rx_bad_frame_reg),
    .i_rx_good_frame(rx_good_frame_reg),

    .o_dispatch_packet_available(dispatch_engine_rx_packet_available[0]),
    .i_dispatch_packet_read_discard(engine_dispatch_rx_packet_read_discard[0]),
    .o_dispatch_data_valid(dispatch_engine_rx_data_last_valid[LAST_DATA_VALID_WIDTH*0+:LAST_DATA_VALID_WIDTH]),
    .o_dispatch_fifo_empty(dispatch_engine_rx_fifo_empty[0]),
    .i_dispatch_fifo_rd_start(engine_dispatch_rx_fifo_rd_start[0]),
    .o_dispatch_fifo_rd_valid(dispatch_engine_rx_fifo_rd_valid[0]),
    .o_dispatch_fifo_rd_data(dispatch_engine_rx_fifo_rd_data[MAC_DATA_WIDTH*0+:MAC_DATA_WIDTH]),

    .i_api_cs(i_api_dispatcher_cs),
    .i_api_we(i_api_dispatcher_we),
    .i_api_address(i_api_dispatcher_address),
    .i_api_write_data(i_api_dispatcher_write_data),
    .o_api_read_data(o_api_dispatcher_read_data),

    .o_engine_cs(api_cs),
    .o_engine_we(api_we),
    .o_engine_address(api_address),
    .o_engine_write_data(api_write_data),
    .i_engine_read_data(api_read_data)
  );

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

        .i_ntp_time(ntp_time_reg),

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
        .i_api_we(api_we),
        .i_api_address(api_address),
        .i_api_write_data(api_write_data),
        .o_api_read_data(api_read_data[API_RW_WIDTH*engine_index+:API_RW_WIDTH]),

        .o_noncegen_get(engine_noncegen_get_DUMMY),
        .i_noncegen_data(noncegen_engine_data_DUMMY),
        .i_noncegen_ready(noncegen_engine_ready_DUMMY),

        .o_detect_unique_identifier(engine_debug_detect_unique_identifier[engine_index]),
        .o_detect_nts_cookie(engine_debug_detect_nts_cookie[engine_index]),
        .o_detect_nts_cookie_placeholder(engine_debug_detect_nts_cookie_placeholder[engine_index]),
        .o_detect_nts_authenticator(engine_debug_detect_nts_authenticator[engine_index])
      );
/*
  endgenerate
*/
  //----------------------------------------------------------------
  // Dummy: TX
  //----------------------------------------------------------------

  reg              tx_receiving;
  reg [64*100-1:0] tx_d;
  integer          tx_i;

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_dispatch_tx_packet_read_DUMMY <= 'b0;
      i_dispatch_tx_fifo_rd_en_DUMMY  <= 'b0;

      tx_receiving  <= 'b0;
      tx_d          <= 0;
      tx_i          <= 0;

    end else begin
      i_dispatch_tx_packet_read_DUMMY <= 'b0;
      i_dispatch_tx_fifo_rd_en_DUMMY  <= 'b0;
      if (tx_receiving) begin
        if (o_dispatch_tx_fifo_empty_DUMMY) begin
          i_dispatch_tx_packet_read_DUMMY <= 'b1;
          tx_receiving <= 'b0;
          if (tx_i < 100) tx_d[tx_i*64+:64] <= o_dispatch_tx_fifo_rd_data_DUMMY;
        end else begin
          i_dispatch_tx_fifo_rd_en_DUMMY  <= 'b1;
        end
      end else if (o_dispatch_tx_packet_available_DUMMY) begin
        tx_receiving <= 'b1;
        tx_d         <= 0;
        tx_i         <= 0;
      end
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
