interface spi_intf();
	logic 	sclk;
  	logic 	cs;
  	logic 	miso;
  	logic	mosi;
  
	modport MASTER 	(output sclk, cs, mosi, input miso);
	modport SLAVE	(input sclk, cs, mosi, output miso);
  
  
endinterface: spi_intf