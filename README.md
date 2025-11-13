Commander X16 BASIC/KERNAL/DOS ROM
=======================================

This is the Commander X16 ROM containing BASIC, KERNAL, and DOS. BASIC and KERNAL are derived from the [Commodore 64 versions](https://github.com/mist64/c64rom).

* BASIC is fully compatible with Commodore BASIC V2, with some additions.
* KERNAL
	* supports the complete $FF81+ API.
	* adds lots of new API, including joystick, mouse and bitmap graphics.
	* supports the same $0300-$0332 vectors as the C64.
	* does not support tape (device 1) or software RS-232 (device 2).
* DOS
	* is compatible with Commodore DOS (`$`, `SCRATCH`, `NEW`, ...).
	* works on SD cards with FAT32 filesystems.
	* supports long filenames, timestamps.
	* supports partitions and subdirectories (CMD-style).


Releases and Building
---------------------

[![Build Status](https://github.com/x16community/x16-rom/actions/workflows/build.yml/badge.svg)](https://github.com/x16community/x16-rom/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/x16community/x16-rom)](https://github.com/x16Community/x16-rom/releases)
[![License: Mixed](https://img.shields.io/github/license/x16community/x16-rom)](./LICENSE.md)
[![Contributors](https://img.shields.io/github/contributors/x16community/x16-rom.svg)](https://github.com/x16community/x16-rom/graphs/contributors)

Each [release of the X16 emulator][emu-releases] includes a compatible build of `rom.bin`. If you wish to build this yourself (perhaps because you're also building the emulator) see below.

> __WARNING:__ The emulator will currently work only with a contemporary version of `rom.bin`; earlier or later versions are likely to fail.

### Building the ROM

Building this source code requires only [GNU Make], [Python 3.7] (or higher), [lzsa] and the [cc65] assembler. GNU Make is almost invariably available as a system package with any Linux distribution; cc65 less often so. 

- Red Hat/CentOS: `sudo yum install make cc65` 
- Debian/Ubuntu: `sudo apt-get install make cc65`

On macOS, cc65 in [homebrew](https://brew.sh/), which must be installed before issuing the following command:

- macOS: `brew install cc65`

If cc65 is not available as a package on your system, you'll need to install or build/install it per the instructions below.

If lzsa is not available as a package on your system, you'll need to install or build/install it per the instructions below.

To check the version of python you have use `python3 --version`.

Once the prerequisites are available, type `make` to build `rom.bin`. To use that with the emulator, copy it to the same directory as the `x16emu` binary or use `x16emu -rom .../path/to/rom.bin`.

*Additional Notes: For users of Red Hat Enterprise Linux 8, you will need to have CodeReady builder repositories enabled, for CentOS, this is called PowerTools. Additionally, you will need Fedora EPEL installed as well as cc65 does not come usually within the official repositories.*

### Building/Installing cc65

#### Linux Builds from Source

You'll need the basic set of tools for building C programs:
- Debian/Ubuntu: `sudo apt-get install build-essential git`

The cc65 source is [on GitHub][cc65]; clone and build it with:

    git clone https://github.com/cc65/cc65.git
    make -j4    # -j4 may be left off; it merely speeds the build

This will leave the binaries in the `bin/` subdirectory; you may use thes directly by adding them to your path, or install them to a standard directory:

    #   This assumes you have ~/.local/bin in your path.
    make install PREFIX=~/.local

#### Building and Packages for Other Systems

Consult the Nesdev Wiki [Installing CC65][nd-cc65] page for some hints, including Windows installs. However, the Debian packages they suggest from [trikaliotis.net] appear to have signature errors.


### Building/Installing lzsa

#### Packages

##### Linux
No major distro offers packages for `lzsa`, so the source build is likely your best option -- see below.

##### Windows
The releases page for the lzsa GitHub repo offers Windows binaries: https://github.com/emmanuel-marty/lzsa/releases

##### MacOS
There is a Homebrew formula: `brew install lzsa`.

#### Linux Builds from Source

The `lzsa` compression utility is used for some resources packaged into the ROM, and is available [on Github](https://github.com/emmanuel-marty/lzsa); clone and build it with:

	git clone git@github.com:emmanuel-marty/lzsa.git
	make

The `lzsa` utility will be left in the root directory of the repository.  It can be copied into a directory in your path, such as `~/.local/bin`.

#### Building for Other Systems

The `lzsa` repository contains project files for both Visual Studio 2017 and XCode, which should allow it to be built for Windows and MacOS.


Credits
-------

See [LICENSE.md](LICENSE.md)

Release Notes
-------------
### Release 48 ("Cadmium")

For hardware compatibilty, the following firmware versions are supported by this ROM release:

* VERA:
	* Recommended: 47.0.2
	* Also supported: 0.3.1, 0.3.2
	* Functional but with known problems: 0.3.3
	* Unsupported: 0.1.1 or older
* SMC:
	* Recommended: 47.2.3
	* Also supported: 43.0.0 and higher
	* Unsupported: 42.0.0 or older

Changelog:

* BUILD
	* Building BASLOAD and X16EDIT now outputs trace headers to facilitate instruction traces in the emulator for those banks. [stefan-b-jakobsson]
* KERNAL
	* Fix a few issues applying the PS/2 typematic (speed/delay) preference after a boot. [stefan-b-jakobsson]
	* Num Lock can now be turned off.
	* Added `extapi` command `kbd_leds` to fetch or set the keyboard LED state
	* Added `extapi` command `scnsiz` to override the KERNAL's text resolution
	* `ioinit` now disables all stock interrupt sources (VERA, VIAs, and YM2151)
	* 65C816 default native NMI handler now chains to the 65C02 one
	* Fixed a bug which caused backspace and quote mode glitches in the BASIC editor when the background color was set to 8 or above.
	* Removed some unused code for softclock and C64 RS-232 [Fulgen301]
* DOS
	* Added a channel 15 "T" command to return the current position within an open file and the total file size. See the [example](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2013%20-%20Working%20with%20CMDR-DOS.md#examples).
* FAT32
	* Reworked code to remove indexed reads and writes on the I/O page which reach into banked RAM, which might have side effects on the 65C816.
* KEYMAP
	* Characters that exist in the layout for ISO-8859-16 that are not in -15 can now be typed [adiee5]
* BASIC
	* New commands `OVAL` (filled) and `RING` (unfilled) which can draw ellipses and circles quickly.
	* Fix `POKE` to I/O space by using a non-indexed addressing mode. This avoids the extra phantom reads which can have side effects. [Fulgen301]
	* Fixed regression in `VPOKE` where if `PEEK()` or `POINTER()` was inside its arguments. a write could happen to the wrong VRAM address
* MATH
	* Changed code in `fdiv` that depended on zeropage wraparound behavior so that it would also work in 65C816 native mode
* GRAPH
	* `GRAPH_draw_oval` implementation added
	* Fixed `FB_set_8_pixels` and `FB_set_8_pixels_opaque` which did not properly handle VRAM addresses > $0FFFF
* CHARSET
	* Added katakana character set [adiee5]
* UTILITIES
	* Stefan B. Jakobsson's X16-Edit has been updated.
	* Stefan B. Jakobsson's BASLOAD has been updated.

### Release 47 ("Roswell")

This is a major update with new features and bug fixes. This ROM requires a matching emulator version.

For hardware compatibilty, the following firmware versions are supported by this ROM release:

* VERA:
	* Recommended: 47.0.2
	* Also supported: 0.3.1, 0.3.2
	* Functional but with known problems: 0.3.3
	* Unsupported: 0.1.1 or older
* SMC:
	* Recommended: 47.0.0
	* Also supported: 43.0.0
	* Unsupported: 42.0.0 or older

Changelog:

* BUILD
	* Removed all 6502/65C02 define switches in the source. [Fulgen301]
	* Removed CODEX.
	* Removed open-roms and related define switches. [Fulgen301]
	* New DIAG memory diagnostics. With support in the SMC (version 47 or higher), a long power button press to turn the system on will memory diagnostics rather than booting the ROM.
* KERNAL
	* 65C816 CPU support: new indirect vectors, interrupt-handling code, and API. The bulk of the legwork for this support was done by [Fulgen301].
		* The KERNAL's 65C816 support is only active when a 65C816 CPU is detected. On a 65C02, it will still continue to operate as before.
		* The KERNAL still by and large operates as on a 65C02. The BASIC interpreter still runs as if it were on a 65C02 and is unaware of 65C816 code.
		* The indirect vector table at `$03xx` has been extended to include native mode interrupts, as well as emulation mode COP and ABORT. The KERNAL populates these with native and emulation mode interrupt handlers. When in native mode, the default native ISR handler chains to the emulation mode handler, so native 65C816 applications can still benefit from ISRs that are only aware of 65C02 instructions.
		* With very limited exceptions, the traditional KERNAL API must still be called with 8 bit memory/index registers, and with the stack pointer at $01xx.
		* The `jsrfar` API call has been made fully 16-bit native capable.
		* A new `extapi16` API call at `$FEA8` was created for additional 65C816-specific calls, which include informing the KERNAL of stack relocations.
		* Relocated the "MIST" signature due to the overlap with the 65C816 ROM vectors. This is a breaking change for the emulator, so an update to emulator R47 is required.
	* Change timing to improve SNES controller compatibilty. [jburks]
	* When attempting to open IEC device 1 (not implemented on X16), the logical file was erroneously left half-open.
	* When calling monitor via the kernal API ($FECC), exiting the monitor via the run command (G) should now work. [irmen]
	* Rearranged low RAM to free up space for new 65C816 trampolines. The row continuation table (62 bytes) has been transformed into a bitmap (8 bytes). Relocated VARFONTS to bank 0 RAM.
	* The day of week in the RTC was not being set correctly in the `rtc_set_date_time` function.
	* When opening a file, the KERNAL uploads the current time to DOS/FAT32 in case updating the timestamp on a file when opening for write is needed. With the RTC date functions using an extra byte of ZP now that they pass the day of week, this ZP location was not being properly preserved around the call to DOS.
	* Support for faster/shorter PS/2 I2C transactions if the SMC version is >= 47.x.x. [stefan-b-jakobsson]
	* New `extapi` KERNAL API call at `$FEAB` (unrelated to the 65C816 call `extapi16`) implements an additional API table for miscellaneous kernal calls. The specific call is selected via the .A register, and the rest of the registers can be used for parameters to the call.
		1. `clear_status` resets the IEC status byte
		2. `getlfs` useful for getting the last device used
		3. `mouse_sprite_offset` good for custom mouse cursors where the locus is at a position in the sprite other than x=0, y=0
		4. `joystick_ps2_keycodes` can remap the keyboard joystick
		5. `iso_cursor_char` sets the blinking cursor screen code to a character other than $9F while in ISO mode.
		6. `ps2kbd_typematic` sets the keyboard repeat delay and repeat rate.
		7. `pfkey`, similar to the C128 `PFKEY` API call. Within the KERNAL screen editor, the actions of the function keys F1-F8, as well as the SHIFT+RUN action can be changed.
		8. `ps2data_fetch` is part of the default ISR, and necessary for populating the data for `ps2data_mouse_raw`, `mouse_scan`, and `kbd_scan`.
		9. `ps2data_raw` returns 0-4 bytes of PS/2 mouse data in r0L-r1H, useful when overriding `mouse_scan` for handling raw PS/2 mouse events, such as implementing non-traditional mouse controls or relative mouse games. Also returns the last scanned key code.
		10. `cursor_blink` is part of the default ISR, and handles blinking the cursor in the KERNAL screen editor if appropriate.
		11. `led_update` is part of the default ISR, and illuminates the SMC activity light based on disk activity.
		12. `mouse_set_position` sets the mouse cursor X/Y to an absolute position.
	* Solved a race in kbd_scan if a KERNAL call was in progress was interrupted by the default ISR.
	* Removed support for preserving state in the KERNAL ISR for VERA 0.1.1. VERA 0.3.1 is the new minimum version.
	* The `LOAD` API call halts loading at $9F00 with an out of memory error if the load started in low RAM. This prevents accidentally clobbering the I/O range and crashing the system through loading an excessively large file.
* DOS
	* Implemented turning on ___experimental___ fast reads (auto_tx) and writes for SD card accesses. There are no known problems with this mode, but out of an abundance of caution, the feature is disabled by default. This is implemented via the channel 15 command `"U0>Bn"` where `n` is a value from 0 to 3:
		* 0 = Turn off fast reads/writes
		* 1 = Fast reads (auto_tx)
		* 2 = Fast writes
		* 3 = Both
* FAT32
	* Implemented renaming across directories (file move).
	* Prevent clobbering a directory upon file overwrite. [stefan-b-jakobsson]
* KEYMAP
	* The PS/2 "MENU" key is now recognized and returns a petscii $06. [stefan-b-jakobsson]
	* The PS/2 "INT'L 1" key is now recognized and can be used in layouts that support it, such as pt-BR. [stefan-b-jakobsson]
* BASIC
	* Quoted numerics for changing the default device number, such as with DOS"9" should now work. [irmen]
	* `LIST` output can be paused and unpaused with the space bar. While paused, PgDn and Down will advance the listing by a page and by a line respectively. [zpc0070]
	* Prevent the `OLD` command from hanging if there is no valid program listing to restore. [JimmyDansbo]
	* The butterfly on the splash screen is now symmetrical. [stefanoborini]
	* New `TDATA()` and `TATTR()` functions to return the screen code at specific tile addresses on VERA layer 1. [JimmyDansbo]
	* Calling POKE with pointer functions such as `POKE <address>,POINTER(<var>)` should now work properly inline. Prior to this change, the expression in the second argument could corrupt the POKE pointer.
	* The splash screen warns if you're using known buggy VERA version 0.3.3.
	* BASIC can now tokenize keywords with lowercase letters in ISO mode.
	* The detected CPU type is now shown in the output of the `HELP` command.
* MATH:
	* Implement VAL_1 in the FP library. This singular routine requires all of BASIC zeropage to be intact ($A9-$FF), not just shared BASIC/MATH zeropage ($A9-$D3). [irmen]
* GRAPH
	* Fix FB_get_pixels and FB_set_pixels overflow when the number of pixels is a multiple of 256. [irmen]
	* GRAPH_put_image is now RAM bank-wrap aware.
* CHARSET
	* Improve the appearance of some glyphs in the ISO character sets. [akumanatt]
	* Add ANSI character set [tomxp411]
	* Add Cyrillic (ISO-8859-5) character sets. [adiee5]
	* Add Eastern European (ISO-8859-16) character sets. [adiee5]
* AUDIO
	* Change initialization order to avoid reading uninitialized memory during init.
* UTILITIES
	* Control Panel: When modifying the vertical scaling, clear the 240p flag if set.
	* Control Panel: Fix date setting bug when the current year is set to a leap year.
	* Control Panel: VERA version is now properly displayed in decimal.
	* Stefan B. Jakobsson's X16-Edit has been updated to fix a few minor bugs.
	* Stefan B. Jakobsson's BASLOAD has been included in the ROM and can be called via X16-Edit.


### Release 46 ("Winnipeg")

This is mainly a minor bugfix release.

* KERNAL
	* Changes to the joystick polling routine released with R45 had a bad interaction with the emulator, causing the emulated buttons to shift by one bit. This affects the emulator but not real hardware. The polling sequence and timing were changed to be in line with how it was done in R44. [stefan-b-jakobsson]
	* Caps Lock incorrectly shifted the `'` key to `"` in the ABC/X16 keyboard layout. [stefan-b-jakobsson]
	* `mouse_scan` had a race against `mouse_get`, specifically if the KERNAL interrupt service routine happend in the middle of reading out one of the 16-bit values of X/Y, the high and low values could be returned out of sync. [stefan-b-jakobsson]
* UTILITIES
	* Stefan B. Jakobsson's X16-Edit has been updated to fix a hang that happens if it is launched without an SD card present.


### Release 45 ("Nuuk")

* META
	* The meaning of the version byte at bank 0 \$FF80 has been updated to comport with the original intent of having prereleases as a negative number and releases as a positive number.  Release R45 will have 45/`$2D` in this spot, while later builds should show as -46/`$D2` to indicate R46 prerelease. This should make minimum version checking in applications a lot easier for custom builds and for in-between updates.
	* Dependency improvements in the Makefile.
	* `lzsa` is now a build dependency as it compresses X16-Edit's help text.
	* VERA firmware versions earlier than 0.3.x will display a deprecation warning on the splash screen.
* KERNAL
	* Paired with updates in SMC firmware 45.1.0, Intellimouse support has been added. This allows for reading the scroll wheel and potentially buttons higher than 3, depending on the mouse type.
	* clock_get_date_time and clock_set_date_time can now return and set the RTC's day of week field. [markjreed]
	* New block-wise write call [`MCIOUT`](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2004%20-%20KERNAL.md#function-name-mciout) to complement the block-wise read call `MACPTR`. This seems to accelerate `save` type calls by about 5x.
	* `CINT` call now uploads the default X16 palette to the VERA.
	* New I2C batch read and write commands `i2c_batch_read` and `i2c_batch_write`.
* DOS/FAT32
	* Fully split DOS and FAT32 into two separate banks, freeing up ample space for fixes and enhancements.
	* `MCIOUT` call implementation for FAT32
* BASIC
	* new [`EXEC`](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2003%20-%20BASIC.md#exec) command plays back scripted input from a RAM location.
	* `MENU` now produces a menu of built-in applications.
	* Improvements to the layout of the second BASIC bank (annex) allowing for more functions to be moved to this area, making room for new features.
	* new system variable `MWHEEL` returns the mouse wheel delta since the last call as a signed 8-bit value.
	* new [`TILE`](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2003%20-%20BASIC.md#tile) comamnd, making pokes to layer 1 screen memory easier.
	* new [`EDIT`](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2003%20-%20BASIC.md#edit) command, invoking the built-in text editor X16-Edit.
	* new sprite-handling commands [`MOVSPR`](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2003%20-%20BASIC.md#movspr), [`SPRITE`](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2003%20-%20BASIC.md#sprite), and [`SPRMEM`](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2003%20-%20BASIC.md#sprmem). The first two have parameters which are inspired by the Commodore 128 version of the commands, but their usage is not exactly the same.
	* `VPOKE` and `VPEEK` can now be used to reach add-on VERA cards. VRAM banks 2-3 point to a VERA at `$9F60` and VRAM banks 4-5 point to a VERA at `$9F80`.
	* DOS wedge emulation. `@`, `/`, and friends can be used in BASIC immediate mode.
	* Chain-`LOAD`ing another BASIC program from within a BASIC program was problematic when the second program used variables, as the variable table pointer was not updated after the load. This was a deficiency in BASIC V2, and is now fixed for the Commander X16.
	* A bug has been fixed affecting `LINPUT`, `LINPUT#`, and `BINPUT#`. These statements would spuriously return a `STRING TOO LONG` error whenever BASIC needed to garbage-collect the string memory before allocating string space to these functions.
	* After a `LOAD` or `BLOAD` into banked RAM, the RAM bank that the load ended at is saved as if the user called the `BANK` command with this value. Prior to this release, the end bank could be immediately read with `PEEK(0)` after loading, but would be clobbered later on as BASIC would reset the RAM bank to the one set by `BANK`.
* MONITOR
	* Improvements related to unwinding the stack to make the PC and register values useful and continuation possible. Making the `BRK` instruction as a breakpoint useful in some situations.
	* The MONITOR now reuses BASIC's zeropage space, no longer clobbering user ZP \$22-\$2F
	* New `J` command for JSR into memory, complementing the `G` command to continue execution.
* UTILITIES
	* The 8-Bit Guy's hex editor has been added to the `MENU`
	* Stefan B. Jakobsson's X16-Edit has been added to the `MENU`, and is also callable from BASIC's `EDIT` command, or via an API call in bank 13, making it useful as an editor spawned by other applications.


### Release 44 ("Milan")

This is the third release of x16-rom by the X16Community team

* KERNAL
	* **BREAKING CHANGE**
		* The first batch of X16 developer boards were originally shipped without VPB support. The VPB bodge will need to be done before upgrading to ROM version R44 or later. Most of the board owners have been walked through doing the bodge. If you have such an early board (DEV0004-DEV0014) and have not performed the modification, please reach out on the Commander X16 forums or on Discord.
	* Implement a custom callback from the screen editor to intercept, suppress, or remap key events. This is used by the MONITOR to handle scrolling off the top and bottom of the screen when viewing disassembly or memory, but it is also available to [user programs](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2002%20-%20Editor.md#custom-basin-petscii-code-override-handler).
	* Move NMI/IRQ handler entry into low RAM, which now requires hardware or emulator VPB support. Prior to this change, VPB was optional. [akumanatt]
	* Add PS/2 Menu key to keycode.inc [stefan-b-jakobsson]
	* Validate nvram checksum before fetching keyboard layout [stefan-b-jakobsson]
	* Improve bounds checking when loading the keymap from nvram
	* In the screen editor, pressing Shift+40/80 (Shift+ScrLock) to change outputs now emits a beep code to indicate which output is selected.  (Low=VGA, Mid=NTSC, High=RGB)
	* Depending on VERA version, kernal ISR now preserves the FX_CTRL register when doing screen updates (cursor blink, mouse sprite).
	* VERA firmwares without a version number or those older than v0.1.1 will display a deprecation warning at boot.
	* Change joystick scan timing to support more third party SNES controllers. [jburks]
	* Prevent the scroll delay when holding Ctrl from clearing the keyboard buffer. This was resulting in dropped characters after pasting code into the emulator on PC.
	* Scale mouse H/V separately based on screen mode.
	* Set mouse pointer to center of display when activating.
	* Preserve L+R outputs for PSG voice 0 around beep function
* CHARSET
	* revert accidental deletion of the butterfly glyph from the main ISO character set.
* DOS
	* Fix bug in `C` copy command [stefan-b-jakobsson]
	* Add `$=L` long directory output, which includes both a human readable size (e.g. "16 KB") and a machine readable exact file size (e.g. `0003fa30`). The line also includes the FAT attribute byte (e.g. `10`), and the modified timestamp in ISO format.
	* Treat `,` comma as an invalid CMDR-DOS filename character, show as `?` in listings.
* BASIC
	* Fix bug with overbroad REN(UMBER) line number parsing
	* new `BANNER` statement
	* Honor new end-of-basic address after call to `MEMTOP`
	* Fix old BASIC garbage collect bug [XarkLabs]
	* Change `OLD` so that it doesn't try to load `AUTOBOOT.X16` [stefan-b-jakobsson]
	* Add YM variant field in the output of the `HELP` command.
	* The `DOS` directory listing command will now case-fold any filename characters which appear as shifted PETSCII if the screen editor is in PETSCII mode, which should mitigate most of the problems with lowercase filenames.
	* `VAL()` can now parse hex (`$xxxx`) and binary (`%xxxxxxxx`) literals
* MONITOR
	* When triggering entry into the monitor via BRK, the displayed PC and registers should now reflect the state upon BRK. The PC will be show as one byte after the BRK instruction.
* GRAPH
	* Accelerate fb_fill_pixels [stople]
	* Fix uninitialized px/py state in console_init
* AUDIO
	* Fix logic bug in `psg_write_fast` routine.
	* Add YM chip type detection logic. `ym_init` can distinguish between a YM2151 and a YM2164.
* UTIL
	* Always enable nvram battery backup when exiting `MENU` [stefan-b-jakobsson]
* BUILD
	* Portability enhancements [dressupgeekout]
	* Drop GEOS bank
	* Remove stale C64 target

### Release 43 ("Stockholm")

This is the second release of x16-rom by the X16Community team

* KERNAL
	* **BREAKING CHANGE**
		* The keyboard protocol between the SMC and the KERNAL has changed. This release requires a firmware update to the System Management Controller on hardware, or on emulator, release R43 or later.
		* This change also affects how the custom keyboard handler vector works (keyhdl). For details, see [Chapter 2 of the Programmer's Reference Guide](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2002%20-%20Editor.md#custom-keyboard-keynum-code-handler)
		* **Your Keyboard will not work unless** you are running
			* R43 of both x16-rom and x16-emulator (on emulator)
			* R43 of both x16-rom and x16-smc (on hardware)
	* Build
		* Add git signature to ROM build process
		* Update source to use zp addressing mode where appropriate, which suppresses warnings about using absolute mode for zp addresses.
		* Due to cc65's use of KERNAL RAM locations, `.assert`s were added to try to stablize RAM locations that are hardcoded in cc65's constants file.
	* Hardware support
		* Additional support for display preferences and keymap stored in nvram
		* Support VPB. Hardware with this design sets the hardware ROM bank to 0 immediately before reading a ROM vector. The previous ROM bank will still be in zp `$01` upon interrupt handler entry.
		* Bugfix: fix joysticks always being detected
	* Editor/Display
		* New bordered screen modes to support CRTs
		* New behavior for the END key. END will go to the end of the current line. Shift+END will go to the last line on the screen.
		* PS/2 Delete key now deletes the character underneath the cursor.
		* Blinking cursor should be more visible during movement.
		* Support for automatically setting 240p in NTSC and RGB modes for screen modes that are scaled 2x vertically.
		* New skinny PET style PETSCII and ISO charsets.
		* Replace bold ISO charset [akumanatt]
	* BASIC
		* New logo splash logic for smaller screen modes
		* Show git signature in BASIC splash screen under non-releases
		* `REBOOT` and `RESET` behaviors swapped.
		* Add "I" (instrument) to playstring macros for FMPLAY, PSGPLAY, and friends.
		* Bugfix: If unable to read color pref from nvram, use the default white on blue.
		* Show DOS status after `SAVE` and `DOS` commands.
		* Modify the output of F-keys in the BASIC editor. Removed F9 for keymap cycling.
		* Bugfix: Better support for reading CBM drives' status with the `DOS` command.
		* Make `FRE(n)` always return a positive value.
		* New BANNEX (BASIC annex) for overflow code from BASIC.
		* New commands:
			* `MENU` - load utility
			* `REN` - renumber BASIC program
			* `LINPUT` - Read line from keyboard
			* `LINPUT#` - Read delimited data from file
			* `BINPUT#` - Read fixed-length data from file
			* `HELP` - Show short help blurb and hardware versions.
		* New functions:
			* `POINTER()` - return pointer to variable structure
			* `STRPTR()` - return pointer to string variable's data
			* `RPT$()` - return a string made up of a repeated byte
	* MONITOR
		* Bugfix: Better support for reading CBM drives' status with the `@` command
		* Bugfix: Clear bank flags at init [stefan-b-jakobsson]
	* API
		* Allow `sprite_set_position` to retain existing priority/flip values in attribyte byte 6.
	* GRAPH
		* Fully implement `fb_fill_pixels` [stople]


### Release 42 ("Cambridge")

This is the first release of x16-rom by the X16Community team

* KERNAL
	* I2C
		* Fixed I2C writing [mist64]
		* Support battery backup [jburks]
		* Moved PS/2 functions to I2C interface [jburks, stefan-b-jakobsson]
		* Caps Lock LED and 40/80 key support [stefan-b-jakobsson]
	* Editor
		* Added WAI to busy loop [LRFLEW]
		* Cosmetic fixes [jestin, stefan-b-jakobsson]
		* Fix line wrap in 20 column modes [mooinglemur]
		* Shift+40/80 will cycle through the three output modes: VGA, Composite, RGB
	* Channel I/O
		* MACPTR: support non-incrementing I/O address as destination [ZeroByteOrg]
		* Fix VERIFY routine (a special case of LOAD).
		* Add headerless SAVE (`BSAVE`) API at `$FEBA`, which otherwise behaves identically to `SAVE` at `$FFD8`
	* Memory
		* Improved RAM detection and testing, allowing for high RAM amounts other than a power of 2 [JimmyDansbo]
		* Fix memory_decompress to VRAM [bsb-Rickd]
		* New cartridge detection and booting in ROM bank 32
		* NMI vector has been replicated in all configured banks to point to a new RAM trampoline that in turn sets the ROM bank to 0 and jumps through (nminv), which by default points to a KERNAL routine that behaves like STOP+RESTORE on the C64.
		* Support RTC NVRAM settings for two profiles to control screen output mode and resolution at boot, selectable with the 40/80 key. Currently requires an external configuration program to set up the profiles.
		* Allocate a page of RAM bank 0 intended for use by user programs to accept parameters set by other such programs such as, for example, file browsers or launchers.
	* Gamepad
		* Properly set presence for nonstandard controllers [akumanatt]
* DOS
	* Return the current working directory with `DOS"$=C"` [mooinglemur]
	* Prevent attempt at cross-directory renames as they're not supported.
	* Allow file append syntax with secondary address 1 (write)
* BASIC
	* Stabilize token assignments for X16 additions to BASIC keywords. BASIC programs saved in this release should be compatible with future releases. [stefan-b-jakobsson]
	* [New commands and functions](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2003%20-%20BASIC.md) [stefan-b-jakobsson, jestin, mooinglemur]
		* `BANK`
		* `BSAVE`
		* `FMCHORD`
		* `FMDRUM`
		* `FMFREQ`
		* `FMINIT`
		* `FMINST`
		* `FMNOTE`
		* `FMPAN`
		* `FMPLAY`
		* `FMPOKE`
		* `FMVIB`
		* `FMVOL`
		* `I2CPEEK`
		* `I2CPOKE`
		* `POWEROFF`
		* `PSGCHORD`
		* `PSGFREQ`
		* `PSGINIT`
		* `PSGNOTE`
		* `PSGPAN`
		* `PSGPLAY`
		* `PSGVOL`
		* `PSGWAV`
		* `REBOOT`
		* `SLEEP`
	* Allow `ASC("")` to return 0 rather than an error
	* Allow `RESTORE` to take a line number argument to set the READ pointer to an arbitrary DATA constant.
	* Added test case test/show-gfx.bas [Jaxartes]
* GRAPH
	* New bank for graphics and font routines to free up KERNAL bank space [stefan-b-jakobsson]
	* Implement FB_set_palette [irmen]
* AUDIO
	* New bank and [new machine language API](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2009%20-%20Sound%20Programming.md) to interact with the YM2151 and VERA PSG, including a full General MIDI-inspired patch set for the YM2151 mainly for use with new BASIC statements [ZeroByteOrg, mooinglemur, jestin]
	* YM2151 and VERA PSG are silenced and reinitialized at boot and in the default handlers for NMI and BRK.
* CODEX
	* Fix for line delete crash [stefan-b-jakobsson]
	* Fix for build under latest cc65 [mooinglemur]
* GEOS
	* Fix mouse issues [stefan-b-jakobsson]	
* Documentation
	* Improve README.md [mobluse]
* Build
	* Add ROM build to CI/CD [maxgerhardt]
### Release 41 ("Marrakech")

* KERNAL
	* keyboard
		* added 16 more keyboard layouts (28 total)
		* default layout ("ABC/X16") is now based on Macintosh "ABC - Extended" (full ISO-8859-15, no dead keys)
		* "keymap" API to activate a built-in keyboard layout
		* custom keyboard layouts can be loaded from disk (to $0:$A000)
		* Caps key behaves as expected
		* support for Shift+AltGr combinations
		* support for dead keys (e.g. ^ + e = ê)
		* PgUp/PgDown, End, Menu and Del generate PETSCII codes
		* Numpad support
		* Shift+Alt toggles between charsets (like C64)
		* Editor: "End" will position cursor on last line
	* VERA source/target support for `memory_fill`, `memory_copy`, `memory_crc`, `memory_decompress` [with PG Lewis]
	* fixed headerless load for verify/VRAM cases [Mike Ketchen]
	* don't reset screen colors on mode switch
* BASIC:
	* `BLOAD`, `BVLOAD` and `BVERIFY` commands for header-less loading [ZeroByteOrg]
	* `KEYMAP` command to change keyboard layout
	* support `DOS8`..`DOS31` (and `A=9:DOSA` etc.) to switch default device
	* `MOUSE` and `SCREEN` accept -1 as argument (was: $FF)
	* Changed auto-boot filename from `AUTOBOOT.X16*` to `AUTOBOOT.X16`
* Monitor:
	* fixed RMB/SMB disassembly
* Charset:
	* X16 logo included in ISO charset, code $AD, Shift+Alt+k in ISO mode

### Release 40 ("Bonn")

* KERNAL
	* Features
		* NMI & BRK will enter monitor
		* added ':' to some F-key replacements
		* allow scrolling screen DOWN: `PRINTCHR$($13)CHR$($91)`
		* Serial Bus works on hardware
	* Bugs
		* fixed SA during LOAD
		* fixed joystick routine messing with PS/2 keyboard [Natt Akuma]
	* API
		* keyhandler vector ($032E/$032F) doesn't need to return Z
		* PLOT API will clear cursor
* BASIC
		* on RESET, runs PRG starting with "AUTOBOOT.X16" from device 8 (N.B.: on host fs, name it "AUTOBOOT.X16*" for now!)
		* BOOT statement with the same function
* DOS
	* better detection of volume label
	* fixed `$=P` (list partitions), `$*=P`/`D` (dir filtering), hidden files
* MONITOR
	* fixed F3/F5 and CSR UP/DOWN auto-scrolling
	* fixed LOAD, SAVE, @
* CodeX
	* works this time! [mjallison42]

### Release 39 ("Buenos Aires")

* KERNAL
	* Adaptation to match Proto 2 Hardware
		* support for 4 SNES controllers
		* 512 KB ROM instead of 128 KB
		* new I/O layout
		* PS/2 and SNES controller GPIOs layout
		* banking through $00 and $01
	* Proto 2 Hardware Features
		* I2C bus (driver by Dieter Hauer, 2-clause BSD)
		* SMC: reset and shutdown support
		* RTC: `DA$`/`TI$` and KERNAL APIs bridge to real-time-clock
	* Screen Features
		* New screen_mode API allows setting and getting current mode and resolution
		* support for 320x240 framebuffer (mode $80/128) [with gaekwad]
		* added 80x30,40x60,40x30,40x15,20x30,20x15 text modes (note new numbers!)
	* Keyboard Features
		* added KERNAL vector to allow intercepting PS/2 codes [Stefan B Jakobsson]
		* added kbdbuf_peek, kbdbuf_get_modifiers, kbdbuf_put API
	* Other Features
		* support for LOADing files without 2-byte PRG header [Elektron72]
		* support for LOAD into banked RAM (acptr and macptr)
		* support BEL code (`PRINT CHR$(7)`)
		* keyboard joystick (joystick 0) supports all SNES buttons
		* support for 4 SNES controllers (joystick 1-4) [John J Bliss]
	* Bugs
		* fixed crash in FB_set_pixels for count>255 [Irmen de Jong]
		* fixed bank switching macros [Stephen Horn]
		* fixed preserving P in JSRFAR [CasaDeRobison]
		* fixed race condition in joystick_get [Elektron72]
		* removed ROM banking limitations from JSRFAR and FETVEC [Elektron72, Stefan B Jakobsson]
		* fixed disabling graphics layer when returning to text mode [Jaxartes]
		* fixed default cursor color when switching to text mode
		* reliable mouse_config support for screen sizes
* Math
	* renamed "fplib" to "math"
	* made Math package compatible with C128/C65, but fixing FADDT, FMULTT, FDIVT, FPWRT
* BASIC
	* Features
		* added `BIN$` & `HEX$` functions [Jimmy Dansbo]
		* added LOCATE statement
	* Bugs/Optimizations
		* removed extra space from BASIC error messages [Elektron72]
		* fixed `DA$` and `TI$` when accessed together or with `BIN$()`/`HEX$()` [Jaxartes]
		* fixed null handling in `GET`/`READ`/`INPUT` [Jaxartes]
		* fixed bank setting in `VPOKE` and `VPEEK` [Jaxartes]
		* fixed optional 'color' argument parsing for `LINE`, `FRAME`, `RECT`
* DOS
	* reliable memory initialization
	* fixed writing LFN directory entries across sector boundary
	* fixed missing partitions ($=P) if type is $0B
	* fixed loading to the passed-in address when SA is 0 [gaekwad]
	* fixed problem where macptr would always return C=0, masking errors
* GEOS
	* text input support
* CodeX
	* integrated CodeX Interactive Assembly Environment into ROM [mjallison42]

### Release 38 ("Kyoto")

* KERNAL
	* new `macptr` API to receive multiple bytes from an IEEE device
	* `load` uses `macptr` for LOAD speeds from SD card of about 140 KB/sec
	* hacked (non-functional) Commodore Serial to not hang
	* LOAD on IEEE without fn defaults to ":*"; changed F5 key to "LOAD"
	* fixed `screen_set_charset` custom charset [Rebecca G. Bettencourt]
	* fixed `stash` to preserve A
	* `entropy_get`: better entropy
* MATH
	* optimized addition, multiplication and `SQR` [Michael Jørgensen]
	* ported over `INT(.9+.1)` = 0 fix from C128
* BASIC
	* updated power-on logo to match the real X16 logo better
	* like `LOAD`/`SAVE`, `OPEN` now also defaults to last IEEE device (or 8)
	* fixed STOP key when showing directory listing (`DOS"$"`)
* CHARSET
	* changed PETSCII screen codes $65/$67 to PET 1/8th blocks
* DOS
	* switched to FAT32 library by Frank van den Hoef
	* rewrote most of DOS ("CMDR-DOS"), almost CMD FD/HD feature parity
		* write support
		* new "modify" mode ("M") that allows reading and writing
		* set-position support in PRG files (like sd2iec)
		* long filenames, full ISO-8859-15 translation
		* wildcards
		* subdirectories
		* partitions
		* timestamps
		* overwriting ("@:")
		* directory listing filter
		* partition listing
		* almost complete set of commands ("scratch", "rename", ...)
		* formatting a new filesystem ("new")
		* activity/error LED
		* detection of SD card presence, fallback to Commodore Serial
		* support for switching SD cards
		* details in the [CMDR-DOS README](https://github.com/commanderx16/x16-rom/blob/master/dos/README.md)
	* misc fixes [Mike Ketchen]

### Release 37 ("Geneva")

* API features
	* console
		* new: console_put_image (inline images)
		* new: console_set_paging_message (to pause after a full screen)
		* now respects window insets
		* try "TEST1" and "TEST2" in BASIC!
	* new entropy_get API to get randomness, used by MATH/BASIC RND function
* KERNAL
	* support for VERA 0.9 register layout (Frank van den Hoef)
* BASIC
	* `TI$` and `DA$` (`DATE$`) are now connected to the new date/time API
	* TI is independent of `TI$` and can be assigned
* DOS
	* enabled partition types 0x0b and 0x0c, should accept more image types
* Build
	* separated KERNAL code into core code and drivers
	* support for building KERNAL for C64
	* ROM banks are built independently
	* support to replace CBM channel and editor code with GPLed "open-roms" code by the MEGA65 project
* bug fixes
	* `LOAD` respects target address
	* FAT32 code no longer overwrites RAM
	* monitor is not as broken any more

### Release 36 ("Berlin")

* API Features
	* added console API for text-based interfaces with proportional font and styles support: console_init, console_put_char, console_get_char
	* added memory API:
		* memory_fill
		* memory_copy
		* memory_crc
		* memory_decompress (LZSA2)
	* added sprite API: sprite_set_image, sprite_set_position
	* renamed GRAPH_LL to FB (framebuffer)
	* GRAPH_init takes an FB graphics driver as an argument

* KERNAL features
	* detect SD card on TALK and LISTEN, properly fall back to serial
	* joystick scanning is done automatically in VBLANK IRQ; no need to call it manually any more
	* added VERA UART driver (device 2)
	* bank 1 is now the default after startup; KERNAL won't touch it
	* sprites and layer 0 are cleared on RESET
	* changed F5 to LOAD":* (filename required for IEEE devices)
	* GRAPH_move_rect supports overlapping [gaekwad]

* BASIC
	* default `LOAD`/`SAVE` device is now 8
	* added `RESET` statement [Ingo Hinterding]
	* added `CLS` statement [Ingo Hinterding]

* CHARSET
	* fixed capital Ö [Ingo Hinterding]
	* Changed Û, î, ã to be more consistent [Ingo Hinterding]

* bug fixes
	* `COLOR` statement with two arguments
	* `PEEK` for ROM addresses
	* keyboard code no longer changes RAM bank
	* fixed clock update
	* fixed side effects of Ctrl+A and color control codes [codewar65]

* misc
	* added 3 more tests, start with "TEST1"/"TEST2"/"TEST3" in BASIC:
	* TEST0: existing misc graphics test
	* TEST1: console text rendering, character wrapping
	* TEST2: console text rendering, word wrapping
	* TEST3: console text input, echo

### Release 35

* API Fetures
	* new KERNAL API: low-level and high-level 320x200@256c bitmap graphics
	* new KERNAL API: get mouse state
	* new KERNAL API: get joystick state
	* new KERNAL API: get/set date and time (old RDTIM call is now a 24 bit timer)
	* new floating point API, jump table at $FC00 on ROM bank 4 (BASIC)

* KERNAL Features
	* invert fg/bg color control code (Ctrl+A) [Daniel Mecklenburg Jr]
	
* BASIC
	* added `COLOR <fg, bg>` statement to set text color
	* added `JOY(n)` function (arg 1 for joy1, arg 2 for joy2)
	* added `TEST` statement to start graphics API unit test
	* `CHAR` statement supports PETSCII control codes (instead of GEOS control codes), including color codes

* misc
	* KERNAL variables for keyboard/mouse/clock drivers were moved from $0200-$02FF to RAM bank #0
	* $8F (set PETSCII-UC even if ISO) printed first after reset [Mikael O. Bonnier]

* bug fixes:
	* got rid of $2c partial instruction skip [Joshua Scholar]
	* fixed `TI`/`TI$`
	* fixed CBDOS infinite loop
	* zp address 0 is no longer overwritten by mouse code
	* mouse scanning is disabled if mouse is off
	* VERA state is correctly saved/restored by IRQ code

### Release 34

* new layout for zero page and KERNAL/BASIC variables:
	* $00-$7F available to the user
	* ($02-$52 are used if using BASIC graphics commands)
	* $80-$A3 used by KERNAL and DOS
	* $A4-$A8 reserved for KERNAL/DOS/BASIC
	* $A9-$FF used by BASIC
* new BASIC statements:
	* `SCREEN <mode>` (0: 40x30, 2: 80x60, 128: graphics)
	* `PSET <x>, <y>, <color>`
	* `LINE <x1>, <y1>, <x2>, <y2>, <color>`
	* `FRAME <x1>, <y1>, <x2>, <y2>, <color>`
	* `RECT <x1>, <y1>, <x2>, <y2>, <color>`
	* `CHAR <x>, <y>, <color>, <string>`
	* `MOUSE <n>` (0: off, 1: on)
* new BASIC functions:
	* `MX` (mouse X coordinate)
	* `MY` (mouse Y coordinate)
	* `MB` (mouse button; 1: left, 2: right, 4: third)
* new KERNAL calls:
	* `MOUSE`: configure mouse
	* `SCRMOD`: set screen mode
* new PS/2 mouse driver
* charsets are uploaded to VERA on demand
* GEOS font rendering uses less slant for faux italics characters
* misc GEOS KERNAL improvements and optimizations

### Release 33

* BASIC
	* additional `LOAD` syntax to load to a specific address `LOAD [filename[,device[,bank,address]]]`
	* `LOAD` into banked RAM will auto-wrap into successive banks
	* `LOAD` allows trailing garbage; great to just type `LOAD` into a directory line [John-Paul Gignac]
	* new BASIC statement: `VLOAD` to load into video RAM: `VLOAD [filename[,device[,bank,address]]]` [John-Paul Gignac]
	* complete jump table bridge
* KERNAL: memory size detection
* KERNAL: faster IRQ entry
* GEOS: converted graphics library to VERA 320x200@256c

### Release 32

* correct ROM banking:
	* BASIC and KERNAL now live on separate 16 KB banks ($C000-$FFFF)
	* BASIC `PEEK` will always access KERNAL ROM
	* BASIC `SYS` will have BASIC ROM enabled
* added GEOS
* added `OLD` statement to recover deleted BASIC program after `NEW` or `RESET`
* removed software RS-232, will be replaced by VERA UART later
* Full ISO mode support in Monitor

### Release 31

* switched to VERA 0.8 register layout; character ROM is uploaded on startup
* ISO mode: ISO-8859-15 character set, standard ASCII keyboard
* keyboard
	* completed US and UK keymaps so all C64 characters are reachable
	* support for AltGr
	* support for F9-F12
* allow hex and binary numbers in `DATA` statements [Frank Buss]
* switched SD card from VIA SPI to VERA SPI (works on real hardware!)
* fix: `VPEEK` overwriting `POKER` ($14/$15)
* fix: `STOP` sometimes not registering in BASIC programs

### Release 30

* support for 13 keyboard layouts; cycle through them using F9
* `GETJOY` call will fall back to keyboard (cursor/Ctrl/Alt/Space/Return), see Programmer's Reference Guide on how to use it
* startup message now shows ROM revision
* $FF80 contains the prerelease revision (negated)
* the 60 Hz IRQ is now generated by VERA VSYNC
* fix: `VPEEK` tokenization
* fix: CBDOS was not correctly preserving the RAM bank
* fix: KERNAL no longer uses zero page $FC-$FE



<!-------------------------------------------------------------------->
[GNU Make]: https://www.gnu.org/software/make/
[Python 3.7]: https://www.python.org/downloads/release/python-370/
[lzsa]: https://github.com/emmanuel-marty/lzsa
[cc65]: https://cc65.github.io/
[emu-releases]: https://github.com/X16community/x16-emulator/releases
[nd-cc65]: https://wiki.nesdev.com/w/index.php/Installing_CC65
[trikaliotis.net]: https://spiro.trikaliotis.net/debian
