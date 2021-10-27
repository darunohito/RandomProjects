% Utility function for performing modulus operations on products of double-precision (or 64-bit ints)

function modulus = quadmod (x1, x2, y)
  x1_mod = mod(x1,y);
  x2_mod = mod(x2,y);
  modulus = mod(x1_mod*x2_mod,y);
endfunction
