module avgPool(clk, Xin, Yout);
	input clk;
	input [15:0]Xin;
	output reg [15:0]Yout;

	wire [15:0]sum;
	reg [15:0]buffers[23:0], temp, j = 16'b0;

	integer i = 0;
	initial begin
		for(i=0; i < 16; i=i+1)
		begin
			buffers[i] = 0;
		end
	end

	integer k = 0;
	
	FP16_Add add(.A(buffers[0]), .B(Xin), .Out(sum));
	
	always @(posedge clk)
	begin
		if(k < 24)
		begin
          if(j == 1)
				begin
					temp = buffers[12];
					buffers[12] = buffers[11];
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
					buffers[1] = sum;
					buffers[0] = temp;
				
					j = 0;
					k = k+1;
				end
			else
				begin
					buffers[0] = sum;
					j = 1;
				end
		end
		else if(k>27)
		begin
			if(k < 52)
			begin
              if(j == 1)
					begin
						temp = buffers[12];
						buffers[12] = buffers[11];
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
						buffers[1] = 0;
						Yout = sum;
						buffers[0] = temp;
				
						j = 0;
						k = k+1;
					end
				else
					begin
						buffers[0] = sum;
						j = 1;
					end
			end
		end
      if(k == 56)
		begin
			k = 0;
		end
	end

endmodule