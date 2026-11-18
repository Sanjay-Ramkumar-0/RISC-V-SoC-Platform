module conv #(
    parameter DATA_WIDTH   = 8,
    parameter KERNEL_SIZE  = 3,
    parameter IMAGE_WIDTH  = 28,
    parameter IMAGE_HEIGHT = 28
)(
    input  wire                         clk,
    input  wire                         rst,

    // Image input
    input  wire [DATA_WIDTH-1:0]        pixel_in,
    input  wire                         pixel_in_valid,

    // Optional external start for a new image
    input  wire                         start,

    // Final classification result
    output wire [3:0]                   prediction,
    output wire                         data_out_valid,

    //------------------------------------------------------------------
    // Per-stage status (for testbench timing measurement)
    //------------------------------------------------------------------
    output wire                         conv_start,
    output wire                         conv_done,
    output wire                         conv_busy,
    output wire                         conv_valid_in,
    output wire                         conv_valid_out,

    output wire                         relu_start,
    output wire                         relu_done,
    output wire                         relu_busy,
    output wire                         relu_valid_in,
    output wire                         relu_valid_out,

    output wire                         pool_start,
    output wire                         pool_done,
    output wire                         pool_busy,
    output wire                         pool_valid_in,
    output wire                         pool_valid_out,

    output wire                         fc_start,
    output wire                         fc_done,
    output wire                         fc_busy,
    output wire                         fc_valid_in,
    output wire                         fc_valid_out
);

    //------------------------------------------------------------------
    // Convolution stage
    //------------------------------------------------------------------
    wire signed [19:0] result1,  result2,  result3,  result4;
    wire signed [19:0] result5,  result6,  result7,  result8;
    wire signed [19:0] result9,  result10, result11, result12;
    wire signed [19:0] result13, result14, result15, result16;

    wire result1_valid,  result2_valid,  result3_valid,  result4_valid;
    wire result5_valid,  result6_valid,  result7_valid,  result8_valid;
    wire result9_valid,  result10_valid, result11_valid, result12_valid;
    wire result13_valid, result14_valid, result15_valid, result16_valid;

    wire conv_done_w, conv_busy_w, conv_valid_out_w;

    assign conv_start     = start;
    assign conv_valid_in  = pixel_in_valid;
    assign conv_done      = conv_done_w;
    assign conv_busy      = conv_busy_w;
    assign conv_valid_out = conv_valid_out_w;

    convolution #(
        .DATA_WIDTH  (DATA_WIDTH),
        .KERNEL_SIZE (KERNEL_SIZE),
        .IMAGE_WIDTH (IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    ) u_conv (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .done           (conv_done_w),
        .busy           (conv_busy_w),
        .valid_in       (pixel_in_valid),
        .valid_out      (conv_valid_out_w),
        .pixel_in       (pixel_in),

        .result1 (result1),  .result2 (result2),  .result3 (result3),  .result4 (result4),
        .result5 (result5),  .result6 (result6),  .result7 (result7),  .result8 (result8),
        .result9 (result9),  .result10(result10), .result11(result11), .result12(result12),
        .result13(result13), .result14(result14), .result15(result15), .result16(result16),

        .result1_valid (result1_valid),  .result2_valid (result2_valid),
        .result3_valid (result3_valid),  .result4_valid (result4_valid),
        .result5_valid (result5_valid),  .result6_valid (result6_valid),
        .result7_valid (result7_valid),  .result8_valid (result8_valid),
        .result9_valid (result9_valid),  .result10_valid(result10_valid),
        .result11_valid(result11_valid), .result12_valid(result12_valid),
        .result13_valid(result13_valid), .result14_valid(result14_valid),
        .result15_valid(result15_valid), .result16_valid(result16_valid)
    );

    //------------------------------------------------------------------
    // ReLU stage
    //------------------------------------------------------------------
    wire relu_done_w, relu_busy_w, relu_valid_out_w;

    // fmap read bus (MaxPool → ReLU)
    wire [9:0]          fmap_rd_addr;
    wire signed [19:0]  fmap_rd_data1,  fmap_rd_data2,  fmap_rd_data3,  fmap_rd_data4;
    wire signed [19:0]  fmap_rd_data5,  fmap_rd_data6,  fmap_rd_data7,  fmap_rd_data8;
    wire signed [19:0]  fmap_rd_data9,  fmap_rd_data10, fmap_rd_data11, fmap_rd_data12;
    wire signed [19:0]  fmap_rd_data13, fmap_rd_data14, fmap_rd_data15, fmap_rd_data16;

    assign relu_start     = conv_valid_out_w;
    assign relu_valid_in  = conv_valid_out_w;
    assign relu_done      = relu_done_w;
    assign relu_busy      = relu_busy_w;
    assign relu_valid_out = relu_valid_out_w;

    ReLU #(.DATA_WIDTH(DATA_WIDTH)) u_relu (
        .clk            (clk),
        .rst            (rst),
        .start          (conv_valid_out_w),
        .done           (relu_done_w),
        .busy           (relu_busy_w),
        .valid_in       (conv_valid_out_w),
        .valid_out      (relu_valid_out_w),

        .result1 (result1),  .result2 (result2),  .result3 (result3),  .result4 (result4),
        .result5 (result5),  .result6 (result6),  .result7 (result7),  .result8 (result8),
        .result9 (result9),  .result10(result10), .result11(result11), .result12(result12),
        .result13(result13), .result14(result14), .result15(result15), .result16(result16),

        .result1_valid (result1_valid),  .result2_valid (result2_valid),
        .result3_valid (result3_valid),  .result4_valid (result4_valid),
        .result5_valid (result5_valid),  .result6_valid (result6_valid),
        .result7_valid (result7_valid),  .result8_valid (result8_valid),
        .result9_valid (result9_valid),  .result10_valid(result10_valid),
        .result11_valid(result11_valid), .result12_valid(result12_valid),
        .result13_valid(result13_valid), .result14_valid(result14_valid),
        .result15_valid(result15_valid), .result16_valid(result16_valid),

        .rd_addr  (fmap_rd_addr),
        .rd_data1 (fmap_rd_data1),  .rd_data2 (fmap_rd_data2),
        .rd_data3 (fmap_rd_data3),  .rd_data4 (fmap_rd_data4),
        .rd_data5 (fmap_rd_data5),  .rd_data6 (fmap_rd_data6),
        .rd_data7 (fmap_rd_data7),  .rd_data8 (fmap_rd_data8),
        .rd_data9 (fmap_rd_data9),  .rd_data10(fmap_rd_data10),
        .rd_data11(fmap_rd_data11), .rd_data12(fmap_rd_data12),
        .rd_data13(fmap_rd_data13), .rd_data14(fmap_rd_data14),
        .rd_data15(fmap_rd_data15), .rd_data16(fmap_rd_data16)
    );

    //------------------------------------------------------------------
    // Max-pooling stage
    //------------------------------------------------------------------
    wire pool_done_w, pool_busy_w, pool_valid_out_w;

    // pool read bus (FC → MaxPool)
    wire [7:0]          pool_rd_addr;
    wire signed [19:0]  pool_rd_data1,  pool_rd_data2,  pool_rd_data3,  pool_rd_data4;
    wire signed [19:0]  pool_rd_data5,  pool_rd_data6,  pool_rd_data7,  pool_rd_data8;
    wire signed [19:0]  pool_rd_data9,  pool_rd_data10, pool_rd_data11, pool_rd_data12;
    wire signed [19:0]  pool_rd_data13, pool_rd_data14, pool_rd_data15, pool_rd_data16;

    assign pool_start     = relu_done_w;
    assign pool_valid_in  = relu_done_w;
    assign pool_done      = pool_done_w;
    assign pool_busy      = pool_busy_w;
    assign pool_valid_out = pool_valid_out_w;

    MaxPool u_pool (
        .clk       (clk),
        .rst       (rst),
        .start     (relu_done_w),
        .done      (pool_done_w),
        .busy      (pool_busy_w),
        .valid_in  (relu_done_w),
        .valid_out (pool_valid_out_w),

        .fmap_rd_addr  (fmap_rd_addr),
        .fmap_rd_data1 (fmap_rd_data1),  .fmap_rd_data2 (fmap_rd_data2),
        .fmap_rd_data3 (fmap_rd_data3),  .fmap_rd_data4 (fmap_rd_data4),
        .fmap_rd_data5 (fmap_rd_data5),  .fmap_rd_data6 (fmap_rd_data6),
        .fmap_rd_data7 (fmap_rd_data7),  .fmap_rd_data8 (fmap_rd_data8),
        .fmap_rd_data9 (fmap_rd_data9),  .fmap_rd_data10(fmap_rd_data10),
        .fmap_rd_data11(fmap_rd_data11), .fmap_rd_data12(fmap_rd_data12),
        .fmap_rd_data13(fmap_rd_data13), .fmap_rd_data14(fmap_rd_data14),
        .fmap_rd_data15(fmap_rd_data15), .fmap_rd_data16(fmap_rd_data16),

        .pool_rd_addr  (pool_rd_addr),
        .pool_rd_data1 (pool_rd_data1),  .pool_rd_data2 (pool_rd_data2),
        .pool_rd_data3 (pool_rd_data3),  .pool_rd_data4 (pool_rd_data4),
        .pool_rd_data5 (pool_rd_data5),  .pool_rd_data6 (pool_rd_data6),
        .pool_rd_data7 (pool_rd_data7),  .pool_rd_data8 (pool_rd_data8),
        .pool_rd_data9 (pool_rd_data9),  .pool_rd_data10(pool_rd_data10),
        .pool_rd_data11(pool_rd_data11), .pool_rd_data12(pool_rd_data12),
        .pool_rd_data13(pool_rd_data13), .pool_rd_data14(pool_rd_data14),
        .pool_rd_data15(pool_rd_data15), .pool_rd_data16(pool_rd_data16)
    );

    //------------------------------------------------------------------
    // Fully-connected + argmax
    //------------------------------------------------------------------
    wire fc_done_w, fc_busy_w, fc_valid_out_w;
    wire [3:0] prediction_w;

    assign fc_start     = pool_done_w;
    assign fc_valid_in  = pool_done_w;
    assign fc_done      = fc_done_w;
    assign fc_busy      = fc_busy_w;
    assign fc_valid_out = fc_valid_out_w;

    assign prediction     = prediction_w;
    assign data_out_valid = fc_valid_out_w;

    FC #(.DATA_WIDTH(DATA_WIDTH)) u_fc (
        .clk            (clk),
        .rst            (rst),
        .start          (pool_done_w),
        .done           (fc_done_w),
        .busy           (fc_busy_w),
        .valid_in       (pool_done_w),
        .valid_out      (fc_valid_out_w),

        .pool_rd_addr  (pool_rd_addr),
        .pool_rd_data1 (pool_rd_data1),  .pool_rd_data2 (pool_rd_data2),
        .pool_rd_data3 (pool_rd_data3),  .pool_rd_data4 (pool_rd_data4),
        .pool_rd_data5 (pool_rd_data5),  .pool_rd_data6 (pool_rd_data6),
        .pool_rd_data7 (pool_rd_data7),  .pool_rd_data8 (pool_rd_data8),
        .pool_rd_data9 (pool_rd_data9),  .pool_rd_data10(pool_rd_data10),
        .pool_rd_data11(pool_rd_data11), .pool_rd_data12(pool_rd_data12),
        .pool_rd_data13(pool_rd_data13), .pool_rd_data14(pool_rd_data14),
        .pool_rd_data15(pool_rd_data15), .pool_rd_data16(pool_rd_data16),

        .prediction     (prediction_w)
    );

endmodule
