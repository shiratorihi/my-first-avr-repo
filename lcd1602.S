; vim: set filetype=asm:

; lcd1602.S by ShiratoriYuuka314
; For use on ATmega328P microcontroller
; PB7:0 as 8-pin parallel IO pins
; PD7:5 as E, RW, RS control pins
; Running on calibrated internal RC oscillator @ 8MHz
; This program is completely bare-metal and doesn't need to link standard start file

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E

; SRAM allocation
.section .bss

.section .text
.global _start
.org 0x0000

  jmp _start ; 0x0000 RESET

.org 0x0068 ; Start of user code section
;-------------------------------------------------------------------------------
_start:
  ; Stack Pointer init
  ldi r16, lo8(RAMEND) ; 0xFF
  out SPL, r16
  ldi r16, hi8(RAMEND) ; 0x08
  out SPH, r16

main_loop:
  
  rjmp main_loop
;-------------------------------------------------------------------------------

