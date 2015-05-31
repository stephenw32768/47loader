        ;; 47loader (c) Stephen Williams 2013-2015
        ;; See LICENSE for distribution terms

LOADER_ABSOLUTE_ADDR:equ 32768
LOADER_THEME_RAINBOW:equ 1
LOADER_DYNAMIC_TABLE_ADDR:equ 49152
LOADER_RESUME:equ 1
LOADER_DYNAMIC_FORWARDS_ONLY:   equ 1
;LOADER_TOGGLE_BORDER:   equ 1
        include "47loader_simple_basic_embed_top.asm"

        ;; black screen
        ld      hl,16384
        ld      (hl),0
        ld      de,16385
        ld      bc,6911
        ldir

        ;; nothing to do besides call loader_dynamic
        call    loader_dynamic
        ;; if it returned carry set, the load succeeded
        jr      nc,.err

        ;; black border to finish
        ;; (loader leaves zero in accumulator)
        out     (0xfe),a
        ret

.err:
        include "47loader_error_handler.asm"
        include "47loader.asm"
        include "47loader_dynamic.asm"
        include "47loader_simple_basic_embed_bottom.asm"
