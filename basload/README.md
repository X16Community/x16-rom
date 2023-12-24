# BASLOAD ROM version

## Introduction

The purpose of BASLOAD is to make BASIC programming on the Commander X16 more convenient.

This is primarily done by using named labels instead of line numbers, and by supporting
long variable names.

The BASIC source code is stored as plain text files on the SD card. BASLOAD converts the source code
into a runnable program.


## Source code formatting

### No line numbers

Source code written for BASLOAD do not contain line numbers. Instead, named labels are decleared
as targets for BASIC commands that need a line number, for instance GOTO and GOSUB.


### Same BASIC commands

BASLOAD supports the standard BASIC commands of the built-in Commander X16 BASIC.


### Whitespace

The following characters are recognized as whitespace:

- Blank space (PETSCII 32)
- Shift + blank space (PETSCII 160)
- Tab (PETSCII 9)


## Identifiers

### General

BASIC commands, labels and variables are commonly called "identifiers" in these
instructions.

All identifiers must begin with a letter, any of A to Z.

The subsequent characters may be letters (A to Z), digits (0 to 9) or decimal points.

An identifier may be at most 64 characters long.

Identifiers are not case-sensitive.

Unless two adjacent identifiers are separated by a character outside the
group of characters allowed in identifier names, the identifiers must be separated
by whitespace.

Example:

```
PRINTME  :REM A variable or label named PRINTME, will not PRINT the value of ME
PRINT ME :REM PRINTs the value of ME
```

### Labels

Labels must be valid identifiers as set out above.

A label declaration occurs at the beginning of a line. There may, however, be whitespace before it.
A label declaration ends with a colon.

You refer to a label in the source code just by typing its name without the colon.

Example:

```
LOOP:
    PRINT "HELLO, WORLD!"
    GOTO LOOP
```

A label may not be exactly the same as any BASIC command or reserved word, or exactly
the same as any other previously decleared identifier.


### Variables

Variables must be valid identifier name as set out above.

A variable is automatically decleared when found in the source code the first time.

As in standard BASIC, a $ after the variable name specififies it as a string, and
a % specifies that it is an integer.

A variable name may not be exactly the same as any BASIC command or reserved word, or
exacly the same as any other previously decleared identifier.

Example:

```
HELLO.WORLD.GREETING$ = "Hello, world!"
PRINT HELLO.WORLD.GREETING$
```

## BASLOAD options

The conversion from source code to runnable program can be controlled by
options stored in the source code.

An option must be at the beginning of a line, but there may be
whitespace before it.

All options start with a hash sign (#) followed by the name of the option.

Some options require an argument. The option name and the argument must be
separated by whitespace.

If the argument is a decimal number, you type it in as is.

If the argument is a string it may optionally be enclosed in double quotes. If so, the string
may include whitespace characters.

The following options are supported:

- \## An alternative comment never outputted to the runnable code.
- \#REM 0|1, turns off (0) or on (1) output of REM statements ti the runnable code. Default is off.
- \#INCLUDE "filename" includes the content of another source file. 
- \#AUTONUM 1..100, sets the number of steps the line number is advanced for each line in the runnable code.
- \#CONTROLCODES 0|1 turns off (0) or on (1) support for named PETSCII control characters, for instance {WHITE} or {CLEAR}.
- \#SYMFILE "filename" writes a symbol table for debugging purposes to the specified file name. Add @: before the file name if you want to overwrite an existing file. This option may only occur once in the source code, before any BASIC code has been outputted.

## Running BASLOAD

TODO