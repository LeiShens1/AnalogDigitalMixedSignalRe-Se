clear all;                  % 清除所有变量
close all;                  % 关闭所有窗口
clc;                        % 清屏
%% 基本参数-模拟部分
f1=1000;                    % 第一个模拟频率分量
f2=0;                       % 第二个模拟频率分量

%% 基本参数-数字部分
M=10;                       % 产生码元数    
L=1625000;                  % 每个码元采样次数
Ts=0.025;                   % 码元的持续时间
Rb=1/Ts;                    % 码元速率40Hz
dt=Ts/L;                    % 采样间隔
TotalT=M*Ts;                % 总时间
t=0:dt:TotalT-dt;           % 时间
t_low=t(1:1625:length(t));
Fs=1/dt;                    % 采样频率65Msps

%% 产生单极性波形
wave=[1,0,1,0,0,1,1,0,0,1]; % 产生二进制随机码,M为码元个数
fz=ones(1,L);               % 定义复制的次数L,L为每码元的采样点数
x1=wave(fz,:);              % 将原来wave的第一行复制L次，称为L*M的矩阵
jidai=reshape(x1,1,L*M);    % 产生单极性不归零矩形脉冲波形，将刚得到的L*M矩阵，按列重新排列形成1*(L*M)的矩阵

%% 2ASK调制
fc=11500;                   % 载波频率11.5kHz       
zb=cos(2*pi*fc*t);          % 载波
ask2=jidai.*zb;             % 2ASK的模拟调制 
anlog=cos(2*pi*f1*t);       % 1kHz模拟信号
mix=anlog+ask2;

%% AM 调制
fc_1=20000000;              % 载波频率20MHz
zb_1=cos(2*pi*fc_1*t);
AM=(mix+2).*zb_1;

%% 绘制模拟信号，基带信号，2ASK信号，2ASK信号加模拟信号
figure(1);
subplot(511);               % 窗口分割成5*1的，当前是第1个子图 
plot(t,anlog,'LineWidth',2);
title('模拟信号');
xlabel('时间/s');
ylabel('幅度');
axis([0.0225,0.0275,-1.5,1.5]);

subplot(512);               % 窗口分割成5*1的，当前是第2个子图 
plot(t,jidai,'LineWidth',2);% 绘制基带码元波形，线宽为2
title('基带信号波形');       % 标题
xlabel('时间/s');           % x轴标签
ylabel('幅度');             % y轴标签
axis([0.0225,0.0275,-0.1,1.1])   % 坐标范围限制

subplot(513)                % 窗口分割成5*1的，当前是第3个子图 
plot(t,ask2,'LineWidth',2); % 绘制2ASK的波形 
title('2ASK信号波形')        % 标题
axis([0.0225,0.0275,-1.1,1.1]);  % 坐标范围限制
xlabel('时间/s');           % x轴标签
ylabel('幅度');             % y轴标签

subplot(514);               % 窗口分割成5*1的，当前是第4个子图
plot(t,mix,'LineWidth',2);  % 绘制2ASK信号加模拟信号的波形
title('2ASK信号加模拟信号');
axis([0.0225,0.0275,-2,2]);
xlabel('时间/s');
ylabel('幅度');

subplot(515);
plot(t,AM,'LineWidth',2);
title('AM调制');
axis([0.0225,0.0275,-4,4]);
xlabel('时间/s');
ylabel('幅度');

%% 信号经过高斯白噪声信道
tz=awgn(AM,20);             % 信号ask2中加入白噪声，信噪比为SNR=20dB
figure(2);                  % 绘制第2幅图
subplot(511);               % 窗口分割成2*1的，当前是第1个子图 
plot(t,tz,'LineWidth',2);   % 绘制2ASK信号加入白噪声的波形
axis([0,0.1,-4.5,4.5]);  % 坐标范围设置
title('通过高斯白噪声信道后的信号');% 标题
xlabel('时间/s');           % x轴标签
ylabel('幅度');             % y轴标签


% %% 保存到txt
% tz = round(tz.*2048/5 + 2048);
% fid = fopen('rom.txt','wt');
% fprintf(fid,'%x\n',tz(812500*1.8:1:812500*1.8+1625000));      %\n 换行
% fclose(fid);
%% 解调部分
tz=abs(tz);                 % 包络检波，全波整流
subplot(512)                % 窗口分割成2*1的，当前是第2个子图
plot(t,tz,'LineWidth',2);
axis([0,0.1,-0.5,4]);% 设置坐标范围
title('包络检波后的信号');
xlabel('时间/s');           % x轴标签
ylabel('幅度');             % y轴标签

% 低通滤波器设计
fp=2*1000;                    % 低通滤波器截止频率，乘以2是因为下面要将模拟频率转换成数字频率wp=Rb/(Fs/2)
b=fir1(30, fp/Fs, boxcar(31));% 生成fir滤波器系统函数中分子多项式的系数
% fir1函数三个参数分别是阶数，数字截止频率，滤波器类型
% 这里是生成了30阶(31个抽头系数)的矩形窗滤波器
[h,w]=freqz(b, 1,512);      % 生成fir滤波器的频率响应
% freqz函数的三个参数分别是滤波器系统函数的分子多项式的系数，分母多项式的系数(fir滤波器分母系数为1)和采样点数(默认)512
lvbo=fftfilt(b,tz);         % 对信号进行滤波，tz是等待滤波的信号，b是fir滤波器的系统函数的分子多项式系数

%{
 figure(3);                  % 绘制第3幅图  
subplot(311);               % 窗口分割成3*1的，当前是第1个子图 
plot(w/pi*Fs/2,20*log(abs(h)),'LineWidth',2); % 绘制滤波器的幅频响应
axis([0,10000000,-150,10]);  % 设置坐标范围
title('低通滤波器的频谱');  % 标题
xlabel('频率/Hz');          % x轴标签
ylabel('幅度/dB');          % y轴标签 
%}


subplot(513)                % 窗口分割成3*1的，当前是第2个子图 
plot(t,lvbo,'LineWidth',2); % 绘制经过低通滤波器后的信号
axis([0,0.1,-0.5,4]);  % 设置坐标范围
title('经过低通滤波器后的信号');% 标题
xlabel('时间/s');           % x轴标签
ylabel('幅度');             % y轴标签

% 第二个低通滤波器
lvbo_low=lvbo(1:1625:length(lvbo));
fp_1=2*10000;
b_1=fir1(30, fp_1/40000, boxcar(31));
[h_1,w_1]=freqz(b_1, 1,512);
lvbo_1=fftfilt(b_1,lvbo_low);
subplot(514)
plot(t_low,lvbo_1,'LineWidth',2);
axis([0,0.1,-0.5,2]);
title('经过第二个低通滤波器后的信号');
xlabel('时间/s');
ylabel('幅度');

% 高通滤波器设计
[b, a] = butter(7, 10000/(40000/2), 'high');
lvbo_2= filter(b, a, lvbo_low);
subplot(515)
plot(t_low,lvbo_2,'LineWidth',2);
axis([0,0.1,-1,1]);
title('经过高通滤波器后的信号');
xlabel('时间/s');
ylabel('幅度');

