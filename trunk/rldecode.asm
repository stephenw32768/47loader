        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; simple run length decoder
        
        ;; source in DE
        ;; destination in HL
        ;; compressed length in BC

rldecode:
        ;; copy first byte
        ld      a,(de)
        ld      (hl),a
.rldecode_loop:
        dec     bc              ; decrement counter
        ld      a,b             ; exit if zero
        or      c
        ret     z
        inc     de              ; advance source pointer
        ld      a,(de)          ; read next byte
        cp      (hl)            ; check whether same as previous byte
        inc     hl              ; advance destination pointer
        ld      (hl),a          ; copy byte
        jr      nz,.rldecode_loop; loop if this byte was different to previous
        dec     bc              ; decrement counter
        inc     de              ; advance source pointer
        ld      a,(de)          ; read run length
        and     a               ; check whether run length is zero
        jr      z,.rldecode_loop; loop if so
        push    bc              ; save byte counter
        ld      b,a             ; place run length in B
        ld      a,(hl)          ; place run byte in accumulator
.rldecode_run:
        inc     hl              ; advance destination pointer
        ld      (hl),a          ; copy byte
        djnz    .rldecode_run   ; loop until run is complete
        pop     bc              ; restore byte counter
        jr      .rldecode_loop  ; continue with main loop
