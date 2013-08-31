        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

loader_start:

        include "47loader_themes.asm"

        ;; average iterations of sampling loop to detect a
        ;; _single_ pulse.  Determined empirically
.pilot_pulse_avg:equ 52
.zero_pulse_avg:equ 5
.one_pulse_avg:equ 20

        ;; min/max iterations of sampling loop to detect a pilot pulse
.pilot_pulse_min:equ .pilot_pulse_avg * 70 / 100  ; 70%
.pilot_pulse_max:equ .pilot_pulse_avg * 120 / 100 ; 120%
        ;; min/max iterations of sampling loop to detect a 1 pulse
.one_pulse_min:equ .one_pulse_avg * 60 / 100 ; 60%, very generous
.one_pulse_max:equ .one_pulse_avg * 150 / 100; 150%, also very generous

        ;; the values that the .read_edge loop counter starts at
        ;; when looking for pilot and data pulses.  This ensures
        ;; that .read_edge never finds an edge that is longer
        ;; than the maximum permitted.  2x because we look at both
        ;; the low and high pulses
.timing_constant_pilot:equ 256-(2 * .pilot_pulse_max)
.timing_constant_data:equ 256-(2 * .one_pulse_max)

        ;; when reading bits, this is the value from two passes
        ;; around .read_edge used as the cutoff between zero
        ;; pulses and one pulses.  It's slightly lower than bang
        ;; in the middle of a zero and one pulse to account for
        ;; the first bit in a byte requiring fewer cycles around
        ;; the sampling loop due to overhead
.timing_constant_threshold:equ .timing_constant_data+.zero_pulse_avg+.one_pulse_avg-5

        ;; REGISTER ALLOCATION
        ;; 
        ;; B: .read_edge loop counter
        ;; C: during searching, the number of pilot pulses found
        ;;    so far.
        ;;    During data loading, the current byte being read
        ;; DE:number of bytes remaining to be read
        ;; IX:target address of next byte to load.

loader_entry:
        di
        ld      (.sp),sp        ; save initial stack pointer
        ;; set load error jump target to return to beginning
        ld      a,.loader_init-.load_error_target-1
        ld      (.load_error_target),a

        ;; and so begins the "searching" phase.  Start by
        ;; setting up the environment
.loader_init:
        xor     a               ; clear accumulator
        ld      (.checksum),a   ; zero checksum
        ld      c,a             ; initialize pilot pulse counter
        set_searching_border

        ;; now we are ready to start looking for pilot pulses
.detect_pilot_pulse:
        call    .read_pilot_edge; read low edge
.detect_pilot_pulse_second:
        call    .read_edge      ; read high edge w/o reinitializing counter
        jr      z,.loader_init  ; restart if no edge found
        ld      a,b             ; place loop counter into accumulator
.detect_pilot_pulse_cp:
        ;; compare against min loops for a pilot pulse, adjusting
        ;; for the loop starting value
        cp      (2 * .pilot_pulse_min)+.timing_constant_pilot
        jr      c,.loader_init  ; too few, not a pilot pulse, so restart
        dec     c               ; we have found a pilot pulse
        jr      nz,.detect_pilot_pulse; look for another pulse if count not hit

.detect_sync:
        ;; a sync consists of a lone zero pulse followed by a
        ;; lone one pulse

        ;; change the border effect now that we're locked
        set_pilot_border

        ;; not sure about this...
        ifdef LOADER_TWO_EDGE_SYNC
        ;; for reliability, we're still checking pairs of pulses
        ;; here; but we need to read them one at a time because
        ;; we don't know when we're going to hit the sync pulse
        ;;
        ;; start by initializing C to a sane value as if we had
        ;; just read a _single_ pilot pulse
        ld      c,.timing_constant_pilot+.pilot_pulse_avg

.detect_sync_loop:
        call    .read_pilot_edge;read the next single edge
        jr      z,.loader_init  ; completely restart if no edge found
        ld      a,c             ; place previous edge counter into accumulator
        sub     .timing_constant_pilot; keep only the number of loop cycles
        add     a,b             ; add the most recent single edge counter
        ;; in the accumulator, we now have the value that we would have
        ;; had in B had we called .read_edge for the previous half-pulse,
        ;; then .read_edge_delay for this half-pulse.  If the newest
        ;; pulse is the first sync pulse, the next comparison will set
        ;; carry
        cp      (2 * .pilot_pulse_min)+.timing_constant_pilot
        ld      c,b             ; store this single edge counter for next time
        jr      nc,.detect_sync_loop ; newest pulse was not the first sync
        endif

        ifndef LOADER_TWO_EDGE_SYNC
.detect_sync_loop:
        call    .read_pilot_edge; read the next single edge
        jr      z,.loader_init  ; completely restart if no edge found
        ld      a,b             ; place loop counter into accumulator
        ;; if the new edge was shorter than a one pulse, we've found our
        ;; first sync
        cp      .one_pulse_avg+.timing_constant_pilot
        jr      nc,.detect_sync_loop
        endif

        ;; read second sync pulse
        set_data_border
        call    .read_edge

        ;; first, check the initial sanity byte; this may fail if
        ;; the data stream is dodgy
        call    .read_sanity_byte
        ;; from now on, load errors cause hard failures, so we dummy
        ;; out the .load_error jump target, causing the .load_error
        ;; code to actually be executed
        xor     a                      ; relative jump with no displacement
        ld      (.load_error_target),a

.main_loop:
        call    .read_byte      ; take a wild guess

        ;; next, we need to check whether we just read a data
        ;; byte or the final checksum by checking the number of
        ;; bytes remaining to be read
        ld      a,d             ; place high byte into accumulator
        or      e               ; add bits from low byte
        jr      z,.verify_checksum; jump forward if this is the checksum

.store_byte:
        ld      a,0x90;xor 0xff   ; load accumulator with our decode value
        xor     c                 ; XOR with byte just read
        ;; use routine to advance pointer if supplied
        ld      (ix+0),a          ; store byte
        ifdef   loader_advance_pointer
        call    loader_advance_pointer
        else
        inc     ix                ; advance pointer
        endif
        dec     de                ; decrement data length
        jr      .main_loop        ; fetch the next byte

.verify_checksum:
        ld      a,(.checksum)   ;retrieve saved checksum
        neg                     ;set carry if non-zero
        ccf                     ;invert carry
.exit:
        ;; exiting with carry set indicates success
        ;; carry clear and zero set indicates BREAK pressed
        ;; carry clear and zero clear indicates load error
.sp:    equ     $ + 1
        ld      sp,0            ; unwind stack if necessary
        ifndef  LOADER_LEAVE_INTERRUPTS_DISABLED
        ei
        endif
        ret
        
        ;; reads a byte, checking it against the expected binary
        ;; value 01001101
.read_sanity_byte:
        ;; the flag byte gets the normal data timing constant
        ;; because there was practically no overhead between
        ;; reading the trailing sync edge and calling this
        ld      b,.timing_constant_data-1
        call    .read_byte + 2  ; read a byte from tape w/o setting timing
        ld      a,01001101b;xor 0xff     ; constant for verification
        xor     c               ; check byte just read
        ret     z               ; return if they match
.load_error:
        ld      sp,(.sp)        ; unwind stack if necessary
.load_error_target:equ $+1
        jr      $+2             ; branch back to the beginning, perhaps
        ifndef  LOADER_DIE_ON_ERROR
        ;; indicate load error by clearing both carry and zero
        or      1
        jr      .exit
        else
        rst     0               ; reboot BASIC
        endif

        ;; spins in a loop until an edge is found.
        ;; If BREAK/SPACE is pressed, bails out to .exit with
        ;; carry clear.  If no edge is found after 256 iterations
        ;; minus the initial value of B, returns zero set.  On
        ;; success, returns zero clear and the loop counter in B
        ;;
        ;; total 376T, plus 34T per additional pass around the loop
.read_pilot_edge:
        ld      b,.timing_constant_pilot ; (7T)
.read_edge:
        ;; delay loop consumes 226T
        ld      a,14              ; prepare delay loop (7T)
        dec     a                 ; (4T)
        jr      nz,$-1            ; (12T when taken, 7T when not)
        ifndef LOADER_DIE_ON_ERROR
        ld      a,0x7f            ; read port 0x7ffe (7T)
        else
        ;; if we're not checking BREAK/SPACE, we still do
        ;; a port read to keep the timings constant, but we
        ;; dummy it out to a port that doesn't read keys
        ld      a,0xff            ; read port 0xfffe (7T)
        endif
        in      a,(0xfe)          ; (11T)
        rra                       ; place BREAK/SPACE bit in carry (4T)
        jr      nc,.break_pressed ; jump forward if pressed (7T)
        ;; straight through, the sampling routine requires
        ;; 143T, plus 34T per additional pass around the loop
.read_edge_loop:
        inc     b                 ; increment counter (4T)
        ret     z                 ; give up if wrapped round (5T)
        in      a,(0xfe)          ; read port 0xfe (11T)
        add     a,a               ; shift EAR bit into sign bit & set flag (4T)
.read_edge_test:
        jp      m,.read_edge_loop ; loop if no change (10T)
        ;; the rainbow border theme requires 19T:
        ;; rla     4T
        ;; sbc a,a 4T
        ;; and c   4T
        ;; and 7   7T
        border                    ; put border colour in accumulator
        or      8                 ; set bit 3 to make sound (7T)
        out     (0xfe),a          ; switch border and make sound (11T)
        ld      a,(.read_edge_test); place test instruction in accumulator, 13T
        xor     8                 ; invert test (7T)
        ld      (.read_edge_test),a; save new test for next time (13T)
.exit_edge_loop:
        ret                       ; (10T)
        ifndef  LOADER_DIE_ON_ERROR
.break_pressed:
        xor     a                 ; clear carry and set zero to signal BREAK
        jr      .exit             ; bail straight out
        else
.break_pressed:equ .read_edge_loop; should never happen...
        endif

        ;; reads eight bits, leaving the result in register C
.read_byte:
        ;; the first bit gets a slightly tighter timing constant
        ;; due to the T-states we've consumed in storing the
        ;; previous byte, etc.
        ld      b,.timing_constant_data + 3
        ;; C will be shifted left one place for each bit we read.
        ;; When the initial 1 is in the carry, we know we're done
        ld      c,1
.read_bit:
        ;; not including the sampling loop, each bit requires
        ;; 72T
        call    .read_edge      ; read low edge (17T)
        call    .read_edge      ; read high edge w/o reinitializing counter
        jr      z,.load_error   ; abort if no edge found (7T)
        ;; if B returned more cycles than this threshold, we have
        ;; a 1 pulse, else a 0
        ld      a,.timing_constant_threshold ;(7T)
        sub     b               ; sets carry if a 1 was detected (4T)
        ifndef  LOADER_THEME_LDBYTES
        ld      a,c             ; copy working value into accumulator; (4T)
        rla                     ; rotate the new bit in from carry; if
                                ; we've done eight bits, the original 1
                                ; will now be in carry (4T)
        ld      c,a             ; save new working value (4T)
        else
        ;; LDBYTES theme requires 4T more than the others, so we
        ;; can save that time here
        rl      c               ; rotate new bit in from carry (8T)
        endif
        ld      b,.timing_constant_data - 1; set for next bit (7T)
        jr      nc,.read_bit    ; read the next bit if necessary (12/7T)
        ;; update checksum with the byte just read
.checksum:equ $ + 1
        ld      a,0             ; place checksum into accumulator
        xor     c               ; XOR with byte just read
        ld      (.checksum),a   ; save new checksum for later
        ret
