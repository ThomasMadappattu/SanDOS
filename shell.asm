;#########################################################################################################
;#                                                                                                       #
;#  shell.asm                                                                                            #
;#   This implements the shell . This is a really simple shell .It  gets a string from the user          #
;#   and checks whether it is one  of the commands known to shell ,if it is one them it just calls       #
;#   the corresponding  functions , else it check that there exists an external file in the disk         #
;#   that has a same name as the input . If it exits , its  loaded and executed                          #
;#########################################################################################################






;-------------------------------------------------------------------------------+
; procedure shell_initialize                                                    |
;    performs various operations before starting the  shell  .                  |
;    (1) print the Sandman Logo :)                                              |
;                                                                               |
;-------------------------------------------------------------------------------+
shell_initialize:
		mov   [save_address],dx    
		mov   [cs_save],ax		   
		push  cs			    
		pop   ds			    
		push  ds			   
		pop   es			    
		cld				    

		mov si , initial_msg
		call print_string
		cli
		call install_interrupts
		sti
shell_loop:
	  call print_prompt
	  mov di , cmd_buffer
	  mov cx , 13
	  call read_string
	  mov di , cmd_buffer
	  call to_upper
	  mov si , cmd_buffer
	  mov di , cmd_cls
	  stc
	  call string_equal
	  jnc .do_cls

	  mov si , cmd_buffer
	  mov di , cmd_help
	  stc
	  call string_equal
	  jnc .do_help


	  mov si , cmd_buffer
	  mov di , cmd_dir
	  stc
	  call string_equal
	  jnc .do_dir

    .load_prog:

       call  ConvertFileName		   



       stc
       mov di ,  RootConvertedFileName
       add di , 8
       mov si , com_ext
       call string_equal
       jnc .file_extension_ok

       stc
       mov di ,  RootConvertedFileName
       add di , 8
       mov si , exe_ext
       call string_equal
       jnc .file_extension_ok


       jmp   shell_loop 		  
.file_extension_ok:

 
	mov   ax,0x80			 
	shl   ax, 6			   
	mov   word[end_memory],ax	    
	int   12h			   
	shl   ax,6			   
	mov   word[top_memory],ax

	sub   ax,512 / 16		   
	mov   es,ax			   
	sub   ax,2048 / 16		   
	mov   ss,ax			   
	mov   sp,2048			

	mov   cx, 11			
	mov   si, RootConvertedFileName
	mov   di,[save_address]
	rep   movsb			    

	push  es			    
	mov   bx,[cs_save]
	push  bx			    
	xor   bx,bx			    
	retf				    
	jmp    $



    .do_cls:
	  xor dx , dx
	  call set_cursor
	  call clear_screen
	  jmp shell_loop

    .do_help:
	  mov si , help_msg
	  call print_string
	  jmp shell_loop
    .do_dir:
	   call clear_screen
	   call DirPrintFile
	   jmp shell_loop

;--------------------------------------------------------------------------------+
;  procedure print_prompt :                                                      |
;     prints the prompt to the user .                                            |
;     input  : none                                                              |
;     output : prints the prompt                                                 |
;--------------------------------------------------------------------------------+
print_prompt:
	     mov si , prompt
	     call print_string
	     ret

cmd_cls     db	'CLS',0
cmd_help    db	'HELP',0
cmd_dir     db	'DIR',0
prompt	    db '$' ,0
cmd_buffer: times 14  db 0
com_ext    db 'COM',0
exe_ext    db 'EXE',0

initial_msg  db  'Welcome to 1K-DOS :) ',13,10, '             ^ ^ ^',13,10, '            ( *|* )',13,10, '            /  ~  \',13,10, '           /       \',13,10, '           ---------',13,10,'             |   |',13,10, '            _|  _|        by S@ndM@n ',13,10 ,0
help_msg db 13 , 10 ,'CLS - Clears  the Screen ' ,13 , 10 , 'HELP - Displays This Info ' , 13,10 , '<FILENAME> - Executes Given File' ,13 , 10,'DIR -List Contents of Root Directory' ,13 , 10, 0
save_address dw 0
cs_save 	dw 0

include 'util.asm'
