`timescale 1ns/1ps

// ============================================================
//  Single-port synchronous RAM
//  - External addr is a BYTE address
//  - word_addr is explicitly sliced (no WIDTHTRUNC warning)
// ============================================================
module ram_sp #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 1024
)(
    input  wire                  clk,
    input  wire                  rst_n,          // active-low
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire                  we,
    output reg  [DATA_WIDTH-1:0] rdata
);

    localparam ADDR_BITS = $clog2(DEPTH);
    localparam BYTE_BITS = $clog2(DATA_WIDTH / 8);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Intentional: take the word index from the byte address
    wire [ADDR_BITS-1:0] word_addr;
    assign word_addr = addr[BYTE_BITS +: ADDR_BITS];

    always @(posedge clk) begin
        if (!rst_n) begin
            rdata <= {DATA_WIDTH{1'b0}};
        end else begin
            if (we)
                mem[word_addr] <= wdata;
            rdata <= mem[word_addr];
        end
    end

endmodule
