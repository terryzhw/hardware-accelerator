`timescale 1ns/1ps

module nn_top_tb;
    localparam CLKS_PER_BIT = 8;
    localparam TIMEOUT = 2000;
    localparam BIT_TIME = CLKS_PER_BIT * 10;

    logic clk = 0;
    logic reset;
    logic uart_rx_pin = 1;
    logic uart_tx_pin;
    logic [3:0] prediction;
    logic [6:0] seg;
    logic [7:0] an;

    logic [7:0] images [50 * 784];
    logic [7:0] exp_pred [50];
    logic [7:0] reply;

    integer replies = 0;
    integer errors = 0;

    nn_top #(
        .CLKS_PER_BIT(CLKS_PER_BIT),
        .TIMEOUT(TIMEOUT),
        .WEIGHTS_FILE("../rtl/weights.mem"),
        .BIASES_FILE("../rtl/biases.mem")
    ) dut(
        .clk(clk),
        .reset(reset),
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),
        .prediction(prediction),
        .seg(seg),
        .an(an)
    );

    always #5ns clk = !clk;

    task send_byte(input logic [7:0] b);
        uart_rx_pin = 0;
        #(BIT_TIME);
        for (int i = 0; i < 8; i++) begin
            uart_rx_pin = b[i];
            #(BIT_TIME);
        end
        uart_rx_pin = 1;
        #(BIT_TIME);
    endtask

    task send_image(input integer v);
        for (int p = 0; p < 784; p++)
            send_byte(images[v * 784 + p]);
    endtask

    // sample each bit in the middle
    always begin
        @(negedge uart_tx_pin);
        #(BIT_TIME * 3 / 2);
        for (int i = 0; i < 8; i++) begin
            reply[i] = uart_tx_pin;
            #(BIT_TIME);
        end
        replies = replies + 1;
    end

    initial begin
        #20ms;
        $fatal(1, "FAIL: timed out");
    end

    initial begin
        $readmemh("../tb/vectors/images.mem", images);
        $readmemh("../tb/vectors/pred.mem", exp_pred);

        reset = 1;
        #100ns;
        reset = 0;
        #100ns;

        if (an !== 8'b11111111) begin
            $display("FAIL an before first image, expected: 11111111 observed: %b", an);
            errors = errors + 1;
        end

        if (seg !== 7'b1111111) begin
            $display("FAIL seg before first image, expected: 1111111 observed: %b", seg);
            errors = errors + 1;
        end

        for (int v = 0; v < 3; v++) begin
            send_image(v);
            wait (replies == v + 1);

            if (reply !== exp_pred[v]) begin
                $display("FAIL image %0d reply, expected: %0d observed: %0d", v, exp_pred[v], reply);
                errors = errors + 1;
            end

            if (prediction !== exp_pred[v]) begin
                $display("FAIL image %0d prediction, expected: %0d observed: %0d", v, exp_pred[v], prediction);
                errors = errors + 1;
            end

            if (an !== 8'b11111110) begin
                $display("FAIL image %0d an, expected: 11111110 observed: %b", v, an);
                errors = errors + 1;
            end
        end

        // half an image then stop, should time out with no reply
        for (int p = 0; p < 300; p++)
            send_byte(8'h7f);
        #(TIMEOUT * 10ns * 2);

        if (replies !== 3) begin
            $display("FAIL partial image, expected: 3 replies observed: %0d", replies);
            errors = errors + 1;
        end

        send_image(3);
        wait (replies == 4);

        if (reply !== exp_pred[3]) begin
            $display("FAIL image 3 reply, expected: %0d observed: %0d", exp_pred[3], reply);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: nn_top_tb");
        else
            $fatal(1, "FAIL: %0d errors", errors);
        $finish;
    end

endmodule
