//adder testbench
module adder_tb();
	
	parameter TB_DATA_WIDTH=16;

// INTERNAL SIGNALS
	logic 	[TB_DATA_WIDTH-1:0] 	tb_a;		//operand a
	logic 	[TB_DATA_WIDTH-1:0] 	tb_b;		//operand b
	logic 						tb_c_in;	//carry in
	logic	[TB_DATA_WIDTH-1:0]	tb_sum;	//sum of a and b
	logic						tb_c_out;	//carry out

// INSTANTIATE MODULES UNDER TEST
	adder #(TB_DATA_WIDTH) 
		adder1( .a(tb_a), .b(tb_b), .c_in(tb_c_in), .sum(tb_sum), .c_out(tb_c_out) ); //note the parameter input method


// FUNCTIONAL DESCRIPTION OF TESTBENCH
	//Assignment types
		// can use "assign" for continous assignment
		// can use "always" or "initial" for procedural assignment
			// initial only evaluated at beginning of sim
			// always is evaluated in every sim cycle
	initial begin
		#1; //wait one cycle
		tb_a=1;
		tb_b=1;
		tb_c_in=1;
		
		#1; //wait one cycle
		tb_a=10;
		tb_b=10;
		tb_c_in=0;
				
		#1; //wait one cycle
		tb_a=50;
		tb_b=60;
		tb_c_in=1;
		
		#1; //wait one cycle
		tb_a='hFF; 	//hexadecimal designation. 
					//Can use 'b for binary and 'd for decimal
		tb_b=0;
		tb_c_in=1;
		
		#1; //wait one cycle
		tb_a=0; //to prevent compiler from removing last sim cycle
		$finish(); //explicitly end simulation
		
	end
	
	initial begin
		$dumpfile("dump.vcd"); 
		$dumpvars;
	end
	
endmodule: adder_tb

	