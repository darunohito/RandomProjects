totalT = tic;
tic
range = 5e7;
x = linspace(1,range,range);
x_primes = isprime(x);
printf("******************\nPrimes found. ");
toc

tic
window = 1e3; 
y = filter(ones(window,1)/window,1,x_primes);
printf("\nAveraged primes vector to %d-length rolling window. ", window);
toc

tic
plot(x,y)
printf("\nPlot finished. ");
toc
printf("\nTotal ");
toc(totalT)
printf("\n******************");