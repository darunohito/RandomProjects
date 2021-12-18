x = 3559594545621774848;
y = "";

while (x > 0)
  x_chunk = mod(x,256);
  fprintf("x_chunk: %x\n", dec2hex(x_chunk));
  y = strcat(x_chunk, y);
  x = floor(x/256);
end

fprintf("y: %s\n", y);