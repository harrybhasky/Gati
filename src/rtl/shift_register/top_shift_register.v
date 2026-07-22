module top_shift_register #(
    parameter DATA_WIDTH = 8,
    parameter NUM_SHIFT = 4
) (
    input [DATA_WIDTH - 1 : 0] quantized_result,
    input valid_quantized_result,
    input clk,
    input rst,
    output valid_out,
    output [DATA_WIDTH - 1 : 0] data_out
);

register #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SHIFT(NUM_SHIFT)
) register_inst (
    .din(quantized_result),
    .valid_quantized_result(valid_quantized_result),
    .dout(data_out),
    .valid_out(valid_out),
    .clk(clk),
    .rst(rst)
);

endmodule
