clear all

num_entries = 500; % number of people who committed a random number to the lottery. Equal to number of people who perform "Burn" phase 1.
random_number_len = 4; % number of random bytes committed per user
bits_kept = 64; % number of bits to keep from the resulting hash. Directly controls time delay. 
delay_difficulty = 10; % == k in most literature
delay_padding = 3; % number of MSB to set to maintain consistent difficulties across addresses

