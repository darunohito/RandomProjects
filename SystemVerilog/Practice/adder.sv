//adder module
module adder #(
	parameter DATA_WIDTH=8)
	(a, b, c_in, sum, c_out);

// PORT DECLARATION
	input 	logic 	[DATA_WIDTH-1:0] 	a;		//operand a
	input 	logic 	[DATA_WIDTH-1:0] 	b;		//operand b
	input 	logic 						c_in;	//carry in
	output 	logic	[DATA_WIDTH-1:0]	sum;	//sum of a and b
	output	logic						c_out;	//carry out
	
// INTERNAL SIGNALS
	logic	[DATA_WIDTH:0]	result;
	
// FUNCTIONAL DESCRIPTION
	assign	result 	= a + b + c_in;
	assign	sum 	= result[DATA_WIDTH-1:0];
	assign	c_out	= result[DATA_WIDTH];
	
	
endmodule: adder
	