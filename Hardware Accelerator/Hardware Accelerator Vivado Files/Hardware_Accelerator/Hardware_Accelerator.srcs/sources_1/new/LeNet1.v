`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.11.2020 11:32:07
// Design Name: 
// Module Name: LeNet1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module subtractor(
  input [11:0] significand,
  input [4:0] Exponent_a,
  output reg [11:0] Significand,
  output [4:0] Exponent_sub
			);

reg [3:0] shift;

always @(significand)
begin
	casex (significand)
		12'b11xxxxxxxxxx :	begin
          Significand = significand;
          shift = 4'b0000;
        end
		12'b101xxxxxxxxx : 	begin						
          Significand = significand << 1;
          shift = 4'b0001;
        end

		12'b1001xxxxxxxx : 	begin						
          Significand = significand << 2;
          shift = 4'b0010;
        end

		12'b10001xxxxxxx : 	begin 							
          Significand = significand << 3;
          shift = 4'b0011;
        end

		12'b100001xxxxxx : 	begin						
          Significand = significand << 4;
          shift = 4'b0100;
        end

		12'b1000001xxxxx : 	begin						
          Significand = significand << 5;
          shift = 4'b0101;
        end

		12'b10000001xxxx : 	begin						
          Significand = significand << 6;
          shift = 4'b0110;
        end

		12'b100000001xxx : 	begin						
          Significand = significand << 7;
          shift = 4'b0111;
        end

		12'b1000000001xx : 	begin					
          Significand = significand << 8;
          shift = 4'b1000;
        end

		12'b10000000001x : 	begin						
          Significand = significand << 9;
          shift = 4'b1001;
        end

		12'b100000000001 : 	begin						
          Significand = significand << 10;
          shift = 4'b1010;
        end

		
		12'b100000000000 : 	begin					
          Significand = significand << 11;
          shift = 4'b1011;
        end
		default : 	begin
						Significand = (~significand) + 1'b1;
						shift = 4'b0000;
					end

	endcase
end
assign Exponent_sub = Exponent_a - shift;

endmodule

module FP16_Add(A,B,Out);
  input [15:0] A,B;
  output [15:0] Out;
  
  wire exception;
  wire operation_sub_addBar; 
  wire Comp_enable;
  wire sign;

  wire [15:0] operand_a,operand_b;
  wire [10:0] significand_a,significand_b;
  wire [4:0] exponent_diff;

  wire [10:0] significand_b_add_sub;
  wire [4:0] exponent_b_add_sub;

  wire [11:0] significand_add;
  wire [14:0] add_sum;
  
  wire [10:0] significand_sub_complement;
  wire [11:0] significand_sub;
  wire [14:0] sub_diff;
  wire [11:0] subtraction_diff; 
  wire [4:0] exponent_sub;
  
  wire perform;

//for operations always operand_a must not be less than b_operand
  assign {Comp_enable,operand_a,operand_b} = (A[14:0] < B[14:0]) ? {1'b1,B,A} : {1'b0,A,B};
  assign exception = ((&A[14:10]) | (&B[14:10]));//Exception flag sets 1 if either one of the exponent is 255.
  assign sign = operand_a[15];
  assign operation_sub_addBar = ~(operand_a[15]^operand_b[15]) ;

  assign significand_a = (|operand_a[14:10]) ? {1'b1,operand_a[9:0]} : {1'b0,operand_a[9:0]};//If exponent is equal to zero then hidden bit will be 0 for that respective significand else it will be 1
  assign significand_b = (|operand_b[14:10]) ? {1'b1,operand_b[9:0]} : {1'b0,operand_b[9:0]};

  assign exponent_diff = operand_a[14:10] - operand_b[14:10];//Evaluating Exponent Difference

  assign significand_b_add_sub = significand_b >> exponent_diff;//Shifting significand_b according to exponent_diff
  assign exponent_b_add_sub = operand_b[14:10] + exponent_diff;//Shifting significand_b according to exponent_diff

  assign perform = (operand_a[14:10] == exponent_b_add_sub);//Checking exponents are same or not

  assign significand_add = (perform & operation_sub_addBar) ? (significand_a + significand_b_add_sub) : 12'd0; 
  assign add_sum[9:0] = significand_add[11] ? significand_add[10:1] : significand_add[9:0];//Result will be equal to Most 23 bits if carry generates else it will be Least 22 bits.
  assign add_sum[14:10] = significand_add[11] ? (1'b1 + operand_a[14:10]) : operand_a[14:10];//If carry generates in sum value then exponent must be added with 1 else feed as it is.
  
  assign significand_sub_complement = (perform & !operation_sub_addBar) ? ~(significand_b_add_sub) + 11'd1 : 11'd0 ; 

  assign significand_sub = perform ? (significand_a + significand_sub_complement) : 12'd0;

  subtractor sub(significand_sub,operand_a[14:10],subtraction_diff,exponent_sub);

  assign sub_diff[14:10] = exponent_sub;
 
  assign sub_diff[9:0] = subtraction_diff[9:0];

  assign Out = exception ? 16'b0 : ((!operation_sub_addBar) ? {sign,sub_diff} : {sign,add_sum});


endmodule

module FP16_Multiply (A,B,Out);
  input [15:0] A,B;
  output [15:0] Out;
  
  wire sign, product_round,normalized, zero, exception, over, under;
  wire [5:0] exp, sum_exp;
  wire [21:0] product, norm_prod;
  wire [9:0] product_mantissa;
  wire [11:0] operand_a , operand_b;
  
  assign sign = A[15]^B[15];//signbit
  assign exception = ((&A[14:10])|(&B[14:10]));//checking overflow(exp>30)
  assign operand_a = (|A[14:10]) ? {1'b1,A[9:0]} : {1'b0,A[9:0]};//assigning hiddenbit as 0 or 1
  assign operand_b = (|B[14:10]) ? {1'b1,B[9:0]} : {1'b0,B[9:0]};//assigning hiddenbit as 0 or 1
  assign product = operand_a * operand_b;//multiplication of fraction
  assign normalized = product[21] ? 1'b1 : 1'b0;//
  assign norm_prod = normalized ? product : product << 1;
  assign product_round = |norm_prod[9:0];//checking for rounding
  assign product_mantissa = norm_prod[20:11] + (norm_prod[10] & product_round);//rounding mantissa
  assign zero = exception ? 1'b0 : (product_mantissa == 10'd0) ? 1'b1 : 1'b0;
  assign sum_exp = A[14:10] + B[14:10];
  assign exp = sum_exp - 4'd15 + normalized;
  assign over = ((exp[5] & !exp[4]) & !zero);
  assign under = ((exp[5] & exp[4]) & !zero) ? 1'b1 : 1'b0;
  assign Out = exception ? 16'd0 : zero ? {sign, 15'd0} : over ? {sign, 5'b11111, 10'd0} : under ? {sign, 15'd0} : {sign, exp[4:0], product_mantissa};
endmodule

module ReLu(A,Out);
  input [15:0] A;
  output [15:0] Out;

  assign Out = (A[15] == 0)?A:16'b0000000000000000;
endmodule

module Average(A, B, C, D, Out);
  input [15:0] A, B, C, D;
  output [15:0] Out;
  
  wire [15:0] sum1, sum2, sum3; //Intermediate sums
  //wire [4:0] exp; //Exponent
  FP16_Add add1(.A(A), .B(B), .Out(sum1)); //Sum1
  FP16_Add add2(.A(C), .B(D), .Out(sum2)); //Sum2
  FP16_Add add3(.A(sum1), .B(sum2), .Out(sum3)); //Final Sum 
  assign Out[15] = sum3[15]; //Sign bit is same
  assign Out[14:10] = (sum3[14:10] < 2)?5'b00000:sum3[14:10] - 5'b00010; //Exponent is final exponent
  assign Out[9:0] = sum3[9:0]; //Mentissa is same
endmodule

module Average_Relu(A, B, C, D, Out);
  input [15:0] A, B, C, D;
  output [15:0] Out;
  wire [15:0] avg;
  
  wire [15:0] sum1, sum2, sum3; //Intermediate sums
  //wire [4:0] exp; //Exponent
  FP16_Add add1(.A(A), .B(B), .Out(sum1)); //Sum1
  FP16_Add add2(.A(C), .B(D), .Out(sum2)); //Sum2
  FP16_Add add3(.A(sum1), .B(sum2), .Out(sum3)); //Final Sum 
  ReLu relu0 (.A(sum3), .Out(Out));
endmodule

module stackSum (dataIn1, dataIn2, dataIn3, dataIn4, dataOut);
  parameter FP_LENGTH = 16,
      dataIn_Row = 8,
      dataIn_Column = 8;
  
  input [dataIn_Row*dataIn_Column*FP_LENGTH - 1:0] dataIn1, dataIn2, dataIn3, dataIn4;
  output [dataIn_Row*dataIn_Column*FP_LENGTH - 1:0] dataOut;
  
  genvar i;
  generate
    for (i = 0; i < 64; i = i + 1) begin:stack0
      Average_Relu sum0 (.A(dataIn1[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (FP_LENGTH*i) -: FP_LENGTH]),
                         .B(dataIn2[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (FP_LENGTH*i) -: FP_LENGTH]),
                         .C(dataIn3[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (FP_LENGTH*i) -: FP_LENGTH]),
                         .D(dataIn4[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (FP_LENGTH*i) -: FP_LENGTH]),
                         .Out(dataOut[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (FP_LENGTH*i) -: FP_LENGTH]));

    end
  endgenerate
  
endmodule

module kernel (data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, data24, weights, bias, feature);
  parameter FP_LENGTH = 16;
  input [FP_LENGTH - 1:0] data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, data24, bias;
  input [25*FP_LENGTH - 1:0] weights;
  output [FP_LENGTH - 1:0] feature;
  
  wire [FP_LENGTH - 1:0] interMulti0,interMulti1,interMulti2,interMulti3,interMulti4,interMulti5,interMulti6,interMulti7,interMulti8,interMulti9,interMulti10,interMulti11,interMulti12,interMulti13,interMulti14,interMulti15,interMulti16,interMulti17,interMulti18,interMulti19,interMulti20,interMulti21,interMulti22,interMulti23,interMulti24;
  wire [FP_LENGTH - 1:0] interSum0,interSum1,interSum2,interSum3,interSum4,interSum5,interSum6,interSum7,interSum8,interSum9,interSum10,interSum11,interSum12,interSum13,interSum14,interSum15,interSum16,interSum17,interSum18,interSum19,interSum20,interSum21,interSum22,interSum23,interSum24;
  
  FP16_Multiply stage0 (.A(data0), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*0) -: FP_LENGTH]), .Out(interMulti0));
  FP16_Multiply stage1 (.A(data1), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*1) -: FP_LENGTH]), .Out(interMulti1));
  FP16_Multiply stage2 (.A(data2), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*2) -: FP_LENGTH]), .Out(interMulti2));
  FP16_Multiply stage3 (.A(data3), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*3) -: FP_LENGTH]), .Out(interMulti3));
  FP16_Multiply stage4 (.A(data4), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*4) -: FP_LENGTH]), .Out(interMulti4));
  FP16_Multiply stage5 (.A(data5), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*5) -: FP_LENGTH]), .Out(interMulti5));
  FP16_Multiply stage6 (.A(data6), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*6) -: FP_LENGTH]), .Out(interMulti6));
  FP16_Multiply stage7 (.A(data7), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*7) -: FP_LENGTH]), .Out(interMulti7));
  FP16_Multiply stage8 (.A(data8), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*8) -: FP_LENGTH]), .Out(interMulti8));
  FP16_Multiply stage9 (.A(data9), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*9) -: FP_LENGTH]), .Out(interMulti9));
  FP16_Multiply stage10 (.A(data10), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*10) -: FP_LENGTH]), .Out(interMulti10));
  FP16_Multiply stage11 (.A(data11), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*11) -: FP_LENGTH]), .Out(interMulti11));
  FP16_Multiply stage12 (.A(data12), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*12) -: FP_LENGTH]), .Out(interMulti12));
  FP16_Multiply stage13 (.A(data13), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*13) -: FP_LENGTH]), .Out(interMulti13));
  FP16_Multiply stage14 (.A(data14), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*14) -: FP_LENGTH]), .Out(interMulti14));
  FP16_Multiply stage15 (.A(data15), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*15) -: FP_LENGTH]), .Out(interMulti15));
  FP16_Multiply stage16 (.A(data16), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*16) -: FP_LENGTH]), .Out(interMulti16));
  FP16_Multiply stage17 (.A(data17), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*17) -: FP_LENGTH]), .Out(interMulti17));
  FP16_Multiply stage18 (.A(data18), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*18) -: FP_LENGTH]), .Out(interMulti18));
  FP16_Multiply stage19 (.A(data19), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*19) -: FP_LENGTH]), .Out(interMulti19));
  FP16_Multiply stage20 (.A(data20), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*20) -: FP_LENGTH]), .Out(interMulti20));
  FP16_Multiply stage21 (.A(data21), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*21) -: FP_LENGTH]), .Out(interMulti21));
  FP16_Multiply stage22 (.A(data22), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*22) -: FP_LENGTH]), .Out(interMulti22));
  FP16_Multiply stage23 (.A(data23), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*23) -: FP_LENGTH]), .Out(interMulti23));
  FP16_Multiply stage24 (.A(data24), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*24) -: FP_LENGTH]), .Out(interMulti24));
  
  FP16_Add stage25 (.A(interMulti0), .B(interMulti1), .Out(interSum0));
  FP16_Add stage26 (.A(interMulti2), .B(interMulti3), .Out(interSum1));
  FP16_Add stage27 (.A(interMulti4), .B(interMulti5), .Out(interSum2));
  FP16_Add stage28 (.A(interMulti6), .B(interMulti7), .Out(interSum3));
  FP16_Add stage29 (.A(interMulti8), .B(interMulti9), .Out(interSum4));
  FP16_Add stage30 (.A(interMulti10), .B(interMulti11), .Out(interSum5));
  FP16_Add stage31 (.A(interMulti12), .B(interMulti13), .Out(interSum6));
  FP16_Add stage32 (.A(interMulti14), .B(interMulti15), .Out(interSum7));
  FP16_Add stage33 (.A(interMulti16), .B(interMulti17), .Out(interSum8));
  FP16_Add stage34 (.A(interMulti18), .B(interMulti19), .Out(interSum9));
  FP16_Add stage35 (.A(interMulti20), .B(interMulti21), .Out(interSum10));
  FP16_Add stage36 (.A(interMulti22), .B(interMulti23), .Out(interSum11));
  
  FP16_Add stage37 (.A(interSum0), .B(interSum1), .Out(interSum12));
  FP16_Add stage38 (.A(interSum2), .B(interSum3), .Out(interSum13));
  FP16_Add stage39 (.A(interSum4), .B(interSum5), .Out(interSum14));
  FP16_Add stage40 (.A(interSum6), .B(interSum7), .Out(interSum15));
  FP16_Add stage41 (.A(interSum8), .B(interSum9), .Out(interSum16));
  FP16_Add stage42 (.A(interSum10), .B(interSum11), .Out(interSum17));
  
  FP16_Add stage43 (.A(interSum12), .B(interSum13), .Out(interSum18));
  FP16_Add stage44 (.A(interSum14), .B(interSum15), .Out(interSum19));
  FP16_Add stage45 (.A(interSum16), .B(interSum17), .Out(interSum20));
  
  FP16_Add stage46 (.A(interSum18), .B(interSum19), .Out(interSum21));
  FP16_Add stage47 (.A(interMulti24), .B(interSum20), .Out(interSum22));
  
  FP16_Add stage48 (.A(interSum21), .B(interSum22), .Out(interSum23));
  
  FP16_Add stage49 (.A(interSum23), .B(bias), .Out(interSum24));
  
  ReLu stage50 (.A(interSum24), .Out(feature));
  
endmodule

module kernel2 (data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, data24, weights, bias, feature);
  parameter FP_LENGTH = 16;
  input [FP_LENGTH - 1:0] data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, data24, bias;
  input [25*FP_LENGTH - 1:0] weights;
  output [FP_LENGTH - 1:0] feature;
  
  wire [FP_LENGTH - 1:0] interMulti0,interMulti1,interMulti2,interMulti3,interMulti4,interMulti5,interMulti6,interMulti7,interMulti8,interMulti9,interMulti10,interMulti11,interMulti12,interMulti13,interMulti14,interMulti15,interMulti16,interMulti17,interMulti18,interMulti19,interMulti20,interMulti21,interMulti22,interMulti23,interMulti24;
  wire [FP_LENGTH - 1:0] interSum0,interSum1,interSum2,interSum3,interSum4,interSum5,interSum6,interSum7,interSum8,interSum9,interSum10,interSum11,interSum12,interSum13,interSum14,interSum15,interSum16,interSum17,interSum18,interSum19,interSum20,interSum21,interSum22,interSum23;
  
  FP16_Multiply stage0 (.A(data0), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*0) -: FP_LENGTH]), .Out(interMulti0));
  FP16_Multiply stage1 (.A(data1), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*1) -: FP_LENGTH]), .Out(interMulti1));
  FP16_Multiply stage2 (.A(data2), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*2) -: FP_LENGTH]), .Out(interMulti2));
  FP16_Multiply stage3 (.A(data3), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*3) -: FP_LENGTH]), .Out(interMulti3));
  FP16_Multiply stage4 (.A(data4), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*4) -: FP_LENGTH]), .Out(interMulti4));
  FP16_Multiply stage5 (.A(data5), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*5) -: FP_LENGTH]), .Out(interMulti5));
  FP16_Multiply stage6 (.A(data6), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*6) -: FP_LENGTH]), .Out(interMulti6));
  FP16_Multiply stage7 (.A(data7), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*7) -: FP_LENGTH]), .Out(interMulti7));
  FP16_Multiply stage8 (.A(data8), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*8) -: FP_LENGTH]), .Out(interMulti8));
  FP16_Multiply stage9 (.A(data9), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*9) -: FP_LENGTH]), .Out(interMulti9));
  FP16_Multiply stage10 (.A(data10), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*10) -: FP_LENGTH]), .Out(interMulti10));
  FP16_Multiply stage11 (.A(data11), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*11) -: FP_LENGTH]), .Out(interMulti11));
  FP16_Multiply stage12 (.A(data12), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*12) -: FP_LENGTH]), .Out(interMulti12));
  FP16_Multiply stage13 (.A(data13), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*13) -: FP_LENGTH]), .Out(interMulti13));
  FP16_Multiply stage14 (.A(data14), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*14) -: FP_LENGTH]), .Out(interMulti14));
  FP16_Multiply stage15 (.A(data15), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*15) -: FP_LENGTH]), .Out(interMulti15));
  FP16_Multiply stage16 (.A(data16), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*16) -: FP_LENGTH]), .Out(interMulti16));
  FP16_Multiply stage17 (.A(data17), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*17) -: FP_LENGTH]), .Out(interMulti17));
  FP16_Multiply stage18 (.A(data18), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*18) -: FP_LENGTH]), .Out(interMulti18));
  FP16_Multiply stage19 (.A(data19), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*19) -: FP_LENGTH]), .Out(interMulti19));
  FP16_Multiply stage20 (.A(data20), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*20) -: FP_LENGTH]), .Out(interMulti20));
  FP16_Multiply stage21 (.A(data21), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*21) -: FP_LENGTH]), .Out(interMulti21));
  FP16_Multiply stage22 (.A(data22), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*22) -: FP_LENGTH]), .Out(interMulti22));
  FP16_Multiply stage23 (.A(data23), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*23) -: FP_LENGTH]), .Out(interMulti23));
  FP16_Multiply stage24 (.A(data24), .B(weights[25*FP_LENGTH - 1 - (FP_LENGTH*24) -: FP_LENGTH]), .Out(interMulti24));
  
  FP16_Add stage25 (.A(interMulti0), .B(interMulti1), .Out(interSum0));
  FP16_Add stage26 (.A(interMulti2), .B(interMulti3), .Out(interSum1));
  FP16_Add stage27 (.A(interMulti4), .B(interMulti5), .Out(interSum2));
  FP16_Add stage28 (.A(interMulti6), .B(interMulti7), .Out(interSum3));
  FP16_Add stage29 (.A(interMulti8), .B(interMulti9), .Out(interSum4));
  FP16_Add stage30 (.A(interMulti10), .B(interMulti11), .Out(interSum5));
  FP16_Add stage31 (.A(interMulti12), .B(interMulti13), .Out(interSum6));
  FP16_Add stage32 (.A(interMulti14), .B(interMulti15), .Out(interSum7));
  FP16_Add stage33 (.A(interMulti16), .B(interMulti17), .Out(interSum8));
  FP16_Add stage34 (.A(interMulti18), .B(interMulti19), .Out(interSum9));
  FP16_Add stage35 (.A(interMulti20), .B(interMulti21), .Out(interSum10));
  FP16_Add stage36 (.A(interMulti22), .B(interMulti23), .Out(interSum11));
  
  FP16_Add stage37 (.A(interSum0), .B(interSum1), .Out(interSum12));
  FP16_Add stage38 (.A(interSum2), .B(interSum3), .Out(interSum13));
  FP16_Add stage39 (.A(interSum4), .B(interSum5), .Out(interSum14));
  FP16_Add stage40 (.A(interSum6), .B(interSum7), .Out(interSum15));
  FP16_Add stage41 (.A(interSum8), .B(interSum9), .Out(interSum16));
  FP16_Add stage42 (.A(interSum10), .B(interSum11), .Out(interSum17));
  
  FP16_Add stage43 (.A(interSum12), .B(interSum13), .Out(interSum18));
  FP16_Add stage44 (.A(interSum14), .B(interSum15), .Out(interSum19));
  FP16_Add stage45 (.A(interSum16), .B(interSum17), .Out(interSum20));
  
  FP16_Add stage46 (.A(interSum18), .B(interSum19), .Out(interSum21));
  FP16_Add stage47 (.A(interMulti24), .B(interSum20), .Out(interSum22));
  
  FP16_Add stage48 (.A(interSum21), .B(interSum22), .Out(interSum23));
  
  FP16_Add stage49 (.A(interSum23), .B(bias), .Out(feature));
  
endmodule

module rowConv1 (row0, row1, row2, row3, row4, weights, bias, outRow);
  parameter FP_LENGTH = 16,
  	COLIn = 28,
  	COLOut = 24;
  
  input [COLIn*FP_LENGTH - 1:0] row0, row1, row2, row3, row4;
  input [25*FP_LENGTH - 1:0] weights;
  input [FP_LENGTH - 1:0] bias;
  output [COLOut*FP_LENGTH - 1:0] outRow;
  
  genvar i;
  
  generate
  for (i = 0; i < 24; i = i + 1) begin:kernelStage
    kernel k_stage (.data0(row0[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]), 
             .data1(row0[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]), 
             .data2(row0[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]), 
             .data3(row0[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]), 
             .data4(row0[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]), 
             .data5(row1[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]), 
             .data6(row1[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]), 
             .data7(row1[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]),
             .data8(row1[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]),
             .data9(row1[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]),
             .data10(row2[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]),
             .data11(row2[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]),
             .data12(row2[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]),
             .data13(row2[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]),
             .data14(row2[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]),
             .data15(row3[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]),
             .data16(row3[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]),
             .data17(row3[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]),
             .data18(row3[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]),
             .data19(row3[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]),
             .data20(row4[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]),
             .data21(row4[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]),
             .data22(row4[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]),
             .data23(row4[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]),
             .data24(row4[COLIn*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]),
             .weights(weights),
             .bias(bias), 
  			 .feature(outRow[COLOut*FP_LENGTH - 1 - (FP_LENGTH*(i+0))-: FP_LENGTH]));

  end
  endgenerate
endmodule

module conv1 (dataIn, weights, bias, dataOut);
  parameter FP_LENGTH = 16,
  	dataIn_Row = 28,
  	dataIn_Column = 28,
  	dataOut_Row = 24,
  	dataOut_Column = 24;
  
  input [dataIn_Row*dataIn_Column*FP_LENGTH - 1:0] dataIn;
  input [25*FP_LENGTH - 1:0] weights;
  input [FP_LENGTH - 1:0] bias;
  output [dataOut_Row*dataOut_Column*FP_LENGTH - 1:0] dataOut;
  
  genvar i;
  generate
  for (i = 0; i < 24; i = i + 1) begin:rowStage
    rowConv1 r1 (.row0(dataIn[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (dataIn_Row*FP_LENGTH*(i+0)) -: dataIn_Row*FP_LENGTH]),
               .row1(dataIn[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (dataIn_Row*FP_LENGTH*(i+1)) -: dataIn_Row*FP_LENGTH]),
               .row2(dataIn[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (dataIn_Row*FP_LENGTH*(i+2)) -: dataIn_Row*FP_LENGTH]),
               .row3(dataIn[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (dataIn_Row*FP_LENGTH*(i+3)) -: dataIn_Row*FP_LENGTH]),
               .row4(dataIn[dataIn_Row*dataIn_Column*FP_LENGTH - 1 - (dataIn_Row*FP_LENGTH*(i+4)) -: dataIn_Row*FP_LENGTH]),
               .weights(weights),
               .bias(bias),
               .outRow(dataOut[dataOut_Row*dataOut_Column*FP_LENGTH - 1 - (dataOut_Row*FP_LENGTH*(i+0)) -: dataOut_Row*FP_LENGTH]));
  end
  endgenerate
endmodule

module AveragePool_1(data, pool);
  parameter FP_LENGTH=16;
  input [9215:0] data;
  output [2303:0] pool;
  
    Average stage0(data[9215:9200],data[9199:9184],data[8831:8816],data[8815:8800],pool[2303:2288]);
    Average stage32(data[9183:9168],data[9167:9152],data[8799:8784],data[8783:8768],pool[2287:2272]);
    Average stage64(data[9151:9136],data[9135:9120],data[8767:8752],data[8751:8736],pool[2271:2256]);
    Average stage96(data[9119:9104],data[9103:9088],data[8735:8720],data[8719:8704],pool[2255:2240]);
    Average stage128(data[9087:9072],data[9071:9056],data[8703:8688],data[8687:8672],pool[2239:2224]);
    Average stage160(data[9055:9040],data[9039:9024],data[8671:8656],data[8655:8640],pool[2223:2208]);
    Average stage192(data[9023:9008],data[9007:8992],data[8639:8624],data[8623:8608],pool[2207:2192]);
    Average stage224(data[8991:8976],data[8975:8960],data[8607:8592],data[8591:8576],pool[2191:2176]);
    Average stage256(data[8959:8944],data[8943:8928],data[8575:8560],data[8559:8544],pool[2175:2160]);
    Average stage288(data[8927:8912],data[8911:8896],data[8543:8528],data[8527:8512],pool[2159:2144]);
    Average stage320(data[8895:8880],data[8879:8864],data[8511:8496],data[8495:8480],pool[2143:2128]);
    Average stage352(data[8863:8848],data[8847:8832],data[8479:8464],data[8463:8448],pool[2127:2112]);
    Average stage768(data[8447:8432],data[8431:8416],data[8063:8048],data[8047:8032],pool[2111:2096]);
    Average stage800(data[8415:8400],data[8399:8384],data[8031:8016],data[8015:8000],pool[2095:2080]);
    Average stage832(data[8383:8368],data[8367:8352],data[7999:7984],data[7983:7968],pool[2079:2064]);
    Average stage864(data[8351:8336],data[8335:8320],data[7967:7952],data[7951:7936],pool[2063:2048]);
    Average stage896(data[8319:8304],data[8303:8288],data[7935:7920],data[7919:7904],pool[2047:2032]);
    Average stage928(data[8287:8272],data[8271:8256],data[7903:7888],data[7887:7872],pool[2031:2016]);
    Average stage960(data[8255:8240],data[8239:8224],data[7871:7856],data[7855:7840],pool[2015:2000]);
    Average stage992(data[8223:8208],data[8207:8192],data[7839:7824],data[7823:7808],pool[1999:1984]);
    Average stage1024(data[8191:8176],data[8175:8160],data[7807:7792],data[7791:7776],pool[1983:1968]);
    Average stage1056(data[8159:8144],data[8143:8128],data[7775:7760],data[7759:7744],pool[1967:1952]);
    Average stage1088(data[8127:8112],data[8111:8096],data[7743:7728],data[7727:7712],pool[1951:1936]);
    Average stage1120(data[8095:8080],data[8079:8064],data[7711:7696],data[7695:7680],pool[1935:1920]);
    Average stage1536(data[7679:7664],data[7663:7648],data[7295:7280],data[7279:7264],pool[1919:1904]);
    Average stage1568(data[7647:7632],data[7631:7616],data[7263:7248],data[7247:7232],pool[1903:1888]);
    Average stage1600(data[7615:7600],data[7599:7584],data[7231:7216],data[7215:7200],pool[1887:1872]);
    Average stage1632(data[7583:7568],data[7567:7552],data[7199:7184],data[7183:7168],pool[1871:1856]);
    Average stage1664(data[7551:7536],data[7535:7520],data[7167:7152],data[7151:7136],pool[1855:1840]);
    Average stage1696(data[7519:7504],data[7503:7488],data[7135:7120],data[7119:7104],pool[1839:1824]);
    Average stage1728(data[7487:7472],data[7471:7456],data[7103:7088],data[7087:7072],pool[1823:1808]);
    Average stage1760(data[7455:7440],data[7439:7424],data[7071:7056],data[7055:7040],pool[1807:1792]);
    Average stage1792(data[7423:7408],data[7407:7392],data[7039:7024],data[7023:7008],pool[1791:1776]);
    Average stage1824(data[7391:7376],data[7375:7360],data[7007:6992],data[6991:6976],pool[1775:1760]);
    Average stage1856(data[7359:7344],data[7343:7328],data[6975:6960],data[6959:6944],pool[1759:1744]);
    Average stage1888(data[7327:7312],data[7311:7296],data[6943:6928],data[6927:6912],pool[1743:1728]);
    Average stage2304(data[6911:6896],data[6895:6880],data[6527:6512],data[6511:6496],pool[1727:1712]);
    Average stage2336(data[6879:6864],data[6863:6848],data[6495:6480],data[6479:6464],pool[1711:1696]);
    Average stage2368(data[6847:6832],data[6831:6816],data[6463:6448],data[6447:6432],pool[1695:1680]);
    Average stage2400(data[6815:6800],data[6799:6784],data[6431:6416],data[6415:6400],pool[1679:1664]);
    Average stage2432(data[6783:6768],data[6767:6752],data[6399:6384],data[6383:6368],pool[1663:1648]);
    Average stage2464(data[6751:6736],data[6735:6720],data[6367:6352],data[6351:6336],pool[1647:1632]);
    Average stage2496(data[6719:6704],data[6703:6688],data[6335:6320],data[6319:6304],pool[1631:1616]);
    Average stage2528(data[6687:6672],data[6671:6656],data[6303:6288],data[6287:6272],pool[1615:1600]);
    Average stage2560(data[6655:6640],data[6639:6624],data[6271:6256],data[6255:6240],pool[1599:1584]);
    Average stage2592(data[6623:6608],data[6607:6592],data[6239:6224],data[6223:6208],pool[1583:1568]);
    Average stage2624(data[6591:6576],data[6575:6560],data[6207:6192],data[6191:6176],pool[1567:1552]);
    Average stage2656(data[6559:6544],data[6543:6528],data[6175:6160],data[6159:6144],pool[1551:1536]);
    Average stage3072(data[6143:6128],data[6127:6112],data[5759:5744],data[5743:5728],pool[1535:1520]);
    Average stage3104(data[6111:6096],data[6095:6080],data[5727:5712],data[5711:5696],pool[1519:1504]);
    Average stage3136(data[6079:6064],data[6063:6048],data[5695:5680],data[5679:5664],pool[1503:1488]);
    Average stage3168(data[6047:6032],data[6031:6016],data[5663:5648],data[5647:5632],pool[1487:1472]);
    Average stage3200(data[6015:6000],data[5999:5984],data[5631:5616],data[5615:5600],pool[1471:1456]);
    Average stage3232(data[5983:5968],data[5967:5952],data[5599:5584],data[5583:5568],pool[1455:1440]);
    Average stage3264(data[5951:5936],data[5935:5920],data[5567:5552],data[5551:5536],pool[1439:1424]);
    Average stage3296(data[5919:5904],data[5903:5888],data[5535:5520],data[5519:5504],pool[1423:1408]);
    Average stage3328(data[5887:5872],data[5871:5856],data[5503:5488],data[5487:5472],pool[1407:1392]);
    Average stage3360(data[5855:5840],data[5839:5824],data[5471:5456],data[5455:5440],pool[1391:1376]);
    Average stage3392(data[5823:5808],data[5807:5792],data[5439:5424],data[5423:5408],pool[1375:1360]);
    Average stage3424(data[5791:5776],data[5775:5760],data[5407:5392],data[5391:5376],pool[1359:1344]);
    Average stage3840(data[5375:5360],data[5359:5344],data[4991:4976],data[4975:4960],pool[1343:1328]);
    Average stage3872(data[5343:5328],data[5327:5312],data[4959:4944],data[4943:4928],pool[1327:1312]);
    Average stage3904(data[5311:5296],data[5295:5280],data[4927:4912],data[4911:4896],pool[1311:1296]);
    Average stage3936(data[5279:5264],data[5263:5248],data[4895:4880],data[4879:4864],pool[1295:1280]);
    Average stage3968(data[5247:5232],data[5231:5216],data[4863:4848],data[4847:4832],pool[1279:1264]);
    Average stage4000(data[5215:5200],data[5199:5184],data[4831:4816],data[4815:4800],pool[1263:1248]);
    Average stage4032(data[5183:5168],data[5167:5152],data[4799:4784],data[4783:4768],pool[1247:1232]);
    Average stage4064(data[5151:5136],data[5135:5120],data[4767:4752],data[4751:4736],pool[1231:1216]);
    Average stage4096(data[5119:5104],data[5103:5088],data[4735:4720],data[4719:4704],pool[1215:1200]);
    Average stage4128(data[5087:5072],data[5071:5056],data[4703:4688],data[4687:4672],pool[1199:1184]);
    Average stage4160(data[5055:5040],data[5039:5024],data[4671:4656],data[4655:4640],pool[1183:1168]);
    Average stage4192(data[5023:5008],data[5007:4992],data[4639:4624],data[4623:4608],pool[1167:1152]);
    Average stage4608(data[4607:4592],data[4591:4576],data[4223:4208],data[4207:4192],pool[1151:1136]);
    Average stage4640(data[4575:4560],data[4559:4544],data[4191:4176],data[4175:4160],pool[1135:1120]);
    Average stage4672(data[4543:4528],data[4527:4512],data[4159:4144],data[4143:4128],pool[1119:1104]);
    Average stage4704(data[4511:4496],data[4495:4480],data[4127:4112],data[4111:4096],pool[1103:1088]);
    Average stage4736(data[4479:4464],data[4463:4448],data[4095:4080],data[4079:4064],pool[1087:1072]);
    Average stage4768(data[4447:4432],data[4431:4416],data[4063:4048],data[4047:4032],pool[1071:1056]);
    Average stage4800(data[4415:4400],data[4399:4384],data[4031:4016],data[4015:4000],pool[1055:1040]);
    Average stage4832(data[4383:4368],data[4367:4352],data[3999:3984],data[3983:3968],pool[1039:1024]);
    Average stage4864(data[4351:4336],data[4335:4320],data[3967:3952],data[3951:3936],pool[1023:1008]);
    Average stage4896(data[4319:4304],data[4303:4288],data[3935:3920],data[3919:3904],pool[1007:992]);
    Average stage4928(data[4287:4272],data[4271:4256],data[3903:3888],data[3887:3872],pool[991:976]);
    Average stage4960(data[4255:4240],data[4239:4224],data[3871:3856],data[3855:3840],pool[975:960]);
    Average stage5376(data[3839:3824],data[3823:3808],data[3455:3440],data[3439:3424],pool[959:944]);
    Average stage5408(data[3807:3792],data[3791:3776],data[3423:3408],data[3407:3392],pool[943:928]);
    Average stage5440(data[3775:3760],data[3759:3744],data[3391:3376],data[3375:3360],pool[927:912]);
    Average stage5472(data[3743:3728],data[3727:3712],data[3359:3344],data[3343:3328],pool[911:896]);
    Average stage5504(data[3711:3696],data[3695:3680],data[3327:3312],data[3311:3296],pool[895:880]);
    Average stage5536(data[3679:3664],data[3663:3648],data[3295:3280],data[3279:3264],pool[879:864]);
    Average stage5568(data[3647:3632],data[3631:3616],data[3263:3248],data[3247:3232],pool[863:848]);
    Average stage5600(data[3615:3600],data[3599:3584],data[3231:3216],data[3215:3200],pool[847:832]);
    Average stage5632(data[3583:3568],data[3567:3552],data[3199:3184],data[3183:3168],pool[831:816]);
    Average stage5664(data[3551:3536],data[3535:3520],data[3167:3152],data[3151:3136],pool[815:800]);
    Average stage5696(data[3519:3504],data[3503:3488],data[3135:3120],data[3119:3104],pool[799:784]);
    Average stage5728(data[3487:3472],data[3471:3456],data[3103:3088],data[3087:3072],pool[783:768]);
    Average stage6144(data[3071:3056],data[3055:3040],data[2687:2672],data[2671:2656],pool[767:752]);
    Average stage6176(data[3039:3024],data[3023:3008],data[2655:2640],data[2639:2624],pool[751:736]);
    Average stage6208(data[3007:2992],data[2991:2976],data[2623:2608],data[2607:2592],pool[735:720]);
    Average stage6240(data[2975:2960],data[2959:2944],data[2591:2576],data[2575:2560],pool[719:704]);
    Average stage6272(data[2943:2928],data[2927:2912],data[2559:2544],data[2543:2528],pool[703:688]);
    Average stage6304(data[2911:2896],data[2895:2880],data[2527:2512],data[2511:2496],pool[687:672]);
    Average stage6336(data[2879:2864],data[2863:2848],data[2495:2480],data[2479:2464],pool[671:656]);
    Average stage6368(data[2847:2832],data[2831:2816],data[2463:2448],data[2447:2432],pool[655:640]);
    Average stage6400(data[2815:2800],data[2799:2784],data[2431:2416],data[2415:2400],pool[639:624]);
    Average stage6432(data[2783:2768],data[2767:2752],data[2399:2384],data[2383:2368],pool[623:608]);
    Average stage6464(data[2751:2736],data[2735:2720],data[2367:2352],data[2351:2336],pool[607:592]);
    Average stage6496(data[2719:2704],data[2703:2688],data[2335:2320],data[2319:2304],pool[591:576]);
    Average stage6912(data[2303:2288],data[2287:2272],data[1919:1904],data[1903:1888],pool[575:560]);
    Average stage6944(data[2271:2256],data[2255:2240],data[1887:1872],data[1871:1856],pool[559:544]);
    Average stage6976(data[2239:2224],data[2223:2208],data[1855:1840],data[1839:1824],pool[543:528]);
    Average stage7008(data[2207:2192],data[2191:2176],data[1823:1808],data[1807:1792],pool[527:512]);
    Average stage7040(data[2175:2160],data[2159:2144],data[1791:1776],data[1775:1760],pool[511:496]);
    Average stage7072(data[2143:2128],data[2127:2112],data[1759:1744],data[1743:1728],pool[495:480]);
    Average stage7104(data[2111:2096],data[2095:2080],data[1727:1712],data[1711:1696],pool[479:464]);
    Average stage7136(data[2079:2064],data[2063:2048],data[1695:1680],data[1679:1664],pool[463:448]);
    Average stage7168(data[2047:2032],data[2031:2016],data[1663:1648],data[1647:1632],pool[447:432]);
    Average stage7200(data[2015:2000],data[1999:1984],data[1631:1616],data[1615:1600],pool[431:416]);
    Average stage7232(data[1983:1968],data[1967:1952],data[1599:1584],data[1583:1568],pool[415:400]);
    Average stage7264(data[1951:1936],data[1935:1920],data[1567:1552],data[1551:1536],pool[399:384]);
    Average stage7680(data[1535:1520],data[1519:1504],data[1151:1136],data[1135:1120],pool[383:368]);
    Average stage7712(data[1503:1488],data[1487:1472],data[1119:1104],data[1103:1088],pool[367:352]);
    Average stage7744(data[1471:1456],data[1455:1440],data[1087:1072],data[1071:1056],pool[351:336]);
    Average stage7776(data[1439:1424],data[1423:1408],data[1055:1040],data[1039:1024],pool[335:320]);
    Average stage7808(data[1407:1392],data[1391:1376],data[1023:1008],data[1007:992],pool[319:304]);
    Average stage7840(data[1375:1360],data[1359:1344],data[991:976],data[975:960],pool[303:288]);
    Average stage7872(data[1343:1328],data[1327:1312],data[959:944],data[943:928],pool[287:272]);
    Average stage7904(data[1311:1296],data[1295:1280],data[927:912],data[911:896],pool[271:256]);
    Average stage7936(data[1279:1264],data[1263:1248],data[895:880],data[879:864],pool[255:240]);
    Average stage7968(data[1247:1232],data[1231:1216],data[863:848],data[847:832],pool[239:224]);
    Average stage8000(data[1215:1200],data[1199:1184],data[831:816],data[815:800],pool[223:208]);
    Average stage8032(data[1183:1168],data[1167:1152],data[799:784],data[783:768],pool[207:192]);
    Average stage8448(data[767:752],data[751:736],data[383:368],data[367:352],pool[191:176]);
    Average stage8480(data[735:720],data[719:704],data[351:336],data[335:320],pool[175:160]);
    Average stage8512(data[703:688],data[687:672],data[319:304],data[303:288],pool[159:144]);
    Average stage8544(data[671:656],data[655:640],data[287:272],data[271:256],pool[143:128]);
    Average stage8576(data[639:624],data[623:608],data[255:240],data[239:224],pool[127:112]);
    Average stage8608(data[607:592],data[591:576],data[223:208],data[207:192],pool[111:96]);
    Average stage8640(data[575:560],data[559:544],data[191:176],data[175:160],pool[95:80]);
    Average stage8672(data[543:528],data[527:512],data[159:144],data[143:128],pool[79:64]);
    Average stage8704(data[511:496],data[495:480],data[127:112],data[111:96],pool[63:48]);
    Average stage8736(data[479:464],data[463:448],data[95:80],data[79:64],pool[47:32]);
    Average stage8768(data[447:432],data[431:416],data[63:48],data[47:32],pool[31:16]);
    Average stage8800(data[415:400],data[399:384],data[31:16],data[15:0],pool[15:0]);
endmodule

module rowConv2 (row0, row1, row2, row3, row4, weights, bias, outRow);
  parameter FP_LENGTH = 16,
  	col_in = 12,
  	col_out = 8;
  
  input [col_in*FP_LENGTH - 1:0] row0, row1, row2, row3, row4;
  input [25*FP_LENGTH - 1:0] weights;
  input [FP_LENGTH - 1:0] bias;
  output [col_out*FP_LENGTH - 1:0] outRow;
  
  genvar i;
  generate
  for (i = 0; i < 8; i = i + 1) begin:kernel2Stage
    kernel2 k00 (.data0(row0[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]), 
             .data1(row0[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]), 
             .data2(row0[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]), 
             .data3(row0[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]), 
             .data4(row0[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]), 
             .data5(row1[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]), 
             .data6(row1[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]), 
             .data7(row1[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]),
             .data8(row1[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]),
             .data9(row1[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]),
             .data10(row2[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]),
             .data11(row2[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]),
             .data12(row2[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]),
             .data13(row2[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]),
             .data14(row2[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]),
             .data15(row3[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]),
             .data16(row3[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]),
             .data17(row3[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]),
             .data18(row3[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]),
             .data19(row3[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]),
             .data20(row4[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+0)) -: FP_LENGTH]),
             .data21(row4[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+1)) -: FP_LENGTH]),
             .data22(row4[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+2)) -: FP_LENGTH]),
             .data23(row4[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+3)) -: FP_LENGTH]),
             .data24(row4[col_in*FP_LENGTH - 1 - (FP_LENGTH*(i+4)) -: FP_LENGTH]),
             .weights(weights),
             .bias(bias),
  			 .feature(outRow[col_out*FP_LENGTH - 1 - (FP_LENGTH*(i+0))-: FP_LENGTH]));
  end
  endgenerate
endmodule

module conv2 (dataIn, weights, bias, dataOut);
  parameter FP_LENGTH = 16,
  	datainrow = 12,
  	dataincol = 12,
  	dataoutrow = 8,
  	dataoutcol = 8;
  
  input [datainrow*dataincol*FP_LENGTH - 1:0] dataIn;
  input [25*FP_LENGTH - 1:0] weights;
  input [FP_LENGTH - 1:0] bias;
  output [dataoutrow*dataoutcol*FP_LENGTH - 1:0] dataOut;
  
  genvar i;
  generate
  for (i = 0; i < 8; i = i + 1) begin:row2Stage
    rowConv2 r1 (.row0(dataIn[datainrow*dataincol*FP_LENGTH - 1 - (datainrow*FP_LENGTH*(i+0)) -: datainrow*FP_LENGTH]),
               .row1(dataIn[datainrow*dataincol*FP_LENGTH - 1 - (datainrow*FP_LENGTH*(i+1)) -: datainrow*FP_LENGTH]),
               .row2(dataIn[datainrow*dataincol*FP_LENGTH - 1 - (datainrow*FP_LENGTH*(i+2)) -: datainrow*FP_LENGTH]),
               .row3(dataIn[datainrow*dataincol*FP_LENGTH - 1 - (datainrow*FP_LENGTH*(i+3)) -: datainrow*FP_LENGTH]),
               .row4(dataIn[datainrow*dataincol*FP_LENGTH - 1 - (datainrow*FP_LENGTH*(i+4)) -: datainrow*FP_LENGTH]),
               .weights(weights),
               .bias(bias),
               .outRow(dataOut[dataoutrow*dataoutcol*FP_LENGTH - 1 - (dataoutrow*FP_LENGTH*(i+0)) -: dataoutrow*FP_LENGTH]));
  end
  endgenerate
endmodule

module conv2_feature (dataIn1, dataIn2, dataIn3, dataIn4, weights, bias, dataOut);
  parameter FP_LENGTH = 16,
      datainrowf = 12,
      dataincolf = 12,
      dataoutrowf = 8,
      dataoutcolf = 8;
  
  input [datainrowf*dataincolf*FP_LENGTH - 1:0] dataIn1, dataIn2, dataIn3, dataIn4;
  input [100*FP_LENGTH - 1:0] weights;
  input [FP_LENGTH - 1:0] bias;
  output [dataoutrowf*dataoutcolf*FP_LENGTH - 1:0] dataOut;
  
  wire [dataoutrowf*dataoutcolf*FP_LENGTH - 1:0] feature1, feature2, feature3, feature4;
  
  conv2 f1 (.dataIn(dataIn1),
            .weights(weights[100*FP_LENGTH - 1 - (25*FP_LENGTH*0) -: 25*FP_LENGTH]),
            .bias(16'b0000000000000000),
            .dataOut(feature1));
  
  conv2 f2 (.dataIn(dataIn2),
            .weights(weights[100*FP_LENGTH - 1 - (25*FP_LENGTH*1) -: 25*FP_LENGTH]),
            .bias(16'b0000000000000000),
            .dataOut(feature2));
  
  conv2 f3 (.dataIn(dataIn3),
            .weights(weights[100*FP_LENGTH - 1 - (25*FP_LENGTH*2) -: 25*FP_LENGTH]),
            .bias(16'b0000000000000000),
            .dataOut(feature3));
  
  conv2 f4 (.dataIn(dataIn4),
            .weights(weights[100*FP_LENGTH - 1 - (25*FP_LENGTH*3) -: 25*FP_LENGTH]),
            .bias(bias),
            .dataOut(feature4));
  
  stackSum sum0 (.dataIn1(feature1),
                 .dataIn2(feature2),
                 .dataIn3(feature3),
                 .dataIn4(feature4),
                 .dataOut(dataOut));
                 
  
endmodule

module AveragePool_2(data, pool);
  input [1023:0] data;
  output [255:0] pool;

    Average stage0(data[1023:1008],data[1007:992],data[895:880],data[879:864],pool[255:240]);
    Average stage32(data[991:976],data[975:960],data[863:848],data[847:832],pool[239:224]);
    Average stage64(data[959:944],data[943:928],data[831:816],data[815:800],pool[223:208]);
    Average stage96(data[927:912],data[911:896],data[799:784],data[783:768],pool[207:192]);
    Average stage256(data[767:752],data[751:736],data[639:624],data[623:608],pool[191:176]);
    Average stage288(data[735:720],data[719:704],data[607:592],data[591:576],pool[175:160]);
    Average stage320(data[703:688],data[687:672],data[575:560],data[559:544],pool[159:144]);
    Average stage352(data[671:656],data[655:640],data[543:528],data[527:512],pool[143:128]);
    Average stage512(data[511:496],data[495:480],data[383:368],data[367:352],pool[127:112]);
    Average stage544(data[479:464],data[463:448],data[351:336],data[335:320],pool[111:96]);
    Average stage576(data[447:432],data[431:416],data[319:304],data[303:288],pool[95:80]);
    Average stage608(data[415:400],data[399:384],data[287:272],data[271:256],pool[79:64]);
    Average stage768(data[255:240],data[239:224],data[127:112],data[111:96],pool[63:48]);
    Average stage800(data[223:208],data[207:192],data[95:80],data[79:64],pool[47:32]);
    Average stage832(data[191:176],data[175:160],data[63:48],data[47:32],pool[31:16]);
    Average stage864(data[159:144],data[143:128],data[31:16],data[15:0],pool[15:0]);
  
endmodule

module processElement (Xin, weight, bias, Yout);
  parameter FP_LENGTH = 16;
  
  input [FP_LENGTH - 1:0] Xin, weight, bias;
  output [FP_LENGTH - 1:0] Yout;
	
  wire [FP_LENGTH - 1:0] multiplied;
  FP16_Multiply multiply(.A(weight), .B(Xin), .Out(multiplied));
  FP16_Add add(.A(multiplied), .B(bias), .Out(Yout));
	
endmodule

module FCLayer(data,
              weights,
              bias1,
              result);
  
  parameter WEIGHTS = 192,
  	  FP_LENGTH = 16;
  
  input [WEIGHTS*FP_LENGTH - 1:0] data, weights;
  input [FP_LENGTH - 1:0] bias1;
  output [FP_LENGTH - 1:0] result;
  
  wire [WEIGHTS*FP_LENGTH - 1:0] Yout, interBias;
  
  processElement pelement0 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*0 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*0 -: 16]), .bias(bias1), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*0 -: 16]));
  FP16_Add interSum0 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*0 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*0 -: 16]));
  processElement pelement1 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*1 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*1 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*0 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*1 -: 16]));
  FP16_Add interSum1 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*1 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*1 -: 16]));
  processElement pelement2 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*2 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*2 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*1 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*2 -: 16]));
  FP16_Add interSum2 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*2 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*2 -: 16]));
  processElement pelement3 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*3 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*3 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*2 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*3 -: 16]));
  FP16_Add interSum3 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*3 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*3 -: 16]));
  processElement pelement4 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*4 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*4 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*3 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*4 -: 16]));
  FP16_Add interSum4 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*4 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*4 -: 16]));
  processElement pelement5 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*5 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*5 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*4 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*5 -: 16]));
  FP16_Add interSum5 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*5 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*5 -: 16]));
  processElement pelement6 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*6 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*6 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*5 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*6 -: 16]));
  FP16_Add interSum6 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*6 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*6 -: 16]));
  processElement pelement7 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*7 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*7 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*6 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*7 -: 16]));
  FP16_Add interSum7 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*7 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*7 -: 16]));
  processElement pelement8 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*8 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*8 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*7 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*8 -: 16]));
  FP16_Add interSum8 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*8 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*8 -: 16]));
  processElement pelement9 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*9 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*9 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*8 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*9 -: 16]));
  FP16_Add interSum9 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*9 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*9 -: 16]));
  processElement pelement10 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*10 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*10 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*9 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*10 -: 16]));
  FP16_Add interSum10 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*10 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*10 -: 16]));
  processElement pelement11 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*11 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*11 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*10 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*11 -: 16]));
  FP16_Add interSum11 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*11 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*11 -: 16]));
  processElement pelement12 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*12 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*12 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*11 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*12 -: 16]));
  FP16_Add interSum12 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*12 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*12 -: 16]));
  processElement pelement13 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*13 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*13 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*12 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*13 -: 16]));
  FP16_Add interSum13 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*13 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*13 -: 16]));
  processElement pelement14 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*14 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*14 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*13 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*14 -: 16]));
  FP16_Add interSum14 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*14 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*14 -: 16]));
  processElement pelement15 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*15 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*15 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*14 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*15 -: 16]));
  FP16_Add interSum15 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*15 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*15 -: 16]));
  processElement pelement16 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*16 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*16 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*15 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*16 -: 16]));
  FP16_Add interSum16 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*16 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*16 -: 16]));
  processElement pelement17 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*17 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*17 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*16 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*17 -: 16]));
  FP16_Add interSum17 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*17 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*17 -: 16]));
  processElement pelement18 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*18 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*18 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*17 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*18 -: 16]));
  FP16_Add interSum18 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*18 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*18 -: 16]));
  processElement pelement19 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*19 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*19 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*18 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*19 -: 16]));
  FP16_Add interSum19 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*19 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*19 -: 16]));
  processElement pelement20 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*20 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*20 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*19 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*20 -: 16]));
  FP16_Add interSum20 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*20 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*20 -: 16]));
  processElement pelement21 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*21 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*21 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*20 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*21 -: 16]));
  FP16_Add interSum21 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*21 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*21 -: 16]));
  processElement pelement22 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*22 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*22 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*21 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*22 -: 16]));
  FP16_Add interSum22 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*22 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*22 -: 16]));
  processElement pelement23 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*23 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*23 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*22 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*23 -: 16]));
  FP16_Add interSum23 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*23 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*23 -: 16]));
  processElement pelement24 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*24 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*24 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*23 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*24 -: 16]));
  FP16_Add interSum24 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*24 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*24 -: 16]));
  processElement pelement25 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*25 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*25 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*24 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*25 -: 16]));
  FP16_Add interSum25 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*25 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*25 -: 16]));
  processElement pelement26 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*26 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*26 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*25 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*26 -: 16]));
  FP16_Add interSum26 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*26 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*26 -: 16]));
  processElement pelement27 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*27 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*27 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*26 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*27 -: 16]));
  FP16_Add interSum27 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*27 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*27 -: 16]));
  processElement pelement28 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*28 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*28 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*27 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*28 -: 16]));
  FP16_Add interSum28 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*28 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*28 -: 16]));
  processElement pelement29 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*29 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*29 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*28 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*29 -: 16]));
  FP16_Add interSum29 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*29 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*29 -: 16]));
  processElement pelement30 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*30 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*30 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*29 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*30 -: 16]));
  FP16_Add interSum30 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*30 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*30 -: 16]));
  processElement pelement31 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*31 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*31 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*30 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*31 -: 16]));
  FP16_Add interSum31 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*31 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*31 -: 16]));
  processElement pelement32 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*32 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*32 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*31 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*32 -: 16]));
  FP16_Add interSum32 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*32 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*32 -: 16]));
  processElement pelement33 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*33 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*33 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*32 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*33 -: 16]));
  FP16_Add interSum33 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*33 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*33 -: 16]));
  processElement pelement34 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*34 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*34 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*33 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*34 -: 16]));
  FP16_Add interSum34 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*34 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*34 -: 16]));
  processElement pelement35 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*35 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*35 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*34 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*35 -: 16]));
  FP16_Add interSum35 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*35 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*35 -: 16]));
  processElement pelement36 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*36 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*36 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*35 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*36 -: 16]));
  FP16_Add interSum36 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*36 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*36 -: 16]));
  processElement pelement37 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*37 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*37 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*36 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*37 -: 16]));
  FP16_Add interSum37 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*37 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*37 -: 16]));
  processElement pelement38 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*38 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*38 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*37 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*38 -: 16]));
  FP16_Add interSum38 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*38 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*38 -: 16]));
  processElement pelement39 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*39 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*39 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*38 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*39 -: 16]));
  FP16_Add interSum39 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*39 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*39 -: 16]));
  processElement pelement40 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*40 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*40 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*39 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*40 -: 16]));
  FP16_Add interSum40 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*40 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*40 -: 16]));
  processElement pelement41 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*41 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*41 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*40 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*41 -: 16]));
  FP16_Add interSum41 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*41 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*41 -: 16]));
  processElement pelement42 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*42 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*42 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*41 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*42 -: 16]));
  FP16_Add interSum42 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*42 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*42 -: 16]));
  processElement pelement43 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*43 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*43 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*42 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*43 -: 16]));
  FP16_Add interSum43 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*43 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*43 -: 16]));
  processElement pelement44 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*44 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*44 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*43 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*44 -: 16]));
  FP16_Add interSum44 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*44 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*44 -: 16]));
  processElement pelement45 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*45 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*45 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*44 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*45 -: 16]));
  FP16_Add interSum45 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*45 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*45 -: 16]));
  processElement pelement46 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*46 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*46 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*45 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*46 -: 16]));
  FP16_Add interSum46 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*46 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*46 -: 16]));
  processElement pelement47 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*47 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*47 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*46 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*47 -: 16]));
  FP16_Add interSum47 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*47 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*47 -: 16]));
  processElement pelement48 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*48 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*48 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*47 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*48 -: 16]));
  FP16_Add interSum48 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*48 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*48 -: 16]));
  processElement pelement49 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*49 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*49 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*48 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*49 -: 16]));
  FP16_Add interSum49 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*49 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*49 -: 16]));
  processElement pelement50 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*50 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*50 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*49 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*50 -: 16]));
  FP16_Add interSum50 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*50 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*50 -: 16]));
  processElement pelement51 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*51 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*51 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*50 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*51 -: 16]));
  FP16_Add interSum51 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*51 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*51 -: 16]));
  processElement pelement52 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*52 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*52 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*51 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*52 -: 16]));
  FP16_Add interSum52 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*52 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*52 -: 16]));
  processElement pelement53 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*53 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*53 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*52 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*53 -: 16]));
  FP16_Add interSum53 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*53 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*53 -: 16]));
  processElement pelement54 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*54 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*54 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*53 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*54 -: 16]));
  FP16_Add interSum54 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*54 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*54 -: 16]));
  processElement pelement55 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*55 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*55 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*54 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*55 -: 16]));
  FP16_Add interSum55 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*55 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*55 -: 16]));
  processElement pelement56 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*56 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*56 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*55 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*56 -: 16]));
  FP16_Add interSum56 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*56 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*56 -: 16]));
  processElement pelement57 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*57 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*57 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*56 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*57 -: 16]));
  FP16_Add interSum57 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*57 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*57 -: 16]));
  processElement pelement58 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*58 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*58 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*57 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*58 -: 16]));
  FP16_Add interSum58 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*58 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*58 -: 16]));
  processElement pelement59 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*59 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*59 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*58 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*59 -: 16]));
  FP16_Add interSum59 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*59 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*59 -: 16]));
  processElement pelement60 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*60 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*60 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*59 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*60 -: 16]));
  FP16_Add interSum60 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*60 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*60 -: 16]));
  processElement pelement61 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*61 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*61 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*60 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*61 -: 16]));
  FP16_Add interSum61 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*61 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*61 -: 16]));
  processElement pelement62 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*62 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*62 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*61 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*62 -: 16]));
  FP16_Add interSum62 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*62 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*62 -: 16]));
  processElement pelement63 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*63 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*63 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*62 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*63 -: 16]));
  FP16_Add interSum63 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*63 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*63 -: 16]));
  processElement pelement64 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*64 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*64 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*63 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*64 -: 16]));
  FP16_Add interSum64 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*64 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*64 -: 16]));
  processElement pelement65 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*65 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*65 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*64 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*65 -: 16]));
  FP16_Add interSum65 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*65 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*65 -: 16]));
  processElement pelement66 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*66 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*66 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*65 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*66 -: 16]));
  FP16_Add interSum66 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*66 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*66 -: 16]));
  processElement pelement67 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*67 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*67 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*66 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*67 -: 16]));
  FP16_Add interSum67 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*67 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*67 -: 16]));
  processElement pelement68 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*68 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*68 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*67 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*68 -: 16]));
  FP16_Add interSum68 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*68 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*68 -: 16]));
  processElement pelement69 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*69 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*69 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*68 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*69 -: 16]));
  FP16_Add interSum69 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*69 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*69 -: 16]));
  processElement pelement70 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*70 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*70 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*69 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*70 -: 16]));
  FP16_Add interSum70 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*70 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*70 -: 16]));
  processElement pelement71 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*71 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*71 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*70 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*71 -: 16]));
  FP16_Add interSum71 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*71 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*71 -: 16]));
  processElement pelement72 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*72 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*72 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*71 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*72 -: 16]));
  FP16_Add interSum72 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*72 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*72 -: 16]));
  processElement pelement73 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*73 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*73 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*72 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*73 -: 16]));
  FP16_Add interSum73 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*73 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*73 -: 16]));
  processElement pelement74 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*74 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*74 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*73 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*74 -: 16]));
  FP16_Add interSum74 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*74 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*74 -: 16]));
  processElement pelement75 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*75 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*75 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*74 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*75 -: 16]));
  FP16_Add interSum75 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*75 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*75 -: 16]));
  processElement pelement76 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*76 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*76 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*75 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*76 -: 16]));
  FP16_Add interSum76 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*76 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*76 -: 16]));
  processElement pelement77 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*77 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*77 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*76 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*77 -: 16]));
  FP16_Add interSum77 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*77 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*77 -: 16]));
  processElement pelement78 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*78 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*78 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*77 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*78 -: 16]));
  FP16_Add interSum78 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*78 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*78 -: 16]));
  processElement pelement79 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*79 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*79 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*78 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*79 -: 16]));
  FP16_Add interSum79 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*79 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*79 -: 16]));
  processElement pelement80 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*80 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*80 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*79 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*80 -: 16]));
  FP16_Add interSum80 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*80 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*80 -: 16]));
  processElement pelement81 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*81 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*81 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*80 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*81 -: 16]));
  FP16_Add interSum81 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*81 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*81 -: 16]));
  processElement pelement82 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*82 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*82 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*81 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*82 -: 16]));
  FP16_Add interSum82 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*82 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*82 -: 16]));
  processElement pelement83 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*83 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*83 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*82 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*83 -: 16]));
  FP16_Add interSum83 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*83 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*83 -: 16]));
  processElement pelement84 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*84 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*84 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*83 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*84 -: 16]));
  FP16_Add interSum84 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*84 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*84 -: 16]));
  processElement pelement85 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*85 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*85 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*84 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*85 -: 16]));
  FP16_Add interSum85 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*85 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*85 -: 16]));
  processElement pelement86 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*86 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*86 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*85 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*86 -: 16]));
  FP16_Add interSum86 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*86 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*86 -: 16]));
  processElement pelement87 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*87 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*87 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*86 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*87 -: 16]));
  FP16_Add interSum87 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*87 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*87 -: 16]));
  processElement pelement88 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*88 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*88 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*87 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*88 -: 16]));
  FP16_Add interSum88 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*88 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*88 -: 16]));
  processElement pelement89 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*89 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*89 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*88 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*89 -: 16]));
  FP16_Add interSum89 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*89 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*89 -: 16]));
  processElement pelement90 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*90 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*90 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*89 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*90 -: 16]));
  FP16_Add interSum90 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*90 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*90 -: 16]));
  processElement pelement91 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*91 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*91 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*90 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*91 -: 16]));
  FP16_Add interSum91 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*91 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*91 -: 16]));
  processElement pelement92 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*92 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*92 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*91 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*92 -: 16]));
  FP16_Add interSum92 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*92 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*92 -: 16]));
  processElement pelement93 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*93 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*93 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*92 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*93 -: 16]));
  FP16_Add interSum93 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*93 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*93 -: 16]));
  processElement pelement94 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*94 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*94 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*93 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*94 -: 16]));
  FP16_Add interSum94 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*94 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*94 -: 16]));
  processElement pelement95 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*95 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*95 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*94 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*95 -: 16]));
  FP16_Add interSum95 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*95 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*95 -: 16]));
  processElement pelement96 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*96 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*96 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*95 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*96 -: 16]));
  FP16_Add interSum96 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*96 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*96 -: 16]));
  processElement pelement97 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*97 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*97 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*96 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*97 -: 16]));
  FP16_Add interSum97 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*97 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*97 -: 16]));
  processElement pelement98 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*98 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*98 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*97 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*98 -: 16]));
  FP16_Add interSum98 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*98 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*98 -: 16]));
  processElement pelement99 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*99 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*99 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*98 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*99 -: 16]));
  FP16_Add interSum99 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*99 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*99 -: 16]));
  processElement pelement100 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*100 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*100 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*99 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*100 -: 16]));
  FP16_Add interSum100 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*100 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*100 -: 16]));
  processElement pelement101 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*101 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*101 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*100 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*101 -: 16]));
  FP16_Add interSum101 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*101 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*101 -: 16]));
  processElement pelement102 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*102 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*102 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*101 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*102 -: 16]));
  FP16_Add interSum102 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*102 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*102 -: 16]));
  processElement pelement103 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*103 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*103 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*102 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*103 -: 16]));
  FP16_Add interSum103 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*103 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*103 -: 16]));
  processElement pelement104 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*104 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*104 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*103 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*104 -: 16]));
  FP16_Add interSum104 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*104 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*104 -: 16]));
  processElement pelement105 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*105 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*105 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*104 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*105 -: 16]));
  FP16_Add interSum105 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*105 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*105 -: 16]));
  processElement pelement106 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*106 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*106 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*105 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*106 -: 16]));
  FP16_Add interSum106 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*106 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*106 -: 16]));
  processElement pelement107 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*107 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*107 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*106 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*107 -: 16]));
  FP16_Add interSum107 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*107 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*107 -: 16]));
  processElement pelement108 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*108 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*108 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*107 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*108 -: 16]));
  FP16_Add interSum108 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*108 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*108 -: 16]));
  processElement pelement109 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*109 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*109 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*108 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*109 -: 16]));
  FP16_Add interSum109 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*109 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*109 -: 16]));
  processElement pelement110 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*110 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*110 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*109 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*110 -: 16]));
  FP16_Add interSum110 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*110 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*110 -: 16]));
  processElement pelement111 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*111 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*111 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*110 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*111 -: 16]));
  FP16_Add interSum111 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*111 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*111 -: 16]));
  processElement pelement112 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*112 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*112 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*111 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*112 -: 16]));
  FP16_Add interSum112 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*112 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*112 -: 16]));
  processElement pelement113 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*113 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*113 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*112 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*113 -: 16]));
  FP16_Add interSum113 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*113 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*113 -: 16]));
  processElement pelement114 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*114 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*114 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*113 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*114 -: 16]));
  FP16_Add interSum114 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*114 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*114 -: 16]));
  processElement pelement115 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*115 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*115 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*114 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*115 -: 16]));
  FP16_Add interSum115 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*115 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*115 -: 16]));
  processElement pelement116 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*116 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*116 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*115 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*116 -: 16]));
  FP16_Add interSum116 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*116 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*116 -: 16]));
  processElement pelement117 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*117 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*117 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*116 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*117 -: 16]));
  FP16_Add interSum117 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*117 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*117 -: 16]));
  processElement pelement118 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*118 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*118 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*117 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*118 -: 16]));
  FP16_Add interSum118 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*118 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*118 -: 16]));
  processElement pelement119 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*119 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*119 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*118 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*119 -: 16]));
  FP16_Add interSum119 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*119 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*119 -: 16]));
  processElement pelement120 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*120 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*120 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*119 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*120 -: 16]));
  FP16_Add interSum120 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*120 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*120 -: 16]));
  processElement pelement121 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*121 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*121 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*120 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*121 -: 16]));
  FP16_Add interSum121 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*121 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*121 -: 16]));
  processElement pelement122 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*122 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*122 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*121 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*122 -: 16]));
  FP16_Add interSum122 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*122 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*122 -: 16]));
  processElement pelement123 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*123 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*123 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*122 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*123 -: 16]));
  FP16_Add interSum123 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*123 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*123 -: 16]));
  processElement pelement124 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*124 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*124 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*123 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*124 -: 16]));
  FP16_Add interSum124 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*124 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*124 -: 16]));
  processElement pelement125 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*125 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*125 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*124 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*125 -: 16]));
  FP16_Add interSum125 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*125 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*125 -: 16]));
  processElement pelement126 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*126 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*126 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*125 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*126 -: 16]));
  FP16_Add interSum126 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*126 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*126 -: 16]));
  processElement pelement127 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*127 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*127 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*126 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*127 -: 16]));
  FP16_Add interSum127 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*127 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*127 -: 16]));
  processElement pelement128 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*128 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*128 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*127 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*128 -: 16]));
  FP16_Add interSum128 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*128 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*128 -: 16]));
  processElement pelement129 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*129 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*129 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*128 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*129 -: 16]));
  FP16_Add interSum129 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*129 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*129 -: 16]));
  processElement pelement130 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*130 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*130 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*129 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*130 -: 16]));
  FP16_Add interSum130 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*130 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*130 -: 16]));
  processElement pelement131 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*131 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*131 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*130 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*131 -: 16]));
  FP16_Add interSum131 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*131 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*131 -: 16]));
  processElement pelement132 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*132 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*132 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*131 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*132 -: 16]));
  FP16_Add interSum132 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*132 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*132 -: 16]));
  processElement pelement133 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*133 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*133 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*132 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*133 -: 16]));
  FP16_Add interSum133 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*133 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*133 -: 16]));
  processElement pelement134 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*134 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*134 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*133 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*134 -: 16]));
  FP16_Add interSum134 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*134 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*134 -: 16]));
  processElement pelement135 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*135 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*135 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*134 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*135 -: 16]));
  FP16_Add interSum135 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*135 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*135 -: 16]));
  processElement pelement136 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*136 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*136 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*135 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*136 -: 16]));
  FP16_Add interSum136 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*136 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*136 -: 16]));
  processElement pelement137 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*137 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*137 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*136 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*137 -: 16]));
  FP16_Add interSum137 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*137 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*137 -: 16]));
  processElement pelement138 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*138 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*138 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*137 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*138 -: 16]));
  FP16_Add interSum138 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*138 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*138 -: 16]));
  processElement pelement139 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*139 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*139 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*138 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*139 -: 16]));
  FP16_Add interSum139 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*139 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*139 -: 16]));
  processElement pelement140 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*140 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*140 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*139 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*140 -: 16]));
  FP16_Add interSum140 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*140 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*140 -: 16]));
  processElement pelement141 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*141 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*141 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*140 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*141 -: 16]));
  FP16_Add interSum141 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*141 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*141 -: 16]));
  processElement pelement142 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*142 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*142 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*141 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*142 -: 16]));
  FP16_Add interSum142 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*142 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*142 -: 16]));
  processElement pelement143 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*143 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*143 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*142 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*143 -: 16]));
  FP16_Add interSum143 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*143 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*143 -: 16]));
  processElement pelement144 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*144 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*144 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*143 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*144 -: 16]));
  FP16_Add interSum144 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*144 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*144 -: 16]));
  processElement pelement145 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*145 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*145 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*144 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*145 -: 16]));
  FP16_Add interSum145 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*145 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*145 -: 16]));
  processElement pelement146 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*146 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*146 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*145 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*146 -: 16]));
  FP16_Add interSum146 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*146 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*146 -: 16]));
  processElement pelement147 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*147 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*147 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*146 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*147 -: 16]));
  FP16_Add interSum147 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*147 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*147 -: 16]));
  processElement pelement148 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*148 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*148 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*147 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*148 -: 16]));
  FP16_Add interSum148 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*148 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*148 -: 16]));
  processElement pelement149 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*149 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*149 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*148 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*149 -: 16]));
  FP16_Add interSum149 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*149 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*149 -: 16]));
  processElement pelement150 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*150 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*150 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*149 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*150 -: 16]));
  FP16_Add interSum150 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*150 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*150 -: 16]));
  processElement pelement151 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*151 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*151 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*150 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*151 -: 16]));
  FP16_Add interSum151 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*151 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*151 -: 16]));
  processElement pelement152 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*152 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*152 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*151 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*152 -: 16]));
  FP16_Add interSum152 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*152 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*152 -: 16]));
  processElement pelement153 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*153 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*153 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*152 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*153 -: 16]));
  FP16_Add interSum153 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*153 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*153 -: 16]));
  processElement pelement154 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*154 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*154 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*153 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*154 -: 16]));
  FP16_Add interSum154 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*154 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*154 -: 16]));
  processElement pelement155 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*155 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*155 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*154 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*155 -: 16]));
  FP16_Add interSum155 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*155 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*155 -: 16]));
  processElement pelement156 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*156 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*156 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*155 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*156 -: 16]));
  FP16_Add interSum156 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*156 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*156 -: 16]));
  processElement pelement157 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*157 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*157 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*156 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*157 -: 16]));
  FP16_Add interSum157 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*157 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*157 -: 16]));
  processElement pelement158 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*158 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*158 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*157 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*158 -: 16]));
  FP16_Add interSum158 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*158 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*158 -: 16]));
  processElement pelement159 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*159 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*159 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*158 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*159 -: 16]));
  FP16_Add interSum159 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*159 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*159 -: 16]));
  processElement pelement160 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*160 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*160 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*159 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*160 -: 16]));
  FP16_Add interSum160 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*160 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*160 -: 16]));
  processElement pelement161 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*161 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*161 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*160 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*161 -: 16]));
  FP16_Add interSum161 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*161 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*161 -: 16]));
  processElement pelement162 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*162 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*162 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*161 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*162 -: 16]));
  FP16_Add interSum162 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*162 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*162 -: 16]));
  processElement pelement163 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*163 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*163 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*162 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*163 -: 16]));
  FP16_Add interSum163 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*163 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*163 -: 16]));
  processElement pelement164 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*164 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*164 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*163 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*164 -: 16]));
  FP16_Add interSum164 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*164 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*164 -: 16]));
  processElement pelement165 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*165 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*165 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*164 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*165 -: 16]));
  FP16_Add interSum165 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*165 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*165 -: 16]));
  processElement pelement166 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*166 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*166 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*165 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*166 -: 16]));
  FP16_Add interSum166 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*166 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*166 -: 16]));
  processElement pelement167 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*167 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*167 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*166 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*167 -: 16]));
  FP16_Add interSum167 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*167 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*167 -: 16]));
  processElement pelement168 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*168 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*168 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*167 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*168 -: 16]));
  FP16_Add interSum168 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*168 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*168 -: 16]));
  processElement pelement169 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*169 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*169 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*168 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*169 -: 16]));
  FP16_Add interSum169 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*169 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*169 -: 16]));
  processElement pelement170 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*170 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*170 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*169 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*170 -: 16]));
  FP16_Add interSum170 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*170 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*170 -: 16]));
  processElement pelement171 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*171 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*171 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*170 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*171 -: 16]));
  FP16_Add interSum171 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*171 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*171 -: 16]));
  processElement pelement172 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*172 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*172 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*171 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*172 -: 16]));
  FP16_Add interSum172 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*172 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*172 -: 16]));
  processElement pelement173 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*173 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*173 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*172 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*173 -: 16]));
  FP16_Add interSum173 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*173 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*173 -: 16]));
  processElement pelement174 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*174 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*174 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*173 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*174 -: 16]));
  FP16_Add interSum174 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*174 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*174 -: 16]));
  processElement pelement175 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*175 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*175 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*174 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*175 -: 16]));
  FP16_Add interSum175 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*175 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*175 -: 16]));
  processElement pelement176 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*176 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*176 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*175 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*176 -: 16]));
  FP16_Add interSum176 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*176 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*176 -: 16]));
  processElement pelement177 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*177 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*177 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*176 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*177 -: 16]));
  FP16_Add interSum177 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*177 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*177 -: 16]));
  processElement pelement178 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*178 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*178 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*177 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*178 -: 16]));
  FP16_Add interSum178 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*178 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*178 -: 16]));
  processElement pelement179 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*179 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*179 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*178 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*179 -: 16]));
  FP16_Add interSum179 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*179 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*179 -: 16]));
  processElement pelement180 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*180 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*180 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*179 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*180 -: 16]));
  FP16_Add interSum180 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*180 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*180 -: 16]));
  processElement pelement181 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*181 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*181 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*180 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*181 -: 16]));
  FP16_Add interSum181 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*181 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*181 -: 16]));
  processElement pelement182 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*182 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*182 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*181 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*182 -: 16]));
  FP16_Add interSum182 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*182 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*182 -: 16]));
  processElement pelement183 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*183 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*183 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*182 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*183 -: 16]));
  FP16_Add interSum183 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*183 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*183 -: 16]));
  processElement pelement184 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*184 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*184 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*183 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*184 -: 16]));
  FP16_Add interSum184 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*184 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*184 -: 16]));
  processElement pelement185 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*185 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*185 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*184 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*185 -: 16]));
  FP16_Add interSum185 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*185 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*185 -: 16]));
  processElement pelement186 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*186 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*186 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*185 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*186 -: 16]));
  FP16_Add interSum186 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*186 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*186 -: 16]));
  processElement pelement187 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*187 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*187 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*186 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*187 -: 16]));
  FP16_Add interSum187 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*187 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*187 -: 16]));
  processElement pelement188 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*188 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*188 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*187 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*188 -: 16]));
  FP16_Add interSum188 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*188 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*188 -: 16]));
  processElement pelement189 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*189 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*189 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*188 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*189 -: 16]));
  FP16_Add interSum189 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*189 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*189 -: 16]));
  processElement pelement190 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*190 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*190 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*189 -: 16]), .Yout(Yout[WEIGHTS*FP_LENGTH - 1 - 16*190 -: 16]));
  FP16_Add interSum190 (.A(Yout[WEIGHTS*FP_LENGTH - 1 - 16*190 -: 16]), .B(bias1), .Out(interBias[WEIGHTS*FP_LENGTH - 1 - 16*190 -: 16]));
  processElement pelement191 (.Xin(data[WEIGHTS*FP_LENGTH - 1 - 16*191 -: 16]), .weight(weights[WEIGHTS*FP_LENGTH - 1 - 16*191 -: 16]), .bias(interBias[WEIGHTS*FP_LENGTH - 1 - 16*190 -: 16]), .Yout(result));
    
endmodule

module FP16_Max (num1, num2, Out);
  parameter FP_LENGTH = 16;

  input [FP_LENGTH -1:0] num1, num2;
  output [FP_LENGTH - 1:0] Out;

  assign Out = (num1[15]==num2[15])?((num1[14:10] == num2[14:10])?((num1[9:0] == num2[9:0])?num1:(num1[15] == 0)?((num1[9:0] > num2[9:0])?num1:num2):((num1[9:0] < num2[9:0])?num1:num2)): (num1[15] == 0)?((num1[14:10] > num2[14:10])?num1:num2):((num1[14:10] < num2[14:10])?num1:num2)):(num1[15] < num2[15])?num1:num2;
endmodule

module Answer (num0, num1, num2, num3, num4, num5, num6, num7, num8, num9, answer);
  parameter FP_LENGTH = 16;
  
  input [FP_LENGTH - 1:0] num0, num1, num2, num3, num4, num5, num6, num7, num8, num9;
  output [FP_LENGTH - 1:0] answer;
  wire [FP_LENGTH - 1:0] max0, max1, max2, max3, max4, max5, max6,max7;
  
  FP16_Max compare0 (.num1(num0),
                     .num2(num1),
                     .Out(max0));
  FP16_Max compare1 (.num1(max0),
                     .num2(num2),
                     .Out(max1));
  FP16_Max compare2 (.num1(max1),
                     .num2(num3),
                     .Out(max2));
  FP16_Max compare3 (.num1(max2),
                     .num2(num4),
                     .Out(max3));
  FP16_Max compare4 (.num1(max3),
                     .num2(num5),
                     .Out(max4));
  FP16_Max compare5 (.num1(max4),
                     .num2(num6),
                     .Out(max5));
  FP16_Max compare6 (.num1(max5),
                     .num2(num7),
                     .Out(max6));
  FP16_Max compare7 (.num1(max6),
                     .num2(num8),
                     .Out(max7));
  FP16_Max compare8 (.num1(max7),
                     .num2(num9),
                     .Out(answer));
 
endmodule

module LeNet1 (clk, rst, data, data_11,data_12,data_13,data_14,avg_data_11,avg_data_12,avg_data_13,avg_data_14,data_201,data_202,data_203,data_204,data_205,data_206,data_207,data_208,data_209,data_210,data_211,data_212,avg_data_201,avg_data_202,avg_data_203,avg_data_204,avg_data_205,avg_data_206,avg_data_207,avg_data_208,avg_data_209,avg_data_210,avg_data_211,avg_data_212,result_i,result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7, result_8, result_9,result);

  //Parameters
  parameter CONV1_WEIGHTS_ROW = 4,
    CONV1_WEIGHTS_COLUMN = 25,
    CONV1_BIAS_ROW = 4,
    CONV2_WEIGHTS_ROW = 12,
    CONV2_WEIGHTS_COLUMN = 100,
    CONV2_BIAS_ROW = 12,
    FC1_WEIGHTS_ROW = 10,
    FC1_WEIGHTS_COLUMN = 192,
    FC1_BIAS_ROW = 10,
    FP_LENGTH = 16;
  
  input clk, rst;
  input [784*FP_LENGTH - 1:0] data;
  
  output [576*FP_LENGTH - 1:0] data_11,data_12,data_13,data_14;
  output [144*FP_LENGTH - 1:0] avg_data_11,avg_data_12,avg_data_13,avg_data_14;
  output [64*FP_LENGTH - 1:0] data_201,data_202,data_203,data_204,data_205,data_206,data_207,data_208,data_209,data_210,data_211,data_212;
  output [16*FP_LENGTH - 1:0] avg_data_201,avg_data_202,avg_data_203,avg_data_204,avg_data_205,avg_data_206,avg_data_207,avg_data_208,avg_data_209,avg_data_210,avg_data_211,avg_data_212;
  output [FP_LENGTH - 1:0] result_i,result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7, result_8, result_9;
  output reg [3:0] result;
    
  //Memory arrays in which all the parameters will be imported
  reg [FP_LENGTH - 1:0] CONV1_WEIGHTS_M [0:CONV1_WEIGHTS_ROW*CONV1_WEIGHTS_COLUMN - 1];
  reg [FP_LENGTH - 1:0] CONV1_BIAS_M [0:CONV1_BIAS_ROW - 1];
  reg [FP_LENGTH - 1:0] CONV2_WEIGHTS_M [0:CONV2_WEIGHTS_ROW*CONV2_WEIGHTS_COLUMN - 1];
  reg [FP_LENGTH - 1:0] CONV2_BIAS_M [0:CONV2_BIAS_ROW - 1];
  reg [FP_LENGTH - 1:0] FC1_WEIGHTS_M [0:FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1];
  reg [FP_LENGTH - 1:0] FC1_BIAS_M [0:FC1_BIAS_ROW - 1];
  
  initial begin
   //Importing all required files in memory arrays
   $readmemb("C:/Users/king/Documents/Jupyter/HA/Files/conv1_weight.txt", CONV1_WEIGHTS_M);
   $readmemb("C:/Users/king/Documents/Jupyter/HA/Files/conv1_bias.txt", CONV1_BIAS_M);
   $readmemb("C:/Users/king/Documents/Jupyter/HA/Files/conv2_weight.txt", CONV2_WEIGHTS_M);
   $readmemb("C:/Users/king/Documents/Jupyter/HA/Files/conv2_bias.txt", CONV2_BIAS_M);
   $readmemb("C:/Users/king/Documents/Jupyter/HA/Files/fc1_weight.txt", FC1_WEIGHTS_M);
   $readmemb("C:/Users/king/Documents/Jupyter/HA/Files/fc1_bias.txt", FC1_BIAS_M);
   //$readmemb("C:/Users/king/Documents/Jupyter/HA/Files/test_data.txt", TEST_DATA_M);
   
   
  end
  
    //CONVOLUTION 1
    conv1 conv1_f1(.dataIn(data),
                  .weights({CONV1_WEIGHTS_M[0],CONV1_WEIGHTS_M[1],CONV1_WEIGHTS_M[2],CONV1_WEIGHTS_M[3],CONV1_WEIGHTS_M[4],CONV1_WEIGHTS_M[5],CONV1_WEIGHTS_M[6],CONV1_WEIGHTS_M[7],CONV1_WEIGHTS_M[8],CONV1_WEIGHTS_M[9],CONV1_WEIGHTS_M[10],CONV1_WEIGHTS_M[11],CONV1_WEIGHTS_M[12],CONV1_WEIGHTS_M[13],CONV1_WEIGHTS_M[14],CONV1_WEIGHTS_M[15],CONV1_WEIGHTS_M[16],CONV1_WEIGHTS_M[17],CONV1_WEIGHTS_M[18],CONV1_WEIGHTS_M[19],CONV1_WEIGHTS_M[20],CONV1_WEIGHTS_M[21],CONV1_WEIGHTS_M[22],CONV1_WEIGHTS_M[23],CONV1_WEIGHTS_M[24]}),
                  .bias(CONV1_BIAS_M[0]),
                  .dataOut(data_11));
                  
    conv1 conv1_f2(.dataIn(data),
                  .weights({CONV1_WEIGHTS_M[25],CONV1_WEIGHTS_M[26],CONV1_WEIGHTS_M[27],CONV1_WEIGHTS_M[28],CONV1_WEIGHTS_M[29],CONV1_WEIGHTS_M[30],CONV1_WEIGHTS_M[31],CONV1_WEIGHTS_M[32],CONV1_WEIGHTS_M[33],CONV1_WEIGHTS_M[34],CONV1_WEIGHTS_M[35],CONV1_WEIGHTS_M[36],CONV1_WEIGHTS_M[37],CONV1_WEIGHTS_M[38],CONV1_WEIGHTS_M[39],CONV1_WEIGHTS_M[40],CONV1_WEIGHTS_M[41],CONV1_WEIGHTS_M[42],CONV1_WEIGHTS_M[43],CONV1_WEIGHTS_M[44],CONV1_WEIGHTS_M[45],CONV1_WEIGHTS_M[46],CONV1_WEIGHTS_M[47],CONV1_WEIGHTS_M[48],CONV1_WEIGHTS_M[49]}),
                  .bias(CONV1_BIAS_M[1]),
                  .dataOut(data_12));
  
    conv1 conv1_f3(.dataIn(data),
                      .weights({CONV1_WEIGHTS_M[50],CONV1_WEIGHTS_M[51],CONV1_WEIGHTS_M[52],CONV1_WEIGHTS_M[53],CONV1_WEIGHTS_M[54],CONV1_WEIGHTS_M[55],CONV1_WEIGHTS_M[56],CONV1_WEIGHTS_M[57],CONV1_WEIGHTS_M[58],CONV1_WEIGHTS_M[59],CONV1_WEIGHTS_M[60],CONV1_WEIGHTS_M[61],CONV1_WEIGHTS_M[62],CONV1_WEIGHTS_M[63],CONV1_WEIGHTS_M[64],CONV1_WEIGHTS_M[65],CONV1_WEIGHTS_M[66],CONV1_WEIGHTS_M[67],CONV1_WEIGHTS_M[68],CONV1_WEIGHTS_M[69],CONV1_WEIGHTS_M[70],CONV1_WEIGHTS_M[71],CONV1_WEIGHTS_M[72],CONV1_WEIGHTS_M[73],CONV1_WEIGHTS_M[74]}),
                      .bias(CONV1_BIAS_M[2]),
                      .dataOut(data_13));
    
    conv1 conv1_f4(.dataIn(data),
                      .weights({CONV1_WEIGHTS_M[75],CONV1_WEIGHTS_M[76],CONV1_WEIGHTS_M[77],CONV1_WEIGHTS_M[78],CONV1_WEIGHTS_M[79],CONV1_WEIGHTS_M[80],CONV1_WEIGHTS_M[81],CONV1_WEIGHTS_M[82],CONV1_WEIGHTS_M[83],CONV1_WEIGHTS_M[84],CONV1_WEIGHTS_M[85],CONV1_WEIGHTS_M[86],CONV1_WEIGHTS_M[87],CONV1_WEIGHTS_M[88],CONV1_WEIGHTS_M[89],CONV1_WEIGHTS_M[90],CONV1_WEIGHTS_M[91],CONV1_WEIGHTS_M[92],CONV1_WEIGHTS_M[93],CONV1_WEIGHTS_M[94],CONV1_WEIGHTS_M[95],CONV1_WEIGHTS_M[96],CONV1_WEIGHTS_M[97],CONV1_WEIGHTS_M[98],CONV1_WEIGHTS_M[99]}),
                      .bias(CONV1_BIAS_M[3]),
                      .dataOut(data_14));
  
    //AVERAGE POOLING 1
    AveragePool_1 avg_p1_1(.data(data_11),.pool(avg_data_11));
    AveragePool_1 avg_p1_2(.data(data_12),.pool(avg_data_12));
    AveragePool_1 avg_p1_3(.data(data_13),.pool(avg_data_13));
    AveragePool_1 avg_p1_4(.data(data_14),.pool(avg_data_14));

    
    //CONVOLUTION 2
    conv2_feature c2f1(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[0], CONV2_WEIGHTS_M[1], CONV2_WEIGHTS_M[2], CONV2_WEIGHTS_M[3], CONV2_WEIGHTS_M[4], CONV2_WEIGHTS_M[5], CONV2_WEIGHTS_M[6], CONV2_WEIGHTS_M[7], CONV2_WEIGHTS_M[8], CONV2_WEIGHTS_M[9], CONV2_WEIGHTS_M[10], CONV2_WEIGHTS_M[11], CONV2_WEIGHTS_M[12], CONV2_WEIGHTS_M[13], CONV2_WEIGHTS_M[14], CONV2_WEIGHTS_M[15], CONV2_WEIGHTS_M[16], CONV2_WEIGHTS_M[17], CONV2_WEIGHTS_M[18], CONV2_WEIGHTS_M[19], CONV2_WEIGHTS_M[20], CONV2_WEIGHTS_M[21], CONV2_WEIGHTS_M[22], CONV2_WEIGHTS_M[23], CONV2_WEIGHTS_M[24], CONV2_WEIGHTS_M[25], CONV2_WEIGHTS_M[26], CONV2_WEIGHTS_M[27], CONV2_WEIGHTS_M[28], CONV2_WEIGHTS_M[29], CONV2_WEIGHTS_M[30], CONV2_WEIGHTS_M[31], CONV2_WEIGHTS_M[32], CONV2_WEIGHTS_M[33], CONV2_WEIGHTS_M[34], CONV2_WEIGHTS_M[35], CONV2_WEIGHTS_M[36], CONV2_WEIGHTS_M[37], CONV2_WEIGHTS_M[38], CONV2_WEIGHTS_M[39], CONV2_WEIGHTS_M[40], CONV2_WEIGHTS_M[41], CONV2_WEIGHTS_M[42], CONV2_WEIGHTS_M[43], CONV2_WEIGHTS_M[44], CONV2_WEIGHTS_M[45], CONV2_WEIGHTS_M[46], CONV2_WEIGHTS_M[47], CONV2_WEIGHTS_M[48], CONV2_WEIGHTS_M[49], CONV2_WEIGHTS_M[50], CONV2_WEIGHTS_M[51], CONV2_WEIGHTS_M[52], CONV2_WEIGHTS_M[53], CONV2_WEIGHTS_M[54], CONV2_WEIGHTS_M[55], CONV2_WEIGHTS_M[56], CONV2_WEIGHTS_M[57], CONV2_WEIGHTS_M[58], CONV2_WEIGHTS_M[59], CONV2_WEIGHTS_M[60], CONV2_WEIGHTS_M[61], CONV2_WEIGHTS_M[62], CONV2_WEIGHTS_M[63], CONV2_WEIGHTS_M[64], CONV2_WEIGHTS_M[65], CONV2_WEIGHTS_M[66], CONV2_WEIGHTS_M[67], CONV2_WEIGHTS_M[68], CONV2_WEIGHTS_M[69], CONV2_WEIGHTS_M[70], CONV2_WEIGHTS_M[71], CONV2_WEIGHTS_M[72], CONV2_WEIGHTS_M[73], CONV2_WEIGHTS_M[74], CONV2_WEIGHTS_M[75], CONV2_WEIGHTS_M[76], CONV2_WEIGHTS_M[77], CONV2_WEIGHTS_M[78], CONV2_WEIGHTS_M[79], CONV2_WEIGHTS_M[80], CONV2_WEIGHTS_M[81], CONV2_WEIGHTS_M[82], CONV2_WEIGHTS_M[83], CONV2_WEIGHTS_M[84], CONV2_WEIGHTS_M[85], CONV2_WEIGHTS_M[86], CONV2_WEIGHTS_M[87], CONV2_WEIGHTS_M[88], CONV2_WEIGHTS_M[89], CONV2_WEIGHTS_M[90], CONV2_WEIGHTS_M[91], CONV2_WEIGHTS_M[92], CONV2_WEIGHTS_M[93], CONV2_WEIGHTS_M[94], CONV2_WEIGHTS_M[95], CONV2_WEIGHTS_M[96], CONV2_WEIGHTS_M[97], CONV2_WEIGHTS_M[98], CONV2_WEIGHTS_M[99]}), 
                       .bias(CONV2_BIAS_M[0]), 
                       .dataOut(data_201));
                       
    conv2_feature c2f2(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[100], CONV2_WEIGHTS_M[101], CONV2_WEIGHTS_M[102], CONV2_WEIGHTS_M[103], CONV2_WEIGHTS_M[104], CONV2_WEIGHTS_M[105], CONV2_WEIGHTS_M[106], CONV2_WEIGHTS_M[107], CONV2_WEIGHTS_M[108], CONV2_WEIGHTS_M[109], CONV2_WEIGHTS_M[110], CONV2_WEIGHTS_M[111], CONV2_WEIGHTS_M[112], CONV2_WEIGHTS_M[113], CONV2_WEIGHTS_M[114], CONV2_WEIGHTS_M[115], CONV2_WEIGHTS_M[116], CONV2_WEIGHTS_M[117], CONV2_WEIGHTS_M[118], CONV2_WEIGHTS_M[119], CONV2_WEIGHTS_M[120], CONV2_WEIGHTS_M[121], CONV2_WEIGHTS_M[122], CONV2_WEIGHTS_M[123], CONV2_WEIGHTS_M[124], CONV2_WEIGHTS_M[125], CONV2_WEIGHTS_M[126], CONV2_WEIGHTS_M[127], CONV2_WEIGHTS_M[128], CONV2_WEIGHTS_M[129], CONV2_WEIGHTS_M[130], CONV2_WEIGHTS_M[131], CONV2_WEIGHTS_M[132], CONV2_WEIGHTS_M[133], CONV2_WEIGHTS_M[134], CONV2_WEIGHTS_M[135], CONV2_WEIGHTS_M[136], CONV2_WEIGHTS_M[137], CONV2_WEIGHTS_M[138], CONV2_WEIGHTS_M[139], CONV2_WEIGHTS_M[140], CONV2_WEIGHTS_M[141], CONV2_WEIGHTS_M[142], CONV2_WEIGHTS_M[143], CONV2_WEIGHTS_M[144], CONV2_WEIGHTS_M[145], CONV2_WEIGHTS_M[146], CONV2_WEIGHTS_M[147], CONV2_WEIGHTS_M[148], CONV2_WEIGHTS_M[149], CONV2_WEIGHTS_M[150], CONV2_WEIGHTS_M[151], CONV2_WEIGHTS_M[152], CONV2_WEIGHTS_M[153], CONV2_WEIGHTS_M[154], CONV2_WEIGHTS_M[155], CONV2_WEIGHTS_M[156], CONV2_WEIGHTS_M[157], CONV2_WEIGHTS_M[158], CONV2_WEIGHTS_M[159], CONV2_WEIGHTS_M[160], CONV2_WEIGHTS_M[161], CONV2_WEIGHTS_M[162], CONV2_WEIGHTS_M[163], CONV2_WEIGHTS_M[164], CONV2_WEIGHTS_M[165], CONV2_WEIGHTS_M[166], CONV2_WEIGHTS_M[167], CONV2_WEIGHTS_M[168], CONV2_WEIGHTS_M[169], CONV2_WEIGHTS_M[170], CONV2_WEIGHTS_M[171], CONV2_WEIGHTS_M[172], CONV2_WEIGHTS_M[173], CONV2_WEIGHTS_M[174], CONV2_WEIGHTS_M[175], CONV2_WEIGHTS_M[176], CONV2_WEIGHTS_M[177], CONV2_WEIGHTS_M[178], CONV2_WEIGHTS_M[179], CONV2_WEIGHTS_M[180], CONV2_WEIGHTS_M[181], CONV2_WEIGHTS_M[182], CONV2_WEIGHTS_M[183], CONV2_WEIGHTS_M[184], CONV2_WEIGHTS_M[185], CONV2_WEIGHTS_M[186], CONV2_WEIGHTS_M[187], CONV2_WEIGHTS_M[188], CONV2_WEIGHTS_M[189], CONV2_WEIGHTS_M[190], CONV2_WEIGHTS_M[191], CONV2_WEIGHTS_M[192], CONV2_WEIGHTS_M[193], CONV2_WEIGHTS_M[194], CONV2_WEIGHTS_M[195], CONV2_WEIGHTS_M[196], CONV2_WEIGHTS_M[197], CONV2_WEIGHTS_M[198], CONV2_WEIGHTS_M[199]}), 
                       .bias(CONV2_BIAS_M[1]), 
                       .dataOut(data_202));
                       
    conv2_feature c2f3(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[200], CONV2_WEIGHTS_M[201], CONV2_WEIGHTS_M[202], CONV2_WEIGHTS_M[203], CONV2_WEIGHTS_M[204], CONV2_WEIGHTS_M[205], CONV2_WEIGHTS_M[206], CONV2_WEIGHTS_M[207], CONV2_WEIGHTS_M[208], CONV2_WEIGHTS_M[209], CONV2_WEIGHTS_M[210], CONV2_WEIGHTS_M[211], CONV2_WEIGHTS_M[212], CONV2_WEIGHTS_M[213], CONV2_WEIGHTS_M[214], CONV2_WEIGHTS_M[215], CONV2_WEIGHTS_M[216], CONV2_WEIGHTS_M[217], CONV2_WEIGHTS_M[218], CONV2_WEIGHTS_M[219], CONV2_WEIGHTS_M[220], CONV2_WEIGHTS_M[221], CONV2_WEIGHTS_M[222], CONV2_WEIGHTS_M[223], CONV2_WEIGHTS_M[224], CONV2_WEIGHTS_M[225], CONV2_WEIGHTS_M[226], CONV2_WEIGHTS_M[227], CONV2_WEIGHTS_M[228], CONV2_WEIGHTS_M[229], CONV2_WEIGHTS_M[230], CONV2_WEIGHTS_M[231], CONV2_WEIGHTS_M[232], CONV2_WEIGHTS_M[233], CONV2_WEIGHTS_M[234], CONV2_WEIGHTS_M[235], CONV2_WEIGHTS_M[236], CONV2_WEIGHTS_M[237], CONV2_WEIGHTS_M[238], CONV2_WEIGHTS_M[239], CONV2_WEIGHTS_M[240], CONV2_WEIGHTS_M[241], CONV2_WEIGHTS_M[242], CONV2_WEIGHTS_M[243], CONV2_WEIGHTS_M[244], CONV2_WEIGHTS_M[245], CONV2_WEIGHTS_M[246], CONV2_WEIGHTS_M[247], CONV2_WEIGHTS_M[248], CONV2_WEIGHTS_M[249], CONV2_WEIGHTS_M[250], CONV2_WEIGHTS_M[251], CONV2_WEIGHTS_M[252], CONV2_WEIGHTS_M[253], CONV2_WEIGHTS_M[254], CONV2_WEIGHTS_M[255], CONV2_WEIGHTS_M[256], CONV2_WEIGHTS_M[257], CONV2_WEIGHTS_M[258], CONV2_WEIGHTS_M[259], CONV2_WEIGHTS_M[260], CONV2_WEIGHTS_M[261], CONV2_WEIGHTS_M[262], CONV2_WEIGHTS_M[263], CONV2_WEIGHTS_M[264], CONV2_WEIGHTS_M[265], CONV2_WEIGHTS_M[266], CONV2_WEIGHTS_M[267], CONV2_WEIGHTS_M[268], CONV2_WEIGHTS_M[269], CONV2_WEIGHTS_M[270], CONV2_WEIGHTS_M[271], CONV2_WEIGHTS_M[272], CONV2_WEIGHTS_M[273], CONV2_WEIGHTS_M[274], CONV2_WEIGHTS_M[275], CONV2_WEIGHTS_M[276], CONV2_WEIGHTS_M[277], CONV2_WEIGHTS_M[278], CONV2_WEIGHTS_M[279], CONV2_WEIGHTS_M[280], CONV2_WEIGHTS_M[281], CONV2_WEIGHTS_M[282], CONV2_WEIGHTS_M[283], CONV2_WEIGHTS_M[284], CONV2_WEIGHTS_M[285], CONV2_WEIGHTS_M[286], CONV2_WEIGHTS_M[287], CONV2_WEIGHTS_M[288], CONV2_WEIGHTS_M[289], CONV2_WEIGHTS_M[290], CONV2_WEIGHTS_M[291], CONV2_WEIGHTS_M[292], CONV2_WEIGHTS_M[293], CONV2_WEIGHTS_M[294], CONV2_WEIGHTS_M[295], CONV2_WEIGHTS_M[296], CONV2_WEIGHTS_M[297], CONV2_WEIGHTS_M[298], CONV2_WEIGHTS_M[299]}), 
                       .bias(CONV2_BIAS_M[2]), 
                       .dataOut(data_203));
                       
    conv2_feature c2f4(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[300], CONV2_WEIGHTS_M[301], CONV2_WEIGHTS_M[302], CONV2_WEIGHTS_M[303], CONV2_WEIGHTS_M[304], CONV2_WEIGHTS_M[305], CONV2_WEIGHTS_M[306], CONV2_WEIGHTS_M[307], CONV2_WEIGHTS_M[308], CONV2_WEIGHTS_M[309], CONV2_WEIGHTS_M[310], CONV2_WEIGHTS_M[311], CONV2_WEIGHTS_M[312], CONV2_WEIGHTS_M[313], CONV2_WEIGHTS_M[314], CONV2_WEIGHTS_M[315], CONV2_WEIGHTS_M[316], CONV2_WEIGHTS_M[317], CONV2_WEIGHTS_M[318], CONV2_WEIGHTS_M[319], CONV2_WEIGHTS_M[320], CONV2_WEIGHTS_M[321], CONV2_WEIGHTS_M[322], CONV2_WEIGHTS_M[323], CONV2_WEIGHTS_M[324], CONV2_WEIGHTS_M[325], CONV2_WEIGHTS_M[326], CONV2_WEIGHTS_M[327], CONV2_WEIGHTS_M[328], CONV2_WEIGHTS_M[329], CONV2_WEIGHTS_M[330], CONV2_WEIGHTS_M[331], CONV2_WEIGHTS_M[332], CONV2_WEIGHTS_M[333], CONV2_WEIGHTS_M[334], CONV2_WEIGHTS_M[335], CONV2_WEIGHTS_M[336], CONV2_WEIGHTS_M[337], CONV2_WEIGHTS_M[338], CONV2_WEIGHTS_M[339], CONV2_WEIGHTS_M[340], CONV2_WEIGHTS_M[341], CONV2_WEIGHTS_M[342], CONV2_WEIGHTS_M[343], CONV2_WEIGHTS_M[344], CONV2_WEIGHTS_M[345], CONV2_WEIGHTS_M[346], CONV2_WEIGHTS_M[347], CONV2_WEIGHTS_M[348], CONV2_WEIGHTS_M[349], CONV2_WEIGHTS_M[350], CONV2_WEIGHTS_M[351], CONV2_WEIGHTS_M[352], CONV2_WEIGHTS_M[353], CONV2_WEIGHTS_M[354], CONV2_WEIGHTS_M[355], CONV2_WEIGHTS_M[356], CONV2_WEIGHTS_M[357], CONV2_WEIGHTS_M[358], CONV2_WEIGHTS_M[359], CONV2_WEIGHTS_M[360], CONV2_WEIGHTS_M[361], CONV2_WEIGHTS_M[362], CONV2_WEIGHTS_M[363], CONV2_WEIGHTS_M[364], CONV2_WEIGHTS_M[365], CONV2_WEIGHTS_M[366], CONV2_WEIGHTS_M[367], CONV2_WEIGHTS_M[368], CONV2_WEIGHTS_M[369], CONV2_WEIGHTS_M[370], CONV2_WEIGHTS_M[371], CONV2_WEIGHTS_M[372], CONV2_WEIGHTS_M[373], CONV2_WEIGHTS_M[374], CONV2_WEIGHTS_M[375], CONV2_WEIGHTS_M[376], CONV2_WEIGHTS_M[377], CONV2_WEIGHTS_M[378], CONV2_WEIGHTS_M[379], CONV2_WEIGHTS_M[380], CONV2_WEIGHTS_M[381], CONV2_WEIGHTS_M[382], CONV2_WEIGHTS_M[383], CONV2_WEIGHTS_M[384], CONV2_WEIGHTS_M[385], CONV2_WEIGHTS_M[386], CONV2_WEIGHTS_M[387], CONV2_WEIGHTS_M[388], CONV2_WEIGHTS_M[389], CONV2_WEIGHTS_M[390], CONV2_WEIGHTS_M[391], CONV2_WEIGHTS_M[392], CONV2_WEIGHTS_M[393], CONV2_WEIGHTS_M[394], CONV2_WEIGHTS_M[395], CONV2_WEIGHTS_M[396], CONV2_WEIGHTS_M[397], CONV2_WEIGHTS_M[398], CONV2_WEIGHTS_M[399]}), 
                       .bias(CONV2_BIAS_M[3]), 
                       .dataOut(data_204));
                       
    conv2_feature c2f5(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[400], CONV2_WEIGHTS_M[401], CONV2_WEIGHTS_M[402], CONV2_WEIGHTS_M[403], CONV2_WEIGHTS_M[404], CONV2_WEIGHTS_M[405], CONV2_WEIGHTS_M[406], CONV2_WEIGHTS_M[407], CONV2_WEIGHTS_M[408], CONV2_WEIGHTS_M[409], CONV2_WEIGHTS_M[410], CONV2_WEIGHTS_M[411], CONV2_WEIGHTS_M[412], CONV2_WEIGHTS_M[413], CONV2_WEIGHTS_M[414], CONV2_WEIGHTS_M[415], CONV2_WEIGHTS_M[416], CONV2_WEIGHTS_M[417], CONV2_WEIGHTS_M[418], CONV2_WEIGHTS_M[419], CONV2_WEIGHTS_M[420], CONV2_WEIGHTS_M[421], CONV2_WEIGHTS_M[422], CONV2_WEIGHTS_M[423], CONV2_WEIGHTS_M[424], CONV2_WEIGHTS_M[425], CONV2_WEIGHTS_M[426], CONV2_WEIGHTS_M[427], CONV2_WEIGHTS_M[428], CONV2_WEIGHTS_M[429], CONV2_WEIGHTS_M[430], CONV2_WEIGHTS_M[431], CONV2_WEIGHTS_M[432], CONV2_WEIGHTS_M[433], CONV2_WEIGHTS_M[434], CONV2_WEIGHTS_M[435], CONV2_WEIGHTS_M[436], CONV2_WEIGHTS_M[437], CONV2_WEIGHTS_M[438], CONV2_WEIGHTS_M[439], CONV2_WEIGHTS_M[440], CONV2_WEIGHTS_M[441], CONV2_WEIGHTS_M[442], CONV2_WEIGHTS_M[443], CONV2_WEIGHTS_M[444], CONV2_WEIGHTS_M[445], CONV2_WEIGHTS_M[446], CONV2_WEIGHTS_M[447], CONV2_WEIGHTS_M[448], CONV2_WEIGHTS_M[449], CONV2_WEIGHTS_M[450], CONV2_WEIGHTS_M[451], CONV2_WEIGHTS_M[452], CONV2_WEIGHTS_M[453], CONV2_WEIGHTS_M[454], CONV2_WEIGHTS_M[455], CONV2_WEIGHTS_M[456], CONV2_WEIGHTS_M[457], CONV2_WEIGHTS_M[458], CONV2_WEIGHTS_M[459], CONV2_WEIGHTS_M[460], CONV2_WEIGHTS_M[461], CONV2_WEIGHTS_M[462], CONV2_WEIGHTS_M[463], CONV2_WEIGHTS_M[464], CONV2_WEIGHTS_M[465], CONV2_WEIGHTS_M[466], CONV2_WEIGHTS_M[467], CONV2_WEIGHTS_M[468], CONV2_WEIGHTS_M[469], CONV2_WEIGHTS_M[470], CONV2_WEIGHTS_M[471], CONV2_WEIGHTS_M[472], CONV2_WEIGHTS_M[473], CONV2_WEIGHTS_M[474], CONV2_WEIGHTS_M[475], CONV2_WEIGHTS_M[476], CONV2_WEIGHTS_M[477], CONV2_WEIGHTS_M[478], CONV2_WEIGHTS_M[479], CONV2_WEIGHTS_M[480], CONV2_WEIGHTS_M[481], CONV2_WEIGHTS_M[482], CONV2_WEIGHTS_M[483], CONV2_WEIGHTS_M[484], CONV2_WEIGHTS_M[485], CONV2_WEIGHTS_M[486], CONV2_WEIGHTS_M[487], CONV2_WEIGHTS_M[488], CONV2_WEIGHTS_M[489], CONV2_WEIGHTS_M[490], CONV2_WEIGHTS_M[491], CONV2_WEIGHTS_M[492], CONV2_WEIGHTS_M[493], CONV2_WEIGHTS_M[494], CONV2_WEIGHTS_M[495], CONV2_WEIGHTS_M[496], CONV2_WEIGHTS_M[497], CONV2_WEIGHTS_M[498], CONV2_WEIGHTS_M[499]}), 
                       .bias(CONV2_BIAS_M[4]), 
                       .dataOut(data_205));
                       
    conv2_feature c2f6(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[500], CONV2_WEIGHTS_M[501], CONV2_WEIGHTS_M[502], CONV2_WEIGHTS_M[503], CONV2_WEIGHTS_M[504], CONV2_WEIGHTS_M[505], CONV2_WEIGHTS_M[506], CONV2_WEIGHTS_M[507], CONV2_WEIGHTS_M[508], CONV2_WEIGHTS_M[509], CONV2_WEIGHTS_M[510], CONV2_WEIGHTS_M[511], CONV2_WEIGHTS_M[512], CONV2_WEIGHTS_M[513], CONV2_WEIGHTS_M[514], CONV2_WEIGHTS_M[515], CONV2_WEIGHTS_M[516], CONV2_WEIGHTS_M[517], CONV2_WEIGHTS_M[518], CONV2_WEIGHTS_M[519], CONV2_WEIGHTS_M[520], CONV2_WEIGHTS_M[521], CONV2_WEIGHTS_M[522], CONV2_WEIGHTS_M[523], CONV2_WEIGHTS_M[524], CONV2_WEIGHTS_M[525], CONV2_WEIGHTS_M[526], CONV2_WEIGHTS_M[527], CONV2_WEIGHTS_M[528], CONV2_WEIGHTS_M[529], CONV2_WEIGHTS_M[530], CONV2_WEIGHTS_M[531], CONV2_WEIGHTS_M[532], CONV2_WEIGHTS_M[533], CONV2_WEIGHTS_M[534], CONV2_WEIGHTS_M[535], CONV2_WEIGHTS_M[536], CONV2_WEIGHTS_M[537], CONV2_WEIGHTS_M[538], CONV2_WEIGHTS_M[539], CONV2_WEIGHTS_M[540], CONV2_WEIGHTS_M[541], CONV2_WEIGHTS_M[542], CONV2_WEIGHTS_M[543], CONV2_WEIGHTS_M[544], CONV2_WEIGHTS_M[545], CONV2_WEIGHTS_M[546], CONV2_WEIGHTS_M[547], CONV2_WEIGHTS_M[548], CONV2_WEIGHTS_M[549], CONV2_WEIGHTS_M[550], CONV2_WEIGHTS_M[551], CONV2_WEIGHTS_M[552], CONV2_WEIGHTS_M[553], CONV2_WEIGHTS_M[554], CONV2_WEIGHTS_M[555], CONV2_WEIGHTS_M[556], CONV2_WEIGHTS_M[557], CONV2_WEIGHTS_M[558], CONV2_WEIGHTS_M[559], CONV2_WEIGHTS_M[560], CONV2_WEIGHTS_M[561], CONV2_WEIGHTS_M[562], CONV2_WEIGHTS_M[563], CONV2_WEIGHTS_M[564], CONV2_WEIGHTS_M[565], CONV2_WEIGHTS_M[566], CONV2_WEIGHTS_M[567], CONV2_WEIGHTS_M[568], CONV2_WEIGHTS_M[569], CONV2_WEIGHTS_M[570], CONV2_WEIGHTS_M[571], CONV2_WEIGHTS_M[572], CONV2_WEIGHTS_M[573], CONV2_WEIGHTS_M[574], CONV2_WEIGHTS_M[575], CONV2_WEIGHTS_M[576], CONV2_WEIGHTS_M[577], CONV2_WEIGHTS_M[578], CONV2_WEIGHTS_M[579], CONV2_WEIGHTS_M[580], CONV2_WEIGHTS_M[581], CONV2_WEIGHTS_M[582], CONV2_WEIGHTS_M[583], CONV2_WEIGHTS_M[584], CONV2_WEIGHTS_M[585], CONV2_WEIGHTS_M[586], CONV2_WEIGHTS_M[587], CONV2_WEIGHTS_M[588], CONV2_WEIGHTS_M[589], CONV2_WEIGHTS_M[590], CONV2_WEIGHTS_M[591], CONV2_WEIGHTS_M[592], CONV2_WEIGHTS_M[593], CONV2_WEIGHTS_M[594], CONV2_WEIGHTS_M[595], CONV2_WEIGHTS_M[596], CONV2_WEIGHTS_M[597], CONV2_WEIGHTS_M[598], CONV2_WEIGHTS_M[599]}), 
                       .bias(CONV2_BIAS_M[5]), 
                       .dataOut(data_206));
                       
    conv2_feature c2f7(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[600], CONV2_WEIGHTS_M[601], CONV2_WEIGHTS_M[602], CONV2_WEIGHTS_M[603], CONV2_WEIGHTS_M[604], CONV2_WEIGHTS_M[605], CONV2_WEIGHTS_M[606], CONV2_WEIGHTS_M[607], CONV2_WEIGHTS_M[608], CONV2_WEIGHTS_M[609], CONV2_WEIGHTS_M[610], CONV2_WEIGHTS_M[611], CONV2_WEIGHTS_M[612], CONV2_WEIGHTS_M[613], CONV2_WEIGHTS_M[614], CONV2_WEIGHTS_M[615], CONV2_WEIGHTS_M[616], CONV2_WEIGHTS_M[617], CONV2_WEIGHTS_M[618], CONV2_WEIGHTS_M[619], CONV2_WEIGHTS_M[620], CONV2_WEIGHTS_M[621], CONV2_WEIGHTS_M[622], CONV2_WEIGHTS_M[623], CONV2_WEIGHTS_M[624], CONV2_WEIGHTS_M[625], CONV2_WEIGHTS_M[626], CONV2_WEIGHTS_M[627], CONV2_WEIGHTS_M[628], CONV2_WEIGHTS_M[629], CONV2_WEIGHTS_M[630], CONV2_WEIGHTS_M[631], CONV2_WEIGHTS_M[632], CONV2_WEIGHTS_M[633], CONV2_WEIGHTS_M[634], CONV2_WEIGHTS_M[635], CONV2_WEIGHTS_M[636], CONV2_WEIGHTS_M[637], CONV2_WEIGHTS_M[638], CONV2_WEIGHTS_M[639], CONV2_WEIGHTS_M[640], CONV2_WEIGHTS_M[641], CONV2_WEIGHTS_M[642], CONV2_WEIGHTS_M[643], CONV2_WEIGHTS_M[644], CONV2_WEIGHTS_M[645], CONV2_WEIGHTS_M[646], CONV2_WEIGHTS_M[647], CONV2_WEIGHTS_M[648], CONV2_WEIGHTS_M[649], CONV2_WEIGHTS_M[650], CONV2_WEIGHTS_M[651], CONV2_WEIGHTS_M[652], CONV2_WEIGHTS_M[653], CONV2_WEIGHTS_M[654], CONV2_WEIGHTS_M[655], CONV2_WEIGHTS_M[656], CONV2_WEIGHTS_M[657], CONV2_WEIGHTS_M[658], CONV2_WEIGHTS_M[659], CONV2_WEIGHTS_M[660], CONV2_WEIGHTS_M[661], CONV2_WEIGHTS_M[662], CONV2_WEIGHTS_M[663], CONV2_WEIGHTS_M[664], CONV2_WEIGHTS_M[665], CONV2_WEIGHTS_M[666], CONV2_WEIGHTS_M[667], CONV2_WEIGHTS_M[668], CONV2_WEIGHTS_M[669], CONV2_WEIGHTS_M[670], CONV2_WEIGHTS_M[671], CONV2_WEIGHTS_M[672], CONV2_WEIGHTS_M[673], CONV2_WEIGHTS_M[674], CONV2_WEIGHTS_M[675], CONV2_WEIGHTS_M[676], CONV2_WEIGHTS_M[677], CONV2_WEIGHTS_M[678], CONV2_WEIGHTS_M[679], CONV2_WEIGHTS_M[680], CONV2_WEIGHTS_M[681], CONV2_WEIGHTS_M[682], CONV2_WEIGHTS_M[683], CONV2_WEIGHTS_M[684], CONV2_WEIGHTS_M[685], CONV2_WEIGHTS_M[686], CONV2_WEIGHTS_M[687], CONV2_WEIGHTS_M[688], CONV2_WEIGHTS_M[689], CONV2_WEIGHTS_M[690], CONV2_WEIGHTS_M[691], CONV2_WEIGHTS_M[692], CONV2_WEIGHTS_M[693], CONV2_WEIGHTS_M[694], CONV2_WEIGHTS_M[695], CONV2_WEIGHTS_M[696], CONV2_WEIGHTS_M[697], CONV2_WEIGHTS_M[698], CONV2_WEIGHTS_M[699]}), 
                       .bias(CONV2_BIAS_M[6]), 
                       .dataOut(data_207));
                       
    conv2_feature c2f8(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[700], CONV2_WEIGHTS_M[701], CONV2_WEIGHTS_M[702], CONV2_WEIGHTS_M[703], CONV2_WEIGHTS_M[704], CONV2_WEIGHTS_M[705], CONV2_WEIGHTS_M[706], CONV2_WEIGHTS_M[707], CONV2_WEIGHTS_M[708], CONV2_WEIGHTS_M[709], CONV2_WEIGHTS_M[710], CONV2_WEIGHTS_M[711], CONV2_WEIGHTS_M[712], CONV2_WEIGHTS_M[713], CONV2_WEIGHTS_M[714], CONV2_WEIGHTS_M[715], CONV2_WEIGHTS_M[716], CONV2_WEIGHTS_M[717], CONV2_WEIGHTS_M[718], CONV2_WEIGHTS_M[719], CONV2_WEIGHTS_M[720], CONV2_WEIGHTS_M[721], CONV2_WEIGHTS_M[722], CONV2_WEIGHTS_M[723], CONV2_WEIGHTS_M[724], CONV2_WEIGHTS_M[725], CONV2_WEIGHTS_M[726], CONV2_WEIGHTS_M[727], CONV2_WEIGHTS_M[728], CONV2_WEIGHTS_M[729], CONV2_WEIGHTS_M[730], CONV2_WEIGHTS_M[731], CONV2_WEIGHTS_M[732], CONV2_WEIGHTS_M[733], CONV2_WEIGHTS_M[734], CONV2_WEIGHTS_M[735], CONV2_WEIGHTS_M[736], CONV2_WEIGHTS_M[737], CONV2_WEIGHTS_M[738], CONV2_WEIGHTS_M[739], CONV2_WEIGHTS_M[740], CONV2_WEIGHTS_M[741], CONV2_WEIGHTS_M[742], CONV2_WEIGHTS_M[743], CONV2_WEIGHTS_M[744], CONV2_WEIGHTS_M[745], CONV2_WEIGHTS_M[746], CONV2_WEIGHTS_M[747], CONV2_WEIGHTS_M[748], CONV2_WEIGHTS_M[749], CONV2_WEIGHTS_M[750], CONV2_WEIGHTS_M[751], CONV2_WEIGHTS_M[752], CONV2_WEIGHTS_M[753], CONV2_WEIGHTS_M[754], CONV2_WEIGHTS_M[755], CONV2_WEIGHTS_M[756], CONV2_WEIGHTS_M[757], CONV2_WEIGHTS_M[758], CONV2_WEIGHTS_M[759], CONV2_WEIGHTS_M[760], CONV2_WEIGHTS_M[761], CONV2_WEIGHTS_M[762], CONV2_WEIGHTS_M[763], CONV2_WEIGHTS_M[764], CONV2_WEIGHTS_M[765], CONV2_WEIGHTS_M[766], CONV2_WEIGHTS_M[767], CONV2_WEIGHTS_M[768], CONV2_WEIGHTS_M[769], CONV2_WEIGHTS_M[770], CONV2_WEIGHTS_M[771], CONV2_WEIGHTS_M[772], CONV2_WEIGHTS_M[773], CONV2_WEIGHTS_M[774], CONV2_WEIGHTS_M[775], CONV2_WEIGHTS_M[776], CONV2_WEIGHTS_M[777], CONV2_WEIGHTS_M[778], CONV2_WEIGHTS_M[779], CONV2_WEIGHTS_M[780], CONV2_WEIGHTS_M[781], CONV2_WEIGHTS_M[782], CONV2_WEIGHTS_M[783], CONV2_WEIGHTS_M[784], CONV2_WEIGHTS_M[785], CONV2_WEIGHTS_M[786], CONV2_WEIGHTS_M[787], CONV2_WEIGHTS_M[788], CONV2_WEIGHTS_M[789], CONV2_WEIGHTS_M[790], CONV2_WEIGHTS_M[791], CONV2_WEIGHTS_M[792], CONV2_WEIGHTS_M[793], CONV2_WEIGHTS_M[794], CONV2_WEIGHTS_M[795], CONV2_WEIGHTS_M[796], CONV2_WEIGHTS_M[797], CONV2_WEIGHTS_M[798], CONV2_WEIGHTS_M[799]}), 
                       .bias(CONV2_BIAS_M[7]), 
                       .dataOut(data_208));
                       
    conv2_feature c2f9(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[800], CONV2_WEIGHTS_M[801], CONV2_WEIGHTS_M[802], CONV2_WEIGHTS_M[803], CONV2_WEIGHTS_M[804], CONV2_WEIGHTS_M[805], CONV2_WEIGHTS_M[806], CONV2_WEIGHTS_M[807], CONV2_WEIGHTS_M[808], CONV2_WEIGHTS_M[809], CONV2_WEIGHTS_M[810], CONV2_WEIGHTS_M[811], CONV2_WEIGHTS_M[812], CONV2_WEIGHTS_M[813], CONV2_WEIGHTS_M[814], CONV2_WEIGHTS_M[815], CONV2_WEIGHTS_M[816], CONV2_WEIGHTS_M[817], CONV2_WEIGHTS_M[818], CONV2_WEIGHTS_M[819], CONV2_WEIGHTS_M[820], CONV2_WEIGHTS_M[821], CONV2_WEIGHTS_M[822], CONV2_WEIGHTS_M[823], CONV2_WEIGHTS_M[824], CONV2_WEIGHTS_M[825], CONV2_WEIGHTS_M[826], CONV2_WEIGHTS_M[827], CONV2_WEIGHTS_M[828], CONV2_WEIGHTS_M[829], CONV2_WEIGHTS_M[830], CONV2_WEIGHTS_M[831], CONV2_WEIGHTS_M[832], CONV2_WEIGHTS_M[833], CONV2_WEIGHTS_M[834], CONV2_WEIGHTS_M[835], CONV2_WEIGHTS_M[836], CONV2_WEIGHTS_M[837], CONV2_WEIGHTS_M[838], CONV2_WEIGHTS_M[839], CONV2_WEIGHTS_M[840], CONV2_WEIGHTS_M[841], CONV2_WEIGHTS_M[842], CONV2_WEIGHTS_M[843], CONV2_WEIGHTS_M[844], CONV2_WEIGHTS_M[845], CONV2_WEIGHTS_M[846], CONV2_WEIGHTS_M[847], CONV2_WEIGHTS_M[848], CONV2_WEIGHTS_M[849], CONV2_WEIGHTS_M[850], CONV2_WEIGHTS_M[851], CONV2_WEIGHTS_M[852], CONV2_WEIGHTS_M[853], CONV2_WEIGHTS_M[854], CONV2_WEIGHTS_M[855], CONV2_WEIGHTS_M[856], CONV2_WEIGHTS_M[857], CONV2_WEIGHTS_M[858], CONV2_WEIGHTS_M[859], CONV2_WEIGHTS_M[860], CONV2_WEIGHTS_M[861], CONV2_WEIGHTS_M[862], CONV2_WEIGHTS_M[863], CONV2_WEIGHTS_M[864], CONV2_WEIGHTS_M[865], CONV2_WEIGHTS_M[866], CONV2_WEIGHTS_M[867], CONV2_WEIGHTS_M[868], CONV2_WEIGHTS_M[869], CONV2_WEIGHTS_M[870], CONV2_WEIGHTS_M[871], CONV2_WEIGHTS_M[872], CONV2_WEIGHTS_M[873], CONV2_WEIGHTS_M[874], CONV2_WEIGHTS_M[875], CONV2_WEIGHTS_M[876], CONV2_WEIGHTS_M[877], CONV2_WEIGHTS_M[878], CONV2_WEIGHTS_M[879], CONV2_WEIGHTS_M[880], CONV2_WEIGHTS_M[881], CONV2_WEIGHTS_M[882], CONV2_WEIGHTS_M[883], CONV2_WEIGHTS_M[884], CONV2_WEIGHTS_M[885], CONV2_WEIGHTS_M[886], CONV2_WEIGHTS_M[887], CONV2_WEIGHTS_M[888], CONV2_WEIGHTS_M[889], CONV2_WEIGHTS_M[890], CONV2_WEIGHTS_M[891], CONV2_WEIGHTS_M[892], CONV2_WEIGHTS_M[893], CONV2_WEIGHTS_M[894], CONV2_WEIGHTS_M[895], CONV2_WEIGHTS_M[896], CONV2_WEIGHTS_M[897], CONV2_WEIGHTS_M[898], CONV2_WEIGHTS_M[899]}), 
                       .bias(CONV2_BIAS_M[8]), 
                       .dataOut(data_209));
                       
    conv2_feature c2f10(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[900], CONV2_WEIGHTS_M[901], CONV2_WEIGHTS_M[902], CONV2_WEIGHTS_M[903], CONV2_WEIGHTS_M[904], CONV2_WEIGHTS_M[905], CONV2_WEIGHTS_M[906], CONV2_WEIGHTS_M[907], CONV2_WEIGHTS_M[908], CONV2_WEIGHTS_M[909], CONV2_WEIGHTS_M[910], CONV2_WEIGHTS_M[911], CONV2_WEIGHTS_M[912], CONV2_WEIGHTS_M[913], CONV2_WEIGHTS_M[914], CONV2_WEIGHTS_M[915], CONV2_WEIGHTS_M[916], CONV2_WEIGHTS_M[917], CONV2_WEIGHTS_M[918], CONV2_WEIGHTS_M[919], CONV2_WEIGHTS_M[920], CONV2_WEIGHTS_M[921], CONV2_WEIGHTS_M[922], CONV2_WEIGHTS_M[923], CONV2_WEIGHTS_M[924], CONV2_WEIGHTS_M[925], CONV2_WEIGHTS_M[926], CONV2_WEIGHTS_M[927], CONV2_WEIGHTS_M[928], CONV2_WEIGHTS_M[929], CONV2_WEIGHTS_M[930], CONV2_WEIGHTS_M[931], CONV2_WEIGHTS_M[932], CONV2_WEIGHTS_M[933], CONV2_WEIGHTS_M[934], CONV2_WEIGHTS_M[935], CONV2_WEIGHTS_M[936], CONV2_WEIGHTS_M[937], CONV2_WEIGHTS_M[938], CONV2_WEIGHTS_M[939], CONV2_WEIGHTS_M[940], CONV2_WEIGHTS_M[941], CONV2_WEIGHTS_M[942], CONV2_WEIGHTS_M[943], CONV2_WEIGHTS_M[944], CONV2_WEIGHTS_M[945], CONV2_WEIGHTS_M[946], CONV2_WEIGHTS_M[947], CONV2_WEIGHTS_M[948], CONV2_WEIGHTS_M[949], CONV2_WEIGHTS_M[950], CONV2_WEIGHTS_M[951], CONV2_WEIGHTS_M[952], CONV2_WEIGHTS_M[953], CONV2_WEIGHTS_M[954], CONV2_WEIGHTS_M[955], CONV2_WEIGHTS_M[956], CONV2_WEIGHTS_M[957], CONV2_WEIGHTS_M[958], CONV2_WEIGHTS_M[959], CONV2_WEIGHTS_M[960], CONV2_WEIGHTS_M[961], CONV2_WEIGHTS_M[962], CONV2_WEIGHTS_M[963], CONV2_WEIGHTS_M[964], CONV2_WEIGHTS_M[965], CONV2_WEIGHTS_M[966], CONV2_WEIGHTS_M[967], CONV2_WEIGHTS_M[968], CONV2_WEIGHTS_M[969], CONV2_WEIGHTS_M[970], CONV2_WEIGHTS_M[971], CONV2_WEIGHTS_M[972], CONV2_WEIGHTS_M[973], CONV2_WEIGHTS_M[974], CONV2_WEIGHTS_M[975], CONV2_WEIGHTS_M[976], CONV2_WEIGHTS_M[977], CONV2_WEIGHTS_M[978], CONV2_WEIGHTS_M[979], CONV2_WEIGHTS_M[980], CONV2_WEIGHTS_M[981], CONV2_WEIGHTS_M[982], CONV2_WEIGHTS_M[983], CONV2_WEIGHTS_M[984], CONV2_WEIGHTS_M[985], CONV2_WEIGHTS_M[986], CONV2_WEIGHTS_M[987], CONV2_WEIGHTS_M[988], CONV2_WEIGHTS_M[989], CONV2_WEIGHTS_M[990], CONV2_WEIGHTS_M[991], CONV2_WEIGHTS_M[992], CONV2_WEIGHTS_M[993], CONV2_WEIGHTS_M[994], CONV2_WEIGHTS_M[995], CONV2_WEIGHTS_M[996], CONV2_WEIGHTS_M[997], CONV2_WEIGHTS_M[998], CONV2_WEIGHTS_M[999]}), 
                       .bias(CONV2_BIAS_M[9]), 
                       .dataOut(data_210));
    
    conv2_feature c2f11(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[1000], CONV2_WEIGHTS_M[1001], CONV2_WEIGHTS_M[1002], CONV2_WEIGHTS_M[1003], CONV2_WEIGHTS_M[1004], CONV2_WEIGHTS_M[1005], CONV2_WEIGHTS_M[1006], CONV2_WEIGHTS_M[1007], CONV2_WEIGHTS_M[1008], CONV2_WEIGHTS_M[1009], CONV2_WEIGHTS_M[1010], CONV2_WEIGHTS_M[1011], CONV2_WEIGHTS_M[1012], CONV2_WEIGHTS_M[1013], CONV2_WEIGHTS_M[1014], CONV2_WEIGHTS_M[1015], CONV2_WEIGHTS_M[1016], CONV2_WEIGHTS_M[1017], CONV2_WEIGHTS_M[1018], CONV2_WEIGHTS_M[1019], CONV2_WEIGHTS_M[1020], CONV2_WEIGHTS_M[1021], CONV2_WEIGHTS_M[1022], CONV2_WEIGHTS_M[1023], CONV2_WEIGHTS_M[1024], CONV2_WEIGHTS_M[1025], CONV2_WEIGHTS_M[1026], CONV2_WEIGHTS_M[1027], CONV2_WEIGHTS_M[1028], CONV2_WEIGHTS_M[1029], CONV2_WEIGHTS_M[1030], CONV2_WEIGHTS_M[1031], CONV2_WEIGHTS_M[1032], CONV2_WEIGHTS_M[1033], CONV2_WEIGHTS_M[1034], CONV2_WEIGHTS_M[1035], CONV2_WEIGHTS_M[1036], CONV2_WEIGHTS_M[1037], CONV2_WEIGHTS_M[1038], CONV2_WEIGHTS_M[1039], CONV2_WEIGHTS_M[1040], CONV2_WEIGHTS_M[1041], CONV2_WEIGHTS_M[1042], CONV2_WEIGHTS_M[1043], CONV2_WEIGHTS_M[1044], CONV2_WEIGHTS_M[1045], CONV2_WEIGHTS_M[1046], CONV2_WEIGHTS_M[1047], CONV2_WEIGHTS_M[1048], CONV2_WEIGHTS_M[1049], CONV2_WEIGHTS_M[1050], CONV2_WEIGHTS_M[1051], CONV2_WEIGHTS_M[1052], CONV2_WEIGHTS_M[1053], CONV2_WEIGHTS_M[1054], CONV2_WEIGHTS_M[1055], CONV2_WEIGHTS_M[1056], CONV2_WEIGHTS_M[1057], CONV2_WEIGHTS_M[1058], CONV2_WEIGHTS_M[1059], CONV2_WEIGHTS_M[1060], CONV2_WEIGHTS_M[1061], CONV2_WEIGHTS_M[1062], CONV2_WEIGHTS_M[1063], CONV2_WEIGHTS_M[1064], CONV2_WEIGHTS_M[1065], CONV2_WEIGHTS_M[1066], CONV2_WEIGHTS_M[1067], CONV2_WEIGHTS_M[1068], CONV2_WEIGHTS_M[1069], CONV2_WEIGHTS_M[1070], CONV2_WEIGHTS_M[1071], CONV2_WEIGHTS_M[1072], CONV2_WEIGHTS_M[1073], CONV2_WEIGHTS_M[1074], CONV2_WEIGHTS_M[1075], CONV2_WEIGHTS_M[1076], CONV2_WEIGHTS_M[1077], CONV2_WEIGHTS_M[1078], CONV2_WEIGHTS_M[1079], CONV2_WEIGHTS_M[1080], CONV2_WEIGHTS_M[1081], CONV2_WEIGHTS_M[1082], CONV2_WEIGHTS_M[1083], CONV2_WEIGHTS_M[1084], CONV2_WEIGHTS_M[1085], CONV2_WEIGHTS_M[1086], CONV2_WEIGHTS_M[1087], CONV2_WEIGHTS_M[1088], CONV2_WEIGHTS_M[1089], CONV2_WEIGHTS_M[1090], CONV2_WEIGHTS_M[1091], CONV2_WEIGHTS_M[1092], CONV2_WEIGHTS_M[1093], CONV2_WEIGHTS_M[1094], CONV2_WEIGHTS_M[1095], CONV2_WEIGHTS_M[1096], CONV2_WEIGHTS_M[1097], CONV2_WEIGHTS_M[1098], CONV2_WEIGHTS_M[1099]}), 
                       .bias(CONV2_BIAS_M[10]), 
                       .dataOut(data_211));
    
    conv2_feature c2f12(.dataIn1(avg_data_11), 
                       .dataIn2(avg_data_12), 
                       .dataIn3(avg_data_13), 
                       .dataIn4(avg_data_14), 
                       .weights({CONV2_WEIGHTS_M[1100], CONV2_WEIGHTS_M[1101], CONV2_WEIGHTS_M[1102], CONV2_WEIGHTS_M[1103], CONV2_WEIGHTS_M[1104], CONV2_WEIGHTS_M[1105], CONV2_WEIGHTS_M[1106], CONV2_WEIGHTS_M[1107], CONV2_WEIGHTS_M[1108], CONV2_WEIGHTS_M[1109], CONV2_WEIGHTS_M[1110], CONV2_WEIGHTS_M[1111], CONV2_WEIGHTS_M[1112], CONV2_WEIGHTS_M[1113], CONV2_WEIGHTS_M[1114], CONV2_WEIGHTS_M[1115], CONV2_WEIGHTS_M[1116], CONV2_WEIGHTS_M[1117], CONV2_WEIGHTS_M[1118], CONV2_WEIGHTS_M[1119], CONV2_WEIGHTS_M[1120], CONV2_WEIGHTS_M[1121], CONV2_WEIGHTS_M[1122], CONV2_WEIGHTS_M[1123], CONV2_WEIGHTS_M[1124], CONV2_WEIGHTS_M[1125], CONV2_WEIGHTS_M[1126], CONV2_WEIGHTS_M[1127], CONV2_WEIGHTS_M[1128], CONV2_WEIGHTS_M[1129], CONV2_WEIGHTS_M[1130], CONV2_WEIGHTS_M[1131], CONV2_WEIGHTS_M[1132], CONV2_WEIGHTS_M[1133], CONV2_WEIGHTS_M[1134], CONV2_WEIGHTS_M[1135], CONV2_WEIGHTS_M[1136], CONV2_WEIGHTS_M[1137], CONV2_WEIGHTS_M[1138], CONV2_WEIGHTS_M[1139], CONV2_WEIGHTS_M[1140], CONV2_WEIGHTS_M[1141], CONV2_WEIGHTS_M[1142], CONV2_WEIGHTS_M[1143], CONV2_WEIGHTS_M[1144], CONV2_WEIGHTS_M[1145], CONV2_WEIGHTS_M[1146], CONV2_WEIGHTS_M[1147], CONV2_WEIGHTS_M[1148], CONV2_WEIGHTS_M[1149], CONV2_WEIGHTS_M[1150], CONV2_WEIGHTS_M[1151], CONV2_WEIGHTS_M[1152], CONV2_WEIGHTS_M[1153], CONV2_WEIGHTS_M[1154], CONV2_WEIGHTS_M[1155], CONV2_WEIGHTS_M[1156], CONV2_WEIGHTS_M[1157], CONV2_WEIGHTS_M[1158], CONV2_WEIGHTS_M[1159], CONV2_WEIGHTS_M[1160], CONV2_WEIGHTS_M[1161], CONV2_WEIGHTS_M[1162], CONV2_WEIGHTS_M[1163], CONV2_WEIGHTS_M[1164], CONV2_WEIGHTS_M[1165], CONV2_WEIGHTS_M[1166], CONV2_WEIGHTS_M[1167], CONV2_WEIGHTS_M[1168], CONV2_WEIGHTS_M[1169], CONV2_WEIGHTS_M[1170], CONV2_WEIGHTS_M[1171], CONV2_WEIGHTS_M[1172], CONV2_WEIGHTS_M[1173], CONV2_WEIGHTS_M[1174], CONV2_WEIGHTS_M[1175], CONV2_WEIGHTS_M[1176], CONV2_WEIGHTS_M[1177], CONV2_WEIGHTS_M[1178], CONV2_WEIGHTS_M[1179], CONV2_WEIGHTS_M[1180], CONV2_WEIGHTS_M[1181], CONV2_WEIGHTS_M[1182], CONV2_WEIGHTS_M[1183], CONV2_WEIGHTS_M[1184], CONV2_WEIGHTS_M[1185], CONV2_WEIGHTS_M[1186], CONV2_WEIGHTS_M[1187], CONV2_WEIGHTS_M[1188], CONV2_WEIGHTS_M[1189], CONV2_WEIGHTS_M[1190], CONV2_WEIGHTS_M[1191], CONV2_WEIGHTS_M[1192], CONV2_WEIGHTS_M[1193], CONV2_WEIGHTS_M[1194], CONV2_WEIGHTS_M[1195], CONV2_WEIGHTS_M[1196], CONV2_WEIGHTS_M[1197], CONV2_WEIGHTS_M[1198], CONV2_WEIGHTS_M[1199]}), 
                       .bias(CONV2_BIAS_M[11]), 
                       .dataOut(data_212));
  
    //AVERAGE POOLING 2
    AveragePool_2 avg_p2_01(.data(data_201), .pool(avg_data_201));
    AveragePool_2 avg_p2_02(.data(data_202), .pool(avg_data_202));
    AveragePool_2 avg_p2_03(.data(data_203), .pool(avg_data_203));
    AveragePool_2 avg_p2_04(.data(data_204), .pool(avg_data_204));
    AveragePool_2 avg_p2_05(.data(data_205), .pool(avg_data_205));
    AveragePool_2 avg_p2_06(.data(data_206), .pool(avg_data_206));
    AveragePool_2 avg_p2_07(.data(data_207), .pool(avg_data_207));
    AveragePool_2 avg_p2_08(.data(data_208), .pool(avg_data_208));
    AveragePool_2 avg_p2_09(.data(data_209), .pool(avg_data_209));
    AveragePool_2 avg_p2_10(.data(data_210), .pool(avg_data_210));
    AveragePool_2 avg_p2_11(.data(data_211), .pool(avg_data_211));
    AveragePool_2 avg_p2_12(.data(data_212), .pool(avg_data_212));
    
    //FULLY CONNECTED LAYER
    FCLayer result0 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1919], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1918], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1917], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1916], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1915], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1914], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1913], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1912], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1911], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1910], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1909], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1908], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1907], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1906], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1905], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1904], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1903], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1902], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1901], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1900], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1899], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1898], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1897], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1896], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1895], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1894], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1893], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1892], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1891], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1890], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1889], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1888], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1887], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1886], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1885], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1884], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1883], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1882], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1881], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1880], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1879], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1878], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1877], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1876], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1875], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1874], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1873], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1872], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1871], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1870], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1869], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1868], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1867], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1866], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1865], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1864], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1863], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1862], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1861], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1860], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1859], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1858], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1857], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1856], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1855], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1854], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1853], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1852], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1851], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1850], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1849], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1848], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1847], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1846], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1845], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1844], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1843], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1842], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1841], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1840], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1839], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1838], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1837], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1836], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1835], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1834], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1833], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1832], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1831], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1830], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1829], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1828], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1827], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1826], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1825], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1824], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1823], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1822], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1821], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1820], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1819], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1818], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1817], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1816], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1815], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1814], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1813], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1812], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1811], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1810], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1809], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1808], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1807], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1806], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1805], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1804], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1803], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1802], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1801], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1800], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1799], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1798], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1797], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1796], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1795], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1794], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1793], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1792], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1791], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1790], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1789], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1788], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1787], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1786], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1785], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1784], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1783], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1782], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1781], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1780], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1779], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1778], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1777], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1776], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1775], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1774], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1773], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1772], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1771], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1770], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1769], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1768], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1767], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1766], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1765], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1764], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1763], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1762], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1761], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1760], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1759], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1758], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1757], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1756], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1755], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1754], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1753], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1752], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1751], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1750], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1749], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1748], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1747], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1746], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1745], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1744], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1743], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1742], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1741], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1740], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1739], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1738], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1737], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1736], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1735], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1734], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1733], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1732], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1731], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1730], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1729], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1728]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*9]),
    .result(result_0));
    
  FCLayer result1 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1727], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1726], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1725], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1724], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1723], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1722], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1721], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1720], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1719], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1718], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1717], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1716], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1715], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1714], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1713], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1712], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1711], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1710], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1709], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1708], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1707], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1706], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1705], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1704], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1703], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1702], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1701], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1700], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1699], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1698], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1697], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1696], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1695], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1694], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1693], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1692], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1691], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1690], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1689], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1688], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1687], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1686], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1685], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1684], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1683], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1682], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1681], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1680], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1679], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1678], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1677], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1676], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1675], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1674], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1673], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1672], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1671], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1670], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1669], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1668], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1667], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1666], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1665], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1664], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1663], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1662], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1661], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1660], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1659], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1658], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1657], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1656], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1655], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1654], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1653], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1652], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1651], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1650], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1649], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1648], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1647], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1646], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1645], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1644], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1643], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1642], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1641], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1640], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1639], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1638], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1637], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1636], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1635], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1634], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1633], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1632], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1631], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1630], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1629], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1628], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1627], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1626], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1625], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1624], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1623], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1622], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1621], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1620], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1619], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1618], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1617], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1616], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1615], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1614], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1613], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1612], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1611], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1610], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1609], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1608], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1607], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1606], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1605], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1604], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1603], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1602], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1601], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1600], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1599], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1598], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1597], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1596], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1595], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1594], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1593], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1592], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1591], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1590], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1589], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1588], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1587], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1586], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1585], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1584], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1583], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1582], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1581], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1580], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1579], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1578], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1577], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1576], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1575], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1574], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1573], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1572], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1571], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1570], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1569], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1568], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1567], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1566], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1565], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1564], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1563], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1562], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1561], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1560], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1559], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1558], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1557], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1556], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1555], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1554], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1553], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1552], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1551], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1550], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1549], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1548], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1547], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1546], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1545], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1544], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1543], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1542], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1541], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1540], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1539], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1538], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1537], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1536]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*8]),
    .result(result_1));
    
  FCLayer result2 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1535], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1534], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1533], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1532], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1531], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1530], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1529], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1528], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1527], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1526], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1525], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1524], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1523], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1522], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1521], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1520], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1519], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1518], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1517], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1516], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1515], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1514], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1513], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1512], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1511], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1510], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1509], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1508], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1507], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1506], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1505], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1504], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1503], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1502], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1501], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1500], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1499], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1498], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1497], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1496], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1495], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1494], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1493], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1492], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1491], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1490], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1489], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1488], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1487], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1486], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1485], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1484], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1483], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1482], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1481], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1480], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1479], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1478], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1477], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1476], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1475], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1474], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1473], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1472], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1471], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1470], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1469], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1468], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1467], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1466], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1465], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1464], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1463], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1462], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1461], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1460], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1459], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1458], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1457], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1456], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1455], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1454], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1453], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1452], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1451], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1450], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1449], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1448], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1447], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1446], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1445], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1444], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1443], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1442], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1441], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1440], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1439], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1438], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1437], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1436], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1435], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1434], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1433], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1432], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1431], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1430], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1429], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1428], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1427], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1426], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1425], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1424], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1423], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1422], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1421], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1420], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1419], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1418], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1417], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1416], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1415], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1414], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1413], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1412], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1411], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1410], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1409], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1408], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1407], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1406], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1405], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1404], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1403], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1402], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1401], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1400], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1399], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1398], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1397], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1396], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1395], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1394], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1393], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1392], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1391], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1390], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1389], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1388], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1387], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1386], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1385], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1384], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1383], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1382], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1381], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1380], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1379], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1378], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1377], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1376], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1375], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1374], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1373], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1372], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1371], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1370], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1369], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1368], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1367], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1366], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1365], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1364], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1363], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1362], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1361], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1360], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1359], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1358], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1357], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1356], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1355], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1354], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1353], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1352], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1351], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1350], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1349], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1348], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1347], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1346], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1345], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1344]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*7]),
    .result(result_2));
    
  FCLayer result3 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1343], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1342], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1341], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1340], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1339], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1338], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1337], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1336], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1335], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1334], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1333], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1332], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1331], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1330], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1329], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1328], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1327], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1326], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1325], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1324], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1323], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1322], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1321], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1320], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1319], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1318], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1317], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1316], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1315], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1314], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1313], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1312], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1311], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1310], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1309], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1308], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1307], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1306], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1305], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1304], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1303], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1302], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1301], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1300], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1299], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1298], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1297], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1296], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1295], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1294], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1293], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1292], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1291], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1290], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1289], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1288], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1287], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1286], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1285], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1284], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1283], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1282], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1281], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1280], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1279], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1278], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1277], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1276], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1275], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1274], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1273], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1272], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1271], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1270], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1269], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1268], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1267], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1266], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1265], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1264], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1263], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1262], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1261], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1260], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1259], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1258], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1257], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1256], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1255], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1254], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1253], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1252], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1251], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1250], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1249], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1248], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1247], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1246], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1245], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1244], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1243], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1242], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1241], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1240], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1239], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1238], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1237], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1236], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1235], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1234], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1233], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1232], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1231], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1230], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1229], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1228], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1227], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1226], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1225], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1224], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1223], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1222], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1221], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1220], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1219], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1218], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1217], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1216], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1215], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1214], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1213], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1212], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1211], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1210], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1209], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1208], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1207], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1206], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1205], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1204], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1203], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1202], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1201], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1200], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1199], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1198], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1197], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1196], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1195], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1194], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1193], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1192], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1191], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1190], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1189], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1188], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1187], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1186], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1185], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1184], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1183], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1182], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1181], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1180], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1179], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1178], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1177], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1176], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1175], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1174], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1173], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1172], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1171], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1170], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1169], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1168], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1167], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1166], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1165], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1164], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1163], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1162], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1161], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1160], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1159], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1158], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1157], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1156], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1155], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1154], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1153], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1152]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*6]),
    .result(result_3));
    
  FCLayer result4 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1151], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1150], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1149], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1148], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1147], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1146], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1145], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1144], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1143], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1142], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1141], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1140], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1139], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1138], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1137], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1136], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1135], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1134], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1133], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1132], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1131], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1130], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1129], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1128], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1127], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1126], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1125], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1124], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1123], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1122], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1121], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1120], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1119], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1118], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1117], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1116], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1115], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1114], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1113], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1112], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1111], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1110], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1109], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1108], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1107], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1106], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1105], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1104], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1103], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1102], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1101], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1100], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1099], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1098], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1097], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1096], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1095], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1094], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1093], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1092], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1091], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1090], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1089], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1088], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1087], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1086], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1085], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1084], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1083], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1082], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1081], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1080], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1079], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1078], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1077], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1076], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1075], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1074], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1073], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1072], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1071], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1070], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1069], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1068], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1067], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1066], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1065], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1064], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1063], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1062], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1061], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1060], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1059], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1058], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1057], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1056], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1055], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1054], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1053], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1052], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1051], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1050], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1049], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1048], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1047], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1046], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1045], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1044], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1043], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1042], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1041], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1040], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1039], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1038], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1037], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1036], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1035], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1034], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1033], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1032], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1031], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1030], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1029], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1028], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1027], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1026], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1025], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1024], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1023], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1022], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1021], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1020], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1019], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1018], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1017], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1016], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1015], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1014], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1013], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1012], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1011], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1010], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1009], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1008], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1007], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1006], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1005], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1004], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1003], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1002], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1001], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1000], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*999], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*998], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*997], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*996], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*995], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*994], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*993], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*992], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*991], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*990], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*989], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*988], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*987], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*986], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*985], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*984], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*983], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*982], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*981], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*980], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*979], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*978], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*977], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*976], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*975], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*974], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*973], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*972], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*971], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*970], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*969], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*968], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*967], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*966], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*965], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*964], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*963], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*962], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*961], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*960]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*5]),
    .result(result_4));
    
  FCLayer result5 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*959], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*958], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*957], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*956], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*955], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*954], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*953], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*952], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*951], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*950], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*949], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*948], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*947], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*946], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*945], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*944], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*943], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*942], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*941], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*940], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*939], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*938], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*937], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*936], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*935], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*934], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*933], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*932], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*931], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*930], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*929], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*928], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*927], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*926], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*925], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*924], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*923], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*922], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*921], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*920], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*919], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*918], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*917], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*916], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*915], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*914], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*913], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*912], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*911], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*910], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*909], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*908], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*907], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*906], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*905], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*904], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*903], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*902], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*901], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*900], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*899], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*898], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*897], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*896], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*895], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*894], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*893], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*892], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*891], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*890], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*889], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*888], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*887], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*886], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*885], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*884], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*883], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*882], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*881], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*880], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*879], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*878], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*877], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*876], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*875], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*874], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*873], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*872], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*871], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*870], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*869], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*868], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*867], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*866], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*865], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*864], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*863], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*862], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*861], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*860], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*859], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*858], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*857], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*856], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*855], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*854], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*853], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*852], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*851], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*850], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*849], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*848], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*847], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*846], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*845], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*844], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*843], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*842], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*841], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*840], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*839], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*838], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*837], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*836], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*835], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*834], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*833], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*832], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*831], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*830], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*829], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*828], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*827], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*826], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*825], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*824], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*823], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*822], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*821], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*820], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*819], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*818], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*817], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*816], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*815], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*814], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*813], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*812], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*811], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*810], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*809], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*808], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*807], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*806], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*805], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*804], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*803], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*802], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*801], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*800], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*799], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*798], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*797], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*796], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*795], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*794], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*793], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*792], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*791], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*790], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*789], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*788], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*787], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*786], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*785], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*784], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*783], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*782], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*781], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*780], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*779], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*778], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*777], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*776], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*775], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*774], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*773], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*772], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*771], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*770], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*769], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*768]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*4]),
    .result(result_5));
    
  FCLayer result6 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*767], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*766], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*765], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*764], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*763], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*762], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*761], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*760], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*759], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*758], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*757], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*756], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*755], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*754], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*753], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*752], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*751], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*750], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*749], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*748], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*747], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*746], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*745], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*744], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*743], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*742], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*741], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*740], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*739], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*738], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*737], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*736], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*735], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*734], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*733], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*732], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*731], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*730], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*729], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*728], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*727], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*726], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*725], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*724], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*723], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*722], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*721], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*720], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*719], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*718], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*717], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*716], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*715], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*714], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*713], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*712], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*711], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*710], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*709], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*708], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*707], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*706], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*705], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*704], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*703], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*702], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*701], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*700], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*699], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*698], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*697], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*696], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*695], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*694], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*693], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*692], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*691], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*690], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*689], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*688], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*687], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*686], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*685], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*684], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*683], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*682], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*681], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*680], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*679], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*678], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*677], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*676], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*675], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*674], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*673], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*672], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*671], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*670], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*669], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*668], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*667], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*666], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*665], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*664], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*663], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*662], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*661], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*660], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*659], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*658], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*657], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*656], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*655], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*654], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*653], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*652], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*651], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*650], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*649], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*648], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*647], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*646], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*645], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*644], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*643], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*642], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*641], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*640], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*639], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*638], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*637], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*636], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*635], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*634], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*633], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*632], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*631], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*630], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*629], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*628], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*627], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*626], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*625], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*624], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*623], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*622], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*621], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*620], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*619], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*618], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*617], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*616], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*615], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*614], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*613], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*612], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*611], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*610], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*609], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*608], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*607], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*606], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*605], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*604], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*603], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*602], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*601], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*600], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*599], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*598], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*597], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*596], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*595], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*594], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*593], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*592], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*591], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*590], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*589], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*588], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*587], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*586], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*585], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*584], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*583], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*582], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*581], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*580], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*579], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*578], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*577], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*576]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*3]),
    .result(result_6));
    
  FCLayer result7 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*575], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*574], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*573], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*572], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*571], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*570], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*569], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*568], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*567], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*566], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*565], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*564], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*563], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*562], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*561], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*560], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*559], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*558], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*557], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*556], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*555], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*554], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*553], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*552], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*551], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*550], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*549], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*548], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*547], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*546], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*545], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*544], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*543], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*542], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*541], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*540], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*539], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*538], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*537], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*536], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*535], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*534], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*533], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*532], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*531], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*530], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*529], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*528], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*527], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*526], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*525], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*524], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*523], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*522], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*521], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*520], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*519], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*518], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*517], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*516], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*515], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*514], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*513], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*512], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*511], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*510], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*509], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*508], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*507], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*506], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*505], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*504], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*503], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*502], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*501], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*500], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*499], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*498], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*497], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*496], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*495], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*494], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*493], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*492], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*491], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*490], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*489], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*488], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*487], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*486], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*485], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*484], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*483], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*482], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*481], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*480], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*479], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*478], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*477], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*476], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*475], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*474], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*473], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*472], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*471], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*470], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*469], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*468], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*467], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*466], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*465], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*464], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*463], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*462], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*461], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*460], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*459], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*458], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*457], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*456], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*455], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*454], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*453], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*452], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*451], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*450], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*449], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*448], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*447], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*446], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*445], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*444], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*443], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*442], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*441], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*440], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*439], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*438], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*437], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*436], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*435], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*434], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*433], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*432], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*431], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*430], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*429], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*428], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*427], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*426], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*425], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*424], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*423], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*422], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*421], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*420], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*419], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*418], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*417], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*416], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*415], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*414], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*413], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*412], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*411], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*410], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*409], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*408], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*407], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*406], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*405], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*404], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*403], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*402], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*401], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*400], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*399], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*398], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*397], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*396], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*395], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*394], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*393], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*392], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*391], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*390], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*389], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*388], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*387], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*386], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*385], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*384]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*2]),
    .result(result_7));
    
  FCLayer result8 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*383], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*382], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*381], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*380], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*379], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*378], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*377], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*376], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*375], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*374], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*373], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*372], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*371], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*370], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*369], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*368], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*367], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*366], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*365], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*364], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*363], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*362], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*361], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*360], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*359], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*358], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*357], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*356], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*355], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*354], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*353], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*352], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*351], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*350], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*349], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*348], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*347], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*346], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*345], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*344], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*343], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*342], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*341], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*340], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*339], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*338], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*337], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*336], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*335], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*334], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*333], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*332], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*331], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*330], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*329], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*328], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*327], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*326], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*325], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*324], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*323], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*322], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*321], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*320], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*319], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*318], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*317], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*316], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*315], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*314], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*313], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*312], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*311], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*310], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*309], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*308], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*307], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*306], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*305], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*304], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*303], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*302], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*301], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*300], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*299], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*298], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*297], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*296], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*295], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*294], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*293], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*292], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*291], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*290], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*289], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*288], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*287], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*286], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*285], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*284], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*283], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*282], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*281], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*280], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*279], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*278], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*277], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*276], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*275], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*274], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*273], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*272], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*271], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*270], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*269], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*268], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*267], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*266], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*265], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*264], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*263], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*262], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*261], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*260], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*259], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*258], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*257], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*256], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*255], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*254], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*253], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*252], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*251], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*250], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*249], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*248], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*247], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*246], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*245], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*244], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*243], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*242], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*241], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*240], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*239], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*238], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*237], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*236], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*235], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*234], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*233], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*232], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*231], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*230], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*229], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*228], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*227], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*226], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*225], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*224], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*223], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*222], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*221], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*220], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*219], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*218], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*217], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*216], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*215], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*214], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*213], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*212], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*211], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*210], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*209], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*208], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*207], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*206], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*205], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*204], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*203], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*202], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*201], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*200], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*199], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*198], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*197], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*196], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*195], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*194], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*193], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*192]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*1]),
    .result(result_8));
    
  FCLayer result9 (.data({avg_data_201, avg_data_202, avg_data_203, avg_data_204, avg_data_205, avg_data_206, avg_data_207, avg_data_208, avg_data_209, avg_data_210, avg_data_211, avg_data_212}),
    .weights({FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*191], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*190], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*189], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*188], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*187], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*186], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*185], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*184], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*183], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*182], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*181], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*180], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*179], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*178], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*177], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*176], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*175], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*174], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*173], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*172], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*171], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*170], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*169], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*168], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*167], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*166], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*165], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*164], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*163], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*162], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*161], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*160], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*159], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*158], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*157], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*156], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*155], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*154], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*153], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*152], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*151], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*150], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*149], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*148], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*147], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*146], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*145], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*144], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*143], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*142], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*141], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*140], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*139], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*138], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*137], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*136], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*135], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*134], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*133], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*132], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*131], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*130], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*129], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*128], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*127], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*126], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*125], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*124], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*123], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*122], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*121], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*120], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*119], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*118], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*117], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*116], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*115], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*114], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*113], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*112], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*111], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*110], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*109], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*108], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*107], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*106], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*105], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*104], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*103], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*102], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*101], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*100], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*99], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*98], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*97], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*96], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*95], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*94], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*93], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*92], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*91], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*90], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*89], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*88], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*87], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*86], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*85], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*84], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*83], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*82], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*81], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*80], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*79], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*78], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*77], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*76], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*75], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*74], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*73], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*72], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*71], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*70], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*69], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*68], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*67], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*66], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*65], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*64], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*63], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*62], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*61], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*60], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*59], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*58], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*57], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*56], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*55], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*54], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*53], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*52], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*51], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*50], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*49], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*48], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*47], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*46], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*45], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*44], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*43], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*42], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*41], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*40], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*39], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*38], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*37], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*36], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*35], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*34], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*33], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*32], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*31], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*30], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*29], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*28], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*27], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*26], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*25], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*24], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*23], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*22], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*21], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*20], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*19], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*18], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*17], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*16], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*15], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*14], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*13], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*12], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*11], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*10], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*9], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*8], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*7], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*6], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*5], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*4], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*3], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*2], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*1], FC1_WEIGHTS_M [FC1_WEIGHTS_ROW*FC1_WEIGHTS_COLUMN - 1 -1*0]}),
    .bias1(FC1_BIAS_M [FC1_BIAS_ROW - 1 - 1*0]),
    .result(result_9));
    
   //Compare the values of all 0-9 Digits
   Answer FC_result (.num0(result_0),
                    .num1(result_1),
                    .num2(result_2),
                    .num3(result_3),
                    .num4(result_4),
                    .num5(result_5),
                    .num6(result_6),
                    .num7(result_7),
                    .num8(result_8),
                    .num9(result_9),
                    .answer(result_i));
    
    
    always@ (posedge clk, negedge rst) begin
      if (!rst) result <= 15;
      else begin
        if (result_i == result_0) begin
          result <= 0;
        end
        else begin
          if (result_i == result_1) begin
            result <= 1;
          end
          else begin
            if (result_i == result_2) begin
              result <= 2;
            end
            else begin
              if (result_i == result_3) begin
                result <= 3;
              end
              else begin
                if (result_i == result_4) begin
                  result <= 4;
                end
                else begin
                  if (result_i == result_5) begin
                    result <= 5;
                  end
                  else begin
                    if (result_i == result_6) begin
                      result <= 6;
                    end
                    else begin
                      if (result_i == result_7) begin
                        result <= 7;
                      end
                      else begin
                        if (result_i == result_8) begin
                          result <= 8;
                        end
                        else begin
                          if (result_i == result_9) begin
                            result <= 9;
                          end
                          else begin
                            result <= 15;
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end  
endmodule