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

	.globl	_save_os_regs
	.globl	_restore_os_regs

	.area	_HEADER (ABS)

	.include "zx81rom-patched.i"

_CDFLAG = 0x403B

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

os_reg_bc:
	.ds 2
os_reg_de:
	.ds 2
os_reg_hl:
	.ds 2
os_reg_ix:
	.ds 2

	.area   _CODE

_save_os_regs:
	ld (os_reg_bc), bc
	ld (os_reg_de), de
	ld (os_reg_hl), hl
	ld (os_reg_ix), ix
	ret

_restore_os_regs:
	ld bc, (os_reg_bc)
	ld de, (os_reg_de)
	ld hl, (os_reg_hl)
	ld ix, (os_reg_ix)
	ret

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

	call _save_os_regs

	; save CDFLAG
	ld a,(_CDFLAG)
	push af

	; we need FAST mode, since sdcc is using IX
	; however the save/last routines are actually
	; called in FAST mode, so this switch is not necessary
	;call _ROM_FAST

	; __sdcccall(1): set 'hl' -> filename for save function
	ld h,d
	ld l,e
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

	call _save_os_regs

	; save CDFLAG
	ld a,(_CDFLAG)
	push af

	; we need FAST mode, since sdcc is using IX
	; however the save/last routines are actually
	; called in FAST mode, so this switch is not necessary
	;call _ROM_FAST

	; __sdcccall(1): set 'hl' -> filename for load function
	ld h,d
	ld l,e
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

	call _restore_os_regs

	ld a,(_tfs_last_error)
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

