# ============================================================
#  SoC Project Makefile (Icarus Verilog)
# ============================================================

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

RTL_DIR  = rtl
TB_DIR   = tb
SIM_DIR  = sim

INCLUDES = -I$(RTL_DIR)/cpu

CPU_SRCS = \
	$(RTL_DIR)/cpu/defines.vh \
	$(RTL_DIR)/cpu/decoder.v \
	$(RTL_DIR)/cpu/rv32i.v \
	$(RTL_DIR)/cpu/rv64m.v \
	$(RTL_DIR)/cpu/alu.v \
	$(RTL_DIR)/cpu/agu.v \
	$(RTL_DIR)/cpu/branch_unit.v \
	$(RTL_DIR)/cpu/muldiv.v \
	$(RTL_DIR)/cpu/regfile.v \
	$(RTL_DIR)/cpu/forwarding_unit.v \
	$(RTL_DIR)/cpu/hazard_unit.v \
	$(RTL_DIR)/cpu/btb.v \
	$(RTL_DIR)/cpu/predictor.v \
	$(RTL_DIR)/cpu/pipeline.v \
	$(RTL_DIR)/cpu/cpu.v \
	$(RTL_DIR)/cpu/memory.v

DSE_SRCS = \
	$(RTL_DIR)/data_streaming_engine/dma_read_engine.v \
	$(RTL_DIR)/data_streaming_engine/data_streaming_engine.v

SRAM_SRCS = \
	$(RTL_DIR)/sram/ram_sp.v

INTERCONNECT_SRCS = \
	$(RTL_DIR)/interconnect/axi_lite_regs.v \
	$(RTL_DIR)/interconnect/cpu_axi_lite_bridge.v

CNN_SRCS = \
	$(RTL_DIR)/cnn/mac_unit.v \
	$(RTL_DIR)/cnn/line_buffer.v \
	$(RTL_DIR)/cnn/control_logic.v \
	$(RTL_DIR)/cnn/convolution.v \
	$(RTL_DIR)/cnn/conv.v \
	$(RTL_DIR)/cnn/ReLU.v \
	$(RTL_DIR)/cnn/MaxPool.v \
	$(RTL_DIR)/cnn/FC.v

ADAPTER_SRCS = \
	$(RTL_DIR)/adapters/axis_to_pixel.v

TOP_SRCS = \
	$(RTL_DIR)/soc_top.v

TB_SRCS = \
	$(TB_DIR)/tb_soc.v

ALL_SRCS = $(CPU_SRCS) $(DSE_SRCS) $(SRAM_SRCS) $(INTERCONNECT_SRCS) \
           $(CNN_SRCS) $(ADAPTER_SRCS) $(TOP_SRCS) $(TB_SRCS)

.PHONY: all compile run wave clean

all: run

$(SIM_DIR):
	mkdir -p $(SIM_DIR)

compile: $(SIM_DIR)
	$(IVERILOG) -g2012 $(INCLUDES) -o $(SIM_DIR)/soc.vvp $(ALL_SRCS)

run: compile
	cd $(SIM_DIR) && $(VVP) soc.vvp

wave:
	$(GTKWAVE) $(SIM_DIR)/soc.vcd &

clean:
	rm -rf $(SIM_DIR)/*.vvp $(SIM_DIR)/*.vcd
