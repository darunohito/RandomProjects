total = 0;
blks = 0;
blks_norm = 0;
total_norm = 0;

times = linspace(60,5,120)
for i = 1:120
  blks = blks + 1/i; % (i + 1)
  total = total + times(i)/i; % (i + 1)
  blks_norm = blks_norm + 1;
  total_norm = total_norm + times(i);
endfor

blks
total
blks_norm
total_norm

avg = total/blks
avg_norm = total_norm/blks_norm



