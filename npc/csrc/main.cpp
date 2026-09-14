#include <Vtop.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../sEMU/hello.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

extern "C" bool get_sim_finish(void);
extern "C" int  get_sim_exit_code(void);
extern "C" void pmem_init(const char *img);

static const char *DEFAULT_IMG =
    "../am-kernels/tests/cpu-tests/build/dummy-minirv-npc.bin";

#define MAX_CYCLES 1000000000

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);

    Vtop *tb = new Vtop;
    Verilated::traceEverOn(true);

    VerilatedVcdC *tfp = nullptr;
    if (std::getenv("NPC_TRACE") != nullptr) {
        tfp = new VerilatedVcdC;
        tb->trace(tfp, 99);
        tfp->open("wave.vcd");
    }

    // RTL 和参考模型必须加载同一个镜像，否则两边跑的根本不是同一个程序。
    const char *img = (argc > 1) ? argv[1] : DEFAULT_IMG;
    pmem_init(img);
    if (emu_init(img) != 0) {
        std::printf("emu_init 失败: %s\n", img);
        return 1;
    }

    uint64_t sim_time = 0;
    auto step = [&]() {                 // 推进一个时钟周期
        tb->clk = 0; tb->eval();
        if (tfp) tfp->dump(sim_time);
        sim_time++;
        tb->clk = 1; tb->eval();
        if (tfp) tfp->dump(sim_time);
        sim_time++;
    };

    // 复位：先拉高 rst 走两拍，再放开。
    tb->rst = 1; tb->clk = 0; tb->eval();
    step(); step();
    tb->rst = 0;

    // ───────────────────────────────────────────────────────────────
    // difftest 主循环
    //
    // 对齐关系（k = 两边各自已经走完的条数）：
    //   RTL 第 k 拍（posedge 之前）: pc=addr(k), inst=inst(k), 寄存器堆=state_k
    //   EMU 走完 k 步:              PC=addr(k), inst=inst(k-1), Reg=state_k
    //                                              ^ emu 的 inst 慢一条
    //
    // 原因：hello.c 的 fetch() 是先取 inst 再 PC+=4，所以 emu 那边 PC 指向
    // 下一条时，inst 还停在上一条。RTL 则是 inst=pmem_read(pc) 组合读，同拍。
    //
    // 所以 pc 和 32 个 GPR 在 step() 之前比（两边都停在 state_k），
    // inst 必须等两边各走一步之后才比。
    // ───────────────────────────────────────────────────────────────
    uint64_t cycles    = 0;
    int      diff_fail = 0;

    while (!emu_halted() && !Verilated::gotFinish() && cycles < MAX_CYCLES) {
        // Verilator 生成的端口是普通成员变量，不是函数 —— 不能写 tb->pc()
        uint32_t rtl_inst = tb->inst;       // 先采下来，等下才轮到它比

        // ---- pc：两边同拍 ----
        uint32_t rtl_pc = tb->pc;
        uint32_t emu_pc = (uint32_t)emu_getpc();
        if (rtl_pc != emu_pc) {
            std::printf("DIFF pc    @cycle %llu  NPC:0x%08x  EMU:0x%08x\n",
                        (unsigned long long)cycles, rtl_pc, emu_pc);
            diff_fail = 1;
            break;
        }

        // ---- GPR：32 个全比（此时两边都是 state_k）----
        // x0 也一起比 —— 两边都该恒为 0，正好是个免费的自检。
        int bad = -1;
        for (int i = 0; i < 32; i++) {
            uint32_t rtl = (uint32_t)tb->gpr_dump[i];
            uint32_t emu = (uint32_t)emu_getgpr(i);
            if (rtl != emu) {
                std::printf("DIFF x%-2d   @cycle %llu  NPC:0x%08x  EMU:0x%08x\n",
                            i, (unsigned long long)cycles, rtl, emu);
                bad = i;
                break;
            }
        }
        if (bad >= 0) { diff_fail = 1; break; }

        step();        // RTL -> 第 k+1 拍
        emu_step();    // EMU -> 执行完第 k 条

        // ---- inst：emu 的 inst 慢一条，到这之后才对齐 ----
        uint32_t emu_inst = (uint32_t)emu_getinst();
        if (emu_inst != rtl_inst) {
            std::printf("DIFF inst  @cycle %llu  NPC:0x%08x  EMU:0x%08x\n",
                        (unsigned long long)cycles, rtl_inst, emu_inst);
            diff_fail = 1;
            break;
        }

        cycles++;
    }

    tb->final();                        // 必须调，不然波形收尾不完整
    if (tfp) { tfp->close(); delete tfp; }
    delete tb;

    if (diff_fail) {
        std::printf("==== difftest FAIL @cycle %llu ====\n",
                    (unsigned long long)cycles);
        return 1;
    }

    // 两边都该在 ebreak 上停下。只停一边，说明 ebreak 的语义对不上，也是 bug。
    if (emu_halted() != get_sim_finish()) {
        std::printf("==== 结束状态不一致：EMU halted=%d, RTL finish=%d ====\n",
                    emu_halted(), (int)get_sim_finish());
        return 1;
    }

    if (get_sim_finish()) {
        int code = get_sim_exit_code();
        if (code == 0) {
            std::printf("HIT GOOD TRAP\n");
            return 0;                   // 程序正常结束
        }
        std::printf("HIT BAD TRAP, a0 = %d (0x%08x)\n", code, (unsigned)code);
        return 1;                       // 程序自己报错，让 Makefile 判 FAIL
    }

    // 没执行到 ebreak
    if (Verilated::gotFinish())
        std::printf("==== RTL 里执行了 $finish，但程序还没执行 ebreak ====\n");
    else
        std::printf("==== 程序没有执行 ebreak，跑满 %llu 拍强制停机 ====\n",
                    (unsigned long long)cycles);
    return 1;
}
