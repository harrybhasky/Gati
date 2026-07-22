module mux #(parameter DATA_WIDTH = 8) (
    input [DATA_WIDTH - 1 : 0] intermediate_result,
    input [DATA_WIDTH - 1 : 0] quantized_result,
    input sel,
    output reg [DATA_WIDTH - 1 : 0] dout = 0
);

always @(*) begin
    case(sel)
    1'b0: begin
        dout = intermediate_result;
    end 
    1'b1: begin
        dout = quantized_result;
    end
    endcase
end

endmodule