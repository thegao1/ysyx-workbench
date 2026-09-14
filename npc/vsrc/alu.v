module alu(
    input   [3:0] a,
    input   [3:0] b,
    input   [2:0] op,
    output reg [3:0] res,
    output reg zero,
    output reg overflow,
    output reg carry_out
);

wire signed [3:0] sa, sb;
assign sa = a;
assign sb = b;

wire signed [4:0] add_res  = {1'b0,sa} + {1'b0,sb};
wire signed [4:0] sub_res  = {1'b0,sa} - {1'b0,sb};

always @(*) begin
    res       = 4'd0;
    zero      = 1'b0;
    overflow  = 1'b0;
    carry_out = 1'b0;

    case(op)
        3'b000: begin // A+B
            res = add_res[3:0];
            carry_out = add_res[4];
            overflow = (~sa[3] & ~sb[3] &  res[3]) | ( sa[3] &  sb[3] & ~res[3]);
        end
        3'b001: begin // A‑B
            res = sub_res[3:0];
            carry_out = sub_res[4];
            overflow = (~sa[3] &  sb[3] &  res[3]) | ( sa[3] & ~sb[3] & ~res[3]);
        end
        3'b010: begin // Not A
            res = ~sa;
        end
        3'b011: begin // A & B
            res = sa & sb;
        end
        3'b100: begin // A | B
            res = sa | sb;
        end
        3'b101: begin // A ^ B
            res = sa ^ sb;
        end
        3'b110: begin // A < B 带符号比较
            res = (sa < sb) ? 4'b0001 : 4'b0000;
        end
        3'b111: begin // A == B 相等
            res = (sa == sb) ? 4'b0001 : 4'b0000;
        end
    endcase

    // zero放到always内部，统一过程赋值，删掉外部assign
    zero = (res == 4'd0);
end

endmodule
