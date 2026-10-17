.equ RAMEND, 0x08FF
.equ SPL, 0x3D
.equ SPH, 0x3E

.section .text
.global _start
.org 0x0000

    jmp _start          ; 0x0000 RESET

.org 0x0068
_start:
    ; Stack Pointer init
    ldi r16, lo8(RAMEND)
    out SPL, r16
    ldi r16, hi8(RAMEND)
    out SPH, r16
