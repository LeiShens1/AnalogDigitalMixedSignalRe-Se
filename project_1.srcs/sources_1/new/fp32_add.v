// 分解输入
module floatAdd32 (
    input [31:0] in1,
    input [31:0] in2,
    output reg [31:0] out,
    output reg [1:0] overflow);

    // 提取符号位、指数位和尾数位
    wire sign1 = in1[31];
    wire sign2 = in2[31];
    wire [7:0] exp1 = in1[30:23];
    wire [7:0] exp2 = in2[30:23];
    wire [22:0] mantissa1 = in1[22:0];
    wire [22:0] mantissa2 = in2[22:0];

    // 隐藏位
    wire [23:0] mantissa1_ext = {1'b1, mantissa1};
    wire [23:0] mantissa2_ext = {1'b1, mantissa2};

    // 比较指数大小
    wire exp_greater = {exp1, mantissa1} > {exp2, mantissa2};
    wire [7:0] exp_max = exp_greater ? exp1 : exp2;
    wire [7:0] exp_min = exp_greater ? exp2 : exp1;
    wire [23:0] mantissa_max = exp_greater ? mantissa1_ext : mantissa2_ext;
    wire [23:0] mantissa_min = exp_greater ? mantissa2_ext : mantissa1_ext;
    wire min_sign = exp_greater ? sign2 : sign1;
    wire max_sign = exp_greater ? sign1 : sign2;

    // 右移较小的尾数以对齐指数
    wire [23:0] mantissa_min_shifted = mantissa_min >> (exp_max - exp_min);

    // 尾数相加或相减
    wire signed [24:0] mantissa_sum;
    assign mantissa_sum = (min_sign == max_sign) ? (mantissa_max + mantissa_min_shifted) : (mantissa_max - mantissa_min_shifted);

    // 处理尾数归一化
    reg [23:0] mantissa_normalized;
    reg [7:0] exp_normalized;
    reg sign_result;
    reg signed[7:0]  shift_count;

    always @(*) begin
        if (mantissa_sum[24]) begin
            shift_count = 1;
        end else if (mantissa_sum[23]) begin
            shift_count = 0;
        end else if (mantissa_sum[22]) begin
            shift_count = -1;
        end else if (mantissa_sum[21]) begin
            shift_count = -2;
        end else if (mantissa_sum[20]) begin
            shift_count = -3;
        end else if (mantissa_sum[19]) begin
            shift_count = -4;
        end else if (mantissa_sum[18]) begin
            shift_count = -5;
        end else if (mantissa_sum[17]) begin
            shift_count = -6;
        end else if (mantissa_sum[16]) begin
            shift_count = -7;
        end else if (mantissa_sum[15]) begin
            shift_count = -8;
        end else if (mantissa_sum[14]) begin
            shift_count = -9;
        end else if (mantissa_sum[13]) begin
            shift_count = -10;
        end else if (mantissa_sum[12]) begin
            shift_count = -11;
        end else if (mantissa_sum[11]) begin
            shift_count = -12;
        end else if (mantissa_sum[10]) begin
            shift_count = -13;
        end else if (mantissa_sum[9]) begin
            shift_count = -14;
        end else if (mantissa_sum[8]) begin
            shift_count = -15;
        end else if (mantissa_sum[7]) begin
            shift_count = -16;
        end else if (mantissa_sum[6]) begin
            shift_count = -17;
        end else if (mantissa_sum[5]) begin
            shift_count = -18;
        end else if (mantissa_sum[4]) begin
            shift_count = -19;
        end else if (mantissa_sum[3]) begin
            shift_count = -20;
        end else if (mantissa_sum[2]) begin
            shift_count = -21;
        end else if (mantissa_sum[1]) begin
            shift_count = -22;
        end else if (mantissa_sum[0]) begin
            shift_count = -23;
        end else begin
            shift_count = -24;
        end

        if (shift_count > 0) begin
            mantissa_normalized = mantissa_sum[24:1];
            exp_normalized = !exp1 && !exp2 ? 0: exp_max + 1;
        end else begin
            mantissa_normalized = mantissa_sum << (-shift_count);
            exp_normalized = (exp_max > (-shift_count)) ? exp_max + shift_count : 0;
        end

        sign_result = (mantissa_sum[24] && (min_sign != max_sign)) ? ~max_sign : max_sign;
    end

    // 去除隐藏位
    wire [22:0] mantissa_final = mantissa_normalized[22:0];

    // 组合结果
    always @(*) begin
        if(exp_normalized == 8'b11111111) begin
            out <= {sign_result, 8'b11111111, 23'b0};
            overflow <= sign_result ? 1 : -1;
        end else begin
            out <= {sign_result, exp_normalized, mantissa_final};
            overflow <= 0;
        end
    end

endmodule