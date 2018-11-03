.model tiny
.stack
.386

.code
.startup
		jmp	install

old_keyboard	DD	?
screen_buffer	DB	80*50*2 DUP(?)
filename	DB	"C:\screen.txt",0


keyboard	PROC FAR
		pushf
		call	cs:old_keyboard
		sti

		pusha

		mov	cx, 0B800h
		mov	ds, cx
		push	cs
		pop	es

		xor	si, si
		mov	di, OFFSET screen_buffer
		mov	cx, 80*24
@@:		lodsw
		stosw
		loop	@b

		push	cs
		pop	ds
		mov	ah, 03ch
		xor	cx, cx
		mov	dx, OFFSET filename
		int	21h

		mov	bx, ax
		mov	ah, 040h
		mov	cx, 80*24*2
		mov	dx, OFFSET screen_buffer
		int	21h

		mov	ah, 03Eh
		int	21h
		
		popa

		iret
keyboard	ENDP


install		PROC
		; Get old keyboard interrupt and save it
		mov	ax, 3509h
		int	21h
		mov	WORD PTR old_keyboard[0], bx
		mov	WORD PTR old_keyboard[2], es

		; Install new keyboard interrupt
		mov	ax, 2509h
		mov	dx, OFFSET keyboard
		int	21h

		; TSR
		mov	dx, OFFSET install
		shr	dx, 4
		inc	dx
		mov	ax, 3100h
		int	21h
install		ENDP

END
