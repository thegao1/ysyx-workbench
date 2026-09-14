module key_sync(
    input   clk,
    input   rst,
    input   key_raw,
    output  press_pulse,
    output  release_pulse
);

reg r1, r2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r1 <= 1'b0;
        r2 <= 1'b0;
    end
    else begin
        r1 <= key_raw;
        r2 <= r1;
    end
end

// 两级同步后取边沿
assign press_pulse   = r1 & (~r2);  // 上升沿：按下
assign release_pulse = r2 & (~r1);  // 下降沿：松开

endmodule
