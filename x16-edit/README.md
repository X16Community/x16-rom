# X16 Edit

X16 Edit is a simple text editor for the Commander X16 platform inspired by GNU Nano.

The program's primary design goal is to handle large text files with good performance. 
The text buffer is stored in banked RAM (512 KB, expandable to 2 MB).

# Building

The program is written in 65c02 assembly for the ca65 compiler. To build the project
you also need the lzsa compression and Makefile utilities.

Currently, there are three build targets.

* **make** or **make ram** builds the standard version that is loaded into RAM and
  started in the same way as a BASIC program.

* **make hiram** builds a version of the program that is to be loaded into RAM address
  $6000.

* **make rom** builds an image to be stored in the X16 ROM (32 kB).


# Required Kernal/Emulator version

The current version of the editor requires Kernal/Emulator version R43 or later.


# Running the RAM version

Run the RAM version with the following command:

x16emu -prg X16EDIT.PRG -run


# Running the HI RAM version

The HI RAM version can be loaded and started with the following commands:

In host computer terminal: x16emu -prg X16EDIT.PRG,6000
On the X16: SYS $6000

# Running the ROM version

There are a few more steps to set up and try the ROM version.

Please see the supplemented manual for details.


# Further reading

Refer to the X16 Edit Manual for further help using the program.


# X16 Community

You may read more about the Commander X16 Platform on the website

https://www.commanderx16.com/
