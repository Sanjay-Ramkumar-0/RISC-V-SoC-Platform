module ReLU #(
    parameter DATA_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         rst,

    // Control / status
    input  wire                         start,
    output reg                          done,
    output reg                          busy,
    input  wire                         valid_in,
    output reg                          valid_out,

    // MAC results from convolution stage
    input  wire signed [19:0]           result1,
    input  wire signed [19:0]           result2,
    input  wire signed [19:0]           result3,
    input  wire signed [19:0]           result4,
    input  wire signed [19:0]           result5,
    input  wire signed [19:0]           result6,
    input  wire signed [19:0]           result7,
    input  wire signed [19:0]           result8,
    input  wire signed [19:0]           result9,
    input  wire signed [19:0]           result10,
    input  wire signed [19:0]           result11,
    input  wire signed [19:0]           result12,
    input  wire signed [19:0]           result13,
    input  wire signed [19:0]           result14,
    input  wire signed [19:0]           result15,
    input  wire signed [19:0]           result16,

    input  wire                         result1_valid,
    input  wire                         result2_valid,
    input  wire                         result3_valid,
    input  wire                         result4_valid,
    input  wire                         result5_valid,
    input  wire                         result6_valid,
    input  wire                         result7_valid,
    input  wire                         result8_valid,
    input  wire                         result9_valid,
    input  wire                         result10_valid,
    input  wire                         result11_valid,
    input  wire                         result12_valid,
    input  wire                         result13_valid,
    input  wire                         result14_valid,
    input  wire                         result15_valid,
    input  wire                         result16_valid,

    // Read port for MaxPool (pure Verilog – no array ports)
    input  wire [9:0]                   rd_addr,
    output wire signed [19:0]           rd_data1,
    output wire signed [19:0]           rd_data2,
    output wire signed [19:0]           rd_data3,
    output wire signed [19:0]           rd_data4,
    output wire signed [19:0]           rd_data5,
    output wire signed [19:0]           rd_data6,
    output wire signed [19:0]           rd_data7,
    output wire signed [19:0]           rd_data8,
    output wire signed [19:0]           rd_data9,
    output wire signed [19:0]           rd_data10,
    output wire signed [19:0]           rd_data11,
    output wire signed [19:0]           rd_data12,
    output wire signed [19:0]           rd_data13,
    output wire signed [19:0]           rd_data14,
    output wire signed [19:0]           rd_data15,
    output wire signed [19:0]           rd_data16
);

    //------------------------------------------------------------------
    // Feature maps (internal – pure Verilog)
    //------------------------------------------------------------------
`ifdef SYNTHESIS
    // Stub depth for physical build (full depth only in simulation)
    (* ram_style = "block" *) reg signed [19:0] fmap1  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap2  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap3  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap4  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap5  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap6  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap7  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap8  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap9  [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap10 [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap11 [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap12 [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap13 [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap14 [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap15 [0:15];
    (* ram_style = "block" *) reg signed [19:0] fmap16 [0:15];
`else
    (* ram_style = "block" *) reg signed [19:0] fmap1  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap2  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap3  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap4  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap5  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap6  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap7  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap8  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap9  [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap10 [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap11 [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap12 [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap13 [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap14 [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap15 [0:675];
    (* ram_style = "block" *) reg signed [19:0] fmap16 [0:675];
`endif

    // Combinational read (async) – pure Verilog, no array ports
    assign rd_data1  = fmap1[rd_addr];
    assign rd_data2  = fmap2[rd_addr];
    assign rd_data3  = fmap3[rd_addr];
    assign rd_data4  = fmap4[rd_addr];
    assign rd_data5  = fmap5[rd_addr];
    assign rd_data6  = fmap6[rd_addr];
    assign rd_data7  = fmap7[rd_addr];
    assign rd_data8  = fmap8[rd_addr];
    assign rd_data9  = fmap9[rd_addr];
    assign rd_data10 = fmap10[rd_addr];
    assign rd_data11 = fmap11[rd_addr];
    assign rd_data12 = fmap12[rd_addr];
    assign rd_data13 = fmap13[rd_addr];
    assign rd_data14 = fmap14[rd_addr];
    assign rd_data15 = fmap15[rd_addr];
    assign rd_data16 = fmap16[rd_addr];

    //------------------------------------------------------------------
    // Biases
    //------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] B1 [0:15];

    // Biases loaded only in simulation; empty for synthesis
    `ifndef SYNTHESIS
    initial begin
        $readmemh("B1_int8.txt", B1);
    end
    `endif

    //------------------------------------------------------------------
    // Write pointers
    //------------------------------------------------------------------
    reg [9:0] count1,  count2,  count3,  count4;
    reg [9:0] count5,  count6,  count7,  count8;
    reg [9:0] count9,  count10, count11, count12;
    reg [9:0] count13, count14, count15, count16;

    //------------------------------------------------------------------
    // Bias-add + ReLU store (runs concurrently with convolution)
    //------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            count1  <= 10'd0;
            count2  <= 10'd0;
            count3  <= 10'd0;
            count4  <= 10'd0;
            count5  <= 10'd0;
            count6  <= 10'd0;
            count7  <= 10'd0;
            count8  <= 10'd0;
            count9  <= 10'd0;
            count10 <= 10'd0;
            count11 <= 10'd0;
            count12 <= 10'd0;
            count13 <= 10'd0;
            count14 <= 10'd0;
            count15 <= 10'd0;
            count16 <= 10'd0;
            done      <= 1'b0;
            busy      <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            done      <= 1'b0;
            valid_out <= 1'b0;

            if (start || (valid_in && !busy))
                busy <= 1'b1;

            if (result1_valid) begin
                fmap1[count1] <= ((result1 + 20'($signed(B1[0]))) > 0) ?
                                  (result1 + 20'($signed(B1[0]))) : 20'sb0;
                count1 <= count1 + 1'b1;
                valid_out <= 1'b1;
            end
            if (result2_valid) begin
                fmap2[count2] <= ((result2 + 20'($signed(B1[1]))) > 0) ?
                                  (result2 + 20'($signed(B1[1]))) : 20'sb0;
                count2 <= count2 + 1'b1;
            end
            if (result3_valid) begin
                fmap3[count3] <= ((result3 + 20'($signed(B1[2]))) > 0) ?
                                  (result3 + 20'($signed(B1[2]))) : 20'sb0;
                count3 <= count3 + 1'b1;
            end
            if (result4_valid) begin
                fmap4[count4] <= ((result4 + 20'($signed(B1[3]))) > 0) ?
                                  (result4 + 20'($signed(B1[3]))) : 20'sb0;
                count4 <= count4 + 1'b1;
            end
            if (result5_valid) begin
                fmap5[count5] <= ((result5 + 20'($signed(B1[4]))) > 0) ?
                                  (result5 + 20'($signed(B1[4]))) : 20'sb0;
                count5 <= count5 + 1'b1;
            end
            if (result6_valid) begin
                fmap6[count6] <= ((result6 + 20'($signed(B1[5]))) > 0) ?
                                  (result6 + 20'($signed(B1[5]))) : 20'sb0;
                count6 <= count6 + 1'b1;
            end
            if (result7_valid) begin
                fmap7[count7] <= ((result7 + 20'($signed(B1[6]))) > 0) ?
                                  (result7 + 20'($signed(B1[6]))) : 20'sb0;
                count7 <= count7 + 1'b1;
            end
            if (result8_valid) begin
                fmap8[count8] <= ((result8 + 20'($signed(B1[7]))) > 0) ?
                                  (result8 + 20'($signed(B1[7]))) : 20'sb0;
                count8 <= count8 + 1'b1;
            end
            if (result9_valid) begin
                fmap9[count9] <= ((result9 + 20'($signed(B1[8]))) > 0) ?
                                  (result9 + 20'($signed(B1[8]))) : 20'sb0;
                count9 <= count9 + 1'b1;
            end
            if (result10_valid) begin
                fmap10[count10] <= ((result10 + 20'($signed(B1[9]))) > 0) ?
                                    (result10 + 20'($signed(B1[9]))) : 20'sb0;
                count10 <= count10 + 1'b1;
            end
            if (result11_valid) begin
                fmap11[count11] <= ((result11 + 20'($signed(B1[10]))) > 0) ?
                                    (result11 + 20'($signed(B1[10]))) : 20'sb0;
                count11 <= count11 + 1'b1;
            end
            if (result12_valid) begin
                fmap12[count12] <= ((result12 + 20'($signed(B1[11]))) > 0) ?
                                    (result12 + 20'($signed(B1[11]))) : 20'sb0;
                count12 <= count12 + 1'b1;
            end
            if (result13_valid) begin
                fmap13[count13] <= ((result13 + 20'($signed(B1[12]))) > 0) ?
                                    (result13 + 20'($signed(B1[12]))) : 20'sb0;
                count13 <= count13 + 1'b1;
            end
            if (result14_valid) begin
                fmap14[count14] <= ((result14 + 20'($signed(B1[13]))) > 0) ?
                                    (result14 + 20'($signed(B1[13]))) : 20'sb0;
                count14 <= count14 + 1'b1;
            end
            if (result15_valid) begin
                fmap15[count15] <= ((result15 + 20'($signed(B1[14]))) > 0) ?
                                    (result15 + 20'($signed(B1[14]))) : 20'sb0;
                count15 <= count15 + 1'b1;
            end
            if (result16_valid) begin
                fmap16[count16] <= ((result16 + 20'($signed(B1[15]))) > 0) ?
                                    (result16 + 20'($signed(B1[15]))) : 20'sb0;
                count16 <= count16 + 1'b1;
            end

            // Finish on the write that makes count16 == 676
            if (count16 == 10'd675 && result16_valid) begin
                done <= 1'b1;
                busy <= 1'b0;
            end
        end
    end

endmodule
