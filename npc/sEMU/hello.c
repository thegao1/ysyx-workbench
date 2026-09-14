#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>

#include "hello.h"
#define DECODE_ITYPE(raw_inst, rs1, rd, funct3, imm)        \
    do {                                                   \
        IType i_ins;                                       \
        i_ins.inst = (raw_inst);                           \
        (rs1)    = i_ins.ins.rs1;                          \
        (rd)     = i_ins.ins.rd;                           \
        (funct3) = i_ins.ins.funct3;                       \
        (imm)    = sign_ext(i_ins.ins.imm,12);             \
    } while (0)

uint32_t PC = 0x80000000;       
uint32_t  Reg[32];  

#define EMU_MEM_BASE 0x80000000u
#define EMU_MEM_SIZE (128u * 1024 * 1024)
uint8_t   M[EMU_MEM_SIZE];        // 字节内存数组
uint32_t inst;                   // 当前取出的32位指令
uint8_t  j_en;                   // 跳转使能标志
uint8_t  j_is_abs;               // 1=绝对跳转(jalr),0=相对跳转(B型)
uint32_t result;                 // ALU运算结果
uint8_t  halted;                 // ebreak 置 1，主循环看到就停


typedef union {
    uint32_t inst;
    struct {
        uint32_t opcode : 7;
        uint32_t rd     : 5;
        uint32_t funct3 : 3;
        uint32_t rs1    : 5;
        uint32_t rs2    : 5;
        uint32_t funct7 : 7;
    } ins;
} RType;

typedef union {
    uint32_t inst;
    struct {
        uint32_t opcode : 7;
        uint32_t rd     : 5;
        uint32_t funct3 : 3;
        uint32_t rs1    : 5;
        uint32_t imm    :12;
    } ins;
} IType;

typedef union {
    uint32_t inst;
    struct {
        uint32_t opcode   :7;
        uint32_t imm_low  :5;
        uint32_t funct3   :3;
        uint32_t rs1      :5;
        uint32_t rs2      :5;
        uint32_t imm_high :7;  
    } ins;
} SType;

typedef union {
    uint32_t inst;
    struct {
        uint32_t opcode  :7;
        uint32_t imm11   :1;
        uint32_t imm4_1  :4;
        uint32_t funct3  :3;
        uint32_t rs1     :5;
        uint32_t rs2     :5;
        uint32_t imm10_5 :6;
        uint32_t imm12   :1;      
    } ins;
} BType;

typedef union {
    uint32_t inst;
    struct{
        uint32_t opcode :7;
        uint32_t rd  :5;
        uint32_t imm :20;
    } ins;
} UType;

int32_t sign_ext(uint32_t val, int bit_cnt)
{
    int shift = 32 - bit_cnt;
    return (int32_t)(val << shift) >> shift;
}

uint32_t mem_read(uint32_t addr,uint8_t n){
    if (addr < EMU_MEM_BASE) return 0;
    uint32_t off = addr - EMU_MEM_BASE;
    if (off + n > sizeof(M)) return 0; // 边界保护：注意是 addr+n，不是 addr
    if(n == 1)
    {
        return M[off] & 0xFFu;
    }
    else if(n == 4)
    {
        uint32_t b0 = M[off];
        uint32_t b1 = M[off+1] << 8;
        uint32_t b2 = M[off+2] << 16;
        uint32_t b3 = M[off+3] << 24;
        return b0 | b1 | b2 | b3;
    }
    return 0;
}

// 写内存 sb/sw
void mem_write(uint32_t addr, uint32_t wdata, uint8_t n)
{
    if (addr < EMU_MEM_BASE) return;
    uint32_t off = addr - EMU_MEM_BASE;
    if (off + n > sizeof(M)) return; 
    if(n == 1)
    {
        M[off] = wdata & 0xFFu;
    }
    else if(n == 4)
    {
        M[off]   = (wdata >> 0) & 0xFF;
        M[off+1] = (wdata >> 8) & 0xFF;
        M[off+2] = (wdata >>16) & 0xFF;
        M[off+3] = (wdata >>24) & 0xFF;
    }
}

void fetch(void)
{
    uint32_t off = PC - EMU_MEM_BASE;
    if (PC < EMU_MEM_BASE || off + 3 >= sizeof(M)) { // 超出内存范围，返回全0指令
        inst = 0;
    } else {
        inst = M[off] | (M[off+1] << 8) | (M[off+2] << 16) | (M[off+3] << 24);
    }
    PC += 4;
    printf("Fetch PC=%d, inst=0x%08x\n", PC-4, inst);
}

int  emu_getpc(){
    return (int)PC;      
}
int  emu_getinst(){
    return (int)inst;
}
int emu_getgpr(int idx){
    if (idx < 0 || idx > 31) return 0;
    return (int)Reg[idx];
}
int emu_halted(){
    return halted;
}

int emu_init(const char *path)
{
    memset(M, 0, sizeof(M));
    for (int i = 0; i < 32; i++) Reg[i] = 0;
    PC       = EMU_MEM_BASE;
    inst     = 0;
    j_en     = 0;
    j_is_abs = 0;
    halted   = 0;

    if (path == NULL) return -1;

    FILE *fp = fopen(path, "rb");
    if (fp == NULL) { perror(path); return -1; }

    size_t n = fread(M, 1, sizeof(M), fp);
    fclose(fp);
    if (n == 0) { printf("emu_init: %s 是空文件\n", path); return -1; }

    printf("emu_init: 从 %s 读了 %zu 字节\n", path, n);
    return 0;
}
/*
    译码+执行ALU计算 decode
    返回：ALU结果；同时设置 j_en 跳转标志
*/
uint32_t decode(uint32_t raw_inst)
{
    uint8_t opcode = raw_inst & 0x7F;
    j_en = 0;
    j_is_abs = 0;
    result = 0;
    if (opcode == 0x33) // R-type add
    {
        RType r_ins;
        r_ins.inst = raw_inst;
        uint8_t rs1 = r_ins.ins.rs1;
        uint8_t rs2 = r_ins.ins.rs2;
        uint8_t rd  = r_ins.ins.rd;
        uint8_t funct3 = r_ins.ins.funct3;
        uint32_t rs1_data = Reg[rs1];
        uint32_t rs2_data = Reg[rs2];
        uint8_t funct7 = r_ins.ins.funct7;
        if (funct3 == 0 && funct7 == 0)
        {
            result = rs1_data + rs2_data;
            printf(" -> R-type add x%d, x%d, x%d | val=%u+%u=%u\n", rd, rs1, rs2, rs1_data, rs2_data, result);
        }
    }
    else if (opcode == 0x37) //lui U-type
    {
        UType u_ins;
        u_ins.inst =raw_inst;
        uint8_t rd = u_ins.ins.rd;
        uint32_t imm = u_ins.ins.imm;
        result =  imm <<12;
        printf(" -> U-type lui x%d, 0x%x | val=0x%08x\n", rd, imm, result);
    }
    else if (opcode == 0x13) // I-type addi
    {
        uint8_t rs1,rd,funct3;
        int32_t imm;
        DECODE_ITYPE(raw_inst, rs1, rd, funct3, imm);
        uint32_t rs1_data = Reg[rs1];
        if (funct3 == 0)
        {
            result = rs1_data + imm;
            printf(" -> I-type addi x%d, x%d, %d | val=%u+%d=%u\n", rd, rs1, imm, rs1_data, imm, result);
        }
    }
    else if(opcode ==0x67)  //jalr I-type
    {
        uint8_t rs1,rd,funct3;
        int32_t imm;
        DECODE_ITYPE(raw_inst, rs1, rd, funct3, imm);
        uint32_t rs1_data = Reg[rs1];
        if (funct3 == 0)
        {
            uint32_t target = (rs1_data + imm) & ~1U; // 最低位清零
            result = target;
            j_en = 1;
            j_is_abs = 1; // 绝对跳转
            if(rd!=0){
                 Reg[rd]= PC; // 返回地址=当前PC(已经+4)
            }
            printf(" -> I-type jalr x%d, %d(x%d) | target = %d, ra=%d\n", rd, imm, rs1, target, PC);
        }
    }
    else if(opcode == 0x73) // SYSTEM I-type: ecall / ebreak
    {
    uint8_t rs1,rd,funct3;
    int32_t imm;
    DECODE_ITYPE(raw_inst, rs1, rd, funct3, imm);
    (void)rs1; (void)rd; (void)funct3;   // ebreak 只用 imm
    if (funct3 == 0)
    {
        if(imm == 1) {
            // 原来是 exit(0)：进程直接没了，寄存器 dump 打不出来，
            // 而且退出码恒为 0 —— 测试跑失败了也看不出来。
            halted = 1;
        }
    }
}

    else if(opcode == 0x03) // I-type load lw/lbu
    {
        IType l_ins;
        l_ins.inst = raw_inst;
        uint8_t rd = l_ins.ins.rd;
        uint8_t rs1 = l_ins.ins.rs1;
        uint8_t funct3 = l_ins.ins.funct3;
        int32_t imm = sign_ext(l_ins.ins.imm, 12);
        uint32_t rs1_data = Reg[rs1];
        uint32_t addr = rs1_data + imm;
        if(funct3 == 0b010) // lw
        {
            uint32_t data = mem_read(addr,4);
            result= data;
            printf(" -> I-type lw x%d, %d(x%d) | addr=0x%08x data=0x%08x\n", rd, imm, rs1, addr, data);
        }
        else if(funct3 == 0b100) // lbu
        {
            uint32_t data = mem_read(addr,1);
            result = data;
            printf(" -> I-type lbu x%d, %d(x%d) | addr=0x%08x data=0x%02x\n", rd, imm, rs1, addr, data);
        }
    }
    else if(opcode == 0x23) // S-type sb/sw
    {
        SType s_ins;
        s_ins.inst = raw_inst;
        uint8_t rs1 = s_ins.ins.rs1;
        uint8_t rs2 = s_ins.ins.rs2;
        uint8_t funct3 = s_ins.ins.funct3;
        uint32_t imm_raw = (s_ins.ins.imm_high << 5) | s_ins.ins.imm_low;
        int32_t imm = sign_ext(imm_raw, 12);

        uint32_t rs1_data = Reg[rs1];
        uint32_t addr = rs1_data + imm;
        uint32_t wdata = Reg[rs2];

        if(funct3 == 0b000) // sb store byte
        {
            mem_write(addr, wdata, 1);
            printf(" -> S-type sb x%d, %d(x%d) | addr=0x%08x byte=0x%02x\n", rs2, imm, rs1, addr, wdata & 0xFF);
        }
        else if(funct3 == 0b010) // sw store word
        {
            mem_write(addr, wdata, 4);
            printf(" -> S-type sw x%d, %d(x%d) | addr=0x%08x word=0x%08x\n", rs2, imm, rs1, addr, wdata);
        }
    }
    else if (opcode == 0x63) // B-type beq
    {
        BType b_ins;
        b_ins.inst = raw_inst;
        uint8_t rs1 = b_ins.ins.rs1;
        uint8_t rs2 = b_ins.ins.rs2;
        uint8_t funct3 = b_ins.ins.funct3;
        uint32_t rs1_data = Reg[rs1];
        uint32_t rs2_data = Reg[rs2];
        uint32_t imm_raw = (b_ins.ins.imm12 <<12)
                        | (b_ins.ins.imm11 <<11)
                        | (b_ins.ins.imm10_5 <<5)
                        | (b_ins.ins.imm4_1 <<1);
        int32_t imm = sign_ext(imm_raw,13);
        if (funct3 == 0) // beq
        {
            if (rs1_data == rs2_data)
            {
                j_en = 1;
                j_is_abs =0;
                result = imm;
                printf(" -> B-type beq x%d, x%d, offset=%d | equal, jump\n", rs1, rs2, imm);
            }
            else
            {
                j_en = 0;
                printf(" -> B-type beq x%d, x%d, offset=%d | not equal\n", rs1, rs2, imm);
            }
        }
    }
    return result;
}

void execute(uint32_t raw_inst, uint32_t alu_res)
{
    uint8_t opcode = raw_inst & 0x7F;
    if (j_en)
    {
        if(j_is_abs){
            PC = alu_res;
        }else{
            PC = PC + alu_res;
        }
    }
    else
    {
        uint8_t rd;
        if(opcode == 0x33){
            RType r_ins;
            r_ins.inst = raw_inst;
            rd = r_ins.ins.rd;
        }else if(opcode == 0x13){
            IType i_ins;
            i_ins.inst = raw_inst;
            rd = i_ins.ins.rd;
        }else if(opcode == 0x03){
            IType i_ins;
            i_ins.inst = raw_inst;
            rd = i_ins.ins.rd;
        }else if(opcode == 0x37){
            UType u_ins;
            u_ins.inst = raw_inst;
            rd = u_ins.ins.rd;
        }else{
            return;
        }
        if(rd != 0){
            Reg[rd] = alu_res;
        }
    }
    Reg[0] = 0;
}

/* 执行一条指令：取指 -> 译码 -> 执行/写回。
   difftest 每拍调一次，跟 RTL 的一拍对齐。
   放这儿是因为要用到 decode() 和 execute()，它们都在上面定义。 */
void emu_step(){
    fetch();
    uint32_t alu_out = decode(inst);
    execute(inst, alu_out);
}

/* 把一个 32 位字按小端写进 M */
void load_word(uint32_t addr, uint32_t w)
{
    if (addr < EMU_MEM_BASE) return;
    uint32_t off = addr - EMU_MEM_BASE;
    if (off + 3 >= sizeof(M)) return;

    M[off]   = (w >> 0)  & 0xFF;
    M[off+1] = (w >> 8)  & 0xFF;
    M[off+2] = (w >> 16) & 0xFF;
    M[off+3] = (w >> 24) & 0xFF;
}
// 只有单独编 emulator 时才需要 main。
// Verilator 那条路不定义这个宏 —— 否则会跟 csrc/main.cpp 的 main 撞车。
#ifdef EMU_STANDALONE
int main(int argc, char **argv)
{
    if (argc < 2) {
        printf("用法: %s <xxx.bin>\n", argv[0]);
        return 2;
    }
    // emu_init 里已经把 PC / Reg / 内存 / halted 全复位好了，不用再手动清一遍
    if (emu_init(argv[1]) != 0) return 2;

    // 原来这里是 200 拍（给 test_isa 那 37 条玩具指令留的余量）。
    // 真实程序动辄几万条，add 就要跑十几万拍，所以放宽到 1000 万。
    const uint32_t MAX_CYCLE = 10000000;
    printf("==== minirvEMU start ====\n");
    for (uint32_t cycle = 0; cycle < MAX_CYCLE && !halted; cycle++) {
        printf("\nCycle %u\n", cycle);
        emu_step();
    }

    if (!halted) printf("\n!! 跑满 %u 拍还没停机（多半是跳转算错了）\n", MAX_CYCLE);

    printf("\n==== minirvEMU finish ====\n");
    for (int i = 0; i < 32; i++) {
        if (i % 8 == 0) printf("\n");
        printf("x%-2d=0x%08x  ", i, Reg[i]);
    }
    printf("\nPC = 0x%08x\n", PC);
    if (!halted) printf("\na0 = %u 但压根没跑到 ebreak ==> FAIL\n", Reg[10]);
    else printf("\na0 (退出码) = %u   ==> %s\n", Reg[10],
                Reg[10] == 0 ? "PASS" : "FAIL");
    return halted && Reg[10] == 0 ? 0 : 1;
}
#endif  // EMU_STANDALONE