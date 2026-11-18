// ============================================================
//  Streaming Engine specialized for CNN
// ============================================================
// Uses existing dma_read_engine + ram_sp.
// Output goes through axis_to_pixel adapter into the CNN.
// ============================================================

`timescale 1ns/1ps

module streaming_engine_cnn #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH  = 16,
    parameter MEM_DEPTH  = 1024
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // Control from AXI-Lite regs
    input  wire                     start,
    input  wire [ADDR_WIDTH-1:0]    src_addr,
    input  wire [LEN_WIDTH-1:0]     transfer_len,
    output wire                     busy,
    output reg                      done,

    // Image SRAM preload interface (CPU side, only while idle)
    input  wire [ADDR_WIDTH-1:0]    img_mem_addr,
    input  wire [DATA_WIDTH-1:0]    img_mem_wdata,
    input  wire                     img_mem_we,
    output wire [DATA_WIDTH-1:0]    img_mem_rdata,

    // AXI-Stream toward CNN adapter
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire                     m_axis_tlast
);

    // Internal signals
    wire [ADDR_WIDTH-1:0] read_ram_addr;
    wire [DATA_WIDTH-1:0] read_ram_rdata;
    wire                  read_done;
    wire                  read_busy;

    reg  transfer_active;
    wire start_transfer = start && !transfer_active;

    // ----------------------------------------------------------------
    // DMA Read Engine
    // ----------------------------------------------------------------
    dma_read_engine #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .LEN_WIDTH  (LEN_WIDTH)
    ) u_dma_read (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start_transfer),
        .src_addr        (src_addr),
        .transfer_length (transfer_len),
        .ram_addr        (read_ram_addr),
        .ram_rdata       (read_ram_rdata),
        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tready   (m_axis_tready),
        .busy            (read_busy),
        .done            (read_done)
    );

    // Simple tlast generation (last beat of the transfer)
    // Approximate: assert tlast when remaining bytes <= DATA_WIDTH/8
    // For simplicity we leave tlast = 0 here; the adapter can ignore it
    // or the higher level can pulse frame_done after the expected length.
    assign m_axis_tlast = 1'b0;

    // ----------------------------------------------------------------
    // Image SRAM (single-port)
    // ----------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] ram_addr_i;
    wire                  ram_we_i;
    wire [DATA_WIDTH-1:0] ram_wdata_i;

    assign ram_addr_i  = (transfer_active || start_transfer) ? read_ram_addr : img_mem_addr;
    assign ram_we_i    = (!(transfer_active || start_transfer)) && img_mem_we;
    assign ram_wdata_i = img_mem_wdata;

    ram_sp #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (MEM_DEPTH)
    ) u_image_ram (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (ram_addr_i),
        .wdata (ram_wdata_i),
        .we    (ram_we_i),
        .rdata (read_ram_rdata)
    );

    assign img_mem_rdata = read_ram_rdata;

    // ----------------------------------------------------------------
    // Transfer control
    // ----------------------------------------------------------------
    assign busy = transfer_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transfer_active <= 1'b0;
            done            <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start_transfer && (transfer_len != 0))
                transfer_active <= 1'b1;

            if (read_done) begin
                transfer_active <= 1'b0;
                done            <= 1'b1;
            end
        end
    end

endmodule
