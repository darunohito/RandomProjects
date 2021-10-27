function result = modular_exp (x, y, p)
%% Utility function to do modular exponentiation.
%% It returns (x^y) % p
    result = 1;        % Initialize result
    x = uint64(mod(x,p));   % Update x if >= p
    while (y > 0)
        % If y is odd, multiply x with result
        if (bitand(y,1))
            result = uint64(quadmod(result,x,p));
        endif
        % y must be even now
        y = bitshift(y,-1); % y = y/2
        x = uint64(quadmod(x,x,p));
    endwhile
    result = floor(result);
endfunction

%{
    Problem 7 (i): modexp function
    Returns x ^ y mod n for x, y, and n > 1.
%}

    %anything raised to 0th power = 1 so return 1
##    if (y == 0)
##        result = 1;
##        return;
##    end
##
##    %recurse
##    z = modular_exp(x, floor(y/2), p);
##
##    %if even square the result
##    if (mod(y, 2) == 0)
##        result = mod(z*z, p);
##        return;
##    else
##        %odd so square the result & multiply by itself
##        result = mod(x*z*z, p);
##        return;
##    end
##end
