% "out" is returned as either symbolic integer vector or char vector array
% "in" is given as a decimal integer vector, symbolic decimal integer vector, or char vector array
% "direction" is either 'encode' or 'decode'
function out = base58(in,direction)
  warning("off");
  base58_map = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"; %offset strfind by 1
  
  if(strcmp(direction,'encode'))
    
    in_s = sym(in); % cast input as symbolic
    out_len = ceil(log(in_s)/log(58)); %output length in Base58 characters
    out = [];
    for i1 = 1:size(in,1)
      pos = 0;
      while(in_s(i1) >= 1)
        out(i1,out_len(i1)-pos) = base58_map(floor(mod(in_s(i1),58))+1);
        in_s(i1) = floor(in_s(i1) / 58);
        pos = pos+1;
      endwhile
      printf(".");
    endfor
    out = char(out);
    printf("encoding done\n");
  elseif(strcmp(direction,'decode'))
    if(!ischar(in))
      error("base58 input must be char array (string) for decode operations\n");
    endif
    out = sym(zeros(size(in,1),1));
    for i1 = 1:size(in,1)
    pos = 0;
      for i2 = size(in,2):-1:1 % LSB first
        if(!strfind(base58_map,in(i1,i2)))
          error("input must be Base58 encoded for decode operations\n");
        endif
        out(i1) = out(i1) + (strfind(base58_map,in(i1,i2))-1) * sym(58)^pos; % base58 chars are 6 bits wide
        pos = pos + 1; 
      endfor
      printf(".");
    endfor
    printf("decoding done\n");
  else
    error("base58 'direction' argument is invalid. Must be given as 'encode' or 'decode'.\n");
  endif
  warning("on")
endfunction