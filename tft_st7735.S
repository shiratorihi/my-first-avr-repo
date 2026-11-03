; vim: set filetype=asm:

; tft_st7735.S by ShiratoriYuuka314
; For use on ATmega328P microcontroller
; Using hardware SPI interface to control TFT module
; TFT module based on ST7735S, 128x128 resolution
; Using RGB565 color format
; PD7:5 as RST, RS, CS control pins
; Running on calibrated internal RC oscillator @ 8MHz
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
.equ PORTD, 0x0B
.equ DDRD, 0x0A
.equ DDRB, 0x04
; Set SFR Data addr
.equ OSCCAL, 0x66

; Set pin definition
.equ RST, 7
.equ RS, 6
.equ CS, 5

; Calibration for internal calibrated RC oscillator varies on different chips
.equ CALIBRATION, 0xC0 ; Default value of my chip is 0xC5, calibrated to error margin < ±1%

; Set SPI output ring buffer size, must be power of 2, max 256
; .equ SPIOUTBUFSIZE, 256
; .equ SPIOUTBUFMASK, SPIOUTBUFSIZE - 1

; SRAM allocation
.section .bss
; spiout_buf: .space SPIOUTBUFSIZE
; spiout_buf_head: .space 1
; spiout_buf_tail: .space 1

.section .text
.global _start
.org 0x0000

  rjmp _start ; RESET

; .org 0x0044
;
;   rjmp _spi_stc_isr ; SPI_STC

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
  rcall tft_init
  rcall tft_set_fullscreen
  ; sei

main_loop:

  ldi r23, 0xFF
  ldi r22, 0xFF
  rcall tft_fill_screen

  ldi r23, 0x00
  ldi r22, 0x00
  rcall tft_fill_screen

  rjmp main_loop
;-------------------------------------------------------------------------------

spi_master_init:
  ldi r16, 0x2C ; Set bit 5, 3, 2 or SCK, MOSI, SS to output
  out DDRB, r16
  ldi r16, 0xE0 ; Set bit PD7:5 to output
  out DDRD, r16
  ldi r16, 1 << 0 ; SPI2X
  out SPSR, r16 ; Enable double SPI speed
  ldi r16, (1 << 6) | (1 << 4) ; SPE, MSTR
  out SPCR, r16 ; Enable SPI, SPI interrupt, master mode
  ret

osc_cal:
  ; Load new internal RC oscillator calibration value
  ldi r16, CALIBRATION
  sts OSCCAL, r16
  ret

delay:
  ; Simple delay subroutine of 255 rounds, ~770 clk cycles or ~96 us @ 8MHz
  ldi r16, 255
delay_loop:
  dec r16
  brne delay_loop
  ret

delay_24ms:
  ; Simple delay subroutine of ~195,844 cycles or 24.48 ms @ 8MHz
  ldi r16, 255
delay_24ms_outer:
  ldi r17, 255
delay_24ms_inner:
  dec r17
  brne delay_24ms_inner
  dec r16
  brne delay_24ms_outer
  ret

delay_168ms:
  ; Repeat delay_24ms 7 times
  ldi r18, 7
delay_168ms_loop:
  rcall delay_24ms
  dec r18
  brne delay_168ms_loop
  ret

spiout_blocking:
  ; Load byte to transmit into SPDR to r24 before calling
  in r16, SPSR
  in r16, SPDR ; Ensure stale SPIF is cleared
  out SPDR, r24
spiout_blocking_wait:
  in r16, SPSR
  sbrs r16, 7 ; SPIF
  rjmp spiout_blocking_wait
  in r16, SPDR ; Ensure SPIF cleared before returning
  ret

tft_send_command:
  ; Load byte to send to r24 before calling
  ; Notice! This function does NOT set nor clear CS
  cbi PORTD, RS
  rcall spiout_blocking
  ret

tft_send_data:
  ; Load byte to send to r24 before calling
  ; Notice! This function does NOT set nor clear CS
  sbi PORTD, RS
  rcall spiout_blocking
  ret

tft_init:
  rcall delay_24ms
  sbi PORTD, RST ; End hardware reset
  rcall delay_168ms

  cbi PORTD, CS ; Ensure CS is low
  ldi r24, 0x01 ; SWRESET
  rcall tft_send_command
  sbi PORTD, CS
  rcall delay_168ms

  cbi PORTD, CS
  ldi r24, 0x11 ; SLPOUT
  rcall tft_send_command
  sbi PORTD, CS
  rcall delay_168ms

  cbi PORTD, CS
  ldi r24, 0x3A ; COLMOD
  rcall tft_send_command
  ldi r24, 0x55 ; 16-bit mode, RGB565
  rcall tft_send_data
  sbi PORTD, CS
  rcall delay_24ms

  cbi PORTD, CS
  ldi r24, 0x29 ; DISPON
  rcall tft_send_command
  sbi PORTD, CS
  rcall delay_168ms
  ret

tft_set_fullscreen:
  ; Call this after init
  cbi PORTD, CS
  ldi r24, 0x2A ; CASET
  rcall tft_send_command
  ldi r24, 0x00
  rcall tft_send_data
  ldi r24, 0x02 ; Column address from 2
  rcall tft_send_data
  ldi r24, 0x00
  rcall tft_send_data
  ldi r24, 0x81 ; to 129
  rcall tft_send_data
  sbi PORTD, CS

  cbi PORTD, CS
  ldi r24, 0x2B ; RASET
  rcall tft_send_command
  ldi r24, 0x00
  rcall tft_send_data
  ldi r24, 0x00 ; Row address from 3
  rcall tft_send_data
  ldi r24, 0x00
  rcall tft_send_data
  ldi r24, 0x7F ; to 130
  rcall tft_send_data
  sbi PORTD, CS
  ret

tft_fill_screen:
  ; Load RGB565 value to r23:r22 before calling
  cbi PORTD, CS
  ldi r24, 0x2C ; RAMWR
  rcall tft_send_command
  ldi r17, 128
fill_row_loop:
  ldi r16, 128
fill_column_loop:
  mov r24, r23
  rcall tft_send_data
  mov r24, r22
  rcall tft_send_data
  dec r16
  brne fill_column_loop
  dec r17
  brne fill_row_loop
  sbi PORTD, CS
  ret

; spiout_fillbyte:
;   ; Load byte to fill into spiout_buf to r24 before calling
;   ; Clobbers are r16, r17, r18, Y
;   ldi YH, hi8(spiout_buf)
;   ldi YL, lo8(spiout_buf)
;   lds r16, spiout_buf_head
;   inc r16
;   andi r16, SPIOUTBUFMASK ; Loopback when overflow
;   lds r17, spiout_buf_tail
;   cp r16, r17
;   breq spiout_fillbyte_full ; Blocking wait if buffer full, ensure global interrupt on
;   lds r16, spiout_buf_head
;   mov r18, r16 ; Save a copy of head index
;   add YL, r16
;   ldi r16, 0
;   adc YH, r16
;   st Y, r24 ; Load byte to ring buffer
;   inc r18 ; Increase head index by 1
;   andi r18, SPIOUTBUFMASK ; Loopback when overflow
;   sts spiout_buf_head, r18 ; Update new head index value
;   in r16, SPCR
;   sbrc r16, 7 ; Skip if SPIE cleared, indicates SPI idle
;   rjmp spiout_fillbyte_end
;   lds r17, spiout_buf_tail
;   inc r17
;   andi r17, SPIOUTBUFMASK
;   sts spiout_buf_tail, r17
;   sbr r16, 1 << 7 ; SPIE
;   out SPCR, r16 ; Set SPIE, marking SPI busy
;   out SPDR, r24 ; Start new cycle of transfer
; spiout_fillbyte_end:
;   ret
; spiout_fillbyte_full:
;   rjmp spiout_fillbyte
;   ret
;
; _spi_stc_isr:
;   ; Keep transmitting the next byte, or disabling SPI_STC interrupt
;   ; Context saving
;   push r16
;   push r17
;   push XH
;   push XL
;   in r16, SREG
;   push r16
;
;   lds r16, spiout_buf_head
;   lds r17, spiout_buf_tail
;   cp r16, r17
;   brne keep_spiout ; Check if buffer empty
;   in r16, SPCR
;   cbr r16, 1 << 7 ; SPIE
;   out SPCR, r16 ; Disable SPIE, mark SPI idle
;   rjmp spi_stc_end
; keep_spiout:
;   ldi r16, 0
;   ldi XH, hi8(spiout_buf)
;   ldi XL, lo8(spiout_buf)
;   add XL, r17
;   adc XH, r16
;   ld r16, X
;   out SPDR, r16 ; Load byte to send to SPDR
;   inc r17
;   andi r17, SPIOUTBUFMASK ; Loopback when overflow
;   sts spiout_buf_tail, r17
; spi_stc_end:
;   ; Context recovering
;   pop r16
;   out SREG, r16
;   pop XL
;   pop XH
;   pop r17
;   pop r16
;   reti

guard_loop:
  ; Prevent program from running into data area
  rjmp guard_loop
