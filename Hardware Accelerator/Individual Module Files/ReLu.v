////RELU
module ReLU(A,out,clk);
  input [15:0]A;
  input clk;
  output reg [15:0]out;

  always @(clk)
    begin
      if (A[15]==0)
        out=A;
      else
        out=16'b0000000000000000;
    end
endmodule
