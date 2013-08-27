        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; simple run length decoder
        
        ;; source in HL
        ;; destination in DE
        ;; compressed length in BC

rldecode:
.rldecode_loop:
        ld      a,(hl)          ; read this byte
        ldi                     ; copy one byte
        ret     po              ; return if BC is now 0
        cp      (hl)            ; compare this byte against previous
        jr      nz,.rldecode_loop; loop if different
        dec     bc              ; decrement byte counter (past byte)
        push    bc              ; save byte counter
        inc     hl              ; advance source pointer to run length
        ld      b,(hl)          ; read run length
        inc     b               ; do one more copy (we didn't copy the byte
                                ; when we saw it was the same as previous)
.rldecode_run:
        ld      (de),a          ; copy byte
        inc     de              ; advance destination pointer
        djnz    .rldecode_run   ; loop until run is complete
        pop     bc              ; restore byte counter
        cpi                     ; advance source pointer and decrement byte
                                ; counter (past run length)
        ret     po              ; return if BC is now 0
        jr      .rldecode_loop  ; continue with main loop
