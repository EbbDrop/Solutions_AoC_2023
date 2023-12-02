TOOLCHAIN = ../riscv/bin/riscv64-unknown-elf-
CC = $(TOOLCHAIN)gcc
AS = $(TOOLCHAIN)as
LD = $(TOOLCHAIN)ld
OBJCOPY = $(TOOLCHAIN)objcopy
OBJDUMP = $(TOOLCHAIN)objdump
GDB = gdb-multiarch

QEMU_USR = qemu-riscv32
QEMU_SYS = qemu-system-riscv32
