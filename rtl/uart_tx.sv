// UART transmitter: 8 data bits, no parity, 1 stop bit
module uart_tx #(
  parameter CLKS_PER_BIT = 868   // 100 MHz clock / 115200 baud
) (
  input  logic       clk,
  reset,
  input  logic [7:0] data,
  input  logic       start,      // send data (ignored while busy)
  output logic       busy,
  output logic       tx          // serial output, idle high
);

  logic [9:0]  frame;       // stop bit, 8 data bits, start bit
  logic [15:0] clk_count;
  logic [3:0]  bit_count;

  always_ff @(posedge clk) begin
    if (reset) begin
      busy      <= 0;
      tx        <= 1;
      clk_count <= 0;
      bit_count <= 0;
    end else if (!busy) begin
      tx <= 1;
      if (start) begin
        frame     <= {1'b1, data, 1'b0};
        busy      <= 1;
        clk_count <= 0;
        bit_count <= 0;
      end
    end else begin
      // Send frame[0], hold it for one bit time, then shift to the next bit
      tx <= frame[0];
      if (clk_count == CLKS_PER_BIT - 1) begin
        clk_count <= 0;
        frame     <= frame >> 1;
        if (bit_count == 9) busy <= 0;
        bit_count <= bit_count + 1;
      end else
        clk_count <= clk_count + 1;
    end
  end

endmodule : uart_tx
