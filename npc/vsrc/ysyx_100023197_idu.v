
module ysyx_100023197_idu(
    input      [31:0] inst,

    output [6:0]  opcode,
    output [4:0]  rd,
    output [2:0]  funct3,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output [6:0]  funct7,
    output [31:0] i_imm,    // I 型：addi / lw / lbu / jalr
    output [31:0] s_imm,    // S 型：sw / sb
    output [31:0] u_imm,    // U 型：lui
    output [31:0] bge_imm   // B 型
);

assign opcode = inst[6:0];
assign rd     = inst[11:7];
assign funct3 = inst[14:12];
assign rs1    = inst[19:15];
assign rs2    = inst[24:20];
assign funct7 = inst[31:25];

assign i_imm  = {{20{inst[31]}}, inst[31:20]};
assign s_imm  = {{20{inst[31]}}, inst[31:25], inst[11:7]};
assign u_imm  = {inst[31:12], 12'b0};

assign bge_imm = {{19{inst[31]}}, inst[31], inst[7],
                  inst[30:25], inst[11:8], 1'b0};

endmodule
