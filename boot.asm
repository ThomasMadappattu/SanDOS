; ##########################################################################
; #                                                                        #
; # boot.asm                                                               #
; #   This is the sandos bootloader , it searches for a kernel file in     #
; #   the root directory . It then loads it into memory and transfers      #
; #   control to the kernel                                                #
; ##########################################################################
use16

; FAT  constansts for 1.44 MB floppy drives , since other  drives
; are hardpressed  to find  , i am assuming that sandos will only
; use them

SECTORS_PER_TRACK  equ	18
TOTAL_HEADS	  equ  2
ROOT_DIR_ENTRIES  equ 224
; sandos only supports floppy drives , so the defalut drive is always A drive floppy
DEFAULT_DRIVE	  equ  0


;  the initial header that makes a floppy readle by an os that can read fat12

	jmp	short  bootloader_start
	nop
; The bpb table hardcoded for a 1.44 MB floppy drive
OEM_label		  db 'SANBOOTS'
bytes_per_sector	  dw 512
sectors_per_cluster	  db 1
reserved_for_boot	  dw 1
number_of_fats		  db 2
root_diriretory_entries   dw 224
logical_sectors 	  dw 2880
medium_byte		  db 0F0h
sectors_per_fat 	  dw 9
sectors_per_track	  dw 18
total_heads		  dw 2
hidden_sectors		  dd 0
large_sectors		  dd 0
drive_number		  dw 0
signature		  db 41
vol_id			  dd 00000000h
vol_label		  db 'SAN-DOS    '
fat_type		  db 'FAT12   '

bootloader_start:
    ;set up  the boot stack  , its just a random location  SS : SP - >  [99000]   as long as it does not interfere with the kernel
    cli
    mov ax , 0x9000
    mov ss , ax
    mov ax , 0x9000
    mov sp , ax
    sti

    ; set up the segment registers  , usually the firmware copies the
    ; 512 byte bootsector to 0x07C00  , so I set the segment registers
    ; that way
    mov ax , 0x07C0
    mov ds , ax
    mov es , ax

    ; now print the brilliant sandos booting message
    mov si , boot_msg
    call print_string

read_root_directory:
    ; now read the root directory into memory

    mov ax , 0x07C0
    mov cx , 0x03
    mov es , ax
    mov bx , buffer
    mov dx , 14
    mov ax ,19	 ; root directory starting logical block address
    stc
    call read_sector
    jnc done_reading_root_dir
    stc
    call reset_floppy
    jnc read_root_directory
    mov si , floppy_io_error
    call reboot_keypress
done_reading_root_dir:

    ; we are done reading the root directory  , now we should search for the kernel file in root directory
    mov dx , ROOT_DIR_ENTRIES
    mov di , buffer
find_kernel_file:
    mov si , kernel_file
    mov cx , 11
    rep cmpsb
    je found_kernel_file
    dec dx
    add di , 32
    jnz find_kernel_file

kernel_file_not_found:
    mov si , kernel_file
    call print_string
    mov si , not_found_msg
    call print_string
found_kernel_file:
    ;we have found the kernel file , now we should load the file into memory
    ;first we should read the fat-table into the buffer , use the first
    ;cluster to index into the fat table to find the next cluster ..etc and load
    ;the file into memory
    mov ax , word [es:di + 0Fh]
    mov word [cluster_save] , ax
    mov cx ,0x03
    mov ax , 1
    mov dx , 0x09
    mov bx , buffer
    stc
    call read_sector
    jnc done_reading_fat_table
    stc
    call reset_floppy
    jnc found_kernel_file
    mov si , floppy_io_error
    call reboot_keypress
done_reading_fat_table:
    ;we have read the fat table
    mov bx ,0x2000
    mov es ,bx
    mov ax , 31
    mov cx , 3
kernel_next_sector:
    mov bx , word [kernel_start_offset]
    mov dx , 1
    call read_sector
    jnc done_reading_kernel_sector
    call reset_floppy
    jmp done_reading_fat_table
done_reading_kernel_sector:
    mov ax  , word [cluster_save]
    call fat12_next_cluster
    mov word [cluster_save] , ax
    cmp ax ,0FF8h
    jae load_file
    add word [kernel_start_offset] ,32
    jmp kernel_next_sector
    ; done loading the kernel file into memory , now jump to 2000 : 0000
load_file:
    xor dx , dx
    jmp 2000:0000

;--------------------------------------------------------------------------------------+
; procedure fat12_next_cluster                                                         |
;   given a cluster number , get the next cluster number from the fat12 table          |
;   input ax = current cluster  , es : bx = fat table                                  |
;   output ax = next cluster number                                                    |
;   *note *:- assumes that the buffer contains the fat table                           |
;--------------------------------------------------------------------------------------+
fat12_next_cluster:
       xor dx , dx
       mov bx , 3
       mul bx
       mov bx , 2
       div bx
       mov si , buffer
       add si , ax
       mov ax , word [ds:si]
       or dx , dx
       jz even_clusterno
odd_clusterno:
       shr ax , 4
       jmp done_next_cluster
even_clusterno:
       and ax, 0x0FFF
done_next_cluster:
       ret

; -----------------------------------------------------------------------------------------+
;   procedure reboot_keypress                                                              |
;     prints the string pointed by si, waits for a keypress and then reboots the system,.  |
;     input : string to be printed in si                                                   |
;     output : waits for a key press and reboots the system                                |
;------------------------------------------------------------------------------------------+
reboot_keypress:
		call print_string
		xor ax ,ax
		int 0x16
		xor ax , ax
		jmp 0xffff:0000



;-----------------------------------------------------------------------------------------+
; procedure reset_floppy:                                                                 |
;   resets the floppy disk controller                                                     |
;   input : nothing                                                                       |
;   output : sets the carry flag in case of error                                         |
;-----------------------------------------------------------------------------------------+
reset_floppy:
	     stc	  ; set carry flag initially
	     xor ax ,  ax
	     xor dl , dl  ; boot device = floppy drive
	     int 0x13
	     ret

;-----------------------------------------------------------------------------------------+
;  procedure print_string:                                                                |
;  prints a string on the screen at the given cursor position                             |  
;  input : [ds : si ] := the string to be printed                                         |
;  output : prints the string at the current cursor position                              |
;-----------------------------------------------------------------------------------------+
print_string:

	    mov ah , 0x0e
	.print_string_loop:   
	    lodsb
	    or al , al
	    jz .done_print_string
	    mov bl , 0x07
	    mov bh , 0x00
	    int 0x10
	    jmp .print_string_loop 
	.done_print_string:
	    ret
     


;------------------------------------------------------------+
; procedure : lba_to_chs                                     |
; converts a logical block address to cylinder , head        |
; sector.                                                    |
; SECTOR   = (LBA % SECTOR_PER_TRACK )+ 1                    |
; HEAD     = ( LBA / SECTORS_PER_TRACK ) % TOTAL_HEADS       |
; CYLINDER = ( LBA / SECTORS_PER_TRACK ) / TOTAL_HEADS       |
;                                                            |
; input  : ax := logical block address                       |
; output : cx := sector , dx = head , ax=cylinder            |
;------------------------------------------------------------+
lba_to_chs:
	   mov bx ,  SECTORS_PER_TRACK
	   div bx
	   inc dx
	   mov cx  , dx
	   mov bx , TOTAL_HEADS
	   div bx
	   ret
;-----------------------------------------------------------+
; procedure read_sector                                     |
;    read number of sectors given into al register into     |
;    a buffer                                               |
;  input :                                                  |
;     ax : logical block address                            |
;     dx : = number of sectors                              |
;     ES : BX :=  address of the buffer                     |
;     cx : = number of tries                                |
;  output :                                                 |
;         contents of the sectors in [ES : BX ]             |
;         sets the carry flag on error                      |
;-----------------------------------------------------------+
read_sector:
	    push cx
	    push dx
	    call lba_to_chs
	    mov dh , dl
	    mov ch , al
	    mov ah , 0x02
	    pop dx
	    mov al , dl
	    xor dx , dx
	    int 13h
	    pop cx
	    dec cx
	    jc	read_sector
	    ret

boot_msg	    db 'Booting Sandos ....' , 0
floppy_io_error     db 'Error during floppy i/o ' , 0
not_found_msg	    db '   not found !'
kernel_file	    db 'SANDOS  BIN',0
cluster_save	    dw	0
retry		    db	0
kernel_start_offset dw 0
; padd the rest of the bytes with zero and put the boot signature , 8086 is little endian ,the magic boot signature is 55aa
boot_signature:
		times 510 -($-$$) db 0
		dw  0xaa55

; Buffer past  bootsector for storing root directory and fat table
buffer:

