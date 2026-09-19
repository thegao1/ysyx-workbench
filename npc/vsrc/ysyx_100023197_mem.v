import pmem_pkg::*;
module ysyx_100023197_mem(
    input               clock,
    input               io_lsu_wen,
    input      [3:0]    io_lsu_wmask,
    input      [31:0]   io_lsu_addr,
    input      [31:0]   io_lsu_wdata,
    input               io_ifu_reqValid,
    input               io_lsu_reqValid,
    output reg          io_ifu_respValid,
    output reg          io_lsu_respValid,
    input      [31:0]   io_ifu_addr,
    output reg [31:0]   io_ifu_rdata,
    output     [31:0]   io_lsu_rdata
);

// LSU 读：组合读 —— reqValid 当拍数据就有效（含外设地址）
// 这样 load 的 io_lsu_rdata 与 fetch 提交沿同一拍，写回时机对齐
//
// pmem_read 的地址要按字对齐：DPI 里的 pmem_read 是按 raddr 逐字节取的（非对齐读），
// 而 SoC 侧 MemBridge 返回的是「地址所在的那个 32 位字」。CPU 里只有一套字节抽取
// 逻辑（用 addr[1:0] 挑），两种存储器模型必须一致，否则独立模式会重复移位：
// lbu 0x...71 会拿到字里 1 号字节 0x58 而不是 0x00，和 EMU 对不上。
// 写路径本来就对齐（下面 pmem_write 已经 & ~3 并用 wmask 选字节），读路径对齐后一致。
//
// UART 状态要按「块」匹配，不能只匹配某一个地址：trm.c 的 putch() 轮询的是
// LSR —— 16550 里在 +5，也就是字节地址 0x10000005。只匹配 0x10000004 的话
// 这个读会落到 pmem_read 上（越界返回 0），THRE 永远为 0 → putch 死循环。
// 返回 0x6060，让字节抽取无论落在哪个字节都能看到 THRE|TEMT（0x60）。
assign io_lsu_rdata = (io_lsu_reqValid && !io_lsu_wen) ?
    (io_lsu_addr[31:3] == 29'h0200_0000 ? 32'h0000_6060 :   // UART 块 0x1000_0000~7
     io_lsu_addr == 32'h20000000 ? get_time()[31:0] :
     io_lsu_addr == 32'h20000004 ? get_time()[63:32] :
     pmem_read({io_lsu_addr[31:2], 2'b00})) : 32'b0;

// IFU 取指 + 响应 + LSU 写：时序，与 respValid 同拍
always @(posedge clock) begin
    io_ifu_rdata     <= io_ifu_reqValid ? pmem_read(io_ifu_addr) : 32'b0;
    io_ifu_respValid <= io_ifu_reqValid;
    io_lsu_respValid <= io_lsu_reqValid;
    if (io_lsu_reqValid && io_lsu_wen) begin
        // 串口写：老镜像用 0xa00003f8（ysyx 约定的 UART），新的 trm.c 用 0x1000_0000
        // 的 THR（16550 布局）。两个都接上，免得换地址就得重新编镜像。
        if (io_lsu_addr[31:3] == 29'h0200_0000 || io_lsu_addr >= 32'hA000_0000) begin
            uart_putchar(io_lsu_wdata);
        end else begin
            pmem_write(io_lsu_addr & 32'hFFFF_FFFC, io_lsu_wdata, {4'b0000, io_lsu_wmask});
        end
    end
end

endmodule
