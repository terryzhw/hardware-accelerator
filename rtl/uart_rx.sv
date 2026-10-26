// UART receiver, 8N1
module uart_rx #(
    parameter CLKS_PER_BIT = 868 // 100 MHz / 115200 baud
) (
    input logic clk, reset,
    input logic rx,
    output logic [7:0] data,
    output logic valid
);

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic rx_meta, rx_sync;
    logic [15:0] clk_count;
    logic [2:0] bit_index;

    // synchronizer
    always_ff @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            valid <= 0;
        end else begin
            valid <= 0;
            case (state)
                IDLE: begin
                    clk_count <= 0;
                    if (rx_sync == 0) state <= START;
                end

                START: begin
                    if (clk_count == CLKS_PER_BIT / 2 - 1) begin
                        clk_count <= 0;
                        bit_index <= 0;
                        if (rx_sync == 0) state <= DATA;
                        else state <= IDLE;
                    end else
                        clk_count <= clk_count + 1;
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        data[bit_index] <= rx_sync;
                        if (bit_index == 7) state <= STOP;
                        bit_index <= bit_index + 1;
                    end else
                        clk_count <= clk_count + 1;
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        valid <= (rx_sync == 1);
                        state <= IDLE;
                    end else
                        clk_count <= clk_count + 1;
                end
            endcase
        end
    end

endmodule : uart_rx
