// Seven-segment decoder for the Nexys A7: shows one digit on the rightmost display.
// The board's segments and anodes are active low (0 = on).
//
//      a
//     ---
//  f |   | b
//     -g-
//  e |   | c
//     ---
//      d
module seven_seg (
  input  logic [3:0] digit,
  input  logic       blank,   // 1 = turn the display off
  output logic [6:0] seg,     // seg[0] = a ... seg[6] = g  (CA..CG on the board)
  output logic [7:0] an       // one per display, an[0] is the rightmost
);

  // Local net declaration
  logic [6:0] lit;  // 1 = segment on, bit order gfedcba

  always_comb begin
    case (digit)
      4'd0:    lit = 7'b0111111;
      4'd1:    lit = 7'b0000110;
      4'd2:    lit = 7'b1011011;
      4'd3:    lit = 7'b1001111;
      4'd4:    lit = 7'b1100110;
      4'd5:    lit = 7'b1101101;
      4'd6:    lit = 7'b1111101;
      4'd7:    lit = 7'b0000111;
      4'd8:    lit = 7'b1111111;
      4'd9:    lit = 7'b1101111;
      default: lit = 7'b0000000;  // 10-15 never come out of the network, show nothing
    endcase

    if (blank)
      lit = 7'b0000000;
  end

  // Flip to active low. Only the rightmost display is turned on, so no multiplexing needed.
  assign seg = ~lit;
  assign an  = blank ? 8'b11111111 : 8'b11111110;

endmodule : seven_seg
