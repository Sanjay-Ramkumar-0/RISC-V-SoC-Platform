module convolution #(
    parameter DATA_WIDTH  = 8,
    parameter KERNEL_SIZE = 3,
    parameter IMAGE_WIDTH = 28,
    parameter IMAGE_HEIGHT= 28
)(
    input  wire                         clk,
    input  wire                         rst,

    // Control / status
    input  wire                         start,          // pulse: begin accepting a new image
    output reg                          done,           // 1-cycle pulse when last window produced
    output reg                          busy,           // high while processing an image
    input  wire                         valid_in,       // = pixel_in_valid
    output wire                         valid_out,      // high when results are valid

    // Data
    input  wire [DATA_WIDTH-1:0]        pixel_in,

    // 16 parallel convolution results (MAC only, no bias / ReLU)
    output wire signed [19:0]           result1,
    output wire signed [19:0]           result2,
    output wire signed [19:0]           result3,
    output wire signed [19:0]           result4,
    output wire signed [19:0]           result5,
    output wire signed [19:0]           result6,
    output wire signed [19:0]           result7,
    output wire signed [19:0]           result8,
    output wire signed [19:0]           result9,
    output wire signed [19:0]           result10,
    output wire signed [19:0]           result11,
    output wire signed [19:0]           result12,
    output wire signed [19:0]           result13,
    output wire signed [19:0]           result14,
    output wire signed [19:0]           result15,
    output wire signed [19:0]           result16,

    output wire                         result1_valid,
    output wire                         result2_valid,
    output wire                         result3_valid,
    output wire                         result4_valid,
    output wire                         result5_valid,
    output wire                         result6_valid,
    output wire                         result7_valid,
    output wire                         result8_valid,
    output wire                         result9_valid,
    output wire                         result10_valid,
    output wire                         result11_valid,
    output wire                         result12_valid,
    output wire                         result13_valid,
    output wire                         result14_valid,
    output wire                         result15_valid,
    output wire                         result16_valid
);

    //------------------------------------------------------------------
    // Line-buffer / sliding-window control
    //------------------------------------------------------------------
    wire [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] control_out;
    wire                                           control_out_valid;

    control_logic #(
        .DATA_WIDTH (DATA_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) line_buffer_DUT (
        .clk           (clk),
        .rst           (rst),
        .data_in       (pixel_in),
        .data_in_valid (valid_in),
        .data_out      (control_out),
        .data_out_valid(control_out_valid)
    );

    //------------------------------------------------------------------
    // Conv-layer weights (16 filters × 3×3)
    //------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] w1 [0:143];

    // Weights loaded only in simulation; empty for synthesis
    `ifndef SYNTHESIS
    initial begin
        $readmemh("W1_int8.txt", w1);
    end
    `endif

    //------------------------------------------------------------------
    // 16 parallel MAC units
    //------------------------------------------------------------------
    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac1 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[0], w1[1], w1[2], w1[3], w1[4], w1[5], w1[6], w1[7], w1[8]}),
        .data_in_valid(control_out_valid),
        .data_out(result1), .data_out_valid(result1_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac2 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[9], w1[10], w1[11], w1[12], w1[13], w1[14], w1[15], w1[16], w1[17]}),
        .data_in_valid(control_out_valid),
        .data_out(result2), .data_out_valid(result2_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac3 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[18], w1[19], w1[20], w1[21], w1[22], w1[23], w1[24], w1[25], w1[26]}),
        .data_in_valid(control_out_valid),
        .data_out(result3), .data_out_valid(result3_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac4 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[27], w1[28], w1[29], w1[30], w1[31], w1[32], w1[33], w1[34], w1[35]}),
        .data_in_valid(control_out_valid),
        .data_out(result4), .data_out_valid(result4_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac5 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[36], w1[37], w1[38], w1[39], w1[40], w1[41], w1[42], w1[43], w1[44]}),
        .data_in_valid(control_out_valid),
        .data_out(result5), .data_out_valid(result5_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac6 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[45], w1[46], w1[47], w1[48], w1[49], w1[50], w1[51], w1[52], w1[53]}),
        .data_in_valid(control_out_valid),
        .data_out(result6), .data_out_valid(result6_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac7 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[54], w1[55], w1[56], w1[57], w1[58], w1[59], w1[60], w1[61], w1[62]}),
        .data_in_valid(control_out_valid),
        .data_out(result7), .data_out_valid(result7_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac8 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[63], w1[64], w1[65], w1[66], w1[67], w1[68], w1[69], w1[70], w1[71]}),
        .data_in_valid(control_out_valid),
        .data_out(result8), .data_out_valid(result8_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac9 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[72], w1[73], w1[74], w1[75], w1[76], w1[77], w1[78], w1[79], w1[80]}),
        .data_in_valid(control_out_valid),
        .data_out(result9), .data_out_valid(result9_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac10 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[81], w1[82], w1[83], w1[84], w1[85], w1[86], w1[87], w1[88], w1[89]}),
        .data_in_valid(control_out_valid),
        .data_out(result10), .data_out_valid(result10_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac11 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[90], w1[91], w1[92], w1[93], w1[94], w1[95], w1[96], w1[97], w1[98]}),
        .data_in_valid(control_out_valid),
        .data_out(result11), .data_out_valid(result11_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac12 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[99], w1[100], w1[101], w1[102], w1[103], w1[104], w1[105], w1[106], w1[107]}),
        .data_in_valid(control_out_valid),
        .data_out(result12), .data_out_valid(result12_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac13 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[108], w1[109], w1[110], w1[111], w1[112], w1[113], w1[114], w1[115], w1[116]}),
        .data_in_valid(control_out_valid),
        .data_out(result13), .data_out_valid(result13_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac14 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[117], w1[118], w1[119], w1[120], w1[121], w1[122], w1[123], w1[124], w1[125]}),
        .data_in_valid(control_out_valid),
        .data_out(result14), .data_out_valid(result14_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac15 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[126], w1[127], w1[128], w1[129], w1[130], w1[131], w1[132], w1[133], w1[134]}),
        .data_in_valid(control_out_valid),
        .data_out(result15), .data_out_valid(result15_valid)
    );

    mac #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE))
    mac16 (
        .clk(clk), .rst(rst),
        .data_in(control_out),
        .weight({w1[135], w1[136], w1[137], w1[138], w1[139], w1[140], w1[141], w1[142], w1[143]}),
        .data_in_valid(control_out_valid),
        .data_out(result16), .data_out_valid(result16_valid)
    );

    //------------------------------------------------------------------
    // Status generation
    // valid_out is high whenever any (all) MAC produces a result
    //------------------------------------------------------------------
    assign valid_out = result16_valid;   // all 16 valids are simultaneous

    // Count number of valid output windows (26×26 = 676)
    reg [9:0] out_count;

    always @(posedge clk) begin
        if (!rst) begin
            out_count <= 10'd0;
            done      <= 1'b0;
            busy      <= 1'b0;
        end else begin
            // default: done is a single-cycle pulse
            done <= 1'b0;

            // start / first pixel → go busy
            if (start || (valid_in && !busy))
                busy <= 1'b1;

            // count valid outputs
            if (valid_out) begin
                if (out_count == 10'd675) begin
                    // this is the 676th (last) window
                    done      <= 1'b1;
                    busy      <= 1'b0;
                    out_count <= 10'd0;
                end else begin
                    out_count <= out_count + 1'b1;
                end
            end
        end
    end

endmodule
