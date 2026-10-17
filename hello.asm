; hello.asm : sample .COM program for SanDOS (fasm hello.asm HELLO.COM)
use16
org 100h
	mov ah , 9
	mov dx , msg
	int 21h
	int 20h
msg db 'Hello from a COM program!',13,10,'$'
