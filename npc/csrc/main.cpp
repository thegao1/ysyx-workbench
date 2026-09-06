#include <Vtop.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <cstdio>
#include <cstdlib>
#include <cassert>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtop* top = new Vtop;

    // 开启波形追踪
    Verilated::traceEverOn(true);
    VerilatedVcdC tfp;
    top->trace(&tfp, 99);   // 追踪 99 层信号
    tfp.open("wave.vcd");

    vluint64_t main_time = 0;

    // 遍历所有输入组合，每个组合模拟几个周期
    for (int a = 0; a < 2; a++) {
        for (int b = 0; b < 2; b++) {
            top->a = a;
            top->b = b;
            for (int i = 0; i < 5; i++) {
                top->eval();
                tfp.dump(main_time++);
            }
            printf("a=%d, b=%d -> f=%d (expect %d) %s\n",
                   top->a, top->b, top->f, a ^ b,
                   (top->f == (a ^ b)) ? "OK" : "FAIL");
            assert(top->f == (a ^ b));
        }
    }

    top->final();
    tfp.close();
    delete top;
    printf("Simulation done, wave.vcd written.\n");
    return 0;
}
