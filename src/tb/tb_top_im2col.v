`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

// Design Name: Im2col
// Module Name: Im2col- Testbench
// Project Name: CNN Acceleration
// Description: This is the testbench for the top im2col module. 
// 
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top_im2col();
  parameter   WIDTH=8;
  parameter   VALID=9;
  
  reg [7:0]         i_im2col_data;     
  reg               i_clk;
  reg               i_rstn;             
  wire [7:0]        o_im2col_data; 
  wire [8:0]        o_valid_squares;
  wire [8:0]        o_row1;
  wire [8:0]        o_row2;
  wire [8:0]        o_row3;
  wire [8:0]        o_row4;
  wire [8:0]        o_row5;
  wire [8:0]        o_row6;
  wire [8:0]        o_row7;
  wire [8:0]        o_row8;
  wire [8:0]        o_row9;
  integer     i;
top_im2col #(.WIDTH(8),.VALID(9))
dut(
  .i_im2col_data(i_im2col_data),  
  .i_clk(i_clk),
  .i_rstn(i_rstn),          
  .o_im2col_data(o_im2col_data),  
  .o_valid_squares(o_valid_squares),
  .o_row1(o_row1),
  .o_row2(o_row2),
  .o_row3(o_row3),
  .o_row4(o_row4),
  .o_row5(o_row5),
  .o_row6(o_row6),
  .o_row7(o_row7),
  .o_row8(o_row8),
  .o_row9(o_row9)
); 

initial begin 
  i_clk = 0;
  i_rstn = 0;
  i_im2col_data = 8'd0;
  #10 i_rstn = 1;
end
always #5 i_clk = ~i_clk;
initial begin
//    #10 i_im2col_data = 6;        

  for(i = 0;i < 255;i = i+1) begin
    #10 i_im2col_data = i[7:0];        

    end
   end      
       
endmodule
