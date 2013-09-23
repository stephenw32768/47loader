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
        ld      a,7             ; white
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

        ifdef LOADER_THEME_SPAIN
        ;; Searching: red/white
        ;; Pilot/sync:yellow/white
        ;; Data:      red/yellow

        ;; no matter what, we always want the red bit set
        ;; on the border; so rather than adding an extra
        ;; instruction to do it, we can have the loader do
        ;; it at the same time as setting the sound bit
.theme_extra_border_bits:equ 2

        macro set_searching_border
        ld      hl,0x00f6                ; OR 0, i.e. a 7T no-op
        ld      (.border_instruction),hl
        endm

        macro set_pilot_border
        ld      a,4                      ; border instr becomes OR 4,
        ld      (.border_instruction+1),a; setting the green bit for yellow
        endm

        macro set_data_border
        ld      a,0xe6                   ; border inst becomes AND 4
        ld      (.border_instruction),a
        endm

.theme_t_states:equ 23          ; high, but loader can compensate
        macro border
        rla                     ; move EAR bit into bit 0 (4T)
        sbc     a,a             ; A=0xFF on high edge, 0 on low edge (4T)
        res     4,a             ; kill EAR bit (8T)
.border_instruction:
        and     0               ; combine with colour number (7T)
        endm

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
        ;; Pilot/sync:solid green with fine black lines
        ;; Data:      solid black with fine rainbow lines

        macro theme_new_byte
        ;; this sets .line_colour to a value derived from the byte
        ;; counter.  It consumes 32T, close enough to one pass
        ;; around the sample loop
        ld      a,e                ; fetch low byte of byte counter (4T)
        and     7                  ; isolate colour bits (7T)
        set     4,a                ; add sound bit (8T)
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
        ld      a,4
        ld      (.background_colour),a ; green background
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
        ;; Pilot/sync:solid black with fine green lines
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
        ld      a,12
        ld      (.line_colour),a       ; green lines
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

        ifndef .theme_t_states
        .error  No theme selected
        endif
        if      .theme_t_states > 25
        .error  Theme imposes too much overhead
        endif