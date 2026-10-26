module seven_seg (
    input logic [3:0] digit,
    input logic blank, // 1 = turn the display off
    output logic [6:0] seg,
    output logic [7:0] an // right most display
);

    logic [6:0] lit; // 1 = segment on, bit order gfedcba

    always_comb begin
        case (digit)
            4'd0: lit = 7'b0111111;
            4'd1: lit = 7'b0000110;
            4'd2: lit = 7'b1011011;
            4'd3: lit = 7'b1001111;
            4'd4: lit = 7'b1100110;
            4'd5: lit = 7'b1101101;
            4'd6: lit = 7'b1111101;
            4'd7: lit = 7'b0000111;
            4'd8: lit = 7'b1111111;
            4'd9: lit = 7'b1101111;
            default: lit = 7'b0000000;
        endcase

        if (blank)
            lit = 7'b0000000;
    end

    // right most display active low
    assign seg = ~lit;
    assign an = blank ? 8'b11111111 : 8'b11111110;

endmodule : seven_seg
