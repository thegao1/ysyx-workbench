// NPC wrapper：包装 ysyx_100023197_scpu，接入 ysyxSoC（SimTop 例化 NPC core0）
module NPC(
    input         clock, reset,
    output [31:0] io_ifu_addr,
    output        io_ifu_reqValid,
    input  [31:0] io_ifu_rdata,
    input         io_ifu_respValid,
    output [31:0] io_lsu_addr,
    output        io_lsu_reqValid,
    input  [31:0] io_lsu_rdata,
    input         io_lsu_respValid,
    output [1:0]  io_lsu_size,
    output        io_lsu_wen,
    output [31:0] io_lsu_wdata,
    output [3:0]  io_lsu_wmask
);
    ysyx_100023197_scpu u_cpu(
        .clock(clock), .reset(reset),
        .io_ifu_addr(io_ifu_addr), .io_ifu_reqValid(io_ifu_reqValid),
        .io_ifu_rdata(io_ifu_rdata), .io_ifu_respValid(io_ifu_respValid),
        .io_lsu_addr(io_lsu_addr), .io_lsu_reqValid(io_lsu_reqValid),
        .io_lsu_rdata(io_lsu_rdata), .io_lsu_respValid(io_lsu_respValid),
        .io_lsu_size(io_lsu_size), .io_lsu_wen(io_lsu_wen),
        .io_lsu_wdata(io_lsu_wdata), .io_lsu_wmask(io_lsu_wmask)
    );
endmodule