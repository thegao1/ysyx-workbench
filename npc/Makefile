# .PHONY: sim clean

# SIM_CSRC := $(wildcard csrc/main.cpp)
# NV_CSRC  := $(WILDCARD csrc/nv_main.cpp)

# VSRC := $(wildcard vsrc/*.v)

# sim: $(SIM_CSRC) $(VSRC)
# 	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
# 	@rm -rf obj_dir
# 	@verilator -Wall -Wno-fatal --trace --cc $(VSRC) --exe $(CSRC)
# 	@make -C obj_dir -f Vtop.mk
# 	@./obj_dir/Vtop
# 	@vcd2fst -v wave.vcd -f wave.fst
# 	@gtkwave wave.fst
# clean :
# 	rm -rf obj_dir

include ../Makefile

export NVBOARD_HOME ?= $(abspath ../nvboard)

TOPNAME = top
NXDC_FILES = constr/top.nxdc
INC_PATH ?=

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc  \
				-O3 --x-assign fast --x-initial fast --noassert --trace

BUILD_DIR = ./build
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)

default: $(BIN)

$(shell mkdir -p $(BUILD_DIR))

# constraint file
SRC_AUTO_BIND = $(abspath $(BUILD_DIR)/auto_bind.cpp)
$(SRC_AUTO_BIND): $(NXDC_FILES)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@

# project source
VSRCS = $(shell find $(abspath ./vsrc) -name "*.v")
CSRCS = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
CSRCS += $(abspath ./sEMU/hello.c)
CSRCS += $(SRC_AUTO_BIND)

# rules for NVBoard
include $(NVBOARD_HOME)/scripts/nvboard.mk

# rules for verilator
INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\""

$(BIN): $(VSRCS) $(CSRCS) $(NVBOARD_ARCHIVE)
	@rm -rf $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

all: default

run: $(BIN)
	@$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	@$^

# 单独编 emulator（脱离 RTL，调 sEMU 自己的 bug 用）。
# EMU_STANDALONE 是 hello.c 里 main 的开关：带上才有 main，不带就只有 emu_* 供 difftest 调。
emu:
	gcc -DEMU_STANDALONE -O2 -g -o $(abspath ./sEMU/sEMU) $(abspath ./sEMU/hello.c)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: default all clean run emu