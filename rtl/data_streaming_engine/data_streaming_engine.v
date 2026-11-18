`timescale 1ns/1ps

// ============================================================
//  Data Streaming Engine (DMA subsystem)
// ============================================================
// Hierarchy for Innovus / standard SoC:
//   Control + DMA Read Engine → AXI-Stream master
//
// SRAM is EXTERNAL (rtl/sram/).  This module only presents a
// memory-master interface that soc_top connects to the SRAM.
//
// For the current CNN path only the read engine is active.
// dma_write_engine, descriptor manager, etc. remain available
// in the folder for a future full-copy / multi-channel DMA.
// ============================================================

module data_streaming_engine #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH  = 16
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // ------------------------------------------------------------------
    // Control interface (driven by axi_lite_regs)
    // ------------------------------------------------------------------
    input  wire                     start,           // pulse
    input  wire [ADDR_WIDTH-1:0]    src_addr,
    input  wire [LEN_WIDTH-1:0]     transfer_len,
    output wire                     busy,
    output reg                      done,

    // ------------------------------------------------------------------
    // External SRAM interface (memory master)
    // Connected at soc_top to the instance in rtl/sram/
    // ------------------------------------------------------------------
    output wire [ADDR_WIDTH-1:0]    mem_addr,
    input  wire [DATA_WIDTH-1:0]    mem_rdata,
    output wire [DATA_WIDTH-1:0]    mem_wdata,
    output wire                     mem_we,

    // ------------------------------------------------------------------
    // AXI-Stream master toward CNN (via axis_to_pixel)
    // ------------------------------------------------------------------
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output reg                      m_axis_tlast
);

    // -------------------------------------------------------------------------
    // Internal control
    // -------------------------------------------------------------------------
    reg  transfer_active;
    wire start_transfer = start && !transfer_active;

    wire                  read_done;
    wire                  read_busy;
    wire [ADDR_WIDTH-1:0] read_ram_addr;
    wire [DATA_WIDTH-1:0] axis_tdata_i;
    wire                  axis_tvalid_i;

    // Remaining-byte counter for TLAST generation
    reg  [LEN_WIDTH-1:0]  bytes_left;
    localparam [LEN_WIDTH-1:0] BYTES_PER_WORD = DATA_WIDTH / 8;

    assign busy      = transfer_active;
    assign mem_addr  = read_ram_addr;
    assign mem_we    = 1'b0;                     // read-only for CNN path
    assign mem_wdata = {DATA_WIDTH{1'b0}};

    assign m_axis_tdata  = axis_tdata_i;
    assign m_axis_tvalid = axis_tvalid_i;

    // -------------------------------------------------------------------------
    // DMA Read Engine  (lives inside Data Streaming Engine)
    // -------------------------------------------------------------------------
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
        .ram_rdata       (mem_rdata),
        .m_axis_tdata    (axis_tdata_i),
        .m_axis_tvalid   (axis_tvalid_i),
        .m_axis_tready   (m_axis_tready),
        .busy            (read_busy),
        .done            (read_done)
    );

    // -------------------------------------------------------------------------
    // TLAST generation – assert on the final beat of the transfer
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bytes_left   <= {LEN_WIDTH{1'b0}};
            m_axis_tlast <= 1'b0;
        end else begin
            if (start_transfer)
                bytes_left <= transfer_len;

            // Default
            m_axis_tlast <= 1'b0;

            if (axis_tvalid_i && m_axis_tready) begin
                if (bytes_left <= BYTES_PER_WORD) begin
                    m_axis_tlast <= 1'b1;
                    bytes_left   <= {LEN_WIDTH{1'b0}};
                end else begin
                    bytes_left <= bytes_left - BYTES_PER_WORD;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Transfer control FSM
    // -------------------------------------------------------------------------
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
