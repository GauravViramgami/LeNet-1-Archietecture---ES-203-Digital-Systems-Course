////Half Precision Floating Point Multiplier
module FP16_Multiply(A, B, Out);
  input [15:0] A, B;
  output reg [15:0] Out;
  
  reg [4:0] exp;
  reg [10:0] MA, MB;
  reg [21:0] M;
  integer i = 21, j = 9, k;
  
  always @(A, B) begin
    
    //Sign bit
    Out[15] = A[15] ^ B[15]; //Sign bit = XOR of two Sign bits 
    
    //Intermediate exponent
    exp = (A[14:10] + B[14:10] - 5'b01111); //Exponent = Sum of two exponents - bias 
    
    //Mentissa
    MA = 11'b10000000000 + A[9:0]; //Adding MSB = 1
    MB = 11'b10000000000 + B[9:0]; //Adding MSB = 1
    M = MA * MB; //22 Bit multiplication
    
    if(M[0]==1'b1) k=0;
    if(M[1]==1'b1) k=1;
    if(M[2]==1'b1) k=2;
    if(M[3]==1'b1) k=3;
    if(M[4]==1'b1) k=4;
    if(M[5]==1'b1) k=5;
    if(M[6]==1'b1) k=6;
    if(M[7]==1'b1) k=7;
    if(M[8]==1'b1) k=8;
    if(M[9]==1'b1) k=9;
    if(M[10]==1'b1) k=10;
    if(M[11]==1'b1) k=11;
    if(M[12]==1'b1) k=12;
    if(M[13]==1'b1) k=13;
    if(M[14]==1'b1) k=14;
    if(M[15]==1'b1) k=15;
    if(M[16]==1'b1) k=16;
    if(M[17]==1'b1) k=17;
    if(M[18]==1'b1) k=18; 
    if(M[19]==1'b1) k=19;
    if(M[20]==1'b1) k=20;
    if(M[21]==1'b1) k=21;
      
//    while (i >= 0 && M[i] == 1'b0)
//    i = i - 1; //Finding first 1 from MSB
    $display("26");
    i = k;
    
    //Final Exponent
    if (i > 19) exp = exp + (i - 20); //Shifting exponent according to decimal place in mentissa
    else exp = exp - (20 - i);
    Out[14:10] = exp;$display("32");
    
    Out[9]=M[i-1];
    i=i-1;
    Out[8]=M[i-1];
    i=i-1;
    Out[7]=M[i-1];
    i=i-1;
    Out[6]=M[i-1];
    i=i-1;
    Out[5]=M[i-1];
    i=i-1;
    Out[4]=M[i-1];
    i=i-1;
    Out[3]=M[i-1];
    i=i-1;
    Out[2]=M[i-1];
    i=i-1;
    Out[1]=M[i-1];
    i=i-1;
    Out[0]=M[i-1];
    i=i-1;
    //Normalized Mentissa
//    while (j >= 0) begin
//      Out[j] = M[i-1];
//      j = j - 1;
//      i = i - 1;
//    end
    $display("40");
    //Round the Output
    if (k >= 13 && M[k-11] == 1 && (M[k-12] == 1 || M[k-13] == 1)) begin
      Out[9:0] = Out[9:0] + 1;
    end
    $display("45");
  end
endmodule
