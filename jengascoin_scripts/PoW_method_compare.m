## Copyright (C) 2021 darpo
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.

## -*- texinfo -*-
## @deftypefn {} {@var{retval} =} PoW_method_compare (@var{input1}, @var{input2})
##
## @seealso{}
## @end deftypefn

## Author: darpo <darpo@SMALLSAT>
## Created: 2021-09-24

function octave_value_list = PoW_method_compare (h_max, gpu_hashrate, gpu_xo_num, gpu_power, block_time, blocks_per_epoch, phase_1_blocks)
  
 %intermediate vars
 h_xo = gpu_hashrate * gpu_xo_num; %Crossover hashrate, when going from lin to log
 p_xo = gpu_xo_num * gpu_power; %Network power consumption at crossover
 p_h_slope = gpu_power/gpu_hashrate;%linear slope of power to hashrate 
 epoch_time = block_time * blocks_per_epoch
 phase_1_duty_cycle = block_time * phase_1_blocks / epoch_time
 
 %outputs
 h = linspace(0,h_max,10001);
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
 clf
 axes('fontsize',14)
 semilogy(h,y_lin,'linewidth',2,h,y_log,'linewidth',2,h,y_log_plus_phase_1,'linewidth',2)
 title('Power vs Hashrate for Proof-of-Work Consensus Algorithms','fontsize',14)
 xlim([0,h_max])
 ylim([0,max(y_lin)])
 xlabel('Hashrate [Hash/s]','fontsize',16)
 ylabel('Power Consumption [Watts]','fontsize',16)
 h = legend({'Traditional PoW', 'intermediate function', 'Multistage PoW'});
 legend(h,"Location","Northwest","fontsize",16)
 
 %output printing
 printf("\n Multistage PoW vs Traditional PoW:\n")
 phase_1_duty_cycle
 power_ratio = max(y_log_plus_phase_1)/max(y_lin)
 traditional_PoW_max_power = max(y_lin)
 multistage_PoW_max_power = max(y_log_plus_phase_1)
 printf(" Estimates ignoring pool mining:\n")
 number_of_gpus_phase1 = round(max(y_lin)/gpu_power)
 number_of_gpus_phase3 = round(max(y_log)/gpu_power)
 number_of_gpus_average = round(max(y_log_plus_phase_1)/gpu_power)

endfunction
