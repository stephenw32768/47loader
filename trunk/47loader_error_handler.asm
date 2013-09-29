        ;; 47loader (c) Stephen Williams 2013
        ;; See LICENSE for distribution terms

        ;; little snippet of code that can be used to handle
        ;; the error conditions.  Divert code here if the loader
        ;; returns carry clear

        ifndef  LOADER_DIE_ON_ERROR

        ;; if loader returned zero set, BREAK was pressed
        ifndef  LOADER_IGNORE_BREAK
        jp      z,0x1b7b        ; ROM routine indicating BREAK (code L)
        endif
        ;; otherwise, there was a tape error
        rst     8               ; error restart
        defb    26              ; "R Tape loading error"

        endif