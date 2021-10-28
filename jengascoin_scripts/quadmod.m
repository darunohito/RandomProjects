% Utility function for performing modulus operations on products of double-precision (or 64-bit ints)

function modulus = quadmod (x1, x2, y)
  xmod(1) = mod(x1,y);
  xmod(2) = mod(x2,y);
  xmod_logs = log2(xmod);
  while (sum(xmod_logs) > 64) % 64 is Octave's native integer size

  endwhile
  modulus = mod(xmod(1)*xmod(2),y);
endfunction
