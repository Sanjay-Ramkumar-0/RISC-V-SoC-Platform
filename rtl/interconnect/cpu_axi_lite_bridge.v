// ============================================================
//  CPU dmem port → AXI4-Lite Master Bridge
// ============================================================
// Converts the simple RISC-V data-memory interface into a
// correct AXI4-Lite master that respects READY/VALID handshakes
// and waits for BRESP / RRESP before asserting dmem_ready.
// ============================================================

`timescale 1ns/1ps

module cpu_axi_lite_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // ------------------------------------------------------------------
    // CPU data-memory port
    // ------------------------------------------------------------------
    input  wire [ADDR_WIDTH-1:0]    dmem_addr,
    input  wire [DATA_WIDTH-1:0]    dmem_wdata,
    input  wire                     dmem_we,
    input  wire                     dmem_re,
    input  wire [1:0]               dmem_size,   // unused for now (always word)
    output reg  [DATA_WIDTH-1:0]    dmem_rdata,
    output reg                      dmem_ready,

    // ------------------------------------------------------------------
    // AXI4-Lite Master
    // ------------------------------------------------------------------
    output reg  [ADDR_WIDTH-1:0]    m_axi_awaddr,
    output reg                      m_axi_awvalid,
    input  wire                     m_axi_awready,

    output reg  [DATA_WIDTH-1:0]    m_axi_wdata,
    output reg  [DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output reg                      m_axi_wvalid,
    input  wire                     m_axi_wready,

    input  wire [1:0]               m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output reg                      m_axi_bready,

    output reg  [ADDR_WIDTH-1:0]    m_axi_araddr,
    output reg                      m_axi_arvalid,
    input  wire                     m_axi_arready,

    input  wire [DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rvalid,
    output reg                      m_axi_rready
);

    // ----------------------------------------------------------------
    // FSM
    // ----------------------------------------------------------------
    localparam S_IDLE       = 3'd0;
    localparam S_WR_ADDR    = 3'd1;
    localparam S_WR_DATA    = 3'd2;
    localparam S_WR_RESP    = 3'd3;
    localparam S_RD_ADDR    = 3'd4;
    localparam S_RD_DATA    = 3'd5;

    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            dmem_ready    <= 1'b0;
            dmem_rdata    <= {DATA_WIDTH{1'b0}};

            m_axi_awaddr  <= {ADDR_WIDTH{1'b0}};
            m_axi_awvalid <= 1'b0;
            m_axi_wdata   <= {DATA_WIDTH{1'b0}};
            m_axi_wstrb   <= {(DATA_WIDTH/8){1'b0}};
            m_axi_wvalid  <= 1'b0;
            m_axi_bready  <= 1'b0;

            m_axi_araddr  <= {ADDR_WIDTH{1'b0}};
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
        end else begin
            // defaults
            dmem_ready    <= 1'b0;
            m_axi_bready  <= 1'b0;
            m_axi_rready  <= 1'b0;

            case (state)
                // ------------------------------------------------
                S_IDLE: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_arvalid <= 1'b0;

                    if (dmem_we) begin
                        m_axi_awaddr  <= dmem_addr;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata   <= dmem_wdata;
                        m_axi_wstrb   <= 4'hF;          // full word for now
                        m_axi_wvalid  <= 1'b1;
                        state         <= S_WR_ADDR;
                    end else if (dmem_re) begin
                        m_axi_araddr  <= dmem_addr;
                        m_axi_arvalid <= 1'b1;
                        state         <= S_RD_ADDR;
                    end
                end

                // ------------------------------------------------
                // Write path: present AW + W, wait for both ready
                // ------------------------------------------------
                S_WR_ADDR: begin
                    // Keep asserting until both channels accepted
                    if (m_axi_awvalid && m_axi_awready)
                        m_axi_awvalid <= 1'b0;
                    if (m_axi_wvalid && m_axi_wready)
                        m_axi_wvalid  <= 1'b0;

                    if ( (!m_axi_awvalid || m_axi_awready) &&
                         (!m_axi_wvalid  || m_axi_wready) ) begin
                        // Both address and data accepted → wait for response
                        state        <= S_WR_RESP;
                        m_axi_bready <= 1'b1;
                    end
                end

                S_WR_RESP: begin
                    m_axi_bready <= 1'b1;
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        dmem_ready   <= 1'b1;   // transaction complete
                        state        <= S_IDLE;
                    end
                end

                // ------------------------------------------------
                // Read path
                // ------------------------------------------------
                S_RD_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        state         <= S_RD_DATA;
                        m_axi_rready  <= 1'b1;
                    end
                end

                S_RD_DATA: begin
                    m_axi_rready <= 1'b1;
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready <= 1'b0;
                        dmem_rdata   <= m_axi_rdata;
                        dmem_ready   <= 1'b1;
                        state        <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
