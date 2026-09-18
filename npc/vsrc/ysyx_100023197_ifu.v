module ysyx_100023197_ifu(
    input             clock,
    input             reset,
    input             pc_sel,
    input      [31:0] pc_target,
    input             if_busy,
    output reg        io_ifu_reqValid,
    input             io_ifu_respValid,
    output reg [31:0] pc,
    output     [31:0] io_ifu_addr,
    input      [31:0] io_ifu_rdata,
    output     [31:0] inst,
    output reg        status
);

assign io_ifu_addr = pc;        // 发地址：每拍都是当前 PC（wire，不是 reg）
assign inst      = io_ifu_rdata; // 存储器数据直通给 decode（wire，不是 reg）

always @(posedge clock or posedge reset) begin
    if (reset) begin
        pc     <= 32'h80000000;  // 默认：独立仿真从 PMEM 取指
        `ifdef NPC_SOC
        pc     <= 32'h30000000;  // SoC：从 Flash 取指
        `endif
        status <= 1'b0;          // 复位进入 idle
        io_ifu_reqValid <=1'b0;
    end else begin
        case (status)
            1'b0: begin          // idle：发地址，冻结，等数据
                status <= 1'b1;
                io_ifu_reqValid <=1;
            end
            1'b1: begin          // wait：数据有效且 LSU 不忙才提交
                if(io_ifu_respValid && !if_busy) begin
                    pc     <= pc_sel ? pc_target : pc + 32'd4;
                    status <= 1'b0;
                    io_ifu_reqValid <= 1'b0;
                end else begin
                    status      <= 1'b1;      // 保持 wait
                    io_ifu_reqValid <= 1'b1;     // 保持请求，等数据/LSU
                end
            end
        endcase
    end
end

endmodule
