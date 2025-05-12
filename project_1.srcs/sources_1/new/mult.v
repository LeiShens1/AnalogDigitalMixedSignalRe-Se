module mult 
(
    precision_mode_reg,
    a_in,                                // 输入的被乘数
    b_in,                                // 输入的乘数  
    mult_out,                            // 输出运算结果                                
    overflow                             // 输出溢出标志
);
    input [2:0] precision_mode_reg;
    input signed [31:0] a_in;
    input signed [31:0] b_in;
    output wire signed [31:0] mult_out;
    output wire [1:0] overflow;

    wire signed [7:0]  a_in_int4;
    wire signed [7:0]  b_in_int4;
    wire signed [7:0]  a_in_int8;
    wire signed [7:0]  b_in_int8;
    wire        [31:0] a_in_fp16_ext;
    wire        [31:0] b_in_fp16_ext;

    wire signed [15:0] mult_int4or8;
    wire signed [7:0]  mult_int4;
    wire signed [15:0] mult_int8;
    wire signed [31:0] mult_fp16or32;
    wire signed [31:0] mult_fp16;
    wire signed [31:0] mult_fp32;

    assign mult_int4  = mult_int4or8[7:0];
    assign mult_int8  = mult_int4or8;
    assign mult_fp16  = mult_fp16or32;
    assign mult_fp32  = mult_fp16or32;

    assign a_in_int4  = a_in[3] ? {4'b1111, a_in[3:0]} : {4'b0000, a_in[3:0]}; // 四位补成八位
    assign a_in_int8  = a_in[7:0];
    assign b_in_int4  = b_in[3] ? {4'b1111, b_in[3:0]} : {4'b0000, b_in[3:0]}; // 四位补成八位
    assign b_in_int8  = b_in[7:0];
    FP16toFP32 my_16_2_32_0 (a_in[15:0], a_in_fp16_ext);
    FP16toFP32 my_16_2_32_1 (b_in[15:0], b_in_fp16_ext);

    assign mult_out  = precision_mode_reg == 0 ? {24'b0, mult_int4[7:0]}: 
                       precision_mode_reg == 1 ? {16'b0, mult_int8     }: 
                       precision_mode_reg == 2 ?         mult_fp16      :
                       precision_mode_reg == 3 ?         mult_fp32      :
                       precision_mode_reg == 4 ? {24'b0, mult_int4[7:0]}:
                       precision_mode_reg == 5 ? {16'b0, mult_int8     }:
                       precision_mode_reg == 6 ?         mult_fp16      :0;

    signed_mul_8 my_mult_int8 ( .signed_mul_a_i(precision_mode_reg == 0 || precision_mode_reg == 4 ? a_in_int4 : precision_mode_reg == 1 || precision_mode_reg == 5 ? a_in_int8 : 8'b0),
                                .signed_mul_b_i(precision_mode_reg == 0 || precision_mode_reg == 4 ? b_in_int4 : precision_mode_reg == 1 || precision_mode_reg == 5 ? b_in_int8 : 8'b0),
                                .signed_mul_s_o(mult_int4or8));

    float_mul_16or32 my_floatMuilt16 (  .A(precision_mode_reg == 2 || precision_mode_reg == 6 ? a_in_fp16_ext : precision_mode_reg == 3 ? a_in : 32'b0), 
                                        .B(precision_mode_reg == 2 || precision_mode_reg == 6 ? b_in_fp16_ext : precision_mode_reg == 3 ? b_in : 32'b0), 
                                        .Result(mult_fp16or32),
                                        .overflow(overflow));

endmodule
 

module signed_mul_8 #(parameter    DATA_LEN = 8 )
    (
        input  [ DATA_LEN -1   : 0 ] signed_mul_a_i    ,
        input  [ DATA_LEN -1   : 0 ] signed_mul_b_i    ,
    
        output [ DATA_LEN*2 -1 : 0 ] signed_mul_s_o    
    );
 
    wire [ DATA_LEN -1 : 0 ] a_bi [ DATA_LEN -1 : 0 ] ;
    
    //-----------------------------------------------------------------------
    //----每一行计算
    //-----------------------------------------------------------------------
    generate
        genvar i ;
        genvar j ;
    
        //AB
        for( i=0 ; i < DATA_LEN - 1 ; i=i+1 )begin
            for( j=0 ; j < DATA_LEN - 1 ; j=j+1)begin
                assign a_bi[i][j] = signed_mul_a_i[i] & signed_mul_b_i[j] ;
            end
        end
    
        //A4*B4 = (-a3*2^3 + A3) * (-b3*2^3 + B3) = a3b3*x^6 -a3B3*2^3 -A3b3*2^3 + A3B3 
        //aB
        for( i=0 ; i < DATA_LEN - 1 ; i=i+1 )begin
            assign a_bi[i][DATA_LEN - 1] = ~(signed_mul_a_i[DATA_LEN - 1] & signed_mul_b_i[i]) ;
        end
    
        //Ab
        for( i=0 ; i < DATA_LEN - 1 ; i=i+1 )begin
            assign a_bi[DATA_LEN - 1][i] = ~(signed_mul_a_i[i] & signed_mul_b_i[DATA_LEN - 1]) ;
        end
    
        //ab
        assign a_bi[DATA_LEN - 1][DATA_LEN - 1] = signed_mul_a_i[DATA_LEN - 1] & signed_mul_b_i[DATA_LEN - 1] ;
    
    endgenerate
    
    //-----------------------------------------------------------------------
    //----求和
    //-----------------------------------------------------------------------
    wire [DATA_LEN*2 -1 : 0]add_sum[DATA_LEN -1 : 0];
    
    generate
        genvar k ;
    
        assign add_sum[0] = {1'b1 , a_bi[0][DATA_LEN - 1] , a_bi[0][DATA_LEN - 2 : 0]} ;
        for( k=1 ; k<DATA_LEN-1 ; k=k+1 )begin
            assign add_sum[k] = { a_bi[k][DATA_LEN - 1] , a_bi[k][DATA_LEN - 2 : 0] } << k ;
        end
        assign add_sum[DATA_LEN - 1] = { 1'b1 , a_bi[DATA_LEN - 1][DATA_LEN - 1] , a_bi[DATA_LEN - 1][DATA_LEN - 2 : 0] } << (DATA_LEN - 1) ;
    
    endgenerate
    
    //根据实际多少位需要自己添加  可以使用类似于累加器  但是循环好像并不好写
    assign signed_mul_s_o = add_sum[0] + add_sum[1] + add_sum[2] + add_sum[3] + 
                            add_sum[4] + add_sum[5] + add_sum[6] + add_sum[7];
endmodule

module unsigned_mul_24
    #(parameter WIDTH_A = 24,
        WIDTH_B = 24)
    (
    input   [WIDTH_A-1:0]        a,
    input   [WIDTH_B-1:0]        b,
    output  reg [WIDTH_A+WIDTH_B-1:0]   out
    );
    integer i; 
    always @(a or b) begin
    out = 0;
    for(i=0; i<WIDTH_B; i=i+1)
    if(b[i])
    out = out + (a << i);
    end
endmodule


