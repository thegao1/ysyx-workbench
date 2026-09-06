.PHONY: sim clean

CSRC := $(wildcard csrc/*.cpp)
VSRC := $(wildcard vsrc/*.v)

sim: $(CSRC) $(VSRC)
	rm -rf obj_dir
	verilator -Wall -Wno-fatal --cc $(VSRC) --exe $(CSRC)
	make -C obj_dir -f Vtop.mk
	./obj_dir/Vtop
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!

clean :
	rm -rf obj_dir

include ../Makefile