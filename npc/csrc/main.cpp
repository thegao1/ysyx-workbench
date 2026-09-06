#include <Vtop.h>
#include <verilated.h>
#include <cstdio>
#include <cstdlib>
#include <cassert>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtop* top = new Vtop;

    while (1) {
        int a = rand() & 1;
        int b = rand() & 1;
        top->a = a;
        top->b = b;
        top->eval();
        printf("a=%d , b=%d , f=%d \n", top->a, top->b, top->f);
        assert(top->f == (a ^ b));
    }
    delete top;
    return 0;
}