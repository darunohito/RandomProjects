clear all

num_entries = 500; % number of people who committed a random number to the lottery. Equal to number of people who perform "Burn" phase 1.
random_number_len = 4; % number of random bytes committed per user
delay_difficulty = 50; % number of bits to keep from the resulting hash. Directly controls time delay. 

public_key_numeric = random_bytes(28);
public_key = native2unicode(public_key_numeric)
address = hash('SHA224',public_key); % wrong algo, but right length
last_block_hash = hash('SHA512',native2unicode(random_bytes(128))); % wrong algo, but right length

random_bytestream_hash = hash('SHA512',native2unicode(random_bytes(num_entries*random_number_len))); % common across network
keyed_bytestream_hash = hash('SHA512',[random_bytestream_hash public_key]); % address-specific

if(delay_difficulty < length(keyed_bytestream_hash))
  keyed_bytestream_hash = strtrunc(keyed_bytestream_hash,delay_difficulty)
elseif(delay_difficulty > length(keyed_bytestream_hash))
  while(delay_difficulty > length(keyed_bytestream_hash))
    keyed_bytestream_hash = [keyed_bytestream_hash strtrunc(keyed_bytestream_hash,delay_difficulty-length(keyed_bytestream_hash))];
  endwhile
endif

notprime = true; numtries = 0;
keyed_bytestream_hash_mod = unicode2native(keyed_bytestream_hash);
while(notprime)
  numtries = numtries + 1
  notprime = ~isprime(keyed_bytestream_hash_mod)
  keyed_bytestream_hash_mod(end) = keyed_bytestream_hash_mod(end) + 1;

endwhile