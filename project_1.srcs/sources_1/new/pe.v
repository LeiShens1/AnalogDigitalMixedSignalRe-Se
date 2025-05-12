`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/03 20:12:06
// Design Name: 
// Module Name: pe
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module pe(
    clk,
    rst,
    b_in,
    precision_mode_reg,
    down,
    a_in,
    mult_out
);

parameter N = 32;
input clk;
input rst;
input signed [N-1:0] a_in;
input signed [N-1:0] b_in;
input        [2:0]   precision_mode_reg;
output reg signed [N-1:0] down = 0;
wire signed [N-1:0] mult;
output wire signed [N-1:0]mult_out;

/*
                          b_in
                          |
                          |
                -------------------------
                |       |   |           |
                |       |   |           |
        a_in----|-----------x-----------|
                |       |   |---+---    |
                |       |       |   |   |
                -------------------------
                        |         |
                        |         |
                        down      mult_out
*/

assign mult_out = precision_mode_reg == 0 ? {24'b0, mult[7:0]} :
                  precision_mode_reg == 1 ? {16'b0, mult[15:0]}:
                  precision_mode_reg == 2 ? mult               :
                  precision_mode_reg == 3 ? mult               :
                  precision_mode_reg == 4 ? {24'b0, mult[7:0]} :
                  precision_mode_reg == 5 ? {16'b0, mult[15:0]}:
                  precision_mode_reg == 6 ? mult               :
                  0;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        down <= 0;
    end 
    else begin
        down <= b_in;
    end 
end

mult my_mult
(
    .precision_mode_reg (precision_mode_reg),
    .a_in               (a_in),                 // 输入的被乘数
    .b_in               (b_in),                 // 输入的乘数  
    .mult_out           (mult),                 // 输出运算结果                                
    .overflow           ()                      // 输出溢出标志
);

endmodule