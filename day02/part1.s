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

        call read_input     # a0 = bytes read

        la s2, input_buf    # cursor into input

        li s3, 0            # Result counter
main_loop:
        li s6, 1            # min red
        li s7, 1            # min green
        li s8, 1            # min blue
        lb t0, 0(s2)
        beq t0, zero, main_loop_end  # Exit on null byte
        addi s2, s2, 5      # Skip "Game "
        mv a0, s2
        call parse_int      # a0 = new_pointer, a1 = int
        mv s2, a0           # Move pointer
        mv s4, a1           # Game number
        mv a0, s4
        call print_int
        addi s2, s2, 2      # Skip ": "

game_loop:
draw_loop:
        mv a0, s2
        call parse_int      # a0 = new_pointer, a1 = int
        mv s2, a0           # Move pointer
        mv s5, a1           # Amount of cubes
        addi s2, s2, 1      # Skip " "
        lb t0, 0(s2)        # Read first letter of cube collor

        li t1, 'r'
        bne t0, t1, not_red_cube   # t0 != 'r'
red_cube:
        addi s2, s2, 3      # Skip "red"
        blt s5, s6, cubes_end # if amount of cubes in draw < amount of pos cubes of htis color: jump
        mv s6, s5
        j cubes_end
not_red_cube:
        li t1, 'g'
        bne t0, t1, blue_cube   # t0 != 'g'
green_cube:
        addi s2, s2, 5      # Skip "green"
        blt s5, s7, cubes_end # if amount of cubes in draw < amount of pos cubes of htis color: jump
        mv s7, s5
        j cubes_end
blue_cube:
        addi s2, s2, 4      # Skip "blue"
        blt s5, s8, cubes_end # if amount of cubes in draw < amount of pos cubes of htis color: jump
        mv s8, s5
cubes_end:

        lb t0, 0(s2)
        li t2, ','
        bne t0, t2, end_of_draw # not a ','
        addi s2, s2, 2      # Skip ", "

        j draw_loop
end_of_draw:
        li t2, ';'
        bne t0, t2, end_of_game # not a ';'
        addi s2, s2, 2      # Skip "; "
        j game_loop
end_of_game:
        mul s6, s6, s7
        mul s6, s6, s8     # power
        add s3, s3, s6     # add power to total

not_posible:
        addi s2, s2, 1      # Skip "\n"
        j main_loop

main_loop_end:
        mv a0, s3
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
        lb a0, 0(t2)         # load byte from input
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
        auipc t0, %pcrel_hi(input_buf+1)
        add t0, t0, t1
        sb zero, %pcrel_lo(read_input.0)(t0)

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
