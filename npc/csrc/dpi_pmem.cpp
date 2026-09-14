//=====================================================================
// dpi_pmem.cpp —— 物理内存模型（唯一的一份内存）
//
// 为什么要放 C++：DPI 的 import 是函数调用，按值传参。Verilog 那边
// 就算再写一个 reg 数组，也是另一块内存，两边各改各的、还不报错。
// 所以内存只在这里存一份，Verilog 通过下面三个函数访问：
//
//   pmem_read (raddr)               读 4 字节（小端）
//   pmem_write(waddr, wdata, wmask) 按 wmask 逐字节写
//   pmem_init (img)                 装程序：NULL = 内置自检，否则读裸二进制
//
// 签名必须和 vsrc/pmem_pkg.v 一致，对不上会链接失败：
//   package 里是 int / int / byte，这里就是 int / int / char
//   （Verilator 把 byte 映射成 char，不是 unsigned char）
//=====================================================================
#include <cstdint>
#include <cstdio>
#include <cstring>

extern "C" int pmem_read(int raddr);   // 下面 pmem_init 里要用，先声明

static const uint32_t CONFIG_MBASE = 0x80000000u;   // 内存基址（ysyx 约定）
static const uint32_t CONFIG_MSIZE = 0x8000000u;    // 128MB

static uint8_t pmem[CONFIG_MSIZE];

// 内置自检程序：和原来 inst_mem.v 里那 9 条一模一样。
// 功能是把 1 加到 10 累加起来（结果 55 = 0x37），最后 sw 到地址 0 -> LED。
static const uint32_t builtin_img[] = {
    0x00000093,  // addi x1, x0, 0
    0x00100113,  // addi x2, x0, 1
    0x00b00193,  // addi x3, x0, 11
    0x00315863,  // bge  x2, x3, +16
    0x002080b3,  // add  x1, x1, x2
    0x00110113,  // addi x2, x2, 1
    0xfe005ae3,  // bge  x0, x0, -12
    0x00102023,  // sw   x1, 0(x0)
    0x00005063,  // bge  x0, x0, 0
};
static const uint32_t builtin_words = sizeof(builtin_img) / sizeof(builtin_img[0]);

// 把一个 32 位字按小端写进 pmem 的 offset 处
static void pmem_load_word(uint32_t off, uint32_t w) {
    pmem[off + 0] = (uint8_t)((w >> 0) & 0xff);
    pmem[off + 1] = (uint8_t)((w >> 8) & 0xff);
    pmem[off + 2] = (uint8_t)((w >> 16) & 0xff);
    pmem[off + 3] = (uint8_t)((w >> 24) & 0xff);
}

extern "C" void pmem_init(const char *img) {
    std::memset(pmem, 0, sizeof(pmem));

    if (img == nullptr) {
        for (uint32_t i = 0; i < builtin_words; i++)
            pmem_load_word(i * 4, builtin_img[i]);
    } else {
        std::FILE *f = std::fopen(img, "rb");
        if (f == nullptr) {
            std::printf("pmem_init: 打不开 %s，内存留空\n", img);
            return;
        }
        size_t n = std::fread(pmem, 1, CONFIG_MSIZE, f);
        std::fclose(f);
        std::printf("pmem_init: 从 %s 读了 %zu 字节\n", img, n);
    }

    std::printf("pmem_init: img=%s, 0x%08x 处第一个字 = 0x%08x\n",
                img ? img : "<builtin>", CONFIG_MBASE,
                (uint32_t)pmem_read((int)CONFIG_MBASE));
}

extern "C" int pmem_read(int raddr) {
    uint32_t off = (uint32_t)raddr - CONFIG_MBASE;
    // 越界返回 0。raddr < MBASE 时会回绕成超大数，也一并被这条挡住。
    if (off > CONFIG_MSIZE - 4) return 0;
    return (int)((uint32_t)pmem[off + 0] |
                 ((uint32_t)pmem[off + 1] << 8) |
                 ((uint32_t)pmem[off + 2] << 16) |
                 ((uint32_t)pmem[off + 3] << 24));
}

extern "C" void pmem_write(int waddr, int wdata, char wmask) {

    uint32_t off = (uint32_t)waddr - CONFIG_MBASE;
    if (off > CONFIG_MSIZE - 4) return;   // 越界忽略
    uint32_t data = (uint32_t)wdata;
    for (int i = 0; i < 4; i++)
        if ((wmask >> i) & 1)
            pmem[off + i] = (uint8_t)((data >> (8 * i)) & 0xff);
}

extern "C" void uart_putchar(char c) {
    fputc(c, stdout);   
    fflush(stdout);     
}
