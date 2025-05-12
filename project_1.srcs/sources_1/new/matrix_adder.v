`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/03/23 17:56:07
// Design Name: 
// Module Name: matrix_adder
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


module matrix_adder #(
    parameter N  = 32
)
    (
    clk,
    rst,
    in1,                                                        // 输入矩阵A
    in2,                                                        // 输入矩阵B
    precision_mode_reg,                                         // 矩阵精度控制
    out                                                         // 输出矩阵 
    );
    input clk;
    input rst;
    input [2:0] precision_mode_reg;
    input [N*64-1:0] in1;
    input [N*64-1:0] in2;
    output [N*64-1:0] out;

    wire  signed [N-1:0] A [7:0] [7:0];                         // 展开存储矩阵A
    wire  signed [N-1:0] B [7:0] [7:0];                         // 展开存储矩阵B
    wire  signed [N-1:0] C [7:0] [7:0];
    
    wire [FP16-1:0] float16_sum [7:0][7:0];
    wire [FP32-1:0] float32_sum [7:0][7:0];
    
    localparam INT4 = 4;
    localparam INT8 = 8;
    localparam FP16 = 16;
    localparam FP32 = 32;

    genvar i, h;
    // 矩阵A展开
    generate
        for(h = 0; h < 8; h = h + 1)begin
            for(i = 0; i < 8; i = i + 1)begin
                // 行优先存储（最高位为第一行第一列）的矩阵AB展开
                assign A[h][i] =    precision_mode_reg==0 ? {24'b0, in1[h*8*INT8+(i+1)*INT8-1 -:INT8]} : 
                                    precision_mode_reg==1 ? {24'b0, in1[h*8*INT8+(i+1)*INT8-1 -:INT8]} :
                                    precision_mode_reg==2 ? {16'b0, in1[h*8*FP16+(i+1)*FP16-1 -:FP16]} :
                                                                    in1[h*8*FP32+(i+1)*FP32-1 -:FP32] ;
                assign B[h][i] =    precision_mode_reg==0 ? {24'b0, in2[h*8*INT8+(i+1)*INT8-1 -:INT8]} : 
                                    precision_mode_reg==1 ? {24'b0, in2[h*8*INT8+(i+1)*INT8-1 -:INT8]} :
                                    precision_mode_reg==2 ? {16'b0, in2[h*8*FP16+(i+1)*FP16-1 -:FP16]} :
                                                                    in2[h*8*FP32+(i+1)*FP32-1 -:FP32];
                /* always @(*) begin
                case (precision_mode_reg)
                    0:  begin
                        A [h][i] <= {24'b0, in1[h*8*INT8+(i+1)*INT8-1 -:INT8]};
                        B [h][i] <= {24'b0, in2[h*8*INT8+(i+1)*INT8-1 -:INT8]};
                    end   
                    1:  begin
                        A [h][i] <= {24'b0, in1[h*8*INT8+(i+1)*INT8-1 -:INT8]};
                        B [h][i] <= {24'b0, in2[h*8*INT8+(i+1)*INT8-1 -:INT8]};
                    end
                    2:  begin
                        A [h][i] <= {16'b0, in1[h*8*FP16+(i+1)*FP16-1 -:FP16]};
                        B [h][i] <= {16'b0, in2[h*8*FP16+(i+1)*FP16-1 -:FP16]};
                    end
                    3:  begin
                        A [h][i] <= in1[h*8*FP32+(i+1)*FP32-1 -:FP32];
                        B [h][i] <= in2[h*8*FP32+(i+1)*FP32-1 -:FP32];
                    end
                    default: A [h][i] <= 0;
                endcase
                end */
            end
        end
    endgenerate

    generate
        for(h = 0; h < 8; h = h + 1)begin
            for(i = 0; i < 8; i = i + 1)begin
                assign C [h][i] =   precision_mode_reg==0 ? {24'b0, A[h][i][7:0] + B[h][i][7:0]} : 
                                    precision_mode_reg==1 ? {24'b0, A[h][i][7:0] + B[h][i][7:0]} :
                                    precision_mode_reg==2 ? {16'b0, float16_sum[h][i]} :
                                                            float32_sum [h][i];
               /*  always @(*) begin
                    case (precision_mode_reg)
                        0: C [h][i] <= {24'b0, A[h][i][7:0] + B[h][i][7:0]};
                        1: C [h][i] <= {24'b0, A[h][i][7:0] + B[h][i][7:0]};
                        2: C [h][i] <= {16'b0, float16_sum[h][i]};
                        3: C [h][i] <= float32_sum [h][i];
                        default: C [h][i] = 0;
                endcase
                end */
            end
        end
    endgenerate
    generate
        for(h = 0; h < 8; h = h + 1)begin
            for(i = 0; i < 8; i = i + 1)begin
                assign out[h*8*N+(i+1)*N-1 -:N] = C[h][i];
            end
        end
    endgenerate 

    generate
        for(h = 0; h < 8; h = h + 1) begin
            for(i = 0; i < 8; i = i + 1) begin
                floatAdd16 my_floatAdd16_x (
                    .floatA(A[h][i][FP16-1:0]),
                    .floatB(B[h][i][FP16-1:0]),
                    .sum(float16_sum[h][i])
                );
            end
        end
    endgenerate

    
    generate
        for(h = 0; h < 8; h = h + 1) begin
            for(i = 0; i < 8; i = i + 1) begin
                floatAdd32 my_floatAdd16_x (
                    .in1(A[h][i][FP32-1:0]),
                    .in2(B[h][i][FP32-1:0]),
                    .out(float32_sum[h][i])
                );
            end
        end
    endgenerate
endmodule