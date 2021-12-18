n_div = 1; % initialize elo division number;



%%%%%%%%%%%%%%%%%%%% elo_div_calc %%%%%%%%%%%%%%%%%%%%
%% INPUT ARGS &&
%{
    - network_diff is a double-precision float representation of the integer difficulty of the full network, linearly proportional to network hashrate.
    - div_dcnt_metric is a double-precision float vector of values between 0 and 1, representing estimated decentralization of hashpower in each division
    - div_size is integer vector of number of miners in each division
%}
%% OUTPUTS %%
%{
    - n_div is positive integer number of elo divisions
    - div_diff is integer vector of difficulties at each division
    - div_burn is integer vector of currency burn requirements at each division
%}
function n_div, div_diff, div_burn = elo_div_calc(network_diff, div_dcnt_metric, div_size)
  
endfunction
%%%%%%%%%%%%%%%%%%%% elo_div_calc %%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%% decentralization %%%%%%%%%%%%%%%%%%%%
function network_dcnt_metric, div_dcnt_metric = decentralization(n_div, 
  
  network_dcnt_metric = (1+log(n_div)) / prod(div_dcnt_metric); % just a network health metric
endfunction
%%%%%%%%%%%%%%%%%%%% decentralization %%%%%%%%%%%%%%%%%%%%


