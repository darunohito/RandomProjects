clear all

[dummy,info] = pkg('list');
pkglist = cell(2,length(info));
pkgposition = 0;
for index = 1:length(info)
  pkglist(1,index) = info{index}.name;
  pkglist(2,index) = info{index}.loaded;
  if(strcmp(pkglist(1,index){1},'symbolic'))
    pkgposition = index;
    if(pkglist(2,index){1} == 0)
      pkg load symbolic
    endif
  endif
endfor
if(!pkgposition)
  pkg install -forge symbolic
  pkg load symbolic
endif




num_entries = 500; % number of people who committed a random number to the lottery. Equal to number of people who perform "Burn" phase 1.
random_number_len = 4; % number of random bytes committed per user
bits_kept = 64; % number of bits to keep from the resulting hash. Directly controls time delay. 
delay_difficulty = 10; % == k in most literature
delay_padding = 3; % number of MSB to set to maintain consistent difficulties across addresses

