%% INPUT PARAMETERS %%
    % Adjust the inputs below:
##burn_coefficient = 1; % enter any positive number. Higher number is a larger ante/burn.
##burn_power = -2; % enter any negative number.  
##raffle_win_ratio = 0.2; % enter a positive number no greater than 1. (0 < number <= 1)
##reward_coefficient = 0.5; % enter any positive number. Higher number scales rewards.
##reward_cutoff = 5; % enter a positive whole number. Max number of accepted hashes in a given epoch.

close all
clear all

    % Optional adjustments:
plot_granularity = 31; % Enter a whole number greater than or equal to 10. Determines number of x and y points.
color_granularity = 51; % Enter a whole number greater than or equal to 5. Determines number of color steps.
plot_balance_range_multiplier = 5; % enter any positive number. Scales balance axis. Recommend at least 2.
plot_extension_multiplier = 1.2; % will accept any number from between 0 and +inf, but is intended to give a natural plot 

burn_coeff = [0.5,1];
burn_pow = [-1,-2];
raffle_ratio = [0.1,0.2];
reward_coeff = 0.5;
reward_cut = 5;

surf_count = length(burn_coeff)*length(burn_pow)*length(raffle_ratio)*length(reward_coeff)*length(reward_cut)
surf_i = 1;
figure(1);

for i1 = 1:length(burn_coeff)
  for i2 = 1:length(burn_pow)
    for i3 = 1:length(raffle_ratio)
      surf_i
      [x_out(:,i1,i2,i3),y_out(:,i1,i2,i3),z_out(:,:,i1,i2,i3)] = PoP_surface(burn_coeff(i1),burn_pow(i2),raffle_ratio(i3),reward_coeff,reward_cut, 0);
      subplot(2,4,surf_i);
      
      %% PLOT %% 
      mesh(x_out(:,i1,i2,i3),y_out(:,i1,i2,i3),z_out(:,:,i1,i2,i3));
      xlabel("Rewards Received\n(average per epoch)");
      ylabel("Wallet Balance (coins)");
      zlabel("Profit (coins,average per epoch)")

      z_range = zlim;
      if(z_range(1) < 0 && z_range(2) > 0)
        zero_pos = -z_range(1)/(z_range(2)-z_range(1));
      endif
      cmap = ones(color_granularity,3)/8;
      zero_i = round(color_granularity*zero_pos);
      for c_i = 1:zero_i
        cmap(c_i,1) = (zero_i - c_i) / (color_granularity * zero_pos);
        cmap(c_i,3) =  c_i / (color_granularity * zero_pos) / 2;
      endfor
      for c_i = zero_i:color_granularity
        cmap(c_i,2) = (c_i - zero_i) / (1 + color_granularity * (1-zero_pos));
        cmap(c_i,3) = (color_granularity - c_i) / (1 + color_granularity * (1-zero_pos)) / 2;
      endfor

      colormap(cmap)
      surf_i = surf_i + 1;
    endfor
  endfor
endfor



