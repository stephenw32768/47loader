        ;; 47loader (c) Stephen Williams 2013-2015
        ;; See LICENSE for distribution terms

loader_start:

        include "47loader_themes.asm"
        include "47loader_timings.asm"

        ;; disabling clean error return implies disabling BREAK
        ;; checking; don't want to reset the Speccy just because
        ;; we accidentally nudged the space bar...
        ifdef LOADER_DIE_ON_ERROR
LOADER_IGNORE_BREAK:equ 1
        endif

        ;; when the sound bit is added to the accumulator
        ;; immediately before OUT (0xFE), themes can add
        ;; additional bits
        ifdef .theme_extra_border_bits
.border_sound:equ 8 | .theme_extra_border_bits
        else
.border_sound:equ 8
        endif

        ;; REGISTER ALLOCATION
        ;; 
        ;; B: .read_edge loop counter
        ;; C: during searching, the number of pilot pulses found
        ;;    so far.
        ;;    During data loading, the current byte being read
        ;; DE:number of bytes remaining to be read.  "Borrowed" during
        ;;    searching if LOADER_SUPPORT_ROM_TIMINGS is set for adding
        ;;    to the running total using ADD HL,DE
        ;; HL:during searching, if LOADER_SUPPORT_ROM_TIMINGS is set, a
        ;;    running total of the values returned by .read_edge for
        ;;    each pilot pulse found.
        ;;    During data loading, the Fletcher-16 checksum.
        ;; IX:target address of next byte to load.

loader_entry:
        ld      (.sp),sp        ; save initial stack pointer
        ;; set load error jump target to return to beginning

        ld      a,.loader_init-.load_error_target-1
        ld      (.load_error_target),a
        ;; and so begins the "searching" phase.  Start by
        ;; setting up the environment
.loader_init:
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        push    de              ; save data length
        endif
.loader_start_search:
        xor     a               ; clear accumulator
        ld      c,a             ; initialize pilot pulse counter
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        ld      d,a             ; knock out high byte of DE
        endif
        set_searching_border
        ifdef   LOADER_TOGGLE_BORDER
        ;; enable the border if it has been disabled; the
        ;; expected usage for this feature is to kill the border
        ;; immediately after an instascreen
        call    loader_enable_border
        endif

        ;; now we are ready to start looking for pilot pulses
        di
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        ld      h,c             ; initialize pulse counter sum
        ld      l,c
        endif
.detect_pilot_pulse:
        call    .read_pilot_edge; read low edge
.detect_pilot_pulse_second:
        call    .read_edge      ; read high edge w/o reinitializing counter
        jr      z,.loader_start_search; restart if no edge found
        ld      a,b             ; place loop counter into accumulator
.detect_pilot_pulse_cp:
        ;; compare against min loops for a pilot pulse, adjusting
        ;; for the loop starting value
        cp      (2 * .pilot_pulse_min)+.timing_constant_pilot
        jr      c,.loader_start_search; too few, not a pilot pulse, so restart
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        ld      e,b             ; DE=loop counter
        add     hl,de           ; add to running total
        endif
        dec     c               ; we have found a pilot pulse
        jr      nz,.detect_pilot_pulse; look for another pulse if count not hit

        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        ;; at this point, HL contains the sum of the return values
        ;; from .read_edge for 256 pilot pulses; therefore H contains
        ;; a rough average of the cycle count for a single pilot pulse
        pop     de              ; restore saved data length
        ld      a,h             ; place averaged cycle count into accumulator
        cp      .pilot_detection_threshold; compare against threshold
        ;; place timing constants into HL
        ld      hl,(256 * .timing_constant_data) | .timing_constant_threshold
        jr      c,.set_timings  ; jump forward if we are using fast timings
        ;; place ROM timing constants into HL
        ld      hl,(256 * .timing_constant_rom_data) | .timing_constant_rom_threshold
.set_timings:
        ld      a,h             ; put timing constant into accumulator
        ld      (.timing_constant_addr),a ; store it
        ld      a,l             ; put zero/one threshold into accumulator
        ld      (.timing_constant_threshold_addr),a ; store it
        endif

.begin_sync:
        ;; change the border effect now that we're locked
        set_pilot_border

        ifdef   LOADER_RESUME
        ;; this is the entry point when re-entering the loader to
        ;; load blocks glued together with tiny pilots in between
loader_resume:
        ifndef LOADER_LEAVE_INTERRUPTS_DISABLED
        di                      ; re-disable interrupts if necessary
        endif
        ifndef LOADER_DIE_ON_ERROR
        ;; we only need to re-save the stack pointer if
        ;; clean exiting is enabled: resume never jumps back
        ;; to .loader_init, it can only error out, so there'll
        ;; be no need to restore the stack pointer before the
        ;; inevitable RST 0
        ld      (.sp),sp
        endif
        endif

        ;; next, keep reading pilot pulses until we hit a
        ;; sync pulse
        call    .detect_sync

        ;; if we got this far, we're synced and ready to read data!

        ;; first, check the initial sanity byte; this may fail if
        ;; the data stream is dodgy
        call    .read_sanity_byte
        ;; from now on, load errors cause hard failures, so we dummy
        ;; out the .load_error jump target, causing the .load_error
        ;; code to actually be executed
        ;; .read_sanity_byte leaves zero in accumulator, so no need
        ;; to reinit
        ;xor     a               ; relative jump with no displacement
        ld      (.load_error_target),a

        ;; the next two bytes are the low and high bytes of the
        ;; starting value of the Fletcher-16 checksum.  Because
        ;; .read_byte also updates the checksum, we don't simply
        ;; copy the read bytes into L and H respectively because
        ;; the read of the high byte will mess it up.  So we put
        ;; the low byte on the stack while reading the high byte
        call    .read_byte      ; read the low byte of the starting value
        push    bc              ; stack it
        call    .read_byte      ; read the high byte
        pop     hl              ; low byte was in C when pushed, now in L
        ld      h,c             ; copy high byte into H

.main_loop:
        call    .read_byte      ; take a wild guess

.store_byte:
        ld      a,0x90;xor 0xff   ; load accumulator with our decode value
        xor     c                 ; XOR with byte just read
        ld      (ix+0),a          ; store byte
.store_byte_instruction:
        ifdef   LOADER_BACKWARDS
        dec     ix
        else
        inc     ix                ; advance pointer
        endif
        dec     de                ; decrement data length
        ld      a,d               ; place high byte into accumulator
        or      e                 ; add bits from low byte
        jr      nz,.main_loop     ; fetch the next byte if more to read

.verify_checksum:
        ;; the Fletcher-16 checksum will finish up as 0xFFFF if
        ;; everything was read correctly.  So if we AND the two
        ;; bytes together and increment the result, we should have
        ;; zero
        ld      a,l             ; copy the low byte of the checksum into A
        and     h               ; combine with the high byte
        add     a,1             ; increment accumulator and set carry if zero

.exit:
        ifndef  LOADER_LEAVE_INTERRUPTS_DISABLED
        ei
        endif
        ;; exiting with carry set indicates success
        ;; carry clear and zero set indicates BREAK pressed
        ;; carry clear and zero clear indicates load error
        ret     c
        ;; BREAK or error if still here
.sp:    equ     $ + 1
        ld      sp,0            ; unwind stack if necessary
.load_error_target:equ $+1
        ;; if BREAK not pressed, we are either restarting
        ;; the search or failing the load depending on
        ;; the displacement set as .load_error_target
        jr      nz,.loader_init    ; jump back to the beginning, perhaps
        ifndef  LOADER_DIE_ON_ERROR
        ret
        else
        rst     0               ; reboot BASIC
        endif
        
        ;; reads a byte, checking it against the expected binary
        ;; value 10110010
.read_sanity_byte:
        call    .read_byte
        ld      a,10110010b;xor 0xff     ; constant for verification
        xor     c               ; check byte just read
        ret     z               ; return if they match
.load_error:
        ;; indicate load error by clearing both carry and zero
        or      1
        jr      .exit

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
        ld      a,0x7f            ; read port 0x7ffe (7T)
        in      a,(0xfe)          ; (11T)
        ifndef LOADER_IGNORE_BREAK
        rra                       ; place BREAK/SPACE bit in carry (4T)
        else
        ;; if we're not checking BREAK/SPACE, we still do
        ;; a port read to keep the timings constant, but we
        ;; dummy out the next instruction so the jump is never
        ;; taken
        scf                       ; ensure that we can never jump (4T)
        endif
        jr      nc,.break_pressed ; jump forward if pressed (7T)
        ;; straight through, the sampling routine requires
        ;; 143T, plus 34T per additional pass around the loop
.read_edge_loop_t_states:equ 34
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
.border_sound_instruction:
        or      .border_sound     ; set bit 3 to make sound (7T)
        out     (0xfe),a          ; switch border and make sound (11T)
        ld      a,(.read_edge_test); place test instruction in accumulator, 13T
        xor     8                 ; invert test (7T)
        ld      (.read_edge_test),a; save new test for next time (13T)
.exit_edge_loop:
        ret                       ; (10T)
        ifndef  LOADER_IGNORE_BREAK
.break_pressed:
        xor     a                 ; clear carry and set zero to signal BREAK
        jr      .exit             ; bail straight out
        else
.break_pressed:equ .read_edge_loop; should never happen...
        endif

        ;; a sync consists of a lone zero pulse followed by a
        ;; lone one pulse.  Both are much shorter than a pilot
        ;; pulse.  So this routine keeps reading edged until
        ;; it hits a pulse shorter than a one pulse; it takes
        ;; this to be the first sync pulse
.detect_sync:
        ;; start by discarding one edge; we could be anywhere
        ;; in it, so we'll start scanning from the start of the
        ;; next one
        call    .read_pilot_edge
.detect_sync_loop:
        call    .read_pilot_edge; read the next single edge
        jr      z,.load_error   ; completely restart if no edge found
        ld      a,b             ; place loop counter into accumulator
        ;; if the new edge was shorter than a one pulse, we've found our
        ;; first sync
        cp      .one_pulse_avg+.timing_constant_pilot
        jr      nc,.detect_sync_loop

        ;; read second sync pulse
        set_data_border
        call    .read_edge

        ;; before returning to start reading data, waste
        ;; approximately three cycles around the sampling loop
        ;; to simulate the usual overhead that occurs after
        ;; reading a byte, so the timing constant at the start
        ;; of the first byte is accurate
        ld      b,9
        djnz    $
        ret

        ;; reads eight bits, leaving the result in register C
.read_byte:
        ;; the first bit gets a slightly tighter timing constant
        ;; due to the T-states we've consumed in storing the
        ;; previous byte, etc.
        ;ld      b,.timing_constant_data + .new_byte_overhead
        ld      a,(.timing_constant_addr) ; place timing constant into A
        add     a,.new_byte_overhead + 1  ; add overhead
        ld      b,a                       ; place into B for reading edge
        ifdef   .theme_new_byte
        ;; theme wants to do some custom setup...
        theme_new_byte
        endif
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
.timing_constant_threshold_addr:equ $+1
        ld      a,.timing_constant_threshold ;(7T)
        sub     b               ; sets carry if a 1 was detected (4T)
        if      .theme_t_states < 23
        ld      a,c             ; copy working value into accumulator; (4T)
        rla                     ; rotate the new bit in from carry; if
                                ; we've done eight bits, the original 1
                                ; will now be in carry (4T)
        ld      c,a             ; save new working value (4T)
        else
        ;; theme requires 4T more than the "standard", so we can save that
        ;; time here
        rl      c               ; rotate new bit in from carry (8T)
        endif
.timing_constant_addr:equ $+1
        ld      b,.timing_constant_data - 1; set for next bit (7T)
        jr      nc,.read_bit    ; read the next bit if necessary (12/7T)

        ;; Next, we must update checksum with the byte just read.
        ;; This is a simple implementation of Fletcher-16:
        ;; https://en.wikipedia.org/wiki/Fletcher%27s_checksum#Fletcher-16
        ;; rather than proper mod 255 arithmetic, we simply add the
        ;; bytes (implicit mod 256) and add 1 if there is overflow
        ld      a,l             ; copy previous low byte of checksum into A
        add     a,c             ; add the byte just read
        adc     a,0             ; include the carry bit if it overflowed
        ld      l,a             ; store the new value of the low byte
        add     a,h             ; add the low byte to the high byte
        adc     a,0             ; include the carry bit if it overflowed
        ld      h,a             ; store the new value of the high byte
        ret

        ;; reverse the direction of the load
        ifdef   LOADER_CHANGE_DIRECTION
loader_change_direction:
        ld      hl,.store_byte_instruction + 1 ; point to the instruction
        ld      a,8                            ; bitmask for toggling inc/dec
        xor     (hl)                           ; switch the instruction
        ld      (hl),a                         ; store it
        ret
        endif

        ifdef   LOADER_TOGGLE_BORDER
        ;; enable the border effect by setting the "border
        ;; sound instruction" to OR *, combining the sound
        ;; bit with the colour in the accumulator
loader_enable_border:
        ld      a,0xf6          ; opcode for OR *
        ld      (.border_sound_instruction),a
        ret

        ;; enable the border effect by setting the "border
        ;; sound instruction" to LD A *, replacing the colour
        ;; in the accumulator with just the sound bit
loader_disable_border:
        ld      a,0x3e          ; opcode for LD A,*
        ld      (.border_sound_instruction),a
        ret
        endif
