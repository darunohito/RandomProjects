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
## @deftypefn {} {@var{retval} =} PoP_surface (@var{input1}, @var{input2})
##
## @seealso{}
## @end deftypefn

## Author: darpo <darpo@SMALLSAT>
## Created: 2021-10-15

function [x_vector y_vector z_matrix] = PoP_surface (burn_coefficient, burn_power, raffle_win_ratio, reward_coefficient, reward_cutoff, plot_bool)


%% INPUT PARAMETERS %%
    % Adjust the inputs below:
##burn_coefficient = 1; % enter any positive number. Higher number is a larger ante/burn.
##burn_power = -2; % enter any negative number.  
##raffle_win_ratio = 0.2; % enter a positive number no greater than 1. (0 < number <= 1)
##reward_coefficient = 0.5; % enter any positive number. Higher number scales rewards.
##reward_cutoff = 5; % enter a positive whole number. Max number of accepted hashes in a given epoch.

    % Optional adjustments:
plot_granularity = 31; % Enter a whole number greater than or equal to 10. Determines number of x and y points.
color_granularity = 51; % Enter a whole number greater than or equal to 5. Determines number of color steps.
plot_balance_range_multiplier = 5; % enter any positive number. Scales balance axis. Recommend at least 2.
plot_extension_multiplier = 1.2; % will accept any number from between 0 and +inf, but is intended to give a natural plot scale, dependent on the reward_cutoff and balance_cutoff. 1, 1.2, 2 are all reasonable entries.


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
balance_cutoff = sqrt(burn_coefficient); % minimum number of coins in a wallet to mine.

% "x" == "reward_count", which is proportional to hashrate
x_range = [0 reward_cutoff] * plot_extension_multiplier;
x = linspace(x_range(1),x_range(2),plot_granularity);

% "y" == "wallet_balance", in coins
y_range = [0 balance_cutoff*plot_balance_range_multiplier] * plot_extension_multiplier;
y = linspace(y_range(1),y_range(2),plot_granularity);

% "z" == "profit", in terms of coins
z = zeros(length(x),length(y));


%% MATH %%
    % Don't touch!
for x_i = 1:length(x)
  for y_i = 1:length(y)
    if(y(y_i) < balance_cutoff)
      z(y_i,x_i) = 0;
    elseif(x(x_i) > reward_cutoff)
      z(y_i,x_i) = -burn_coefficient*realpow(y(y_i),burn_power) + reward_coefficient*log(reward_cutoff);
    else
      z(y_i,x_i) = -burn_coefficient*realpow(y(y_i),burn_power) + reward_coefficient*log(x(x_i));
    endif
      z(y_i,x_i) = z(y_i,x_i) * raffle_win_ratio;
  endfor
endfor

x_vector = x;
y_vector = y;
z_matrix = z;

if(plot_bool) 
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
endif
    

endfunction