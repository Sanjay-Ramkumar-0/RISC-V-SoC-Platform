module MaxPool (
    input  wire                         clk,
    input  wire                         rst,

    // Control / status
    input  wire                         start,
    output reg                          done,
    output reg                          busy,
    input  wire                         valid_in,
    output reg                          valid_out,

    // Read interface into ReLU feature maps (pure Verilog)
    output reg  [9:0]                   fmap_rd_addr,
    input  wire signed [19:0]           fmap_rd_data1,
    input  wire signed [19:0]           fmap_rd_data2,
    input  wire signed [19:0]           fmap_rd_data3,
    input  wire signed [19:0]           fmap_rd_data4,
    input  wire signed [19:0]           fmap_rd_data5,
    input  wire signed [19:0]           fmap_rd_data6,
    input  wire signed [19:0]           fmap_rd_data7,
    input  wire signed [19:0]           fmap_rd_data8,
    input  wire signed [19:0]           fmap_rd_data9,
    input  wire signed [19:0]           fmap_rd_data10,
    input  wire signed [19:0]           fmap_rd_data11,
    input  wire signed [19:0]           fmap_rd_data12,
    input  wire signed [19:0]           fmap_rd_data13,
    input  wire signed [19:0]           fmap_rd_data14,
    input  wire signed [19:0]           fmap_rd_data15,
    input  wire signed [19:0]           fmap_rd_data16,

    // Read interface for FC (pure Verilog)
    input  wire [7:0]                   pool_rd_addr,
    output wire signed [19:0]           pool_rd_data1,
    output wire signed [19:0]           pool_rd_data2,
    output wire signed [19:0]           pool_rd_data3,
    output wire signed [19:0]           pool_rd_data4,
    output wire signed [19:0]           pool_rd_data5,
    output wire signed [19:0]           pool_rd_data6,
    output wire signed [19:0]           pool_rd_data7,
    output wire signed [19:0]           pool_rd_data8,
    output wire signed [19:0]           pool_rd_data9,
    output wire signed [19:0]           pool_rd_data10,
    output wire signed [19:0]           pool_rd_data11,
    output wire signed [19:0]           pool_rd_data12,
    output wire signed [19:0]           pool_rd_data13,
    output wire signed [19:0]           pool_rd_data14,
    output wire signed [19:0]           pool_rd_data15,
    output wire signed [19:0]           pool_rd_data16
);

    //------------------------------------------------------------------
    // Pooled maps (internal)
    //------------------------------------------------------------------
    (* ram_style = "block" *) reg signed [19:0] pool_result1  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result2  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result3  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result4  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result5  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result6  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result7  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result8  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result9  [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result10 [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result11 [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result12 [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result13 [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result14 [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result15 [0:168];
    (* ram_style = "block" *) reg signed [19:0] pool_result16 [0:168];

    assign pool_rd_data1  = pool_result1[pool_rd_addr];
    assign pool_rd_data2  = pool_result2[pool_rd_addr];
    assign pool_rd_data3  = pool_result3[pool_rd_addr];
    assign pool_rd_data4  = pool_result4[pool_rd_addr];
    assign pool_rd_data5  = pool_result5[pool_rd_addr];
    assign pool_rd_data6  = pool_result6[pool_rd_addr];
    assign pool_rd_data7  = pool_result7[pool_rd_addr];
    assign pool_rd_data8  = pool_result8[pool_rd_addr];
    assign pool_rd_data9  = pool_result9[pool_rd_addr];
    assign pool_rd_data10 = pool_result10[pool_rd_addr];
    assign pool_rd_data11 = pool_result11[pool_rd_addr];
    assign pool_rd_data12 = pool_result12[pool_rd_addr];
    assign pool_rd_data13 = pool_result13[pool_rd_addr];
    assign pool_rd_data14 = pool_result14[pool_rd_addr];
    assign pool_rd_data15 = pool_result15[pool_rd_addr];
    assign pool_rd_data16 = pool_result16[pool_rd_addr];

    //------------------------------------------------------------------
    // 2×2 max helper
    //------------------------------------------------------------------
    function signed [19:0] max4;
        input signed [19:0] a0, a1, a2, a3;
        begin
            if      (a0 >= a1 && a0 >= a2 && a0 >= a3) max4 = a0;
            else if (a1 >= a0 && a1 >= a2 && a1 >= a3) max4 = a1;
            else if (a2 >= a0 && a2 >= a1 && a2 >= a3) max4 = a2;
            else                                        max4 = a3;
        end
    endfunction

    //------------------------------------------------------------------
    // Pooling FSM
    //------------------------------------------------------------------
    reg [2:0]  pool_phase;
    reg [9:0]  idx_hold;
    reg [4:0]  pool_row;
    reg [4:0]  pool_col;
    reg [7:0]  pool_count;

    reg signed [19:0] top1,    top2,    top3,    top4,    top5,    top6,    top7,    top8;
    reg signed [19:0] top9,    top10,   top11,   top12,   top13,   top14,   top15,   top16;
    reg signed [19:0] top1_p1, top2_p1, top3_p1, top4_p1, top5_p1, top6_p1, top7_p1, top8_p1;
    reg signed [19:0] top9_p1, top10_p1,top11_p1,top12_p1,top13_p1,top14_p1,top15_p1,top16_p1;
    reg signed [19:0] bot1,    bot2,    bot3,    bot4,    bot5,    bot6,    bot7,    bot8;
    reg signed [19:0] bot9,    bot10,   bot11,   bot12,   bot13,   bot14,   bot15,   bot16;
    reg signed [19:0] bot1_p1, bot2_p1, bot3_p1, bot4_p1, bot5_p1, bot6_p1, bot7_p1, bot8_p1;
    reg signed [19:0] bot9_p1, bot10_p1,bot11_p1,bot12_p1,bot13_p1,bot14_p1,bot15_p1,bot16_p1;

    reg start_latched;

    wire [9:0] idx = pool_row * 10'd26 + {5'b0, pool_col};

    always @(posedge clk) begin
        if (!rst) begin
            pool_phase    <= 3'd0;
            pool_count    <= 8'd0;
            pool_row      <= 5'd0;
            pool_col      <= 5'd0;
            idx_hold      <= 10'd0;
            fmap_rd_addr  <= 10'd0;
            done          <= 1'b0;
            busy          <= 1'b0;
            valid_out     <= 1'b0;
            start_latched <= 1'b0;
        end else begin
            done      <= 1'b0;
            valid_out <= 1'b0;

            if (start)
                start_latched <= 1'b1;

            if (start || start_latched)
                busy <= 1'b1;

            if (start_latched && pool_count < 169) begin
                case (pool_phase)
                    3'd0: begin
                        fmap_rd_addr <= idx;
                        idx_hold     <= idx;
                        pool_phase   <= 3'd1;
                    end

                    3'd1: begin
                        // Capture top-left (data available from previous addr)
                        top1  <= fmap_rd_data1;
                        top2  <= fmap_rd_data2;
                        top3  <= fmap_rd_data3;
                        top4  <= fmap_rd_data4;
                        top5  <= fmap_rd_data5;
                        top6  <= fmap_rd_data6;
                        top7  <= fmap_rd_data7;
                        top8  <= fmap_rd_data8;
                        top9  <= fmap_rd_data9;
                        top10 <= fmap_rd_data10;
                        top11 <= fmap_rd_data11;
                        top12 <= fmap_rd_data12;
                        top13 <= fmap_rd_data13;
                        top14 <= fmap_rd_data14;
                        top15 <= fmap_rd_data15;
                        top16 <= fmap_rd_data16;
                        fmap_rd_addr <= idx_hold + 10'd1;
                        pool_phase   <= 3'd2;
                    end

                    3'd2: begin
                        top1_p1  <= fmap_rd_data1;
                        top2_p1  <= fmap_rd_data2;
                        top3_p1  <= fmap_rd_data3;
                        top4_p1  <= fmap_rd_data4;
                        top5_p1  <= fmap_rd_data5;
                        top6_p1  <= fmap_rd_data6;
                        top7_p1  <= fmap_rd_data7;
                        top8_p1  <= fmap_rd_data8;
                        top9_p1  <= fmap_rd_data9;
                        top10_p1 <= fmap_rd_data10;
                        top11_p1 <= fmap_rd_data11;
                        top12_p1 <= fmap_rd_data12;
                        top13_p1 <= fmap_rd_data13;
                        top14_p1 <= fmap_rd_data14;
                        top15_p1 <= fmap_rd_data15;
                        top16_p1 <= fmap_rd_data16;
                        fmap_rd_addr <= idx_hold + 10'd26;
                        pool_phase   <= 3'd3;
                    end

                    3'd3: begin
                        bot1  <= fmap_rd_data1;
                        bot2  <= fmap_rd_data2;
                        bot3  <= fmap_rd_data3;
                        bot4  <= fmap_rd_data4;
                        bot5  <= fmap_rd_data5;
                        bot6  <= fmap_rd_data6;
                        bot7  <= fmap_rd_data7;
                        bot8  <= fmap_rd_data8;
                        bot9  <= fmap_rd_data9;
                        bot10 <= fmap_rd_data10;
                        bot11 <= fmap_rd_data11;
                        bot12 <= fmap_rd_data12;
                        bot13 <= fmap_rd_data13;
                        bot14 <= fmap_rd_data14;
                        bot15 <= fmap_rd_data15;
                        bot16 <= fmap_rd_data16;
                        fmap_rd_addr <= idx_hold + 10'd27;
                        pool_phase   <= 3'd4;
                    end

                    3'd4: begin
                        bot1_p1  <= fmap_rd_data1;
                        bot2_p1  <= fmap_rd_data2;
                        bot3_p1  <= fmap_rd_data3;
                        bot4_p1  <= fmap_rd_data4;
                        bot5_p1  <= fmap_rd_data5;
                        bot6_p1  <= fmap_rd_data6;
                        bot7_p1  <= fmap_rd_data7;
                        bot8_p1  <= fmap_rd_data8;
                        bot9_p1  <= fmap_rd_data9;
                        bot10_p1 <= fmap_rd_data10;
                        bot11_p1 <= fmap_rd_data11;
                        bot12_p1 <= fmap_rd_data12;
                        bot13_p1 <= fmap_rd_data13;
                        bot14_p1 <= fmap_rd_data14;
                        bot15_p1 <= fmap_rd_data15;
                        bot16_p1 <= fmap_rd_data16;
                        pool_phase <= 3'd5;
                    end

                    3'd5: begin
                        pool_result1[pool_count]  <= max4(top1,  top1_p1,  bot1,  bot1_p1);
                        pool_result2[pool_count]  <= max4(top2,  top2_p1,  bot2,  bot2_p1);
                        pool_result3[pool_count]  <= max4(top3,  top3_p1,  bot3,  bot3_p1);
                        pool_result4[pool_count]  <= max4(top4,  top4_p1,  bot4,  bot4_p1);
                        pool_result5[pool_count]  <= max4(top5,  top5_p1,  bot5,  bot5_p1);
                        pool_result6[pool_count]  <= max4(top6,  top6_p1,  bot6,  bot6_p1);
                        pool_result7[pool_count]  <= max4(top7,  top7_p1,  bot7,  bot7_p1);
                        pool_result8[pool_count]  <= max4(top8,  top8_p1,  bot8,  bot8_p1);
                        pool_result9[pool_count]  <= max4(top9,  top9_p1,  bot9,  bot9_p1);
                        pool_result10[pool_count] <= max4(top10, top10_p1, bot10, bot10_p1);
                        pool_result11[pool_count] <= max4(top11, top11_p1, bot11, bot11_p1);
                        pool_result12[pool_count] <= max4(top12, top12_p1, bot12, bot12_p1);
                        pool_result13[pool_count] <= max4(top13, top13_p1, bot13, bot13_p1);
                        pool_result14[pool_count] <= max4(top14, top14_p1, bot14, bot14_p1);
                        pool_result15[pool_count] <= max4(top15, top15_p1, bot15, bot15_p1);
                        pool_result16[pool_count] <= max4(top16, top16_p1, bot16, bot16_p1);

                        valid_out  <= 1'b1;
                        pool_count <= pool_count + 8'd1;

                        if (pool_col == 5'd24) begin
                            pool_col <= 5'd0;
                            pool_row <= pool_row + 5'd2;
                        end else begin
                            pool_col <= pool_col + 5'd2;
                        end

                        pool_phase <= 3'd0;

                        if (pool_count == 8'd168) begin
                            done          <= 1'b1;
                            busy          <= 1'b0;
                            start_latched <= 1'b0;
                        end
                    end

                    default: pool_phase <= 3'd0;
                endcase
            end
        end
    end

endmodule
