function x = pMod4_3_sqrt (n, p)
% Returns true if square root of n under modulo p exists
% Assumption: p is of the form 3*i + 4 where i >= 1

    if (mod(p,4) != 3)
        fprintf("Invalid Input");
        return;
    endif
 
    % Try "+(n^((p + 1)/4))"
    n = mod(n,p);
    x = uint64(power(n,(p+1)/4,p));
    if (mod((x * x),p) == n)
      retval = x;
        fprintf("Square root is %d\n",x);
        return;
    endif
 
    % Try "-(n ^ ((p + 1)/4))"
    x = p - x;
    if (mod((x * x),p) == n)
      retval = x;
        fprintf("Square root is %d\n",x);
        return;
    endif
 
    % If none of the above two work, then
    % square root doesn't exist
    fprintf("Square root doesn't exist\n");
    x = 0;
endfunction
