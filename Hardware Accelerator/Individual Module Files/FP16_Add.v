////Half Precision Floating Point Adder
module FP16_Add(
  input [15:0] A,
  input [15:0] B,
  output reg [15:0] Out
	);
  reg [4:0] exp_a, exp_b;
  reg [10:0] MA, MB, temp_M;
  integer k, i=0, j=11, n=9;
  reg [11:0] temp_sum;
  reg [4:0] temp_exp;
  
  always@(*)
    begin
      exp_a = A[14:10] - 5'b01111; 
      exp_b = B[14:10] - 5'b01111; 
      
      //mantissa
      MA =11'b10000000000 + A[9:0]; 
      MB =11'b10000000000 + B[9:0]; 
      
      //assign sign
      if (A[15] != B[15]) begin
        if (exp_a == exp_b) begin
          if (MA > MB) begin
            temp_sum = MA - MB; 
            Out[15] = A[15];
          end
          else if (MA == MB) begin
            temp_sum = 0; 
            Out[15] = 0;
          end
      	  else begin
            temp_sum = MB - MA; 
            Out[15] = B[15];
          end 
          temp_exp = exp_a + 5'b01111;
        end
          
      	else if (exp_a > exp_b) begin
      	  k = exp_a - exp_b; 
      	  exp_b = exp_a;
      	  //shifting smaller no. to match exp of bigger no.
          temp_M = MB;
      	  case(k)
            0: MB= MB;
            1: MB[10:0] = {1'b0 ,MB[10:1]};
            2: MB[10:0] = {2'b00 ,MB[10:2]};
            3: MB[10:0] = {3'b000 ,MB[10:3]};
            4: MB[10:0] = {4'b0000 ,MB[10:4]};
            5: MB[10:0] = {5'b00000 ,MB[10:5]};
            6: MB[10:0] = {6'b000000 ,MB[10:6]};
            7: MB[10:0] = {7'b0000000 ,MB[10:7]};
            8: MB[10:0] = {8'b00000000 ,MB[10:8]};
            9: MB[10:0] = {9'b000000000 ,MB[10:9]};
            default: MB = 0;
          endcase
          if (k >= 3 && temp_M[k-1] == 1 && (temp_M[k-2] == 1 || temp_M[k-3] == 1)) MB = MB + 1;
      	  //output
          Out[15] = A[15]; //sign_assignment
          temp_sum = MA - MB;
          temp_exp = exp_a + 5'b01111; //exp_assignment
        end
              
        else if (exp_a < exp_b) begin
          k = exp_b - exp_a; 
      	  exp_a = exp_b;
      	  //shifting smaller no. to match exp of bigger no.
          temp_M = MA;
      	  case(k)
        0: MA = MA;
        1: MA[10:0] = {1'b0 ,MA[10:1]};
        2: MA[10:0] = {2'b00 ,MA[10:2]};
        3: MA[10:0] = {3'b000 ,MA[10:3]};
        4: MA[10:0] = {4'b0000 ,MA[10:4]};
        5: MA[10:0] = {5'b00000 ,MA[10:5]};
        6: MA[10:0] = {6'b000000 ,MA[10:6]};
        7: MA[10:0] = {7'b0000000 ,MA[10:7]};
        8: MA[10:0] = {8'b00000000 ,MA[10:8]};
        9: MA[10:0] = {9'b000000000 ,MA[10:9]};
        default: MA = 0;
      endcase
          if (k >= 3 && temp_M[k-1] == 1 && (temp_M[k-2] == 1 || temp_M[k-3] == 1)) MA = MA + 1;
      	  //output
          temp_exp = exp_b + 5'b01111;//exp_assignment
          Out[15] = B[15];//sign_assignment
          temp_sum = MB - MA;
        end
      end
      
      else begin //when (A[15]==B[15])
        Out[15] = A[15];
        if (exp_a == exp_b) begin
          temp_exp = exp_a + 5'b01111;
          temp_sum = MA + MB;
        end
          
      	else if (exp_a > exp_b) begin
      	  k = exp_a - exp_b; 
      	  exp_b = exp_a;
      	  //shifting smaller no. to match exp of bigger no.
      	  //will round off later
          temp_M = MB;
      	  case(k)
            0: MB= MB;
            1: MB[10:0] = {1'b0 ,MB[10:1]};
            2: MB[10:0] = {2'b00 ,MB[10:2]};
            3: MB[10:0] = {3'b000 ,MB[10:3]};
            4: MB[10:0] = {4'b0000 ,MB[10:4]};
            5: MB[10:0] = {5'b00000 ,MB[10:5]};
            6: MB[10:0] = {6'b000000 ,MB[10:6]};
            7: MB[10:0] = {7'b0000000 ,MB[10:7]};
            8: MB[10:0] = {8'b00000000 ,MB[10:8]};
            9: MB[10:0] = {9'b000000000 ,MB[10:9]};
            default: MB = 0;
          endcase
          if (k >= 3 && temp_M[k-1] == 1 && (temp_M[k-2] == 1 || temp_M[k-3] == 1)) MB = MB + 1;
      	  //output
          temp_exp = exp_a + 5'b01111; //exp_assignment
          temp_sum = MA + MB;
          end
                  
        else if (exp_a < exp_b) begin
          k = exp_b - exp_a; 
      	  exp_a = exp_b;
      	  //shifting smaller no. to match exp of bigger no.
          temp_M = MA;
      	  case(k)
        0: MA = MA;
        1: MA[10:0] = {1'b0 ,MA[10:1]};
        2: MA[10:0] = {2'b00 ,MA[10:2]};
        3: MA[10:0] = {3'b000 ,MA[10:3]};
        4: MA[10:0] = {4'b0000 ,MA[10:4]};
        5: MA[10:0] = {5'b00000 ,MA[10:5]};
        6: MA[10:0] = {6'b000000 ,MA[10:6]};
        7: MA[10:0] = {7'b0000000 ,MA[10:7]};
        8: MA[10:0] = {8'b00000000 ,MA[10:8]};
        9: MA[10:0] = {9'b000000000 ,MA[10:9]};
        default: MA = 0;
      endcase
          if (k >= 3 && temp_M[k-1] == 1 && (temp_M[k-2] == 1 || temp_M[k-3] == 1)) MA = MA + 1;
      	  //output
          temp_exp = exp_b + 5'b01111;//exp_assignment
          temp_sum = MA + MB;
        end
      end
    
      //normalize mantissa sum and update exponent
      
      case(k)
        0: MA = MA;
        1: MA[10:0] = {1'b0 ,MA[10:1]};
        2: MA[10:0] = {2'b00 ,MA[10:2]};
        3: MA[10:0] = {3'b000 ,MA[10:3]};
        4: MA[10:0] = {4'b0000 ,MA[10:4]};
        5: MA[10:0] = {5'b00000 ,MA[10:5]};
        6: MA[10:0] = {6'b000000 ,MA[10:6]};
        7: MA[10:0] = {7'b0000000 ,MA[10:7]};
        8: MA[10:0] = {8'b00000000 ,MA[10:8]};
        9: MA[10:0] = {9'b000000000 ,MA[10:9]};
        default: MA = 0;
      endcase
      
      
    if(temp_sum[0]==1'b1) j=0;
    if(temp_sum[1]==1'b1) j=1;
    if(temp_sum[2]==1'b1) j=2;
    if(temp_sum[3]==1'b1) j=3;
    if(temp_sum[4]==1'b1) j=4;
    if(temp_sum[5]==1'b1) j=5;
    if(temp_sum[6]==1'b1) j=6;
    if(temp_sum[7]==1'b1) j=7;
    if(temp_sum[8]==1'b1) j=8;
    if(temp_sum[9]==1'b1) j=9;
    if(temp_sum[10]==1'b1) j=10;
    if(temp_sum[11]==1'b1) j=11;
      
//      while (j >= 0 && temp_sum[j] == 0) begin
//        j = j - 1;
//      end //Finding first 1 from MSB
    
      //final exponent
      if (j > 9) temp_exp = temp_exp + (j - 10); //Shifting exponent according to decimal place in mentissa
      else temp_exp = temp_exp - (10 - j);
      Out[14:10] = temp_exp;
      //shifting 1 to before decimal
      
    if(j>0)begin
    Out[9]=temp_sum[j-1];
    j = j-1;
    n=8;
    end
    if(j>0)begin
    Out[8]=temp_sum[j-1];
    j = j-1;
    n=7;
    end
    if(j>0)begin
    Out[7]=temp_sum[j-1];
    j = j-1;
    n=6;
    end
    if(j>0)begin
    Out[6]=temp_sum[j-1];
    j = j-1;
    n=5;
    end
    if(j>0)begin
    Out[5]=temp_sum[j-1];
    j = j-1;
    n=4;
    end
    if(j>0)begin
    Out[4]=temp_sum[j-1];
    j = j-1;
    n=3;
    end
    if(j>0)begin
    Out[3]=temp_sum[j-1];
    j = j-1;
    n=2;
    end
    if(j>0)begin
    Out[2]=temp_sum[j-1];
    j = j-1;
    n=1;
    end
    if(j>0)begin
    Out[1]=temp_sum[j-1];
    j = j-1;    
    n=0;
    end
    if(j>0)begin
    Out[0]=temp_sum[j-1];
    j = j-1;
    n=-1;
    end
      //SNEAK100XD
//      while (n >= 0 && j >= 1) begin
//        Out[n] = temp_sum[j-1];
//        j = j-1;
//        n = n-1;
//      end

//    for(i=n;i>=0;i=i-1) Out[i]=1'b0;
       
       case(n)
            9: Out[9:0] = 0;
            8: Out[8:0] = 0;
            7: Out[7:0] = 0;
            6: Out[6:0] = 0;
            5: Out[5:0] = 0;
            4: Out[4:0] = 0;
            3: Out[3:0] = 0;
            2: Out[2:0] = 0;
            1: Out[1:0] = 0;
            default: Out = Out;
       endcase
       
//      while (n >= 0) begin
//        Out[n] = 1'b0;
//        n = n-1;
//      end
    end
endmodule 
