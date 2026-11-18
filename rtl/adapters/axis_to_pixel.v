// ============================================================
//  AXI-Stream to CNN Pixel Adapter
// ============================================================
// Converts a standard AXI-Stream (32-bit data) into the simple
// pixel_in + pixel_in_valid interface expected by the CNN.
//
// For 8-bit pixels packed into 32-bit words we unpack them
// sequentially (byte 0 → byte 1 → byte 2 → byte 3).
// ============================================================

`timescale 1ns/1ps

module axis_to_pixel #(
    parameter DATA_WIDTH = 32,
    parameter PIXEL_WIDTH = 8
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // AXI-Stream Slave (from DMA Read)
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire                     s_axis_tlast,   // optional

    // CNN pixel interface
    output reg  [PIXEL_WIDTH-1:0]   pixel_out,
    output reg                      pixel_out_valid,
    input  wire                     pixel_out_ready, // back-pressure from CNN (tie to 1 if none)

    // Control
    input  wire                     enable,         // only forward when transfer is active
    output reg                      frame_done      // pulses when tlast seen (or external)
);

    // Simple 1-word buffer + byte unpacker
    reg [DATA_WIDTH-1:0] data_buf;
    reg                  buf_valid;
    reg [1:0]            byte_idx;          // which byte to emit next
    reg                  last_flag;

    // Ready when we can accept a new word
    assign s_axis_tready = enable && !buf_valid && pixel_out_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_buf        <= {DATA_WIDTH{1'b0}};
            buf_valid       <= 1'b0;
            byte_idx        <= 2'd0;
            last_flag       <= 1'b0;
            pixel_out       <= {PIXEL_WIDTH{1'b0}};
            pixel_out_valid <= 1'b0;
            frame_done      <= 1'b0;
        end else begin
            frame_done      <= 1'b0;
            pixel_out_valid <= 1'b0;

            // Accept new AXI beat
            if (s_axis_tvalid && s_axis_tready) begin
                data_buf  <= s_axis_tdata;
                buf_valid <= 1'b1;
                byte_idx  <= 2'd0;
                last_flag <= s_axis_tlast;
            end

            // Emit one pixel per cycle while buffer holds data
            if (buf_valid && pixel_out_ready && enable) begin
                case (byte_idx)
                    2'd0: pixel_out <= data_buf[7:0];
                    2'd1: pixel_out <= data_buf[15:8];
                    2'd2: pixel_out <= data_buf[23:16];
                    2'd3: pixel_out <= data_buf[31:24];
                endcase
                pixel_out_valid <= 1'b1;

                if (byte_idx == 2'd3) begin
                    buf_valid <= 1'b0;
                    if (last_flag)
                        frame_done <= 1'b1;
                end else begin
                    byte_idx <= byte_idx + 2'd1;
                end
            end
        end
    end

endmodule
