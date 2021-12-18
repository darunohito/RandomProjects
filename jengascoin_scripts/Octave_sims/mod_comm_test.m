%modular commutation test
testnum = 100;
for i1 = 1:testnum
  clc
  fprintf("i1 = %d\n",i1);
  for i2 = 1:testnum
    for i3 = 1:testnum
      tradmod = mod(i1*i2,i3);
      commmod = mod(i1+i2,i3);
      _quadmod = quadmod(i1,i2,i3);
      if(tradmod != _quadmod)
        error("quadmod != commmod!\ni1 = %d, i2 = %d, i3 = %d \
          \ntradmod == %d, commmod = %d, quadmod = %d\n",i1,i2,i3, tradmod, commmod, _quadmod);
      endif
    endfor
  endfor
endfor

  