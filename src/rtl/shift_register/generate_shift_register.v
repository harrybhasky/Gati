//this block is to generate the main design 4 times, for testing purposes.
// TODO: refactor the comment above.

module generate_shift_register #(parameter N = 4, 
                                parameter NUM_SHIFT = 4, 
                                parameter DATA_WIDTH = 8, 
                                parameter QUANT_DATA_WIDTH = 8) (
    input [(N * QUANT_DATA_WIDTH)-1 : 0] quantized_result_in,
    input [(N) - 1 : 0] valid_quantized_result,
    input clk,
    input rst,
    output [(N) - 1 : 0] valid_out_final,
    output [(N * (NUM_SHIFT * DATA_WIDTH)) - 1 : 0] data_out
);

genvar i;

generate 
    for(i = 0; i < N; i = i + 1) begin : gen_shift_array
        top_gen_shift_register #(.NUM_SHIFT(NUM_SHIFT),
        .QUANT_DATA_WIDTH(QUANT_DATA_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)) 
        top_gen_shift_register_inst(
            .quantized_result_in(
                quantized_result_in[(((N-i) * QUANT_DATA_WIDTH) - 1)
                                   -: QUANT_DATA_WIDTH]
            ),
            .valid_quantized_result(valid_quantized_result[i]),
            .clk(clk),
            .rst(rst),
            .valid_out_final(valid_out_final[i]),
            .data_out(
                data_out[(((N-i) * NUM_SHIFT * DATA_WIDTH) - 1)
                        -: NUM_SHIFT * DATA_WIDTH]
            )
        );
    end
endgenerate

endmodule