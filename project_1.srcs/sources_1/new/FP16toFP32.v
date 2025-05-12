`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/04 12:56:24
// Design Name: 
// Module Name: FP16toFP32
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


module FP16toFP32(
    input [15:0] FP16,
    output [31:0] FP32
    );

    wire [4:0] exp_16 = FP16[14:10];
    wire [9:0] mantissa_16 = FP16[9:0];
    reg [7:0] exp_32;
    reg [22:0] mantissa_32;
    wire [22:0] mantissa_32_find;
    wire [3:0] high_bit;
    // 特殊值判断
    wire is_zero    = (exp_16 == 0) && (mantissa_16 == 0);
    wire is_inf     = (exp_16 == 5'b11111) && (mantissa_16 == 0);
    wire is_nan     = (exp_16 == 5'b11111) && (mantissa_16 != 0);

    always @(*) begin
        if (is_zero) begin
            exp_32  <= 8'h00;
            mantissa_32 <= 23'h0;
        end else if (is_inf) begin
            exp_32  <= 8'hFF;
            mantissa_32 <= 23'h0;
        end else if (is_nan) begin
            exp_32 <= 8'hFF;
            mantissa_32 <= {1'b1, 22'h0};       // Canonical NaN
        end else if (exp_16 == 0) begin         // Subnormal
            exp_32  <= 8'd103 + high_bit;       // -24 + 127
            mantissa_32 <= mantissa_32_find;
        end else begin                          // Normal
            exp_32  = exp_16 + 8'd112;          // 15-127+127=15
            mantissa_32 = {mantissa_16, 13'h0};
        end
    end
    find_high_bit my_finder (mantissa_16, high_bit, mantissa_32_find);
    assign FP32 = {FP16[15], exp_32, mantissa_32};
endmodule

module FP32toFP16(
    input [31:0] FP32,
    output [15:0] FP16,
    output reg [1:0] overflow
    );

    reg [4:0] exp_16;
    reg [10:0] mantissa_16;
    wire [7:0] exp_32 = FP32[30:23];
    wire [22:0] mantissa_32 = FP32[22:0];

    reg [12:0] round_bits;
    reg        round_up  ;

    // 特殊值判断
    wire is_zero    = (exp_32 == 0) && (mantissa_32 == 0);
    wire is_inf     = (exp_32 == 8'b11111111) && (mantissa_32 == 0);
    wire is_nan     = (exp_32 == 8'b11111111) && (mantissa_32 != 0);

    // 实际指数计算
    wire signed [8:0] exp_actual = exp_32 - 127;
    
    always @(*) begin
        // 特殊值处理
        if (is_inf | is_nan) begin       // NaN/Inf
            exp_16 = 5'b11111;
            mantissa_16  = is_inf ? 11'h0 : 11'h3FF;
            overflow = 0;
        end else if (exp_actual < -24) begin// Underflow
            exp_16   = 5'h00;
            mantissa_16  = 11'h00;
            overflow = 0;
        end else if (exp_actual > 15) begin // Overflow
            exp_16   = 5'b11111;
            mantissa_16  = 11'h00;
            overflow = FP32[31] ? 2'b01 : 2'b11;
        end else if (exp_actual <-14) begin
            exp_16   = 5'h00;
            case(24 + exp_actual)
                0:  mantissa_16 = 11'd1;
                1:  mantissa_16 = 11'd2 + mantissa_32[22];
                2:  mantissa_16 = 11'd4 + mantissa_32[22:21];
                3:  mantissa_16 = 11'd8 + mantissa_32[22:20];
                4:  mantissa_16 = 11'd16 + mantissa_32[22:19];
                5:  mantissa_16 = 11'd32 + mantissa_32[22:18];
                6:  mantissa_16 = 11'd64 + mantissa_32[22:17];
                7:  mantissa_16 = 11'd128 + mantissa_32[22:16];
                8:  mantissa_16 = 11'd256 + mantissa_32[22:15];
                9:  mantissa_16 = 11'd512 + mantissa_32[22:14];
            endcase
        end else begin                      // Normal range
            // 指数转换
            exp_16 = exp_actual[4:0] + 5'd15;
            
            // 尾数舍入（Round to nearest even）
            round_bits = {mantissa_32[12:0]};
            round_up   = (round_bits > 13'h1000) || 
                                    ((round_bits == 13'h1000) && mantissa_32[13]);
            
            // 组合尾数
            mantissa_16 = {1'b0, mantissa_32[22:13]} + round_up;
            
            // 处理进位
            if (mantissa_16[10]) begin
                exp_16  = exp_16 + 1;
                mantissa_16 = 11'h00;
            end else begin
                mantissa_16 = mantissa_16;
            end
        end
    end
    
    assign FP16 = {FP32[31], exp_16, mantissa_16[9:0]};

endmodule

module find_high_bit(
    input [9:0] in,
    output reg [3:0] high_bit,
    output reg [22:0] mantissa
    );

    reg [9:0] in_shift;
    integer i;
    always @(*) begin
        high_bit = 4'b0;
        for (i = 0; i <= 9; i = i + 1) begin
            if (in[i]) begin
                high_bit = i;
            end
        end
        in_shift = in << (10 - high_bit);
        mantissa = {in_shift, 13'b0};
    end
endmodule 