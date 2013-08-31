        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; Border themes for 47loader

        ;; Each theme defines three macros:
        ;; border, set_pilot_border, set_data_border
        ;;
        ;; border does the actual work of placing the border
        ;; colour into the accumulator.  On entry, carry is
        ;; set on high edges and clear on low edges
        ;;
        ;; set_pilot_border and set_data_border make any
        ;; adjustments to the code to set things up for the
        ;; pilot or data borders
        ;;
        ;; Define one of:
        ;; LOADER_THEME_ORIGINAL
        ;; LOADER_THEME_SPEEDLOCK
        ;; LOADER_THEME_LDBYTES
        ;; LOADER_THEME_JUBILEE
        ;; LOADER_THEME_RAINBOW
        ;; LOADER_THEME_RAINBOW_RIPPLE


        ifdef LOADER_THEME_ORIGINAL
        ;; the original 47loader border: blue/black pilot, red/black data

        macro set_searching_border
        inc     a               ; from 0 to 1, i.e. blue
        ld      (.border_mask),a
        endm

        macro set_pilot_border
        ;; same as searching border
        endm

        macro set_data_border
        ld      a,2             ; red
        ld      (.border_mask),a
        endm

        macro border
        ;; 19T, same as rainbow theme
        sla     a               ; move EAR bit into carry flag (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_mask:equ $+1
        and     0               ; mask only the required colour bits of A (7T)
        endm

.theme_set:equ 1
        endif

        ifdef LOADER_THEME_SPEEDLOCK
        ;; red/black pilot, blue/black data, Speedlock-stylee

        macro set_searching_border
        ld      (.border_instruction),a ; 0, NOP
        endm

        macro set_pilot_border
        ;; same as searching border
        endm

        macro set_data_border
        ;; shift right, back into bit 0, i.e. blue
        ld      a,0x1f          ; opcode for RRA
        ld      (.border_instruction),a
        endm

        macro border
        ;; 19T, same as rainbow theme
        rlca                    ; move EAR bit into bit 0 (4T)
        and     1               ; keep only the EAR bit (7T)
        add     a,a             ; shift the EAR bit to make red colour (4)
.border_instruction:
        nop                     ; room for a one-byte instruction (4T)
        endm

.theme_set:equ 1
        endif

        ifdef LOADER_THEME_LDBYTES
        ;; same colour scheme as the ROM loader

        macro set_searching_border
        ;; base colour for pilot border is red
        ld      a,2
        ld      (.colour),a
        endm

        macro set_pilot_border
        ;; same as searching border
        endm

        macro set_data_border
        ;; base colour for data border is blue
        ld      a,1
        ld      (.colour),a
        endm

        macro border
        ;; 23T
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.colour:equ $+1
        xor     0               ; combine with colour number (7T)
        and     7               ; keep only lowest three bits (7T)
.high_edge:
        endm

.theme_set:equ 1
        endif

        ifdef LOADER_THEME_JUBILEE
        ;; black/white pilot, red/white/blue data
        ;; (deprecated: colossal waste of T-states!)

        ;; the pilot and data effects are completely different;
        ;; so rather than changing one or two instructions, the
        ;; set_*_border functions install calls to different
        ;; routines

.jubilee_pilot:
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
        and     7               ; keep only the colour bits (7T)
        ret

.jubilee_data:
        ld      a,3             ; load accumulator with colour number
        and     3               ; use only the lowest two bits
        dec     a               ; decrement to get the colour to use
        jr      nz,.red_or_blue ; jump forward if non-zero (red or blue)
        ld      a,7             ; if zero, make white
.red_or_blue:
        ld      (.jubilee_data+1),a ; save colour number for next time
        ret

        macro set_searching_border
        ;; install call to .jubilee_pilot
        push    hl              ; at this point, HL is important, so save it
        ld      hl,.jubilee_pilot
        ld      (.border_routine_addr),hl
        pop     hl
        endm

        macro set_pilot_border
        ;; same as searching border
        endm

        macro set_data_border
        ;; install call to .jubilee_data
        push    hl              ; at this point, HL is important, so save it
        ld      hl,.jubilee_data
        ld      (.border_routine_addr),hl
        pop     hl
        endm

        macro border
.border_routine_addr:equ $+1
        call    0               ; will be replaced by set_*_border
        endm

.theme_set:equ 1
        endif

        ifdef LOADER_THEME_RAINBOW
        ;; rainbow data, black/white pilot

        macro set_searching_border
        ;; A is 0 when this macro is executed, so this line
        ;; sets .border_instruction to NOP
        ld      (.border_instruction),a ; NOP
        ld      a,2                     ; mask for red
        ld      (.border_mask),a
        endm

        macro set_pilot_border
        ld      a,4                     ; mask for green
        ld      (.border_mask),a
        endm

        macro set_data_border
        ;; sets border instruction to AND C, combining the
        ;; value in the accumulator with the bits currently
        ;; being loaded
        ld      a,0xa4                     ; AND H
        ld      (.border_instruction),a
        ld      a,7                        ; mask for all colour bits
        ld      (.border_mask),a
        endm

        macro border
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_instruction:
        nop                     ; room for a one-byte instruction (4T)
.border_mask:equ $+1
        and     0               ; mask only the lowest three bits of A (7T)
        endm

.theme_set:equ 1
        endif

        ifdef LOADER_THEME_RAINBOW_RIPPLE
        ;; rainbow data, black/white pilot.  Data border is derived
        ;; from the E register (low byte of byte counter) and thus
        ;; changes once per eight bits, giving a rippling effect

        macro set_searching_border
        ;; A is 0 when this macro is executed, so this line
        ;; sets .border_instruction to NOP
        ld      (.border_instruction),a ; NOP
        ld      a,2                     ; mask for red
        ld      (.border_mask),a
        endm

        macro set_pilot_border
        ld      a,4                     ; mask for green
        ld      (.border_mask),a
        endm

        macro set_data_border
        ;; sets border instruction to AND E, combining the
        ;; value in the accumulator with the low byte of the
        ;; byte counter
        ld      a,0xa3                     ; AND E
        ld      (.border_instruction),a
        ld      a,7                        ; mask for all colour bits
        ld      (.border_mask),a
        endm

        macro border
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_instruction:
        nop                     ; room for a one-byte instruction (4T)
.border_mask:equ $+1
        and     0               ; mask only the lowest three bits of A (7T)
        endm

.theme_set:equ 1
        endif

        ifndef .theme_set
        .error  No theme selected
        endif
