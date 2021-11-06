% "out" is returned as either symbolic integer or char array
% "in" is given as a decimal integer, symbolic decimal integer, or char array
% "direction" is either 'encode' or 'decode'
function out = base58(in,direction)
  warning("off");
  base58_map = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"; %offset strfind by -1
  pos = 0;
  if(strcmp(direction,'encode'))
    in_s = sym(in); % cast input as symbolic
    out_len = ceil(log(in_s)/log(58)); %output length in Base58 characters
    out = [];
    while(in_s >= 1)
      out(out_len-pos) = base58_map(floor(mod(in_s,58))+1);
      in_s = floor(in_s / 58);
      pos = pos+1;
    endwhile
    out = char(out);
  elseif(strcmp(direction,'decode'))
    if(!ischar(in))
      error("base58 input must be char array (string) for decode operations\n");
    endif
    out = 0;
    for index = length(in):-1:1 % LSB first
      if(!strfind(base58_map,in(index)))
        error("input must be Base58 encoded for decode operations\n");
      endif
      out = out + (strfind(base58_map,in(index))-1) * sym(58)^pos; % base58 chars are 6 bits wide
      pos = pos + 1; 
    endfor
  else
    error("base58 'direction' argument is invalid. Must be given as 'encode' or 'decode'.\n");
  endif
  warning("on")
endfunction