        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; Simple progress meter.  Assumes forward loading.  Changes
        ;; screen attributes one at a time as chunks of data are loaded.
        ;;
        ;; Pass the address of the first attribute to change in DE
        ;; and the number of chunks to load in A.
        ;;
        ;; Define the following:
        ;;
        ;; LOADER_PROGRESSIVE_INITIAL:
        ;; if defined, this is the address of a routine to call to fetch
        ;; the length of the initial block.  Probably this will be
        ;; loader_entry.  If not defined, loader_resume is used.
        ;;
        ;; LOADER_PROGRESSIVE_VERTICAL:
        ;; if set, the progress meter goes downwards; if not set, left
        ;; to right.
        ;;
        ;; LOADER_PROGRESSIVE_ATTR_LOADING:
        ;; the attribute value to set while a chunk of data is loading.
        ;;
        ;; LOADER_PROGRESSIVE_ATTR_LOADED:
        ;; the attribute value to set after a chunk of data has loaded.

        ifdef   LOADER_TAP_FILE_COMPAT
        ;.error  Progressive loads cannot work in TAP files
        endif

loader_progressive:
        ;; set up the environment.  DE' will point to the address
        ;; to change next; B' will be the number of chunks remaining.
        ;; colour byte to be used next
        push    de              ; stack the address passed in DE
        exx                     ; swap in the alternate registers
        ex      de,hl           ; save HL' in DE'
        pop     hl              ; save the stacked address in HL'
        ld      b,a             ; save the number of chunks remaining in B'
        exx                     ; return to main registers

        ;; bootstrap the progressive load by reading two
        ;; bytes: the length of the first block to load
        ld      de,2
        ifdef   LOADER_PROGRESSIVE_INITIAL
        ;; if defined, call this routine to load the first block
        call    LOADER_PROGRESSIVE_INITIAL
        else
        call    loader_resume
        endif
        ifndef  LOADER_DIE_ON_ERROR
        jr      nc,.loader_progressive_out
        endif
        exx                     ; swap in the alternate registers
        jr      .loader_progressive_load_next_block

.loader_progressive_loop:
        call    loader_resume   ; load the block
.loader_progressive_block_loaded:
        ifndef  LOADER_DIE_ON_ERROR
        jr      nc,.loader_progressive_out
        endif
        exx                     ; swap in the alternate registers
        ld      (hl),LOADER_PROGRESSIVE_ATTR_LOADED ; set attr to mark loaded
        dec     b               ; decrement chunk counter
        jr      z,.loader_progressive_out ; if zero, we're done
        ifdef   LOADER_PROGRESSIVE_VERTICAL
        ;; advance attr to next line
        ld      a,32            ; 32 columns per line
        add     a,l             ; add to low byte
        ld      l,a
        jr      nc,.loader_progressive_load_next_block ; jump if not wrapped
        inc     h               ; low byte wrapped, so increment high byte
        else
        inc     hl              ; advance attr to next column
        endif

.loader_progressive_load_next_block:
        ld      (hl),LOADER_PROGRESSIVE_ATTR_LOADING ; set the attribute
        exx                     ; main registers back in
        ;; now, we need to load the next block
        ld      d,(ix-1)        ; get high byte of next block length
        ld      e,(ix-2)        ; and the low byte
        dec     ix              ; reposition IX before the block length
        dec     ix
        jr      .loader_progressive_loop ; loop back to load the block

.loader_progressive_out:
        ex      de,hl           ; restore DE'
        exx                     ; main registers back in
        ret