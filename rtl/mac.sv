// Multiply-accumulate: acc = bias + sum of a * w
module mac (
    input logic clk,
    input logic clear,
    input logic enable,
    input logic signed [31:0] bias,
    input logic signed [7:0] a, w,
    output logic signed [31:0] acc
);

    always_ff @(posedge clk) begin
        if (clear)
            acc <= bias;
        else if (enable)
            acc <= acc + a * w;
    end

endmodule : mac
