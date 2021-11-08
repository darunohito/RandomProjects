f = fileread('Jengascoin_PoW_history.7z');
  output = hash('SHA256',f);
  display(output)

  if(output == 'e67c54770df15f2d8bef0b4fd85f52fb91c1832316b00988a79c400f4dc8d5ae')
  printf('hashes match');
endif


