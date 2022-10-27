//fft_radix2_real module
module fft_radix2_real #(
		log2Ns	= 10, 	// log2(number_of_samples)
		Nbits	= 8		// number of bits per sample
	) (
	input 	logic	[Nbits-1:0] samples_in;
	input	logic				latch_in;
	input	logic				latch_out;
	output 	logic	[Nbits-1:0] samples_out;
	output	logic				sclk
	output	logic				idle;
	);
	
	logic	[Nbits-1:0] samples [0:2**log2Ns-1];
		
		// w = exp(2*pi()*1i / N); 
		function automatic int twiddle (ref integer x[]);
			//if length(x) == 1
			//	return x;
			//else
			//	xe = x(0:2:end);
			//	xo = x(1:2:end);
		endfunction: twiddle
	
	
endmodule: fft_radix2_real


//example recursive behavior
function automatic int factorial (input int a);
  begin
    if (a > 1) begin
      factorial = a * factorial(a - 1);
    end
    else begin
      factorial = 1;
    end
  end
endfunction : factorial


//example recursive behavior
module funct (input [7:0] ip, output reg [7:0] we);

	function automatic [7:0] factorial;
		input [7:0] i_Num;
		begin
		if (i_Num == 1)
			factorial = 1;
		else 
			factorial = i_Num * factorial(i_Num-1); 
		end 
	endfunction

	always @ ip begin 
		we = factorial(ip); 
	end
endmodule



