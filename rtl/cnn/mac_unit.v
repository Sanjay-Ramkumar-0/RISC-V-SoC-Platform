// ============================================================
//  MAC unit – 3x3 multiply-accumulate
//  - Fully combinational product array (no latches)
//  - Active-high reset (matches CNN convention via ~rst_n)
// ============================================================
module mac #(
    parameter DATA_WIDTH  = 8,
    parameter KERNEL_SIZE = 3
)(
    input  wire                                   clk,
    input  wire                                   rst,          // active-high
    input  wire [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] data_in,
    input  wire signed [DATA_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] weight,
    input  wire                                   data_in_valid,

    output reg  signed [19:0]                     data_out,
    output reg                                    data_out_valid
);

    // Combinational products – always assigned (no latch)
    reg signed [19:0] temp [0:KERNEL_SIZE*KERNEL_SIZE-1];
    integer i;

    always @(*) begin
        for (i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
            if (data_in_valid)
                temp[i] = $signed({1'b0, data_in[i*DATA_WIDTH +: DATA_WIDTH]})
                        * $signed(weight[i*DATA_WIDTH +: DATA_WIDTH]);
            else
                temp[i] = 20'sd0;
        end
    end

    // Registered sum
    always @(posedge clk) begin
        if (rst) begin
            data_out       <= 20'sd0;
            data_out_valid <= 1'b0;
        end else if (data_in_valid) begin
            data_out <= temp[0] + temp[1] + temp[2]
                      + temp[3] + temp[4] + temp[5]
                      + temp[6] + temp[7] + temp[8];
            data_out_valid <= 1'b1;
        end else begin
            data_out_valid <= 1'b0;
        end
    end

endmodule
