clear all;
graphics_toolkit('fltk')

blocktime = 100; %seconds, technically only affects resolution in this model
ss_growth = 0.08; %steady-state supply growth per year
period_of_interest = .1; %years, the period which is modelled & plotted

##target_miners = 5000; %miners, target number of solo miners to ensure security
##init_miners = 10;
##solo_miner_hr = 10000; %h/s, average solo miner hashrate

%ratio_of_target is given as "actual/target"
function out = RC_Growth(in, ratio_of_target) 
  out = in * (1 - e^(-ratio_of_target));
endfunction

function log_rate = Log_Growth(block_height, block_time)
  global log_scalar = 100000; %scales logarithmic rate linearly
  global log_stretch = 10000; %stretches logarithmic rate over time 
  log_rate = log_scalar * 1/(1 + block_time*block_height/log_stretch);
endfunction

function target_ratio = Miner_Check(block_height, block_time)
  global time_to_security = 0.1; %years, time until target_miners is reached.
  global seconds_per_year = 365 * 24 * 60 * 60; 
  target_ratio = block_height / (time_to_security * seconds_per_year / block_time);
endfunction

n_blocks = round(period_of_interest * 365 * 24 * 60 * 60 / blocktime);
ss_block_growth = ss_growth / (365 * 24 * 60 * 60) * blocktime;
printf("n_blocks: %i\n", n_blocks);
reward_mat = zeros(3, n_blocks);

for i = 1:n_blocks
  reward_mat(1,i) = i * blocktime/60/64/24; %days
  reward_mat(2,i) = Log_Growth(i, blocktime); %base logarithmic supply
  reward_mat(3,i) = RC_Growth(reward_mat(2,i), Miner_Check(i, blocktime)); %RC curving
  if(i>1)
    reward_mat(4,i) = reward_mat(4,i-1) + reward_mat(2,i); %log integration
    reward_mat(5,i) = reward_mat(5,i-1) + reward_mat(3,i); %RC integration
    %compounding mint steady state increase
    reward_mat(6,i) = (ss_block_growth * reward_mat(8,i-1)) + reward_mat(2,i-1);
    reward_mat(7,i) = (ss_block_growth * reward_mat(9,i-1)) + reward_mat(3,i-1);
    %compounding supply steady state increase
    reward_mat(8,i) = reward_mat(8,i-1) + reward_mat(6,i-1);
    reward_mat(9,i) = reward_mat(9,i-1) + reward_mat(7,i-1);;
    
  else
    reward_mat(4,i) = 0;
    reward_mat(5,i) = 0;
    reward_mat(6,i) = reward_mat(2,i);
    reward_mat(7,i) = reward_mat(3,i);
    reward_mat(8,i) = 0;
    reward_mat(9,i) = 0;
  end
  
  printf("\r%i", i)
end

close all;
figure(1);
subplot(2,1,1);
plot(reward_mat(1,:), reward_mat(2,:), "linewidth", 2, reward_mat(1,:), reward_mat(3,:), "linewidth", 1.5); hold on;
plot(reward_mat(1,:), reward_mat(6,:), "linewidth", 1.5, reward_mat(1,:), reward_mat(7,:), "linewidth", 1.5);
ylim([0 2.5*max(reward_mat(7,:))])
xlabel("days since launch"); ylabel("reward size (Jengascoin)");
legend("Log rate", "RC conditioned", "Log rate+SS", "RC cond.+SS");

subplot(2,1,2); 
plot(reward_mat(1,:), reward_mat(4,:), "linewidth", 1.5, reward_mat(1,:), reward_mat(5,:), "linewidth", 1.5); hold on;
plot(reward_mat(1,:), reward_mat(8,:), "linewidth", 1.5, reward_mat(1,:), reward_mat(9,:), "linewidth", 1.5);
xlabel("days since launch"); ylabel("total supply (Jengascoin)");
legend("Log supply", "RC cond. supply", "Log supply+SS", "RC cond. supply+SS");
