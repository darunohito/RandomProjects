clear all

num_entries = 500; % number of people who committed a random number to the lottery. Equal to number of people who perform "Burn" phase 1.
random_number_len = 4; % number of random bytes committed per user
bits_kept = 31; % number of bits to keep from the resulting hash. Directly controls time delay. 
delay_difficulty = 10; % == k in most literature
delay_padding = 3; % number of MSB to set to maintain consistent difficulties across addresses

public_key_numeric = random_bytes(28);
public_key = native2unicode(public_key_numeric)
address = hash('SHA224',public_key); % wrong algo, but right length
last_block_hash = hash('SHA512',native2unicode(random_bytes(128))); % wrong algo, but right length
% elo_ID = 1; % arbitrary number assigned to each Elo, designed to reduce interplay of high-speed cpus sharing PoD solutions with high-hash GPUs/ASICs

random_bytestream_hash = hash('SHA512',native2unicode(random_bytes(num_entries*random_number_len))); % common across network
keyed_bytestream_hash = hash('SHA512',[random_bytestream_hash public_key]) % address-specific

notprime = true; numtries = 0;
keyed_bytestream_hash_num = 0;

% truncate hash down to nibbles kept
newlen = ceil(bits_kept/4);
keyed_bytestream_hash_trunc = strtrunc(keyed_bytestream_hash,newlen);
keyed_bytestream_hash_num = hex2dec(keyed_bytestream_hash_trunc);
% truncate LSBs down to bits_kept 
length_diff = floor(bits_kept - log2(keyed_bytestream_hash_num));
keyed_bytestream_hash_num = bitshift(keyed_bytestream_hash_num,length_diff);
if (keyed_bytestream_hash_num > 2^bits_kept)
  error("truncation error!")
endif

% set delay_padding highest MSB to maintain similar difficulties across all addresses
bitpad = 0;
for index = bits_kept:-1:bits_kept-delay_padding+1
  bitpad = bitpad + 2^(index-1);
endfor
keyed_bytestream_hash_num = uint64(bitor(keyed_bytestream_hash_num,bitpad));

% make sure the number is odd
if(~mod(keyed_bytestream_hash_num,2))
  keyed_bytestream_hash_num = keyed_bytestream_hash_num - 1;
else %decrement in preparation for prime search loop
  keyed_bytestream_hash_num = keyed_bytestream_hash_num - 2;
endif

% make sure the number satisfies (p = 3)mod4, or "3 = mod(p,4)"
if (3 != mod(keyed_bytestream_hash_num,4))
  keyed_bytestream_hash_num = keyed_bytestream_hash_num + 2;
endif

% find the nearest prime >= keyed_bytestream_hash_num 
% and make sure the number satisfies (p = 3)mod4, or "3 = mod(p,4)"
while(notprime)
  keyed_bytestream_hash_num = keyed_bytestream_hash_num + 4;
  %notprime = ~isPrimeMiller(keyed_bytestream_hash_num,20);
  notprime = ~isprime(keyed_bytestream_hash_num,20);
  numtries = numtries + 1
endwhile
p = keyed_bytestream_hash_num;
p_hash = hash('SHA224',native2unicode(p));
fprintf("Found prime after %d tries\n",numtries);
fprintf("Working prime is %d (binary: %s)\n",p,num2str(dec2bin(keyed_bytestream_hash_num)));
fprintf("Does built-in prime function agree?\n     isprime: %d\n", isprime(keyed_bytestream_hash_num));
if(!isprime(p))
  error("isprime(p) is false!");
endif
fprintf("Does this satisfy (p = 3) mod 4?\n     3 =? %d\n", mod(p,4));
fprintf("FIRST VERIFICATION OUTPUT: Hash of prime = %s\n", p_hash);

if(bits_kept < length(p_hash)*4) %p_hash is in hex, so 4 bits per char
  p_hash = strtrunc(p_hash,ceil(bits_kept/4))
elseif(bits_kept > length(p_hash))
  while(bits_kept > length(p_hash)*4)
    p_hash = [p_hash ...
        strtrunc(p_hash,(bits_kept/4)-length(p_hash))];
  endwhile
endif

p_hash_num = 0;
% create single integer out of character vector
for index = 1:uint64(length(p_hash))
  p_hash_num = uint64(p_hash_num) + bitshift(uint64(p_hash(index)),(4*(index-1)));
endfor

% truncate LSBs down to bits_kept 
p_hash_num = bitshift(p_hash_num,-mod(bits_kept,4));
fprintf("  OUTPUT 1.1: Trimmed Hash of prime = %s\n", num2str(dec2hex(p_hash_num)));

omega = zeros(delay_difficulty+1,1);
omega(1) = mod(p_hash_num,p);
for index = 1:delay_difficulty
    omega(index+1) = pMod4_3_sqrt(omega(index),p);
endfor
  
    
    