clear all

num_entries = 500; % number of people who committed a random number to the lottery. Equal to number of people who perform "Burn" phase 1.
random_number_len = 4; % number of random bytes committed per user
delay_difficulty = 31; % number of bits to keep from the resulting hash. Directly controls time delay. 
delay_padding = 3; % number of MSB to set to maintain consistent difficulties across addresses

public_key_numeric = random_bytes(28);
public_key = native2unicode(public_key_numeric)
address = hash('SHA224',public_key); % wrong algo, but right length
last_block_hash = hash('SHA512',native2unicode(random_bytes(128))); % wrong algo, but right length

random_bytestream_hash = hash('SHA512',native2unicode(random_bytes(num_entries*random_number_len))); % common across network
keyed_bytestream_hash = hash('SHA512',[random_bytestream_hash public_key]); % address-specific

if(delay_difficulty < length(keyed_bytestream_hash)*4) %keyed_bytestream_hash is in hex, so 4 bits per char
  keyed_bytestream_hash = strtrunc(keyed_bytestream_hash,ceil(delay_difficulty/4))
elseif(delay_difficulty > length(keyed_bytestream_hash))
  while(delay_difficulty > length(keyed_bytestream_hash)*4)
    keyed_bytestream_hash = [keyed_bytestream_hash ...
        strtrunc(keyed_bytestream_hash,(delay_difficulty/4)-length(keyed_bytestream_hash))];
  endwhile
endif

notprime = true; numtries = 0;
keyed_bytestream_hash_num = 0;
keyed_bytestream_hash_mod = unicode2native(keyed_bytestream_hash);

% create single integer out of character vector
for index = 1:uint64(length(keyed_bytestream_hash_mod))
  keyed_bytestream_hash_num = uint64(keyed_bytestream_hash_num) + bitshift(uint64(keyed_bytestream_hash_mod(index)),(4*(index-1)));
endfor

% truncate LSBs down to difficulty (NEED TO IMPLEMENT)
keyed_bytestream_hash_num = bitshift(keyed_bytestream_hash_num,-mod(delay_difficulty,4));

% make sure the number is odd
if(~mod(keyed_bytestream_hash_num,2))
  keyed_bytestream_hash_num = keyed_bytestream_hash_num - 1;
endif

% set delay_padding highest MSB to maintain similar difficulties across all addresses
bitpad = 0;
for index = delay_difficulty:-1:delay_difficulty-delay_padding+1
  bitpad = bitpad + 2^(index-1);
endfor
keyed_bytestream_hash_num = bitor(keyed_bytestream_hash_num,bitpad);

% find the nearest prime >= keyed_bytestream_hash_num 
% which also satisfies (p = 3)mod4, or "3 = mod(p,4)
while(notprime || (3 != mod(keyed_bytestream_hash_num,4)))
  numtries = numtries + 1;
  notprime = ~isPrimeMiller(keyed_bytestream_hash_num,7);
  if(notprime || (3 != mod(keyed_bytestream_hash_num,4)))
    keyed_bytestream_hash_num = keyed_bytestream_hash_num + 2;
  endif
endwhile
fprintf("Found prime after %d tries\n",numtries);
fprintf("Working prime is %d (binary: %s)\n",keyed_bytestream_hash_num,num2str(dec2bin(keyed_bytestream_hash_num)));
fprintf("Does this satisfy (p = 3) mod 4? 3 =? %d\n", mod(keyed_bytestream_hash_num,4));
fprintf("FIRST VERIFICATION OUTPUT: Hash of prime = %s\n", hash("SHA224",native2unicode(keyed_bytestream_hash_num)));

