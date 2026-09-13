//=====================================================================
// main.cpp —— 仿真环境的入口
//
// 用法：
//   ./build/top <二进制镜像路径>       指定跑哪个程序
//   不传路径就用 DEFAULT_IMG
//
// 结束条件（取代了原来 top.v 里"跑满 400 拍就 $finish"那种做法）：
//   程序执行 ebreak -> RTL 调 set_finish_flag(a0)，这里轮询到就停机。
//   a0 == 0 报 HIT GOOD TRAP 并返回 0；a0 != 0 报 HIT BAD TRAP 并返回非 0。
//
//   为什么退出码要区分：Makefile 是看进程退出码判 PASS/FAIL 的
//   （见 am-kernels/tests/cpu-tests/Makefile），全返回 0 的话
//   wrong 程序也会被判成 PASS。
//
// 波形：
//   默认不录 —— 批量跑程序时写 VCD 又慢又占地方，还容易刷屏。
//   要看波形：NPC_TRACE=1 ./build/top <镜像>
//=====================================================================
#include <Vtop.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>

extern "C" bool get_sim_finish(void);     // 实现见 csrc/dpi_sim.cpp
extern "C" int  get_sim_exit_code(void);
extern "C" void pmem_init(const char *img);

static const char *DEFAULT_IMG =
    "../am-kernels/tests/cpu-tests/build/dummy-minirv-npc.bin";

// 程序始终不执行 ebreak 时（程序自己死循环，或者 NPC 有 bug）的兜底拍数。
// 跑到这里就判失败退出，免得批量跑的时候整个卡死。真跑不完就调大。
#define MAX_CYCLES 10000000

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);

    // 必须在 time 0 之前调，否则直接 abort
    Vtop *tb = new Vtop;
    Verilated::traceEverOn(true);

    VerilatedVcdC *tfp = nullptr;
    if (std::getenv("NPC_TRACE") != nullptr) {
        tfp = new VerilatedVcdC;
        tb->trace(tfp, 99);
        tfp->open("wave.vcd");
    }

    pmem_init(argc > 1 ? argv[1] : DEFAULT_IMG);

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
    // 原来的 main 从头到尾没把 rst 放下来，pc 就一直卡在 0x80000000，
    // 一条指令都没执行过 —— 这点必须先修掉，否则后面测什么都测不出来。
    tb->rst = 1; tb->clk = 0; tb->eval();
    step(); step();
    tb->rst = 0;

    uint64_t cycles = 0;
    while (!get_sim_finish() && !Verilated::gotFinish() && cycles < MAX_CYCLES) {
        step();
        cycles++;
    }

    tb->final();                        // 必须调，不然波形收尾不完整
    if (tfp) { tfp->close(); delete tfp; }
    delete tb;

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
