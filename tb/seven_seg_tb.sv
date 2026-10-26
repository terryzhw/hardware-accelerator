`timescale 1ns/1ps

module seven_seg_tb;
    logic [3:0] digit;
    logic blank;
    logic [6:0] seg;
    logic [7:0] an;

    integer errors = 0;

    seven_seg dut(
        .digit(digit),
        .blank(blank),
        .seg(seg),
        .an(an)
    );

    initial begin
        digit = 0;
        blank = 0;
        #10ns;

        if (an !== 8'b11111110) begin
            $display("FAIL an on, expected: 11111110 observed: %b", an);
            errors = errors + 1;
        end

        if (seg !== 7'b1000000) begin
            $display("FAIL digit 0, expected: 1000000 observed: %b", seg);
            errors = errors + 1;
        end

        blank = 1;
        #10ns;

        if (an !== 8'b11111111) begin
            $display("FAIL an off, expected: 11111111 observed: %b", an);
            errors = errors + 1;
        end

        if (seg !== 7'b1111111) begin
            $display("FAIL blank, expected: 1111111 observed: %b", seg);
            errors = errors + 1;
        end

        blank = 0;
        digit = 1;
        #10ns;

        if (seg !== 7'b1111001) begin
            $display("FAIL digit 1, expected: 1111001 observed: %b", seg);
            errors = errors + 1;
        end

        digit = 2;
        #10ns;

        if (seg !== 7'b0100100) begin
            $display("FAIL digit 2, expected: 0100100 observed: %b", seg);
            errors = errors + 1;
        end

        digit = 3;
        #10ns;

        if (seg !== 7'b0110000) begin
            $display("FAIL digit 3, expected: 0110000 observed: %b", seg);
            errors = errors + 1;
        end

        digit = 4;
        #10ns;

        if (seg !== 7'b0011001) begin
            $display("FAIL digit 4, expected: 0011001 observed: %b", seg);
            errors = errors + 1;
        end

        digit = 5;
        #10ns;

        if (seg !== 7'b0010010) begin
            $display("FAIL digit 5, expected: 0010010 observed: %b", seg);
            errors = errors + 1;
        end

        digit = 6;
        #10ns;

        if (seg !== 7'b0000010) begin
            $display("FAIL digit 6, expected: 0000010 observed: %b", seg);
            errors = errors + 1;
        end

        digit = 7;
        #10ns;

        if (seg !== 7'b1111000) begin
            $display("FAIL digit 7, expected: 1111000 observed: %b", seg);
            errors = errors + 1;
        end

        digit = 8;
        #10ns;

        if (seg !== 7'b0000000) begin
            $display("FAIL digit 8, expected: 0000000 observed: %b", seg);
            errors = errors + 1;
        end

        digit = 9;
        #10ns;

        if (seg !== 7'b0010000) begin
            $display("FAIL digit 9, expected: 0010000 observed: %b", seg);
            errors = errors + 1;
        end

        // 10-15 never come out of the network, so the display should be off
        digit = 12;
        #10ns;

        if (seg !== 7'b1111111) begin
            $display("FAIL digit 12, expected: 1111111 observed: %b", seg);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: seven_seg_tb");
        else
            $fatal(1, "FAIL: %0d errors", errors);
        $finish;
    end

endmodule
