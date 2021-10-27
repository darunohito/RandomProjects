function retval = millerTest (d, n)
% This function is called for all k trials. It returns
% false if n is composite and returns true if n is
% probably prime.
% d is an odd number such that  d*2<sup>r</sup> = n-1
% for some r >= 1
    % Pick a random number in [2..n-2]
    % Corner cases make sure that n > 4
    a = 2 + round(rand(1) * (n-2-eps));
 
    % Compute a^d % n
    x = modular_exp(a, d, n);
 
    if (x == 1  || x == n-1)
       retval = true;
       return;
     endif
     
 
    % Keep squaring x while one of the following doesn't
    % happen
    % (i)   d does not reach n-1
    % (ii)  (x^2) % n is not 1
    % (iii) (x^2) % n is not n-1
    while (d != n-1)
        x = prodmod(uint64([x x]),uint64(n));
        d = d * 2;
        if (x == 1)
          retval = false;
          return;
        elseif (x == n-1)
          retval = true;
          return;
        endif
    endwhile
 
    % Return composite
    retval = false;
endfunction
