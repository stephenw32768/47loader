        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; this is the end of the code we want to relocate from the
        ;; REM statement into uncontended memory.  We're still
        ;; assembling relative to LOADER_ABSOLUTE_ADDR, so subtracting the
        ;; current address from LOADER_ABSOLUTE_ADDR  gives us the number
        ;; of bytes to copy
.loader_embed_reloc_len: equ $ - LOADER_ABSOLUTE_ADDR

        ;; from this point, we want to stop assembling relative to
        ;; LOADER_ABSOLUTE_ADDR and revert to assembling relative to zero.
        ;; The .DEPHASE directive tells Pasmo to do this
        .dephase

        ;; this is the last byte of our line of BASIC.  It's a carriage
        ;; return; all BASIC lines end with one of these
        db      13
        ;; we're assembling relative to zero, so this symbol both marks
        ;; the end of the code and also tells us its total length
.loader_embed_end:   equ     $
