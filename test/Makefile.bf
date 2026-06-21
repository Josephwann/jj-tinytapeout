# Makefile.bf
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src

# Only compile the isolated testbench and the bf core
VERILOG_SOURCES = $(SRC_DIR)/bf.v $(PWD)/tb_bf.v

TOPLEVEL = tb_bf
MODULE = test_bf

include $(shell cocotb-config --makefiles)/Makefile.sim