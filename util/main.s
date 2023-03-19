.import util_menu
.import util_control

.segment "JMPTBL"
    jmp util_menu       ; $C000
    jmp util_control    ; $C003

