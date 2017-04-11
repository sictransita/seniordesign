module sqrt_pipelined(
	input clk,
	input [UP:0] x,
	output [UP:0] out_sqrt,
	output [UP:0] out_sqrt_rem
	);

parameter BITS= 8;

parameter UP= BITS-1;

reg [UP:0] root [UP:0];
reg [UP:0] sqrt_rem [UP:0];

reg [UP:0] in_sqrt [UP:0];

`define BOUT (UP)	

assign out_sqrt= root[`BOUT];
assign out_sqrt_rem= sqrt_rem[`BOUT];

always @( posedge clk )
begin:name
	integer ind;

	in_sqrt[0]<= x;
`define MEDI  (64'h0000000000000001<<(BITS-1) )
`define MEDI2 (64'h0000000000000001<<(BITS-1))
	root[0]<=  `MEDI;
	sqrt_rem[0]<= `MEDI2;


	for (ind=0; ind< UP; ind=ind+1)
	begin
		if ( in_sqrt[ind]>sqrt_rem[ind] )
		begin
			root [ind+1]<= root [ind] + (`MEDI>>(ind+1));
			sqrt_rem[ind+1]<= sqrt_rem [ind] + (`MEDI2>>(2*(ind+1))) + ( (root[ind])>>(ind) );
		end
		else
		begin
			root [ind+1]<= root [ind] - (`MEDI>>(ind+1));
			sqrt_rem[ind+1]<= sqrt_rem [ind] + (`MEDI2>>(2*(ind+1))) - ( (root[ind])>>(ind) );
		end
		in_sqrt [ind+1]<= in_sqrt [ind];
	end
end

endmodule
