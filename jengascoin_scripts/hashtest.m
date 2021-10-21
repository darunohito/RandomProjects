for index = 1:64
  output = hash('SHA512',index);
  pause(0.1); 
  clc()
  printf("SHA256(%d) = ", index)
  display(output)
endfor
