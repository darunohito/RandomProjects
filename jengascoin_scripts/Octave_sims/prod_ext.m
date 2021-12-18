% extended product function
  % accepts up to 64-bit integer vectors for both arguments, with LSB first order:
  % e.g. [ x1(1) == (int)x1(1)*2^0, x1(2) == (int)x1(2)*2^64... x1(N) == (int)x1(N)*2^(64*(N-1)) ] 
  % as such, signs and data types should be maintained externally, if necessary
function y = prod_ext(x1,x2) 
  if(class(x1) != "uint64" || class(x2) != "uint64")
    error("prod_ext function expects uint64 vectors\n");
  endif
  expected_length = length(x2) + length(x2); % maximum length function can produce
  y = zeros(1,expected_length);
  x2_bin = dec2bin(x2);
  
  for i1 = 1:length(x1)
    for i2 = 1:length(x2)
      bin_temp = 0;
      output_index = i1+i2-1;
      carry(output_index + 1) = uint64(floor(log2(x1(i1)) + log2(x2(i2))));
      for i3 = 1:64
        bin_temp = bin_temp + bitshift(x2_bin(i2),bitget(x1,i3));
      endfor
      y(output_index) = y(output_index) + bin_temp;
      y(output_index + 1) = y(output_index + 1) + 2^carry(output_index + 1);
    endfor
  endfor
  
endfunction