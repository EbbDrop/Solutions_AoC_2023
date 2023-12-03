MAX_INPUT_FILESZ = 0x100000  # 1MB

        .data
msg_open_failed:
        .ascii "Opening input failed.\n"
        .set msg_open_failed_len, . - msg_open_failed
msg_read_failed:
        .ascii "Reading input failed.\n"
        .set msg_read_failed_len, . - msg_read_failed
msg_newline:
        .ascii "\n"
        .set msg_newline_len, . - msg_newline

        .bss
input_buf:
        .space  MAX_INPUT_FILESZ + 1


# Used to store the indecies of the numbers in the input.
# in the format: [value][index1][index2][index3][ -1 ][next value]....
# where every value is a word big
scratch:
        .space  0x10000

# Array of the positions of the symbols
symbols:
        .space  0x10000
# Buffer to store the indexes to search
positions:
        .space  8 * 4

        .text
        .globl _start
_start:
        .option push
        .option norelax
        lla gp, __global_pointer$
        .option pop

        call main

        # exit(0)
        li a0, 0        # error code 0 means success
        li a7, 93       # syscall nr. for exit
        ecall

_start_loop:      
        j _start_loop


        .globl main
        .type main, @function
main:
        addi sp, sp, -44
        sw s8, 40(sp)
        sw s7, 36(sp)
        sw s6, 32(sp)
        sw s5, 28(sp)
        sw s4, 24(sp)
        sw s3, 20(sp)
        sw s2, 16(sp)
        sw ra, 12(sp)
        sw s1, 8(sp)
        sw s0, 4(sp)

        li s0, 0            # Result counter

        call read_input     # a0 = bytes read

        la s1, input_buf    # cursor into input
        la s2, scratch      # cursor into scratch
        la s5, symbols      # cursor into symbols

        mv a0, s1           # Print input address
        call print_int
        mv a0, s2           # Print scratch address
        call print_int
        mv a0, s5           # Print symbols address
        call print_int

        ### PARSING

parse_loop:
        lbu t0, 0(s1)       # load char
        li t1, '\n'
        bne t0, t1, parse_not_new_line
        addi s1, s1, 1      # skip new line

        lbu t0, 0(s1)       # load char
        beq t0, zero, parse_end    # exit on null

        mv s4, s1           # Save start of this line (used to get line length)
parse_not_new_line:

        lbu a0, 0(s1)
        call parse_digit    # a0 = -1 if not a digit
        bge a0, zero, parse_new_number
        # not number not new line => check if symbol
        lbu t0, 0(s1)       # load char
        li t1, '.'
        beq t0, t1, parse_not_symbol
        sw s1, 0(s5)        # Store symbol position
        addi s5, s5, 4      # move symbols cursor

parse_not_symbol:
        addi s1, s1, 1      # next byte
        j parse_loop
parse_new_number:
        mv a0, s1

        mv s3, s1            # Save old position
        mv a0, s1
        call parse_int       # a0 = new_ptr, a1 = int
        mv s1, a0            # update ptr

        sw zero, 0(s2)       # write 0 to scratch, to be used for flags
        sw a1, 4(s2)         # write value to scratch
        addi s2, s2, 8       # move scratch ptr

parse_save_indexes:
        sw s3, 0(s2)         # write index
        addi s2, s2, 4       # move scratch ptr
        addi s3, s3, 1       # next index
        blt s3, s1, parse_save_indexes   # not reached last index yet

        li t0, -1
        sw t0, 0(s2)         # Save -1 for end of indexes
        addi s2, s2, 4       # move scratch ptr
        j parse_loop

parse_end:
        li t0, -1
        sw t0, 0(s2)         # Save -1 for end of scratch

        sub s4, s1, s4       # s4 = pos - begin of line; s4 = length of line

        la s5, symbols       # cursor into symbols

## Loking for part numbers

symbol_loop:
        lw t0, 0(s5)         # symbol position
        beq t0, zero, symbol_loop_end
        addi s5, s5, 4

        la t3, positions
        addi t1, t0, -1
        sw t1, 0(t3)
        addi t1, t0, 1
        sw t1, 4(t3)
        add t1, t0, s4
        sw t1, 8(t3)
        addi t1, t1, -1
        sw t1, 12(t3)
        addi t1, t1, 2
        sw t1, 16(t3)
        sub t1, t0, s4
        sw t1, 20(t3)
        addi t1, t1, -1
        sw t1, 24(t3)
        addi t1, t1, 2
        sw t1, 28(t3)

        li t0, 0
position_loop:
        la t1, positions
        add t1, t1, t0
        lw t1, 0(t1)         # load to search positon

# marks all the symbols that have a index == t1
        la s2, scratch       # cursor into scratch
number_loop:
        lw t5, 0(s2)         # the flags
        blt t5, zero, number_loop_end    # end of number when flags is -1
        mv t6, s2            # save flags position
        addi s2, s2, 8       # move scratch passed flags and value
indexes_loop:
        lw t3, 0(s2)
        addi s2, s2, 4       # move scratch passed index
        blt t3, zero, indexes_loop_end    # end of indexes when index is -1
        sub t4, t3, t1       # t4 = index - to look for index
        seqz t4, t4          # t4 = 1 if index is the to look for index

        or t5, t5, t4        # flags = old flags | is the to loof for index
        j indexes_loop

indexes_loop_end:
        sw t5, 0(t6)         # store new flags
        j number_loop

number_loop_end:
        addi t0, t0, 4       # next position in array
        li a0, 32
        blt t0, a0, position_loop
        j symbol_loop        # next symbol
symbol_loop_end:
        # all part nubmer have now been marked: add all values

## sum all part numbers

        li s0, 0

        la s2, scratch       # cursor into scratch
number_loop2:
        lw t5, 0(s2)         # the flags

        mv a0, t5
        call print_int

        addi s2, s2, 8       # move scratch passed flags and value
        blt t5, zero, number_loop2_end    # end of number when flags is -1
        bge zero, t5, indexes_loop2       # when not marked jump to index loop
        # This index is marked
        lw t5, -4(s2)         # the value

        add s0, s0, t5

indexes_loop2:               # loop to skip to -1
        lw t3, 0(s2)
        addi s2, s2, 4       # move scratch passed index
        blt t3, zero, number_loop2    # end of indexes when index is -1
        j indexes_loop2

number_loop2_end:
        
        mv a0, s0           # Print result
        call print_int

main.return:
        lw s0, 4(sp)
        lw s1, 8(sp)
        lw ra, 12(sp)
        lw s2, 16(sp)
        lw s3, 20(sp)
        lw s4, 24(sp)
        lw s5, 28(sp)
        lw s6, 32(sp)
        lw s7, 36(sp)
        lw s8, 40(sp)
        addi sp, sp, 44
        ret



################################################################################
# Parse a single decimal ASCII number to an integer, stops on first non digit char
#
# INPUT
#   a0: pointer into string
#
# OUTPUT
#   a0: pointer to first char passed number
#   a1: the read interger
################################################################################
        .type parse_int, @function
parse_int:
        mv t5, ra
        mv t2, a0
        mv t3, zero
        li t4, 10
parse_int_loop:
        lbu a0, 0(t2)        # load byte from input
        ## WARN: Relies on that parse_digit does not use t2 or higher
        call parse_digit     # a0 =  digit or -1
        blt a0, zero, parse_int_exit
        mul t3, t3, t4       # t3 *= 10
        add t3, t3, a0       # t3 += char
        addi t2, t2, 1
        j parse_int_loop
parse_int_exit:
        mv a0, t2
        mv a1, t3
        mv ra, t5
        ret


################################################################################
# Parse a single decimal ASCII digit to an integer
#
# INPUT
#   a0: ASCII character (byte)
#
# OUTPUT
#   a0: the integer value corresponding to a0 it it is a decimal digit,
#       -1 otherwise
################################################################################
        .type parse_digit, @function
parse_digit:
        ## if (a0 - '0' < 10u) { return a0 - '0' }
        addi a0, a0, -'0'
        sltiu t1, a0, 10
        bne t1, zero, parse_digit.1
        ## else { return -1 }
        li a0, -1
parse_digit.1:      
        ret


################################################################################
# Write a nonnegative integer to stdout, followed by a newline
#
# INPUT
#   a0: integer to print
################################################################################
        .type print_int, @function
print_int:
        mv t2, sp  # store original $sp in $t2

        # Extract digits and push to stack in reverse order.
        li t0, 10
print_int.1:
        remu t1, a0, t0  # t1 := a0 % 10
        addi t1, t1, '0'
        addi sp, sp, -1
        sb t1, 0(sp)
        divu a0, a0, t0  # a0 := a0 // 10
        bne a0, zero, print_int.1

        # write(stdout, msg, msg_len)
        li a0, 1        # file descriptor of stdout
        mv a1, sp       # buffer address
        sub a2, t2, sp  # nr of bytes to write
        li a7, 64       # syscall nr for write
        ecall

        mv sp, t2

        # write(stdout, msg_newline, msg_open_newline_len)
        li a0, 1                # file descriptor of stdout
        la a1, msg_newline      # buffer address
        li a2, msg_newline_len  # nr of bytes to write
        li a7, 64               # syscall nr for write
        ecall

        ret


################################################################################
# Print a string to stdout. followd by a new line
#
# INPUT
#   a0: ptr to string
#   a1: length
################################################################################
        .type println, @function
println:
        mv a2, a1               # nr of bytes to write
        mv a1, a0               # buffer addres
        li a0, 1                # file descriptor of stdout
        li a7, 64               # syscall nr for write
        ecall
        li a0, 1                # file descriptor of stdout
        la a1, msg_newline      # buffer address
        li a2, msg_newline_len  # nr of bytes to write
        li a7, 64               # syscall nr for write
        ecall
        ret

################################################################################
# Read the stdin to input_buf and return the number of bytes read
#
# Assumes that the input is no longer than MAX_INPUT_FILESZ, and that it
# only contains non-null ASCII characters.
#
# A single null byte is appended to input_buf after the file content.
# This null byte is not counted for the returned size.
#
# OUTPUT
#   a0: nr of bytes read, or a negative number on error
################################################################################
        .type read_input, @function
read_input:

        # read(fd, input_buf, MAX_INPUT_FILESZ)
        li a0, 0                 # file descriptor (stdin)
        la a1, input_buf         # void *buf = buf
        li a2, MAX_INPUT_FILESZ  # size_t count = count
        li a7, 63                # syscall nr for read
        ecall
        # a0 is an error value if -4095 <= a0 <= -1
        li t1, -4095
        bgeu a0, t1, read_input.read_failed

        mv t1, a0  # t1 := nr of bytes read

        # Write single null byte after the read contents
read_input.0:
        # auipc t0, %pcrel_hi(input_buf+1)
        # add t0, t0, t1
        # sb zero, %pcrel_lo(read_input.0)(t0)

        mv a0, t1  # return nr of bytes read
        j read_input.return

read_input.open_failed:
        # write(stdout, msg_open_failed, msg_open_failed_len)
        li a0, 1                    # file descriptor of stdout
        la a1, msg_open_failed      # buffer address
        li a2, msg_open_failed_len  # nr of bytes to write
        li a7, 64                   # syscall nr for write
        ecall

        li a0, -1  # return -1
        j read_input.return

read_input.read_failed:
        # write(stdout, msg_read_failed, msg_read_failed_len)
        li a0, 1                    # file descriptor of stdout
        la a1, msg_read_failed      # buffer address
        li a2, msg_read_failed_len  # nr of bytes to write
        li a7, 64                   # syscall nr for write
        ecall

        li a0, -1  # return -1
        # fall through to read_input.return

read_input.return:
        ret
