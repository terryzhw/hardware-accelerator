// UART transmitter, 8N1
module uart_tx #(
    parameter CLKS_PER_BIT = 868 // 100 MHz / 115200 baud
) (
    input logic clk, reset,
    input logic [7:0] data,
    input logic start,
    output logic busy,
    output logic tx
);

    logic [9:0] frame;
    logic [15:0] clk_count;
    logic [3:0] bit_count;

    always_ff @(posedge clk) begin
        if (reset) begin
            busy <= 0;
            tx <= 1;
            clk_count <= 0;
            bit_count <= 0;
        end else if (!busy) begin
            tx <= 1;
            if (start) begin
                frame <= {1'b1, data, 1'b0};
                busy <= 1;
                clk_count <= 0;
                bit_count <= 0;
            end
        end else begin
            tx <= frame[0];
            if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 0;
                frame <= frame >> 1;
                if (bit_count == 9) busy <= 0;
                bit_count <= bit_count + 1;
            end else
                clk_count <= clk_count + 1;
        end
    end

endmodule : uart_tx
