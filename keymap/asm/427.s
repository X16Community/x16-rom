; Commander X16 PETSCII/ISO Keyboard Table
; ***this file is auto-generated!***
;
; Name:   Lithuanian IBM
; Locale: lt-LT
; KLID:   427

.segment "KBDMETA"

	.byte "LT-LT", 0, 0, 0, 0, 0, 0, 0, 0, 0
	.word kbtab_427

.segment "KBDTABLES"

kbtab_427:
	.incbin "asm/427.bin.lzsa"

; PETSCII
; ~~~~~~~
; C64 keyboard regressions:
;   chars: "#$%&'<>@QQWWXX^£π←"
;   graph: '\xa4\xa6\xa8\xa9\xba' <--- *** THIS IS BAD! ***
; Keys outside of PETSCII:
;   '\_{|}~ĄąČčĖėĘęĮįŠšŪūŲųŽž“”€'

; ISO
; ~~~
; Keys outside of ISO-8859-15 (and -16):
;   'ĖėĮįŪūŲų“'
; Non-reachable ISO-8859-15:
;   '#$%&'*<>@QWX^qwx ¡¢£¥§©ª«¬­®¯°±²³µ¶·¹º»ŒœŸ¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþ'

