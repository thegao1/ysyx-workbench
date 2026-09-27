// set_finish_flag 是仿真专用的 DPI-C 函数，综合器不认识它，
// 所以综合时（-DSYNTHESIS / +define+SYNTHESIS）把它整段去掉。
`ifndef SYNTHESIS
import "DPI-C" function void set_finish_flag(input int code);
`endif

module ysyx_100023197_exu(
    input             clock,
    input             reset,
    input      [6:0]  opcode,
    input      [4:0]  rd,
    input      [2:0]  funct3,
    input      [6:0]  funct7,
    input      [11:0] csr_addr,
    input      [31:0] pc,
    input      [31:0] i_imm,
    input      [31:0] s_imm,
    input      [31:0] u_imm,
    input      [31:0] bge_imm,
    input      [31:0] rs1_data,
    input      [31:0] rs2_data,
    input      [31:0] a0_data,
    input      [31:0] io_lsu_rdata,
    input             ifu_status,
    input             ifu_respValid,
    input             io_lsu_respValid,
    output reg        io_lsu_reqValid,
    output reg        lsu_status,
    output reg        lsu_done,
    output reg        w_en,
    output reg [4:0]  w_rd,
    output reg [31:0] w_data,
    output reg        io_lsu_wen,
    output reg [3:0]  io_lsu_wmask,
    output reg [1:0]  io_lsu_size,
    output reg [31:0] io_lsu_addr,
    output reg [31:0] io_lsu_wdata,
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

reg [63:0] cycle_cnt;
reg [31:0] alu_w_data;


reg        lsu_is_load;
reg [4:0]  lsu_rd;
reg [2:0]  lsu_funct3;
reg [31:0] lsu_addr_q;
reg [31:0] lsu_wdata_q;
reg [3:0]  lsu_wmask_q;
reg [1:0]  lsu_size_q;
reg        lsu_wen_q;


wire       lsu_busy       = (lsu_status == 1'b1);
wire [2:0] lsu_funct3_eff = lsu_busy ? lsu_funct3 : funct3;

// 访存有效地址：load 用 I 型立即数、store 用 S 型立即数。
wire [31:0] lsu_eff_addr = (opcode == OP_LOAD) ? (rs1_data + i_imm)
                                              : (rs1_data + s_imm);

wire lsu_issue = ((opcode == OP_LOAD) || (opcode == OP_STORE)) &&
                 ifu_status && ifu_respValid && !lsu_done && !lsu_busy;

always @(*) begin
    w_en       = 1'b0;
    w_rd       = rd;
    alu_w_data = 32'd0;
    io_lsu_wen    = 1'b0;
    io_lsu_size   = 2'b00;
    io_lsu_wmask  = 4'b0000;
    io_lsu_addr   = 32'd0;
    io_lsu_wdata  = 32'd0;
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
`ifndef SYNTHESIS
            if (ifu_status == 1'b1 && funct3 == 3'b000 && i_imm == 32'd1) begin
                set_finish_flag(a0_data);
            end
`endif
            if (funct3 == 3'b010) begin
                w_en   =1'b1;
                case(csr_addr) 
                    12'hF11 : alu_w_data = 32'h79737978;
                    12'hF12 : alu_w_data = 32'h10023197;
                    12'hB00 : alu_w_data = cycle_cnt[31:0];
                    12'hB80 : alu_w_data = cycle_cnt[63:32];
                    default : alu_w_data = 32'h0;
                endcase
            end
        end
        OP_U: begin
            w_en   = 1'b1;
            alu_w_data = u_imm;
        end
        OP_LOAD: begin
            io_lsu_addr = rs1_data + i_imm;
            io_lsu_size = funct3[1:0];
        end
        OP_STORE: begin
            io_lsu_addr = rs1_data + s_imm;
            io_lsu_wen  = 1'b1;
            io_lsu_size = funct3[1:0];
            case (funct3)
                3'b000: begin
                    io_lsu_wmask = 4'b0001 << io_lsu_addr[1:0];
                    io_lsu_wdata = rs2_data << {io_lsu_addr[1:0], 3'b000};
                end
                3'b001: begin
                    io_lsu_wmask = 4'b0011 << {io_lsu_addr[1], 1'b0};
                    io_lsu_wdata = rs2_data << {io_lsu_addr[1], 4'b0000};
                end
                3'b010: begin
                    io_lsu_wmask = 4'b1111;
                    io_lsu_wdata = rs2_data;
                end
                default: io_lsu_wen = 1'b0;
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


    if (lsu_busy) begin
        io_lsu_addr  = lsu_addr_q;
        io_lsu_size  = lsu_size_q;
        io_lsu_wen   = lsu_wen_q;
        io_lsu_wmask = lsu_wmask_q;
        io_lsu_wdata = lsu_wdata_q;
    end

    if (!(ifu_status && ifu_respValid) &&
        opcode != OP_LOAD && opcode != OP_STORE) begin
        w_en   = 1'b0;
        pc_sel = 1'b0;
    end

    if (lsu_is_load && lsu_busy && io_lsu_respValid) begin
        w_en = 1'b1;
        w_rd = lsu_rd;
    end

    if_busy = lsu_issue || (lsu_busy && !io_lsu_respValid);
end


wire [7:0]  lsu_byte = io_lsu_rdata[{io_lsu_addr[1:0], 3'b000} +: 8];
wire [15:0] lsu_half = io_lsu_rdata[{io_lsu_addr[1],   4'b0000} +: 16];

wire [31:0] load_wdata;
assign load_wdata = (lsu_funct3_eff == 3'b000) ? {{24{lsu_byte[7]}},  lsu_byte}  :  // lb
                    (lsu_funct3_eff == 3'b100) ? {24'b0,                lsu_byte}  :  // lbu
                    (lsu_funct3_eff == 3'b001) ? {{16{lsu_half[15]}},  lsu_half}  :  // lh
                    (lsu_funct3_eff == 3'b101) ? {16'b0,                lsu_half}  :  // lhu
                    io_lsu_rdata;                                                  // lw

always @(*) begin
    w_data = alu_w_data;
    if (lsu_is_load && lsu_busy) begin
        w_data = load_wdata;
    end
    
end

// mcycle 计数器：只有"复位清零 + 每拍自增"，单独写成一块，
// 这样综合器才能认出标准的"异步复位"结构。
always @(posedge clock or posedge reset) begin
    if (reset) cycle_cnt <= 64'h0;
    else       cycle_cnt <= cycle_cnt + 1;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        lsu_status  <= 1'b0;
        lsu_done    <= 1'b0;
        io_lsu_reqValid <= 1'b0;
        lsu_is_load <= 1'b0;
        lsu_rd      <= 5'd0;
        lsu_funct3  <= 3'd0;
        lsu_addr_q  <= 32'd0;
        lsu_wdata_q <= 32'd0;
        lsu_wmask_q <= 4'd0;
        lsu_size_q  <= 2'd0;
        lsu_wen_q   <= 1'b0;
    end else if (lsu_status == 1'b1) begin
        // 等待状态：只要响应到达就完成，不受当前指令类型限制
        if (io_lsu_respValid) begin
            lsu_status  <= 1'b0;
            lsu_done    <= 1'b1;
            io_lsu_reqValid <= 1'b0;
        end
    end else if ((opcode == OP_LOAD || opcode == OP_STORE) && ifu_status == 1'b1 && ifu_respValid && !lsu_done) begin
        lsu_status  <= 1'b1;
        io_lsu_reqValid <= 1'b1;
        lsu_is_load <= (opcode == OP_LOAD);
        lsu_rd      <= rd;
        lsu_funct3  <= funct3;
        lsu_addr_q  <= lsu_eff_addr;
        lsu_size_q  <= funct3[1:0];
        lsu_wen_q   <= (opcode == OP_STORE) &&
                       (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b010);
        lsu_wmask_q <= 4'b0000;
        lsu_wdata_q <= 32'd0;
        case (funct3)
            3'b000: begin
                lsu_wmask_q <= 4'b0001 << lsu_eff_addr[1:0];
                lsu_wdata_q <= rs2_data << {lsu_eff_addr[1:0], 3'b000};
            end
            3'b001: begin
                lsu_wmask_q <= 4'b0011 << {lsu_eff_addr[1], 1'b0};
                lsu_wdata_q <= rs2_data << {lsu_eff_addr[1], 4'b0000};
            end
            3'b010: begin
                lsu_wmask_q <= 4'b1111;
                lsu_wdata_q <= rs2_data;
            end
            default: ;
        endcase
    end else if (lsu_done) begin
        // 完成拍：清 done，IFU 已解冻提交
        lsu_done <= 1'b0;
    end
end
endmodule