import pmem_pkg::*;
module mem(
    input               clk,
    input               mw_en,      
    input      [3:0]    mw_mask,    
    input      [31:0]   mw_addr,
    input      [31:0]   mw_data,
    input               mr_en,      
    input      [31:0]   mr_addr,
    output reg [31:0]   r_data
);


always @(*) begin
    if (mr_en) r_data = pmem_read(mr_addr);
    else       r_data = 32'd0;
end

always @(posedge clk) begin
    if (mw_en) begin
        if (mw_addr >= 32'hA000_0000) begin      
            uart_putchar(mw_data);               
        end
        else begin                               
            pmem_write(mw_addr & 32'hFFFF_FFFC, mw_data, {4'b0000, mw_mask});
        end
    end
end

endmodule
