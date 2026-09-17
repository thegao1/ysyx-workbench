import "DPI-C" function void set_finish_flag(input int code);

module execute(
    input             clk,
    input             rst,
    input      [6:0]  opcode,
    input      [4:0]  rd,
    input      [2:0]  funct3,
    input      [6:0]  funct7,
    input      [31:0] pc,
    input      [31:0] i_imm,
    input      [31:0] s_imm,
    input      [31:0] u_imm,
    input      [31:0] bge_imm,
    input      [31:0] rs1_data,
    input      [31:0] rs2_data,
    input      [31:0] a0_data,
    input      [31:0] lsu_rdata,
    input             ifu_status,
    input             lsu_respvalid,
    output reg        lsu_reqvalid,
    output reg        lsu_status,
    output reg        w_en,
    output reg [4:0]  w_rd,
    output reg [31:0] w_data,
    output reg        lsu_wen,
    output reg [3:0]  lsu_wmask,
    output reg [31:0] lsu_addr,
    output reg [31:0] lsu_wdata,
    output reg        pc_sel,
    output reg        if_busy,
    output reg [31:0] pc_target
);

localparam OP_R      = 7'b0110011;
localparam OP_I      = 7'b0010011;
localparam OP_U      = 7'b0110111;
localparam OP_ebreak = 7'b1110011;
localparam OP_LOAD   = 7'b0000011;
localparam OP_STORE  = 7'b0100011;
localparam OP_JALR   = 7'b1100111;
localparam OP_BRANCH = 7'b1100011;

reg [31:0] alu_w_data;

// ===== 块1：ALU + LSU 请求 + 控制（不读 lsu_rdata，避免组合环路）=====
always @(*) begin
    w_en       = 1'b0;
    w_rd       = rd;
    alu_w_data = 32'd0;
    lsu_wen    = 1'b0;
    lsu_wmask  = 4'b0000;
    lsu_addr   = 32'd0;
    lsu_wdata  = 32'd0;
    pc_sel     = 1'b0;
    pc_target  = 32'd0;
    if_busy    = 1'b0;
    case (opcode)
        OP_R: begin
            if (funct3 == 3'b000 && funct7 == 7'b0000000) begin
                w_en   = 1'b1;
                alu_w_data = rs1_data + rs2_data;
            end
        end
        OP_I: begin
            if (funct3 == 3'b000) begin
                w_en   = 1'b1;
                alu_w_data = rs1_data + i_imm;
            end
        end
        OP_ebreak: begin
            if (ifu_status == 1'b1 && funct3 == 3'b000 && i_imm == 32'd1) begin
                set_finish_flag(a0_data);
            end
        end
        OP_U: begin
            w_en   = 1'b1;
            alu_w_data = u_imm;
        end
        OP_LOAD: begin
            lsu_addr = rs1_data + i_imm;
        end
        OP_STORE: begin
            lsu_addr = rs1_data + s_imm;
            lsu_wen  = 1'b1;
            case (funct3)
                3'b000: begin
                    lsu_wmask = 4'b0001 << lsu_addr[1:0];
                    lsu_wdata = rs2_data << {lsu_addr[1:0], 3'b000};
                end
                3'b010: begin
                    lsu_wmask = 4'b1111;
                    lsu_wdata = rs2_data;
                end
                default: lsu_wen = 1'b0;
            endcase
        end
        OP_JALR: begin
            if (funct3 == 3'b000) begin
                w_en      = 1'b1;
                alu_w_data= pc + 32'd4;
                pc_sel    = 1'b1;
                pc_target = (rs1_data + i_imm) & ~32'd1;
            end
        end
        OP_BRANCH: begin
            pc_target = pc + bge_imm;
            pc_sel    = (funct3 == 3'b101) &&
                        ($signed(rs1_data) >= $signed(rs2_data));
        end
        default: ;
    endcase

    // idle 拍冻结所有提交使能（放在 case 之后，覆盖上面的赋值）
    if (ifu_status == 1'b0) begin
        w_en   = 1'b0;
        lsu_wen = 1'b0;
        pc_sel = 1'b0;
    end

    // load 写回：只在发请求当拍（lsu_status=1 且响应未到）写回，
    // 响应到达后（lsu_respvalid=1）立即关 w_en，防止 lsu_addr 重算导致二次写回
    if (opcode == OP_LOAD && lsu_status == 1'b1 && !lsu_respvalid) begin
        w_en = 1'b1;
    end

    // if_busy: load/store 还在等数据时(lsu_status==0)，让 IFU 多等一拍
    if_busy = (opcode == OP_LOAD) && (lsu_status == 1'b0) || (opcode == OP_STORE) && (lsu_status == 1'b0);
end

// ===== 块2：写回数据选择（读 lsu_rdata，但只输出 w_data，不再驱动 lsu_wen）=====
wire [31:0] load_wdata;
assign load_wdata = (funct3 == 3'b000) ? {{24{lsu_rdata[7]}}, lsu_rdata[7:0]} :  // lb
                    (funct3 == 3'b100) ? {24'b0, lsu_rdata[7:0]}               :  // lbu
                    lsu_rdata;                                                     // lw

always @(*) begin
    w_data = alu_w_data;
    if (opcode == OP_LOAD && lsu_status == 1'b1) begin
        w_data = load_wdata;
        
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lsu_status  <= 1'b0;
        lsu_reqvalid <= 1'b0;
    end else if (lsu_status == 1'b1) begin
        // 等待状态：只要响应到达就完成，不受当前指令类型限制
        if (lsu_respvalid) begin
            lsu_status  <= 1'b0;
            lsu_reqvalid <= 1'b0;
        end
    end else if ((opcode == OP_LOAD || opcode == OP_STORE) && ifu_status == 1'b1) begin
        // idle：识别到 load/store，发请求
        lsu_status  <= 1'b1;
        lsu_reqvalid <= 1'b1;
    end
end
endmodule