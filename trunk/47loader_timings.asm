        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; the standard 47loader timings are 543T for a zero half-pulse
        ;; and 1086T for a one half-pulse.  Define LOADER_EXTRA_CYCLES
        ;; to add extra 34T cycles.  So for timings of 713T/1426T,
        ;; define LOADER_EXTRA_CYCLES as 5: 543 + (5 * 34) == 713.  If
        ;; you're feeling brave, you can even try subtracting cycles:
        ;; setting LOADER_EXTRA_CYCLES to -2 gives timings 475T/950T

        ifndef LOADER_EXTRA_CYCLES

        ;; some friendly aliases for various timings
        ifdef  LOADER_SPEED_FAST
LOADER_EXTRA_CYCLES:equ -2
        endif
        ifdef  LOADER_SPEED_EAGER
LOADER_EXTRA_CYCLES:equ -1
        endif
        ifdef  LOADER_SPEED_STANDARD
LOADER_EXTRA_CYCLES:equ 0
        endif
        ifdef  LOADER_SPEED_CAUTIOUS
LOADER_EXTRA_CYCLES:equ 2
        endif
        ifdef  LOADER_SPEED_CONSERVATIVE
LOADER_EXTRA_CYCLES:equ 4
        endif
        ifdef  LOADER_SPEED_SPEEDLOCK7
LOADER_EXTRA_CYCLES:equ 5
        endif
        ifdef  LOADER_SPEED_ROM
        ifndef LOADER_SUPPORT_ROM_TIMINGS
LOADER_SUPPORT_ROM_TIMINGS:equ 1
        endif
        endif

        ;; if none of the above...
        ifndef LOADER_EXTRA_CYCLES
LOADER_EXTRA_CYCLES:equ 0
        endif
        endif

        ;; average iterations of sampling loop to detect a
        ;; _single_ pulse.  Determined empirically
.pilot_pulse_rom_avg:equ 52
.pilot_pulse_fast_avg:equ 39
.zero_pulse_avg:equ 5 + LOADER_EXTRA_CYCLES
.one_pulse_avg:equ 20 + (2 * LOADER_EXTRA_CYCLES)
.zero_pulse_rom_avg:equ 14
.one_pulse_rom_avg:equ 39

        ;; min/max iterations of sampling loop to detect a pilot pulse
.pilot_pulse_min:equ .pilot_pulse_fast_avg * 70 / 100 ; 70%
.pilot_pulse_max:equ .pilot_pulse_rom_avg * 120 / 100 ; 120%
        ;; max iterations of sampling loop to detect a 1 pulse
.one_pulse_max:equ .one_pulse_avg * 150 / 100; 150%, also very generous
.one_pulse_rom_max:equ .one_pulse_rom_avg * 150 / 100; 150%, also very generous

        ;; the values that the .read_edge loop counter starts at
        ;; when looking for pilot and data pulses.  This ensures
        ;; that .read_edge never finds an edge that is longer
        ;; than the maximum permitted.  2x because we look at both
        ;; the low and high pulses
.timing_constant_pilot:equ 256-(2 * .pilot_pulse_max)
.timing_constant_data:equ 256-(2 * .one_pulse_max)
.timing_constant_rom_data:equ 256-(2 * .one_pulse_rom_max)

        ;; when reading bits, this is the value from two passes
        ;; around .read_edge used as the cutoff between zero
        ;; pulses and one pulses.  It's slightly lower than bang
        ;; in the middle of a zero and one pulse to account for
        ;; the first bit in a byte requiring fewer cycles around
        ;; the sampling loop due to overhead
.timing_constant_threshold:equ .timing_constant_data+.zero_pulse_avg+.one_pulse_avg;-5
.timing_constant_rom_threshold:equ .timing_constant_rom_data+.zero_pulse_rom_avg+.one_pulse_rom_avg;-5

        ;; this is the value from two passes around .read_edge used as
        ;; the cutoff to decide whether we have standard or fast pilot
        ;; pulses
.pilot_detection_threshold:equ .timing_constant_pilot+.pilot_pulse_rom_avg+.pilot_pulse_fast_avg

        ;; when reading the first bit of a new byte, the
        ;; timing constant is adjusted to account for the
        ;; overhead of storing the previous byte etc.  This
        ;; is the number of cycles around the sampling loop
        ;; that is "added" to account for this overhead
.new_byte_overhead:defl 3

        ;; themes and integration points may impose extra overhead
.new_byte_extra_t_states:defl 0

        ;; if a theme wants to perform some setup prior to a new
        ;; byte being read, it must be declared
        ifdef .theme_new_byte
        ifndef .theme_new_byte_overhead
        .error .theme_new_byte T-state overhead must be declared as .theme_new_byte_overhead
        endif
.new_byte_extra_t_states:defl .new_byte_extra_t_states + .theme_new_byte_overhead
        endif

.new_byte_overhead:defl .new_byte_overhead + (.new_byte_extra_t_states / .read_edge_loop_t_states)
