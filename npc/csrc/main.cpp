#include <verilated.h>
#include <nvboard.h>
#include <verilated_vcd_c.h>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#ifdef NPC_SOC
// ================= SoC 仿真（VSimTop，双时钟 + 复位100拍） =================
#include <VSimTop.h>
extern void nvboard_bind_all_pins(VSimTop* top);

// hello 程序（ysyxSoC 专用，链接在 0x30000000）
static const char *DEFAULT_IMG =
    "../ysyxSoC/ready-to-run/minirv/hello-minirv-ysyxsoc.bin";

// dpi_pmem.cpp 实现：把 bin 读入 16MB flash 数组
extern "C" void soc_init(const char *img);
extern "C" bool get_sim_finish(void);
extern "C" int  get_sim_exit_code(void);

int main(int argc, char **argv) {
    const char *flash_img = (argc > 1) ? argv[1] : DEFAULT_IMG;
    soc_init(flash_img);

    Verilated::commandArgs(argc, argv);
    VSimTop *top = new VSimTop;
    nvboard_bind_all_pins(top);
    nvboard_init();
    Verilated::traceEverOn(true);
    VerilatedVcdC *tfp = nullptr;
    if (std::getenv("NPC_TRACE") != nullptr) {
        tfp = new VerilatedVcdC;
        top->trace(tfp, 9);
        tfp->open("wave.vcd");
    }
    uint64_t sim_time = 0;
    const uint64_t CPU_CLOCK_MULT = 4;   
    uint64_t clk_phase = 0;
    auto single_cycle = [&]() {
        top->cpuClock = 0;                
        top->eval();
        if (tfp) tfp->dump(sim_time); sim_time++;
        top->cpuClock = 1;                 
        top->eval();
        if (tfp) tfp->dump(sim_time); sim_time++;

        clk_phase += 2;                   
        if (clk_phase >= CPU_CLOCK_MULT) { /
            clk_phase -= CPU_CLOCK_MULT;
            top->clock = !top->clock;
        }
    };

    // 复位期间：所有 input 赋初值
    top->reset                  = 1;
    top->coreSel                = 0;
    top->externalPins_mygpio_in = 0;
    top->externalPins_uart0_rx  = 1;
    top->clock                  = 0;
    top->cpuClock               = 0;
    top->eval();
    
    for (int i = 0; i < 100; i++) single_cycle();

    // 释放复位，开始跑
    top->reset = 0;
    printf("reset released, start running...\n");
    fflush(stdout);
    uint64_t cycles = 0;
    uint64_t MAX_SOC_CYCLES = 2000000000;
    if (const char *e = std::getenv("NPC_MAX_CYCLES"))
        MAX_SOC_CYCLES = strtoull(e, nullptr, 0);
    while (!Verilated::gotFinish() && !get_sim_finish() && cycles < MAX_SOC_CYCLES) {
        single_cycle();
        nvboard_update();
        cycles++;
        if ((cycles % 10000000) == 0) {
            printf("\n[progress] cycle %llu  seg=%02x %02x %02x %02x %02x %02x %02x %02x  led=%04x\n",
                (unsigned long long)cycles,
                top->externalPins_mygpio_seg_0, top->externalPins_mygpio_seg_1,
                top->externalPins_mygpio_seg_2, top->externalPins_mygpio_seg_3,
                top->externalPins_mygpio_seg_4, top->externalPins_mygpio_seg_5,
                top->externalPins_mygpio_seg_6, top->externalPins_mygpio_seg_7,
                top->externalPins_mygpio_out);
            fflush(stdout);
        }
    }
    if (get_sim_finish()) {
        int code = get_sim_exit_code();
        printf("HIT %s TRAP, a0=%d (0x%08x), cycles=%llu\n",
               code == 0 ? "GOOD" : "BAD", code, (unsigned)code, (unsigned long long)cycles);
    } else {
        printf("NO TRAP, ran %llu cycles\n", (unsigned long long)cycles);
    }
    std::fflush(stdout
    );

    top->final();
    if (tfp) { tfp->close(); delete tfp; }
    delete top;
    nvboard_quit();
    printf("sim done, cycles=%llu\n", (unsigned long long)cycles);
    return 0;
}

#else
// ================= 独立 NPC 仿真（Vysyx_100023197 + DiffTest + IPC） =================
#include <Vysyx_100023197.h>
#include "../sEMU/hello.h"

extern "C" bool get_sim_finish(void);
extern "C" int  get_sim_exit_code(void);
extern "C" void pmem_init(const char *img);
extern "C" void refresh_time(void);
extern "C" int  pmem_read(int raddr);

static const char *DEFAULT_IMG =
    "../am-kernels/tests/cpu-tests/build/dummy-minirv-npc.bin";

#define MAX_CYCLES 10000000000

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vysyx_100023197 *tb = new Vysyx_100023197;
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
        tb->clock = 0; tb->eval();
        if (tfp) tfp->dump(sim_time);
        sim_time++;
        tb->clock = 1; tb->eval();
        if (tfp) tfp->dump(sim_time);
        sim_time++;
    };

    tb->reset = 1; tb->clock = 0; tb->eval();
    step(); step();
    tb->reset = 0;

    uint64_t cycles    = 0;
    int      diff_fail = 0;
    uint64_t insts     = 0;

    while (!emu_halted() && !Verilated::gotFinish() && cycles < MAX_CYCLES) {

        if (!tb->commit) {  // 指令未提交（IFU idle 或 load 发地址周期），跳过对比
            step();
            cycles++;
            continue;
        }
        uint32_t rtl_inst = (uint32_t)pmem_read((int)tb->pc);
        insts++;

        uint32_t rtl_pc = tb->pc;
        uint32_t emu_pc = (uint32_t)emu_getpc();
        if (rtl_pc != emu_pc) {
            std::printf("DIFF pc    @cycle %llu  NPC:0x%08x  EMU:0x%08x  NPCinst:0x%08x EMUinst:0x%08x\n",
                        (unsigned long long)cycles, rtl_pc, emu_pc, rtl_inst, (uint32_t)emu_getinst());
            diff_fail = 1;
            break;
        }

        for (int i = 0; i < 32; i++) {
            uint32_t rtl = (uint32_t)tb->gpr_dump[i];
            uint32_t emu = (uint32_t)emu_getgpr(i);
            if (rtl != emu) {
                std::printf("DIFF x%-2d   @cycle %llu  NPC:0x%08x  EMU:0x%08x\n",
                            i, (unsigned long long)cycles, rtl, emu);
                diff_fail = 1;
                break;
            }
        }
        if (diff_fail) break;

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
            std::printf("npc的ipc为%lf （指令 %llu 拍 %llu）\n",
                        ((double)insts/cycles), (unsigned long long)insts,
                        (unsigned long long)cycles);
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
#endif