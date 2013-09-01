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

        ifdef LOADER_THEME_JUBILEE
        ;; Searching: black/red
        ;; Pilot/sync:black/white
        ;; Data:      red/white/blue

        macro theme_new_byte    ; 34T, exactly one sample loop pass
        ;; this is a roundabout way of switching the colour number
        ;; between 1 and 2 in 34 T-states
        ld      a,iyl           ; copy previous colour number (8T)
        and     255             ; waste some time (7T)
        cpl                     ; invert accumulator (4T)
        and     3               ; keep only thw lowest two bits (7T)
        ld      iyl,a           ; store new colour number (8T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ .read_edge_loop_t_states ; close enough to 1 cycle
LOADER_RESTORE_IYL:equ 1

        macro set_searching_border
        ld      a,0xa5          ; opcode for AND L/IXL/IYL
        ld      (.border_instruction),a
        ld      iyl,2           ; red
        endm
        macro set_pilot_border
        ld      iyl,7           ; white
        endm
        macro set_data_border
        ld      a,0xb5          ; opcode for OR L/IXL/IYL
        ld      (.border_instruction),a
        ld      iyl,2           ; red
        endm

.theme_t_states:equ 23          ; high, but loader can compensate
        macro border
        rla                     ; shift EAR bit into carry (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
        defb    0xfd            ; next instruction uses IY
.border_instruction:
        nop                     ; room for AND/OR IYL (8T)
        and     7               ; keep only colour bits (7T)
        endm

        endif

        ifdef LOADER_THEME_RAINBOW
        ;; Searching: black/red
        ;; Pilot/sync:black/green
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

        ifdef LOADER_THEME_RAINBOW_RIPPLE
        ;; Searching: black/red
        ;; Pilot/sync:black/green
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
        ;; Pilot/sync:black/yellow
        ;; Data:      black/red/yellow

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
        ld      a,6           ; yellow
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

        ;; the VERSA themes are inspired by Peter Knight/GoingDigital's
        ;; Versaload.  Its border effect is a solid colour with thin
        ;; lines.
        ;;
        ;; The themes use separate code for the searching/pilot and
        ;; data borders.  Each is five bytes and must be installed
        ;; in the set_*_border macros
        macro   versa_install_searching_border
        ;; we need to install the following, 20T:
        ;sla     a   0xCB 0x27   ; shift EAR bit into carry (8T)
        ;sbc     a,a 0x9F        ; A=0xFF on high edge, 0 on low edge (4T)
        ;and     iyl 0xFD 0xA5   ; set colour on high edge (8T)
        ld      hl,0x27cb
        ld      (.border_instructions),hl
        ld      hl,0xfd9f
        ld      (.border_instructions+2),hl
        ld      a,0xa5
        ld      (.border_instructions+4),a
        endm
        macro   versa_install_data_border
        ;; we need to install the following, 23T:
        ;ld      a,iyl   FD 7D ; transfer colour from IYL into A (8T)
        ;out     (254),a D3 FE ; briefly set border (11T)
        ;xor     a       AF    ; clear accumulator (4T)
        ld      hl,0x7dfd
        ld      (.border_instructions),hl
        ld      hl,0xfed3
        ld      (.border_instructions+2),hl
        ld      a,0xaf
        ld      (.border_instructions+4),a
        endm
        macro   versa_border
.theme_t_states:equ 23 ; though 20 on pilot
        macro   border
.border_instructions:
        ds      5      ; space for five bytes of code
        endm
        endm

        ifdef LOADER_THEME_VERSA
        ;; Searching: blue/cyan
        ;; Pilot/sync:blue/white
        ;; Data:      solid blue with fine cyan/white

        macro theme_new_byte
        ;; this switches IYL between cyan and white using the
        ;; byte counter as a seed.  It's a silly dance, but it
        ;; consumes 34T, precisely the same as one pass around
        ;; the sample loop
        ld      a,e                ; fetch low byte of byte counter (4T)
        sla     a                  ; shift it left so LSb is in bit 1 (8T)
        or      13                 ; set bits 0, 2 and 4 (7T)
        and     15                 ; keep only the colour and sound bits (7T)
        ld      iyl,a              ; save in IYL (8T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ 34
LOADER_RESTORE_IYL:equ 1
        ;; no matter what, we always want the blue bit set
        ;; on the border; so rather than adding an extra
        ;; instruction to do it, we can have the loader do
        ;; it at the same time as setting the sound bit
.theme_extra_border_bits:equ 1

        macro set_searching_border
        versa_install_searching_border
        ld      iyl,5             ; blue/cyan during search
        endm
        macro set_pilot_border
        ld      iyl,7             ; blue/white during sync
        endm
        macro set_data_border
        versa_install_data_border
        endm

        versa_border

        endif

        ifdef LOADER_THEME_RAINBOW_VERSA
        ;; Searching: black/red
        ;; Pilot/sync:black/green
        ;; Data:      solid black with fine rainbow lines

        macro theme_new_byte
        ;; this loads IYL with colour bits taken from the byte
        ;; counter.  It consumes 34T, precisely the same as one
        ;; pass around the sample loop
        and     iyl                ; waste 8T
        ld      a,e                ; fetch low byte of byte counter (4T)
        and     7                  ; isolate colour bits (7T)
        or      8                  ; add sound bit (7T)
        ld      iyl,a              ; save in IYL (8T)
        endm
.theme_new_byte:equ 1
.theme_new_byte_overhead:equ 34
LOADER_RESTORE_IYL:equ 1

        macro set_searching_border
        versa_install_searching_border
        ld      iyl,2             ; black/red during search
        endm
        macro set_pilot_border
        ld      iyl,4             ; black/green during sync
        endm
        macro set_data_border
        versa_install_data_border
        endm

        versa_border

        endif

        ifdef LOADER_THEME_CANDY
        ;; Searching: black/magenta
        ;; Pilot/sync:black/yellow
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
        ld      a,6           ; yellow
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

        ifndef .theme_t_states
        .error  No theme selected
        endif
        if      .theme_t_states > 25
        .error  Theme imposes too much overhead
        endif
