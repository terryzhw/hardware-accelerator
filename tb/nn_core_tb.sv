`timescale 1ns/1ps

module nn_core_tb;
    logic clk = 0;
    logic reset;
    logic pixel_we;
    logic [9:0] pixel_addr;
    logic [7:0] pixel_data;
    logic start;
    logic busy;
    logic done;
    logic [3:0] prediction;

    logic [7:0] images [50 * 784];
    logic [7:0] exp_hidden [50 * 32];
    logic [31:0] exp_scores [50 * 10];
    logic [7:0] exp_pred [50];
    logic signed [31:0] scores [10];

    integer errors = 0;
    integer cycles;

    nn_core #(
        .WEIGHTS_FILE("../rtl/weights.mem"),
        .BIASES_FILE("../rtl/biases.mem")
    ) dut(
        .clk(clk),
        .reset(reset),
        .pixel_we(pixel_we),
        .pixel_addr(pixel_addr),
        .pixel_data(pixel_data),
        .start(start),
        .busy(busy),
        .done(done),
        .prediction(prediction)
    );

    always #5ns clk = !clk;

    always @(posedge clk) begin
        if (dut.state == dut.SAVE && dut.layer == 1)
            scores[dut.neuron] = dut.acc;
    end

    initial begin
        $readmemh("../tb/vectors/images.mem", images);
        $readmemh("../tb/vectors/hidden.mem", exp_hidden);
        $readmemh("../tb/vectors/scores.mem", exp_scores);
        $readmemh("../tb/vectors/pred.mem", exp_pred);

        reset = 1;
        pixel_we = 0;
        pixel_addr = 0;
        pixel_data = 0;
        start = 0;
        #20ns;
        reset = 0;

        for (int v = 0; v < 50; v++) begin
            for (int p = 0; p < 784; p++) begin
                @(negedge clk);
                pixel_we = 1;
                pixel_addr = p;
                pixel_data = images[v * 784 + p];
            end
            @(negedge clk);
            pixel_we = 0;

            start = 1;
            @(negedge clk);
            start = 0;
            cycles = 1;
            while (!done) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            for (int n = 0; n < 32; n++) begin
                if (dut.hidden[n] !== exp_hidden[v * 32 + n]) begin
                    $display("FAIL image %0d hidden %0d, expected: %0d observed: %0d", v, n, exp_hidden[v * 32 + n], dut.hidden[n]);
                    errors = errors + 1;
                end
            end

            for (int k = 0; k < 10; k++) begin
                if (scores[k] !== exp_scores[v * 10 + k]) begin
                    $display("FAIL image %0d score %0d, expected: %0d observed: %0d", v, k, $signed(exp_scores[v * 10 + k]), scores[k]);
                    errors = errors + 1;
                end
            end

            if (prediction !== exp_pred[v]) begin
                $display("FAIL image %0d prediction, expected: %0d observed: %0d", v, exp_pred[v], prediction);
                errors = errors + 1;
            end

            $display("image %0d: prediction %0d, %0d cycles", v, prediction, cycles);
        end

        if (errors == 0)
            $display("PASS: nn_core_tb");
        else
            $fatal(1, "FAIL: %0d errors", errors);
        $finish;
    end

endmodule
