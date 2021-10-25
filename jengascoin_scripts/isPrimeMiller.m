function retval = isPrimeMiller (n, k)
% It returns false if n is composite and returns true if n
% is probably prime.  k is an input parameter that determines
% accuracy level. Higher value of k indicates more accuracy.
    % Corner cases
    if (n <= 1 || n == 4)  
      retval = false;
      return;
    elseif (n <= 3) 
      retval = true;
      return;
    endif
 
    % Find r such that n = 2^d * r + 1 for some r >= 1
    d = uint64(n - 1);
    while (mod(d,2) == 0)
      d = d / 2;
    endwhile
      
 
    % Iterate given number of 'k' times
    for index_k = 1:k 
##      fprintf("iteration k = %d\n",index_k)
      if (!millerTest(d, n))
        retval = false;
        return;
      endif
      index_k = index_k + 1;
    endfor
          
    retval = true;
endfunction
