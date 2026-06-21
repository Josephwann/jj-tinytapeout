# Run using make -f Makefile.bf -B
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src

VERILOG_SOURCES = $(SRC_DIR)/bf.v $(PWD)/tb_bf.v

TOPLEVEL = tb_bf
MODULE = test_bf

include $(shell cocotb-config --makefiles)/Makefile.sim