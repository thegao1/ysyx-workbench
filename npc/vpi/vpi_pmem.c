#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <vpi_user.h>
extern int pmem_read(int raddr);
extern void  pmem_write(int waddr, int wdata, char wmask);
extern void pmem_init(const char *img);
extern void uart_putchar(char c);
extern unsigned long long get_time(void);
extern void refresh_time(void);   // dpi_pmem.cpp：刷新 timer_value/uart 状态，见下面 $tick_time

static int load_bin_compiletf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    int cnt = 0;
    while (vpi_scan(iter)) cnt++;

    if (cnt != 1) {
        vpi_printf("$load_bin 参数错误：需要1个参数(文件名,)\n");
        return 1;
    }
    return 0;
}


static int load_bin_calltf(char *user_data)
{
    (void)user_data;
    vpiHandle tf_handle = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle arg_iter = vpi_iterate(vpiArgument, tf_handle);

    vpiHandle file_arg = vpi_scan(arg_iter);
    s_vpi_value file_val;
    file_val.format = vpiStringVal;
    vpi_get_value(file_arg,&file_val);
    const char *filename= file_val.value.str;
    pmem_init(filename);
    return 0;
}

static void load_bin_register(void)
{
    s_vpi_systf_data tf_data;
    tf_data.type      = vpiSysTask;
    tf_data.tfname    = "$load_bin";
    tf_data.calltf    = load_bin_calltf;
    tf_data.compiletf = load_bin_compiletf;
    tf_data.sizetf    = 0;
    tf_data.user_data = 0;
    vpi_register_systf(&tf_data);
}

//mem_read
static int mem_read_compiletf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    int cnt = 0;
    while (vpi_scan(iter)) cnt++;

    if (cnt != 1) {
        vpi_printf("$mem_read 参数错误：需要1个参数(地址)\n");
        return 1;
    }
    return 0;
}

static int mem_read_sizetf(char *user_data)
{
    (void)user_data;
    return 32; // 返回值位宽32位
}


static int mem_read_calltf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    vpiHandle addr_arg =vpi_scan(iter);

    s_vpi_value addr_val;
    addr_val.format=vpiIntVal;
    vpi_get_value(addr_arg, &addr_val);
    int addr = addr_val.value.integer;
    int rdata=pmem_read(addr);
    s_vpi_value ret_val;
    ret_val.format=vpiIntVal;
    ret_val.value.integer = rdata;
    vpi_put_value(tf, &ret_val, NULL, vpiNoDelay);
    return 0;
}


static void mem_read_register(void)
{
    s_vpi_systf_data tf_data;
    tf_data.type      = vpiSysFunc;
    tf_data.tfname    = "$mem_read";
    tf_data.calltf    = mem_read_calltf;
    tf_data.compiletf = mem_read_compiletf;
    tf_data.sizetf    = mem_read_sizetf;
    tf_data.user_data = 0;
    vpi_register_systf(&tf_data);
}


static int mem_write_compiletf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    int cnt = 0;
    while (vpi_scan(iter)) cnt++;

    if (cnt != 3) {
        vpi_printf("$mem_write 参数错误：需要3个参数( 地址, 数据,mask)\n");
        return 1;
    }
    return 0;
}


static int mem_write_calltf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    vpiHandle addr_arg =vpi_scan(iter);
    s_vpi_value addr_val;
    addr_val.format = vpiIntVal;
    vpi_get_value(addr_arg, &addr_val);
    int waddr = addr_val.value.integer;

    vpiHandle wdata_arg =vpi_scan(iter);
    s_vpi_value wdata_val;
    wdata_val.format=vpiIntVal;
    vpi_get_value(wdata_arg,&wdata_val);
    int wdata=wdata_val.value.integer;

    vpiHandle wmask_arg =vpi_scan(iter);
    s_vpi_value wmask_val;
    wmask_val.format=vpiIntVal;
    vpi_get_value(wmask_arg,&wmask_val);
    int wmask=wmask_val.value.integer;

    pmem_write(waddr,wdata,wmask);
    return 0;
}

static void mem_write_register(void)
{
    s_vpi_systf_data tf_data;
    tf_data.type      = vpiSysTask;
    tf_data.tfname    = "$mem_write";
    tf_data.calltf    = mem_write_calltf;
    tf_data.compiletf = mem_write_compiletf;
    tf_data.sizetf    = 0;
    tf_data.user_data = 0;
    vpi_register_systf(&tf_data);
}

// uart_putchar：verilog 的 $uart_putchar(wdata) 转发给 DPI-C 的 uart_putchar()
static int uart_putchar_compiletf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    int cnt = 0;
    while (vpi_scan(iter)) cnt++;

    if (cnt != 1) {
        vpi_printf("$uart_putchar 参数错误：需要1个参数(字符)\n");
        return 1;
    }
    return 0;
}

static int uart_putchar_calltf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    vpiHandle ch_arg = vpi_scan(iter);

    s_vpi_value ch_val;
    ch_val.format = vpiIntVal;
    vpi_get_value(ch_arg, &ch_val);
    int ch = ch_val.value.integer;
    uart_putchar((char)(ch & 0xFF));
    return 0;
}

static void uart_putchar_register(void)
{
    s_vpi_systf_data tf_data;
    tf_data.type      = vpiSysTask;
    tf_data.tfname    = "$uart_putchar";
    tf_data.calltf    = uart_putchar_calltf;
    tf_data.compiletf = uart_putchar_compiletf;
    tf_data.sizetf    = 0;
    tf_data.user_data = 0;
    vpi_register_systf(&tf_data);
}

// get_time 拆成两个 32 位函数：iverilog 不支持系统函数加位选、且默认 32 位返回值，
// 所以用 $get_time_lo / $get_time_hi 分别取低 32 位 / 高 32 位，转发给 DPI-C 的 get_time()。
static int get_time_compiletf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    if (iter != NULL) {  // 零参数时 vpi_iterate 返回 NULL，不能直接 vpi_scan
        vpi_printf("$get_time_lo/$get_time_hi 参数错误：需要0个参数\n");
        return 1;
    }
    return 0;
}

static int get_time_lo_calltf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    unsigned long long t = get_time();
    s_vpi_value ret_val;
    ret_val.format = vpiIntVal;
    ret_val.value.integer = (int)(t & 0xFFFFFFFFull);  // 低 32 位
    vpi_put_value(tf, &ret_val, NULL, vpiNoDelay);
    return 0;
}

static int get_time_hi_calltf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    unsigned long long t = get_time();
    s_vpi_value ret_val;
    ret_val.format = vpiIntVal;
    ret_val.value.integer = (int)((t >> 32) & 0xFFFFFFFFull);  // 高 32 位
    vpi_put_value(tf, &ret_val, NULL, vpiNoDelay);
    return 0;
}

static int get_time_sizetf(char *user_data)
{
    (void)user_data;
    return 32; // 低/高各返回 32 位
}

static void get_time_register(void)
{
    s_vpi_systf_data tf_data;
    tf_data.type      = vpiSysFunc;
    tf_data.tfname    = "$get_time_lo";
    tf_data.calltf    = get_time_lo_calltf;
    tf_data.compiletf = get_time_compiletf;
    tf_data.sizetf    = get_time_sizetf;
    tf_data.user_data = 0;
    vpi_register_systf(&tf_data);

    tf_data.tfname    = "$get_time_hi";
    tf_data.calltf    = get_time_hi_calltf;
    vpi_register_systf(&tf_data);
}

// $tick_time：把 dpi_pmem.cpp 里的 refresh_time() 暴露给 iverilog。
//
// Verilator 那边是 difftest 的主循环每提交一条指令调一次 refresh_time()，
// 计时器(timer_value)才会往前走；iverilog 没有 difftest 主循环，
// 没人调它，$get_time_lo/hi 就永远返回 0 —— 程序里读到的 uptime 恒等于 0，
// 于是"跑了多久"这种依赖计时值的东西(比如 microbench 打印的耗时、
// 以及 format_time() 里按位数循环的那段)就和 Verilator 跑出来的不一样。
// 所以在测试台里每提交一条指令调一次 $tick_time()，两边口径就一致了。
static int tick_time_compiletf(char *user_data)
{
    (void)user_data;
    vpiHandle tf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, tf);
    if (iter != NULL) {  // 零参数时 vpi_iterate 返回 NULL，不能直接 vpi_scan
        vpi_printf("$tick_time 参数错误：需要0个参数\n");
        return 1;
    }
    return 0;
}

static int tick_time_calltf(char *user_data)
{
    (void)user_data;
    refresh_time();
    return 0;
}

static void tick_time_register(void)
{
    s_vpi_systf_data tf_data;
    tf_data.type      = vpiSysTask;
    tf_data.tfname    = "$tick_time";
    tf_data.calltf    = tick_time_calltf;
    tf_data.compiletf = tick_time_compiletf;
    tf_data.sizetf    = 0;
    tf_data.user_data = 0;
    vpi_register_systf(&tf_data);
}

void (*vlog_startup_routines[])(void) = {
    load_bin_register,
    mem_read_register,
    mem_write_register,
    uart_putchar_register,
    get_time_register,
    tick_time_register,
    0 // 结束标记，必须有
};