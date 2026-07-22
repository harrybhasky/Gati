`timescale 1ns / 1ps
module uart_sa_tb();

parameter COL = 2;
parameter ROW = 9;
parameter W_DATA = 8;
parameter W_ADDR = 8;
parameter RAM_DEPTH = ( 1 << W_ADDR);

reg clk = 0;
reg sel1 = 0;
reg sel2 = 0;
reg trigger1 = 0;
reg trigger2 = 0;
wire rx_serial;
wire column_serial_out;
wire row_serial_out;
                                                
reg [((COL * ROW) * 8)-1 : 0] weight_matrix = {
    8'h0, 8'h8, 8'h4, 8'h6, 8'h3, 8'h5, 8'h1, 8'h2, 8'h6,
    8'h1, 8'h2, 8'h9, 8'h4, 8'h5, 8'h2, 8'h6, 8'h4, 8'h5
    
    
};


reg [((ROW * COL) * 8)-1 : 0] data_matrix = {8'h4, 8'h7, 8'h5, 8'h5, 8'h5, 8'h1, 8'h0, 8'h1, 8'h4,
                                             8'h3, 8'h3, 8'h7, 8'h6, 8'h7, 8'h2, 8'h2, 8'h7, 8'h4                                                                                                                                            
                                            };     
                                                                                              

always #5 clk <= ~clk;                                                

uart_systolic_array_9xN #(
    .ROW(ROW),
    .COL(COL),
    .W_DATA(W_DATA),
    .W_ADDR(W_ADDR),
    .RAM_DEPTH(1 << W_ADDR),
    .TOTAL_BYTES(ROW * COL)
) design_unit_test (
    .i_clk (clk),
    .i_sel_1 (sel1),
    .i_sel_2 (sel2),
    .i_trigger_1 (trigger1),
    .i_trigger_2 (trigger2),
    .i_rx_serial (rx_serial),
    //output [W_DATA-1:0] col_data_out,
    //output [W_DATA-1:0] row_data_out
    .o_tx_serial_column (column_serial_out),
    .o_tx_serial_row (row_serial_out)
);

reg tx_dv = 0;
reg [7:0] tx_byte = 0;
wire tx_active;
wire tx_serial_data;
wire tx_done; 

uart_tx #(
    .CLKS_PER_BIT(50)
) test_data (
    .i_Rst_L(1'b1),
    .i_Clock(clk),
    .i_TX_DV(tx_dv),
    .i_TX_Byte(tx_byte), 
    .o_TX_Active(tx_active),
    .o_TX_Serial(tx_serial_data),
    .o_TX_Done(tx_done)
);

reg [7:0] tx_state = 0;
reg [(($clog2(ROW * COL))-1) : 0] counter = 0;

always @(posedge clk)begin
    case(tx_state)
        0: begin
            if(~tx_active)begin
                if(counter == (ROW * COL))begin
                    tx_state <= 2;
                    counter <= 0;
                    tx_dv <= 0;
                end else begin
                    tx_state <= 1;
                end
            end
        end
        
        1: begin
            tx_byte <= weight_matrix [(((ROW * COL) - counter) * 8) -1 -: 8];
            counter <= counter + 1;
            tx_dv <= 1'b1;
            tx_state <= 0;
        end
        
        2: begin
            if(~tx_active) begin            
                if(counter == (ROW * COL))begin
                    tx_state <= 4;
                    counter <= 0;
                    tx_dv <= 0;
                end else begin
                    tx_state <= 3;
                end
            end            
        end
        
        3: begin
            tx_byte <= data_matrix [(((ROW * COL) - counter) * 8) -1 -: 8];
            counter <= counter + 1;
            tx_dv <= 1'b1;
            tx_state <= 2;  
        end
        
        4: begin
            counter <= 0;
            tx_dv <= 0;
            tx_byte <= 0;
        end
        
        default : begin
            tx_state <= 0;
            tx_dv <= 0;
            tx_byte <= 0;
            counter <= 0;
        end
        
    endcase
end

initial begin
    clk <= 0;
    #5 clk <= 1;
    fork 
        #20 sel1 <= 1'b1;
        #92380 sel1 <= 1'b0;
        #92400 trigger1 <= 1'b1;
                trigger2 <= 1'b0;
        #92499 trigger1 <= 1'b0;
        #92500 sel2 <= 1'b1;
        #180185 sel2 <= 1'b0;
        #180415 trigger2 <= 1'b1;
        #180999 trigger2 <= 1'b0;
    join
                
end

assign rx_serial = tx_serial_data;

endmodule
