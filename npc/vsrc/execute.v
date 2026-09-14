// code 是 ebreak 前 a0 的值。签名要和 csrc/dpi_sim.cpp 里的定义对上，
// 少写参数会报 Too many arguments in call to task 'set_finish_flag'。
import "DPI-C" function void set_finish_flag(input int code);

module execute(
    input      [6:0]  opcode,
    input      [4:0]  rd,
    input      [2:0]  funct3,
    input      [6:0]  funct7,
    input      [31:0] pc,        // 当前指令的 PC（jalr 要算 pc+4）
    input      [31:0] i_imm,     // decode 已符号扩展
    input      [31:0] s_imm,
    input      [31:0] u_imm,
    input      [31:0] bge_imm,   // B 型（分支用）
    input      [31:0] rs1_data,
    input      [31:0] rs2_data,
    input      [31:0] r_data,    // mem 读回来的数据
    input      [31:0] a0_data,
    // 写回寄存器堆
    output reg        w_en,
    output reg [4:0]  w_rd,
    output reg [31:0] w_data,

    // 写内存
    output reg        mw_en,
    output reg [3:0]  mw_mask,   // 字节使能，4 位（不是 3 位）
    output reg [31:0] mw_addr,
    output reg [31:0] mw_data,

    // 读内存
    output reg        mr_en,
    output reg [31:0] mr_addr,

    // 下一条 PC
    output reg        pc_sel,
    output reg [31:0] pc_target

);

// 操作码
localparam OP_R     = 7'b0110011;   // add
localparam OP_I     = 7'b0010011;   // addi
localparam OP_U     = 7'b0110111;   // lui
localparam OP_ebreak= 7'b1110011;   //ebreak
localparam OP_LOAD = 7'b0000011;   // lb / lh / lw / lbu / lhu
localparam OP_STORE = 7'b0100011;   // sb / sh / sw
localparam OP_JALR  = 7'b1100111;   // jalr
localparam OP_BRANCH= 7'b1100011;   // bge

// 实验 B：把「读 r_data」这件事从主组合块里搬出去
reg [31:0] alu_w_data;   // 非 load 指令的写回数据

always @(*) begin
    w_en      = 1'b0;
    w_rd      = rd;
    alu_w_data= 32'd0;
    mw_en     = 1'b0;
    mw_mask   = 4'b0000;
    mw_addr   = 32'd0;
    mw_data   = 32'd0;
    mr_en     = 1'b0;
    mr_addr   = 32'd0;
    pc_sel    = 1'b0;
    pc_target = 32'd0;

    case (opcode)
        // add 
        OP_R: begin
            if (funct3 == 3'b000 && funct7 == 7'b0000000) begin
                w_en   = 1'b1;
                alu_w_data = rs1_data + rs2_data;
            end
        end
        // li
        OP_I: begin
            if (funct3 == 3'b000) begin
                w_en   = 1'b1;
                alu_w_data = rs1_data + i_imm;   // i_imm 已经是 32 位符号扩展好的
            end
        end
        OP_ebreak :begin
             if(funct3 == 3'b000 && i_imm == 32'd1) begin
                set_finish_flag(a0_data);
            end
        end
        // lui
        OP_U: begin
            w_en   = 1'b1;
            alu_w_data = u_imm;
        end
        //读内存 
        OP_LOAD: begin
            mr_en   = 1'b1;
            mr_addr = rs1_data + i_imm;
            w_en    = 1'b1;
            case (funct3)
                3'b000, 3'b100, 3'b010: ;   // 数据在下面单独的组合块里选
                default: w_en   = 1'b0;
            endcase
        end

        // 写内存
        OP_STORE: begin
            mw_en   = 1'b1;
            mw_addr = rs1_data + s_imm;
            case (funct3)
                3'b000: begin  
                    mw_mask = 4'b0001 << mw_addr[1:0];
                    mw_data = rs2_data << {mw_addr[1:0], 3'b000};
                end
                3'b010: begin   // sw：全字
                    mw_mask = 4'b1111;
                    mw_data = rs2_data;
                end
                default: mw_en = 1'b0;
            endcase
        end

        // jalr
        OP_JALR: begin
            if (funct3 == 3'b000) begin
                w_en      = 1'b1;
                alu_w_data= pc + 32'd4;
                pc_sel    = 1'b1;
                pc_target = (rs1_data + i_imm) & ~32'd1;
            end
        end

        // bge
        OP_BRANCH: begin
            pc_target = pc + bge_imm;
            pc_sel    = (funct3 == 3'b101) &&
                        ($signed(rs1_data) >= $signed(rs2_data));
        end

        default: ;   //
    endcase
end

always @(*) begin
    if (w_en && opcode == OP_LOAD) begin
        case (funct3)
            3'b000:  w_data = {{24{r_data[7]}}, r_data[7:0]};   // lb
            3'b100:  w_data = {24'b0, r_data[7:0]};             // lbu
            3'b010:  w_data = r_data;                           // lw
            default: w_data = 32'd0;
        endcase
    end
    else w_data = alu_w_data;
end

endmodule
