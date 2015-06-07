        ;; 47loader (c) Stephen Williams 2015
        ;; See LICENSE for distribution terms

        ;; Progressive load with countdown.  Assumes forward
        ;; loading.  Loads chunks of data, decrementing and
        ;; displaying a countdown as blocks are loaded.
        ;;
        ;; Define the following:
        ;;
        ;; LOADER_COUNTDOWN_COLUMN:
        ;; the index of the column in which the left-hand digit is
        ;; printed.  Must be between 0 and 30.
        ;; 
        ;; LOADER_COUNTDOWN_LINE:
        ;; the index of the line on which the countdown is printed.
        ;; Must be between 0 and 23.
        ;;
        ;; LOADER_COUNTDOWN_ENTRY:
        ;; define this if you need the loader_countdown_entry entry
        ;; point that starts a countdown load using loader_entry
        ;; (i.e. the block has a pilot tone).
        ;;
        ;; LOADER_COUNTDOWN_RESUME:
        ;; define this if you need the loader_countdown_resume entry
        ;; point that starts a countdown load using loader_resume
        ;; (i.e. the block is glued to the previous block).
        ;;
        ;; LOADER_COUNTDOWN_CHARSET_ADDRESS:
        ;; if defined, the address of the character set to use for the
        ;; countdown.  This must be the address of the first byte of
        ;; the "0" character; the bytes for all the characters from "0"
        ;; to "9" then follow linearly, 80 bytes in total.  If not
        ;; defined, the ROM character set is used.
        ;; 
        ;; LOADER_COUNTDOWN_INVERSE_VIDEO:
        ;; if defined, the ink and paper colours of the countdown
        ;; digits are swapped.  Define this if the background colour of
        ;; the part of the screen where the countdown is being printed is
        ;; actually the ink colour.
        ;;
        ;; LOADER_COUNTDOWN_RESTORE_PILOT_BORDER:
        ;; define this if you want to restore the pilot border colour
        ;; before loading each countdown block.  Useless unless -bleep
        ;; was passed to 47loader-tzx.

        ifdef   LOADER_TAP_FILE_COMPAT
        .error  Progressive loads cannot work in TAP files
        endif

        ifndef  LOADER_COUNTDOWN_CHARSET_ADDRESS
LOADER_COUNTDOWN_CHARSET_ADDRESS: equ  15744
        endif

        ;; calculate display addresses
        if      (LOADER_COUNTDOWN_COLUMN < 0) || (LOADER_COUNTDOWN_COLUMN > 30)
        .error  COUNDOWN_COLUMN must be between 0 and 30
        endif
        if      (LOADER_COUNTDOWN_LINE < 0) || (LOADER_COUNTDOWN_LINE > 23)
        .error  COUNDOWN_LINE must be between 0 and 23
        endif
        if (LOADER_COUNTDOWN_LINE < 8)
.countdown_tens_address:  equ LOADER_COUNTDOWN_COLUMN + 16384 + (32 * LOADER_COUNTDOWN_LINE)
        else
        if  (LOADER_COUNTDOWN_LINE < 16)
.countdown_tens_address:  equ LOADER_COUNTDOWN_COLUMN + 18432 + (32 * (LOADER_COUNTDOWN_LINE - 8))
        else
.countdown_tens_address:  equ LOADER_COUNTDOWN_COLUMN + 20480 + (32 * (LOADER_COUNTDOWN_LINE - 16))
        endif
        endif
.countdown_units_address: equ 1 + .countdown_tens_address

        ifdef   LOADER_COUNTDOWN_ENTRY
        ifdef   LOADER_COUNTDOWN_RESUME
.countdown_both_entry_points:equ 1
        endif
        else
        ifndef  LOADER_COUNTDOWN_RESUME
        .error  Neither LOADER_COUNTDOWN_ENTRY nor LOADER_COUNTDOWN_RESUME defined
        endif
        endif

        ;; bootstrap the progressive load by reading four
        ;; bytes: the length of the first block to load,
        ;; the number at which to stop the countdown and
        ;; the number at which to start the countdown

        ifdef   LOADER_COUNTDOWN_ENTRY
loader_countdown_entry:
        ld      de,4
        call    loader_entry
        ifdef   .countdown_both_entry_points
        jr      .countdown_first_block_loaded
        endif
        endif

        ifdef   LOADER_COUNTDOWN_RESUME
loader_countdown_resume:
        ld      de,4
        call    loader_resume
        endif
.countdown_first_block_loaded:
        ;; store the countdown stop and start numbers in BC
        ld      c,(ix-1)
        ld      b,(ix-2)
        ;; leave IX one byte ahead of the length of the first
        ;; block to load
        dec     ix
        dec     ix

        ;; entering this loop, B contains the last number to print
        ;; and C contains the current countdown number.  IX is
        ;; pointing one byte after the length of the next block to
        ;; load, or one byte after the loaded data if there is
        ;; nothing more to load.  The accumulator is clear because
        ;; we just loaded a block successfully
.countdown_loop:
        ifndef  LOADER_DIE_ON_ERROR
        ret     nc              ; bail out if load failed
        endif

        push    bc              ; we will need a copy of this later

        ;; C contains the next number to print in BCD format
        ;; pick tens digit
        ld      b,a             ; clear B
        push    bc              ; save this for later
        ld      a,c             ; counter into accumulator
        and     0xf0            ; isolate high nibble
        rra                     ; divide by 2; same as rotate into low nibble
                                ; and multiply by 8
        ld      c,a             ; offset from "0" into BC
        ld      de,.countdown_tens_address ; destination into DE
        call    .countdown_print

        pop     bc              ; restore stacked counter with B clear

        ;; pick units digit
        ld      a,c             ; counter into accumulator
        and     0xf             ; isolate low nibble
        add     a,a             ; multiply by 2
        add     a,a             ; multiply by 4
        add     a,a             ; multiply by 8
        ld      c,a             ; offset from "0" into BC
        ld      de,.countdown_units_address ; destination into DE
        call    .countdown_print

        ;; now we see if that was the last digit
        pop     bc              ; restore stacked counter
        ld      a,b             ; final value in accumulator
        xor     c               ; combine with current counter
        scf                     ; indicate successful load
        ret     z               ; return if B^C is zero

        ;; if still here, the countdown is not finished, so we
        ;; decrement the current number
        ld      a,c             ; current value into accumulator
        sub     1               ; can't use DEC A because of DAA
        daa                     ; convert to BCD
        ld      c,a             ; store in counter
        push    bc              ; save for later

        ;; now we have to load the next block
        ld      d,(ix-1)        ; get high byte of next block length
        ld      e,(ix-2)        ; and the low byte
        dec     ix              ; reposition IX before the block length
        dec     ix
        ifdef LOADER_COUNTDOWN_RESTORE_PILOT_BORDER
        xor     a
        set_searching_border
        set_pilot_border
        endif
        call    loader_resume
        pop     bc              ; restore saved counter
        jr      .countdown_loop

.countdown_print:
        ld      hl,LOADER_COUNTDOWN_CHARSET_ADDRESS ; location of "0"
        add     hl,bc           ; add offset to HL to get address of character
        ld      b,8
.countdown_print_loop:
        ld      a,(hl)          ; byte into accumulator
        ifdef   LOADER_COUNTDOWN_INVERSE_VIDEO
        cpl                     ; invert byte
        endif
        ld      (de),a          ; byte onto screen
        inc     hl              ; point to next source byte
        inc     d               ; move down one pixel row
        djnz    .countdown_print_loop ; loop to copy next byte

        ret
