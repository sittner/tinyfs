; ***********************************************************
; An Assembly Listing of the Operating System of the ZX81 ROM
; ***********************************************************
; -------------------------
; Last updated: 13-DEC-2004
; -------------------------
;
; Work in progress.
; This file will cross-assemble an original version of the "Improved"
; ZX81 ROM.  The file can be modified to change the behaviour of the ROM
; when used in emulators although there is no spare space available.
;
; The documentation is incomplete and if you can find a copy
; of "The Complete Spectrum ROM Disassembly" then many routines
; such as POINTERS and most of the mathematical routines are
; similar and often identical.
;
; I've used the labels from the above book in this file and also
; some from the more elusive Complete ZX81 ROM Disassembly
; by the same publishers, Melbourne House.
			
;*****************************************
;** Part 1. RESTART ROUTINES AND TABLES **
;*****************************************
			
	.org	0x0000	
			
; -----------
; THE 'START'
; -----------
; All Z80 chips start at location zero.
; At start-up the Interrupt Mode is 0, ZX computers use Interrupt Mode 1.
; Interrupts are disabled .
			
;; START
L0000:	out	(0xFD),A	; Turn off the NMI generator if this ROM is
				; running in ZX81 hardware. This does nothing
				; if this ROM is running within an upgraded
				; ZX80.
	ld	BC,#0x7FFF	; Set BC to the top of possible RAM.
				; The higher unpopulated addresses are used for
				; video generation.
	jp	L03CB		; Jump forward to RAM-CHECK.
			
; -------------------
; THE 'ERROR' RESTART
; -------------------
; The error restart deals immediately with an error. ZX computers execute the
; same code in runtime as when checking syntax. If the error occurred while
; running a program then a brief report is produced. If the error occurred
; while entering a BASIC line or in input etc., then the error marker indicates
; the exact point at which the error lies.
			
;; ERROR-1
L0008:	ld	HL,(0x4016)	; fetch character address from CH_ADD.
	ld	(0x4018),HL	; and set the error pointer X_PTR.
	jr	L0056		; forward to continue at ERROR-2.
			
; -------------------------------
; THE 'PRINT A CHARACTER' RESTART
; -------------------------------
; This restart prints the character in the accumulator using the alternate
; register set so there is no requirement to save the main registers.
; There is sufficient room available to separate a space (zero) from other
; characters as leading spaces need not be considered with a space.
			
;; PRINT-A
L0010:	and	A		; test for zero - space.
	jp	NZ,L07F1	; jump forward if not to PRINT-CH.
			
	jp	L07F5		; jump forward to PRINT-SP.
			
; ---
			
	.db	0xFF		; unused location.
			
; ---------------------------------
; THE 'COLLECT A CHARACTER' RESTART
; ---------------------------------
; The character addressed by the system variable CH_ADD is fetched and if it
; is a non-space, non-cursor character it is returned else CH_ADD is
; incremented and the new addressed character tested until it is not a space.
			
;; GET-CHAR
L0018:	ld	HL,(0x4016)	; set HL to character address CH_ADD.
	ld	A,(HL)		; fetch addressed character to A.
			
;; TEST-SP
L001C:	and	A		; test for space.
	ret	NZ		; return if not a space
			
	nop			; else trickle through
	nop			; to the next routine.
			
; ------------------------------------
; THE 'COLLECT NEXT CHARACTER' RESTART
; ------------------------------------
; The character address in incremented and the new addressed character is
; returned if not a space, or cursor, else the process is repeated.
			
;; NEXT-CHAR
L0020:	call	L0049		; routine CH-ADD+1 gets next immediate
				; character.
	jr	L001C		; back to TEST-SP.
			
; ---
			
	.db	0xFF, 0xFF, 0xFF	; unused locations.
			
; ---------------------------------------
; THE 'FLOATING POINT CALCULATOR' RESTART
; ---------------------------------------
; this restart jumps to the recursive floating-point calculator.
; the ZX81's internal, FORTH-like, stack-based language.
;
; In the five remaining bytes there is, appropriately, enough room for the
; end-calc literal - the instruction which exits the calculator.
			
;; FP-CALC
L0028:	jp	L199D		; jump immediately to the CALCULATE routine.
			
; ---
			
;; end-calc
L002B:	pop	AF		; drop the calculator return address RE-ENTRY
	exx			; switch to the other set.
			
	ex	(SP),HL		; transfer H'L' to machine stack for the
				; return address.
				; when exiting recursion then the previous
				; pointer is transferred to H'L'.
			
	exx			; back to main set.
	ret			; return.
			
			
; -----------------------------
; THE 'MAKE BC SPACES'  RESTART
; -----------------------------
; This restart is used eight times to create, in workspace, the number of
; spaces passed in the BC register.
			
;; BC-SPACES
L0030:	push	BC		; push number of spaces on stack.
	ld	HL,(0x4014)	; fetch edit line location from E_LINE.
	push	HL		; save this value on stack.
	jp	L1488		; jump forward to continue at RESERVE.
			
; -----------------------
; THE 'INTERRUPT' RESTART
; -----------------------
;   The Mode 1 Interrupt routine is concerned solely with generating the central
;   television picture.
;   On the ZX81 interrupts are enabled only during the interrupt routine,
;   although the interrupt
;   This Interrupt Service Routine automatically disables interrupts at the
;   outset and the last interrupt in a cascade exits before the interrupts are
;   enabled.
;   There is no DI instruction in the ZX81 ROM.
;   An maskable interrupt is triggered when bit 6 of the Z80's Refresh register
;   changes from set to reset.
;   The Z80 will always be executing a HALT (NEWLINE) when the interrupt occurs.
;   A HALT instruction repeatedly executes NOPS but the seven lower bits
;   of the Refresh register are incremented each time as they are when any
;   simple instruction is executed. (The lower 7 bits are incremented twice for
;   a prefixed instruction)
;   This is controlled by the Sinclair Computer Logic Chip - manufactured from
;   a Ferranti Uncommitted Logic Array.
;
;   When a Mode 1 Interrupt occurs the Program Counter, which is the address in
;   the upper echo display following the NEWLINE/HALT instruction, goes on the
;   machine stack.  193 interrupts are required to generate the last part of
;   the 56th border line and then the 192 lines of the central TV picture and,
;   although each interrupt interrupts the previous one, there are no stack
;   problems as the 'return address' is discarded each time.
;
;   The scan line counter in C counts down from 8 to 1 within the generation of
;   each text line. For the first interrupt in a cascade the initial value of
;   C is set to 1 for the last border line.
;   Timing is of the utmost importance as the RH border, horizontal retrace
;   and LH border are mostly generated in the 58 clock cycles this routine
;   takes .
			
;; INTERRUPT
L0038:	dec	C		; (4)  decrement C - the scan line counter.
	jp	NZ,L0045	; (10/10) JUMP forward if not zero to SCAN-LINE
			
	pop	HL		; (10) point to start of next row in display
				;      file.
			
	dec	B		; (4)  decrement the row counter. (4)
	ret	Z		; (11/5) return when picture complete to L028B
				;      with interrupts disabled.
			
	set	3,C		; (8)  Load the scan line counter with eight.
				;      Note. LD C,$08 is 7 clock cycles which
				;      is way too fast.
			
; ->
			
;; WAIT-INT
L0041:	ld	R,A		; (9) Load R with initial rising value $DD.
			
	ei			; (4) Enable Interrupts.  [ R is now $DE ].
			
	jp	(HL)		; (4) jump to the echo display file in upper
				;     memory and execute characters $00 - $3F
				;     as NOP instructions.  The video hardware
				;     is able to read these characters and,
				;     with the I register is able to convert
				;     the character bitmaps in this ROM into a
				;     line of bytes. Eventually the NEWLINE/HALT
				;     will be encountered before R reaches $FF.
				;     It is however the transition from $FF to
				;     $80 that triggers the next interrupt.
				;     [ The Refresh register is now $DF ]
			
; ---
			
;; SCAN-LINE
L0045:	pop	DE		; (10) discard the address after NEWLINE as the
				;      same text line has to be done again
				;      eight times.
			
	ret	Z		; (5)  Harmless Nonsensical Timing.
				;      (condition never met)
			
	jr	L0041		; (12) back to WAIT-INT
			
;   Note. that a computer with less than 4K or RAM will have a collapsed
;   display file and the above mechanism deals with both types of display.
;
;   With a full display, the 32 characters in the line are treated as NOPS
;   and the Refresh register rises from $E0 to $FF and, at the next instruction
;   - HALT, the interrupt occurs.
;   With a collapsed display and an initial NEWLINE/HALT, it is the NOPs
;   generated by the HALT that cause the Refresh value to rise from $E0 to $FF,
;   triggering an Interrupt on the next transition.
;   This works happily for all display lines between these extremes and the
;   generation of the 32 character, 1 pixel high, line will always take 128
;   clock cycles.
			
; ---------------------------------
; THE 'INCREMENT CH-ADD' SUBROUTINE
; ---------------------------------
; This is the subroutine that increments the character address system variable
; and returns if it is not the cursor character. The ZX81 has an actual
; character at the cursor position rather than a pointer system variable
; as is the case with prior and subsequent ZX computers.
			
;; CH-ADD+1
L0049:	ld	HL,(0x4016)	; fetch character address to CH_ADD.
			
;; TEMP-PTR1
L004C:	inc	HL		; address next immediate location.
			
;; TEMP-PTR2
L004D:	ld	(0x4016),HL	; update system variable CH_ADD.
			
	ld	A,(HL)		; fetch the character.
	cp	#0x7F		; compare to cursor character.
	ret	NZ		; return if not the cursor.
			
	jr	L004C		; back for next character to TEMP-PTR1.
			
; --------------------
; THE 'ERROR-2' BRANCH
; --------------------
; This is a continuation of the error restart.
; If the error occurred in runtime then the error stack pointer will probably
; lead to an error report being printed unless it occurred during input.
; If the error occurred when checking syntax then the error stack pointer
; will be an editing routine and the position of the error will be shown
; when the lower screen is reprinted.
			
;; ERROR-2
L0056:	pop	HL		; pop the return address which points to the
				; DEFB, error code, after the RST 08.
	ld	L,(HL)		; load L with the error code. HL is not needed
				; anymore.
			
;; ERROR-3
L0058:	ld	0x00(IY),L	; place error code in system variable ERR_NR
	ld	SP,(0x4002)	; set the stack pointer from ERR_SP
	call	L0207		; routine SLOW/FAST selects slow mode.
	jp	L14BC		; exit to address on stack via routine SET-MIN.
			
; ---
			
	.db	0xFF		; unused.
			
; ------------------------------------
; THE 'NON MASKABLE INTERRUPT' ROUTINE
; ------------------------------------
;   Jim Westwood's technical dodge using Non-Maskable Interrupts solved the
;   flicker problem of the ZX80 and gave the ZX81 a multi-tasking SLOW mode
;   with a steady display.  Note that the AF' register is reserved for this
;   function and its interaction with the display routines.  When counting
;   TV lines, the NMI makes no use of the main registers.
;   The circuitry for the NMI generator is contained within the SCL (Sinclair
;   Computer Logic) chip.
;   ( It takes 32 clock cycles while incrementing towards zero ).
			
;; NMI
L0066:	ex	AF,AF'		; (4) switch in the NMI's copy of the
				;     accumulator.
	inc	A		; (4) increment.
	jp	M,L006D		; (10/10) jump, if minus, to NMI-RET as this is
				;     part of a test to see if the NMI
				;     generation is working or an intermediate
				;     value for the ascending negated blank
				;     line counter.
			
	jr	Z,L006F		; (12) forward to NMI-CONT
				;      when line count has incremented to zero.
			
; Note. the synchronizing NMI when A increments from zero to one takes this
; 7 clock cycle route making 39 clock cycles in all.
			
;; NMI-RET
L006D:	ex	AF,AF'		; (4)  switch out the incremented line counter
				;      or test result $80
	ret			; (10) return to User application for a while.
			
; ---
			
;   This branch is taken when the 55 (or 31) lines have been drawn.
			
;; NMI-CONT
L006F:	ex	AF,AF'		; (4) restore the main accumulator.
			
	push	AF		; (11) *             Save Main Registers
	push	BC		; (11) **
	push	DE		; (11) ***
	push	HL		; (11) ****
			
;   the next set-up procedure is only really applicable when the top set of
;   blank lines have been generated.
			
	ld	HL,(0x400C)	; (16) fetch start of Display File from D_FILE
				;      points to the HALT at beginning.
	set	7,H		; (8) point to upper 32K 'echo display file'
			
	halt			; (1) HALT synchronizes with NMI.
				; Used with special hardware connected to the
				; Z80 HALT and WAIT lines to take 1 clock cycle.
			
; ----------------------------------------------------------------------------
;   the NMI has been generated - start counting. The cathode ray is at the RH
;   side of the TV.
;   First the NMI servicing, similar to CALL            =  17 clock cycles.
;   Then the time taken by the NMI for zero-to-one path =  39 cycles
;   The HALT above                                      =  01 cycles.
;   The two instructions below                          =  19 cycles.
;   The code at L0281 up to and including the CALL      =  43 cycles.
;   The Called routine at L02B5                         =  24 cycles.
;   --------------------------------------                ---
;   Total Z80 instructions                              = 143 cycles.
;
;   Meanwhile in TV world,
;   Horizontal retrace                                  =  15 cycles.
;   Left blanking border 8 character positions          =  32 cycles
;   Generation of 75% scanline from the first NEWLINE   =  96 cycles
;   ---------------------------------------               ---
;                                                         143 cycles
;
;   Since at the time the first JP (HL) is encountered to execute the echo
;   display another 8 character positions have to be put out, then the
;   Refresh register need to hold $F8. Working back and counteracting
;   the fact that every instruction increments the Refresh register then
;   the value that is loaded into R needs to be $F5.      :-)
;
;
	out	(0xFD),A	; (11) Stop the NMI generator.
			
	jp	(IX)		; (8) forward to L0281 (after top) or L028F
			
; ****************
; ** KEY TABLES **
; ****************
			
; -------------------------------
; THE 'UNSHIFTED' CHARACTER CODES
; -------------------------------
			
;; K-UNSHIFT
L007E:	.db	0x3F		; Z
	.db	0x3D		; X
	.db	0x28		; C
	.db	0x3B		; V
	.db	0x26		; A
	.db	0x38		; S
	.db	0x29		; D
	.db	0x2B		; F
	.db	0x2C		; G
	.db	0x36		; Q
	.db	0x3C		; W
	.db	0x2A		; E
	.db	0x37		; R
	.db	0x39		; T
	.db	0x1D		; 1
	.db	0x1E		; 2
	.db	0x1F		; 3
	.db	0x20		; 4
	.db	0x21		; 5
	.db	0x1C		; 0
	.db	0x25		; 9
	.db	0x24		; 8
	.db	0x23		; 7
	.db	0x22		; 6
	.db	0x35		; P
	.db	0x34		; O
	.db	0x2E		; I
	.db	0x3A		; U
	.db	0x3E		; Y
	.db	0x76		; NEWLINE
	.db	0x31		; L
	.db	0x30		; K
	.db	0x2F		; J
	.db	0x2D		; H
	.db	0x00		; SPACE
	.db	0x1B		; .
	.db	0x32		; M
	.db	0x33		; N
	.db	0x27		; B
			
; -----------------------------
; THE 'SHIFTED' CHARACTER CODES
; -----------------------------
			
			
;; K-SHIFT
L00A5:	.db	0x0E		; :
	.db	0x19		; ;
	.db	0x0F		; ?
	.db	0x18		; /
	.db	0xE3		; STOP
	.db	0xE1		; LPRINT
	.db	0xE4		; SLOW
	.db	0xE5		; FAST
	.db	0xE2		; LLIST
	.db	0xC0		; ""
	.db	0xD9		; OR
	.db	0xE0		; STEP
	.db	0xDB		; <=
	.db	0xDD		; <>
	.db	0x75		; EDIT
	.db	0xDA		; AND
	.db	0xDE		; THEN
	.db	0xDF		; TO
	.db	0x72		; cursor-left
	.db	0x77		; RUBOUT
	.db	0x74		; GRAPHICS
	.db	0x73		; cursor-right
	.db	0x70		; cursor-up
	.db	0x71		; cursor-down
	.db	0x0B		; "
	.db	0x11		; )
	.db	0x10		; (
	.db	0x0D		; $
	.db	0xDC		; >=
	.db	0x79		; FUNCTION
	.db	0x14		; =
	.db	0x15		;
	.db	0x16		; -
	.db	0xD8		; **
	.db	0x0C		; ukp
	.db	0x1A		; ,
	.db	0x12		; >
	.db	0x13		; <
	.db	0x17		; *
			
; ------------------------------
; THE 'FUNCTION' CHARACTER CODES
; ------------------------------
			
			
;; K-FUNCT
L00CC:	.db	0xCD		; LN
	.db	0xCE		; EXP
	.db	0xC1		; AT
	.db	0x78		; KL
	.db	0xCA		; ASN
	.db	0xCB		; ACS
	.db	0xCC		; ATN
	.db	0xD1		; SGN
	.db	0xD2		; ABS
	.db	0xC7		; SIN
	.db	0xC8		; COS
	.db	0xC9		; TAN
	.db	0xCF		; INT
	.db	0x40		; RND
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0xC2		; TAB
	.db	0xD3		; PEEK
	.db	0xC4		; CODE
	.db	0xD6		; CHR$
	.db	0xD5		; STR$
	.db	0x78		; KL
	.db	0xD4		; USR
	.db	0xC6		; LEN
	.db	0xC5		; VAL
	.db	0xD0		; SQR
	.db	0x78		; KL
	.db	0x78		; KL
	.db	0x42		; PI
	.db	0xD7		; NOT
	.db	0x41		; INKEY$
			
; -----------------------------
; THE 'GRAPHIC' CHARACTER CODES
; -----------------------------
			
			
;; K-GRAPH
L00F3:	.db	0x08		; graphic
	.db	0x0A		; graphic
	.db	0x09		; graphic
	.db	0x8A		; graphic
	.db	0x89		; graphic
	.db	0x81		; graphic
	.db	0x82		; graphic
	.db	0x07		; graphic
	.db	0x84		; graphic
	.db	0x06		; graphic
	.db	0x01		; graphic
	.db	0x02		; graphic
	.db	0x87		; graphic
	.db	0x04		; graphic
	.db	0x05		; graphic
	.db	0x77		; RUBOUT
	.db	0x78		; KL
	.db	0x85		; graphic
	.db	0x03		; graphic
	.db	0x83		; graphic
	.db	0x8B		; graphic
	.db	0x91		; inverse )
	.db	0x90		; inverse (
	.db	0x8D		; inverse $
	.db	0x86		; graphic
	.db	0x78		; KL
	.db	0x92		; inverse >
	.db	0x95		; inverse
	.db	0x96		; inverse -
	.db	0x88		; graphic
			
; ------------------
; THE 'TOKEN' TABLES
; ------------------
			
			
;; TOKENS
L0111:	.db	0x0F+0x80	; '?'+$80
	.db	0x0B,#0x0B+0x80	; ""
	.db	0x26,0x39+0x80	; AT
	.db	0x39,0x26,0x27+0x80	; TAB
	.db	0x0F+0x80	; '?'+$80
	.db	0x28,0x34,0x29,0x2A+0x80	; CODE
	.db	0x3B,#0x26,0x31+0x80	; VAL
	.db	0x31,0x2A,#0x33+0x80	; LEN
	.db	0x38,0x2E,#0x33+0x80	; SIN
	.db	0x28,0x34,0x38+0x80	; COS
	.db	0x39,0x26,0x33+0x80	; TAN
	.db	0x26,0x38,0x33+0x80	; ASN
	.db	0x26,0x28,0x38+0x80	; ACS
	.db	0x26,0x39,0x33+0x80	; ATN
	.db	0x31,0x33+0x80	; LN
	.db	0x2A,#0x3D,#0x35+0x80	; EXP
	.db	0x2E,#0x33,0x39+0x80	; INT
	.db	0x38,0x36,0x37+0x80	; SQR
	.db	0x38,0x2C,#0x33+0x80	; SGN
	.db	0x26,0x27,0x38+0x80	; ABS
	.db	0x35,0x2A,#0x2A,#0x30+0x80	; PEEK
	.db	0x3A,#0x38,0x37+0x80	; USR
	.db	0x38,0x39,0x37,0x0D+0x80	; STR$
	.db	0x28,0x2D,#0x37,0x0D+0x80	; CHR$
	.db	0x33,0x34,0x39+0x80	; NOT
	.db	0x17,0x17+0x80	; **
	.db	0x34,0x37+0x80	; OR
	.db	0x26,0x33,0x29+0x80	; AND
	.db	0x13,0x14+0x80	; <=
	.db	0x12,0x14+0x80	; >=
	.db	0x13,0x12+0x80	; <>
	.db	0x39,0x2D,#0x2A,#0x33+0x80	; THEN
	.db	0x39,0x34+0x80	; TO
	.db	0x38,0x39,0x2A,#0x35+0x80	; STEP
	.db	0x31,0x35,0x37,0x2E,#0x33,0x39+0x80	; LPRINT
	.db	0x31,0x31,0x2E,#0x38,0x39+0x80	; LLIST
	.db	0x38,0x39,0x34,0x35+0x80	; STOP
	.db	0x38,0x31,0x34,0x3C+0x80	; SLOW
	.db	0x2B,#0x26,0x38,0x39+0x80	; FAST
	.db	0x33,0x2A,#0x3C+0x80	; NEW
	.db	0x38,0x28,0x37,0x34,0x31,0x31+0x80	; SCROLL
	.db	0x28,0x34,0x33,0x39+0x80	; CONT
	.db	0x29,0x2E,#0x32+0x80	; DIM
	.db	0x37,0x2A,#0x32+0x80	; REM
	.db	0x2B,#0x34,0x37+0x80	; FOR
	.db	0x2C,#0x34,0x39,0x34+0x80	; GOTO
	.db	0x2C,#0x34,0x38,0x3A,#0x27+0x80	; GOSUB
	.db	0x2E,#0x33,0x35,0x3A,#0x39+0x80	; INPUT
	.db	0x31,0x34,0x26,0x29+0x80	; LOAD
	.db	0x31,0x2E,#0x38,0x39+0x80	; LIST
	.db	0x31,0x2A,#0x39+0x80	; LET
	.db	0x35,0x26,0x3A,#0x38,0x2A+0x80	; PAUSE
	.db	0x33,0x2A,#0x3D,#0x39+0x80	; NEXT
	.db	0x35,0x34,0x30,0x2A+0x80	; POKE
	.db	0x35,0x37,0x2E,#0x33,0x39+0x80	; PRINT
	.db	0x35,0x31,0x34,0x39+0x80	; PLOT
	.db	0x37,0x3A,#0x33+0x80	; RUN
	.db	0x38,0x26,0x3B,#0x2A+0x80	; SAVE
	.db	0x37,0x26,0x33,0x29+0x80	; RAND
	.db	0x2E,#0x2B+0x80	; IF
	.db	0x28,0x31,0x38+0x80	; CLS
	.db	0x3A,#0x33,0x35,0x31,0x34,0x39+0x80	; UNPLOT
	.db	0x28,0x31,0x2A,#0x26,0x37+0x80	; CLEAR
	.db	0x37,0x2A,#0x39,0x3A,#0x37,0x33+0x80	; RETURN
	.db	0x28,0x34,0x35,0x3E+0x80	; COPY
	.db	0x37,0x33,0x29+0x80	; RND
	.db	0x2E,#0x33,0x30,0x2A,#0x3E,#0x0D+0x80	; INKEY$
	.db	0x35,0x2E+0x80	; PI
			
			
; ------------------------------
; THE 'LOAD-SAVE UPDATE' ROUTINE
; ------------------------------
;
;
			
;; LOAD/SAVE
L01FC:	inc	HL		;
	ex	DE,HL		;
	ld	HL,(0x4014)	; system variable edit line E_LINE.
	scf			; set carry flag
	sbc	HL,DE		;
	ex	DE,HL		;
	ret	NC		; return if more bytes to load/save.
			
	pop	HL		; else drop return address
			
; ----------------------
; THE 'DISPLAY' ROUTINES
; ----------------------
;
;
			
;; SLOW/FAST
L0207:	ld	HL,#0x403B	; Address the system variable CDFLAG.
	ld	A,(HL)		; Load value to the accumulator.
	rla			; rotate bit 6 to position 7.
	xor	(HL)		; exclusive or with original bit 7.
	rla			; rotate result out to carry.
	ret	NC		; return if both bits were the same.
			
;   Now test if this really is a ZX81 or a ZX80 running the upgraded ROM.
;   The standard ZX80 did not have an NMI generator.
			
	ld	A,#0x7F		; Load accumulator with %011111111
	ex	AF,AF'		; save in AF'
			
	ld	B,#0x11		; A counter within which an NMI should occur
				; if this is a ZX81.
	out	(0xFE),A	; start the NMI generator.
			
;  Note that if this is a ZX81 then the NMI will increment AF'.
			
;; LOOP-11
L0216:	djnz	L0216		; self loop to give the NMI a chance to kick in.
				; = 16*13 clock cycles + 8 = 216 clock cycles.
			
	out	(0xFD),A	; Turn off the NMI generator.
	ex	AF,AF'		; bring back the AF' value.
	rla			; test bit 7.
	jr	NC,L0226	; forward, if bit 7 is still reset, to NO-SLOW.
			
;   If the AF' was incremented then the NMI generator works and SLOW mode can
;   be set.
			
	set	7,(HL)		; Indicate SLOW mode - Compute and Display.
			
	push	AF		; *             Save Main Registers
	push	BC		; **
	push	DE		; ***
	push	HL		; ****
			
	jr	L0229		; skip forward - to DISPLAY-1.
			
; ---
			
;; NO-SLOW
L0226:	res	6,(HL)		; reset bit 6 of CDFLAG.
	ret			; return.
			
; -----------------------
; THE 'MAIN DISPLAY' LOOP
; -----------------------
; This routine is executed once for every frame displayed.
			
;; DISPLAY-1
L0229:	ld	HL,(0x4034)	; fetch two-byte system variable FRAMES.
	dec	HL		; decrement frames counter.
			
;; DISPLAY-P
L022D:	ld	A,#0x7F		; prepare a mask
	and	H		; pick up bits 6-0 of H.
	or	L		; and any bits of L.
	ld	A,H		; reload A with all bits of H for PAUSE test.
			
;   Note both branches must take the same time.
			
	jr	NZ,L0237	; (12/7) forward if bits 14-0 are not zero
				; to ANOTHER
			
	rla			; (4) test bit 15 of FRAMES.
	jr	L0239		; (12) forward with result to OVER-NC
			
; ---
			
;; ANOTHER
L0237:	ld	B,(HL)		; (7) Note. Harmless Nonsensical Timing weight.
	scf			; (4) Set Carry Flag.
			
; Note. the branch to here takes either (12)(7)(4) cyles or (7)(4)(12) cycles.
			
;; OVER-NC
L0239:	ld	H,A		; (4)  set H to zero
	ld	(0x4034),HL	; (16) update system variable FRAMES
	ret	NC		; (11/5) return if FRAMES is in use by PAUSE
				; command.
			
;; DISPLAY-2
L023E:	call	L02BB		; routine KEYBOARD gets the key row in H and
				; the column in L. Reading the ports also starts
				; the TV frame synchronization pulse. (VSYNC)
			
	ld	BC,(0x4025)	; fetch the last key values read from LAST_K
	ld	(0x4025),HL	; update LAST_K with new values.
			
	ld	A,B		; load A with previous column - will be $FF if
				; there was no key.
	add	A,#0x02		; adding two will set carry if no previous key.
			
	sbc	HL,BC		; subtract with the carry the two key values.
			
; If the same key value has been returned twice then HL will be zero.
			
	ld	A,(0x4027)	; fetch system variable DEBOUNCE
	or	H		; and OR with both bytes of the difference
	or	L		; setting the zero flag for the upcoming branch.
			
	ld	E,B		; transfer the column value to E
	ld	B,#0x0B		; and load B with eleven
			
	ld	HL,#0x403B	; address system variable CDFLAG
	res	0,(HL)		; reset the rightmost bit of CDFLAG
	jr	NZ,L0264	; skip forward if debounce/diff >0 to NO-KEY
			
	bit	7,(HL)		; test compute and display bit of CDFLAG
	set	0,(HL)		; set the rightmost bit of CDFLAG.
	ret	Z		; return if bit 7 indicated fast mode.
			
	dec	B		; (4) decrement the counter.
	nop			; (4) Timing - 4 clock cycles. ??
	scf			; (4) Set Carry Flag
			
;; NO-KEY
L0264:	ld	HL,#0x4027	; sv DEBOUNCE
	ccf			; Complement Carry Flag
	rl	B		; rotate left B picking up carry
				;  C<-76543210<-C
			
;; LOOP-B
L026A:	djnz	L026A		; self-loop while B>0 to LOOP-B
			
	ld	B,(HL)		; fetch value of DEBOUNCE to B
	ld	A,E		; transfer column value
	cp	#0xFE		;
	sbc	A,A		;
	ld	B,#0x1F		;
	or	(HL)		;
	and	B		;
	rra			;
	ld	(HL),A		;
			
	out	(0xFF),A	; end the TV frame synchronization pulse.
			
	ld	HL,(0x400C)	; (12) set HL to the Display File from D_FILE
	set	7,H		; (8) set bit 15 to address the echo display.
			
	call	L0292		; (17) routine DISPLAY-3 displays the top set
				; of blank lines.
			
; ---------------------
; THE 'VIDEO-1' ROUTINE
; ---------------------
			
;; R-IX-1
L0281:	ld	A,R		; (9)  Harmless Nonsensical Timing or something
				;      very clever?
	ld	BC,#0x1901	; (10) 25 lines, 1 scanline in first.
	ld	A,#0xF5		; (7)  This value will be loaded into R and
				; ensures that the cycle starts at the right
				; part of the display  - after 32nd character
				; position.
			
	call	L02B5		; (17) routine DISPLAY-5 completes the current
				; blank line and then generates the display of
				; the live picture using INT interrupts
				; The final interrupt returns to the next
				; address.
			
L028B:	dec	HL		; point HL to the last NEWLINE/HALT.
			
	call	L0292		; routine DISPLAY-3 displays the bottom set of
				; blank lines.
			
; ---
			
;; R-IX-2
L028F:	jp	L0229		; JUMP back to DISPLAY-1
			
; ---------------------------------
; THE 'DISPLAY BLANK LINES' ROUTINE
; ---------------------------------
;   This subroutine is called twice (see above) to generate first the blank
;   lines at the top of the television display and then the blank lines at the
;   bottom of the display.
			
;; DISPLAY-3
L0292:	pop	IX		; pop the return address to IX register.
				; will be either L0281 or L028F - see above.
			
	ld	C,0x28(IY)	; load C with value of system constant MARGIN.
	bit	7,0x3B(IY)	; test CDFLAG for compute and display.
	jr	Z,L02A9		; forward, with FAST mode, to DISPLAY-4
			
	ld	A,C		; move MARGIN to A  - 31d or 55d.
	neg			; Negate
	inc	A		;
	ex	AF,AF'		; place negative count of blank lines in A'
			
	out	(0xFE),A	; enable the NMI generator.
			
	pop	HL		; ****
	pop	DE		; ***
	pop	BC		; **
	pop	AF		; *             Restore Main Registers
			
	ret			; return - end of interrupt.  Return is to
				; user's program - BASIC or machine code.
				; which will be interrupted by every NMI.
			
; ------------------------
; THE 'FAST MODE' ROUTINES
; ------------------------
			
;; DISPLAY-4
L02A9:	ld	A,#0xFC		; (7)  load A with first R delay value
	ld	B,#0x01		; (7)  one row only.
			
	call	L02B5		; (17) routine DISPLAY-5
			
	dec	HL		; (6)  point back to the HALT.
	ex	(SP),HL		; (19) Harmless Nonsensical Timing if paired.
	ex	(SP),HL		; (19) Harmless Nonsensical Timing.
	jp	(IX)		; (8)  to L0281 or L028F
			
; --------------------------
; THE 'DISPLAY-5' SUBROUTINE
; --------------------------
;   This subroutine is called from SLOW mode and FAST mode to generate the
;   central TV picture. With SLOW mode the R register is incremented, with
;   each instruction, to $F7 by the time it completes.  With fast mode, the
;   final R value will be $FF and an interrupt will occur as soon as the
;   Program Counter reaches the HALT.  (24 clock cycles)
			
;; DISPLAY-5
L02B5:	ld	R,A		; (9) Load R from A.    R = slow: $F5 fast: $FC
	ld	A,#0xDD		; (7) load future R value.        $F6       $FD
			
	ei			; (4) Enable Interrupts           $F7       $FE
			
	jp	(HL)		; (4) jump to the echo display.   $F8       $FF
			
; ----------------------------------
; THE 'KEYBOARD SCANNING' SUBROUTINE
; ----------------------------------
; The keyboard is read during the vertical sync interval while no video is
; being displayed.  Reading a port with address bit 0 low i.e. $FE starts the
; vertical sync pulse.
			
;; KEYBOARD
L02BB:	ld	HL,#0xFFFF	; (16) prepare a buffer to take key.
	ld	BC,#0xFEFE	; (20) set BC to port $FEFE. The B register,
				;      with its single reset bit also acts as
				;      an 8-counter.
	in	A,(C)		; (11) read the port - all 16 bits are put on
				;      the address bus.  Start VSYNC pulse.
	or	#0x01		; (7)  set the rightmost bit so as to ignore
				;      the SHIFT key.
			
;; EACH-LINE
L02C5:	or	#0xE0		; [7] OR %11100000
	ld	D,A		; [4] transfer to D.
	cpl			; [4] complement - only bits 4-0 meaningful now.
	cp	#0x01		; [7] sets carry if A is zero.
	sbc	A,A		; [4] $FF if $00 else zero.
	or	B		; [7] $FF or port FE,FD,FB....
	and	L		; [4] unless more than one key, L will still be
				;     $FF. if more than one key is pressed then A is
				;     now invalid.
	ld	L,A		; [4] transfer to L.
			
; now consider the column identifier.
			
	ld	A,H		; [4] will be $FF if no previous keys.
	and	D		; [4] 111xxxxx
	ld	H,A		; [4] transfer A to H
			
; since only one key may be pressed, H will, if valid, be one of
; 11111110, 11111101, 11111011, 11110111, 11101111
; reading from the outer column, say Q, to the inner column, say T.
			
	rlc	B		; [8]  rotate the 8-counter/port address.
				;      sets carry if more to do.
	in	A,(C)		; [10] read another half-row.
				;      all five bits this time.
			
	jr	C,L02C5		; [12](7) loop back, until done, to EACH-LINE
			
;   The last row read is SHIFT,Z,X,C,V  for the second time.
			
	rra			; (4) test the shift key - carry will be reset
				;     if the key is pressed.
	rl	H		; (8) rotate left H picking up the carry giving
				;     column values -
				;        $FD, $FB, $F7, $EF, $DF.
				;     or $FC, $FA, $F6, $EE, $DE if shifted.
			
;   We now have H identifying the column and L identifying the row in the
;   keyboard matrix.
			
;   This is a good time to test if this is an American or British machine.
;   The US machine has an extra diode that causes bit 6 of a byte read from
;   a port to be reset.
			
	rla			; (4) compensate for the shift test.
	rla			; (4) rotate bit 7 out.
	rla			; (4) test bit 6.
			
	sbc	A,A		; (4)           $FF or $00 {USA}
	and	#0x18		; (7)           $18 or $00
	add	A,#0x1F		; (7)           $37 or $1F
			
;   result is either 31 (USA) or 55 (UK) blank lines above and below the TV
;   picture.
			
	ld	(0x4028),A	; (13) update system variable MARGIN
			
	ret			; (10) return
			
; ------------------------------
; THE 'SET FAST MODE' SUBROUTINE
; ------------------------------
;
;
			
;; SET-FAST
L02E7:	bit	7,0x3B(IY)	; sv CDFLAG
	ret	Z		;
			
	halt			; Wait for Interrupt
	out	(0xFD),A	;
	res	7,0x3B(IY)	; sv CDFLAG
	ret			; return.
			
			
; --------------
; THE 'REPORT-F'
; --------------
			
;; REPORT-F
L02F4:	rst	#0x08		; ERROR-1
	.db	0x0E		; Error Report: No Program Name supplied.
			
; --------------------------
; THE 'SAVE COMMAND' ROUTINE
; --------------------------
;
;
			
;; SAVE
L02F6:	call	L03A8		; routine NAME
	jr	C,L02F4		; back with null name to REPORT-F above.
			
	ex	DE,HL		;
	ld	DE,#0x12CB	; five seconds timing value
			
;; HEADER
L02FF:	call	L0F46		; routine BREAK-1
	jr	NC,L0332	; to BREAK-2
			
;; DELAY-1
L0304:	djnz	L0304		; to DELAY-1
			
	dec	DE		;
	ld	A,D		;
	or	E		;
	jr	NZ,L02FF	; back for delay to HEADER
			
;; OUT-NAME
L030B:	call	L031E		; routine OUT-BYTE
	bit	7,(HL)		; test for inverted bit.
	inc	HL		; address next character of name.
	jr	Z,L030B		; back if not inverted to OUT-NAME
			
; now start saving the system variables onwards.
			
	ld	HL,#0x4009	; set start of area to VERSN thereby
				; preserving RAMTOP etc.
			
;; OUT-PROG
L0316:	call	L031E		; routine OUT-BYTE
			
	call	L01FC		; routine LOAD/SAVE                     >>
	jr	L0316		; loop back to OUT-PROG
			
; -------------------------
; THE 'OUT-BYTE' SUBROUTINE
; -------------------------
; This subroutine outputs a byte a bit at a time to a domestic tape recorder.
			
;; OUT-BYTE
L031E:	ld	E,(HL)		; fetch byte to be saved.
	scf			; set carry flag - as a marker.
			
;; EACH-BIT
L0320:	rl	E		;  C < 76543210 < C
	ret	Z		; return when the marker bit has passed
				; right through.                        >>
			
	sbc	A,A		; $FF if set bit or $00 with no carry.
	and	#0x05		; $05               $00
	add	A,#0x04		; $09               $04
	ld	C,A		; transfer timer to C. a set bit has a longer
				; pulse than a reset bit.
			
;; PULSES
L0329:	out	(0xFF),A	; pulse to cassette.
	ld	B,#0x23		; set timing constant
			
;; DELAY-2
L032D:	djnz	L032D		; self-loop to DELAY-2
			
	call	L0F46		; routine BREAK-1 test for BREAK key.
			
;; BREAK-2
L0332:	jr	NC,L03A6	; forward with break to REPORT-D
			
	ld	B,#0x1E		; set timing value.
			
;; DELAY-3
L0336:	djnz	L0336		; self-loop to DELAY-3
			
	dec	C		; decrement counter
	jr	NZ,L0329	; loop back to PULSES
			
;; DELAY-4
L033B:	and	A		; clear carry for next bit test.
	djnz	L033B		; self loop to DELAY-4 (B is zero - 256)
			
	jr	L0320		; loop back to EACH-BIT
			
; --------------------------
; THE 'LOAD COMMAND' ROUTINE
; --------------------------
;
;
			
;; LOAD
L0340:	call	L03A8		; routine NAME
			
; DE points to start of name in RAM.
			
	rl	D		; pick up carry
	rrc	D		; carry now in bit 7.
			
;; NEXT-PROG
L0347:	call	L034C		; routine IN-BYTE
	jr	L0347		; loop to NEXT-PROG
			
; ------------------------
; THE 'IN-BYTE' SUBROUTINE
; ------------------------
			
;; IN-BYTE
L034C:	ld	C,#0x01		; prepare an eight counter 00000001.
			
;; NEXT-BIT
L034E:	ld	B,#0x00		; set counter to 256
			
;; BREAK-3
L0350:	ld	A,#0x7F		; read the keyboard row
	in	A,(0xFE)	; with the SPACE key.
			
	out	(0xFF),A	; output signal to screen.
			
	rra			; test for SPACE pressed.
	jr	NC,L03A2	; forward if so to BREAK-4
			
	rla			; reverse above rotation
	rla			; test tape bit.
	jr	C,L0385		; forward if set to GET-BIT
			
	djnz	L0350		; loop back to BREAK-3
			
	pop	AF		; drop the return address.
	cp	D		; ugh.
			
;; RESTART
L0361:	jp	NC,L03E5	; jump forward to INITIAL if D is zero
				; to reset the system
				; if the tape signal has timed out for example
				; if the tape is stopped. Not just a simple
				; report as some system variables will have
				; been overwritten.
			
	ld	H,D		; else transfer the start of name
	ld	L,E		; to the HL register
			
;; IN-NAME
L0366:	call	L034C		; routine IN-BYTE is sort of recursion for name
				; part. received byte in C.
	bit	7,D		; is name the null string ?
	ld	A,C		; transfer byte to A.
	jr	NZ,L0371	; forward with null string to MATCHING
			
	cp	(HL)		; else compare with string in memory.
	jr	NZ,L0347	; back with mis-match to NEXT-PROG
				; (seemingly out of subroutine but return
				; address has been dropped).
			
			
;; MATCHING
L0371:	inc	HL		; address next character of name
	rla			; test for inverted bit.
	jr	NC,L0366	; back if not to IN-NAME
			
; the name has been matched in full.
; proceed to load the data but first increment the high byte of E_LINE, which
; is one of the system variables to be loaded in. Since the low byte is loaded
; before the high byte, it is possible that, at the in-between stage, a false
; value could cause the load to end prematurely - see  LOAD/SAVE check.
			
	inc	0x15(IY)	; increment system variable E_LINE_hi.
	ld	HL,#0x4009	; start loading at system variable VERSN.
			
;; IN-PROG
L037B:	ld	D,B		; set D to zero as indicator.
	call	L034C		; routine IN-BYTE loads a byte
	ld	(HL),C		; insert assembled byte in memory.
	call	L01FC		; routine LOAD/SAVE                     >>
	jr	L037B		; loop back to IN-PROG
			
; ---
			
; this branch assembles a full byte before exiting normally
; from the IN-BYTE subroutine.
			
;; GET-BIT
L0385:	push	DE		; save the
	ld	E,#0x94		; timing value.
			
;; TRAILER
L0388:	ld	B,#0x1A		; counter to twenty six.
			
;; COUNTER
L038A:	dec	E		; decrement the measuring timer.
	in	A,(0xFE)	; read the
	rla			;
	bit	7,E		;
	ld	A,E		;
	jr	C,L0388		; loop back with carry to TRAILER
			
	djnz	L038A		; to COUNTER
			
	pop	DE		;
	jr	NZ,L039C	; to BIT-DONE
			
	cp	#0x56		;
	jr	NC,L034E	; to NEXT-BIT
			
;; BIT-DONE
L039C:	ccf			; complement carry flag
	rl	C		;
	jr	NC,L034E	; to NEXT-BIT
			
	ret			; return with full byte.
			
; ---
			
; if break is pressed while loading data then perform a reset.
; if break pressed while waiting for program on tape then OK to break.
			
;; BREAK-4
L03A2:	ld	A,D		; transfer indicator to A.
	and	A		; test for zero.
	jr	Z,L0361		; back if so to RESTART
			
			
;; REPORT-D
L03A6:	rst	#0x08		; ERROR-1
	.db	0x0C		; Error Report: BREAK - CONT repeats
			
; -----------------------------
; THE 'PROGRAM NAME' SUBROUTINE
; -----------------------------
;
;
			
;; NAME
L03A8:	call	L0F55		; routine SCANNING
	ld	A,(0x4001)	; sv FLAGS
	add	A,A		;
	jp	M,L0D9A		; to REPORT-C
			
	pop	HL		;
	ret	NC		;
			
	push	HL		;
	call	L02E7		; routine SET-FAST
	call	L13F8		; routine STK-FETCH
	ld	H,D		;
	ld	L,E		;
	dec	C		;
	ret	M		;
			
	add	HL,BC		;
	set	7,(HL)		;
	ret			;
			
; -------------------------
; THE 'NEW' COMMAND ROUTINE
; -------------------------
;
;
			
;; NEW
L03C3:	call	L02E7		; routine SET-FAST
	ld	BC,(0x4004)	; fetch value of system variable RAMTOP
	dec	BC		; point to last system byte.
			
; -----------------------
; THE 'RAM CHECK' ROUTINE
; -----------------------
;
;
			
;; RAM-CHECK
L03CB:	ld	H,B		;
	ld	L,C		;
	ld	A,#0x3F		;
			
;; RAM-FILL
L03CF:	ld	(HL),#0x02	;
	dec	HL		;
	cp	H		;
	jr	NZ,L03CF	; to RAM-FILL
			
;; RAM-READ
L03D5:	and	A		;
	sbc	HL,BC		;
	add	HL,BC		;
	inc	HL		;
	jr	NC,L03E2	; to SET-TOP
			
	dec	(HL)		;
	jr	Z,L03E2		; to SET-TOP
			
	dec	(HL)		;
	jr	Z,L03D5		; to RAM-READ
			
;; SET-TOP
L03E2:	ld	(0x4004),HL	; set system variable RAMTOP to first byte
				; above the BASIC system area.
			
; ----------------------------
; THE 'INITIALIZATION' ROUTINE
; ----------------------------
;
;
			
;; INITIAL
L03E5:	ld	HL,(0x4004)	; fetch system variable RAMTOP.
	dec	HL		; point to last system byte.
	ld	(HL),#0x3E	; make GO SUB end-marker $3E - too high for
				; high order byte of line number.
				; (was $3F on ZX80)
	dec	HL		; point to unimportant low-order byte.
	ld	SP,HL		; and initialize the stack-pointer to this
				; location.
	dec	HL		; point to first location on the machine stack
	dec	HL		; which will be filled by next CALL/PUSH.
	ld	(0x4002),HL	; set the error stack pointer ERR_SP to
				; the base of the now empty machine stack.
			
; Now set the I register so that the video hardware knows where to find the
; character set. This ROM only uses the character set when printing to
; the ZX Printer. The TV picture is formed by the external video hardware.
; Consider also, that this 8K ROM can be retro-fitted to the ZX80 instead of
; its original 4K ROM so the video hardware could be on the ZX80.
			
	ld	A,#0x1E		; address for this ROM is $1E00.
	ld	I,A		; set I register from A.
	im	1		; select Z80 Interrupt Mode 1.
			
	ld	IY,#0x4000	; set IY to the start of RAM so that the
				; system variables can be indexed.
	ld	0x3B(IY),#0x40	; set CDFLAG 0100 0000. Bit 6 indicates
				; Compute nad Display required.
			
	ld	HL,#0x407D	; The first location after System Variables -
				; 16509 decimal.
	ld	(0x400C),HL	; set system variable D_FILE to this value.
	ld	B,#0x19		; prepare minimal screen of 24 NEWLINEs
				; following an initial NEWLINE.
			
;; LINE
L0408:	ld	(HL),#0x76	; insert NEWLINE (HALT instruction)
	inc	HL		; point to next location.
	djnz	L0408		; loop back for all twenty five to LINE
			
	ld	(0x4010),HL	; set system variable VARS to next location
			
	call	L149A		; routine CLEAR sets $80 end-marker and the
				; dynamic memory pointers E_LINE, STKBOT and
				; STKEND.
			
;; N/L-ONLY
L0413:	call	L14AD		; routine CURSOR-IN inserts the cursor and
				; end-marker in the Edit Line also setting
				; size of lower display to two lines.
			
	call	L0207		; routine SLOW/FAST selects COMPUTE and DISPLAY
			
; ---------------------------
; THE 'BASIC LISTING' SECTION
; ---------------------------
;
;
			
;; UPPER
L0419:	call	L0A2A		; routine CLS
	ld	HL,(0x400A)	; sv E_PPC_lo
	ld	DE,(0x4023)	; sv S_TOP_lo
	and	A		;
	sbc	HL,DE		;
	ex	DE,HL		;
	jr	NC,L042D	; to ADDR-TOP
			
	add	HL,DE		;
	ld	(0x4023),HL	; sv S_TOP_lo
			
;; ADDR-TOP
L042D:	call	L09D8		; routine LINE-ADDR
	jr	Z,L0433		; to LIST-TOP
			
	ex	DE,HL		;
			
;; LIST-TOP
L0433:	call	L073E		; routine LIST-PROG
	dec	0x1E(IY)	; sv BERG
	jr	NZ,L0472	; to LOWER
			
	ld	HL,(0x400A)	; sv E_PPC_lo
	call	L09D8		; routine LINE-ADDR
	ld	HL,(0x4016)	; sv CH_ADD_lo
	scf			; Set Carry Flag
	sbc	HL,DE		;
	ld	HL,#0x4023	; sv S_TOP_lo
	jr	NC,L0457	; to INC-LINE
			
	ex	DE,HL		;
	ld	A,(HL)		;
	inc	HL		;
	ldi			;
	ld	(DE),A		;
	jr	L0419		; to UPPER
			
; ---
			
;; DOWN-KEY
L0454:	ld	HL,#0x400A	; sv E_PPC_lo
			
;; INC-LINE
L0457:	ld	E,(HL)		;
	inc	HL		;
	ld	D,(HL)		;
	push	HL		;
	ex	DE,HL		;
	inc	HL		;
	call	L09D8		; routine LINE-ADDR
	call	L05BB		; routine LINE-NO
	pop	HL		;
			
;; KEY-INPUT
L0464:	bit	5,0x2D(IY)	; sv FLAGX
	jr	NZ,L0472	; forward to LOWER
			
	ld	(HL),D		;
	dec	HL		;
	ld	(HL),E		;
	jr	L0419		; to UPPER
			
; ----------------------------
; THE 'EDIT LINE COPY' SECTION
; ----------------------------
; This routine sets the edit line to just the cursor when
; 1) There is not enough memory to edit a BASIC line.
; 2) The edit key is used during input.
; The entry point LOWER
			
			
;; EDIT-INP
L046F:	call	L14AD		; routine CURSOR-IN sets cursor only edit line.
			
; ->
			
;; LOWER
L0472:	ld	HL,(0x4014)	; fetch edit line start from E_LINE.
			
;; EACH-CHAR
L0475:	ld	A,(HL)		; fetch a character from edit line.
	cp	#0x7E		; compare to the number marker.
	jr	NZ,L0482	; forward if not to END-LINE
			
	ld	BC,#0x0006	; else six invisible bytes to be removed.
	call	L0A60		; routine RECLAIM-2
	jr	L0475		; back to EACH-CHAR
			
; ---
			
;; END-LINE
L0482:	cp	#0x76		;
	inc	HL		;
	jr	NZ,L0475	; to EACH-CHAR
			
;; EDIT-LINE
L0487:	call	L0537		; routine CURSOR sets cursor K or L.
			
;; EDIT-ROOM
L048A:	call	L0A1F		; routine LINE-ENDS
	ld	HL,(0x4014)	; sv E_LINE_lo
	ld	0x00(IY),#0xFF	; sv ERR_NR
	call	L0766		; routine COPY-LINE
	bit	7,0x00(IY)	; sv ERR_NR
	jr	NZ,L04C1	; to DISPLAY-6
			
	ld	A,(0x4022)	; sv DF_SZ
	cp	#0x18		;
	jr	NC,L04C1	; to DISPLAY-6
			
	inc	A		;
	ld	(0x4022),A	; sv DF_SZ
	ld	B,A		;
	ld	C,#0x01		;
	call	L0918		; routine LOC-ADDR
	ld	D,H		;
	ld	E,L		;
	ld	A,(HL)		;
			
;; FREE-LINE
L04B1:	dec	HL		;
	cp	(HL)		;
	jr	NZ,L04B1	; to FREE-LINE
			
	inc	HL		;
	ex	DE,HL		;
	ld	A,(0x4005)	; sv RAMTOP_hi
	cp	#0x4D		;
	call	C,L0A5D		; routine RECLAIM-1
	jr	L048A		; to EDIT-ROOM
			
; --------------------------
; THE 'WAIT FOR KEY' SECTION
; --------------------------
;
;
			
;; DISPLAY-6
L04C1:	ld	HL,#0x0000	;
	ld	(0x4018),HL	; sv X_PTR_lo
			
	ld	HL,#0x403B	; system variable CDFLAG
	bit	7,(HL)		;
			
	call	Z,L0229		; routine DISPLAY-1
			
;; SLOW-DISP
L04CF:	bit	0,(HL)		;
	jr	Z,L04CF		; to SLOW-DISP
			
	ld	BC,(0x4025)	; sv LAST_K
	call	L0F4B		; routine DEBOUNCE
	call	L07BD		; routine DECODE
			
	jr	NC,L0472	; back to LOWER
			
; -------------------------------
; THE 'KEYBOARD DECODING' SECTION
; -------------------------------
;   The decoded key value is in E and HL points to the position in the
;   key table. D contains zero.
			
;; K-DECODE
L04DF:	ld	A,(0x4006)	; Fetch value of system variable MODE
	dec	A		; test the three values together
			
	jp	M,L0508		; forward, if was zero, to FETCH-2
			
	jr	NZ,L04F7	; forward, if was 2, to FETCH-1
			
;   The original value was one and is now zero.
			
	ld	(0x4006),A	; update the system variable MODE
			
	dec	E		; reduce E to range $00 - $7F
	ld	A,E		; place in A
	sub	#0x27		; subtract 39 setting carry if range 00 - 38
	jr	C,L04F2		; forward, if so, to FUNC-BASE
			
	ld	E,A		; else set E to reduced value
			
;; FUNC-BASE
L04F2:	ld	HL,#L00CC	; address of K-FUNCT table for function keys.
	jr	L0505		; forward to TABLE-ADD
			
; ---
			
;; FETCH-1
L04F7:	ld	A,(HL)		;
	cp	#0x76		;
	jr	Z,L052B		; to K/L-KEY
			
	cp	#0x40		;
	set	7,A		;
	jr	C,L051B		; to ENTER
			
	ld	HL,#0x00C7	; (expr reqd)
			
;; TABLE-ADD
L0505:	add	HL,DE		;
	jr	L0515		; to FETCH-3
			
; ---
			
;; FETCH-2
L0508:	ld	A,(HL)		;
	bit	2,0x01(IY)	; sv FLAGS  - K or L mode ?
	jr	NZ,L0516	; to TEST-CURS
			
	add	A,#0xC0		;
	cp	#0xE6		;
	jr	NC,L0516	; to TEST-CURS
			
;; FETCH-3
L0515:	ld	A,(HL)		;
			
;; TEST-CURS
L0516:	cp	#0xF0		;
	jp	PE,L052D	; to KEY-SORT
			
;; ENTER
L051B:	ld	E,A		;
	call	L0537		; routine CURSOR
			
	ld	A,E		;
	call	L0526		; routine ADD-CHAR
			
;; BACK-NEXT
L0523:	jp	L0472		; back to LOWER
			
; ------------------------------
; THE 'ADD CHARACTER' SUBROUTINE
; ------------------------------
;
;
			
;; ADD-CHAR
L0526:	call	L099B		; routine ONE-SPACE
	ld	(DE),A		;
	ret			;
			
; -------------------------
; THE 'CURSOR KEYS' ROUTINE
; -------------------------
;
;
			
;; K/L-KEY
L052B:	ld	A,#0x78		;
			
;; KEY-SORT
L052D:	ld	E,A		;
	ld	HL,#0x0482	; base address of ED-KEYS (exp reqd)
	add	HL,DE		;
	add	HL,DE		;
	ld	C,(HL)		;
	inc	HL		;
	ld	B,(HL)		;
	push	BC		;
			
;; CURSOR
L0537:	ld	HL,(0x4014)	; sv E_LINE_lo
	bit	5,0x2D(IY)	; sv FLAGX
	jr	NZ,L0556	; to L-MODE
			
;; K-MODE
L0540:	res	2,0x01(IY)	; sv FLAGS  - Signal use K mode
			
;; TEST-CHAR
L0544:	ld	A,(HL)		;
	cp	#0x7F		;
	ret	Z		; return
			
	inc	HL		;
	call	L07B4		; routine NUMBER
	jr	Z,L0544		; to TEST-CHAR
			
	cp	#0x26		;
	jr	C,L0544		; to TEST-CHAR
			
	cp	#0xDE		;
	jr	Z,L0540		; to K-MODE
			
;; L-MODE
L0556:	set	2,0x01(IY)	; sv FLAGS  - Signal use L mode
	jr	L0544		; to TEST-CHAR
			
; --------------------------
; THE 'CLEAR-ONE' SUBROUTINE
; --------------------------
;
;
			
;; CLEAR-ONE
L055C:	ld	BC,#0x0001	;
	jp	L0A60		; to RECLAIM-2
			
			
			
; ------------------------
; THE 'EDITING KEYS' TABLE
; ------------------------
;
;
			
;; ED-KEYS
L0562:	.dw	L059F		; Address: $059F; Address: UP-KEY
	.dw	L0454		; Address: $0454; Address: DOWN-KEY
	.dw	L0576		; Address: $0576; Address: LEFT-KEY
	.dw	L057F		; Address: $057F; Address: RIGHT-KEY
	.dw	L05AF		; Address: $05AF; Address: FUNCTION
	.dw	L05C4		; Address: $05C4; Address: EDIT-KEY
	.dw	L060C		; Address: $060C; Address: N/L-KEY
	.dw	L058B		; Address: $058B; Address: RUBOUT
	.dw	L05AF		; Address: $05AF; Address: FUNCTION
	.dw	L05AF		; Address: $05AF; Address: FUNCTION
			
			
; -------------------------
; THE 'CURSOR LEFT' ROUTINE
; -------------------------
;
;
			
;; LEFT-KEY
L0576:	call	L0593		; routine LEFT-EDGE
	ld	A,(HL)		;
	ld	(HL),#0x7F	;
	inc	HL		;
	jr	L0588		; to GET-CODE
			
; --------------------------
; THE 'CURSOR RIGHT' ROUTINE
; --------------------------
;
;
			
;; RIGHT-KEY
L057F:	inc	HL		;
	ld	A,(HL)		;
	cp	#0x76		;
	jr	Z,L059D		; to ENDED-2
			
	ld	(HL),#0x7F	;
	dec	HL		;
			
;; GET-CODE
L0588:	ld	(HL),A		;
			
;; ENDED-1
L0589:	jr	L0523		; to BACK-NEXT
			
; --------------------
; THE 'RUBOUT' ROUTINE
; --------------------
;
;
			
;; RUBOUT
L058B:	call	L0593		; routine LEFT-EDGE
	call	L055C		; routine CLEAR-ONE
	jr	L0589		; to ENDED-1
			
; ------------------------
; THE 'ED-EDGE' SUBROUTINE
; ------------------------
;
;
			
;; LEFT-EDGE
L0593:	dec	HL		;
	ld	DE,(0x4014)	; sv E_LINE_lo
	ld	A,(DE)		;
	cp	#0x7F		;
	ret	NZ		;
			
	pop	DE		;
			
;; ENDED-2
L059D:	jr	L0589		; to ENDED-1
			
; -----------------------
; THE 'CURSOR UP' ROUTINE
; -----------------------
;
;
			
;; UP-KEY
L059F:	ld	HL,(0x400A)	; sv E_PPC_lo
	call	L09D8		; routine LINE-ADDR
	ex	DE,HL		;
	call	L05BB		; routine LINE-NO
	ld	HL,#0x400B	; point to system variable E_PPC_hi
	jp	L0464		; jump back to KEY-INPUT
			
; --------------------------
; THE 'FUNCTION KEY' ROUTINE
; --------------------------
;
;
			
;; FUNCTION
L05AF:	ld	A,E		;
	and	#0x07		;
	ld	(0x4006),A	; sv MODE
	jr	L059D		; back to ENDED-2
			
; ------------------------------------
; THE 'COLLECT LINE NUMBER' SUBROUTINE
; ------------------------------------
;
;
			
;; ZERO-DE
L05B7:	ex	DE,HL		;
	ld	DE,#L04C1 + 1	; $04C2 - a location addressing two zeros.
			
; ->
			
;; LINE-NO
L05BB:	ld	A,(HL)		;
	and	#0xC0		;
	jr	NZ,L05B7	; to ZERO-DE
			
	ld	D,(HL)		;
	inc	HL		;
	ld	E,(HL)		;
	ret			;
			
; ----------------------
; THE 'EDIT KEY' ROUTINE
; ----------------------
;
;
			
;; EDIT-KEY
L05C4:	call	L0A1F		; routine LINE-ENDS clears lower display.
			
	ld	HL,#L046F	; Address: EDIT-INP
	push	HL		; ** is pushed as an error looping address.
			
	bit	5,0x2D(IY)	; test FLAGX
	ret	NZ		; indirect jump if in input mode
				; to L046F, EDIT-INP (begin again).
			
;
			
	ld	HL,(0x4014)	; fetch E_LINE
	ld	(0x400E),HL	; and use to update the screen cursor DF_CC
			
; so now RST $10 will print the line numbers to the edit line instead of screen.
; first make sure that no newline/out of screen can occur while sprinting the
; line numbers to the edit line.
			
	ld	HL,#0x1821	; prepare line 0, column 0.
	ld	(0x4039),HL	; update S_POSN with these dummy values.
			
	ld	HL,(0x400A)	; fetch current line from E_PPC may be a
				; non-existent line e.g. last line deleted.
	call	L09D8		; routine LINE-ADDR gets address or that of
				; the following line.
	call	L05BB		; routine LINE-NO gets line number if any in DE
				; leaving HL pointing at second low byte.
			
	ld	A,D		; test the line number for zero.
	or	E		;
	ret	Z		; return if no line number - no program to edit.
			
	dec	HL		; point to high byte.
	call	L0AA5		; routine OUT-NO writes number to edit line.
			
	inc	HL		; point to length bytes.
	ld	C,(HL)		; low byte to C.
	inc	HL		;
	ld	B,(HL)		; high byte to B.
			
	inc	HL		; point to first character in line.
	ld	DE,(0x400E)	; fetch display file cursor DF_CC
			
	ld	A,#0x7F		; prepare the cursor character.
	ld	(DE),A		; and insert in edit line.
	inc	DE		; increment intended destination.
			
	push	HL		; * save start of BASIC.
			
	ld	HL,#0x001D	; set an overhead of 29 bytes.
	add	HL,DE		; add in the address of cursor.
	add	HL,BC		; add the length of the line.
	sbc	HL,SP		; subtract the stack pointer.
			
	pop	HL		; * restore pointer to start of BASIC.
			
	ret	NC		; return if not enough room to L046F EDIT-INP.
				; the edit key appears not to work.
			
	ldir			; else copy bytes from program to edit line.
				; Note. hidden floating point forms are also
				; copied to edit line.
			
	ex	DE,HL		; transfer free location pointer to HL
			
	pop	DE		; ** remove address EDIT-INP from stack.
			
	call	L14A6		; routine SET-STK-B sets STKEND from HL.
			
	jr	L059D		; back to ENDED-2 and after 3 more jumps
				; to L0472, LOWER.
				; Note. The LOWER routine removes the hidden
				; floating-point numbers from the edit line.
			
; -------------------------
; THE 'NEWLINE KEY' ROUTINE
; -------------------------
;
;
			
;; N/L-KEY
L060C:	call	L0A1F		; routine LINE-ENDS
			
	ld	HL,#L0472	; prepare address: LOWER
			
	bit	5,0x2D(IY)	; sv FLAGX
	jr	NZ,L0629	; to NOW-SCAN
			
	ld	HL,(0x4014)	; sv E_LINE_lo
	ld	A,(HL)		;
	cp	#0xFF		;
	jr	Z,L0626		; to STK-UPPER
			
	call	L08E2		; routine CLEAR-PRB
	call	L0A2A		; routine CLS
			
;; STK-UPPER
L0626:	ld	HL,#L0419	; Address: UPPER
			
;; NOW-SCAN
L0629:	push	HL		; push routine address (LOWER or UPPER).
	call	L0CBA		; routine LINE-SCAN
	pop	HL		;
	call	L0537		; routine CURSOR
	call	L055C		; routine CLEAR-ONE
	call	L0A73		; routine E-LINE-NO
	jr	NZ,L064E	; to N/L-INP
			
	ld	A,B		;
	or	C		;
	jp	NZ,L06E0	; to N/L-LINE
			
	dec	BC		;
	dec	BC		;
	ld	(0x4007),BC	; sv PPC_lo
	ld	0x22(IY),#0x02	; sv DF_SZ
	ld	DE,(0x400C)	; sv D_FILE_lo
			
	jr	L0661		; forward to TEST-NULL
			
; ---
			
;; N/L-INP
L064E:	cp	#0x76		;
	jr	Z,L0664		; to N/L-NULL
			
	ld	BC,(0x4030)	; sv T_ADDR_lo
	call	L0918		; routine LOC-ADDR
	ld	DE,(0x4029)	; sv NXTLIN_lo
	ld	0x22(IY),#0x02	; sv DF_SZ
			
;; TEST-NULL
L0661:	rst	#0x18		; GET-CHAR
	cp	#0x76		;
			
;; N/L-NULL
L0664:	jp	Z,L0413		; to N/L-ONLY
			
	ld	0x01(IY),#0x80	; sv FLAGS
	ex	DE,HL		;
			
;; NEXT-LINE
L066C:	ld	(0x4029),HL	; sv NXTLIN_lo
	ex	DE,HL		;
	call	L004D		; routine TEMP-PTR-2
	call	L0CC1		; routine LINE-RUN
	res	1,0x01(IY)	; sv FLAGS  - Signal printer not in use
	ld	A,#0xC0		;
	ld	0x19(IY),A	; sv X_PTR_lo
	call	L14A3		; routine X-TEMP
	res	5,0x2D(IY)	; sv FLAGX
	bit	7,0x00(IY)	; sv ERR_NR
	jr	Z,L06AE		; to STOP-LINE
			
	ld	HL,(0x4029)	; sv NXTLIN_lo
	and	(HL)		;
	jr	NZ,L06AE	; to STOP-LINE
			
	ld	D,(HL)		;
	inc	HL		;
	ld	E,(HL)		;
	ld	(0x4007),DE	; sv PPC_lo
	inc	HL		;
	ld	E,(HL)		;
	inc	HL		;
	ld	D,(HL)		;
	inc	HL		;
	ex	DE,HL		;
	add	HL,DE		;
	call	L0F46		; routine BREAK-1
	jr	C,L066C		; to NEXT-LINE
			
	ld	HL,#0x4000	; sv ERR_NR
	bit	7,(HL)		;
	jr	Z,L06AE		; to STOP-LINE
			
	ld	(HL),#0x0C	;
			
;; STOP-LINE
L06AE:	bit	7,0x38(IY)	; sv PR_CC
	call	Z,L0871		; routine COPY-BUFF
	ld	BC,#0x0121	;
	call	L0918		; routine LOC-ADDR
	ld	A,(0x4000)	; sv ERR_NR
	ld	BC,(0x4007)	; sv PPC_lo
	inc	A		;
	jr	Z,L06D1		; to REPORT
			
	cp	#0x09		;
	jr	NZ,L06CA	; to CONTINUE
			
	inc	BC		;
			
;; CONTINUE
L06CA:	ld	(0x402B),BC	; sv OLDPPC_lo
	jr	NZ,L06D1	; to REPORT
			
	dec	BC		;
			
;; REPORT
L06D1:	call	L07EB		; routine OUT-CODE
	ld	A,#0x18		;
			
	rst	#0x10		; PRINT-A
	call	L0A98		; routine OUT-NUM
	call	L14AD		; routine CURSOR-IN
	jp	L04C1		; to DISPLAY-6
			
; ---
			
;; N/L-LINE
L06E0:	ld	(0x400A),BC	; sv E_PPC_lo
	ld	HL,(0x4016)	; sv CH_ADD_lo
	ex	DE,HL		;
	ld	HL,#L0413	; Address: N/L-ONLY
	push	HL		;
	ld	HL,(0x401A)	; sv STKBOT_lo
	sbc	HL,DE		;
	push	HL		;
	push	BC		;
	call	L02E7		; routine SET-FAST
	call	L0A2A		; routine CLS
	pop	HL		;
	call	L09D8		; routine LINE-ADDR
	jr	NZ,L0705	; to COPY-OVER
			
	call	L09F2		; routine NEXT-ONE
	call	L0A60		; routine RECLAIM-2
			
;; COPY-OVER
L0705:	pop	BC		;
	ld	A,C		;
	dec	A		;
	or	B		;
	ret	Z		;
			
	push	BC		;
	inc	BC		;
	inc	BC		;
	inc	BC		;
	inc	BC		;
	dec	HL		;
	call	L099E		; routine MAKE-ROOM
	call	L0207		; routine SLOW/FAST
	pop	BC		;
	push	BC		;
	inc	DE		;
	ld	HL,(0x401A)	; sv STKBOT_lo
	dec	HL		;
	lddr			; copy bytes
	ld	HL,(0x400A)	; sv E_PPC_lo
	ex	DE,HL		;
	pop	BC		;
	ld	(HL),B		;
	dec	HL		;
	ld	(HL),C		;
	dec	HL		;
	ld	(HL),E		;
	dec	HL		;
	ld	(HL),D		;
			
	ret			; return.
			
; ---------------------------------------
; THE 'LIST' AND 'LLIST' COMMAND ROUTINES
; ---------------------------------------
;
;
			
;; LLIST
L072C:	set	1,0x01(IY)	; sv FLAGS  - signal printer in use
			
;; LIST
L0730:	call	L0EA7		; routine FIND-INT
			
	ld	A,B		; fetch high byte of user-supplied line number.
	and	#0x3F		; and crudely limit to range 1-16383.
			
	ld	H,A		;
	ld	L,C		;
	ld	(0x400A),HL	; sv E_PPC_lo
	call	L09D8		; routine LINE-ADDR
			
;; LIST-PROG
L073E:	ld	E,#0x00		;
			
;; UNTIL-END
L0740:	call	L0745		; routine OUT-LINE lists one line of BASIC
				; making an early return when the screen is
				; full or the end of program is reached.    >>
	jr	L0740		; loop back to UNTIL-END
			
; -----------------------------------
; THE 'PRINT A BASIC LINE' SUBROUTINE
; -----------------------------------
;
;
			
;; OUT-LINE
L0745:	ld	BC,(0x400A)	; sv E_PPC_lo
	call	L09EA		; routine CP-LINES
	ld	D,#0x92		;
	jr	Z,L0755		; to TEST-END
			
	ld	DE,#0x0000	;
	rl	E		;
			
;; TEST-END
L0755:	ld	0x1E(IY),E	; sv BERG
	ld	A,(HL)		;
	cp	#0x40		;
	pop	BC		;
	ret	NC		;
			
	push	BC		;
	call	L0AA5		; routine OUT-NO
	inc	HL		;
	ld	A,D		;
			
	rst	#0x10		; PRINT-A
	inc	HL		;
	inc	HL		;
			
;; COPY-LINE
L0766:	ld	(0x4016),HL	; sv CH_ADD_lo
	set	0,0x01(IY)	; sv FLAGS  - Suppress leading space
			
;; MORE-LINE
L076D:	ld	BC,(0x4018)	; sv X_PTR_lo
	ld	HL,(0x4016)	; sv CH_ADD_lo
	and	A		;
	sbc	HL,BC		;
	jr	NZ,L077C	; to TEST-NUM
			
	ld	A,#0xB8		;
			
	rst	#0x10		; PRINT-A
			
;; TEST-NUM
L077C:	ld	HL,(0x4016)	; sv CH_ADD_lo
	ld	A,(HL)		;
	inc	HL		;
	call	L07B4		; routine NUMBER
	ld	(0x4016),HL	; sv CH_ADD_lo
	jr	Z,L076D		; to MORE-LINE
			
	cp	#0x7F		;
	jr	Z,L079D		; to OUT-CURS
			
	cp	#0x76		;
	jr	Z,L07EE		; to OUT-CH
			
	bit	6,A		;
	jr	Z,L079A		; to NOT-TOKEN
			
	call	L094B		; routine TOKENS
	jr	L076D		; to MORE-LINE
			
; ---
			
			
;; NOT-TOKEN
L079A:	rst	#0x10		; PRINT-A
	jr	L076D		; to MORE-LINE
			
; ---
			
;; OUT-CURS
L079D:	ld	A,(0x4006)	; Fetch value of system variable MODE
	ld	B,#0xAB		; Prepare an inverse [F] for function cursor.
			
	and	A		; Test for zero -
	jr	NZ,L07AA	; forward if not to FLAGS-2
			
	ld	A,(0x4001)	; Fetch system variable FLAGS.
	ld	B,#0xB0		; Prepare an inverse [K] for keyword cursor.
			
;; FLAGS-2
L07AA:	rra			; 00000?00 -> 000000?0
	rra			; 000000?0 -> 0000000?
	and	#0x01		; 0000000?    0000000x
			
	add	A,B		; Possibly [F] -> [G]  or  [K] -> [L]
			
	call	L07F5		; routine PRINT-SP prints character
	jr	L076D		; back to MORE-LINE
			
; -----------------------
; THE 'NUMBER' SUBROUTINE
; -----------------------
;
;
			
;; NUMBER
L07B4:	cp	#0x7E		;
	ret	NZ		;
			
	inc	HL		;
	inc	HL		;
	inc	HL		;
	inc	HL		;
	inc	HL		;
	ret			;
			
; --------------------------------
; THE 'KEYBOARD DECODE' SUBROUTINE
; --------------------------------
;
;
			
;; DECODE
L07BD:	ld	D,#0x00		;
	sra	B		;
	sbc	A,A		;
	or	#0x26		;
	ld	L,#0x05		;
	sub	L		;
			
;; KEY-LINE
L07C7:	add	A,L		;
	scf			; Set Carry Flag
	rr	C		;
	jr	C,L07C7		; to KEY-LINE
			
	inc	C		;
	ret	NZ		;
			
	ld	C,B		;
	dec	L		;
	ld	L,#0x01		;
	jr	NZ,L07C7	; to KEY-LINE
			
	ld	HL,#0x007D	; (expr reqd)
	ld	E,A		;
	add	HL,DE		;
	scf			; Set Carry Flag
	ret			;
			
; -------------------------
; THE 'PRINTING' SUBROUTINE
; -------------------------
;
;
			
;; LEAD-SP
L07DC:	ld	A,E		;
	and	A		;
	ret	M		;
			
	jr	L07F1		; to PRINT-CH
			
; ---
			
;; OUT-DIGIT
L07E1:	xor	A		;
			
;; DIGIT-INC
L07E2:	add	HL,BC		;
	inc	A		;
	jr	C,L07E2		; to DIGIT-INC
			
	sbc	HL,BC		;
	dec	A		;
	jr	Z,L07DC		; to LEAD-SP
			
;; OUT-CODE
L07EB:	ld	E,#0x1C		;
	add	A,E		;
			
;; OUT-CH
L07EE:	and	A		;
	jr	Z,L07F5		; to PRINT-SP
			
;; PRINT-CH
L07F1:	res	0,0x01(IY)	; update FLAGS - signal leading space permitted
			
;; PRINT-SP
L07F5:	exx			;
	push	HL		;
	bit	1,0x01(IY)	; test FLAGS - is printer in use ?
	jr	NZ,L0802	; to LPRINT-A
			
	call	L0808		; routine ENTER-CH
	jr	L0805		; to PRINT-EXX
			
; ---
			
;; LPRINT-A
L0802:	call	L0851		; routine LPRINT-CH
			
;; PRINT-EXX
L0805:	pop	HL		;
	exx			;
	ret			;
			
; ---
			
;; ENTER-CH
L0808:	ld	D,A		;
	ld	BC,(0x4039)	; sv S_POSN_x
	ld	A,C		;
	cp	#0x21		;
	jr	Z,L082C		; to TEST-LOW
			
;; TEST-N/L
L0812:	ld	A,#0x76		;
	cp	D		;
	jr	Z,L0847		; to WRITE-N/L
			
	ld	HL,(0x400E)	; sv DF_CC_lo
	cp	(HL)		;
	ld	A,D		;
	jr	NZ,L083E	; to WRITE-CH
			
	dec	C		;
	jr	NZ,L083A	; to EXPAND-1
			
	inc	HL		;
	ld	(0x400E),HL	; sv DF_CC_lo
	ld	C,#0x21		;
	dec	B		;
	ld	(0x4039),BC	; sv S_POSN_x
			
;; TEST-LOW
L082C:	ld	A,B		;
	cp	0x22(IY)	; sv DF_SZ
	jr	Z,L0835		; to REPORT-5
			
	and	A		;
	jr	NZ,L0812	; to TEST-N/L
			
;; REPORT-5
L0835:	ld	L,#0x04		; 'No more room on screen'
	jp	L0058		; to ERROR-3
			
; ---
			
;; EXPAND-1
L083A:	call	L099B		; routine ONE-SPACE
	ex	DE,HL		;
			
;; WRITE-CH
L083E:	ld	(HL),A		;
	inc	HL		;
	ld	(0x400E),HL	; sv DF_CC_lo
	dec	0x39(IY)	; sv S_POSN_x
	ret			;
			
; ---
			
;; WRITE-N/L
L0847:	ld	C,#0x21		;
	dec	B		;
	set	0,0x01(IY)	; sv FLAGS  - Suppress leading space
	jp	L0918		; to LOC-ADDR
			
; --------------------------
; THE 'LPRINT-CH' SUBROUTINE
; --------------------------
; This routine sends a character to the ZX-Printer placing the code for the
; character in the Printer Buffer.
; Note. PR-CC contains the low byte of the buffer address. The high order byte
; is always constant.
			
			
;; LPRINT-CH
L0851:	cp	#0x76		; compare to NEWLINE.
	jr	Z,L0871		; forward if so to COPY-BUFF
			
	ld	C,A		; take a copy of the character in C.
	ld	A,(0x4038)	; fetch print location from PR_CC
	and	#0x7F		; ignore bit 7 to form true position.
	cp	#0x5C		; compare to 33rd location
			
	ld	L,A		; form low-order byte.
	ld	H,#0x40		; the high-order byte is fixed.
			
	call	Z,L0871		; routine COPY-BUFF to send full buffer to
				; the printer if first 32 bytes full.
				; (this will reset HL to start.)
			
	ld	(HL),C		; place character at location.
	inc	L		; increment - will not cross a 256 boundary.
	ld	0x38(IY),L	; update system variable PR_CC
				; automatically resetting bit 7 to show that
				; the buffer is not empty.
	ret			; return.
			
; --------------------------
; THE 'COPY' COMMAND ROUTINE
; --------------------------
; The full character-mapped screen is copied to the ZX-Printer.
; All twenty-four text/graphic lines are printed.
			
;; COPY
L0869:	ld	D,#0x16		; prepare to copy twenty four text lines.
	ld	HL,(0x400C)	; set HL to start of display file from D_FILE.
	inc	HL		;
	jr	L0876		; forward to COPY*D
			
; ---
			
; A single character-mapped printer buffer is copied to the ZX-Printer.
			
;; COPY-BUFF
L0871:	ld	D,#0x01		; prepare to copy a single text line.
	ld	HL,#0x403C	; set HL to start of printer buffer PRBUFF.
			
; both paths converge here.
			
;; COPY*D
L0876:	call	L02E7		; routine SET-FAST
			
	push	BC		; *** preserve BC throughout.
				; a pending character may be present
				; in C from LPRINT-CH
			
;; COPY-LOOP
L087A:	push	HL		; save first character of line pointer. (*)
	xor	A		; clear accumulator.
	ld	E,A		; set pixel line count, range 0-7, to zero.
			
; this inner loop deals with each horizontal pixel line.
			
;; COPY-TIME
L087D:	out	(0xFB),A	; bit 2 reset starts the printer motor
				; with an inactive stylus - bit 7 reset.
	pop	HL		; pick up first character of line pointer (*)
				; on inner loop.
			
;; COPY-BRK
L0880:	call	L0F46		; routine BREAK-1
	jr	C,L088A		; forward with no keypress to COPY-CONT
			
; else A will hold 11111111 0
			
	rra			; 0111 1111
	out	(0xFB),A	; stop ZX printer motor, de-activate stylus.
			
;; REPORT-D2
L0888:	rst	#0x08		; ERROR-1
	.db	0x0C		; Error Report: BREAK - CONT repeats
			
; ---
			
;; COPY-CONT
L088A:	in	A,(0xFB)	; read from printer port.
	add	A,A		; test bit 6 and 7
	jp	M,L08DE		; jump forward with no printer to COPY-END
			
	jr	NC,L0880	; back if stylus not in position to COPY-BRK
			
	push	HL		; save first character of line pointer (*)
	push	DE		; ** preserve character line and pixel line.
			
	ld	A,D		; text line count to A?
	cp	#0x02		; sets carry if last line.
	sbc	A,A		; now $FF if last line else zero.
			
; now cleverly prepare a printer control mask setting bit 2 (later moved to 1)
; of D to slow printer for the last two pixel lines ( E = 6 and 7)
			
	and	E		; and with pixel line offset 0-7
	rlca			; shift to left.
	and	E		; and again.
	ld	D,A		; store control mask in D.
			
;; COPY-NEXT
L089C:	ld	C,(HL)		; load character from screen or buffer.
	ld	A,C		; save a copy in C for later inverse test.
	inc	HL		; update pointer for next time.
	cp	#0x76		; is character a NEWLINE ?
	jr	Z,L08C7		; forward, if so, to COPY-N/L
			
	push	HL		; * else preserve the character pointer.
			
	sla	A		; (?) multiply by two
	add	A,A		; multiply by four
	add	A,A		; multiply by eight
			
	ld	H,#0x0F		; load H with half the address of character set.
	rl	H		; now $1E or $1F (with carry)
	add	A,E		; add byte offset 0-7
	ld	L,A		; now HL addresses character source byte
			
	rl	C		; test character, setting carry if inverse.
	sbc	A,A		; accumulator now $00 if normal, $FF if inverse.
			
	xor	(HL)		; combine with bit pattern at end or ROM.
	ld	C,A		; transfer the byte to C.
	ld	B,#0x08		; count eight bits to output.
			
;; COPY-BITS
L08B5:	ld	A,D		; fetch speed control mask from D.
	rlc	C		; rotate a bit from output byte to carry.
	rra			; pick up in bit 7, speed bit to bit 1
	ld	H,A		; store aligned mask in H register.
			
;; COPY-WAIT
L08BA:	in	A,(0xFB)	; read the printer port
	rra			; test for alignment signal from encoder.
	jr	NC,L08BA	; loop if not present to COPY-WAIT
			
	ld	A,H		; control byte to A.
	out	(0xFB),A	; and output to printer port.
	djnz	L08B5		; loop for all eight bits to COPY-BITS
			
	pop	HL		; * restore character pointer.
	jr	L089C		; back for adjacent character line to COPY-NEXT
			
; ---
			
; A NEWLINE has been encountered either following a text line or as the
; first character of the screen or printer line.
			
;; COPY-N/L
L08C7:	in	A,(0xFB)	; read printer port.
	rra			; wait for encoder signal.
	jr	NC,L08C7	; loop back if not to COPY-N/L
			
	ld	A,D		; transfer speed mask to A.
	rrca			; rotate speed bit to bit 1.
				; bit 7, stylus control is reset.
	out	(0xFB),A	; set the printer speed.
			
	pop	DE		; ** restore character line and pixel line.
	inc	E		; increment pixel line 0-7.
	bit	3,E		; test if value eight reached.
	jr	Z,L087D		; back if not to COPY-TIME
			
; eight pixel lines, a text line have been completed.
			
	pop	BC		; lose the now redundant first character
				; pointer
	dec	D		; decrease text line count.
	jr	NZ,L087A	; back if not zero to COPY-LOOP
			
	ld	A,#0x04		; stop the already slowed printer motor.
	out	(0xFB),A	; output to printer port.
			
;; COPY-END
L08DE:	call	L0207		; routine SLOW/FAST
	pop	BC		; *** restore preserved BC.
			
; -------------------------------------
; THE 'CLEAR PRINTER BUFFER' SUBROUTINE
; -------------------------------------
; This subroutine sets 32 bytes of the printer buffer to zero (space) and
; the 33rd character is set to a NEWLINE.
; This occurs after the printer buffer is sent to the printer but in addition
; after the 24 lines of the screen are sent to the printer.
; Note. This is a logic error as the last operation does not involve the
; buffer at all. Logically one should be able to use
; 10 LPRINT "HELLO ";
; 20 COPY
; 30 LPRINT ; "WORLD"
; and expect to see the entire greeting emerge from the printer.
; Surprisingly this logic error was never discovered and although one can argue
; if the above is a bug, the repetition of this error on the Spectrum was most
; definitely a bug.
; Since the printer buffer is fixed at the end of the system variables, and
; the print position is in the range $3C - $5C, then bit 7 of the system
; variable is set to show the buffer is empty and automatically reset when
; the variable is updated with any print position - neat.
			
;; CLEAR-PRB
L08E2:	ld	HL,#0x405C	; address fixed end of PRBUFF
	ld	(HL),#0x76	; place a newline at last position.
	ld	B,#0x20		; prepare to blank 32 preceding characters.
			
;; PRB-BYTES
L08E9:	dec	HL		; decrement address - could be DEC L.
	ld	(HL),#0x00	; place a zero byte.
	djnz	L08E9		; loop for all thirty-two to PRB-BYTES
			
	ld	A,L		; fetch character print position.
	set	7,A		; signal the printer buffer is clear.
	ld	(0x4038),A	; update one-byte system variable PR_CC
	ret			; return.
			
; -------------------------
; THE 'PRINT AT' SUBROUTINE
; -------------------------
;
;
			
;; PRINT-AT
L08F5:	ld	A,#0x17		;
	sub	B		;
	jr	C,L0905		; to WRONG-VAL
			
;; TEST-VAL
L08FA:	cp	0x22(IY)	; sv DF_SZ
	jp	C,L0835		; to REPORT-5
			
	inc	A		;
	ld	B,A		;
	ld	A,#0x1F		;
	sub	C		;
			
;; WRONG-VAL
L0905:	jp	C,L0EAD		; to REPORT-B
			
	add	A,#0x02		;
	ld	C,A		;
			
;; SET-FIELD
L090B:	bit	1,0x01(IY)	; sv FLAGS  - Is printer in use
	jr	Z,L0918		; to LOC-ADDR
			
	ld	A,#0x5D		;
	sub	C		;
	ld	(0x4038),A	; sv PR_CC
	ret			;
			
; ----------------------------
; THE 'LOCATE ADDRESS' ROUTINE
; ----------------------------
;
;
			
;; LOC-ADDR
L0918:	ld	(0x4039),BC	; sv S_POSN_x
	ld	HL,(0x4010)	; sv VARS_lo
	ld	D,C		;
	ld	A,#0x22		;
	sub	C		;
	ld	C,A		;
	ld	A,#0x76		;
	inc	B		;
			
;; LOOK-BACK
L0927:	dec	HL		;
	cp	(HL)		;
	jr	NZ,L0927	; to LOOK-BACK
			
	djnz	L0927		; to LOOK-BACK
			
	inc	HL		;
	cpir			;
	dec	HL		;
	ld	(0x400E),HL	; sv DF_CC_lo
	scf			; Set Carry Flag
	ret	PO		;
			
	dec	D		;
	ret	Z		;
			
	push	BC		;
	call	L099E		; routine MAKE-ROOM
	pop	BC		;
	ld	B,C		;
	ld	H,D		;
	ld	L,E		;
			
;; EXPAND-2
L0940:	ld	(HL),#0x00	;
	dec	HL		;
	djnz	L0940		; to EXPAND-2
			
	ex	DE,HL		;
	inc	HL		;
	ld	(0x400E),HL	; sv DF_CC_lo
	ret			;
			
; ------------------------------
; THE 'EXPAND TOKENS' SUBROUTINE
; ------------------------------
;
;
			
;; TOKENS
L094B:	push	AF		;
	call	L0975		; routine TOKEN-ADD
	jr	NC,L0959	; to ALL-CHARS
			
	bit	0,0x01(IY)	; sv FLAGS  - Leading space if set
	jr	NZ,L0959	; to ALL-CHARS
			
	xor	A		;
			
	rst	#0x10		; PRINT-A
			
;; ALL-CHARS
L0959:	ld	A,(BC)		;
	and	#0x3F		;
			
	rst	#0x10		; PRINT-A
	ld	A,(BC)		;
	inc	BC		;
	add	A,A		;
	jr	NC,L0959	; to ALL-CHARS
			
	pop	BC		;
	bit	7,B		;
	ret	Z		;
			
	cp	#0x1A		;
	jr	Z,L096D		; to TRAIL-SP
			
	cp	#0x38		;
	ret	C		;
			
;; TRAIL-SP
L096D:	xor	A		;
	set	0,0x01(IY)	; sv FLAGS  - Suppress leading space
	jp	L07F5		; to PRINT-SP
			
; ---
			
;; TOKEN-ADD
L0975:	push	HL		;
	ld	HL,#L0111	; Address of TOKENS
	bit	7,A		;
	jr	Z,L097F		; to TEST-HIGH
			
	and	#0x3F		;
			
;; TEST-HIGH
L097F:	cp	#0x43		;
	jr	NC,L0993	; to FOUND
			
	ld	B,A		;
	inc	B		;
			
;; WORDS
L0985:	bit	7,(HL)		;
	inc	HL		;
	jr	Z,L0985		; to WORDS
			
	djnz	L0985		; to WORDS
			
	bit	6,A		;
	jr	NZ,L0992	; to COMP-FLAG
			
	cp	#0x18		;
			
;; COMP-FLAG
L0992:	ccf			; Complement Carry Flag
			
;; FOUND
L0993:	ld	B,H		;
	ld	C,L		;
	pop	HL		;
	ret	NC		;
			
	ld	A,(BC)		;
	add	A,#0xE4		;
	ret			;
			
; --------------------------
; THE 'ONE SPACE' SUBROUTINE
; --------------------------
;
;
			
;; ONE-SPACE
L099B:	ld	BC,#0x0001	;
			
; --------------------------
; THE 'MAKE ROOM' SUBROUTINE
; --------------------------
;
;
			
;; MAKE-ROOM
L099E:	push	HL		;
	call	L0EC5		; routine TEST-ROOM
	pop	HL		;
	call	L09AD		; routine POINTERS
	ld	HL,(0x401C)	; sv STKEND_lo
	ex	DE,HL		;
	lddr			; Copy Bytes
	ret			;
			
; -------------------------
; THE 'POINTERS' SUBROUTINE
; -------------------------
;
;
			
;; POINTERS
L09AD:	push	AF		;
	push	HL		;
	ld	HL,#0x400C	; sv D_FILE_lo
	ld	A,#0x09		;
			
;; NEXT-PTR
L09B4:	ld	E,(HL)		;
	inc	HL		;
	ld	D,(HL)		;
	ex	(SP),HL		;
	and	A		;
	sbc	HL,DE		;
	add	HL,DE		;
	ex	(SP),HL		;
	jr	NC,L09C8	; to PTR-DONE
			
	push	DE		;
	ex	DE,HL		;
	add	HL,BC		;
	ex	DE,HL		;
	ld	(HL),D		;
	dec	HL		;
	ld	(HL),E		;
	inc	HL		;
	pop	DE		;
			
;; PTR-DONE
L09C8:	inc	HL		;
	dec	A		;
	jr	NZ,L09B4	; to NEXT-PTR
			
	ex	DE,HL		;
	pop	DE		;
	pop	AF		;
	and	A		;
	sbc	HL,DE		;
	ld	B,H		;
	ld	C,L		;
	inc	BC		;
	add	HL,DE		;
	ex	DE,HL		;
	ret			;
			
; -----------------------------
; THE 'LINE ADDRESS' SUBROUTINE
; -----------------------------
;
;
			
;; LINE-ADDR
L09D8:	push	HL		;
	ld	HL,#0x407D	;
	ld	D,H		;
	ld	E,L		;
			
;; NEXT-TEST
L09DE:	pop	BC		;
	call	L09EA		; routine CP-LINES
	ret	NC		;
			
	push	BC		;
	call	L09F2		; routine NEXT-ONE
	ex	DE,HL		;
	jr	L09DE		; to NEXT-TEST
			
; -------------------------------------
; THE 'COMPARE LINE NUMBERS' SUBROUTINE
; -------------------------------------
;
;
			
;; CP-LINES
L09EA:	ld	A,(HL)		;
	cp	B		;
	ret	NZ		;
			
	inc	HL		;
	ld	A,(HL)		;
	dec	HL		;
	cp	C		;
	ret			;
			
; --------------------------------------
; THE 'NEXT LINE OR VARIABLE' SUBROUTINE
; --------------------------------------
;
;
			
;; NEXT-ONE
L09F2:	push	HL		;
	ld	A,(HL)		;
	cp	#0x40		;
	jr	C,L0A0F		; to LINES
			
	bit	5,A		;
	jr	Z,L0A10		; forward to NEXT-O-4
			
	add	A,A		;
	jp	M,L0A01		; to NEXT+FIVE
			
	ccf			; Complement Carry Flag
			
;; NEXT+FIVE
L0A01:	ld	BC,#0x0005	;
	jr	NC,L0A08	; to NEXT-LETT
			
	ld	C,#0x11		;
			
;; NEXT-LETT
L0A08:	rla			;
	inc	HL		;
	ld	A,(HL)		;
	jr	NC,L0A08	; to NEXT-LETT
			
	jr	L0A15		; to NEXT-ADD
			
; ---
			
;; LINES
L0A0F:	inc	HL		;
			
;; NEXT-O-4
L0A10:	inc	HL		;
	ld	C,(HL)		;
	inc	HL		;
	ld	B,(HL)		;
	inc	HL		;
			
;; NEXT-ADD
L0A15:	add	HL,BC		;
	pop	DE		;
			
; ---------------------------
; THE 'DIFFERENCE' SUBROUTINE
; ---------------------------
;
;
			
;; DIFFER
L0A17:	and	A		;
	sbc	HL,DE		;
	ld	B,H		;
	ld	C,L		;
	add	HL,DE		;
	ex	DE,HL		;
	ret			;
			
; --------------------------
; THE 'LINE-ENDS' SUBROUTINE
; --------------------------
;
;
			
;; LINE-ENDS
L0A1F:	ld	B,0x22(IY)	; sv DF_SZ
	push	BC		;
	call	L0A2C		; routine B-LINES
	pop	BC		;
	dec	B		;
	jr	L0A2C		; to B-LINES
			
; -------------------------
; THE 'CLS' COMMAND ROUTINE
; -------------------------
;
;
			
;; CLS
L0A2A:	ld	B,#0x18		;
			
;; B-LINES
L0A2C:	res	1,0x01(IY)	; sv FLAGS  - Signal printer not in use
	ld	C,#0x21		;
	push	BC		;
	call	L0918		; routine LOC-ADDR
	pop	BC		;
	ld	A,(0x4005)	; sv RAMTOP_hi
	cp	#0x4D		;
	jr	C,L0A52		; to COLLAPSED
			
	set	7,0x3A(IY)	; sv S_POSN_y
			
;; CLEAR-LOC
L0A42:	xor	A		; prepare a space
	call	L07F5		; routine PRINT-SP prints a space
	ld	HL,(0x4039)	; sv S_POSN_x
	ld	A,L		;
	or	H		;
	and	#0x7E		;
	jr	NZ,L0A42	; to CLEAR-LOC
			
	jp	L0918		; to LOC-ADDR
			
; ---
			
;; COLLAPSED
L0A52:	ld	D,H		;
	ld	E,L		;
	dec	HL		;
	ld	C,B		;
	ld	B,#0x00		;
	ldir			; Copy Bytes
	ld	HL,(0x4010)	; sv VARS_lo
			
; ----------------------------
; THE 'RECLAIMING' SUBROUTINES
; ----------------------------
;
;
			
;; RECLAIM-1
L0A5D:	call	L0A17		; routine DIFFER
			
;; RECLAIM-2
L0A60:	push	BC		;
	ld	A,B		;
	cpl			;
	ld	B,A		;
	ld	A,C		;
	cpl			;
	ld	C,A		;
	inc	BC		;
	call	L09AD		; routine POINTERS
	ex	DE,HL		;
	pop	HL		;
	add	HL,DE		;
	push	DE		;
	ldir			; Copy Bytes
	pop	HL		;
	ret			;
			
; ------------------------------
; THE 'E-LINE NUMBER' SUBROUTINE
; ------------------------------
;
;
			
;; E-LINE-NO
L0A73:	ld	HL,(0x4014)	; sv E_LINE_lo
	call	L004D		; routine TEMP-PTR-2
			
	rst	#0x18		; GET-CHAR
	bit	5,0x2D(IY)	; sv FLAGX
	ret	NZ		;
			
	ld	HL,#0x405D	; sv MEM-0-1st
	ld	(0x401C),HL	; sv STKEND_lo
	call	L1548		; routine INT-TO-FP
	call	L158A		; routine FP-TO-BC
	jr	C,L0A91		; to NO-NUMBER
			
	ld	HL,#0xD8F0	; value '-10000'
	add	HL,BC		;
			
;; NO-NUMBER
L0A91:	jp	C,L0D9A		; to REPORT-C
			
	cp	A		;
	jp	L14BC		; routine SET-MIN
			
; -------------------------------------------------
; THE 'REPORT AND LINE NUMBER' PRINTING SUBROUTINES
; -------------------------------------------------
;
;
			
;; OUT-NUM
L0A98:	push	DE		;
	push	HL		;
	xor	A		;
	bit	7,B		;
	jr	NZ,L0ABF	; to UNITS
			
	ld	H,B		;
	ld	L,C		;
	ld	E,#0xFF		;
	jr	L0AAD		; to THOUSAND
			
; ---
			
;; OUT-NO
L0AA5:	push	DE		;
	ld	D,(HL)		;
	inc	HL		;
	ld	E,(HL)		;
	push	HL		;
	ex	DE,HL		;
	ld	E,#0x00		; set E to leading space.
			
;; THOUSAND
L0AAD:	ld	BC,#0xFC18	;
	call	L07E1		; routine OUT-DIGIT
	ld	BC,#0xFF9C	;
	call	L07E1		; routine OUT-DIGIT
	ld	C,#0xF6		;
	call	L07E1		; routine OUT-DIGIT
	ld	A,L		;
			
;; UNITS
L0ABF:	call	L07EB		; routine OUT-CODE
	pop	HL		;
	pop	DE		;
	ret			;
			
; --------------------------
; THE 'UNSTACK-Z' SUBROUTINE
; --------------------------
; This subroutine is used to return early from a routine when checking syntax.
; On the ZX81 the same routines that execute commands also check the syntax
; on line entry. This enables precise placement of the error marker in a line
; that fails syntax.
; The sequence CALL SYNTAX-Z ; RET Z can be replaced by a call to this routine
; although it has not replaced every occurrence of the above two instructions.
; Even on the ZX-80 this routine was not fully utilized.
			
;; UNSTACK-Z
L0AC5:	call	L0DA6		; routine SYNTAX-Z resets the ZERO flag if
				; checking syntax.
	pop	HL		; drop the return address.
	ret	Z		; return to previous calling routine if
				; checking syntax.
			
	jp	(HL)		; else jump to the continuation address in
				; the calling routine as RET would have done.
			
; ----------------------------
; THE 'LPRINT' COMMAND ROUTINE
; ----------------------------
;
;
			
;; LPRINT
L0ACB:	set	1,0x01(IY)	; sv FLAGS  - Signal printer in use
			
; ---------------------------
; THE 'PRINT' COMMAND ROUTINE
; ---------------------------
;
;
			
;; PRINT
L0ACF:	ld	A,(HL)		;
	cp	#0x76		;
	jp	Z,L0B84		; to PRINT-END
			
;; PRINT-1
L0AD5:	sub	#0x1A		;
	adc	A,#0x00		;
	jr	Z,L0B44		; to SPACING
			
	cp	#0xA7		;
	jr	NZ,L0AFA	; to NOT-AT
			
			
	rst	#0x20		; NEXT-CHAR
	call	L0D92		; routine CLASS-6
	cp	#0x1A		;
	jp	NZ,L0D9A	; to REPORT-C
			
			
	rst	#0x20		; NEXT-CHAR
	call	L0D92		; routine CLASS-6
	call	L0B4E		; routine SYNTAX-ON
			
	rst	#0x28		;; FP-CALC
	.db	0x01		;;exchange
	.db	0x34		;;end-calc
			
	call	L0BF5		; routine STK-TO-BC
	call	L08F5		; routine PRINT-AT
	jr	L0B37		; to PRINT-ON
			
; ---
			
;; NOT-AT
L0AFA:	cp	#0xA8		;
	jr	NZ,L0B31	; to NOT-TAB
			
			
	rst	#0x20		; NEXT-CHAR
	call	L0D92		; routine CLASS-6
	call	L0B4E		; routine SYNTAX-ON
	call	L0C02		; routine STK-TO-A
	jp	NZ,L0EAD	; to REPORT-B
			
	and	#0x1F		;
	ld	C,A		;
	bit	1,0x01(IY)	; sv FLAGS  - Is printer in use
	jr	Z,L0B1E		; to TAB-TEST
			
	sub	0x38(IY)	; sv PR_CC
	set	7,A		;
	add	A,#0x3C		;
	call	NC,L0871	; routine COPY-BUFF
			
;; TAB-TEST
L0B1E:	add	A,0x39(IY)	; sv S_POSN_x
	cp	#0x21		;
	ld	A,(0x403A)	; sv S_POSN_y
	sbc	A,#0x01		;
	call	L08FA		; routine TEST-VAL
	set	0,0x01(IY)	; sv FLAGS  - Suppress leading space
	jr	L0B37		; to PRINT-ON
			
; ---
			
;; NOT-TAB
L0B31:	call	L0F55		; routine SCANNING
	call	L0B55		; routine PRINT-STK
			
;; PRINT-ON
L0B37:	rst	#0x18		; GET-CHAR
	sub	#0x1A		;
	adc	A,#0x00		;
	jr	Z,L0B44		; to SPACING
			
	call	L0D1D		; routine CHECK-END
	jp	L0B84		;;; to PRINT-END
			
; ---
			
;; SPACING
L0B44:	call	NC,L0B8B	; routine FIELD
			
	rst	#0x20		; NEXT-CHAR
	cp	#0x76		;
	ret	Z		;
			
	jp	L0AD5		;;; to PRINT-1
			
; ---
			
;; SYNTAX-ON
L0B4E:	call	L0DA6		; routine SYNTAX-Z
	ret	NZ		;
			
	pop	HL		;
	jr	L0B37		; to PRINT-ON
			
; ---
			
;; PRINT-STK
L0B55:	call	L0AC5		; routine UNSTACK-Z
	bit	6,0x01(IY)	; sv FLAGS  - Numeric or string result?
	call	Z,L13F8		; routine STK-FETCH
	jr	Z,L0B6B		; to PR-STR-4
			
	jp	L15DB		; jump forward to PRINT-FP
			
; ---
			
;; PR-STR-1
L0B64:	ld	A,#0x0B		;
			
;; PR-STR-2
L0B66:	rst	#0x10		; PRINT-A
			
;; PR-STR-3
L0B67:	ld	DE,(0x4018)	; sv X_PTR_lo
			
;; PR-STR-4
L0B6B:	ld	A,B		;
	or	C		;
	dec	BC		;
	ret	Z		;
			
	ld	A,(DE)		;
	inc	DE		;
	ld	(0x4018),DE	; sv X_PTR_lo
	bit	6,A		;
	jr	Z,L0B66		; to PR-STR-2
			
	cp	#0xC0		;
	jr	Z,L0B64		; to PR-STR-1
			
	push	BC		;
	call	L094B		; routine TOKENS
	pop	BC		;
	jr	L0B67		; to PR-STR-3
			
; ---
			
;; PRINT-END
L0B84:	call	L0AC5		; routine UNSTACK-Z
	ld	A,#0x76		;
			
	rst	#0x10		; PRINT-A
	ret			;
			
; ---
			
;; FIELD
L0B8B:	call	L0AC5		; routine UNSTACK-Z
	set	0,0x01(IY)	; sv FLAGS  - Suppress leading space
	xor	A		;
			
	rst	#0x10		; PRINT-A
	ld	BC,(0x4039)	; sv S_POSN_x
	ld	A,C		;
	bit	1,0x01(IY)	; sv FLAGS  - Is printer in use
	jr	Z,L0BA4		; to CENTRE
			
	ld	A,#0x5D		;
	sub	0x38(IY)	; sv PR_CC
			
;; CENTRE
L0BA4:	ld	C,#0x11		;
	cp	C		;
	jr	NC,L0BAB	; to RIGHT
			
	ld	C,#0x01		;
			
;; RIGHT
L0BAB:	call	L090B		; routine SET-FIELD
	ret			;
			
; --------------------------------------
; THE 'PLOT AND UNPLOT' COMMAND ROUTINES
; --------------------------------------
;
;
			
;; PLOT/UNP
L0BAF:	call	L0BF5		; routine STK-TO-BC
	ld	(0x4036),BC	; sv COORDS_x
	ld	A,#0x2B		;
	sub	B		;
	jp	C,L0EAD		; to REPORT-B
			
	ld	B,A		;
	ld	A,#0x01		;
	sra	B		;
	jr	NC,L0BC5	; to COLUMNS
			
	ld	A,#0x04		;
			
;; COLUMNS
L0BC5:	sra	C		;
	jr	NC,L0BCA	; to FIND-ADDR
			
	rlca			;
			
;; FIND-ADDR
L0BCA:	push	AF		;
	call	L08F5		; routine PRINT-AT
	ld	A,(HL)		;
	rlca			;
	cp	#0x10		;
	jr	NC,L0BDA	; to TABLE-PTR
			
	rrca			;
	jr	NC,L0BD9	; to SQ-SAVED
			
	xor	#0x8F		;
			
;; SQ-SAVED
L0BD9:	ld	B,A		;
			
;; TABLE-PTR
L0BDA:	ld	DE,#L0C9E	; Address: P-UNPLOT
	ld	A,(0x4030)	; sv T_ADDR_lo
	sub	E		;
	jp	M,L0BE9		; to PLOT
			
	pop	AF		;
	cpl			;
	and	B		;
	jr	L0BEB		; to UNPLOT
			
; ---
			
;; PLOT
L0BE9:	pop	AF		;
	or	B		;
			
;; UNPLOT
L0BEB:	cp	#0x08		;
	jr	C,L0BF1		; to PLOT-END
			
	xor	#0x8F		;
			
;; PLOT-END
L0BF1:	exx			;
			
	rst	#0x10		; PRINT-A
	exx			;
	ret			;
			
; ----------------------------
; THE 'STACK-TO-BC' SUBROUTINE
; ----------------------------
;
;
			
;; STK-TO-BC
L0BF5:	call	L0C02		; routine STK-TO-A
	ld	B,A		;
	push	BC		;
	call	L0C02		; routine STK-TO-A
	ld	E,C		;
	pop	BC		;
	ld	D,C		;
	ld	C,A		;
	ret			;
			
; ---------------------------
; THE 'STACK-TO-A' SUBROUTINE
; ---------------------------
;
;
			
;; STK-TO-A
L0C02:	call	L15CD		; routine FP-TO-A
	jp	C,L0EAD		; to REPORT-B
			
	ld	C,#0x01		;
	ret	Z		;
			
	ld	C,#0xFF		;
	ret			;
			
; -----------------------
; THE 'SCROLL' SUBROUTINE
; -----------------------
;
;
			
;; SCROLL
L0C0E:	ld	B,0x22(IY)	; sv DF_SZ
	ld	C,#0x21		;
	call	L0918		; routine LOC-ADDR
	call	L099B		; routine ONE-SPACE
	ld	A,(HL)		;
	ld	(DE),A		;
	inc	0x3A(IY)	; sv S_POSN_y
	ld	HL,(0x400C)	; sv D_FILE_lo
	inc	HL		;
	ld	D,H		;
	ld	E,L		;
	cpir			;
	jp	L0A5D		; to RECLAIM-1
			
; -------------------
; THE 'SYNTAX' TABLES
; -------------------
			
; i) The Offset table
			
;; offset-t
L0C29:	.db	L0CB4 - .	; 8B offset to; Address: P-LPRINT
	.db	L0CB7 - .	; 8D offset to; Address: P-LLIST
	.db	L0C58 - .	; 2D offset to; Address: P-STOP
	.db	L0CAB - .	; 7F offset to; Address: P-SLOW
	.db	L0CAE - .	; 81 offset to; Address: P-FAST
	.db	L0C77 - .	; 49 offset to; Address: P-NEW
	.db	L0CA4 - .	; 75 offset to; Address: P-SCROLL
	.db	L0C8F - .	; 5F offset to; Address: P-CONT
	.db	L0C71 - .	; 40 offset to; Address: P-DIM
	.db	L0C74 - .	; 42 offset to; Address: P-REM
	.db	L0C5E - .	; 2B offset to; Address: P-FOR
	.db	L0C4B - .	; 17 offset to; Address: P-GOTO
	.db	L0C54 - .	; 1F offset to; Address: P-GOSUB
	.db	L0C6D - .	; 37 offset to; Address: P-INPUT
	.db	L0C89 - .	; 52 offset to; Address: P-LOAD
	.db	L0C7D - .	; 45 offset to; Address: P-LIST
	.db	L0C48 - .	; 0F offset to; Address: P-LET
	.db	L0CA7 - .	; 6D offset to; Address: P-PAUSE
	.db	L0C66 - .	; 2B offset to; Address: P-NEXT
	.db	L0C80 - .	; 44 offset to; Address: P-POKE
	.db	L0C6A - .	; 2D offset to; Address: P-PRINT
	.db	L0C98 - .	; 5A offset to; Address: P-PLOT
	.db	L0C7A - .	; 3B offset to; Address: P-RUN
	.db	L0C8C - .	; 4C offset to; Address: P-SAVE
	.db	L0C86 - .	; 45 offset to; Address: P-RAND
	.db	L0C4F - .	; 0D offset to; Address: P-IF
	.db	L0C95 - .	; 52 offset to; Address: P-CLS
	.db	L0C9E - .	; 5A offset to; Address: P-UNPLOT
	.db	L0C92 - .	; 4D offset to; Address: P-CLEAR
	.db	L0C5B - .	; 15 offset to; Address: P-RETURN
	.db	L0CB1 - .	; 6A offset to; Address: P-COPY
			
; ii) The parameter table.
			
			
;; P-LET
L0C48:	.db	0x01		; Class-01 - A variable is required.
	.db	0x14		; Separator:  '='
	.db	0x02		; Class-02 - An expression, numeric or string,
				; must follow.
			
;; P-GOTO
L0C4B:	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x00		; Class-00 - No further operands.
	.dw	L0E81		; Address: $0E81; Address: GOTO
			
;; P-IF
L0C4F:	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0xDE		; Separator:  'THEN'
	.db	0x05		; Class-05 - Variable syntax checked entirely
				; by routine.
	.dw	L0DAB		; Address: $0DAB; Address: IF
			
;; P-GOSUB
L0C54:	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x00		; Class-00 - No further operands.
	.dw	L0EB5		; Address: $0EB5; Address: GOSUB
			
;; P-STOP
L0C58:	.db	0x00		; Class-00 - No further operands.
	.dw	L0CDC		; Address: $0CDC; Address: STOP
			
;; P-RETURN
L0C5B:	.db	0x00		; Class-00 - No further operands.
	.dw	L0ED8		; Address: $0ED8; Address: RETURN
			
;; P-FOR
L0C5E:	.db	0x04		; Class-04 - A single character variable must
				; follow.
	.db	0x14		; Separator:  '='
	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0xDF		; Separator:  'TO'
	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x05		; Class-05 - Variable syntax checked entirely
				; by routine.
	.dw	L0DB9		; Address: $0DB9; Address: FOR
			
;; P-NEXT
L0C66:	.db	0x04		; Class-04 - A single character variable must
				; follow.
	.db	0x00		; Class-00 - No further operands.
	.dw	L0E2E		; Address: $0E2E; Address: NEXT
			
;; P-PRINT
L0C6A:	.db	0x05		; Class-05 - Variable syntax checked entirely
				; by routine.
	.dw	L0ACF		; Address: $0ACF; Address: PRINT
			
;; P-INPUT
L0C6D:	.db	0x01		; Class-01 - A variable is required.
	.db	0x00		; Class-00 - No further operands.
	.dw	L0EE9		; Address: $0EE9; Address: INPUT
			
;; P-DIM
L0C71:	.db	0x05		; Class-05 - Variable syntax checked entirely
				; by routine.
	.dw	L1409		; Address: $1409; Address: DIM
			
;; P-REM
L0C74:	.db	0x05		; Class-05 - Variable syntax checked entirely
				; by routine.
	.dw	L0D6A		; Address: $0D6A; Address: REM
			
;; P-NEW
L0C77:	.db	0x00		; Class-00 - No further operands.
	.dw	L03C3		; Address: $03C3; Address: NEW
			
;; P-RUN
L0C7A:	.db	0x03		; Class-03 - A numeric expression may follow
				; else default to zero.
	.dw	L0EAF		; Address: $0EAF; Address: RUN
			
;; P-LIST
L0C7D:	.db	0x03		; Class-03 - A numeric expression may follow
				; else default to zero.
	.dw	L0730		; Address: $0730; Address: LIST
			
;; P-POKE
L0C80:	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x1A		; Separator:  ','
	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x00		; Class-00 - No further operands.
	.dw	L0E92		; Address: $0E92; Address: POKE
			
;; P-RAND
L0C86:	.db	0x03		; Class-03 - A numeric expression may follow
				; else default to zero.
	.dw	L0E6C		; Address: $0E6C; Address: RAND
			
;; P-LOAD
L0C89:	.db	0x05		; Class-05 - Variable syntax checked entirely
				; by routine.
	.dw	L0340		; Address: $0340; Address: LOAD
			
;; P-SAVE
L0C8C:	.db	0x05		; Class-05 - Variable syntax checked entirely
				; by routine.
	.dw	L02F6		; Address: $02F6; Address: SAVE
			
;; P-CONT
L0C8F:	.db	0x00		; Class-00 - No further operands.
	.dw	L0E7C		; Address: $0E7C; Address: CONT
			
;; P-CLEAR
L0C92:	.db	0x00		; Class-00 - No further operands.
	.dw	L149A		; Address: $149A; Address: CLEAR
			
;; P-CLS
L0C95:	.db	0x00		; Class-00 - No further operands.
	.dw	L0A2A		; Address: $0A2A; Address: CLS
			
;; P-PLOT
L0C98:	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x1A		; Separator:  ','
	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x00		; Class-00 - No further operands.
	.dw	L0BAF		; Address: $0BAF; Address: PLOT/UNP
			
;; P-UNPLOT
L0C9E:	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x1A		; Separator:  ','
	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x00		; Class-00 - No further operands.
	.dw	L0BAF		; Address: $0BAF; Address: PLOT/UNP
			
;; P-SCROLL
L0CA4:	.db	0x00		; Class-00 - No further operands.
	.dw	L0C0E		; Address: $0C0E; Address: SCROLL
			
;; P-PAUSE
L0CA7:	.db	0x06		; Class-06 - A numeric expression must follow.
	.db	0x00		; Class-00 - No further operands.
	.dw	L0F32		; Address: $0F32; Address: PAUSE
			
;; P-SLOW
L0CAB:	.db	0x00		; Class-00 - No further operands.
	.dw	L0F2B		; Address: $0F2B; Address: SLOW
			
;; P-FAST
L0CAE:	.db	0x00		; Class-00 - No further operands.
	.dw	L0F23		; Address: $0F23; Address: FAST
			
;; P-COPY
L0CB1:	.db	0x00		; Class-00 - No further operands.
	.dw	L0869		; Address: $0869; Address: COPY
			
;; P-LPRINT
L0CB4:	.db	0x05		; Class-05 - Variable syntax checked entirely
				; by routine.
	.dw	L0ACB		; Address: $0ACB; Address: LPRINT
			
;; P-LLIST
L0CB7:	.db	0x03		; Class-03 - A numeric expression may follow
				; else default to zero.
	.dw	L072C		; Address: $072C; Address: LLIST
			
			
; ---------------------------
; THE 'LINE SCANNING' ROUTINE
; ---------------------------
;
;
			
;; LINE-SCAN
L0CBA:	ld	0x01(IY),#0x01	; sv FLAGS
	call	L0A73		; routine E-LINE-NO
			
;; LINE-RUN
L0CC1:	call	L14BC		; routine SET-MIN
	ld	HL,#0x4000	; sv ERR_NR
	ld	(HL),#0xFF	;
	ld	HL,#0x402D	; sv FLAGX
	bit	5,(HL)		;
	jr	Z,L0CDE		; to LINE-NULL
			
	cp	#0xE3		; 'STOP' ?
	ld	A,(HL)		;
	jp	NZ,L0D6F	; to INPUT-REP
			
	call	L0DA6		; routine SYNTAX-Z
	ret	Z		;
			
			
	rst	#0x08		; ERROR-1
	.db	0x0C		; Error Report: BREAK - CONT repeats
			
			
; --------------------------
; THE 'STOP' COMMAND ROUTINE
; --------------------------
;
;
			
;; STOP
L0CDC:	rst	#0x08		; ERROR-1
	.db	0x08		; Error Report: STOP statement
			
; ---
			
; the interpretation of a line continues with a check for just spaces
; followed by a carriage return.
; The IF command also branches here with a true value to execute the
; statement after the THEN but the statement can be null so
; 10 IF 1 = 1 THEN
; passes syntax (on all ZX computers).
			
;; LINE-NULL
L0CDE:	rst	#0x18		; GET-CHAR
	ld	B,#0x00		; prepare to index - early.
	cp	#0x76		; compare to NEWLINE.
	ret	Z		; return if so.
			
	ld	C,A		; transfer character to C.
			
	rst	#0x20		; NEXT-CHAR advances.
	ld	A,C		; character to A
	sub	#0xE1		; subtract 'LPRINT' - lowest command.
	jr	C,L0D26		; forward if less to REPORT-C2
			
	ld	C,A		; reduced token to C
	ld	HL,#L0C29	; set HL to address of offset table.
	add	HL,BC		; index into offset table.
	ld	C,(HL)		; fetch offset
	add	HL,BC		; index into parameter table.
	jr	L0CF7		; to GET-PARAM
			
; ---
			
;; SCAN-LOOP
L0CF4:	ld	HL,(0x4030)	; sv T_ADDR_lo
			
; -> Entry Point to Scanning Loop
			
;; GET-PARAM
L0CF7:	ld	A,(HL)		;
	inc	HL		;
	ld	(0x4030),HL	; sv T_ADDR_lo
			
	ld	BC,#L0CF4	; Address: SCAN-LOOP
	push	BC		; is pushed on machine stack.
			
	ld	C,A		;
	cp	#0x0B		;
	jr	NC,L0D10	; to SEPARATOR
			
	ld	HL,#L0D16	; class-tbl - the address of the class table.
	ld	B,#0x00		;
	add	HL,BC		;
	ld	C,(HL)		;
	add	HL,BC		;
	push	HL		;
			
	rst	#0x18		; GET-CHAR
	ret			; indirect jump to class routine and
				; by subsequent RET to SCAN-LOOP.
			
; -----------------------
; THE 'SEPARATOR' ROUTINE
; -----------------------
			
;; SEPARATOR
L0D10:	rst	#0x18		; GET-CHAR
	cp	C		;
	jr	NZ,L0D26	; to REPORT-C2
				; 'Nonsense in BASIC'
			
	rst	#0x20		; NEXT-CHAR
	ret			; return
			
			
; -------------------------
; THE 'COMMAND CLASS' TABLE
; -------------------------
;
			
;; class-tbl
L0D16:	.db	L0D2D - .	; 17 offset to; Address: CLASS-0
	.db	L0D3C - .	; 25 offset to; Address: CLASS-1
	.db	L0D6B - .	; 53 offset to; Address: CLASS-2
	.db	L0D28 - .	; 0F offset to; Address: CLASS-3
	.db	L0D85 - .	; 6B offset to; Address: CLASS-4
	.db	L0D2E - .	; 13 offset to; Address: CLASS-5
	.db	L0D92 - .	; 76 offset to; Address: CLASS-6
			
			
; --------------------------
; THE 'CHECK END' SUBROUTINE
; --------------------------
; Check for end of statement and that no spurious characters occur after
; a correctly parsed statement. Since only one statement is allowed on each
; line, the only character that may follow a statement is a NEWLINE.
;
			
;; CHECK-END
L0D1D:	call	L0DA6		; routine SYNTAX-Z
	ret	NZ		; return in runtime.
			
	pop	BC		; else drop return address.
			
;; CHECK-2
L0D22:	ld	A,(HL)		; fetch character.
	cp	#0x76		; compare to NEWLINE.
	ret	Z		; return if so.
			
;; REPORT-C2
L0D26:	jr	L0D9A		; to REPORT-C
				; 'Nonsense in BASIC'
			
; --------------------------
; COMMAND CLASSES 03, 00, 05
; --------------------------
;
;
			
;; CLASS-3
L0D28:	cp	#0x76		;
	call	L0D9C		; routine NO-TO-STK
			
;; CLASS-0
L0D2D:	cp	A		;
			
;; CLASS-5
L0D2E:	pop	BC		;
	call	Z,L0D1D		; routine CHECK-END
	ex	DE,HL		;
	ld	HL,(0x4030)	; sv T_ADDR_lo
	ld	C,(HL)		;
	inc	HL		;
	ld	B,(HL)		;
	ex	DE,HL		;
			
;; CLASS-END
L0D3A:	push	BC		;
	ret			;
			
; ------------------------------
; COMMAND CLASSES 01, 02, 04, 06
; ------------------------------
;
;
			
;; CLASS-1
L0D3C:	call	L111C		; routine LOOK-VARS
			
;; CLASS-4-2
L0D3F:	ld	0x2D(IY),#0x00	; sv FLAGX
	jr	NC,L0D4D	; to SET-STK
			
	set	1,0x2D(IY)	; sv FLAGX
	jr	NZ,L0D63	; to SET-STRLN
			
			
;; REPORT-2
L0D4B:	rst	#0x08		; ERROR-1
	.db	0x01		; Error Report: Variable not found
			
; ---
			
;; SET-STK
L0D4D:	call	Z,L11A7		; routine STK-VAR
	bit	6,0x01(IY)	; sv FLAGS  - Numeric or string result?
	jr	NZ,L0D63	; to SET-STRLN
			
	xor	A		;
	call	L0DA6		; routine SYNTAX-Z
	call	NZ,L13F8	; routine STK-FETCH
	ld	HL,#0x402D	; sv FLAGX
	or	(HL)		;
	ld	(HL),A		;
	ex	DE,HL		;
			
;; SET-STRLN
L0D63:	ld	(0x402E),BC	; sv STRLEN_lo
	ld	(0x4012),HL	; sv DEST-lo
			
; THE 'REM' COMMAND ROUTINE
			
;; REM
L0D6A:	ret			;
			
; ---
			
;; CLASS-2
L0D6B:	pop	BC		;
	ld	A,(0x4001)	; sv FLAGS
			
;; INPUT-REP
L0D6F:	push	AF		;
	call	L0F55		; routine SCANNING
	pop	AF		;
	ld	BC,#L1321	; Address: LET
	ld	D,0x01(IY)	; sv FLAGS
	xor	D		;
	and	#0x40		;
	jr	NZ,L0D9A	; to REPORT-C
			
	bit	7,D		;
	jr	NZ,L0D3A	; to CLASS-END
			
	jr	L0D22		; to CHECK-2
			
; ---
			
;; CLASS-4
L0D85:	call	L111C		; routine LOOK-VARS
	push	AF		;
	ld	A,C		;
	or	#0x9F		;
	inc	A		;
	jr	NZ,L0D9A	; to REPORT-C
			
	pop	AF		;
	jr	L0D3F		; to CLASS-4-2
			
; ---
			
;; CLASS-6
L0D92:	call	L0F55		; routine SCANNING
	bit	6,0x01(IY)	; sv FLAGS  - Numeric or string result?
	ret	NZ		;
			
			
;; REPORT-C
L0D9A:	rst	#0x08		; ERROR-1
	.db	0x0B		; Error Report: Nonsense in BASIC
			
; --------------------------------
; THE 'NUMBER TO STACK' SUBROUTINE
; --------------------------------
;
;
			
;; NO-TO-STK
L0D9C:	jr	NZ,L0D92	; back to CLASS-6 with a non-zero number.
			
	call	L0DA6		; routine SYNTAX-Z
	ret	Z		; return if checking syntax.
			
; in runtime a zero default is placed on the calculator stack.
			
	rst	#0x28		;; FP-CALC
	.db	0xA0		;;stk-zero
	.db	0x34		;;end-calc
			
	ret			; return.
			
; -------------------------
; THE 'SYNTAX-Z' SUBROUTINE
; -------------------------
; This routine returns with zero flag set if checking syntax.
; Calling this routine uses three instruction bytes compared to four if the
; bit test is implemented inline.
			
;; SYNTAX-Z
L0DA6:	bit	7,0x01(IY)	; test FLAGS  - checking syntax only?
	ret			; return.
			
; ------------------------
; THE 'IF' COMMAND ROUTINE
; ------------------------
; In runtime, the class routines have evaluated the test expression and
; the result, true or false, is on the stack.
			
;; IF
L0DAB:	call	L0DA6		; routine SYNTAX-Z
	jr	Z,L0DB6		; forward if checking syntax to IF-END
			
; else delete the Boolean value on the calculator stack.
			
	rst	#0x28		;; FP-CALC
	.db	0x02		;;delete
	.db	0x34		;;end-calc
			
; register DE points to exponent of floating point value.
			
	ld	A,(DE)		; fetch exponent.
	and	A		; test for zero - FALSE.
	ret	Z		; return if so.
			
;; IF-END
L0DB6:	jp	L0CDE		; jump back to LINE-NULL
			
; -------------------------
; THE 'FOR' COMMAND ROUTINE
; -------------------------
;
;
			
;; FOR
L0DB9:	cp	#0xE0		; is current character 'STEP' ?
	jr	NZ,L0DC6	; forward if not to F-USE-ONE
			
			
	rst	#0x20		; NEXT-CHAR
	call	L0D92		; routine CLASS-6 stacks the number
	call	L0D1D		; routine CHECK-END
	jr	L0DCC		; forward to F-REORDER
			
; ---
			
;; F-USE-ONE
L0DC6:	call	L0D1D		; routine CHECK-END
			
	rst	#0x28		;; FP-CALC
	.db	0xA1		;;stk-one
	.db	0x34		;;end-calc
			
			
			
;; F-REORDER
L0DCC:	rst	#0x28		;; FP-CALC      v, l, s.
	.db	0xC0		;;st-mem-0      v, l, s.
	.db	0x02		;;delete        v, l.
	.db	0x01		;;exchange      l, v.
	.db	0xE0		;;get-mem-0     l, v, s.
	.db	0x01		;;exchange      l, s, v.
	.db	0x34		;;end-calc      l, s, v.
			
	call	L1321		; routine LET
			
	ld	(0x401F),HL	; set MEM to address variable.
	dec	HL		; point to letter.
	ld	A,(HL)		;
	set	7,(HL)		;
	ld	BC,#0x0006	;
	add	HL,BC		;
	rlca			;
	jr	C,L0DEA		; to F-LMT-STP
			
	sla	C		;
	call	L099E		; routine MAKE-ROOM
	inc	HL		;
			
;; F-LMT-STP
L0DEA:	push	HL		;
			
	rst	#0x28		;; FP-CALC
	.db	0x02		;;delete
	.db	0x02		;;delete
	.db	0x34		;;end-calc
			
	pop	HL		;
	ex	DE,HL		;
			
	ld	C,#0x0A		; ten bytes to be moved.
	ldir			; copy bytes
			
	ld	HL,(0x4007)	; set HL to system variable PPC current line.
	ex	DE,HL		; transfer to DE, variable pointer to HL.
	inc	DE		; loop start will be this line + 1 at least.
	ld	(HL),E		;
	inc	HL		;
	ld	(HL),D		;
	call	L0E5A		; routine NEXT-LOOP considers an initial pass.
	ret	NC		; return if possible.
			
; else program continues from point following matching NEXT.
			
	bit	7,0x08(IY)	; test PPC_hi
	ret	NZ		; return if over 32767 ???
			
	ld	B,0x2E(IY)	; fetch variable name from STRLEN_lo
	res	6,B		; make a true letter.
	ld	HL,(0x4029)	; set HL from NXTLIN
			
; now enter a loop to look for matching next.
			
;; NXTLIN-NO
L0E0E:	ld	A,(HL)		; fetch high byte of line number.
	and	#0xC0		; mask off low bits $3F
	jr	NZ,L0E2A	; forward at end of program to FOR-END
			
	push	BC		; save letter
	call	L09F2		; routine NEXT-ONE finds next line.
	pop	BC		; restore letter
			
	inc	HL		; step past low byte
	inc	HL		; past the
	inc	HL		; line length.
	call	L004C		; routine TEMP-PTR1 sets CH_ADD
			
	rst	#0x18		; GET-CHAR
	cp	#0xF3		; compare to 'NEXT'.
	ex	DE,HL		; next line to HL.
	jr	NZ,L0E0E	; back with no match to NXTLIN-NO
			
;
			
	ex	DE,HL		; restore pointer.
			
	rst	#0x20		; NEXT-CHAR advances and gets letter in A.
	ex	DE,HL		; save pointer
	cp	B		; compare to variable name.
	jr	NZ,L0E0E	; back with mismatch to NXTLIN-NO
			
;; FOR-END
L0E2A:	ld	(0x4029),HL	; update system variable NXTLIN
	ret			; return.
			
; --------------------------
; THE 'NEXT' COMMAND ROUTINE
; --------------------------
;
;
			
;; NEXT
L0E2E:	bit	1,0x2D(IY)	; sv FLAGX
	jp	NZ,L0D4B	; to REPORT-2
			
	ld	HL,(0x4012)	; DEST
	bit	7,(HL)		;
	jr	Z,L0E58		; to REPORT-1
			
	inc	HL		;
	ld	(0x401F),HL	; sv MEM_lo
			
	rst	#0x28		;; FP-CALC
	.db	0xE0		;;get-mem-0
	.db	0xE2		;;get-mem-2
	.db	0x0F		;;addition
	.db	0xC0		;;st-mem-0
	.db	0x02		;;delete
	.db	0x34		;;end-calc
			
	call	L0E5A		; routine NEXT-LOOP
	ret	C		;
			
	ld	HL,(0x401F)	; sv MEM_lo
	ld	DE,#0x000F	;
	add	HL,DE		;
	ld	E,(HL)		;
	inc	HL		;
	ld	D,(HL)		;
	ex	DE,HL		;
	jr	L0E86		; to GOTO-2
			
; ---
			
			
;; REPORT-1
L0E58:	rst	#0x08		; ERROR-1
	.db	0x00		; Error Report: NEXT without FOR
			
			
; --------------------------
; THE 'NEXT-LOOP' SUBROUTINE
; --------------------------
;
;
			
;; NEXT-LOOP
L0E5A:	rst	#0x28		;; FP-CALC
	.db	0xE1		;;get-mem-1
	.db	0xE0		;;get-mem-0
	.db	0xE2		;;get-mem-2
	.db	0x32		;;less-0
	.db	0x00		;;jump-true
	.db	0x02		;;to L0E62, LMT-V-VAL
			
	.db	0x01		;;exchange
			
;; LMT-V-VAL
L0E62:	.db	0x03		;;subtract
	.db	0x33		;;greater-0
	.db	0x00		;;jump-true
	.db	0x04		;;to L0E69, IMPOSS
			
	.db	0x34		;;end-calc
			
	and	A		; clear carry flag
	ret			; return.
			
; ---
			
			
;; IMPOSS
L0E69:	.db	0x34		;;end-calc
			
	scf			; set carry flag
	ret			; return.
			
; --------------------------
; THE 'RAND' COMMAND ROUTINE
; --------------------------
; The keyword was 'RANDOMISE' on the ZX80, is 'RAND' here on the ZX81 and
; becomes 'RANDOMIZE' on the ZX Spectrum.
; In all invocations the procedure is the same - to set the SEED system variable
; with a supplied integer value or to use a time-based value if no number, or
; zero, is supplied.
			
;; RAND
L0E6C:	call	L0EA7		; routine FIND-INT
	ld	A,B		; test value
	or	C		; for zero
	jr	NZ,L0E77	; forward if not zero to SET-SEED
			
	ld	BC,(0x4034)	; fetch value of FRAMES system variable.
			
;; SET-SEED
L0E77:	ld	(0x4032),BC	; update the SEED system variable.
	ret			; return.
			
; --------------------------
; THE 'CONT' COMMAND ROUTINE
; --------------------------
; Another abbreviated command. ROM space was really tight.
; CONTINUE at the line number that was set when break was pressed.
; Sometimes the current line, sometimes the next line.
			
;; CONT
L0E7C:	ld	HL,(0x402B)	; set HL from system variable OLDPPC
	jr	L0E86		; forward to GOTO-2
			
; --------------------------
; THE 'GOTO' COMMAND ROUTINE
; --------------------------
; This token also suffered from the shortage of room and there is no space
; getween GO and TO as there is on the ZX80 and ZX Spectrum. The same also
; applies to the GOSUB keyword.
			
;; GOTO
L0E81:	call	L0EA7		; routine FIND-INT
	ld	H,B		;
	ld	L,C		;
			
;; GOTO-2
L0E86:	ld	A,H		;
	cp	#0xF0		;
	jr	NC,L0EAD	; to REPORT-B
			
	call	L09D8		; routine LINE-ADDR
	ld	(0x4029),HL	; sv NXTLIN_lo
	ret			;
			
; --------------------------
; THE 'POKE' COMMAND ROUTINE
; --------------------------
;
;
			
;; POKE
L0E92:	call	L15CD		; routine FP-TO-A
	jr	C,L0EAD		; forward, with overflow, to REPORT-B
			
	jr	Z,L0E9B		; forward, if positive, to POKE-SAVE
			
	neg			; negate
			
;; POKE-SAVE
L0E9B:	push	AF		; preserve value.
	call	L0EA7		; routine FIND-INT gets address in BC
				; invoking the error routine with overflow
				; or a negative number.
	pop	AF		; restore value.
			
; Note. the next two instructions are legacy code from the ZX80 and
; inappropriate here.
			
	bit	7,0x00(IY)	; test ERR_NR - is it still $FF ?
	ret	Z		; return with error.
			
	ld	(BC),A		; update the address contents.
	ret			; return.
			
; -----------------------------
; THE 'FIND INTEGER' SUBROUTINE
; -----------------------------
;
;
			
;; FIND-INT
L0EA7:	call	L158A		; routine FP-TO-BC
	jr	C,L0EAD		; forward with overflow to REPORT-B
			
	ret	Z		; return if positive (0-65535).
			
			
;; REPORT-B
L0EAD:	rst	#0x08		; ERROR-1
	.db	0x0A		; Error Report: Integer out of range
			
; -------------------------
; THE 'RUN' COMMAND ROUTINE
; -------------------------
;
;
			
;; RUN
L0EAF:	call	L0E81		; routine GOTO
	jp	L149A		; to CLEAR
			
; ---------------------------
; THE 'GOSUB' COMMAND ROUTINE
; ---------------------------
;
;
			
;; GOSUB
L0EB5:	ld	HL,(0x4007)	; sv PPC_lo
	inc	HL		;
	ex	(SP),HL		;
	push	HL		;
	ld	(0x4002),SP	; set the error stack pointer - ERR_SP
	call	L0E81		; routine GOTO
	ld	BC,#0x0006	;
			
; --------------------------
; THE 'TEST ROOM' SUBROUTINE
; --------------------------
;
;
			
;; TEST-ROOM
L0EC5:	ld	HL,(0x401C)	; sv STKEND_lo
	add	HL,BC		;
	jr	C,L0ED3		; to REPORT-4
			
	ex	DE,HL		;
	ld	HL,#0x0024	;
	add	HL,DE		;
	sbc	HL,SP		;
	ret	C		;
			
;; REPORT-4
L0ED3:	ld	L,#0x03		;
	jp	L0058		; to ERROR-3
			
; ----------------------------
; THE 'RETURN' COMMAND ROUTINE
; ----------------------------
;
;
			
;; RETURN
L0ED8:	pop	HL		;
	ex	(SP),HL		;
	ld	A,H		;
	cp	#0x3E		;
	jr	Z,L0EE5		; to REPORT-7
			
	ld	(0x4002),SP	; sv ERR_SP_lo
	jr	L0E86		; back to GOTO-2
			
; ---
			
;; REPORT-7
L0EE5:	ex	(SP),HL		;
	push	HL		;
			
	rst	#0x08		; ERROR-1
	.db	0x06		; Error Report: RETURN without GOSUB
			
; ---------------------------
; THE 'INPUT' COMMAND ROUTINE
; ---------------------------
;
;
			
;; INPUT
L0EE9:	bit	7,0x08(IY)	; sv PPC_hi
	jr	NZ,L0F21	; to REPORT-8
			
	call	L14A3		; routine X-TEMP
	ld	HL,#0x402D	; sv FLAGX
	set	5,(HL)		;
	res	6,(HL)		;
	ld	A,(0x4001)	; sv FLAGS
	and	#0x40		;
	ld	BC,#0x0002	;
	jr	NZ,L0F05	; to PROMPT
			
	ld	C,#0x04		;
			
;; PROMPT
L0F05:	or	(HL)		;
	ld	(HL),A		;
			
	rst	#0x30		; BC-SPACES
	ld	(HL),#0x76	;
	ld	A,C		;
	rrca			;
	rrca			;
	jr	C,L0F14		; to ENTER-CUR
			
	ld	A,#0x0B		;
	ld	(DE),A		;
	dec	HL		;
	ld	(HL),A		;
			
;; ENTER-CUR
L0F14:	dec	HL		;
	ld	(HL),#0x7F	;
	ld	HL,(0x4039)	; sv S_POSN_x
	ld	(0x4030),HL	; sv T_ADDR_lo
	pop	HL		;
	jp	L0472		; to LOWER
			
; ---
			
;; REPORT-8
L0F21:	rst	#0x08		; ERROR-1
	.db	0x07		; Error Report: End of file
			
; ---------------------------
; THE 'PAUSE' COMMAND ROUTINE
; ---------------------------
;
;
			
;; FAST
L0F23:	call	L02E7		; routine SET-FAST
	res	6,0x3B(IY)	; sv CDFLAG
	ret			; return.
			
; --------------------------
; THE 'SLOW' COMMAND ROUTINE
; --------------------------
;
;
			
;; SLOW
L0F2B:	set	6,0x3B(IY)	; sv CDFLAG
	jp	L0207		; to SLOW/FAST
			
; ---------------------------
; THE 'PAUSE' COMMAND ROUTINE
; ---------------------------
			
;; PAUSE
L0F32:	call	L0EA7		; routine FIND-INT
	call	L02E7		; routine SET-FAST
	ld	H,B		;
	ld	L,C		;
	call	L022D		; routine DISPLAY-P
			
	ld	0x35(IY),#0xFF	; sv FRAMES_hi
			
	call	L0207		; routine SLOW/FAST
	jr	L0F4B		; routine DEBOUNCE
			
; ----------------------
; THE 'BREAK' SUBROUTINE
; ----------------------
;
;
			
;; BREAK-1
L0F46:	ld	A,#0x7F		; read port $7FFE - keys B,N,M,.,SPACE.
	in	A,(0xFE)	;
	rra			; carry will be set if space not pressed.
			
; -------------------------
; THE 'DEBOUNCE' SUBROUTINE
; -------------------------
;
;
			
;; DEBOUNCE
L0F4B:	res	0,0x3B(IY)	; update system variable CDFLAG
	ld	A,#0xFF		;
	ld	(0x4027),A	; update system variable DEBOUNCE
	ret			; return.
			
			
; -------------------------
; THE 'SCANNING' SUBROUTINE
; -------------------------
; This recursive routine is where the ZX81 gets its power. Provided there is
; enough memory it can evaluate an expression of unlimited complexity.
; Note. there is no unary plus so, as on the ZX80, PRINT +1 gives a syntax error.
; PRINT +1 works on the Spectrum but so too does PRINT + "STRING".
			
;; SCANNING
L0F55:	rst	#0x18		; GET-CHAR
	ld	B,#0x00		; set B register to zero.
	push	BC		; stack zero as a priority end-marker.
			
;; S-LOOP-1
L0F59:	cp	#0x40		; compare to the 'RND' character
	jr	NZ,L0F8C	; forward, if not, to S-TEST-PI
			
; ------------------
; THE 'RND' FUNCTION
; ------------------
			
	call	L0DA6		; routine SYNTAX-Z
	jr	Z,L0F8A		; forward if checking syntax to S-JPI-END
			
	ld	BC,(0x4032)	; sv SEED_lo
	call	L1520		; routine STACK-BC
			
	rst	#0x28		;; FP-CALC
	.db	0xA1		;;stk-one
	.db	0x0F		;;addition
	.db	0x30		;;stk-data
	.db	0x37		;;Exponent: $87, Bytes: 1
	.db	0x16		;;(+00,+00,+00)
	.db	0x04		;;multiply
	.db	0x30		;;stk-data
	.db	0x80		;;Bytes: 3
	.db	0x41		;;Exponent $91
	.db	0x00,0x00,0x80	;;(+00)
	.db	0x2E		;;n-mod-m
	.db	0x02		;;delete
	.db	0xA1		;;stk-one
	.db	0x03		;;subtract
	.db	0x2D		;;duplicate
	.db	0x34		;;end-calc
			
	call	L158A		; routine FP-TO-BC
	ld	(0x4032),BC	; update the SEED system variable.
	ld	A,(HL)		; HL addresses the exponent of the last value.
	and	A		; test for zero
	jr	Z,L0F8A		; forward, if so, to S-JPI-END
			
	sub	#0x10		; else reduce exponent by sixteen
	ld	(HL),A		; thus dividing by 65536 for last value.
			
;; S-JPI-END
L0F8A:	jr	L0F99		; forward to S-PI-END
			
; ---
			
;; S-TEST-PI
L0F8C:	cp	#0x42		; the 'PI' character
	jr	NZ,L0F9D	; forward, if not, to S-TST-INK
			
; -------------------
; THE 'PI' EVALUATION
; -------------------
			
	call	L0DA6		; routine SYNTAX-Z
	jr	Z,L0F99		; forward if checking syntax to S-PI-END
			
			
	rst	#0x28		;; FP-CALC
	.db	0xA3		;;stk-pi/2
	.db	0x34		;;end-calc
			
	inc	(HL)		; double the exponent giving PI on the stack.
			
;; S-PI-END
L0F99:	rst	#0x20		; NEXT-CHAR advances character pointer.
			
	jp	L1083		; jump forward to S-NUMERIC to set the flag
				; to signal numeric result before advancing.
			
; ---
			
;; S-TST-INK
L0F9D:	cp	#0x41		; compare to character 'INKEY$'
	jr	NZ,L0FB2	; forward, if not, to S-ALPHANUM
			
; -----------------------
; THE 'INKEY$' EVALUATION
; -----------------------
			
	call	L02BB		; routine KEYBOARD
	ld	B,H		;
	ld	C,L		;
	ld	D,C		;
	inc	D		;
	call	NZ,L07BD	; routine DECODE
	ld	A,D		;
	adc	A,D		;
	ld	B,D		;
	ld	C,A		;
	ex	DE,HL		;
	jr	L0FED		; forward to S-STRING
			
; ---
			
;; S-ALPHANUM
L0FB2:	call	L14D2		; routine ALPHANUM
	jr	C,L1025		; forward, if alphanumeric to S-LTR-DGT
			
	cp	#0x1B		; is character a '.' ?
	jp	Z,L1047		; jump forward if so to S-DECIMAL
			
	ld	BC,#0x09D8	; prepare priority 09, operation 'subtract'
	cp	#0x16		; is character unary minus '-' ?
	jr	Z,L1020		; forward, if so, to S-PUSH-PO
			
	cp	#0x10		; is character a '(' ?
	jr	NZ,L0FD6	; forward if not to S-QUOTE
			
	call	L0049		; routine CH-ADD+1 advances character pointer.
			
	call	L0F55		; recursively call routine SCANNING to
				; evaluate the sub-expression.
			
	cp	#0x11		; is subsequent character a ')' ?
	jr	NZ,L0FFF	; forward if not to S-RPT-C
			
			
	call	L0049		; routine CH-ADD+1  advances.
	jr	L0FF8		; relative jump to S-JP-CONT3 and then S-CONT3
			
; ---
			
; consider a quoted string e.g. PRINT "Hooray!"
; Note. quotes are not allowed within a string.
			
;; S-QUOTE
L0FD6:	cp	#0x0B		; is character a quote (") ?
	jr	NZ,L1002	; forward, if not, to S-FUNCTION
			
	call	L0049		; routine CH-ADD+1 advances
	push	HL		; * save start of string.
	jr	L0FE3		; forward to S-QUOTE-S
			
; ---
			
			
;; S-Q-AGAIN
L0FE0:	call	L0049		; routine CH-ADD+1
			
;; S-QUOTE-S
L0FE3:	cp	#0x0B		; is character a '"' ?
	jr	NZ,L0FFB	; forward if not to S-Q-NL
			
	pop	DE		; * retrieve start of string
	and	A		; prepare to subtract.
	sbc	HL,DE		; subtract start from current position.
	ld	B,H		; transfer this length
	ld	C,L		; to the BC register pair.
			
;; S-STRING
L0FED:	ld	HL,#0x4001	; address system variable FLAGS
	res	6,(HL)		; signal string result
	bit	7,(HL)		; test if checking syntax.
			
	call	NZ,L12C3	; in run-time routine STK-STO-$ stacks the
				; string descriptor - start DE, length BC.
			
	rst	#0x20		; NEXT-CHAR advances pointer.
			
;; S-J-CONT-3
L0FF8:	jp	L1088		; jump to S-CONT-3
			
; ---
			
; A string with no terminating quote has to be considered.
			
;; S-Q-NL
L0FFB:	cp	#0x76		; compare to NEWLINE
	jr	NZ,L0FE0	; loop back if not to S-Q-AGAIN
			
;; S-RPT-C
L0FFF:	jp	L0D9A		; to REPORT-C
			
; ---
			
;; S-FUNCTION
L1002:	sub	#0xC4		; subtract 'CODE' reducing codes
				; CODE thru '<>' to range $00 - $XX
	jr	C,L0FFF		; back, if less, to S-RPT-C
			
; test for NOT the last function in character set.
			
	ld	BC,#0x04EC	; prepare priority $04, operation 'not'
	cp	#0x13		; compare to 'NOT'  ( - CODE)
	jr	Z,L1020		; forward, if so, to S-PUSH-PO
			
	jr	NC,L0FFF	; back with anything higher to S-RPT-C
			
; else is a function 'CODE' thru 'CHR$'
			
	ld	B,#0x10		; priority sixteen binds all functions to
				; arguments removing the need for brackets.
			
	add	A,#0xD9		; add $D9 to give range $D9 thru $EB
				; bit 6 is set to show numeric argument.
				; bit 7 is set to show numeric result.
			
; now adjust these default argument/result indicators.
			
	ld	C,A		; save code in C
			
	cp	#0xDC		; separate 'CODE', 'VAL', 'LEN'
	jr	NC,L101A	; skip forward if string operand to S-NO-TO-$
			
	res	6,C		; signal string operand.
			
;; S-NO-TO-$
L101A:	cp	#0xEA		; isolate top of range 'STR$' and 'CHR$'
	jr	C,L1020		; skip forward with others to S-PUSH-PO
			
	res	7,C		; signal string result.
			
;; S-PUSH-PO
L1020:	push	BC		; push the priority/operation
			
	rst	#0x20		; NEXT-CHAR
	jp	L0F59		; jump back to S-LOOP-1
			
; ---
			
;; S-LTR-DGT
L1025:	cp	#0x26		; compare to 'A'.
	jr	C,L1047		; forward if less to S-DECIMAL
			
	call	L111C		; routine LOOK-VARS
	jp	C,L0D4B		; back if not found to REPORT-2
				; a variable is always 'found' when checking
				; syntax.
			
	call	Z,L11A7		; routine STK-VAR stacks string parameters or
				; returns cell location if numeric.
			
	ld	A,(0x4001)	; fetch FLAGS
	cp	#0xC0		; compare to numeric result/numeric operand
	jr	C,L1087		; forward if not numeric to S-CONT-2
			
	inc	HL		; address numeric contents of variable.
	ld	DE,(0x401C)	; set destination to STKEND
	call	L19F6		; routine MOVE-FP stacks the five bytes
	ex	DE,HL		; transfer new free location from DE to HL.
	ld	(0x401C),HL	; update STKEND system variable.
	jr	L1087		; forward to S-CONT-2
			
; ---
			
; The Scanning Decimal routine is invoked when a decimal point or digit is
; found in the expression.
; When checking syntax, then the 'hidden floating point' form is placed
; after the number in the BASIC line.
; In run-time, the digits are skipped and the floating point number is picked
; up.
			
;; S-DECIMAL
L1047:	call	L0DA6		; routine SYNTAX-Z
	jr	NZ,L106F	; forward in run-time to S-STK-DEC
			
	call	L14D9		; routine DEC-TO-FP
			
	rst	#0x18		; GET-CHAR advances HL past digits
	ld	BC,#0x0006	; six locations are required.
	call	L099E		; routine MAKE-ROOM
	inc	HL		; point to first new location
	ld	(HL),#0x7E	; insert the number marker 126 decimal.
	inc	HL		; increment
	ex	DE,HL		; transfer destination to DE.
	ld	HL,(0x401C)	; set HL from STKEND which points to the
				; first location after the 'last value'
	ld	C,#0x05		; five bytes to move.
	and	A		; clear carry.
	sbc	HL,BC		; subtract five pointing to 'last value'.
	ld	(0x401C),HL	; update STKEND thereby 'deleting the value.
			
	ldir			; copy the five value bytes.
			
	ex	DE,HL		; basic pointer to HL which may be white-space
				; following the number.
	dec	HL		; now points to last of five bytes.
	call	L004C		; routine TEMP-PTR1 advances the character
				; address skipping any white-space.
	jr	L1083		; forward to S-NUMERIC
				; to signal a numeric result.
			
; ---
			
; In run-time the branch is here when a digit or point is encountered.
			
;; S-STK-DEC
L106F:	rst	#0x20		; NEXT-CHAR
	cp	#0x7E		; compare to 'number marker'
	jr	NZ,L106F	; loop back until found to S-STK-DEC
				; skipping all the digits.
			
	inc	HL		; point to first of five hidden bytes.
	ld	DE,(0x401C)	; set destination from STKEND system variable
	call	L19F6		; routine MOVE-FP stacks the number.
	ld	(0x401C),DE	; update system variable STKEND.
	ld	(0x4016),HL	; update system variable CH_ADD.
			
;; S-NUMERIC
L1083:	set	6,0x01(IY)	; update FLAGS  - Signal numeric result
			
;; S-CONT-2
L1087:	rst	#0x18		; GET-CHAR
			
;; S-CONT-3
L1088:	cp	#0x10		; compare to opening bracket '('
	jr	NZ,L1098	; forward if not to S-OPERTR
			
	bit	6,0x01(IY)	; test FLAGS  - Numeric or string result?
	jr	NZ,L10BC	; forward if numeric to S-LOOP
			
; else is a string
			
	call	L1263		; routine SLICING
			
	rst	#0x20		; NEXT-CHAR
	jr	L1088		; back to S-CONT-3
			
; ---
			
; the character is now manipulated to form an equivalent in the table of
; calculator literals. This is quite cumbersome and in the ZX Spectrum a
; simple look-up table was introduced at this point.
			
;; S-OPERTR
L1098:	ld	BC,#0x00C3	; prepare operator 'subtract' as default.
				; also set B to zero for later indexing.
			
	cp	#0x12		; is character '>' ?
	jr	C,L10BC		; forward if less to S-LOOP as
				; we have reached end of meaningful expression
			
	sub	#0x16		; is character '-' ?
	jr	NC,L10A7	; forward with - * / and '**' '<>' to SUBMLTDIV
			
	add	A,#0x0D		; increase others by thirteen
				; $09 '>' thru $0C '+'
	jr	L10B5		; forward to GET-PRIO
			
; ---
			
;; SUBMLTDIV
L10A7:	cp	#0x03		; isolate $00 '-', $01 '*', $02 '/'
	jr	C,L10B5		; forward if so to GET-PRIO
			
; else possibly originally $D8 '**' thru $DD '<>' already reduced by $16
			
	sub	#0xC2		; giving range $00 to $05
	jr	C,L10BC		; forward if less to S-LOOP
			
	cp	#0x06		; test the upper limit for nonsense also
	jr	NC,L10BC	; forward if so to S-LOOP
			
	add	A,#0x03		; increase by 3 to give combined operators of
			
				; $00 '-'
				; $01 '*'
				; $02 '/'
			
				; $03 '**'
				; $04 'OR'
				; $05 'AND'
				; $06 '<='
				; $07 '>='
				; $08 '<>'
			
				; $09 '>'
				; $0A '<'
				; $0B '='
				; $0C '+'
			
;; GET-PRIO
L10B5:	add	A,C		; add to default operation 'sub' ($C3)
	ld	C,A		; and place in operator byte - C.
			
	ld	HL,#L110F - 0xC3	; theoretical base of the priorities table.
	add	HL,BC		; add C ( B is zero)
	ld	B,(HL)		; pick up the priority in B
			
;; S-LOOP
L10BC:	pop	DE		; restore previous
	ld	A,D		; load A with priority.
	cp	B		; is present priority higher
	jr	C,L10ED		; forward if so to S-TIGHTER
			
	and	A		; are both priorities zero
	jp	Z,L0018		; exit if zero via GET-CHAR
			
	push	BC		; stack present values
	push	DE		; stack last values
	call	L0DA6		; routine SYNTAX-Z
	jr	Z,L10D5		; forward is checking syntax to S-SYNTEST
			
	ld	A,E		; fetch last operation
	and	#0x3F		; mask off the indicator bits to give true
				; calculator literal.
	ld	B,A		; place in the B register for BREG
			
; perform the single operation
			
	rst	#0x28		;; FP-CALC
	.db	0x37		;;fp-calc-2
	.db	0x34		;;end-calc
			
	jr	L10DE		; forward to S-RUNTEST
			
; ---
			
;; S-SYNTEST
L10D5:	ld	A,E		; transfer masked operator to A
	xor	0x01(IY)	; XOR with FLAGS like results will reset bit 6
	and	#0x40		; test bit 6
			
;; S-RPORT-C
L10DB:	jp	NZ,L0D9A	; back to REPORT-C if results do not agree.
			
; ---
			
; in run-time impose bit 7 of the operator onto bit 6 of the FLAGS
			
;; S-RUNTEST
L10DE:	pop	DE		; restore last operation.
	ld	HL,#0x4001	; address system variable FLAGS
	set	6,(HL)		; presume a numeric result
	bit	7,E		; test expected result in operation
	jr	NZ,L10EA	; forward if numeric to S-LOOPEND
			
	res	6,(HL)		; reset to signal string result
			
;; S-LOOPEND
L10EA:	pop	BC		; restore present values
	jr	L10BC		; back to S-LOOP
			
; ---
			
;; S-TIGHTER
L10ED:	push	DE		; push last values and consider these
			
	ld	A,C		; get the present operator.
	bit	6,0x01(IY)	; test FLAGS  - Numeric or string result?
	jr	NZ,L110A	; forward if numeric to S-NEXT
			
	and	#0x3F		; strip indicator bits to give clear literal.
	add	A,#0x08		; add eight - augmenting numeric to equivalent
				; string literals.
	ld	C,A		; place plain literal back in C.
	cp	#0x10		; compare to 'AND'
	jr	NZ,L1102	; forward if not to S-NOT-AND
			
	set	6,C		; set the numeric operand required for 'AND'
	jr	L110A		; forward to S-NEXT
			
; ---
			
;; S-NOT-AND
L1102:	jr	C,L10DB		; back if less than 'AND' to S-RPORT-C
				; Nonsense if '-', '*' etc.
			
	cp	#0x17		; compare to 'strs-add' literal
	jr	Z,L110A		; forward if so signaling string result
			
	set	7,C		; set bit to numeric (Boolean) for others.
			
;; S-NEXT
L110A:	push	BC		; stack 'present' values
			
	rst	#0x20		; NEXT-CHAR
	jp	L0F59		; jump back to S-LOOP-1
			
			
			
; -------------------------
; THE 'TABLE OF PRIORITIES'
; -------------------------
;
;
			
;; tbl-pri
L110F:	.db	0x06		;       '-'
	.db	0x08		;       '*'
	.db	0x08		;       '/'
	.db	0x0A		;       '**'
	.db	0x02		;       'OR'
	.db	0x03		;       'AND'
	.db	0x05		;       '<='
	.db	0x05		;       '>='
	.db	0x05		;       '<>'
	.db	0x05		;       '>'
	.db	0x05		;       '<'
	.db	0x05		;       '='
	.db	0x06		;       '+'
			
			
; --------------------------
; THE 'LOOK-VARS' SUBROUTINE
; --------------------------
;
;
			
;; LOOK-VARS
L111C:	set	6,0x01(IY)	; sv FLAGS  - Signal numeric result
			
	rst	#0x18		; GET-CHAR
	call	L14CE		; routine ALPHA
	jp	NC,L0D9A	; to REPORT-C
			
	push	HL		;
	ld	C,A		;
			
	rst	#0x20		; NEXT-CHAR
	push	HL		;
	res	5,C		;
	cp	#0x10		;
	jr	Z,L1148		; to V-SYN/RUN
			
	set	6,C		;
	cp	#0x0D		;
	jr	Z,L1143		; forward to V-STR-VAR
			
	set	5,C		;
			
;; V-CHAR
L1139:	call	L14D2		; routine ALPHANUM
	jr	NC,L1148	; forward when not to V-RUN/SYN
			
	res	6,C		;
			
	rst	#0x20		; NEXT-CHAR
	jr	L1139		; loop back to V-CHAR
			
; ---
			
;; V-STR-VAR
L1143:	rst	#0x20		; NEXT-CHAR
	res	6,0x01(IY)	; sv FLAGS  - Signal string result
			
;; V-RUN/SYN
L1148:	ld	B,C		;
	call	L0DA6		; routine SYNTAX-Z
	jr	NZ,L1156	; forward to V-RUN
			
	ld	A,C		;
	and	#0xE0		;
	set	7,A		;
	ld	C,A		;
	jr	L118A		; forward to V-SYNTAX
			
; ---
			
;; V-RUN
L1156:	ld	HL,(0x4010)	; sv VARS
			
;; V-EACH
L1159:	ld	A,(HL)		;
	and	#0x7F		;
	jr	Z,L1188		; to V-80-BYTE
			
	cp	C		;
	jr	NZ,L1180	; to V-NEXT
			
	rla			;
	add	A,A		;
	jp	P,L1195		; to V-FOUND-2
			
	jr	C,L1195		; to V-FOUND-2
			
	pop	DE		;
	push	DE		;
	push	HL		;
			
;; V-MATCHES
L116B:	inc	HL		;
			
;; V-SPACES
L116C:	ld	A,(DE)		;
	inc	DE		;
	and	A		;
	jr	Z,L116C		; back to V-SPACES
			
	cp	(HL)		;
	jr	Z,L116B		; back to V-MATCHES
			
	or	#0x80		;
	cp	(HL)		;
	jr	NZ,L117F	; forward to V-GET-PTR
			
	ld	A,(DE)		;
	call	L14D2		; routine ALPHANUM
	jr	NC,L1194	; forward to V-FOUND-1
			
;; V-GET-PTR
L117F:	pop	HL		;
			
;; V-NEXT
L1180:	push	BC		;
	call	L09F2		; routine NEXT-ONE
	ex	DE,HL		;
	pop	BC		;
	jr	L1159		; back to V-EACH
			
; ---
			
;; V-80-BYTE
L1188:	set	7,B		;
			
;; V-SYNTAX
L118A:	pop	DE		;
			
	rst	#0x18		; GET-CHAR
	cp	#0x10		;
	jr	Z,L1199		; forward to V-PASS
			
	set	5,B		;
	jr	L11A1		; forward to V-END
			
; ---
			
;; V-FOUND-1
L1194:	pop	DE		;
			
;; V-FOUND-2
L1195:	pop	DE		;
	pop	DE		;
	push	HL		;
			
	rst	#0x18		; GET-CHAR
			
;; V-PASS
L1199:	call	L14D2		; routine ALPHANUM
	jr	NC,L11A1	; forward if not alphanumeric to V-END
			
			
	rst	#0x20		; NEXT-CHAR
	jr	L1199		; back to V-PASS
			
; ---
			
;; V-END
L11A1:	pop	HL		;
	rl	B		;
	bit	6,B		;
	ret			;
			
; ------------------------
; THE 'STK-VAR' SUBROUTINE
; ------------------------
;
;
			
;; STK-VAR
L11A7:	xor	A		;
	ld	B,A		;
	bit	7,C		;
	jr	NZ,L11F8	; forward to SV-COUNT
			
	bit	7,(HL)		;
	jr	NZ,L11BF	; forward to SV-ARRAYS
			
	inc	A		;
			
;; SV-SIMPLE$
L11B2:	inc	HL		;
	ld	C,(HL)		;
	inc	HL		;
	ld	B,(HL)		;
	inc	HL		;
	ex	DE,HL		;
	call	L12C3		; routine STK-STO-$
			
	rst	#0x18		; GET-CHAR
	jp	L125A		; jump forward to SV-SLICE?
			
; ---
			
;; SV-ARRAYS
L11BF:	inc	HL		;
	inc	HL		;
	inc	HL		;
	ld	B,(HL)		;
	bit	6,C		;
	jr	Z,L11D1		; forward to SV-PTR
			
	dec	B		;
	jr	Z,L11B2		; forward to SV-SIMPLE$
			
	ex	DE,HL		;
			
	rst	#0x18		; GET-CHAR
	cp	#0x10		;
	jr	NZ,L1231	; forward to REPORT-3
			
	ex	DE,HL		;
			
;; SV-PTR
L11D1:	ex	DE,HL		;
	jr	L11F8		; forward to SV-COUNT
			
; ---
			
;; SV-COMMA
L11D4:	push	HL		;
			
	rst	#0x18		; GET-CHAR
	pop	HL		;
	cp	#0x1A		;
	jr	Z,L11FB		; forward to SV-LOOP
			
	bit	7,C		;
	jr	Z,L1231		; forward to REPORT-3
			
	bit	6,C		;
	jr	NZ,L11E9	; forward to SV-CLOSE
			
	cp	#0x11		;
	jr	NZ,L1223	; forward to SV-RPT-C
			
			
	rst	#0x20		; NEXT-CHAR
	ret			;
			
; ---
			
;; SV-CLOSE
L11E9:	cp	#0x11		;
	jr	Z,L1259		; forward to SV-DIM
			
	cp	#0xDF		;
	jr	NZ,L1223	; forward to SV-RPT-C
			
			
;; SV-CH-ADD
L11F1:	rst	#0x18		; GET-CHAR
	dec	HL		;
	ld	(0x4016),HL	; sv CH_ADD
	jr	L1256		; forward to SV-SLICE
			
; ---
			
;; SV-COUNT
L11F8:	ld	HL,#0x0000	;
			
;; SV-LOOP
L11FB:	push	HL		;
			
	rst	#0x20		; NEXT-CHAR
	pop	HL		;
	ld	A,C		;
	cp	#0xC0		;
	jr	NZ,L120C	; forward to SV-MULT
			
			
	rst	#0x18		; GET-CHAR
	cp	#0x11		;
	jr	Z,L1259		; forward to SV-DIM
			
	cp	#0xDF		;
	jr	Z,L11F1		; back to SV-CH-ADD
			
;; SV-MULT
L120C:	push	BC		;
	push	HL		;
	call	L12FF		; routine DE,(DE+1)
	ex	(SP),HL		;
	ex	DE,HL		;
	call	L12DD		; routine INT-EXP1
	jr	C,L1231		; forward to REPORT-3
			
	dec	BC		;
	call	L1305		; routine GET-HL*DE
	add	HL,BC		;
	pop	DE		;
	pop	BC		;
	djnz	L11D4		; loop back to SV-COMMA
			
	bit	7,C		;
			
;; SV-RPT-C
L1223:	jr	NZ,L128B	; relative jump to SL-RPT-C
			
	push	HL		;
	bit	6,C		;
	jr	NZ,L123D	; forward to SV-ELEM$
			
	ld	B,D		;
	ld	C,E		;
			
	rst	#0x18		; GET-CHAR
	cp	#0x11		; is character a ')' ?
	jr	Z,L1233		; skip forward to SV-NUMBER
			
			
;; REPORT-3
L1231:	rst	#0x08		; ERROR-1
	.db	0x02		; Error Report: Subscript wrong
			
			
;; SV-NUMBER
L1233:	rst	#0x20		; NEXT-CHAR
	pop	HL		;
	ld	DE,#0x0005	;
	call	L1305		; routine GET-HL*DE
	add	HL,BC		;
	ret			; return                            >>
			
; ---
			
;; SV-ELEM$
L123D:	call	L12FF		; routine DE,(DE+1)
	ex	(SP),HL		;
	call	L1305		; routine GET-HL*DE
	pop	BC		;
	add	HL,BC		;
	inc	HL		;
	ld	B,D		;
	ld	C,E		;
	ex	DE,HL		;
	call	L12C2		; routine STK-ST-0
			
	rst	#0x18		; GET-CHAR
	cp	#0x11		; is it ')' ?
	jr	Z,L1259		; forward if so to SV-DIM
			
	cp	#0x1A		; is it ',' ?
	jr	NZ,L1231	; back if not to REPORT-3
			
;; SV-SLICE
L1256:	call	L1263		; routine SLICING
			
;; SV-DIM
L1259:	rst	#0x20		; NEXT-CHAR
			
;; SV-SLICE?
L125A:	cp	#0x10		;
	jr	Z,L1256		; back to SV-SLICE
			
	res	6,0x01(IY)	; sv FLAGS  - Signal string result
	ret			; return.
			
; ------------------------
; THE 'SLICING' SUBROUTINE
; ------------------------
;
;
			
;; SLICING
L1263:	call	L0DA6		; routine SYNTAX-Z
	call	NZ,L13F8	; routine STK-FETCH
			
	rst	#0x20		; NEXT-CHAR
	cp	#0x11		; is it ')' ?
	jr	Z,L12BE		; forward if so to SL-STORE
			
	push	DE		;
	xor	A		;
	push	AF		;
	push	BC		;
	ld	DE,#0x0001	;
			
	rst	#0x18		; GET-CHAR
	pop	HL		;
	cp	#0xDF		; is it 'TO' ?
	jr	Z,L1292		; forward if so to SL-SECOND
			
	pop	AF		;
	call	L12DE		; routine INT-EXP2
	push	AF		;
	ld	D,B		;
	ld	E,C		;
	push	HL		;
			
	rst	#0x18		; GET-CHAR
	pop	HL		;
	cp	#0xDF		; is it 'TO' ?
	jr	Z,L1292		; forward if so to SL-SECOND
			
	cp	#0x11		;
			
;; SL-RPT-C
L128B:	jp	NZ,L0D9A	; to REPORT-C
			
	ld	H,D		;
	ld	L,E		;
	jr	L12A5		; forward to SL-DEFINE
			
; ---
			
;; SL-SECOND
L1292:	push	HL		;
			
	rst	#0x20		; NEXT-CHAR
	pop	HL		;
	cp	#0x11		; is it ')' ?
	jr	Z,L12A5		; forward if so to SL-DEFINE
			
	pop	AF		;
	call	L12DE		; routine INT-EXP2
	push	AF		;
			
	rst	#0x18		; GET-CHAR
	ld	H,B		;
	ld	L,C		;
	cp	#0x11		; is it ')' ?
	jr	NZ,L128B	; back if not to SL-RPT-C
			
;; SL-DEFINE
L12A5:	pop	AF		;
	ex	(SP),HL		;
	add	HL,DE		;
	dec	HL		;
	ex	(SP),HL		;
	and	A		;
	sbc	HL,DE		;
	ld	BC,#0x0000	;
	jr	C,L12B9		; forward to SL-OVER
			
	inc	HL		;
	and	A		;
	jp	M,L1231		; jump back to REPORT-3
			
	ld	B,H		;
	ld	C,L		;
			
;; SL-OVER
L12B9:	pop	DE		;
	res	6,0x01(IY)	; sv FLAGS  - Signal string result
			
;; SL-STORE
L12BE:	call	L0DA6		; routine SYNTAX-Z
	ret	Z		; return if checking syntax.
			
; --------------------------
; THE 'STK-STORE' SUBROUTINE
; --------------------------
;
;
			
;; STK-ST-0
L12C2:	xor	A		;
			
;; STK-STO-$
L12C3:	push	BC		;
	call	L19EB		; routine TEST-5-SP
	pop	BC		;
	ld	HL,(0x401C)	; sv STKEND
	ld	(HL),A		;
	inc	HL		;
	ld	(HL),E		;
	inc	HL		;
	ld	(HL),D		;
	inc	HL		;
	ld	(HL),C		;
	inc	HL		;
	ld	(HL),B		;
	inc	HL		;
	ld	(0x401C),HL	; sv STKEND
	res	6,0x01(IY)	; update FLAGS - signal string result
	ret			; return.
			
; -------------------------
; THE 'INT EXP' SUBROUTINES
; -------------------------
;
;
			
;; INT-EXP1
L12DD:	xor	A		;
			
;; INT-EXP2
L12DE:	push	DE		;
	push	HL		;
	push	AF		;
	call	L0D92		; routine CLASS-6
	pop	AF		;
	call	L0DA6		; routine SYNTAX-Z
	jr	Z,L12FC		; forward if checking syntax to I-RESTORE
			
	push	AF		;
	call	L0EA7		; routine FIND-INT
	pop	DE		;
	ld	A,B		;
	or	C		;
	scf			; Set Carry Flag
	jr	Z,L12F9		; forward to I-CARRY
			
	pop	HL		;
	push	HL		;
	and	A		;
	sbc	HL,BC		;
			
;; I-CARRY
L12F9:	ld	A,D		;
	sbc	A,#0x00		;
			
;; I-RESTORE
L12FC:	pop	HL		;
	pop	DE		;
	ret			;
			
; --------------------------
; THE 'DE,(DE+1)' SUBROUTINE
; --------------------------
; INDEX and LOAD Z80 subroutine.
; This emulates the 6800 processor instruction LDX 1,X which loads a two-byte
; value from memory into the register indexing it. Often these are hardly worth
; the bother of writing as subroutines and this one doesn't save any time or
; memory. The timing and space overheads have to be offset against the ease of
; writing and the greater program readability from using such toolkit routines.
			
;; DE,(DE+1)
L12FF:	ex	DE,HL		; move index address into HL.
	inc	HL		; increment to address word.
	ld	E,(HL)		; pick up word low-order byte.
	inc	HL		; index high-order byte and
	ld	D,(HL)		; pick it up.
	ret			; return with DE = word.
			
; --------------------------
; THE 'GET-HL*DE' SUBROUTINE
; --------------------------
;
			
;; GET-HL*DE
L1305:	call	L0DA6		; routine SYNTAX-Z
	ret	Z		;
			
	push	BC		;
	ld	B,#0x10		;
	ld	A,H		;
	ld	C,L		;
	ld	HL,#0x0000	;
			
;; HL-LOOP
L1311:	add	HL,HL		;
	jr	C,L131A		; forward with carry to HL-END
			
	rl	C		;
	rla			;
	jr	NC,L131D	; forward with no carry to HL-AGAIN
			
	add	HL,DE		;
			
;; HL-END
L131A:	jp	C,L0ED3		; to REPORT-4
			
;; HL-AGAIN
L131D:	djnz	L1311		; loop back to HL-LOOP
			
	pop	BC		;
	ret			; return.
			
; --------------------
; THE 'LET' SUBROUTINE
; --------------------
;
;
			
;; LET
L1321:	ld	HL,(0x4012)	; sv DEST-lo
	bit	1,0x2D(IY)	; sv FLAGX
	jr	Z,L136E		; forward to L-EXISTS
			
	ld	BC,#0x0005	;
			
;; L-EACH-CH
L132D:	inc	BC		;
			
; check
			
;; L-NO-SP
L132E:	inc	HL		;
	ld	A,(HL)		;
	and	A		;
	jr	Z,L132E		; back to L-NO-SP
			
	call	L14D2		; routine ALPHANUM
	jr	C,L132D		; back to L-EACH-CH
			
	cp	#0x0D		; is it '$' ?
	jp	Z,L13C8		; forward if so to L-NEW$
			
			
	rst	#0x30		; BC-SPACES
	push	DE		;
	ld	HL,(0x4012)	; sv DEST
	dec	DE		;
	ld	A,C		;
	sub	#0x06		;
	ld	B,A		;
	ld	A,#0x40		;
	jr	Z,L1359		; forward to L-SINGLE
			
;; L-CHAR
L134B:	inc	HL		;
	ld	A,(HL)		;
	and	A		; is it a space ?
	jr	Z,L134B		; back to L-CHAR
			
	inc	DE		;
	ld	(DE),A		;
	djnz	L134B		; loop back to L-CHAR
			
	or	#0x80		;
	ld	(DE),A		;
	ld	A,#0x80		;
			
;; L-SINGLE
L1359:	ld	HL,(0x4012)	; sv DEST-lo
	xor	(HL)		;
	pop	HL		;
	call	L13E7		; routine L-FIRST
			
;; L-NUMERIC
L1361:	push	HL		;
			
	rst	#0x28		;; FP-CALC
	.db	0x02		;;delete
	.db	0x34		;;end-calc
			
	pop	HL		;
	ld	BC,#0x0005	;
	and	A		;
	sbc	HL,BC		;
	jr	L13AE		; forward to L-ENTER
			
; ---
			
;; L-EXISTS
L136E:	bit	6,0x01(IY)	; sv FLAGS  - Numeric or string result?
	jr	Z,L137A		; forward to L-DELETE$
			
	ld	DE,#0x0006	;
	add	HL,DE		;
	jr	L1361		; back to L-NUMERIC
			
; ---
			
;; L-DELETE$
L137A:	ld	HL,(0x4012)	; sv DEST-lo
	ld	BC,(0x402E)	; sv STRLEN_lo
	bit	0,0x2D(IY)	; sv FLAGX
	jr	NZ,L13B7	; forward to L-ADD$
			
	ld	A,B		;
	or	C		;
	ret	Z		;
			
	push	HL		;
			
	rst	#0x30		; BC-SPACES
	push	DE		;
	push	BC		;
	ld	D,H		;
	ld	E,L		;
	inc	HL		;
	ld	(HL),#0x00	;
	lddr			; Copy Bytes
	push	HL		;
	call	L13F8		; routine STK-FETCH
	pop	HL		;
	ex	(SP),HL		;
	and	A		;
	sbc	HL,BC		;
	add	HL,BC		;
	jr	NC,L13A3	; forward to L-LENGTH
			
	ld	B,H		;
	ld	C,L		;
			
;; L-LENGTH
L13A3:	ex	(SP),HL		;
	ex	DE,HL		;
	ld	A,B		;
	or	C		;
	jr	Z,L13AB		; forward if zero to L-IN-W/S
			
	ldir			; Copy Bytes
			
;; L-IN-W/S
L13AB:	pop	BC		;
	pop	DE		;
	pop	HL		;
			
; ------------------------
; THE 'L-ENTER' SUBROUTINE
; ------------------------
;
			
;; L-ENTER
L13AE:	ex	DE,HL		;
	ld	A,B		;
	or	C		;
	ret	Z		;
			
	push	DE		;
	ldir			; Copy Bytes
	pop	HL		;
	ret			; return.
			
; ---
			
;; L-ADD$
L13B7:	dec	HL		;
	dec	HL		;
	dec	HL		;
	ld	A,(HL)		;
	push	HL		;
	push	BC		;
			
	call	L13CE		; routine L-STRING
			
	pop	BC		;
	pop	HL		;
	inc	BC		;
	inc	BC		;
	inc	BC		;
	jp	L0A60		; jump back to exit via RECLAIM-2
			
; ---
			
;; L-NEW$
L13C8:	ld	A,#0x60		; prepare mask %01100000
	ld	HL,(0x4012)	; sv DEST-lo
	xor	(HL)		;
			
; -------------------------
; THE 'L-STRING' SUBROUTINE
; -------------------------
;
			
;; L-STRING
L13CE:	push	AF		;
	call	L13F8		; routine STK-FETCH
	ex	DE,HL		;
	add	HL,BC		;
	push	HL		;
	inc	BC		;
	inc	BC		;
	inc	BC		;
			
	rst	#0x30		; BC-SPACES
	ex	DE,HL		;
	pop	HL		;
	dec	BC		;
	dec	BC		;
	push	BC		;
	lddr			; Copy Bytes
	ex	DE,HL		;
	pop	BC		;
	dec	BC		;
	ld	(HL),B		;
	dec	HL		;
	ld	(HL),C		;
	pop	AF		;
			
;; L-FIRST
L13E7:	push	AF		;
	call	L14C7		; routine REC-V80
	pop	AF		;
	dec	HL		;
	ld	(HL),A		;
	ld	HL,(0x401A)	; sv STKBOT_lo
	ld	(0x4014),HL	; sv E_LINE_lo
	dec	HL		;
	ld	(HL),#0x80	;
	ret			;
			
; --------------------------
; THE 'STK-FETCH' SUBROUTINE
; --------------------------
; This routine fetches a five-byte value from the calculator stack
; reducing the pointer to the end of the stack by five.
; For a floating-point number the exponent is in A and the mantissa
; is the thirty-two bits EDCB.
; For strings, the start of the string is in DE and the length in BC.
; A is unused.
			
;; STK-FETCH
L13F8:	ld	HL,(0x401C)	; load HL from system variable STKEND
			
	dec	HL		;
	ld	B,(HL)		;
	dec	HL		;
	ld	C,(HL)		;
	dec	HL		;
	ld	D,(HL)		;
	dec	HL		;
	ld	E,(HL)		;
	dec	HL		;
	ld	A,(HL)		;
			
	ld	(0x401C),HL	; set system variable STKEND to lower value.
	ret			; return.
			
; -------------------------
; THE 'DIM' COMMAND ROUTINE
; -------------------------
; An array is created and initialized to zeros which is also the space
; character on the ZX81.
			
;; DIM
L1409:	call	L111C		; routine LOOK-VARS
			
;; D-RPORT-C
L140C:	jp	NZ,L0D9A	; to REPORT-C
			
	call	L0DA6		; routine SYNTAX-Z
	jr	NZ,L141C	; forward to D-RUN
			
	res	6,C		;
	call	L11A7		; routine STK-VAR
	call	L0D1D		; routine CHECK-END
			
;; D-RUN
L141C:	jr	C,L1426		; forward to D-LETTER
			
	push	BC		;
	call	L09F2		; routine NEXT-ONE
	call	L0A60		; routine RECLAIM-2
	pop	BC		;
			
;; D-LETTER
L1426:	set	7,C		;
	ld	B,#0x00		;
	push	BC		;
	ld	HL,#0x0001	;
	bit	6,C		;
	jr	NZ,L1434	; forward to D-SIZE
			
	ld	L,#0x05		;
			
;; D-SIZE
L1434:	ex	DE,HL		;
			
;; D-NO-LOOP
L1435:	rst	#0x20		; NEXT-CHAR
	ld	H,#0x40		;
	call	L12DD		; routine INT-EXP1
	jp	C,L1231		; jump back to REPORT-3
			
	pop	HL		;
	push	BC		;
	inc	H		;
	push	HL		;
	ld	H,B		;
	ld	L,C		;
	call	L1305		; routine GET-HL*DE
	ex	DE,HL		;
			
	rst	#0x18		; GET-CHAR
	cp	#0x1A		;
	jr	Z,L1435		; back to D-NO-LOOP
			
	cp	#0x11		; is it ')' ?
	jr	NZ,L140C	; back if not to D-RPORT-C
			
			
	rst	#0x20		; NEXT-CHAR
	pop	BC		;
	ld	A,C		;
	ld	L,B		;
	ld	H,#0x00		;
	inc	HL		;
	inc	HL		;
	add	HL,HL		;
	add	HL,DE		;
	jp	C,L0ED3		; jump to REPORT-4
			
	push	DE		;
	push	BC		;
	push	HL		;
	ld	B,H		;
	ld	C,L		;
	ld	HL,(0x4014)	; sv E_LINE_lo
	dec	HL		;
	call	L099E		; routine MAKE-ROOM
	inc	HL		;
	ld	(HL),A		;
	pop	BC		;
	dec	BC		;
	dec	BC		;
	dec	BC		;
	inc	HL		;
	ld	(HL),C		;
	inc	HL		;
	ld	(HL),B		;
	pop	AF		;
	inc	HL		;
	ld	(HL),A		;
	ld	H,D		;
	ld	L,E		;
	dec	DE		;
	ld	(HL),#0x00	;
	pop	BC		;
	lddr			; Copy Bytes
			
;; DIM-SIZES
L147F:	pop	BC		;
	ld	(HL),B		;
	dec	HL		;
	ld	(HL),C		;
	dec	HL		;
	dec	A		;
	jr	NZ,L147F	; back to DIM-SIZES
			
	ret			; return.
			
; ---------------------
; THE 'RESERVE' ROUTINE
; ---------------------
;
;
			
;; RESERVE
L1488:	ld	HL,(0x401A)	; address STKBOT
	dec	HL		; now last byte of workspace
	call	L099E		; routine MAKE-ROOM
	inc	HL		;
	inc	HL		;
	pop	BC		;
	ld	(0x4014),BC	; sv E_LINE_lo
	pop	BC		;
	ex	DE,HL		;
	inc	HL		;
	ret			;
			
; ---------------------------
; THE 'CLEAR' COMMAND ROUTINE
; ---------------------------
;
;
			
;; CLEAR
L149A:	ld	HL,(0x4010)	; sv VARS_lo
	ld	(HL),#0x80	;
	inc	HL		;
	ld	(0x4014),HL	; sv E_LINE_lo
			
; -----------------------
; THE 'X-TEMP' SUBROUTINE
; -----------------------
;
;
			
;; X-TEMP
L14A3:	ld	HL,(0x4014)	; sv E_LINE_lo
			
; ----------------------
; THE 'SET-STK' ROUTINES
; ----------------------
;
;
			
;; SET-STK-B
L14A6:	ld	(0x401A),HL	; sv STKBOT
			
;
			
;; SET-STK-E
L14A9:	ld	(0x401C),HL	; sv STKEND
	ret			;
			
; -----------------------
; THE 'CURSOR-IN' ROUTINE
; -----------------------
; This routine is called to set the edit line to the minimum cursor/newline
; and to set STKEND, the start of free space, at the next position.
			
;; CURSOR-IN
L14AD:	ld	HL,(0x4014)	; fetch start of edit line from E_LINE
	ld	(HL),#0x7F	; insert cursor character
			
	inc	HL		; point to next location.
	ld	(HL),#0x76	; insert NEWLINE character
	inc	HL		; point to next free location.
			
	ld	0x22(IY),#0x02	; set lower screen display file size DF_SZ
			
	jr	L14A6		; exit via SET-STK-B above
			
; ------------------------
; THE 'SET-MIN' SUBROUTINE
; ------------------------
;
;
			
;; SET-MIN
L14BC:	ld	HL,#0x405D	; normal location of calculator's memory area
	ld	(0x401F),HL	; update system variable MEM
	ld	HL,(0x401A)	; fetch STKBOT
	jr	L14A9		; back to SET-STK-E
			
			
; ------------------------------------
; THE 'RECLAIM THE END-MARKER' ROUTINE
; ------------------------------------
			
;; REC-V80
L14C7:	ld	DE,(0x4014)	; sv E_LINE_lo
	jp	L0A5D		; to RECLAIM-1
			
; ----------------------
; THE 'ALPHA' SUBROUTINE
; ----------------------
			
;; ALPHA
L14CE:	cp	#0x26		;
	jr	L14D4		; skip forward to ALPHA-2
			
			
; -------------------------
; THE 'ALPHANUM' SUBROUTINE
; -------------------------
			
;; ALPHANUM
L14D2:	cp	#0x1C		;
			
			
;; ALPHA-2
L14D4:	ccf			; Complement Carry Flag
	ret	NC		;
			
	cp	#0x40		;
	ret			;
			
			
; ------------------------------------------
; THE 'DECIMAL TO FLOATING POINT' SUBROUTINE
; ------------------------------------------
;
			
;; DEC-TO-FP
L14D9:	call	L1548		; routine INT-TO-FP gets first part
	cp	#0x1B		; is character a '.' ?
	jr	NZ,L14F5	; forward if not to E-FORMAT
			
			
	rst	#0x28		;; FP-CALC
	.db	0xA1		;;stk-one
	.db	0xC0		;;st-mem-0
	.db	0x02		;;delete
	.db	0x34		;;end-calc
			
			
;; NXT-DGT-1
L14E5:	rst	#0x20		; NEXT-CHAR
	call	L1514		; routine STK-DIGIT
	jr	C,L14F5		; forward to E-FORMAT
			
			
	rst	#0x28		;; FP-CALC
	.db	0xE0		;;get-mem-0
	.db	0xA4		;;stk-ten
	.db	0x05		;;division
	.db	0xC0		;;st-mem-0
	.db	0x04		;;multiply
	.db	0x0F		;;addition
	.db	0x34		;;end-calc
			
	jr	L14E5		; loop back till exhausted to NXT-DGT-1
			
; ---
			
;; E-FORMAT
L14F5:	cp	#0x2A		; is character 'E' ?
	ret	NZ		; return if not
			
	ld	0x5D(IY),#0xFF	; initialize sv MEM-0-1st to $FF TRUE
			
	rst	#0x20		; NEXT-CHAR
	cp	#0x15		; is character a '+' ?
	jr	Z,L1508		; forward if so to SIGN-DONE
			
	cp	#0x16		; is it a '-' ?
	jr	NZ,L1509	; forward if not to ST-E-PART
			
	inc	0x5D(IY)	; sv MEM-0-1st change to FALSE
			
;; SIGN-DONE
L1508:	rst	#0x20		; NEXT-CHAR
			
;; ST-E-PART
L1509:	call	L1548		; routine INT-TO-FP
			
	rst	#0x28		;; FP-CALC              m, e.
	.db	0xE0		;;get-mem-0             m, e, (1/0) TRUE/FALSE
	.db	0x00		;;jump-true
	.db	0x02		;;to L1511, E-POSTVE
	.db	0x18		;;neg                   m, -e
			
;; E-POSTVE
L1511:	.db	0x38		;;e-to-fp               x.
	.db	0x34		;;end-calc              x.
			
	ret			; return.
			
			
; --------------------------
; THE 'STK-DIGIT' SUBROUTINE
; --------------------------
;
			
;; STK-DIGIT
L1514:	cp	#0x1C		;
	ret	C		;
			
	cp	#0x26		;
	ccf			; Complement Carry Flag
	ret	C		;
			
	sub	#0x1C		;
			
; ------------------------
; THE 'STACK-A' SUBROUTINE
; ------------------------
;
			
			
;; STACK-A
L151D:	ld	C,A		;
	ld	B,#0x00		;
			
; -------------------------
; THE 'STACK-BC' SUBROUTINE
; -------------------------
; The ZX81 does not have an integer number format so the BC register contents
; must be converted to their full floating-point form.
			
;; STACK-BC
L1520:	ld	IY,#0x4000	; re-initialize the system variables pointer.
	push	BC		; save the integer value.
			
; now stack zero, five zero bytes as a starting point.
			
	rst	#0x28		;; FP-CALC
	.db	0xA0		;;stk-zero                      0.
	.db	0x34		;;end-calc
			
	pop	BC		; restore integer value.
			
	ld	(HL),#0x91	; place $91 in exponent         65536.
				; this is the maximum possible value
			
	ld	A,B		; fetch hi-byte.
	and	A		; test for zero.
	jr	NZ,L1536	; forward if not zero to STK-BC-2
			
	ld	(HL),A		; else make exponent zero again
	or	C		; test lo-byte
	ret	Z		; return if BC was zero - done.
			
; else  there has to be a set bit if only the value one.
			
	ld	B,C		; save C in B.
	ld	C,(HL)		; fetch zero to C
	ld	(HL),#0x89	; make exponent $89             256.
			
;; STK-BC-2
L1536:	dec	(HL)		; decrement exponent - halving number
	sla	C		;  C<-76543210<-0
	rl	B		;  C<-76543210<-C
	jr	NC,L1536	; loop back if no carry to STK-BC-2
			
	srl	B		;  0->76543210->C
	rr	C		;  C->76543210->C
			
	inc	HL		; address first byte of mantissa
	ld	(HL),B		; insert B
	inc	HL		; address second byte of mantissa
	ld	(HL),C		; insert C
			
	dec	HL		; point to the
	dec	HL		; exponent again
	ret			; return.
			
; ------------------------------------------
; THE 'INTEGER TO FLOATING POINT' SUBROUTINE
; ------------------------------------------
;
;
			
;; INT-TO-FP
L1548:	push	AF		;
			
	rst	#0x28		;; FP-CALC
	.db	0xA0		;;stk-zero
	.db	0x34		;;end-calc
			
	pop	AF		;
			
;; NXT-DGT-2
L154D:	call	L1514		; routine STK-DIGIT
	ret	C		;
			
			
	rst	#0x28		;; FP-CALC
	.db	0x01		;;exchange
	.db	0xA4		;;stk-ten
	.db	0x04		;;multiply
	.db	0x0F		;;addition
	.db	0x34		;;end-calc
			
			
	rst	#0x20		; NEXT-CHAR
	jr	L154D		; to NXT-DGT-2
			
			
; -------------------------------------------
; THE 'E-FORMAT TO FLOATING POINT' SUBROUTINE
; -------------------------------------------
; (Offset $38: 'e-to-fp')
; invoked from DEC-TO-FP and PRINT-FP.
; e.g. 2.3E4 is 23000.
; This subroutine evaluates xEm where m is a positive or negative integer.
; At a simple level x is multiplied by ten for every unit of m.
; If the decimal exponent m is negative then x is divided by ten for each unit.
; A short-cut is taken if the exponent is greater than seven and in this
; case the exponent is reduced by seven and the value is multiplied or divided
; by ten million.
; Note. for the ZX Spectrum an even cleverer method was adopted which involved
; shifting the bits out of the exponent so the result was achieved with six
; shifts at most. The routine below had to be completely re-written mostly
; in Z80 machine code.
; Although no longer operable, the calculator literal was retained for old
; times sake, the routine being invoked directly from a machine code CALL.
;
; On entry in the ZX81, m, the exponent, is the 'last value', and the
; floating-point decimal mantissa is beneath it.
			
			
;; e-to-fp
L155A:	rst	#0x28		;; FP-CALC              x, m.
	.db	0x2D		;;duplicate             x, m, m.
	.db	0x32		;;less-0                x, m, (1/0).
	.db	0xC0		;;st-mem-0              x, m, (1/0).
	.db	0x02		;;delete                x, m.
	.db	0x27		;;abs                   x, +m.
			
;; E-LOOP
L1560:	.db	0xA1		;;stk-one               x, m,1.
	.db	0x03		;;subtract              x, m-1.
	.db	0x2D		;;duplicate             x, m-1,m-1.
	.db	0x32		;;less-0                x, m-1, (1/0).
	.db	0x00		;;jump-true             x, m-1.
	.db	0x22		;;to L1587, E-END       x, m-1.
			
	.db	0x2D		;;duplicate             x, m-1, m-1.
	.db	0x30		;;stk-data
	.db	0x33		;;Exponent: $83, Bytes: 1
			
	.db	0x40		;;(+00,+00,+00)         x, m-1, m-1, 6.
	.db	0x03		;;subtract              x, m-1, m-7.
	.db	0x2D		;;duplicate             x, m-1, m-7, m-7.
	.db	0x32		;;less-0                x, m-1, m-7, (1/0).
	.db	0x00		;;jump-true             x, m-1, m-7.
	.db	0x0C		;;to L157A, E-LOW
			
; but if exponent m is higher than 7 do a bigger chunk.
; multiplying (or dividing if negative) by 10 million - 1e7.
			
	.db	0x01		;;exchange              x, m-7, m-1.
	.db	0x02		;;delete                x, m-7.
	.db	0x01		;;exchange              m-7, x.
	.db	0x30		;;stk-data
	.db	0x80		;;Bytes: 3
	.db	0x48		;;Exponent $98
	.db	0x18,0x96,0x80	;;(+00)                 m-7, x, 10,000,000 (=f)
	.db	0x2F		;;jump
	.db	0x04		;;to L157D, E-CHUNK
			
; ---
			
;; E-LOW
L157A:	.db	0x02		;;delete                x, m-1.
	.db	0x01		;;exchange              m-1, x.
	.db	0xA4		;;stk-ten               m-1, x, 10 (=f).
			
;; E-CHUNK
L157D:	.db	0xE0		;;get-mem-0             m-1, x, f, (1/0)
	.db	0x00		;;jump-true             m-1, x, f
	.db	0x04		;;to L1583, E-DIVSN
			
	.db	0x04		;;multiply              m-1, x*f.
	.db	0x2F		;;jump
	.db	0x02		;;to L1584, E-SWAP
			
; ---
			
;; E-DIVSN
L1583:	.db	0x05		;;division              m-1, x/f (= new x).
			
;; E-SWAP
L1584:	.db	0x01		;;exchange              x, m-1 (= new m).
	.db	0x2F		;;jump                  x, m.
	.db	0xDA		;;to L1560, E-LOOP
			
; ---
			
;; E-END
L1587:	.db	0x02		;;delete                x. (-1)
	.db	0x34		;;end-calc              x.
			
	ret			; return.
			
; -------------------------------------
; THE 'FLOATING-POINT TO BC' SUBROUTINE
; -------------------------------------
; The floating-point form on the calculator stack is compressed directly into
; the BC register rounding up if necessary.
; Valid range is 0 to 65535.4999
			
;; FP-TO-BC
L158A:	call	L13F8		; routine STK-FETCH - exponent to A
				; mantissa to EDCB.
	and	A		; test for value zero.
	jr	NZ,L1595	; forward if not to FPBC-NZRO
			
; else value is zero
			
	ld	B,A		; zero to B
	ld	C,A		; also to C
	push	AF		; save the flags on machine stack
	jr	L15C6		; forward to FPBC-END
			
; ---
			
; EDCB  =>  BCE
			
;; FPBC-NZRO
L1595:	ld	B,E		; transfer the mantissa from EDCB
	ld	E,C		; to BCE. Bit 7 of E is the 17th bit which
	ld	C,D		; will be significant for rounding if the
				; number is already normalized.
			
	sub	#0x91		; subtract 65536
	ccf			; complement carry flag
	bit	7,B		; test sign bit
	push	AF		; push the result
			
	set	7,B		; set the implied bit
	jr	C,L15C6		; forward with carry from SUB/CCF to FPBC-END
				; number is too big.
			
	inc	A		; increment the exponent and
	neg			; negate to make range $00 - $0F
			
	cp	#0x08		; test if one or two bytes
	jr	C,L15AF		; forward with two to BIG-INT
			
	ld	E,C		; shift mantissa
	ld	C,B		; 8 places right
	ld	B,#0x00		; insert a zero in B
	sub	#0x08		; reduce exponent by eight
			
;; BIG-INT
L15AF:	and	A		; test the exponent
	ld	D,A		; save exponent in D.
			
	ld	A,E		; fractional bits to A
	rlca			; rotate most significant bit to carry for
				; rounding of an already normal number.
			
	jr	Z,L15BC		; forward if exponent zero to EXP-ZERO
				; the number is normalized
			
;; FPBC-NORM
L15B5:	srl	B		;   0->76543210->C
	rr	C		;   C->76543210->C
			
	dec	D		; decrement exponent
			
	jr	NZ,L15B5	; loop back till zero to FPBC-NORM
			
;; EXP-ZERO
L15BC:	jr	NC,L15C6	; forward without carry to NO-ROUND
			
	inc	BC		; round up.
	ld	A,B		; test result
	or	C		; for zero
	jr	NZ,L15C6	; forward if not to GRE-ZERO
			
	pop	AF		; restore sign flag
	scf			; set carry flag to indicate overflow
	push	AF		; save combined flags again
			
;; FPBC-END
L15C6:	push	BC		; save BC value
			
; set HL and DE to calculator stack pointers.
			
	rst	#0x28		;; FP-CALC
	.db	0x34		;;end-calc
			
			
	pop	BC		; restore BC value
	pop	AF		; restore flags
	ld	A,C		; copy low byte to A also.
	ret			; return
			
; ------------------------------------
; THE 'FLOATING-POINT TO A' SUBROUTINE
; ------------------------------------
;
;
			
;; FP-TO-A
L15CD:	call	L158A		; routine FP-TO-BC
	ret	C		;
			
	push	AF		;
	dec	B		;
	inc	B		;
	jr	Z,L15D9		; forward if in range to FP-A-END
			
	pop	AF		; fetch result
	scf			; set carry flag signaling overflow
	ret			; return
			
;; FP-A-END
L15D9:	pop	AF		;
	ret			;
			
			
; ----------------------------------------------
; THE 'PRINT A FLOATING-POINT NUMBER' SUBROUTINE
; ----------------------------------------------
; prints 'last value' x on calculator stack.
; There are a wide variety of formats see Chapter 4.
; e.g.
; PI            prints as       3.1415927
; .123          prints as       0.123
; .0123         prints as       .0123
; 999999999999  prints as       1000000000000
; 9876543210123 prints as       9876543200000
			
; Begin by isolating zero and just printing the '0' character
; for that case. For negative numbers print a leading '-' and
; then form the absolute value of x.
			
;; PRINT-FP
L15DB:	rst	#0x28		;; FP-CALC              x.
	.db	0x2D		;;duplicate             x, x.
	.db	0x32		;;less-0                x, (1/0).
	.db	0x00		;;jump-true
	.db	0x0B		;;to L15EA, PF-NGTVE    x.
			
	.db	0x2D		;;duplicate             x, x
	.db	0x33		;;greater-0             x, (1/0).
	.db	0x00		;;jump-true
	.db	0x0D		;;to L15F0, PF-POSTVE   x.
			
	.db	0x02		;;delete                .
	.db	0x34		;;end-calc              .
			
	ld	A,#0x1C		; load accumulator with character '0'
			
	rst	#0x10		; PRINT-A
	ret			; return.                               >>
			
; ---
			
;; PF-NEGTVE
L15EA:	.db	0x27		; abs                   +x.
	.db	0x34		;;end-calc              x.
			
	ld	A,#0x16		; load accumulator with '-'
			
	rst	#0x10		; PRINT-A
			
	rst	#0x28		;; FP-CALC              x.
			
;; PF-POSTVE
L15F0:	.db	0x34		;;end-calc              x.
			
; register HL addresses the exponent of the floating-point value.
; if positive, and point floats to left, then bit 7 is set.
			
	ld	A,(HL)		; pick up the exponent byte
	call	L151D		; routine STACK-A places on calculator stack.
			
; now calculate roughly the number of digits, n, before the decimal point by
; subtracting a half from true exponent and multiplying by log to
; the base 10 of 2.
; The true number could be one higher than n, the integer result.
			
	rst	#0x28		;; FP-CALC              x, e.
	.db	0x30		;;stk-data
	.db	0x78		;;Exponent: $88, Bytes: 2
	.db	0x00,0x80	;;(+00,+00)             x, e, 128.5.
	.db	0x03		;;subtract              x, e -.5.
	.db	0x30		;;stk-data
	.db	0xEF		;;Exponent: $7F, Bytes: 4
	.db	0x1A,#0x20,0x9A,#0x85	;;                      .30103 (log10 2)
	.db	0x04		;;multiply              x,
	.db	0x24		;;int
	.db	0xC1		;;st-mem-1              x, n.
			
			
	.db	0x30		;;stk-data
	.db	0x34		;;Exponent: $84, Bytes: 1
	.db	0x00		;;(+00,+00,+00)         x, n, 8.
			
	.db	0x03		;;subtract              x, n-8.
	.db	0x18		;;neg                   x, 8-n.
	.db	0x38		;;e-to-fp               x * (10^n)
			
; finally the 8 or 9 digit decimal is rounded.
; a ten-digit integer can arise in the case of, say, 999999999.5
; which gives 1000000000.
			
	.db	0xA2		;;stk-half
	.db	0x0F		;;addition
	.db	0x24		;;int                   i.
	.db	0x34		;;end-calc
			
; If there were 8 digits then final rounding will take place on the calculator
; stack above and the next two instructions insert a masked zero so that
; no further rounding occurs. If the result is a 9 digit integer then
; rounding takes place within the buffer.
			
	ld	HL,#0x406B	; address system variable MEM-2-5th
				; which could be the 'ninth' digit.
	ld	(HL),#0x90	; insert the value $90  10010000
			
; now starting from lowest digit lay down the 8, 9 or 10 digit integer
; which represents the significant portion of the number
; e.g. PI will be the nine-digit integer 314159265
			
	ld	B,#0x0A		; count is ten digits.
			
;; PF-LOOP
L1615:	inc	HL		; increase pointer
			
	push	HL		; preserve buffer address.
	push	BC		; preserve counter.
			
	rst	#0x28		;; FP-CALC              i.
	.db	0xA4		;;stk-ten               i, 10.
	.db	0x2E		;;n-mod-m               i mod 10, i/10
	.db	0x01		;;exchange              i/10, remainder.
	.db	0x34		;;end-calc
			
	call	L15CD		; routine FP-TO-A  $00-$09
			
	or	#0x90		; make left hand nibble 9
			
	pop	BC		; restore counter
	pop	HL		; restore buffer address.
			
	ld	(HL),A		; insert masked digit in buffer.
	djnz	L1615		; loop back for all ten to PF-LOOP
			
; the most significant digit will be last but if the number is exhausted then
; the last one or two positions will contain zero ($90).
			
; e.g. for 'one' we have zero as estimate of leading digits.
; 1*10^8 100000000 as integer value
; 90 90 90 90 90   90 90 90 91 90 as buffer mem3/mem4 contents.
			
			
	inc	HL		; advance pointer to one past buffer
	ld	BC,#0x0008	; set C to 8 ( B is already zero )
	push	HL		; save pointer.
			
;; PF-NULL
L162C:	dec	HL		; decrease pointer
	ld	A,(HL)		; fetch masked digit
	cp	#0x90		; is it a leading zero ?
	jr	Z,L162C		; loop back if so to PF-NULL
			
; at this point a significant digit has been found. carry is reset.
			
	sbc	HL,BC		; subtract eight from the address.
	push	HL		; ** save this pointer too
	ld	A,(HL)		; fetch addressed byte
	add	A,#0x6B		; add $6B - forcing a round up ripple
				; if  $95 or over.
	push	AF		; save the carry result.
			
; now enter a loop to round the number. After rounding has been considered
; a zero that has arisen from rounding or that was present at that position
; originally is changed from $90 to $80.
			
;; PF-RND-LP
L1639:	pop	AF		; retrieve carry from machine stack.
	inc	HL		; increment address
	ld	A,(HL)		; fetch new byte
	adc	A,#0x00		; add in any carry
			
	daa			; decimal adjust accumulator
				; carry will ripple through the '9'
			
	push	AF		; save carry on machine stack.
	and	#0x0F		; isolate character 0 - 9 AND set zero flag
				; if zero.
	ld	(HL),A		; place back in location.
	set	7,(HL)		; set bit 7 to show printable.
				; but not if trailing zero after decimal point.
	jr	Z,L1639		; back if a zero to PF-RND-LP
				; to consider further rounding and/or trailing
				; zero identification.
			
	pop	AF		; balance stack
	pop	HL		; ** retrieve lower pointer
			
; now insert 6 trailing zeros which are printed if before the decimal point
; but mark the end of printing if after decimal point.
; e.g. 9876543210123 is printed as 9876543200000
; 123.456001 is printed as 123.456
			
	ld	B,#0x06		; the count is six.
			
;; PF-ZERO-6
L164B:	ld	(HL),#0x80	; insert a masked zero
	dec	HL		; decrease pointer.
	djnz	L164B		; loop back for all six to PF-ZERO-6
			
; n-mod-m reduced the number to zero and this is now deleted from the calculator
; stack before fetching the original estimate of leading digits.
			
			
	rst	#0x28		;; FP-CALC              0.
	.db	0x02		;;delete                .
	.db	0xE1		;;get-mem-1             n.
	.db	0x34		;;end-calc              n.
			
	call	L15CD		; routine FP-TO-A
	jr	Z,L165B		; skip forward if positive to PF-POS
			
	neg			; negate makes positive
			
;; PF-POS
L165B:	ld	E,A		; transfer count of digits to E
	inc	E		; increment twice
	inc	E		;
	pop	HL		; * retrieve pointer to one past buffer.
			
;; GET-FIRST
L165F:	dec	HL		; decrement address.
	dec	E		; decrement digit counter.
	ld	A,(HL)		; fetch masked byte.
	and	#0x0F		; isolate right-hand nibble.
	jr	Z,L165F		; back with leading zero to GET-FIRST
			
; now determine if E-format printing is needed
			
	ld	A,E		; transfer now accurate number count to A.
	sub	#0x05		; subtract five
	cp	#0x08		; compare with 8 as maximum digits is 13.
	jp	P,L1682		; forward if positive to PF-E-FMT
			
	cp	#0xF6		; test for more than four zeros after point.
	jp	M,L1682		; forward if so to PF-E-FMT
			
	add	A,#0x06		; test for zero leading digits, e.g. 0.5
	jr	Z,L16BF		; forward if so to PF-ZERO-1
			
	jp	M,L16B2		; forward if more than one zero to PF-ZEROS
			
; else digits before the decimal point are to be printed
			
	ld	B,A		; count of leading characters to B.
			
;; PF-NIB-LP
L167B:	call	L16D0		; routine PF-NIBBLE
	djnz	L167B		; loop back for counted numbers to PF-NIB-LP
			
	jr	L16C2		; forward to consider decimal part to PF-DC-OUT
			
; ---
			
;; PF-E-FMT
L1682:	ld	B,E		; count to B
	call	L16D0		; routine PF-NIBBLE prints one digit.
	call	L16C2		; routine PF-DC-OUT considers fractional part.
			
	ld	A,#0x2A		; prepare character 'E'
	rst	#0x10		; PRINT-A
			
	ld	A,B		; transfer exponent to A
	and	A		; test the sign.
	jp	P,L1698		; forward if positive to PF-E-POS
			
	neg			; negate the negative exponent.
	ld	B,A		; save positive exponent in B.
			
	ld	A,#0x16		; prepare character '-'
	jr	L169A		; skip forward to PF-E-SIGN
			
; ---
			
;; PF-E-POS
L1698:	ld	A,#0x15		; prepare character '+'
			
;; PF-E-SIGN
L169A:	rst	#0x10		; PRINT-A
			
; now convert the integer exponent in B to two characters.
; it will be less than 99.
			
	ld	A,B		; fetch positive exponent.
	ld	B,#0xFF		; initialize left hand digit to minus one.
			
;; PF-E-TENS
L169E:	inc	B		; increment ten count
	sub	#0x0A		; subtract ten from exponent
	jr	NC,L169E	; loop back if greater than ten to PF-E-TENS
			
	add	A,#0x0A		; reverse last subtraction
	ld	C,A		; transfer remainder to C
			
	ld	A,B		; transfer ten value to A.
	and	A		; test for zero.
	jr	Z,L16AD		; skip forward if so to PF-E-LOW
			
	call	L07EB		; routine OUT-CODE prints as digit '1' - '9'
			
;; PF-E-LOW
L16AD:	ld	A,C		; low byte to A
	call	L07EB		; routine OUT-CODE prints final digit of the
				; exponent.
	ret			; return.                               >>
			
; ---
			
; this branch deals with zeros after decimal point.
; e.g.      .01 or .0000999
			
;; PF-ZEROS
L16B2:	neg			; negate makes number positive 1 to 4.
	ld	B,A		; zero count to B.
			
	ld	A,#0x1B		; prepare character '.'
	rst	#0x10		; PRINT-A
			
	ld	A,#0x1C		; prepare a '0'
			
;; PF-ZRO-LP
L16BA:	rst	#0x10		; PRINT-A
	djnz	L16BA		; loop back to PF-ZRO-LP
			
	jr	L16C8		; forward to PF-FRAC-LP
			
; ---
			
; there is  a need to print a leading zero e.g. 0.1 but not with .01
			
;; PF-ZERO-1
L16BF:	ld	A,#0x1C		; prepare character '0'.
	rst	#0x10		; PRINT-A
			
; this subroutine considers the decimal point and any trailing digits.
; if the next character is a marked zero, $80, then nothing more to print.
			
;; PF-DC-OUT
L16C2:	dec	(HL)		; decrement addressed character
	inc	(HL)		; increment it again
	ret	PE		; return with overflow  (was 128) >>
				; as no fractional part
			
; else there is a fractional part so print the decimal point.
			
	ld	A,#0x1B		; prepare character '.'
	rst	#0x10		; PRINT-A
			
; now enter a loop to print trailing digits
			
;; PF-FRAC-LP
L16C8:	dec	(HL)		; test for a marked zero.
	inc	(HL)		;
	ret	PE		; return when digits exhausted          >>
			
	call	L16D0		; routine PF-NIBBLE
	jr	L16C8		; back for all fractional digits to PF-FRAC-LP.
			
; ---
			
; subroutine to print right-hand nibble
			
;; PF-NIBBLE
L16D0:	ld	A,(HL)		; fetch addressed byte
	and	#0x0F		; mask off lower 4 bits
	call	L07EB		; routine OUT-CODE
	dec	HL		; decrement pointer.
	ret			; return.
			
			
; -------------------------------
; THE 'PREPARE TO ADD' SUBROUTINE
; -------------------------------
; This routine is called twice to prepare each floating point number for
; addition, in situ, on the calculator stack.
; The exponent is picked up from the first byte which is then cleared to act
; as a sign byte and accept any overflow.
; If the exponent is zero then the number is zero and an early return is made.
; The now redundant sign bit of the mantissa is set and if the number is
; negative then all five bytes of the number are twos-complemented to prepare
; the number for addition.
; On the second invocation the exponent of the first number is in B.
			
			
;; PREP-ADD
L16D8:	ld	A,(HL)		; fetch exponent.
	ld	(HL),#0x00	; make this byte zero to take any overflow and
				; default to positive.
	and	A		; test stored exponent for zero.
	ret	Z		; return with zero flag set if number is zero.
			
	inc	HL		; point to first byte of mantissa.
	bit	7,(HL)		; test the sign bit.
	set	7,(HL)		; set it to its implied state.
	dec	HL		; set pointer to first byte again.
	ret	Z		; return if bit indicated number is positive.>>
			
; if negative then all five bytes are twos complemented starting at LSB.
			
	push	BC		; save B register contents.
	ld	BC,#0x0005	; set BC to five.
	add	HL,BC		; point to location after 5th byte.
	ld	B,C		; set the B counter to five.
	ld	C,A		; store original exponent in C.
	scf			; set carry flag so that one is added.
			
; now enter a loop to twos-complement the number.
; The first of the five bytes becomes $FF to denote a negative number.
			
;; NEG-BYTE
L16EC:	dec	HL		; point to first or more significant byte.
	ld	A,(HL)		; fetch to accumulator.
	cpl			; complement.
	adc	A,#0x00		; add in initial carry or any subsequent carry.
	ld	(HL),A		; place number back.
	djnz	L16EC		; loop back five times to NEG-BYTE
			
	ld	A,C		; restore the exponent to accumulator.
	pop	BC		; restore B register contents.
			
	ret			; return.
			
; ----------------------------------
; THE 'FETCH TWO NUMBERS' SUBROUTINE
; ----------------------------------
; This routine is used by addition, multiplication and division to fetch
; the two five-byte numbers addressed by HL and DE from the calculator stack
; into the Z80 registers.
; The HL register may no longer point to the first of the two numbers.
; Since the 32-bit addition operation is accomplished using two Z80 16-bit
; instructions, it is important that the lower two bytes of each mantissa are
; in one set of registers and the other bytes all in the alternate set.
;
; In: HL = highest number, DE= lowest number
;
;         : alt':   :
; Out:    :H,B-C:C,B: num1
;         :L,D-E:D-E: num2
			
;; FETCH-TWO
L16F7:	push	HL		; save HL
	push	AF		; save A - result sign when used from division.
			
	ld	C,(HL)		;
	inc	HL		;
	ld	B,(HL)		;
	ld	(HL),A		; insert sign when used from multiplication.
	inc	HL		;
	ld	A,C		; m1
	ld	C,(HL)		;
	push	BC		; PUSH m2 m3
			
	inc	HL		;
	ld	C,(HL)		; m4
	inc	HL		;
	ld	B,(HL)		; m5  BC holds m5 m4
			
	ex	DE,HL		; make HL point to start of second number.
			
	ld	D,A		; m1
	ld	E,(HL)		;
	push	DE		; PUSH m1 n1
			
	inc	HL		;
	ld	D,(HL)		;
	inc	HL		;
	ld	E,(HL)		;
	push	DE		; PUSH n2 n3
			
	exx			; - - - - - - -
			
	pop	DE		; POP n2 n3
	pop	HL		; POP m1 n1
	pop	BC		; POP m2 m3
			
	exx			; - - - - - - -
			
	inc	HL		;
	ld	D,(HL)		;
	inc	HL		;
	ld	E,(HL)		; DE holds n4 n5
			
	pop	AF		; restore saved
	pop	HL		; registers.
	ret			; return.
			
; -----------------------------
; THE 'SHIFT ADDEND' SUBROUTINE
; -----------------------------
; The accumulator A contains the difference between the two exponents.
; This is the lowest of the two numbers to be added
			
;; SHIFT-FP
L171A:	and	A		; test difference between exponents.
	ret	Z		; return if zero. both normal.
			
	cp	#0x21		; compare with 33 bits.
	jr	NC,L1736	; forward if greater than 32 to ADDEND-0
			
	push	BC		; preserve BC - part
	ld	B,A		; shift counter to B.
			
; Now perform B right shifts on the addend  L'D'E'D E
; to bring it into line with the augend     H'B'C'C B
			
;; ONE-SHIFT
L1722:	exx			; - - -
	sra	L		;    76543210->C    bit 7 unchanged.
	rr	D		; C->76543210->C
	rr	E		; C->76543210->C
	exx			; - - -
	rr	D		; C->76543210->C
	rr	E		; C->76543210->C
	djnz	L1722		; loop back B times to ONE-SHIFT
			
	pop	BC		; restore BC
	ret	NC		; return if last shift produced no carry.   >>
			
; if carry flag was set then accuracy is being lost so round up the addend.
			
	call	L1741		; routine ADD-BACK
	ret	NZ		; return if not FF 00 00 00 00
			
; this branch makes all five bytes of the addend zero and is made during
; addition when the exponents are too far apart for the addend bits to
; affect the result.
			
;; ADDEND-0
L1736:	exx			; select alternate set for more significant
				; bytes.
	xor	A		; clear accumulator.
			
			
; this entry point (from multiplication) sets four of the bytes to zero or if
; continuing from above, during addition, then all five bytes are set to zero.
			
;; ZEROS-4/5
L1738:	ld	L,#0x00		; set byte 1 to zero.
	ld	D,A		; set byte 2 to A.
	ld	E,L		; set byte 3 to zero.
	exx			; select main set
	ld	DE,#0x0000	; set lower bytes 4 and 5 to zero.
	ret			; return.
			
; -------------------------
; THE 'ADD-BACK' SUBROUTINE
; -------------------------
; Called from SHIFT-FP above during addition and after normalization from
; multiplication.
; This is really a 32-bit increment routine which sets the zero flag according
; to the 32-bit result.
; During addition, only negative numbers like FF FF FF FF FF,
; the twos-complement version of xx 80 00 00 01 say
; will result in a full ripple FF 00 00 00 00.
; FF FF FF FF FF when shifted right is unchanged by SHIFT-FP but sets the
; carry invoking this routine.
			
;; ADD-BACK
L1741:	inc	E		;
	ret	NZ		;
			
	inc	D		;
	ret	NZ		;
			
	exx			;
	inc	E		;
	jr	NZ,L174A	; forward if no overflow to ALL-ADDED
			
	inc	D		;
			
;; ALL-ADDED
L174A:	exx			;
	ret			; return with zero flag set for zero mantissa.
			
			
; ---------------------------
; THE 'SUBTRACTION' OPERATION
; ---------------------------
; just switch the sign of subtrahend and do an add.
			
;; subtract
L174C:	ld	A,(DE)		; fetch exponent byte of second number the
				; subtrahend.
	and	A		; test for zero
	ret	Z		; return if zero - first number is result.
			
	inc	DE		; address the first mantissa byte.
	ld	A,(DE)		; fetch to accumulator.
	xor	#0x80		; toggle the sign bit.
	ld	(DE),A		; place back on calculator stack.
	dec	DE		; point to exponent byte.
				; continue into addition routine.
			
; ------------------------
; THE 'ADDITION' OPERATION
; ------------------------
; The addition operation pulls out all the stops and uses most of the Z80's
; registers to add two floating-point numbers.
; This is a binary operation and on entry, HL points to the first number
; and DE to the second.
			
;; addition
L1755:	exx			; - - -
	push	HL		; save the pointer to the next literal.
	exx			; - - -
			
	push	DE		; save pointer to second number
	push	HL		; save pointer to first number - will be the
				; result pointer on calculator stack.
			
	call	L16D8		; routine PREP-ADD
	ld	B,A		; save first exponent byte in B.
	ex	DE,HL		; switch number pointers.
	call	L16D8		; routine PREP-ADD
	ld	C,A		; save second exponent byte in C.
	cp	B		; compare the exponent bytes.
	jr	NC,L1769	; forward if second higher to SHIFT-LEN
			
	ld	A,B		; else higher exponent to A
	ld	B,C		; lower exponent to B
	ex	DE,HL		; switch the number pointers.
			
;; SHIFT-LEN
L1769:	push	AF		; save higher exponent
	sub	B		; subtract lower exponent
			
	call	L16F7		; routine FETCH-TWO
	call	L171A		; routine SHIFT-FP
			
	pop	AF		; restore higher exponent.
	pop	HL		; restore result pointer.
	ld	(HL),A		; insert exponent byte.
	push	HL		; save result pointer again.
			
; now perform the 32-bit addition using two 16-bit Z80 add instructions.
			
	ld	L,B		; transfer low bytes of mantissa individually
	ld	H,C		; to HL register
			
	add	HL,DE		; the actual binary addition of lower bytes
			
; now the two higher byte pairs that are in the alternate register sets.
			
	exx			; switch in set
	ex	DE,HL		; transfer high mantissa bytes to HL register.
			
	adc	HL,BC		; the actual addition of higher bytes with
				; any carry from first stage.
			
	ex	DE,HL		; result in DE, sign bytes ($FF or $00) to HL
			
; now consider the two sign bytes
			
	ld	A,H		; fetch sign byte of num1
			
	adc	A,L		; add including any carry from mantissa
				; addition. 00 or 01 or FE or FF
			
	ld	L,A		; result in L.
			
; possible outcomes of signs and overflow from mantissa are
;
;  H +  L + carry =  L    RRA  XOR L  RRA
; ------------------------------------------------------------
; 00 + 00         = 00    00   00
; 00 + 00 + carry = 01    00   01     carry
; FF + FF         = FE C  FF   01     carry
; FF + FF + carry = FF C  FF   00
; FF + 00         = FF    FF   00
; FF + 00 + carry = 00 C  80   80
			
	rra			; C->76543210->C
	xor	L		; set bit 0 if shifting required.
			
	exx			; switch back to main set
	ex	DE,HL		; full mantissa result now in D'E'D E registers.
	pop	HL		; restore pointer to result exponent on
				; the calculator stack.
			
	rra			; has overflow occurred ?
	jr	NC,L1790	; skip forward if not to TEST-NEG
			
; if the addition of two positive mantissas produced overflow or if the
; addition of two negative mantissas did not then the result exponent has to
; be incremented and the mantissa shifted one place to the right.
			
	ld	A,#0x01		; one shift required.
	call	L171A		; routine SHIFT-FP performs a single shift
				; rounding any lost bit
	inc	(HL)		; increment the exponent.
	jr	Z,L17B3		; forward to ADD-REP-6 if the exponent
				; wraps round from FF to zero as number is too
				; big for the system.
			
; at this stage the exponent on the calculator stack is correct.
			
;; TEST-NEG
L1790:	exx			; switch in the alternate set.
	ld	A,L		; load result sign to accumulator.
	and	#0x80		; isolate bit 7 from sign byte setting zero
				; flag if positive.
	exx			; back to main set.
			
	inc	HL		; point to first byte of mantissa
	ld	(HL),A		; insert $00 positive or $80 negative at
				; position on calculator stack.
			
	dec	HL		; point to exponent again.
	jr	Z,L17B9		; forward if positive to GO-NC-MLT
			
; a negative number has to be twos-complemented before being placed on stack.
			
	ld	A,E		; fetch lowest (rightmost) mantissa byte.
	neg			; Negate
	ccf			; Complement Carry Flag
	ld	E,A		; place back in register
			
	ld	A,D		; ditto
	cpl			;
	adc	A,#0x00		;
	ld	D,A		;
			
	exx			; switch to higher (leftmost) 16 bits.
			
	ld	A,E		; ditto
	cpl			;
	adc	A,#0x00		;
	ld	E,A		;
			
	ld	A,D		; ditto
	cpl			;
	adc	A,#0x00		;
	jr	NC,L17B7	; forward without overflow to END-COMPL
			
; else entire mantissa is now zero.  00 00 00 00
			
	rra			; set mantissa to 80 00 00 00
	exx			; switch.
	inc	(HL)		; increment the exponent.
			
;; ADD-REP-6
L17B3:	jp	Z,L1880		; jump forward if exponent now zero to REPORT-6
				; 'Number too big'
			
	exx			; switch back to alternate set.
			
;; END-COMPL
L17B7:	ld	D,A		; put first byte of mantissa back in DE.
	exx			; switch to main set.
			
;; GO-NC-MLT
L17B9:	xor	A		; clear carry flag and
				; clear accumulator so no extra bits carried
				; forward as occurs in multiplication.
			
	jr	L1828		; forward to common code at TEST-NORM
				; but should go straight to NORMALIZE.
			
			
; ----------------------------------------------
; THE 'PREPARE TO MULTIPLY OR DIVIDE' SUBROUTINE
; ----------------------------------------------
; this routine is called twice from multiplication and twice from division
; to prepare each of the two numbers for the operation.
; Initially the accumulator holds zero and after the second invocation bit 7
; of the accumulator will be the sign bit of the result.
			
;; PREP-M/D
L17BC:	scf			; set carry flag to signal number is zero.
	dec	(HL)		; test exponent
	inc	(HL)		; for zero.
	ret	Z		; return if zero with carry flag set.
			
	inc	HL		; address first mantissa byte.
	xor	(HL)		; exclusive or the running sign bit.
	set	7,(HL)		; set the implied bit.
	dec	HL		; point to exponent byte.
	ret			; return.
			
; ------------------------------
; THE 'MULTIPLICATION' OPERATION
; ------------------------------
;
;
			
;; multiply
L17C6:	xor	A		; reset bit 7 of running sign flag.
	call	L17BC		; routine PREP-M/D
	ret	C		; return if number is zero.
				; zero * anything = zero.
			
	exx			; - - -
	push	HL		; save pointer to 'next literal'
	exx			; - - -
			
	push	DE		; save pointer to second number
			
	ex	DE,HL		; make HL address second number.
			
	call	L17BC		; routine PREP-M/D
			
	ex	DE,HL		; HL first number, DE - second number
	jr	C,L1830		; forward with carry to ZERO-RSLT
				; anything * zero = zero.
			
	push	HL		; save pointer to first number.
			
	call	L16F7		; routine FETCH-TWO fetches two mantissas from
				; calc stack to B'C'C,B  D'E'D E
				; (HL will be overwritten but the result sign
				; in A is inserted on the calculator stack)
			
	ld	A,B		; transfer low mantissa byte of first number
	and	A		; clear carry.
	sbc	HL,HL		; a short form of LD HL,$0000 to take lower
				; two bytes of result. (2 program bytes)
	exx			; switch in alternate set
	push	HL		; preserve HL
	sbc	HL,HL		; set HL to zero also to take higher two bytes
				; of the result and clear carry.
	exx			; switch back.
			
	ld	B,#0x21		; register B can now be used to count thirty
				; three shifts.
	jr	L17F8		; forward to loop entry point STRT-MLT
			
; ---
			
; The multiplication loop is entered at  STRT-LOOP.
			
;; MLT-LOOP
L17E7:	jr	NC,L17EE	; forward if no carry to NO-ADD
			
				; else add in the multiplicand.
			
	add	HL,DE		; add the two low bytes to result
	exx			; switch to more significant bytes.
	adc	HL,DE		; add high bytes of multiplicand and any carry.
	exx			; switch to main set.
			
; in either case shift result right into B'C'C A
			
;; NO-ADD
L17EE:	exx			; switch to alternate set
	rr	H		; C > 76543210 > C
	rr	L		; C > 76543210 > C
	exx			;
	rr	H		; C > 76543210 > C
	rr	L		; C > 76543210 > C
			
;; STRT-MLT
L17F8:	exx			; switch in alternate set.
	rr	B		; C > 76543210 > C
	rr	C		; C > 76543210 > C
	exx			; now main set
	rr	C		; C > 76543210 > C
	rra			; C > 76543210 > C
	djnz	L17E7		; loop back 33 times to MLT-LOOP
			
;
			
	ex	DE,HL		;
	exx			;
	ex	DE,HL		;
	exx			;
	pop	BC		;
	pop	HL		;
	ld	A,B		;
	add	A,C		;
	jr	NZ,L180E	; forward to MAKE-EXPT
			
	and	A		;
			
;; MAKE-EXPT
L180E:	dec	A		;
	ccf			; Complement Carry Flag
			
;; DIVN-EXPT
L1810:	rla			;
	ccf			; Complement Carry Flag
	rra			;
	jp	P,L1819		; forward to OFLW1-CLR
			
	jr	NC,L1880	; forward to REPORT-6
			
	and	A		;
			
;; OFLW1-CLR
L1819:	inc	A		;
	jr	NZ,L1824	; forward to OFLW2-CLR
			
	jr	C,L1824		; forward to OFLW2-CLR
			
	exx			;
	bit	7,D		;
	exx			;
	jr	NZ,L1880	; forward to REPORT-6
			
;; OFLW2-CLR
L1824:	ld	(HL),A		;
	exx			;
	ld	A,B		;
	exx			;
			
; addition joins here with carry flag clear.
			
;; TEST-NORM
L1828:	jr	NC,L183F	; forward to NORMALIZE
			
	ld	A,(HL)		;
	and	A		;
			
;; NEAR-ZERO
L182C:	ld	A,#0x80		; prepare to rescue the most significant bit
				; of the mantissa if it is set.
	jr	Z,L1831		; skip forward to SKIP-ZERO
			
;; ZERO-RSLT
L1830:	xor	A		; make mask byte zero signaling set five
				; bytes to zero.
			
;; SKIP-ZERO
L1831:	exx			; switch in alternate set
	and	D		; isolate most significant bit (if A is $80).
			
	call	L1738		; routine ZEROS-4/5 sets mantissa without
				; affecting any flags.
			
	rlca			; test if MSB set. bit 7 goes to bit 0.
				; either $00 -> $00 or $80 -> $01
	ld	(HL),A		; make exponent $01 (lowest) or $00 zero
	jr	C,L1868		; forward if first case to OFLOW-CLR
			
	inc	HL		; address first mantissa byte on the
				; calculator stack.
	ld	(HL),A		; insert a zero for the sign bit.
	dec	HL		; point to zero exponent
	jr	L1868		; forward to OFLOW-CLR
			
; ---
			
; this branch is common to addition and multiplication with the mantissa
; result still in registers D'E'D E .
			
;; NORMALIZE
L183F:	ld	B,#0x20		; a maximum of thirty-two left shifts will be
				; needed.
			
;; SHIFT-ONE
L1841:	exx			; address higher 16 bits.
	bit	7,D		; test the leftmost bit
	exx			; address lower 16 bits.
			
	jr	NZ,L1859	; forward if leftmost bit was set to NORML-NOW
			
	rlca			; this holds zero from addition, 33rd bit
				; from multiplication.
			
	rl	E		; C < 76543210 < C
	rl	D		; C < 76543210 < C
			
	exx			; address higher 16 bits.
			
	rl	E		; C < 76543210 < C
	rl	D		; C < 76543210 < C
			
	exx			; switch to main set.
			
	dec	(HL)		; decrement the exponent byte on the calculator
				; stack.
			
	jr	Z,L182C		; back if exponent becomes zero to NEAR-ZERO
				; it's just possible that the last rotation
				; set bit 7 of D. We shall see.
			
	djnz	L1841		; loop back to SHIFT-ONE
			
; if thirty-two left shifts were performed without setting the most significant
; bit then the result is zero.
			
	jr	L1830		; back to ZERO-RSLT
			
; ---
			
;; NORML-NOW
L1859:	rla			; for the addition path, A is always zero.
				; for the mult path, ...
			
	jr	NC,L1868	; forward to OFLOW-CLR
			
; this branch is taken only with multiplication.
			
	call	L1741		; routine ADD-BACK
			
	jr	NZ,L1868	; forward to OFLOW-CLR
			
	exx			;
	ld	D,#0x80		;
	exx			;
	inc	(HL)		;
	jr	Z,L1880		; forward to REPORT-6
			
; now transfer the mantissa from the register sets to the calculator stack
; incorporating the sign bit already there.
			
;; OFLOW-CLR
L1868:	push	HL		; save pointer to exponent on stack.
	inc	HL		; address first byte of mantissa which was
				; previously loaded with sign bit $00 or $80.
			
	exx			; - - -
	push	DE		; push the most significant two bytes.
	exx			; - - -
			
	pop	BC		; pop - true mantissa is now BCDE.
			
; now pick up the sign bit.
			
	ld	A,B		; first mantissa byte to A
	rla			; rotate out bit 7 which is set
	rl	(HL)		; rotate sign bit on stack into carry.
	rra			; rotate sign bit into bit 7 of mantissa.
			
; and transfer mantissa from main registers to calculator stack.
			
	ld	(HL),A		;
	inc	HL		;
	ld	(HL),C		;
	inc	HL		;
	ld	(HL),D		;
	inc	HL		;
	ld	(HL),E		;
			
	pop	HL		; restore pointer to num1 now result.
	pop	DE		; restore pointer to num2 now STKEND.
			
	exx			; - - -
	pop	HL		; restore pointer to next calculator literal.
	exx			; - - -
			
	ret			; return.
			
; ---
			
;; REPORT-6
L1880:	rst	#0x08		; ERROR-1
	.db	0x05		; Error Report: Arithmetic overflow.
			
; ------------------------
; THE 'DIVISION' OPERATION
; ------------------------
;   "Of all the arithmetic subroutines, division is the most complicated and
;   the least understood.  It is particularly interesting to note that the
;   Sinclair programmer himself has made a mistake in his programming ( or has
;   copied over someone else's mistake!) for
;   PRINT PEEK 6352 [ $18D0 ] ('unimproved' ROM, 6351 [ $18CF ] )
;   should give 218 not 225."
;   - Dr. Ian Logan, Syntax magazine Jul/Aug 1982.
;   [  i.e. the jump should be made to div-34th ]
			
;   First check for division by zero.
			
;; division
L1882:	ex	DE,HL		; consider the second number first.
	xor	A		; set the running sign flag.
	call	L17BC		; routine PREP-M/D
	jr	C,L1880		; back if zero to REPORT-6
				; 'Arithmetic overflow'
			
	ex	DE,HL		; now prepare first number and check for zero.
	call	L17BC		; routine PREP-M/D
	ret	C		; return if zero, 0/anything is zero.
			
	exx			; - - -
	push	HL		; save pointer to the next calculator literal.
	exx			; - - -
			
	push	DE		; save pointer to divisor - will be STKEND.
	push	HL		; save pointer to dividend - will be result.
			
	call	L16F7		; routine FETCH-TWO fetches the two numbers
				; into the registers H'B'C'C B
				;                    L'D'E'D E
	exx			; - - -
	push	HL		; save the two exponents.
			
	ld	H,B		; transfer the dividend to H'L'H L
	ld	L,C		;
	exx			;
	ld	H,C		;
	ld	L,B		;
			
	xor	A		; clear carry bit and accumulator.
	ld	B,#0xDF		; count upwards from -33 decimal
	jr	L18B2		; forward to mid-loop entry point DIV-START
			
; ---
			
;; DIV-LOOP
L18A2:	rla			; multiply partial quotient by two
	rl	C		; setting result bit from carry.
	exx			;
	rl	C		;
	rl	B		;
	exx			;
			
;; div-34th
L18AB:	add	HL,HL		;
	exx			;
	adc	HL,HL		;
	exx			;
	jr	C,L18C2		; forward to SUBN-ONLY
			
;; DIV-START
L18B2:	sbc	HL,DE		; subtract divisor part.
	exx			;
	sbc	HL,DE		;
	exx			;
	jr	NC,L18C9	; forward if subtraction goes to NO-RSTORE
			
	add	HL,DE		; else restore
	exx			;
	adc	HL,DE		;
	exx			;
	and	A		; clear carry
	jr	L18CA		; forward to COUNT-ONE
			
; ---
			
;; SUBN-ONLY
L18C2:	and	A		;
	sbc	HL,DE		;
	exx			;
	sbc	HL,DE		;
	exx			;
			
;; NO-RSTORE
L18C9:	scf			; set carry flag
			
;; COUNT-ONE
L18CA:	inc	B		; increment the counter
	jp	M,L18A2		; back while still minus to DIV-LOOP
			
	push	AF		;
	jr	Z,L18B2		; back to DIV-START
			
; "This jump is made to the wrong place. No 34th bit will ever be obtained
; without first shifting the dividend. Hence important results like 1/10 and
; 1/1000 are not rounded up as they should be. Rounding up never occurs when
; it depends on the 34th bit. The jump should be made to div-34th above."
; - Dr. Frank O'Hara, "The Complete Spectrum ROM Disassembly", 1983,
; published by Melbourne House.
; (Note. on the ZX81 this would be JR Z,L18AB)
;
; However if you make this change, then while (1/2=.5) will now evaluate as
; true, (.25=1/4), which did evaluate as true, no longer does.
			
	ld	E,A		;
	ld	D,C		;
	exx			;
	ld	E,C		;
	ld	D,B		;
			
	pop	AF		;
	rr	B		;
	pop	AF		;
	rr	B		;
			
	exx			;
	pop	BC		;
	pop	HL		;
	ld	A,B		;
	sub	C		;
	jp	L1810		; jump back to DIVN-EXPT
			
; ------------------------------------------------
; THE 'INTEGER TRUNCATION TOWARDS ZERO' SUBROUTINE
; ------------------------------------------------
;
			
;; truncate
L18E4:	ld	A,(HL)		; fetch exponent
	cp	#0x81		; compare to +1
	jr	NC,L18EF	; forward, if 1 or more, to T-GR-ZERO
			
; else the number is smaller than plus or minus 1 and can be made zero.
			
	ld	(HL),#0x00	; make exponent zero.
	ld	A,#0x20		; prepare to set 32 bits of mantissa to zero.
	jr	L18F4		; forward to NIL-BYTES
			
; ---
			
;; T-GR-ZERO
L18EF:	sub	#0xA0		; subtract +32 from exponent
	ret	P		; return if result is positive as all 32 bits
				; of the mantissa relate to the integer part.
				; The floating point is somewhere to the right
				; of the mantissa
			
	neg			; else negate to form number of rightmost bits
				; to be blanked.
			
; for instance, disregarding the sign bit, the number 3.5 is held as
; exponent $82 mantissa .11100000 00000000 00000000 00000000
; we need to set $82 - $A0 = $E2 NEG = $1E (thirty) bits to zero to form the
; integer.
; The sign of the number is never considered as the first bit of the mantissa
; must be part of the integer.
			
;; NIL-BYTES
L18F4:	push	DE		; save pointer to STKEND
	ex	DE,HL		; HL points at STKEND
	dec	HL		; now at last byte of mantissa.
	ld	B,A		; Transfer bit count to B register.
	srl	B		; divide by
	srl	B		; eight
	srl	B		;
	jr	Z,L1905		; forward if zero to BITS-ZERO
			
; else the original count was eight or more and whole bytes can be blanked.
			
;; BYTE-ZERO
L1900:	ld	(HL),#0x00	; set eight bits to zero.
	dec	HL		; point to more significant byte of mantissa.
	djnz	L1900		; loop back to BYTE-ZERO
			
; now consider any residual bits.
			
;; BITS-ZERO
L1905:	and	#0x07		; isolate the remaining bits
	jr	Z,L1912		; forward if none to IX-END
			
	ld	B,A		; transfer bit count to B counter.
	ld	A,#0xFF		; form a mask 11111111
			
;; LESS-MASK
L190C:	sla	A		; 1 <- 76543210 <- o     slide mask leftwards.
	djnz	L190C		; loop back for bit count to LESS-MASK
			
	and	(HL)		; lose the unwanted rightmost bits
	ld	(HL),A		; and place in mantissa byte.
			
;; IX-END
L1912:	ex	DE,HL		; restore result pointer from DE.
	pop	DE		; restore STKEND from stack.
	ret			; return.
			
			
;********************************
;**  FLOATING-POINT CALCULATOR **
;********************************
			
; As a general rule the calculator avoids using the IY register.
; Exceptions are val and str$.
; So an assembly language programmer who has disabled interrupts to use IY
; for other purposes can still use the calculator for mathematical
; purposes.
			
			
; ------------------------
; THE 'TABLE OF CONSTANTS'
; ------------------------
; The ZX81 has only floating-point number representation.
; Both the ZX80 and the ZX Spectrum have integer numbers in some form.
			
;; stk-zero                                                 00 00 00 00 00
L1915:	.db	0x00		;;Bytes: 1
	.db	0xB0		;;Exponent $00
	.db	0x00		;;(+00,+00,+00)
			
;; stk-one                                                  81 00 00 00 00
L1918:	.db	0x31		;;Exponent $81, Bytes: 1
	.db	0x00		;;(+00,+00,+00)
			
			
;; stk-half                                                 80 00 00 00 00
L191A:	.db	0x30		;;Exponent: $80, Bytes: 1
	.db	0x00		;;(+00,+00,+00)
			
			
;; stk-pi/2                                                 81 49 0F DA A2
L191C:	.db	0xF1		;;Exponent: $81, Bytes: 4
	.db	0x49,0x0F,0xDA,#0xA2	;;
			
;; stk-ten                                                  84 20 00 00 00
L1921:	.db	0x34		;;Exponent: $84, Bytes: 1
	.db	0x20		;;(+00,+00,+00)
			
			
; ------------------------
; THE 'TABLE OF ADDRESSES'
; ------------------------
;
; starts with binary operations which have two operands and one result.
; three pseudo binary operations first.
			
;; tbl-addrs
L1923:	.dw	L1C2F		; $00 Address: $1C2F - jump-true
	.dw	L1A72		; $01 Address: $1A72 - exchange
	.dw	L19E3		; $02 Address: $19E3 - delete
			
; true binary operations.
			
	.dw	L174C		; $03 Address: $174C - subtract
	.dw	L17C6		; $04 Address: $176C - multiply
	.dw	L1882		; $05 Address: $1882 - division
	.dw	L1DE2		; $06 Address: $1DE2 - to-power
	.dw	L1AED		; $07 Address: $1AED - or
			
	.dw	L1AF3		; $08 Address: $1B03 - no-&-no
	.dw	L1B03		; $09 Address: $1B03 - no-l-eql
	.dw	L1B03		; $0A Address: $1B03 - no-gr-eql
	.dw	L1B03		; $0B Address: $1B03 - nos-neql
	.dw	L1B03		; $0C Address: $1B03 - no-grtr
	.dw	L1B03		; $0D Address: $1B03 - no-less
	.dw	L1B03		; $0E Address: $1B03 - nos-eql
	.dw	L1755		; $0F Address: $1755 - addition
			
	.dw	L1AF8		; $10 Address: $1AF8 - str-&-no
	.dw	L1B03		; $11 Address: $1B03 - str-l-eql
	.dw	L1B03		; $12 Address: $1B03 - str-gr-eql
	.dw	L1B03		; $13 Address: $1B03 - strs-neql
	.dw	L1B03		; $14 Address: $1B03 - str-grtr
	.dw	L1B03		; $15 Address: $1B03 - str-less
	.dw	L1B03		; $16 Address: $1B03 - strs-eql
	.dw	L1B62		; $17 Address: $1B62 - strs-add
			
; unary follow
			
	.dw	L1AA0		; $18 Address: $1AA0 - neg
			
	.dw	L1C06		; $19 Address: $1C06 - code
	.dw	L1BA4		; $1A Address: $1BA4 - val
	.dw	L1C11		; $1B Address: $1C11 - len
	.dw	L1D49		; $1C Address: $1D49 - sin
	.dw	L1D3E		; $1D Address: $1D3E - cos
	.dw	L1D6E		; $1E Address: $1D6E - tan
	.dw	L1DC4		; $1F Address: $1DC4 - asn
	.dw	L1DD4		; $20 Address: $1DD4 - acs
	.dw	L1D76		; $21 Address: $1D76 - atn
	.dw	L1CA9		; $22 Address: $1CA9 - ln
	.dw	L1C5B		; $23 Address: $1C5B - exp
	.dw	L1C46		; $24 Address: $1C46 - int
	.dw	L1DDB		; $25 Address: $1DDB - sqr
	.dw	L1AAF		; $26 Address: $1AAF - sgn
	.dw	L1AAA		; $27 Address: $1AAA - abs
	.dw	L1ABE		; $28 Address: $1A1B - peek
	.dw	L1AC5		; $29 Address: $1AC5 - usr-no
	.dw	L1BD5		; $2A Address: $1BD5 - str$
	.dw	L1B8F		; $2B Address: $1B8F - chrs
	.dw	L1AD5		; $2C Address: $1AD5 - not
			
; end of true unary
			
	.dw	L19F6		; $2D Address: $19F6 - duplicate
	.dw	L1C37		; $2E Address: $1C37 - n-mod-m
			
	.dw	L1C23		; $2F Address: $1C23 - jump
	.dw	L19FC		; $30 Address: $19FC - stk-data
			
	.dw	L1C17		; $31 Address: $1C17 - dec-jr-nz
	.dw	L1ADB		; $32 Address: $1ADB - less-0
	.dw	L1ACE		; $33 Address: $1ACE - greater-0
	.dw	L002B		; $34 Address: $002B - end-calc
	.dw	L1D18		; $35 Address: $1D18 - get-argt
	.dw	L18E4		; $36 Address: $18E4 - truncate
	.dw	L19E4		; $37 Address: $19E4 - fp-calc-2
	.dw	L155A		; $38 Address: $155A - e-to-fp
			
; the following are just the next available slots for the 128 compound literals
; which are in range $80 - $FF.
			
	.dw	L1A7F		; $39 Address: $1A7F - series-xx    $80 - $9F.
	.dw	L1A51		; $3A Address: $1A51 - stk-const-xx $A0 - $BF.
	.dw	L1A63		; $3B Address: $1A63 - st-mem-xx    $C0 - $DF.
	.dw	L1A45		; $3C Address: $1A45 - get-mem-xx   $E0 - $FF.
			
; Aside: 3D - 7F are therefore unused calculator literals.
;        39 - 7B would be available for expansion.
			
; -------------------------------
; THE 'FLOATING POINT CALCULATOR'
; -------------------------------
;
;
			
;; CALCULATE
L199D:	call	L1B85		; routine STK-PNTRS is called to set up the
				; calculator stack pointers for a default
				; unary operation. HL = last value on stack.
				; DE = STKEND first location after stack.
			
; the calculate routine is called at this point by the series generator...
			
;; GEN-ENT-1
L19A0:	ld	A,B		; fetch the Z80 B register to A
	ld	(0x401E),A	; and store value in system variable BREG.
				; this will be the counter for dec-jr-nz
				; or if used from fp-calc2 the calculator
				; instruction.
			
; ... and again later at this point
			
;; GEN-ENT-2
L19A4:	exx			; switch sets
	ex	(SP),HL		; and store the address of next instruction,
				; the return address, in H'L'.
				; If this is a recursive call then the H'L'
				; of the previous invocation goes on stack.
				; c.f. end-calc.
	exx			; switch back to main set.
			
; this is the re-entry looping point when handling a string of literals.
			
;; RE-ENTRY
L19A7:	ld	(0x401C),DE	; save end of stack in system variable STKEND
	exx			; switch to alt
	ld	A,(HL)		; get next literal
	inc	HL		; increase pointer'
			
; single operation jumps back to here
			
;; SCAN-ENT
L19AE:	push	HL		; save pointer on stack   *
	and	A		; now test the literal
	jp	P,L19C2		; forward to FIRST-3D if in range $00 - $3D
				; anything with bit 7 set will be one of
				; 128 compound literals.
			
; compound literals have the following format.
; bit 7 set indicates compound.
; bits 6-5 the subgroup 0-3.
; bits 4-0 the embedded parameter $00 - $1F.
; The subgroup 0-3 needs to be manipulated to form the next available four
; address places after the simple literals in the address table.
			
	ld	D,A		; save literal in D
	and	#0x60		; and with 01100000 to isolate subgroup
	rrca			; rotate bits
	rrca			; 4 places to right
	rrca			; not five as we need offset * 2
	rrca			; 00000xx0
	add	A,#0x72		; add ($39 * 2) to give correct offset.
				; alter above if you add more literals.
	ld	L,A		; store in L for later indexing.
	ld	A,D		; bring back compound literal
	and	#0x1F		; use mask to isolate parameter bits
	jr	L19D0		; forward to ENT-TABLE
			
; ---
			
; the branch was here with simple literals.
			
;; FIRST-3D
L19C2:	cp	#0x18		; compare with first unary operations.
	jr	NC,L19CE	; to DOUBLE-A with unary operations
			
; it is binary so adjust pointers.
			
	exx			;
	ld	BC,#0xFFFB	; the value -5
	ld	D,H		; transfer HL, the last value, to DE.
	ld	E,L		;
	add	HL,BC		; subtract 5 making HL point to second
				; value.
	exx			;
			
;; DOUBLE-A
L19CE:	rlca			; double the literal
	ld	L,A		; and store in L for indexing
			
;; ENT-TABLE
L19D0:	ld	DE,#L1923	; Address: tbl-addrs
	ld	H,#0x00		; prepare to index
	add	HL,DE		; add to get address of routine
	ld	E,(HL)		; low byte to E
	inc	HL		;
	ld	D,(HL)		; high byte to D
			
	ld	HL,#L19A7	; Address: RE-ENTRY
	ex	(SP),HL		; goes on machine stack
				; address of next literal goes to HL. *
			
			
	push	DE		; now the address of routine is stacked.
	exx			; back to main set
				; avoid using IY register.
	ld	BC,(0x401D)	; STKEND_hi
				; nothing much goes to C but BREG to B
				; and continue into next ret instruction
				; which has a dual identity
			
			
; -----------------------
; THE 'DELETE' SUBROUTINE
; -----------------------
; offset $02: 'delete'
; A simple return but when used as a calculator literal this
; deletes the last value from the calculator stack.
; On entry, as always with binary operations,
; HL=first number, DE=second number
; On exit, HL=result, DE=stkend.
; So nothing to do
			
;; delete
L19E3:	ret			; return - indirect jump if from above.
			
; ---------------------------------
; THE 'SINGLE OPERATION' SUBROUTINE
; ---------------------------------
; offset $37: 'fp-calc-2'
; this single operation is used, in the first instance, to evaluate most
; of the mathematical and string functions found in BASIC expressions.
			
;; fp-calc-2
L19E4:	pop	AF		; drop return address.
	ld	A,(0x401E)	; load accumulator from system variable BREG
				; value will be literal eg. 'tan'
	exx			; switch to alt
	jr	L19AE		; back to SCAN-ENT
				; next literal will be end-calc in scanning
			
; ------------------------------
; THE 'TEST 5 SPACES' SUBROUTINE
; ------------------------------
; This routine is called from MOVE-FP, STK-CONST and STK-STORE to
; test that there is enough space between the calculator stack and the
; machine stack for another five-byte value. It returns with BC holding
; the value 5 ready for any subsequent LDIR.
			
;; TEST-5-SP
L19EB:	push	DE		; save
	push	HL		; registers
	ld	BC,#0x0005	; an overhead of five bytes
	call	L0EC5		; routine TEST-ROOM tests free RAM raising
				; an error if not.
	pop	HL		; else restore
	pop	DE		; registers.
	ret			; return with BC set at 5.
			
			
; ---------------------------------------------
; THE 'MOVE A FLOATING POINT NUMBER' SUBROUTINE
; ---------------------------------------------
; offset $2D: 'duplicate'
; This simple routine is a 5-byte LDIR instruction
; that incorporates a memory check.
; When used as a calculator literal it duplicates the last value on the
; calculator stack.
; Unary so on entry HL points to last value, DE to stkend
			
;; duplicate
;; MOVE-FP
L19F6:	call	L19EB		; routine TEST-5-SP test free memory
				; and sets BC to 5.
	ldir			; copy the five bytes.
	ret			; return with DE addressing new STKEND
				; and HL addressing new last value.
			
; -------------------------------
; THE 'STACK LITERALS' SUBROUTINE
; -------------------------------
; offset $30: 'stk-data'
; When a calculator subroutine needs to put a value on the calculator
; stack that is not a regular constant this routine is called with a
; variable number of following data bytes that convey to the routine
; the floating point form as succinctly as is possible.
			
;; stk-data
L19FC:	ld	H,D		; transfer STKEND
	ld	L,E		; to HL for result.
			
;; STK-CONST
L19FE:	call	L19EB		; routine TEST-5-SP tests that room exists
				; and sets BC to $05.
			
	exx			; switch to alternate set
	push	HL		; save the pointer to next literal on stack
	exx			; switch back to main set
			
	ex	(SP),HL		; pointer to HL, destination to stack.
			
	push	BC		; save BC - value 5 from test room ??.
			
	ld	A,(HL)		; fetch the byte following 'stk-data'
	and	#0xC0		; isolate bits 7 and 6
	rlca			; rotate
	rlca			; to bits 1 and 0  range $00 - $03.
	ld	C,A		; transfer to C
	inc	C		; and increment to give number of bytes
				; to read. $01 - $04
	ld	A,(HL)		; reload the first byte
	and	#0x3F		; mask off to give possible exponent.
	jr	NZ,L1A14	; forward to FORM-EXP if it was possible to
				; include the exponent.
			
; else byte is just a byte count and exponent comes next.
			
	inc	HL		; address next byte and
	ld	A,(HL)		; pick up the exponent ( - $50).
			
;; FORM-EXP
L1A14:	add	A,#0x50		; now add $50 to form actual exponent
	ld	(DE),A		; and load into first destination byte.
	ld	A,#0x05		; load accumulator with $05 and
	sub	C		; subtract C to give count of trailing
				; zeros plus one.
	inc	HL		; increment source
	inc	DE		; increment destination
	ld	B,#0x00		; prepare to copy
	ldir			; copy C bytes
			
	pop	BC		; restore 5 counter to BC ??.
			
	ex	(SP),HL		; put HL on stack as next literal pointer
				; and the stack value - result pointer -
				; to HL.
			
	exx			; switch to alternate set.
	pop	HL		; restore next literal pointer from stack
				; to H'L'.
	exx			; switch back to main set.
			
	ld	B,A		; zero count to B
	xor	A		; clear accumulator
			
;; STK-ZEROS
L1A27:	dec	B		; decrement B counter
	ret	Z		; return if zero.          >>
				; DE points to new STKEND
				; HL to new number.
			
	ld	(DE),A		; else load zero to destination
	inc	DE		; increase destination
	jr	L1A27		; loop back to STK-ZEROS until done.
			
; -------------------------------
; THE 'SKIP CONSTANTS' SUBROUTINE
; -------------------------------
; This routine traverses variable-length entries in the table of constants,
; stacking intermediate, unwanted constants onto a dummy calculator stack,
; in the first five bytes of the ZX81 ROM.
			
;; SKIP-CONS
L1A2D:	and	A		; test if initially zero.
			
;; SKIP-NEXT
L1A2E:	ret	Z		; return if zero.          >>
			
	push	AF		; save count.
	push	DE		; and normal STKEND
			
	ld	DE,#0x0000	; dummy value for STKEND at start of ROM
				; Note. not a fault but this has to be
				; moved elsewhere when running in RAM.
				;
	call	L19FE		; routine STK-CONST works through variable
				; length records.
			
	pop	DE		; restore real STKEND
	pop	AF		; restore count
	dec	A		; decrease
	jr	L1A2E		; loop back to SKIP-NEXT
			
; --------------------------------
; THE 'MEMORY LOCATION' SUBROUTINE
; --------------------------------
; This routine, when supplied with a base address in HL and an index in A,
; will calculate the address of the A'th entry, where each entry occupies
; five bytes. It is used for addressing floating-point numbers in the
; calculator's memory area.
			
;; LOC-MEM
L1A3C:	ld	C,A		; store the original number $00-$1F.
	rlca			; double.
	rlca			; quadruple.
	add	A,C		; now add original value to multiply by five.
			
	ld	C,A		; place the result in C.
	ld	B,#0x00		; set B to 0.
	add	HL,BC		; add to form address of start of number in HL.
			
	ret			; return.
			
; -------------------------------------
; THE 'GET FROM MEMORY AREA' SUBROUTINE
; -------------------------------------
; offsets $E0 to $FF: 'get-mem-0', 'get-mem-1' etc.
; A holds $00-$1F offset.
; The calculator stack increases by 5 bytes.
			
;; get-mem-xx
L1A45:	push	DE		; save STKEND
	ld	HL,(0x401F)	; MEM is base address of the memory cells.
	call	L1A3C		; routine LOC-MEM so that HL = first byte
	call	L19F6		; routine MOVE-FP moves 5 bytes with memory
				; check.
				; DE now points to new STKEND.
	pop	HL		; the original STKEND is now RESULT pointer.
	ret			; return.
			
; ---------------------------------
; THE 'STACK A CONSTANT' SUBROUTINE
; ---------------------------------
; offset $A0: 'stk-zero'
; offset $A1: 'stk-one'
; offset $A2: 'stk-half'
; offset $A3: 'stk-pi/2'
; offset $A4: 'stk-ten'
; This routine allows a one-byte instruction to stack up to 32 constants
; held in short form in a table of constants. In fact only 5 constants are
; required. On entry the A register holds the literal ANDed with $1F.
; It isn't very efficient and it would have been better to hold the
; numbers in full, five byte form and stack them in a similar manner
; to that which would be used later for semi-tone table values.
			
;; stk-const-xx
L1A51:	ld	H,D		; save STKEND - required for result
	ld	L,E		;
	exx			; swap
	push	HL		; save pointer to next literal
	ld	HL,#L1915	; Address: stk-zero - start of table of
				; constants
	exx			;
	call	L1A2D		; routine SKIP-CONS
	call	L19FE		; routine STK-CONST
	exx			;
	pop	HL		; restore pointer to next literal.
	exx			;
	ret			; return.
			
; ---------------------------------------
; THE 'STORE IN A MEMORY AREA' SUBROUTINE
; ---------------------------------------
; Offsets $C0 to $DF: 'st-mem-0', 'st-mem-1' etc.
; Although 32 memory storage locations can be addressed, only six
; $C0 to $C5 are required by the ROM and only the thirty bytes (6*5)
; required for these are allocated. ZX81 programmers who wish to
; use the floating point routines from assembly language may wish to
; alter the system variable MEM to point to 160 bytes of RAM to have
; use the full range available.
; A holds derived offset $00-$1F.
; Unary so on entry HL points to last value, DE to STKEND.
			
;; st-mem-xx
L1A63:	push	HL		; save the result pointer.
	ex	DE,HL		; transfer to DE.
	ld	HL,(0x401F)	; fetch MEM the base of memory area.
	call	L1A3C		; routine LOC-MEM sets HL to the destination.
	ex	DE,HL		; swap - HL is start, DE is destination.
	call	L19F6		; routine MOVE-FP.
				; note. a short ld bc,5; ldir
				; the embedded memory check is not required
				; so these instructions would be faster!
	ex	DE,HL		; DE = STKEND
	pop	HL		; restore original result pointer
	ret			; return.
			
; -------------------------
; THE 'EXCHANGE' SUBROUTINE
; -------------------------
; offset $01: 'exchange'
; This routine exchanges the last two values on the calculator stack
; On entry, as always with binary operations,
; HL=first number, DE=second number
; On exit, HL=result, DE=stkend.
			
;; exchange
L1A72:	ld	B,#0x05		; there are five bytes to be swapped
			
; start of loop.
			
;; SWAP-BYTE
L1A74:	ld	A,(DE)		; each byte of second
	ld	C,(HL)		; each byte of first
	ex	DE,HL		; swap pointers
	ld	(DE),A		; store each byte of first
	ld	(HL),C		; store each byte of second
	inc	HL		; advance both
	inc	DE		; pointers.
	djnz	L1A74		; loop back to SWAP-BYTE until all 5 done.
			
	ex	DE,HL		; even up the exchanges
				; so that DE addresses STKEND.
	ret			; return.
			
; ---------------------------------
; THE 'SERIES GENERATOR' SUBROUTINE
; ---------------------------------
; offset $86: 'series-06'
; offset $88: 'series-08'
; offset $8C: 'series-0C'
; The ZX81 uses Chebyshev polynomials to generate approximations for
; SIN, ATN, LN and EXP. These are named after the Russian mathematician
; Pafnuty Chebyshev, born in 1821, who did much pioneering work on numerical
; series. As far as calculators are concerned, Chebyshev polynomials have an
; advantage over other series, for example the Taylor series, as they can
; reach an approximation in just six iterations for SIN, eight for EXP and
; twelve for LN and ATN. The mechanics of the routine are interesting but
; for full treatment of how these are generated with demonstrations in
; Sinclair BASIC see "The Complete Spectrum ROM Disassembly" by Dr Ian Logan
; and Dr Frank O'Hara, published 1983 by Melbourne House.
			
;; series-xx
L1A7F:	ld	B,A		; parameter $00 - $1F to B counter
	call	L19A0		; routine GEN-ENT-1 is called.
				; A recursive call to a special entry point
				; in the calculator that puts the B register
				; in the system variable BREG. The return
				; address is the next location and where
				; the calculator will expect its first
				; instruction - now pointed to by HL'.
				; The previous pointer to the series of
				; five-byte numbers goes on the machine stack.
			
; The initialization phase.
			
	.db	0x2D		;;duplicate       x,x
	.db	0x0F		;;addition        x+x
	.db	0xC0		;;st-mem-0        x+x
	.db	0x02		;;delete          .
	.db	0xA0		;;stk-zero        0
	.db	0xC2		;;st-mem-2        0
			
; a loop is now entered to perform the algebraic calculation for each of
; the numbers in the series
			
;; G-LOOP
L1A89:	.db	0x2D		;;duplicate       v,v.
	.db	0xE0		;;get-mem-0       v,v,x+2
	.db	0x04		;;multiply        v,v*x+2
	.db	0xE2		;;get-mem-2       v,v*x+2,v
	.db	0xC1		;;st-mem-1
	.db	0x03		;;subtract
	.db	0x34		;;end-calc
			
; the previous pointer is fetched from the machine stack to H'L' where it
; addresses one of the numbers of the series following the series literal.
			
	call	L19FC		; routine STK-DATA is called directly to
				; push a value and advance H'L'.
	call	L19A4		; routine GEN-ENT-2 recursively re-enters
				; the calculator without disturbing
				; system variable BREG
				; H'L' value goes on the machine stack and is
				; then loaded as usual with the next address.
			
	.db	0x0F		;;addition
	.db	0x01		;;exchange
	.db	0xC2		;;st-mem-2
	.db	0x02		;;delete
			
	.db	0x31		;;dec-jr-nz
	.db	0xEE		;;back to L1A89, G-LOOP
			
; when the counted loop is complete the final subtraction yields the result
; for example SIN X.
			
	.db	0xE1		;;get-mem-1
	.db	0x03		;;subtract
	.db	0x34		;;end-calc
			
	ret			; return with H'L' pointing to location
				; after last number in series.
			
; -----------------------
; Handle unary minus (18)
; -----------------------
; Unary so on entry HL points to last value, DE to STKEND.
			
;; NEGATE
;; negate
L1AA0:	ld	A,  (HL)	; fetch exponent of last value on the
				; calculator stack.
	and	A		; test it.
	ret	Z		; return if zero.
			
	inc	HL		; address the byte with the sign bit.
	ld	A,(HL)		; fetch to accumulator.
	xor	#0x80		; toggle the sign bit.
	ld	(HL),A		; put it back.
	dec	HL		; point to last value again.
	ret			; return.
			
; -----------------------
; Absolute magnitude (27)
; -----------------------
; This calculator literal finds the absolute value of the last value,
; floating point, on calculator stack.
			
;; abs
L1AAA:	inc	HL		; point to byte with sign bit.
	res	7,(HL)		; make the sign positive.
	dec	HL		; point to last value again.
	ret			; return.
			
; -----------
; Signum (26)
; -----------
; This routine replaces the last value on the calculator stack,
; which is in floating point form, with one if positive and with -minus one
; if negative. If it is zero then it is left as such.
			
;; sgn
L1AAF:	inc	HL		; point to first byte of 4-byte mantissa.
	ld	A,(HL)		; pick up the byte with the sign bit.
	dec	HL		; point to exponent.
	dec	(HL)		; test the exponent for
	inc	(HL)		; the value zero.
			
	scf			; set the carry flag.
	call	NZ,L1AE0	; routine FP-0/1  replaces last value with one
				; if exponent indicates the value is non-zero.
				; in either case mantissa is now four zeros.
			
	inc	HL		; point to first byte of 4-byte mantissa.
	rlca			; rotate original sign bit to carry.
	rr	(HL)		; rotate the carry into sign.
	dec	HL		; point to last value.
	ret			; return.
			
			
; -------------------------
; Handle PEEK function (28)
; -------------------------
; This function returns the contents of a memory address.
; The entire address space can be peeked including the ROM.
			
;; peek
L1ABE:	call	L0EA7		; routine FIND-INT puts address in BC.
	ld	A,(BC)		; load contents into A register.
			
;; IN-PK-STK
L1AC2:	jp	L151D		; exit via STACK-A to put value on the
				; calculator stack.
			
; ---------------
; USR number (29)
; ---------------
; The USR function followed by a number 0-65535 is the method by which
; the ZX81 invokes machine code programs. This function returns the
; contents of the BC register pair.
; Note. that STACK-BC re-initializes the IY register to $4000 if a user-written
; program has altered it.
			
;; usr-no
L1AC5:	call	L0EA7		; routine FIND-INT to fetch the
				; supplied address into BC.
			
	ld	HL,#L1520	; address: STACK-BC is
	push	HL		; pushed onto the machine stack.
	push	BC		; then the address of the machine code
				; routine.
			
	ret			; make an indirect jump to the routine
				; and, hopefully, to STACK-BC also.
			
			
; -----------------------
; Greater than zero ($33)
; -----------------------
; Test if the last value on the calculator stack is greater than zero.
; This routine is also called directly from the end-tests of the comparison
; routine.
			
;; GREATER-0
;; greater-0
L1ACE:	ld	A,(HL)		; fetch exponent.
	and	A		; test it for zero.
	ret	Z		; return if so.
			
			
	ld	A,#0xFF		; prepare XOR mask for sign bit
	jr	L1ADC		; forward to SIGN-TO-C
				; to put sign in carry
				; (carry will become set if sign is positive)
				; and then overwrite location with 1 or 0
				; as appropriate.
			
; ------------------------
; Handle NOT operator ($2C)
; ------------------------
; This overwrites the last value with 1 if it was zero else with zero
; if it was any other value.
;
; e.g. NOT 0 returns 1, NOT 1 returns 0, NOT -3 returns 0.
;
; The subroutine is also called directly from the end-tests of the comparison
; operator.
			
;; NOT
;; not
L1AD5:	ld	A,(HL)		; get exponent byte.
	neg			; negate - sets carry if non-zero.
	ccf			; complement so carry set if zero, else reset.
	jr	L1AE0		; forward to FP-0/1.
			
; -------------------
; Less than zero (32)
; -------------------
; Destructively test if last value on calculator stack is less than zero.
; Bit 7 of second byte will be set if so.
			
;; less-0
L1ADB:	xor	A		; set xor mask to zero
				; (carry will become set if sign is negative).
			
; transfer sign of mantissa to Carry Flag.
			
;; SIGN-TO-C
L1ADC:	inc	HL		; address 2nd byte.
	xor	(HL)		; bit 7 of HL will be set if number is negative.
	dec	HL		; address 1st byte again.
	rlca			; rotate bit 7 of A to carry.
			
; -----------
; Zero or one
; -----------
; This routine places an integer value zero or one at the addressed location
; of calculator stack or MEM area. The value one is written if carry is set on
; entry else zero.
			
;; FP-0/1
L1AE0:	push	HL		; save pointer to the first byte
	ld	B,#0x05		; five bytes to do.
			
;; FP-loop
L1AE3:	ld	(HL),#0x00	; insert a zero.
	inc	HL		;
	djnz	L1AE3		; repeat.
			
	pop	HL		;
	ret	NC		;
			
	ld	(HL),#0x81	; make value 1
	ret			; return.
			
			
; -----------------------
; Handle OR operator (07)
; -----------------------
; The Boolean OR operator. eg. X OR Y
; The result is zero if both values are zero else a non-zero value.
;
; e.g.    0 OR 0  returns 0.
;        -3 OR 0  returns -3.
;         0 OR -3 returns 1.
;        -3 OR 2  returns 1.
;
; A binary operation.
; On entry HL points to first operand (X) and DE to second operand (Y).
			
;; or
L1AED:	ld	A,(DE)		; fetch exponent of second number
	and	A		; test it.
	ret	Z		; return if zero.
			
	scf			; set carry flag
	jr	L1AE0		; back to FP-0/1 to overwrite the first operand
				; with the value 1.
			
			
; -----------------------------
; Handle number AND number (08)
; -----------------------------
; The Boolean AND operator.
;
; e.g.    -3 AND 2  returns -3.
;         -3 AND 0  returns 0.
;          0 and -2 returns 0.
;          0 and 0  returns 0.
;
; Compare with OR routine above.
			
;; no-&-no
L1AF3:	ld	A,(DE)		; fetch exponent of second number.
	and	A		; test it.
	ret	NZ		; return if not zero.
			
	jr	L1AE0		; back to FP-0/1 to overwrite the first operand
				; with zero for return value.
			
; -----------------------------
; Handle string AND number (10)
; -----------------------------
; e.g. "YOU WIN" AND SCORE>99 will return the string if condition is true
; or the null string if false.
			
;; str-&-no
L1AF8:	ld	A,(DE)		; fetch exponent of second number.
	and	A		; test it.
	ret	NZ		; return if number was not zero - the string
				; is the result.
			
; if the number was zero (false) then the null string must be returned by
; altering the length of the string on the calculator stack to zero.
			
	push	DE		; save pointer to the now obsolete number
				; (which will become the new STKEND)
			
	dec	DE		; point to the 5th byte of string descriptor.
	xor	A		; clear the accumulator.
	ld	(DE),A		; place zero in high byte of length.
	dec	DE		; address low byte of length.
	ld	(DE),A		; place zero there - now the null string.
			
	pop	DE		; restore pointer - new STKEND.
	ret			; return.
			
; -----------------------------------
; Perform comparison ($09-$0E, $11-$16)
; -----------------------------------
; True binary operations.
;
; A single entry point is used to evaluate six numeric and six string
; comparisons. On entry, the calculator literal is in the B register and
; the two numeric values, or the two string parameters, are on the
; calculator stack.
; The individual bits of the literal are manipulated to group similar
; operations although the SUB 8 instruction does nothing useful and merely
; alters the string test bit.
; Numbers are compared by subtracting one from the other, strings are
; compared by comparing every character until a mismatch, or the end of one
; or both, is reached.
;
; Numeric Comparisons.
; --------------------
; The 'x>y' example is the easiest as it employs straight-thru logic.
; Number y is subtracted from x and the result tested for greater-0 yielding
; a final value 1 (true) or 0 (false).
; For 'x<y' the same logic is used but the two values are first swapped on the
; calculator stack.
; For 'x=y' NOT is applied to the subtraction result yielding true if the
; difference was zero and false with anything else.
; The first three numeric comparisons are just the opposite of the last three
; so the same processing steps are used and then a final NOT is applied.
;
; literal    Test   No  sub 8       ExOrNot  1st RRCA  exch sub  ?   End-Tests
; -----------------------------------------------------------------------------
; no-l-eql   x<=y   09 00000001 dec 00000000 00000000  ---- x-y  ?  --- >0? NOT
; no-gr-eql  x>=y   0A 00000010 dec 00000001 10000000c swap y-x  ?  --- >0? NOT
; nos-neql   x<>y   0B 00000011 dec 00000010 00000001  ---- x-y  ?  NOT --- NOT
; no-grtr    x>y    0C 00000100  -  00000100 00000010  ---- x-y  ?  --- >0? ---
; no-less    x<y    0D 00000101  -  00000101 10000010c swap y-x  ?  --- >0? ---
; nos-eql    x=y    0E 00000110  -  00000110 00000011  ---- x-y  ?  NOT --- ---
;
;                                                           comp -> C/F
;                                                          -------------
; str-l-eql  x$<=y$ 11 00001001 dec 00001000 00000100  ---- x$y$ 0  !or >0? NOT
; str-gr-eql x$>=y$ 12 00001010 dec 00001001 10000100c swap y$x$ 0  !or >0? NOT
; strs-neql  x$<>y$ 13 00001011 dec 00001010 00000101  ---- x$y$ 0  !or >0? NOT
; str-grtr   x$>y$  14 00001100  -  00001100 00000110  ---- x$y$ 0  !or >0? ---
; str-less   x$<y$  15 00001101  -  00001101 10000110c swap y$x$ 0  !or >0? ---
; strs-eql   x$=y$  16 00001110  -  00001110 00000111  ---- x$y$ 0  !or >0? ---
;
; String comparisons are a little different in that the eql/neql carry flag
; from the 2nd RRCA is, as before, fed into the first of the end tests but
; along the way it gets modified by the comparison process. The result on the
; stack always starts off as zero and the carry fed in determines if NOT is
; applied to it. So the only time the greater-0 test is applied is if the
; stack holds zero which is not very efficient as the test will always yield
; zero. The most likely explanation is that there were once separate end tests
; for numbers and strings.
			
;; no-l-eql,etc.
L1B03:	ld	A,B		; transfer literal to accumulator.
	sub	#0x08		; subtract eight - which is not useful.
			
	bit	2,A		; isolate '>', '<', '='.
			
	jr	NZ,L1B0B	; skip to EX-OR-NOT with these.
			
	dec	A		; else make $00-$02, $08-$0A to match bits 0-2.
			
;; EX-OR-NOT
L1B0B:	rrca			; the first RRCA sets carry for a swap.
	jr	NC,L1B16	; forward to NU-OR-STR with other 8 cases
			
; for the other 4 cases the two values on the calculator stack are exchanged.
			
	push	AF		; save A and carry.
	push	HL		; save HL - pointer to first operand.
				; (DE points to second operand).
			
	call	L1A72		; routine exchange swaps the two values.
				; (HL = second operand, DE = STKEND)
			
	pop	DE		; DE = first operand
	ex	DE,HL		; as we were.
	pop	AF		; restore A and carry.
			
; Note. it would be better if the 2nd RRCA preceded the string test.
; It would save two duplicate bytes and if we also got rid of that sub 8
; at the beginning we wouldn't have to alter which bit we test.
			
;; NU-OR-STR
L1B16:	bit	2,A		; test if a string comparison.
	jr	NZ,L1B21	; forward to STRINGS if so.
			
; continue with numeric comparisons.
			
	rrca			; 2nd RRCA causes eql/neql to set carry.
	push	AF		; save A and carry
			
	call	L174C		; routine subtract leaves result on stack.
	jr	L1B54		; forward to END-TESTS
			
; ---
			
;; STRINGS
L1B21:	rrca			; 2nd RRCA causes eql/neql to set carry.
	push	AF		; save A and carry.
			
	call	L13F8		; routine STK-FETCH gets 2nd string params
	push	DE		; save start2 *.
	push	BC		; and the length.
			
	call	L13F8		; routine STK-FETCH gets 1st string
				; parameters - start in DE, length in BC.
	pop	HL		; restore length of second to HL.
			
; A loop is now entered to compare, by subtraction, each corresponding character
; of the strings. For each successful match, the pointers are incremented and
; the lengths decreased and the branch taken back to here. If both string
; remainders become null at the same time, then an exact match exists.
			
;; BYTE-COMP
L1B2C:	ld	A,H		; test if the second string
	or	L		; is the null string and hold flags.
			
	ex	(SP),HL		; put length2 on stack, bring start2 to HL *.
	ld	A,B		; hi byte of length1 to A
			
	jr	NZ,L1B3D	; forward to SEC-PLUS if second not null.
			
	or	C		; test length of first string.
			
;; SECND-LOW
L1B33:	pop	BC		; pop the second length off stack.
	jr	Z,L1B3A		; forward to BOTH-NULL if first string is also
				; of zero length.
			
; the true condition - first is longer than second (SECND-LESS)
			
	pop	AF		; restore carry (set if eql/neql)
	ccf			; complement carry flag.
				; Note. equality becomes false.
				; Inequality is true. By swapping or applying
				; a terminal 'not', all comparisons have been
				; manipulated so that this is success path.
	jr	L1B50		; forward to leave via STR-TEST
			
; ---
; the branch was here with a match
			
;; BOTH-NULL
L1B3A:	pop	AF		; restore carry - set for eql/neql
	jr	L1B50		; forward to STR-TEST
			
; ---
; the branch was here when 2nd string not null and low byte of first is yet
; to be tested.
			
			
;; SEC-PLUS
L1B3D:	or	C		; test the length of first string.
	jr	Z,L1B4D		; forward to FRST-LESS if length is zero.
			
; both strings have at least one character left.
			
	ld	A,(DE)		; fetch character of first string.
	sub	(HL)		; subtract with that of 2nd string.
	jr	C,L1B4D		; forward to FRST-LESS if carry set
			
	jr	NZ,L1B33	; back to SECND-LOW and then STR-TEST
				; if not exact match.
			
	dec	BC		; decrease length of 1st string.
	inc	DE		; increment 1st string pointer.
			
	inc	HL		; increment 2nd string pointer.
	ex	(SP),HL		; swap with length on stack
	dec	HL		; decrement 2nd string length
	jr	L1B2C		; back to BYTE-COMP
			
; ---
;   the false condition.
			
;; FRST-LESS
L1B4D:	pop	BC		; discard length
	pop	AF		; pop A
	and	A		; clear the carry for false result.
			
; ---
;   exact match and x$>y$ rejoin here
			
;; STR-TEST
L1B50:	push	AF		; save A and carry
			
	rst	#0x28		;; FP-CALC
	.db	0xA0		;;stk-zero      an initial false value.
	.db	0x34		;;end-calc
			
;   both numeric and string paths converge here.
			
;; END-TESTS
L1B54:	pop	AF		; pop carry  - will be set if eql/neql
	push	AF		; save it again.
			
	call	C,L1AD5		; routine NOT sets true(1) if equal(0)
				; or, for strings, applies true result.
	call	L1ACE		; greater-0  ??????????
			
			
	pop	AF		; pop A
	rrca			; the third RRCA - test for '<=', '>=' or '<>'.
	call	NC,L1AD5	; apply a terminal NOT if so.
	ret			; return.
			
; -------------------------
; String concatenation ($17)
; -------------------------
;   This literal combines two strings into one e.g. LET A$ = B$ + C$
;   The two parameters of the two strings to be combined are on the stack.
			
;; strs-add
L1B62:	call	L13F8		; routine STK-FETCH fetches string parameters
				; and deletes calculator stack entry.
	push	DE		; save start address.
	push	BC		; and length.
			
	call	L13F8		; routine STK-FETCH for first string
	pop	HL		; re-fetch first length
	push	HL		; and save again
	push	DE		; save start of second string
	push	BC		; and its length.
			
	add	HL,BC		; add the two lengths.
	ld	B,H		; transfer to BC
	ld	C,L		; and create
	rst	#0x30		; BC-SPACES in workspace.
				; DE points to start of space.
			
	call	L12C3		; routine STK-STO-$ stores parameters
				; of new string updating STKEND.
			
	pop	BC		; length of first
	pop	HL		; address of start
	ld	A,B		; test for
	or	C		; zero length.
	jr	Z,L1B7D		; to OTHER-STR if null string
			
	ldir			; copy string to workspace.
			
;; OTHER-STR
L1B7D:	pop	BC		; now second length
	pop	HL		; and start of string
	ld	A,B		; test this one
	or	C		; for zero length
	jr	Z,L1B85		; skip forward to STK-PNTRS if so as complete.
			
	ldir			; else copy the bytes.
				; and continue into next routine which
				; sets the calculator stack pointers.
			
; --------------------
; Check stack pointers
; --------------------
;   Register DE is set to STKEND and HL, the result pointer, is set to five
;   locations below this.
;   This routine is used when it is inconvenient to save these values at the
;   time the calculator stack is manipulated due to other activity on the
;   machine stack.
;   This routine is also used to terminate the VAL routine for
;   the same reason and to initialize the calculator stack at the start of
;   the CALCULATE routine.
			
;; STK-PNTRS
L1B85:	ld	HL,(0x401C)	; fetch STKEND value from system variable.
	ld	DE,#0xFFFB	; the value -5
	push	HL		; push STKEND value.
			
	add	HL,DE		; subtract 5 from HL.
			
	pop	DE		; pop STKEND to DE.
	ret			; return.
			
; ----------------
; Handle CHR$ (2B)
; ----------------
;   This function returns a single character string that is a result of
;   converting a number in the range 0-255 to a string e.g. CHR$ 38 = "A".
;   Note. the ZX81 does not have an ASCII character set.
			
;; chrs
L1B8F:	call	L15CD		; routine FP-TO-A puts the number in A.
			
	jr	C,L1BA2		; forward to REPORT-Bd if overflow
	jr	NZ,L1BA2	; forward to REPORT-Bd if negative
			
	push	AF		; save the argument.
			
	ld	BC,#0x0001	; one space required.
	rst	#0x30		; BC-SPACES makes DE point to start
			
	pop	AF		; restore the number.
			
	ld	(DE),A		; and store in workspace
			
	call	L12C3		; routine STK-STO-$ stacks descriptor.
			
	ex	DE,HL		; make HL point to result and DE to STKEND.
	ret			; return.
			
; ---
			
;; REPORT-Bd
L1BA2:	rst	#0x08		; ERROR-1
	.db	0x0A		; Error Report: Integer out of range
			
; ----------------------------
; Handle VAL ($1A)
; ----------------------------
;   VAL treats the characters in a string as a numeric expression.
;       e.g. VAL "2.3" = 2.3, VAL "2+4" = 6, VAL ("2" + "4") = 24.
			
;; val
L1BA4:	ld	HL,(0x4016)	; fetch value of system variable CH_ADD
	push	HL		; and save on the machine stack.
			
	call	L13F8		; routine STK-FETCH fetches the string operand
				; from calculator stack.
			
	push	DE		; save the address of the start of the string.
	inc	BC		; increment the length for a carriage return.
			
	rst	#0x30		; BC-SPACES creates the space in workspace.
	pop	HL		; restore start of string to HL.
	ld	(0x4016),DE	; load CH_ADD with start DE in workspace.
			
	push	DE		; save the start in workspace
	ldir			; copy string from program or variables or
				; workspace to the workspace area.
	ex	DE,HL		; end of string + 1 to HL
	dec	HL		; decrement HL to point to end of new area.
	ld	(HL),#0x76	; insert a carriage return at end.
				; ZX81 has a non-ASCII character set
	res	7,0x01(IY)	; update FLAGS  - signal checking syntax.
	call	L0D92		; routine CLASS-06 - SCANNING evaluates string
				; expression and checks for integer result.
			
	call	L0D22		; routine CHECK-2 checks for carriage return.
			
			
	pop	HL		; restore start of string in workspace.
			
	ld	(0x4016),HL	; set CH_ADD to the start of the string again.
	set	7,0x01(IY)	; update FLAGS  - signal running program.
	call	L0F55		; routine SCANNING evaluates the string
				; in full leaving result on calculator stack.
			
	pop	HL		; restore saved character address in program.
	ld	(0x4016),HL	; and reset the system variable CH_ADD.
			
	jr	L1B85		; back to exit via STK-PNTRS.
				; resetting the calculator stack pointers
				; HL and DE from STKEND as it wasn't possible
				; to preserve them during this routine.
			
; ----------------
; Handle STR$ (2A)
; ----------------
;   This function returns a string representation of a numeric argument.
;   The method used is to trick the PRINT-FP routine into thinking it
;   is writing to a collapsed display file when in fact it is writing to
;   string workspace.
;   If there is already a newline at the intended print position and the
;   column count has not been reduced to zero then the print routine
;   assumes that there is only 1K of RAM and the screen memory, like the rest
;   of dynamic memory, expands as necessary using calls to the ONE-SPACE
;   routine. The screen is character-mapped not bit-mapped.
			
;; str$
L1BD5:	ld	BC,#0x0001	; create an initial byte in workspace
	rst	#0x30		; using BC-SPACES restart.
			
	ld	(HL),#0x76	; place a carriage return there.
			
	ld	HL,(0x4039)	; fetch value of S_POSN column/line
	push	HL		; and preserve on stack.
			
	ld	L,#0xFF		; make column value high to create a
				; contrived buffer of length 254.
	ld	(0x4039),HL	; and store in system variable S_POSN.
			
	ld	HL,(0x400E)	; fetch value of DF_CC
	push	HL		; and preserve on stack also.
			
	ld	(0x400E),DE	; now set DF_CC which normally addresses
				; somewhere in the display file to the start
				; of workspace.
	push	DE		; save the start of new string.
			
	call	L15DB		; routine PRINT-FP.
			
	pop	DE		; retrieve start of string.
			
	ld	HL,(0x400E)	; fetch end of string from DF_CC.
	and	A		; prepare for true subtraction.
	sbc	HL,DE		; subtract to give length.
			
	ld	B,H		; and transfer to the BC
	ld	C,L		; register.
			
	pop	HL		; restore original
	ld	(0x400E),HL	; DF_CC value
			
	pop	HL		; restore original
	ld	(0x4039),HL	; S_POSN values.
			
	call	L12C3		; routine STK-STO-$ stores the string
				; descriptor on the calculator stack.
			
	ex	DE,HL		; HL = last value, DE = STKEND.
	ret			; return.
			
			
; -------------------
; THE 'CODE' FUNCTION
; -------------------
; (offset $19: 'code')
;   Returns the code of a character or first character of a string
;   e.g. CODE "AARDVARK" = 38  (not 65 as the ZX81 does not have an ASCII
;   character set).
			
			
;; code
L1C06:	call	L13F8		; routine STK-FETCH to fetch and delete the
				; string parameters.
				; DE points to the start, BC holds the length.
	ld	A,B		; test length
	or	C		; of the string.
	jr	Z,L1C0E		; skip to STK-CODE with zero if the null string.
			
	ld	A,(DE)		; else fetch the first character.
			
;; STK-CODE
L1C0E:	jp	L151D		; jump back to STACK-A (with memory check)
			
; --------------------
; THE 'LEN' SUBROUTINE
; --------------------
; (offset $1b: 'len')
;   Returns the length of a string.
;   In Sinclair BASIC strings can be more than twenty thousand characters long
;   so a sixteen-bit register is required to store the length
			
;; len
L1C11:	call	L13F8		; routine STK-FETCH to fetch and delete the
				; string parameters from the calculator stack.
				; register BC now holds the length of string.
			
	jp	L1520		; jump back to STACK-BC to save result on the
				; calculator stack (with memory check).
			
; -------------------------------------
; THE 'DECREASE THE COUNTER' SUBROUTINE
; -------------------------------------
; (offset $31: 'dec-jr-nz')
;   The calculator has an instruction that decrements a single-byte
;   pseudo-register and makes consequential relative jumps just like
;   the Z80's DJNZ instruction.
			
;; dec-jr-nz
L1C17:	exx			; switch in set that addresses code
			
	push	HL		; save pointer to offset byte
	ld	HL,#0x401E	; address BREG in system variables
	dec	(HL)		; decrement it
	pop	HL		; restore pointer
			
	jr	NZ,L1C24	; to JUMP-2 if not zero
			
	inc	HL		; step past the jump length.
	exx			; switch in the main set.
	ret			; return.
			
;   Note. as a general rule the calculator avoids using the IY register
;   otherwise the cumbersome 4 instructions in the middle could be replaced by
;   dec (iy+$xx) - using three instruction bytes instead of six.
			
			
; ---------------------
; THE 'JUMP' SUBROUTINE
; ---------------------
; (Offset $2F; 'jump')
;   This enables the calculator to perform relative jumps just like
;   the Z80 chip's JR instruction.
;   This is one of the few routines to be polished for the ZX Spectrum.
;   See, without looking at the ZX Spectrum ROM, if you can get rid of the
;   relative jump.
			
;; jump
;; JUMP
L1C23:	exx			;switch in pointer set
			
;; JUMP-2
L1C24:	ld	E,(HL)		; the jump byte 0-127 forward, 128-255 back.
	xor	A		; clear accumulator.
	bit	7,E		; test if negative jump
	jr	Z,L1C2B		; skip, if positive, to JUMP-3.
			
	cpl			; else change to $FF.
			
;; JUMP-3
L1C2B:	ld	D,A		; transfer to high byte.
	add	HL,DE		; advance calculator pointer forward or back.
			
	exx			; switch out pointer set.
	ret			; return.
			
; -----------------------------
; THE 'JUMP ON TRUE' SUBROUTINE
; -----------------------------
; (Offset $00; 'jump-true')
;   This enables the calculator to perform conditional relative jumps
;   dependent on whether the last test gave a true result
;   On the ZX81, the exponent will be zero for zero or else $81 for one.
			
;; jump-true
L1C2F:	ld	A,(DE)		; collect exponent byte
			
	and	A		; is result 0 or 1 ?
	jr	NZ,L1C23	; back to JUMP if true (1).
			
	exx			; else switch in the pointer set.
	inc	HL		; step past the jump length.
	exx			; switch in the main set.
	ret			; return.
			
			
; ------------------------
; THE 'MODULUS' SUBROUTINE
; ------------------------
; ( Offset $2E: 'n-mod-m' )
; ( i1, i2 -- i3, i4 )
;   The subroutine calculate N mod M where M is the positive integer, the
;   'last value' on the calculator stack and N is the integer beneath.
;   The subroutine returns the integer quotient as the last value and the
;   remainder as the value beneath.
;   e.g.    17 MOD 3 = 5 remainder 2
;   It is invoked during the calculation of a random number and also by
;   the PRINT-FP routine.
			
;; n-mod-m
L1C37:	rst	#0x28		;; FP-CALC          17, 3.
	.db	0xC0		;;st-mem-0          17, 3.
	.db	0x02		;;delete            17.
	.db	0x2D		;;duplicate         17, 17.
	.db	0xE0		;;get-mem-0         17, 17, 3.
	.db	0x05		;;division          17, 17/3.
	.db	0x24		;;int               17, 5.
	.db	0xE0		;;get-mem-0         17, 5, 3.
	.db	0x01		;;exchange          17, 3, 5.
	.db	0xC0		;;st-mem-0          17, 3, 5.
	.db	0x04		;;multiply          17, 15.
	.db	0x03		;;subtract          2.
	.db	0xE0		;;get-mem-0         2, 5.
	.db	0x34		;;end-calc          2, 5.
			
	ret			; return.
			
			
; ----------------------
; THE 'INTEGER' FUNCTION
; ----------------------
; (offset $24: 'int')
;   This function returns the integer of x, which is just the same as truncate
;   for positive numbers. The truncate literal truncates negative numbers
;   upwards so that -3.4 gives -3 whereas the BASIC INT function has to
;   truncate negative numbers down so that INT -3.4 is 4.
;   It is best to work through using, say, plus or minus 3.4 as examples.
			
;; int
L1C46:	rst	#0x28		;; FP-CALC              x.    (= 3.4 or -3.4).
	.db	0x2D		;;duplicate             x, x.
	.db	0x32		;;less-0                x, (1/0)
	.db	0x00		;;jump-true             x, (1/0)
	.db	0x04		;;to L1C46, X-NEG
			
	.db	0x36		;;truncate              trunc 3.4 = 3.
	.db	0x34		;;end-calc              3.
			
	ret			; return with + int x on stack.
			
			
;; X-NEG
L1C4E:	.db	0x2D		;;duplicate             -3.4, -3.4.
	.db	0x36		;;truncate              -3.4, -3.
	.db	0xC0		;;st-mem-0              -3.4, -3.
	.db	0x03		;;subtract              -.4
	.db	0xE0		;;get-mem-0             -.4, -3.
	.db	0x01		;;exchange              -3, -.4.
	.db	0x2C		;;not                   -3, (0).
	.db	0x00		;;jump-true             -3.
	.db	0x03		;;to L1C59, EXIT        -3.
			
	.db	0xA1		;;stk-one               -3, 1.
	.db	0x03		;;subtract              -4.
			
;; EXIT
L1C59:	.db	0x34		;;end-calc              -4.
			
	ret			; return.
			
			
; ----------------
; Exponential (23)
; ----------------
;
;
			
;; EXP
;; exp
L1C5B:	rst	#0x28		;; FP-CALC
	.db	0x30		;;stk-data
	.db	0xF1		;;Exponent: $81, Bytes: 4
	.db	0x38,0xAA,#0x3B,#0x29	;;
	.db	0x04		;;multiply
	.db	0x2D		;;duplicate
	.db	0x24		;;int
	.db	0xC3		;;st-mem-3
	.db	0x03		;;subtract
	.db	0x2D		;;duplicate
	.db	0x0F		;;addition
	.db	0xA1		;;stk-one
	.db	0x03		;;subtract
	.db	0x88		;;series-08
	.db	0x13		;;Exponent: $63, Bytes: 1
	.db	0x36		;;(+00,+00,+00)
	.db	0x58		;;Exponent: $68, Bytes: 2
	.db	0x65,0x66	;;(+00,+00)
	.db	0x9D		;;Exponent: $6D, Bytes: 3
	.db	0x78,0x65,0x40	;;(+00)
	.db	0xA2		;;Exponent: $72, Bytes: 3
	.db	0x60,0x32,0xC9	;;(+00)
	.db	0xE7		;;Exponent: $77, Bytes: 4
	.db	0x21,0xF7,0xAF,0x24	;;
	.db	0xEB		;;Exponent: $7B, Bytes: 4
	.db	0x2F,0xB0,0xB0,0x14	;;
	.db	0xEE		;;Exponent: $7E, Bytes: 4
	.db	0x7E,#0xBB,#0x94,0x58	;;
	.db	0xF1		;;Exponent: $81, Bytes: 4
	.db	0x3A,#0x7E,#0xF8,0xCF	;;
	.db	0xE3		;;get-mem-3
	.db	0x34		;;end-calc
			
	call	L15CD		; routine FP-TO-A
	jr	NZ,L1C9B	; to N-NEGTV
			
	jr	C,L1C99		; to REPORT-6b
			
	add	A,(HL)		;
	jr	NC,L1CA2	; to RESULT-OK
			
			
;; REPORT-6b
L1C99:	rst	#0x08		; ERROR-1
	.db	0x05		; Error Report: Number too big
			
;; N-NEGTV
L1C9B:	jr	C,L1CA4		; to RSLT-ZERO
			
	sub	(HL)		;
	jr	NC,L1CA4	; to RSLT-ZERO
			
	neg			; Negate
			
;; RESULT-OK
L1CA2:	ld	(HL),A		;
	ret			; return.
			
			
;; RSLT-ZERO
L1CA4:	rst	#0x28		;; FP-CALC
	.db	0x02		;;delete
	.db	0xA0		;;stk-zero
	.db	0x34		;;end-calc
			
	ret			; return.
			
			
; --------------------------------
; THE 'NATURAL LOGARITHM' FUNCTION
; --------------------------------
; (offset $22: 'ln')
;   Like the ZX81 itself, 'natural' logarithms came from Scotland.
;   They were devised in 1614 by well-traveled Scotsman John Napier who noted
;   "Nothing doth more molest and hinder calculators than the multiplications,
;    divisions, square and cubical extractions of great numbers".
;
;   Napier's logarithms enabled the above operations to be accomplished by
;   simple addition and subtraction simplifying the navigational and
;   astronomical calculations which beset his age.
;   Napier's logarithms were quickly overtaken by logarithms to the base 10
;   devised, in conjunction with Napier, by Henry Briggs a Cambridge-educated
;   professor of Geometry at Oxford University. These simplified the layout
;   of the tables enabling humans to easily scale calculations.
;
;   It is only recently with the introduction of pocket calculators and
;   computers like the ZX81 that natural logarithms are once more at the fore,
;   although some computers retain logarithms to the base ten.
;   'Natural' logarithms are powers to the base 'e', which like 'pi' is a
;   naturally occurring number in branches of mathematics.
;   Like 'pi' also, 'e' is an irrational number and starts 2.718281828...
;
;   The tabular use of logarithms was that to multiply two numbers one looked
;   up their two logarithms in the tables, added them together and then looked
;   for the result in a table of antilogarithms to give the desired product.
;
;   The EXP function is the BASIC equivalent of a calculator's 'antiln' function
;   and by picking any two numbers, 1.72 and 6.89 say,
;     10 PRINT EXP ( LN 1.72 + LN 6.89 )
;   will give just the same result as
;     20 PRINT 1.72 * 6.89.
;   Division is accomplished by subtracting the two logs.
;
;   Napier also mentioned "square and cubicle extractions".
;   To raise a number to the power 3, find its 'ln', multiply by 3 and find the
;   'antiln'.  e.g. PRINT EXP( LN 4 * 3 )  gives 64.
;   Similarly to find the n'th root divide the logarithm by 'n'.
;   The ZX81 ROM used PRINT EXP ( LN 9 / 2 ) to find the square root of the
;   number 9. The Napieran square root function is just a special case of
;   the 'to_power' function. A cube root or indeed any root/power would be just
;   as simple.
			
;   First test that the argument to LN is a positive, non-zero number.
			
;; ln
L1CA9:	rst	#0x28		;; FP-CALC
	.db	0x2D		;;duplicate
	.db	0x33		;;greater-0
	.db	0x00		;;jump-true
	.db	0x04		;;to L1CB1, VALID
			
	.db	0x34		;;end-calc
			
			
;; REPORT-Ab
L1CAF:	rst	#0x08		; ERROR-1
	.db	0x09		; Error Report: Invalid argument
			
;; VALID
L1CB1:	.db	0xA0		;;stk-zero              Note. not
	.db	0x02		;;delete                necessary.
	.db	0x34		;;end-calc
	ld	A,(HL)		;
			
	ld	(HL),#0x80	;
	call	L151D		; routine STACK-A
			
	rst	#0x28		;; FP-CALC
	.db	0x30		;;stk-data
	.db	0x38		;;Exponent: $88, Bytes: 1
	.db	0x00		;;(+00,+00,+00)
	.db	0x03		;;subtract
	.db	0x01		;;exchange
	.db	0x2D		;;duplicate
	.db	0x30		;;stk-data
	.db	0xF0		;;Exponent: $80, Bytes: 4
	.db	0x4C,#0xCC,#0xCC,#0xCD	;;
	.db	0x03		;;subtract
	.db	0x33		;;greater-0
	.db	0x00		;;jump-true
	.db	0x08		;;to L1CD2, GRE.8
			
	.db	0x01		;;exchange
	.db	0xA1		;;stk-one
	.db	0x03		;;subtract
	.db	0x01		;;exchange
	.db	0x34		;;end-calc
			
	inc	(HL)		;
			
	rst	#0x28		;; FP-CALC
			
;; GRE.8
L1CD2:	.db	0x01		;;exchange
	.db	0x30		;;stk-data
	.db	0xF0		;;Exponent: $80, Bytes: 4
	.db	0x31,0x72,0x17,0xF8	;;
	.db	0x04		;;multiply
	.db	0x01		;;exchange
	.db	0xA2		;;stk-half
	.db	0x03		;;subtract
	.db	0xA2		;;stk-half
	.db	0x03		;;subtract
	.db	0x2D		;;duplicate
	.db	0x30		;;stk-data
	.db	0x32		;;Exponent: $82, Bytes: 1
	.db	0x20		;;(+00,+00,+00)
	.db	0x04		;;multiply
	.db	0xA2		;;stk-half
	.db	0x03		;;subtract
	.db	0x8C		;;series-0C
	.db	0x11		;;Exponent: $61, Bytes: 1
	.db	0xAC		;;(+00,+00,+00)
	.db	0x14		;;Exponent: $64, Bytes: 1
	.db	0x09		;;(+00,+00,+00)
	.db	0x56		;;Exponent: $66, Bytes: 2
	.db	0xDA,#0xA5	;;(+00,+00)
	.db	0x59		;;Exponent: $69, Bytes: 2
	.db	0x30,0xC5	;;(+00,+00)
	.db	0x5C		;;Exponent: $6C, Bytes: 2
	.db	0x90,0xAA	;;(+00,+00)
	.db	0x9E		;;Exponent: $6E, Bytes: 3
	.db	0x70,0x6F,0x61	;;(+00)
	.db	0xA1		;;Exponent: $71, Bytes: 3
	.db	0xCB,#0xDA,#0x96	;;(+00)
	.db	0xA4		;;Exponent: $74, Bytes: 3
	.db	0x31,0x9F,0xB4	;;(+00)
	.db	0xE7		;;Exponent: $77, Bytes: 4
	.db	0xA0,0xFE,#0x5C,#0xFC	;;
	.db	0xEA		;;Exponent: $7A, Bytes: 4
	.db	0x1B,#0x43,0xCA,#0x36	;;
	.db	0xED		;;Exponent: $7D, Bytes: 4
	.db	0xA7,0x9C,#0x7E,#0x5E	;;
	.db	0xF0		;;Exponent: $80, Bytes: 4
	.db	0x6E,#0x23,0x80,0x93	;;
	.db	0x04		;;multiply
	.db	0x0F		;;addition
	.db	0x34		;;end-calc
			
	ret			; return.
			
; -----------------------------
; THE 'TRIGONOMETRIC' FUNCTIONS
; -----------------------------
;   Trigonometry is rocket science. It is also used by carpenters and pyramid
;   builders.
;   Some uses can be quite abstract but the principles can be seen in simple
;   right-angled triangles. Triangles have some special properties -
;
;   1) The sum of the three angles is always PI radians (180 degrees).
;      Very helpful if you know two angles and wish to find the third.
;   2) In any right-angled triangle the sum of the squares of the two shorter
;      sides is equal to the square of the longest side opposite the right-angle.
;      Very useful if you know the length of two sides and wish to know the
;      length of the third side.
;   3) Functions sine, cosine and tangent enable one to calculate the length
;      of an unknown side when the length of one other side and an angle is
;      known.
;   4) Functions arcsin, arccosine and arctan enable one to calculate an unknown
;      angle when the length of two of the sides is known.
			
; --------------------------------
; THE 'REDUCE ARGUMENT' SUBROUTINE
; --------------------------------
; (offset $35: 'get-argt')
;
;   This routine performs two functions on the angle, in radians, that forms
;   the argument to the sine and cosine functions.
;   First it ensures that the angle 'wraps round'. That if a ship turns through
;   an angle of, say, 3*PI radians (540 degrees) then the net effect is to turn
;   through an angle of PI radians (180 degrees).
;   Secondly it converts the angle in radians to a fraction of a right angle,
;   depending within which quadrant the angle lies, with the periodicity
;   resembling that of the desired sine value.
;   The result lies in the range -1 to +1.
;
;                       90 deg.
;
;                       (pi/2)
;                II       +1        I
;                         |
;          sin+      |\   |   /|    sin+
;          cos-      | \  |  / |    cos+
;          tan-      |  \ | /  |    tan+
;                    |   \|/)  |
;   180 deg. (pi) 0 -|----+----|-- 0  (0)   0 degrees
;                    |   /|\   |
;          sin-      |  / | \  |    sin-
;          cos-      | /  |  \ |    cos+
;          tan+      |/   |   \|    tan-
;                         |
;                III      -1       IV
;                       (3pi/2)
;
;                       270 deg.
			
			
;; get-argt
L1D18:	rst	#0x28		;; FP-CALC         X.
	.db	0x30		;;stk-data
	.db	0xEE		;;Exponent: $7E,
				;;Bytes: 4
	.db	0x22,0xF9,0x83,0x6E	;;                 X, 1/(2*PI)
	.db	0x04		;;multiply         X/(2*PI) = fraction
			
	.db	0x2D		;;duplicate
	.db	0xA2		;;stk-half
	.db	0x0F		;;addition
	.db	0x24		;;int
			
	.db	0x03		;;subtract         now range -.5 to .5
			
	.db	0x2D		;;duplicate
	.db	0x0F		;;addition         now range -1 to 1.
	.db	0x2D		;;duplicate
	.db	0x0F		;;addition         now range -2 to 2.
			
;   quadrant I (0 to +1) and quadrant IV (-1 to 0) are now correct.
;   quadrant II ranges +1 to +2.
;   quadrant III ranges -2 to -1.
			
	.db	0x2D		;;duplicate        Y, Y.
	.db	0x27		;;abs              Y, abs(Y).    range 1 to 2
	.db	0xA1		;;stk-one          Y, abs(Y), 1.
	.db	0x03		;;subtract         Y, abs(Y)-1.  range 0 to 1
	.db	0x2D		;;duplicate        Y, Z, Z.
	.db	0x33		;;greater-0        Y, Z, (1/0).
			
	.db	0xC0		;;st-mem-0         store as possible sign
				;;                 for cosine function.
			
	.db	0x00		;;jump-true
	.db	0x04		;;to L1D35, ZPLUS  with quadrants II and III
			
;   else the angle lies in quadrant I or IV and value Y is already correct.
			
	.db	0x02		;;delete          Y    delete test value.
	.db	0x34		;;end-calc        Y.
			
	ret			; return.         with Q1 and Q4 >>>
			
;   The branch was here with quadrants II (0 to 1) and III (1 to 0).
;   Y will hold -2 to -1 if this is quadrant III.
			
;; ZPLUS
L1D35:	.db	0xA1		;;stk-one         Y, Z, 1
	.db	0x03		;;subtract        Y, Z-1.       Q3 = 0 to -1
	.db	0x01		;;exchange        Z-1, Y.
	.db	0x32		;;less-0          Z-1, (1/0).
	.db	0x00		;;jump-true       Z-1.
	.db	0x02		;;to L1D3C, YNEG
				;;if angle in quadrant III
			
;   else angle is within quadrant II (-1 to 0)
			
	.db	0x18		;;negate          range +1 to 0
			
			
;; YNEG
L1D3C:	.db	0x34		;;end-calc        quadrants II and III correct.
			
	ret			; return.
			
			
; ---------------------
; THE 'COSINE' FUNCTION
; ---------------------
; (offset $1D: 'cos')
;   Cosines are calculated as the sine of the opposite angle rectifying the
;   sign depending on the quadrant rules.
;
;
;             /|
;          h /y|
;           /  |o
;          /x  |
;         /----|
;           a
;
;   The cosine of angle x is the adjacent side (a) divided by the hypotenuse 1.
;   However if we examine angle y then a/h is the sine of that angle.
;   Since angle x plus angle y equals a right-angle, we can find angle y by
;   subtracting angle x from pi/2.
;   However it's just as easy to reduce the argument first and subtract the
;   reduced argument from the value 1 (a reduced right-angle).
;   It's even easier to subtract 1 from the angle and rectify the sign.
;   In fact, after reducing the argument, the absolute value of the argument
;   is used and rectified using the test result stored in mem-0 by 'get-argt'
;   for that purpose.
			
;; cos
L1D3E:	rst	#0x28		;; FP-CALC              angle in radians.
	.db	0x35		;;get-argt              X       reduce -1 to +1
			
	.db	0x27		;;abs                   ABS X   0 to 1
	.db	0xA1		;;stk-one               ABS X, 1.
	.db	0x03		;;subtract              now opposite angle
				;;                      though negative sign.
	.db	0xE0		;;get-mem-0             fetch sign indicator.
	.db	0x00		;;jump-true
	.db	0x06		;;fwd to L1D4B, C-ENT
				;;forward to common code if in QII or QIII
			
			
	.db	0x18		;;negate                else make positive.
	.db	0x2F		;;jump
	.db	0x03		;;fwd to L1D4B, C-ENT
				;;with quadrants QI and QIV
			
; -------------------
; THE 'SINE' FUNCTION
; -------------------
; (offset $1C: 'sin')
;   This is a fundamental transcendental function from which others such as cos
;   and tan are directly, or indirectly, derived.
;   It uses the series generator to produce Chebyshev polynomials.
;
;
;             /|
;          1 / |
;           /  |x
;          /a  |
;         /----|
;           y
;
;   The 'get-argt' function is designed to modify the angle and its sign
;   in line with the desired sine value and afterwards it can launch straight
;   into common code.
			
;; sin
L1D49:	rst	#0x28		;; FP-CALC      angle in radians
	.db	0x35		;;get-argt      reduce - sign now correct.
			
;; C-ENT
L1D4B:	.db	0x2D		;;duplicate
	.db	0x2D		;;duplicate
	.db	0x04		;;multiply
	.db	0x2D		;;duplicate
	.db	0x0F		;;addition
	.db	0xA1		;;stk-one
	.db	0x03		;;subtract
			
	.db	0x86		;;series-06
	.db	0x14		;;Exponent: $64, Bytes: 1
	.db	0xE6		;;(+00,+00,+00)
	.db	0x5C		;;Exponent: $6C, Bytes: 2
	.db	0x1F,0x0B	;;(+00,+00)
	.db	0xA3		;;Exponent: $73, Bytes: 3
	.db	0x8F,0x38,0xEE	;;(+00)
	.db	0xE9		;;Exponent: $79, Bytes: 4
	.db	0x15,0x63,0xBB,#0x23	;;
	.db	0xEE		;;Exponent: $7E, Bytes: 4
	.db	0x92,0x0D,#0xCD,#0xED	;;
	.db	0xF1		;;Exponent: $81, Bytes: 4
	.db	0x23,0x5D,#0x1B,#0xEA	;;
			
	.db	0x04		;;multiply
	.db	0x34		;;end-calc
			
	ret			; return.
			
			
; ----------------------
; THE 'TANGENT' FUNCTION
; ----------------------
; (offset $1E: 'tan')
;
;   Evaluates tangent x as    sin(x) / cos(x).
;
;
;             /|
;          h / |
;           /  |o
;          /x  |
;         /----|
;           a
;
;   The tangent of angle x is the ratio of the length of the opposite side
;   divided by the length of the adjacent side. As the opposite length can
;   be calculates using sin(x) and the adjacent length using cos(x) then
;   the tangent can be defined in terms of the previous two functions.
			
;   Error 6 if the argument, in radians, is too close to one like pi/2
;   which has an infinite tangent. e.g. PRINT TAN (PI/2)  evaluates as 1/0.
;   Similarly PRINT TAN (3*PI/2), TAN (5*PI/2) etc.
			
;; tan
L1D6E:	rst	#0x28		;; FP-CALC          x.
	.db	0x2D		;;duplicate         x, x.
	.db	0x1C		;;sin               x, sin x.
	.db	0x01		;;exchange          sin x, x.
	.db	0x1D		;;cos               sin x, cos x.
	.db	0x05		;;division          sin x/cos x (= tan x).
	.db	0x34		;;end-calc          tan x.
			
	ret			; return.
			
; ---------------------
; THE 'ARCTAN' FUNCTION
; ---------------------
; (Offset $21: 'atn')
;   The inverse tangent function with the result in radians.
;   This is a fundamental transcendental function from which others such as
;   asn and acs are directly, or indirectly, derived.
;   It uses the series generator to produce Chebyshev polynomials.
			
;; atn
L1D76:	ld	A,(HL)		; fetch exponent
	cp	#0x81		; compare to that for 'one'
	jr	C,L1D89		; forward, if less, to SMALL
			
	rst	#0x28		;; FP-CALC      X.
	.db	0xA1		;;stk-one
	.db	0x18		;;negate
	.db	0x01		;;exchange
	.db	0x05		;;division
	.db	0x2D		;;duplicate
	.db	0x32		;;less-0
	.db	0xA3		;;stk-pi/2
	.db	0x01		;;exchange
	.db	0x00		;;jump-true
	.db	0x06		;;to L1D8B, CASES
			
	.db	0x18		;;negate
	.db	0x2F		;;jump
	.db	0x03		;;to L1D8B, CASES
			
; ---
			
;; SMALL
L1D89:	rst	#0x28		;; FP-CALC
	.db	0xA0		;;stk-zero
			
;; CASES
L1D8B:	.db	0x01		;;exchange
	.db	0x2D		;;duplicate
	.db	0x2D		;;duplicate
	.db	0x04		;;multiply
	.db	0x2D		;;duplicate
	.db	0x0F		;;addition
	.db	0xA1		;;stk-one
	.db	0x03		;;subtract
			
	.db	0x8C		;;series-0C
	.db	0x10		;;Exponent: $60, Bytes: 1
	.db	0xB2		;;(+00,+00,+00)
	.db	0x13		;;Exponent: $63, Bytes: 1
	.db	0x0E		;;(+00,+00,+00)
	.db	0x55		;;Exponent: $65, Bytes: 2
	.db	0xE4,0x8D	;;(+00,+00)
	.db	0x58		;;Exponent: $68, Bytes: 2
	.db	0x39,0xBC	;;(+00,+00)
	.db	0x5B		;;Exponent: $6B, Bytes: 2
	.db	0x98,0xFD	;;(+00,+00)
	.db	0x9E		;;Exponent: $6E, Bytes: 3
	.db	0x00,0x36,0x75	;;(+00)
	.db	0xA0		;;Exponent: $70, Bytes: 3
	.db	0xDB,#0xE8,0xB4	;;(+00)
	.db	0x63		;;Exponent: $73, Bytes: 2
	.db	0x42,0xC4	;;(+00,+00)
	.db	0xE6		;;Exponent: $76, Bytes: 4
	.db	0xB5,0x09,0x36,0xBE	;;
	.db	0xE9		;;Exponent: $79, Bytes: 4
	.db	0x36,0x73,0x1B,#0x5D	;;
	.db	0xEC		;;Exponent: $7C, Bytes: 4
	.db	0xD8,0xDE,#0x63,0xBE	;;
	.db	0xF0		;;Exponent: $80, Bytes: 4
	.db	0x61,0xA1,0xB3,0x0C	;;
			
	.db	0x04		;;multiply
	.db	0x0F		;;addition
	.db	0x34		;;end-calc
			
	ret			; return.
			
			
; ---------------------
; THE 'ARCSIN' FUNCTION
; ---------------------
; (Offset $1F: 'asn')
;   The inverse sine function with result in radians.
;   Derived from arctan function above.
;   Error A unless the argument is between -1 and +1 inclusive.
;   Uses an adaptation of the formula asn(x) = atn(x/sqr(1-x*x))
;
;
;                 /|
;                / |
;              1/  |x
;              /a  |
;             /----|
;               y
;
;   e.g. We know the opposite side (x) and hypotenuse (1)
;   and we wish to find angle a in radians.
;   We can derive length y by Pythagoras and then use ATN instead.
;   Since y*y + x*x = 1*1 (Pythagoras Theorem) then
;   y=sqr(1-x*x)                         - no need to multiply 1 by itself.
;   So, asn(a) = atn(x/y)
;   or more fully,
;   asn(a) = atn(x/sqr(1-x*x))
			
;   Close but no cigar.
			
;   While PRINT ATN (x/SQR (1-x*x)) gives the same results as PRINT ASN x,
;   it leads to division by zero when x is 1 or -1.
;   To overcome this, 1 is added to y giving half the required angle and the
;   result is then doubled.
;   That is, PRINT ATN (x/(SQR (1-x*x) +1)) *2
;
;
;               . /|
;            .  c/ |
;         .     /1 |x
;      . c   b /a  |
;    ---------/----|
;      1      y
;
;   By creating an isosceles triangle with two equal sides of 1, angles c and
;   c are also equal. If b+c+d = 180 degrees and b+a = 180 degrees then c=a/2.
;
;   A value higher than 1 gives the required error as attempting to find  the
;   square root of a negative number generates an error in Sinclair BASIC.
			
;; asn
L1DC4:	rst	#0x28		;; FP-CALC      x.
	.db	0x2D		;;duplicate     x, x.
	.db	0x2D		;;duplicate     x, x, x.
	.db	0x04		;;multiply      x, x*x.
	.db	0xA1		;;stk-one       x, x*x, 1.
	.db	0x03		;;subtract      x, x*x-1.
	.db	0x18		;;negate        x, 1-x*x.
	.db	0x25		;;sqr           x, sqr(1-x*x) = y.
	.db	0xA1		;;stk-one       x, y, 1.
	.db	0x0F		;;addition      x, y+1.
	.db	0x05		;;division      x/y+1.
	.db	0x21		;;atn           a/2     (half the angle)
	.db	0x2D		;;duplicate     a/2, a/2.
	.db	0x0F		;;addition      a.
	.db	0x34		;;end-calc      a.
			
	ret			; return.
			
			
; ------------------------
; THE 'ARCCOS' FUNCTION
; ------------------------
; (Offset $20: 'acs')
;   The inverse cosine function with the result in radians.
;   Error A unless the argument is between -1 and +1.
;   Result in range 0 to pi.
;   Derived from asn above which is in turn derived from the preceding atn. It
;   could have been derived directly from atn using acs(x) = atn(sqr(1-x*x)/x).
;   However, as sine and cosine are horizontal translations of each other,
;   uses acs(x) = pi/2 - asn(x)
			
;   e.g. the arccosine of a known x value will give the required angle b in
;   radians.
;   We know, from above, how to calculate the angle a using asn(x).
;   Since the three angles of any triangle add up to 180 degrees, or pi radians,
;   and the largest angle in this case is a right-angle (pi/2 radians), then
;   we can calculate angle b as pi/2 (both angles) minus asn(x) (angle a).
;
;
;            /|
;         1 /b|
;          /  |x
;         /a  |
;        /----|
;          y
			
;; acs
L1DD4:	rst	#0x28		;; FP-CALC      x.
	.db	0x1F		;;asn           asn(x).
	.db	0xA3		;;stk-pi/2      asn(x), pi/2.
	.db	0x03		;;subtract      asn(x) - pi/2.
	.db	0x18		;;negate        pi/2 - asn(x) = acs(x).
	.db	0x34		;;end-calc      acs(x)
			
	ret			; return.
			
			
; --------------------------
; THE 'SQUARE ROOT' FUNCTION
; --------------------------
; (Offset $25: 'sqr')
;   Error A if argument is negative.
;   This routine is remarkable for its brevity - 7 bytes.
;   The ZX81 code was originally 9K and various techniques had to be
;   used to shoe-horn it into an 8K Rom chip.
			
			
;; sqr
L1DDB:	rst	#0x28		;; FP-CALC              x.
	.db	0x2D		;;duplicate             x, x.
	.db	0x2C		;;not                   x, 1/0
	.db	0x00		;;jump-true             x, (1/0).
	.db	0x1E		;;to L1DFD, LAST        exit if argument zero
				;;                      with zero result.
			
;   else continue to calculate as x ** .5
			
	.db	0xA2		;;stk-half              x, .5.
	.db	0x34		;;end-calc              x, .5.
			
			
; ------------------------------
; THE 'EXPONENTIATION' OPERATION
; ------------------------------
; (Offset $06: 'to-power')
;   This raises the first number X to the power of the second number Y.
;   As with the ZX80,
;   0 ** 0 = 1
;   0 ** +n = 0
;   0 ** -n = arithmetic overflow.
			
;; to-power
L1DE2:	rst	#0x28		;; FP-CALC              X,Y.
	.db	0x01		;;exchange              Y,X.
	.db	0x2D		;;duplicate             Y,X,X.
	.db	0x2C		;;not                   Y,X,(1/0).
	.db	0x00		;;jump-true
	.db	0x07		;;forward to L1DEE, XISO if X is zero.
			
;   else X is non-zero. function 'ln' will catch a negative value of X.
			
	.db	0x22		;;ln                    Y, LN X.
	.db	0x04		;;multiply              Y * LN X
	.db	0x34		;;end-calc
			
	jp	L1C5B		; jump back to EXP routine.  ->
			
; ---
			
;   These routines form the three simple results when the number is zero.
;   begin by deleting the known zero to leave Y the power factor.
			
;; XISO
L1DEE:	.db	0x02		;;delete                Y.
	.db	0x2D		;;duplicate             Y, Y.
	.db	0x2C		;;not                   Y, (1/0).
	.db	0x00		;;jump-true
	.db	0x09		;;forward to L1DFB, ONE if Y is zero.
			
;   the power factor is not zero. If negative then an error exists.
			
	.db	0xA0		;;stk-zero              Y, 0.
	.db	0x01		;;exchange              0, Y.
	.db	0x33		;;greater-0             0, (1/0).
	.db	0x00		;;jump-true             0
	.db	0x06		;;to L1DFD, LAST        if Y was any positive
				;;                      number.
			
;   else force division by zero thereby raising an Arithmetic overflow error.
;   There are some one and two-byte alternatives but perhaps the most formal
;   might have been to use end-calc; rst 08; defb 05.
			
	.db	0xA1		;;stk-one               0, 1.
	.db	0x01		;;exchange              1, 0.
	.db	0x05		;;division              1/0    >> error
			
; ---
			
;; ONE
L1DFB:	.db	0x02		;;delete                .
	.db	0xA1		;;stk-one               1.
			
;; LAST
L1DFD:	.db	0x34		;;end-calc              last value 1 or 0.
			
	ret			; return.
			
; ---------------------
; THE 'SPARE LOCATIONS'
; ---------------------
			
;; SPARE
L1DFF:	.db	0xFF		; That's all folks.
			
			
			
; ------------------------
; THE 'ZX81 CHARACTER SET'
; ------------------------
			
;; char-set - begins with space character.
			
; $00 - Character: ' '          CHR$(0)
			
L1E00:	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
			
; $01 - Character: mosaic       CHR$(1)
			
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
			
			
; $02 - Character: mosaic       CHR$(2)
			
	.db	0b00001111
	.db	0b00001111
	.db	0b00001111
	.db	0b00001111
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
			
			
; $03 - Character: mosaic       CHR$(3)
			
	.db	0b11111111
	.db	0b11111111
	.db	0b11111111
	.db	0b11111111
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
			
; $04 - Character: mosaic       CHR$(4)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
			
; $05 - Character: mosaic       CHR$(5)
			
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
			
; $06 - Character: mosaic       CHR$(6)
			
	.db	0b00001111
	.db	0b00001111
	.db	0b00001111
	.db	0b00001111
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
			
; $07 - Character: mosaic       CHR$(7)
			
	.db	0b11111111
	.db	0b11111111
	.db	0b11111111
	.db	0b11111111
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
	.db	0b11110000
			
; $08 - Character: mosaic       CHR$(8)
			
	.db	0b10101010
	.db	0b01010101
	.db	0b10101010
	.db	0b01010101
	.db	0b10101010
	.db	0b01010101
	.db	0b10101010
	.db	0b01010101
			
; $09 - Character: mosaic       CHR$(9)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b10101010
	.db	0b01010101
	.db	0b10101010
	.db	0b01010101
			
; $0A - Character: mosaic       CHR$(10)
			
	.db	0b10101010
	.db	0b01010101
	.db	0b10101010
	.db	0b01010101
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
			
; $0B - Character: '"'          CHR$(11)
			
	.db	0b00000000
	.db	0b00100100
	.db	0b00100100
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
			
; $0B - Character: ukp          CHR$(12)
			
	.db	0b00000000
	.db	0b00011100
	.db	0b00100010
	.db	0b01111000
	.db	0b00100000
	.db	0b00100000
	.db	0b01111110
	.db	0b00000000
			
; $0B - Character: '$'          CHR$(13)
			
	.db	0b00000000
	.db	0b00001000
	.db	0b00111110
	.db	0b00101000
	.db	0b00111110
	.db	0b00001010
	.db	0b00111110
	.db	0b00001000
			
; $0B - Character: ':'          CHR$(14)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00010000
	.db	0b00000000
	.db	0b00000000
	.db	0b00010000
	.db	0b00000000
			
; $0B - Character: '?'          CHR$(15)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b00000100
	.db	0b00001000
	.db	0b00000000
	.db	0b00001000
	.db	0b00000000
			
; $10 - Character: '('          CHR$(16)
			
	.db	0b00000000
	.db	0b00000100
	.db	0b00001000
	.db	0b00001000
	.db	0b00001000
	.db	0b00001000
	.db	0b00000100
	.db	0b00000000
			
; $11 - Character: ')'          CHR$(17)
			
	.db	0b00000000
	.db	0b00100000
	.db	0b00010000
	.db	0b00010000
	.db	0b00010000
	.db	0b00010000
	.db	0b00100000
	.db	0b00000000
			
; $12 - Character: '>'          CHR$(18)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00010000
	.db	0b00001000
	.db	0b00000100
	.db	0b00001000
	.db	0b00010000
	.db	0b00000000
			
; $13 - Character: '<'          CHR$(19)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000100
	.db	0b00001000
	.db	0b00010000
	.db	0b00001000
	.db	0b00000100
	.db	0b00000000
			
; $14 - Character: '='          CHR$(20)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00111110
	.db	0b00000000
	.db	0b00111110
	.db	0b00000000
	.db	0b00000000
			
; $15 - Character: '+'          CHR$(21)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00001000
	.db	0b00001000
	.db	0b00111110
	.db	0b00001000
	.db	0b00001000
	.db	0b00000000
			
; $16 - Character: '-'          CHR$(22)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00111110
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
			
; $17 - Character: '*'          CHR$(23)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00010100
	.db	0b00001000
	.db	0b00111110
	.db	0b00001000
	.db	0b00010100
	.db	0b00000000
			
; $18 - Character: '/'          CHR$(24)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000010
	.db	0b00000100
	.db	0b00001000
	.db	0b00010000
	.db	0b00100000
	.db	0b00000000
			
; $19 - Character: ';'          CHR$(25)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00010000
	.db	0b00000000
	.db	0b00000000
	.db	0b00010000
	.db	0b00010000
	.db	0b00100000
			
; $1A - Character: ','          CHR$(26)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00001000
	.db	0b00001000
	.db	0b00010000
			
; $1B - Character: '.'          CHR$(27)
			
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00000000
	.db	0b00011000
	.db	0b00011000
	.db	0b00000000
			
; $1C - Character: '0'          CHR$(28)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000110
	.db	0b01001010
	.db	0b01010010
	.db	0b01100010
	.db	0b00111100
	.db	0b00000000
			
; $1D - Character: '1'          CHR$(29)
			
	.db	0b00000000
	.db	0b00011000
	.db	0b00101000
	.db	0b00001000
	.db	0b00001000
	.db	0b00001000
	.db	0b00111110
	.db	0b00000000
			
; $1E - Character: '2'          CHR$(30)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b00000010
	.db	0b00111100
	.db	0b01000000
	.db	0b01111110
	.db	0b00000000
			
; $1F - Character: '3'          CHR$(31)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b00001100
	.db	0b00000010
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $20 - Character: '4'          CHR$(32)
			
	.db	0b00000000
	.db	0b00001000
	.db	0b00011000
	.db	0b00101000
	.db	0b01001000
	.db	0b01111110
	.db	0b00001000
	.db	0b00000000
			
; $21 - Character: '5'          CHR$(33)
			
	.db	0b00000000
	.db	0b01111110
	.db	0b01000000
	.db	0b01111100
	.db	0b00000010
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $22 - Character: '6'          CHR$(34)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000000
	.db	0b01111100
	.db	0b01000010
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $23 - Character: '7'          CHR$(35)
			
	.db	0b00000000
	.db	0b01111110
	.db	0b00000010
	.db	0b00000100
	.db	0b00001000
	.db	0b00010000
	.db	0b00010000
	.db	0b00000000
			
; $24 - Character: '8'          CHR$(36)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b00111100
	.db	0b01000010
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $25 - Character: '9'          CHR$(37)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b01000010
	.db	0b00111110
	.db	0b00000010
	.db	0b00111100
	.db	0b00000000
			
; $26 - Character: 'A'          CHR$(38)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b01000010
	.db	0b01111110
	.db	0b01000010
	.db	0b01000010
	.db	0b00000000
			
; $27 - Character: 'B'          CHR$(39)
			
	.db	0b00000000
	.db	0b01111100
	.db	0b01000010
	.db	0b01111100
	.db	0b01000010
	.db	0b01000010
	.db	0b01111100
	.db	0b00000000
			
; $28 - Character: 'C'          CHR$(40)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b01000000
	.db	0b01000000
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $29 - Character: 'D'          CHR$(41)
			
	.db	0b00000000
	.db	0b01111000
	.db	0b01000100
	.db	0b01000010
	.db	0b01000010
	.db	0b01000100
	.db	0b01111000
	.db	0b00000000
			
; $2A - Character: 'E'          CHR$(42)
			
	.db	0b00000000
	.db	0b01111110
	.db	0b01000000
	.db	0b01111100
	.db	0b01000000
	.db	0b01000000
	.db	0b01111110
	.db	0b00000000
			
; $2B - Character: 'F'          CHR$(43)
			
	.db	0b00000000
	.db	0b01111110
	.db	0b01000000
	.db	0b01111100
	.db	0b01000000
	.db	0b01000000
	.db	0b01000000
	.db	0b00000000
			
; $2C - Character: 'G'          CHR$(44)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b01000000
	.db	0b01001110
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $2D - Character: 'H'          CHR$(45)
			
	.db	0b00000000
	.db	0b01000010
	.db	0b01000010
	.db	0b01111110
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b00000000
			
; $2E - Character: 'I'          CHR$(46)
			
	.db	0b00000000
	.db	0b00111110
	.db	0b00001000
	.db	0b00001000
	.db	0b00001000
	.db	0b00001000
	.db	0b00111110
	.db	0b00000000
			
; $2F - Character: 'J'          CHR$(47)
			
	.db	0b00000000
	.db	0b00000010
	.db	0b00000010
	.db	0b00000010
	.db	0b01000010
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $30 - Character: 'K'          CHR$(48)
			
	.db	0b00000000
	.db	0b01000100
	.db	0b01001000
	.db	0b01110000
	.db	0b01001000
	.db	0b01000100
	.db	0b01000010
	.db	0b00000000
			
; $31 - Character: 'L'          CHR$(49)
			
	.db	0b00000000
	.db	0b01000000
	.db	0b01000000
	.db	0b01000000
	.db	0b01000000
	.db	0b01000000
	.db	0b01111110
	.db	0b00000000
			
; $32 - Character: 'M'          CHR$(50)
			
	.db	0b00000000
	.db	0b01000010
	.db	0b01100110
	.db	0b01011010
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b00000000
			
; $33 - Character: 'N'          CHR$(51)
			
	.db	0b00000000
	.db	0b01000010
	.db	0b01100010
	.db	0b01010010
	.db	0b01001010
	.db	0b01000110
	.db	0b01000010
	.db	0b00000000
			
; $34 - Character: 'O'          CHR$(52)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $35 - Character: 'P'          CHR$(53)
			
	.db	0b00000000
	.db	0b01111100
	.db	0b01000010
	.db	0b01000010
	.db	0b01111100
	.db	0b01000000
	.db	0b01000000
	.db	0b00000000
			
; $36 - Character: 'Q'          CHR$(54)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000010
	.db	0b01000010
	.db	0b01010010
	.db	0b01001010
	.db	0b00111100
	.db	0b00000000
			
; $37 - Character: 'R'          CHR$(55)
			
	.db	0b00000000
	.db	0b01111100
	.db	0b01000010
	.db	0b01000010
	.db	0b01111100
	.db	0b01000100
	.db	0b01000010
	.db	0b00000000
			
; $38 - Character: 'S'          CHR$(56)
			
	.db	0b00000000
	.db	0b00111100
	.db	0b01000000
	.db	0b00111100
	.db	0b00000010
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $39 - Character: 'T'          CHR$(57)
			
	.db	0b00000000
	.db	0b11111110
	.db	0b00010000
	.db	0b00010000
	.db	0b00010000
	.db	0b00010000
	.db	0b00010000
	.db	0b00000000
			
; $3A - Character: 'U'          CHR$(58)
			
	.db	0b00000000
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b00111100
	.db	0b00000000
			
; $3B - Character: 'V'          CHR$(59)
			
	.db	0b00000000
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b00100100
	.db	0b00011000
	.db	0b00000000
			
; $3C - Character: 'W'          CHR$(60)
			
	.db	0b00000000
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b01000010
	.db	0b01011010
	.db	0b00100100
	.db	0b00000000
			
; $3D - Character: 'X'          CHR$(61)
			
	.db	0b00000000
	.db	0b01000010
	.db	0b00100100
	.db	0b00011000
	.db	0b00011000
	.db	0b00100100
	.db	0b01000010
	.db	0b00000000
			
; $3E - Character: 'Y'          CHR$(62)
			
	.db	0b00000000
	.db	0b10000010
	.db	0b01000100
	.db	0b00101000
	.db	0b00010000
	.db	0b00010000
	.db	0b00010000
	.db	0b00000000
			
; $3F - Character: 'Z'          CHR$(63)
			
	.db	0b00000000
	.db	0b01111110
	.db	0b00000100
	.db	0b00001000
	.db	0b00010000
	.db	0b00100000
	.db	0b01111110
	.db	0b00000000

