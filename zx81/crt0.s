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

CDFLAG_ADR .equ 16443

	.globl	_ROM_AFTER_PATCH
	.globl	_ROM_REPORT_F
	.globl	_ROM_SAVE_CONT
	.globl	_ROM_LOAD_CONT
	.globl	_ROM_GET_FILENAME
	.globl	_ROM_INIT_CONT
	.globl	_ROM_FAST
	.globl	_ROM_SLOW

	.globl	_init
	.globl	_save
	.globl	_load
	.globl	_show_error

	.area	_HEADER (ABS)

	.include "zx81rom-patched.i"

	;; Ordering of segments for the linker.
	.area	_HOME
	.area	_CODE
	.area	_INITIALIZER
	.area   _GSINIT
	.area   _GSFINAL

	.area	_DATA
	.area	_INITIALIZED
	.area	_BSEG
	.area   _BSS
	.area   _HEAP

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
	call _ROM_GET_FILENAME
	jp c,save_tape
	push af

	; check for ":" prefix for mmc access
	ld a,(de)
	and #0x7f
	cp #14
	jr nz,save_tape

	push bc
	push de
	push hl
	push ix

	; save CDFLAG
	ld a,(CDFLAG_ADR)
	push af

	; force fast mode
	call _ROM_FAST

	call _save

	call _show_error
	jp exit_to_os

save_tape:
	pop af
	jp _ROM_SAVE_CONT

load_patch:
	; get filename
	call _ROM_GET_FILENAME
	jp c,load_tape
	push af

	; check for ":" prefix for mmc access
	ld a,(de)
	and #0x7f
	cp #14
	jr nz,load_tape

	push bc
	push de
	push hl
	push ix

	; save CDFLAG
	ld a,(CDFLAG_ADR)
	push af

	; force fast mode
	call _ROM_FAST

	call _load
	call _show_error
	jp exit_to_os

load_tape:
	pop af
	jp _ROM_SAVE_CONT

exit_to_os:
	; restore CDFLAG
	pop af
	ld (CDFLAG_ADR),a

	pop ix
	pop hl
	pop de
	pop bc

	ld a,(_last_error)
	cp #0
	jp z,exit_ok

exit_failed:
	pop af
	jp _ROM_REPORT_F

exit_ok:
	pop af
	jp _ROM_AFTER_PATCH

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

