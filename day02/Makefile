include ../tools.mk


SRCS = $(wildcard *.s)
OBJS = $(SRCS:.s=.o)
BINS = $(OBJS:.o=.bin)

.PHONY : build
build : $(BINS)

.PHONY : run-%
run-% : %.bin
	$(QEMU_USR) $<

# %.o : %.s
# 	$(AS) -march=rv32i -g -o $@ $^

# %.bin : %.o
# 	$(LD) -e main -o $@ $^

%.bin : %.s
	$(CC) -march=rv32im -mabi=ilp32 -nostdlib -static -g -o $@ $^

.PHONY : debug-%
debug-% : %.bin
	$(QEMU_USR) -g 1234 -d exec $<

.PHONY : gdb-%
gdb-% : %.bin
	$(GDB) -q -ex 'target remote :1234' $<

.PHONY : clean
clean :
	find . \( -name '*.o' -or -name '*.d' -or -name '*.elf' \
	           -or -name '*.so' -or -name '*.bin' -or -name '*.img' \
	       \) -delete
