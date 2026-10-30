; vim: set filetype=asm:

; lcd1602.S by ShiratoriYuuka314
; For use on ATmega328P microcontroller
; PB7:0 as 8-pin parallel IO pins D7:0
; PD7:5 as RS, RW, E control pins
; Running on calibrated internal RC oscillator @ 8MHz
; This program is completely bare-metal and doesn't need to link standard start file

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
.equ PINB, 0x03
.equ DDRB, 0x04
.equ PORTB, 0x05
.equ PIND, 0x09
.equ DDRD, 0x0A
.equ PORTD, 0x0B

; Set pin definition
.equ RS, 7
.equ RW, 6
.equ E, 5

; Set string
.macro TEXT0
  .string "Hello world!"
.endm

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

  ldi r16, 0xE0 ; Set RS, RW, E to output
  out DDRD, r16

  rcall delay_long ; Enough delay to ensure lcd module ready
  rcall lcd_init

  ldi ZH, hi8(text0)
  ldi ZL, lo8(text0)
  rcall display_flash

main_loop:

  rjmp main_loop
;-------------------------------------------------------------------------------

lcd_init:
  ; Inits lcd module after startup delay
  ldi r16, 0xFF ; Set D7:0 to output
  out DDRB, r16

  ldi r16, 0x00 ; Set RS=0, RW=0, E=0
  out PORTD, r16

  ldi r24, 0x38 ; 8-bit mode, 2 lines, 5x8 font
  rcall lcd_write_cmd

  ldi r24, 0x0F ; Display on, cursor on, blink on
  rcall lcd_write_cmd

  ldi r24, 0x06 ; Cursor increment mode, display shift off
  rcall lcd_write_cmd

  ldi r24, 0x01 ; Clear screen
  rcall lcd_write_cmd
  ret

lcd_wait_busy:
  ; Polling busy flag until lcd not busy
  ldi r16, 0x00 ; Set D7:0 to input
  out DDRB, r16
  cbi PORTD, RS ; RS=0, RW=1 for busy flag read
  sbi PORTD, RW
lcd_wait_busy_loop:
  sbi PORTD, E
  nop
  nop
  nop
  nop ; Wait at least 450 ns, 4 nops are 500 ns @ 8MHz
  in r16, PINB
  cbi PORTD, E
  sbrc r16, 7 ; Check busy flag
  rjmp lcd_wait_busy_loop
  ldi r16, 0xFF ; Restore D7:0 to output
  out DDRB, r16
  ret

lcd_write_cmd:
  ; Load command to write to lcd module to r24 before calling
  rcall lcd_wait_busy
  cbi PORTD, RS ; RS=0, RW=0 for command write
  cbi PORTD, RW
  out PORTB, r24 ; Output data to wait until stable
  sbi PORTD, E
  nop
  nop
  nop
  nop ; Wait at least 450 ns, 4 nops are 500 ns @ 8MHz
  cbi PORTD, E ; Create a falling edge on E for lcd module to latch data
  ret

lcd_write_data:
  ; Load data to write to lcd module to r24 before calling
  rcall lcd_wait_busy
  sbi PORTD, RS ; RS=1, RW=0 for data write
  cbi PORTD, RW
  out PORTB, r24 ; Output data to wait until stable
  sbi PORTD, E
  nop
  nop
  nop
  nop ; Wait at least 450 ns, 4 nops are 500 ns @ 8MHz
  cbi PORTD, E ; Create a falling edge on E for lcd module to latch data
  ret

display_flash:
  ; Load text space address of text to display to Z before calling
display_flash_loop:
  lpm r24, Z+
  tst r24
  breq display_flash_end
  rcall lcd_write_data
  rjmp display_flash_loop
display_flash_end:
  ret

delay_long:
  ; Simple delay subroutine of ~195,844 cycles or 24.48 ms @ 8MHz
  ldi r16, 255
delay_long_outer:
  ldi r17, 255
delay_long_inner:
  dec r17
  brne delay_long_inner
  dec r16
  brne delay_long_outer
  ret

guard_loop:
  ; Prevent program from running into data area
  rjmp guard_loop

; Flash data area
text0:
  TEXT0
