% Jengascoin addresses are 56 hex characters, 38 Base58 characters, or 224 bits long.
% Public keys are 176 hex characters, 120 Base58 characters, or 704 bits long.
% Private keys are 236 hex chars, 161 Base58 chars, or 944 bits long.
%          priv_bit_length  [944]
%          publ_bit_length  [704]
%          addr_bit_length  [224]                  
%   varagin arg1:       base58_address_prefix(character, 6 bits per char, empty args defaults to no prefix)
                  % e.g: ["J"]
%   keygen(); returns private, public keys and address, in cell array, in symbolic integer, hex, and base58 form.
function key = keygen(varagin)
  if (nargin)
    prefix = varagin(1);
    prefix_dec = base58(varagin(1),'decode'); %convert prefix to symbolic decimal 
  endif
  key = cell(3,3);
  %      priv | pub | addr
  % sym: 
  % hex:
  % b58: 
  first_try = 1;
  while(nargin && key(3,3){1} != varagin(1) || first_try)
    key(1,1){1} = sym(2)^903;
    randombits = round(rand(904,1));
    for(i1 = 1:903)
      key(1,1){1} = key(1,1){1} + sym(randombits(i1)*sym(2)^(i1-1)); %generate private key
    endfor
    key(2,1){1} = base16(key(1,1){1},'encode'); %encode private key as hex char vector
    temp = hash('SHA224',key(2,1){1}); 
    key(2,2){1} = strcat(hash('SHA256',key(2,1){1}),temp,hash('SHA224',temp)); %hash public key
    key(2,3){1} = hash('SHA224',key(2,2){1}); %hash address
    key(1,2:3){1} = base16(char([key(2,2){1};key(2,3){1}]),'decode'); %decode public key and address to decimal
    key(3,1:3){1} = base58([key(1,1){1};key(1,2){1};key(1,3){1}],'encode'); %encode both keys and address to base58
    first_try = 0;
  endwhile
  printf("Keygen finished \n");
endfunction
