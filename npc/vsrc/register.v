module register_file(
    input               clk,
    input               rst,
    input               w_en,      // 写使能
    input      [4:0]    rd,        // 写地址
    input      [4:0]    rs1,       // 读地址1
    input      [4:0]    rs2,       // 读地址2
    input      [31:0]   w_data,    // 写入的数据
    output reg [31:0]   rs1_data,  // rs1读出数据
    output reg [31:0]   rs2_data,  // rs2读出数据
    output reg [31:0]   rd_data,   // 写入的数据
    output reg [31:0]   a0_data,   // x10(a0)读出数据，只有 ebreak 结束程序时用得到
    output     [1023:0] gpr_dump   // difftest 用：32 个 GPR 的全量快照
);


reg [31:0] reg_file [0:31];

always @(posedge clk) begin
    if(rst) begin
        for(int i = 0; i < 32; i = i + 1) begin
            reg_file[i] <= 32'd0;
        end
    end
    else begin
        if(w_en && rd != 5'd0) begin
            reg_file[rd] <= w_data;
        end
    end
end

// 组合读逻辑：寄存器堆读是组合逻辑
always @(*) begin
    rs1_data = reg_file[rs1];
    rs2_data = reg_file[rs2];
    rd_data  = reg_file[rd];
    a0_data  = reg_file[10];   // x10 = a0，AM 用它在 ebreak 前递结束状态
end

genvar gi;
generate
    for (gi = 0; gi < 32; gi = gi + 1) begin : gpr_pack
        assign gpr_dump[gi*32 +: 32] = reg_file[gi];
    end
endgenerate

endmodule
