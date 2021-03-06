module conv2d(Xin, Xout, Yout, bias, weights, clk);

	input [15:0]Xin;
	input [15:0]bias;
	input [399: 0]weights;
	input clk;
	output [15:0]Yout, Xout;

	reg [15:0]buffers[95:0];
	reg [15:0]sumDelay[4:0], rOut[4:0];
	wire [15:0]sum[5:0];

	integer i;
	initial begin
		for(i=0; i<96; i=i+1)
		begin
			buffers[i] = 0;
			if(i < 5)
			begin
				sumDelay[i] = 0;
			end
		end
	end

	always @(posedge clk)
	begin
		buffers[95] = buffers[94];
		buffers[94] = buffers[93];
		buffers[93] = buffers[92];
		buffers[92] = buffers[91];
		buffers[91] = buffers[90];
		buffers[90] = buffers[89];
		buffers[89] = buffers[88];
		buffers[88] = buffers[87];
		buffers[87] = buffers[86];
		buffers[86] = buffers[85];
		buffers[85] = buffers[84];
		buffers[84] = buffers[83];
		buffers[83] = buffers[82];
		buffers[82] = buffers[81];
		buffers[81] = buffers[80];
		buffers[80] = buffers[79];
		buffers[79] = buffers[78];
		buffers[78] = buffers[77];
		buffers[77] = buffers[76];
		buffers[76] = buffers[75];
		buffers[75] = buffers[74];
		buffers[74] = buffers[73];
		buffers[73] = buffers[72];
		buffers[71] = buffers[70];
		buffers[70] = buffers[69];
		buffers[69] = buffers[68];
		buffers[68] = buffers[67];
		buffers[67] = buffers[66];
		buffers[66] = buffers[65];
		buffers[65] = buffers[64];
		buffers[64] = buffers[63];
		buffers[63] = buffers[62];
		buffers[62] = buffers[61];
		buffers[61] = buffers[60];
		buffers[60] = buffers[59];
		buffers[59] = buffers[58];
		buffers[58] = buffers[57];
		buffers[57] = buffers[56];
		buffers[56] = buffers[55];
		buffers[55] = buffers[54];
		buffers[54] = buffers[53];
		buffers[53] = buffers[52];
		buffers[52] = buffers[51];
		buffers[51] = buffers[50];
		buffers[50] = buffers[49];
		buffers[49] = buffers[48];
		buffers[47] = buffers[46];
		buffers[46] = buffers[45];
		buffers[45] = buffers[44];
		buffers[44] = buffers[43];
		buffers[43] = buffers[42];
		buffers[42] = buffers[41];
		buffers[41] = buffers[40];
		buffers[40] = buffers[39];
		buffers[39] = buffers[38];
		buffers[38] = buffers[37];
		buffers[37] = buffers[36];
		buffers[36] = buffers[35];
		buffers[35] = buffers[34];
		buffers[34] = buffers[33];
		buffers[33] = buffers[32];
		buffers[32] = buffers[31];
		buffers[31] = buffers[30];
		buffers[30] = buffers[29];
		buffers[29] = buffers[28];
		buffers[28] = buffers[27];
		buffers[27] = buffers[26];
		buffers[26] = buffers[25];
		buffers[25] = buffers[24];
		buffers[23] = buffers[22];
		buffers[22] = buffers[21];
		buffers[21] = buffers[20];
		buffers[20] = buffers[19];
		buffers[19] = buffers[18];
		buffers[18] = buffers[17];
		buffers[17] = buffers[16];
		buffers[16] = buffers[15];
		buffers[15] = buffers[14];
		buffers[14] = buffers[13];
		buffers[13] = buffers[12];
		buffers[11] = buffers[10];
		buffers[10] = buffers[9];
		buffers[9] = buffers[8];
		buffers[8] = buffers[7];
		buffers[7] = buffers[6];
		buffers[6] = buffers[5];
		buffers[5] = buffers[4];
		buffers[4] = buffers[3];
		buffers[3] = buffers[2];
		buffers[2] = buffers[1];
		buffers[1] = buffers[0];
 
		sumDelay[0] = sum[0];
		sumDelay[1] = sum[1];
		sumDelay[2] = sum[2];
		sumDelay[3] = rOut[0];
		sumDelay[4] = sumDelay[3];
	end

	RowConv R0(clk, weights[399:320], buffers[95], bias, Xout, rOut[4]);
	RowConv R1(clk, weights[319:240], buffers[71], 16'b0, buffers[72], rOut[3]);
	RowConv R2(clk, weights[239:160], buffers[47], 16'b0, buffers[48], rOut[2]);
	RowConv R3(clk, weights[159:80], buffers[23], 16'b0, buffers[24], rOut[1]);
	RowConv R4(clk, weights[79:0], Xin, 16'b0, buffers[0], rOut[0]);

	FP16_Add add0(.A(rOut[4]), .B(rOut[3]), .Out(sum[0]));
	FP16_Add add1(.A(rOut[2]), .B(rOut[1]), .Out(sum[1]));
	FP16_Add add2(.A(sumDelay[0]), .B(sumDelay[1]), .Out(sum[2]));
	FP16_Add add3(.A(sumDelay[2]), .B(sumDelay[3]), .Out(Yout));
endmodule
