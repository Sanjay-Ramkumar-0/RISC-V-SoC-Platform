// ============================================================
//  SoC Top Level
//  Target architecture for Genus / Innovus:
//
//      RISC-V CPU
//          │
//     cpu_axi_lite_bridge
//          │
//     axi_lite_regs  (interconnect/)
//          │
//     Data Streaming Engine  (DMA subsystem)
//          │ mem ports          │ AXI-Stream
//          ▼                    ▼
//        SRAM                 CNN
// ============================================================

`timescale 1ns/1ps
`include "defines.vh"

module soc_top #(
    parameter XLEN       = `XLEN,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH  = 256
)(
    input  wire             clk,
    input  wire             rst_n,

    // Optional external UART / debug
    output wire [XLEN-1:0]  debug_pc,
    output wire             debug_stall,
    output wire             irq_cnn_done
);

    // ----------------------------------------------------------------
    // RISC-V Core
    // ----------------------------------------------------------------
    wire [XLEN-1:0] imem_addr;
    wire [31:0]     imem_rdata;
    wire [XLEN-1:0] dmem_addr;
    wire [XLEN-1:0] dmem_wdata;
    wire            dmem_we;
    wire            dmem_re;
    wire [1:0]      dmem_size;
    wire [XLEN-1:0] dmem_rdata;
    wire            dmem_ready;

    cpu #(.XLEN(XLEN)) u_cpu (
        .clk         (clk),
        .rst_n       (rst_n),
        .imem_addr   (imem_addr),
        .imem_rdata  (imem_rdata),
        .dmem_addr   (dmem_addr),
        .dmem_wdata  (dmem_wdata),
        .dmem_we     (dmem_we),
        .dmem_re     (dmem_re),
        .dmem_size   (dmem_size),
        .dmem_rdata  (dmem_rdata),
        .dmem_ready  (dmem_ready),
        .debug_pc    (debug_pc),
        .debug_stall (debug_stall)
    );

    // ----------------------------------------------------------------
    // Address map
    //   0x0000_0000 - 0x0FFF_FFFF : main instruction/data memory
    //   0x1000_0000 - 0x1000_FFFF : accelerator control (AXI-Lite)
    //   0x2000_0000 - 0x2000_FFFF : image SRAM (CPU accessible when idle)
    // ----------------------------------------------------------------
    wire is_accel_access = (dmem_addr[31:16] == 16'h1000);
    wire is_sram_access  = (dmem_addr[31:16] == 16'h2000);

    // ----------------------------------------------------------------
    // Main instruction / data memory (CPU local)
    // ----------------------------------------------------------------
    wire [XLEN-1:0] main_mem_rdata;

    main_memory #(
        .DEPTH (MEM_DEPTH),
        .XLEN  (XLEN)
    ) u_main_mem (
        .clk     (clk),
        .i_addr  (imem_addr),
        .i_rdata (imem_rdata),
        .d_addr  (dmem_addr),
        .d_re    (dmem_re && !is_accel_access && !is_sram_access),
        .d_we    (dmem_we && !is_accel_access && !is_sram_access),
        .d_size  (dmem_size),
        .d_wdata (dmem_wdata),
        .d_rdata (main_mem_rdata)
    );

    // ----------------------------------------------------------------
    // CPU → AXI-Lite Master Bridge  (interconnect/)
    // ----------------------------------------------------------------
    wire [ADDR_WIDTH-1:0]   axi_awaddr;
    wire                    axi_awvalid;
    wire                    axi_awready;
    wire [DATA_WIDTH-1:0]   axi_wdata;
    wire [DATA_WIDTH/8-1:0] axi_wstrb;
    wire                    axi_wvalid;
    wire                    axi_wready;
    wire [1:0]              axi_bresp;
    wire                    axi_bvalid;
    wire                    axi_bready;
    wire [ADDR_WIDTH-1:0]   axi_araddr;
    wire                    axi_arvalid;
    wire                    axi_arready;
    wire [DATA_WIDTH-1:0]   axi_rdata;
    wire [1:0]              axi_rresp;
    wire                    axi_rvalid;
    wire                    axi_rready;

    wire [DATA_WIDTH-1:0]   bridge_rdata;
    wire                    bridge_ready;

    cpu_axi_lite_bridge #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_cpu_axi_bridge (
        .clk            (clk),
        .rst_n          (rst_n),

        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_we        (dmem_we && is_accel_access),
        .dmem_re        (dmem_re && is_accel_access),
        .dmem_size      (dmem_size),
        .dmem_rdata     (bridge_rdata),
        .dmem_ready     (bridge_ready),

        .m_axi_awaddr   (axi_awaddr),
        .m_axi_awvalid  (axi_awvalid),
        .m_axi_awready  (axi_awready),
        .m_axi_wdata    (axi_wdata),
        .m_axi_wstrb    (axi_wstrb),
        .m_axi_wvalid   (axi_wvalid),
        .m_axi_wready   (axi_wready),
        .m_axi_bresp    (axi_bresp),
        .m_axi_bvalid   (axi_bvalid),
        .m_axi_bready   (axi_bready),
        .m_axi_araddr   (axi_araddr),
        .m_axi_arvalid  (axi_arvalid),
        .m_axi_arready  (axi_arready),
        .m_axi_rdata    (axi_rdata),
        .m_axi_rresp    (axi_rresp),
        .m_axi_rvalid   (axi_rvalid),
        .m_axi_rready   (axi_rready)
    );

    // ----------------------------------------------------------------
    // AXI-Lite Register Block  (interconnect/)
    // ----------------------------------------------------------------
    wire        ctrl_start;
    wire        ctrl_soft_reset;
    wire        status_busy;
    wire        status_done;
    wire        status_cnn_valid;
    wire [31:0] reg_src_addr;
    wire [31:0] reg_dst_addr;
    wire [15:0] reg_length;
    wire [3:0]  cnn_prediction;
    wire        irq_enable;
    wire        irq;

    axi_lite_regs #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_axi_lite_regs (
        .clk              (clk),
        .rst_n            (rst_n),

        .s_axi_awaddr     (axi_awaddr),
        .s_axi_awvalid    (axi_awvalid),
        .s_axi_awready    (axi_awready),
        .s_axi_wdata      (axi_wdata),
        .s_axi_wstrb      (axi_wstrb),
        .s_axi_wvalid     (axi_wvalid),
        .s_axi_wready     (axi_wready),
        .s_axi_bresp      (axi_bresp),
        .s_axi_bvalid     (axi_bvalid),
        .s_axi_bready     (axi_bready),
        .s_axi_araddr     (axi_araddr),
        .s_axi_arvalid    (axi_arvalid),
        .s_axi_arready    (axi_arready),
        .s_axi_rdata      (axi_rdata),
        .s_axi_rresp      (axi_rresp),
        .s_axi_rvalid     (axi_rvalid),
        .s_axi_rready     (axi_rready),

        .ctrl_start       (ctrl_start),
        .ctrl_soft_reset  (ctrl_soft_reset),
        .status_busy      (status_busy),
        .status_done      (status_done),
        .status_cnn_valid (status_cnn_valid),
        .reg_src_addr     (reg_src_addr),
        .reg_dst_addr     (reg_dst_addr),
        .reg_length       (reg_length),
        .cnn_prediction   (cnn_prediction),
        .irq_enable       (irq_enable),
        .irq              (irq)
    );

    assign irq_cnn_done = irq;

    // ----------------------------------------------------------------
    // External Image SRAM  (rtl/sram/)
    // ----------------------------------------------------------------
    // Arbitration:
    //   - When DSE is busy  → DSE owns the SRAM ports
    //   - When DSE is idle  → CPU can read/write via 0x2000_0000
    // ----------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] dse_mem_addr;
    wire [DATA_WIDTH-1:0] dse_mem_wdata;
    wire                  dse_mem_we;
    wire [DATA_WIDTH-1:0] sram_rdata;

    wire                  se_busy;
    wire                  se_done;

    wire cpu_sram_we = dmem_we && is_sram_access && !se_busy;
    wire cpu_sram_re = dmem_re && is_sram_access && !se_busy;

    wire [ADDR_WIDTH-1:0] sram_addr  = se_busy ? dse_mem_addr : dmem_addr;
    wire [DATA_WIDTH-1:0] sram_wdata = se_busy ? dse_mem_wdata : dmem_wdata;
    wire                  sram_we    = se_busy ? dse_mem_we    : cpu_sram_we;

    ram_sp #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (MEM_DEPTH)
    ) u_image_sram (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (sram_addr),
        .wdata (sram_wdata),
        .we    (sram_we),
        .rdata (sram_rdata)
    );

    // CPU read data from SRAM is registered (1-cycle latency of ram_sp)
    reg [DATA_WIDTH-1:0] sram_rdata_q;
    reg                  sram_re_q;
    // Synchronous reset only (matches ram_sp) – avoids SYNCASYNCNET
    always @(posedge clk) begin
        if (!rst_n) begin
            sram_rdata_q <= {DATA_WIDTH{1'b0}};
            sram_re_q    <= 1'b0;
        end else begin
            sram_re_q    <= cpu_sram_re;
            sram_rdata_q <= sram_rdata;
        end
    end

    // ----------------------------------------------------------------
    // Data Streaming Engine  (DMA subsystem)
    // ----------------------------------------------------------------
    wire [DATA_WIDTH-1:0] axis_tdata;
    wire                  axis_tvalid;
    wire                  axis_tready;
    wire                  axis_tlast;

    data_streaming_engine #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .LEN_WIDTH  (16)
    ) u_data_streaming_engine (
        .clk            (clk),
        .rst_n          (rst_n),

        .start          (ctrl_start),
        .src_addr       (reg_src_addr),
        .transfer_len   (reg_length),
        .busy           (se_busy),
        .done           (se_done),

        // Memory master → external SRAM
        .mem_addr       (dse_mem_addr),
        .mem_rdata      (sram_rdata),
        .mem_wdata      (dse_mem_wdata),
        .mem_we         (dse_mem_we),

        // AXI-Stream → CNN path
        .m_axis_tdata   (axis_tdata),
        .m_axis_tvalid  (axis_tvalid),
        .m_axis_tready  (axis_tready),
        .m_axis_tlast   (axis_tlast)
    );

    assign status_busy = se_busy;
    assign status_done = se_done;

    // ----------------------------------------------------------------
    // CPU data-return mux + ready generation
    // ----------------------------------------------------------------
    // Main memory is combinational → ready immediately
    // AXI-Lite path uses the bridge's ready
    // SRAM path has 1-cycle latency
    assign dmem_rdata = is_accel_access ? bridge_rdata :
                        is_sram_access  ? sram_rdata_q :
                                          main_mem_rdata;

    assign dmem_ready = is_accel_access ? bridge_ready :
                        is_sram_access  ? sram_re_q    :
                                          1'b1;

    // ----------------------------------------------------------------
    // AXI-Stream → Pixel adapter
    // ----------------------------------------------------------------
    wire [7:0]  pixel;
    wire        pixel_valid;
    wire        pixel_ready = 1'b1;   // CNN currently has no back-pressure
    wire        frame_done;

    axis_to_pixel #(
        .DATA_WIDTH  (DATA_WIDTH),
        .PIXEL_WIDTH (8)
    ) u_axis_to_pixel (
        .clk             (clk),
        .rst_n           (rst_n),
        .s_axis_tdata    (axis_tdata),
        .s_axis_tvalid   (axis_tvalid),
        .s_axis_tready   (axis_tready),
        .s_axis_tlast    (axis_tlast),
        .pixel_out       (pixel),
        .pixel_out_valid (pixel_valid),
        .pixel_out_ready (pixel_ready),
        .enable          (se_busy || ctrl_start),
        .frame_done      (frame_done)
    );

    // Tie-offs for unused CNN status ports (keeps lint clean)
    wire _nc_conv_start, _nc_conv_done, _nc_conv_busy, _nc_conv_vin, _nc_conv_vout;
    wire _nc_relu_start, _nc_relu_done, _nc_relu_busy, _nc_relu_vin, _nc_relu_vout;
    wire _nc_pool_start, _nc_pool_done, _nc_pool_busy, _nc_pool_vin, _nc_pool_vout;
    wire _nc_fc_start, _nc_fc_done, _nc_fc_busy, _nc_fc_vin, _nc_fc_vout;

    // ----------------------------------------------------------------
    // CNN Accelerator
    // ----------------------------------------------------------------
    wire [3:0] prediction;
    wire       cnn_valid;

    conv #(
        .DATA_WIDTH   (8),
        .KERNEL_SIZE  (3),
        .IMAGE_WIDTH  (28),
        .IMAGE_HEIGHT (28)
    ) u_cnn (
        .clk            (clk),
        .rst            (~rst_n),
        .pixel_in       (pixel),
        .pixel_in_valid (pixel_valid),
        .start          (ctrl_start),
        .prediction     (prediction),
        .data_out_valid (cnn_valid),
        .conv_start     (_nc_conv_start),
        .conv_done      (_nc_conv_done),
        .conv_busy      (_nc_conv_busy),
        .conv_valid_in  (_nc_conv_vin),
        .conv_valid_out (_nc_conv_vout),
        .relu_start     (_nc_relu_start),
        .relu_done      (_nc_relu_done),
        .relu_busy      (_nc_relu_busy),
        .relu_valid_in  (_nc_relu_vin),
        .relu_valid_out (_nc_relu_vout),
        .pool_start     (_nc_pool_start),
        .pool_done      (_nc_pool_done),
        .pool_busy      (_nc_pool_busy),
        .pool_valid_in  (_nc_pool_vin),
        .pool_valid_out (_nc_pool_vout),
        .fc_start       (_nc_fc_start),
        .fc_done        (_nc_fc_done),
        .fc_busy        (_nc_fc_busy),
        .fc_valid_in    (_nc_fc_vin),
        .fc_valid_out   (_nc_fc_vout)
    );

    assign cnn_prediction   = prediction;
    assign status_cnn_valid = cnn_valid;

endmodule
