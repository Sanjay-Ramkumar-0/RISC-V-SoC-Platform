module FC #(
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

    // Read interface into MaxPool results (pure Verilog – no array ports)
    output reg  [7:0]                   pool_rd_addr,
    input  wire signed [19:0]           pool_rd_data1,
    input  wire signed [19:0]           pool_rd_data2,
    input  wire signed [19:0]           pool_rd_data3,
    input  wire signed [19:0]           pool_rd_data4,
    input  wire signed [19:0]           pool_rd_data5,
    input  wire signed [19:0]           pool_rd_data6,
    input  wire signed [19:0]           pool_rd_data7,
    input  wire signed [19:0]           pool_rd_data8,
    input  wire signed [19:0]           pool_rd_data9,
    input  wire signed [19:0]           pool_rd_data10,
    input  wire signed [19:0]           pool_rd_data11,
    input  wire signed [19:0]           pool_rd_data12,
    input  wire signed [19:0]           pool_rd_data13,
    input  wire signed [19:0]           pool_rd_data14,
    input  wire signed [19:0]           pool_rd_data15,
    input  wire signed [19:0]           pool_rd_data16,

    output reg  [3:0]                   prediction
);

    //------------------------------------------------------------------
    // Fully-connected weights & biases
    //------------------------------------------------------------------
`ifdef SYNTHESIS
    // Physical-design build: no huge weight memories (zeros only)
    reg signed [DATA_WIDTH-1:0] w2_0 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_1 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_2 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_3 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_4 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_5 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_6 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_7 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_8 [0:0];
    reg signed [DATA_WIDTH-1:0] w2_9 [0:0];
    reg signed [DATA_WIDTH-1:0] B2   [0:9];
`else
    reg signed [DATA_WIDTH-1:0] w2_0 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_1 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_2 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_3 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_4 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_5 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_6 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_7 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_8 [0:2703];
    reg signed [DATA_WIDTH-1:0] w2_9 [0:2703];
    reg signed [DATA_WIDTH-1:0] B2   [0:9];
`endif

    // FC weights/biases loaded only in simulation; empty for synthesis
    `ifndef SYNTHESIS
    initial begin
        $readmemh("W2_int8_0.txt", w2_0);
        $readmemh("W2_int8_1.txt", w2_1);
        $readmemh("W2_int8_2.txt", w2_2);
        $readmemh("W2_int8_3.txt", w2_3);
        $readmemh("W2_int8_4.txt", w2_4);
        $readmemh("W2_int8_5.txt", w2_5);
        $readmemh("W2_int8_6.txt", w2_6);
        $readmemh("W2_int8_7.txt", w2_7);
        $readmemh("W2_int8_8.txt", w2_8);
        $readmemh("W2_int8_9.txt", w2_9);
        $readmemh("B2_int8.txt",   B2);
    end
    `endif

    //------------------------------------------------------------------
    // Sequential streamer via address/data ports
    //
    // Timing (async read):
    //   pool_rd_addr already holds the index to read.
    //   Sample pool_rd_dataX, then advance addr for next cycle.
    //------------------------------------------------------------------
    reg [4:0]  acc_state;
    reg [7:0]  acc_count;               // how many values already taken from current channel
    reg signed [19:0] pool_value;
    reg        pool_value_valid;
    reg        start_latched;

    always @(posedge clk) begin
        if (!rst) begin
            acc_state        <= 5'd0;
            pool_value_valid <= 1'b0;
            acc_count        <= 8'd0;
            pool_rd_addr     <= 8'd0;
            start_latched    <= 1'b0;
            busy             <= 1'b0;
        end else begin
            // start_latched and busy are driven ONLY in this always block
            // (done is a 1-cycle pulse from the bias/argmax block)
            if (done) begin
                start_latched <= 1'b0;
                busy          <= 1'b0;
            end else if (start) begin
                start_latched <= 1'b1;
                busy          <= 1'b1;
            end else if (start_latched) begin
                busy <= 1'b1;
            end

            if (start_latched) begin
                case (acc_state)
                    5'd0: begin
                        if (acc_count < 169) begin
                            // addr already points to acc_count
                            pool_value       <= pool_rd_data1;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1; // next index
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd1;
                        end
                    end
                    5'd1: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data2;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd2;
                        end
                    end
                    5'd2: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data3;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd3;
                        end
                    end
                    5'd3: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data4;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd4;
                        end
                    end
                    5'd4: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data5;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd5;
                        end
                    end
                    5'd5: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data6;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd6;
                        end
                    end
                    5'd6: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data7;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd7;
                        end
                    end
                    5'd7: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data8;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd8;
                        end
                    end
                    5'd8: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data9;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd9;
                        end
                    end
                    5'd9: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data10;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd10;
                        end
                    end
                    5'd10: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data11;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd11;
                        end
                    end
                    5'd11: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data12;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd12;
                        end
                    end
                    5'd12: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data13;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd13;
                        end
                    end
                    5'd13: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data14;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd14;
                        end
                    end
                    5'd14: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data15;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd15;
                        end
                    end
                    5'd15: begin
                        if (acc_count < 169) begin
                            pool_value       <= pool_rd_data16;
                            pool_value_valid <= 1'b1;
                            acc_count        <= acc_count + 1'b1;
                            pool_rd_addr     <= acc_count + 1'b1;
                        end else begin
                            pool_value_valid <= 1'b0;
                            acc_count        <= 8'd0;
                            pool_rd_addr     <= 8'd0;
                            acc_state        <= 5'd16;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    //------------------------------------------------------------------
    // 10 parallel accumulators
    //------------------------------------------------------------------
    reg signed [47:0] acc0, acc1, acc2, acc3, acc4;
    reg signed [47:0] acc5, acc6, acc7, acc8, acc9;
    integer k;

    always @(posedge clk) begin
        if (!rst) begin
            acc0 <= 48'sd0;
            acc1 <= 48'sd0;
            acc2 <= 48'sd0;
            acc3 <= 48'sd0;
            acc4 <= 48'sd0;
            acc5 <= 48'sd0;
            acc6 <= 48'sd0;
            acc7 <= 48'sd0;
            acc8 <= 48'sd0;
            acc9 <= 48'sd0;
            k    <= 0;
        end
        else if (pool_value_valid && k < 2704) begin
`ifdef SYNTHESIS
            acc0 <= acc0 + ($signed(pool_value) * $signed(w2_0[0]));
            acc1 <= acc1 + ($signed(pool_value) * $signed(w2_1[0]));
            acc2 <= acc2 + ($signed(pool_value) * $signed(w2_2[0]));
            acc3 <= acc3 + ($signed(pool_value) * $signed(w2_3[0]));
            acc4 <= acc4 + ($signed(pool_value) * $signed(w2_4[0]));
            acc5 <= acc5 + ($signed(pool_value) * $signed(w2_5[0]));
            acc6 <= acc6 + ($signed(pool_value) * $signed(w2_6[0]));
            acc7 <= acc7 + ($signed(pool_value) * $signed(w2_7[0]));
            acc8 <= acc8 + ($signed(pool_value) * $signed(w2_8[0]));
            acc9 <= acc9 + ($signed(pool_value) * $signed(w2_9[0]));
`else
            acc0 <= acc0 + ($signed(pool_value) * $signed(w2_0[k]));
            acc1 <= acc1 + ($signed(pool_value) * $signed(w2_1[k]));
            acc2 <= acc2 + ($signed(pool_value) * $signed(w2_2[k]));
            acc3 <= acc3 + ($signed(pool_value) * $signed(w2_3[k]));
            acc4 <= acc4 + ($signed(pool_value) * $signed(w2_4[k]));
            acc5 <= acc5 + ($signed(pool_value) * $signed(w2_5[k]));
            acc6 <= acc6 + ($signed(pool_value) * $signed(w2_6[k]));
            acc7 <= acc7 + ($signed(pool_value) * $signed(w2_7[k]));
            acc8 <= acc8 + ($signed(pool_value) * $signed(w2_8[k]));
            acc9 <= acc9 + ($signed(pool_value) * $signed(w2_9[k]));
`endif
            k    <= k + 1;
        end
    end

    //------------------------------------------------------------------
    // Add biases & produce final valid / done (1-cycle pulse)
    //------------------------------------------------------------------
    reg signed [47:0] dense_out0, dense_out1, dense_out2, dense_out3, dense_out4;
    reg signed [47:0] dense_out5, dense_out6, dense_out7, dense_out8, dense_out9;
    reg               dense_fired;   // ensures done/valid_out pulse only once

    always @(posedge clk) begin
        if (!rst) begin
            dense_out0     <= 48'sd0;
            dense_out1     <= 48'sd0;
            dense_out2     <= 48'sd0;
            dense_out3     <= 48'sd0;
            dense_out4     <= 48'sd0;
            dense_out5     <= 48'sd0;
            dense_out6     <= 48'sd0;
            dense_out7     <= 48'sd0;
            dense_out8     <= 48'sd0;
            dense_out9     <= 48'sd0;
            valid_out      <= 1'b0;
            done           <= 1'b0;
            dense_fired    <= 1'b0;
        end
        else if ((k == 2704) && !dense_fired) begin
            // one-shot: first cycle k reaches 2704
            dense_out0     <= acc0 + 48'($signed(B2[0]));
            dense_out1     <= acc1 + 48'($signed(B2[1]));
            dense_out2     <= acc2 + 48'($signed(B2[2]));
            dense_out3     <= acc3 + 48'($signed(B2[3]));
            dense_out4     <= acc4 + 48'($signed(B2[4]));
            dense_out5     <= acc5 + 48'($signed(B2[5]));
            dense_out6     <= acc6 + 48'($signed(B2[6]));
            dense_out7     <= acc7 + 48'($signed(B2[7]));
            dense_out8     <= acc8 + 48'($signed(B2[8]));
            dense_out9     <= acc9 + 48'($signed(B2[9]));
            valid_out      <= 1'b1;
            done           <= 1'b1;
            dense_fired    <= 1'b1;
            // do NOT drive start_latched / busy here — only in the FSM always block
        end
        else begin
            valid_out <= 1'b0;
            done      <= 1'b0;
        end
    end

    //------------------------------------------------------------------
    // Argmax
    //------------------------------------------------------------------
    reg signed [47:0] max_val;

    always @(*) begin
        prediction = 4'd0;
        max_val    = dense_out0;

        if (dense_out1 > max_val) begin max_val = dense_out1; prediction = 4'd1; end
        if (dense_out2 > max_val) begin max_val = dense_out2; prediction = 4'd2; end
        if (dense_out3 > max_val) begin max_val = dense_out3; prediction = 4'd3; end
        if (dense_out4 > max_val) begin max_val = dense_out4; prediction = 4'd4; end
        if (dense_out5 > max_val) begin max_val = dense_out5; prediction = 4'd5; end
        if (dense_out6 > max_val) begin max_val = dense_out6; prediction = 4'd6; end
        if (dense_out7 > max_val) begin max_val = dense_out7; prediction = 4'd7; end
        if (dense_out8 > max_val) begin max_val = dense_out8; prediction = 4'd8; end
        if (dense_out9 > max_val) begin max_val = dense_out9; prediction = 4'd9; end
    end

endmodule
