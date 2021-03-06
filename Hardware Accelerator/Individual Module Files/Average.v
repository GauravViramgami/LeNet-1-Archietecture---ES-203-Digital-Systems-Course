////AVERAGE POLING
module Average_Pooling(data1, data2);
    parameter DATA1_ROW = 24,
        DATA1_COLUMN = 24,
        DATA2_ROW = 12,
        DATA2_COLUMN = 12,
        FP_LENGTH = 16;
    
    input [DATA1_ROW*DATA1_COLUMN*FP_LENGTH - 1:0] data1;
    output [DATA2_ROW*DATA2_COLUMN*FP_LENGTH - 1:0] data2;
    
    
endmodule
