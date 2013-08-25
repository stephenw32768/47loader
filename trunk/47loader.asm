        org     0

.dest:  equ     65368           ; UDG area
        ld      de,.dest
        push    bc
        pop     hl              ; entry address now in HL
        ld      bc,.reloc_start
        add     hl,bc
        ld      bc,.reloc_len
        ldir
        jp      .dest

.reloc_start:   equ     $
        org     .dest

        ;; all the minimums have been adjusted down a little
        ;; to allow for the extra T-states consumed by the
        ;; processing outside of .read_edge

        ;; min/max iterations of .read_edge to detect a pilot pulse
.pilot_pulse_min:equ 34         ; adjusted from estimated 36
.pilot_pulse_max:equ 63         ; adjusted from estimated 60
        ;; min/max iterations of .read_edge to detect a 0 pulse
.zero_pulse_min:equ 4           ; adjusted from estimated 6
.zero_pulse_max:equ 13
        ;; min/max iterations of .read_edge to detect a 1 pulse
.one_pulse_min:equ 14           ; adjusted from estimated 15
.one_pulse_max:equ 28

        ;; the values that the .read_edge loop counter starts at
        ;; when looking for pilot and data pulses.  This ensures
        ;; that .read_edge never finds an edge that is longer
        ;; than the maximum permitted
.edge_loop_start_pilot:equ 256-.pilot_pulse_max
.edge_loop_start_data:equ 256-.one_pulse_max

        ;; REGISTER ALLOCATION
        ;; 
        ;; B: .read_edge loop counter
        ;; C: during searching, the number of pilot pulses found
        ;;    so far.
        ;;    During data loading, the current byte being read
        ;; D: a bitmask for matching the current edge against a
        ;;    byte read from port 0xFE; so 0x40 for high edges
        ;;    and 0 for low edges
        ;; E: the bitmask for isolating bit 5 from port 0xFE: so
        ;;    0x40
        ;; H: the starting value of .read_edge's loop counter; this
        ;;    limits the number of iterations that .read_edge can
        ;;    make, and thus sets the maximum length of a pulse
        ;;    that will be recognized.
        ;; IX:target address of next byte to read, as LD-BYTES

        ;; set this test program to load a screen
        ld      ix,16384
        ld      de,6912

        di

        ;; move the data length out of the way, no sense in
        ;; it hogging two registers permanently
        push    de

        ;; initially, we are looking for the tape signal to go
        ;; low, so we behave as if it is currently high; hence
        ;; we initialize D to 0x40.  E is fixed at 0x40
        ld      de,0x4040

.detect_pilot_tone:
        ;; adjust .read_edge's loop counter for pilot pulses
        ld      h,.edge_loop_start_pilot
        ld      c,0             ; initialize pilot pulse counter
        ;; L isn't being used for anything else at the moment,
        ;; so we may as well set it to one of the constants
        ;; used for detecting sync pulses to save a few T-states
        ld      l,.zero_pulse_max+.edge_loop_start_pilot

.detect_pilot_pulse:
        call    .read_edge      ; read low edge and discard
        call    .read_edge      ; read high edge
        jr      z,.detect_pilot_tone; restart if no edge found
        ld      a,b             ; place loop counter into accumulator
.detect_pilot_pulse_cp:
        ;; compare against min loops for a pilot pulse, adjusting
        ;; for the loop starting value
        cp      .pilot_pulse_min+.edge_loop_start_pilot
        jr      c,.detect_pilot_tone; too few, not a pilot pulse, so restart
        inc     c               ; we have found a pilot pulse
        jr      z,.detect_sync  ; we have found 256 pulses; this is a pilot
        jr      .detect_pilot_pulse ; look for another pulse

.detect_sync:
        ;; a sync consists of a lone zero pulse followed by a
        ;; lone one pulse

.detect_sync_zero:
        ;; we may need to check for more pilot pulses, so start
        ;; by decrementing the pilot pulse counter
        dec     c
        call    .read_edge      ; read the next edge
        jr      z,.detect_pilot_tone; completely restart if no edge found
        ld      a,b             ; place loop counter into accumulator
        ;; compare against max loops for a zero pulse, adjusting
        ;; for the loop starting value
        cp      l
        jr      nc,.detect_pilot_pulse_cp ;too many, perhaps it's another pilot
        ;; compare against min loops for a zero pulse, adjusting
        ;; for the loop starting value
        cp      .zero_pulse_min+.edge_loop_start_pilot
        jr      c,.detect_pilot_tone ; too few, restart search

.detect_sync_one:
        ;; okay, we've found a zero pulse.  From now on, the only
        ;; valid pulses are ones and zeros, so we can adjust
        ;; .read_edge's loop counter to enforce this
        ld      h,.edge_loop_start_data

        call    .read_edge      ;read the next edge
        jr      z,.detect_pilot_tone ; completely restart if no edge found
        ld      a,b             ; place loop counter into accumulator
        ;; compare against min loops for a one pulse, adjusting
        ;; for the loop starting value
        cp      .one_pulse_min+.edge_loop_start_data
        jr      c,.detect_pilot_tone ;too few, restart search

        ;; if we got this far, we've found a one pulse and thus
        ;; a valid sync.  So we can start reading the data

.read_byte:
        ;; L will be shifted left one place for each bit we read.
        ;; When the initial 1 is in the carry, we know we're done
        ld      l,1
.read_bit:
        sla     l               ; make room for the next bit
        ex      af,af'          ; stash the flags away for later
        call    .read_edge      ; read low edge and discard
        call    .read_edge      ; read high edge
        jr      z,.load_error   ; abort if no edge found
        ld      a,b             ; place loop counter into accumulator
        ;; compare against min loops for a zero pulse, adjusting
        ;; for the loop starting value
        cp      .zero_pulse_min+.edge_loop_start_data
        jr      c,.load_error   ; abort if too few
        ;; subtract from min loops for a one pulse minus one,
        ;; adjusting for the loop starting value.  If negative,
        ;; carry will be set and the pulse is a one, otherwise
        ;; we'll assume it's a zero
        ld      a,.one_pulse_min+.edge_loop_start_data-1
        sub     b
        jr      nc,.read_bit_zero; don't set if it's a zero
        set     0,l              ; set if it's a one
.read_bit_zero:
        ex      af,af'          ; restore the carry we saved earlier
        jr      nc,.read_bit    ; read the next bit if necessary

        ;; Okay, we've read a byte!  We need to update the
        ;; checksum with it
.checksum:equ $+1
        ld      a,0             ; place checksum into accumulator
        xor     l               ; XOR with byte just read
        ld      (.checksum),a   ; save new checksum for later

        ;; Next, we need to check whether we just read a data
        ;; byte or the final checksum
        pop     bc              ; fetch data length from stack
        ld      a,b             ; place high byte into accumulator
        or      c               ; add bits from low byte
        jr      z,.verify_checksum; jump forward if this is the checksum

.store_byte:
        ld      a,0               ; TODO
        xor     l                 ; XOR with byte just read
        ld      (ix+0),a          ; store byte
        inc     ix                ; advance pointer
        dec     bc                ; decrement data length
        push    bc                ; save new data length on stack
        jr      .read_byte        ; fetch the next byte

.verify_checksum:
        push    bc              ;exit code assumes data length on stack
        ld      a,(.checksum)   ;retrieve saved checksum
        or      a               ;see if it's zero
        jr      nz,.load_error  ;abort if so

        scf                     ;set carry to indicate success
        jr      .exit           ;exit succesfully
        
.load_error:
        ;; indicate load error by clearing both carry and zero
        ld      a,1
        and     a
.exit:
        ;; exiting with carry set indicates success
        ;; carry clear and zero set indicates BREAK pressed
        ;; carry clear and zero clear indicates load error
        pop     hl              ;remove the data length from the stack
        ei
        ret

        ;; spins in a loop until an edge is found.
        ;; If BREAK/SPACE is pressed, bails out to .exit with
        ;; carry clear.  If no edge is found after 256 iterations,
        ;; returns zero set.  On success, returns zero clear and the
        ;; loop counter in B
.read_edge:
        ld      b,h               ; initialize counter
        ld      a,0x7f            ; read port 0x7ffe
        in      a,(0xfe)
        bit     0,a               ; look at BREAK/SPACE
        jr      nz,.test_ear_port ; if not pressed, jump into loop
        xor     a                 ; clear carry and set zero to signal BREAK
        pop     bc                ; abandon this routine call
        jr      .exit             ; bail straight out
.read_edge_loop:
        inc     b                 ; increment counter
        ret     z                 ; give up if wrapped round -- no edge found
        in      a,(0xfe)          ; read port 0xfe
.test_ear_port:
        ;; d: current edge bitmask; e: bitmask for reading EAR
        and     e                 ; look at EAR bit
        cp      d                 ; compare against current edge
        jr      z,.read_edge_loop ; loop if no change
        ld      d,a               ; store new current edge for next time
        rlca                      ; bit 7 now set/clear
        rlca                      ; bit 0 (and carry flag) now set/clear
        or      8                 ; set bit 3 to make sound
        out     (0xfe),a          ; switch border and make sound
.exit_edge_loop:
        ret
;.break_pressed:
;        and     a               ; clear carry flag
;        ret

;.border:and     a               ; see if this is the low or high edge
;        ret     z               ; black on the low edge
;        ld      a,r             ; rainbow on the high edge
;        and     7
;        ret
;.border:
;.colour:equ $ + 1
;       ld a,3          ; self modifies 3 -> 2 -> 1 -> 3 ...
;        dec a
;        jr z,.make_white
;        ld (.colour),a          ; save for next time
;        ret
;.make_white:
;        ld a,3                  ; reset sequence
;        ld (.colour),a          ; save for next time
;        ld a,7                  ; this time, we want white
;        ret
        
.reloc_len: equ $ - .dest
