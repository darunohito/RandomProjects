//clk_divider module
`include "counter.sv"

module clk_divider #(
	parameter COUNTER_WIDTH=8) 
	(
	input 	logic						clk_in,
	input	logic						rst_n,
	input	logic	[COUNTER_WIDTH-1:0]	div_half_N,
	output	logic						clk_out
	);
	
// NOTE: Module has a built-in divide by 2. 
//			i.e. a "div_half_N" input of 1 will divide the clock by 2.
// Maximum division is [2^(COUNTER_WIDTH+1)]
	
// PORT DECLARATION

	
// INTERNAL SIGNALS
	logic								counter_strobe;
	
	counter #(COUNTER_WIDTH) 
  clk_counter(.clk(clk_in),
              .oc_val(div_half_N),
              .oc_en(1'b1),
              .rst_n(rst_n),
              .en(1'b1),
              .out( ),
              .oc_strobe(counter_strobe)
             );


// FUNCTIONAL DESCRIPTION
	initial begin
		clk_out	= 0;
	end
	
	always @ (posedge counter_strobe) begin
		clk_out	= !clk_out;
	end
	
	always @ (posedge clk_in) begin
		if (!rst_n)
			clk_out = 0;
		
	end
	
endmodule: clk_divider