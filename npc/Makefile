.PHONY: sim clean

CSRC := $(wildcard csrc/*.cpp)
VSRC := $(wildcard vsrc/*.v)

sim: $(CSRC) $(VSRC)
	rm -rf obj_dir
	verilator -Wall -Wno-fatal --trace --cc $(VSRC) --exe $(CSRC)
	make -C obj_dir -f Vtop.mk
	./obj_dir/Vtop
	vcd2fst -v wave.vcd -f wave.fst
	gtkwave wave.fst
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!

clean :
	rm -rf obj_dir

include ../Makefile