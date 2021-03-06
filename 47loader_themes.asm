        ;; 47loader (c) Stephen Williams 2013-2015
        ;; See LICENSE for distribution terms

        ;; Border themes for 47loader

        ;; Each theme defines four macros:
        ;; border, set_searching_border, set_pilot_border,
        ;; set_data_border
        ;;
        ;; border does the actual work of placing the border colour
        ;; into the accumulator.  On entry, the sign bit of the
        ;; accumulator is set or clear on alternate edges
        ;;
        ;; set_*_border make any adjustments to the code to set things
        ;; up for the searching, syncing/pilot or data borders.  On
        ;; entry to set_pilot_border, carry is set if fast timings
        ;; are in use and clear if ROM timings are in use
        ;;
        ;; Themes can define a subroutine, .theme_delay, that replaces the
        ;; usual 226T delay loop at the beginning of each .read_edge.  The
        ;; subroutine must execute within a hair's breadth of 226T,
        ;; including the CALL and RET.
        ;;
        ;; Define one of:
        ;; LOADER_THEME_ARGENTINA
        ;; LOADER_THEME_BRAZIL
        ;; LOADER_THEME_BLEEPLOAD
        ;; LOADER_THEME_CANDY
        ;; LOADER_THEME_CHRISTMAS
        ;; LOADER_THEME_CYCLE_VERSA
        ;; LOADER_THEME_ELIXIRVITAE
        ;; LOADER_THEME_FIRE
        ;; LOADER_THEME_ICE
        ;; LOADER_THEME_JUBILEE
        ;; LOADER_THEME_LDBYTES
        ;; LOADER_THEME_LDBYTESPLUS
        ;; LOADER_THEME_ORIGINAL
        ;; LOADER_THEME_RAINBOW
        ;; LOADER_THEME_RAINBOW_RIPPLE
        ;; LOADER_THEME_RAINBOW_VERSA
        ;; LOADER_THEME_SETYBDL
        ;; LOADER_THEME_SPAIN
        ;; LOADER_THEME_TRINIDAD
        ;; LOADER_THEME_SPEEDLOCK
        ;; LOADER_THEME_VERSA
        ;; 
        ;; LOADER_THEME_RAINBOW is the "standard".  Its border
        ;; implementation requires 19 T-states.  Other themes
        ;; are coded to match this as closely as possible


        ifdef LOADER_THEME_ORIGINAL
        ;; the original 47loader border
        ;; Searching: black/blue
        ;; Pilot/sync:black/blue
        ;; Data:      black/red

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

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        ;; 19T, same as rainbow theme
        sla     a               ; move EAR bit into carry flag (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_mask:equ $+1
        and     0               ; mask only the required colour bits of A (7T)
        endm

        endif

        ifdef LOADER_THEME_SPEEDLOCK
        ;; Searching: black/red
        ;; Pilot/sync:black/red
        ;; Data:      black/blue

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

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        ;; 19T, same as rainbow theme
        rlca                    ; move EAR bit into bit 0 (4T)
        and     1               ; keep only the EAR bit (7T)
        add     a,a             ; shift the EAR bit to make red colour (4)
.border_instruction:
        nop                     ; room for a one-byte instruction (4T)
        endm

        endif

        ifdef LOADER_THEME_LDBYTES
        ;; same colour scheme as the ROM loader
        ;; Searching: red/cyan
        ;; Pilot/sync:red/cyan
        ;; Data:      blue/yellow

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

.theme_t_states:equ 23          ; high, but loader can compensate
        macro border
        ;; 23T
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.colour:equ $+1
        xor     0               ; combine with colour number (7T)
        res     4,a             ; kill EAR bit (8T)
        endm

        endif

        ifdef LOADER_THEME_SETYBDL
        ;; inverse of the ROM loader's colour scheme
        ;; Searching: blue/yellow
        ;; Pilot/sync:blue/yellow
        ;; Data:      red/cyan

        macro set_searching_border
        ;; base colour for pilot border is blue
        ld      a,1
        ld      (.colour),a
        endm

        macro set_pilot_border
        ;; same as searching border
        endm

        macro set_data_border
        ;; base colour for data border is red
        ld      a,2
        ld      (.colour),a
        endm

.theme_t_states:equ 23          ; high, but loader can compensate
        macro border
        ;; 23T
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.colour:equ $+1
        xor     0               ; combine with colour number (7T)
        res     4,a             ; kill EAR bit (8T)
        endm

        endif

        ifdef LOADER_THEME_BLEEPLOAD
        ;; the Firebird Bleepload colour scheme
        ;; Searching: red/yellow
        ;; Pilot/sync:red/yellow
        ;; Data:      blue/cyan

        macro set_searching_border
        ;; base colour for pilot border is red
        ld      a,0xcf          ; SET 1,A
        ld      (.colour_instr),a
        endm

        macro set_pilot_border
        ;; same as searching border
        endm

        macro set_data_border
        ;; base colour for data border is blue
        ld      a,0xc7          ; SET 0,A
        ld      (.colour_instr),a
        endm

.theme_t_states:equ 23          ; high, but loader can compensate
        macro border
        ;; 23T
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
        and     4               ; A=4 (green bit) on high edge (7T)
.colour_instr:equ $+1
        set     0,a             ; set the blue bit (8T)
        endm

        endif

        ifdef LOADER_THEME_BRAZIL
        ;; based on the Brazilian flag, as requested by
        ;; Alessandro Grussu (http://alessandrogrussu.it/)
        ;; Searching: blue/white
        ;; Pilot/sync:blue/white
        ;; Data:      green/yellow

        macro set_searching_border
        ;; on alternate edges, we want to flick the border between
        ;; blue and white.  The colour numbers are 1 for blue and
        ;; 7 for white; or, in binary, 001 and 111.
        ;;
        ;; So if we can arrange to have the accumulator containing
        ;; all zeros or all ones on alternate edges, we simply need
        ;; to mask off bits 1 and 2, giving us 000 or 110, then
        ;; set bit 0, giving 001 or 111
        ld      a,6             ; mask for bits 110
        ld      (.colour_mask),a
        ld      a,0xc7          ; SET 0,A
        ld      (.colour_instr),a
        endm

        macro set_pilot_border
        ;; same as searching border
        endm

        macro set_data_border
        ;; on alternate edges, we want to flick the border between
        ;; green and yellow.  The colour numbers are 4 for green and
        ;; 6 for yellow; or, in binary, 100 and 110.
        ;; 
        ;; Switching between these colours is very similar to the
        ;; strategy for the pilot border, except that we mask off
        ;; only bit 1, giving us 000 or 010, then always set bit 2,
        ;; giving us 100 or 110.
        ld      a,2             ; mask for bits 010
        ld      (.colour_mask),a
        ld      a,0xd7          ; SET 2,A
        ld      (.colour_instr),a
        endm

        ;; the loader expects a theme to run in either 19T or 23T,
        ;; and we have to declare the time required
.theme_t_states:equ 23
        macro border
        ;; 23T
        ;; in order for the logic described in the above comments
        ;; to work, we need the accumulator to contain all zeros or
        ;; all ones on alternate edges.  At the point that this code
        ;; is executed, the accumulator's sign bit is 0 or 1 on
        ;; alternate edges.  It's simple to move this into the
        ;; carry flag using a rotate instruction, so carry will be
        ;; either set or clear on alternate edges.  Following that,
        ;; we can use use SBC A,A to clear the accumulator and then
        ;; subtract the carry flag from it; so if carry was clear, we
        ;; finish with the accumulator containing zero; if it was set
        ;; we finish with it containing -1, aka 255, aka all ones
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
        ;; now, we apply the logic described in the above comments.
        ;; The example values here are the values for the data border,
        ;; but they will be changes by set_searching_border and
        ;; set_data_border to be the colours appropriate for the
        ;; phase that the loader is currently in.
.colour_mask:equ $+1
        and     2               ; mask off the red bit (7T)
.colour_instr:equ $+1
        set     2,a             ; set the green bit (8T)
        endm

        endif

        ifdef LOADER_THEME_JUBILEE
        ;; Searching: black/red
        ;; Pilot/sync:black/blue; black/white with ROM timings
        ;; Data:      red/white/blue

        macro theme_new_byte    ; 33T
        ld      a,(.border_instruction+1) ; place colour into accumulator (13T)
        xor     3                         ; switch between red and blue (7T)
        ld      (.border_instruction+1),a ; store new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle

        macro set_searching_border
        ld      hl,0x02e6       ; AND 2, i.e. black/red
        ld      (.border_instruction),hl
        endm
        macro set_pilot_border
        ld      a,1                   ; blue
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast  ; jump forward if fast timings in use
        ld      a,7                   ; white
.pilot_border_fast:
        endif
        ld      (.border_instruction+1),a
        endm
        macro set_data_border
        ld      hl,0x02f6       ; OR 2, i.e. red/white
        ld      (.border_instruction),hl
        endm

.theme_t_states:equ 23          ; high, but loader can compensate
        macro border
        rla                     ; shift EAR bit into carry (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_instruction:
        nop                     ; room for AND/OR * (7T)
        defb    0               ; room for colour number
        res     4,a             ; kill EAR bit (8T)
        endm

        endif

        ifdef LOADER_THEME_RAINBOW_RIPPLE
        ;; Searching: black/red
        ;; Pilot/sync:black/green; black/white with ROM timings
        ;; Data:      black/rainbow derived from byte counter

        macro set_searching_border
        ;; A is 0 when this macro is executed, so this line
        ;; sets .border_instruction to NOP
        ld      (.border_instruction),a ; NOP
        ld      a,2                     ; mask for red
        ld      (.border_mask),a
        endm

        macro set_pilot_border
        ld      a,4                     ; mask for green
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast    ; jump forward if fast timings in use
        ld      a,7                     ; mask for white
.pilot_border_fast:
        endif
        ld      (.border_mask),a
        endm

        macro set_data_border
        ;; sets border instruction to AND E, combining the
        ;; value in the accumulator with the low byte of the
        ;; byte counter.  Colour thus changes once per eight
        ;; bits, giving a rippling effect
        ld      a,0xa3                     ; AND E
        ld      (.border_instruction),a
        ld      a,7                        ; mask for all colour bits
        ld      (.border_mask),a
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_instruction:
        nop                     ; room for a one-byte instruction (4T)
.border_mask:equ $+1
        and     0               ; mask only the lowest three bits of A (7T)
        endm

        endif

        ifdef LOADER_THEME_FIRE
        ;; Searching: black/red
        ;; Pilot/sync:black/yellow; black/white with ROM timings
        ;; Data:      black/red/yellow
        ;;
        ;; Data border colour changes per byte.

        macro theme_new_byte    ; 33T, one T-state less than sample loop cycle
        ld      a,(.border_colour) ; copy existing colour into accumulator, 13T
        xor     4                  ; switch colour (7T)
        ld      (.border_colour),a ; save new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle

        macro set_searching_border
        ld      a,2           ; red
        ld      (.border_colour),a
        endm
        macro set_pilot_border
        ld      a,6                  ; yellow
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast ; jump forward if fast timings in use
        ld      a,7                  ; white
.pilot_border_fast:
        endif
        ld      (.border_colour),a
        endm
        macro set_data_border
        ld      a,2           ; red; need to reinit in case it was white
        ld      (.border_colour),a
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        sla     a               ; shift EAR bit into carry (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_colour:equ $ + 1
        and     0               ; set colour on high edge (7T)
        endm

        endif

        ifdef LOADER_THEME_ICE
        ;; Searching: blue/cyan
        ;; Pilot/sync:blue/white
        ;; Data:      blue/cyan/white

        macro theme_new_byte    ; 33T, one T-state less than sample loop cycle
        ld      a,(.border_colour) ; copy existing colour into accumulator, 13T
        xor     2                  ; switch colour (7T)
        ld      (.border_colour),a ; save new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle
        ;; no matter what, we always want the blue bit set
        ;; on the border; so rather than adding an extra
        ;; instruction to do it, we can have the loader do
        ;; it at the same time as setting the sound bit
.theme_extra_border_bits:equ 1

        macro set_searching_border
        ld      a,5             ; cyan
        ld      (.border_colour),a
        endm
        macro set_pilot_border
        ld      a,7             ; white
        ld      (.border_colour),a
        endm
        macro set_data_border
        ;; nothing, theme_new_byte does it
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        sla     a               ; shift EAR bit into carry (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_colour:equ $ + 1
        and     0               ; set colour on high edge (7T)
        endm

        endif

        ifdef LOADER_THEME_CHRISTMAS
        ;; Searching: black/red
        ;; Pilot/sync:black/white
        ;; Data:      black/red/green
        ;;
        ;; Data border colour changes per byte.

        macro theme_new_byte    ; 33T, one T-state less than sample loop cycle
        ld      a,(.border_colour) ; copy existing colour into accumulator, 13T
        xor     6                  ; switch colour (7T)
        ld      (.border_colour),a ; save new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle

        macro set_searching_border
        ld      a,2           ; red
        ld      (.border_colour),a
        endm
        macro set_pilot_border
        ld      a,7                  ; white
        ld      (.border_colour),a
        endm
        macro set_data_border
        ld      a,2           ; red
        ld      (.border_colour),a
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        sla     a               ; shift EAR bit into carry (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_colour:equ $ + 1
        and     0               ; set colour on high edge (7T)
        endm

        endif

        ifdef LOADER_THEME_TRINIDAD
        ;; Searching: black/red
        ;; Pilot/sync:black/white
        ;; Data:      black/red/white
        ;;
        ;; Data border colour changes per byte.

        macro theme_new_byte    ; 33T, one T-state less than sample loop cycle
        ld      a,(.border_colour) ; copy existing colour into accumulator, 13T
        xor     5                  ; switch colour (7T)
        ld      (.border_colour),a ; save new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle

        macro set_searching_border
        ld      a,2           ; red
        ld      (.border_colour),a
        endm
        macro set_pilot_border
        ld      a,7                  ; white
        ld      (.border_colour),a
        endm
        macro set_data_border
        ld      a,2           ; red
        ld      (.border_colour),a
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        sla     a               ; shift EAR bit into carry (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_colour:equ $ + 1
        and     0               ; set colour on high edge (7T)
        endm

        endif

        ifdef LOADER_THEME_SPAIN
        ;; Searching: black/red
        ;; Pilot/sync:black/yellow, black/white with ROM timings
        ;; Data:      red/yellow

        macro set_searching_border
        ;; accumulator contains 0 on entry
        ld      h,a                ; zero HL
        ld      l,a
        ld      (.border_instr),hl ; set instructions to no-ops
        ld      a,2                ; mask for red
        ld      (.border_mask),a   ; black/red alternation
        endm

        macro set_pilot_border
        ld      a,6                  ; mask for yellow
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast ; jump forward if fast timings are in use
        ld      a,7                  ; mask for yellow
.pilot_border_fast:
        endif
        ld      (.border_mask),a     ; store the new mask
        endm

        macro set_data_border
        ld      a,4                  ; mask for green
        ld      (.border_mask),a     ; store the new mask
        ld      hl,0x3c3c            ; 2x "INC A"
        ld      (.border_instr),hl   ; set instructions to INC A
        endm

.theme_t_states:equ 23          ; high, but loader can compensate
        macro border
        rla                     ; shift EAR bit into carry (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_mask:equ $ + 1
        and     4               ; A=4 on high edge, 0 on low edge (7T)
.border_instr:
        inc     a               ; A=5 on high edge, 1 on low edge (4T)
        inc     a               ; A=6 on high edge, 2 on low edge (4T)
        endm

        endif

        ifdef LOADER_THEME_ITALY
        ;; Searching: black/red
        ;; Pilot/sync:black/green; black/white with ROM timings
        ;; Data:      red/white/green

        macro theme_new_byte    ; 33T
        ld      a,(.border_instruction+1) ; place colour into accumulator (13T)
        xor     6                         ; switch between red and green (7T)
        ld      (.border_instruction+1),a ; store new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle

        macro set_searching_border
        ld      hl,0x02e6       ; AND 2, i.e. black/red
        ld      (.border_instruction),hl
        endm
        macro set_pilot_border
        ld      a,4                   ; green
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast  ; jump forward if fast timings in use
        ld      a,7                   ; white
.pilot_border_fast:
        endif
        ld      (.border_instruction+1),a
        endm
        macro set_data_border
        ld      hl,0x02f6       ; OR 2, i.e. red/white
        ld      (.border_instruction),hl
        endm

.theme_t_states:equ 23          ; high, but loader can compensate
        macro border
        rla                     ; shift EAR bit into carry (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_instruction:
        nop                     ; room for AND/OR * (7T)
        defb    0               ; room for colour number
        res     4,a             ; kill EAR bit (8T)
        endm

        endif

        ifdef LOADER_THEME_ARGENTINA
        ;; Searching: black/white
        ;; Pilot/sync:black/cyan
        ;; Data:      cyan/white

        macro set_searching_border
        ;; on alternate edges, we want to flick the border between
        ;; black and white.  The colour numbers are 0 for black and
        ;; 7 for white; or, in binary, 000 and 111.
        ;;
        ;; So if we can arrange to have the accumulator containing
        ;; all zeros or all ones on alternate edges, we simply need
        ;; to mask off the lowest three bits using AND.
        ld      hl,0x07e6         ; "AND 7" in little-endian format
        ld      (.border_instr),hl; store the instruction and operand
        endm

        macro set_pilot_border
        ;; we keep the AND instruction set for the searching border,
        ;; but change the mask to 5, for cyan.  So on alternate edges,
        ;; the accumulator after applying the mask will contain 000
        ;; or 101 in binary, i.e. 0 or 5.
        ld      a,5                  ; mask for cyan
        ld      (.border_mask),a     ; store the new mask
        endm

        macro set_data_border
        ;; we keep the cyan mask set for the pilot border, but change
        ;; the instruction to OR.  So if the accumulator starts off
        ;; containing all ones, it stays at all ones; the lowest three
        ;; bits give white.  However, if the accumulator starts off
        ;; containing all zeros, it gets bits 0 and 2 set, giving
        ;; cyan.
        ld      a,0xf6               ; opcode for OR *
        ld      (.border_instr),a    ; set instruction
        endm

        ;; the loader expects a theme to run in either 19T or 23T,
        ;; and we have to declare the time required
.theme_t_states:equ 23
        macro border
        ;; in order for the logic described in the above comments
        ;; to work, we need the accumulator to contain all zeros or
        ;; all ones on alternate edges.  At the point that this code
        ;; is executed, the accumulator's sign bit is 0 or 1 on
        ;; alternate edges.  It's simple to move this into the
        ;; carry flag using a rotate instruction, so carry will be
        ;; either set or clear on alternate edges.  Following that,
        ;; we can use use SBC A,A to clear the accumulator and then
        ;; subtract the carry flag from it; so if carry was clear, we
        ;; finish with the accumulator containing zero; if it was set
        ;; we finish with it containing -1, aka 255, aka all ones
        rla                   ; shift EAR bit into carry (4T)
        sbc     a,a           ; A=0xFF on high edge, 0 on low edge (4T)
        ;; this is the instruction applying the logic described in
        ;; the above comments.
.border_instr:
.border_mask:equ $ + 1
        or      5             ; A=0xFF on high edge, 5 on low edge (7T)
        ;; in the case where we ORed the mask, the accumulator may
        ;; be left containing all ones.  We need to knock out bit 4
        ;; in this case or the OUT instruction that sets the border
        ;; will also set the EAR bit and make more noise than we want
        res     4,a           ; kill EAR bit (8T)
        endm

        endif

        ifdef LOADER_THEME_CANDY
        ;; Searching: black/magenta
        ;; Pilot/sync:black/yellow; black/white with ROM timings
        ;; Data:      black/magenta/yellow

        macro theme_new_byte    ; 33T, one T-state less than sample loop cycle
        ld      a,(.border_colour) ; copy existing colour into accumulator, 13T
        xor     5                  ; switch colour (7T)
        ld      (.border_colour),a ; save new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle

        macro set_searching_border
        ld      a,3           ; magenta
        ld      (.border_colour),a
        endm
        macro set_pilot_border
        ld      a,6                  ; yellow
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast ; jump forward if fast timings in use
        ld      a,7                  ; white
.pilot_border_fast:
        endif
        ld      (.border_colour),a
        endm
        macro set_data_border
        ld      a,3           ; magenta; need to reinit in case it was white
        ld      (.border_colour),a
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        sla     a               ; shift EAR bit into carry (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_colour:equ $ + 1
        and     0               ; set colour on high edge (7T)
        endm

        endif

        ifdef LOADER_THEME_LDBYTESPLUS
        ;; Searching: black/red
        ;; Pilot/sync:black/cyan; black/white with ROM timings
        ;; Data:      black/blue/yellow

        macro theme_new_byte    ; 33T, one T-state less than sample loop cycle
        ld      a,(.border_colour) ; copy existing colour into accumulator, 13T
        xor     7                  ; switch colour (7T)
        ld      (.border_colour),a ; save new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle

        macro set_searching_border
        ld      a,2           ; red
        ld      (.border_colour),a
        endm
        macro set_pilot_border
        ld      a,5                  ; cyan
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast ; jump forward if fast timings in use
        ld      a,7                  ; white
.pilot_border_fast:
        endif
        ld      (.border_colour),a
        endm
        macro set_data_border
        ld      a,1           ; blue
        ld      (.border_colour),a
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        sla     a               ; shift EAR bit into carry (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_colour:equ $ + 1
        and     0               ; set colour on high edge (7T)
        endm

        endif

        ifdef LOADER_THEME_ELIXIRVITAE
        ;; Searching: black/magenta
        ;; Pilot/sync:black/cyan; black/white with ROM timings
        ;; Data:      black/magenta/cyan

        macro theme_new_byte    ; 33T, one T-state less than sample loop cycle
        ld      a,(.border_colour) ; copy existing colour into accumulator, 13T
        xor     6                  ; switch colour (7T)
        ld      (.border_colour),a ; save new colour (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle

        macro set_searching_border
        ld      a,3                  ; magenta
        ld      (.border_colour),a
        endm
        macro set_pilot_border
        ld      a,5                  ; cyan
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast ; jump forward if fast timings in use
        ld      a,7                  ; white
.pilot_border_fast:
        endif
        ld      (.border_colour),a
        endm
        macro set_data_border
        ld      a,3             ; magenta
        ld      (.border_colour),a
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        sla     a               ; shift EAR bit into carry (8T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_colour:equ $ + 1
        and     0               ; set colour on high edge (7T)
        endm

        endif

        ifdef LOADER_THEME_VERSA
        ;; Searching: solid cyan with fine blue lines
        ;; Pilot/sync:solid white with fine blue lines
        ;; Data:      solid blue with fine cyan/white lines

        macro theme_new_byte
        ;; this switches the line colour between cyan and white
        ;; using the byte counter as a seed.  It's a silly dance,
        ;; but it consumes 33T, nearly the same as one pass around
        ;; the sample loop
        ld      a,e                ; fetch low byte of byte counter (4T)
        sla     a                  ; shift it left so LSb is in bit 1 (8T)
        or      13                 ; set bits 0, 2 and 4 (7T)
        and     15                 ; keep only the colour and sound bits (7T)
        ld      (.line_colour),a   ; save it (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ 34 ; close enough to one pass around sample loop

        macro set_searching_border
        ld      a,9                  ; blue lines (with sound bit)
        ld      (.line_colour),a
        ld      a,5
        ld      (.background_colour),a ; on cyan background
        endm
        macro set_pilot_border
        ld      a,7
        ld      (.background_colour),a ; white background
        endm
        macro set_data_border
        ld      a,1
        ld      (.background_colour),a ; blue background
        endm

.theme_t_states:equ 25
        macro   border
.line_colour:equ $ + 1
        ld      a,0             ; load accumulator with line colour (7T)
        out     (254),a         ; set border briefly (11T)
.background_colour:equ $ + 1
        ld      a,0             ; load accumulator with background colour (7T)
        endm

        endif

        ifdef LOADER_THEME_RAINBOW_VERSA
        ;; Searching: solid red with fine black lines
        ;; Pilot/sync:solid green (ROM timings: white) with fine black lines
        ;; Data:      solid black with fine rainbow lines

        macro theme_new_byte
        ;; this sets .line_colour to a value derived from the byte
        ;; counter.  It consumes 32T, close enough to one pass
        ;; around the sample loop
        ld      a,e                ; fetch low byte of byte counter (4T)
        and     7                  ; isolate colour bits (7T)
        set     3,a                ; add sound bit (8T)
        ld      (.line_colour),a   ; save (13T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ 34 ; close enough

        macro set_searching_border
        ld      a,8                  ; black lines (with sound bit)
        ld      (.line_colour),a
        ld      a,2
        ld      (.background_colour),a ; on red background
        endm
        macro set_pilot_border
        ld      a,4                     ; mask for green
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast    ; jump forward if fast timings in use
        ld      a,7                     ; mask for white
.pilot_border_fast:
        endif
        ld      (.background_colour),a ; green or white background
        endm
        macro set_data_border
        xor     a                      ; zero accumulator
        ld      (.background_colour),a ; black background
        endm

.theme_t_states:equ 25
        macro   border
.line_colour:equ $ + 1
        ld      a,0             ; load accumulator with line colour (7T)
        out     (254),a         ; set border briefly (11T)
.background_colour:equ $ + 1
        ld      a,0             ; load accumulator with background colour (7T)
        endm

        endif

        ifdef LOADER_THEME_CYCLE_VERSA
        ;; Searching: solid black with fine red lines
        ;; Pilot/sync:solid black with fine green lines (white for ROM timings)
        ;; Data:      solid colour with fine black or white lines

        macro theme_new_byte
        ;; this sets .background_colour to a value derived from the
        ;; byte counter, and .line_colour to complementary black or
        ;; white.  It consumes 69T, a fraction over two passes
        ;; around the sampling loop
        ld      a,d                ; fetch high byte of byte counter (4T)
        and     7                  ; isolate colour bits (7T)
        ld      (.background_colour),a; save (13T)
        cp      4                  ; set carry if 3 (magenta) or below (7T)
        sbc     a,a                ; accumulator now 0xFF if blk/blu/red/mgt,4T
        and     7                  ; isolate colour bits (7T)
        or      8                  ; add sound bit (7T)
        ld      (.line_colour),a   ; save as line colour (13T)
        ld      a,(hl)             ; waste 7T to round up to 69T
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ 69

        macro set_searching_border
        ;; accumulator is already empty when this is called
        ld      a,10                   ; red lines (with sound bit)
        ld      (.line_colour),a
        xor     a
        ld      (.background_colour),a ; on red background
        endm
        macro set_pilot_border
        ld      a,12                   ; green lines (with sound bit)
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast   ; jump forward if fast timings in use
        or      7                      ; white lines
.pilot_border_fast:
        endif
        ld      (.line_colour),a
        endm
        macro set_data_border
        ;; nothing, .theme_new_byte does it all
        endm

.theme_t_states:equ 25
        macro   border
.line_colour:equ $ + 1
        ld      a,0             ; load accumulator with line colour (7T)
        out     (254),a         ; set border briefly (11T)
.background_colour:equ $ + 1
        ld      a,0             ; load accumulator with background colour (7T)
        endm

        endif

        ;; this is the default, we use it if no other theme is
        ;; selected
        ifndef .theme_t_states
        ifndef LOADER_THEME_RAINBOW
LOADER_THEME_RAINBOW:   equ 1
        endif
        endif
        ifdef LOADER_THEME_RAINBOW
        ;; Searching: black/red
        ;; Pilot/sync:black/green; black/white with ROM timings
        ;; Data:      black/rainbow derived from bits being loaded

        macro set_searching_border
        ;; A is 0 when this macro is executed, so this line
        ;; sets .border_instruction to NOP
        ld      (.border_instruction),a ; NOP
        ld      a,2                     ; mask for red
        ld      (.border_mask),a
        endm

        macro set_pilot_border
        ld      a,4                     ; mask for green
        ifdef   LOADER_SUPPORT_ROM_TIMINGS
        jr      c,.pilot_border_fast    ; jump forward if fast timings in use
        ld      a,7                     ; mask for white
.pilot_border_fast:
        endif
        ld      (.border_mask),a
        endm

        macro set_data_border
        ;; sets border instruction to AND C, combining the
        ;; value in the accumulator with the bits currently
        ;; being loaded
        ld      a,0xa1                     ; AND C
        ld      (.border_instruction),a
        ld      a,7                        ; mask for all colour bits
        ld      (.border_mask),a
        endm

.theme_t_states:equ 19          ; "standard" theme overhead
        macro border
        rla                     ; move EAR bit into carry flag (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
.border_instruction:
        nop                     ; room for a one-byte instruction (4T)
.border_mask:equ $+1
        and     0               ; mask only the lowest three bits of A (7T)
        endm

        endif

        if      .theme_t_states > 25
        .error  Theme imposes too much overhead
        endif
