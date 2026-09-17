//=====================================================================
// top.v —— 顶层
//=====================================================================
module top(
    input  clk,
    input  rst,
    output [15:0] led,
    output [31:0] inst,
    output [31:0] pc,
    output [31:0] rd_data,
    output [1023:0] gpr_dump,
    output        status,
    output        lsu_status,
    output        commit
);
scpu u_cpu(
    .clk(clk),
    .rst(rst),
    .led(led),
    .pc(pc),
    .inst(inst),
    .rd_data(rd_data),
    .gpr_dump(gpr_dump),
    .status(status),
    .lsu_status(lsu_status),
    .commit(commit)

);

endmodule
