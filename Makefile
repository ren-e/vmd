# Makefile for vmctl

SIGN   = codesign
CC     = clang
PROG   = vmctl
OBJS   = main.o compat/reallocarray.o compat/fmt_scaled.o \
	 vm.o vmd.o config.o
CFLAGS = -mtune=native -O2 -Wall
FFLAGS = -framework Foundation -framework Virtualization


all:	vmctl sign

vmctl:	$(OBJS)
	$(CC) $(CFLAGS) $(FFLAGS) -o $@ $^

sign:	vmctl
	$(SIGN) --entitlements hypervisor.entitlements --force -s - $<

clean:
	rm -f *.o compat/*.o vmctl
