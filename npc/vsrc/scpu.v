module scpu(
    input  clk,
    input  rst,
    output reg [15:0] led,
    output [31:0] inst,
    output [31:0] pc,
    output [31:0] rd_data,
    output [1023:0] gpr_dump,
    output        status,
    output        lsu_status,
    output        commit

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

wire        lsu_wen;
wire [3:0]  lsu_wmask;
wire [31:0] lsu_addr, lsu_wdata;

wire        pc_sel;
wire [31:0] pc_target;
wire        if_busy;
// IFU <-> MEM 取指总线
wire [31:0] ifu_raddr;
wire [31:0] ifu_rdata;

// LSU <-> MEM 访存总线
wire [31:0] lsu_rdata;
wire        ifu_reqvalid;
wire        ifu_respvalid;

wire        lsu_reqvalid;
wire        lsu_respvalid;

fetch u_fetch(
    .clk(clk),
    .rst(rst),
    .pc_sel(pc_sel),
    .pc_target(pc_target),
    .pc(pc),
    .ifu_raddr(ifu_raddr),
    .ifu_rdata(ifu_rdata),
    .inst(inst),
    .status(status),
    .if_busy(if_busy),
    .ifu_reqvalid(ifu_reqvalid),
    .ifu_respvalid(ifu_respvalid)
);

decode u_decode(
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

register_file u_reg(
    .clk(clk),
    .rst(rst),
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

execute u_exec(
    .clk(clk),
    .rst(rst),
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
    .lsu_rdata(lsu_rdata),
    .ifu_status(status),
    .lsu_status(lsu_status),
    .w_en(w_en),
    .w_rd(w_rd),
    .w_data(w_data),
    .lsu_wen(lsu_wen),
    .lsu_wmask(lsu_wmask),
    .lsu_addr(lsu_addr),
    .lsu_wdata(lsu_wdata),
    .pc_sel(pc_sel),
    .pc_target(pc_target),
    .lsu_reqvalid(lsu_reqvalid),
    .lsu_respvalid(lsu_respvalid),
    .if_busy(if_busy)
);

mem u_mem(
    .clk(clk),
    .lsu_wen(lsu_wen),
    .lsu_wmask(lsu_wmask),
    .lsu_wdata(lsu_wdata),
    .ifu_raddr(ifu_raddr),
    .ifu_rdata(ifu_rdata),
    .lsu_addr(lsu_addr),
    .ifu_reqvalid(ifu_reqvalid),
    .ifu_respvalid(ifu_respvalid),
    .lsu_rdata(lsu_rdata),
    .lsu_reqvalid(lsu_reqvalid),
    .lsu_respvalid(lsu_respvalid)

);

always @(posedge clk or posedge rst) begin
    if (rst)                          led <= 16'd0;
    else if (lsu_wen && lsu_addr == 32'd0) led <= lsu_wdata[15:0];
end

assign commit = status && ifu_respvalid && (!if_busy || lsu_status);

endmodule
