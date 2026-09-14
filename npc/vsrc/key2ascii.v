// PS/2 Set1 扫描码(make code) -> ASCII
module key2ascii(
    input  [7:0] latch_key,   // 锁存的扫描码
    output [7:0] ascii_out    // 对应 ASCII
);

reg [7:0] ascii_reg;
assign ascii_out = ascii_reg;

always @(*) begin
    case(latch_key)
        // 数字行
        8'h45: ascii_reg = "0";   // 0x30
        8'h16: ascii_reg = "1";   // 0x31
        8'h1E: ascii_reg = "2";   // 0x32
        8'h26: ascii_reg = "3";   // 0x33
        8'h25: ascii_reg = "4";   // 0x34
        8'h2E: ascii_reg = "5";   // 0x35
        8'h36: ascii_reg = "6";   // 0x36
        8'h3D: ascii_reg = "7";   // 0x37
        8'h3E: ascii_reg = "8";   // 0x38
        8'h46: ascii_reg = "9";   // 0x39
        // 字母 A~Z
        8'h1C: ascii_reg = "A";
        8'h32: ascii_reg = "B";
        8'h21: ascii_reg = "C";
        8'h23: ascii_reg = "D";
        8'h24: ascii_reg = "E";
        8'h2B: ascii_reg = "F";
        8'h34: ascii_reg = "G";
        8'h33: ascii_reg = "H";
        8'h43: ascii_reg = "I";
        8'h3B: ascii_reg = "J";
        8'h42: ascii_reg = "K";
        8'h4B: ascii_reg = "L";
        8'h3A: ascii_reg = "M";
        8'h31: ascii_reg = "N";
        8'h44: ascii_reg = "O";
        8'h4D: ascii_reg = "P";
        8'h15: ascii_reg = "Q";
        8'h2D: ascii_reg = "R";
        8'h1B: ascii_reg = "S";
        8'h2C: ascii_reg = "T";
        8'h3C: ascii_reg = "U";
        8'h2A: ascii_reg = "V";
        8'h1D: ascii_reg = "W";
        8'h22: ascii_reg = "X";
        8'h35: ascii_reg = "Y";
        8'h1A: ascii_reg = "Z";
        // 空格、回车
        8'h29: ascii_reg = " ";     // 0x20
        8'h5A: ascii_reg = 8'h0D;   // 回车 CR
        default: ascii_reg = 8'h00; // 未识别键：0
    endcase
end

endmodule
