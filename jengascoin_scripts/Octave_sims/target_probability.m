max_out = 10e6;
diff_div = 500
target = max_out / diff_div;
loops = 100000;
try_mat = zeros(1, loops);

i = 1;
while i < loops
  tries = 1;
  while randi(max_out) > target
    tries = tries + 1;
  end
  try_mat(i) = tries;
  printf('\r%i', i)
  i = i+1;
  
end
printf("\ncreating histogram\n")
  
hist(try_mat, 250);
xlim([0 5*diff_div]);
printf('average: %i\n', mean(tries));