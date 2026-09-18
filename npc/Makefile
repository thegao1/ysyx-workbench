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

# 根 Makefile 的 _default 会被当成默认目标，这里显式改回编 BIN
.DEFAULT_GOAL = $(BIN)

export NVBOARD_HOME ?= $(abspath ../nvboard)

# 模式切换：make（默认）编 SoC(SimTop)；make MODE=npc 编独立版
MODE ?= soc
ifeq ($(MODE), soc)
TOPNAME = SimTop
MODE_VFLAGS   = -DNPC_SOC          # 给 verilator：RTL 的 `ifdef NPC_SOC
MODE_CXXFLAGS = -DNPC_SOC          # 给 C++ 编译器：main.cpp 的 #ifdef NPC_SOC
EXTRA_SRC = $(PERIP) $(MINRIV)
else
TOPNAME = ysyx_100023197
MODE_VFLAGS   =
MODE_CXXFLAGS =
EXTRA_SRC =
endif
NXDC_FILES = constr/top.nxdc
INC_PATH ?=

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc  \
				-O3 --x-assign fast --x-initial fast --noassert --trace -Wno-fatal \
				--timescale "1ns/1ns" --no-timing  -D__VERILOG__ -DPDK_BEHAV\
				-D__UART_TO_CONSOLE__ \
				-I$(SOC_DIR)/perip/uart16550/rtl -I$(SOC_DIR)/perip/spi/rtl
BUILD_DIR = ./build
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)

SOC_DIR = $(abspath ../ysyxSoC)
PER_DIR = $(SOC_DIR)/perip
MINIRV_DIR=$(abspath ./soc)

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
# CSRCS += $(SRC_AUTO_BIND)  # SoC 仿真不用 NVBoard
PERIP = $(shell find $(abspath $(PER_DIR)) -name "*.v" -or -name "*.sv")
MINRIV= $(shell find $(abspath $(MINIRV_DIR)) -name "*.v")
# rules for NVBoard
include $(NVBOARD_HOME)/scripts/nvboard.mk

# rules for verilator
INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\""

# 独立仿真（NVBoard 版）用：$(BIN): $(VSRCS) $(CSRCS) $(NVBOARD_ARCHIVE) $(PERIP) $(MINRIV)
# SoC 仿真（SimTop）不用 NVBoard，注释掉 NVBOARD_ARCHIVE：
$(BIN): $(VSRCS) $(CSRCS) $(EXTRA_SRC)
	@rm -rf $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_CFLAGS) $(MODE_VFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS) $(MODE_CXXFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

all: default

run: $(BIN)
	@$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	@$^ $(IMG)

# 单独编 emulator（脱离 RTL，调 sEMU 自己的 bug 用）。
# EMU_STANDALONE 是 hello.c 里 main 的开关：带上才有 main，不带就只有 emu_* 供 difftest 调。
emu:
	gcc -DEMU_STANDALONE -O2 -g -o $(abspath ./sEMU/sEMU) $(abspath ./sEMU/hello.c)

# 兼容 AM 的 npc.mk run（写死跑 $(NPC_HOME)/build/top）：
# 用法：make MODE=npc top   → 编独立版并复制成 build/top
ifeq ($(MODE), npc)
$(BUILD_DIR)/top: $(BIN)
	cp $(BIN) $(BUILD_DIR)/top
top: $(BUILD_DIR)/top
.PHONY: top
endif

clean:
	rm -rf $(BUILD_DIR)

.PHONY: default all clean run emu