% Jengascoin addresses are 56 hex characters, 38 Base58 characters, or 224 bits long.
% Public keys are 176 hex characters, 120 Base58 characters, or 704 bits long.
% Private keys are 236 hex chars, Base58 chars, or 944 bits long.
%   arg1:       bit_length (length of desired key)
                  % e.g: [704]
%   arg2:       base58_address_prefix(character, 6 bits per char)
                  % e.g: ["JC"]
%   random_key(); returns private, public keys and address, in cell array, in symbolic integer, hex, and base58 form.
function [private_key, public_key, address] = keygen(varagin)
  for index = 1:length(varagin)
    varagin(index) = cast(strfind(base58_map, varagin(index)),'uint8'); %convert prefix to decimal
    if (!varagin(index) || varagin(index) > 58)
      error("random_key function requires Base58 character prefix arguments");
    endif
  endfor
  
  for index = 1:bitlength % MSB first
    if(index <= 6 * length(varagin))
      
    else
    
    endif
    
  endfor
endfunction