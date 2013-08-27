        org     0

        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

.dest:  equ     0xfb00

        ;; relocate loader
        ld      de,.dest
        push    bc
        pop     hl              ; entry address now in HL
        ld      bc,.reloc_start
        add     hl,bc
        ld      bc,.reloc_len
        ldir

        ;; the run-length decoder and compressed screen are
        ;; loaded together
.rldecoder:equ  0xe000
.rldecoder_len:equ 22
.screen_len:equ 2978
        ld      ix,.rldecoder
        ld      de,.rldecoder_len + .screen_len

        ;; load the decoder and screen
        call    loader_entry

        ;; if it returned carry set, all went well
        jr      nc,.err

        ;; turn border black
        ;; (loader leaves zero in accumulator)
        out     (0xfe),a

        ;; decode the screen directly into video RAM
        ld      de,0x4000
        ld      hl,.rldecoder + .rldecoder_len ; decoder comes before screen
        ld      bc,.screen_len
        jp      .rldecoder      ; will return to BASIC after decoding

.err:
        ;; if it returned zero set, BREAK was pressed
        jp      z,0x1b7b        ; ROM routine indicating BREAK (code L)
        ;; otherwise, there was a tape error
        rst     8               ; error restart
        defb    26              ; "R Tape loading error"

.reloc_start:   equ     $
        .phase  .dest

LOADER_TWO_EDGE_SYNC:   equ 1
LOADER_THEME_JUBILEE:equ 1
        include "47loader.asm"
.reloc_len: equ $ - .dest
