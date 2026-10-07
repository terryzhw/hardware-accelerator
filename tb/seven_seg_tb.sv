// Testbench for seven_seg: checks every digit against a list of which segments
// should be lit, written as letters so it doesn't just copy the RTL table.
`timescale 1ns/1ps
module seven_seg_tb;
  logic [3:0] digit;
  logic       blank;
  logic [6:0] seg;
  logic [7:0] an;
  integer errors = 0;

  // Segments that should be on for 0-9
  string expected [10] = '{"abcdef", "bc", "abdeg", "abcdg", "bcfg",
                           "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"};

  // Instantiate design under test
  seven_seg dut (
    .digit(digit),
    .blank(blank),
    .seg  (seg),
    .an   (an)
  );

  // Turn a string like "bc" into the active-low pattern the board wants
  function automatic logic [6:0] to_seg(input string s);
    logic [6:0] on = 0;
    for (int i = 0; i < s.len(); i++)
      on[s[i] - "a"] = 1;
    return ~on;
  endfunction

  initial begin
    // Digits 0-9 on the rightmost display
    blank = 0;
    for (int d = 0; d < 10; d++) begin
      digit = d;
      #10ns;
      if (seg !== to_seg(expected[d]) || an !== 8'b11111110) begin
        $display("FAIL digit %0d: expected seg=%b an=11111110 observed seg=%b an=%b",
                 d, to_seg(expected[d]), seg, an);
        errors = errors + 1;
      end else
        $display("digit %0d: seg=%b", d, seg);
    end

    // 10-15 should show nothing
    for (int d = 10; d < 16; d++) begin
      digit = d;
      #10ns;
      if (seg !== 7'b1111111) begin
        $display("FAIL digit %0d: expected all segments off, observed seg=%b", d, seg);
        errors = errors + 1;
      end
    end

    // Blank turns everything off
    blank = 1;
    digit = 8;
    #10ns;
    if (seg !== 7'b1111111 || an !== 8'b11111111) begin
      $display("FAIL blank: observed seg=%b an=%b", seg, an);
      errors = errors + 1;
    end

    if (errors == 0)
      $display("PASS: seven_seg_tb");
    else
      $fatal(1, "FAIL: %0d errors", errors);
    $finish;
  end
endmodule
