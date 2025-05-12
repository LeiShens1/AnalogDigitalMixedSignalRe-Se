module super_adder (
    precision_mode_reg,

    A,
    B,
    C,
    D,

    E,
    F,
    G,
    H,

    I,
    J,
    K,
    L,

    M,
    N,
    O,
    P,

    out,
    overflow
);
    input [31:0] A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P;
    input [2:0] precision_mode_reg;
    output wire [31:0] out;
    output wire [1:0]  overflow;

    wire signed [7 :0] A_INT4, B_INT4, C_INT4, D_INT4, E_INT4, F_INT4, G_INT4, H_INT4, I_INT4, J_INT4, K_INT4, L_INT4, M_INT4, N_INT4, O_INT4, P_INT4;
    wire signed [15:0] A_INT8, B_INT8, C_INT8, D_INT8, E_INT8, F_INT8, G_INT8, H_INT8, I_INT8, J_INT8, K_INT8, L_INT8, M_INT8, N_INT8, O_INT8, P_INT8;
    wire signed [11 :0] INT4_sum;
    wire signed [19:0] INT8_sum;
    wire signed [1 :0] INT4_overflow;
    wire signed [1 :0] INT8_overflow;
    wire signed [1 :0] FP16_overflow;
    wire signed [1 :0] FP32_overflow;
    wire signed [15:0] out_fp16;
    wire signed [31:0] out_fp32;
    wire signed [15:0] AB, CD, EF, GH, IJ, KL, MN, OP, ABCD, EFGH, IJKL, MNOP;
    wire signed [31:0] AB32, CD32, EF32, GH32, IJ32, KL32, MN32, OP32, ABCD32, EFGH32, IJKL32, MNOP32, ABCDEFGH32, IJKLMNOP32;

    assign INT4_sum = A_INT4 + B_INT4 + C_INT4 + D_INT4 + E_INT4 + F_INT4 + G_INT4 + H_INT4 + I_INT4 + J_INT4 + K_INT4 + L_INT4 + M_INT4 + N_INT4 + O_INT4 + P_INT4;
    assign INT8_sum = A_INT8 + B_INT8 + C_INT8 + D_INT8 + E_INT8 + F_INT8 + G_INT8 + H_INT8 + I_INT8 + J_INT8 + K_INT8 + L_INT8 + M_INT8 + N_INT8 + O_INT8 + P_INT8;
    assign INT4_overflow = ( INT4_sum[11:3] ==9'b0000000     || INT4_sum[11:3] ==9'b111111111     ) ? 0 : INT4_sum[11] ? -1 : 1;
    assign INT8_overflow = ( INT8_sum[19:7] ==13'b00000000000|| INT8_sum[19:7] ==13'b1111111111111) ? 0 : INT8_sum[19] ? -1 : 1;
    assign overflow =   precision_mode_reg==0? INT4_overflow:
                        precision_mode_reg==1? INT8_overflow:
                        precision_mode_reg==2? FP16_overflow:
                        precision_mode_reg==3? FP32_overflow:0
                        ;
    assign A_INT4 = A[7:0];
    assign B_INT4 = B[7:0];
    assign C_INT4 = C[7:0];
    assign D_INT4 = D[7:0];
    assign E_INT4 = E[7:0];
    assign F_INT4 = F[7:0];
    assign G_INT4 = G[7:0];
    assign H_INT4 = H[7:0];
    assign I_INT4 = I[7:0];
    assign J_INT4 = J[7:0];
    assign K_INT4 = K[7:0];
    assign L_INT4 = L[7:0];
    assign M_INT4 = M[7:0];
    assign N_INT4 = N[7:0];
    assign O_INT4 = O[7:0];
    assign P_INT4 = P[7:0];

    assign A_INT8 = A[15:0];
    assign B_INT8 = B[15:0];
    assign C_INT8 = C[15:0];
    assign D_INT8 = D[15:0];
    assign E_INT8 = E[15:0];
    assign F_INT8 = F[15:0];
    assign G_INT8 = G[15:0];
    assign H_INT8 = H[15:0];
    assign I_INT8 = I[15:0];
    assign J_INT8 = J[15:0];
    assign K_INT8 = K[15:0];
    assign L_INT8 = L[15:0];
    assign M_INT8 = M[15:0];
    assign N_INT8 = N[15:0];
    assign O_INT8 = O[15:0];
    assign P_INT8 = P[15:0];

    assign out =    precision_mode_reg==0? INT4_overflow==0? {28'b0, INT4_sum[3:0]} : INT4_overflow==1? {29'b0, 3'b111    }: {28'b0, 4'b1000    }:
                    precision_mode_reg==1? INT8_overflow==0? {24'b0, INT8_sum[7:0]} : INT8_overflow==1? {25'b0, 7'b1111111}: {24'b0, 8'b10000000}:
                    precision_mode_reg==2? {16'b0, out_fp16}:
                    precision_mode_reg==3? out_fp32:
                    precision_mode_reg==4? INT4_sum[11]?{20'b11111111111111111111, INT4_sum}: {20'b0, INT4_sum}:
                    precision_mode_reg==5? INT8_sum[19]?{12'b111111111111,         INT8_sum}: {12 'b0, INT8_sum}:
                    precision_mode_reg==6? out_fp32:
                    0;

    FP32toFP16 my32_2_16(out_fp32, out_fp16, FP16_overflow);

    floatAdd32 my_floatAdd32_0(.in1(A), .in2(B), .out(AB32));
    floatAdd32 my_floatAdd32_1(.in1(C), .in2(D), .out(CD32));
    floatAdd32 my_floatAdd32_2(.in1(E), .in2(F), .out(EF32));
    floatAdd32 my_floatAdd32_3(.in1(G), .in2(H), .out(GH32));
    floatAdd32 my_floatAdd32_4(.in1(I), .in2(J), .out(IJ32));
    floatAdd32 my_floatAdd32_5(.in1(K), .in2(L), .out(KL32));
    floatAdd32 my_floatAdd32_6(.in1(M), .in2(N), .out(MN32));
    floatAdd32 my_floatAdd32_7(.in1(O), .in2(P), .out(OP32));
    floatAdd32 my_floatAdd32_8(.in1(AB32), .in2(CD32), .out(ABCD32));
    floatAdd32 my_floatAdd32_9(.in1(EF32), .in2(GH32), .out(EFGH32));
    floatAdd32 my_floatAdd32_10(.in1(IJ32), .in2(KL32), .out(IJKL32));
    floatAdd32 my_floatAdd32_11(.in1(MN32), .in2(OP32), .out(MNOP32));
    floatAdd32 my_floatAdd32_12(.in1(ABCD32), .in2(EFGH32), .out(ABCDEFGH32));
    floatAdd32 my_floatAdd32_13(.in1(IJKL32), .in2(MNOP32), .out(IJKLMNOP32));
    floatAdd32 my_floatAdd32_14(.in1(ABCDEFGH32), .in2(IJKLMNOP32), .out(out_fp32), .overflow(FP32_overflow));


endmodule