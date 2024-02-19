; Commander X16 KERNAL
;
; Font library

.include "regs.inc"
.include "mac.inc"
.include "fonts.inc"
.include "banks.inc"

.import kvswitch_tmp1
.import kvswitch_tmp2

ram_bank = 0

.import FB_init
.import FB_get_info
.import FB_set_palette
.import FB_cursor_position
.import FB_cursor_next_line
.import FB_get_pixel
.import FB_get_pixels
.import FB_set_pixel
.import FB_set_pixels
.import FB_set_8_pixels
.import FB_set_8_pixels_opaque
.import FB_fill_pixels
.import FB_filter_pixels
.import FB_move_pixels
.import col1, col2, col_bg

.import baselineOffset, curSetWidth, curHeight, cardDataPntr, currentMode
.import windowTop, windowBottom, leftMargin, rightMargin, fontTemp1, fontTemp2
.import PrvCharWidth, FontTVar1, FontTVar2, FontTVar3, FontTVar4
.importzp curIndexTable


.segment "GRAPH"

.include "fonts2.s"
.include "fonts3.s"
.include "fonts4.s"
.include "fonts4b.s"
.include "conio1.s"
.include "conio3b.s"
.include "sysfont.s"

