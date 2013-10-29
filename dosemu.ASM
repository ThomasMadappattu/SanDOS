;#######################################################################
;#                                                                     #
;#  dosemu.asm  : This file installs and simulates the int21 handler   #
;# .This  mainly provides for dos emulation                            #
;#                                                                     #
;#######################################################################

include 'fat122.asm'

;----------------------------------------------------------------------+
; procedure install_interrupts :                                       | 
;     The main goal of this procedure is to initialize the real mode   |
;     intterrupt table . The real mode interrupt table is initialized  |
;     as follows [0000 : int_no * 4 ] := handler offset address and    | 
;                [0000 : int_no *4 +2 ] := handler segment address .   | 
;                                                                      |
;     input   : none                                                   |
;     output  : sets the real mode interrupt table                     |
;----------------------------------------------------------------------+ 

install_interrupts:
		    push   ax
		    push   es
		    cli
		    xor    ax ,  ax
		    mov    es ,  ax
		    ; install the int20 interrupt handler
		    mov    WORD   [es : 0x20 *4] , int20_handler
		    mov    WORD   [es : 0x20 * 4 + 2] , cs
		    ; install the int21 interrupt handler
		    mov    WORD   [es : 0x21 *4 ] ,int21_handler
		    mov    WORD   [es : 0x21 *4 + 2],cs
		    sti
		    pop es
		    pop ax
		    ret




int20_handler:
		  je shell_loop
		  iret


int21_handler:

;====================================================;
;  int 21H: DOS emulation                            ;
;====================================================; 
int21:
	sti				   ; Int's on
	cmp   ah,0			   ; Does AH = 0 
	je    int21_00			   ; Terminate program
	cmp   ah,1			   ; Does AH = 1
	je    int21_01			   ; Read char with echo
	cmp   ah,2			   ; Does AH = 2
	je    int21_02			   ; Write char
	cmp   ah,6			   ; Does AH = 6   (Added by asiekierka)
	je    int21_06			   ; Direct console output
	cmp   ah,7			   ; Does AH = 7
	je    int21_07			   ; Read char without echo
	cmp   ah,8			   ; Does AH = 8
	je    int21_07			   ; Read char
	cmp   ah,9			   ; Does AH = 9
	je    int21_09			   ; Write string
	cmp   ah,0Ah			   ; Does AH = 0x0A
	je    int21_0A			   ; Enter string
	cmp   ah,19h			   ; Does AH = 0x19
	je    int21_19			   ; Current drive
	cmp   ah,25h			   ; Does AH = 0x25
	je    int21_25			   ; Set int vec
	cmp   ah,2Ah			   ; Does AH = 0x2A
	je    int21_2A			   ; Get date
	cmp   ah,2Bh			   ; Does AH = 0x2B
	je    int21_2B			   ; Set date
	cmp   ah,2Ch			   ; Does AH = 0x2C
	je    int21_2C			   ; Get time
	cmp   ah,2Dh			   ; Does AH = 0x2D
	je    int21_2D			   ; Set time
	cmp   ah,30h			   ; Does AH = 0x30
	je    int21_30			   ; Get dos version
	cmp   ah,35h			   ; Does AH = 0x35
	je    int21_35			   ; Get int vec
	cmp   ah,48h			   ; Does AH = 0x48
	je    int21_48			   ; Alloc ram memory
	cmp   ah,4Ch			   ; Does AH = 0x4C
	je    int21_4C			   ; Terminate program
	jmp int21_error
;====================================================;
;  terminate program                                 ;
;====================================================; 
int21_00:
	jmp   shell_loop		       ; Jump to int20 label
;====================================================;
;  read character with echo                          ;
;====================================================; 
int21_01:
	xor   ax,ax			   ; 0 AX
	int   16h			   ; Call BIOS function.
	call  print_char		       ; Call our char function
	jmp   int21_exit		   ; Jump to int21_exit label
;====================================================;
;  write character                                   ;
;====================================================; 
int21_02:
; asiekierka - AL is preserved (at least in DOS 2.10+)
	push  ax			   ; Save AX
	mov   al,dl			   ; Put whats in dl into al
	call  print_char		      ; Call our char function
	pop   ax			   ; Restore AX
	mov   al,dl			   ; Re-move, push AH dosen't want to work :O
	jmp   int21_exit		   ; Jump to int21_exit label
;====================================================;
;  direct console output                             ;
;====================================================;
int21_06:
	cmp DL, 255			   
	je int21_07
	jmp int21_02
;====================================================;
;  read character without echo                       ;
;====================================================; 
int21_07:
	xor   ax,ax			   ; 0 AX
	int   16h			   ; Call BIOS function.
	jmp   int21_exit		   ; Jump to int21_exit label
;====================================================;
; write string; input es:dx = string(ended with '$') ;
;====================================================; 
int21_09:
	push  bx			   ; Save BX
	mov   bx,dx			   ; Put whats in DX into AX
Next:
	mov   al,byte[es:bx]		   ; Move byte that ES:BX ponts to, into AL
	cmp   al,'$'			   ; Is it a '$' ?.
	je    Done			   ; If yes, jump label Done
	call  print_char		      ; If not call char function.
	inc   bx			   ; Move the pointer on.
	jmp   Next			   ; Do another loop
Done:
	pop   bx			   ; Restore BX.
	mov   al,'$'			   ; Move '$' into AL
	jmp   int21_exit		   ; Jump to int21_exit label
;====================================================;
;  read string (not yet done)                        ;
;====================================================; 
int21_0A:
	jmp   int21_error		   ; Jump to int21_error label,as function not implemented
;====================================================;
;  get current drive                                 ;
;====================================================; 
int21_19:
	mov   al,0   ; byte[cs:DriveNumber]      ; Move boot drive number into AL
	jmp   int21_exit		   ; Jump to int21_exit label
;====================================================;
;  set interrupt vector                              ;
;====================================================; 
int21_25:
	cmp   al,19h			   ; No change int 19h (for rebooting)
	je    int21_error		   ; Jump to int21_error label
	cli				   ; Turn off int's
	xor   ah,ah			   ; 0 AH
	shl   ax,2			   ; Mul whats in AX by 4
	push  si			   ; Save SI
	push  bx			   ; Save BX
	push  es			   ; Save ES
	mov   si,ax			   ; Move AX into SI
	xor   bx,bx			   ; 0 BX
	mov   es,bx			   ; Move BX into ES
	mov   word[es:si],dx		   ; Move offset address to ES:SI points to.
	mov   bx, ds			   ; Move DS into BX
	mov   word[es:si+2],bx		   ; Move segment of address to ES:SI+2 points too.
	pop   es			   ; Restore ES
	pop   bx			   ; Restore BX
	pop   si			   ; Restore SI
	sti				   ; Turn int's on
	jmp int21_exit			   ; Jump to int21_exit label
;====================================================;
;  Get date                                          ;
;====================================================; 
int21_2A:
;====================================================;
;  Set date                                          ;
;====================================================; 
int21_2B:
;====================================================;
;  Get time                                          ;
;====================================================; 
int21_2C:
;====================================================;
;  Set time                                          ;
;====================================================; 
int21_2D:
	jmp   int21_error		   ; Jump to int21_error label,as function not implemented
;====================================================;
;  Get dos version:                                  ;
;====================================================; 
int21_30:
	mov   al,0	    ; Move higher part of number into AL
	mov   ah,2	    ; Move lower part of number into AH
	jmp   int21_exit		   ; Jump to int21_exit label
;====================================================;
;  Get interrupt vector                              ;
;====================================================; 
int21_35:
	push  ds			   ; Save DS
	push  si			   ; Save SI
	xor   ah,ah			   ; 0 AH
	shl   ax,2			   ; Mul whats in AX by 4     
	mov   si,ax			   ; Move AX into SI
	xor   bx,bx			   ; 0 BX
	mov   ds,bx			   ; DS = 0
	mov   bx,word[ds:si+2]		   ; Move the word that DS:SI+2 points to, into BX
	push bx 			   ; Save BX
	mov   bx,word [ds:si]		   ; Move the word that DS:SI points to, into BX
	pop es				   ; Move what was in the pushed BX into ES          
	pop si				   ; Restore SI
	pop ds				   ; Restore DS
	jmp   int21_exit		   ; Jump to int21_exit label
;====================================================;
; alloc ram memory                                   ;
;====================================================; 
int21_48:
	mov   ax,word [cs:end_memory]	   ; Move whats in the var [cs:end_memory] into AX
	add   ax,bx			   ; Add BX to the var
	cmp   ax,word [cs:top_memory]	   ; Is it more than whats in the var [cs:top_memory] ?
	jg    .error			   ; If yes jump .error label
	mov   word [cs:top_memory],ax	   ; If not it is now, put in [cs:top_memory] var.
.error:
	mov   bx, word [cs:top_memory]	   ; return in bx free paragraphs
	sub   bx, word [cs:end_memory]	   ; Show what memory is available.
	stc				   ; Set CF ti 1
	jmp   int21_error		   ; Jump to int21_error label
;====================================================;
; End program                                        ;
;====================================================; 
int21_4C:
	jmp   shell_loop		     ; Jump to int20   label
;====================================================;
; int21 error                                        ;
;====================================================; 
int21_error:
	mov   ax,0xffff 		   ; Move AX 0xFFFF to show error
;====================================================;
; int21 exit                                         ;
;====================================================;
int21_exit:
	iret				   ; Int return.

		    

end_memory dw 0
top_memory dw 0
