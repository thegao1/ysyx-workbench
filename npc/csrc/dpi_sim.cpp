//=====================================================================
// dpi_sim.cpp —— 仿真"跑完了没有、跑得对不对"
//
// 为什么要单独一个文件：dpi_pmem.cpp 只管内存这一件事。程序结束状态是
// 另一件事，混在一起以后会越看越乱。csrc/ 下所有 .cpp 都会被自动编进去，
// 加文件不用改 Makefile。
//
// RTL 那边（vsrc/execute.v）执行到 ebreak 时调用 set_finish_flag：
//   set_finish_flag(code)  code 就是 ebreak 前 a0(x10) 的值
// C 这边负责把它存下来，main.cpp 轮询 get_sim_finish() 决定什么时候停机，
// 再读 get_sim_exit_code() 决定报 GOOD 还是 BAD。
//
// 签名必须和 vsrc/pmem_pkg.v 里的声明一致，对不上会链接失败。
//=====================================================================

static bool sim_finish    = false;   // 有没有执行到 ebreak
static int  sim_exit_code = 0;       // ebreak 时 a0 的值：0 = 正常，非 0 = 出错

extern "C" void set_finish_flag(int code) {
    sim_finish    = true;
    sim_exit_code = code;
}

extern "C" bool get_sim_finish(void) {
    return sim_finish;
}

extern "C" int get_sim_exit_code(void) {
    return sim_exit_code;
}
