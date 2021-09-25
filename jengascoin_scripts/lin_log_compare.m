 clear all
 close all
 
 %input vars:
 h_max = 5 * 10^12; %Hash/sec, expected maximum hashrate on network (or test value)
 gpu_hashrate = 10^6; %Hash/sec, predicted average GPU hashrate
 gpu_xo_num = 500; %GPUs at log crossover, number of active mining GPUs before log crossover
 gpu_power = 200; %Watts, GPU power consumption estimate
 block_time = 15; %seconds
 blocks_per_epoch = 100; %blocks
 phase_1_blocks = 1; %number of blocks for phase-1 buy-in process
 
 %intermediate vars
 h_xo = gpu_hashrate * gpu_xo_num; %Crossover hashrate, when going from lin to log
 p_xo = gpu_xo_num * gpu_power; %Network power consumption at crossover
 p_h_slope = gpu_power/gpu_hashrate;%linear slope of power to hashrate 
 epoch_time = block_time * blocks_per_epoch
 phase_1_duty_cycle = block_time * phase_1_blocks / epoch_time
 
 %outputs
 h = linspace(0,h_max,1001);
 y_lin = p_h_slope * h;
 y_phase_1 = y_lin * phase_1_duty_cycle;
 for i1 = 1:length(h)
   if h(i1) < h_xo
     y_log(i1) = y_lin(i1);
     y_log_plus_phase_1(i1) = y_lin(i1);
   elseif h(i1) >= h_xo
     y_log(i1) = p_h_slope * h_xo * log(h(i1)/h_xo) + p_xo;
     y_log_plus_phase_1(i1) = y_log(i1) + y_phase_1(i1);
   endif
 endfor
 
 %plot
 figure(1)
 axes('fontsize',14)
 plot(h,y_lin,'linewidth',2,h,y_log,'linewidth',2,h,y_log_plus_phase_1,'linewidth',2)
 title('Power vs Hashrate for Proof-of-Work Consensus Algorithms','fontsize',14)
 ylim([0,max(y_lin)])
 xlabel('Hashrate [Hash/s]','fontsize',16)
 ylabel('Power Consumption [Watts]','fontsize',16)
 h = legend({'Traditional PoW', 'intermediate function', 'Multistage PoW'});
 legend(h,"Location","Northwest","fontsize",16)
 
 %output printing
 printf("\n Multistage PoW / Traditional PoW:\n")
 power_ratio = max(y_log_plus_phase_1)/max(y_lin)
 printf(" Estimates ignoring pool mining:\n")
 number_of_gpus_phase1 = round(max(y_lin)/gpu_power)
 number_of_gpus_phase3 = round(max(y_log)/gpu_power)
 number_of_gpus_average = round(max(y_log_plus_phase_1)/gpu_power)