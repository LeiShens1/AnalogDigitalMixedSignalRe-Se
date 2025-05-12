`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/29 18:28:05
// Design Name: 
// Module Name: pe8x8
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


module pe16x16(
    clk,
    rst,
    en,
    precision_mode_reg,
    in3,
    out1,
    out2,
    a_in,
    b_in,
    valid_1,
    valid_2
    );
    parameter N = 32;
    localparam INT4 = 4;
    localparam INT8 = 8;
    localparam FP16 = 16;
    localparam FP32 = 32;

    input clk;
    input rst;
    input en;
    input [N*64-1:0] in3;
    input [N*16-1 :0] a_in;
    input [N*16-1 :0] b_in;
    input [2:0]      precision_mode_reg;        // 0: INT4, 1: INT8, 2: FP16, 3: FP32, 4: INT4-INT32, 5: INT8-INT32, 6: FP16-FP32
    output wire [N*256-1:0] out1, out2;         // �������
    output reg  valid_1;                        // �������һ��Ч
    output reg  valid_2;                        // ����������Ч

    reg [N-1: 0]a_in_reg        [15:0][15:0];   // ���������pe��ĽӿڼĴ���
    reg [N-1: 0]b_in_reg        [15:0];         // ���������pe��ĽӿڼĴ���
    reg [N-1: 0]out_1_2D        [15:0][15:0];   // �������2D��ʽ
    reg [N-1: 0]out_2_2D        [15:0][15:0];   // �������2D��ʽ
    reg [1:   0]overflow_out_1  [15:0][15:0];   // ����ź� 0:�������1: �����, -1: �����
    reg [1:   0]overflow_out_2  [15:0][15:0];
    wire [N-1: 0]down           [15:0][15:0];   // ����pe�����������
    wire [N-1: 0]mult_out       [15:0][15:0];   // �˷��������
    wire [N-1: 0]sum            [15:0];         // ��˽�����
    wire [1:   0]overflow       [15:0];         // ����ź�
    reg state_machine_en;                       // ״̬��ʹ���źţ��Ĵ������ͣ����ڴ�������ʹ���ź� en ���ͺ������ʱ16��ʱ�����ڣ���֤��������
    wire state_machine_en_wire;                 // ״̬��ʹ���źţ������ͣ����ڴ�������ʹ���ź� en ���ͺ������ʱ16��ʱ�����ڣ���֤��������
    reg [2:0]cycle_times = 6;                   // ѭ��������Ĭ��Ϊ6��IN4, INT8, FP16 ģʽ��ѭ�����κ�ʼ�����Ч�ľ���
    reg [3:0]state;                             // ״̬��״̬
    reg flag_state;                             // ״̬����ż��������out1_2D��out2_2D������д�� 
/*en���½��ؼ�⣬���ڿ���state_machine_en_wire�ź�*/
    reg [4:0] counter;      // 16��������Ҫ5λ������ (0-15)
    reg prev_en;            // ���ڱ��ؼ���EN��ʷ״̬
    assign state_machine_en_wire = en ? 1 : state_machine_en;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            // �첽��λ��ʼ��
            prev_en   <= 1'b0;
            counter   <= 5'd0;
            state_machine_en  <= 1'b0;
        end else begin
            prev_en <= en;  // ��¼EN��ʷ״̬
            
            // ״̬���߼�
            if (en) begin
                // ENΪ��ʱ�������
                counter  <= 5'd0;
                state_machine_en <= 1'b1;
            end else if (!en && prev_en) begin
                // ��⵽�½���ʱ����������
                counter <= 5'd1;
                state_machine_en <= 1'b1;
            end else if (counter > 0) begin
                // �����������ڼ�
                if (counter == 5'd15) begin
                    counter  <= 5'd0;               // �������
                    state_machine_en <= 1'b0;       // �ر����
                end else begin
                    counter <= counter + 5'd1;      // ��������
                    state_machine_en <= 1'b1;       // �������
                end
            end else begin
                // Ĭ�ϱ���״̬
                state_machine_en <= 1'b0;
            end
        end
    end
/* �����Ч��״̬������ż״̬��״̬�������Ŀ��� */
    always @(posedge clk or negedge rst) 
        if(!rst)begin 
            state <= 0;
            valid_1 <= 0; 
            valid_2 <= 0;
            flag_state <= 0;
            cycle_times <= 6;
        end
        else if(state_machine_en_wire) begin
            if( state == 15)begin
                cycle_times <= cycle_times==0 ? 0 : cycle_times-1;
                state <= 0;
                flag_state <= ~flag_state;
                valid_1 <= (cycle_times==5 || cycle_times==3 ? 1 : 0);     // ��������״̬��ѭ�����ٿ�ʼ����valid
                valid_2 <= (cycle_times==4 || cycle_times==2 ? 1 : 0);
            end
            else begin
                state <= state+1;
                valid_1 <= 0;
                valid_2 <= 0;
            end 
        end else begin
            cycle_times <= 6;
            state <= 0;
            valid_2 <= 0;
            valid_1 <= 0;
            flag_state <= 0;
        end

/* ��״̬���߼� */
    integer  i, j;
    generate
    always @(posedge clk or negedge rst) begin
        if(!rst)begin
            for(i=0; i<16; i=i+1)begin
                for(j=0; j<16; j=j+1) begin
                    a_in_reg[i][j] <= 0;
                    out_1_2D[i][j] <= 0;    overflow_out_1[i][j] <= 0;
                    out_2_2D[i][j] <= 0;    overflow_out_2[i][j] <= 0;
                end
                b_in_reg[i] <= 0;
            end
        end
        else if(state_machine_en_wire) begin
            case(state)
                0: begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1)begin
                            a_in_reg[0][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1)begin
                            a_in_reg[0][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 0; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i]       <= sum[i];
                            overflow_out_1[15-i][i] <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i]       <= sum[i];
                            overflow_out_2[15-i][i] <= overflow[i];
                        end
                    end
                end
                1: begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1)begin
                            a_in_reg[1][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1)begin
                            a_in_reg[1][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 1; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-1]         <= sum[i];
                            overflow_out_1[15-i][i-1]   <= overflow[i];
                        end
                        out_2_2D[15][15] <= sum[0];   overflow_out_2[15][15] <= overflow[0];
                    end else begin
                        for(i = 1; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-1]         <= sum[i];
                            overflow_out_2[15-i][i-1]   <= overflow[i];
                        end
                        out_1_2D[15][15] <= sum[0];   overflow_out_1[15][15] <= overflow[0];
                    end
                end
                2: begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[2][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[2][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 2; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-2]         <= sum[i];
                            overflow_out_1[15-i][i-2]   <= overflow[i];
                        end
                        for(i = 0; i < 2; i = i + 1)begin
                            out_2_2D[15-i][14+i]        <= sum[i];   
                            overflow_out_2[15-i][14+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 2; i = i + 1)begin
                            out_1_2D[15-i][14+i]        <= sum[i];   
                            overflow_out_1[15-i][14+i]  <= overflow[i];
                        end
                        for(i = 2; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-2]         <= sum[i];
                            overflow_out_2[15-i][i-2]   <= overflow[i];
                        end
                    end
                end
                3: begin 
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[3][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[3][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 3; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-3]         <= sum[i];
                            overflow_out_1[15-i][i-3]   <= overflow[i];
                        end
                        for(i = 0; i < 3; i = i + 1)begin
                            out_2_2D[15-i][13+i]        <= sum[i];   
                            overflow_out_2[15-i][13+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 3; i = i + 1)begin
                            out_1_2D[15-i][13+i]        <= sum[i];   
                            overflow_out_1[15-i][13+i]  <= overflow[i];
                        end
                        for(i = 3; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-3]         <= sum[i];
                            overflow_out_2[15-i][i-3]   <= overflow[i];
                        end
                    end
                end
                4: begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[4][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[4][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 4; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-4]         <= sum[i];
                            overflow_out_1[15-i][i-4]   <= overflow[i];
                        end
                        for(i = 0; i < 4; i = i + 1)begin
                            out_2_2D[15-i][12+i]        <= sum[i];   
                            overflow_out_2[15-i][12+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 4; i = i + 1)begin
                            out_1_2D[15-i][12+i]        <= sum[i];   
                            overflow_out_1[15-i][12+i]  <= overflow[i];
                        end
                        for(i = 4; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-4]         <= sum[i];
                            overflow_out_2[15-i][i-4]   <= overflow[i];
                        end
                    end
                end
                5: begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[5][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[5][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 5; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-5]         <= sum[i];
                            overflow_out_1[15-i][i-5]   <= overflow[i];
                        end
                        for(i = 0; i < 5; i = i + 1)begin
                            out_2_2D[15-i][11+i]        <= sum[i];   
                            overflow_out_2[15-i][11+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 5; i = i + 1)begin
                            out_1_2D[15-i][11+i]        <= sum[i];   
                            overflow_out_1[15-i][11+i]  <= overflow[i];
                        end
                        for(i = 5; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-5]         <= sum[i];
                            overflow_out_2[15-i][i-5]   <= overflow[i];
                        end
                    end
                end
                6: begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[6][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[6][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 6; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-6]         <= sum[i];
                            overflow_out_1[15-i][i-6]   <= overflow[i];
                        end
                        for(i = 0; i < 6; i = i + 1)begin
                            out_2_2D[15-i][10+i]        <= sum[i];   
                            overflow_out_2[15-i][10+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 6; i = i + 1)begin
                            out_1_2D[15-i][10+i]        <= sum[i];   
                            overflow_out_1[15-i][10+i]  <= overflow[i];
                        end
                        for(i = 6; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-6]         <= sum[i];
                            overflow_out_2[15-i][i-6]   <= overflow[i];
                        end
                    end
                end
                7: begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[7][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[7][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 7; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-7]         <= sum[i];
                            overflow_out_1[15-i][i-7]   <= overflow[i];
                        end
                        for(i = 0; i < 7; i = i + 1)begin
                            out_2_2D[15-i][9+i]        <= sum[i];   
                            overflow_out_2[15-i][9+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 7; i = i + 1)begin
                            out_1_2D[15-i][9+i]        <= sum[i];   
                            overflow_out_1[15-i][9+i]  <= overflow[i];
                        end
                        for(i = 7; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-7]         <= sum[i];
                            overflow_out_2[15-i][i-7]   <= overflow[i];
                        end
                    end
                end
                8:begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[8][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[8][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 8; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-8]         <= sum[i];
                            overflow_out_1[15-i][i-8]   <= overflow[i];
                        end
                        for(i = 0; i < 8; i = i + 1)begin
                            out_2_2D[15-i][8+i]        <= sum[i];   
                            overflow_out_2[15-i][8+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 8; i = i + 1)begin
                            out_1_2D[15-i][8+i]        <= sum[i];   
                            overflow_out_1[15-i][8+i]  <= overflow[i];
                        end
                        for(i = 8; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-8]         <= sum[i];
                            overflow_out_2[15-i][i-8]   <= overflow[i];
                        end
                    end
                end
                9:begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[9][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[9][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 9; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-9]         <= sum[i];
                            overflow_out_1[15-i][i-9]   <= overflow[i];
                        end
                        for(i = 0; i < 9; i = i + 1)begin
                            out_2_2D[15-i][7+i]        <= sum[i];   
                            overflow_out_2[15-i][7+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 9; i = i + 1)begin
                            out_1_2D[15-i][7+i]        <= sum[i];   
                            overflow_out_1[15-i][7+i]  <= overflow[i];
                        end
                        for(i = 9; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-9]         <= sum[i];
                            overflow_out_2[15-i][i-9]   <= overflow[i];
                        end
                    end
                end
                10:begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[10][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[10][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 10; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-10]         <= sum[i];
                            overflow_out_1[15-i][i-10]   <= overflow[i];
                        end
                        for(i = 0; i < 10; i = i + 1)begin
                            out_2_2D[15-i][6+i]        <= sum[i];   
                            overflow_out_2[15-i][6+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 10; i = i + 1)begin
                            out_1_2D[15-i][6+i]        <= sum[i];   
                            overflow_out_1[15-i][6+i]  <= overflow[i];
                        end
                        for(i = 10; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-10]         <= sum[i];
                            overflow_out_2[15-i][i-10]   <= overflow[i];
                        end
                    end
                end
                11:begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[11][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[11][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 11; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-11]         <= sum[i];
                            overflow_out_1[15-i][i-11]   <= overflow[i];
                        end
                        for(i = 0; i < 11; i = i + 1)begin
                            out_2_2D[15-i][5+i]        <= sum[i];   
                            overflow_out_2[15-i][5+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 11; i = i + 1)begin
                            out_1_2D[15-i][5+i]        <= sum[i];   
                            overflow_out_1[15-i][5+i]  <= overflow[i];
                        end
                        for(i = 11; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-11]         <= sum[i];
                            overflow_out_2[15-i][i-11]   <= overflow[i];
                        end
                    end
                end
                12:begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[12][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[12][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 12; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-12]         <= sum[i];
                            overflow_out_1[15-i][i-12]   <= overflow[i];
                        end
                        for(i = 0; i < 12; i = i + 1)begin
                            out_2_2D[15-i][4+i]        <= sum[i];   
                            overflow_out_2[15-i][4+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 12; i = i + 1)begin
                            out_1_2D[15-i][4+i]        <= sum[i];   
                            overflow_out_1[15-i][4+i]  <= overflow[i];
                        end
                        for(i = 12; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-12]         <= sum[i];
                            overflow_out_2[15-i][i-12]   <= overflow[i];
                        end
                    end
                end
                13:begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[13][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[13][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 13; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-13]         <= sum[i];
                            overflow_out_1[15-i][i-13]   <= overflow[i];
                        end
                        for(i = 0; i < 13; i = i + 1)begin
                            out_2_2D[15-i][3+i]        <= sum[i];   
                            overflow_out_2[15-i][3+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 13; i = i + 1)begin
                            out_1_2D[15-i][3+i]        <= sum[i];   
                            overflow_out_1[15-i][3+i]  <= overflow[i];
                        end
                        for(i = 13; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-13]         <= sum[i];
                            overflow_out_2[15-i][i-13]   <= overflow[i];
                        end
                    end
                end
                14:begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[14][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[14][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 14; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-14]         <= sum[i];
                            overflow_out_1[15-i][i-14]   <= overflow[i];
                        end
                        for(i = 0; i < 14; i = i + 1)begin
                            out_2_2D[15-i][2+i]        <= sum[i];   
                            overflow_out_2[15-i][2+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 14; i = i + 1)begin
                            out_1_2D[15-i][2+i]        <= sum[i];   
                            overflow_out_1[15-i][2+i]  <= overflow[i];
                        end
                        for(i = 14; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-14]         <= sum[i];
                            overflow_out_2[15-i][i-14]   <= overflow[i];
                        end
                    end
                end
                15:begin
                    if(en)begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[15][i]  <= a_in[N*(16-i)-1-:N];
                            b_in_reg[i]     <= b_in[N*(16-i)-1-:N];
                        end
                    end else begin
                        for(i = 0; i < 16; i = i + 1) begin 
                            a_in_reg[15][i]  <= 0;
                            b_in_reg[i]     <= 0;
                        end
                    end
                    if(flag_state)begin
                        for(i = 15; i < 16; i = i + 1)begin
                            out_1_2D[15-i][i-15]         <= sum[i];
                            overflow_out_1[15-i][i-15]   <= overflow[i];
                        end
                        for(i = 0; i < 15; i = i + 1)begin
                            out_2_2D[15-i][1+i]        <= sum[i];   
                            overflow_out_2[15-i][1+i]  <= overflow[i];
                        end
                    end else begin
                        for(i = 0; i < 15; i = i + 1)begin
                            out_1_2D[15-i][1+i]        <= sum[i];   
                            overflow_out_1[15-i][1+i]  <= overflow[i];
                        end
                        for(i = 15; i < 16; i = i + 1)begin
                            out_2_2D[15-i][i-15]         <= sum[i];
                            overflow_out_2[15-i][i-15]   <= overflow[i];
                        end
                    end
                end
            endcase
        end else begin
            for(i=0; i<16; i=i+1)begin
                for(j=0; j<16; j=j+1) begin
                    a_in_reg[i][j] <= 0;
                    out_1_2D[i][j] <= 0;
                    out_2_2D[i][j] <= 0;
                end
                b_in_reg[i] <= 0;
            end
        end
    end
    endgenerate

    genvar p, q;
    generate
        for(p = 0; p < 16; p = p + 1)begin
            for(q = 0; q < 16; q = q + 1)begin
                 assign out1 [16*FP32*p + (q+1)*FP32-1 -: FP32] = out_1_2D[p][q];         
            end
        end
    endgenerate

    generate
        for (p = 0; p < 16; p = p + 1)begin
            for (q = 0; q < 16; q = q + 1)begin
                assign out2 [16*FP32*p + (q+1)*FP32-1 -: FP32] = out_2_2D[p][q];
            end
        end
    endgenerate
    generate
    for(p=0; p<16; p=p+1)
        for(q=0; q<16; q=q+1) begin
            if(p==0)
                pe pe_inst(
                    .clk        (clk),
                    .rst        (rst),
                    .a_in       (a_in_reg[p][q]),
                    .b_in       (b_in_reg[q]),
                    .precision_mode_reg(precision_mode_reg),
                    .down       (down[p][q]),
                    .mult_out   (mult_out[p][q])
                );       
            else 
                pe pe_inst(
                    .clk        (clk),
                    .rst        (rst),
                    .a_in       (a_in_reg[p][q]),
                    .b_in       (down[p-1][q]),
                    .precision_mode_reg(precision_mode_reg),
                    .down       (down[p][q]),
                    .mult_out   (mult_out[p][q])
                );                                       
        end
    endgenerate
    generate
        for(p=0; p<16; p=p+1) begin
            super_adder super_adder_inst(
                .precision_mode_reg(precision_mode_reg),
                .A(mult_out[p][0]),
                .B(mult_out[p][1]),
                .C(mult_out[p][2]),
                .D(mult_out[p][3]),
                .E(mult_out[p][4]),
                .F(mult_out[p][5]),
                .G(mult_out[p][6]),
                .H(mult_out[p][7]),
                .I(mult_out[p][8]),
                .J(mult_out[p][9]),
                .K(mult_out[p][10]),
                .L(mult_out[p][11]),
                .M(mult_out[p][12]),
                .N(mult_out[p][13]),
                .O(mult_out[p][14]),
                .P(mult_out[p][15]),
                .out(sum[p]),
                .overflow(overflow[p])
            );
        end
    endgenerate
endmodule
