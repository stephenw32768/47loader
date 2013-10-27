        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; This routine loads a pixmap into the display file, attributes
        ;; into high memory, then LDIRs the attributes onto the screen
        ;; while reading edges.  The loader can then resume to load the
        ;; game with no pause; the effect is a Speedlock-style instant
        ;; loading screen.
        ;;
        ;; The routine assumes forwards loading.
        ;;
        ;; Define:
        ;; 
        ;; LOADER_INSTASCREEN_ATTR_ADDRESS:
        ;; address in uncontended memory to which to load the attrs
        ;;
        ;; LOADER_INSTASCREEN_FILL_COLOUR:
        ;; 0-7, number of colour with which to fill the screen.  If
        ;; not defined, defaults to 0.
        ;;
        ;; LOADER_INSTASCREEN_FILL_BRIGHT:
        ;; if set, the colour specified by LOADER_INSTASCREEN_FILL_COLOUR
        ;; is made bright.

        if      LOADER_INSTASCREEN_ATTR_ADDRESS < 32768
        .error  Load attributes into uncontended memory
        endif

        ifdef   LOADER_INSTASCREEN_FILL_COLOUR
        if      LOADER_INSTASCREEN_FILL_COLOUR % 8 != 0
        ;; fill colour is not black; set paper and ink colour
        ;; to be the same
.instascreen_colour:defl LOADER_INSTASCREEN_FILL_COLOUR % 8
.instascreen_colour:defl .instascreen_colour | (.instascreen_colour << 3)
        ifdef LOADER_INSTASCREEN_FILL_BRIGHT
.instascreen_colour:defl .instascreen_colour | 64
        endif
        endif
        endif

loader_instascreen:
        ;; clear attributes
        ld      hl,0x5800               ; address of first attr
        ifdef   .instascreen_colour
        ld      (hl),.instascreen_colour; attr to fill screen
        else
        ld      (hl),l                  ; L = 0; fill screen with black
        endif
        ld      de,0x5801
        ld      bc,767
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
