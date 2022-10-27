//counter module
module counter #(
	parameter N=8,
	parameter DOWN=0)
	(clk, oc_val, oc_en, rst_n, en, out, oc_strobe);

// PORT DECLARATION
	input 	logic 		 	clk;		//clock input
	input 	logic 	[N-1:0] oc_val;		//output compare value input
	input	logic			oc_en;		//enable output compare
	input 	logic			rst_n;		//active low reset counter
	input	logic			en;			//enable counter
	output	logic	[N-1:0]	out;		//counter output
	output	logic			oc_strobe;	//output compare strobe
	
// INTERNAL SIGNALS
	logic	[N-1:0]			out_temp;
	
// FUNCTIONAL DESCRIPTION
	initial begin
		out_temp 	= 0;
		out			= 0;
	end
	
	always @ (posedge clk) begin
		if (!rst_n) begin
			out_temp <= 0;
		end else begin
			if (en) begin
				// increment counter
				if (DOWN)
					out_temp <= out - 1;
				else
					out_temp <= out + 1;
			end 
		end
	end
	
	always @ (negedge clk) begin
		if (!rst_n) begin
			out <= out_temp;
		end else begin
			//output compare
			if (oc_en && (out_temp == oc_val)) begin
				out <= 0;
				oc_strobe <= 1;
			end else begin
				out <= out_temp;
				oc_strobe <= 0;		
			end
		end
	end
	
endmodule: counter