org 100h
include 'shell.asm'



;====================================================;
; DirPrintFileNS.                                    ;
;====================================================;
DirPrintFile:
	pusha				    ; Save genral regs
	push  ds			    ; Save DS
	push  es			    ; Save ES
	mov   [cs:RdirFileCount],0x9000     ; Move the address of root dir into [cs:RdirFileCount]
	xor   si,si			    ; 0 SI
FileNamePrintLoop: 
	xor   ax,ax			    ; 0 AX
	mov   ax,[cs:RdirFileCount]	    ; Move whats in [cs:RdirFileCount] into AX
	mov   ds,ax			    ; Move whats in AX into DS
	add   si,32			    ; Add 32 to the address
	cmp   byte [ds:si],0xe5 	    ; Check for deleted file
	je    FileNamePrintLoop 	    ; If = loop
	cmp   byte [ds:si],'A'		    ; Check for 'A'.
	je    FileNamePrintLoop 	    ; If = loop
	cmp   byte [ds:si],0x00 	    ; Check for 00
	je    DirSuccsess		    ; If = jume to exit
;====================================================;
; Print file/dir name.                               ;
;====================================================; 
	pusha				    ; Save genral regs
	mov   cx,8			    ; Mov count 8
FilePrintLoop:
	lodsb				    ; load a letter into AL
	 call print_char
      ;  call  chrout                        ; Print it
	loop  FilePrintLoop		    ; loop 8 times
	mov   al,0x20			    ; print a space
	call print_char
      ;  call  chrout
;====================================================;
; Print file exten.                                  ;
;====================================================;
	mov   cx,3			    ; Mov cx 3 for ext loop
FileExtenPrintLoop:
	lodsb				    ; Load al with letter
	call print_char
       ; call  chrout                        ; Print it
	loop  FileExtenPrintLoop	    ; Loop 3 times.
;====================================================;
; Print files size in bytes.                         ;
;====================================================;
	push  cs			    ; Move CS on stack
	pop   ds			    ; Move CS into DS
	mov   si,nextline		    ; Move the address of nextline in SI
	call print_string
       ; call  print                         ; Call print function
	popa				    ; Restore regs
	jmp   FileNamePrintLoop 	    ; Jump to label FileNamePrintLoop
DirSuccsess:
	pop   es			    ; Restore ES
	pop   ds			    ; Restore DS
	popa				    ; Restore general regs
	clc				    ; Do not set CF to 1
	ret				    ; Return

DirError:
	pop  es 			    ; Restore ES
	pop  ds 			    ; Restore DS
	popa				    ; Restore general regs
	stc				    ; Set CF to 1
	ret				    ; Return
 ;----------------------------------------------------;
 ; Convert File Name.                                 ;
 ;----------------------------------------------------;
ConvertFileName:
	pusha				    ; Save genral regs        
	push  es			    ; Save ES
	push  ds			    ; Save DS
 ;----------------------------------------------------;
 ; Convert command line Name to root name.            ;
 ;----------------------------------------------------;
	mov   si,cmd_buffer		; Move the address of CommandBuffer in SI
	mov   di,RootConvertedFileName	    ; Move the address of RootConvertedFileName in DI    
	mov   cx,8			    ; Move count 8
ConvertCliFileName:
	cmp   byte [ds:si],'.'		    ; Check for a '.'
	je    @f			    ; If = jump to label
	cld				    ; Make movs prosess from left to right.
	movsb				    ; Move what ds:si points to, to what es:di points to
	dec   cx			    ; Decreass counter.
	jnz   ConvertCliFileName	    ; If counter not 0, loop
	jmp   FinConertCliFname 	    ; If 0 jump label  
@@:
	mov   al,0x20			    ; Move  ' ' into AL 
	cld				    ; Make movs prosess from left to right.
	rep   stosb			    ; Move what in AL, to the address es:di points to
FinConertCliFname:
	cmp   byte [ds:si],'.'		    ; Check for a '.'
	jne   @f			    ; If not jump label
	inc   si			    ; If = add a byte to SI
@@:
	mov   cx,6			    ; Move 6 into count reg
	cld				    ; Make movs prosess from left to right.
	rep   movsb			    ; Move what ds:si points to, to what es:di points to
	mov   di,RootConvertedFileName	    ; Move the address of RootConvertedFileName in DI  
	add   di,8			    ; Point to the ext

	pop   ds			    ; Restore DS
	pop   es			    ; Restore ES
	popa				    ; Restore general regs
	clc				    ; Do not set CF to 1
	ret				    ; Return

;====================================================;
; Data.                                              ;
;====================================================;

LabelDir:  db "<Dir>",10,13,0
nextline:  db 10,13,0
RdirFileCount dw 0
RootConvertedFileName : times 12 db 0
count  db 0
count2 dw 0