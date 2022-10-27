module tapped_shift_reg #(
	parameter		DATA_WIDTH		= 8, //number of bits per data primitive
	parameter 		BLOCK_LENGTH	= 16 //maximum number of DATA_WIDTH blocks
	)
	(
	input	logic	latch,
	input	logic	clk_in,
	input	logic	d_in,
	output	logic	d_out,
	output 	logic	idle
	);
	
// INTERNAL SIGNALS
	logic	[DATA_WIDTH-1:0] 	data 	[$:BLOCK_LENGTH-1];
	logic						length_counter;
	logic						length_out; 
	
// FUNCTIONAL DESCRIPTION
	initial begin
		length_counter = 0;
	end
	
	always @ (posedge latch) begin
		
	end
	
	always @ (posedge clk_in) begin
		
	end
	
endmodule: tapped_shift_reg