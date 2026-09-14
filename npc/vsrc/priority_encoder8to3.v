module priority_encoder(
    input      [7:0] x,
    input            en,
    output reg [2:0] y,
    output reg       valid
);
always @(*) begin
    if(en) begin
        valid = 1'b1;
        priority casez(x)
            8'b1??????? : y = 3'b111;
            8'b01?????? : y = 3'b110;
            8'b001????? : y = 3'b101;
            8'b0001???? : y = 3'b100;
            8'b00001??? : y = 3'b011;
            8'b000001?? : y = 3'b010;
            8'b0000001? : y = 3'b001;
            8'b00000001 : y = 3'b000;
            default: begin
                y     = 3'b000;
                valid = 1'b0;
            end
        endcase
    end
    else begin
        y     = 3'b000;
        valid = 1'b0;
    end
end

endmodule