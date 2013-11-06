        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        org     0

        ;; to BASIC, the jump forward looks like line 6147
        jr      .start          ; jump past REM statement
        dw      .end - 4        ; length of BASIC line
        db      0xea            ; BASIC REM keyword

        .dest:  equ     0xfb00

.start:
        ld      de,.dest
        push    bc
        pop     hl              ; entry address now in HL
        ld      bc,.reloc_start
        add     hl,bc
        ld      bc,.reloc_len
        ldir

        ;; load directly into screen
        ld      ix,0x4000
        ld      de,0x1b00

        ;; GO!
        call    loader_entry

        ;; if it returned carry set, all went well
        jr      nc,.err

        ;; black border to finish
        ;; (loader leaves zero in accumulator)
        out     (0xfe),a
        ret

.err:
        ;; if it returned zero set, BREAK was pressed
        jp      z,0x1b7b        ; ROM routine indicating BREAK (code L)
        ;; otherwise, there was a tape error
        rst     8               ; error restart
        defb    26              ; "R Tape loading error"

.reloc_start:   equ     $
        .phase  .dest

;LOADER_THEME_CANDY:equ 1
;LOADER_THEME_CYCLE_VERSA:equ 1
;LOADER_THEME_FIRE:equ 1
;LOADER_THEME_ICE:equ 1
;LOADER_THEME_LDBYTES:equ 1
;LOADER_THEME_LDBYTESPLUS:equ 1
;LOADER_THEME_JUBILEE:equ 1
;LOADER_THEME_ORIGINAL:equ 1
LOADER_THEME_RAINBOW:equ 1
;LOADER_THEME_RAINBOW_RIPPLE:equ 1
;LOADER_THEME_RAINBOW_VERSA:equ 1
;LOADER_THEME_SPAIN:     equ 1
;LOADER_THEME_SPEEDLOCK:equ 1
;LOADER_THEME_VERSA:equ 1
;LOADER_EXTRA_CYCLES:equ -2
        include "47loader.asm"
.reloc_len: equ $ - .dest

        .dephase
        db      13              ; BASIC line terminator
.end:   equ     $
