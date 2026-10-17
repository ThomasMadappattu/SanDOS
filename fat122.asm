use16
org 100h
include 'shell.asm'



;====================================================;
; DirPrintFileNS.                                    ;
;====================================================;
DirPrintFile:
	pusha				    ; Save genral regs
	push  ds			    ; Save DS
	push  es			    ; Save ES
	call  load_root_dir
	jc    DirError
	mov   word [cs:RdirFileCount],DIR_SEG ; Segment holding the root directory
	xor   si,si			    ; 0 SI
FileNamePrintLoop: 
	mov   ax,[cs:RdirFileCount]	    ; Move whats in [cs:RdirFileCount] into AX
	mov   ds,ax			    ; Move whats in AX into DS
	cmp   byte [ds:si],0x00 	    ; Check for end of directory
	je    DirSuccsess		    ; If = jump to exit
	cmp   byte [ds:si],0xe5 	    ; Check for deleted file
	je    NextDirEntry		    ; If = skip it
	test  byte [ds:si+11],0x08	    ; Skip the volume label
	jnz   NextDirEntry
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
NextDirEntry:
	add   si,32			    ; Next 32 byte directory entry
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
	cld
ConvertCliFileName:
	mov   al,[ds:si]
	cmp   al,'.'			    ; Name ends at '.' or end of string
	je    PadName
	or    al,al
	jz    PadName
	movsb				    ; Copy one character
	dec   cx
	jnz   ConvertCliFileName
SkipRestOfName:				    ; name longer than 8 chars : skip the rest
	mov   al,[ds:si]
	cmp   al,'.'
	je    ConvertExtension
	or    al,al
	jz    ConvertExtension
	inc   si
	jmp   SkipRestOfName
PadName:
	mov   al,0x20			    ; pad the name with spaces
	rep   stosb
ConvertExtension:
	mov   di,RootConvertedFileName	    ; Point to the ext
	add   di,8
	cmp   byte [ds:si],'.'
	jne   PadExtension
	inc   si			    ; Skip the '.'
	mov   cx,3
CopyExtension:
	mov   al,[ds:si]
	or    al,al
	jz    PadExtension
	movsb
	loop  CopyExtension
	jmp   FinConvert
PadExtension:
	mov   al,0x20
	rep   stosb
FinConvert:

	pop   ds			    ; Restore DS
	pop   es			    ; Restore ES
	popa				    ; Restore general regs
	clc				    ; Do not set CF to 1
	ret				    ; Return

;====================================================;
; Disk / program loading.                            ;
;====================================================;
DIR_SEG   = 0x3000		; root directory buffer (14 sectors)
FAT_SEG   = 0x3200		; FAT buffer (9 sectors)
PROG_SEG  = 0x4000		; segment .COM programs are loaded into

; read one sector : ax = LBA , es:bx = buffer , CF set on error
; all registers are preserved
disk_read_sector:
	pusha
	mov   byte [dr_tries],3
	mov   word [dr_lba],ax
.try:
	mov   ax,word [dr_lba]
	xor   dx,dx
	mov   si,SECTORS_PER_TRACK
	div   si
	mov   cl,dl
	inc   cl			    ; sector (1 based)
	xor   dx,dx
	mov   si,TOTAL_HEADS
	div   si
	mov   dh,dl			    ; head
	mov   ch,al			    ; cylinder
	mov   dl,DEFAULT_DRIVE
	mov   ax,0x0201
	int   13h
	jnc   .done
	xor   ax,ax			    ; reset the controller and retry
	int   13h
	dec   byte [dr_tries]
	jnz   .try
	stc
.done:
	popa
	ret

; read the root directory (sectors 19..32) into DIR_SEG
load_root_dir:
	push  ax
	push  bx
	push  cx
	push  es
	mov   ax,DIR_SEG
	mov   es,ax
	xor   bx,bx
	mov   ax,19
	mov   cx,14
.next:
	call  disk_read_sector
	jc    .error
	add   bx,512
	inc   ax
	loop  .next
	clc
	jmp   .exit
.error:
	mov   si,disk_err_msg
	call  print_string
	stc
.exit:
	pop   es
	pop   cx
	pop   bx
	pop   ax
	ret

; read the first FAT (sectors 1..9) into FAT_SEG
load_fat:
	push  ax
	push  bx
	push  cx
	push  es
	mov   ax,FAT_SEG
	mov   es,ax
	xor   bx,bx
	mov   ax,1
	mov   cx,9
.next:
	call  disk_read_sector
	jc    .error
	add   bx,512
	inc   ax
	loop  .next
	clc
	jmp   .exit
.error:
	mov   si,disk_err_msg
	call  print_string
	stc
.exit:
	pop   es
	pop   cx
	pop   bx
	pop   ax
	ret

; find RootConvertedFileName in the root directory
; output : ax = first cluster , CF set if not found
find_file:
	push  es
	push  di
	push  dx
	mov   ax,DIR_SEG
	mov   es,ax
	xor   di,di
	mov   dx,224
.entry:
	cmp   byte [es:di],0		    ; end of directory
	je    .not_found
	push  di
	mov   si,RootConvertedFileName
	mov   cx,11
	repe  cmpsb
	pop   di
	je    .found
	add   di,32
	dec   dx
	jnz   .entry
.not_found:
	stc
	jmp   .exit
.found:
	mov   ax,word [es:di+0x1A]
	clc
.exit:
	pop   dx
	pop   di
	pop   es
	ret

; ax = cluster , output ax = next cluster (FAT must be loaded)
next_cluster:
	push  bx
	push  dx
	push  es
	mov   bx,ax
	shr   bx,1
	add   bx,ax			    ; bx = cluster * 3 / 2
	mov   dx,FAT_SEG
	mov   es,dx
	mov   dx,word [es:bx]
	test  al,1
	jz    .even
	shr   dx,4
	jmp   .done
.even:
	and   dx,0x0FFF
.done:
	mov   ax,dx
	pop   es
	pop   dx
	pop   bx
	ret

; load the .COM file named in RootConvertedFileName at PROG_SEG:0100 and run it.
; only returns (with CF set) if the program could not be loaded.
load_com:
	call  load_root_dir
	jc    .fail
	call  load_fat
	jc    .fail
	call  find_file
	jnc   .found
	mov   si,not_found_msg
	call  print_string
	jmp   .fail
.found:
	mov   dx,PROG_SEG
	mov   es,dx
	mov   bx,0x100
.load:
	cmp   ax,2			    ; free / reserved cluster : corrupt chain
	jb    .disk_error
	push  ax
	add   ax,31			    ; first data sector is 33 , cluster 2
	call  disk_read_sector
	pop   ax
	jc    .disk_error
	add   bx,512
	cmp   bx,0xFE00 		    ; does not fit in a 64K .COM segment
	jae   .too_big
	call  next_cluster
	cmp   ax,0xFF8
	jb    .load

	; build a minimal PSP : int 20h at offset 0 , empty command tail
	mov   word [es:0],0x20CD
	mov   ax,word [top_memory]
	mov   word [es:2],ax
	mov   byte [es:0x80],0
	mov   byte [es:0x81],0x0D

	cli
	mov   ax,PROG_SEG
	mov   ds,ax
	mov   ss,ax
	mov   sp,0xFFFE
	sti
	xor   ax,ax
	push  ax			    ; a plain 'ret' ends up at the int 20h in the PSP
	push  word PROG_SEG
	push  word 0x100
	retf
.disk_error:
	mov   si,disk_err_msg
	call  print_string
	jmp   .fail
.too_big:
	mov   si,too_big_msg
	call  print_string
.fail:
	stc
	ret

;====================================================;
; Data.                                              ;
;====================================================;

dr_tries   db 0
dr_lba	   dw 0
disk_err_msg  db 'Disk read error',13,10,0
not_found_msg db 'File not found',13,10,0
too_big_msg   db 'Program too big',13,10,0
LabelDir:  db "<Dir>",10,13,0
nextline:  db 13,10,0
RdirFileCount dw 0
RootConvertedFileName : times 12 db 0
count  db 0
count2 dw 0