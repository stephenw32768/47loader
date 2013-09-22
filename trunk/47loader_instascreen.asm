        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; This macro loads a pixmap into the display file, attributes
        ;; into high memory, then LDIRs the attributes onto the screen
        ;; while reading edges.  The loader can then resume to load the
        ;; game with no pause; the effect is a Speedlock-style instant
        ;; loading screen.
        ;;
        ;; The macro arguments are:
        ;; 1/ an address in high memory to which to load the attributes;
        ;; 2/ the address to which to jump if loading fails.
        ;;
        ;; The macro assumes forwards loading.

        macro   loader_instascreen,addr,err

        if      addr < 32768
        .error  Load attributes into uncontended memory
        endif

        ;; load pixmap directly into screen
        ld      ix,0x4000
        ld      de,0x1800
        call    loader_entry
        ifndef  LOADER_DIE_ON_ERROR
        jr      nc,err          ; bail out on error
        endif
        ;; load attrs into high memory
        ld      ix,addr
        ld      de,768
        call    loader_resume
        ifndef  LOADER_DIE_ON_ERROR
        jr      nc,err
        endif

        ;; copy attributes to screen, reading an edge
        ;; every 32 bytes
        ld      d,0x58          ; DE=0x5800 b/c DE=0 after a load
        ld      hl,addr
.copy_loop:
        ld      bc,32
        ldir                    ; copy this block
        call    .read_edge      ; (this call corrupts A and B)
        ld      a,d             ; look at high byte of destination
        cp      0x5b            ; see if it's past the attributes
        jr      nz,.copy_loop   ; loop back if not

        endm
