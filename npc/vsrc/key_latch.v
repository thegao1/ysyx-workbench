module key_latch(
    input               clk,
    input               rst,
    input               press_pulse,
    input               release_pulse,
    input      [7:0]    key_code_in,

    output reg [7:0]    key_count,    // 按键总次数
    output reg [7:0]    latch_key,    // 锁存的键码
    output reg          key_dis_en    // 低4位显示使能：1点亮，0熄灭
);

always @(posedge clk or posedge rst) begin
    if(rst) begin
        key_count   <= 8'd0;
        latch_key   <= 8'd0;
        key_dis_en  <= 1'b0;   // 复位，低四位熄灭
    end
    else begin
        if(press_pulse) begin
            // 刚按下脉冲：三件事
            key_count   <= key_count + 8'd1;
            latch_key   <= key_code_in;
            key_dis_en  <= 1'b1;  // 打开低四位显示
        end
        else if(release_pulse) begin
            // 刚松开脉冲：只关闭显示，不修改count、latch_key
            key_dis_en  <= 1'b0;
        end
        else begin
            // 按住不放 / 空闲：全部保持，什么都不改
            key_count   <= key_count;
            latch_key   <= latch_key;
            key_dis_en  <= key_dis_en;
        end
    end
end

endmodule
