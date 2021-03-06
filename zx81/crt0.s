;--------------------------------------------------------------------------
;  crt0.s - crt0.s for a ZX81 including ROM
;
;  Copyright (C) 2021, Sascha Ittner
;
;  This library is free software; you can redistribute it and/or modify it
;  under the terms of the GNU General Public License as published by the
;  Free Software Foundation; either version 2, or (at your option) any
;  later version.
;
;  This library is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License 
;  along with this library; see the file COPYING. If not, write to the
;  Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
;   MA 02110-1301, USA.
;--------------------------------------------------------------------------

	.module crt0

	.globl	_ROM_SLOW_FAST
	.globl	_ROM_DISPLAY_1
	.globl	_ROM_SAVE_CONT
	.globl	_ROM_LOAD_CONT
	.globl	_ROM_PROGRAM_NAME
	.globl	_ROM_INIT_CONT
	.globl	_ROM_PRINT_CH
	.globl	_ROM_PRINT_SP
	.globl	_ROM_CLS

	.globl	_init
	.globl	_save
	.globl	_load
	.globl	_show_error

	.area	_HEADER (ABS)

	.include "zx81rom-patched.i"

	;; Ordering of segments for the linker.
	.area	_HOME
	.area	_CODE
	.area   _GSINIT
	.area   _GSFINAL

	.area	_CDATA
	.area	_INITIALIZER

	.area	_DATA
	.area	_INITIALIZED
	.area	_BSEG
	.area   _BSS
	.area   _HEAP

	.area	_DATA
_CDFLAG =	0x403B

	.area   _CODE

init_patch:
	; first the remaining initialization ripped from original ROM
	; this was overwritten by our patch call
	ld hl,#0x407D	; The first location after System Variables -
			; 16509 decimal.
	ld (0x400C),hl	; set system variable D_FILE to this value.
	ld b,#0x19	; prepare minimal screen of 24 NEWLINEs
			; following an initial NEWLINE.

	push af
	push bc
	push de
	push hl
	push ix

	;; Initialise global variables
	call gsinit

	call _init

	POP ix
	POP hl
	POP de
	POP bc
	POP af

	; continue with init
	jp _ROM_INIT_CONT

save_patch:
	; get filename
	call _ROM_PROGRAM_NAME
	jr c,save_tape
	push af

	; check for ":" prefix for mmc access
	ld a,(de)
	and #0x7f
	cp #14
	jr NZ,save_tape

	push bc
	push de
	push hl
	push ix

	; save CDFLAG
	ld a,(_CDFLAG)
	push af

	; we need FAST mode, since sdcc is using IX
	; however the save/last routines are actually
	; called in FAST mode, so this switch is not necessary
	;call _ROM_FAST

	; push DE on stack -> filename for save function
	push de
	call _save

	call _show_error
	jr exit_to_os

save_tape:
	pop af
	jp _ROM_SAVE_CONT

load_patch:
	; get filename
	call _ROM_PROGRAM_NAME
	jr c,load_tape
	push af

	; check for ":" prefix for mmc access
	ld a,(de)
	and #0x7f
	cp #14
	jr NZ,load_tape

	push bc
	push de
	push hl
	push ix

	; save CDFLAG
	ld a,(_CDFLAG)
	push af

	; we need FAST mode, since sdcc is using IX
	; however the save/last routines are actually
	; called in FAST mode, so this switch is not necessary
	;call _ROM_FAST

	; push DE on stack -> filename for load function
	push de
	call _load

	call _show_error
	jr exit_to_os

load_tape:
	pop af
	jp _ROM_SAVE_CONT

exit_to_os:
	; restore CDFLAG
	pop af
	ld (_CDFLAG),a

	pop ix
	pop hl
	pop de
	pop bc

	ld a,(_last_error)
	cp #0
	jr NZ,exit_error

	pop af
	jp _ROM_SLOW_FAST

exit_error:
	pop af
	rst #0x08 ; ERROR-1
	.db 0x1b  ; error S (sd card error)

	.area   _GSINIT

gsinit::
	ld	bc, #l__INITIALIZER
	ld	a, b
	or	a, c
	jr	Z, gsinit_next
	ld	de, #s__INITIALIZED
	ld	hl, #s__INITIALIZER
	ldir
gsinit_next:

	.area   _GSFINAL
	ret

