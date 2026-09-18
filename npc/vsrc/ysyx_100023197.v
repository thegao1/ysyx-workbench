//=====================================================================
// top.v —— 顶层：CPU(scpu) + 存储器行为模型(mem) 通过 SimpleBus(io_*) 连接
//=====================================================================
module ysyx_100023197(
    input  clock,
    input  reset,
    output [15:0] led,
    output [31:0] inst,
    output [31:0] pc,
    output [31:0] rd_data,
    output [1023:0] gpr_dump,
    output        status,
    output        lsu_status,
    output        commit
);

// SimpleBus：CPU <-> 存储器
wire        io_ifu_reqValid;
wire [31:0] io_ifu_addr;
wire        io_ifu_respValid;
wire [31:0] io_ifu_rdata;
wire        io_lsu_reqValid;
wire [31:0] io_lsu_addr;
wire        io_lsu_wen;
wire [31:0] io_lsu_wdata;
wire [3:0]  io_lsu_wmask;
wire        io_lsu_respValid;
wire [31:0] io_lsu_rdata;
wire [1:0]  io_lsu_size;
ysyx_100023197_scpu u_cpu(
    .clock(clock),
    .reset(reset),
    .led(led),
    .pc(pc),
    .inst(inst),
    .rd_data(rd_data),
    .gpr_dump(gpr_dump),
    .status(status),
    .lsu_status(lsu_status),
    .commit(commit),
    .io_ifu_reqValid(io_ifu_reqValid),
    .io_ifu_addr(io_ifu_addr),
    .io_ifu_respValid(io_ifu_respValid),
    .io_ifu_rdata(io_ifu_rdata),
    .io_lsu_reqValid(io_lsu_reqValid),
    .io_lsu_addr(io_lsu_addr),
    .io_lsu_wen(io_lsu_wen),
    .io_lsu_wdata(io_lsu_wdata),
    .io_lsu_wmask(io_lsu_wmask),
    .io_lsu_size(io_lsu_size),
    .io_lsu_respValid(io_lsu_respValid),
    .io_lsu_rdata(io_lsu_rdata)
);

ysyx_100023197_mem u_mem(
    .clock(clock),
    .io_ifu_reqValid(io_ifu_reqValid),
    .io_ifu_addr(io_ifu_addr),
    .io_ifu_respValid(io_ifu_respValid),
    .io_ifu_rdata(io_ifu_rdata),
    .io_lsu_reqValid(io_lsu_reqValid),
    .io_lsu_addr(io_lsu_addr),
    .io_lsu_wen(io_lsu_wen),
    .io_lsu_wdata(io_lsu_wdata),
    .io_lsu_wmask(io_lsu_wmask),
    .io_lsu_respValid(io_lsu_respValid),
    .io_lsu_rdata(io_lsu_rdata)
);

endmodule