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

        if      LOADER_INSTASCREEN_ATTR_ADDRESS < 32768
        .error  Load attributes into uncontended memory
        endif
        ifdef   LOADER_TAP_FILE_COMPAT
        ;.error  Instascreen cannot work in TAP files
        endif

loader_instascreen:
        ;; clear border attributes
        ld      hl,0x5800
        ld      de,0x5b00 - 64
        ld      bc,64
        ldir

        ;; load pixmap directly into screen
        ld      ix,0x4000
        ld      d,0x18          ; DE=0x1800
        call    loader_entry
        ifndef  LOADER_DIE_ON_ERROR
        ret     nc              ; bail out on error
        endif
        ;; load attrs into high memory
        ld      ix,LOADER_INSTASCREEN_ATTR_ADDRESS
        ;ld      de,768
        ld      d,3             ; DE=0x300, 768
        call    loader_resume
        ifndef  LOADER_DIE_ON_ERROR
        ret     nc
        endif

        ;; copy attributes to screen, reading an edge
        ;; every 32 bytes
        ld      d,0x58          ; DE=0x5800 b/c DE=0 after a load
        ld      hl,LOADER_INSTASCREEN_ATTR_ADDRESS
.copy_loop:
        ld      bc,32
        ldir                    ; copy this block
        call    .read_edge      ; (this call corrupts A and B)
        ld      a,0x5a          ; when done, DE will be pointing at 0x5B00
        cp      d               ; compare D against 0x5A
        jr      nc,.copy_loop   ; loop if no overflow, i.e. D <= 0x5A
        ret                     ; return with carry set to indicate success
