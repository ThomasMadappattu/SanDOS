
org 100h
use16

;testing the print function
mov si , message1
call print_string

mov si , pass_message
call print_string

;testing the read char function  and print char function , first print the message
mov si , message2
call print_string


call read_char
call print_char

; testing the tab character output , you sould see a character after 8 spaces
mov al ,0x09
call print_char
mov al , 65
call print_char
mov si , message5
call print_string


;testing the string compare function
mov si , test_str_cmpr1
mov di , test_str_cmpr2
call string_equal
jnc skip1
mov si , message3
call print_string
jmp  skip2
skip1:
mov si , message4
call print_string
skip2:

; testing the read string function
mov cx , 0x0008
mov di , message6
call read_string
mov si , message6
call print_string

mov si , pause_msg
call print_string

; testing the to_upper function again
mov di, test_str_cmpr1
call to_upper
mov si, test_str_cmpr1
call print_string

;display the pause message and wait for key press
mov si , pause_msg
call print_string
call read_char

; testing the clear_screen function
;call clear_screen
mov es , SEG message6
call clear_screen

; testing the  set_cursor function

; exit to dos
  int 20h

message1      db ' < Utility Functions unit tests  > ',13,10 ,0
pass_message  db 'Test passed ' ,13, 10 , 0
message2      db 'If you see the alphabet you typed the test passes , else it fails ',13,10 , 0
pause_msg     db 13,10, 'Press any key to continue... ' , 13 ,10 , 0
message3      db 13,10,'String not equal',13,10,0
message4      db 13,10,'String equal',13,10,0
message5      db 13,10,' you sould see a character after 8 spaces',13,10,0
message6  :    times  9 db  0
test_str_cmpr1 db 'Hello',0
test_str_cmpr2 db 'Hello',0

include "util.asm"