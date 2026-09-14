module seg7(
    input  [3:0] din,      // 输入数字 0~15
    input        en,       // 显示使能：1 显示，0 熄灭
    output [6:0] seg       // {g,f,e,d,c,b,a}，低电平有效（共阳数码管）
);

reg [6:0] seg_high;        // 高电平有效的中间值

always @(*) begin
    case(din)
        4'h0: seg_high = 7'b0111111; // 0 g灭，其余亮
        4'h1: seg_high = 7'b0000110; // 1
        4'h2: seg_high = 7'b1011011; // 2
        4'h3: seg_high = 7'b1001111; // 3
        4'h4: seg_high = 7'b1100110; // 4
        4'h5: seg_high = 7'b1101101; // 5
        4'h6: seg_high = 7'b1111101; // 6
        4'h7: seg_high = 7'b0000111; // 7
        4'h8: seg_high = 7'b1111111; // 8
        4'h9: seg_high = 7'b1101111; // 9
        4'ha: seg_high = 7'b1110111; // A
        4'hb: seg_high = 7'b1111100; // b
        4'hc: seg_high = 7'b0111001; // C
        4'hd: seg_high = 7'b1011110; // d
        4'he: seg_high = 7'b1111001; // E
        4'hf: seg_high = 7'b1110001; // F
        default: seg_high = 7'b0000000;
    endcase
end

// 共阳数码管：取反后低电平点亮；en=0 时全灭（低电平有效下全 1）
assign seg = en ? ~seg_high : 7'b1111111;

endmodule
