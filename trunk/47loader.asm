        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms
        ;; Released into the public domain.  Do as thou wilt.

loader_start:

        include "47loader_themes.asm"

        ;; min/max iterations of .read_edge to detect a pilot pulse
.pilot_pulse_min:equ 21
.pilot_pulse_max:equ 40
        ;; min/max iterations of .read_edge to detect a 1 pulse
.one_pulse_min:equ 6
.one_pulse_max:equ 20

        ;; the values that the .read_edge loop counter starts at
        ;; when looking for pilot and data pulses.  This ensures
        ;; that .read_edge never finds an edge that is longer
        ;; than the maximum permitted
.timing_constant_pilot:equ 256-(2 * .pilot_pulse_max)
.timing_constant_data:equ 256-(2 * .one_pulse_max)
        ;; this is the minimum value returned by .read_edge
        ;; for a pulse representing a 1.  Exported because it
        ;; is useful for resyncing
loader_one_pulse_min:equ .one_pulse_min+.timing_constant_data

        ;; REGISTER ALLOCATION
        ;; 
        ;; B: .read_edge loop counter
        ;; C: during searching, the number of pilot pulses found
        ;;    so far.
        ;;    During data loading, the current byte being read
        ;; DE:number of bytes remaining to be read
        ;; HL:during search/sync, the address of the timing
        ;;    constant used to initialize .read_edge's counter
        ;; IX:target address of next byte to load.

loader_entry:
        di
        ld      (.sp),sp        ; save initial stack pointer

        ;; and so begins the "searching" phase.  Start by
        ;; setting up the environment
.loader_init:
        ld      a,0x37          ; opcode for SCF
        ld      (.load_error),a ; load errors return to beginning
        xor     a               ; clear accumulator
        ld      (.checksum),a   ; zero checksum
        set_searching_border
        ld      hl,.timing_constant
        ;; adjust .read_edge's loop counter for pilot pulses
        ld      (hl),.timing_constant_pilot-1 ; -1 because of immediate inc b

        ;; now we are ready to start looking for pilot pulses
        ld      c,0            ; we need 256 pulses
.detect_pilot_pulse:
        call    .read_edge      ; read low edge
.detect_pilot_pulse_second:
        call    .read_edge_delay; read high edge w/o reinitializing counter
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
        ld      c,.timing_constant_pilot+.pilot_pulse_min

.detect_sync_loop:
        call    .read_edge      ; read the next single edge
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
        call    .read_edge
        jr      z,.loader_init
        ld      a,b
        cp      5+.one_pulse_min+.timing_constant_pilot ; finger in the air
        jr      nc,.detect_sync_loop
        endif

        ;; from now on, the only valid pulses are ones and zeros,
        ;; so we can adjust .read_edge's loop counter/timing constant
        ;; to enforce this
        ld      (hl),.timing_constant_data-1 ; -1 because of immediate inc b

        ;; read second sync pulse
        set_data_border
        call    .read_edge

        ;; first, check the initial sanity byte; this may fail if
        ;; the data stream is dodgy
        call    .read_sanity_byte
        ld      a,0xa7          ; opcode for AND A, clears carry
        ld      (.load_error),a ; from now on, load errors cause hard failure

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
        ei
        ret
        
        ;; reads a byte, checking it against the expected binary
        ;; value 01001101
.read_sanity_byte:
        call    .read_byte      ; read a byte from tape
        ld      a,01001101b;xor 0xff     ; constant for verification
        xor     c               ; check byte just read
        ret     z               ; return if they match
.load_error:
        nop                     ; room for one-byte instruction
        ld      sp,(.sp)        ; unwind stack if necessary
        jr      c,.loader_init  ; start again if carry set
        ;; indicate load error by clearing both carry and zero
        or      1
        jr      .exit

        ;; spins in a loop until an edge is found.
        ;; If BREAK/SPACE is pressed, bails out to .exit with
        ;; carry clear.  If no edge is found after 256 iterations,
        ;; returns zero set.  On success, returns zero clear and the
        ;; loop counter in B
loader_read_edge:
.read_edge:
.timing_constant:equ $ + 1
        ld      b,0               ; initialize counter (7T)
.read_edge_delay:
        ;; this lot consumes 258T
        ld      a,16              ; prepare delay loop (7T)
        dec     a                 ; (4T)
        jr      nz,$-1            ; (12T when taken, 7T when not)
        ;; straight through, the sampling routine requires
        ;; 119T, plus 53T per additional pass around the loop
.read_edge_loop:
        inc     b                 ; increment counter (4T)
        ret     z                 ; give up if wrapped round (5T)
        ld      a,0x7f            ; read port 0x7ffe (7T)
        in      a,(0xfe)          ; (11T)
        and     0x41              ; look only at EAR/BREAK bits (7T)
.current_edge_mask:equ $ + 1
        cp      0x41              ; compare against current bits (7T)
                                  ; (on high edge, carry now set)
        jr      z,.read_edge_loop ; loop if no change (12T/7T)
        bit     0,a               ; look at BREAK/SPACE (8T)
        jr      z,.break_pressed  ; jump forward if pressed (7T)
        ld      (.current_edge_mask),a; store new current edge for next time 13T
        ;; the rainbow border theme requires 15T:
        ;; sbc a,a 4T
        ;; and c   4T
        ;; and 7   7T
        border                    ; put border colour in accumulator
        or      8                 ; set bit 3 to make sound (7T)
        out     (0xfe),a          ; switch border and make sound (11T)
.exit_edge_loop:
        ret                       ; (10T)
.break_pressed:
        xor     a                 ; clear carry and set zero to signal BREAK
        jr      .exit             ; bail straight out

        ;; reads eight bits, leaving the result in register C
.read_byte:
        ;; C will be shifted left one place for each bit we read.
        ;; When the initial 1 is in the carry, we know we're done
        ld      c,1
.read_bit:
        ;; not including the sampling loop, each bit requires
        ;; 72T
        call    .read_edge      ; read low edge (17T)
        call    .read_edge_delay ; read high edge w/o reinitializing counter
        jr      z,.load_error   ; abort if no edge found (7T)
        ;; this value is just under twice the minimum number of
        ;; cycles around the sampling loop that detect a one pulse,
        ;; thus taking both edges into account.  If our two calls to
        ;; .read_edge yielded a larger number than this, we take it
        ;; that we have a one, otherwise we have a zero (7T)
        ld      a,.one_pulse_min * 19 / 10 + 1 + .timing_constant_data
        sub     b               ; sets carry if a 1 was detected (4T)
        ld      a,c             ; copy working value into accumulator; (4T)
        rla                     ; rotate the new bit in from carry; if
                                ; we've done eight bits, the original 1
                                ; will now be in carry (4T)
        ld      c,a             ; save new working value (4T)
        jr      nc,.read_bit    ; read the next bit if necessary (12/7T)
        ;; update checksum with the byte just read
.checksum:equ $ + 1
        ld      a,0             ; place checksum into accumulator
        xor     c               ; XOR with byte just read
        ld      (.checksum),a   ; save new checksum for later
        ret
