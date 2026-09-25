// Testbench for nn_top: acts like the PC. Sends images over the serial line and
// checks that the digit sent back matches the Python model.
`timescale 1ns/1ps
module nn_top_tb;
  localparam CLKS_PER_BIT = 8;      // fast baud rate so the simulation is short
  localparam BIT_TIME     = CLKS_PER_BIT * 10;  // ns, with a 10 ns clock

  logic       clock = 0;
  logic       reset;
  logic       rx_pin = 1;           // PC -> FPGA
  logic       tx_pin;               // FPGA -> PC
  logic [3:0] prediction;

  logic [7:0] images   [50 * 784];
  logic [7:0] exp_pred [50];
  logic [7:0] replies  [$];         // bytes the FPGA sent back
  integer errors = 0;

  // Instantiate design under test
  nn_top #(
    .CLKS_PER_BIT(CLKS_PER_BIT),
    .WEIGHTS_FILE("../rtl/weights.mem"),
    .BIASES_FILE ("../rtl/biases.mem")
  ) dut (
    .clk        (clock),
    .reset      (reset),
    .uart_rx_pin(rx_pin),
    .uart_tx_pin(tx_pin),
    .prediction (prediction)
  );

  // Clock generator logic
  always #5ns clock = !clock;

  // Send one byte: start bit, 8 data bits LSB first, stop bit
  task send_byte(input logic [7:0] b);
    rx_pin = 0;
    #(BIT_TIME);
    for (int i = 0; i < 8; i++) begin
      rx_pin = b[i];
      #(BIT_TIME);
    end
    rx_pin = 1;
    #(BIT_TIME);
  endtask

  task send_image(input integer v);
    for (int p = 0; p < 784; p++) send_byte(images[v * 784 + p]);
  endtask

  // Receive bytes from the FPGA: wait for a start bit, then sample in the middle of each bit
  initial begin
    logic [7:0] b;
    forever begin
      @(negedge tx_pin);
      #(BIT_TIME * 3 / 2);
      for (int i = 0; i < 8; i++) begin
        b[i] = tx_pin;
        #(BIT_TIME);
      end
      replies.push_back(b);
    end
  end

  // Wait for one reply byte and check it
  task check_reply(input integer v);
    integer waited;
    waited = 0;
    while (replies.size() == 0 && waited < 1000000) begin
      #10ns;
      waited++;
    end
    if (replies.size() == 0) begin
      $display("FAIL image %0d: no reply", v);
      errors = errors + 1;
    end else begin
      if (replies[0] !== exp_pred[v] || prediction !== exp_pred[v]) begin
        $display("FAIL image %0d: expected=%0d reply=%0d display=%0d",
                 v, exp_pred[v], replies[0], prediction);
        errors = errors + 1;
      end else
        $display("image %0d: FPGA says %0d", v, replies[0]);
      void'(replies.pop_front());
    end
  endtask

  initial begin
    $readmemh("../tb/vectors/images.mem", images);
    $readmemh("../tb/vectors/pred.mem", exp_pred);

    // Initialize Inputs
    reset = 1;
    #100ns;
    reset = 0;
    #100ns;

    // Four images in a row
    for (int v = 0; v < 4; v++) begin
      send_image(v);
      check_reply(v);
    end

    if (errors == 0)
      $display("PASS: nn_top_tb");
    else
      $fatal(1, "FAIL: %0d errors", errors);
    $finish;
  end
endmodule
