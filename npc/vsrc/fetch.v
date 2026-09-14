import pmem_pkg::*;
module fetch(
    input             clk,
    input             rst,
    input             pc_sel,      // 1 = 分支/跳转成立
    input      [31:0] pc_target,   // 成立时的目标地址
    output reg [31:0] pc,
    output     [31:0] inst
);

always @(posedge clk or posedge rst) begin
    if      (rst)    pc <= 32'h80000000;
    else if (pc_sel) pc <= pc_target;
    else             pc <= pc + 32'd4;
end

assign inst = pmem_read(pc);

endmodule
