        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; simple run length decoder
        
        ;; source in HL
        ;; destination in DE
        ;; compressed length in BC

rldecode:
        ld      a,RLE_SENTINEL  ; load accumulator with sentinel value
.rldecode_loop:
        cp      (hl)            ; compare against current byte
        jr      z,.rldecode_run ; jump forward if they match
        ldi                     ; no match, so just copy byte
        ret     po              ; return if BC is now 0
        jr      .rldecode_loop  ; continue with main loop
.rldecode_run:
        inc     hl              ; advance source pointer (past sentinel)
        dec     bc              ; decrement byte counter (past sentinel)
        ld      a,(hl)          ; read byte to copy
        ldi                     ; make one copy
        push    bc              ; save byte counter
        ld      b,(hl)          ; read run length
.rldecode_run_loop:
        ld      (de),a          ; copy byte
        inc     de              ; advance destination pointer
        djnz    .rldecode_run_loop; loop until run is complete
        pop     bc              ; restore byte counter
        cpi                     ; advance source pointer and decrement byte
                                ; counter (past run length)
        ret     po              ; return if BC is now 0
        jr      rldecode        ; reload sentinel and continue with main loop
