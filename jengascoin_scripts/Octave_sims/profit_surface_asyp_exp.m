% This script models the "surface" created by the relationship between hashrate, wallet balance, and profit for a given single wallet miner. This applies to all miners, but larger mining operations will likely use multiple wallets.

% This surface is not a pure Proof-of-Work reward function. This reflects an emerging consensus algorithm which is an amalgamation of many consensus algorithms and a modified reward function. The details will not be explored here, beyond the ante, raffle, and reward functions. Additionally, wallet-shuffling (Sybil attack) exploitation methods are not yet explored here.

%   The ante (or burn) function is a required deposit to enter the drawing, and follows an inverse power relationship to wallet balance.
%   The raffle (or lottery) is a true-random sample of all mining addresses which ante the requisite currency to enter the drawing.
%   The reward function gives logarithmic returns to an address which solves multiple hashes in a given epoch, up to a given limit.

% author: Daru


clear all


%% INPUT PARAMETERS %%
    % Adjust the inputs below:
balance_of_min_burn = 10000; % enter any positive number. Indicates balance of minimum burn rate.
min_burn = -2; % enter any negative number, zero-inclusive. May scale with supply.
max_burn = -100; % enter a negative number lower than min_burn; 
raffle_win_ratio = 0.1; % enter a positive number no greater than 1. (0 < number <= 1)
reward_max = 120; % enter any positive number. Indicates maximum block reward total over an epoch.
reward_cutoff = 5; % enter a positive whole number. Max number of accepted hashes in a given epoch.
reward_charge_at_cutoff = 4; % enter a positive number <= 5. Multiple of charge time constant "Tau".

    % Optional adjustments:
plot_granularity = 51; % Enter a whole number greater than or equal to 10. Determines number of x and y points.
color_granularity = 51; % Enter a whole number greater than or equal to 5. Determines number of color steps.
plot_balance_range_multiplier = 1.25; % enter any positive number. Scales balance axis. Recommend between 0.25 and 1.5.
plot_extension_multiplier = 1; % will accept any number from between 0 and +inf, but is intended to give a natural plot scale, dependent on the reward_cutoff and balance_min. 1, 1.2, 2 are all reasonable entries.
animate_bool = 1; % 1 to animate, 0 to take single snapshot
animation_range = 2; % order of magnitude of independent variable movement (total) during animation.
num_animated_vars = 7; % number of variables to animate
animation_steps = 11; % *odd*, positive step number

% no touchy >:(
animation_vals = logspace(-animation_range/2, animation_range/2,animation_steps);
total_steps = 1 + animate_bool * num_animated_vars*(animation_steps*2-1)
step = 1;
animation_matrix = cell(num_animated_vars,animation_steps*2-1);
step_dir_vector = cos(linspace(0,2*pi(),(animation_steps*2-1)));
vars = [balance_of_min_burn min_burn max_burn raffle_win_ratio reward_max reward_cutoff reward_charge_at_cutoff];
for i1 = 1:length(step_dir_vector)
  if(step_dir_vector(i1) > 0) 
    step_dir_vector(i1) = 1;
  else 
    step_dir_vector(i1) = -1;
  endif
endfor

starting_index = round(animation_steps/2);
if (!animate_bool)
  num_animated_vars = 1;
  animation_steps = 1;
endif

    for i1 = 1:num_animated_vars
      i3 = starting_index;
      for i2 = 1:animation_steps*2-1
        tempvars = vars;
        tempvars(i1) = vars(i1) * animation_vals(i3);
        animation_matrix{i1,i2} = tempvars;
        
        
        if(i2 < (animation_steps*2-1))
          i3 = i3 + step_dir_vector(i2+1);
        else
          i3 = starting_index;
        endif
      endfor
    endfor



for i_vars = 1:num_animated_vars
  for i_steps = 1:animation_steps*2-1
    
    %% INPUT CHECKS %%
    % Don't touch!
if (animation_matrix{i_vars,i_steps}(1) <= 0) warning ("balance_of_min_burn invalid"); endif
if (animation_matrix{i_vars,i_steps}(2) > 0) warning ("min_burn invalid"); endif
if (animation_matrix{i_vars,i_steps}(3) > animation_matrix{i_vars,i_steps}(2)) warning ("max_burn invalid"); endif
if (animation_matrix{i_vars,i_steps}(4) <= 0 || raffle_win_ratio > 1) warning("raffle_win_ratio invalid"); endif
if (animation_matrix{i_vars,i_steps}(5) < 0) warning ("reward_max invalid"); endif
if (animation_matrix{i_vars,i_steps}(6) < 1 || mod(reward_cutoff,1)) warning("reward_cutoff invalid"); endif
if (animation_matrix{i_vars,i_steps}(7) < 0 || reward_charge_at_cutoff > 5) warning("reward_charge_at_cutoff invalid or unreasonable"); endif
if (plot_granularity < 10 || mod(plot_granularity,1)) warning("plot_granularity invalid"); endif
if (color_granularity < 5 || mod(color_granularity,1)) warning("plot_granularity invalid"); endif
if (plot_balance_range_multiplier <= 0) warning("plot_balance_range_multiplier invalid"); endif
if (plot_extension_multiplier <= -1) warning("plot_extension_multiplier invalid"); endif



%% INITIALIZE DATA STRUCTURES %%
    % Don't touch!
balance_min = -animation_matrix{i_vars,i_steps}(3); % minimum number of coins in a wallet to mine.
balance_tau = animation_matrix{i_vars,i_steps}(1) / 5; % five-tau settling balance
reward_tau = animation_matrix{i_vars,i_steps}(6) / animation_matrix{i_vars,i_steps}(7); % equivalent to RC time constant

% "x" == "reward_count", which is near-proportional to hashrate
x_range = [0 animation_matrix{i_vars,i_steps}(6)] * plot_extension_multiplier;
x = linspace(x_range(1),x_range(2),plot_granularity);

% "y" == "wallet_balance", in coins
y_range = [0 animation_matrix{i_vars,i_steps}(1)*plot_balance_range_multiplier] * plot_extension_multiplier;
y = linspace(y_range(1),y_range(2),plot_granularity);

% "z" == "profit", in terms of coins
z = zeros(2,length(x),length(y));


%% MATH %%
    % Don't touch!
for x_i = 1:length(x)
  for y_i = 1:length(y)
    if(y(y_i) < balance_min)
      z(1,y_i,x_i) = 0;
      z(2,y_i,x_i) = 0;
    elseif(x(x_i) > animation_matrix{i_vars,i_steps}(6))
      %z(1,y_i,x_i) = -burn_coefficient*realpow(y(y_i),burn_power) + animation_matrix{i_vars,i_steps}(5)*log(animation_matrix{i_vars,i_steps}(6))* animation_matrix{i_vars,i_steps}(4);
      z(1,y_i,x_i) = animation_matrix{i_vars,i_steps}(2) +(animation_matrix{i_vars,i_steps}(3)-animation_matrix{i_vars,i_steps}(2))*e^(-y(y_i)/balance_tau) + animation_matrix{i_vars,i_steps}(5)*animation_matrix{i_vars,i_steps}(4);
      z(2,y_i,x_i) = z(1,y_i,x_i)
    else
      z(1,y_i,x_i) = animation_matrix{i_vars,i_steps}(2) + (animation_matrix{i_vars,i_steps}(3)-animation_matrix{i_vars,i_steps}(2))*e^(-y(y_i)/balance_tau) + animation_matrix{i_vars,i_steps}(5)*(1-e^(-x(x_i)/reward_tau))*animation_matrix{i_vars,i_steps}(4);
      z(2,y_i,x_i) = animation_matrix{i_vars,i_steps}(2) + (animation_matrix{i_vars,i_steps}(3)-animation_matrix{i_vars,i_steps}(2))*e^(-y(y_i)/balance_tau) + + animation_matrix{i_vars,i_steps}(5)*(1-e^(round(-x(x_i))/reward_tau))* animation_matrix{i_vars,i_steps}(4);
    endif
  endfor
endfor

%% PLOT %% 
figure(1)
if(animate_bool)
  numplots = 3;
else
  numplots = 2;
endif


for i1 = 1:2
  subplot(1,numplots,i1)
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
if animate_bool
  plot_vars = [animation_matrix{i_vars,i_steps}(1) abs(animation_matrix{i_vars,i_steps}(2)) abs(animation_matrix{i_vars,i_steps}(3)) animation_matrix{i_vars,i_steps}(4) animation_matrix{i_vars,i_steps}(5) animation_matrix{i_vars,i_steps}(6) animation_matrix{i_vars,i_steps}(7)];
  var_names = {"BAL\nMIN\nBURN" "-MIN\nBURN" "-MAX\nBURN" "WIN\nRATIO" "REWARD\nMAX" "REWARD\nCUT" "CUTOFF\nCHARGE"};
  
  subplot(1,numplots,3)
  hbar = bar(plot_vars);
  set(gca, 'yscale', 'log',"xticklabel",var_names)
  grid on
endif
drawnow

##animation_matrix{i_vars,i_steps}(1) = 10000; % enter any positive number. Indicates balance of minimum burn rate.
##animation_matrix{i_vars,i_steps}(2) = 0; % enter any positive number, zero-inclusive. May scale with supply.
##animation_matrix{i_vars,i_steps}(3) = -100; % enter any negative number.  
##animation_matrix{i_vars,i_steps}(4) = 0.1; % enter a positive number no greater than 1. (0 < number <= 1)
##animation_matrix{i_vars,i_steps}(5) = 100; % enter any positive number. Indicates maximum block reward total over an epoch.
##animation_matrix{i_vars,i_steps}(6) = 5; % enter a positive whole number. Max number of accepted hashes in a given epoch.
##animation_matrix{i_vars,i_steps}(7) = 4; % enter a positive number <= 5. Multiple of charge time constant "Tau".
##animate_bool = 1; % 1 to animate, 0 to take single snapshot
##animation_range = 10; % degree of scaling of independent variables during animation
##num_animated_vars = 7; % number of variables to animate
  endfor
endfor



