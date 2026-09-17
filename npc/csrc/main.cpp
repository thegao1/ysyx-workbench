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
extern "C" void refresh_time(void);

static const char *DEFAULT_IMG =
    "../am-kernels/tests/cpu-tests/build/dummy-minirv-npc.bin";

#define MAX_CYCLES 10000000000

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

    const char *img = (argc > 1) ? argv[1] : DEFAULT_IMG;
    pmem_init(img);
    if (emu_init(img) != 0) {
        std::printf("emu_init 失败: %s\n", img);
        return 1;
    }

    uint64_t sim_time = 0;
    auto step = [&]() {
        tb->clk = 0; tb->eval();
        if (tfp) tfp->dump(sim_time);
        sim_time++;
        tb->clk = 1; tb->eval();
        if (tfp) tfp->dump(sim_time);
        sim_time++;
    };

    tb->rst = 1; tb->clk = 0; tb->eval();
    step(); step();
    tb->rst = 0;

    uint64_t cycles    = 0;
    int      diff_fail = 0;
    uint64_t insts     = 0;
    while (!emu_halted() && !Verilated::gotFinish() && cycles < MAX_CYCLES) {

        if (!tb->commit) {  // 指令未提交（IFU idle 或 load 发地址周期），跳过对比
            step();
            cycles++;
            continue;
        }
        uint32_t rtl_inst = tb->inst;
        insts++;

        uint32_t rtl_pc = tb->pc;
        uint32_t emu_pc = (uint32_t)emu_getpc();
        if (rtl_pc != emu_pc) {
            std::printf("DIFF pc    @cycle %llu  NPC:0x%08x  EMU:0x%08x  NPCinst:0x%08x EMUinst:0x%08x\n",
                        (unsigned long long)cycles, rtl_pc, emu_pc, rtl_inst, (uint32_t)emu_getinst());
            diff_fail = 1;
            break;
        }

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

        step();        // RTL -> 执行完第 k 条，pc/GPR 更新到 state(k+1)
        refresh_time(); // 把 NPC 刚读到的外设值同步给 EMU，再生成新随机值
        emu_step();    // EMU -> 执行完第 k 条

        uint32_t emu_inst = (uint32_t)emu_getinst();
        if (emu_inst != rtl_inst) {
            std::printf("DIFF inst  @cycle %llu  NPC:0x%08x  EMU:0x%08x\n",
                        (unsigned long long)cycles, rtl_inst, emu_inst);
            diff_fail = 1;
            break;
        }

        cycles++;
    }

    tb->final();
    if (tfp) { tfp->close(); delete tfp; }
    delete tb;

    if (diff_fail) {
        std::printf("==== difftest FAIL @cycle %llu ====\n",
                    (unsigned long long)cycles);
        return 1;
    }

    if (emu_halted() != get_sim_finish()) {
        std::printf("==== 结束状态不一致：EMU halted=%d, RTL finish=%d ====\n",
                    emu_halted(), (int)get_sim_finish());
        return 1;
    }

    if (get_sim_finish()) {
        int code = get_sim_exit_code();
        if (code == 0) {
            std::printf("HIT GOOD TRAP\n");
            std::printf("npc的ipc为%lf\n",((double)insts/cycles));
            return 0;
        }
        std::printf("HIT BAD TRAP, a0 = %d (0x%08x)\n", code, (unsigned)code);
        return 1;
    }

    if (Verilated::gotFinish())
        std::printf("==== RTL 里执行了 $finish，但程序还没执行 ebreak ====\n");
    else
        std::printf("==== 程序没有执行 ebreak，跑满 %llu 拍强制停机 ====\n",
                    (unsigned long long)cycles);
    return 1;
}
