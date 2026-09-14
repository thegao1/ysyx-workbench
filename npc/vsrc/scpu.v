
module scpu(
    input  clk,
    input  rst,
    output reg [15:0] led,
    output [31:0] inst,
    output [31:0] pc,
    output [31:0] rd_data,
    output [1023:0] gpr_dump
);

// ---------- decode ----------
wire [6:0] opcode;
wire [4:0] rd;
wire [2:0] funct3;
wire [4:0] rs1, rs2;
wire [6:0] funct7;
wire [31:0] i_imm, s_imm, u_imm, bge_imm;

// ---------- register_file ----------
// rd_data 已经是模块的输出端口，这里不能再声明一根同名 wire
wire [31:0] rs1_data, rs2_data;
wire [31:0] a0_data;
wire        w_en;
wire [4:0]  w_rd;
wire [31:0] w_data;

// ---------- execute <-> mem ----------
wire        mw_en;
wire [3:0]  mw_mask;
wire [31:0] mw_addr, mw_data;
wire        mr_en;
wire [31:0] mr_addr;
wire [31:0] r_data;

// ---------- execute -> fetch ----------
wire        pc_sel;
wire [31:0] pc_target;

// ---------- 例化：一条直线，没有回路 ----------
fetch u_fetch(
    .clk(clk),
    .rst(rst),
    .pc_sel(pc_sel),
    .pc_target(pc_target),
    .pc(pc),
    .inst(inst)
);

// bge_imm 悬空会报 PINMISSING（Verilator 默认把 warning 当 error），所以接满
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
    .r_data(r_data),
    .w_en(w_en),
    .w_rd(w_rd),
    .w_data(w_data),
    .mw_en(mw_en),
    .mw_mask(mw_mask),
    .mw_addr(mw_addr),
    .mw_data(mw_data),
    .mr_en(mr_en),
    .mr_addr(mr_addr),
    .pc_sel(pc_sel),
    .pc_target(pc_target)
);

mem u_mem(
    .clk(clk),
    .mw_en(mw_en),
    .mw_mask(mw_mask),
    .mw_addr(mw_addr),
    .mw_data(mw_data),
    .mr_en(mr_en),
    .mr_addr(mr_addr),
    .r_data(r_data)
);

// ---------- 老调试通道：store 到地址 0 就点亮 LED ----------
always @(posedge clk or posedge rst) begin
    if (rst)                          led <= 16'd0;
    else if (mw_en && mw_addr == 32'd0) led <= mw_data[15:0];
end

endmodule
