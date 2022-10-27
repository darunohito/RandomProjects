//spi_master testbench
`include "spi_intf.sv"

module spi_master_tb();
  
	parameter		TB_DATA_WIDTH		= 8;
	parameter 		TB_CLK_CNT_WIDTH 	= 16;

// INTERNAL SIGNALS
	//module port connections
	logic						tb_clk;
	logic	[TB_CLK_CNT_WIDTH-1:0]	tb_sclk_div; 
	logic	[1:0]				tb_mode; //spi mode input, 0-3
	logic						tb_latch; //pulse high to load input data into output buffer and start transfer
	logic	[TB_DATA_WIDTH-1:0]	tb_data_in;
	logic	[TB_DATA_WIDTH-1:0]	tb_data_out;
	logic						tb_idle;
	// spi interface
  	spi_intf tb_spi_m();
	
	// testbench internal
	logic	[TB_CLK_CNT_WIDTH:0]	tb_counter; 
	//logic	[TB_DATA_WIDTH-1:0]		tb_miso_data;
	
// INSTANTIATE MODULES UNDER TEST	
	spi_master #(TB_DATA_WIDTH,TB_CLK_CNT_WIDTH)
  spi_master1 (.spi_m(tb_spi_m), 
               .clk(tb_clk), 
               .sclk_div(tb_sclk_div), 
               .mode(tb_mode), 
               .latch(tb_latch), 
               .data_in(tb_data_in), 
               .data_out(tb_data_out), 
               .idle(tb_idle) 
              );
		
// FUNCTIONAL DESCRIPTION OF TESTBENCH

  	assign tb_spi_m.miso = tb_spi_m.mosi; //loopback test
  
	initial begin
		#1; //delay 1 clock
		// drive module inputs
		tb_clk			= 0;
		tb_sclk_div 	= 8; 
		tb_latch 		= 0;
		//initialize internal signals
		tb_counter		= 0;
		
      while ((tb_counter <= 4) || !tb_idle) begin
			#1; //delay 1 clock
			tb_clk = !tb_clk;

          	if			(tb_idle == 1) 	begin
              	tb_counter++;
              	if 			(tb_counter == 1) begin
              		tb_data_in 		<= 8'b10100101;
              		tb_mode			<= 2'b00;
              	end else if	(tb_counter == 2) begin
                  	tb_data_in 		<= 8'b11110000;
              		tb_mode			<= 2'b01;
              	end else if	(tb_counter == 3) begin
                  	tb_data_in 		<= 8'b00001111;
              		tb_mode			<= 2'b10;
              	end else if	(tb_counter >= 4) begin
                  	tb_data_in 		<= 8'b00110011;
              		tb_mode			<= 2'b11;
              	end
              	#1; //delay 1 clock
				tb_latch <= 1;
            end else if	(tb_latch == 1) 
				tb_latch <= 0;
		end
		
      	#50; //delay
      	tb_latch <= 1; //dummy assignment
		$finish(); //explicitly end simulation
		
	end
	
	initial begin
		$dumpfile("dump.vcd"); 
		$dumpvars;
	end	
	
endmodule: spi_master_tb