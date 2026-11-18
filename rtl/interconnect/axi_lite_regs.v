// ============================================================
//  AXI-Lite Control Registers for Streaming Engine + CNN
// ============================================================
// Memory Map (base address set by interconnect):
//   0x00 : CONTROL      [0]=start, [1]=soft_reset
//   0x04 : STATUS       [0]=busy, [1]=done, [2]=cnn_valid
//   0x08 : SRC_ADDR     source address in image SRAM
//   0x0C : DST_ADDR     (reserved / optional)
//   0x10 : LENGTH       transfer length in bytes (784 for 28x28)
//   0x14 : PREDICTION   [3:0] CNN result (read-only)
//   0x18 : IRQ_ENABLE   [0]=done interrupt enable
//   0x1C : IRQ_STATUS   [0]=done interrupt (W1C)
// ============================================================

`timescale 1ns/1ps

module axi_lite_regs #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // AXI-Lite Slave Interface
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output reg                      s_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output reg                      s_axi_wready,

    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output reg                      s_axi_arready,

    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready,

    // Control / Status to Streaming Engine + CNN
    output reg                      ctrl_start,
    output reg                      ctrl_soft_reset,
    input  wire                     status_busy,
    input  wire                     status_done,
    input  wire                     status_cnn_valid,
    output reg  [ADDR_WIDTH-1:0]    reg_src_addr,
    output reg  [ADDR_WIDTH-1:0]    reg_dst_addr,
    output reg  [15:0]              reg_length,
    input  wire [3:0]               cnn_prediction,
    output reg                      irq_enable,
    output reg                      irq
);

    // Internal registers
    reg [31:0] reg_control;
    reg [31:0] reg_status;
    reg [31:0] reg_irq_status;

    // AXI-Lite write FSM
    reg [1:0] wr_state;
    localparam WR_IDLE = 2'd0, WR_DATA = 2'd1, WR_RESP = 2'd2;
    reg [7:0] wr_addr;

    // AXI-Lite read FSM
    reg [1:0] rd_state;
    localparam RD_IDLE = 2'd0, RD_DATA = 2'd1;
    reg [7:0] rd_addr;

    // ----------------------------------------------------------------
    // Write channel
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state      <= WR_IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            wr_addr       <= 8'd0;

            reg_control   <= 32'd0;
            reg_src_addr  <= 32'd0;
            reg_dst_addr  <= 32'd0;
            reg_length    <= 16'd784;   // default 28x28
            irq_enable    <= 1'b0;
            reg_irq_status<= 32'd0;
            ctrl_start    <= 1'b0;
            ctrl_soft_reset <= 1'b0;
        end else begin
            // Default pulses
            ctrl_start      <= 1'b0;
            ctrl_soft_reset <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b1;
                    if (s_axi_awvalid && s_axi_awready) begin
                        wr_addr       <= s_axi_awaddr[7:0];
                        s_axi_awready <= 1'b0;
                        if (s_axi_wvalid && s_axi_wready) begin
                            // Address + data in same cycle
                            s_axi_wready <= 1'b0;
                            wr_state     <= WR_RESP;
                            s_axi_bvalid <= 1'b1;
                            s_axi_bresp  <= 2'b00;
                            // Decode write
                            case (s_axi_awaddr[7:0])
                                8'h00: begin
                                    reg_control <= s_axi_wdata;
                                    if (s_axi_wdata[0]) ctrl_start <= 1'b1;
                                    if (s_axi_wdata[1]) ctrl_soft_reset <= 1'b1;
                                end
                                8'h08: reg_src_addr <= s_axi_wdata;
                                8'h0C: reg_dst_addr <= s_axi_wdata;
                                8'h10: reg_length   <= s_axi_wdata[15:0];
                                8'h18: irq_enable   <= s_axi_wdata[0];
                                8'h1C: reg_irq_status <= reg_irq_status & ~s_axi_wdata; // W1C
                                default: ;
                            endcase
                        end else begin
                            wr_state <= WR_DATA;
                        end
                    end
                end

                WR_DATA: begin
                    s_axi_wready <= 1'b1;
                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wready <= 1'b0;
                        wr_state     <= WR_RESP;
                        s_axi_bvalid <= 1'b1;
                        s_axi_bresp  <= 2'b00;
                        case (wr_addr)
                            8'h00: begin
                                reg_control <= s_axi_wdata;
                                if (s_axi_wdata[0]) ctrl_start <= 1'b1;
                                if (s_axi_wdata[1]) ctrl_soft_reset <= 1'b1;
                            end
                            8'h08: reg_src_addr <= s_axi_wdata;
                            8'h0C: reg_dst_addr <= s_axi_wdata;
                            8'h10: reg_length   <= s_axi_wdata[15:0];
                            8'h18: irq_enable   <= s_axi_wdata[0];
                            8'h1C: reg_irq_status <= reg_irq_status & ~s_axi_wdata;
                            default: ;
                        endcase
                    end
                end

                WR_RESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase

            // Latch done interrupt
            if (status_done)
                reg_irq_status[0] <= 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // Read channel
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state      <= RD_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
            s_axi_rresp   <= 2'b00;
            rd_addr       <= 8'd0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid && s_axi_arready) begin
                        rd_addr       <= s_axi_araddr[7:0];
                        s_axi_arready <= 1'b0;
                        rd_state      <= RD_DATA;
                        s_axi_rvalid  <= 1'b1;
                        s_axi_rresp   <= 2'b00;
                        case (s_axi_araddr[7:0])
                            8'h00: s_axi_rdata <= reg_control;
                            8'h04: s_axi_rdata <= {29'd0, status_cnn_valid, status_done, status_busy};
                            8'h08: s_axi_rdata <= reg_src_addr;
                            8'h0C: s_axi_rdata <= reg_dst_addr;
                            8'h10: s_axi_rdata <= {16'd0, reg_length};
                            8'h14: s_axi_rdata <= {28'd0, cnn_prediction};
                            8'h18: s_axi_rdata <= {31'd0, irq_enable};
                            8'h1C: s_axi_rdata <= reg_irq_status;
                            default: s_axi_rdata <= 32'd0;
                        endcase
                    end
                end

                RD_DATA: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state     <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // Interrupt output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            irq <= 1'b0;
        else
            irq <= irq_enable && reg_irq_status[0];
    end

endmodule
