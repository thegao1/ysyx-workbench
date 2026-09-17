import pmem_pkg::*;
module mem(
    input               clk,
    input               lsu_wen,
    input      [3:0]    lsu_wmask,
    input      [31:0]   lsu_addr,
    input      [31:0]   lsu_wdata,
    input               ifu_reqvalid,
    input               lsu_reqvalid,
    output reg          ifu_respvalid,
    output reg          lsu_respvalid,
    input      [31:0]   ifu_raddr,
    output reg [31:0]   ifu_rdata,
    output     [31:0]   lsu_rdata
);

// LSU 读：组合读 —— reqvalid 当拍数据就有效（含外设地址）
// 这样 load 的 lsu_rdata 与 fetch 提交沿同一拍，写回时机对齐
assign lsu_rdata = (lsu_reqvalid && !lsu_wen) ?
    (lsu_addr == 32'h10000004 ? uart_status() :
     lsu_addr == 32'h20000000 ? get_time()[31:0] :
     lsu_addr == 32'h20000004 ? get_time()[63:32] :
     pmem_read(lsu_addr)) : 32'b0;

// IFU 取指 + 响应 + LSU 写：时序，与 respvalid 同拍
always @(posedge clk) begin
    ifu_rdata     <= ifu_reqvalid ? pmem_read(ifu_raddr) : 32'b0;
    ifu_respvalid <= ifu_reqvalid;
    lsu_respvalid <= lsu_reqvalid;
    if (lsu_reqvalid && lsu_wen) begin
        if (lsu_addr >= 32'hA000_0000) begin
            uart_putchar(lsu_wdata);
        end else begin
            pmem_write(lsu_addr & 32'hFFFF_FFFC, lsu_wdata, {4'b0000, lsu_wmask});
        end
    end
end

endmodule