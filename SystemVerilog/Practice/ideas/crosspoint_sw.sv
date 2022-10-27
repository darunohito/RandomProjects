//crosspoint switch module
module crosspoint_sw #(
	parameter	DATA_WIDTH 	= 1, //MUX width
	parameter	N_INPUTS	= 2, //number of inputs
	parameter	N_OUTPUTS	= 2, //number of outputs
	) (
	input 	logic	[DATA_WIDTH-1:0] 	data_in 	[0:N_INPUTS-1];
	output	logic	[DATA_WIDTH-1:0]	data_out 	[0:N_OUTPUTS-1];

endmodule: crosspoint_sw