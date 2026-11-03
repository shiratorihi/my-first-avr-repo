; vim: set filetype=asm:

; template.S by ShiratoriYuuka314
; For use on ATmega328P microcontroller

; This program is completely bare-metal and doesn't need to link standard start file

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
.equ SREG, 0x3F
.equ SPCR, 0x2C ; 7:0 -> SPIE, SPE, DORD, MSTR, CPOL, CPHA, SPR1, SPR0
.equ SPSR, 0x2D ; 7:6, 0 -> SPIF, WCOL, SPI2X
.equ SPDR, 0x2E
.equ DDRB, 0x04
; Set SFR Data addr
.equ OSCCAL, 0x66

; Calibration for internal calibrated RC oscillator varies on different chips
.equ CALIBRATION, 0xC0 ; Default value of my chip is 0xC5, calibrated to error margin < ±1%

; Set SPI output ring buffer size, must be power of 2, max 256
.equ SPIOUTBUFSIZE, 256
.equ SPIOUTBUFMASK, SPIOUTBUFSIZE - 1

; SRAM allocation
.section .bss
spiout_buf: .space SPIOUTBUFSIZE
spiout_buf_head: .space 1
spiout_buf_tail: .space 1

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
  sbi DDRB, 2 ; SS output
  sbi DDRB, 3 ; MOSI output
  sbi DDRB, 5 ; SCK output
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

spiout_fillbyte:
  ; Load byte to fill into spiout_buf to r24 before calling
  ; Clobbers are r16, r17, r18, Y
  ldi YH, hi8(spiout_buf)
  ldi YL, lo8(spiout_buf)
  lds r16, spiout_buf_head
  inc r16
  andi r16, SPIOUTBUFMASK ; Loopback when overflow
  lds r17, spiout_buf_tail
  cp r16, r17
  breq spiout_fillbyte_full ; Blocking wait if buffer full, ensure global interrupt on
  lds r16, spiout_buf_head
  mov r18, r16 ; Save a copy of head index
  add YL, r16
  ldi r16, 0
  adc YH, r16
  st Y, r24 ; Load byte to ring buffer
  inc r18 ; Increase head index by 1
  andi r18, SPIOUTBUFMASK ; Loopback when overflow
  sts spiout_buf_head, r18 ; Update new head index value
  in r16, SPCR
  sbrc r16, 7 ; Skip if SPIE cleared, indicates SPI idle
  rjmp spiout_fillbyte_end
  lds r17, spiout_buf_tail
  inc r17
  andi r17, SPIOUTBUFMASK
  sts spiout_buf_tail, r17
  sbr r16, 1 << 7 ; SPIE
  out SPCR, r16 ; Set SPIE, marking SPI busy
  out SPDR, r24 ; Start new cycle of transfer
spiout_fillbyte_end:
  ret
spiout_fillbyte_full:
  rjmp spiout_fillbyte
  ret

_spi_stc_isr:
  ; Keep transmitting the next byte, or disabling SPI_STC interrupt
  ; Context saving
  push r16
  push r17
  push XH
  push XL
  in r16, SREG
  push r16

  lds r16, spiout_buf_head
  lds r17, spiout_buf_tail
  cp r16, r17
  brne keep_spiout ; Check if buffer empty
  in r16, SPCR
  cbr r16, 1 << 7 ; SPIE
  out SPCR, r16 ; Disable SPIE, mark SPI idle
  rjmp spi_stc_end
keep_spiout:
  ldi r16, 0
  ldi XH, hi8(spiout_buf)
  ldi XL, lo8(spiout_buf)
  add XL, r17
  adc XH, r16
  ld r16, X
  out SPDR, r16 ; Load byte to send to SPDR
  inc r17
  andi r17, SPIOUTBUFMASK ; Loopback when overflow
  sts spiout_buf_tail, r17
spi_stc_end:
  ; Context recovering
  pop r16
  out SREG, r16
  pop XL
  pop XH
  pop r17
  pop r16
  reti

guard_loop:
  ; Prevent program from running into data area
  rjmp guard_loop
