; vim: set filetype=asm:

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
.equ SREG, 0x3F
.equ DDRD, 0x0A ; 1:0 -> TX, RX
; Set SFR Data addr
.equ UCSR0A, 0xC0 ; 7:0 -> RXC0, TXC0, UDRE0, FE0, DOR0, UPE0, U2X0, MPCM0
.equ UCSR0B, 0xC1 ; 7:0 -> RXCIE0, TXCIE0, UDRIE0, RXEN0, TXEN0, UCSZ02, RXB80, TXB80
.equ UCSR0C, 0xC2 ; 7:0 -> UMSEL01, UMSEL00, UPM01, UPM00, USBS0, UCSZ01, UCSZ00, UCPOL0
.equ UBRR0L, 0xC4
.equ UBRR0H, 0xC5
.equ UDR0, 0xC6
.equ OSCCAL, 0x66

; Set baudrate to 1M @ 8MHz clock, UART double speed mode enabled
; Calibration for internal calibrated RC oscillator varies on different chips
.equ BAUDSET, 0
.equ CALIBRATION, 0xC0 ; Default value of my chip is 0xC5, calibrated to error margin < ±1%
; Set tx ring buffer size, must be power of 2, max 256
.equ TXBUFSIZE, 32
.equ TXBUFMASK, TXBUFSIZE - 1

.equ STARTNUM, 0
.equ TOTALROUNDS, 100
.equ STRBUFSIZE, 64

.equ DATAWIDTH, 16

; Set string and its size
.macro HELLOWORLD
  .string "Hello world!\r\n"
.endm
.equ HELLOWORLDSIZE, 15

.macro TEXT1
  .string "\r\nStarting benchmark...\r\n\r\n"
.endm
.equ TEXT1SIZE, 28

.section .bss
tx_buf: .space TXBUFSIZE
tx_buf_head: .space 1
tx_buf_tail: .space 1

str_buf: .space STRBUFSIZE
str_buf_len: .space 1

num: .space DATAWIDTH / 8
cur: .space DATAWIDTH / 8
i: .space DATAWIDTH / 8
result: .space DATAWIDTH / 8

.section .text
.global _start
.org 0x0000

  rjmp _start ; RESET

.org 0x004C

  rjmp _usart_udre_isr ; USART_UDRE

.org 0x0068 ; Start of user code section
;-------------------------------------------------------------------------------
_start:
  ; Stack Pointer init
  ldi r16, lo8(RAMEND) ; 0xFF
  out SPL, r16
  ldi r16, hi8(RAMEND) ; 0x08
  out SPH, r16

  rcall osc_cal
  rcall str_buf_len_init
  rcall uart_init
  sei ; Enable global interrupt

main_loop:
  rcall wait_for_start

  ldi ZH, hi8(hello_world)
  ldi ZL, lo8(hello_world)
  ldi r24, HELLOWORLDSIZE
  rcall transmit_enqueue_flash

  ldi ZH, hi8(text1)
  ldi ZL, lo8(text1)
  ldi r24, TEXT1SIZE
  rcall transmit_enqueue_flash

  ldi r25, hi8(12345)
  ldi r24, lo8(12345)
  rcall double_dabble_16
  rcall str_eol

  ldi XH, hi8(str_buf)
  ldi XL, lo8(str_buf)
  lds r24, str_buf_len
  rcall transmit_enqueue

  rjmp main_loop
;-------------------------------------------------------------------------------

osc_cal:
  ; Load new internal RC oscillator calibration value
  ldi r16, CALIBRATION
  sts OSCCAL, r16
  ret

str_buf_len_init:
  ; Init str_buf_len to 0
  clr r16
  sts str_buf_len, r16
  ret

str_eol:
  ; Add CPLD and \0 to str_buf
  ldi r16, '\r'
  rcall add_byte
  ldi r16, '\n'
  rcall add_byte
  ldi r16, 0
  rcall add_byte
  ret

uart_init:
  ; Set baudrate
  ldi r16, hi8(BAUDSET)
  ldi r17, lo8(BAUDSET)
  sts UBRR0H, r16
  sts UBRR0L, r17
  ; Enable double transmission speed
  lds r16, UCSR0A
  ori r16, 1 << 1 ; U2X0
  sts UCSR0A, r16
  ; Keep all other UART options default
  ; Init tx buffer head and tail index to 0
  ldi r16, 0
  sts tx_buf_head, r16
  sts tx_buf_tail, r16
  ; Set TX pin to output
  sbi DDRD, 1 ; TX(PD1)
  ; Enable receiver and transmitter
  ldi r16, (1 << 4 | 1 << 3) ; RXEN0, TXEN0
  sts UCSR0B, r16
  ret

delay:
  ; Simple delay subroutine of 255 rounds, ~770 clk cycles or ~96 us @ 8MHz
  ldi r16, 255
delay_loop:
  dec r16
  brne delay_loop
  ret

double_dabble_16:
  ; Load input value to r25:r24 as 16-bit binary
  ; Return output value at r20:r19:r18 as 5-digit bcd
  ; Internally calls add_bcd_to_string_16
  ; Clobbers are r21 and r16
  clr r20
  clr r19
  clr r18
  ldi r21, 16 ; Number of iterations
double_dabble_loop:
  ; Add 3 to each bcd digit if ≥ 5
  mov r16, r20
  andi r16, 0x0F
  cpi r16, 5
  brlo dd_skip_digit_1
  subi r20, -3 ; + 3
dd_skip_digit_1:
  mov r16, r19
  andi r16, 0xF0
  cpi r16, 0x50
  brlo dd_skip_digit_2
  subi r19, -0x30 ; + 3
dd_skip_digit_2:
  mov r16, r19
  andi r16, 0x0F
  cpi r16, 5
  brlo dd_skip_digit_3
  subi r19, -3 ; + 3
dd_skip_digit_3:
  mov r16, r18
  andi r16, 0xF0
  cpi r16, 0x50
  brlo dd_skip_digit_4
  subi r18, -0x30 ; + 3
dd_skip_digit_4:
  mov r16, r18
  andi r16, 0x0F
  cpi r16, 5
  brlo dd_skip_digit_5
  subi r18, -3 ; + 3
dd_skip_digit_5:
  ; Shift binary data left into bcd by 1-bit
  lsl r24
  rol r25
  rol r18
  rol r19
  rol r20
  ; Count iterations
  dec r21
  brne double_dabble_loop
  rcall add_bcd_to_string_16
  ret

add_bcd_to_string_16:
  ; Ignores leading zeros of bcd
  ; Load input value to r20:r19:r18 as 5-digit bcd
  ; Internally calls add_digit
  ; Clobbers are r23 and r16
  clr r23 ; Started indicator
  mov r16, r20
  ; andi r16, 0x0F
  rcall add_digit
  mov r16, r19
  swap r16
  andi r16, 0x0F
  rcall add_digit
  mov r16, r19
  andi r16, 0x0F
  rcall add_digit
  mov r16, r18
  swap r16
  andi r16, 0x0F
  rcall add_digit
  mov r16, r18
  andi r16, 0x0F
  rcall add_digit
  ret

add_digit:
  ; Load input value to r16 as one bcd digit, started indicator to r23
  ; Internally calls add_byte
  tst r23 ; Check if started
  brne add_digit_emit ; Output whatever the digit is if started
  tst r16 ; Check if zero
  breq add_digit_skip ; Skip leading zero
  ldi r23, 1 ; Set started indicator if not zero
add_digit_emit:
  subi r16, -'0' ; + '0'
  rcall add_byte
add_digit_skip:
  ret

add_byte:
  ; Load input value to r16 as byte to add to str_buf
  ; Clobbers are X registers(r27:r26)
  lds r17, str_buf_len
  cpi r17, 255
  breq add_byte_skip ; Skip if str_buf full
  ldi XH, hi8(str_buf)
  ldi XL, lo8(str_buf)
  add XL, r17
  clr r1
  adc XH, r1
  st X, r16
  inc r17
  sts str_buf_len, r17
add_byte_skip:
  ret

wait_for_start:
  ; Wait until enter is pressed in serial shell on PC
  lds r16, UCSR0A
  sbrs r16, 7 ; RXC0
  rjmp wait_for_start
  lds r16, UDR0
  cpi r16, '\r'
  brne wait_for_start
  ret

transmit_enqueue_flash:
  ; Load text space address of data to enqueue to Z and length to r24 before calling
  tst r24
  breq transmit_enqueue_flash_end
transmit_enqueue_flash_loop:
  lpm r22, Z+
  rcall transmit_fillbyte
  dec r24
  brne transmit_enqueue_flash_loop
transmit_enqueue_flash_end:
  ret

transmit_enqueue:
  ; Load data space address of data to enqueue to X and length to r24 before calling
  tst r24
  breq transmit_enqueue_end
transmit_enqueue_loop:
  ld r22, X+
  rcall transmit_fillbyte
  dec r24
  brne transmit_enqueue_loop
transmit_enqueue_end:
  sts str_buf_len, r24
  ret

transmit_fillbyte:
  ; Load byte to fill into tx_buf to r22 before calling
  ; Don't change r22 and r24
  ldi YH, hi8(tx_buf)
  ldi YL, lo8(tx_buf)
  lds r16, tx_buf_head
  inc r16
  andi r16, TXBUFMASK ; Loopback when overflow
  lds r17, tx_buf_tail
  cp r16, r17
  breq transmit_fillbyte_full ; Stop and wait if buffer full, ensure interrupt is on!
  lds r16, tx_buf_head
  mov r18, r16 ; Save a copy of head index
  add YL, r16
  ldi r16, 0
  adc YH, r16
  st Y, r22 ; Load byte to ring buffer
  inc r18 ; Increase head index by 1
  andi r18, TXBUFMASK ; Loopback when overflow
  sts tx_buf_head, r18 ; Update new head index value
  lds r16, UCSR0B
  sbr r16, 1 << 5 ; UDRIE0
  sts UCSR0B, r16 ; Set UDRIE0 to ensure interrupt enabled
  ret
transmit_fillbyte_full:
  rjmp transmit_fillbyte
  ret


_usart_udre_isr:
  ; Keep transmitting the next byte, or disabling USART_UDRE interrupt
  ; Context saving
  push r16
  push r17
  push XH
  push XL
  in r16, SREG
  push r16

  lds r16, tx_buf_head
  lds r17, tx_buf_tail
  cp r16, r17
  brne keep_transmit ; Check if head index is as same as tail index, which means buffer empty
  ; Clear UDRIE0 if tx_buf is empty
  lds r16, UCSR0B
  cbr r16, 1 << 5 ; UDRIE0
  sts UCSR0B, r16
  rjmp usart_udre_end
keep_transmit:
  ldi r16, 0
  ldi XH, hi8(tx_buf)
  ldi XL, lo8(tx_buf)
  add XL, r17
  adc XH, r16
  ld r16, X
  sts UDR0, r16 ; Load byte to UDR0 to be sent
  inc r17
  andi r17, TXBUFMASK ; Loopback when overflow
  sts tx_buf_tail, r17 ; Update new tail index value
usart_udre_end:
  ; Context recovering
  pop r16
  out SREG, r16
  pop XL
  pop XH
  pop r17
  pop r16
  reti

guard_loop:
  ; Prevent program from running into data area.
  rjmp guard_loop

hello_world:
  HELLOWORLD

text1:
  TEXT1
