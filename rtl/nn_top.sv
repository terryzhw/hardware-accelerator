// Top level: receive a 28x28 image over UART (784 bytes, one per pixel),
// run the network, and send the predicted digit back as one byte
module nn_top #(
  parameter CLKS_PER_BIT = 868,          // 100 MHz / 115200 baud
  parameter WEIGHTS_FILE = "weights.mem",
  parameter BIASES_FILE  = "biases.mem"
) (
  input  logic       clk,
  reset,
  input  logic       uart_rx_pin,
  output logic       uart_tx_pin,
  output logic [3:0] prediction
);

  // Local net declaration
  logic [7:0]  rx_data;
  logic        rx_valid;
  logic [9:0]  pixel_count;
  logic        start, busy, done, tx_busy;

  uart_rx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) uart_rx_instance (
    .clk  (clk),
    .reset(reset),
    .rx   (uart_rx_pin),
    .data (rx_data),
    .valid(rx_valid)
  );

  nn_core #(
    .WEIGHTS_FILE(WEIGHTS_FILE),
    .BIASES_FILE (BIASES_FILE)
  ) nn_core_instance (
    .clk       (clk),
    .reset     (reset),
    .pixel_we  (rx_valid),
    .pixel_addr(pixel_count),
    .pixel_data(rx_data),
    .start     (start),
    .busy      (busy),
    .done      (done),
    .prediction(prediction)
  );

  // When the network finishes, send the digit back
  uart_tx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) uart_tx_instance (
    .clk  (clk),
    .reset(reset),
    .data ({4'b0000, prediction}),
    .start(done),
    .busy (tx_busy),
    .tx   (uart_tx_pin)
  );

  // Byte n is pixel n. After the last pixel, start the network.
  always_ff @(posedge clk) begin
    if (reset) begin
      pixel_count <= 0;
      start       <= 0;
    end else begin
      start <= 0;
      if (rx_valid) begin
        if (pixel_count == 783) begin
          pixel_count <= 0;
          start       <= 1;
        end else
          pixel_count <= pixel_count + 1;
      end
    end
  end

endmodule : nn_top
