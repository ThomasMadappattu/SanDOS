; #######################################################################################################
; # util .asm                                                                                           #
; # This file mainly contains  utility functions used by the Sandos operating system.These functions    #
; # are mainly a wrapper around the services provied by the bios                                        #
; #######################################################################################################
;

;  MACROS and CONSTANS

; FAT  constansts for 1.44 MB floppy drives , since other  drives
; are hardpressed  to find  , i am assuming that sandos will only
; use them

SECTORS_PER_TRACK equ  18
TOTAL_HEADS	  equ  2
; sandos only supports floppy drives , so the defalut drive is always A drive floppy
DEFAULT_DRIVE	  equ  0

; ------------------------------------------------------------------------------------+
;  procedure read_char                                                                |
;  description : reads a character from the keyboard using the bios functions.        |
; ------------------------------------------------------------------------------------+
read_char:

	   xor ax , ax 
	   int 16h
	   ret
; ------------------------------------------------------------------------------------+
;  procedure set_cursor :                                                             |
;  set the cursor at the required position                                            |
;  input  : dh = row  , dl = col                                                      |
;  output : the cursor at the required position                                       |
; ------------------------------------------------------------------------------------+
set_cursor:
	    mov ah , 0x02
	    mov bh , 0x00
	    int 0x10
	    ret


;--------------------------------------------------------------------------------------+
;  procedure clear_screen:                                                             |
;  clears the screen                                                                   |
;  input : none                                                                        |
;  output : clears the screen                                                          |
;--------------------------------------------------------------------------------------+

clear_screen:
		mov ax , 0x0600
		mov bh , 0x07
		mov cx , 0x0000
		mov dx , 0x184f
		int 0x10
		ret

;----------------------------------------------------------------------------------------+
; procedure print_char:                                                                  |
; prints a character on the screen.                                                      | 
; input : al = character to be printed                                                   |
; output : prints the character at the current cursor                                    |
;----------------------------------------------------------------------------------------+
print_char:
		pusha 
		cmp al ,0x09
		je .print_tab
		mov bl , 0x07 
		mov bh , 0x00
		mov ah , 0x0e
		int 0x10
		popa
		ret
       .print_tab:

		mov al , ' '
		mov cl , 0x08
	.tab_loop:
		call print_char
		dec cl
		jnz .tab_loop
		popa
		ret


;-----------------------------------------------------------------------------------------+
;  procedure print_string:                                                                |
;  prints a string on the screen at the given cursor position                             |  
;  input : [es : si ] := the string to be printed                                         |  
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
; procedure string_equal:                                    |
; compares two string , clears carry flag if equal and sets  |
; carry flag if it is equal , difference between string in AL|
; input : source string in si  , destination string in di    |
; output: if equal carry flag = 0 else carry flag =1         |
;------------------------------------------------------------+

string_equal:
     .string_equal_loop:
	     mov al, [si]
	     mov bl, [di]
	     cmp al , bl
	     jne .string_not_equal

	     cmp al,0
	     je .string_equal

	     inc di
	     inc si
	     sub al , bl
	     jmp .string_equal_loop

      .string_not_equal:
	     stc
	     ret
      .string_equal:
	     clc
	     ret

;----------------------------------------------------------------+
; procedure read_string                                          |
; reads the character from the key board stores it in a buffer   |
; and stops reading from keyboard is if enter is pressed         |
; limited by  cx , the number of characters entered              |
; input : di := buffer to get  ,cx = max no of characters        |
; output : inputted string in the buffer , dx = length of string |
;----------------------------------------------------------------+

read_string:
		 xor dx,dx
      .input_loop:
		 call read_char
		 call print_char

		 ; enter pressed ? then we are done
		 cmp al ,0x0D
		 je .done_reading

		 ;backspace  pressed ? decrement counters etc
		 cmp al , 0x08
		 je .backspace_pressed
		 inc dx
		 stosb
		 dec cx
		 jz .max_reached
		 jmp .input_loop

       .backspace_pressed:
		 cmp dx ,0
		 je .input_loop
		 dec dx
		 dec di
		 inc cx
		 mov byte [di] , 0
		 jmp .input_loop
       .max_reached:
		 mov al , 13
		 call print_char
       .done_reading:
		 mov byte [di],0
		 ; print line feed
		 mov al , 10
		 call print_char
		 ret
;----------------------------------------------------------+
; procedure to_upper :                                     |
;   converts a null terminated string into upper case .    |
;   input :  null terminated string in di                  |
;   output: the string converted to upper case             |
;----------------------------------------------------------+
to_upper:
	  mov al ,[di]
	  cmp al , 0
	  je .done_to_upper
	  cmp al , 'a'
	  jb .donot_make_upper
	  cmp al , 'z'
	  ja .donot_make_upper
     .make_upper:
	  add al , 'A' - 'a'
	  mov [di] , al
     .donot_make_upper:
	  inc di
	  jmp to_upper
     .done_to_upper:
	  ret
;--------------------------------------------------------+
; procedure string_length                                |
;   finds the length of a string                         |
; input : si := input string                             |
; output: ax lenght of the string                        |
;                                                        |
;--------------------------------------------------------+
string_length:
	  xor ax , ax
	  cmp byte [si] , 0
	  je .end_string_length
	  inc ax
	  inc si
   .end_string_length:
	  ret

