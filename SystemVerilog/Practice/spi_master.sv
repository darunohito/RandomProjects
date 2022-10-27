//spi_master module
`include "clk_divider.sv"

module spi_master #(
	parameter		DATA_WIDTH		= 8,
	parameter 		CLK_CNT_WIDTH 	= 16 //width of counter used for SPI clock division
	) (
	spi_intf.MASTER	 					spi_m, 
    input	logic						clk, 
    input	logic	[CLK_CNT_WIDTH-1:0]	sclk_div, 
    input	logic	[1:0]				mode, 
    input	logic						latch, 
    input	logic	[DATA_WIDTH-1:0]	data_in, 
    output	logic	[DATA_WIDTH-1:0]	data_out, 
    output	logic						idle
	); //spi_intf.MASTER 
	
// INTERNAL SIGNALS
	logic	[DATA_WIDTH-1:0]	rx_buf;
	logic	[DATA_WIDTH-1:0]	tx_buf;
	logic	[DATA_WIDTH-1:0]	toggle_counter;
	logic	[DATA_WIDTH-1:0]	sample_counter;
	logic						sclk_int;
	logic						txfr_rdy;

// INSTANIATION OF OTHER MODULES
	clk_divider #(CLK_CNT_WIDTH)
		sclk_divider (.clk_in(clk), .rst_n(!idle), .div_half_N(sclk_div >> 1), .clk_out(sclk_int) );

// FUNCTIONAL DESCRIPTION
	initial begin
		rx_buf		= 1'b0;
		tx_buf		= 1'b0;
		txfr_rdy	= 1'b0;
		spi_m.cs	= 1'b1;
		idle	 	= 1'b1;
	end
	
  assign spi_m.sclk	= (sclk_int & (!idle) & txfr_rdy) ^ mode[1]; // disconnect SCLK from output when idle 

	always @ (posedge latch) begin
		if (idle) begin
			tx_buf 			<= data_in; //latch input data into tx buffer
			toggle_counter	<= 0;
			sample_counter	<= 0;
			spi_m.cs		<= 0; //pull CS low
			idle 			<= 0; //now busy
			//**PULL CLKDIV OUT OF RESET**
		end
	end
	
	always @ (edge sclk_int) begin
		if (!idle) begin
			if (sclk_int ^ mode[0]) begin
				if ((toggle_counter >= 1) && (toggle_counter <= DATA_WIDTH)) begin
					// sample
					rx_buf 			<= rx_buf << 1;
					rx_buf[0] 		<= spi_m.miso;
					sample_counter 	<= sample_counter + 1;
				end else if (toggle_counter > DATA_WIDTH) begin
					idle <= 1;
				end
				
			end else begin
				toggle_counter 	<= toggle_counter + 1;
				if (sample_counter < DATA_WIDTH) begin
                  	txfr_rdy	<= 1;
					// toggle
					spi_m.mosi 	<= tx_buf[DATA_WIDTH-1]; //send MSB
					tx_buf 		<= tx_buf << 1;
				end else begin
					data_out 	<= rx_buf; //latch rx data into output data
					spi_m.cs	<= 1; //pull CS high
                  	txfr_rdy	<= 0;
				end
			end
			
		end //else
			//**PUSH CLKDIV INTO RESET**
	end
	

endmodule: spi_master