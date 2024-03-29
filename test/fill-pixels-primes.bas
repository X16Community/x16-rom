10 REM COMPUTE NUMBER OF PRIMES BELOW N USING SIEVE OF ERATOSTHENES.
20:
30 REM NUMBER SIEVE IS STORED IN VIDEO RAM, USING SCREEN MODE $80, CAUSING
40 REM ITS OPERATION TO BE VISIBLE IN REAL TIME.
41:
42 REM USE SPACE KEY TO PAUSE, ESC TO TERMINATE.
43 REM ADJUST SPEED ON LINE 460.
50:
60 REM HARD LIMIT $1F9BF (129.471) (STOPS DUE TO VERA HARDWARE)
70 REM SOFT LIMIT $1AFFF (110.592) (STOPS DUE TO TEXT MODE)
80 REM SCREEN LIMIT $12BFF (76.800)
90:
100 REM USING 100.000 BYTES, TO COMPARE AGAINST KNOWN VALUE (9.592)
110 REM NOTE THAT THIS WILL USE SOME BYTES OUTSIDE SCREEN AREA.
120:
130 REM USING FB-FILL-PIXELS MACHINE LANGUAGE FUNCTION TO SPEED UP THE CODE.
140:
150 SIZE = 100000
160 LIM = SQR(SIZE)
170 SCREEN $80       : REM 320 X 240
180:
190 REM THE SCREEN COMMAND SETS $00000 TO $12BFF TO $01 (VISIBLE PIXELS ONLY)
200 REM SET $12C00 TO $1869F (100.000) TO $01 USING FB-FILL-PIXELS
210:
210 REM SET VRAM ADDRESS (OFFSET)
220 REM AND FILL PIXELS USING FB-FILL-PIXELS (FSTP-CNT-FCOLR)
230 OFFSET = $12C00
240 FSTP = 1
250 CNT = 100000 - $12C00
260 FCOLR = 1
270 GOSUB 2000
280:
290 REM ITERATE I FROM 2 TO LIMIT
300 FOR I = 2 TO LIM
301 LOCATE 4,1
302 PRINT I
310 TMP = VPEEK(0,I)
320 IF TMP <> 1 GOTO 530
330:
340 REM PRIME FOUND, CLEAR FACTORS
350 VPOKE 0, I, 4  :  REM VISUALIZE CURRENT PRIME
360:
370 REM SET VRAM ADDRESS (OFFSET)
380 REM AND FILL PIXELS USING FB-FILL-PIXELS (FSTP-CNT-FCOLR)
390 OFFSET = I + I
400 FSTP = I
410 CNT = (SIZE / FSTP) - 1
420 FCOLR = 2
430 GOSUB 2000
440:
450 REM DELAY LOOP, CAN BE SKIPPED
REM 460 FOR D = 0 TO 2000: NEXT D
470:
480 REM DRAW PIXELS AGAIN IN A DIFFERENT COLOR, TO HIGHLIGHT THE NEWEST PIXELS
490 FCOLR = 3
500 GOSUB 2000
501:
502 REM  HANDLE KEYBOARD PRESS (SPACE/OTHER)
503 GET TMP$: IF TMP$="" THEN 510
504 IF ASC(TMP$) <> 32 THEN GOTO 600 :  REM  NOT SPACE
505 PRINT "PAUSE..."
506 GET TMP$: IF TMP$="" THEN 506 :  REM  WAIT FOR KEY
507 CLS
510:
520 VPOKE 0, I, 1  :  REM REVERT CURRENT PRIME TO WHITE
530 NEXT I
540:
550 REM COUNT RESULT, OPTIMIZED USING MACHINE CODE
560 GOSUB 3000  :  REM LOAD MACHINE CODE PROGRAM
570 REM USR(0) RUNS MACHINE CODE PROGRAM WHICH COUNTS PRIMES AND RETURNS RESULT
580 SUM = USR(0)
590 PRINT SUM
595 IF SUM=9592 THEN PRINT "SUM IS CORRECT"
596 IF SUM<>9592 THEN PRINT "SUM IS NOT CORRECT, EXPECTED 9592"
600 PRINT "PRESS ANY KEY TO CONTINUE..."
610 GET TMP$: IF TMP$="" THEN 610 :  REM  WAIT FOR KEY
620 SCREEN 0
630 END
997:
998:
999:
1000 REM SET CURSOR TO UPPER LEFT PLUS OFFSET ($00000-$1FFFF)
1010 TMP = INT(OFFSET/65536)
1020 POKE $9F22, TMP + $10  : REM H-0-INCREMENT 1
1030 OFFSET = OFFSET - TMP * 65536
1040 TMP = INT(OFFSET/256)
1050 POKE $9F21, TMP  : REM M-0
1060 POKE $9F20, OFFSET - TMP * 256  : REM L-0
1070 RETURN
1997:
1998:
1999:
2000 REM CURSOR-POSITION(0-0) - FB-FILL-PIXELS(CNT-FSTP-FCOLR)
2010 GOSUB 1000
2020 POKE $02, CNT - INT(CNT/256)*256
2030 POKE $03, INT(CNT/256)
2040 POKE $04, FSTP - INT(FSTP/256)*256
2050 POKE $05, INT(FSTP/256)
2060 POKE $030C, FCOLR
2070 SYS $FF17
2080 RETURN
2997:
2998:
2999:
3000 REM LOAD PROGRAM THAT COUNTS WHITE PIXELS FROM 2 TO 100.000 IN VRAM
3010:
3020 REM PROGRAM IS LOADED INTO $0400
3020 REM PROGRAM CAN BE EXECUTED USING USR(0)
3030:
3040 REM PROGRAM:
3050:
3060                  :  REM  ; SET VERA POINTER TO 2 INCR 1
3070:
3080 POKE $0400, $A9  :  REM  LDA #$10 ; SET INCREMENT TO 1
3090 POKE $0401, $10
3100:
3110 POKE $0402, $8D  :  REM  STA VERA-ADDRX-H ; ($9F22)
3120 POKE $0403, $22
3130 POKE $0404, $9F
3140:
3150 POKE $0405, $9C  :  REM  STZ VERA-ADDRX-M ; ($9F21)
3160 POKE $0406, $21
3170 POKE $0407, $9F
3180:
3190 POKE $0408, $A9  :  REM  LDA #$02 ; SET ADDR-L TO 2
3200 POKE $0409, $02
3210:
3220 POKE $040A, $8D  :  REM  STA VERA-ADDRX-L ; ($9F20)
3230 POKE $040B, $20
3240 POKE $040C, $9F
3250:
3260                  :  REM  ; INITIALIZE DOWNCOUNTER
3270                  :  REM  ; LIMIT -> 100.000 - 2 -> 0X1869E
3280                  :  REM  ; INCREMENT M AND H DUE TO DEC/BNE
3290                  :  REM  ; SET COUNTER-H TO (1 + 1)
3300:
3310 POKE $040D, $85  :  REM  STA COUNTER-H ; (ZERO PAGE, $22)
3320 POKE $040E, $22
3330:
3340 POKE $040F, $A0  :  REM  LDY #($86 + 1) ; COUNTER-M
3350 POKE $0410, $87  :  REM                 ; (+ 1 DUE TO DEC/BNE)
3360:
3370 POKE $0411, $A2  :  REM  LDX #$9E ; COUNTER-L
3380 POKE $0412, $9E
3390:
3400 POKE $0413, $64  :  REM  STZ RESULT-L ; (ZERO PAGE, $23)
3410 POKE $0414, $23
3420:
3430 POKE $0415, $64  :  REM  STZ RESULT-H ; (ZERO PAGE, $24)
3440 POKE $0416, $24
3450:
3460 POKE $0417, $3A  :  REM  DEC ; COMPARATOR VALUE (LDA #1)
3470:
3478:
3479:
3480                  :  REM  LOOP:
3490:
3500 POKE $0418, $CD  :  REM  CMP VERA-DATA0 ; ($9F23)
3510 POKE $0419, $23
3520 POKE $041A, $9F
3530:
3540 POKE $041B, $D0  :  REM  BNE + ; ($0423)
3550 POKE $041C, $06
3560:
3570 POKE $041D, $E6  :  REM  INC RESULT-L ; ($23)
3580 POKE $041E, $23
3590:
3600 POKE $041F, $D0  :  REM  BNE + ($0423)
3610 POKE $0420, $02
3620:
3630 POKE $0421, $E6  :  REM  INC RESULT-H ; ($24)
3640 POKE $0422, $24
3650:
3660                  :  REM  +:
3670:
3680 POKE $0423, $CA  :  REM  DEX
3690:
3700 POKE $0424, $D0  :  REM  BNE LOOP ; ($0418)
3710 POKE $0425, $F2
3720:
3730 POKE $0426, $88  :  REM  DEY
3740:
3750 POKE $0427, $D0  :  REM  BNE LOOP ; ($0418)
3760 POKE $0428, $EF
3770:
3780 POKE $0429, $C6  :  REM  DEC COUNTER-H ; ($22)
3790 POKE $042A, $22
3800:
3810 POKE $042B, $D0  :  REM  BNE LOOP
3820 POKE $042C, $EB
3830:
3838:
3839:
3840 POKE $042D, $A4  :  REM  LDY RESULT-L ($23)
3850 POKE $042E, $23
3860:
3870 POKE $042F, $A5  :  REM  LDA RESULT-H ($24)
3880 POKE $0430, $24
3890:
3900                  :  REM  ; CONVERT SIGNED INTEGER (-32768 TO 32767)
3910                  :  REM  ; TO FLOAT IN FACC
3920:
3930 POKE $0431, $20  :  REM  JSR GIVAYF ; ($FE03)
3940 POKE $0432, $03
3950 POKE $0433, $FE
3960:
3970 POKE $0434, $60  :  REM  RTS
3980:
3988:
3989:
3990 REM DEFINE USR FUNCTION (POINTER AT $0311-$0312)
4000 REM SET IT TO $0400
4010:
4020 POKE $0311, $00
4030 POKE $0312, $04
4040:
4050 RETURN
