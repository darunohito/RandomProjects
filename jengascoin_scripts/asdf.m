clear all
checknum = 1001; %start number, odd only


numbers_checked = 1;
num_disagreements = 0;
miller_timer = 0;
trad_timer = 0;
while(num_disagreements == 0)
  prime = 0;
  
  while (!prime)
    miller_timer_0 = cputime;
    primeMiller = isPrimeMiller(checknum,7);
    miller_timer = miller_timer+cputime-miller_timer_0;
    trad_timer_0 = cputime;
    prime = isprime(checknum);
    trad_timer = trad_timer+cputime-trad_timer_0;
    
    if (primeMiller != prime)
      num_disagreements = num_disagreements + 1;
    endif
    
    if(prime) 
      clc
      fprintf("Numbers checked: %d, Prime Num: %d, Millertime: %d, Tradtime: %d",numbers_checked, checknum,miller_timer,trad_timer);
    endif
    
    checknum = checknum + 2;
    numbers_checked = numbers_checked + 1;
  endwhile
endwhile


fprintf("miller vs traditional disagreements: %d\n",num_disagreements)