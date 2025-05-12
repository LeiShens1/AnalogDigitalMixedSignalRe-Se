`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/01 23:09:51
// Design Name: 
// Module Name: float_mul_16or32
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


module float_mul_16or32(
    input [31: 0]A,
    input [31: 0]B,
    output[31: 0]Result,
    output[1:0]overflow
    );

wire Exception,Overflow,Underflow;
assign overflow = Overflow ? 2'b01 : Underflow ? 2'b11 : 2'b00;
wire [8:0] exponent_16,sum_exponent_16;
wire [22:0] product_16_mantissa;
wire [47:0] product_16,product_16_normalised;
wire bitandA,bitandB,bitorA,bitorB,pro_man_bitand;
wire sign_16,product_16_round,normalised,zero,carry,sign_16_carry,not_zero,w1;
wire [31:0]ripple_result_1,ripple_result_2,ripple_result_3;

xor (sign_16,A[31],B[31]); // sign_16 bit of answer

// if exponent_16 of any operand is zero then either it is Inf or NaN i.e., Exception is set to high
bitand_mul C1(.bitandin(A[30:23]),.bitandout(bitandA));
bitand_mul C2(.bitandin(B[30:23]),.bitandout(bitandB));
or(Exception,bitandA,bitandB); 

// if exponent_16 bits are not all zero then the implied bit (hidden bit) must be 1
bitor_mul  C3(.bitorin(A[30:23]),.bitorout(bitorA));
bitor_mul  C4(.bitorin(B[30:23]),.bitorout(bitorB));


wire [47:0] out_24;
unsigned_mul_24 my_unsigned_mul_24(	.a({bitorA,A[22:0]}),
									.b({bitorB,B[22:0]}),
									.out(out_24));
assign product_16 = out_24;

// Gate Level is to be imlemented     =======================================> :(
//mult_24bit unsigned_mul_24(.data_a({bitorA,A[22:0]}), .data_b({bitorB,B[22:0]}), .data_o(product_16));
//unsigned_mul_24 my_unsigned_mul_24(.a({bitorA,A[22:0]}),.b({bitorB,B[22:0]}),.out(product_16));
//assign product_16 = {bitorA,A[22:0]} * {bitorB,B[22:0]};

// Rounding the last 23 bits
bitor2_mul C5(.in(product_16[22:0]),.out(product_16_round));	
// If 48th bit of product_16 is 1 then product_16 is normalised and this bit will acts as hidden bit
and(normalised,product_16[47],1'b1);
// If not normalised, left shift the product_16 
assign product_16_normalised = normalised ? product_16 : product_16 << 1;
// 
assign product_16_mantissa = product_16_normalised[46:24] + (product_16_normalised[23] & product_16_round);
// product_16 is zero when mantissa is all zero
bitand2_mul C6(.in(product_16_mantissa[22:0]),.out(pro_man_bitand));
// if exception zero will be low otherwise depending on bitwise and of mantissa of product_16, zero will be assigned a value
mux_mul C7(.fi(pro_man_bitand),.si(1'b0),.SL(Exception),.Y(zero));
// Adding of exponent_16a and substracting BIAS from it 
rca8bit_mul  C8(.A(A[30:23]),.B(B[30:23]),.Cin(1'b0),.Sum(sum_exponent_16[7:0]),.Cout(sum_exponent_16[8]));
rca9bit_mul  C10( .A(sum_exponent_16[8:0]), .B(9'b110000001), .Cin(normalised),       .Sum(exponent_16[8:0]), .Cout(sign_16_carry));

// Since we are using 2's complement method for substraction if sign_carry is zero then it means we get a negative value and this is Underflow 
assign Underflow =  (A[30:23]==8'b0000_0000 || B[30:23]==8'b0000_0000) ? 1'b1 : ~sign_16_carry;
//not(Underflow,sign_carry);
// If sign_carry is 1 and 9th bit of exponent_16 is also 1 then it means result is positive but the exponent_16 had exceeded its limit
and(Overflow,sign_16_carry,exponent_16[8]);
// If Exception is high then assign 32'b0 to result
mux_multi_mul C13( .A({sign_16,exponent_16[7:0],product_16_mantissa}), .B(32'b00000000000000000000000000000000),       .SL(Exception),    .O(ripple_result_1[31:0]));
// If zero is high then result is zero
mux_multi_mul C14( .A(ripple_result_1[31:0]),                 .B({sign_16,31'b0000000000000000000000000000000}), .SL(zero),         .O(ripple_result_2[31:0]));
// If Overflow is high then it means exponent_16 had exceeded it value i.e., 8'b11111111
mux_multi_mul C15( .A(ripple_result_2[31:0]),                 .B({sign_16,31'b1111111100000000000000000000000}), .SL(Overflow),     .O(ripple_result_3[31:0]));
// If Underflow is high then it means exponent_16 is still  negative
mux_multi_mul C16( .A(ripple_result_3[31:0]),                 .B({sign_16,31'b0000000000000000000000000000000}), .SL(Underflow),    .O(Result[31:0])         );
// If Exception, zero, Overflow, Underflow are all low then answer is assigned to the result

endmodule
