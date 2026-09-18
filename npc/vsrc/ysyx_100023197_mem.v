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
assign io_lsu_rdata = (io_lsu_reqValid && !io_lsu_wen) ?
    (io_lsu_addr == 32'h10000004 ? uart_status() :
     io_lsu_addr == 32'h20000000 ? get_time()[31:0] :
     io_lsu_addr == 32'h20000004 ? get_time()[63:32] :
     pmem_read(io_lsu_addr)) : 32'b0;

// IFU 取指 + 响应 + LSU 写：时序，与 respValid 同拍
always @(posedge clock) begin
    io_ifu_rdata     <= io_ifu_reqValid ? pmem_read(io_ifu_addr) : 32'b0;
    io_ifu_respValid <= io_ifu_reqValid;
    io_lsu_respValid <= io_lsu_reqValid;
    if (io_lsu_reqValid && io_lsu_wen) begin
        if (io_lsu_addr >= 32'hA000_0000) begin
            uart_putchar(io_lsu_wdata);
        end else begin
            pmem_write(io_lsu_addr & 32'hFFFF_FFFC, io_lsu_wdata, {4'b0000, io_lsu_wmask});
        end
    end
end

endmodule
