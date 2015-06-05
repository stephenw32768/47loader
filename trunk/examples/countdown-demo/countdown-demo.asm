        ;; relocate the loader to this address
LOADER_ABSOLUTE_ADDR:equ 60000
        include "47loader_simple_basic_embed_top.asm"

;; do not abort the load if BREAK/SPACE is pressed
LOADER_IGNORE_BREAK:equ 1

        ;; need this for the countdown loader
LOADER_RESUME:  equ 1

        ;; place the countdown in the top right of the screen
LOADER_COUNTDOWN_COLUMN: equ 29
LOADER_COUNTDOWN_LINE: equ 1

        ;; need both entry points
LOADER_COUNTDOWN_ENTRY: equ 1
LOADER_COUNTDOWN_RESUME: equ 1

        ;; the screen is stored in two progressive chunks
        ;; that must be loaded separately, this is simply to
        ;; prove that a single countdown can be shared between
        ;; more than one load, in the Real World a screen would
        ;; not be loaded this way.  We will load the pixmap to
        ;; 49152, then load the attributes immediately
        ;; afterwards
        ld      ix,49152
        call    loader_countdown_entry ; pixmap
        ;; loader clears carry on error
        jr      nc,.err
        call    loader_countdown_resume ; attrs
        jr      nc,.err

        ;; black border; successful load clears accumulator
        out     (254),a

        ;; copy the screen
        ld      hl,49152
        ld      de,16384
        ld      bc,6912
        ldir

        ret
.err:
 include "47loader_error_handler.asm"
 include "47loader.asm"
 include "47loader_countdown.asm"
 include "47loader_simple_basic_embed_bottom.asm"
