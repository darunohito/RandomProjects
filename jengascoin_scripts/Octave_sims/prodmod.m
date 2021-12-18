% Utility function for performing modulus operations on products of ints up to [native_int_size]
% x is vector of factors up to native unsigned int size
% y is an integer

% (x1 * x2)mod(y) == ((x1)mod(y) * (x2)mod(y))mod(y)
% (x1 * x2 * x3)mod(y) == ((((x1)mod(y) * (x2)mod(y))mod(y)) * (x3)mod(y))mod(y)
function modulus = prodmod (x, y) 
  factor_list = {};
  
  
  % [(a mod n) + (b mod n)] == (a + b) mod n
  % [(a mod n) * (b mod n)] == (a * b) mod n
  while(sum(factor_list{:,4}) > 64)
    for i1 = 1:length(x)
      factor_list{i1,1} = x(i1); % store x values
      factor_list{i1,2} = uint64(factor(x(i1))); % store factors
      factor_list{i1,3} = mod(factor_list{i1,2},y); % store mods of factors
      factor_list{i1,4} = log2(x(i1)); % store bit-length of x values
    endfor
    fprintf("current num bits: %d",sum(log2(mods)));
    mods_len = length(mods);
    diag_vector = ones(mods_len,1);
    x_factors = unique_factors';
    z_factors = unique_factors';
    %mod_mat = zeros(mods_len,mods_len);
    null_mat = diag(diag_vector,0);
    for i1 = 1: length(x_factors) %could be more efficient by only using half the matrix
      for i2 = i1:length(z_factors)
        if(log2(x_factors(i1))+log2(z_factors(i2)) > 64)
          multi_mat(i1,i2) = 0;
          break;
        endif
        multi_mat(i1,i2) = x_factors(i1) * z_factors(i2);
      endfor
    endfor
    mod_mat = mod(multi_mat,y)
    
    
  endwhile
  
  modulus = mod(prod(prod(factor_list{:,3})),y)
##  max_iterations = 100; % not yet sure how many are needed
##  native_int_size = 64; % 64-bit is native to octave
##  
##  if (!isinteger(x) || !isinteger(y))
##    if (rem(x,1) || rem(y,1))
##      error("prodmod function only accepts integers\n\
##        (numerics will be type-casted if integer-equivalent)\n");
##    else
##        warning("prodmod input class is non-integer. \
##        \nValue will be type-casted\n");
##    endif
##  elseif (y < 0)
##    error("prodmod function requires positive modulus value");
##  endif
##  
##  iteration = 1;
##  sign_bit = prod(sign(x));   % compute sign bit
##  x = uint64(x.*sign(x)); % invert negatives
##  
##  x_len = length(x);
##  x_mat = zeros(x_len,3); % initialize matrix
##  x_mat(:,1) = x'; % store x vector
##  x_mat(:,2) = uint64(mod(x_mat(:,1),y)); % store modulus values
##  x_mat(:,3) = log2(x_mat(:,2)); % store modulus bit length
##  x_mat = sortrows(x_mat,2); % order by modulus value, ascending
##  if(max(x_mat(:,2) == 0)) % trival case check
##    modulus = 0;
##    return;
##  endif
##  while (prod(x_mat(:,3)) >= native_int_size && iteration <= max_iterations)
##    % goal is to push elements of x over the value of p 
##    % without corrupting the modulus information in order to
##    % reduce the modulus on an element-basis to allow use of
##    % the commutative property of modular arithmetic.
####    for i1 = 1:x_len 
####      if( x_mat(i1,1) > 0 )
####         min_factor = min(factor(x_mat(i1,1)));
####        if(min_factor < x_mat(i1,1))
####          check_vector = ones(x_len,1);
####          check_vector(i1) = 0;
####          modbits = zeros(x_len,1);
####          modbits(i1) = x_mat(i1,3);
####          for i2 = 1:x_len % search for max-impact refactorization
####            if check_vector(i2)
####              modbits(i2) = prodmod(uint64([x_mat(i2,1) min_factor]),uint64(y)); % recurse
####              [modbits_min_val modbits_min_index] = min(modbits);
####            endif
####          endfor
####          if (modbits_min_val < modbits(i1))
####            x_mat(modbits_min_index,1) = x_mat(modbits_min_index,1) * min_factor
####            x_mat(i1,1) = x_mat(i1,1) / min_factor
####          endif
####        else
####          %error("sufficient factorization not found! prodmod overflow\n");
####          x_mat(:,2) = mod(x,y); % update modulus values
####          x_mat(:,3) = log2(x_mat(:,2)); % update modulus bit length
####        endif
####      endif
####      
##    endfor
##    %iteration = iteration + 1;
##  endwhile
##  if(iteration > max_iterations)
##    error("sufficient factorization not found! prodmod overflow\n");
##  endif
##  modulus = int64(sign_bit * mod(prod(x_mat(:,2)),y));
endfunction
