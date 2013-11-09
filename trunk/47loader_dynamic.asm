        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; "Dynamic" loader.  Loads a table of addresses and data
        ;; lengths, then loads the blocks at the specified addresses.
        ;;
        ;; The table consists of the 16-bit address in big-endian
        ;; format, followed by the 16-bit data length in big-endian
        ;; format.  Only bits 0-14 of the length entry define the
        ;; length; bit 15 is a flag indicating whether to change the
        ;; load direction before loading the block.
        ;;
        ;; On initial entry to loader_dynamic, forward loading is
        ;; assumed.
        ;;
        ;; Define the following:
        ;;
        ;; LOADER_DYNAMIC_TABLE_ADDR:
        ;; the address at which to load the table.
        ;;
        ;; LOADER_DYNAMIC_INITIAL:
        ;; if defined, this is the address of a routine to call to fetch
        ;; the length of the table.  If not defined, loader_entry is used.
        ;;
        ;; LOADER_DYNAMIC_FORWARDS_ONLY:
        ;; if defined, direction changes are disabled; define this to
        ;; save a few bytes if all the dynamic loads are forwards.
        ;;
        ;; LOADER_DYNAMIC_ONE_BYTE_LENGTHS:
        ;; if defined, the table uses only a single byte to store each
        ;; length and direction change flag.  All dynamic blocks are
        ;; thus no larger than 127 bytes.
        
loader_dynamic:

        ;; bootstrap the progressive load by reading two
        ;; bytes: the length of the table
        ld      ix,LOADER_DYNAMIC_TABLE_ADDR
        ld      de,2
        ifdef   LOADER_DYNAMIC_INITIAL
        ;; if defined, call this routine to load the first block
        call    LOADER_DYNAMIC_INITIAL
        else
        call    loader_entry
        endif
        ifndef  LOADER_DIE_ON_ERROR
        ret     nc
        endif

        ;; that loaded two bytes, the length of the table, which
        ;; will be the next block to load
        ld      de,(LOADER_DYNAMIC_TABLE_ADDR) ; get table length

        ;; load the table
        ld      ix,LOADER_DYNAMIC_TABLE_ADDR
        call    loader_resume
        ifndef  LOADER_DIE_ON_ERROR
        ret     nc
        endif

        ;; disable the border once the screen starts loading
        ifdef   LOADER_TOGGLE_BORDER
        call    loader_disable_border
        endif

        ;; enter the main loop with the table address in HL
        ld      hl,LOADER_DYNAMIC_TABLE_ADDR
.loader_dynamic_loop:
        ;; HL is pointing at the next table entry
        ld      a,(hl)          ; look at the byte
        and     a               ; see if it's zero
        scf                     ; signal successful load
        ret     z               ; if A is zero, we're done
        ;; if still here, A is not zero, and HL is
        ;; pointing at the address to load in big-endian
        ;; format
        ld      ixh,a           ; high byte of address into IX
        inc     hl              ; advance table pointer
        ld      a,(hl)          ; low byte of address into accumulator
        ld      ixl,a           ; and into IX
        inc     hl              ; advance pointer


        ;; next, we read the length of the data to load, again
        ;; in big-endian format
        ifndef  LOADER_DYNAMIC_ONE_BYTE_LENGTHS
        ld      d,(hl)          ; high byte of length into DE
        inc     hl              ; advance table pointer
        endif
        ld      e,(hl)          ; low byte of length into DE
        inc     hl              ; advance table pointer
        push    hl              ; stack the table pointer

        ifndef  LOADER_DYNAMIC_FORWARDS_ONLY
        ;; if bit 15 of the length is set (or bit 7 for one-byte
        ;; lengths), we need to change direction
        ifndef  LOADER_DYNAMIC_ONE_BYTE_LENGTHS
        bit     7,d             ; test the flag bit
        res     7,d             ; clear the flag bit
        else
        bit     7,e             ; test the flag bit
        res     7,e             ; clear the flag bit
        endif
        call    nz,loader_change_direction ; change direction if flag set
        endif

        ;; with IX and DE set up, we can load the block
        call    loader_resume   ; load the block
        pop     hl              ; restore the table pointer
        jr      c,.loader_dynamic_loop ; loop if load was successful
        ;; if still here, the load failed
        ifndef  LOADER_DIE_ON_ERROR
        ret
        endif
