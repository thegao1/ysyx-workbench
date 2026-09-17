module fetch(
    input             clk,
    input             rst,
    input             pc_sel,
    input      [31:0] pc_target,
    input             if_busy,
    output reg        ifu_reqvalid,
    input             ifu_respvalid,
    output reg [31:0] pc,
    output     [31:0] ifu_raddr,
    input      [31:0] ifu_rdata,
    output     [31:0] inst,
    output reg        status
);

assign ifu_raddr = pc;        // 发地址：每拍都是当前 PC（wire，不是 reg）
assign inst      = ifu_rdata; // 存储器数据直通给 decode（wire，不是 reg）

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc     <= 32'h80000000;
        status <= 1'b0;          // 复位进入 idle
        ifu_reqvalid <=1'b0;
    end else begin
        case (status)
            1'b0: begin          // idle：发地址，冻结，等数据
                status <= 1'b1;
                ifu_reqvalid <=1;
            end
            1'b1: begin          // wait：数据有效且 LSU 不忙才提交
                if(ifu_respvalid && !if_busy) begin
                    pc     <= pc_sel ? pc_target : pc + 32'd4;
                    status <= 1'b0;
                    ifu_reqvalid <= 1'b0;
                end else begin
                    status      <= 1'b1;      // 保持 wait
                    ifu_reqvalid <= 1'b1;     // 保持请求，等数据/LSU
                end
            end
        endcase
    end
end

endmodule
