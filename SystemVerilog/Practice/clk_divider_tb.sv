//clk_divider testbench
module clk_divider_tb();

	parameter TB_COUNTER_WIDTH	= 8;
// INTERNAL SIGNALS
	logic							tb_clk_in;
	logic							tb_rst_n;
	logic	[TB_COUNTER_WIDTH-1:0]	tb_div_half_N;
	logic							tb_clk_out;
	
	logic	[TB_COUNTER_WIDTH:0]	tb_counter;
	
// INSTANTIATE MODULES UNDER TEST	
	clk_divider #(TB_COUNTER_WIDTH)
		clk_divider1 (.clk_in(tb_clk_in), rst_n(tb_rst_n), .div_half_N(tb_div_half_N), .clk_out(tb_clk_out) );
		
// FUNCTIONAL DESCRIPTION OF TESTBENCH

	initial begin
		#1;
		tb_counter		= 0;
		tb_clk_in		= 0;
		tb_rst_n	= 1;
		tb_div_half_N	= 9;
		
		while (tb_counter < 5 * tb_div_half_N) begin
			#1;
			tb_clk_in = !tb_clk_in;
			tb_counter++;
		end
		
		$finish(); //explicitly end simulation
		
	end
	
	initial begin
		$dumpfile("dump.vcd"); 
		$dumpvars;
	end	
	
endmodule: clk_divider_tb