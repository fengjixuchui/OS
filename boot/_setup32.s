# 1 "boot/setup32.S"
# 1 "<built-in>"
# 1 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3 4
# 1 "<command-line>" 2
# 1 "boot/setup32.S"
# 1 "include/asm/boot.h" 1
# 2 "boot/setup32.S" 2
# 1 "include/asm/x86.h" 1
# 3 "boot/setup32.S" 2



.code16

.section .text
.global _start

_start:
 mov %cs, %ax
 mov %ax, %ds
 mov %ax, %es
 mov $0xfff0, %sp #SS:SP = 0x9000:ff00

    movw $lod_str, %bp
    movw $LOD_STR_LEN, %cx
    movw $0x1301, %ax
    movw $0x000c, %bx
    movw $0x0100, %dx
    int $0x10


 xor %ebx, %ebx

 mov $0x9000, %ax
 mov %ax, %es

 movb %es:0x0D, %al
 movb %al, clus_per_sector

 movl %es:0x2C, %eax
 movl %eax, start_clus

 xor %ecx, %ecx
 movw %es:0x0e, %cx
 movw %cx, fat_start_sector

 movl %es:0x24, %eax
 movl %eax, fat_sector

 movb %es:0x10, %bl

 mul %ebx

 addl %ecx, %eax

 movl %eax, data_start_sector


 cli

 in $0x92, %al
 or $0x2, %al
 out %al, $0x92


 xor %eax, %eax
 movw %ds, %ax
 shl $4, %eax
 movl $tmp_gdt, %ebx
 add %ebx, %eax
 movw $tmp_gdt_ptr, %bx
 movl %eax, 2(%bx)

 lgdt (%bx)



 movl %cr0, %eax
 or $1, %eax
 movl %eax, %cr0


 movw $SELECTOR_DATA32, %ax
 movw %ax, %fs

 movl %cr0, %eax
 and $0xfe, %al
 movl %eax, %cr0

 sti

 movl fat_sector, %ecx
 xor %edx, %edx

 movw data_start_sector, %ax
 movzx %ax, %eax

 movw $0x1000, %bx
 movw %bx, %es

read_dir:
 pushw $1
 pushw $0
 pushw $0x1000
 pushl %eax
 pushl %edx
 call read_disk
 xor %edi, %edi
 add $14, %sp
 cld
find_kernel:
 pushw %cx
 pushw %di

 movw $kernel_file_name, %si
 movw $KERNEL_FILE_NAME_LEN, %cx

 repz cmpsb

 popw %di

 jz has_kernel

 add $0x20, %di
 popw %cx

 cmp $512, %di
 jne find_kernel

 clc
 add $1, %eax
 adc $0, %edx

 loop read_dir

 cmp $0, %cx
 je no_kernel

has_kernel:
 movw %es:20(%di), %ax
 shl $16, %ax
 movw %es:26(%di), %ax

 movw $0x1000, %cx
 movw %cx, %es

read_kernel:
 cmp $0x0fffffff, %eax
 je read_ok

 movl %eax, %ebx

 movl %eax, %esi

 shr $7, %ebx
 and $((1 << 7)-1), %esi

 movw fat_start_sector, %di
 movzx %di, %edi
 add %edi, %ebx

 pushw $1
 pushw $0
 pushw $0x7c0
 pushl %ebx
 pushl $0
 call read_disk
 add $14, %sp

 subl start_clus, %eax
 xor %ecx, %ecx
 movb clus_per_sector, %cl
 mul %ecx

 clc

 add data_start_sector, %eax
 adc $0, %edx

 pushw %cx
 pushw $0
 pushw %es
 pushl %eax
 pushl %edx
 call read_disk
 add $14, %sp

 add %ecx, kernel_sector_size

 movw %es, %ax
 movb clus_per_sector, %bl
 movzx %bl, %bx

 shl $5, %bx

 addw %bx, %ax
 movw %ax, %es

 pushw %ds
 shl $2, %esi
 movw $0x7c0, %ax
 movw %ax, %ds
 movl %ds:(%si), %eax
 popw %ds

 jmp read_kernel

read_ok:
 xorl %ecx, %ecx
 movl (kernel_sector_size), %ecx
 shl $7, %ecx
 mov $0x100000, %edi
 xor %esi, %esi
 mov $0x1000, %ax
 mov %ax, %es
move_kernel:
 movl %es:(%si), %eax
 movl %eax, %fs:(%edi)
 add $4, %esi
 add $4, %edi

 cmpl $0x10000, %esi
 je reset_es
 jmp continue_move
reset_es:
 movw %es, %si
 addw $0x1000, %si
 movw %si, %es
 xorl %esi, %esi

continue_move:
 loop move_kernel

 movw %cs, %ax
 movw %ax, %es
    movw $has_kernel_str, %bp
    movw $HAS_KERNEL_STR_LEN, %cx
    movw $0x1301, %ax
    movw $0x000c, %bx
    movw $0x0200, %dx
    int $0x10

 movw $0x7e0, %ax
 movw %ax, %es
 xor %edi, %edi
 xor %ebx, %ebx

get_mem_info_struct:
 movl $0xe820, %eax
 movl $20, %ecx
 movl $0x534d4150, %edx
 int $0x15
 jc get_mem_info_fail
 add $20, %di
 cmpl $0, %ebx
 jne get_mem_info_struct
 jmp get_mem_info_ok

get_mem_info_fail:
 movw %cs, %ax
 movw %ax, %es
    movw $mem_info_fail_str, %bp
    movw $MEM_INFO_FAIL_STR, %cx
    movw $0x1301, %ax
    movw $0x000c, %bx
    movw $0x0300, %dx
    int $0x10

get_mem_info_ok:
 movw %cs, %ax
 movw %ax, %es
    movw $mem_info_ok_str, %bp
    movw $MEM_INFO_OK_STR, %cx
    movw $0x1301, %ax
    movw $0x000c, %bx
    movw $0x0300, %dx
    int $0x10

get_vbe_info:
 mov $0x800, %ax
 mov %ax, %es
 xor %di, %di
 mov $0x4f00, %ax
 int $0x10

 cmpw $0x4f, %ax
 je get_vbe_info_success

get_vbe_info_fail:
 movw %cs, %ax
 movw %ax, %es
    movw $vbe_info_fail_str, %bp
    movw $VBE_STR_FAIL_LEN, %cx
    movw $0x1301, %ax
    movw $0x000c, %bx
    movw $0x0400, %dx
    int $0x10

get_vbe_info_success:
 movw %cs, %ax
 movw %ax, %es
    movw $vbe_info_ok_str, %bp
    movw $VBE_STR_OK_LEN, %cx
    movw $0x1301, %ax
    movw $0x000c, %bx
    movw $0x0400, %dx
    int $0x10

get_svga_mode_info:
 xorl %edi, %edi
 movw $0x143, %cx
 movw $0x820, %ax
 movw %ax, %es
 movw $0x4f01, %ax
 int $0x10

get_mode_finish:

 movw $0x4f02, %ax

 movw $0x4143, %bx






 int $0x10

 cmp $0x4f, %ax
 jnz exit


 mov %cs, %ax
 mov %ax, %ds

 cli

 movw $tmp_gdt_ptr, %bx
 lgdt (%bx)

 mov %cr0 ,%eax
 or $1, %eax
 mov %eax, %cr0

 ljmpl $0x08, $0x91000


no_kernel:
 mov %cs, %ax
 mov %ax, %es
    movw $no_kernel_str, %bp
    movw $NO_KERNEL_STR_LEN, %cx
    movw $0x1301, %ax
    movw $0x000c, %bx
    movw $0x0200, %dx
    int $0x10
exit:
    jmp .

read_disk:
 push %bp
 mov %sp, %bp

 push %eax
 push %si

 mov $disk_addr_pkg, %si
 xor %eax, %eax
 movl %ss:4(%bp), %eax
 movl %eax, %ds:12(%si)

 movl %ss:8(%bp), %eax
 movl %eax, %ds:8(%si)

 movw %ss:12(%bp), %ax
 movw %ax, %ds:6(%si)

 movw %ss:14(%bp), %ax
 movw %ax, %ds:4(%si)

 movw %ss:16(%bp), %ax
 movb %al, %ds:2(%si)

 movb $0x42, %ah
 movb $0x80, %dl
 int $0x13

 pop %si
 pop %eax
 pop %bp
 ret

.section .data
 data_start_sector:
  .long 0
 fat_start_sector:
  .word 0
 fat_sector:
  .long 0
 start_clus:
  .long 0
 clus_per_sector:
  .byte 0

 lod_str:
  .ascii "setup......!!"

 .equ LOD_STR_LEN, .- lod_str

 disk_addr_pkg:
  .byte 0x10
  .byte 0
  .byte 0
  .byte 0
  .word 0
  .word 0
  .long 0
  .long 0

 kernel_file_name:
  .ascii "KERNEL  BIN"
  .equ KERNEL_FILE_NAME_LEN, . - kernel_file_name

 has_kernel_str:
  .ascii "Has Kernel!"
  .equ HAS_KERNEL_STR_LEN, . - has_kernel_str

 no_kernel_str:
  .ascii "no Kernel!"
  .equ NO_KERNEL_STR_LEN, . - no_kernel_str

 kernel_sector_size:
  .long 0

 mem_info_fail_str:
  .ascii "get memory information fail!"
  .equ MEM_INFO_FAIL_STR, . - mem_info_fail_str

 mem_info_ok_str:
  .ascii "get memory information success!"
  .equ MEM_INFO_OK_STR, . - mem_info_ok_str

 vbe_info_ok_str:
  .ascii "get vbe info success!"
  .equ VBE_STR_OK_LEN, . - vbe_info_ok_str

 vbe_info_fail_str:
  .ascii "get vbe info fail!"
  .equ VBE_STR_FAIL_LEN, . - vbe_info_fail_str
#end of data

.section .gdt32
tmp_gdt:
 .quad 0
desc_code32:
 .quad 0x00cf9a000000ffff
desc_data32:
 .quad 0x00cf92000000ffff

.equ TMP_GDT_LEN, . - tmp_gdt

.equ SELECTOR_CODE32, desc_code32 - tmp_gdt
.equ SELECTOR_DATA32, desc_data32 - tmp_gdt

tmp_gdt_ptr:
 .word TMP_GDT_LEN - 1
 .long (0x90200 + tmp_gdt)
# end of gdt32

.section .idt
tmp_idt:
 .fill 0x50, 8, 0
 .equ IDT_LEN, . - tmp_idt

tmp_idt_ptr:
 .word IDT_LEN - 1
 .long 0
