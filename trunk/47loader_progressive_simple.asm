        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; Simple progressive load.  Assumes forward loading.
        ;; Changes a single attribute byte gradually as chunks
        ;; of data are loaded.
        ;;
        ;; Define the following:
        ;;
        ;; LOADER_PROGRESSIVE_INITIAL:
        ;; if defined, this is the address of a routine to call to fetch
        ;; the length of the initial block.  Probably this will be
        ;; loader_entry.  If not defined, loader_resume is used.
        ;;
        ;; LOADER_PROGRESSIVE_ATTR_ADDRESS:
        ;; the address of the attribute byte to change as the
        ;; progressive chunks are loaded.

        ifdef   LOADER_TAP_FILE_COMPAT
        ;.error  Progressive loads cannot work in TAP files
        endif

loader_progressive:
        ;; set up the environment.  DE' will point to the
        ;; colour byte to be used next
        exx                     ; swap in the alternate registers
        ld      de,.loader_progressive_colours - 1
        exx                     ; return to main registers

        ;; bootstrap the progressive load by reading two
        ;; bytes: the length of the first block to load
        ld      de,2
        ifdef   LOADER_PROGRESSIVE_INITIAL
        ;; if defined, call this routine to load the first block,
        ;; then jump into the loop at the appropriate place
        call    LOADER_PROGRESSIVE_INITIAL
        jr      .loader_progressive_block_loaded
        endif

.loader_progressive_loop:
        call    loader_resume   ; load the block
.loader_progressive_block_loaded:
        ifndef  LOADER_DIE_ON_ERROR
        ret     nc              ; bail out if the load failed
        endif
        exx                     ; swap in the alternate registers
        inc     de              ; advance the pointer to the next colour
        ld      a,(de)          ; put the colour into the accumulator
        exx                     ; swap back to the main registers
        and     a               ; look at the colour number
        scf                     ; indicate successful load
        ret     z               ; if "colour" is zero, we're done
        ld      (LOADER_PROGRESSIVE_ATTR_ADDRESS),a ; change the colour

        ;; now, we need to load the next block
        ld      d,(ix-1)        ; get high byte of next block length
        ld      e,(ix-2)        ; and the low byte
        dec     ix              ; reposition IX before the block length
        dec     ix
        jr      .loader_progressive_loop ; loop back to load the block

.loader_progressive_colours:
        defb    %10000001       ; blue
        defb    %11000001       ; bright blue
        defb    %10000010       ; red
        defb    %11000010       ; bright red
        defb    %10000011       ; magenta
        defb    %11000011       ; bright magenta
        defb    %10000100       ; green
        defb    %11000100       ; bright green
        defb    %10000101       ; cyan
        defb    %11000101       ; bright cyan
        defb    %10000110       ; yellow
        defb    %11000110       ; bright yellow
        defb    %10000111       ; white
        defb    %11000111       ; bright white
        defb    0
