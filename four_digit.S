; four_digit.S by ShiratoriYuuka314
; PB7:0 for segment select
; PD7:4 for digit select
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

.section .bss
seg_table: .space 10

.section .text
.global _start
.org 0x0000

  jmp _start ; 0x0000 RESET

.org 0x0068 ; Start of user code section
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

  rcall mem_init
  rjmp test_loop

mem_init:
  ; Load seg table from flash and store in sram
  ldi ZH, hi8(seg_table_flash)
  ldi ZL, lo8(seg_table_flash)
  ldi XH, hi8(seg_table)
  ldi XL, lo8(seg_table)

  ldi r17, 10
mem_init_loop:
  ; ldi r18, 0
  lpm r16, Z+
  st X+, r16
  dec r17
  ; cpse r17, r18
  ; rjmp mem_init_loop
  brne mem_init_loop
  ret

test_loop:
  ; Simple text showing '2026' by dynamic scanning
  rcall sel_digit_1
  lds r16, seg_table + 2
  out PORTB, r16
  rcall delay

  rcall sel_digit_2
  lds r16, seg_table + 0
  out PORTB, r16
  rcall delay

  rcall sel_digit_3
  lds r16, seg_table + 2
  out PORTB, r16
  rcall delay

  rcall sel_digit_4
  lds r16, seg_table + 6
  out PORTB, r16
  rcall delay

  rjmp test_loop

sel_digit_1:
  ldi r16, 0x00
  out PORTB, r16
  in r16, PORTD
  andi r16, 0x0F
  ori r16, 0x80
  out PORTD, r16
  ret

sel_digit_2:
  ldi r16, 0x00
  out PORTB, r16
  in r16, PORTD
  andi r16, 0x0F
  ori r16, 0x40
  out PORTD, r16
  ret

sel_digit_3:
  ldi r16, 0x00
  out PORTB, r16
  in r16, PORTD
  andi r16, 0x0F
  ori r16, 0x20
  out PORTD, r16
  ret

sel_digit_4:
  ldi r16, 0x00
  out PORTB, r16
  in r16, PORTD
  andi r16, 0x0F
  ori r16, 0x10
  out PORTD, r16
  ret

delay:
  ldi r16, 255
delay_loop:
  dec r16
  brne delay_loop
  ret

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
