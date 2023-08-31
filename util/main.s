.import util_menu
.import util_control
.import util_hexedit

.segment "JMPTBL"
    jmp util_menu       ; $C000
    jmp util_control    ; $C003
    jmp util_hexedit    ; $C006
