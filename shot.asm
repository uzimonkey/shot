.model tiny
.stack
.386

KBD_PORT	EQU	060h
F10_SCAN	EQU	044h

.code
.startup
		jmp	install

old_keyboard	DD	?
old_timer	DD	?

buffer_waiting	DB	0
buffer		DB	80*50*2 DUP(?)

filename	DB	"C:\screen.ans",0

indos_seg	DW	?
indos_offs	DW	?

ctrl_pushed	DB	0

; save screen from ds:dx to file
save		PROC
		; create or truncate file
		push	ds
		push	dx

		; create and open the file
		push	cs			; our data is in cs
		pop	ds
		mov	ah, 03Ch		; truncate/create and open
		xor	cx, cx			; file attributes
		mov	dx, OFFSET filename
		int	21h

		pop	dx
		pop	ds

		; write from memory (screen or buffer) to file
		mov	bx, ax			; file handle
		mov	ax, 04000h		; write to file
		mov	cx, 80*25*2
		int	21h

		; close file
		mov	ah, 03Eh
		int	21h

		ret
save		ENDP

keyboard	PROC FAR
		pusha

		; is this keypress F10?
		in	al, KBD_PORT
		cmp	al, F10_SCAN
		jne	done

		; is DOS busy?
		mov	es, cs:indos_seg
		mov	bx, cs:indos_offs
		cmp	BYTE PTR es:[bx], 0
		jnz	capture

		; save directly from screen to file
		mov	dx, 0B800h
		mov	ds, dx
		xor	dx, dx
		call	save
		jmp	done

capture:	; copy from screen into buffer to save later
		mov	ax, 0B800h		; from video memory
		mov	ds, ax
		xor	si, si
		mov	ax, cs			; to data
		mov	es, ax
		mov	di, OFFSET buffer

		; perform the copy
		mov	cx, 80*25
@@:		lodsw
		stosw
		loop	@b

		; signify we have data waiting in buffer
		inc	cs:buffer_waiting

		; call the old keyboard handler
done:		pushf
		call	cs:old_keyboard
		sti

		popa
		iret
keyboard	ENDP


timer		PROC
		pusha

		; if we have data waiting in the buffer
		cmp	cs:buffer_waiting, 0
		je	done

		; and DOS is not busy
		mov	es, cs:indos_seg
		mov	bx, cs:indos_offs
		cmp	BYTE PTR es:[bx], 0
		jnz	done

		; save the file
		mov	dx, cs
		mov	ds, dx
		mov	dx, OFFSET buffer
		call	save
		dec	cs:buffer_waiting

		; call old timer interrupt handler
done:		pushf
		call	cs:old_timer
		popa
		iret
timer		ENDP


install		PROC
		; get the offset to indos flag
		mov	ah, 034h
		int	21h
		mov	indos_seg, es
		mov	indos_offs, bx

		; get old keyboard interrupt and save it
		mov	ax, 3509h
		int	21h
		mov	WORD PTR old_keyboard[0], bx
		mov	WORD PTR old_keyboard[2], es

		; install new keyboard interrupt
		mov	ax, 2509h
		mov	dx, OFFSET keyboard
		int	21h

		; get old timer interrupt and save it
		mov	ax, 3508h
		int	21h
		mov	WORD PTR old_timer[0], bx
		mov	WORD PTR old_timer[2], es

		; install new timer interrupt
		mov	ax, 2508h
		mov	dx, OFFSET timer
		int	21h

		; TSR
		mov	dx, OFFSET install
		shr	dx, 4
		inc	dx
		mov	ax, 3100h
		int	21h
install		ENDP

END
