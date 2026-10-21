; vim: set filetype=asm:

; four_digit.S by ShiratoriYuuka314
; For use on ATmega328P microcontroller
; Using 3641AS common-cathode 4-digit 7-seg display driven by S8050 BJT
; PB7:0 for segment select a,b,c,d,e,f,g,dp
; PD7:4 for digit select 1,2,3,4
; Running on calibrated internal RC oscillator @ 8MHz
; This program is completely bare-metal and doesn't need to link standard start file

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
.equ DDRB, 0x04
.equ DDRD, 0x0A
.equ PORTB, 0x05
.equ PORTD, 0x0B
; Set static text to show on 7-seg, 4-digit number only
.macro TEXT
  .ascii "0721"
.endm

.section .bss
seg_table: .space 10
static_text: .space 4
bcd: .space 4

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

  in r16, DDRD ; Set digit sel PD7:4 to output
  ori r16, 0xF0
  out DDRD, r16

  ldi r16, 0xFF ; Set seg sel PB7:0 to output
  out DDRB, r16

  rcall seg_table_init ; Load seg_table into sram
  rcall static_text_init ; Load text_to_show into sram
  rcall bcd_init ; Init bcd data to all zero in sram

  rjmp show_static_loop
;-------------------------------------------------------------------------------

seg_table_init:
  ; Load seg table from flash and store in sram
  ldi ZH, hi8(seg_table_flash)
  ldi ZL, lo8(seg_table_flash)
  ldi XH, hi8(seg_table)
  ldi XL, lo8(seg_table)
  ldi r17, 10
seg_table_init_loop:
  lpm r16, Z+
  st X+, r16
  dec r17
  brne seg_table_init_loop
  ret

static_text_init:
  ; Load static text to show from flash and store in sram
  ldi ZH, hi8(static_text_flash)
  ldi ZL, lo8(static_text_flash)
  ldi XH, hi8(static_text)
  ldi XL, lo8(static_text)
  ldi r17, 4
static_text_init_loop:
  lpm r16, Z+
  st X+, r16
  dec r17
  brne static_text_init_loop
  ret

bcd_init:
  ; Init bcd data in sram to all 0(0x00)
  ldi r16, 0
  sts bcd + 0, r16
  sts bcd + 1, r16
  sts bcd + 2, r16
  sts bcd + 3, r16
  ret

show_static_loop:
  ; Simple text showing by dynamic scanning
  rcall sel_digit_1
  ldi XH, hi8(static_text)
  ldi XL, lo8(static_text)
  ld r16, X
  subi r16, 0x30 ; Convert from ascii code to raw number
  ldi XH, hi8(seg_table)
  ldi XL, lo8(seg_table)
  add XL, r16
  clr r0
  adc XH, r0
  ld r16, X
  out PORTB, r16
  rcall delay

  rcall sel_digit_2
  ldi XH, hi8(static_text)
  ldi XL, lo8(static_text + 1)
  ld r16, X
  subi r16, 0x30 ; Convert from ascii code to raw number
  ldi XH, hi8(seg_table)
  ldi XL, lo8(seg_table)
  add XL, r16
  clr r0
  adc XH, r0
  ld r16, X
  out PORTB, r16
  rcall delay

  rcall sel_digit_3
  ldi XH, hi8(static_text)
  ldi XL, lo8(static_text + 2)
  ld r16, X
  subi r16, 0x30 ; Convert from ascii code to raw number
  ldi XH, hi8(seg_table)
  ldi XL, lo8(seg_table)
  add XL, r16
  clr r0
  adc XH, r0
  ld r16, X
  out PORTB, r16
  rcall delay

  rcall sel_digit_4
  ldi XH, hi8(static_text)
  ldi XL, lo8(static_text + 3)
  ld r16, X
  subi r16, 0x30 ; Convert from ascii code to raw number
  ldi XH, hi8(seg_table)
  ldi XL, lo8(seg_table)
  add XL, r16
  clr r0
  adc XH, r0
  ld r16, X
  out PORTB, r16
  rcall delay

  rjmp show_static_loop

sel_digit_1:
  ; Change digit sel to digit 1
  ldi r16, 0x00
  out PORTB, r16 ; Blanking between digits
  in r16, PORTD
  andi r16, 0x0F
  ori r16, 0x80
  out PORTD, r16
  ret

sel_digit_2:
  ; Change digit sel to digit 2
  ldi r16, 0x00
  out PORTB, r16 ; Blanking between digits
  in r16, PORTD
  andi r16, 0x0F
  ori r16, 0x40
  out PORTD, r16
  ret

sel_digit_3:
  ; Change digit sel to digit 3
  ldi r16, 0x00
  out PORTB, r16 ; Blanking between digits
  in r16, PORTD
  andi r16, 0x0F
  ori r16, 0x20
  out PORTD, r16
  ret

sel_digit_4:
  ; Change digit sel to digit 4
  ldi r16, 0x00
  out PORTB, r16 ; Blanking between digits
  in r16, PORTD
  andi r16, 0x0F
  ori r16, 0x10
  out PORTD, r16
  ret

delay:
  ldi r16, 255 ; Simple delay subroutine of 255 rounds, ~770 clk cycles or ~96 us @ 8MHz
delay_loop:
  dec r16
  brne delay_loop
  ret

guard_loop:
  rjmp guard_loop ; Prevent program from running into data table by accident

seg_table_flash:
  .byte 0xFC ; 0
  .byte 0x60 ; 1
  .byte 0xDA ; 2
  .byte 0xF2 ; 3
  .byte 0x66 ; 4
  .byte 0xB6 ; 5
  .byte 0xBE ; 6
  .byte 0xE0 ; 7
  .byte 0xFE ; 8
  .byte 0xF6 ; 9

static_text_flash:
  TEXT
