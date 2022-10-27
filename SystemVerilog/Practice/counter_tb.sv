//counter testbench
module counter_tb();
	
	parameter TB_N=16;
	parameter TB_DOWN=0;
	
// INTERNAL SIGNALS
	logic 			 	tb_clk;			//clock input
	logic 	[TB_N-1:0] 	tb_oc_val;		//output compare value input
	logic				tb_oc_en;		//enable output compare
	logic 	[TB_N-1:0] 	tb_rst_val_in;	//reset value input
	logic				tb_rst_n;		//active low reset counter
	logic				tb_en;			//enable counter
	logic	[TB_N-1:0]	tb_out;			//counter output
	logic				tb_oc_strobe;	//output compare strobe

	logic	[TB_N:0]	tb_counter;
	
// INSTANTIATE MODULES UNDER TEST
	counter #(.N(TB_N), .DOWN(TB_DOWN)) 
		counter1( .clk(tb_clk), .oc_val(tb_oc_val), .oc_en(tb_oc_en), .rst_n(tb_rst_n), .en(tb_en), .out(tb_out), .oc_strobe(tb_oc_strobe));



// FUNCTIONAL DESCRIPTION OF TESTBENCH
	//Assignment types
		// can use "assign" for continous assignment
		// can use "always" or "initial" for procedural assignment
			// initial only evaluated at beginning of sim
			// always is evaluated in every sim cycle
	initial begin
		#1;
		tb_clk = 0;
		while (1) begin
			#1;
			tb_clk <= !tb_clk;
			if (tb_clk)
				tb_counter++;
		end
	end
			
	initial begin
		#1;
		tb_counter 		= 0;
		
		tb_oc_val		= 35;
		tb_oc_en		= 1;
		tb_en			= 1;
		tb_rst_n		= 1; //hold out of reset
		
		
		#3;
		tb_rst_n		= 0; //reset counter
		
		#3;
		tb_rst_n		= 1; //pull out of reset


		while (tb_counter < (tb_oc_val + 12)) begin
			#1;
		end
		
		#1; //wait one cycle
		tb_counter=0; //to prevent compiler from removing last sim cycle
		$finish(); //explicitly end simulation
		
	end
	
	initial begin
		$dumpfile("dump.vcd"); 
		$dumpvars;
	end
	
endmodule: counter_tb