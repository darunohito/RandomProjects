clear all
testnum = 200000;
testrange = 10;

for i1 = testnum-testrange:testnum+testrange
  clc
  fprintf("i1: %d\n", i1);
  for i2 = testnum-testrange:testnum+testrange
    for i3 = testnum-testrange:testnum+testrange
      testvector = int64([i1 i2 i1+i2 i1+50]);
      testmodulus = uint64(i3);
      prodmod_test = prodmod(testvector,testmodulus);
      mod_test = mod(prod(testvector),testmodulus);
      if(prodmod_test != mod_test)
        error("disagreement found!");
      endif
    endfor
  endfor
endfor
fprintf("No disagreements found!\n");


