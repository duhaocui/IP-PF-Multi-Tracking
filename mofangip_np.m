clear all;
close all;
clc;
format long; 

%% ======The initialization of the basic parameters=====
Num_Cell_x=50;
Num_Cell_y=50;
Total_time=100;     % the number of total integrated frames
Total_time_data=100;
Time_point=100;
T_step=1;          % The size of the time cell:Time_step
q1=0.00015;          % q1,q2 the level of process noise in target motion
q1_1=0.00015;

%% ---------- initial distribution of target state 
delta_p=0.05;  % the stardard deviation of the inital distribution of position
delta_v=0.01;   % the stardard deviation of the inital distribution of velocity
new_velocity_Variance=delta_v^2;             % standard deviation 0.1;
% q2=2;                  % q2 the measurement noise
          
%% ---------- transition matrix          
F = [1 T_step 0   0; 
    0    1    0   0; 
    0    0    1   T_step; 
    0    0    0   1];            
           
Q=q1_1*[T_step^3/3  T_step^2/2  0           0 ;
        T_step^2/2  T_step      0           0 ;
        0             0         T_step^3/3  T_step^2/2;
        0             0         T_step^2/2  T_step];                         % ProcessNoise covariance matrix            
%% ---------- Rao-balckwellision parameters
Q_l=q1*[T_step,0;0,T_step];
Q_n=q1*[T_step^3/3,0;0,T_step^3/3];
Q_ln=q1*[T_step^2/2,0;0,T_step^2/2];
A_1_t=eye(2)-Q_ln/(Q_n)*T_step;
Q_1_l=Q_l-(Q_ln.')*(inv(Q_n))*Q_ln;

Target_number=1;
load('T11_20111211_v8.mat')
xn=zeros(4,100);
h=zeros(50,50,Total_time); %扩展目标模型
lx=1;
ly=1;
dx=1;
dy=1;

for (i=1:100)
    xn(:,i)=x(:,i);
end

x_dis=ceil(xn);
initx(:,1)=xn(:,1);

Np_T=[10,30,70,110,150,200];
%Np_T=[30];
SNR_T=[10];
repeati=20;
SNR_num=length(SNR_T);
Np_num=length(Np_T);
E_target_state_MC=zeros(7,Total_time,Target_number,repeati,SNR_num,Np_num);
single_run_time=zeros(Total_time,repeati,SNR_num,Np_num);

for Np_i=1:Np_num
 Np=Np_T(Np_i);
 for SNR_i=1:SNR_num
  SNR_dB=SNR_T(SNR_i);
  for MC_i=1:repeati  %蒙特卡罗次数
             display(['NP=',num2str(Np),'; SNR=',num2str(SNR_dB),'; MC=',num2str(MC_i)]);           
            %% ============== Generate measurements ================  

            %% --------- Generate the measurement noise --------
            Frame_data=zeros(Num_Cell_y,Num_Cell_x,Total_time); % Denote the Intensity of the target in the resolution cell.
            Sigma_noise=1;

            %% ---- Rayleigh distribution   %瑞利分布的噪声平面
            Noise_data=raylrnd(Sigma_noise,Num_Cell_y,Num_Cell_x*Total_time);  %Num_Cell_y,Num_Cell_x*Total_time表示范围，且包含Total_time个时刻。这里一个平面是50*50,100个时刻就是50*5000
            for t_m=1:Total_time
                Frame_data(:,:,t_m)=Noise_data(:,Num_Cell_x*(t_m-1)+1:Num_Cell_x*t_m);  %产生数据平面 （Frame_data有时间维度，而Noise_data是把100个时刻的噪声平面保存在一个二位数组内）
            end       
            %% ---- Add the target signal ----
            Signal_amptitude=(10.^(SNR_dB./10)).^0.5;
            for t=1:Total_time 
                All_T_P=zeros(2,Target_number);
                Lable_num_record=zeros(1,Target_number);
                for n=1:Target_number
                    All_T_P(:,n)=x_dis([1,3],t+Total_time*(n-1));  %x_dis为离散后的目标状态，里面保存了Target_number*Total_time个，这里是11*100，是每个时刻的11个目标的状态；这样访问后， All_T_P里保存的就是当前时刻的11个目标的状态
                end
                for n=1:Target_number
                    num_label_temp=sum(abs(All_T_P-repmat(All_T_P(:,n),1,Target_number)),1);  %repmat(All_T_P(:,n),1,Target_number)是把第n个目标的状态扩展到Target_number个，也就是repmat(All_T_P(:,n),1,Target_number)生成的是11个一样的状态（都是第n个目标的状态）
                    Total_tn=length(find(num_label_temp==0));
                    Lable_num_record(num_label_temp==0)=Total_tn;
                end

                for  n=1:Target_number                   
                    Frame_data( x_dis(3,t+Total_time_data*(n-1)),x_dis(1,t+Total_time_data*(n-1)),t)=raylrnd(sqrt(Sigma_noise+Lable_num_record(1,n).*Signal_amptitude^2),1);
                    x_c(n*3,t)=Frame_data( x_dis(1,t+Total_time_data*(n-1)),x_dis(3,t+Total_time_data*(n-1)),t);
                end  
                
            end  %加上目标信息
                    
                %% ============== PF implementation ================   
            Pre_T_particle=zeros(7,Total_time,Target_number,Np);            % Pre_track particles
            Pre_T_particle_ori=zeros(7,Total_time,Target_number,Np);        % Pre_track particles
            Pre_T_life_index=zeros(Target_number,Np);                   % life length of the pre-tracks
            Pre_T_life_quality=zeros(Target_number,Np);                 % quality of life length of the pre-tracks
            Pre_weight0=zeros(Np,Total_time);               % Particles weights of Pre-track PF
            Pre_weight=zeros(Np,Total_time);                % Normolized Particles weights
            Pre_w_likehood_all=zeros(Np,Total_time);        % likehood part of the pre-PF weights
            Pre_track_bias=zeros(Np,Total_time);            % weight bias part of the pre-PF weights

   
            for t = 1:Time_point
                singerun_start=tic;                
                %% --------------- detection procedure ----------------    
                Detection_frame=Frame_data(:,:,t);    %把当前时刻的数据平面信息保存到不带时间维度的二位数组方便调用
                Pre_track_Z=zeros(Target_number,Np);
                Partition_likehood=zeros(Target_number,Np);

                if t==1   
                    %disp(['t==1']);
                    Num_n_target=Target_number; % number of the birth pre-tracks     航迹数就是目标的个数
                    index_x=initx(1,1:Target_number);
                    index_y=initx(3,1:Target_number);
                    index_vx=initx(2,1:Target_number);
                    index_vy=initx(4,1:Target_number);   %initx保存了11个目标的初始状态
                    % -------generate the new partitions of particles
                    %--------generate position based the detection measurements
                    position_x_p=repmat(index_x,Np,1)+delta_p*randn(Np,Num_n_target);
                    position_y_p=repmat(index_y,Np,1)+delta_p*randn(Np,Num_n_target);  
                    %--------generate velocity based on the detections
                    velocity_x_p=repmat((index_vx),Np,1);
                    velocity_y_p=repmat((index_vy),Np,1);  %已知先验信息产生粒子
                    %--------generate velocity variance
                    velocity_p_kk1=new_velocity_Variance.*ones(Np,2*Num_n_target);

                    %--------new_pretrack=zeros(4,Num_n_target,Np);
                    Pre_T_life_index=ones(Num_n_target,Np);
                    Pre_T_life_quality=ones(Num_n_target,Np);
                    for i=1:Np
                        Pre_T_particle(1:6,t,:,i)=[position_x_p(i,:);velocity_x_p(i,:);velocity_p_kk1(i,1:Num_n_target);position_y_p(i,:);velocity_y_p(i,:);velocity_p_kk1(i,1:Num_n_target)];
                    end   %保存粒子的各种信息，位置，速度，第三个是速度衰减？
                    Pre_T_particle(7,t,:,:)=1;

                    particle_likehood_after_baise=ones(Target_number,Np);   %初始权值都为1？
            %      figure (3)
            %       hold on;
            %        for (jj=1:Np)
            %        plot(Pre_T_particle(1,1,1,jj),Pre_T_particle(4,1,1,jj),'b.','markersize',5);
            %        plot(Pre_T_particle(1,1,2,jj),Pre_T_particle(4,1,2,jj),'r.','markersize',5);
            %        end
            %        axis([0 50 0 50]);
                else

                    %% --------------- evolution of the pre-tracks ----------------
                    %% -----------independent partition particle filter------------
                    Pre_track_Z=zeros(Target_number,Np);
                    Partition_likehood=zeros(Target_number,Np);
                    particle_likehood_after_baise=zeros(Target_number,Np);

                    for i=1:Target_number% 1%
                        for j=1:Np % 6%                  
                            %% === Rao-blackwellisation 
                            Pre_T_particle(1:6,t,i,j)= sample_RB( Pre_T_particle(1:6,t-1,i,j),T_step,Q_l,Q_n,Q_ln,A_1_t,Q_1_l,q1 ); %产生新粒子  Pre_T_particle(1:6,t-1,i,j)是上一个时刻的粒子
                            %%       %Pre_T_particle(1:6,t,i,j)表示t时刻第i个目标第j个粒子的6个信息
                            Pre_T_life_index(i,j)=Pre_T_life_index(i,j)+1; 
                            Z_x_index=ceil(Pre_T_particle(1,t,i,j));
                            Z_y_index=ceil(Pre_T_particle(4,t,i,j));
                            if Z_x_index<=Num_Cell_x && Z_x_index>0 && Z_y_index<=Num_Cell_y && Z_y_index>0   %判断是否在平面范围内                   
                                Pre_track_Z(i,j)=Detection_frame(Z_y_index,Z_x_index);
                                Pre_T_life_quality(i,j)=Pre_T_life_quality(i,j)+Detection_frame(Z_y_index,Z_x_index);
                                Pre_T_particle(7,t,i,j)=Detection_frame(Z_y_index,Z_x_index);
                                %% Gaussian likelihood ratio
                                %Partition_likehood(i,j)=exp(0.5*(2*Detection_frame(Z_y_index,Z_x_index)*Signal_amptitude-Signal_amptitude^2));
                                %% Rayleigh likelihood ratio or just likelihood
                                Partition_likehood(i,j)=raylpdf(Detection_frame(Z_y_index,Z_x_index),sqrt(Sigma_noise+Signal_amptitude^2))./raylpdf(Detection_frame(Z_y_index,Z_x_index),Sigma_noise);
                            else
                                Partition_likehood(i,j)=0;
                            end
                        end
                        Partition_likehood(i,:)=Partition_likehood(i,:)./sum(Partition_likehood(i,:));  %归一化
                        %% === sample index funciton
                        [index_sample]=Sample_index(Partition_likehood(i,:));   %重采样选择的粒子的编号
                        Pre_T_particle(:,:,i,:)=Pre_T_particle(:,:,i,index_sample);   %复制所选粒子
                        Pre_T_life_quality(i,:)=Pre_T_life_quality(i,index_sample);   %保存对应的权值？
                        %% === retain the bias of sample: the likehood 
                        particle_likehood_after_baise(i,:)=Partition_likehood(i,index_sample);
                    end       
                end

                %% ---------- weights calculate of the Pre-track PF --------------- 
                cc=zeros(Np,1);
                for pre_Np_i=1:Np
                    %% ----sensor model: likelihood calculation                    
                    position_in=ceil(squeeze(Pre_T_particle([1,4],t,:,pre_Np_i)));
                    [ Pre_w_likehood_all(pre_Np_i,t)] = likelihood_calc( Detection_frame,position_in,Signal_amptitude);
                    %% -----Independent PF weights biase          
                    Pre_track_bias(pre_Np_i,t)=prod(particle_likehood_after_baise(:,pre_Np_i));
                    %% ------calculate the weights
                    Pre_weight0(pre_Np_i,t)= Pre_w_likehood_all(pre_Np_i,t)/Pre_track_bias(pre_Np_i,t);   
                end
                %% ------------- Normalize th Pre-weights -----------
                Pre_weight(:,t)=Pre_weight0(:,t)./sum(Pre_weight0(:,t));

                %% ------------ Resampling of the Pre-track PF ----------
                inIndex=1:Np;
                outIndex = deterministicR(inIndex,Pre_weight(:,t));
                Pre_T_particle_ori=Pre_T_particle;            % particles before resampling
                Pre_T_particle(:,:,:,:)=Pre_T_particle(:,:,:,outIndex);
                % Pre_T_life_index is not change during the resampling
                Pre_T_life_quality(:,:)=Pre_T_life_quality(:,outIndex); 
                
                %% ------------ time recording ----------
           %     single_run_time(t,MC_i,SNR_i,Np_i)=toc(singerun_start);%

%                 keyboard;
            end
            %% record the estimates
            E_target_state=zeros(7,Total_time,Target_number);
            for ii_t=1:Target_number
                E_target_state(:,:,ii_t)=mean(Pre_T_particle(:,:,ii_t,:),4);
            end
            E_target_state_MC(:,:,:,MC_i,SNR_i,Np_i)=E_target_state;
 end   
end
end


RMSE=zeros(1,Np_num);
R_MC=zeros(1,repeati);
for Np_i=1:Np_num
    for MC_i=1:repeati
        sum_1=0;
        sum_2=0;
        for t_i=1:Total_time
            e_x_1=E_target_state_MC(1,t_i,1,MC_i,1,Np_i);
            e_y_1=E_target_state_MC(4,t_i,1,MC_i,1,Np_i);
            x_1=xn(1,t_i);
            y_1=xn(3,t_i);
            dis_1=(e_x_1-x_1)^2+(e_y_1-y_1)^2;
            sum_1=sum_1+dis_1;
            
            
            sum=(sum_1);
        end
        R_MC(MC_i)=sqrt(sum/(Total_time));    
    end
    rsum=0;
    for i=1:repeati
        rsum=rsum+R_MC(i);
    end
    RMSE(Np_i)=rsum/repeati;
end

figure(20)
    hold on;
    grid on;
    plot(Np_T,RMSE,'+b-');
    xlim([0 200]);
    xlabel('number of particles');ylabel('RMSE');

%t=1;
%for SNR_i=1:SNR_num
%for MC_i=1:repeati
%figure(t);
% plot(E_target_state_MC(1,:,1,MC_i,SNR_i,1),E_target_state_MC(4,:,1,MC_i,SNR_i,1), 'y.-', 'markersize',5);
% hold on;
% plot(E_target_state_MC(1,:,2,MC_i,SNR_i,1),E_target_state_MC(4,:,2,MC_i,SNR_i,1), 'g.-', 'markersize',5);
% i=1:100;
% plot(xn(1,i),xn(3,i),'b.-', 'markersize',5);
% j=101:200;
% plot(xn(1,j),xn(3,j),'r.-', 'markersize',5);
% legend('跟踪1','跟踪2','目标1','目标2');
% xlabel('x方向/分辨单元');ylabel('y方向/分辨单元');
% axis([0 50 0 50]);
% t=t+1;
%end
%end

%figure(2);
%x=1:50;
%y=1:50;
%[X,Y]=meshgrid(x,y);
%surf(X,Y,Frame_data(x,y,1));
%xlabel('x方向/分辨单元');ylabel('y方向/分辨单元');
%axis([0 50 0 50 0 10]);