        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

LOADER_ABSOLUTE_ADDR:equ 32768
LOADER_THEME_RAINBOW:equ 1
LOADER_DYNAMIC_TABLE_ADDR:equ 49152
LOADER_RESUME:equ 1
LOADER_CHANGE_DIRECTION:equ 1
        include "47loader_simple_basic_embed_top.asm"

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
