; vim: set filetype=asm:

; template.S by ShiratoriYuuka314
; For use on ATmega328P microcontroller

; This program is completely bare-metal and doesn't need to link standard start file

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
.equ SPCR, 0x2C ; 7:0 -> SPIE, SPE, DORD, MSTR, CPOL, CPHA, SPR1, SPR0
.equ SPSR, 0x2D ; 7:6, 0 -> SPIF, WCOL, SPI2X
.equ SPDR, 0x2E
; Set SFR Data addr
.equ OSCCAL, 0x66

; Calibration for internal calibrated RC oscillator varies on different chips
.equ CALIBRATION, 0xC0 ; Default value of my chip is 0xC5, calibrated to error margin < ±1%

; SRAM allocation
.section .bss

.section .text
.global _start
.org 0x0000

  rjmp _start ; RESET

.org 0x0044

  rjmp _spi_stc_isr ; SPI_STC

.org 0x0068 ; Start of user code section
;-------------------------------------------------------------------------------
_start:
  ; Stack Pointer init
  ldi r16, lo8(RAMEND) ; 0xFF
  out SPL, r16
  ldi r16, hi8(RAMEND) ; 0x08
  out SPH, r16

  rcall spi_master_init
  rcall osc_cal
  sei

main_loop:

  rjmp main_loop
;-------------------------------------------------------------------------------

spi_master_init:
  ldi r16, 1 << 0 ; SPI2X
  out SPSR, r16 ; Enable double SPI speed
  ldi r16, (1 << 7) | (1 << 6) | (1 << 4) ; SPIE, SPE, MSTR
  out SPCR, r16 ; Enable SPI, SPI interrupt, master mode
  ret

osc_cal:
  ; Load new internal RC oscillator calibration value
  ldi r16, CALIBRATION
  sts OSCCAL, r16
  ret

_spi_stc_isr:
  reti

guard_loop:
  ; Prevent program from running into data area
  rjmp guard_loop
