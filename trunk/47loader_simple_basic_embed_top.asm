        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; Simple boilerplate for embedding the loader in
        ;; a REM statement.  Include this at the very top of your
        ;; code, and 47loader_simple_basic_embed_bottom.asm at the
        ;; very bottom.  Also, define the following:
        ;; 
        ;; LOADER_ABSOLUTE_ADDR: address at which to assemble the
        ;; loader proper

        ;; we don't know what address we will run from, so we will
        ;; assemble the code from zero and use arithmetic to
        ;; calculate the true address of the loaded code
        org     0

        ;; the first five bytes of our BASIC line are the line
        ;; number, the length of the line, and a REM keyword.
        ;; Our "line number" will be a JR instruction that jumps
        ;; over the length and REM keyword and into the code to
        ;; execute.  To BASIC, the assembled instruction looks like
        ;; line 6147; the 47 there is a happy coincidence :-)
        jr      .loader_embed_start
        dw      .loader_embed_end - 4
                          ; ^^^ length of the line; this is the length of
                          ; all the code, minus the line number and length
        db      0xea      ; BASIC REM keyword

.loader_embed_start
        ;; BASIC's USR instruction places the address at which
        ;; execution begins in BC, so we can use this to
        ;; calculate the location of the code that we have to
        ;; copy.  We assembled with origin 0, so .loader_embed_reloc_start
        ;; is the offset of the code to copy relative to our
        ;; entry point.  So by adding .loader_embed_reloc_start to the value
        ;; in BC, we have the absolute address of the code to
        ;; copy
        push    bc
        pop     hl      ; HL now contains the entry address
        ld      bc,.loader_embed_reloc_start
        add     hl,bc   ; HL now contains the address of the code to copy
        ld      de,LOADER_ABSOLUTE_ADDR
        push    de;     ; stack the target address for later
        ld      bc,.loader_embed_reloc_len
        ldir

        ;; the loader has now been copied to the address specified
        ;; in LOADER_ABSOLUTE_ADDR, and we also pushed a copy of it onto
        ;; the stack.  We can thus jump into the relocated loader
        ;; with a simple RET
        ret

.loader_embed_reloc_start: equ $
        ;; this is the beginning of the code we need to relocate.
        ;; Using the .PHASE directive, we can tell Pasmo to start
        ;; assembling using addresses relative to the address to
        ;; which we will copy it
        .phase    LOADER_ABSOLUTE_ADDR
