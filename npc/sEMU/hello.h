int  emu_init(const char *path);
int  emu_getpc();
int  emu_getinst();
int  emu_getgpr(int idx);
void emu_step();
int  emu_halted();
