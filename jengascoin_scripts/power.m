function res = power (x, y, p)
  
%% Utility function to do modular exponentiation.
%% It returns (x^y) % p
    res = 1;        % Initialize result
    x = mod(x,p);   % Update x if it is more than or equal to p
    while (y > 0)
        % If y is odd, multiply x with result
        if (bitand(y,1))
            res = mod((res*x),p);
        endif
        % y must be even now
        y = bitshift(y,-1); % y = y/2
        x = mod((x*x),p);
    endwhile
    res = uint64(res);
endfunction
