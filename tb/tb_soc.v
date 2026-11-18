// ============================================================
//  SoC Testbench – matches current hierarchy
//
//  Hierarchy used:
//    dut.u_image_sram.mem[]
//    dut.u_axi_lite_regs.*
//    dut.u_data_streaming_engine.*
//    dut.status_* / dut.cnn_prediction (via continuous assigns)
// ============================================================

`timescale 1ns/1ps
`include "defines.vh"

module tb_soc;

    reg clk;
    reg rst_n;

    wire [31:0] debug_pc;
    wire        debug_stall;
    wire        irq_cnn_done;

    // Clock – 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT
    soc_top #(
        .XLEN      (32),
        .MEM_DEPTH (4096)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .debug_pc     (debug_pc),
        .debug_stall  (debug_stall),
        .irq_cnn_done (irq_cnn_done)
    );

    // ----------------------------------------------------------------
    // Helper: write a word into main memory (CPU program area)
    // ----------------------------------------------------------------
    task mem_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            dut.u_main_mem.load_word(addr, data);
        end
    endtask

    // ----------------------------------------------------------------
    // Helper: preload image into external SRAM (hierarchical)
    // ----------------------------------------------------------------
    integer i;
    reg [7:0] test_image [0:783];

    task preload_image_zeros;
        begin
            for (i = 0; i < 196; i = i + 1) begin   // 784 bytes / 4
                dut.u_image_sram.mem[i] = 32'h0000_0000;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    initial begin
        $display("============================================");
        $display(" SoC Testbench - RISC-V + DSE + CNN");
        $display(" Hierarchy: data_streaming_engine + external SRAM");
        $display("============================================");

        rst_n = 0;
        #100;
        rst_n = 1;
        #50;

        // ----------------------------------------------------------
        // 1. Preload a simple test image (all zeros)
        //    Hierarchical access into the external SRAM instance
        // ----------------------------------------------------------
        for (i = 0; i < 784; i = i + 1)
            test_image[i] = 8'h00;

        preload_image_zeros();
        $display("[%0t] Image preloaded into u_image_sram (all zeros)", $time);

        // ----------------------------------------------------------
        // 2. Program the accelerator via the AXI-Lite register path
        //    We drive the register outputs of axi_lite_regs directly
        //    for this first-level functional test (CPU not executing
        //    a real program yet).
        // ----------------------------------------------------------
        // Force the control registers inside axi_lite_regs
        // (these are the actual storage elements of the slave)
        force dut.u_axi_lite_regs.reg_src_addr = 32'h0000_0000;
        force dut.u_axi_lite_regs.reg_length   = 16'd784;

        // Pulse start
        force dut.u_axi_lite_regs.ctrl_start = 1'b1;
        #20;
        force dut.u_axi_lite_regs.ctrl_start = 1'b0;
        release dut.u_axi_lite_regs.ctrl_start;

        $display("[%0t] Started Data Streaming Engine", $time);

        // ----------------------------------------------------------
        // 3. Wait for completion
        // ----------------------------------------------------------
        wait (dut.status_done || dut.status_cnn_valid);
        #100;

        $display("[%0t] Transfer / CNN finished", $time);
        $display("    STATUS busy=%b done=%b cnn_valid=%b",
                 dut.status_busy, dut.status_done, dut.status_cnn_valid);
        $display("    PREDICTION = %0d", dut.cnn_prediction);

        #200;
        $display("============================================");
        $display(" Test finished");
        $display("============================================");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #5_000_000;   // 5 ms
        $display("ERROR: Simulation timeout");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("soc.vcd");
        $dumpvars(0, tb_soc);
    end

endmodule
