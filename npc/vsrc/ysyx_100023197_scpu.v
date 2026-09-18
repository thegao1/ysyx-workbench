module ysyx_100023197_scpu(
    input  clock,
    input  reset,
    output reg [15:0] led,
    output [31:0] inst,
    output [31:0] pc,
    output [31:0] rd_data,
    output [1023:0] gpr_dump,
    output        status,
    output        lsu_status,
    output        commit,
    output        io_ifu_reqValid,
    output [31:0] io_ifu_addr,
    input         io_ifu_respValid,
    input  [31:0] io_ifu_rdata,
    output        io_lsu_reqValid,
    output [31:0] io_lsu_addr,
    output        io_lsu_wen,
    output [31:0] io_lsu_wdata,
    output [3:0]  io_lsu_wmask,
    output [1:0]  io_lsu_size,
    input         io_lsu_respValid,
    input  [31:0] io_lsu_rdata
);

wire [6:0] opcode;
wire [4:0] rd;
wire [2:0] funct3;
wire [4:0] rs1, rs2;
wire [6:0] funct7;
wire [31:0] i_imm, s_imm, u_imm, bge_imm;

wire [31:0] rs1_data, rs2_data;
wire [31:0] a0_data;
wire        w_en;
wire [4:0]  w_rd;
wire [31:0] w_data;


wire        pc_sel;
wire [31:0] pc_target;
wire        if_busy;

ysyx_100023197_ifu u_fetch(
    .clock(clock),
    .reset(reset),
    .pc_sel(pc_sel),
    .pc_target(pc_target),
    .pc(pc),
    .io_ifu_addr(io_ifu_addr),
    .io_ifu_rdata(io_ifu_rdata),
    .inst(inst),
    .status(status),
    .if_busy(if_busy),
    .io_ifu_reqValid(io_ifu_reqValid),
    .io_ifu_respValid(io_ifu_respValid)
);

ysyx_100023197_idu u_decode(
    .inst(inst),
    .opcode(opcode),
    .rd(rd),
    .funct3(funct3),
    .rs1(rs1),
    .rs2(rs2),
    .funct7(funct7),
    .i_imm(i_imm),
    .s_imm(s_imm),
    .u_imm(u_imm),
    .bge_imm(bge_imm)
);

ysyx_100023197_register u_reg(
    .clock(clock),
    .reset(reset),
    .w_en(w_en),
    .rd(w_rd),
    .rs1(rs1),
    .rs2(rs2),
    .w_data(w_data),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .rd_data (rd_data),
    .a0_data(a0_data),
    .gpr_dump(gpr_dump)
);

ysyx_100023197_exu u_exec(
    .clock(clock),
    .reset(reset),
    .opcode(opcode),
    .rd(rd),
    .funct3(funct3),
    .funct7(funct7),
    .pc(pc),
    .i_imm(i_imm),
    .s_imm(s_imm),
    .u_imm(u_imm),
    .bge_imm(bge_imm),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .a0_data(a0_data),
    .io_lsu_rdata(io_lsu_rdata),
    .ifu_status(status),
    .lsu_status(lsu_status),
    .w_en(w_en),
    .w_rd(w_rd),
    .w_data(w_data),
    .io_lsu_wen(io_lsu_wen),
    .io_lsu_wmask(io_lsu_wmask),
    .io_lsu_addr(io_lsu_addr),
    .io_lsu_wdata(io_lsu_wdata),
    .pc_sel(pc_sel),
    .pc_target(pc_target),
    .io_lsu_reqValid(io_lsu_reqValid),
    .io_lsu_respValid(io_lsu_respValid),
    .io_lsu_size( io_lsu_size),
    .if_busy(if_busy)
);


always @(posedge clock or posedge reset) begin
    if (reset)                          led <= 16'd0;
    else if (io_lsu_wen && io_lsu_addr == 32'd0) led <= io_lsu_wdata[15:0];
end

assign commit = status && io_ifu_respValid && (!if_busy || lsu_status);

endmodule
