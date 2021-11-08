clear all
close all
clf

p_term_coeff_unscaled = 0.9; % keep between 0 and 1, NON-INCLUSIVE
blocktime_target = 30; %seconds
p_term_coeff = p_term_coeff_unscaled / blocktime_target;
blocktime_logrange = 1;

max_target = hex2dec('FFFF0000000000000000000000000000000000000000000000000000');
blocktime = logspace(log10(blocktime_target)-blocktime_logrange,log10(blocktime_target)+blocktime_logrange,121);
current_diff = logspace(log10(0.0000001*max_target),log10(0.9999999*max_target),201); % to deal with roundoff errors
limiter_monitor = zeros(length(blocktime),length(current_diff));

for i1 = 1:length(blocktime)
  for i2 = 1:length(current_diff)
    current_target(i2) = max_target - current_diff(i2);
    p_term(i1) = (blocktime_target - blocktime(i1)) * p_term_coeff;
    %p_term(i1) = (blocktime(i1) - blocktime_target) * p_term_coeff;
    effective_diff(i2) = max_target - current_diff(i2);
    %change(i1,i2) = ceil(effective_diff(i2) * p_term(i1));
    change(i1,i2) = effective_diff(i2) * p_term(i1);
    new_diff(i1,i2) = change(i1,i2) + current_diff(i2);
    
    if(new_diff(i1,i2) < min(current_diff)) % to deal with roundoff errors
      limiter_monitor(i1,i2) = 1;
      new_diff(i1,i2) = min(current_diff);
    elseif(new_diff(i1,i2) > max(current_diff)) % to deal with roundoff errors
      limiter_monitor(i1,i2) = -1;
      new_diff(i1,i2) = max(current_diff);
    endif
    
    
    new_target(i1,i2) = round(max_target - new_diff(i1,i2));
    diff_percent_change(i1,i2) = (new_diff(i1,i2)-current_diff(i2))/current_diff(i2);
    target_ratio(i1,i2) = new_target(i1,i2) / current_target(i2);
    predicted_new_block_time(i1,i2) = blocktime(i1) / target_ratio(i1,i2);
    
    if(abs(predicted_new_block_time(i1,i2) - blocktime_target) > abs(blocktime(i1) - blocktime_target))
      warning("blocktime not improved! blocktime: %d, current diff: %d", blocktime(i1), current_diff(i2))
    endif
    
    improvement_ratio(i1,i2) = abs((predicted_new_block_time(i1,i2) - blocktime_target)) / abs((blocktime(i1) - blocktime_target+eps));
    blocktime_mat(i1,i2) = blocktime(i1);
  endfor
endfor
printf("Done calculating, starting plot\n");

figure(1)

%subplot(1,2,1)
h = gca;
surf(blocktime, current_diff*10^-40, improvement_ratio')
title("Improvement Ratio, anything less than 1 is an improvement!")
xlabel('blocktime (seconds)')
ylabel('current diff * 10^-40')
%set(h,'zscale','log')

figure(2)
%subplot(1,2,2)
h = gca;
surf(blocktime, current_diff*10^-40, predicted_new_block_time')
title("Predicted New Block Time, with 30 seconds as the Target Blocktime")
xlabel('current blocktime (seconds)')
ylabel('current diff * 10^-40')
zlabel('new blocktime (seconds)');


