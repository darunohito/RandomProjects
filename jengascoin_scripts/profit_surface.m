% This script models the "surface" created by the relationship between hashrate, wallet balance, and profit for a given single wallet miner. This applies to all miners, but larger mining operations will likely use multiple wallets.

% This surface is not a pure Proof-of-Work reward function. This reflects an emerging consensus algorithm which is an amalgamation of many consensus algorithms and a modified reward function. The details will not be explored here, beyond the ante, raffle, and reward functions. Additionally, wallet-shuffling (Sybil attack) exploitation methods are not yet explored here.

%   The ante (or burn) function is a required deposit to enter the drawing, and follows an inverse power relationship to wallet balance.
%   The raffle (or lottery) is a true-random sample of all mining addresses which ante the requisite currency to enter the drawing.
%   The reward function gives logarithmic returns to an address which solves multiple hashes in a given epoch, up to a given limit.

% author: Daru

clf
clear all


%% INPUT PARAMETERS %%
    % Adjust the inputs below:
burn_coefficient = 3; % enter any positive number. Higher number is a larger ante/burn.
burn_power = -.5; % enter any negative number.  
raffle_win_ratio = 0.1; % enter a positive number no greater than 1. (0 < number <= 1)
reward_coefficient = 1; % enter any positive number. Higher number scales rewards.
reward_cutoff = 4; % enter a positive whole number. Max number of accepted hashes in a given epoch.

    % Optional adjustments:
plot_granularity = 251; % Enter a whole number greater than or equal to 10. Determines number of x and y points.
color_granularity = 401; % Enter a whole number greater than or equal to 5. Determines number of color steps.
plot_balance_range_multiplier = 1000; % enter any positive number. Scales balance axis. Recommend at least 2.
plot_extension_multiplier = 1; % will accept any number from between 0 and +inf, but is intended to give a natural plot scale, dependent on the reward_cutoff and balance_cutoff. 1, 1.2, 2 are all reasonable entries.


%% INPUT CHECKS %%
    % Don't touch!
if (burn_coefficient <= 0) error ("burn_coefficient invalid"); endif
if (burn_power >= 0) error ("burn_power invalid"); endif
if (raffle_win_ratio <= 0 || raffle_win_ratio > 1) error("raffle_win_ratio invalid"); endif
if (reward_coefficient < 0) error ("reward_coefficient invalid"); endif
if (reward_cutoff < 1 || mod(reward_cutoff,1)) error("reward_cutoff invalid"); endif
if (plot_granularity < 10 || mod(plot_granularity,1)) error("plot_granularity invalid"); endif
if (color_granularity < 5 || mod(color_granularity,1)) error("plot_granularity invalid"); endif
if (plot_balance_range_multiplier <= 0) error("plot_balance_range_multiplier invalid"); endif
if (plot_extension_multiplier <= -1) error("plot_extension_multiplier invalid"); endif


%% INITIALIZE DATA STRUCTURES %%
    % Don't touch!
balance_cutoff = sqrt(burn_coefficient) % minimum number of coins in a wallet to mine.

% "x" == "reward_count", which is proportional to hashrate
x_range = [0 reward_cutoff] * plot_extension_multiplier;
x = linspace(x_range(1),x_range(2),plot_granularity);

% "y" == "wallet_balance", in coins
y_range = [0 balance_cutoff*plot_balance_range_multiplier] * plot_extension_multiplier;
y = linspace(y_range(1),y_range(2),plot_granularity);

% "z" == "profit", in terms of coins
z = zeros(2,length(x),length(y));


%% MATH %%
    % Don't touch!
for x_i = 1:length(x)
  for y_i = 1:length(y)
    if(y(y_i) < balance_cutoff)
      z(1,y_i,x_i) = 0;
      z(2,y_i,x_i) = 0;
    elseif(x(x_i) > reward_cutoff)
      z(1,y_i,x_i) = -burn_coefficient*realpow(y(y_i),burn_power) + reward_coefficient*log(reward_cutoff)* raffle_win_ratio;
      z(2,y_i,x_i) = z(1,y_i,x_i)
    else
      z(1,y_i,x_i) = -burn_coefficient*realpow(y(y_i),burn_power) + reward_coefficient*log(x(x_i))* raffle_win_ratio;
      z(2,y_i,x_i) = -burn_coefficient*realpow(y(y_i),burn_power) + reward_coefficient*log(round(x(x_i)))* raffle_win_ratio;
    endif
  endfor
endfor

%% PLOT %% 
figure(1)
for i1 = 1:2
  subplot(1,2,i1)
  fig = surf(x,y,squeeze(z(i1,:,:)));
  xlabel("Rewards Received\n(blocks, per epoch)");
  ylabel("Wallet Balance (coins)");
  zlabel("Profit (coins, per epoch)")

  set(fig,'facealpha',0.8)
  set(fig,'edgecolor','none')

  z_range = zlim;
  if(z_range(1) < 0 && z_range(2) > 0)
    zero_pos = -z_range(1)/(max(max(z(i1,:,:)))-z_range(1));
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
    cmap(zero_i-1,:) = [0 0 0];
    colormap(cmap)
  else
    colormap("default")
  endif
  grid on
  colorbar
endfor
