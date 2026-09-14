//=====================================================================
// top.v —— 顶层
//   改动：端口原来叫 `le`，例化时却连 .led(led)，名字对不上。
//         仿真器会隐式造一个 1 bit 的 `led`，导致 16 位 LED 根本没驱动
//         （报 IMPLICIT / UNDRIVEN），这就是之前点不亮灯的原因。
//
//   ⚠ 坑：注释里不要出现 "verilator" 这个单词 —— 会被当成编译指示解析，
//          报 BADVLTPRAGMA。想提它请写 "仿真器"。
//=====================================================================
module top(
    input  clk,
    input  rst,
    output [15:0] led,
    output [31:0] inst,
    output [31:0] pc,
    output [31:0] rd_data,
    output [1023:0] gpr_dump
);
scpu u_cpu(
    .clk(clk),
    .rst(rst),
    .led(led),
    .pc(pc),
    .inst(inst),
    .rd_data(rd_data),
    .gpr_dump(gpr_dump)
);

endmodule
