#!/usr/bin/env python3

# This verifies that ROM doesn't start with value $BF, which is
# the SST39SF040 manufacturer ID. Reading the manufacturer ID is
# used to detect whether the ROM is write-enabled or not. That
# would not work if the start of ROM is set to the same value
# as the manufacturer ID.

import sys

# Usage
if len(sys.argv) != 2:
	print("Usage: " + os.path.basename(__file__) + " path")
	print(" path to rom.bin")
	exit(1)

# Check file content
f = open(sys.argv[1], "rb")
b = int.from_bytes(f.read(1), byteorder="little", signed=False)

print ("Verifying start of Kernal image... ", end="")
if b == 0xbf:
	print("FAIL")
	print("Kernal first byte: 0xBF")
	exit(1)
else:
	print("OK")
