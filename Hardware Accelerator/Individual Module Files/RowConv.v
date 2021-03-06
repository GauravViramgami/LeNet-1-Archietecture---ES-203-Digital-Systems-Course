module RowConv(clk, weight, Xin, bias, Xout, Yout);
	input clk;
	input [79:0]weight;
	input [15:0]bias;
	input [15:0]Xin;
	output [15:0]Yout, Xout;

	reg [15:0]PEout[3:0];
	reg [15:0]buffers[13:0];
	
	integer i;
	initial begin
		for(i=0; i<14; i=i+1)
		begin
			buffers[i] = 0;
			if(i < 4)
			begin
				PEout[i] = 0;
			end
		end
	end
	
	always@(posedge clk)
	begin
		buffers[13]  = buffers[8];
		buffers[12]  = buffers[8];
		buffers[11] = buffers[7];
		buffers[10] = buffers[6];
		buffers[9] = buffers[5];
		buffers[8] = buffers[4];
		buffers[7] = buffers[4];
		buffers[6] = buffers[5];
		buffers[5] = buffers[1];
		buffers[4] = buffers[1];
		buffers[3] = buffers[2];
		buffers[2] = buffers[0];
		buffers[1] = Xin;
		buffers[0] = Xin;
	end

	processElement PE0(clk, weight[79:64], buffers[13], 0, PEout[0]);
	processElement PE1(clk, weight[63:48], buffers[12], PEout[0], PEout[1]);
	processElement PE2(clk, weight[47:32], buffers[11], PEout[1], PEout[2]);
	processElement PE3(clk, weight[31:16], buffers[10], PEout[2], PEout[3]);
	processElement PE4(clk, weight[15:0], buffers[9], PEout[3], Yout);
	
	assign Xout = buffers[13];

endmodule
