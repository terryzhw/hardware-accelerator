// Testbench for nn_core: runs every test image from python/train.py and checks
// all 32 hidden values, all 10 scores and the prediction against the Python model.
`timescale 1ns/1ps
module nn_core_tb;
  parameter NUM_VECTORS = 50;

  logic       clock = 0;
  logic       reset, pixel_we, start;
  logic [9:0] pixel_addr;
  logic [7:0] pixel_data;
  logic       busy, done;
  logic [3:0] prediction;

  // Expected results written by python/train.py
  logic [7:0]  images     [NUM_VECTORS * 784];
  logic [7:0]  exp_hidden [NUM_VECTORS * 32];
  logic [31:0] exp_scores [NUM_VECTORS * 10];
  logic [7:0]  exp_pred   [NUM_VECTORS];

  logic signed [31:0] scores [10];  // grabbed from inside the design as it runs
  integer errors = 0;
  integer cycles;

  // Instantiate design under test
  nn_core #(
    .WEIGHTS_FILE("../rtl/weights.mem"),
    .BIASES_FILE ("../rtl/biases.mem")
  ) dut (
    .clk       (clock),
    .reset     (reset),
    .pixel_we  (pixel_we),
    .pixel_addr(pixel_addr),
    .pixel_data(pixel_data),
    .start     (start),
    .busy      (busy),
    .done      (done),
    .prediction(prediction)
  );

  // Clock generator logic
  always #5ns clock = !clock;

  // Save each output-layer score when the core finishes that neuron
  always @(posedge clock) begin
    if (dut.state == dut.SAVE && dut.layer == 1) scores[dut.neuron] = dut.acc;
  end

  initial begin
    $readmemh("../tb/vectors/images.mem", images);
    $readmemh("../tb/vectors/hidden.mem", exp_hidden);
    $readmemh("../tb/vectors/scores.mem", exp_scores);
    $readmemh("../tb/vectors/pred.mem", exp_pred);

    // Initialize Inputs
    reset = 1;
    pixel_we = 0;
    pixel_addr = 0;
    pixel_data = 0;
    start = 0;
    #20ns;
    reset = 0;

    for (int v = 0; v < NUM_VECTORS; v++) begin
      // Load the image
      for (int p = 0; p < 784; p++) begin
        @(negedge clock);
        pixel_we = 1;
        pixel_addr = p;
        pixel_data = images[v * 784 + p];
      end
      @(negedge clock);
      pixel_we = 0;

      // Run it and count clock cycles until done
      start = 1;
      @(negedge clock);
      start = 0;
      cycles = 1;
      while (!done) begin
        @(negedge clock);
        cycles++;
      end

      // Compare with the Python model
      for (int n = 0; n < 32; n++) begin
        if (dut.hidden[n] !== exp_hidden[v * 32 + n]) begin
          $display("FAIL image %0d hidden %0d: expected=%0d observed=%0d",
                   v, n, exp_hidden[v * 32 + n], dut.hidden[n]);
          errors = errors + 1;
        end
      end
      for (int k = 0; k < 10; k++) begin
        if (scores[k] !== exp_scores[v * 10 + k]) begin
          $display("FAIL image %0d score %0d: expected=%0d observed=%0d",
                   v, k, $signed(exp_scores[v * 10 + k]), scores[k]);
          errors = errors + 1;
        end
      end
      if (prediction !== exp_pred[v]) begin
        $display("FAIL image %0d prediction: expected=%0d observed=%0d", v, exp_pred[v], prediction);
        errors = errors + 1;
      end
      $display("image %0d: prediction=%0d expected=%0d cycles=%0d", v, prediction, exp_pred[v], cycles);
    end

    if (errors == 0)
      $display("PASS: all %0d images match the Python model", NUM_VECTORS);
    else
      $fatal(1, "FAIL: %0d mismatches", errors);
    $finish;
  end
endmodule
