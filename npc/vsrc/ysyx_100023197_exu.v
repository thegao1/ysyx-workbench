import "DPI-C" function void set_finish_flag(input int code);

module ysyx_100023197_exu(
    input             clock,
    input             reset,
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

reg [31:0] alu_w_data;

// LSU 的控制信息必须在发请求那一拍锁存下来。
// 原因：opcode/funct3/addr 都是从取指数据组合译码出来的，而 IFU 在 LSU 握手期间
// 会停发请求；若存储模型在 reqValid=0 时把 rdata 清零（独立模式的 mem.v 就是），
// 响应到达那一拍 opcode 已经变成 0，写回条件 opcode==OP_LOAD 就不再成立，
// load 的结果永远写不回寄存器堆（表现为 jr/jalr 读到旧值，程序跑飞）。
reg        lsu_is_load;
reg [4:0]  lsu_rd;
reg [2:0]  lsu_funct3;
reg [31:0] lsu_addr_q;
reg [31:0] lsu_wdata_q;
reg [3:0]  lsu_wmask_q;
reg [1:0]  lsu_size_q;
reg        lsu_wen_q;

// 事务进行中：SimpleBus 输出全部改用锁存值。
// 存储模型的 io_lsu_rdata 是按 io_lsu_addr 组合读出来的，地址一旦被
// 清掉的取指数据带着变成 0，读回的就是存储器 0 号单元（越界 → 0）。
wire       lsu_busy       = (lsu_status == 1'b1);
wire [2:0] lsu_funct3_eff = lsu_busy ? lsu_funct3 : funct3;

// 访存有效地址：load 用 I 型立即数、store 用 S 型立即数。
wire [31:0] lsu_eff_addr = (opcode == OP_LOAD) ? (rs1_data + i_imm)
                                              : (rs1_data + s_imm);

// 本拍是否要新发起一笔访存事务。
// 带 !lsu_busy：SoC 下取指数据不会被清掉，事务期间 opcode 仍是 LOAD/STORE，
// 不加这条会在响应拍把它又拉起来，重新冻住 IFU。
wire lsu_issue = ((opcode == OP_LOAD) || (opcode == OP_STORE)) &&
                 ifu_status && ifu_respValid && !lsu_done && !lsu_busy;

// ===== 块1：ALU + LSU 请求 + 控制（不读 io_lsu_rdata，避免组合环路）=====
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
            if (ifu_status == 1'b1 && funct3 == 3'b000 && i_imm == 32'd1) begin
                set_finish_flag(a0_data);
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

    // 事务期间改用锁存值驱动 SimpleBus（覆盖上面的组合译码结果）。
    // store 的实际写入发生在发请求的下一拍（mem.v 在 posedge 采样
    // reqValid && wen），那一拍取指数据可能已经被清掉，只有锁存值才靠得住。
    if (lsu_busy) begin
        io_lsu_addr  = lsu_addr_q;
        io_lsu_size  = lsu_size_q;
        io_lsu_wen   = lsu_wen_q;
        io_lsu_wmask = lsu_wmask_q;
        io_lsu_wdata = lsu_wdata_q;
    end

    // 提交门控（放在 case 之后，覆盖上面的赋值）：
    // 非 load/store 指令只在指令真正返回拍(status && respValid)写回/跳转。
    // SoC 慢速取指时 status=1 但 respValid=0 的等待拍，指令总线仍保持上一条
    // 指令，若放行会导致 ALU/JALR 被重复提交（寄存器反复累加、跳转目标错误）。
    // load/store 的多周期握手在下方单独处理，不在此冻结。
    if (!(ifu_status && ifu_respValid) &&
        opcode != OP_LOAD && opcode != OP_STORE) begin
        w_en   = 1'b0;
        pc_sel = 1'b0;
    end

    // load 写回：只在响应拍（respValid=1）写回，且用锁存的目的寄存器——
    // 这一拍 opcode/rd 可能已经被清掉，用实时的会写到 x0 上去。
    if (lsu_is_load && lsu_busy && io_lsu_respValid) begin
        w_en = 1'b1;
        w_rd = lsu_rd;
    end

    // if_busy: 访存指令从「译码出访存」那一拍起冻结 IFU，直到 LSU 响应到达拍为止。
    //
    // 响应拍必须放行，不能多冻一拍：DiffTest 在指令退休那一拍采样的是「执行前」的
    // 寄存器状态（采样后才 step 把写回和 pc 推进一起生效）。load 的写回使能就在
    // 响应拍，若响应拍还冻着 IFU，退休会推迟到下一拍，写回就比退休早一拍落地，
    // 采样时看到的已经是执行后的值，DiffTest 反而会报 EMU 落后一条。
    if_busy = lsu_issue || (lsu_busy && !io_lsu_respValid);
end

// ===== 块2：写回数据选择（读 io_lsu_rdata，但只输出 w_data，不再驱动 io_lsu_wen）=====
// SimpleBus 的 io_lsu_rdata 是「地址所在的那个 32 位字」，MemBridge 不做对齐抽取，
// 字节/半字必须由 CPU 自己用 io_lsu_addr[1:0] 挑。原先固定取 [7:0]，
// 于是 lb/lbu 永远返回字对齐地址的 0 号字节：loader 读 ELF magic 得到 7f 7f 7f 7f，
// buf[1]=='E' 断言失败 → AM Panic @ loader.c:39。
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
        // idle：识别到 load/store，只在取指响应拍（ifu_respValid=1）发请求。
        // 否则新指令取指等待拍 opcode 仍残留上一条 load/store，会重复发起 LSU 读，
        // 与 MemBridge 的 AXI 读响应错位（IFU 拿到 LSU 的数据、真取指数据被 LSU 通道吞掉）。
        lsu_status  <= 1'b1;
        io_lsu_reqValid <= 1'b1;
        // 发请求这一拍把整笔事务的参数锁存下来（见文件开头 reg 声明的注释）
        lsu_is_load <= (opcode == OP_LOAD);
        lsu_rd      <= rd;
        lsu_funct3  <= funct3;
        lsu_addr_q  <= lsu_eff_addr;
        lsu_size_q  <= funct3[1:0];
        // 只有 sb/sh/sw 三种合法宽度才真的写；非法 funct3 保持 wmask=0、wen=0。
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