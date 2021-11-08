% Iterative Function to
% calculate (x^y)%p in O(log y)
function res = powermod(x, y, p)
    digits(cast(cast((ceil(log10(x)*2)),'double'),'uint16'));
    % Initialize result
    res = 1;
 
    % Update x if it is more
    % than or equal to p
    x = mod(x,p);
 
    if(x == 0)
      res = 0;
      return;
    endif
    while (y > 0)
        % If y is odd, multiply
        % x with result
        if (mod(y,2) == 1)
            res = mod((res * x),p);
        endif
        % y must be even now
         
        y = floor(y / 2);
        %y = bitshift(y,-1);
        x = mod((x * x),p);
        
    endwhile
endfunction
 
% This code is contributed by _saurabh_jaiswal