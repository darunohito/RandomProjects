% test code
inputs = ['PZ8Tyr4Nx8MHsRAGMpZmZ6TWY63dXWSCyfwKjMG1Fqak3VJQmPDWHTopuqyP7EPEkMBdE6QY4BUScCAhfxDirgmFVPLaKVAEZBuva9dNgzBAAM11YZn1ALi1',
'PZ8Tyr4Nx8MHsRAGMpZmZ6TWY63dXWSCxsR7Zup31zZXy8NsHSSJbgQnPgHupMGgpZfCNtDVWJzAjx65gw6NXEmiow4R7w4EpreyPZpkSQDn14h7xRDrdtNG',
'PZ8Tyr4Nx8MHsRAGMpZmZ6TWY63dXWSCx9BmnsqRpogkmeLX5DAVPXeEov5NThLTNtYg61ybfnVnoAZgCZZsXaCgBKgxQeoht19e87WKHw8KhC8idL6uveKb'];

integers = base58(inputs,'decode');
input_test = base58(integers,'encode');

if(strcmp(inputs,input_test))
  printf("encode/decode results match!\n");
endif

