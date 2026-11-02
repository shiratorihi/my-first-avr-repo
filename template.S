; vim: set filetype=asm:

; template.S by ShiratoriYuuka314
; For use on ATmega328P microcontroller

; This program is completely bare-metal and doesn't need to link standard start file

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
; Set SFR Data addr
.equ OSCCAL, 0x66

; Calibration for internal calibrated RC oscillator varies on different chips
.equ CALIBRATION, 0xC0 ; Default value of my chip is 0xC5, calibrated to error margin < ±1%

; SRAM allocation
.section .bss

.section .text
.global _start
.org 0x0000

  jmp _start ; RESET

.org 0x0068 ; Start of user code section
;-------------------------------------------------------------------------------
_start:
  ; Stack Pointer init
  ldi r16, lo8(RAMEND) ; 0xFF
  out SPL, r16
  ldi r16, hi8(RAMEND) ; 0x08
  out SPH, r16

  rcall osc_cal

main_loop:

  rjmp main_loop
;-------------------------------------------------------------------------------

osc_cal:
  ; Load new internal RC oscillator calibration value
  ldi r16, CALIBRATION
  sts OSCCAL, r16
  ret

guard_loop:
  ; Prevent program from running into data area
  rjmp guard_loop
