`ifdef __VERILOG__
import pmem_pkg::*;
`endif

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

`ifdef __VERILOG__
// ---- Verilator：直接调 DPI-C 函数 ----
assign io_lsu_rdata = (io_lsu_reqValid && !io_lsu_wen) ?
    (io_lsu_addr[31:3] == 29'h0200_0000 ? 32'h0000_6060 :   // UART 块 0x1000_0000~7
     io_lsu_addr == 32'h20000000 ? get_time()[31:0] :
     io_lsu_addr == 32'h20000004 ? get_time()[63:32] :
     pmem_read({io_lsu_addr[31:2], 2'b00})) : 32'b0;

// 上一拍的"写请求"，用来做边沿检测
reg lsu_wreq_d;

// IFU 取指 + 响应 + LSU 写：时序，与 respValid 同拍
always @(posedge clock) begin
    io_ifu_rdata     <= io_ifu_reqValid ? pmem_read(io_ifu_addr) : 32'b0;
    io_ifu_respValid <= io_ifu_reqValid;
    io_lsu_respValid <= io_lsu_reqValid;
    lsu_wreq_d       <= io_lsu_reqValid && io_lsu_wen;
    // exu 发出一条 store 后，io_lsu_reqValid 要一直保持到收到 respValid 才拉低，
    // 中间整整两拍 reqValid && wen 都是 1；而这里的写是电平触发的，
    // 直接用会把同一条 store 执行两次（uart_putchar 也会把同一个字符打两遍）。
    // 所以加个边沿检测，保证"一次请求只写一次"。
    if (io_lsu_reqValid && io_lsu_wen && !lsu_wreq_d) begin
        if (io_lsu_addr[31:3] == 29'h0200_0000 || io_lsu_addr >= 32'hA000_0000) begin
            uart_putchar(io_lsu_wdata);
        end else begin
            pmem_write(io_lsu_addr & 32'hFFFF_FFFC, io_lsu_wdata, {4'b0000, io_lsu_wmask});
        end
    end
end
`else
// ---- iverilog：调 VPI 系统任务 $mem_* / $get_time_* / $uart_putchar ----
assign io_lsu_rdata = (io_lsu_reqValid && !io_lsu_wen) ?
    (io_lsu_addr[31:3] == 29'h0200_0000 ? 32'h0000_6060 :   // UART 块 0x1000_0000~7
     io_lsu_addr == 32'h20000000 ? $get_time_lo() :
     io_lsu_addr == 32'h20000004 ? $get_time_hi() :
     $mem_read({io_lsu_addr[31:2], 2'b00})) : 32'b0;

// 上一拍的"写请求"，用来做边沿检测
reg lsu_wreq_d;

// IFU 取指 + 响应 + LSU 写：时序，与 respValid 同拍
always @(posedge clock) begin
    io_ifu_rdata     <= io_ifu_reqValid ? $mem_read(io_ifu_addr) : 32'b0;
    io_ifu_respValid <= io_ifu_reqValid;
    io_lsu_respValid <= io_lsu_reqValid;
    lsu_wreq_d       <= io_lsu_reqValid && io_lsu_wen;
    // 同 Verilator 分支：reqValid 会保持两拍，电平触发会把同一条 store 写两次
    if (io_lsu_reqValid && io_lsu_wen && !lsu_wreq_d) begin
        if (io_lsu_addr[31:3] == 29'h0200_0000 || io_lsu_addr >= 32'hA000_0000) begin
            $uart_putchar(io_lsu_wdata);
        end else begin
            $mem_write(io_lsu_addr & 32'hFFFF_FFFC, io_lsu_wdata, {4'b0000, io_lsu_wmask});
        end
    end
end
`endif

endmodule
