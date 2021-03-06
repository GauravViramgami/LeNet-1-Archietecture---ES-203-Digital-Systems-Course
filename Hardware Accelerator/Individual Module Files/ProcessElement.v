module processElement(clk, weight, Xin, Yin, Yout);
	input clk;
	input [15:0]weight;
	input [15:0]Xin, Yin;
	output reg [15:0]Yout;
	
	wire [15:0]multiplied, added;
	FP16_Multiply multiply(.A(weight), .B(Xin), .Out(multiplied));
	FP16_Add add(.A(multiplied), .B(Yin), .Out(added));
	
	always@(posedge clk)
		begin
			Yout <= added;
		end
endmodule
