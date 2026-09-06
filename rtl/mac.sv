// Multiply-accumulate unit: acc = bias + sum of (a * w)
module mac (
  input  logic               clk,
  input  logic               clear,    // load the bias to start a new neuron
  input  logic               enable,   // add a * w this cycle
  input  logic signed [31:0] bias,
  input  logic signed [7:0]  a,
  w,
  output logic signed [31:0] acc
);

  always_ff @(posedge clk) begin
    if (clear)
      acc <= bias;
    else if (enable)
      acc <= acc + a * w;  // a and w are signed, so they are sign-extended to 32 bits first
  end

endmodule : mac
